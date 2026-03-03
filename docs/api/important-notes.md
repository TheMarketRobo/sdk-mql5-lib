# SDK Architecture Notes

## Three-Layer Architecture

The SDK acts as middleware between Server and Robot/Indicator:

```
Server ↔ SDK ↔ Robot (Developer's EA/Indicator Code)
```

- **Server ↔ SDK**: HTTP/JSON communication with JWT authentication
- **SDK ↔ Robot**: Internal MQL5 callbacks and method calls
- **Robot**: Developer's EA/Indicator code with configuration objects

---

## Key Design Principles

### 1. Parameter Separation

| Parameter | Provider | Location |
|-----------|----------|----------|
| `robot_version_uuid` | Programmer | Constructor (hardcoded) |
| `IRobotConfig` schema | Programmer | `define_schema()` method (Robots only) |
| `api_key` | Customer | Input parameter |
| `magic_number` | Customer | Input parameter (Robots only) |
| `base_url` | SDK | `SDK_API_BASE_URL` constant |

### 2. Configuration Management

- **Schema Definition**: Programmer defines field types, constraints, and validation in code using `CConfigField` and `CConfigSchema`
- **Server Sync**: SDK validates that all schema fields exist in server config on `/start`
- **Partial Updates**: Heartbeat responses contain only changed parameters, not full config
- **Validation**: Each parameter change is validated against the schema before applying
- **Notification**: Robot is notified via `on_config_changed()` callback after validation

### 3. Token Management

- **JWT Payload**: Unencrypted, robot can read `exp` claim locally
- **Proactive Refresh**: SDK refreshes token BEFORE expiration (configurable threshold)
- **Default**: 300 seconds (5 minutes) before expiration
- **No Signing by Robot**: Robot never modifies or signs JWT

### 4. Data Persistence

- **Heartbeat Caching**: If token expires during heartbeat, data is cached and resent after refresh
- **Change Results**: Config/symbol change results are persisted until server confirms receipt
- **Sequence Numbers**: Monotonically increasing, not incremented until server confirms

### 5. Heartbeat Interval

- **Server-Specified**: Server tells robot the heartbeat interval in responses
- **Maximum Limit**: SDK enforces 300 seconds (5 minutes) maximum
- **Hardcoded**: Cannot be manipulated by external configuration

---

## SDK Process Summary

### On `/start`:
1. Collect static fields using MQL5 `AccountInfo*()`, `TerminalInfo*()`, `MQLInfo*()` functions
2. Generate session symbols array from all available symbols
3. Send request with API key, robot version UUID, initial balance/equity
4. Validate server config contains ALL fields from programmer's schema
5. Store JWT token, session ID, and apply initial configuration
6. Start timer for heartbeats

### On `/heartbeat`:
1. Check token expiration locally (decode JWT payload)
2. If expired → cache data, call `/refresh` first, then retry
3. Collect dynamic data (balance, equity, margin, profit, drawdown)
4. Include any pending config/symbol change results
5. Send heartbeat with monotonic sequence number
6. Process response: apply interval, handle new change requests
7. Notify robot via callbacks for any config/symbol changes

### On `/refresh`:
1. Send current (expired) JWT to server
2. Receive new JWT with same session context
3. Update cached token
4. Resend any pending heartbeat data

### On `/end`:
1. Build final statistics
2. Send termination request with reason
3. Clear all SDK state

---

## Error Response Requirements

All errors must specify:
- **Error code**: Machine-readable identifier (e.g., `TOKEN_EXPIRED`)
- **Message**: Human-readable description
- **Action required**: What the robot/user should do
- **Details**: Additional context (e.g., expired_at timestamp)

This enables the SDK to handle errors appropriately without guessing.

---

## Feature Toggles

The SDK supports disabling optional features:

```cpp
robot.set_enable_config_change_requests(false);  // Ignore config changes
robot.set_enable_symbol_change_requests(false);  // Ignore symbol changes
```

When disabled:
- SDK ignores relevant fields in responses
- No change results are sent in heartbeats
- Callbacks are not fired

---

## Naming Conventions

The SDK follows MQL5 standard library naming:
- Classes: `CClassName` (e.g., `CTheMarketRobo_Base`, `CSDKContext`)
- Interfaces: `IInterfaceName` (e.g., `IRobotConfig`)
- Methods: `snake_case` (e.g., `on_init`, `get_token`)
- Constants: `UPPER_CASE` (e.g., `SDK_API_BASE_URL`)
