# Trading Robot /refresh Endpoint - Complete Flow Documentation

## Overview
This document provides a comprehensive explanation of the `/refresh` endpoint flow for trading robots in the serverless trading robot control system. The `/refresh` endpoint serves as the JWT token renewal mechanism, allowing robots to maintain session continuity without restarting the entire session. This refactored version uses Secrets Manager for JWT signing and cache-based validation for improved performance and simplified architecture.

## Table of Contents
1. [Robot Request Data Structure](#robot-request-data-structure)
2. [Server Processing Flow](#server-processing-flow)
3. [Authentication Methods](#authentication-methods)
4. [Security and Token Validation](#security-and-token-validation)
5. [Database Operations](#database-operations)
6. [Response Structure](#response-structure)
7. [Error Scenarios](#error-scenarios)
8. [Performance Considerations](#performance-considerations)
9. [Monitoring and Logging](#monitoring-and-logging)

## Robot Request Data Structure

### HTTP Request Format
```
POST /refresh
Content-Type: application/json

{
  "jwt_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6ImtleS0xMjMifQ...",
  "api_key": "string (alternative to jwt_token)",
  "session_id": "integer (required with api_key)"
}
```

### Authentication Methods

#### Method 1: Using Expired JWT Token (Primary Method)
```json
{
  "jwt_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6ImtleS0xMjMifQ..."
}
```

**Advantages:**
- No need to store API key in memory
- Maintains session context automatically
- Single parameter required

#### Method 2: Using API Key + Session ID (Fallback Method)
```json
{
  "api_key": "abc123def456...",
  "session_id": 12345
}
```

**Use Cases:**
- JWT token completely lost or corrupted
- Robot restart scenarios
- Backup authentication method

### Key Request Fields

#### Primary Authentication (JWT Token)
- **`jwt_token`**: Expired or soon-to-expire JWT token from previous authentication
- Contains embedded session context and claims

#### Fallback Authentication (API Key + Session ID)
- **`api_key`**: License key obtained from customer purchase
- **`session_id`**: Numeric session identifier from /start response

## Server Processing Flow

### Step 1: Request Validation
```python
# Parse and validate request body
body = json.loads(event.get('body', '{}'))

# Extract authentication parameters
jwt_token = body.get('jwt_token')
api_key = body.get('api_key')
session_id = body.get('session_id')

# Validate input combinations
if not jwt_token and not (api_key and session_id):
    return create_error_response(400, 'MISSING_PARAMETERS')
```

### Step 2: Authentication Method Selection
```python
if jwt_token:
    # Method 1: Extract session info from JWT
    session_info = jwt_manager.extract_session_info(jwt_token)
    if not session_info:
        return create_error_response(400, 'INVALID_JWT')
else:
    # Method 2: Validate API key
    license_info = validate_api_key(api_key)
    if not license_info:
        return create_error_response(403, 'LICENSE_INVALID')
```

### Step 3: Session Information Extraction

#### From JWT Token (Method 1)
```python
def extract_session_info(token: str) -> Optional[Dict[str, Any]]:
    try:
        # Decode JWT without verification to extract claims
        payload = jwt.decode(token, options={"verify_signature": False})

        return {
            'session_id': payload.get('session_id'),
            'license_id': payload.get('license_id'),
            'robot_type_id': payload.get('robot_type_id'),
            'customer_id': payload.get('customer_id'),
            'issued_at': payload.get('iat'),
            'expires_at': payload.get('exp')
        }
    except Exception as e:
        logger.error(f"Failed to extract session info: {str(e)}")
        return None
```

#### From API Key + Session ID (Method 2)
```python
def validate_api_key(api_key: str) -> Optional[Dict[str, Any]]:
    query = """
    SELECT l.*, pt.max_accounts, rt.fields as robot_config_fields
    FROM licenses l
    JOIN plan_types pt ON l.plan_type_id = pt.id
    JOIN robot_types rt ON l.robot_type_id = rt.id
    WHERE l.api_key = %s
    AND l.start_date <= NOW()
    AND l.end_date > NOW()
    """

    result = db_manager.execute_query(query, (api_key,))
    return result[0] if result else None
```

### Step 4: Session Validation
```python
def validate_session(session_id: int, license_id: Optional[int] = None) -> Optional[Dict[str, Any]]:
    if license_id:
        query = """
        SELECT s.*, l.api_key
        FROM sessions s
        JOIN licenses l ON s.license_id = l.id
        WHERE s.id = %s AND s.license_id = %s AND s.active = true
        """
        params = (session_id, license_id)
    else:
        query = """
        SELECT s.*, l.api_key
        FROM sessions s
        JOIN licenses l ON s.license_id = l.id
        WHERE s.id = %s AND s.active = true
        """
        params = (session_id,)

    result = db_manager.execute_query(query, params)
    return result[0] if result else None
```

**Session Validation Checks:**
- Session exists in database
- Session is marked as active
- Session belongs to authenticated license (if license_id provided)
- Session hasn't been terminated or cleaned up

### Step 5: License Re-validation
```python
def validate_license_by_id(license_id: int) -> Optional[Dict[str, Any]]:
    query = """
    SELECT l.*, c.email, c.first_name, c.last_name,
           rt.name as robot_type_name, pt.name as plan_type_name
    FROM licenses l
    JOIN customers c ON l.customer_id = c.id
    JOIN robot_types rt ON l.robot_type_id = rt.id
    JOIN plan_types pt ON l.plan_type_id = pt.id
    WHERE l.id = %s
    AND l.start_date <= NOW()
    AND l.end_date > NOW()
    """

    result = db_manager.execute_query(query, (license_id,))
    return result[0] if result else None
```

**License Validation Checks:**
- License exists and is valid
- License is within validity period
- Associated customer and robot type are active

### Step 6: Session Activity Validation
```python
def is_refresh_allowed(session: Dict[str, Any]) -> tuple[bool, Optional[str]]:
    # Check if session is still within allowed refresh window
    last_heartbeat = session.get('last_heartbeat_at')
    if last_heartbeat:
        time_since_heartbeat = datetime.utcnow() - last_heartbeat.replace(tzinfo=None)

        # If more than 1 hour since last heartbeat, require new Start
        if time_since_heartbeat.total_seconds() > 3600:
            return False, "Session has been inactive too long, please restart"

    # Check if license is still valid
    license_id = session.get('license_id')
    if license_id and not validate_license_by_id(license_id):
        return False, "License is no longer valid"

    return True, None
```

### Step 7: JWT Token Generation with Cache Update
```python
def create_token(session_data: Dict[str, Any]) -> Dict[str, Any]:
    # Get JWT secret from Secrets Manager (cached)
    jwt_secret = secrets_manager.get_cached_secret('jwt-signing-secret')
    current_time = datetime.utcnow()
    
    # Create JWT payload (readable by robot)
    payload = {
        'iss': 'trading-robot-server',
        'aud': 'trading-robot', 
        'jti': f"session_{session_data['id']}_{int(current_time.timestamp())}",
        'iat': int(current_time.timestamp()),
        'exp': int((current_time + timedelta(seconds=300)).timestamp()), # 5 minutes
        'license_id': session_data['license_id'],
        'session_id': session_data['id'],
        'robot_type_id': session_data['robot_type_id'],
        'plan_type_id': session_data['plan_type_id'],
        'customer_id': session_data['customer_id']
    }

    # Sign with HMAC using secret from Secrets Manager
    token = jwt.encode(payload, jwt_secret, algorithm='HS256')

    # Update cache with new token
    cache_key = f"jwt:{token}"
    cache_data = {
        'api_key': session_data['api_key'],
        'license_expires_at': session_data['license_end_date'].isoformat(),
        'session_id': session_data['id'],
        'license_id': session_data['license_id']
    }
    
    # Store in Redis with token expiration + buffer
    cache_ttl = 360  # 6 minutes (5 min token + 1 min buffer)
    redis_client.setex(cache_key, cache_ttl, json.dumps(cache_data))

    # Clean up old token from cache if exists
    if session_data.get('old_jwt_token'):
        old_cache_key = f"jwt:{session_data['old_jwt_token']}"
        redis_client.delete(old_cache_key)

    return {
        'token': token,
        'expires_in': 300,
        'issued_at': current_time.isoformat(),
        'expires_at': (current_time + timedelta(seconds=300)).isoformat()
    }
```

### Step 8: Session Update
```python
def update_session_jwt(session_id: int, jwt_token: Dict[str, Any]):
    # Parse timestamps
    issued_at = datetime.fromisoformat(jwt_token['issued_at'].replace('Z', '+00:00'))
    expires_at = datetime.fromisoformat(jwt_token['expires_at'].replace('Z', '+00:00'))

    query = """
    UPDATE sessions
    SET jwt_issued_at = %s,
        jwt_expires_at = %s,
        updated_at = NOW()
    WHERE id = %s
    """

    db_manager.execute_query(query, (issued_at, expires_at, session_id))
```

### Step 9: Response Construction
```python
response_data = {
    'jwt': jwt_token['token'],
    'expires_in': jwt_token['expires_in'],
    'issued_at': jwt_token['issued_at'],
    'expires_at': jwt_token['expires_at']
}
```

## Authentication Methods Comparison

### Method 1: JWT Token (Recommended)
**Pros:**
- Single parameter required
- Maintains full session context
- No need to store sensitive data
- Faster processing (no database lookup for license)

**Cons:**
- Requires valid JWT structure
- Token size larger than simple ID

**Processing Flow:**
```
Expired JWT → Decode Claims → Validate Session → Generate New JWT
```

### Method 2: API Key + Session ID (Fallback)
**Pros:**
- Simple and lightweight
- Works when JWT is completely lost
- Easy to implement in robots

**Cons:**
- Requires storing API key in memory
- Additional database lookup for license validation
- More parameters to manage

**Processing Flow:**
```
API Key + Session ID → Validate License → Validate Session → Generate New JWT
```

## Security and Token Validation

### JWT Signing Process (Simplified)
1. **Algorithm**: HS256 (HMAC with SHA-256)
2. **Key Management**: AWS Secrets Manager with automatic rotation
3. **Token Structure**: header.payload.signature (payload readable by robot)
4. **Security Features**:
   - Timestamp-based uniqueness (`jti`)
   - Audience validation (`aud`)
   - Issuer validation (`iss`)
   - Expiration checking (`exp`) - **Robot can check locally**
   - Cache-based validation for performance

### Session Context Validation
```python
def validate_session_context(jwt_claims: Dict, session_id: int) -> bool:
    # Verify session belongs to authenticated license
    db_session = db_get_session(session_id)

    if not db_session:
        return False

    if db_session['license_id'] != jwt_claims['license_id']:
        return False

    if db_session['status'] != 'active':
        return False

    return True
```

### Refresh Rate Limiting
```python
def check_refresh_rate_limit(session_id: int) -> bool:
    # Allow maximum 10 refreshes per minute per session
    key = f"refresh_rate:{session_id}"
    current_count = redis_client.incr(key)

    if current_count == 1:
        redis_client.expire(key, 60)  # 1 minute window

    return current_count <= 10
```

## Database Operations

### License Validation Query
```sql
SELECT l.*, pt.max_accounts, rt.fields as robot_config_fields
FROM licenses l
JOIN plan_types pt ON l.plan_type_id = pt.id
JOIN robot_types rt ON l.robot_type_id = rt.id
WHERE l.api_key = %s
AND l.start_date <= NOW()
AND l.end_date > NOW()
```

### Session Validation Query
```sql
SELECT s.*, l.api_key
FROM sessions s
JOIN licenses l ON s.license_id = l.id
WHERE s.id = %s AND s.license_id = %s AND s.active = true
```

### Session Update Query
```sql
UPDATE sessions
SET jwt_issued_at = %s,
    jwt_expires_at = %s,
    updated_at = NOW()
WHERE id = %s
```

## Response Structure

### Successful Response (200 OK)
```json
{
  "jwt": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6ImtleS0xMjMifQ...",
  "expires_in": 300,
  "issued_at": "2024-01-15T10:30:00.000Z",
  "expires_at": "2024-01-15T10:35:00.000Z"
}
```

### Response Fields

#### Authentication Fields
- **`jwt`**: New JWT token for subsequent requests
- **`expires_in`**: Token validity duration in seconds (typically 300)
- **`issued_at`**: Token issuance timestamp in ISO 8601 format
- **`expires_at`**: Token expiration timestamp in ISO 8601 format

## Error Scenarios

### 1. Missing Parameters (400)
```json
{
  "error": "MISSING_PARAMETERS",
  "message": "Either jwt_token or both api_key and session_id are required",
  "code": "VALIDATION_ERROR",
  "action_required": "Provide jwt_token (preferred) or api_key + session_id"
}
```

### 2. Invalid JSON (400)
```json
{
  "error": "INVALID_JSON",
  "message": "Invalid JSON in request body",
  "code": "PARSING_ERROR",
  "action_required": "Fix JSON syntax in request body"
}
```

### 3. Invalid JWT Token (400)
```json
{
  "error": "INVALID_JWT",
  "message": "Cannot extract session information from JWT or JWT signature invalid",
  "code": "TOKEN_INVALID",
  "action_required": "Restart session with /start endpoint - JWT is corrupted"
}
```

### 4. JWT Token Expired (401)
```json
{
  "error": "JWT_EXPIRED",
  "message": "JWT token has expired beyond refresh window",
  "code": "TOKEN_EXPIRED",
  "details": {
    "expired_at": "2024-01-15T10:30:00Z",
    "current_time": "2024-01-15T10:35:00Z"
  },
  "action_required": "Restart session with /start endpoint - token too old to refresh"
}
```

### 5. API Key Not Found (403)
```json
{
  "error": "API_KEY_NOT_FOUND",
  "message": "API key not found in system",
  "code": "API_KEY_INVALID",
  "action_required": "Check API key spelling or contact support"
}
```

### 6. License Expired (403)
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

### 7. License Inactive (403)
```json
{
  "error": "LICENSE_INACTIVE",
  "message": "License is deactivated",
  "code": "LICENSE_INACTIVE", 
  "action_required": "Contact support to reactivate license"
}
```

### 8. Session Not Found (403)
```json
{
  "error": "SESSION_NOT_FOUND",
  "message": "Session not found or deleted",
  "code": "SESSION_INVALID",
  "action_required": "Restart session with /start endpoint"
}
```

### 9. Session Inactive Too Long (403)
```json
{
  "error": "SESSION_INACTIVE_TOO_LONG",
  "message": "Session has been inactive too long for refresh",
  "code": "SESSION_EXPIRED",
  "details": {
    "last_heartbeat": "2024-01-15T09:30:00Z",
    "max_inactive_minutes": 60
  },
  "action_required": "Restart session with /start endpoint"
}

### 10. Token Generation Failed (500)
```json
{
  "error": "TOKEN_GENERATION_FAILED",
  "message": "Failed to generate new JWT token",
  "code": "TOKEN_GENERATION_FAILED",
  "action_required": "Retry refresh request or restart session if persistent"
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

### 12. Database Error (500)
```json
{
  "error": "DATABASE_ERROR",
  "message": "Database operation failed",
  "code": "DATABASE_ERROR",
  "action_required": "Retry refresh request in a few moments"
}
```

### 13. Cache Error (500)
```json
{
  "error": "CACHE_ERROR",
  "message": "Failed to update token cache",
  "code": "CACHE_ERROR",
  "action_required": "Token refresh may work but validation will be slower"
}
```

## Performance Considerations

### Database Optimization
```sql
-- Indexes for refresh operations
CREATE INDEX idx_sessions_license_active ON sessions(license_id, active);
CREATE INDEX idx_sessions_jwt_timestamps ON sessions(jwt_issued_at, jwt_expires_at);
CREATE INDEX idx_licenses_api_key_active ON licenses(api_key, active, start_date, end_date);
```

### Caching Strategy
```python
# JWT configuration cache
_jwt_config_cache = None
_jwt_config_cache_time = None
JWT_CONFIG_CACHE_TTL = 300  # 5 minutes

def get_cached_jwt_config():
    global _jwt_config_cache, _jwt_config_cache_time

    if _jwt_config_cache and time.time() - _jwt_config_cache_time < JWT_CONFIG_CACHE_TTL:
        return _jwt_config_cache

    _jwt_config_cache = fetch_jwt_config_from_parameter_store()
    _jwt_config_cache_time = time.time()
    return _jwt_config_cache
```

### Connection Pooling
```python
# Database connection reuse
db_manager = DatabaseManager(DB_ENDPOINT, SECRET_ARN)
# Lambda container reuse maintains connection pool
```

### Rate Limiting
```python
def check_refresh_rate_limit(session_id: int) -> bool:
    # Redis-based rate limiting
    key = f"refresh:{session_id}:{int(time.time() / 60)}"  # Per minute window
    count = redis_client.incr(key)
    redis_client.expire(key, 60)

    return count <= MAX_REFRESHES_PER_MINUTE
```

## Monitoring and Logging

### Key Metrics
```python
# Refresh success/failure rates
refresh_success_rate = (successful_refreshes / total_refresh_requests) * 100

# Authentication method distribution
jwt_method_usage = count_jwt_token_refreshes()
api_key_method_usage = count_api_key_refreshes()

# Average refresh processing time
avg_refresh_time = measure_average_processing_time()

# Session validation failures
session_validation_failures = count_session_validation_errors()
```

### Log Entries
```python
# Successful refresh
logger.info(f"Token refresh successful for session: {session_id}")

# Failed refresh
logger.warning(f"Token refresh failed for session {session_id}: {error_message}")

# Authentication method tracking
logger.info(f"Refresh using JWT method for session {session_id}")
logger.info(f"Refresh using API key method for session {session_id}")
```

### Alert Conditions
- Refresh failure rate > 5% over 5 minutes
- JWT generation failures > 1 per minute
- Session validation failures > 10 per minute
- Refresh rate limit violations > 5 per minute

## Refresh Timing Strategy

### Optimal Refresh Timing
```python
def calculate_optimal_refresh_time(token_expires_at: datetime) -> datetime:
    """
    Calculate when to refresh token to maintain session continuity
    """
    # Refresh 2 minutes before expiration
    refresh_buffer = timedelta(minutes=2)
    return token_expires_at - refresh_buffer
```

### Robot-Side Refresh Logic (Robot Doesn't Sign JWT)
```python
class TokenManager:
    def __init__(self, api_key: str, session_id: int = None):
        self.api_key = api_key
        self.session_id = session_id
        self.current_jwt = None
        self.jwt_expires_at = None

    def should_refresh(self) -> bool:
        if not self.current_jwt:
            return True

        # Robot decodes JWT payload to check expiration
        try:
            payload = json.loads(base64.b64decode(self.current_jwt.split('.')[1]))
            current_time = int(time.time())
            # Refresh if token expires within 2 minutes
            return payload['exp'] <= (current_time + 120)
        except:
            return True  # Refresh if can't decode

    def refresh_token(self):
        # Method 1: Use existing JWT (preferred)
        if self.current_jwt:
            response = self._refresh_with_jwt()
            if response.success:
                return self._update_token_from_response(response)
        
        # Method 2: Fallback to API key + session_id
        if self.session_id:
            response = self._refresh_with_api_key()
            if response.success:
                return self._update_token_from_response(response)
        
        raise Exception("Unable to refresh token")

    def _refresh_with_jwt(self):
        # Send existing JWT to server - robot doesn't modify it
        return self.http_client.post('/refresh', {
            'jwt_token': self.current_jwt
        })

    def _refresh_with_api_key(self):
        # Send API key and session ID
        return self.http_client.post('/refresh', {
            'api_key': self.api_key,
            'session_id': self.session_id
        })

    def _update_token_from_response(self, response):
        # Robot receives new JWT from server (doesn't create it)
        self.current_jwt = response.jwt
        # Robot can decode the new expiration time
        payload = json.loads(base64.b64decode(self.current_jwt.split('.')[1]))
        self.jwt_expires_at = datetime.fromtimestamp(payload['exp'])
        return response
```

## SDK Process for Robot

### Three-Layer Token Refresh Architecture
The SDK manages token refresh while preserving heartbeat data integrity:
- **Server ↔ SDK**: JWT refresh requests and new token responses
- **SDK Internal**: Data persistence during token transitions
- **SDK ↔ Robot**: Transparent token management (robot unaware of refresh)

### Token Refresh with Data Persistence
The SDK must handle token refresh while maintaining heartbeat data:

```mql5
// SDK internal token and data management
class TokenRefreshManager {
    private:
        string current_jwt;
        datetime jwt_expires_at;
        string api_key;
        int session_id;
        bool refresh_in_progress;
        
        // Critical: Data persistence during refresh
        HeartbeatData cached_heartbeat_data;
        bool heartbeat_data_pending;
        ConfigChangeResults cached_config_results;
        SymbolChangeResults cached_symbol_results;
}
```

**SDK Internal Process:**

1. **Automatic Refresh Trigger with Data Preservation**
   - Monitor JWT expiration by decoding token payload locally
   - Trigger refresh when token expires within 2 minutes (120 seconds buffer)
   - **Critical**: Before refresh, preserve any pending heartbeat data
   - Handle concurrent refresh requests (prevent multiple simultaneous refreshes)

2. **Pre-Request Token Check with Data Caching**
   ```mql5
   bool EnsureValidToken() {
       if (ShouldRefreshToken()) {
           // STEP 1: Preserve pending data before refresh
           PreservePendingData();
           
           // STEP 2: Perform token refresh
           if (RefreshTokenSynchronously()) {
               // STEP 3: Restore pending data after successful refresh
               RestorePendingData();
               return true;
           }
           return false;
       }
       return true;
   }
   
   void PreservePendingData() {
       if (heartbeat_manager.HasPendingData()) {
           cached_heartbeat_data = heartbeat_manager.GetPendingData();
           heartbeat_data_pending = true;
       }
       
       if (config_manager.HasPendingResults()) {
           cached_config_results = config_manager.GetPendingResults();
       }
       
       if (symbol_manager.HasPendingResults()) {
           cached_symbol_results = symbol_manager.GetPendingResults();
       }
   }
   ```

3. **Refresh Request Processing**
   - **Primary Method**: Send existing JWT token to `/refresh` endpoint
   - **Fallback Method**: Use stored API key + session ID if JWT refresh fails
   - **Data Safety**: Maintain all cached data throughout refresh process
   - Handle different authentication scenarios gracefully

4. **Response Processing with Data Restoration**
   - Extract new JWT token from server response
   - Update internal token storage and expiration time
   - **Critical**: Restore cached heartbeat data for next transmission
   - **Critical**: Restore pending configuration/symbol change results
   - Resume normal operations with new token and preserved data

5. **Post-Refresh Data Transmission**
   ```mql5
   void RestorePendingData() {
       if (heartbeat_data_pending) {
           // Schedule immediate heartbeat with cached data
           ScheduleImmediateHeartbeat(cached_heartbeat_data);
           heartbeat_data_pending = false;
       }
       
       // Restore pending change results for next heartbeat
       config_manager.RestorePendingResults(cached_config_results);
       symbol_manager.RestorePendingResults(cached_symbol_results);
   }
   ```

### Error Handling Strategy

**Refresh-Specific Error Processing:**
- **Token Expired**: Normal case, proceed with refresh using fallback method
- **License Expired**: Stop all operations, notify developer, require restart
- **Session Not Found**: Session was terminated, require full restart
- **Rate Limited**: Implement exponential backoff, respect server limits

**Cascading Failure Prevention:**
- Track refresh attempt frequency to prevent tight loops
- Implement circuit breaker pattern for persistent failures  
- Gracefully degrade functionality when refresh consistently fails
- Maintain operation history for debugging purposes

### Developer Integration

**Transparent Operation:**
The refresh process should be completely invisible to developers:

```mql5
// Developer code - SDK handles refresh automatically
bool SendTradeOrder(string symbol, double volume) {
    // SDK ensures valid token before any server communication
    if (!EnsureValidToken()) {
        return false; // SDK handles the error internally
    }
    
    // Proceed with trade order - token is guaranteed valid
    return ExecuteTradeRequest(symbol, volume);
}
```

**Optional Callbacks for Advanced Users:**
```mql5
// Optional: Developer can register callbacks for token events
void OnTokenRefreshSuccess() {
    Print("Token refreshed successfully");
}

void OnTokenRefreshFailure(string error_message, string action_required) {
    Print("Token refresh failed: ", error_message);
    Print("Required action: ", action_required);
    
    if (action_required == "restart_required") {
        // Notify user to restart the robot
        Alert("Robot needs to be restarted - license may have expired");
    }
}
```

### Retry and Fallback Logic

**Multi-Method Refresh Strategy:**
1. **Primary**: Use existing JWT token (preferred method)
2. **Secondary**: Use API key + session ID (fallback method)
3. **Tertiary**: Full session restart (last resort)

**Implementation Example:**
```mql5
bool RefreshTokenWithFallback() {
    // Method 1: JWT token refresh
    if (current_jwt != NULL) {
        RefreshResult result = RefreshWithJWT(current_jwt);
        if (result.success) {
            UpdateTokenFromResponse(result);
            return true;
        }
    }
    
    // Method 2: API key + session ID fallback
    if (api_key != NULL && session_id > 0) {
        RefreshResult result = RefreshWithApiKey(api_key, session_id);
        if (result.success) {
            UpdateTokenFromResponse(result);
            return true;
        }
        
        // Check if we need to restart session
        if (result.action_required == "restart_required") {
            return RestartSession();
        }
    }
    
    // Method 3: Full session restart
    return RestartSession();
}
```

### Performance Optimization

**Proactive Refresh Strategy:**
- Refresh tokens 2 minutes before expiration (avoid last-minute failures)
- Cache refresh responses to avoid unnecessary server calls
- Batch multiple operations after successful refresh
- Monitor refresh success rates and adjust timing if needed

**Memory Management:**
- Clear old JWT tokens after successful refresh
- Limit storage of failed refresh attempts
- Clean up cached data that becomes stale during refresh process

### Integration with Other Endpoints

**Heartbeat Coordination:**
- Pause heartbeat timer during token refresh process
- Resume heartbeat immediately after successful refresh
- Include refresh status in heartbeat if refresh fails

**Order Execution Protection:**
- Queue trade orders during token refresh process
- Execute queued orders after successful refresh
- Reject new orders if refresh fails with permanent error

## Troubleshooting

### Common Issues

#### Token Refresh Loop
**Problem:** Robot continuously refreshes tokens
**Cause:** System clock skew or token expiration calculation error
**Solution:** Verify system time synchronization

#### Session Not Found After Refresh
**Problem:** Refresh succeeds but subsequent requests fail
**Cause:** Session was cleaned up between refresh and next request
**Solution:** Implement proper error handling and restart session

#### High Latency Refreshes
**Problem:** Refresh requests taking longer than expected
**Cause:** Database connection issues or KMS latency
**Solution:** Monitor database and KMS performance metrics

### Debug Information
```python
def get_refresh_debug_info(session_id: int) -> Dict[str, Any]:
    return {
        'session_id': session_id,
        'session_status': get_session_status(session_id),
        'last_heartbeat': get_last_heartbeat(session_id),
        'license_status': get_license_status(session_id),
        'jwt_config': get_current_jwt_config(),
        'timestamp': datetime.utcnow().isoformat()
    }
```

This comprehensive refresh flow ensures seamless session continuity while maintaining security and performance standards. The dual authentication methods provide flexibility and reliability for different scenarios and failure modes.
