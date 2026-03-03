# SDK Architecture Notes

## Three-Layer Architecture

The SDK acts as middleware between Server and Robot/Indicator:

```
Server ↔ SDK ↔ Robot/Indicator (Developer's EA or Custom Indicator Code)
```

- **Server ↔ SDK**: HTTP/JSON communication with JWT authentication over endpoints under `SDK_API_BASE_URL` (e.g. `https://api.staging.themarketrobo.com`)
- **SDK ↔ Robot/Indicator**: Internal MQL5 callbacks and method calls
- **Robot/Indicator**: Developer's EA or Custom Indicator code; Robots use configuration objects (`IRobotConfig`), Indicators do not

---

## API Endpoints (SDK Implementation)

The SDK sends requests to the following paths **relative to the base URL** (no leading slash in constant; endpoints are concatenated). All are POST with `Content-Type: application/json`.

| Purpose    | Endpoint           | Auth / body |
|-----------|--------------------|-------------|
| Start     | `/robot/start`     | API key in body; SDK sends a special Authorization value for gateway (e.g. `api-key-start`) |
| Heartbeat | `/robot/heartbeat` | `Authorization: Bearer <jwt>`; body: sequence, timestamp, dynamic_data, optional config/symbol results (Robots only) |
| Refresh   | `/robot/refresh`   | `Authorization: Bearer <current_jwt>`; body: `{ "jwt_token": "..." }` |
| End       | `/robot/end`       | `Authorization: Bearer <jwt>`; body: session_id, reason, optional final_stats |

---

## Key Design Principles

### 1. Parameter Separation

| Parameter | Provider | Location | Notes |
|-----------|----------|----------|--------|
| `robot_version_uuid` / `indicator_version_uuid` | Programmer | Constructor (hardcoded) | Same UUID field name in API; Indicators use one-arg constructor |
| `IRobotConfig` schema | Programmer | `define_schema()` (Robots only) | Indicators do not use config |
| `api_key` | Customer | Input parameter | Required for both EAs and Indicators |
| `magic_number` | Customer | Input parameter (Robots only) | Indicators omit; SDK sends 0 in static_fields for indicators |
| `base_url` | SDK | `SDK_API_BASE_URL` in CSDKConstants.mqh | Not configurable |

**Indicators:** The SDK does **not** send `magic_number` or `session_symbols` on `/robot/start`; it does not validate or receive `robot_config`; config/symbol change requests are disabled and not sent in heartbeats.

### 2. Configuration Management

- **Schema Definition**: Programmer defines field types, constraints, and validation in code using `CConfigField` and `CConfigSchema` (Robots only)
- **Server Sync**: SDK validates that all schema fields exist in server config on `/start` (Robots only; Indicators skip this)
- **Partial Updates**: Heartbeat responses may contain change requests; Robots apply and report results in the next heartbeat
- **Validation**: Each parameter change is validated against the schema before applying (Robots only)
- **Notification**: Robot is notified via `on_config_changed()` callback after validation (Indicators do not receive this)

### 3. Token Management

- **JWT Payload**: Unencrypted; robot/indicator can read `exp` claim locally (base64-decode payload)
- **Proactive Refresh**: SDK refreshes token **before** expiration (configurable threshold)
- **Default threshold**: **60 seconds** before expiration (`SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD` in CSDKConstants.mqh); configurable via `set_token_refresh_threshold(seconds)` (range 60–3600)
- **No Signing by Robot**: Robot/Indicator never modifies or signs JWT
- **Note**: If threshold is set ≥ JWT expiration time, refresh triggers immediately

### 4. Data Persistence

- **Heartbeat Caching**: If token expires during heartbeat, data is cached and resent after refresh (handled in timer/refresh flow)
- **Change Results**: Config/symbol change results are included in heartbeat until server confirms (Robots only)
- **Sequence Numbers**: Monotonically increasing; not incremented until server confirms (200 response)

### 5. Heartbeat Interval

- **Server-Specified**: Server may return `heartbeat_interval_seconds` in heartbeat response; SDK applies it
- **Maximum Limit**: SDK enforces **300 seconds** (5 minutes) maximum (`SDK_MAX_HEARTBEAT_INTERVAL`)
- **Timing**: SDK uses **TimeLocal()** (not TimeCurrent()) for heartbeat timing so heartbeats continue when the market is closed (weekends/holidays)
- **Default**: `SDK_DEFAULT_HEARTBEAT_INTERVAL` is 60 seconds if server does not specify

---

## Robot vs Indicator Behavior

| Feature | Robot (EA) | Indicator |
|--------|------------|-----------|
| `/robot/start` payload | Sends magic_number, session_symbols, full static_fields | Omits magic_number and session_symbols; static_fields with expert_magic 0 |
| robot_config | Validated on start; receives change requests | Not used |
| Heartbeat | Sends config_change_results, symbols_change_results when pending | Omits both; no change requests |
| Termination | Calls `ExpertRemove()` on session end / server request | No self-removal; stops timer and alerts user to remove indicator |
| Callbacks | `on_config_changed()`, `on_symbol_changed()` | Not used |

---

## SDK Process Summary

### On `/robot/start`:
1. (Optional) Wait for account data (`wait_for_account_data` up to 10 seconds) so balance/equity are non-zero when available
2. Collect static fields using MQL5 `AccountInfo*()`, `TerminalInfo*()`, `MQLInfo*()`; for Indicators use magic 0 in static_fields
3. Build payload: api_key, robot_version_uuid, (magic_number and session_symbols for Robots only), account_currency, initial_balance, initial_equity, static_fields
4. Send POST to `/robot/start` with API key in body and special Authorization header
5. On success: store session_id (string or number), JWT, expires_in; for Robots validate initial robot_config; for Indicators mark session active immediately
6. Process any initial robot_config_change_request and session_symbols_change_request (Robots only)
7. Start timer for heartbeats

### On `/robot/heartbeat`:
1. Check token expiration locally (decode JWT); if within threshold, call `/robot/refresh` first then retry
2. Build payload: sequence (m_sequence + 1), timestamp (ISO 8601), dynamic_data; for Robots add config_change_results and symbols_change_results when pending
3. Send POST to `/robot/heartbeat` with Bearer token
4. On 200: increment sequence, update last heartbeat time (TimeLocal()), clear pending results (Robots), process heartbeat_interval_seconds, termination_requested (status + termination_reason), robot_config_change_request, session_symbols_change_request (Robots only)
5. On 409: handle sequence error (context.expected_sequence or context.current_sequence), sync sequence, reset confirmation state, retry next interval

### On `/robot/refresh`:
1. Send current JWT in body as `jwt_token` and as `Authorization: Bearer <current_jwt>`
2. POST to `/robot/refresh`
3. On 200: store new JWT from response; fire token refresh event
4. SDK uses **JWT-only** refresh (no api_key + session_id fallback in current implementation)

### On `/robot/end`:
1. Build payload: session_id, reason, optional final_stats (CFinalStats: total_trades, winning_trades, losing_trades, total_pnl, max_drawdown, session_duration_minutes, last_error, shutdown_reason)
2. Fire termination start event; send POST to `/robot/end` with Bearer token
3. On success: mark session inactive; fire termination end event
4. Clear all SDK state

---

## Error Response Requirements

All errors should specify:
- **Error code**: Machine-readable identifier (e.g., `TOKEN_EXPIRED`)
- **Message**: Human-readable description
- **Action required**: What the robot/user should do
- **Details**: Additional context (e.g., expired_at timestamp)

This enables the SDK to handle errors appropriately without guessing.

---

## Feature Toggles (Robots only)

The SDK supports disabling optional features:

```cpp
robot.set_enable_config_change_requests(false);  // Ignore config changes
robot.set_enable_symbol_change_requests(false);  // Ignore symbol changes
```

When disabled:
- SDK ignores relevant fields in heartbeat responses
- No change results are sent in heartbeats
- Callbacks are not fired

Indicators have these effectively disabled by default (config/symbol managers disabled).

---

## Naming Conventions

The SDK follows MQL5 style:
- Classes: `CClassName` (e.g., `CTheMarketRobo_Base`, `CSDKContext`)
- Interfaces: `IInterfaceName` (e.g., `IRobotConfig`)
- Methods: `snake_case` (e.g., `on_init`, `on_config_changed`, `get_token`)
- Constants: `UPPER_CASE` (e.g., `SDK_API_BASE_URL`, `SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD`)
