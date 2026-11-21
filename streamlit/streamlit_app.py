"""
Snowflake DCM DevOps & Developer Isolation - interactive demo
Runs in Streamlit in Snowflake as DCM_DEMO_ADMIN. Every grid, PLAN, DEPLOY and
validation result on screen comes from SQL executed against this account.
"""
from __future__ import annotations

import datetime as dt
import json
import re

import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

import dcm_core as core

st.set_page_config(page_title="DCM DevOps Demo", page_icon="❄️", layout="wide")
session = get_active_session()

# ----------------------------------------------------------------------------- SQL
def sql(statement: str):
    return [r.as_dict() for r in session.sql(statement).collect()]


def df(rows, cols=None):
    frame = pd.DataFrame(rows)
    if cols and not frame.empty:
        frame = frame[[c for c in cols if c in frame.columns]]
    return frame


def show(rows, cols=None, height=None):
    if not rows:
        st.info("No rows returned.")
        return
    kwargs = {"width": "stretch", "hide_index": True}
    if height:
        kwargs["height"] = height
    st.dataframe(df(rows, cols), **kwargs)


# ------------------------------------------------------------------- state & status
ss = st.session_state
ss.setdefault("status", {})        # step key -> dict(state, msg, ts)
ss.setdefault("plans", {})         # (target, ref) -> dict(result, commit, ts, reviewed)
ss.setdefault("results", {})       # free-form stored outputs per step key
ss.setdefault("snapshots", {})     # scenario -> list of (label, totals)
ss.setdefault("guide_step", 0)

STATUS_ICON = {"NOT STARTED": "⚪ Not started", "RUNNING": "🔵 Running", "SUCCESS": "🟢 Successful", "FAILED": "🔴 Failed"}


def status_chip(key: str):
    s = ss.status.get(key)
    if not s:
        st.caption(STATUS_ICON["NOT STARTED"])
        return
    st.caption(f"{STATUS_ICON[s['state']]} · {s['ts']}" + (f" · {s['msg']}" if s.get("msg") else ""))


def set_status(key, state, msg=""):
    ss.status[key] = {"state": state, "msg": msg, "ts": dt.datetime.now().strftime("%H:%M:%S")}


def audit(**kw):
    try:
        core.log_event(sql, source="streamlit", **kw)
    except Exception as e:  # never hide the original result because logging failed
        st.warning(f"Audit log write failed: {e}")


def last_query_id():
    try:
        return sql("SELECT LAST_QUERY_ID(-1) AS QID")[0]["QID"]
    except Exception:
        return ""


def run(key, label, fn, *, actor="", scenario="", operation="", target="", ref="", command=""):
    """Execute fn() with status tracking, error display and audit logging."""
    set_status(key, "RUNNING")
    commit = ""
    if ref and not ref.startswith("commit:"):
        try:
            commit = core.branch_commit(sql, ref) or ""
        except Exception:
            commit = ""
    elif ref:
        commit = ref.split(":", 1)[1]
    with st.spinner(f"{label} ..."):
        try:
            out = fn()
        except Exception as e:
            set_status(key, "FAILED", "see error")
            ss.results[key] = {"error": str(e)}
            audit(actor=actor, scenario=scenario, operation=operation, target=target, branch=core.ref_label(ref) if ref else "",
                  commit=commit, status="FAILED", command=command, error=str(e))
            return None
    set_status(key, "SUCCESS")
    ss.results[key] = {"output": out, "commit": commit}
    audit(actor=actor, scenario=scenario, operation=operation, target=target, branch=core.ref_label(ref) if ref else "",
          commit=commit, status="SUCCESS", command=command, output=_jsonable(out), query_id=last_query_id())
    return out


def _jsonable(out):
    try:
        json.dumps(out, default=str)
        return out
    except Exception:
        return str(out)


def show_error(key):
    r = ss.results.get(key)
    if r and r.get("error"):
        st.error(r["error"])


# ------------------------------------------------------------ reusable DCM widgets
def plan_widget(key, target, ref, actor, scenario):
    t = core.TARGETS[target]
    st.markdown(f"**DCM PLAN** · project `{t['project']}` · configuration `{t['config']}` · source `{core.ref_label(ref)}`")
    st.code(core.dcm_plan_sql(target, ref), language="sql")
    if st.button(f"▶ Run DCM PLAN ({actor} → {target})", key=f"btn_{key}"):
        res = run(key, "DCM PLAN", lambda: core.dcm_plan(sql, target, ref), actor=actor, scenario=scenario,
                  operation="PLAN", target=target, ref=ref, command=core.dcm_plan_sql(target, ref))
        if res is not None:
            ss.plans[(target, ref)] = {"result": res, "commit": ss.results[key].get("commit"), "reviewed": False,
                                       "ts": dt.datetime.now().strftime("%H:%M:%S")}
    status_chip(key)
    show_error(key)
    plan = ss.plans.get((target, ref))
    if plan and ss.status.get(key, {}).get("state") == "SUCCESS":
        render_changeset(plan["result"], f"PLAN result ({plan['ts']}, commit {str(plan['commit'])[:7]})")


def render_changeset(result, title):
    summ = core.changeset_summary(result)
    c1, c2, c3 = st.columns(3)
    c1.metric("Create", summ.get("CREATE", 0))
    c2.metric("Alter", summ.get("ALTER", 0))
    c3.metric("Drop", summ.get("DROP", 0))
    rows = core.changeset_rows(result)
    st.markdown(f"**{title}** - exact objects that will change:")
    show([{k: v for k, v in r.items() if k != "CHANGES"} | {"CHANGE_DETAIL": r["CHANGES"][:300]} for r in rows],
         ["ACTION", "OBJECT_TYPE", "OBJECT", "ONLY_ADOPTION", "CHANGE_DETAIL"])
    new_def = core.view_definition_change(result)
    if new_def:
        st.markdown("New definition of **VW_CUSTOMER_SALES** in this changeset:")
        st.code(new_def, language="sql")
    with st.expander("Raw DCM JSON output"):
        st.json(result)


def deploy_widget(key, target, ref, actor, scenario, alias_prefix):
    t = core.TARGETS[target]
    plan = ss.plans.get((target, ref))
    st.markdown(f"**DCM DEPLOY** · `{t['project']}` → databases `{t['analytics_db']}`, `{t['business_db']}`")
    if not plan:
        st.warning("Safety gate: run and review the DCM PLAN for this target and branch first.")
        status_chip(key)
        return
    reviewed = st.checkbox(f"I have reviewed the PLAN ({sum(core.changeset_summary(plan['result']).values())} objects, "
                           f"{core.changeset_summary(plan['result']).get('DROP', 0)} drops)", key=f"rev_{key}")
    alias = f"{alias_prefix}-{str(plan.get('commit') or 'na')[:7]}-{dt.datetime.now().strftime('%H%M%S')}"
    st.code(core.dcm_deploy_sql(target, ref, alias), language="sql")
    if st.button(f"🚀 Run DCM DEPLOY ({actor} → {target})", key=f"btn_{key}", disabled=not reviewed):
        res = run(key, "DCM DEPLOY", lambda: core.dcm_deploy(sql, target, ref, alias), actor=actor, scenario=scenario,
                  operation="DEPLOY", target=target, ref=ref, command=core.dcm_deploy_sql(target, ref, alias))
        if res is not None:
            ss.plans.pop((target, ref), None)  # a new deploy needs a new plan
    status_chip(key)
    show_error(key)
    r = ss.results.get(key, {}).get("output")
    if r and ss.status.get(key, {}).get("state") == "SUCCESS":
        render_changeset(r, "DEPLOY applied")


def query_widget(key, target, actor="", scenario="", snapshot_scenario=None, snapshot_label=""):
    t = core.TARGETS[target]
    fqn = f"{t['business_db']}.BUSINESS_READY.VW_CUSTOMER_SALES"
    if st.button(f"🔎 Query {fqn}", key=f"btn_{key}"):
        out = run(key, "Query view", lambda: {"sample": core.customer_view_sample(sql, target),
                                              "totals": core.customer_view_totals(sql, target)},
                  actor=actor, scenario=scenario, operation="QUERY VIEW", target=target, command=f"SELECT ... FROM {fqn}")
        if out and snapshot_scenario:
            ss.snapshots.setdefault(snapshot_scenario, []).append((snapshot_label, target, out["totals"]))
    status_chip(key)
    show_error(key)
    out = ss.results.get(key, {}).get("output")
    if out:
        tot = out["totals"]
        c1, c2, c3 = st.columns(3)
        c1.metric("Discount", f"{float(tot.get('DISCOUNT_PCT') or 0):.0%}")
        c2.metric("Gross SALES_AMOUNT", f"{float(tot.get('SALES_AMOUNT') or 0):,.2f}")
        c3.metric("NET_SALES", f"{float(tot.get('NET_SALES') or 0):,.2f}")
        show(out["sample"])


def validation_widget(key, target, actor, scenario):
    if st.button(f"🧪 Run independent business-rule validation on {target}", key=f"btn_{key}"):
        def go():
            template = core.read_validation_template(sql, "main")
            return core.run_validation(sql, template, target)
        run(key, "Validation", go, actor=actor, scenario=scenario, operation="VALIDATE", target=target,
            command=core.VALIDATION_SQL_PATH)
        rows = ss.results.get(key, {}).get("output") or []
        if any(r["STATUS"] != "PASS" for r in rows):
            set_status(key, "FAILED", f"{sum(r['STATUS'] != 'PASS' for r in rows)} business rules violated")
    status_chip(key)
    show_error(key)
    rows = ss.results.get(key, {}).get("output")
    if rows:
        failed = [r for r in rows if r["STATUS"] != "PASS"]
        (st.error if failed else st.success)(f"{len(rows) - len(failed)} passed · {len(failed)} failed")
        show(rows, ["STATUS", "CHECK_ID", "CATEGORY", "CHECK_NAME", "EXPECTED", "ACTUAL", "DETAIL"])


def test_widget(key, target, actor, scenario):
    if st.button(f"📏 Run DCM TEST ALL (expectations) on {target}", key=f"btn_{key}"):
        run(key, "DCM TEST ALL", lambda: core.dcm_test_all(sql, target), actor=actor, scenario=scenario,
            operation="TEST ALL", target=target, command=core.dcm_test_sql(target))
        res = ss.results.get(key, {}).get("output")
        if res and any(r["STATUS"] != "PASS" for r in core.expectation_rows(res)):
            set_status(key, "FAILED", "expectation violated")
    status_chip(key)
    show_error(key)
    res = ss.results.get(key, {}).get("output")
    if res:
        rows = core.expectation_rows(res)
        failed = [r for r in rows if r["STATUS"] != "PASS"]
        (st.error if failed else st.success)(f"DCM expectations: {len(rows) - len(failed)} passed · {len(failed)} failed")
        show(rows)


def branch_file_widget(key, ref, compare_to="main"):
    try:
        new = core.read_repo_file(sql, ref, core.BUSINESS_VIEW_FILE)
        old = core.read_repo_file(sql, compare_to, core.BUSINESS_VIEW_FILE) if compare_to else ""
        commit = core.branch_commit(sql, ref) if not ref.startswith("commit:") else ref.split(":")[1]
    except Exception as e:
        st.error(str(e))
        return
    st.markdown(f"`{ref}` @ `{str(commit)[:7]}` · `dcm/{core.BUSINESS_VIEW_FILE}`")
    c1, c2 = st.columns(2)
    with c1:
        st.markdown("**SQL definition in this branch**")
        st.code(new, language="sql")
    with c2:
        st.markdown(f"**git diff {compare_to}..{ref}**")
        d = core.unified_diff(old, new, f"{compare_to}", ref)
        st.code(d or "(no difference)", language="diff")


def reset_widget(key, target, label):
    with st.expander(f"↺ Reset {target} to the baseline commit {core.BASELINE_COMMIT[:7]} (0% discount)"):
        st.caption(f"Runs a DCM PLAN + DEPLOY of {core.BASELINE_REF} to {target}. Only demo objects managed by "
                   f"{core.TARGETS[target]['project']} are affected.")
        ok = st.checkbox(f"Confirm reset of {target}", key=f"conf_{key}")
        if st.button("Reset now", key=f"btn_{key}", disabled=not ok):
            def go():
                plan = core.dcm_plan(sql, target, core.BASELINE_REF)
                if core.changeset_summary(plan).get("DROP", 0):
                    raise RuntimeError("Reset aborted: baseline PLAN contains DROP operations.")
                return core.dcm_deploy(sql, target, core.BASELINE_REF, f"reset-{dt.datetime.now().strftime('%H%M%S')}")
            run(key, "Reset", go, actor="Presenter", scenario=label, operation="RESET (PLAN+DEPLOY)", target=target,
                ref=core.BASELINE_REF, command=core.dcm_deploy_sql(target, core.BASELINE_REF))
        status_chip(key)
        show_error(key)


# ------------------------------------------------------------------------ sections
SECTIONS = [
    "1. Current State",
    "2. Git Repository and Branches",
    "3. DCM Project Structure",
    "4. Scenario 1 - Shared Object Deployment",
    "5. Scenario 2 - Developer Object Isolation",
    "6. Data Testing and Validation",
    "7. Deployment Pipeline",
    "8. Execution History and Audit",
]

GUIDE = [
    (0, "The customer today", "Two shared databases, built by hand from a shared SQL worksheet. Show the hierarchy, row counts and the data flow RAW → COMPUTE → BUSINESS_READY. Point out: nobody can tell who changed a view, or what it looked like yesterday."),
    (1, "Code moves to Git", "The same SQL now lives in Git. Show main and the three feature branches - these are real GitHub branches that Snowflake reads through a Git repository object. Show the diff: two developers changed the same view differently."),
    (2, "DCM makes it declarative", "manifest.yml defines targets; Jinja variables set database names per target. DEFINE statements describe the desired end state; DCM computes CREATE/ALTER/DROP. One DCM project object per target - an object can belong to only one project."),
    (3, "Scenario 1 - STEP A/B", "Reset shared DEV first. Developer A checks out feature/developer-A: show the 10% change and run DCM PLAN against SHARED DEV. One ALTER on VW_CUSTOMER_SALES, zero drops."),
    (3, "Scenario 1 - STEP C", "Developer A deploys. Query the shared view: 10% discount, NET 684,182.00."),
    (3, "Scenario 1 - STEP D/E/F", "Developer B checks out feature/developer-B (20%), plans against the SAME project and deploys. Query again: 20%, NET 608,161.71. Developer A's change is gone from Snowflake although it is safe in Git. Git branches isolate CODE, not OBJECTS."),
    (4, "Scenario 2 - isolation", "Each developer gets zero-copy cloned data and their own DCM project + Jinja configuration. Plan and deploy A to DEV_A, B to DEV_B."),
    (4, "Scenario 2 - prove independence", "Compare side by side: DEV_A 10%, DEV_B 20%, shared DEV untouched. Show the view DDL: each sandbox reads only its own databases."),
    (5, "Green pipeline, wrong numbers", "Developer A 'refactors' to SALES_AMOUNT * 1.10. Git commit OK, PLAN OK, DEPLOY OK, DCM TEST ALL 9/9 PASS - yet net sales exceed gross sales."),
    (5, "Independent testing catches it", "Run the business-rule validation: discount checks fail. This is why transformation tests must sit next to DCM, not be replaced by it."),
    (6, "Controlled promotion", "Merge the approved branch to main, PLAN shared DEV, validate, deploy, validate, promote to UAT. PROD is PLAN-only and needs a separate approval."),
    (7, "Audit", "Every PLAN, DEPLOY, validation and Git step is logged with branch, commit, query ID and output - plus DCM's own deployment history per project."),
]

# ------------------------------------------------------------------------- sidebar
with st.sidebar:
    st.title("❄️ DCM DevOps Demo")
    try:
        ctx = sql("SELECT CURRENT_ACCOUNT() ACCOUNT, CURRENT_ORGANIZATION_NAME()||'-'||CURRENT_ACCOUNT_NAME() ACCOUNT_ID, "
                  "CURRENT_USER() USR, CURRENT_ROLE() ROLE, CURRENT_WAREHOUSE() WH, CURRENT_REGION() REGION")[0]
        st.success("Connected to Snowflake")
        st.markdown(f"**Account** `{ctx['ACCOUNT_ID']}` (`{ctx['ACCOUNT']}`)  \n**Region** `{ctx['REGION']}`  \n"
                    f"**User** `{ctx['USR']}`  \n**Role** `{ctx['ROLE']}`  \n**Warehouse** `{ctx['WH']}`")
    except Exception as e:
        st.error(f"Connection problem: {e}")
    st.caption(f"Streamlit {st.__version__}")
    st.divider()
    guided = st.toggle("🎤 Guided demo mode", value=False)
    if guided:
        i = ss.guide_step
        st.progress((i + 1) / len(GUIDE), text=f"Step {i + 1} of {len(GUIDE)}")
        b1, b2 = st.columns(2)
        if b1.button("◀ Back", disabled=i == 0, width="stretch"):
            ss.guide_step -= 1
            st.rerun()
        if b2.button("Next ▶", disabled=i == len(GUIDE) - 1, width="stretch"):
            ss.guide_step += 1
            st.rerun()
        section = SECTIONS[GUIDE[ss.guide_step][0]]
        st.markdown(f"**Now:** {section.replace('.', chr(92) + '.', 1)}")
    else:
        section = st.radio("Sections", SECTIONS, label_visibility="collapsed", format_func=lambda x: x.replace(".", "\\.", 1))
    st.divider()
    developer = st.radio("Developer", ["Developer A", "Developer B"], horizontal=True)
    st.caption("Used by Section 2/3 viewers. Scenarios fix the developer per step.")

if guided:
    _, title, notes = GUIDE[ss.guide_step]
    st.info(f"**Presenter - {title}:** {notes}")

st.title(section)


# =================================================================== 1. CURRENT STATE
def page_current_state():
    st.markdown("The customer's starting point: **ANALYTICS_DB** (RAW, COMPUTE) and **BUSINESS_DB** (BUSINESS_READY), "
                "originally created by hand from a shared SQL worksheet (`setup/01_shared_worksheet_objects.sql`).")
    c1, c2 = st.columns([1, 2])
    with c1:
        st.subheader("Initial setup")
        st.caption("Idempotent: IF NOT EXISTS for containers, INSERT OVERWRITE for deterministic synthetic data, "
                   "CREATE VIEW IF NOT EXISTS so DCM-managed views are never overwritten.")
        if st.button("▶ Execute initial setup (from Git main)"):
            def go():
                text = core.read_git_file(sql, "main", "setup/01_shared_worksheet_objects.sql")
                stmts = [s.strip() for s in "\n".join(l for l in text.splitlines() if not l.strip().startswith("--")).split(";")]
                out = []
                for s in stmts:
                    if not s or s.upper().startswith("USE "):
                        continue
                    r = sql(s)
                    out.append({"STATEMENT": s.split("\n")[0][:90], "RESULT": str(list(r[0].values())[0]) if r else ""})
                return out
            run("setup", "Initial setup", go, actor="Presenter", scenario="Current state", operation="INITIAL SETUP",
                command="setup/01_shared_worksheet_objects.sql")
        status_chip("setup")
        show_error("setup")
        if ss.results.get("setup", {}).get("output"):
            show(ss.results["setup"]["output"])
    with c2:
        st.subheader("Data flow")
        st.graphviz_chart("""
        digraph G { rankdir=LR; node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=10];
          subgraph cluster_a { label="ANALYTICS_DB"; style=dashed;
            subgraph cluster_r { label="RAW"; color="#29B5E8"; RC [label="RAW_CUSTOMERS", fillcolor="#E3F4FB"]; RP [label="RAW_PRODUCTS", fillcolor="#E3F4FB"]; RO [label="RAW_ORDERS", fillcolor="#E3F4FB"]; }
            subgraph cluster_c { label="COMPUTE"; color="#7254A3"; CS [label="CUSTOMER_SALES", fillcolor="#EEE8F7"]; PS [label="PRODUCT_SALES", fillcolor="#EEE8F7"]; DS [label="DAILY_SALES", fillcolor="#EEE8F7"]; } }
          subgraph cluster_b { label="BUSINESS_DB"; style=dashed;
            subgraph cluster_br { label="BUSINESS_READY"; color="#11567F"; V1 [label="VW_CUSTOMER_SALES", fillcolor="#FFF3D6"]; V2 [label="VW_PRODUCT_PERFORMANCE", fillcolor="#FFF3D6"]; V3 [label="VW_DAILY_REVENUE", fillcolor="#FFF3D6"]; } }
          RC->CS; RO->CS; RP->CS; RP->PS; RO->PS; RO->DS; RP->DS; CS->V1; PS->V2; DS->V3; }""")

    st.subheader("Database / schema / object explorer")
    existing = [r["name"] for r in sql("SHOW DATABASES") if r["name"] in core.DEMO_DATABASES + [core.CTRL_DB]]
    db = st.selectbox("Database", existing, index=existing.index("ANALYTICS_DB") if "ANALYTICS_DB" in existing else 0)
    objs = sql(f"SELECT TABLE_SCHEMA AS SCHEMA_NAME, TABLE_NAME AS OBJECT_NAME, TABLE_TYPE AS OBJECT_TYPE, ROW_COUNT, "
               f"COMMENT FROM {db}.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA <> 'INFORMATION_SCHEMA' ORDER BY 1, 2")
    if db != core.CTRL_DB and objs:
        counts = []
        for o in objs:
            fqn = f"{db}.{o['SCHEMA_NAME']}.{o['OBJECT_NAME']}"
            n = sql(f"SELECT COUNT(*) AS N FROM {fqn}")[0]["N"]
            counts.append({**o, "ROW_COUNT": n})
        objs = counts
    show(objs, ["SCHEMA_NAME", "OBJECT_NAME", "OBJECT_TYPE", "ROW_COUNT", "COMMENT"])
    if objs:
        names = [f"{db}.{o['SCHEMA_NAME']}.{o['OBJECT_NAME']}" for o in objs]
        pick = st.selectbox("Object", names)
        o = objs[names.index(pick)]
        t1, t2 = st.tabs(["Sample records", "SQL definition"])
        with t1:
            show(sql(f"SELECT * FROM {pick} LIMIT 15"))
        with t2:
            kind = "VIEW" if o["OBJECT_TYPE"] == "VIEW" else "TABLE"
            st.code(sql(f"SELECT GET_DDL('{kind}', '{pick}') AS D")[0]["D"], language="sql")


# ========================================================================= 2. GIT
def page_git():
    st.markdown(f"GitHub repository **MonicaSivasamy/snowflake-dcm-devops-demo** is mirrored into Snowflake as the Git "
                f"repository object `{core.REPO}`. DCM reads project files directly from a branch or commit path.")
    c1, c2 = st.columns([1, 3])
    with c1:
        if st.button("⟳ ALTER GIT REPOSITORY ... FETCH"):
            run("fetch", "Fetch", lambda: core.git_fetch(sql), actor="Presenter", scenario="Git", operation="GIT FETCH",
                command=f"ALTER GIT REPOSITORY {core.REPO} FETCH")
        status_chip("fetch")
        show_error("fetch")
    with c2:
        show(core.git_branches(sql), ["name", "commit_hash", "path"])

    st.subheader("Commit history (recorded output of the real `git log`)")
    rows = sql(f"SELECT EVENT_TS, OUTPUT:graph::string AS GRAPH FROM {core.AUDIT_TABLE} "
               f"WHERE OPERATION = 'GIT LOG' ORDER BY EVENT_ID DESC LIMIT 1")
    if rows:
        st.caption(f"Captured by the git CLI at {rows[0]['EVENT_TS']} and stored in the audit log "
                   f"(Streamlit in Snowflake cannot run git itself).")
        st.code(rows[0]["GRAPH"], language="text")
    else:
        st.info("Run `python scripts/demo_cli.py record-git` to capture git history.")

    st.subheader("Branch checkout and diff")
    default = "feature/developer-A" if developer == "Developer A" else "feature/developer-B"
    c1, c2 = st.columns(2)
    ref = c1.selectbox("Branch (checkout)", core.BRANCHES, index=core.BRANCHES.index(default))
    base = c2.selectbox("Compare with", core.BRANCHES, index=0)
    branch_file_widget("git_diff", ref, base)
    with st.expander(f"Files in {ref}/dcm"):
        show(core.list_repo_files(sql, ref))

    st.subheader("Pull request review")
    st.caption("Review gates are evaluated from real results in the audit log. The merge itself was performed with git "
               "(`git merge --no-ff`) and pushed to GitHub.")
    main_def = core.read_repo_file(sql, "main", core.BUSINESS_VIEW_FILE)
    for br, tgt in [("feature/developer-A", "DEV_A"), ("feature/developer-B", "DEV_B"), ("feature/developer-A-defect", "DEV_A")]:
        bdef = core.read_repo_file(sql, br, core.BUSINESS_VIEW_FILE)
        ev = sql(f"SELECT OPERATION, STATUS, EVENT_TS FROM {core.AUDIT_TABLE} WHERE GIT_BRANCH = {core.q(br)} "
                 f"AND TARGET = {core.q(tgt)} QUALIFY ROW_NUMBER() OVER (PARTITION BY OPERATION ORDER BY EVENT_ID DESC) = 1")
        by = {e["OPERATION"]: e["STATUS"] for e in ev}
        val = sql(f"SELECT STATUS FROM {core.AUDIT_TABLE} WHERE OPERATION='VALIDATE' AND TARGET={core.q(tgt)} "
                  f"AND EVENT_ID > COALESCE((SELECT MAX(EVENT_ID) FROM {core.AUDIT_TABLE} WHERE OPERATION='DEPLOY' "
                  f"AND TARGET={core.q(tgt)} AND GIT_BRANCH={core.q(br)}), 1e12) ORDER BY EVENT_ID LIMIT 1")
        merged = bdef.strip() == main_def.strip()
        state = "🟣 MERGED into main" if merged else ("⛔ BLOCKED" if (val and val[0]["STATUS"] == "FAILED") else "🟡 OPEN")
        with st.expander(f"{state} · {br} → main"):
            st.markdown(
                f"- Code review (diff below): {'✅' if merged else '⏳'}\n"
                f"- DCM PLAN on {tgt}: {by.get('PLAN', 'not run')}\n"
                f"- DCM DEPLOY on {tgt}: {by.get('DEPLOY', 'not run')}\n"
                f"- Business-rule validation after that deploy: {val[0]['STATUS'] if val else 'not run'}\n"
                f"- DCM TEST ALL on {tgt}: {by.get('TEST ALL', 'not run')}")
            st.code(core.unified_diff(main_def, bdef, "main", br) or "(identical to main)", language="diff")


# =================================================================== 3. DCM PROJECT
def page_dcm():
    st.markdown("A **DCM project** = `manifest.yml` + `sources/definitions/*.sql` with `DEFINE` statements describing the "
                "desired state. `EXECUTE DCM PROJECT ... PLAN` computes the changeset; `DEPLOY` applies it "
                "(create / alter / drop / adopt existing objects).")
    ref = st.selectbox("Git ref", core.BRANCHES, key="dcm_ref")
    c1, c2 = st.columns([1, 2])
    with c1:
        st.markdown("**Project tree**")
        files = core.list_repo_files(sql, ref)
        show(files)
    with c2:
        st.markdown("**manifest.yml**")
        st.code(core.read_repo_file(sql, ref, "manifest.yml"), language="yaml")

    st.subheader("Targets → DCM project objects → Jinja configuration")
    projects = {r["name"]: r for r in sql(f"SHOW DCM PROJECTS IN SCHEMA {core.CTRL_DB}.PROJECTS")}
    show([{"TARGET": k, "DCM_PROJECT": v["project"], "EXISTS": v["project"].split(".")[-1] in projects,
           "CONFIGURATION": v["config"], "{{ analytics_db }}": v["analytics_db"], "{{ business_db }}": v["business_db"]}
          for k, v in core.TARGETS.items()])

    st.subheader("Definition file + rendered for a target")
    files_sql = [f["FILE"] for f in files if f["FILE"].endswith(".sql")]
    f = st.selectbox("Definition file", files_sql, index=files_sql.index(core.BUSINESS_VIEW_FILE) if core.BUSINESS_VIEW_FILE in files_sql else 0)
    tgt = st.selectbox("Render for target", list(core.TARGETS))
    text = core.read_repo_file(sql, ref, f)
    a, b = st.columns(2)
    a.markdown("**Source (Jinja)**")
    a.code(text, language="sql")
    b.markdown(f"**Rendered for {tgt}** (variable substitution preview; DCM's own render is in the PLAN output)")
    b.code(core.render_validation(text, tgt), language="sql")

    st.subheader("Supported checks at each stage")
    show([
        {"STAGE": "Git code review", "CHECKS": "Human review of the diff, intent, naming", "DOES NOT CHECK": "Whether SQL runs or data is correct"},
        {"STAGE": "DCM PLAN", "CHECKS": "Jinja render, SQL compilation, dependencies, type compatibility, exact CREATE/ALTER/DROP changeset", "DOES NOT CHECK": "Business correctness of results"},
        {"STAGE": "DCM DEPLOY", "CHECKS": "Applies the changeset; object ownership tracked per project; deployment history", "DOES NOT CHECK": "Business correctness of results"},
        {"STAGE": "DCM expectations (TEST ALL)", "CHECKS": "Data metric functions you attach: nulls, duplicates, volume, min/max", "DOES NOT CHECK": "Rules you did not encode, e.g. NET = GROSS * (1 - discount)"},
        {"STAGE": "Independent validation", "CHECKS": "Recompute from RAW, reconcile layers, business rules", "DOES NOT CHECK": "-- (owned by data/QA team, runs after deploy)"},
    ])


# ============================================================ 4. SCENARIO 1 (shared)
def page_scenario1():
    S = "Scenario 1 - shared target"
    st.markdown("Both developers deploy **different branches** to the **same DCM project** `DCM_SHARED_DEV`, i.e. the "
                "same objects in `BUSINESS_DB`. Git isolates the code; Snowflake has one object.")
    reset_widget("s1_reset", "SHARED_DEV", S)
    st.markdown("**Before:** current state of the shared view")
    query_widget("s1_before", "SHARED_DEV", "Presenter", S, "s1", "Before")

    st.header("Developer A")
    with st.container(border=True):
        st.subheader("STEP A - checkout feature/developer-A")
        branch_file_widget("s1_a", "feature/developer-A")
    with st.container(border=True):
        st.subheader("STEP B - DCM PLAN → shared DEV")
        plan_widget("s1_plan_a", "SHARED_DEV", "feature/developer-A", "Developer A", S)
    with st.container(border=True):
        st.subheader("STEP C - DCM DEPLOY → shared DEV, then query")
        deploy_widget("s1_deploy_a", "SHARED_DEV", "feature/developer-A", "Developer A", S, "devA")
        query_widget("s1_q_a", "SHARED_DEV", "Developer A", S, "s1", "After Developer A deploy")

    st.header("Developer B")
    with st.container(border=True):
        st.subheader("STEP D - checkout feature/developer-B")
        branch_file_widget("s1_b", "feature/developer-B")
    with st.container(border=True):
        st.subheader("STEP E - DCM PLAN → the SAME shared DEV")
        plan_widget("s1_plan_b", "SHARED_DEV", "feature/developer-B", "Developer B", S)
    with st.container(border=True):
        st.subheader("STEP F - DCM DEPLOY → the SAME shared DEV, then query")
        deploy_widget("s1_deploy_b", "SHARED_DEV", "feature/developer-B", "Developer B", S, "devB")
        query_widget("s1_q_b", "SHARED_DEV", "Developer B", S, "s1", "After Developer B deploy")

    st.header("Before / after comparison")
    snaps = ss.snapshots.get("s1", [])
    if snaps:
        show([{"MOMENT": l, "OBJECT": f"{core.TARGETS[t]['business_db']}.BUSINESS_READY.VW_CUSTOMER_SALES",
               "DISCOUNT_PCT": f"{float(x.get('DISCOUNT_PCT') or 0):.0%}", "SALES_AMOUNT": x.get("SALES_AMOUNT"),
               "NET_SALES": x.get("NET_SALES")} for l, t, x in snaps])
        if len(snaps) >= 3:
            st.error("Same object, last writer wins: Developer A's 10% definition was replaced by Developer B's 20% "
                     "in Snowflake, although both branches still exist independently in Git.")
    else:
        st.caption("Query the view before and after each deploy to build the comparison.")
    st.subheader(f"DCM deployment history of {core.TARGETS['SHARED_DEV']['project']}")
    show(core.dcm_deployments(sql, "SHARED_DEV"), ["name", "alias", "created_on", "source_file_path", "git_commit_hash"])


# ========================================================= 5. SCENARIO 2 (isolated)
def page_scenario2():
    S = "Scenario 2 - developer isolation"
    st.markdown("Each developer gets **their own databases** (zero-copy clone of the shared data) and **their own DCM "
                "project object**, using the same definitions with a different Jinja configuration.")
    with st.container(border=True):
        st.subheader("Provision developer sandboxes")
        st.code("\n".join(core.provision_clone_sql("DEV_A") + core.provision_clone_sql("DEV_B")) +
                f"\nCREATE DCM PROJECT IF NOT EXISTS {core.TARGETS['DEV_A']['project']};"
                f"\nCREATE DCM PROJECT IF NOT EXISTS {core.TARGETS['DEV_B']['project']};", language="sql")
        if st.button("▶ Provision (idempotent - never replaces existing databases)"):
            def go():
                out = []
                for t in ("DEV_A", "DEV_B"):
                    for s_ in core.provision_clone_sql(t):
                        out += sql(s_)
                    out += core.dcm_create_project(sql, t)
                return out
            run("s2_prov", "Provision", go, actor="Platform team", scenario=S, operation="PROVISION",
                command="zero-copy clone + CREATE DCM PROJECT")
        status_chip("s2_prov")
        show_error("s2_prov")
        c1, c2 = st.columns(2)
        reset_widget_target = c1.selectbox("Reset sandbox", ["DEV_A", "DEV_B"], key="s2_reset_t")
        with c2:
            reset_widget(f"s2_reset_{reset_widget_target}", reset_widget_target, S)

    colA, colB = st.columns(2)
    for col, dev, tgt, ref, prefix in [(colA, "Developer A", "DEV_A", "feature/developer-A", "devA"),
                                       (colB, "Developer B", "DEV_B", "feature/developer-B", "devB")]:
        with col:
            st.header(dev)
            st.caption(f"Target `{tgt}` → `{core.TARGETS[tgt]['analytics_db']}`, `{core.TARGETS[tgt]['business_db']}`")
            with st.container(border=True):
                st.markdown(f"**1. Checkout `{ref}` and change the calculation**")
                try:
                    new = core.read_repo_file(sql, ref, core.BUSINESS_VIEW_FILE)
                    old = core.read_git_file(sql, core.BASELINE_REF, "dcm/" + core.BUSINESS_VIEW_FILE)
                    st.code(core.unified_diff(old, new, "baseline", ref), language="diff")
                except Exception as e:
                    st.error(str(e))
            with st.container(border=True):
                st.markdown(f"**2. DCM PLAN → {tgt}**")
                plan_widget(f"s2_plan_{tgt}", tgt, ref, dev, S)
            with st.container(border=True):
                st.markdown(f"**3. DCM DEPLOY → {tgt}**")
                deploy_widget(f"s2_deploy_{tgt}", tgt, ref, dev, S, prefix)
            with st.container(border=True):
                st.markdown("**4. Validate with own sample data**")
                query_widget(f"s2_q_{tgt}", tgt, dev, S)
                validation_widget(f"s2_v_{tgt}", tgt, dev, S)

    st.header("Object isolation comparison (live)")
    if st.button("🔎 Compare all three environments now"):
        def go():
            out = []
            for t in ("SHARED_DEV", "DEV_A", "DEV_B"):
                tt = core.TARGETS[t]
                fqn = f"{tt['business_db']}.BUSINESS_READY.VW_CUSTOMER_SALES"
                if not core.database_exists(sql, tt["business_db"]):
                    out.append({"ENVIRONMENT": tt["label"], "OBJECT": fqn, "STATE": "not deployed"})
                    continue
                tot = core.customer_view_totals(sql, t)
                ddl = core.view_ddl(sql, fqn)
                froms = re.findall(r"\bfrom\s+([A-Za-z0-9_$.]+)", ddl, flags=re.IGNORECASE)
                src = froms[-1] if froms else ""
                cs = core.view_ddl(sql, f"{tt['analytics_db']}.COMPUTE.CUSTOMER_SALES")
                raw = [w for w in re.findall(r"\bfrom\s+([A-Za-z0-9_$.]+)", cs, flags=re.IGNORECASE)]
                out.append({"ENVIRONMENT": tt["label"], "OBJECT": fqn,
                            "DISCOUNT_PCT": f"{float(tot.get('DISCOUNT_PCT') or 0):.0%}", "NET_SALES": tot.get("NET_SALES"),
                            "VIEW_READS_FROM": src, "COMPUTE_READS_RAW_FROM": raw[0] if raw else "",
                            "DCM_PROJECT": core.TARGETS[t]["project"]})
            return out
        run("s2_cmp", "Compare", go, actor="Presenter", scenario=S, operation="ISOLATION COMPARE", command="compare views")
    status_chip("s2_cmp")
    show_error("s2_cmp")
    rows = ss.results.get("s2_cmp", {}).get("output")
    if rows:
        show(rows)
        st.success("Three objects, three states: each developer changed only their own sandbox; shared DEV is untouched.")


# ============================================================= 6. DATA TESTING
def page_testing():
    S = "Phase 5 - data testing limitation"
    st.markdown("A **syntactically valid** but **wrong** change: `NET_SALES = SALES_AMOUNT * 1.10` instead of `* 0.90`.")
    st.header("Deliberate defect on Developer A's sandbox")
    with st.container(border=True):
        st.subheader("A. Git commit succeeds")
        branch_file_widget("t_git", "feature/developer-A-defect", "feature/developer-A")
        st.success("The commit exists on GitHub - Git accepts any text.")
    with st.container(border=True):
        st.subheader("B. DCM PLAN succeeds")
        plan_widget("t_plan", "DEV_A", "feature/developer-A-defect", "Developer A", S)
    with st.container(border=True):
        st.subheader("C. DCM DEPLOY succeeds")
        deploy_widget("t_deploy", "DEV_A", "feature/developer-A-defect", "Developer A", S, "devA-defect")
    with st.container(border=True):
        st.subheader("D. The query returns wrong business values")
        query_widget("t_query", "DEV_A", "Developer A", S)
        out = ss.results.get("t_query", {}).get("output")
        if out and float(out["totals"].get("NET_SALES") or 0) > float(out["totals"].get("SALES_AMOUNT") or 0):
            st.error("NET_SALES is higher than gross SALES_AMOUNT - a 'discount' increased revenue.")
    with st.container(border=True):
        st.subheader("DCM TEST ALL - generic data quality expectations")
        test_widget("t_test", "DEV_A", "Developer A", S)
        st.caption("Null, duplicate, volume and non-negative expectations all hold, so the defect is invisible to them.")
    with st.container(border=True):
        st.subheader("E. Independent business-rule validation detects the issue")
        validation_widget("t_val", "DEV_A", "QA", S)
    with st.expander("Validation SQL (validation/business_rules.sql on main)"):
        st.code(core.read_validation_template(sql, "main"), language="sql")

    st.header("Which gate catches what")
    show([
        {"GATE": "Git commit / code review", "RESULT FOR THE * 1.10 DEFECT": "✅ passes (unless a reviewer spots it)", "PURPOSE": "Version control, peer review"},
        {"GATE": "DCM PLAN", "RESULT FOR THE * 1.10 DEFECT": "✅ passes - valid SQL, 1 ALTER", "PURPOSE": "Compile + compute changeset (it did block the NUMBER scale change)"},
        {"GATE": "DCM DEPLOY", "RESULT FOR THE * 1.10 DEFECT": "✅ succeeds", "PURPOSE": "Apply desired state, record deployment"},
        {"GATE": "DCM expectations (TEST ALL)", "RESULT FOR THE * 1.10 DEFECT": "✅ 9/9 pass", "PURPOSE": "Generic data quality via data metric functions"},
        {"GATE": "Independent business-rule tests", "RESULT FOR THE * 1.10 DEFECT": "❌ discount checks FAIL", "PURPOSE": "Transformation correctness vs. business rules"},
    ])
    reset_widget("t_restore", "DEV_A", S)

    st.header("Run checks on any environment")
    tgt = st.selectbox("Target", [t for t in core.TARGETS if t != "PROD"], key="t_any")
    c1, c2 = st.columns(2)
    with c1:
        test_widget(f"t_any_test_{tgt}", tgt, "Presenter", "Ad-hoc testing")
    with c2:
        validation_widget(f"t_any_val_{tgt}", tgt, "Presenter", "Ad-hoc testing")


# ===================================================================== 7. PIPELINE
def page_pipeline():
    S = "Phase 6 - controlled promotion"
    stages = ["Feature branch", "Pull request", "Main branch", "DCM PLAN (shared DEV)",
              "Validation (shared DEV)", "DCM DEPLOY → UAT", "UAT validated", "PROD (plan only)"]
    ev = {}
    for op, tgt in [("PLAN", "SHARED_DEV"), ("DEPLOY", "SHARED_DEV"), ("VALIDATE", "SHARED_DEV"), ("DEPLOY", "UAT"),
                    ("VALIDATE", "UAT"), ("PLAN", "PROD")]:
        r = sql(f"SELECT STATUS, EVENT_TS FROM {core.AUDIT_TABLE} WHERE OPERATION={core.q(op)} AND TARGET={core.q(tgt)} "
                f"AND (GIT_BRANCH = 'main' OR OPERATION='VALIDATE') ORDER BY EVENT_ID DESC LIMIT 1")
        ev[(op, tgt)] = r[0]["STATUS"] if r else None
    merged = core.read_repo_file(sql, "main", core.BUSINESS_VIEW_FILE).strip() == \
        core.read_repo_file(sql, "feature/developer-A", core.BUSINESS_VIEW_FILE).strip()
    marks = [True, merged, merged, ev[("PLAN", "SHARED_DEV")], ev[("VALIDATE", "SHARED_DEV")], ev[("DEPLOY", "UAT")],
             ev[("VALIDATE", "UAT")], "PLAN ONLY" if ev[("PLAN", "PROD")] else None]
    cols = st.columns(len(stages))
    for c, name, m in zip(cols, stages, marks):
        icon = "🟢" if m in (True, "SUCCESS") else ("🔴" if m == "FAILED" else ("🟡" if m == "PLAN ONLY" else "⚪"))
        c.markdown(f"<div style='text-align:center;border:1px solid #ddd;border-radius:8px;padding:8px'>{icon}<br>"
                   f"<b>{name}</b></div>", unsafe_allow_html=True)
    st.caption("Status of each stage from the latest audit-log events (main branch).")

    with st.container(border=True):
        st.subheader("1-3. Feature branch → pull request → main")
        branch_file_widget("p_merge", "main", "feature/developer-B")
        st.caption("Shown: main (after merging feature/developer-A) compared with the rejected feature/developer-B.")
    with st.container(border=True):
        st.subheader("4. Full DCM PLAN of main against the shared integration DEV target")
        plan_widget("p_plan_dev", "SHARED_DEV", "main", "Release manager", S)
    with st.container(border=True):
        st.subheader("5-6. DEPLOY to shared DEV, then business-rule validation")
        deploy_widget("p_deploy_dev", "SHARED_DEV", "main", "Release manager", S, "main")
        validation_widget("p_val_dev", "SHARED_DEV", "Release manager", S)
    with st.container(border=True):
        st.subheader("7. Promote to UAT (only after successful validation)")
        val_ok = ss.status.get("p_val_dev", {}).get("state") == "SUCCESS" or ev[("VALIDATE", "SHARED_DEV")] == "SUCCESS"
        if not val_ok:
            st.warning("Gate closed: shared DEV validation has not passed.")
        else:
            st.success("Gate open: latest shared DEV validation passed.")
            if not core.project_exists(sql, "UAT"):
                if st.button("Provision UAT (clone data + create DCM_UAT)"):
                    def go():
                        return [*[sql(s_) for s_ in core.provision_clone_sql("UAT")], core.dcm_create_project(sql, "UAT")]
                    run("p_uat_prov", "Provision UAT", go, actor="Release manager", scenario=S, operation="PROVISION", target="UAT")
                status_chip("p_uat_prov")
            plan_widget("p_plan_uat", "UAT", "main", "Release manager", S)
            deploy_widget("p_deploy_uat", "UAT", "main", "Release manager", S, "uat-main")
            validation_widget("p_val_uat", "UAT", "Release manager", S)
            test_widget("p_test_uat", "UAT", "Release manager", S)
    with st.container(border=True):
        st.subheader("8. PROD - PLAN only")
        st.info("PROD is never deployed by this demo. A PROD deploy needs a separate change approval and a release "
                "pipeline identity. The PLAN shows exactly what would be created.")
        if st.button("Create DCM_PROD project object (no objects deployed)"):
            run("p_prod_create", "Create", lambda: core.dcm_create_project(sql, "PROD"), actor="Release manager",
                scenario=S, operation="CREATE DCM PROJECT", target="PROD")
        plan_widget("p_plan_prod", "PROD", "main", "Release manager", S)
        st.button("🚫 DCM DEPLOY to PROD (disabled in this demo)", disabled=True)


# ======================================================================= 8. AUDIT
def page_audit():
    st.subheader("Execution log")
    rows = core.audit_history(sql, 500)
    frame = df(rows)
    if not frame.empty:
        c1, c2, c3 = st.columns(3)
        ops = c1.multiselect("Operation", sorted(frame["OPERATION"].dropna().unique()))
        tg = c2.multiselect("Target", sorted(frame["TARGET"].dropna().unique()))
        stt = c3.multiselect("Status", sorted(frame["STATUS"].dropna().unique()))
        if ops:
            frame = frame[frame["OPERATION"].isin(ops)]
        if tg:
            frame = frame[frame["TARGET"].isin(tg)]
        if stt:
            frame = frame[frame["STATUS"].isin(stt)]
        st.dataframe(frame, width="stretch", hide_index=True, height=420)
        eid = st.number_input("Show full output of EVENT_ID", min_value=0, value=0, step=1)
        if eid:
            r = sql(f"SELECT COMMAND_TEXT, OUTPUT, ERROR_TEXT FROM {core.AUDIT_TABLE} WHERE EVENT_ID = {int(eid)}")
            if r:
                st.code(r[0]["COMMAND_TEXT"] or "", language="sql")
                if r[0]["ERROR_TEXT"]:
                    st.error(r[0]["ERROR_TEXT"])
                if r[0]["OUTPUT"]:
                    st.json(json.loads(r[0]["OUTPUT"]))
    st.subheader("DCM deployment history (from Snowflake)")
    for t in core.TARGETS:
        if core.project_exists(sql, t):
            with st.expander(f"{core.TARGETS[t]['project']}"):
                show(core.dcm_deployments(sql, t), ["name", "alias", "created_on", "source_file_path"])

    st.subheader("Cleanup (demo objects only)")
    st.markdown("Drops only the demo databases listed below, and only if they exist, are owned by `DCM_DEMO_ADMIN` and "
                "carry a `DCM_DEMO` comment. The control database, app and audit log are kept "
                "(see `cleanup/cleanup.sql` for full removal).")
    owned = [r for r in sql("SHOW DATABASES") if r["name"] in core.DEMO_DATABASES and r["owner"] == "DCM_DEMO_ADMIN"
             and str(r.get("comment") or "").startswith("DCM_DEMO")]
    show([{"DATABASE": r["name"], "OWNER": r["owner"], "COMMENT": r["comment"]} for r in owned])
    confirm = st.text_input("Type DELETE DEMO OBJECTS to enable cleanup")
    if st.button("🗑 Remove demo databases", disabled=confirm != "DELETE DEMO OBJECTS"):
        def go():
            out = []
            for r in owned:
                out += sql(f"DROP DATABASE IF EXISTS {r['name']}")
            return out
        run("cleanup", "Cleanup", go, actor="Presenter", scenario="Cleanup", operation="CLEANUP",
            command="DROP DATABASE " + ", ".join(r["name"] for r in owned))
    status_chip("cleanup")
    show_error("cleanup")


PAGES = [page_current_state, page_git, page_dcm, page_scenario1, page_scenario2, page_testing, page_pipeline, page_audit]
try:
    PAGES[SECTIONS.index(section)]()
except Exception as e:  # show real Snowflake errors instead of a blank page
    st.error(f"{type(e).__name__}: {e}")
