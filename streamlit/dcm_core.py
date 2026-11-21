"""
dcm_core - the single engine behind the demo.

Used by BOTH:
  * streamlit_app.py  (Streamlit in Snowflake, Snowpark session)
  * scripts/demo_cli.py (local runner, Snowflake Python connector)

Every function receives `sql`, a callable that executes one SQL statement and
returns a list of dicts. Nothing here simulates Snowflake: all results come
from the account.
"""
from __future__ import annotations

import difflib
import json
from typing import Callable, Dict, List, Optional

Sql = Callable[[str], List[dict]]

CTRL_DB = "DCM_DEMO_CTRL_DB"
REPO = f"{CTRL_DB}.GIT.DCM_DEMO_REPO"
AUDIT_TABLE = f"{CTRL_DB}.AUDIT.EXECUTION_LOG"
WHOLE_FILE_FMT = f"{CTRL_DB}.GIT.WHOLE_FILE"
PROJECT_DIR = "dcm"  # folder in the Git repo that holds manifest.yml

# target -> DCM project object, templating configuration, databases
TARGETS: Dict[str, Dict[str, str]] = {
    "SHARED_DEV": {"project": f"{CTRL_DB}.PROJECTS.DCM_SHARED_DEV", "config": "SHARED_DEV",
                   "analytics_db": "ANALYTICS_DB", "business_db": "BUSINESS_DB", "label": "Shared DEV"},
    "DEV_A": {"project": f"{CTRL_DB}.PROJECTS.DCM_DEV_A", "config": "DEV_A",
              "analytics_db": "DEV_A_ANALYTICS_DB", "business_db": "DEV_A_BUSINESS_DB", "label": "Developer A sandbox"},
    "DEV_B": {"project": f"{CTRL_DB}.PROJECTS.DCM_DEV_B", "config": "DEV_B",
              "analytics_db": "DEV_B_ANALYTICS_DB", "business_db": "DEV_B_BUSINESS_DB", "label": "Developer B sandbox"},
    "UAT": {"project": f"{CTRL_DB}.PROJECTS.DCM_UAT", "config": "UAT",
            "analytics_db": "UAT_ANALYTICS_DB", "business_db": "UAT_BUSINESS_DB", "label": "UAT"},
    "PROD": {"project": f"{CTRL_DB}.PROJECTS.DCM_PROD", "config": "PROD",
             "analytics_db": "PROD_ANALYTICS_DB", "business_db": "PROD_BUSINESS_DB", "label": "PROD (plan only)"},
}

# Immutable baseline used by "reset" buttons: main after the DCM migration
# (0% discount, pinned column types). Referenced by commit, so it never moves.
BASELINE_COMMIT = "112399658d741dbeb2d6b2c4ca2714bfaccc773c"
BASELINE_REF = "commit:" + BASELINE_COMMIT

BRANCHES = ["main", "feature/developer-A", "feature/developer-B", "feature/developer-A-defect"]
BUSINESS_VIEW_FILE = "sources/definitions/03_business_ready/vw_customer_sales.sql"

# Databases this prototype may create. Cleanup never touches anything else.
DEMO_DATABASES = [
    "ANALYTICS_DB", "BUSINESS_DB",
    "DEV_A_ANALYTICS_DB", "DEV_A_BUSINESS_DB", "DEV_B_ANALYTICS_DB", "DEV_B_BUSINESS_DB",
    "UAT_ANALYTICS_DB", "UAT_BUSINESS_DB", "PROD_ANALYTICS_DB", "PROD_BUSINESS_DB",
]


# --------------------------------------------------------------------------- helpers
def q(value: Optional[str]) -> str:
    """SQL string literal."""
    if value is None:
        return "NULL"
    return "'" + str(value).replace("\\", "\\\\").replace("'", "''") + "'"


def ref_root(ref: str) -> str:
    """Stage path of a Git ref in the repository object.
    ref = branch name (e.g. 'feature/developer-A') or 'commit:<sha>'."""
    if ref.startswith("commit:"):
        return f"@{REPO}/commits/{ref.split(':', 1)[1]}"
    return f'@{REPO}/branches/"{ref}"'


def ref_label(ref: str) -> str:
    return f"commit {ref.split(':', 1)[1][:7]} (baseline)" if ref.startswith("commit:") else ref


def branch_path(ref: str) -> str:
    """Stage path of the DCM project folder (manifest.yml) inside a Git ref."""
    return f"{ref_root(ref)}/{PROJECT_DIR}"


def read_git_file(sql: Sql, ref: str, repo_path: str) -> str:
    """Read a whole text file (path relative to repo root) from a Git ref."""
    rows = sql(f"SELECT $1 AS CONTENT FROM {ref_root(ref)}/{repo_path} (FILE_FORMAT => '{WHOLE_FILE_FMT}')")
    return rows[0]["CONTENT"] if rows else ""


# ------------------------------------------------------------------------------ Git
def git_fetch(sql: Sql) -> List[dict]:
    return sql(f"ALTER GIT REPOSITORY {REPO} FETCH")


def git_branches(sql: Sql) -> List[dict]:
    return sql(f"SHOW GIT BRANCHES IN {REPO}")


def branch_commit(sql: Sql, branch: str) -> Optional[str]:
    for row in git_branches(sql):
        if row.get("name") == branch:
            return row.get("commit_hash")
    return None


def read_repo_file(sql: Sql, ref: str, relative_path: str) -> str:
    """Read a whole text file from the DCM project folder of a Git ref."""
    return read_git_file(sql, ref, f"{PROJECT_DIR}/{relative_path}")


def list_repo_files(sql: Sql, ref: str) -> List[dict]:
    rows = sql(f"LS {branch_path(ref)}")
    out = []
    for r in rows:
        name = r.get("name", "")
        idx = name.find(f"/{PROJECT_DIR}/")
        out.append({"FILE": name[idx + len(PROJECT_DIR) + 2:] if idx >= 0 else name, "BYTES": r.get("size")})
    return out


def unified_diff(old: str, new: str, old_name: str, new_name: str) -> str:
    return "".join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                                        fromfile=old_name, tofile=new_name))


# ------------------------------------------------------------------------------ DCM
def _parse_result(rows: List[dict]) -> dict:
    if not rows:
        return {}
    first = rows[0]
    raw = first.get("result") or first.get("RESULT") or next(iter(first.values()))
    try:
        return json.loads(raw) if isinstance(raw, str) else raw
    except (TypeError, ValueError):
        return {"raw": raw}


def dcm_create_project(sql: Sql, target: str) -> List[dict]:
    return sql(f"CREATE DCM PROJECT IF NOT EXISTS {TARGETS[target]['project']} COMMENT = 'DCM_DEMO'")


def dcm_plan_sql(target: str, branch: str) -> str:
    t = TARGETS[target]
    return (f"EXECUTE DCM PROJECT {t['project']} PLAN "
            f"USING CONFIGURATION {t['config']} FROM '{branch_path(branch)}'")


def dcm_deploy_sql(target: str, branch: str, alias: Optional[str] = None) -> str:
    t = TARGETS[target]
    alias_sql = f' AS "{alias}"' if alias else ""
    return (f"EXECUTE DCM PROJECT {t['project']} DEPLOY{alias_sql} "
            f"USING CONFIGURATION {t['config']} FROM '{branch_path(branch)}'")


def dcm_test_sql(target: str) -> str:
    return f"EXECUTE DCM PROJECT {TARGETS[target]['project']} TEST ALL"


def dcm_plan(sql: Sql, target: str, branch: str) -> dict:
    return _parse_result(sql(dcm_plan_sql(target, branch)))


def dcm_deploy(sql: Sql, target: str, branch: str, alias: Optional[str] = None) -> dict:
    return _parse_result(sql(dcm_deploy_sql(target, branch, alias)))


def dcm_test_all(sql: Sql, target: str) -> dict:
    return _parse_result(sql(dcm_test_sql(target)))


def dcm_deployments(sql: Sql, target: str) -> List[dict]:
    return sql(f"SHOW DEPLOYMENTS IN DCM PROJECT {TARGETS[target]['project']}")


def project_exists(sql: Sql, target: str) -> bool:
    name = TARGETS[target]["project"].split(".")[-1]
    rows = sql(f"SHOW DCM PROJECTS LIKE '{name}' IN SCHEMA {CTRL_DB}.PROJECTS")
    return len(rows) > 0


def _short_value(v) -> str:
    s = v if isinstance(v, str) else json.dumps(v)
    s = " ".join(str(s).split())
    return s if len(s) <= 140 else s[:137] + "..."


def _flatten_changes(changes, depth=0) -> List[str]:
    lines = []
    for c in changes or []:
        kind = c.get("kind", "")
        attr = c.get("attribute_name") or c.get("name") or ""
        val = c.get("value")
        line = f"{'  ' * depth}{kind} {attr}".strip()
        if val is not None and not isinstance(val, (list, dict)):
            line += f": {_short_value(val)}"
        lines.append(line)
        for key in ("changes", "items", "children"):
            if isinstance(c.get(key), list):
                lines.extend(_flatten_changes(c[key], depth + 1))
        if isinstance(val, list):
            lines.extend(_flatten_changes(val, depth + 1))
    return lines


def changeset_rows(result: dict) -> List[dict]:
    """Flatten a PLAN/DEPLOY changeset into display rows."""
    rows = []
    for entry in result.get("changeset", []) or []:
        oid = entry.get("object_id", {})
        changes = _flatten_changes(entry.get("changes"))
        meaningful = [c for c in changes if not c.startswith("set project")]
        rows.append({
            "ACTION": entry.get("type"),
            "OBJECT_TYPE": oid.get("domain"),
            "OBJECT": (oid.get("fqn") or oid.get("name") or "").replace('"', ""),
            "CHANGES": "\n".join(changes),
            "ONLY_ADOPTION": not meaningful,
        })
    return rows


def changeset_summary(result: dict) -> Dict[str, int]:
    counts = {"CREATE": 0, "ALTER": 0, "DROP": 0}
    for entry in result.get("changeset", []) or []:
        counts[entry.get("type", "?")] = counts.get(entry.get("type", "?"), 0) + 1
    return counts


def view_definition_change(result: dict, view_fqn_suffix: str = "VW_CUSTOMER_SALES") -> Optional[str]:
    for entry in result.get("changeset", []) or []:
        fqn = (entry.get("object_id", {}).get("fqn") or "").replace('"', "")
        if fqn.endswith(view_fqn_suffix):
            for c in entry.get("changes", []) or []:
                if c.get("attribute_name") == "select_query":
                    return c.get("value")
    return None


def expectation_rows(result: dict) -> List[dict]:
    rows = []
    for e in result.get("expectations", []) or []:
        violated = e.get("expectation_violated")
        rows.append({
            "STATUS": "FAIL" if violated is True else ("PASS" if violated is False else "UNKNOWN"),
            "OBJECT": str(e.get("table_name", "")).replace('"', ""),
            "EXPECTATION": e.get("expectation_name"),
            "METRIC": e.get("metric_name"),
            "RULE": e.get("expectation_expression"),
            "ACTUAL_VALUE": e.get("value"),
        })
    return rows


# ------------------------------------------------------------------------ validation
VALIDATION_SQL_PATH = "validation/business_rules.sql"


def render_validation(template: str, target: str) -> str:
    t = TARGETS[target]
    return (template.replace("{{ analytics_db }}", t["analytics_db"])
                    .replace("{{ business_db }}", t["business_db"]))


def read_validation_template(sql: Sql, ref: str = "main") -> str:
    return read_git_file(sql, ref, VALIDATION_SQL_PATH)


def strip_sql_comments(text: str) -> str:
    return "\n".join(l for l in text.splitlines() if not l.strip().startswith("--")).strip().rstrip(";")


def run_validation(sql: Sql, template: str, target: str) -> List[dict]:
    return sql(strip_sql_comments(render_validation(template, target)))


# --------------------------------------------------------------------------- queries
def customer_view_sample(sql: Sql, target: str, limit: int = 8) -> List[dict]:
    db = TARGETS[target]["business_db"]
    return sql(f"SELECT CUSTOMER_ID, CUSTOMER_NAME, SALES_AMOUNT, DISCOUNT_PCT, NET_SALES "
               f"FROM {db}.BUSINESS_READY.VW_CUSTOMER_SALES ORDER BY CUSTOMER_ID LIMIT {limit}")


def customer_view_totals(sql: Sql, target: str) -> dict:
    db = TARGETS[target]["business_db"]
    rows = sql(f"SELECT COUNT(*) AS CUSTOMERS, SUM(SALES_AMOUNT) AS SALES_AMOUNT, "
               f"MAX(DISCOUNT_PCT) AS DISCOUNT_PCT, SUM(NET_SALES) AS NET_SALES "
               f"FROM {db}.BUSINESS_READY.VW_CUSTOMER_SALES")
    return rows[0] if rows else {}


def view_ddl(sql: Sql, fqn: str) -> str:
    rows = sql(f"SELECT GET_DDL('VIEW', {q(fqn)}) AS DDL")
    return rows[0]["DDL"] if rows else ""


def database_exists(sql: Sql, name: str) -> bool:
    return len(sql(f"SHOW DATABASES LIKE '{name}'")) > 0


# -------------------------------------------------------------- provisioning (clones)
def provision_clone_sql(target: str) -> List[str]:
    """Zero-copy clone the shared RAW data into a target's analytics database.
    Only creates; never replaces an existing database."""
    db = TARGETS[target]["analytics_db"]
    return [f"CREATE DATABASE IF NOT EXISTS {db} CLONE ANALYTICS_DB "
            f"COMMENT = 'DCM_DEMO: zero-copy clone of ANALYTICS_DB for {TARGETS[target]['label']}'"]


# ------------------------------------------------------------------------------ audit
def log_event(sql: Sql, *, source: str, actor: str, scenario: str, operation: str,
              target: str = "", branch: str = "", commit: str = "", status: str = "SUCCESS",
              command: str = "", output=None, error: str = "", query_id: str = "") -> None:
    out_json = json.dumps(output, default=str) if output is not None else None
    sql(f"INSERT INTO {AUDIT_TABLE} (SOURCE, ACTOR, SCENARIO, OPERATION, TARGET, GIT_BRANCH, GIT_COMMIT, "
        f"STATUS, COMMAND_TEXT, OUTPUT, ERROR_TEXT, QUERY_ID) "
        f"SELECT {q(source)}, {q(actor)}, {q(scenario)}, {q(operation)}, {q(target)}, {q(branch)}, {q(commit)}, "
        f"{q(status)}, {q(command)}, {('PARSE_JSON(' + q(out_json) + ')') if out_json else 'NULL'}, "
        f"{q(error[:4000] if error else '')}, {q(query_id)}")


def audit_history(sql: Sql, limit: int = 200) -> List[dict]:
    return sql(f"SELECT EVENT_ID, EVENT_TS, SOURCE, ACTOR, SCENARIO, OPERATION, TARGET, GIT_BRANCH, "
               f"LEFT(GIT_COMMIT, 7) AS COMMIT, STATUS, COMMAND_TEXT, ERROR_TEXT, QUERY_ID "
               f"FROM {AUDIT_TABLE} ORDER BY EVENT_ID DESC LIMIT {limit}")
