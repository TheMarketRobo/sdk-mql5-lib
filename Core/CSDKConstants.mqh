//+------------------------------------------------------------------+
//|                                               CSDKConstants.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSDK_CONSTANTS_MQH
#define CSDK_CONSTANTS_MQH

//+------------------------------------------------------------------+
//| SDK Master Toggle                                                  |
//|                                                                    |
//| Define SDK_ENABLED to activate all SDK functionality:              |
//|   - Session management (start / heartbeat / end)                   |
//|   - JWT authentication and token refresh                           |
//|   - Remote configuration and symbol change handling                |
//|   - Data collection and telemetry                                  |
//|   - DLL imports (kernel32.dll, wininet.dll — indicators only)      |
//|                                                                    |
//| Comment out or #undef SDK_ENABLED to run the robot or indicator    |
//| in standalone mode with ZERO SDK overhead:                         |
//|   - No network calls, no DLL imports, no session management        |
//|   - All SDK lifecycle methods become safe no-ops                   |
//|   - on_init() returns INIT_SUCCEEDED immediately                   |
//|   - Your trading/indicator logic runs normally without the SDK     |
//|                                                                    |
//| To disable the SDK for a single file (e.g. one indicator), define  |
//| TMR_SDK_DISABLED before including the SDK in that file.            |
//|                                                                    |
//| Security: When disabled, the compiled binary contains no SDK       |
//| code, no DLL references, and no API URLs — nothing to decompile.   |
//+------------------------------------------------------------------+
#ifndef TMR_SDK_DISABLED
#define SDK_ENABLED
#endif

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

//+------------------------------------------------------------------+
//| Product Types                                                     |
//+------------------------------------------------------------------+
/**
 * Determines which MQL5 program type is using the SDK.
 * - PRODUCT_TYPE_ROBOT:     Expert Advisor — can trade, uses magic_number,
 *                           supports remote config and symbol change requests.
 * - PRODUCT_TYPE_INDICATOR: Custom Indicator — read-only, no magic_number,
 *                           no config or symbol change requests.
 */
enum ENUM_SDK_PRODUCT_TYPE
{
    PRODUCT_TYPE_ROBOT,      // Expert Advisor (EA) — trading program
    PRODUCT_TYPE_INDICATOR   // Custom Indicator — chart analysis program
};

// Product type string identifiers (must match API contract values)
#define SDK_PRODUCT_TYPE_ROBOT     "robot"
#define SDK_PRODUCT_TYPE_INDICATOR "indicator"

#endif
//+------------------------------------------------------------------+

