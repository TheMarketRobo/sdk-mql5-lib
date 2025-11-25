# SDK Protocol Specification

This document details the communication protocol, data structures, and business logic of the `sdk-mql5-lib` SDK. It covers the interaction between the MQL5 client (Robot) and the Server.

## 1. Overview

The SDK manages a trading session lifecycle through a series of HTTP requests. The communication is initiated by the client. The core flows are:
1.  **Start**: Authenticate and initialize the session.
2.  **Heartbeat**: Periodic updates, data transmission, and configuration synchronization.
3.  **Refresh**: Maintain authentication validity.
4.  **End**: Terminate the session and report final statistics.

All requests use JSON for payloads and responses.

## 2. Authentication

-   **Initial Auth**: The `/start` endpoint uses an `api_key` to authenticate the robot.
-   **Session Auth**: Upon successful start, the server returns a `jwt` (JSON Web Token).
-   **Subsequent Requests**: All subsequent requests (`/heartbeat`, `/end`) must include this JWT in the `Authorization` header (Bearer scheme) or as part of the payload (e.g., `/refresh`).
-   **Token Refresh**: The SDK provides a `/refresh` endpoint to obtain a new JWT before the current one expires.

## 3. Data Structures

### 3.1. Static Fields (`static_fields`)
Sent during the `/start` handshake. Contains immutable environment data collected by `Cdata_Collector_Service`.

| Field | Type | Description |
| :--- | :--- | :--- |
| `account_number` | String | Account login number (`ACCOUNT_LOGIN`). |
| `broker` | String | Broker company name (`ACCOUNT_COMPANY`). |
| `server` | String | Trade server name (`ACCOUNT_SERVER`). |
| `account_name` | String | Client name (`ACCOUNT_NAME`). |
| `account_currency` | String | Account currency (`ACCOUNT_CURRENCY`). |
| `account_trade_mode` | Long | 0=Demo, 1=Contest, 2=Real (`ACCOUNT_TRADE_MODE`). |
| `account_leverage` | Long | Account leverage (`ACCOUNT_LEVERAGE`). |
| `account_limit_orders` | Long | Max allowed limit orders (`ACCOUNT_LIMIT_ORDERS`). |
| `account_margin_so_mode` | Long | Stop-out mode (`ACCOUNT_MARGIN_SO_MODE`). |
| `account_trade_allowed` | Bool | If trading is allowed for the account (`ACCOUNT_TRADE_ALLOWED`). |
| `account_trade_expert` | Bool | If EAs are allowed to trade (`ACCOUNT_TRADE_EXPERT`). |
| `account_margin_mode` | Long | Margin calculation mode (`ACCOUNT_MARGIN_MODE`). |
| `account_currency_digits` | Long | Digits in account currency (`ACCOUNT_CURRENCY_DIGITS`). |
| `account_fifo_close` | Bool | If FIFO closing is required (`ACCOUNT_FIFO_CLOSE`). |
| `account_hedge_allowed` | Bool | If hedging is allowed (`ACCOUNT_HEDGE_ALLOWED`). |
| `mql_program_name` | String | Name of the MQL program (`MQL_PROGRAM_NAME`). |
| `mql_program_type` | Long | Type of MQL program (`MQL_PROGRAM_TYPE`). |
| `mql_program_path` | String | Path to the MQL program (`MQL_PROGRAM_PATH`). |
| `mql_trade_allowed` | Bool | If the MQL program is allowed to trade (`MQL_TRADE_ALLOWED`). |
| `mql_optimization` | Bool | If running in optimization mode (`MQL_OPTIMIZATION`). |
| `terminal_path` | String | Path to the terminal installation (`TERMINAL_PATH`). |
| `terminal_data_path` | String | Path to terminal data folder (`TERMINAL_DATA_PATH`). |
| `terminal_commondata_path`| String | Path to common data folder (`TERMINAL_COMMONDATA_PATH`). |
| `terminal_build` | Long | Terminal build number (`TERMINAL_BUILD`). |
| `terminal_language` | String | Terminal language (`TERMINAL_LANGUAGE`). |
| `terminal_name` | String | Terminal name (`TERMINAL_COMPANY`). |
| `terminal_maxbars` | Long | Max bars on chart (`TERMINAL_MAXBARS`). |
| `expert_magic` | Long | Magic number of the EA. |

### 3.2. Session Symbol (`session_symbols`)
An array of objects sent during `/start`. Represents available symbols.

| Field | Type | Description |
| :--- | :--- | :--- |
| `symbol` | String | Symbol name (e.g., "EURUSD"). |
| `active_to_trade` | Bool | If the symbol is visible/active in Market Watch. |
| `spread` | Double | Current spread in points. |
| `lot_size` | Double | Minimum volume (lot size). |
| `pip_value` | Double | Value of one pip. |
| `margin_required` | Double | Margin required for 1 lot buy. |

### 3.3. Final Stats (`final_stats`)
Sent during `/end`. Summarizes the session performance.

| Field | Type | Description |
| :--- | :--- | :--- |
| `total_trades` | Long | Total number of trades executed. |
| `winning_trades` | Long | Number of profitable trades. |
| `losing_trades` | Long | Number of loss-making trades. |
| `total_pnl` | Double | Total Profit/Loss. |
| `max_drawdown` | Double | Maximum drawdown observed. |
| `session_duration_minutes`| Long | Duration of the session in minutes. |
| `last_error` | String | Last recorded error message. |
| `shutdown_reason` | String | Reason for session termination. |

### 3.4. Dynamic Data (`dynamic_data`)
Sent during `/heartbeat`.
> [!NOTE]
> Currently, the `get_dynamic_data` method in `Cdata_Collector_Service` returns an empty JSON object `{}`. This is a placeholder for future implementation of real-time metrics like balance, equity, and open positions.

## 4. Protocol Flow & Business Logic

### 4.1. Start Session
**Endpoint:** `/start`
**Method:** POST

**Request Payload:**
```json
{
  "api_key": "string",
  "robot_version": "string",
  "static_fields": { ... }, // See 3.1
  "session_symbols": [ ... ] // See 3.2
}
```

**Response Payload:**
```json
{
  "session_id": 12345,
  "jwt": "eyJhbG...",
  "robot_config": { ... } // Initial configuration for the robot
}
```

**Business Logic:**
1.  **Collection**: The SDK collects static environment data and iterates through all symbols to build the `session_symbols` list.
2.  **Transmission**: Sends this data to register a new session.
3.  **Initialization**:
    -   Stores `session_id` and `jwt`.
    -   Passes `robot_config` to the developer's `Irobot_Config` implementation for validation and update.
    -   If config validation fails, the session is marked inactive.

### 4.2. Heartbeat
**Endpoint:** `/heartbeat`
**Method:** POST

**Request Payload:**
```json
{
  "session_id": 12345,
  "sequence": 1, // Incremental counter
  "dynamic_data": { }, // Currently empty
  "config_change_results": { // Optional, present if changes were processed
    "accepted_changes": [
      { "field_name": "Risk", "value": "2.0" }
    ],
    "rejected_changes": [
      { "field_name": "LotSize", "reason": "Too high" }
    ]
  },
  "symbols_change_results": { ... } // Optional, reserved for future use
}
```

**Response Payload:**
```json
{
  "heartbeat_interval_seconds": 60, // Optional: Update heartbeat frequency
  "robot_config_change_request": { // Optional: Request to change config
    "Risk": "2.5",
    "MaxTrades": "5"
  },
  "session_symbols_change_request": { // Optional: Request to change symbol status
    "symbols": {
      "EURUSD": true,
      "GBPUSD": false
    }
  }
}
```

**Business Logic:**
1.  **Timing**: Sent every `heartbeat_interval_seconds` (default 60s).
2.  **Sequence**: `sequence` increments with every successful heartbeat.
3.  **Config Changes**:
    -   If the server sends `robot_config_change_request`, the SDK validates each field using `Irobot_Config::validate_field`.
    -   Valid changes are applied via `Irobot_Config::update_field`.
    -   Results (accepted/rejected) are queued and sent in the *next* heartbeat under `config_change_results`.
    -   Fires `SDK_EVENT_CONFIG_CHANGED` event.
4.  **Symbol Changes**:
    -   If the server sends `session_symbols_change_request`, the SDK updates the symbol's status in the terminal (Market Watch) and internal state.
    -   Fires `SDK_EVENT_SYMBOL_CHANGED` event.
    -   *Note: Reporting results back to the server in `symbols_change_results` is currently a TODO in the code.*
5.  **Retry**: If a heartbeat fails (network error or non-200), the payload is cached and retried on the next tick.

### 4.3. Refresh Token
**Endpoint:** `/refresh`
**Method:** POST

**Request Payload:**
```json
{
  "jwt_token": "eyJhbG..." // Current token
}
```

**Response Payload:**
```json
{
  "jwt": "eyJhbG..." // New token
}
```

**Business Logic:**
-   Called explicitly by the SDK to rotate the token.
-   On success, updates the internal token manager and fires `SDK_EVENT_TOKEN_REFRESH` with `success=true`.
-   On failure, fires `SDK_EVENT_TOKEN_REFRESH` with `success=false`.

### 4.4. End Session
**Endpoint:** `/end`
**Method:** POST

**Request Payload:**
```json
{
  "session_id": 12345,
  "reason": "User stop",
  "final_stats": { ... } // See 3.3
}
```

**Response Payload:**
-   HTTP 200 OK

**Business Logic:**
1.  Triggered on `OnDeinit` or explicit stop.
2.  Fires `SDK_EVENT_TERMINATION_START`.
3.  Sends final stats to the server.
4.  Fires `SDK_EVENT_TERMINATION_END` with the result of the request.

## 5. Internal Events

The SDK communicates with the robot implementation via MQL5 Chart Events (`EventChartCustom`).

| Event ID Constant | Description | JSON Data Structure (`sparam`) |
| :--- | :--- | :--- |
| `SDK_EVENT_CONFIG_CHANGED` | Configuration field updated. | `{"type":"config_change","field":"Name","old_value":"Val","new_value":"Val"}` |
| `SDK_EVENT_SYMBOL_CHANGED` | Symbol status updated. | `{"type":"symbol_change","symbol":"EURUSD","active_to_trade":true}` |
| `SDK_EVENT_TERMINATION_START` | Session termination started. | `{"type":"termination","reason":"...","success":false,"message":"..."}` |
| `SDK_EVENT_TERMINATION_END` | Session termination finished. | `{"type":"termination","reason":"...","success":true,"message":"..."}` |
| `SDK_EVENT_TOKEN_REFRESH` | Token refresh attempt result. | `{"type":"token_refresh","success":true,"message":"..."}` |
