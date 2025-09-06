# Trading Robot /start Endpoint - Complete Flow Documentation

## Overview
This document provides a comprehensive explanation of the `/start` endpoint flow for trading robots in the serverless trading robot control system. The `/start` endpoint serves as the initial handshake between a trading robot and the server, establishing a session and providing all necessary configuration and credentials. This refactored version removes payload encryption and implements cache-based API key validation for simplified SDK integration.

## Table of Contents
1. [Robot Request Data Structure](#robot-request-data-structure)
2. [Server Processing Flow](#server-processing-flow)
3. [Database Operations](#database-operations)
4. [Security and Authentication](#security-and-authentication)
5. [Response Structure](#response-structure)
6. [Error Scenarios](#error-scenarios)
7. [Data Flow Diagrams](#data-flow-diagrams)

## Robot Request Data Structure

### HTTP Request Format
```
POST /start
Content-Type: application/json
X-API-Key: <license_key> (optional, can also be in body)

{
  "api_key": "string (required)",
  "robot_version": "string (required)",
  "static_fields": {
    "account_number": "string",
    "broker": "string",
    "server": "string",
    "account_name": "string",
    "account_server": "string",
    "account_currency": "string",
    "account_company": "string",
    "account_trade_mode": "integer",
    "account_leverage": "integer",
    "account_limit_orders": "integer",
    "account_margin_so_mode": "integer",
    "account_trade_allowed": "boolean",
    "account_trade_expert": "boolean",
    "account_margin_mode": "integer",
    "account_currency_digits": "integer",
    "account_fifo_close": "boolean",
    "account_hedge_allowed": "boolean",
    "mql_program_name": "string",
    "mql_program_type": "integer",
    "mql_program_path": "string",
    "mql_trade_allowed": "integer",
    "mql_optimization": "integer",
    "terminal_path": "string",
    "terminal_data_path": "string",
    "terminal_commondata_path": "string",
    "terminal_build": "integer",
    "terminal_language": "string",
    "terminal_name": "string",
    "terminal_maxbars": "integer",
    "expert_magic": "integer",
    "additional_data": "object (flexible JSON)"
  },
  "session_symbols": [
    {
      "symbol": "EURUSD",
      "active_to_trade": true,
      "spread": 1.2,
      "lot_size": 0.01,
      "pip_value": 10.0,
      "margin_required": 100.0
    },
    {
      "symbol": "GBPUSD",
      "active_to_trade": false,
      "spread": 1.8,
      "lot_size": 0.01,
      "pip_value": 10.0,
      "margin_required": 100.0
    }
  ]
}
```

### Key Request Fields

#### Developer-Provided Parameters (SDK Input)
These parameters must be provided by the developer when initializing the robot:
- **`api_key`**: License key obtained from customer purchase (user input)
- **`robot_version`**: Version string hardcoded by developer (e.g., "2.1.0")

#### SDK-Generated Parameters (MQL5 Functions)
These parameters are automatically collected by the SDK using MQL5 built-in functions:

#### Static Fields (Account/Terminal Information)
The robot sends comprehensive static information about the trading account and terminal environment:

**Account Information:**
- Account number, broker, server
- Trading permissions and modes
- Leverage, margin settings
- Currency and FIFO settings

**MQL Program Information:**
- Expert advisor details
- Program path and optimization settings

**Terminal Information:**
- MetaTrader terminal paths and settings
- Build version and language

#### Session Symbols Array (SDK Auto-Generated)
The SDK automatically generates this array by:
1. **Retrieving all available symbols** using MQL5 `SymbolsTotal()` and `SymbolName()`
2. **Checking watchlist status** - symbols in watchlist get `active_to_trade: true`
3. **Collecting symbol specifications** using `SymbolInfoDouble()` and `SymbolInfoInteger()`

Each symbol object contains:
- **`symbol`**: Trading pair name (e.g., "EURUSD") 
- **`active_to_trade`**: `true` if symbol is in watchlist, `false` otherwise
- **`spread`**: Current spread value from `SymbolInfoInteger(symbol, SYMBOL_SPREAD)`
- **`lot_size`**: Minimum lot size from `SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN)`
- **`pip_value`**: Value per pip calculation
- **`margin_required`**: Margin required for 1 lot from `SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL)`

## Server Processing Flow

### Step 1: Request Validation
The server performs multiple validation checks in sequence:

```python
# 1. Extract API key from header or body
api_key = extract_api_key(event)

# 2. Basic input validation
validate_required_fields(body, ['api_key', 'robot_version'])

# 3. License validation
license_info = validate_license(api_key)
```

### Step 2: License Verification
```sql
SELECT l.*, pt.max_accounts, rt.fields as robot_config_fields, rt.default_config
FROM licenses l
JOIN plan_types pt ON l.plan_type_id = pt.id
JOIN robot_types rt ON l.robot_type_id = rt.id
WHERE l.api_key = %s
AND l.start_date <= NOW()
AND l.end_date > NOW()
AND l.active = true
```

**License Validation Checks:**
- API key exists and is valid
- License is within validity period (`start_date <= NOW() < end_date`)
- License is active
- Associated plan type allows robot operation

### Step 3: Session Limit Verification
```sql
SELECT COUNT(*) as active_count
FROM sessions s
JOIN licenses l ON s.license_id = l.id
WHERE l.api_key = %s AND s.active = true
```

**Session Limit Logic:**
- Count current active sessions for the license
- Compare against `plan_types.max_accounts`
- Reject if limit exceeded

### Step 4: Session Creation
```sql
INSERT INTO sessions (
    license_id, session_config, robot_config, session_symbols,
    signing_key_id, encryption_key_id, ip_address, sequence, status
) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
RETURNING id, start_time
```

**Session Initialization Data:**
- `license_id`: Foreign key to validated license
- `session_config`: Canonical robot configuration from `robot_types.default_config`
- `robot_config`: Applied configuration (initially same as session_config)
- `session_symbols`: Symbol list from robot request
- `signing_key_id`: KMS key ID for JWT signing
- `encryption_key_id`: KMS key ID for payload encryption
- `ip_address`: Client IP address from request
- `sequence`: Initialized to 0
- `status`: Set to 'active'

### Step 5: Static Fields Storage
```sql
INSERT INTO session_static_fields (
    session_id, field_name, field_value
) VALUES (%s, %s, %s)
```

All static fields from `static_fields` object are stored as key-value pairs in the `session_static_fields` table.

### Step 6: JWT Token Generation and Cache Management
```python
# Generate JWT using Secrets Manager secret
jwt_secret = secrets_manager.get_secret_value('jwt-signing-secret')
current_time = datetime.utcnow()

jwt_payload = {
    'iss': 'trading-robot-server',
    'aud': 'trading-robot',
    'jti': f"session_{session['id']}_{int(current_time.timestamp())}",
    'iat': int(current_time.timestamp()),
    'exp': int((current_time + timedelta(seconds=300)).timestamp()),
    'license_id': session['license_id'],
    'session_id': session['id'],
    'customer_id': license_info['customer_id'],
    'robot_type_id': license_info['robot_type_id'],
    'plan_type_id': license_info['plan_type_id']
}

# Sign JWT with HMAC-SHA256 (simpler than KMS)
jwt_token = jwt.encode(jwt_payload, jwt_secret, algorithm='HS256')

# Cache API key with expiration for fast validation
cache_key = f"jwt:{jwt_token}"
cache_data = {
    'api_key': license_info['api_key'],
    'license_expires_at': license_info['end_date'].isoformat(),
    'session_id': session['id'],
    'license_id': session['license_id']
}

# Store in Redis with JWT expiration + 60 seconds buffer
cache_ttl = 360  # 6 minutes (5 min token + 1 min buffer)
redis_client.setex(cache_key, cache_ttl, json.dumps(cache_data))
```

**JWT Claims Structure (Readable by Robot):**
- `iss`: Issuer ('trading-robot-server')
- `aud`: Audience ('trading-robot')
- `jti`: JWT ID (unique token identifier)
- `iat`: Issued at timestamp
- `exp`: Expiration timestamp (robot can check locally)
- `license_id`: License identifier
- `session_id`: Session identifier
- `customer_id`: Customer identifier
- `robot_type_id`: Robot type identifier
- `plan_type_id`: Plan type identifier

### Step 7: Configuration Retrieval
```sql
SELECT default_config, fields FROM robot_types WHERE id = %s
```

**Configuration Priority:**
1. Use `robot_types.default_config` if available
2. Fallback to `robot_types.fields` for backward compatibility
3. Return empty object if neither available

### Step 8: Pending Changes Check
```sql
SELECT robot_config_change_request, session_symbols_change_request
FROM sessions WHERE id = %s
```

Check for any pending configuration or symbol changes that need to be sent to the robot.

### Step 9: Session Event Logging
```sql
INSERT INTO session_events (
    session_id, event_type, event_data
) VALUES (%s, %s, %s)
```

Log the session start event with metadata:
- API key (partial, for security)
- Client IP address
- Symbol count
- Default config applied flag

## Security and Authentication

### JWT Signing Process
1. **Key Management**: Uses AWS Secrets Manager with automatic rotation
2. **Algorithm**: HS256 (HMAC with SHA-256)
3. **Token TTL**: 5 minutes (300 seconds)
4. **Clock Skew**: 30 seconds allowance
5. **Secret Rotation**: Automatic rotation every 90 days

### Cache-Based Validation Architecture
```python
def setup_jwt_secret_rotation():
    """Configure automatic JWT secret rotation in Secrets Manager"""
    secrets_client.create_secret(
        Name='jwt-signing-secret',
        SecretString=generate_secure_secret(),
        Description='JWT signing secret with automatic rotation',
        RotationConfiguration={
            'AutomaticallyAfterDays': 90,
            'RotationRuleArn': jwt_rotation_lambda_arn
        }
    )
```

### API Key Cache Management
The new architecture stores API key information in cache for fast validation:
```python
# Cache structure for each JWT token
cache_data = {
    'api_key': 'abc123def456...',
    'license_expires_at': '2024-12-31T23:59:59Z',
    'session_id': 12345,
    'license_id': 123
}
```

### Authorization Context
The JWT token contains all necessary authorization context in readable format:
- Session ownership verification
- License validation (cached for performance)
- Plan type permissions
- Customer identification
- **Robot can now decode token locally to check expiration**

## Response Structure

### Successful Response (200 OK)
```json
{
  "jwt": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJ0cmFkaW5nLXJvYm90LXNlcnZlciIsImF1ZCI6InRyYWRpbmctcm9ib3QiLCJqdGkiOiJzZXNzaW9uXzEyMzQ1XzE3MDU5NjgwMDAiLCJpYXQiOjE3MDU5NjgwMDAsImV4cCI6MTcwNTk2ODMwMCwibGljZW5zZV9pZCI6MTIzLCJzZXNzaW9uX2lkIjoxMjM0NSwicm9ib3RfdHlwZV9pZCI6NDU2LCJwbGFuX3R5cGVfaWQiOjc4OX0...",
  "expires_in": 300,
  "session_id": 12345,
  "robot_config": {
    "risk_level": "medium",
    "max_trades_per_day": 20,
    "stop_loss_pips": 15,
    "take_profit_pips": 25,
    "trading_hours": {
      "start": "08:00",
      "end": "22:00"
    }
  },
  "robot_config_change_request": null,
  "session_symbols_change_request": null
}
```

### Response Fields

#### Authentication Fields
- **`jwt`**: JWT token for subsequent requests (contains all session context in readable payload)
- **`expires_in`**: Token validity duration in seconds (typically 300 seconds)
- **`session_id`**: Unique session identifier for this robot instance

#### Configuration Fields
- **`robot_config`**: Canonical robot configuration to be applied
- **`robot_config_change_request`**: Pending configuration changes (if any)
- **`session_symbols_change_request`**: Pending symbol changes (if any)

#### JWT Payload Structure (Now Readable by Robot)
The JWT token contains the following claims that robots can decode locally:
```json
{
  "iss": "trading-robot-server",
  "aud": "trading-robot", 
  "jti": "session_12345_1705968000",
  "iat": 1705968000,
  "exp": 1705968300,
  "license_id": 123,
  "session_id": 12345,
  "robot_type_id": 456,
  "plan_type_id": 789,
  "customer_id": 101
}

## Error Scenarios

### 1. Missing API Key (400)
```json
{
  "error": "MISSING_API_KEY",
  "message": "API key is required in request body or header",
  "code": "VALIDATION_ERROR",
  "action_required": "Provide valid API key from your license"
}
```

### 2. Invalid API Key - Not Found (403)
```json
{
  "error": "API_KEY_NOT_FOUND",
  "message": "API key not found in system",
  "code": "API_KEY_INVALID",
  "action_required": "Check API key spelling or contact support"
}
```

### 3. License Expired (403)
```json
{
  "error": "LICENSE_EXPIRED",
  "message": "Your license has expired",
  "code": "LICENSE_EXPIRED",
  "details": {
    "expired_at": "2024-01-15T10:30:00Z",
    "current_time": "2024-01-20T15:45:00Z"
  },
  "action_required": "Renew your license through customer portal"
}
```

### 4. License Inactive (403)
```json
{
  "error": "LICENSE_INACTIVE",
  "message": "License is deactivated",
  "code": "LICENSE_INACTIVE",
  "action_required": "Contact support to reactivate license"
}
```

### 5. Robot Type Inactive (403)
```json
{
  "error": "ROBOT_TYPE_INACTIVE",
  "message": "This robot type is no longer supported",
  "code": "ROBOT_TYPE_INACTIVE",
  "details": {
    "robot_type": "Legacy Bot v1.0"
  },
  "action_required": "Upgrade to newer robot version"
}
```

### 6. Session Limit Exceeded (409)
```json
{
  "error": "MAX_SESSIONS_EXCEEDED",
  "message": "Maximum concurrent sessions exceeded for your plan",
  "code": "SESSION_LIMIT_REACHED",
  "details": {
    "current_active_sessions": 3,
    "max_allowed_sessions": 3,
    "plan_name": "Professional",
    "active_session_ids": [12340, 12341, 12342]
  },
  "action_required": "Stop one of your active sessions or upgrade plan"
}

### 7. Missing Required Fields (400)
```json
{
  "error": "MISSING_REQUIRED_FIELDS",
  "message": "Required fields missing from request",
  "code": "VALIDATION_ERROR",
  "details": {
    "missing_fields": ["robot_version", "static_fields"]
  },
  "action_required": "Include all required fields in request"
}
```

### 8. Invalid Robot Version (400)
```json
{
  "error": "INVALID_ROBOT_VERSION",
  "message": "Robot version not supported",
  "code": "VERSION_NOT_SUPPORTED",
  "details": {
    "provided_version": "1.0.0",
    "minimum_version": "2.0.0"
  },
  "action_required": "Update robot to minimum supported version"
}
```

### 9. Database Connection Error (500)
```json
{
  "error": "INTERNAL_ERROR",
  "message": "Database connection failed",
  "code": "DATABASE_ERROR",
  "action_required": "Retry in a few moments or contact support if persistent"
}
```

### 10. JWT Generation Failure (500)
```json
{
  "error": "TOKEN_GENERATION_FAILED",
  "message": "Failed to generate authentication token",
  "code": "TOKEN_GENERATION_FAILED",
  "action_required": "Retry request or contact support"
}
```

### 11. Secrets Manager Error (500)
```json
{
  "error": "SECRET_ACCESS_FAILED",
  "message": "Failed to retrieve JWT signing secret",
  "code": "SECRET_ACCESS_FAILED",
  "action_required": "System maintenance in progress, retry shortly"
}
```

## Data Flow Diagrams

### High-Level Flow
```
Robot Request
    ↓
API Gateway → Lambda Handler
    ↓
License Validation (Database)
    ↓
Session Limit Check
    ↓
Session Creation
    ↓
Static Fields Storage
    ↓
JWT Generation (Secrets Manager)
    ↓
Cache API Key + Expiration
    ↓
Configuration Retrieval
    ↓
Response Construction
    ↓
Robot Response (with readable JWT)
```

### Database Operations Sequence
```
1. SELECT licenses + robot_types + plan_types
2. SELECT COUNT active sessions
3. INSERT sessions
4. INSERT session_static_fields (multiple rows)
5. SELECT robot_config
6. SELECT pending changes
7. INSERT session_events
```

### Security Flow (Simplified)
```
Request → API Gateway
    ↓
Lambda Handler
    ↓
Secrets Manager Get Secret
    ↓
JWT Sign with HMAC
    ↓
Cache API Key for Validation
    ↓
Response with JWT (Robot can decode locally)
```

### Cache Architecture
```
JWT Token Creation:
    ↓
Store in Redis: jwt:{token} → {
    api_key: "abc123...",
    license_expires_at: "2024-12-31T23:59:59Z",
    session_id: 12345,
    license_id: 123
}
    ↓
Robot receives JWT (can read payload locally)
    ↓
Future requests: Server validates via cache lookup
```

## Performance Considerations

### Database Indexes
- `idx_licenses_api_key`: Fast license lookup
- `idx_sessions_license_id`: Session counting
- `idx_sessions_active`: Active session queries

### Caching Strategy
- JWT tokens + API key info cached in Redis for 6 minutes
- Secrets Manager JWT secrets cached locally for performance
- Database connection pooling enabled

### Optimization Points
- Batch static field insertions
- Async session event logging
- Redis cache for fast authentication validation
- JWT payload readable by robot (no server decoding needed)

### Robot-Side SDK Considerations
```javascript
// Robot can now decode JWT locally to check expiration
function isTokenExpired(jwt_token) {
    try {
        const payload = JSON.parse(atob(jwt_token.split('.')[1]));
        const now = Math.floor(Date.now() / 1000);
        return payload.exp <= now + 60; // Check with 1-minute buffer
    } catch (error) {
        return true; // Assume expired if can't decode
    }
}

// Robot should check before each API call
if (isTokenExpired(current_jwt)) {
    // Send refresh request instead of heartbeat
    await refreshToken();
}
```

## SDK Process for Robot

### Three-Layer Architecture
The SDK acts as middleware between Server and Robot:
- **Server ↔ SDK**: HTTP/JSON communication with authentication
- **SDK ↔ Robot**: Internal MQL5 function calls and callbacks
- **Robot**: Developer's EA code with configuration objects

### Initialization Phase
The SDK library should provide initialization with developer's configuration object:

```mql5
// Developer defines their robot configuration class
class MyRobotConfig {
public:
    int max_trades_per_day;
    double risk_percentage;
    string trading_mode;
    bool enable_news_filter;
    
    // Validation methods for each parameter
    bool ValidateMaxTrades(int value);
    bool ValidateRiskPercentage(double value);  
    bool ValidateMode(string value);
    bool ValidateNewsFilter(bool value);
    
    // Convert to JSON for server communication
    string ToJSON();
};

// SDK initialization method
bool InitializeRobotConnection(string api_key, string robot_version, MyRobotConfig& config)
```

**SDK Internal Process:**

1. **Configuration Object Processing**
   - Receive developer's configuration object with parameters and validation methods
   - Store reference to configuration object for future updates
   - Convert configuration object to complete JSON format
   - Validate that all required methods are implemented

2. **Static Data Collection** 
   - Use `AccountInfoInteger()`, `AccountInfoDouble()`, `AccountInfoString()` for account data
   - Use `MQLInfoInteger()`, `MQLInfoString()` for program information
   - Use `TerminalInfoInteger()`, `TerminalInfoString()` for terminal data
   - Store all collected data in internal structures

3. **Session Symbols Array Generation**
   - Iterate through all available symbols using `SymbolsTotal()` and `SymbolName()`
   - For each symbol, check if it's in watchlist using `SymbolSelect()`
   - Collect symbol specifications using `SymbolInfoInteger()` and `SymbolInfoDouble()`
   - Set `active_to_trade: true` for watchlist symbols, `false` for others

4. **Server Communication**
   - Build JSON payload with: API key, robot version, static fields, symbols, **complete configuration**
   - Send POST request to `/start` endpoint
   - Handle authentication and store received JWT token
   - Parse and store `session_id` for future requests

### Success Handling

**Configuration Validation Against Server Response:**
1. **Extract Server Configuration**: Parse `robot_config` from `/start` response
2. **Field Completeness Check**: Verify that ALL fields in developer's config object exist in server response
   - Compare developer's config object fields with server's `robot_config`
   - If any field missing from server config → throw initialization error
   - Error message must specify which fields are missing
3. **Value Validation**: Use developer's validation methods to validate server values
4. **Update SDK Memory**: Store server configuration as current active config
5. **Initialize Internal State**: Set up configuration change tracking

**Authentication and Session Management:**
- Store JWT token and session ID in memory
- Initialize heartbeat timer with server requirements
- Set up configuration change monitoring
- Prepare heartbeat data persistence mechanism

**Robot Notification:**
- Call developer's configuration update callback (if provided)
- Provide initial configuration values to robot
- Set up symbol change notification mechanism

### Error Handling

**Server-Side Errors:**
- **API Key Issues**: Guide user to check API key format and validity
- **Session Limit**: Display list of active sessions and guide user to stop one
- **License Expired**: Direct user to renewal portal with specific expiration date
- **Version Incompatible**: Show minimum required version and update instructions

**Configuration Validation Errors:**
- **Missing Configuration Fields**: Server config doesn't contain all fields from developer's config object
  - Show specific field names that are missing
  - Guide developer to check server-side robot configuration
- **Invalid Configuration Values**: Server values fail developer's validation methods
  - Report which fields failed validation and why
  - Use developer's validation methods to provide specific error messages

### Developer Integration Example

**Step 1: Define Robot Configuration Class**
```mql5
// Developer creates configuration class with validation
class MyTradingRobotConfig {
public:
    int max_trades_per_day;
    double risk_percentage;
    string trading_mode;
    bool enable_news_filter;
    
    // Constructor with default values
    MyTradingRobotConfig() {
        max_trades_per_day = 10;
        risk_percentage = 2.0;
        trading_mode = "conservative";
        enable_news_filter = true;
    }
    
    // Validation methods (SDK will call these)
    bool ValidateMaxTrades(int value) {
        return (value > 0 && value <= 100);
    }
    
    bool ValidateRiskPercentage(double value) {
        return (value > 0.0 && value <= 10.0);
    }
    
    bool ValidateMode(string value) {
        return (value == "conservative" || value == "moderate" || value == "aggressive");
    }
    
    bool ValidateNewsFilter(bool value) {
        return true; // Always valid for boolean
    }
    
    // Convert to JSON (SDK will call this)
    string ToJSON() {
        return StringFormat("{\"max_trades_per_day\":%d,\"risk_percentage\":%.2f,\"trading_mode\":\"%s\",\"enable_news_filter\":%s}",
                          max_trades_per_day, risk_percentage, trading_mode, enable_news_filter ? "true" : "false");
    }
};

// Callback interface for configuration updates
class IConfigUpdateCallback {
public:
    virtual void OnConfigurationChanged(string field_name, string old_value, string new_value) = 0;
    virtual void OnSymbolStatusChanged(string symbol, bool active_to_trade) = 0;
};
```

**Step 2: Initialize Robot with Configuration**
```mql5
// In Expert Advisor
class MyExpertAdvisor : public IConfigUpdateCallback {
private:
    MyTradingRobotConfig robot_config;
    
public:
    // EA initialization
    int OnInit() {
        string my_api_key = "abc123def456..."; // From EA parameters
        string my_version = "2.1.0";           // Hardcoded by developer
        
        // Initialize SDK with configuration object
        if (!InitializeRobotConnection(my_api_key, my_version, robot_config, this)) {
            Print("Failed to initialize robot connection");
            return INIT_FAILED;
        }
        
        Print("Robot connected successfully. Session ID: ", GetSessionId());
        Print("Current config - Max Trades: ", robot_config.max_trades_per_day);
        return INIT_SUCCEEDED;
    }
    
    // Configuration update callbacks (SDK calls these)
    void OnConfigurationChanged(string field_name, string old_value, string new_value) override {
        Print("Server updated config: ", field_name, " from ", old_value, " to ", new_value);
        
        // Robot can react to specific parameter changes
        if (field_name == "risk_percentage") {
            RecalculatePositionSizes();
        } else if (field_name == "max_trades_per_day") {
            UpdateTradeLimits();
        }
    }
    
    void OnSymbolStatusChanged(string symbol, bool active_to_trade) override {
        Print("Symbol ", symbol, " trading status changed to: ", active_to_trade);
        if (active_to_trade) {
            EnableSymbolTrading(symbol);
        } else {
            DisableSymbolTrading(symbol);
        }
    }
};
```

## Monitoring and Logging

### Key Metrics
- Session creation success/failure rates
- JWT generation latency
- Database query performance
- License validation errors

### Log Entries
- Session creation events
- License validation failures
- JWT generation errors
- Database operation timings

This comprehensive flow ensures secure, reliable session establishment between trading robots and the server, with proper validation, configuration management, and error handling throughout the process.
