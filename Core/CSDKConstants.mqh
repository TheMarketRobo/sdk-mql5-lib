//+------------------------------------------------------------------+
//|                                               CSDKConstants.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSDK_CONSTANTS_MQH
#define CSDK_CONSTANTS_MQH

//+------------------------------------------------------------------+
//| SDK Version                                                       |
//+------------------------------------------------------------------+
#define SDK_VERSION "1.0.0"
#define SDK_UUID_LENGTH 36  // Standard UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

//+------------------------------------------------------------------+
//| API Configuration                                                 |
//+------------------------------------------------------------------+
/**
 * SDK_API_BASE_URL
 * 
 * The base URL for TheMarketRobo API. This is a hardcoded SDK constant
 * and is NOT configurable by the robot programmer or customer.
 *
 * Current: Staging environment
 * Production: https://api.themarketrobo.com/
 *
 * Note: To switch between staging and production, this constant must
 * be changed and the SDK recompiled. This is intentional to prevent
 * accidental connections to the wrong environment.
 */
#define SDK_API_BASE_URL "https://api.staging.themarketrobo.com"

//+------------------------------------------------------------------+
//| Default Configuration Values                                      |
//+------------------------------------------------------------------+

/**
 * Default token refresh threshold in seconds.
 * Tokens will be refreshed this many seconds before expiration.
 * Minimum: 60 seconds, Maximum: 3600 seconds
 * 
 * Note: This MUST be less than the JWT expiration time (default 300 seconds).
 * If set equal to or greater than expiration, refresh will trigger immediately!
 */
#define SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD 60

/**
 * Default heartbeat interval in seconds.
 * This is the fallback interval if the server doesn't specify one.
 */
#define SDK_DEFAULT_HEARTBEAT_INTERVAL 60

/**
 * Maximum heartbeat interval in seconds.
 * Server-specified intervals greater than this will be clamped.
 */
#define SDK_MAX_HEARTBEAT_INTERVAL 300

//+------------------------------------------------------------------+
//| Error Codes (matching API contract)                               |
//+------------------------------------------------------------------+

// Configuration error codes
#define SDK_ERROR_INVALID_VALUE     "INVALID_VALUE"
#define SDK_ERROR_OUT_OF_RANGE      "OUT_OF_RANGE"
#define SDK_ERROR_FIELD_NOT_FOUND   "FIELD_NOT_FOUND"
#define SDK_ERROR_READ_ONLY_FIELD   "READ_ONLY_FIELD"

// Symbol error codes
#define SDK_ERROR_SYMBOL_NOT_FOUND      "SYMBOL_NOT_FOUND"
#define SDK_ERROR_SYMBOL_UNAVAILABLE    "SYMBOL_UNAVAILABLE"
#define SDK_ERROR_TRADING_DISABLED      "TRADING_DISABLED"

//+------------------------------------------------------------------+
//| Change Result Status Values                                       |
//+------------------------------------------------------------------+
#define SDK_STATUS_ALL_ACCEPTED       "all_accepted"
#define SDK_STATUS_ALL_REJECTED       "all_rejected"
#define SDK_STATUS_PARTIALLY_ACCEPTED "partially_accepted"

//+------------------------------------------------------------------+
//| HTTP Configuration                                                |
//+------------------------------------------------------------------+
#define SDK_HTTP_TIMEOUT 5000  // 5 seconds

//+------------------------------------------------------------------+
//| Session States                                                    |
//+------------------------------------------------------------------+
enum ENUM_SDK_SESSION_STATE
{
    SDK_SESSION_NONE,       // No session
    SDK_SESSION_STARTING,   // Session is being started
    SDK_SESSION_ACTIVE,     // Session is active
    SDK_SESSION_REFRESHING, // Token is being refreshed
    SDK_SESSION_ENDING,     // Session is being terminated
    SDK_SESSION_ENDED       // Session has ended
};

//+------------------------------------------------------------------+
//| Heartbeat States                                                  |
//+------------------------------------------------------------------+
enum ENUM_SDK_HEARTBEAT_STATE
{
    SDK_HEARTBEAT_IDLE,             // Waiting for next heartbeat
    SDK_HEARTBEAT_SENDING,          // Heartbeat is being sent
    SDK_HEARTBEAT_WAITING_CONFIRM,  // Waiting for server confirmation
    SDK_HEARTBEAT_FAILED            // Last heartbeat failed
};

#endif
//+------------------------------------------------------------------+

