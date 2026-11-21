#!/usr/bin/env python3
"""
demo_cli.py - run the DCM demo steps from a terminal (same engine as the app).

Connection: reads SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD (a
programmatic access token or password) from the environment. Never hardcode
credentials. Role DCM_DEMO_ADMIN, warehouse DCM_DEMO_WH.

Examples
  python scripts/demo_cli.py plan   SHARED_DEV feature/developer-A --actor "Developer A" --scenario "Scenario 1"
  python scripts/demo_cli.py deploy SHARED_DEV feature/developer-A --actor "Developer A" --scenario "Scenario 1"
  python scripts/demo_cli.py query  SHARED_DEV
  python scripts/demo_cli.py validate DEV_A
  python scripts/demo_cli.py test   DEV_A
  python scripts/demo_cli.py record-git           # store real `git log` / branch output in the audit log
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "streamlit"))
import dcm_core as core  # noqa: E402

import snowflake.connector  # noqa: E402


def connect():
    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ.get("SNOWFLAKE_ROLE", "DCM_DEMO_ADMIN"),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "DCM_DEMO_WH"),
        session_parameters={"QUERY_TAG": "DCM_DEMO"},
    )
    return conn


class Runner:
    def __init__(self, conn):
        self.conn = conn
        self.last_qid = ""

    def __call__(self, statement: str):
        cur = self.conn.cursor(snowflake.connector.DictCursor)
        try:
            cur.execute(statement)
            self.last_qid = cur.sfqid
            try:
                return cur.fetchall()
            except snowflake.connector.errors.ProgrammingError:
                return []
        finally:
            cur.close()


def table(rows, cols=None, width=60):
    if not rows:
        print("(no rows)")
        return
    cols = cols or list(rows[0].keys())
    fmt = lambda v: (str(v) if v is not None else "")[:width]
    w = {c: max(len(c), *(len(fmt(r.get(c))) for r in rows)) for c in cols}
    print(" | ".join(c.ljust(w[c]) for c in cols))
    print("-+-".join("-" * w[c] for c in cols))
    for r in rows:
        print(" | ".join(fmt(r.get(c)).ljust(w[c]) for c in cols))


def git(*args) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["create", "plan", "deploy", "test", "validate", "query",
                                        "provision", "deployments", "fetch", "record-git"])
    ap.add_argument("target", nargs="?", default="SHARED_DEV")
    ap.add_argument("branch", nargs="?", default="main")
    ap.add_argument("--actor", default="Demo presenter")
    ap.add_argument("--scenario", default="")
    ap.add_argument("--alias", default=None)
    ap.add_argument("--json", action="store_true", help="print raw JSON result")
    a = ap.parse_args()

    sql = Runner(connect())
    log = dict(source="snow connector (CLI)", actor=a.actor, scenario=a.scenario, target=a.target)

    if a.command == "fetch":
        table(core.git_fetch(sql))
        table(core.git_branches(sql), ["name", "commit_hash"])
        return

    if a.command == "record-git":
        branches = git("branch", "-a", "-vv")
        graph = git("log", "--graph", "--oneline", "--decorate", "--all", "-n", "40")
        core.log_event(sql, source="git CLI", actor=a.actor, scenario=a.scenario or "Git", operation="GIT LOG",
                       command="git log --graph --oneline --decorate --all", output={"branches": branches, "graph": graph})
        print(graph)
        return

    if a.command == "create":
        res = core.dcm_create_project(sql, a.target)
        table(res)
        core.log_event(sql, **log, operation="CREATE DCM PROJECT", command=f"CREATE DCM PROJECT {core.TARGETS[a.target]['project']}",
                       output=res, query_id=sql.last_qid)
        return

    if a.command == "provision":
        for stmt in core.provision_clone_sql(a.target):
            res = sql(stmt)
            table(res)
            core.log_event(sql, **log, operation="ZERO-COPY CLONE", command=stmt, output=res, query_id=sql.last_qid)
        return

    if a.command in ("plan", "deploy"):
        commit = core.branch_commit(sql, a.branch) or ""
        stmt = core.dcm_plan_sql(a.target, a.branch) if a.command == "plan" else \
            core.dcm_deploy_sql(a.target, a.branch, a.alias)
        print(f"-- branch {a.branch} @ {commit[:7]}\n{stmt}\n")
        try:
            raw = sql(stmt)
            result = core._parse_result(raw)
        except Exception as e:  # real error from Snowflake
            core.log_event(sql, **log, operation=a.command.upper(), branch=a.branch, commit=commit,
                           status="FAILED", command=stmt, error=str(e))
            print("FAILED:", e)
            sys.exit(1)
        if a.json:
            print(json.dumps(result, indent=2))
        rows = core.changeset_rows(result)
        table(rows, ["ACTION", "OBJECT_TYPE", "OBJECT", "ONLY_ADOPTION"], width=70)
        print("\nSummary:", core.changeset_summary(result), "| status:", result.get("status", "n/a"))
        change = core.view_definition_change(result)
        if change:
            print("\nVW_CUSTOMER_SALES new definition:\n" + change)
        core.log_event(sql, **log, operation=a.command.upper(), branch=a.branch, commit=commit,
                       command=stmt, output=result, query_id=sql.last_qid)
        return

    if a.command == "test":
        stmt = core.dcm_test_sql(a.target)
        try:
            result = core._parse_result(sql(stmt))
        except Exception as e:
            core.log_event(sql, **log, operation="TEST ALL", status="FAILED", command=stmt, error=str(e))
            print("FAILED:", e)
            sys.exit(1)
        if a.json:
            print(json.dumps(result, indent=2))
        rows = core.expectation_rows(result)
        table(rows, width=50)
        status = "FAILED" if any(r["STATUS"] != "PASS" for r in rows) else "SUCCESS"
        core.log_event(sql, **log, operation="TEST ALL", status=status, command=stmt, output=result, query_id=sql.last_qid)
        return

    if a.command == "validate":
        template = (ROOT / core.VALIDATION_SQL_PATH).read_text()
        rows = core.run_validation(sql, template, a.target)
        table(rows, ["CHECK_ID", "CATEGORY", "CHECK_NAME", "EXPECTED", "ACTUAL", "STATUS"], width=75)
        failed = [r for r in rows if r["STATUS"] != "PASS"]
        print(f"\n{len(rows) - len(failed)} passed, {len(failed)} failed")
        core.log_event(sql, **log, operation="VALIDATE", status="FAILED" if failed else "SUCCESS",
                       command=core.VALIDATION_SQL_PATH, output=rows, query_id=sql.last_qid)
        return

    if a.command == "query":
        print(core.TARGETS[a.target]["business_db"] + ".BUSINESS_READY.VW_CUSTOMER_SALES")
        table(core.customer_view_sample(sql, a.target, 5))
        tot = core.customer_view_totals(sql, a.target)
        print("\nTotals:", {k: str(v) for k, v in tot.items()})
        core.log_event(sql, **log, operation="QUERY VIEW", command="VW_CUSTOMER_SALES totals", output=tot)
        return

    if a.command == "deployments":
        table(core.dcm_deployments(sql, a.target))


if __name__ == "__main__":
    main()
