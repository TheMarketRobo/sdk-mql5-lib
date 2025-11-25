//+------------------------------------------------------------------+
//|                                             CSDK_Constants.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSDK_CONSTANTS_MQH
#define CSDK_CONSTANTS_MQH

/**
 * @file CSDK_Constants.mqh
 * @brief SDK-level constants and configuration values.
 *
 * This file contains all hardcoded SDK constants including:
 * - API endpoints
 * - Version information
 * - Default configuration values
 *
 * ## Environment URLs
 * - Staging: http://api.staging.themarketrobo.com/
 * - Production: https://api.themarketrobo.com/ (future)
 */

//+------------------------------------------------------------------+
//| API Configuration                                                |
//+------------------------------------------------------------------+

/**
 * @brief Base URL for the TheMarketRobo API.
 * @note This is the staging environment URL.
 */
#define SDK_API_BASE_URL "http://api.staging.themarketrobo.com/"

/**
 * @brief API version string.
 */
#define SDK_API_VERSION "v1"

//+------------------------------------------------------------------+
//| SDK Version                                                      |
//+------------------------------------------------------------------+

/**
 * @brief SDK major version number.
 */
#define SDK_VERSION_MAJOR 1

/**
 * @brief SDK minor version number.
 */
#define SDK_VERSION_MINOR 0

/**
 * @brief SDK patch version number.
 */
#define SDK_VERSION_PATCH 0

/**
 * @brief SDK version string.
 */
#define SDK_VERSION "1.0.0"

//+------------------------------------------------------------------+
//| Default Configuration                                            |
//+------------------------------------------------------------------+

/**
 * @brief Default token refresh threshold in seconds.
 * Token will be refreshed this many seconds before expiration.
 */
#define SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD 300

/**
 * @brief Minimum token refresh threshold in seconds.
 */
#define SDK_MIN_TOKEN_REFRESH_THRESHOLD 60

/**
 * @brief Maximum token refresh threshold in seconds.
 */
#define SDK_MAX_TOKEN_REFRESH_THRESHOLD 3600

/**
 * @brief Default heartbeat interval in seconds.
 */
#define SDK_DEFAULT_HEARTBEAT_INTERVAL 60

/**
 * @brief Maximum heartbeat interval in seconds.
 */
#define SDK_MAX_HEARTBEAT_INTERVAL 300

//+------------------------------------------------------------------+
//| API Endpoints                                                    |
//+------------------------------------------------------------------+

/**
 * @brief Session start endpoint.
 */
#define SDK_ENDPOINT_START "/robot/start"

/**
 * @brief Session end endpoint.
 */
#define SDK_ENDPOINT_END "/robot/end"

/**
 * @brief Token refresh endpoint.
 */
#define SDK_ENDPOINT_REFRESH "/robot/refresh"

/**
 * @brief Heartbeat endpoint.
 */
#define SDK_ENDPOINT_HEARTBEAT "/robot/heartbeat"

//+------------------------------------------------------------------+
//| Limits                                                           |
//+------------------------------------------------------------------+

/**
 * @brief Maximum API key length.
 */
#define SDK_MAX_API_KEY_LENGTH 64

/**
 * @brief UUID length (standard UUID format).
 */
#define SDK_UUID_LENGTH 36

/**
 * @brief Maximum symbol name length.
 */
#define SDK_MAX_SYMBOL_LENGTH 32

#endif
//+------------------------------------------------------------------+

