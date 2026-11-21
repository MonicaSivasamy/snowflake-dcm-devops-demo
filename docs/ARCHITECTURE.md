# Architecture

## Git → Snowflake → DCM → target environments

```mermaid
flowchart LR
  subgraph GH["GitHub: MonicaSivasamy/snowflake-dcm-devops-demo"]
    M["main"]
    FA["feature/developer-A<br/>10% discount"]
    FB["feature/developer-B<br/>20% discount"]
    FD["feature/developer-A-defect<br/>* 1.10 bug"]
  end

  subgraph CTRL["DCM_DEMO_CTRL_DB (control plane)"]
    REPO["GIT.DCM_DEMO_REPO<br/>Git repository object<br/>(ALTER ... FETCH)"]
    subgraph PRJ["PROJECTS: one DCM project object per target"]
      P0["DCM_SHARED_DEV"]
      P1["DCM_DEV_A"]
      P2["DCM_DEV_B"]
      P3["DCM_UAT"]
      P4["DCM_PROD (PLAN only)"]
    end
    APP["APP.DCM_DEVOPS_DEMO<br/>Streamlit in Snowflake"]
    AUD["AUDIT.EXECUTION_LOG"]
  end

  GH -- "API integration<br/>DCM_DEMO_GIT_API" --> REPO
  REPO -- "EXECUTE DCM PROJECT ... PLAN / DEPLOY<br/>USING CONFIGURATION &lt;target&gt;<br/>FROM '@repo/branches/&quot;&lt;branch&gt;&quot;/dcm'" --> PRJ

  P0 --> S["ANALYTICS_DB + BUSINESS_DB<br/>(shared DEV)"]
  P1 --> A["DEV_A_ANALYTICS_DB + DEV_A_BUSINESS_DB"]
  P2 --> B["DEV_B_ANALYTICS_DB + DEV_B_BUSINESS_DB"]
  P3 --> U["UAT_ANALYTICS_DB + UAT_BUSINESS_DB"]
  P4 -. "plan only" .-> PR["PROD_ANALYTICS_DB + PROD_BUSINESS_DB"]

  S -- "zero-copy CLONE (data)" --> A
  S -- "zero-copy CLONE (data)" --> B
  S -- "zero-copy CLONE (data)" --> U

  APP --> REPO
  APP --> PRJ
  APP --> AUD
```

## Data flow inside every environment

```mermaid
flowchart LR
  subgraph AN["&lt;env&gt;_ANALYTICS_DB"]
    subgraph RAW
      RC[RAW_CUSTOMERS]; RP[RAW_PRODUCTS]; RO[RAW_ORDERS]
    end
    subgraph COMPUTE
      CS[CUSTOMER_SALES]; PS[PRODUCT_SALES]; DS[DAILY_SALES]
    end
  end
  subgraph BU["&lt;env&gt;_BUSINESS_DB.BUSINESS_READY"]
    V1[VW_CUSTOMER_SALES]; V2[VW_PRODUCT_PERFORMANCE]; V3[VW_DAILY_REVENUE]
  end
  RC & RO & RP --> CS --> V1
  RP & RO --> PS --> V2
  RO & RP --> DS --> V3
```

## Responsibilities

| Layer | Responsibility | Tool |
|---|---|---|
| Source code | Versioned SQL definitions, branches, review, merge | Git / GitHub |
| Desired state | `DEFINE` statements + Jinja per target | DCM project files (`dcm/`) |
| Change computation | Render, compile, compute CREATE/ALTER/DROP | `EXECUTE DCM PROJECT ... PLAN` |
| Change application | Apply changeset, record deployment, own objects | `EXECUTE DCM PROJECT ... DEPLOY` |
| Generic data quality | Nulls, duplicates, volume, min | DCM expectations (`TEST ALL`) |
| Business correctness | Recompute from RAW, reconcile layers, business rules | `validation/business_rules.sql` |
| Isolation | Separate objects per developer | Separate databases + DCM project per target |
| Data for sandboxes | Instant, storage-free copies | Zero-copy `CLONE` |
