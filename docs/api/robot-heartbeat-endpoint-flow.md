# Trading Robot /heartbeat Endpoint - Complete Flow Documentation

## Overview
This document provides a comprehensive explanation of the `/heartbeat` endpoint flow for trading robots in the serverless trading robot control system. The `/heartbeat` endpoint serves as the primary communication channel between an active robot session and the server, handling telemetry updates, configuration changes, and symbol management. This refactored version implements cache-based JWT validation and handles robot-side response caching for improved reliability.

## Table of Contents
1. [Robot Request Data Structure](#robot-request-data-structure)
2. [Server Processing Flow](#server-processing-flow)
3. [Configuration Change Processing](#configuration-change-processing)
4. [Symbol Change Processing](#symbol-change-processing)
5. [Database Operations](#database-operations)
6. [Security and Authentication](#security-and-authentication)
7. [Response Structure](#response-structure)
8. [Error Scenarios](#error-scenarios)
9. [Data Flow Diagrams](#data-flow-diagrams)
10. [SDK Process for Robot](#sdk-process-for-robot)

## Robot Request Data Structure

### HTTP Request Format

**Endpoint:** `POST {SDK_API_BASE_URL}/robot/heartbeat`  
(e.g. `POST https://api.staging.themarketrobo.com/robot/heartbeat`)  
**Authorization:** `Bearer <jwt_token>`  
**Content-Type:** `application/json`

### Request Body Structure

```json
{
  "sequence": "integer (required, monotonic incrementing)",
  "timestamp": "string (required, ISO 8601 timestamp)",
  "dynamic_data": {
    "account_balance": 10000.50,
    "account_equity": 10125.30,
    "account_margin": 250.00,
    "account_margin_free": 9875.30,
    "account_margin_level": 4050.12,
    "balance_profit": 125.30,
    "equity_profit": 125.30,
    "balance_drawdown": 0.0,
    "equity_drawdown": 0.0
  },
  "config_change_results": {
    "status": "all_accepted",
    "results": [
      {
        "field_name": "max_trades_per_day",
        "requested_value": 25,
        "accepted": true,
        "applied_value": 25
      }
    ]
  },
  "symbols_change_results": {
    "status": "partially_accepted",
    "results": [
      {
        "symbol": "EURUSD",
        "requested_active_to_trade": true,
        "accepted": true,
        "applied_active_to_trade": true
      },
      {
        "symbol": "GBPJPY",
        "requested_active_to_trade": true,
        "accepted": false,
        "error_code": "SYMBOL_NOT_FOUND",
        "error_message": "Symbol not available in broker"
      }
    ]
  }
}
```

### Key Request Fields

#### Required Fields
- **`sequence`**: Monotonic counter (must be > previous sequence)
- **`timestamp`**: Current robot timestamp in ISO 8601 format
- **`dynamic_data`**: Real-time account and performance data

#### Dynamic Data Object
The robot sends comprehensive real-time trading data:

**Account Information:**
- `account_balance`: Current account balance (decimal 18,2)
- `account_equity`: Current account equity (decimal 18,2)
- `account_margin`: Used margin amount (decimal 18,2)
- `account_margin_free`: Available free margin (decimal 18,2)
- `account_margin_level`: Margin level percentage (decimal 18,2)

**Performance Metrics:**
- `balance_profit`: Profit/loss based on account balance (decimal 18,2, default: 0)
- `equity_profit`: Profit/loss based on account equity (decimal 18,2, default: 0)
- `balance_drawdown`: Maximum drawdown from peak balance (double, default: 0)
- `equity_drawdown`: Maximum drawdown from peak equity (double, default: 0)

#### Change Results Objects (Expert Advisors only)
For **Custom Indicators** the SDK does **not** include `config_change_results` or `symbols_change_results` in the heartbeat payload. For **Expert Advisors** only:

**Config Change Results:**
- `status`: Overall status (`all_accepted`, `all_rejected`, `partially_accepted`)
- `results`: Array of result items, each containing:
  - `field_name`: Configuration parameter name
  - `requested_value`: Value that was requested
  - `accepted`: Boolean indicating if change was accepted
  - `error_code`: Error code if rejected (optional)
  - `error_message`: Human-readable error message (optional)
  - `applied_value`: Actual value applied (optional, if different from requested)

**Symbols Change Results:**
- `status`: Overall status (`all_accepted`, `all_rejected`, `partially_accepted`)
- `results`: Array of result items, each containing:
  - `symbol`: Trading symbol identifier
  - `requested_active_to_trade`: Requested activation status
  - `accepted`: Boolean indicating if change was accepted
  - `error_code`: Error code if rejected (optional)
  - `error_message`: Human-readable error message (optional)
  - `applied_active_to_trade`: Actual status applied (optional)

## Server Processing Flow

### Step 1: Cache-Based JWT Validation
The server validates the JWT token using cache-based validation:
1. Verify JWT signature and structure using Secrets Manager secret
2. Check JWT expiration locally
3. Check cache for API key validation
4. Verify license expiration from cache

If validation fails, appropriate error response is returned.

### Step 2: Session and Sequence Validation
The server validates:
- Session exists and is active
- Session belongs to authenticated license
- Sequence number is greater than current stored sequence (prevents replay attacks)
- Session hasn't been terminated

### Step 3: Dynamic Data Update
The server updates the session record with:
- `last_heartbeat_at`: Current timestamp
- `dynamic_data`: Complete JSON payload from robot
- `sequence`: Updated sequence number
- `updated_at`: Database update timestamp

### Step 4: Configuration Change Processing
If `config_change_results` is provided:
- **Accepted Changes**: Update `sessions.robot_config` with applied values, log successful application, clear the change request
- **Rejected Changes**: Log rejection reasons, keep change request active for retry

### Step 5: Symbol Change Processing
If `symbols_change_results` is provided:
- **Accepted Changes**: Update `sessions.session_symbols` with new active states, log successful application, clear the change request
- **Rejected Changes**: Log rejection reasons, keep change request active for retry

### Step 6: Pending Changes Check
The server checks for pending configuration or symbol changes:
- Compare `robot_config` vs canonical `session_config` to generate diffs
- Compare desired vs current symbol states to generate diffs
- Return pending changes to robot if any

### Step 7: Session Event Logging
The server logs heartbeat events including:
- Heartbeat received
- Config changes accepted/rejected
- Symbol changes accepted/rejected
- Sequence validation failures

### Step 8: Cache Update
The server updates Redis cache with latest session data including last heartbeat timestamp, sequence number, and dynamic data.

## Configuration Change Processing

### Accepted Configuration Changes
When configuration changes are accepted:
- Update `sessions.robot_config` with applied values
- Log successful application in `session_events`
- Clear the change request

### Rejected Configuration Changes
When configuration changes are rejected:
- Log rejection reasons in `session_events`
- Keep change request active for retry

**Common Rejection Reasons:**
- Invalid value range
- Conflicting with current settings
- Feature not supported by robot version
- Temporary rejection - will retry

## Symbol Change Processing

### Accepted Symbol Changes
When symbol changes are accepted:
- Update `sessions.session_symbols` with new active states
- Log successful application in `session_events`
- Clear the change request

### Rejected Symbol Changes
When symbol changes are rejected:
- Log rejection reasons in `session_events`
- Keep change request active for retry

**Common Symbol Rejection Reasons:**
- Symbol not available in broker
- Insufficient margin for symbol
- Symbol temporarily unavailable
- Trading disabled for symbol
- Invalid symbol format

## Database Operations

### Heartbeat Update
The server updates the session record with dynamic data, sequence number, and last heartbeat timestamp.

### Configuration Update
When configuration changes are accepted, the server updates `sessions.robot_config` with new values.

### Symbol Update
When symbol changes are accepted, the server updates `sessions.session_symbols` with new active states.

### Change Request Clearing
When changes are fully processed, the server clears the change request fields.

## Security and Authentication

### Cache-Based JWT Token Validation
The server validates JWT tokens using:
1. JWT secret from Secrets Manager (cached)
2. JWT signature verification
3. Cache lookup for API key validation
4. License expiration check from cache

### Session Context Verification
The server verifies session context by checking:
- Session exists in database
- Session is marked as active
- Session belongs to authenticated license

### Sequence Replay Protection
The server validates sequence numbers to prevent replay attacks:
- Sequence must be strictly greater than current stored sequence
- Rejects duplicate or out-of-order sequences
- Logs security events for replay attempts

## Response Structure

### Successful Response (200 OK)

```json
{
  "status": "success",
  "sequence": 12345,
  "server_timestamp": "2024-01-15T10:29:47.123Z",
  "heartbeat_interval_seconds": 60,
  "robot_config_change_request": [
    {
      "field_name": "max_trades_per_day",
      "new_value": 30
    },
    {
      "field_name": "stop_loss_pips",
      "new_value": 12
    }
  ],
  "session_symbols_change_request": [
    {
      "symbol": "GBPJPY",
      "active_to_trade": true
    },
    {
      "symbol": "AUDUSD",
      "active_to_trade": false
    }
  ],
  "server_notifications": [
    {
      "type": "warning",
      "message": "License expires in 3 days",
      "priority": "medium"
    }
  ]
}
```

### Response Fields

#### Core Fields
- **`status`**: "success" for normal 200 responses; **`termination_requested`** when the server requests session termination (SDK then fires termination event and calls `/robot/end`)
- **`termination_reason`**: Present when status is `termination_requested`; human-readable reason string
- **`sequence`**: Echoed sequence number from request
- **`server_timestamp`**: Server timestamp in ISO 8601 format (optional)
- **`heartbeat_interval_seconds`**: Server-specified interval between heartbeats; SDK clamps to maximum 300 seconds

#### Configuration Changes (Robots only)
- **`robot_config_change_request`**: Array of pending configuration updates (null if none); each item has `field_name` and `new_value`. Processed by SDK only for Expert Advisors; Indicators ignore.

#### Symbol Changes (Robots only)
- **`session_symbols_change_request`**: Array of pending symbol activation changes (null if none); each item has `symbol` and `active_to_trade`. Processed by SDK only for Expert Advisors; Indicators ignore.

#### Notifications
- **`server_notifications`**: Array of server-generated notifications and alerts

## Error Scenarios

### 1. Missing Authorization (401)
```json
{
  "type": "https://api.themarketrobo.com/problems/authentication-error",
  "title": "Authentication Failed",
  "status": 401,
  "detail": "Authorization header missing or malformed",
  "instance": "/api/v1/robots/heartbeat",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "auth_error_code": "AUTH_MISSING"
}
```

### 2. Invalid JWT Token (401)
```json
{
  "type": "https://api.themarketrobo.com/problems/authentication-error",
  "title": "Authentication Failed",
  "status": 401,
  "detail": "JWT token signature is invalid",
  "instance": "/api/v1/robots/heartbeat",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "auth_error_code": "TOKEN_INVALID"
}
```

### 3. Expired JWT Token (401)
```json
{
  "type": "https://api.themarketrobo.com/problems/authentication-error",
  "title": "Authentication Failed",
  "status": 401,
  "detail": "JWT token has expired",
  "instance": "/api/v1/robots/heartbeat",
  "timestamp": "2024-01-15T10:35:00.000Z",
  "request_id": "req_abc123def456",
  "auth_error_code": "TOKEN_EXPIRED",
  "details": {
    "expired_at": "2024-01-15T10:30:00Z",
    "current_time": "2024-01-15T10:35:00Z"
  }
}
```

### 4. Invalid Sequence (409)
```json
{
  "type": "https://api.themarketrobo.com/problems/session-error",
  "title": "Session Error",
  "status": 409,
  "detail": "Invalid or duplicate sequence number",
  "instance": "/api/v1/robots/heartbeat",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "session_error_code": "SEQUENCE_INVALID",
  "context": {
    "expected_sequence": 12346
  }
}
```
Or with `current_sequence` instead of `expected_sequence`. The SDK syncs its local sequence from this context and resets confirmation state so the next heartbeat uses the correct sequence. Sequence is only incremented after a successful 200 response.
```json
{
  "type": "https://api.themarketrobo.com/problems/session-error",
  "title": "Session Error",
  "status": 409,
  "detail": "Invalid or duplicate sequence number",
  "instance": "/api/v1/robots/heartbeat",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "session_error_code": "SEQUENCE_INVALID",
  "details": {
    "expected_minimum": 12346,
    "received": 12345
  }
}
```

### 5. License Expired (403)
```json
{
  "type": "https://api.themarketrobo.com/problems/authentication-error",
  "title": "Authentication Failed",
  "status": 403,
  "detail": "Your license has expired",
  "instance": "/api/v1/robots/heartbeat",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "auth_error_code": "LICENSE_EXPIRED",
  "details": {
    "expired_at": "2024-01-15T10:30:00Z"
  }
}
```

### 6. Session Not Found (404)
```json
{
  "type": "https://api.themarketrobo.com/problems/session-error",
  "title": "Session Error",
  "status": 404,
  "detail": "Robot session not found or deleted",
  "instance": "/api/v1/robots/heartbeat",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "session_error_code": "SESSION_NOT_FOUND"
}
```

## Data Flow Diagrams

### Heartbeat Processing Flow
```
Robot Heartbeat Request
    ↓
API Gateway + JWT Authorizer
    ↓
Lambda Handler Validation
    ↓
Session & Sequence Check
    ↓
Dynamic Data Update
    ↓
Process Change Results
    ↓
Check Pending Changes
    ↓
Update Cache
    ↓
Response Construction
    ↓
Robot Response
```

### Configuration Change Flow (EAs only)
```
Server Config Request → Robot Receives (Ignored by Indicators)
    ↓
Robot Applies Changes
    ↓
Robot Reports Results in Heartbeat
    ↓
Server Processes Results
    ↓
Server Logs Acceptance/Rejection
    ↓
Server Clears/Updates Requests
```

### Symbol Change Flow (EAs only)
```
Server Symbol Request → Robot Receives (Ignored by Indicators)
    ↓
Robot Validates Symbols
    ↓
Robot Reports Results in Heartbeat
    ↓
Server Updates Symbol States
    ↓
Server Logs Events
    ↓
Server Clears Requests
```

## Performance Considerations

### Database Optimization
- Composite indexes for heartbeat queries
- Session events partitioning by date
- Optimized sequence validation queries

### Caching Strategy
- Redis cache for session data
- JWT validation cache
- License expiration cache

### Batch Processing
- Efficient processing of multiple change results
- Bulk database operations for accepted changes
- Batch logging for rejected changes

## SDK Process for Robot

### Three-Layer Communication Architecture
The SDK manages communication between Server and Robot while handling data persistence:
- **Server ↔ SDK**: HTTP heartbeat requests with configuration/symbol changes
- **SDK ↔ Robot**: Parameter validation, updates, and notifications
- **Internal SDK**: Data persistence, token management, change tracking

### Heartbeat Data Persistence Mechanism
The SDK maintains an internal cache to handle token expiration scenarios:

**SDK Internal Process:**

1. **Pre-Heartbeat Token Validation**
   - Decode JWT payload locally (base64) and check `exp` against current time
   - If token expires within threshold (default **60 seconds** in SDK, `SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD`): cache current heartbeat data, call `/robot/refresh` first, then retry heartbeat with cached data
   - Ensure no data loss during token transitions

2. **Heartbeat Data Collection**
   - Collect account information using MQL5 AccountInfo
   - Calculate performance metrics (profit, drawdown) via `CDataCollectorService.get_dynamic_data()`
   - For **Robots only**: gather any pending config_change_results and symbols_change_results; **Indicators** omit both

3. **Send Heartbeat Request**
   - POST to **`/robot/heartbeat`** (relative to `SDK_API_BASE_URL`) with Bearer token
   - Payload: sequence (monotonic), timestamp (ISO 8601 via **TimeLocal()**-derived value so heartbeats continue when market is closed), dynamic_data, and for Robots optional config_change_results and symbols_change_results
   - On 200: process response (interval, termination_requested, change requests for Robots); increment sequence; clear pending results; use **TimeLocal()** for next send time
   - On 409: read context.expected_sequence or context.current_sequence; sync sequence; reset confirmation state; retry on next interval

### Response Processing

**Successful Heartbeat Confirmation:**
1. Clear pending data - server confirmed receipt
2. Apply server-specified interval with safety limit (max 300 seconds)
3. Process configuration change requests (if any)
4. Process symbol change requests (if any)

**Configuration Change Management:**
The server sends array of configuration change requests. For each request:
1. Validate using developer's validation method
2. If valid: Update SDK internal configuration, notify robot via callback, update developer's config object
3. If invalid: Collect rejection reason from validation
4. Store results for next heartbeat with proper status and results array

**Symbol Change Management:**
The server sends array of symbol change requests. For each request:
1. Attempt to change symbol trading status
2. If successful: Update internal symbol list, notify robot via callback
3. If failed: Collect failure reason
4. Store results for next heartbeat with proper status and results array

### Error Recovery Strategy

**Token Expiration During Heartbeat:**
1. Preserve Data: Keep all heartbeat data in cache
2. Token Refresh: Call refresh endpoint to get new JWT
3. Data Integrity: Ensure configuration/symbol change results are preserved
4. Retry Transmission: Resend exact same data with new token
5. Confirmation Wait: Wait for successful response before clearing cache

**Network Failure Handling:**
- Implement exponential backoff for retry attempts
- Maintain cached heartbeat data across all retry attempts
- Resume normal operation when connectivity restored
- Log all failures for debugging but preserve data integrity

**Configuration Change Data Persistence:**
SDK must persist configuration change results until server confirms. Results include status and results array with proper structure.

**Symbol Change Data Persistence:**
Same principle applies to symbol change results - SDK maintains results until server confirmation.

**Sequence Number Management:**
- Maintain monotonically increasing sequence counter
- Handle sequence validation errors from server
- Don't increment sequence until server confirms receipt
- Reset sequence if server requests (edge case)

### Developer Integration

**Required Callback Interface (Robots only):**
- **`on_config_changed(string event_json)`**: Called when server configuration change request has been applied (and validated)
- **`on_symbol_changed(string event_json)`**: Called when server symbol change request has been applied

Indicators do not receive config or symbol change requests; these callbacks are not used for Custom Indicators.

**SDK Automatic Operations:**
The following operations happen automatically without developer intervention:
- Token Management: Check expiration, refresh as needed
- Data Persistence: Cache heartbeat data if token expires
- Parameter Validation: Use developer's validation methods
- Change Results: Report success/failure to server with proper structure
- Sequence Management: Maintain monotonic counters
- Network Recovery: Handle failures with exponential backoff

**Developer Responsibilities:**
1. Implement Callback Interface: Handle configuration and symbol changes
2. Provide Validation Methods: In configuration object for parameter validation
3. React to Changes: Update robot behavior based on server parameter changes
4. Error Handling: Handle critical errors reported through callbacks (SDK handles communication errors)

## Monitoring and Alerting

### Key Metrics
- Heartbeat success rate
- Sequence validation failures
- Change acceptance rates (config and symbols)
- Token refresh frequency

### Alert Conditions
- Heartbeat failure rate > 5% over 5 minutes
- Sequence validation failures > 10 per minute
- Session heartbeat older than 5 minutes
- Database update failures > 1 per minute

This comprehensive heartbeat flow ensures reliable, secure communication between trading robots and the server, with proper sequencing, change management, and real-time data synchronization.
