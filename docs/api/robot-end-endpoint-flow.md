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
10. [SDK Process for Robot](#sdk-process-for-robot)

## Robot Request Data Structure

### HTTP Request Format

**Endpoint:** `POST {SDK_API_BASE_URL}/robot/end`  
(e.g. `POST https://api.staging.themarketrobo.com/robot/end`)  
**Authorization:** `Bearer <jwt_token>`  
**Content-Type:** `application/json`

### Request Body Structure

The SDK builds the payload with **session_id** (required for the server to identify the session), **reason**, and optionally **final_stats**. The SDK obtains session_id from the stored value after `/robot/start`.

```json
{
  "session_id": 12345,
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

The **CFinalStats** class in the SDK (Models/CFinalStats.mqh) produces this structure via `to_json()`; field names match the above. When the SDK calls `terminate(reason)`, it creates a default CFinalStats instance (zeros and empty strings) and sends it with the end request; the programmer can extend the flow to populate final_stats if needed.

**Optional reason values** (examples): `normal_shutdown`, `error_shutdown`, `user_request`, `license_expired`, `system_error`, etc.

## Server Processing Flow

### Step 1: Cache-Based JWT Validation
The server validates the JWT token for termination:
1. Verify JWT signature with Secrets Manager secret
2. Allow expired tokens with grace period (5 minutes) for termination
3. Check cache for API key validation (even for termination)
4. If cache miss, allow if JWT is structurally valid (with warning)
5. Check license expiration from cache

### Step 2: Session Verification
The server verifies the session:
- Session exists in database
- Session belongs to authenticated license
- Session is currently active
- License is still valid

### Step 3: Pre-Termination Validation
The server validates if termination request is allowed:
- Check if session is already being terminated
- Check for pending operations
- Check session age (prevent premature termination, minimum 1 minute)

### Step 4: Session Termination
The server performs session termination:
- Update session status to inactive
- Set `ended_at` timestamp
- Store final statistics if provided
- Clear session from cache
- Log termination event

### Step 5: Final Statistics Storage
If `final_stats` is provided, the server stores:
- Total trades, winning trades, losing trades
- Total P&L and max drawdown
- Session duration
- Last error and shutdown reason

### Step 6: Session Event Logging
The server logs the session termination event with:
- Termination reason
- Termination timestamp
- Session duration
- Final statistics (if provided)

### Step 7: Cleanup Operations
The server performs cleanup:
- Clear pending change requests
- Archive session data if needed
- Update license usage statistics
- Send termination notifications

## Security and Authentication

### JWT Token Validation (Cache-Based)
The server validates JWT token for termination using cache:
1. Get JWT secret from Secrets Manager (cached)
2. Decode and verify JWT - allow grace period for termination (5 minutes)
3. Verify required claims (session_id, license_id, customer_id)
4. Check cache for additional validation
5. Check license expiration from cache

### Session Ownership Verification
The server verifies:
- Session belongs to authenticated user
- License ownership matches
- Customer ownership matches

### Termination Authorization
The server checks:
- Session must be active
- User must own the session (verified by JWT claims)
- Additional checks for enterprise features if applicable

## Database Operations

### Session Termination Query
The server updates the session record:
- Set `active` to false
- Set `ended_at` to current timestamp
- Update `updated_at` timestamp

### Final Statistics Storage Query
If final statistics are provided, the server inserts into `session_final_stats` table:
- Session ID
- Trading metrics (trades, P&L, drawdown)
- Session duration
- Error information
- Shutdown reason

### Session Event Logging Query
The server inserts termination event into `session_events` table with:
- Event type: 'session_terminated'
- Termination reason
- Final statistics (if provided)
- Timestamp

## Response Structure

### Successful Response (200 OK)

```json
{
  "status": "success",
  "message": "Session terminated successfully",
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
- **`terminated_at`**: Session termination timestamp in ISO 8601 format

#### Optional Fields
- **`session_duration`**: Session duration information
  - `minutes`: Total duration in minutes
  - `formatted`: Human-readable duration string
- **`cleanup_status`**: Status of cleanup operations (`completed`, `partial`, `failed`)

## Error Scenarios

### 1. Missing Authorization (401)
```json
{
  "type": "https://api.themarketrobo.com/problems/authentication-error",
  "title": "Authentication Failed",
  "status": 401,
  "detail": "Authorization header missing or malformed",
  "instance": "/api/v1/robots/end",
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
  "instance": "/api/v1/robots/end",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "auth_error_code": "TOKEN_INVALID"
}
```

### 3. JWT Token Too Old (401)
```json
{
  "type": "https://api.themarketrobo.com/problems/authentication-error",
  "title": "Authentication Failed",
  "status": 401,
  "detail": "JWT token expired beyond grace period for termination",
  "instance": "/api/v1/robots/end",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "auth_error_code": "TOKEN_TOO_OLD",
  "details": {
    "grace_period_minutes": 5,
    "expired_minutes_ago": 10
  }
}
```

### 4. License Expired (403)
```json
{
  "type": "https://api.themarketrobo.com/problems/authentication-error",
  "title": "Authentication Failed",
  "status": 403,
  "detail": "License has expired - termination allowed but limited",
  "instance": "/api/v1/robots/end",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "auth_error_code": "LICENSE_EXPIRED",
  "details": {
    "expired_at": "2024-01-15T10:30:00Z"
  }
}
```

### 5. Session Not Found (404)
```json
{
  "type": "https://api.themarketrobo.com/problems/session-error",
  "title": "Session Error",
  "status": 404,
  "detail": "Session not found or already deleted",
  "instance": "/api/v1/robots/end",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "session_error_code": "SESSION_NOT_FOUND"
}
```

### 6. Session Already Inactive (409)
```json
{
  "type": "https://api.themarketrobo.com/problems/session-error",
  "title": "Session Error",
  "status": 409,
  "detail": "Session is already inactive",
  "instance": "/api/v1/robots/end",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "session_error_code": "SESSION_ALREADY_INACTIVE",
  "details": {
    "terminated_at": "2024-01-15T10:25:00Z"
  }
}
```

## Cleanup Operations

### Cache Cleanup
The server removes session from all cache layers:
- Remove from Redis session cache
- Remove JWT token from cache if available
- Remove all JWT tokens for this session (fallback cleanup)
- Clear any pending heartbeat data

### Pending Changes Cleanup
The server clears all pending configuration and symbol changes:
- Clear `robot_config_change_request`
- Clear `session_symbols_change_request`

### Statistics Archival
The server archives session data for analytics and compliance:
- Move session events to archive table
- Create session summary record

## Monitoring and Logging

### Key Metrics
- Termination success/failure rates
- Average session duration
- Termination reasons distribution
- Cleanup operation success rate

### Session Termination Events
The server logs comprehensive termination events including:
- Event type: session_termination
- Session ID
- Termination reason
- Success status
- Session duration
- Cleanup status
- Final statistics stored flag

### Alert Conditions
- Termination failure rate > 5% over 10 minutes
- Database errors during termination > 1 per minute
- Sessions stuck in terminating state > 5
- Cleanup operation failures > 10 per hour

## SDK Process for Robot

### Three-Layer Termination Architecture
The SDK coordinates termination across all communication layers:
- **Server ↔ SDK**: Final statistics transmission and termination confirmation
- **SDK ↔ Robot**: Configuration cleanup and final data collection
- **Internal SDK**: Pending data resolution and resource cleanup

### Session Termination with Data Resolution
The SDK must resolve all pending configuration/symbol changes before termination:

**SDK Internal Process:**

1. **Termination Triggers**
   - **Manual**: Developer or user stops EA/Indicator (OnDeinit)
   - **Automatic**: Server sends `termination_requested` in heartbeat response; SDK fires termination event then calls `terminate(reason)` and sends `/robot/end`
   - **Graceful**: Normal shutdown; SDK calls `end_session(reason, final_stats)` from `CSessionManager`

2. **Pre-Termination**
   - SDK fires **termination start event** (`Fire_Termination_Start_Event`) before sending the request

3. **End Request**
   - Build payload: **session_id** (from stored value), **reason**, optional **final_stats** (CFinalStats: total_trades, winning_trades, losing_trades, total_pnl, max_drawdown, session_duration_minutes, last_error, shutdown_reason)
   - POST to **`/robot/end`** (relative to `SDK_API_BASE_URL`) with Bearer token

4. **Post-Response**
   - On success: mark session inactive; fire **termination end event** (`Fire_Termination_End_Event`); clear SDK state
   - On failure: log error; still mark session inactive locally

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

### Developer Integration

**Manual Termination:**
Developers can request termination with a reason. The SDK handles:
- Data resolution
- Final statistics collection
- Server notification
- Local cleanup

**Automatic Termination:**
The SDK automatically terminates in these scenarios:
- License expiration detected
- Critical authentication failures
- Unrecoverable network errors
- MetaTrader terminal shutdown

**Termination Status Feedback:**  
The SDK fires chart events for termination progress: **SDK_EVENT_TERMINATION_START** (before sending end request) and **SDK_EVENT_TERMINATION_END** (after response). For server-requested termination it fires **SDK_EVENT_TERMINATION_REQUESTED** with reason in sparam (JSON); the base class then calls `on_termination_requested()` and for EAs calls `ExpertRemove()`, for Indicators stops the timer and alerts the user.

### Final Statistics Collection

**Automatic Tracking:**
The SDK maintains running statistics throughout the session:
- Trade counters and P&L tracking
- Drawdown monitoring
- Session timing
- Error logging

**Statistics Structure:**
- Total trades, winning trades, losing trades
- Total P&L and max drawdown
- Session duration in minutes
- Last error message
- Shutdown reason

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
If EA/Indicator crashes during termination:
- Next startup should check for incomplete sessions
- Send "crash_recovery" termination notification to server
- Perform cleanup of any remaining resources

## Performance Considerations

### Database Optimization
- Indexes for termination operations
- Optimized queries for session status checks
- Partitioned session events table by date

### Batch Cleanup Operations
- Efficient cleanup of multiple sessions
- Batch database updates
- Batch cache cleanup

### Connection Management
- Handle termination with retry logic
- Exponential backoff for retry attempts
- Graceful degradation on persistent failures

This comprehensive termination flow ensures clean session closure, proper resource cleanup, and accurate final statistics collection while maintaining security and reliability standards.
