# Customer demo script (≈ 35 minutes)

Open Snowsight → **Projects → Streamlit → DCM_DEVOPS_DEMO** (role `DCM_DEMO_ADMIN`).
Turn on **🎤 Guided demo mode** in the sidebar: every step below has a matching
presenter note and the **Next ▶** button moves to the right section.

All numbers below are what the account returned during the verified run on
2026-11-21. Synthetic data: 50 customers, 20 products, 1,200 order lines,
**gross completed sales 760,202.17**.

| Discount | Expected NET_SALES total |
|---|---|
| 0% (baseline) | 760,202.17 |
| 10% (Developer A) | 684,182.00 |
| 20% (Developer B) | 608,161.71 |
| defect `* 1.10` | 836,222.39 |

---

## 0. Opening (2 min) - the problem
> "Today your SQL lives in shared worksheets. Two people can edit the same view,
> nobody knows what it looked like yesterday, and there is no review. Let's see
> what Git and DCM fix - and what they don't."

## 1. Current State (3 min)
* Sidebar shows the live connection: account, role, warehouse.
* Data flow diagram: RAW → COMPUTE → BUSINESS_READY across two databases.
* Explorer: pick `ANALYTICS_DB`, show row counts (50 / 20 / 1,200), open
  `VW_CUSTOMER_SALES` → *SQL definition* tab.
* Optional: **Execute initial setup** - safe to rerun (idempotent).

## 2. Git Repository and Branches (4 min)
* Branch table = real GitHub branches as seen by Snowflake (`SHOW GIT BRANCHES`).
* Commit graph = real `git log --graph` captured by the git CLI.
* Checkout `feature/developer-A`, compare with `feature/developer-B`:
  > "Same file, same view, two different business rules. Git keeps both safely."
* Pull request review: A is merged, B is open, the defect branch is blocked by validation.

## 3. DCM Project Structure (4 min)
* `manifest.yml`: five targets, each with its own **DCM project object** and
  **Jinja configuration** (`analytics_db`, `business_db`).
* Show `vw_customer_sales.sql` rendered for `SHARED_DEV` and `DEV_A`.
  > "One definition, many environments. `DEFINE` = desired state; DCM works out
  > CREATE / ALTER / DROP."
* Bottom table: what each stage checks - come back to it in step 6.

## 4. Scenario 1 - Shared Object Deployment (7 min) ⭐
1. Expand **Reset SHARED_DEV**, confirm, **Reset now** (deploys the 0% baseline commit).
2. **Query** → 0%, NET 760,202.17.
3. **STEP A** Developer A's branch + diff (`0.00 → 0.10`, `* 1.00 → * 0.90`).
4. **STEP B** Run DCM PLAN → *1 ALTER, 0 DROP*; the new view text is shown.
5. **STEP C** tick *reviewed*, Deploy, Query → **10 %, 684,182.00**.
6. **STEP D** Developer B's branch (`0.20`, `* 0.80`).
7. **STEP E** PLAN against the **same** project `DCM_SHARED_DEV`.
8. **STEP F** Deploy, Query → **20 %, 608,161.71**.
9. Before/after table + red banner.
   > "Both branches are intact in Git. Snowflake has one object - the last deploy
   > wins. **Git branches isolate code, not database objects.**"
* DCM deployment history at the bottom shows both deployments with their source branch.

## 5. Scenario 2 - Developer Object Isolation (7 min) ⭐
1. **Provision** - zero-copy clones `DEV_A_ANALYTICS_DB`, `DEV_B_ANALYTICS_DB`
   (instant, no extra storage) + DCM projects `DCM_DEV_A`, `DCM_DEV_B`.
2. Left column (Developer A): diff → PLAN → Deploy → Query (10 %) → Validate (13/13).
3. Right column (Developer B): same → 20 %, 13/13.
4. **Compare all three environments now**:
   | Environment | Discount | Reads from |
   |---|---|---|
   | Shared DEV | unchanged | `ANALYTICS_DB.COMPUTE...` |
   | Developer A | 10 % | `DEV_A_ANALYTICS_DB.COMPUTE...` |
   | Developer B | 20 % | `DEV_B_ANALYTICS_DB.COMPUTE...` |
   > "Same Git repository, same definitions, different Jinja configuration and
   > DCM project → separate objects. Nobody overwrites anybody."
* Talking point: cloned views initially still pointed at `ANALYTICS_DB`; the
  DCM deploy re-rendered them against the developer's own databases.

## 6. Data Testing and Validation (6 min) ⭐
Developer A "refactors": `round(SALES_AMOUNT * 1.10, 2)`.
* **A** Git commit exists ✅  **B** PLAN ✅ (1 ALTER)  **C** DEPLOY ✅
* **D** Query → NET **836,222.39** > gross 760,202.17 ❌
* **DCM TEST ALL** → **9/9 PASS** (nulls, duplicates, volume, non-negative)
* **E** Independent validation → **3 FAIL** (checks 7, 8, 9: discount rule)
  > "Every automated gate was green and the numbers are wrong. DCM PLAN is a
  > compiler and change calculator, not a test suite. Expectations only test what
  > you encode. You still need transformation tests that know the business rules."
* Show the *Which gate catches what* table. Mention that PLAN *did* block a real
  structural problem earlier (NUMBER scale change) - see the audit log.
* **Reset DEV_A** to finish.

## 7. Deployment Pipeline (4 min)
Feature → PR → main → PLAN shared DEV → DEPLOY → Validation → UAT → PROD.
* Pipeline bar shows each stage's last real status.
* Merge evidence: `main` now equals `feature/developer-A`; B was not merged.
* PLAN → review → DEPLOY → validate shared DEV; UAT gate opens only after validation passes.
* UAT: PLAN, DEPLOY, validate (13/13), TEST ALL (9/9).
* PROD: PLAN only (16 creates). The deploy button is disabled by design.

## 8. Execution History and Audit (2 min)
* Filter by operation / target / status; open any EVENT_ID to see the exact SQL,
  JSON output, query ID - including the **failed** PLAN that DCM rejected.
* DCM's own deployment history per project.

## Closing
> "Git gives you history, review and branching. DCM gives you declarative,
> repeatable deployments per environment. Isolation comes from **separate
> targets**, and correctness comes from **tests that know your business** - you
> need all three."
