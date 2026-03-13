//+------------------------------------------------------------------+
//|                                                   CSDKLogger.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"

#ifndef CSDK_LOGGER_MQH
#define CSDK_LOGGER_MQH

#include "../Core/CSDKConstants.mqh"

//+------------------------------------------------------------------+
//| Global SDK Log Level                                              |
//|                                                                    |
//| Defaults to SDK_LOG_ALL (full verbosity) for development.         |
//| For the FINAL PRODUCT the programmer MUST set the level to        |
//| SDK_LOG_ERROR (errors only). Set via:                             |
//|   SDKSetLogLevel(SDK_LOG_ERROR);   or                              |
//|   myRobot.set_log_level(SDK_LOG_ERROR);   before on_init(),       |
//| or use an input with default SDK_LOG_ERROR.                       |
//+------------------------------------------------------------------+
ENUM_SDK_LOG_LEVEL g_sdk_log_level = SDK_LOG_ALL;

//+------------------------------------------------------------------+
//| Level-check helpers                                               |
//|                                                                    |
//| Use these before multi-argument Print() calls to skip message     |
//| construction entirely when the level is suppressed:               |
//|   if(SDKShouldLogInfo()) Print("SDK Info: ...", value);           |
//|                                                                    |
//| Errors bypass the check — they always print.                      |
//+------------------------------------------------------------------+
bool SDKShouldLogDebug(void)   { return (g_sdk_log_level <= SDK_LOG_ALL); }
bool SDKShouldLogInfo(void)    { return (g_sdk_log_level <= SDK_LOG_INFO); }
bool SDKShouldLogWarning(void) { return (g_sdk_log_level <= SDK_LOG_WARNING); }

//+------------------------------------------------------------------+
//| Getter / Setter                                                   |
//+------------------------------------------------------------------+
void SDKSetLogLevel(ENUM_SDK_LOG_LEVEL level)
{
    g_sdk_log_level = level;
}

ENUM_SDK_LOG_LEVEL SDKGetLogLevel(void)
{
    return g_sdk_log_level;
}

//+------------------------------------------------------------------+
//| Human-readable label for the current level                        |
//+------------------------------------------------------------------+
string SDKLogLevelToString(ENUM_SDK_LOG_LEVEL level)
{
    switch(level)
    {
        case SDK_LOG_ALL:     return "ALL";
        case SDK_LOG_INFO:    return "INFO";
        case SDK_LOG_WARNING: return "WARNING";
        case SDK_LOG_ERROR:   return "ERROR";
        default:                return "UNKNOWN";
    }
}

#endif
//+------------------------------------------------------------------+
