---
paths:
  - "**/Core/CSessionManager.mqh"
  - "**/Core/CHeartbeatManager.mqh"
  - "**/Core/CTokenManager.mqh"
  - "**/Services/CDataCollectorService.mqh"
  - "**/Services/CHttpService.mqh"
---
> Backend API contract (extracted verbatim from CLAUDE.md, 2026-05-31 split). Read when changing session/heartbeat/refresh payloads — the contract lives in the sibling `aws/` repo with `additionalProperties: false`.

# Backend API Contract

The SDK talks to 4 endpoints:
- `POST /robot/start` — session init (sends `static_fields`, `session_symbols`, config)
- `POST /robot/heartbeat` — periodic telemetry (sends `dynamic_data`, sequence counter)
- `POST /robot/refresh` — JWT token renewal
- `POST /robot/end` — session termination

Contract schemas live in `aws/contracts/schemas/static_data/v1.json` and `aws/contracts/api/robot/components/robot-start.yaml` (separate repo). The `static_fields` schema has `additionalProperties: false` — any new field sent by the SDK must also be added to the contract.

MQL4 sessions omit 5 MQL5-only fields (`account_margin_mode`, `account_currency_digits`, `account_fifo_close`, `account_hedge_allowed`, `terminal_x64`). These are optional in the schema. The `platform` field (`"mt4"` or `"mt5"`) is also sent.

## Operational invariants

- **Heartbeat sequence**: Monotonically increasing counter. Server returns 409 on mismatch; SDK resyncs from response.
- **Token refresh**: Proactive — happens `SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD` (60s) before JWT expiry, not after.
- **Product type**: Determined server-side from database via `robot_version_uuid`, not from SDK payload.
