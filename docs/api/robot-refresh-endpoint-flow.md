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
9. [SDK Process for Robot](#sdk-process-for-robot)

## Robot Request Data Structure

### HTTP Request Format

**Endpoint:** `POST {SDK_API_BASE_URL}/robot/refresh`  
(e.g. `POST https://api.staging.themarketrobo.com/robot/refresh`)  
**Content-Type:** `application/json`  
**Authorization:** `Bearer <current_jwt_token>` (SDK sends the current token in the header and in the body)

### Request Body Structure

**Method used by SDK: JWT Token**
```json
{
  "jwt_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

The **current SDK implementation** uses only this method. The SDK sends the existing (possibly expired) JWT in both the `Authorization: Bearer` header and as `jwt_token` in the body. The server returns a new JWT in the response; the SDK stores it and continues heartbeats with the new token.

**Optional server-supported fallback (not implemented in SDK): API Key + Session ID**
Some server implementations may support a fallback for recovery when the JWT is lost; the SDK does not currently implement this.

### Key Request Fields

- **`jwt_token`**: Current or expired JWT token. The SDK sends it in the body and in the Authorization header. The robot/indicator does not modify the token.

## Server Processing Flow

### Step 1: Request Validation
The server parses and validates the request body:
- Extract authentication parameters (jwt_token or api_key + session_id)
- Validate that at least one authentication method is provided
- Return error if neither method is provided

### Step 2: Authentication Method Selection
The server determines which authentication method to use:
- **Method 1**: If `jwt_token` is provided, extract session info from JWT
- **Method 2**: If `api_key` and `session_id` are provided, validate API key

### Step 3: Session Information Extraction

#### From JWT Token (Method 1)
The server decodes the JWT token (without verification) to extract:
- `session_id`: Session identifier
- `license_id`: License identifier
- `customer_id`: Customer identifier
- `issued_at`: Token issuance timestamp
- `expires_at`: Token expiration timestamp

#### From API Key + Session ID (Method 2)
The server validates the API key by querying the database:
- Verify API key exists and is valid
- Check license is within validity period
- Verify license is active

### Step 4: Session Validation
The server validates the session:
- Session exists in database
- Session is marked as active
- Session belongs to authenticated license (if license_id provided)
- Session hasn't been terminated or cleaned up

### Step 5: License Re-validation
The server re-validates the license:
- License exists and is valid
- License is within validity period
- Associated customer and robot type are active

### Step 6: Session Activity Validation
The server checks if refresh is allowed:
- Verify session hasn't been inactive too long (max 1 hour since last heartbeat)
- Check if license is still valid
- Return error if session is too inactive or license expired

### Step 7: JWT Token Generation with Cache Update
The server generates a new JWT token:
- **Algorithm**: HS256 (HMAC with SHA-256)
- **Secret Source**: AWS Secrets Manager (cached)
- **Token TTL**: 5 minutes (300 seconds)
- **Payload**: Contains same session context as original token

**JWT Payload Structure:**
- `iss`: Issuer ('trading-robot-server')
- `aud`: Audience ('trading-robot')
- `jti`: Unique JWT identifier
- `iat`: Issued at timestamp
- `exp`: Expiration timestamp (5 minutes from now)
- `license_id`: License identifier
- `session_id`: Session identifier
- `customer_id`: Customer identifier

**Cache Update:**
- Store new JWT token in cache with API key and license expiration
- Cache TTL: 6 minutes (token expiration + 1 minute buffer)
- Clean up old token from cache if exists

### Step 8: Session Update
The server updates the session record with new JWT timestamps:
- `jwt_issued_at`: New token issuance time
- `jwt_expires_at`: New token expiration time

### Step 9: Response Construction
The server constructs the response with:
- New JWT token
- Token expiration duration
- Token issuance timestamp
- Token expiration timestamp

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

### JWT Signing Process
1. **Algorithm**: HS256 (HMAC with SHA-256)
2. **Key Management**: AWS Secrets Manager with automatic rotation
3. **Token Structure**: header.payload.signature (payload readable by robot)
4. **Security Features**:
   - Timestamp-based uniqueness (`jti`)
   - Audience validation (`aud`)
   - Issuer validation (`iss`)
   - Expiration checking (`exp`) - Robot can check locally
   - Cache-based validation for performance

### Session Context Validation
The server verifies:
- Session belongs to authenticated license
- Session is marked as active
- Session hasn't been terminated

### Refresh Rate Limiting
The server implements rate limiting:
- Maximum 10 refreshes per minute per session
- Prevents abuse and excessive refresh requests

## Database Operations

### License Validation Query
The server queries licenses table to verify:
- API key exists and is valid
- License is within validity period
- License is active

### Session Validation Query
The server queries sessions table to verify:
- Session exists
- Session is active
- Session belongs to authenticated license

### Session Update Query
The server updates session record with:
- New JWT issuance timestamp
- New JWT expiration timestamp

## Response Structure

### Successful Response (200 OK)

```json
{
  "jwt": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "expires_in": 300
}
```

### Response Fields

#### Authentication Fields
- **`jwt`**: New JWT token for subsequent requests
- **`expires_in`**: Token validity duration in seconds (typically 300)

**Note:** Token timestamps (`iat`, `exp`) and session identifiers are available in the JWT payload. The robot can decode the payload locally to check expiration.

## Error Scenarios

### 1. Missing Parameters (400)
```json
{
  "type": "https://api.themarketrobo.com/problems/validation-error",
  "title": "Validation Error",
  "status": 400,
  "detail": "Either jwt_token or both api_key and session_id are required",
  "instance": "/api/v1/robots/refresh",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456"
}
```

### 2. Invalid JWT Token (400)
```json
{
  "type": "https://api.themarketrobo.com/problems/authentication-error",
  "title": "Authentication Failed",
  "status": 400,
  "detail": "Cannot extract session information from JWT or JWT signature invalid",
  "instance": "/api/v1/robots/refresh",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "auth_error_code": "INVALID_JWT"
}
```

### 3. License Expired (403)
```json
{
  "type": "https://api.themarketrobo.com/problems/authentication-error",
  "title": "Authentication Failed",
  "status": 403,
  "detail": "Your license has expired",
  "instance": "/api/v1/robots/refresh",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "auth_error_code": "LICENSE_EXPIRED",
  "details": {
    "expired_at": "2024-01-15T10:30:00Z"
  }
}
```

### 4. Session Not Found (403)
```json
{
  "type": "https://api.themarketrobo.com/problems/session-error",
  "title": "Session Error",
  "status": 403,
  "detail": "Session not found or deleted",
  "instance": "/api/v1/robots/refresh",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "session_error_code": "SESSION_NOT_FOUND"
}
```

### 5. Session Inactive Too Long (403)
```json
{
  "type": "https://api.themarketrobo.com/problems/session-error",
  "title": "Session Error",
  "status": 403,
  "detail": "Session has been inactive too long for refresh",
  "instance": "/api/v1/robots/refresh",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "request_id": "req_abc123def456",
  "session_error_code": "SESSION_INACTIVE_TOO_LONG",
  "details": {
    "last_heartbeat": "2024-01-15T09:30:00Z",
    "max_inactive_minutes": 60
  }
}
```

## Performance Considerations

### Database Optimization
- Indexes for refresh operations on sessions and licenses tables
- Optimized queries for session validation
- Connection pooling for database access

### Caching Strategy
- JWT configuration cache (5 minute TTL)
- Secrets Manager secrets cached locally
- Session data cached in Redis

### Connection Pooling
- Database connection reuse
- Lambda container reuse maintains connection pool

### Rate Limiting
- Redis-based rate limiting per session
- Maximum 10 refreshes per minute per session
- Prevents abuse and excessive refresh requests

## Monitoring and Logging

### Key Metrics
- Refresh success/failure rates
- Authentication method distribution (JWT vs API key)
- Average refresh processing time
- Session validation failures

### Log Entries
- Successful refresh events
- Failed refresh attempts with error details
- Authentication method tracking
- Session validation failures

### Alert Conditions
- Refresh failure rate > 5% over 5 minutes
- JWT generation failures > 1 per minute
- Session validation failures > 10 per minute
- Refresh rate limit violations > 5 per minute

## SDK Process for Robot

### Three-Layer Token Refresh Architecture
The SDK manages token refresh while preserving heartbeat data integrity:
- **Server ↔ SDK**: JWT refresh requests and new token responses
- **SDK Internal**: Data persistence during token transitions
- **SDK ↔ Robot**: Transparent token management (robot unaware of refresh)

### Token Refresh with Data Persistence
The SDK must handle token refresh while maintaining heartbeat data:

**SDK Internal Process:**

1. **Automatic Refresh Trigger with Data Preservation**
   - Monitor JWT expiration by decoding token payload locally (check `exp` claim)
   - Trigger refresh when token expires within threshold — **default in SDK is 60 seconds** (`SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD` in CSDKConstants.mqh); configurable via `set_token_refresh_threshold(seconds)` (range 60–3600)
   - Before refresh, preserve any pending heartbeat data
   - Prevent multiple simultaneous refresh requests

2. **Refresh Request**
   - Send POST to **`/robot/refresh`** (relative to `SDK_API_BASE_URL`)
   - Body: `{ "jwt_token": "<current_token>" }`
   - Authorization: `Bearer <current_token>`

3. **Response Processing**
   - On 200: extract new JWT from response `jwt` field; update internal token storage; fire token refresh event; resume heartbeats with new token (and any cached data)
   - On failure: fire token refresh event with success=false; SDK may remove EA or stop indicator timer depending on product type

### Error Handling Strategy

**Refresh-Specific Error Processing:**
- **Token Expired**: Normal case, proceed with refresh using fallback method if needed
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
The refresh process should be completely invisible to developers. The SDK automatically:
- Checks token expiration before any server communication
- Refreshes token proactively before expiration
- Preserves all data during token transitions
- Handles errors gracefully

**Automatic Token Management:**
The SDK automatically handles:
- Token expiration checking (by decoding JWT payload locally)
- Proactive refresh before expiration
- Data preservation during refresh
- Error recovery and retry logic

### Retry and Fallback Logic

The SDK uses **JWT-only** refresh. If refresh fails (e.g. session not found, license expired), the SDK does not fall back to api_key + session_id in the current implementation; it handles the error (e.g. triggers termination or removes EA / stops indicator timer).

### Performance Optimization

**Proactive Refresh Strategy:**
- Refresh tokens before expiration; default threshold **60 seconds** in SDK (`SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD`)
- After successful refresh, resume heartbeat with new token (and any cached payload)

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

This comprehensive refresh flow ensures seamless session continuity while maintaining security and performance standards. The dual authentication methods provide flexibility and reliability for different scenarios and failure modes.
