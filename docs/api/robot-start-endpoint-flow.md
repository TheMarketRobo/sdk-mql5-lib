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
8. [SDK Process for Robot](#sdk-process-for-robot)

## Robot Request Data Structure

### HTTP Request Format

**Endpoint:** `POST /start`  
**Content-Type:** `application/json`  
**X-API-Key:** `<license_key>` (optional, can also be in body)

### Request Body Structure

```json
{
  "api_key": "string (required)",
  "robot_version_uuid": "string (required)",
  "magic_number": "integer (required)",
  "account_currency": "string (required, ISO 4217 format)",
  "initial_balance": "number (required)",
  "initial_equity": "number (required)",
  "static_fields": {
    "account_login": "integer",
    "account_name": "string",
    "account_server": "string",
    "account_currency": "string",
    "account_company": "string",
    "account_trade_mode": "string (enum: REAL, DEMO, CONTEST)",
    "account_leverage": "integer",
    "account_limit_orders": "integer",
    "account_margin_so_mode": "string (enum: PERCENT, MONEY)",
    "account_trade_allowed": "boolean",
    "account_trade_expert": "boolean",
    "account_margin_mode": "string (enum)",
    "account_currency_digits": "integer",
    "account_fifo_close": "boolean",
    "account_hedge_allowed": "boolean",
    "terminal_build": "integer",
    "terminal_community_account": "boolean",
    "terminal_community_connection": "boolean",
    "terminal_connected": "boolean",
    "terminal_dlls_allowed": "boolean",
    "terminal_trade_allowed": "boolean",
    "terminal_email_enabled": "boolean",
    "terminal_ftp_enabled": "boolean",
    "terminal_notifications_enabled": "boolean",
    "terminal_maxbars": "integer",
    "terminal_mqid": "boolean",
    "terminal_codepage": "integer",
    "terminal_cpu_cores": "integer",
    "terminal_memory_physical": "integer",
    "terminal_memory_total": "integer",
    "terminal_memory_available": "integer",
    "terminal_memory_used": "integer",
    "terminal_x64": "boolean",
    "terminal_path": "string",
    "terminal_data_path": "string",
    "terminal_commondata_path": "string",
    "terminal_name": "string",
    "terminal_language": "string",
    "mql_program_name": "string",
    "mql_program_type": "integer",
    "mql_program_path": "string",
    "mql_trade_allowed": "integer",
    "mql_optimization": "integer",
    "expert_magic": "integer"
  },
  "session_symbols": [
    {
      "symbol": "EURUSD",
      "active_to_trade": true,
      "spread": 1.2,
      "lot_size": 0.01,
      "pip_value": 10.0,
      "margin_required": 100.0
    }
  ]
}
```

### Key Request Fields

#### Required Fields
- **`api_key`**: License key obtained from customer purchase (customer input parameter)
- **`robot_version_uuid`**: Robot version identifier (programmer-defined, hardcoded in robot)
- **`magic_number`**: MT5 magic number for trade identification (customer input parameter; defaults to `0` for Custom Indicators)
- **`account_currency`**: Account currency code in ISO 4217 format (e.g., "USD", "EUR")
- **`initial_balance`**: Initial account balance at session start
- **`initial_equity`**: Initial account equity at session start
- **`static_fields`**: Complete account and terminal information object
- **`session_symbols`**: Array of trading symbols with their specifications

#### Static Fields (Account/Terminal Information)
The robot sends comprehensive static information about the trading account and terminal environment:

**Account Information:**
- Account login, name, server, company
- Trading permissions and modes
- Leverage, margin settings
- Currency and FIFO settings

**MQL Program Information:**
- Expert advisor details
- Program path and optimization settings

**Terminal Information:**
- MetaTrader terminal paths and settings
- Build version and language
- System resources (CPU, memory)

#### Session Symbols Array
The SDK automatically generates this array by:
1. Retrieving symbols from the **Market Watch** (Watchlist) using MQL5 `SymbolsTotal(true)` and `SymbolName(i, true)`
2. Checking watchlist status - symbols in watchlist get `active_to_trade: true`
3. Collecting symbol specifications using `SymbolInfoDouble()` and `SymbolInfoInteger()`

Each symbol object contains:
- **`symbol`**: Trading pair name (e.g., "EURUSD")
- **`active_to_trade`**: `true` if symbol is in watchlist, `false` otherwise
- **`spread`**: Current spread value
- **`lot_size`**: Minimum lot size
- **`pip_value`**: Value per pip calculation
- **`margin_required`**: Margin required for 1 lot

## Server Processing Flow

### Step 1: Request Validation
The server performs multiple validation checks:
1. Extract API key from header or body
2. Validate required fields are present
3. Validate field formats and types

### Step 2: License Verification
The server queries the database to:
- Verify API key exists and is valid
- Check license is within validity period
- Verify license is active
- Confirm associated plan type allows robot operation

### Step 3: Session Limit Verification
The server counts current active sessions for the license and compares against plan limits. If limit exceeded, request is rejected.

### Step 4: Session Creation
The server creates a new session record with:
- License ID reference
- Session configuration from robot type defaults
- Initial robot configuration
- Session symbols from request
- Signing key ID for JWT generation
- IP address from request
- Sequence initialized to 0
- Status set to 'active'

### Step 5: Static Fields Storage
All static fields from `static_fields` object are stored as key-value pairs in the `session_static_fields` table.

### Step 6: JWT Token Generation and Cache Management
The server generates a JWT token using:
- **Algorithm**: HS256 (HMAC with SHA-256)
- **Secret Source**: AWS Secrets Manager with automatic rotation
- **Token TTL**: 5 minutes (300 seconds)
- **Cache TTL**: 6 minutes (token expiration + 1 minute buffer)

**JWT Claims Structure (Readable by Robot):**
- `iss`: Issuer ('trading-robot-server')
- `aud`: Audience ('trading-robot')
- `jti`: JWT ID (unique token identifier)
- `iat`: Issued at timestamp (Unix timestamp)
- `exp`: Expiration timestamp (Unix timestamp, robot can check locally)
- `license_id`: License identifier
- `session_id`: Session identifier
- `customer_id`: Customer identifier

**Cache Structure:**
The server stores in Redis cache:
- API key associated with the JWT
- License expiration timestamp
- Session ID and License ID

### Step 7: Configuration Retrieval
The server retrieves robot configuration from `robot_types` table:
1. Use `robot_types.default_config` if available
2. Fallback to `robot_types.fields` for backward compatibility
3. Return empty object if neither available

### Step 8: Pending Changes Check
The server checks for any pending configuration or symbol changes that need to be sent to the robot.

### Step 9: Session Event Logging
The server logs the session start event with metadata including partial API key, client IP, symbol count, and default config applied flag.

## Security and Authentication

### JWT Signing Process
1. **Key Management**: Uses AWS Secrets Manager with automatic rotation
2. **Algorithm**: HS256 (HMAC with SHA-256)
3. **Token TTL**: 5 minutes (300 seconds)
4. **Clock Skew**: 30 seconds allowance
5. **Secret Rotation**: Automatic rotation every 90 days

### Cache-Based Validation Architecture
The server stores API key information in cache for fast validation:
- Cache key format: `jwt:{jwt_token}`
- Cache data includes: API key, license expiration, session ID, license ID
- Cache TTL matches JWT expiration + buffer

### Authorization Context
The JWT token contains all necessary authorization context in readable format:
- Session ownership verification
- License validation (cached for performance)
- Customer identification
- **Robot can decode token locally to check expiration**

## Response Structure

### Successful Response (200 OK)

```json
{
  "jwt": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
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
- **`robot_config_change_request`**: Pending configuration changes (if any, null otherwise)
- **`session_symbols_change_request`**: Pending symbol changes (if any, null otherwise)

#### JWT Payload Structure (Readable by Robot)
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
  "customer_id": 101
}
```

## Error Scenarios

### 1. Missing API Key (400)
```json
{
  "type": "https://api.themarketrobo.com/problems/validation-error",
  "title": "Validation Error",
  "status": 400,
  "detail": "API key is required in request body or header",
  "instance": "/api/v1/robots/start",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "errors": [
    {
      "field": "/api_key",
      "code": "REQUIRED",
      "message": "API key is required"
    }
  ]
}
```

### 2. Invalid API Key - Not Found (403)
```json
{
  "type": "https://api.themarketrobo.com/problems/authentication-error",
  "title": "Authentication Failed",
  "status": 403,
  "detail": "API key not found in system",
  "instance": "/api/v1/robots/start",
  "timestamp": "2024-01-20T15:45:00.000Z",
  "request_id": "req_abc123def456",
  "auth_error_code": "API_KEY_NOT_FOUND"
}
```

### 3. License Expired (403)
```json
{
  "type": "https://api.themarketrobo.com/problems/authentication-error",
  "title": "Authentication Failed",
  "status": 403,
  "detail": "Your license has expired",
  "instance": "/api/v1/robots/start",
  "timestamp": "2024-01-20T15:45:00.000Z",
  "request_id": "req_abc123def456",
  "auth_error_code": "LICENSE_EXPIRED",
  "license_context": {
    "license_id": "12345",
    "license_status": "expired",
    "expires_at": "2024-01-15T10:30:00Z"
  }
}
```

### 4. License Inactive (403)
```json
{
  "type": "https://api.themarketrobo.com/problems/authentication-error",
  "title": "Authentication Failed",
  "status": 403,
  "detail": "License is deactivated",
  "instance": "/api/v1/robots/start",
  "timestamp": "2024-01-20T15:45:00.000Z",
  "request_id": "req_abc123def456",
  "auth_error_code": "LICENSE_INACTIVE"
}
```

### 5. Session Limit Exceeded (409)
```json
{
  "type": "https://api.themarketrobo.com/problems/session-error",
  "title": "Session Error",
  "status": 409,
  "detail": "Maximum concurrent sessions exceeded for your plan",
  "instance": "/api/v1/robots/start",
  "timestamp": "2024-01-20T15:45:00.000Z",
  "request_id": "req_abc123def456",
  "session_error_code": "MAX_SESSIONS_EXCEEDED",
  "session_context": {
    "current_active_sessions": 3,
    "max_allowed_sessions": 3,
    "plan_name": "Professional",
    "active_session_ids": [12340, 12341, 12342]
  }
}
```

### 6. Missing Required Fields (400)
```json
{
  "type": "https://api.themarketrobo.com/problems/validation-error",
  "title": "Validation Error",
  "status": 400,
  "detail": "Required fields missing from request",
  "instance": "/api/v1/robots/start",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "errors": [
    {
      "field": "/robot_version_uuid",
      "code": "REQUIRED",
      "message": "Robot version UUID is required"
    },
    {
      "field": "/magic_number",
      "code": "REQUIRED",
      "message": "Magic number is required"
    }
  ]
}
```

### 7. Invalid Robot Version (400)
```json
{
  "type": "https://api.themarketrobo.com/problems/validation-error",
  "title": "Validation Error",
  "status": 400,
  "detail": "Robot version not supported",
  "instance": "/api/v1/robots/start",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "errors": [
    {
      "field": "/robot_version_uuid",
      "code": "INVALID_VERSION",
      "message": "Robot version not supported",
      "details": {
        "provided_version": "1.0.0",
        "minimum_version": "2.0.0"
      }
    }
  ]
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
1. SELECT licenses + robot_types + plan_types
2. SELECT COUNT active sessions
3. INSERT sessions
4. INSERT session_static_fields (multiple rows)
5. SELECT robot_config
6. SELECT pending changes
7. INSERT session_events

### Security Flow
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

## SDK Process for Robot

### Three-Layer Architecture
The SDK acts as middleware between Server and Robot:
- **Server ↔ SDK**: HTTP/JSON communication with authentication
- **SDK ↔ Robot**: Internal MQL5 function calls and callbacks
- **Robot**: Developer's EA code with configuration objects

### Initialization Phase

**SDK Internal Process:**

1. **Configuration Object Processing (Expert Advisors only)**
   - Receive developer's configuration object with parameters and validation methods
   - Store reference to configuration object for future updates
   - Convert configuration object to complete JSON format
   - Validate that all required methods are implemented

2. **Static Data Collection**
   - Use MQL5 AccountInfo functions for account data
   - Use MQL5 MQLInfo functions for program information
   - Use MQL5 TerminalInfo functions for terminal data
   - Store all collected data in internal structures

3. **Session Symbols Array Generation**
   - Iterate through all available symbols using MQL5 functions
   - For each symbol, check if it's in watchlist
   - Collect symbol specifications
   - Set `active_to_trade: true` for watchlist symbols, `false` for others

4. **Server Communication**
   - Build JSON payload with: API key, robot version UUID, magic number, account currency, initial balance/equity, static fields, symbols, complete configuration
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
- Decode JWT payload locally to extract expiration time
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
