# Avatar Videos — Business Context

This file contains business data not available in Databricks. Update manually as accounts progress.

## Accounts

| Customer | Industry | Environment | Status | Notes |
|----------|----------|-------------|--------|-------|
| Umich | Education | Staging | Active | POC |
| Roche | Healthcare | Staging | Active | POC |
| Amsterdam School of Arts (AHK) | Education | Production | Active | Tester group |
| McDonald's | Food & Retail | Staging | Active | POC on video portal |
| eLearning Media | Education | Staging | Active | POC |
| EY | Professional Services | Staging | Active | POC |
| Simpplr | Technology | — | Planned POC | Not yet started |

## Free Trial Program — Cohort 1

| Partner ID | Customer | Status |
|-----------|----------|--------|
| 4170533 | Allspring Global Investments | No Objections from CSM |
| 3193793 | Block, Inc. | No Objections from CSM |
| 2167581 | Liberty University | Selected by EDU NA Team |
| 2189801 | UMaine System | Selected by EDU NA Team |

## Report Update Workflow

1. Run `./update_report.sh` — fetches fresh data from Databricks
2. Tell Claude "update the report" — it reads `data.json` + this file and updates `index.html`

Queries are stored in `queries/` folder. Databricks warehouse: `ccae3439c77a865d` (explorers - nvp).
