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

## Robot Request Data Structure

### HTTP Request Format
```
POST /heartbeat
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "session_id": "integer (required)",
  "sequence": "integer (required, monotonic incrementing)",
  "timestamp": "string (required, ISO 8601 timestamp)",
  "dynamic_data": {
    "account_balance": 10000.50,
    "account_equity": 10125.30,
    "account_margin": 250.00,
    "account_free_margin": 9875.30,
    "account_credit": 0.0,
    "account_profit": 125.30,
    "account_currency": "USD",
    "positions": [
      {
        "ticket": 12345678,
        "symbol": "EURUSD",
        "type": "BUY",
        "volume": 0.01,
        "open_price": 1.0845,
        "current_price": 1.0860,
        "profit": 15.00,
        "swap": -0.50,
        "commission": -0.10,
        "open_time": "2024-01-15T10:00:00Z",
        "magic_number": 12345,
        "comment": "Robot Trade"
      }
    ],
    "orders": [
      {
        "ticket": 87654321,
        "symbol": "GBPUSD",
        "type": "BUY_LIMIT",
        "volume": 0.02,
        "price": 1.2720,
        "stop_loss": 1.2650,
        "take_profit": 1.2850,
        "open_time": "2024-01-15T09:30:00Z",
        "magic_number": 12345,
        "comment": "Pending Order"
      }
    ],
    "daily_stats": {
      "trades_today": 8,
      "winning_trades": 6,
      "losing_trades": 2,
      "total_pnl": 125.30,
      "max_drawdown": 25.00,
      "win_rate": 75.0
    },
    "market_data": {
      "server_time": "2024-01-15T10:29:45Z",
      "connection_status": "connected",
      "spread_eurusd": 1.2,
      "spread_gbpusd": 1.8
    },
    "robot_status": {
      "is_trading_enabled": true,
      "last_trade_time": "2024-01-15T10:25:00Z",
      "active_symbols": ["EURUSD", "GBPUSD"],
      "error_messages": [],
      "warning_messages": ["High volatility detected"]
    }
  },
  "config_change_results": {
    "request_id": "config_req_456",
    "status": "accepted",
    "applied_changes": {
      "risk_level": "medium",
      "max_trades_per_day": 25
    }
  },
  "symbols_change_results": {
    "request_id": "symbol_req_789",
    "status": "rejected",
    "rejected_symbols": [
      {
        "symbol": "GBPJPY",
        "reason": "Symbol not available in broker"
      }
    ]
  }
}
```

### Key Request Fields

#### Required Fields
- **`session_id`**: Unique session identifier from /start response
- **`sequence`**: Monotonic counter (must be > previous sequence)
- **`timestamp`**: Current robot timestamp in ISO 8601 format

#### Dynamic Data Object
The robot sends comprehensive real-time trading data:

**Account Information:**
- Balance, equity, margin, free margin
- Credit, profit, currency

**Positions Array:**
- All open positions with detailed information
- Profit/loss, swap, commission
- Magic numbers, comments, timestamps

**Orders Array:**
- All pending orders
- Entry conditions, stop loss, take profit

**Daily Statistics:**
- Trade counts and win rates
- P&L and drawdown information

**Market Data:**
- Server time synchronization
- Connection status
- Current spreads

**Robot Status:**
- Trading enable/disable state
- Active symbols list
- Error and warning messages

#### Change Results Objects
The robot reports results of server-requested changes:

**Config Change Results:**
- `request_id`: Identifier from server request
- `status`: "accepted" or "rejected"
- `applied_changes`: Actually applied configuration values

**Symbols Change Results:**
- `request_id`: Identifier from server request
- `status`: "accepted" or "rejected"
- `rejected_symbols`: Array of rejected symbols with reasons

## Server Processing Flow

### Step 1: Cache-Based JWT Validation
```python
# Extract JWT token from Authorization header
jwt_token = extract_bearer_token(event.headers)

# New validation flow using cache
def validate_jwt_with_cache(jwt_token: str) -> Dict[str, Any]:
    # 1. Verify JWT signature and structure
    try:
        jwt_secret = secrets_manager.get_cached_secret('jwt-signing-secret')
        payload = jwt.decode(jwt_token, jwt_secret, algorithms=['HS256'])
    except jwt.ExpiredSignatureError:
        return {'error': 'TOKEN_EXPIRED', 'action': 'refresh_required'}
    except jwt.InvalidTokenError:
        return {'error': 'TOKEN_INVALID', 'action': 'restart_required'}
    
    # 2. Check JWT expiration locally
    now = int(datetime.utcnow().timestamp())
    if payload['exp'] <= now:
        return {'error': 'TOKEN_EXPIRED', 'action': 'refresh_required'}
    
    # 3. Check cache for API key validation
    cache_key = f"jwt:{jwt_token}"
    cache_data = redis_client.get(cache_key)
    
    if not cache_data:
        return {'error': 'TOKEN_NOT_IN_CACHE', 'action': 'refresh_required'}
    
    cache_info = json.loads(cache_data)
    
    # 4. Check license expiration from cache
    license_expires_at = datetime.fromisoformat(cache_info['license_expires_at'])
    if license_expires_at <= datetime.utcnow():
        return {'error': 'LICENSE_EXPIRED', 'action': 'restart_required'}
    
    return {
        'valid': True,
        'session_id': payload['session_id'],
        'license_id': payload['license_id'],
        'api_key': cache_info['api_key'],
        'payload': payload
    }

# Validate JWT using new cache-based method
validation_result = validate_jwt_with_cache(jwt_token)
if 'error' in validation_result:
    return create_error_response(validation_result)
```

### Step 2: Session and Sequence Validation
```sql
SELECT sequence, status, last_heartbeat_at
FROM sessions
WHERE id = %s AND status = 'active'
```

**Sequence Validation Logic:**
- Sequence must be greater than current stored sequence
- Prevents replay attacks and ensures monotonic ordering
- Rejects duplicate or out-of-order sequences

**Session Validation Checks:**
- Session exists and is active
- Session belongs to authenticated license
- Session hasn't been terminated

### Step 3: Dynamic Data Update
```sql
UPDATE sessions
SET last_heartbeat_at = NOW(),
    dynamic_data = %s,
    sequence = %s,
    updated_at = NOW()
WHERE id = %s AND status = 'active'
```

**Data Storage:**
- `dynamic_data`: Complete JSON payload from robot
- `last_heartbeat_at`: Timestamp of successful heartbeat
- `sequence`: Updated sequence number
- `updated_at`: Database update timestamp

### Step 4: Configuration Change Processing
```python
if config_change_results:
    process_config_change_results(session_id, config_change_results)
```

**Accepted Changes:**
- Update `sessions.robot_config` with applied values
- Log successful application in `session_events`
- Clear the change request

**Rejected Changes:**
- Log rejection reasons in `session_events`
- Keep change request active for retry

### Step 5: Symbol Change Processing
```python
if symbols_change_results:
    process_symbols_change_results(session_id, symbols_change_results)
```

**Accepted Changes:**
- Update `sessions.session_symbols` with new active states
- Log successful application in `session_events`
- Clear the change request

**Rejected Changes:**
- Log rejection reasons in `session_events`
- Keep change request active for retry

### Step 6: Pending Changes Check
```sql
SELECT robot_config_change_request, session_symbols_change_request,
       robot_config, session_symbols
FROM sessions WHERE id = %s
```

**Configuration Changes:**
- Compare `robot_config` vs canonical `session_config`
- Generate diffs for mismatched fields
- Return pending changes to robot

**Symbol Changes:**
- Compare desired vs current symbol states
- Generate diffs for `active_to_trade` mismatches
- Return pending changes to robot

### Step 7: Session Event Logging
```sql
INSERT INTO session_events (
    session_id, event_type, event_data, created_at
) VALUES (%s, %s, %s, NOW())
```

**Logged Events:**
- Heartbeat received
- Config changes accepted/rejected
- Symbol changes accepted/rejected
- Sequence validation failures

### Step 8: Cache Update
```python
# Update Redis cache with latest session data
session_cache.cache_session(session_id, {
    'last_heartbeat': datetime.utcnow().isoformat(),
    'sequence': sequence,
    'dynamic_data': dynamic_data
})
```

## Configuration Change Processing

### Accepted Configuration Changes
```python
def apply_config_changes(session_id: str, changes: Dict[str, Any]):
    # Get current robot_config
    current_config = json.loads(db_get_robot_config(session_id))

    # Apply changes using dot notation
    for field_path, value in changes.items():
        set_nested_value(current_config, field_path, value)

    # Update database
    db_update_robot_config(session_id, json.dumps(current_config))
```

**Field Path Examples:**
- `"risk_level"`: Direct field update
- `"trading_hours.start"`: Nested object update
- `"indicators.0.period"`: Array element update

### Rejected Configuration Changes
```python
def log_config_rejection(session_id: int, field_path: str, reason: str):
    event_data = {
        'field_path': field_path,
        'reason': reason,
        'result': 'rejected'
    }

    db_insert_session_event(session_id, 'config_change_rejected', event_data)
```

**Common Rejection Reasons:**
- "Invalid value range"
- "Conflicting with current settings"
- "Feature not supported by robot version"
- "Temporary rejection - will retry"

## Symbol Change Processing

### Accepted Symbol Changes
```python
def apply_symbol_changes(session_id: str, changes: Dict[str, bool]):
    # Get current session_symbols
    current_symbols = json.loads(db_get_session_symbols(session_id))

    # Update symbol activation status
    for symbol_name, active_to_trade in changes.items():
        for symbol in current_symbols:
            if symbol.get('symbol') == symbol_name:
                symbol['active_to_trade'] = active_to_trade
                break

    # Update database
    db_update_session_symbols(session_id, json.dumps(current_symbols))
```

### Rejected Symbol Changes
```python
def log_symbol_rejection(session_id: int, symbol: str, reason: str):
    event_data = {
        'symbol': symbol,
        'reason': reason,
        'result': 'rejected'
    }

    db_insert_session_event(session_id, 'symbol_change_rejected', event_data)
```

**Common Symbol Rejection Reasons:**
- "Symbol not available in broker"
- "Insufficient margin for symbol"
- "Symbol temporarily unavailable"
- "Trading disabled for symbol"
- "Invalid symbol format"

## Database Operations

### Heartbeat Update Query
```sql
UPDATE sessions
SET last_heartbeat_at = NOW(),
    dynamic_data = $1,
    sequence = $2,
    updated_at = NOW()
WHERE id = $3 AND status = 'active'
RETURNING last_heartbeat_at
```

### Configuration Update Query
```sql
UPDATE sessions
SET robot_config = $1, updated_at = NOW()
WHERE id = $2
```

### Symbol Update Query
```sql
UPDATE sessions
SET session_symbols = $1, updated_at = NOW()
WHERE id = $2
```

### Change Request Clearing
```sql
UPDATE sessions
SET robot_config_change_request = NULL, updated_at = NOW()
WHERE id = $1
```

## Security and Authentication

### Cache-Based JWT Token Validation
```python
def validate_robot_token_with_cache(token: str) -> Dict[str, Any]:
    try:
        # 1. Get JWT secret from Secrets Manager (cached)
        jwt_secret = secrets_manager.get_cached_secret('jwt-signing-secret')
        
        # 2. Decode and verify JWT signature 
        payload = jwt.decode(token, jwt_secret, algorithms=['HS256'])

        # 3. Verify basic claims
        required_claims = ['iss', 'aud', 'session_id', 'license_id', 'exp']
        for claim in required_claims:
            if claim not in payload:
                return {'error': 'MISSING_CLAIMS'}

        # 4. Check expiration (robot should have done this already)
        now = int(datetime.utcnow().timestamp())
        if payload['exp'] <= now:
            return {'error': 'TOKEN_EXPIRED'}

        # 5. Validate against cache
        cache_key = f"jwt:{token}"
        cache_data = redis_client.get(cache_key)
        
        if not cache_data:
            return {'error': 'TOKEN_NOT_IN_CACHE'}
        
        cache_info = json.loads(cache_data)
        
        # 6. Check license expiration from cache
        license_expires_at = datetime.fromisoformat(cache_info['license_expires_at'])
        if license_expires_at <= datetime.utcnow():
            return {'error': 'LICENSE_EXPIRED'}

        # 7. Return successful validation with context
        return {
            'valid': True,
            'session_id': payload['session_id'],
            'license_id': payload['license_id'],
            'api_key': cache_info['api_key'],
            'payload': payload
        }

    except jwt.ExpiredSignatureError:
        return {'error': 'TOKEN_EXPIRED'}
    except jwt.InvalidSignatureError:
        return {'error': 'INVALID_TOKEN'}
    except json.JSONDecodeError:
        return {'error': 'CACHE_CORRUPTION'}
```

### Session Context Verification (Simplified)
```python
def validate_session_context(session_id: int) -> bool:
    # Quick database check only for session status
    # Most validation now done through cache
    db_session = db_get_session_status(session_id)
    
    return db_session and db_session['status'] == 'active'
```

### Sequence Replay Protection
```python
def validate_sequence(session_id: int, new_sequence: int) -> bool:
    current_sequence = db_get_current_sequence(session_id)

    # Sequence must be strictly greater than current
    if new_sequence <= current_sequence:
        log_security_event('SEQUENCE_REPLAY_ATTEMPT', {
            'session_id': session_id,
            'attempted_sequence': new_sequence,
            'current_sequence': current_sequence
        })
        return False

    return True
```

## Response Structure

### Successful Response (200 OK)
```json
{
  "status": "success",
  "sequence": 12345,
  "server_timestamp": "2024-01-15T10:29:47.123Z",
  "heartbeat_interval_seconds": 60,
  "robot_config_change_request": {
    "max_trades_per_day": 30,
    "stop_loss_pips": 12,
    "take_profit_pips": 20
  },
  "session_symbols_change_request": {
    "symbols": {
      "GBPJPY": true,
      "AUDUSD": false
    }
  },
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
- **`status`**: Always "success" for 200 responses
- **`sequence`**: Echoed sequence number from request
- **`server_timestamp`**: Server timestamp in ISO 8601 format
- **`heartbeat_interval_seconds`**: Server-specified interval between heartbeats (1-300 seconds)

#### Configuration Changes
- **`robot_config_change_request`**: Pending configuration updates (null if none)

#### Symbol Changes
- **`session_symbols_change_request`**: Pending symbol activation changes (null if none)

#### Notifications
- **`server_notifications`**: Array of server-generated notifications

### Configuration Change Request Format
```json
{
  "risk_level": "high",
  "max_trades_per_day": 50,
  "indicators": {
    "rsi_period": 14,
    "macd_fast": 12
  },
  "trading_hours": {
    "start": "09:00",
    "end": "23:00"
  }
}
```

### Symbol Change Request Format
```json
{
  "symbols": {
    "EURUSD": true,
    "GBPUSD": true,
    "GBPJPY": false,
    "AUDUSD": true
  }
}
```

## Robot-Side Response Caching Strategy

### Handling Token Expiration During Heartbeat
Since robots can now decode JWT tokens locally, they should check token expiration before sending heartbeat requests. However, there may be edge cases where a token expires between the check and the actual request.

```javascript
class RobotHeartbeatManager {
    constructor() {
        this.pendingHeartbeatData = null;
        this.lastSuccessfulHeartbeat = null;
    }

    async sendHeartbeat(heartbeatData) {
        // 1. Check token expiration locally first
        if (this.isTokenExpired()) {
            // Cache the heartbeat data and refresh token instead
            this.pendingHeartbeatData = heartbeatData;
            return await this.refreshTokenAndRetry();
        }

        try {
            // 2. Send heartbeat normally
            const response = await this.httpClient.post('/heartbeat', heartbeatData);
            
            // 3. Clear pending data on success
            this.pendingHeartbeatData = null;
            this.lastSuccessfulHeartbeat = response;
            
            return response;
            
        } catch (error) {
            if (error.code === 'TOKEN_EXPIRED') {
                // 4. Cache data and refresh token
                this.pendingHeartbeatData = heartbeatData;
                return await this.refreshTokenAndRetry();
            }
            throw error;
        }
    }

    async refreshTokenAndRetry() {
        try {
            // 1. Call server's /refresh endpoint to get new JWT
            const refreshResponse = await this.callRefreshEndpoint();
            
            // 2. Update current JWT token (robot doesn't modify it)
            this.currentJWT = refreshResponse.jwt;
            
            // 3. Retry with cached data if available
            if (this.pendingHeartbeatData) {
                const cachedData = this.pendingHeartbeatData;
                this.pendingHeartbeatData = null;
                return await this.sendHeartbeat(cachedData);
            }
            
        } catch (refreshError) {
            // If refresh fails, may need to restart session
            if (refreshError.code === 'LICENSE_EXPIRED') {
                await this.restartSession();
            }
            throw refreshError;
        }
    }

    isTokenExpired() {
        try {
            // Robot decodes JWT payload (server provided it unencrypted)
            const payload = JSON.parse(atob(this.currentJWT.split('.')[1]));
            const now = Math.floor(Date.now() / 1000);
            return payload.exp <= (now + 60); // 60 second buffer
        } catch (error) {
            return true; // Assume expired if can't decode
        }
    }

    async callRefreshEndpoint() {
        // Robot sends existing JWT to refresh endpoint
        // Server returns new JWT with same structure
        return await this.httpClient.post('/refresh', {
            jwt_token: this.currentJWT
        });
    }
}
```

### Critical Response Data to Cache
Robots should prioritize caching the following data:
- **Change Results**: Configuration and symbol change confirmations
- **Trading Decisions**: Buy/sell signals that haven't been processed
- **Account Updates**: Critical account state changes
- **Error Messages**: Important warnings that need server attention

## Error Scenarios

### 1. Missing Authorization (401)
```json
{
  "error": "UNAUTHORIZED",
  "message": "Authorization header missing or malformed",
  "code": "AUTH_MISSING",
  "action_required": "Include valid JWT token in Authorization Bearer header"
}
```

### 2. Invalid JWT Token (401)
```json
{
  "error": "INVALID_TOKEN",
  "message": "JWT token signature is invalid",
  "code": "TOKEN_INVALID", 
  "action_required": "Restart session with /start endpoint"
}
```

### 3. Expired JWT Token (401)
```json
{
  "error": "TOKEN_EXPIRED",
  "message": "JWT token has expired",
  "code": "TOKEN_EXPIRED",
  "details": {
    "expired_at": "2024-01-15T10:30:00Z",
    "current_time": "2024-01-15T10:35:00Z"
  },
  "action_required": "Refresh token using /refresh endpoint"
}
```

### 4. JWT Not In Cache (401)
```json
{
  "error": "TOKEN_NOT_IN_CACHE", 
  "message": "JWT token not found in validation cache",
  "code": "TOKEN_NOT_IN_CACHE",
  "action_required": "Refresh token using /refresh endpoint"
}
```

### 5. License Expired (403)
```json
{
  "error": "LICENSE_EXPIRED",
  "message": "Your license has expired", 
  "code": "LICENSE_EXPIRED",
  "details": {
    "expired_at": "2024-01-15T10:30:00Z"
  },
  "action_required": "Renew license through customer portal"
}
```

### 6. Invalid Sequence (409)
```json
{
  "error": "INVALID_SEQUENCE",
  "message": "Invalid or duplicate sequence number",
  "code": "SEQUENCE_INVALID",
  "details": {
    "expected_minimum": 12346,
    "received": 12345
  },
  "action_required": "Check sequence counter and ensure monotonic increment"
}
```

### 7. Cache Corruption (500)
```json
{
  "error": "CACHE_CORRUPTION",
  "message": "JWT cache data is corrupted", 
  "code": "CACHE_CORRUPTION",
  "action_required": "Refresh token using /refresh endpoint"
}

### 8. Session Not Found (404)
```json
{
  "error": "SESSION_NOT_FOUND",
  "message": "Robot session not found or deleted",
  "code": "SESSION_NOT_FOUND", 
  "action_required": "Restart session with /start endpoint"
}
```

### 9. Session Not Active (409)
```json
{
  "error": "SESSION_NOT_ACTIVE",
  "message": "Session is not active",
  "code": "SESSION_INACTIVE",
  "action_required": "Restart session with /start endpoint"
}
```

### 10. Database Error (500)
```json
{
  "error": "INTERNAL_ERROR",
  "message": "Database operation failed",
  "code": "DATABASE_ERROR",
  "action_required": "Retry heartbeat in a few moments"
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

### Configuration Change Flow
```
Server Config Request → Robot Receives
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

### Symbol Change Flow
```
Server Symbol Request → Robot Receives
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
```sql
-- Composite indexes for heartbeat queries
CREATE INDEX idx_sessions_active_sequence ON sessions(id, active, sequence);
CREATE INDEX idx_sessions_heartbeat_time ON sessions(last_heartbeat_at);

-- Session events partitioning by date
CREATE TABLE session_events_y2024m01 PARTITION OF session_events
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

### Caching Strategy
```python
# Redis cache structure
session_cache = {
    f"session:{session_id}": {
        "last_heartbeat": "2024-01-15T10:29:45Z",
        "sequence": 12345,
        "dynamic_data": {...},
        "expires_at": 1234567890
    }
}
```

### Batch Processing
```python
# Process multiple change results efficiently
def batch_process_changes(session_id: int, changes: List[Dict]) -> Dict[str, Any]:
    accepted = []
    rejected = []

    for change in changes:
        if validate_change(change):
            accepted.append(change)
        else:
            rejected.append(change)

    # Bulk database operations
    bulk_apply_accepted(session_id, accepted)
    bulk_log_rejected(session_id, rejected)

    return {"accepted": len(accepted), "rejected": len(rejected)}
```

## SDK Process for Robot

### Three-Layer Communication Architecture
The SDK manages communication between Server and Robot while handling data persistence:
- **Server ↔ SDK**: HTTP heartbeat requests with configuration/symbol changes
- **SDK ↔ Robot**: Parameter validation, updates, and notifications
- **Internal SDK**: Data persistence, token management, change tracking

### Heartbeat Data Persistence Mechanism
The SDK maintains an internal cache to handle token expiration scenarios:

```mql5
// SDK internal data management
class HeartbeatDataManager {
    private:
        HeartbeatData pending_heartbeat_data;  // Data waiting for server confirmation
        bool data_pending;                     // Flag indicating unconfirmed data
        ConfigChangeResults pending_config_results;
        SymbolChangeResults pending_symbol_results;
        int heartbeat_interval_seconds;
        int max_interval_seconds; // Hardcoded to 300 (5 minutes)
}
```

**SDK Internal Process:**

1. **Pre-Heartbeat Token Validation**
   - Decode JWT payload locally using base64 decoding
   - Check `exp` field against current timestamp  
   - If token expires within 2 minutes:
     - **Cache current heartbeat data** in `pending_heartbeat_data`
     - Call refresh endpoint first
     - **Retry heartbeat with cached data** after successful refresh
     - Ensure no data loss during token transitions

2. **Heartbeat Data Collection**
   - Collect account information using `AccountInfo*()` functions
   - Gather open positions using `PositionTotal()` and `PositionGetString/Integer/Double()`
   - Collect pending orders using `OrdersTotal()` and `OrderGet*()`
   - Calculate daily statistics from internal tracking
   - Get market data using `SymbolInfoTick()` and `SymbolInfoDouble()`

3. **Configuration Change Results Processing**
   - Retrieve any pending configuration changes from previous heartbeat responses
   - Validate changes using developer's configuration object validation methods
   - If **valid**: Apply changes, update SDK memory, notify robot via callback
   - If **invalid**: Prepare rejection reason for server response
   - Include validation results in `config_change_results`

4. **Symbol Change Results Processing**
   - Process any pending symbol `active_to_trade` changes from previous heartbeat
   - Attempt to modify symbol trading status in MetaTrader
   - If **successful**: Update internal symbol list, notify robot via callback
   - If **failed**: Prepare rejection reason with specific error message
   - Include change results in `symbols_change_results`

5. **Send Heartbeat Request**
   - Include incremental sequence number (monotonic counter)
   - Include pending configuration/symbol change results
   - Send all collected data in structured format
   - Handle network errors with retry logic
   - Mark data as "waiting for confirmation"

### Response Processing

**Successful Heartbeat Confirmation:**
```mql5
void ProcessHeartbeatResponse(HeartbeatResponse& response) {
    // 1. Clear pending data - server confirmed receipt
    pending_heartbeat_data.Clear();
    data_pending = false;
    
    // 2. Apply server-specified interval with safety limit  
    int server_interval = response.heartbeat_interval_seconds;
    heartbeat_interval_seconds = MathMin(server_interval, max_interval_seconds);
    ResetHeartbeatTimer();
    
    // 3. Process configuration change requests (if any)
    ProcessConfigurationChanges(response.robot_config_change_request);
    
    // 4. Process symbol change requests (if any)  
    ProcessSymbolChanges(response.session_symbols_change_request);
}
```

**Configuration Change Management:**
The server sends **only changed parameters**, not complete configuration:

```mql5
void ProcessConfigurationChanges(ConfigChangeRequest& request) {
    if (request.IsEmpty()) return; // No changes
    
    ConfigChangeResults results;
    results.request_id = request.id;
    
    // Process each changed parameter individually
    foreach (string field_name in request.changed_fields) {
        var new_value = request.GetFieldValue(field_name);
        
        // 1. Validate using developer's validation method
        bool is_valid = developer_config.CallValidationMethod(field_name, new_value);
        
        if (is_valid) {
            // 2. Update SDK internal configuration
            sdk_config.SetFieldValue(field_name, new_value);
            
            // 3. Notify robot about the change
            string old_value = developer_config.GetFieldValue(field_name);
            robot_callback.OnConfigurationChanged(field_name, old_value, new_value);
            
            // 4. Update developer's config object
            developer_config.SetFieldValue(field_name, new_value);
            
            results.AddAccepted(field_name, new_value);
        } else {
            // 5. Collect rejection reason from validation
            string reason = developer_config.GetValidationError(field_name, new_value);
            results.AddRejected(field_name, reason);
        }
    }
    
    // Store results for next heartbeat
    pending_config_results = results;
}
```

**Symbol Change Management:**
Handle `active_to_trade` status changes for specific symbols:

```mql5
void ProcessSymbolChanges(SymbolChangeRequest& request) {
    if (request.IsEmpty()) return; // No changes
    
    SymbolChangeResults results;
    results.request_id = request.id;
    
    // Process each symbol activation/deactivation
    foreach (string symbol in request.symbol_changes) {
        bool new_status = request.GetSymbolStatus(symbol);
        bool old_status = GetCurrentSymbolStatus(symbol);
        
        if (new_status != old_status) {
            // 1. Attempt to change symbol trading status
            bool change_successful = UpdateSymbolTradingStatus(symbol, new_status);
            
            if (change_successful) {
                // 2. Update internal symbol list
                UpdateInternalSymbolStatus(symbol, new_status);
                
                // 3. Notify robot about the change
                robot_callback.OnSymbolStatusChanged(symbol, new_status);
                
                results.AddAccepted(symbol, new_status);
            } else {
                // 4. Collect failure reason
                string reason = GetSymbolChangeErrorReason(symbol, new_status);
                results.AddRejected(symbol, reason);
            }
        }
    }
    
    // Store results for next heartbeat
    pending_symbol_results = results;
}
```

### Error Recovery Strategy

**Token Expiration During Heartbeat:**
```mql5
bool SendHeartbeatWithTokenCheck() {
    // 1. Check token expiration before sending
    if (IsTokenNearExpiration()) {
        // Cache current heartbeat data
        pending_heartbeat_data = CollectHeartbeatData();
        data_pending = true;
        
        // 2. Refresh token first
        if (!RefreshToken()) {
            return false; // Refresh failed
        }
        
        // 3. Send cached data with new token
        return SendHeartbeat(pending_heartbeat_data);
    }
    
    // Normal heartbeat flow
    return SendHeartbeat(CollectHeartbeatData());
}
```

**Heartbeat Rejection Recovery:**
If heartbeat is rejected due to expired token:
1. **Preserve Data**: Keep all heartbeat data in `pending_heartbeat_data`
2. **Token Refresh**: Call refresh endpoint to get new JWT
3. **Data Integrity**: Ensure configuration/symbol change results are preserved
4. **Retry Transmission**: Resend exact same data with new token
5. **Confirmation Wait**: Wait for successful response before clearing cache

**Network Failure Handling:**
- Implement exponential backoff for retry attempts
- **Critical**: Maintain `pending_heartbeat_data` across all retry attempts
- Resume normal operation when connectivity restored
- Log all failures for debugging but preserve data integrity

**Configuration Change Data Persistence:**
```mql5
// SDK must persist configuration change results until server confirms
class ConfigChangeTracker {
    private:
        ConfigChangeResults pending_results;
        bool results_pending;
        
    public:
        void AddResult(string field, string status, string reason) {
            pending_results.Add(field, status, reason);
            results_pending = true;
        }
        
        void OnServerConfirmation() {
            pending_results.Clear();
            results_pending = false;
        }
        
        ConfigChangeResults GetPendingResults() {
            return results_pending ? pending_results : ConfigChangeResults();
        }
};
```

**Symbol Change Data Persistence:**
Same principle applies to symbol change results - SDK maintains results until server confirmation.

**Sequence Number Management:**
- Maintain monotonically increasing sequence counter
- Handle sequence validation errors from server
- **Important**: Don't increment sequence until server confirms receipt
- Reset sequence if server requests (edge case)

### Developer Integration with Callback System

The SDK operates automatically but provides callbacks for robot awareness:

**Required Callback Interface:**
```mql5
// Developer must implement this interface
class IConfigUpdateCallback {
public:
    // Called when server changes configuration parameters
    virtual void OnConfigurationChanged(string field_name, string old_value, string new_value) = 0;
    
    // Called when server changes symbol trading permissions
    virtual void OnSymbolStatusChanged(string symbol, bool active_to_trade) = 0;
    
    // Optional: Called when heartbeat succeeds (for monitoring)
    virtual void OnHeartbeatSuccess(int sequence) { }
    
    // Optional: Called when heartbeat encounters errors (SDK handles retry)
    virtual void OnHeartbeatError(string error_message) { }
};
```

**Developer Implementation Example:**
```mql5
// Robot implementation of callback interface
class MyRobotEA : public IConfigUpdateCallback {
private:
    MyRobotConfig current_config;
    bool symbols_status[100]; // Track symbol trading permissions
    
public:
    // Server changed a configuration parameter
    void OnConfigurationChanged(string field_name, string old_value, string new_value) override {
        Print("Config update: ", field_name, " changed from ", old_value, " to ", new_value);
        
        // Robot reacts to specific parameter changes
        if (field_name == "risk_percentage") {
            RecalculatePositionSizes(StringToDouble(new_value));
        } 
        else if (field_name == "max_trades_per_day") {
            UpdateDailyTradeLimits(StringToInteger(new_value));
        }
        else if (field_name == "trading_mode") {
            SwitchTradingStrategy(new_value);
        }
        
        // Update local configuration object
        current_config.UpdateField(field_name, new_value);
    }
    
    // Server changed symbol trading permissions
    void OnSymbolStatusChanged(string symbol, bool active_to_trade) override {
        Print("Symbol ", symbol, " trading changed to: ", active_to_trade ? "ENABLED" : "DISABLED");
        
        if (active_to_trade) {
            EnableSymbolTrading(symbol);
            AddToWatchList(symbol);
        } else {
            DisableSymbolTrading(symbol);
            ClosePositionsForSymbol(symbol); // If configured to do so
        }
        
        // Update internal tracking
        UpdateSymbolStatus(symbol, active_to_trade);
    }
    
    // Optional: Monitor heartbeat status
    void OnHeartbeatSuccess(int sequence) override {
        // Can be used for connection monitoring
        last_successful_heartbeat = GetTickCount();
    }
    
    void OnHeartbeatError(string error_message) override {
        Print("Heartbeat error: ", error_message);
        // SDK handles retry automatically - robot just logs
    }
};
```

**SDK Automatic Operations:**
The following operations happen automatically without developer intervention:
- **Token Management**: Check expiration, refresh as needed
- **Data Persistence**: Cache heartbeat data if token expires
- **Parameter Validation**: Use developer's validation methods
- **Change Results**: Report success/failure to server
- **Sequence Management**: Maintain monotonic counters
- **Network Recovery**: Handle failures with exponential backoff

**Developer Responsibilities:**
1. **Implement Callback Interface**: Handle configuration and symbol changes
2. **Provide Validation Methods**: In configuration object for parameter validation
3. **React to Changes**: Update robot behavior based on server parameter changes
4. **Error Handling**: Handle critical errors reported through callbacks (SDK handles communication errors)

## Monitoring and Alerting

### Key Metrics
```python
# Heartbeat success rate
heartbeat_success_rate = (successful_heartbeats / total_heartbeats) * 100

# Sequence validation failures
sequence_failures = count_sequence_validation_errors()

# Change acceptance rates
config_acceptance_rate = (accepted_configs / total_config_requests) * 100
symbol_acceptance_rate = (accepted_symbols / total_symbol_requests) * 100
```

### Alert Conditions
- Heartbeat failure rate > 5% over 5 minutes
- Sequence validation failures > 10 per minute
- Session heartbeat older than 5 minutes
- Database update failures > 1 per minute

### Log Analysis
```sql
-- Heartbeat frequency analysis
SELECT
    session_id,
    COUNT(*) as heartbeat_count,
    AVG(EXTRACT(EPOCH FROM (created_at - lag(created_at) OVER (ORDER BY created_at)))) as avg_interval_seconds,
    MAX(created_at) as last_heartbeat
FROM session_events
WHERE event_type = 'heartbeat_received'
    AND created_at >= NOW() - INTERVAL '1 hour'
GROUP BY session_id;
```

## Sequence Number Management

### Monotonic Sequence Requirements
```python
class SequenceManager:
    def __init__(self):
        self.current_sequences = {}  # session_id -> last_sequence

    def validate_and_update(self, session_id: int, new_sequence: int) -> bool:
        """Validate sequence and update if valid"""
        current = self.current_sequences.get(session_id, 0)

        if new_sequence <= current:
            return False

        self.current_sequences[session_id] = new_sequence
        return True
```

### Sequence Recovery
```python
def handle_sequence_gap(session_id: int, expected: int, received: int) -> Dict[str, Any]:
    """Handle missing sequences (possible network issues)"""
    gap_size = received - expected

    if gap_size > MAX_ALLOWED_GAP:
        # Large gap - possible replay attack
        log_security_event('SEQUENCE_GAP_TOO_LARGE', {
            'session_id': session_id,
            'expected': expected,
            'received': received,
            'gap': gap_size
        })
        return {'action': 'reject', 'reason': 'sequence_gap_too_large'}

    # Small gap - allow but log
    log_monitoring_event('SEQUENCE_GAP_DETECTED', {
        'session_id': session_id,
        'expected': expected,
        'received': received,
        'gap': gap_size
    })

    return {'action': 'accept', 'reason': 'sequence_gap_allowed'}
```

This comprehensive heartbeat flow ensures reliable, secure communication between trading robots and the server, with proper sequencing, change management, and real-time data synchronization.
