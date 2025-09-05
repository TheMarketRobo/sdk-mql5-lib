# Trading Robot /end Endpoint - Complete Flow Documentation

## Overview
This document provides a comprehensive explanation of the `/end` endpoint flow for trading robots in the serverless trading robot control system. The `/end` endpoint serves as the graceful termination mechanism, allowing robots to properly close their sessions and perform cleanup operations. This refactored version uses cache-based JWT validation and provides clear error responses for SDK development.

## Table of Contents
1. [Robot Request Data Structure](#robot-request-data-structure)
2. [Server Processing Flow](#server-processing-flow)
3. [Session Termination Logic](#session-termination-logic)
4. [Security and Authentication](#security-and-authentication)
5. [Database Operations](#database-operations)
6. [Response Structure](#response-structure)
7. [Error Scenarios](#error-scenarios)
8. [Cleanup Operations](#cleanup-operations)
9. [Monitoring and Logging](#monitoring-and-logging)

## Robot Request Data Structure

### HTTP Request Format
```
POST /robots/end
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "session_id": "integer (required)",
  "reason": "string (optional)",
  "final_stats": {
    "total_trades": 25,
    "winning_trades": 18,
    "losing_trades": 7,
    "total_pnl": 1250.50,
    "max_drawdown": 150.00,
    "session_duration_minutes": 480,
    "last_error": null,
    "shutdown_reason": "scheduled_maintenance"
  }
}
```

### Key Request Fields

#### Required Fields
- **`session_id`**: Unique session identifier from /start response
- **Authorization Header**: Valid JWT token (`Bearer <token>`)

#### Optional Fields
- **`reason`**: Human-readable reason for termination
  - `"normal_shutdown"`: Regular session end
  - `"error_shutdown"`: Error condition caused shutdown
  - `"maintenance_shutdown"`: System maintenance
  - `"user_request"`: User manually stopped session
  - `"license_expired"`: License validity ended
  - `"system_error"`: System-level error

- **`final_stats`**: Final trading statistics object
  - Trading performance metrics
  - Session duration information
  - Error conditions and shutdown reasons
  - Final account state

## Server Processing Flow

### Step 1: Cache-Based JWT Validation
```python
# Extract JWT token from Authorization header
jwt_token = extract_bearer_token(event.headers)

# New cache-based validation for /end endpoint
def validate_jwt_for_termination(jwt_token: str) -> Dict[str, Any]:
    # 1. Verify JWT signature with Secrets Manager secret
    try:
        jwt_secret = secrets_manager.get_cached_secret('jwt-signing-secret')
        payload = jwt.decode(jwt_token, jwt_secret, algorithms=['HS256'])
    except jwt.ExpiredSignatureError:
        # Allow expired tokens for termination with grace period
        grace_period = 300  # 5 minutes grace period for termination
        try:
            payload = jwt.decode(jwt_token, jwt_secret, algorithms=['HS256'], 
                               options={"verify_exp": False})
            if payload['exp'] < (int(datetime.utcnow().timestamp()) - grace_period):
                return {'error': 'TOKEN_TOO_OLD', 'action': 'restart_required'}
        except:
            return {'error': 'TOKEN_INVALID', 'action': 'restart_required'}
    except jwt.InvalidTokenError:
        return {'error': 'TOKEN_INVALID', 'action': 'restart_required'}
    
    # 2. Check cache for API key validation (even for termination)
    cache_key = f"jwt:{jwt_token}"
    cache_data = redis_client.get(cache_key)
    
    if not cache_data:
        # For termination, allow if JWT is structurally valid
        # but warn that validation couldn't be completed
        return {
            'valid': True,
            'session_id': payload['session_id'],
            'license_id': payload['license_id'],
            'warning': 'CACHE_MISS_ON_TERMINATION'
        }
    
    cache_info = json.loads(cache_data)
    
    # 3. Check license expiration from cache
    license_expires_at = datetime.fromisoformat(cache_info['license_expires_at'])
    if license_expires_at <= datetime.utcnow():
        return {'error': 'LICENSE_EXPIRED', 'action': 'restart_required'}
    
    return {
        'valid': True,
        'session_id': payload['session_id'],
        'license_id': payload['license_id'],
        'api_key': cache_info['api_key']
    }

# Validate JWT for termination
validation_result = validate_jwt_for_termination(jwt_token)
if 'error' in validation_result:
    return create_error_response(validation_result)

session_id = validation_result['session_id']
license_id = validation_result['license_id']
```

### Step 2: Session Verification
```python
def verify_session_for_termination(session_id: int, license_id: int) -> Optional[Dict[str, Any]]:
    """Verify session exists and can be terminated"""
    query = """
    SELECT s.*, l.api_key, l.customer_id
    FROM sessions s
    JOIN licenses l ON s.license_id = l.id
    WHERE s.id = %s AND s.license_id = %s AND s.active = true
    """

    result = db_manager.execute_query(query, (session_id, license_id))
    return result[0] if result else None
```

**Session Verification Checks:**
- Session exists in database
- Session belongs to authenticated license
- Session is currently active
- License is still valid

### Step 3: Pre-Termination Validation
```python
def validate_termination_request(session: Dict[str, Any], request_data: Dict[str, Any]) -> tuple[bool, Optional[str]]:
    """Validate if termination request is allowed"""

    # Check if session is already being terminated
    if session.get('terminating', False):
        return False, "Session is already being terminated"

    # Check for pending operations
    pending_operations = check_pending_operations(session['id'])
    if pending_operations:
        return False, f"Session has {len(pending_operations)} pending operations"

    # Check session age (prevent premature termination)
    session_age_minutes = calculate_session_age(session['started_at'])
    if session_age_minutes < 1:  # Less than 1 minute
        return False, "Session is too new to terminate"

    return True, None
```

### Step 4: Session Termination
```python
def terminate_session(session_id: int, reason: str, final_stats: Optional[Dict] = None) -> bool:
    """Perform session termination"""

    # Update session status
    termination_query = """
    UPDATE sessions
    SET active = false,
        ended_at = NOW(),
        updated_at = NOW()
    WHERE id = %s AND active = true
    """

    result = db_manager.execute_query(termination_query, (session_id,))

    if not result:
        return False

    # Store final statistics if provided
    if final_stats:
        store_final_statistics(session_id, final_stats)

    # Clear session from cache
    session_cache.invalidate_session(session_id)

    # Log termination event
    log_session_termination(session_id, reason, final_stats)

    return True
```

### Step 5: Final Statistics Storage
```python
def store_final_statistics(session_id: int, final_stats: Dict[str, Any]):
    """Store final session statistics"""
    query = """
    INSERT INTO session_final_stats (
        session_id, total_trades, winning_trades, losing_trades,
        total_pnl, max_drawdown, session_duration_minutes,
        last_error, shutdown_reason, created_at
    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
    """

    params = (
        session_id,
        final_stats.get('total_trades'),
        final_stats.get('winning_trades'),
        final_stats.get('losing_trades'),
        final_stats.get('total_pnl'),
        final_stats.get('max_drawdown'),
        final_stats.get('session_duration_minutes'),
        final_stats.get('last_error'),
        final_stats.get('shutdown_reason')
    )

    db_manager.execute_query(query, params)
```

### Step 6: Session Event Logging
```python
def log_session_termination(session_id: int, reason: str, final_stats: Optional[Dict] = None):
    """Log session termination event"""
    event_data = {
        'termination_reason': reason,
        'termination_timestamp': datetime.utcnow().isoformat(),
        'session_duration': calculate_session_duration(session_id)
    }

    if final_stats:
        event_data['final_stats'] = final_stats

    db_manager.log_session_event(
        session_id=session_id,
        event_type='session_terminated',
        result='success',
        reason=reason,
        payload=event_data
    )
```

### Step 7: Cleanup Operations
```python
def perform_session_cleanup(session_id: int):
    """Perform cleanup operations after session termination"""

    # Clear pending change requests
    clear_pending_changes(session_id)

    # Archive session data if needed
    archive_session_data(session_id)

    # Update license usage statistics
    update_license_usage_stats(session_id)

    # Send termination notifications
    send_termination_notifications(session_id)
```

## Security and Authentication

### JWT Token Validation (Cache-Based)
```python
def validate_jwt_for_termination(token: str) -> Dict[str, Any]:
    """Validate JWT token for session termination using cache"""
    try:
        # Get JWT secret from Secrets Manager (cached)
        jwt_secret = secrets_manager.get_cached_secret('jwt-signing-secret')
        
        # Decode and verify JWT - allow grace period for termination
        try:
            claims = jwt.decode(token, jwt_secret, algorithms=['HS256'])
        except jwt.ExpiredSignatureError:
            # Allow expired tokens with grace period for termination
            claims = jwt.decode(token, jwt_secret, algorithms=['HS256'], 
                              options={"verify_exp": False})
            grace_period = 300  # 5 minutes
            if claims['exp'] < (int(datetime.utcnow().timestamp()) - grace_period):
                return {'error': 'TOKEN_TOO_OLD'}

        # Verify required claims
        required_claims = ['session_id', 'license_id', 'customer_id']
        for claim in required_claims:
            if claim not in claims:
                return {'error': 'MISSING_CLAIMS'}

        # Check cache for additional validation
        cache_key = f"jwt:{token}"
        cache_data = redis_client.get(cache_key)
        
        if cache_data:
            cache_info = json.loads(cache_data)
            license_expires_at = datetime.fromisoformat(cache_info['license_expires_at'])
            if license_expires_at <= datetime.utcnow():
                return {'error': 'LICENSE_EXPIRED'}

        return {
            'valid': True,
            'claims': claims,
            'cache_available': bool(cache_data)
        }

    except jwt.InvalidTokenError:
        return {'error': 'INVALID_TOKEN'}
```

### Session Ownership Verification
```python
def verify_session_ownership(session_id: int, token_claims: Dict[str, Any]) -> bool:
    """Verify session belongs to authenticated user"""
    session = db_get_session(session_id)

    if not session:
        return False

    # Verify license ownership
    if session['license_id'] != token_claims['license_id']:
        return False

    # Verify customer ownership
    if session['customer_id'] != token_claims['customer_id']:
        return False

    return True
```

### Termination Authorization
```python
def check_termination_authorization(session: Dict[str, Any], token_claims: Dict[str, Any]) -> bool:
    """Check if user is authorized to terminate session"""
    # Session must be active
    if not session.get('active', False):
        return False

    # User must own the session (verified by JWT claims)
    if session['customer_id'] != token_claims['customer_id']:
        return False

    # Additional checks for enterprise features
    if has_enterprise_features(session['license_id']):
        return check_enterprise_permissions(token_claims)

    return True
```

## Database Operations

### Session Termination Query
```sql
UPDATE sessions
SET active = false,
    ended_at = NOW(),
    updated_at = NOW()
WHERE id = $1 AND active = true
RETURNING ended_at
```

### Final Statistics Storage Query
```sql
INSERT INTO session_final_stats (
    session_id, total_trades, winning_trades, losing_trades,
    total_pnl, max_drawdown, session_duration_minutes,
    last_error, shutdown_reason, created_at
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
```

### Session Event Logging Query
```sql
INSERT INTO session_events (
    session_id, event_type, result, reason, payload, created_at
) VALUES ($1, $2, $3, $4, $5, NOW())
```

## Response Structure

### Successful Response (200 OK)
```json
{
  "status": "success",
  "message": "Session terminated successfully",
  "session_id": 12345,
  "terminated_at": "2024-01-15T14:30:00.000Z",
  "session_duration": {
    "minutes": 480,
    "formatted": "8h 0m"
  },
  "cleanup_status": "completed"
}
```

### Response Fields

#### Core Fields
- **`status`**: Always "success" for 200 responses
- **`message`**: Human-readable success message
- **`session_id`**: Echoed session identifier
- **`terminated_at`**: Session termination timestamp in ISO 8601 format

#### Optional Fields
- **`session_duration`**: Session duration information
  - `minutes`: Total duration in minutes
  - `formatted`: Human-readable duration string
- **`cleanup_status`**: Status of cleanup operations
- **`final_stats_stored`**: Boolean indicating if final statistics were stored

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
  "action_required": "Session cannot be terminated with invalid token - restart session if needed"
}
```

### 3. JWT Token Too Old (401)
```json
{
  "error": "TOKEN_TOO_OLD",
  "message": "JWT token expired beyond grace period for termination",
  "code": "TOKEN_TOO_OLD",
  "details": {
    "grace_period_minutes": 5,
    "expired_minutes_ago": 10
  },
  "action_required": "Session termination not possible with old token"
}
```

### 4. License Expired (403)
```json
{
  "error": "LICENSE_EXPIRED",
  "message": "License has expired - termination allowed but limited",
  "code": "LICENSE_EXPIRED",
  "details": {
    "expired_at": "2024-01-15T10:30:00Z"
  },
  "action_required": "Session will be terminated, renew license for future sessions"
}
```

### 5. Session Not Found (404)
```json
{
  "error": "SESSION_NOT_FOUND",
  "message": "Session not found or already deleted",
  "code": "SESSION_NOT_FOUND",
  "action_required": "Session may have been already terminated or cleaned up"
}
```

### 6. Session Already Inactive (409)
```json
{
  "error": "SESSION_ALREADY_INACTIVE",
  "message": "Session is already inactive",
  "code": "SESSION_ALREADY_INACTIVE",
  "details": {
    "terminated_at": "2024-01-15T10:25:00Z"
  },
  "action_required": "Session already terminated - no further action needed"
}
```

### 7. Session Not Owned (403)
```json
{
  "error": "SESSION_NOT_OWNED",
  "message": "Session does not belong to your license",
  "code": "SESSION_ACCESS_DENIED",
  "action_required": "You can only terminate sessions belonging to your license"
}
```

### 8. Pending Operations (409)
```json
{
  "error": "PENDING_OPERATIONS",
  "message": "Session has pending operations - termination delayed",
  "code": "PENDING_OPERATIONS",
  "details": {
    "pending_count": 3,
    "pending_types": ["config_change", "symbol_change"],
    "estimated_completion_seconds": 30
  },
  "action_required": "Wait for pending operations to complete then retry termination"
}
```

### 9. Session Too New (400)
```json
{
  "error": "SESSION_TOO_NEW",
  "message": "Session is too new to terminate (prevents accidental termination)",
  "code": "SESSION_TOO_NEW",
  "details": {
    "session_age_minutes": 0.5,
    "minimum_age_minutes": 1
  },
  "action_required": "Wait at least 1 minute before terminating session"
}
```

### 10. Termination Failed (500)
```json
{
  "error": "TERMINATION_FAILED",
  "message": "Failed to terminate session due to database error",
  "code": "TERMINATION_FAILED",
  "action_required": "Retry termination request or contact support"
}
```

### 11. Cache Cleanup Failed (500)
```json
{
  "error": "CACHE_CLEANUP_FAILED",
  "message": "Session terminated but cache cleanup failed",
  "code": "CACHE_CLEANUP_FAILED",
  "details": {
    "session_terminated": true,
    "cache_cleanup": false
  },
  "action_required": "Session is terminated - cache will be cleaned up automatically"
}
```

## Cleanup Operations

### Cache Cleanup (Updated for New Architecture)
```python
def cleanup_session_cache(session_id: int, current_jwt: str = None):
    """Remove session from all cache layers"""
    try:
        # Remove from Redis session cache
        session_cache.invalidate_session(session_id)

        # Remove JWT token from cache if available
        if current_jwt:
            jwt_cache_key = f"jwt:{current_jwt}"
            redis_client.delete(jwt_cache_key)
        
        # Remove all JWT tokens for this session (fallback)
        # This is a more expensive operation but ensures cleanup
        pattern = f"jwt:*"
        for key in redis_client.scan_iter(match=pattern):
            cache_data = redis_client.get(key)
            if cache_data:
                try:
                    cache_info = json.loads(cache_data)
                    if cache_info.get('session_id') == session_id:
                        redis_client.delete(key)
                except json.JSONDecodeError:
                    # Remove corrupted cache entries
                    redis_client.delete(key)

        # Clear any pending heartbeat data
        heartbeat_cache.clear_session_data(session_id)

        logger.info(f"Cache cleanup completed for session {session_id}")

    except Exception as e:
        logger.error(f"Cache cleanup failed for session {session_id}: {str(e)}")
        # Continue with termination even if cache cleanup fails
```

### Pending Changes Cleanup
```python
def clear_pending_changes(session_id: int):
    """Clear all pending configuration and symbol changes"""
    queries = [
        "UPDATE sessions SET robot_config_change_request = NULL WHERE id = %s",
        "UPDATE sessions SET session_symbols_change_request = NULL WHERE id = %s"
    ]

    for query in queries:
        db_manager.execute_query(query, (session_id,))
```

### Statistics Archival
```python
def archive_session_data(session_id: int):
    """Archive session data for analytics and compliance"""
    try:
        # Move session events to archive table
        archive_query = """
        INSERT INTO session_events_archive
        SELECT * FROM session_events WHERE session_id = %s
        """

        db_manager.execute_query(archive_query, (session_id,))

        # Create session summary record
        create_session_summary(session_id)

    except Exception as e:
        logger.error(f"Session archival failed for session {session_id}: {str(e)}")
```

## Monitoring and Logging

### Key Metrics
```python
# Termination success/failure rates
termination_success_rate = (successful_terminations / total_termination_requests) * 100

# Average session duration
avg_session_duration = calculate_average_session_duration()

# Termination reasons distribution
termination_reasons = count_termination_reasons()

# Cleanup operation success rate
cleanup_success_rate = (successful_cleanups / total_cleanups) * 100
```

### Session Termination Events
```python
def log_termination_event(session_id: int, reason: str, success: bool, details: Dict[str, Any]):
    """Log comprehensive termination event"""
    event_data = {
        'event_type': 'session_termination',
        'session_id': session_id,
        'termination_reason': reason,
        'success': success,
        'timestamp': datetime.utcnow().isoformat(),
        'session_duration': calculate_session_duration(session_id),
        'cleanup_status': details.get('cleanup_status'),
        'final_stats_stored': details.get('final_stats_stored', False)
    }

    logger.info(f"Session termination: {json.dumps(event_data)}")
```

### Alert Conditions
- Termination failure rate > 5% over 10 minutes
- Database errors during termination > 1 per minute
- Sessions stuck in terminating state > 5
- Cleanup operation failures > 10 per hour

## Robot-Side Termination Logic

### Graceful Shutdown Sequence
```python
class RobotSessionManager:
    def __init__(self, session_id: int, jwt_token: str):
        self.session_id = session_id
        self.jwt_token = jwt_token
        self.is_shutting_down = False

    def initiate_shutdown(self, reason: str = "normal_shutdown"):
        """Initiate graceful shutdown sequence"""
        if self.is_shutting_down:
            return  # Already shutting down

        self.is_shutting_down = True
        logger.info(f"Initiating shutdown for session {self.session_id}: {reason}")

        try:
            # Stop trading operations
            self.stop_trading_operations()

            # Close all positions if configured
            if self.should_close_positions():
                self.close_all_positions()

            # Gather final statistics
            final_stats = self.collect_final_statistics()

            # Send termination request
            self.send_termination_request(reason, final_stats)

            # Wait for confirmation
            confirmation = self.wait_for_termination_confirmation()

            if confirmation:
                logger.info(f"Session {self.session_id} terminated successfully")
            else:
                logger.error(f"Session {self.session_id} termination failed")

        except Exception as e:
            logger.error(f"Shutdown failed for session {self.session_id}: {str(e)}")

    def send_termination_request(self, reason: str, final_stats: Dict[str, Any]):
        """Send termination request to server using existing JWT"""
        payload = {
            'session_id': self.session_id,
            'reason': reason,
            'final_stats': final_stats
        }

        headers = {
            'Authorization': f'Bearer {self.jwt_token}',  # Use JWT received from server
            'Content-Type': 'application/json'
        }

        try:
            # Robot can check JWT expiration locally before sending
            if self.is_token_expired():
                logger.warning("JWT token expired - attempting termination anyway with grace period")
            
            # Send POST request to /robots/end
            response = requests.post('/robots/end', json=payload, headers=headers)

            if response.status_code == 200:
                return response.json()
            elif response.status_code == 401:
                # Token issues - server allows some grace period for termination
                error_response = response.json()
                if error_response.get('code') == 'TOKEN_TOO_OLD':
                    raise Exception(f"Token too old for termination: {error_response['message']}")
                else:
                    raise Exception(f"Authentication failed: {error_response['message']}")
            else:
                error_response = response.json()
                raise Exception(f"Termination failed: {error_response.get('message', 'Unknown error')}")
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Network error during termination: {str(e)}")
            raise

    def is_token_expired(self) -> bool:
        """Check if JWT token is expired (robot can decode locally)"""
        try:
            payload = json.loads(base64.b64decode(self.jwt_token.split('.')[1]))
            return payload['exp'] <= int(time.time())
        except:
            return True  # Assume expired if can't decode
```

### Termination Confirmation
```python
def wait_for_termination_confirmation(self, timeout_seconds: int = 30) -> bool:
    """Wait for server confirmation of termination"""
    start_time = time.time()

    while time.time() - start_time < timeout_seconds:
        try:
            # Check session status (this would be a separate endpoint)
            status = self.check_session_status()

            if status == 'terminated':
                return True
            elif status == 'termination_failed':
                return False

            time.sleep(1)  # Wait 1 second before checking again

        except Exception as e:
            logger.error(f"Status check failed: {str(e)}")
            time.sleep(2)  # Wait longer on error

    return False  # Timeout
```

## SDK Process for Robot

### Three-Layer Termination Architecture
The SDK coordinates termination across all communication layers:
- **Server ↔ SDK**: Final statistics transmission and termination confirmation
- **SDK ↔ Robot**: Configuration cleanup and final data collection  
- **Internal SDK**: Pending data resolution and resource cleanup

### Session Termination with Data Resolution
The SDK must resolve all pending configuration/symbol changes before termination:

```mql5
// SDK termination management with data integrity
class SessionTerminationManager {
    private:
        bool is_terminating;
        bool auto_terminate_on_error;
        string termination_reason;
        FinalStats final_stats;
        
        // Data resolution during termination
        bool has_pending_config_changes;
        bool has_pending_symbol_changes;
        HeartbeatData final_heartbeat_data;
        ConfigChangeResults final_config_results;
        SymbolChangeResults final_symbol_results;
}
```

**SDK Internal Process:**

1. **Termination Triggers**
   - **Manual**: Developer calls `TerminateSession()` method
   - **Automatic**: Critical errors, license expiration, or EA shutdown
   - **Graceful**: Normal EA shutdown (OnDeinit with reason REASON_REMOVE)
   - **Emergency**: System errors or unrecoverable failures

2. **Pre-Termination Data Resolution**
   ```mql5
   bool PrepareForTermination() {
       // 1. Check for pending configuration changes
       if (config_manager.HasPendingResults()) {
           final_config_results = config_manager.GetPendingResults();
           has_pending_config_changes = true;
       }
       
       // 2. Check for pending symbol changes
       if (symbol_manager.HasPendingResults()) {
           final_symbol_results = symbol_manager.GetPendingResults();
           has_pending_symbol_changes = true;
       }
       
       // 3. Send final heartbeat with pending changes if needed
       if (has_pending_config_changes || has_pending_symbol_changes) {
           SendFinalHeartbeat();
       }
       
       return true;
   }
   ```

3. **Final Data Collection**
   ```mql5
   void CollectFinalStatistics() {
       final_stats.total_trades = GetTotalTrades();
       final_stats.winning_trades = GetWinningTrades();
       final_stats.losing_trades = GetLosingTrades();
       final_stats.total_pnl = GetTotalPnL();
       final_stats.max_drawdown = GetMaxDrawdown();
       final_stats.session_duration_minutes = GetSessionDuration();
       final_stats.last_error = GetLastError();
       final_stats.shutdown_reason = termination_reason;
       
       // Include final configuration state
       final_stats.final_config = developer_config.ToJSON();
       final_stats.final_symbol_count = GetActiveSymbolCount();
   }
   ```

4. **Graceful Shutdown Sequence**
   - **Step 1**: Resolve pending configuration/symbol changes
   - **Step 2**: Stop all trading operations (disable auto-trading)
   - **Step 3**: Cancel pending orders (if configured to do so)
   - **Step 4**: Close open positions (if configured and safe to do so)
   - **Step 5**: Collect final trading statistics
   - **Step 6**: Send termination request to server with complete data
   - **Step 7**: Clean up internal resources

5. **Token Handling for Termination**
   - Check if JWT token is expired using local decoding
   - Allow termination even with expired token (server has 5-minute grace period)
   - Handle authentication errors gracefully during termination
   - **Critical**: Include final configuration/symbol results even with expired token
   - Log termination attempt regardless of authentication status

### Error Handling During Termination

**Token Issues:**
- **Expired Token**: Proceed with termination (server allows 5-minute grace period)
- **Invalid Token**: Log error but continue with local cleanup
- **No Token**: Skip server notification, perform local cleanup only

**Network Issues:**
- **Connection Failure**: Retry termination request 3 times with increasing delays
- **Timeout**: Complete local cleanup, log failed server notification
- **Server Error**: Log error, ensure local resources are cleaned up

**Server Rejection:**
- **Session Not Found**: Consider termination successful (already cleaned up)
- **Session Already Inactive**: Log warning but consider successful
- **Authentication Failed**: Complete local cleanup anyway

### Developer Integration with Termination Callbacks

**Extended Callback Interface for Termination:**
```mql5
// Extended callback interface including termination events
class IConfigUpdateCallback {
public:
    // Configuration and symbol change callbacks (same as heartbeat)
    virtual void OnConfigurationChanged(string field_name, string old_value, string new_value) = 0;
    virtual void OnSymbolStatusChanged(string symbol, bool active_to_trade) = 0;
    
    // Termination-specific callbacks
    virtual void OnTerminationStarted(string reason) { }
    virtual void OnPendingDataResolution(bool config_pending, bool symbol_pending) { }
    virtual void OnFinalDataCollection() { }
    virtual void OnTerminationCompleted(bool success, string message) { }
    virtual void OnTerminationError(string error_message) { }
};
```

**Manual Termination with Callbacks:**
```mql5
// In developer's EA class
class MyExpertAdvisor : public IConfigUpdateCallback {
public:
    // Manual termination method
    bool RequestTermination(string reason = "manual_shutdown") {
        Print("Requesting session termination: ", reason);
        return TerminateSession(reason);  // SDK method
    }

    // EA shutdown integration
    void OnDeinit(const int reason) {
        string shutdown_reason = GetShutdownReason(reason);
        Print("EA shutting down with reason: ", shutdown_reason);
        
        // SDK automatically handles termination with callbacks
        TerminateSession(shutdown_reason);
    }
    
    // Termination progress callbacks
    void OnTerminationStarted(string reason) override {
        Print("SDK started termination process: ", reason);
        // Robot can perform custom cleanup here
        SaveTradeHistory();
        LogFinalState();
    }
    
    void OnPendingDataResolution(bool config_pending, bool symbol_pending) override {
        if (config_pending) {
            Print("SDK resolving pending configuration changes...");
        }
        if (symbol_pending) {
            Print("SDK resolving pending symbol changes...");
        }
        // Robot can wait or perform additional cleanup
    }
    
    void OnFinalDataCollection() override {
        Print("SDK collecting final statistics...");
        // Robot can add custom final data
        AddCustomFinalData();
    }
    
    void OnTerminationCompleted(bool success, string message) override {
        if (success) {
            Print("Session terminated successfully: ", message);
            CleanupRobotResources();
        } else {
            Print("Termination failed: ", message);
            // Even if server communication failed, local cleanup succeeded
            CleanupRobotResources();
        }
    }
    
    void OnTerminationError(string error_message) override {
        Print("Termination error: ", error_message);
        // SDK continues with local cleanup even on server errors
    }

private:
    string GetShutdownReason(int reason) {
        switch(reason) {
            case REASON_REMOVE: return "ea_removed";
            case REASON_RECOMPILE: return "ea_recompiled";
            case REASON_CHARTCHANGE: return "chart_changed";
            case REASON_CHARTCLOSE: return "chart_closed";
            case REASON_PARAMETERS: return "parameters_changed";
            case REASON_ACCOUNT: return "account_changed";
            default: return "system_shutdown";
        }
    }
};
```

**Automatic Termination:**
The SDK should automatically terminate in these scenarios:
- License expiration detected
- Critical authentication failures
- Unrecoverable network errors
- MetaTrader terminal shutdown

**Configuration Options:**
```mql5
// SDK configuration for termination behavior
struct TerminationConfig {
    bool auto_close_positions;      // Close positions on termination
    bool auto_cancel_orders;        // Cancel pending orders
    bool force_termination;         // Terminate even with active trades
    int termination_timeout_seconds; // Max time to wait for graceful shutdown
};
```

### Termination Status Feedback

**Progress Callbacks:**
```mql5
// Optional developer callbacks for termination progress
void OnTerminationStarted(string reason) {
    Print("Starting session termination: ", reason);
}

void OnPositionsClosing(int position_count) {
    Print("Closing ", position_count, " open positions...");
}

void OnServerNotificationSent() {
    Print("Server termination notification sent successfully");
}

void OnTerminationCompleted(bool server_notified, bool cleanup_success) {
    Print("Session termination completed. Server notified: ", server_notified);
    Print("Local cleanup successful: ", cleanup_success);
}

void OnTerminationError(string error_message) {
    Print("Termination error: ", error_message);
    // SDK continues with local cleanup
}
```

### Final Statistics Collection

**Automatic Tracking:**
The SDK should maintain running statistics throughout the session:
- Trade counters and P&L tracking
- Drawdown monitoring
- Session timing
- Error logging

**Statistics Calculation:**
```mql5
struct FinalStats {
    int total_trades;
    int winning_trades;
    int losing_trades;
    double total_pnl;
    double max_drawdown;
    int session_duration_minutes;
    string last_error;
    string shutdown_reason;
    
    // Additional metrics
    double win_rate;
    double profit_factor;
    double avg_win;
    double avg_loss;
};
```

### Resource Cleanup

**Memory Management:**
- Free all allocated memory structures
- Clear cached data and temporary files
- Release network connections
- Stop all timers and background tasks

**Persistence:**
- Save important session data to local files
- Export final statistics for analysis
- Store termination logs for debugging
- Clear sensitive data (tokens, keys)

### Recovery Scenarios

**Incomplete Termination:**
If termination process is interrupted:
- SDK should detect incomplete termination on next startup
- Attempt to send delayed termination notification
- Clean up any remaining resources
- Log the recovery process for analysis

**Crash Recovery:**
If EA crashes during termination:
- Next startup should check for incomplete sessions
- Send "crash_recovery" termination notification to server
- Perform cleanup of any remaining resources

## Performance Considerations

### Database Optimization
```sql
-- Indexes for termination operations
CREATE INDEX idx_sessions_active_ended ON sessions(active, ended_at);
CREATE INDEX idx_sessions_termination_time ON sessions(ended_at DESC);
CREATE INDEX idx_session_final_stats_session_id ON session_final_stats(session_id);

-- Partition session_events by date for better performance
CREATE TABLE session_events_y2024m01 PARTITION OF session_events
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

### Batch Cleanup Operations
```python
def batch_cleanup_sessions(session_ids: List[int]):
    """Cleanup multiple sessions efficiently"""
    if not session_ids:
        return

    # Batch database updates
    placeholders = ','.join(['%s'] * len(session_ids))

    # Update sessions table
    update_query = f"""
    UPDATE sessions
    SET active = false, ended_at = NOW(), updated_at = NOW()
    WHERE id IN ({placeholders})
    """
    db_manager.execute_query(update_query, session_ids)

    # Batch cache cleanup
    for session_id in session_ids:
        session_cache.invalidate_session(session_id)

    logger.info(f"Batch cleaned up {len(session_ids)} sessions")
```

### Connection Management
```python
def handle_termination_with_retry(session_id: int, max_retries: int = 3):
    """Handle termination with retry logic"""
    for attempt in range(max_retries):
        try:
            success = terminate_session(session_id)

            if success:
                return True

        except DatabaseError as e:
            if attempt == max_retries - 1:
                raise  # Last attempt failed

            logger.warning(f"Termination attempt {attempt + 1} failed, retrying...")
            time.sleep(2 ** attempt)  # Exponential backoff

    return False
```

This comprehensive termination flow ensures clean session closure, proper resource cleanup, and accurate final statistics collection while maintaining security and reliability standards.
