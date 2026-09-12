//+------------------------------------------------------------------+
//|                                             CSDKUserErrors.mqh   |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"

#ifndef CSDK_USER_ERRORS_MQH
#define CSDK_USER_ERRORS_MQH

#include "CSDKLogger.mqh"
#include "../TMR_Platform.mqh"
#include "../Core/CSDKErrorCatalog.generated.mqh"
#include "../Core/CSDKConstants.mqh"

//+------------------------------------------------------------------+
//| SDK User-Facing Error Utility                                     |
//|                                                                    |
//| All Alert() messages from the SDK flow through these helpers so   |
//| that end users always see short, non-technical messages while     |
//| programmers can still find the technical detail in the Experts    |
//| log via Print().                                                   |
//|                                                                    |
//| Error-level messages (SDKUserError, SDKUserErrorWithDetails)      |
//| ALWAYS print regardless of the global log level.                   |
//+------------------------------------------------------------------+

#define TMKR_USER_PREFIX "TheMarketRobo: "

//+------------------------------------------------------------------+
//| Show a user-friendly alert (short message only)                   |
//+------------------------------------------------------------------+
void TMKRUserError(string short_msg)
{
    Alert(TMKR_USER_PREFIX + short_msg);
    Print("SDK User Error: ", short_msg);
}

//+------------------------------------------------------------------+
//| Show a user-friendly alert + log technical details for devs       |
//+------------------------------------------------------------------+
void TMKRUserErrorWithDetails(string short_msg, string technical_detail)
{
    Alert(TMKR_USER_PREFIX + short_msg);
    Print("SDK User Error: ", short_msg);
    Print("SDK Technical Detail: ", technical_detail);
}

//+------------------------------------------------------------------+
//| Coded helpers (single-line, code-FIRST)                           |
//|                                                                    |
//| The TMKR-#### code is printed FIRST on a single line so it is      |
//| unmissable in the Experts tab and trivial to copy into the search  |
//| at themarketrobo.com/problems. Every line also carries the exact   |
//| docs URL for that code. Codes come from CSDKErrorCatalog.generated |
//| (single source of truth: aws/contracts/schemas/error_catalog).     |
//+------------------------------------------------------------------+

// "[TMKR-3001] TheMarketRobo: <msg> (themarketrobo.com/problems/TMKR-3001)"
string TMKRFormatCoded(string code, string msg)
{
    return "[" + code + "] " + TMKR_USER_PREFIX + msg +
           " (" + TMKR_PROBLEMS_BASE_URL + "/" + code + ")";
}

// Error to the Experts log only (code-first; errors always print).
void TMKRErrorCoded(string code, string msg)
{
    Print(TMKRFormatCoded(code, msg));
}

// Error shown to the user (Alert) AND logged on one code-first line.
void TMKRUserErrorCoded(string code, string short_msg)
{
    string line = TMKRFormatCoded(code, short_msg);
    Alert(line);
    Print(line);
}

// Like TMKRUserErrorCoded, plus a code-prefixed technical detail line for devs.
void TMKRUserErrorCodedWithDetails(string code, string short_msg, string technical_detail)
{
    string line = TMKRFormatCoded(code, short_msg);
    Alert(line);
    Print(line);
    Print("[" + code + "] SDK Technical Detail: ", technical_detail);
}

// Warning to the Experts log (code-first). Respects the configured log level.
void TMKRWarnCoded(string code, string msg)
{
    if(SDKShouldLogWarning())
        Print("[", code, "] SDK Warning: ", msg, " (", TMKR_PROBLEMS_BASE_URL, "/", code, ")");
}

// Info to the Experts log (code-first). Respects the configured log level.
void TMKRInfoCoded(string code, string msg)
{
    if(SDKShouldLogInfo())
        Print("[", code, "] SDK Info: ", msg, " (", TMKR_PROBLEMS_BASE_URL, "/", code, ")");
}

//+------------------------------------------------------------------+
//| Map common MQL5 GetLastError() codes to plain-English messages   |
//| These are the errors an end user might encounter; the function   |
//| returns a short sentence suitable for an Alert() dialog.          |
//+------------------------------------------------------------------+
string GetUserFriendlyErrorMessage(int mql_error_code)
{
    switch(mql_error_code)
    {
        //--- General runtime errors
        case 0:      return "";  // No error
        case 4001:   return "An internal error occurred. Please restart MetaTrader and try again.";
        case 4003:   return "An invalid setting was detected. Please check your inputs.";
        case 4004:   return "Not enough memory. Please close other programs and try again.";
        case 4014:   return "This feature is not available in the current environment.";

        //--- Network / WebRequest errors
        case 4060:   return "Network requests are not allowed. Please enable them in Tools > Options > Expert Advisors.";
        case 5200:   return "Cannot connect: the server address is invalid. Please contact support.";
        case 5201:   return "Cannot connect to the server. Please check your internet connection.";
        case 5202:   return "Connection timed out. Please check your internet and try again.";
        case 5203:   return "Connection was refused by the server. Please try again later.";

        //--- DLL / indicator-specific
        case 4015:   return "A resource conflict occurred. Please remove and re-add the indicator.";
        case 4012:   return "An internal pointer error occurred. Please restart MetaTrader.";

        //--- Catch-all
        default:
            return "An unexpected error occurred (code " + IntegerToString(mql_error_code) +
                   "). Please contact support.";
    }
}

//+------------------------------------------------------------------+
//| Get a user-friendly message for HTTP response failures            |
//| Maps common HTTP status codes to messages end users understand.   |
//+------------------------------------------------------------------+
string GetUserFriendlyHTTPMessage(int http_code)
{
    if(http_code == 0 || http_code == -1)
        return "Could not connect to the server. Please check your internet connection and try again.";
    if(http_code == 401)
        return "Your session has expired or your API Key is invalid. Please check your API Key.";
    if(http_code == 403)
        return "Access denied. Your API Key may not be authorized for this product.";
    if(http_code == 404)
        return "The service could not be found. Please contact support.";
    if(http_code == 429)
        return "Too many requests. Please wait a moment and try again.";
    if(http_code >= 500)
        return "The server is temporarily unavailable. Please try again later.";
    
    return "Connection failed (HTTP " + IntegerToString(http_code) +
           "). Please check your internet connection or contact support.";
}

//+------------------------------------------------------------------+
//| Map a raw MQL GetLastError() code to its TMKR-#### code so the    |
//| user can look up the fix at themarketrobo.com/problems.           |
//+------------------------------------------------------------------+
string GetCodeForMqlError(int mql_error_code)
{
    switch(mql_error_code)
    {
        case 4060: return TMKR_ERR_3001;  // WebRequest not in the allowed list
        case 5200: return TMKR_ERR_3002;  // invalid server address
        case 5201: return TMKR_ERR_3003;  // cannot connect
        case 5202: return TMKR_ERR_3004;  // timeout
        case 5203: return TMKR_ERR_3005;  // refused
        case 4014: return TMKR_ERR_3010;  // WebRequest unavailable from this context (indicator)
        default:   return TMKR_ERR_9010;  // generic SDK/runtime failure
    }
}

//+------------------------------------------------------------------+
//| Map an HTTP status to its TMKR-#### code. Used as a fallback when |
//| the response body carries no machine-readable "code" field (e.g.  |
//| a bare authorizer 401). When the body HAS a code, callers show    |
//| that exact code instead.                                          |
//+------------------------------------------------------------------+
string GetCodeForHTTPStatus(int http_code)
{
    if(http_code == 0 || http_code == -1) return TMKR_ERR_3020;  // no response
    if(http_code == 401)                  return TMKR_ERR_2003;  // expired/invalid session
    if(http_code == 403)                  return TMKR_ERR_2001;  // access denied / API key
    if(http_code == 429)                  return TMKR_ERR_3050;  // rate limited
    if(http_code >= 500)                  return TMKR_ERR_9001;  // server error
    return TMKR_ERR_9001;
}

//+------------------------------------------------------------------+
//| Session start refusals                                            |
//|                                                                    |
//| A refused POST /robot/start answers RFC 7807 problem+json whose   |
//| "code" is the canonical TMKR-####. These helpers turn that code   |
//| (or, only when the body carries none, the HTTP status) into a     |
//| typed reason and a short, non-technical sentence for the trader.  |
//|                                                                    |
//| Anti-oracle: an unknown, malformed, deleted or rotated-out key    |
//| all answer the SAME TMKR-2001, so its sentence never guesses.     |
//+------------------------------------------------------------------+

// True when tmkr_s is a canonical code: "TMKR-" followed by four digits.
bool TMKRIsCanonicalCode(string tmkr_s)
{
    if(StringLen(tmkr_s) != 9) return false;
    if(StringSubstr(tmkr_s, 0, 5) != "TMKR-") return false;
    for(int tmkr_i = 5; tmkr_i < 9; tmkr_i++)
    {
        ushort tmkr_ch = StringGetCharacter(tmkr_s, tmkr_i);
        if(tmkr_ch < '0' || tmkr_ch > '9') return false;
    }
    return true;
}

// Classify a refused /robot/start. A canonical code from the response body
// wins; the HTTP status is a fallback for bodies that carry no code.
ENUM_TMKR_START_REFUSAL TMKRStartRefusalFor(string tmkr_code, int http_code)
{
    if(TMKRIsCanonicalCode(tmkr_code))
    {
        if(tmkr_code == TMKR_ERR_2001) return TMKR_START_KEY_NOT_RECOGNIZED;
        if(tmkr_code == TMKR_ERR_2005) return TMKR_START_LICENSE_EXPIRED;
        if(tmkr_code == TMKR_ERR_2006) return TMKR_START_LICENSE_INACTIVE;
        if(tmkr_code == TMKR_ERR_2008) return TMKR_START_VERSION_NOT_COVERED;
        if(tmkr_code == TMKR_ERR_2009) return TMKR_START_SUBMISSION_NOT_TESTABLE;
        if(tmkr_code == TMKR_ERR_4004) return TMKR_START_MAX_SESSIONS;
        if(tmkr_code == TMKR_ERR_3050) return TMKR_START_RATE_LIMITED;
        if(tmkr_code == TMKR_ERR_4008 || tmkr_code == TMKR_ERR_4009 || tmkr_code == TMKR_ERR_4010)
            return TMKR_START_REQUEST_REJECTED;
        if(StringSubstr(tmkr_code, 5, 1) == "9") return TMKR_START_SERVER_ERROR;
        return TMKR_START_UNKNOWN;
    }
    if(http_code == 0 || http_code == -1) return TMKR_START_NO_CONNECTION;
    if(http_code == 429)                  return TMKR_START_RATE_LIMITED;
    if(http_code >= 500)                  return TMKR_START_SERVER_ERROR;
    // A 401/403 with no machine-readable code did not come from the licence
    // gate, which always sends one (e.g. an edge proxy's HTML page) — so do
    // not claim a key or licence problem.
    return TMKR_START_UNKNOWN;
}

// The code to alert for a refusal: the server's own code when it sent one,
// otherwise the catalog code that fits the reason.
string TMKRStartRefusalCode(ENUM_TMKR_START_REFUSAL tmkr_reason, string tmkr_code, int http_code)
{
    if(TMKRIsCanonicalCode(tmkr_code)) return tmkr_code;
    if(tmkr_reason == TMKR_START_CONFIG_INVALID || tmkr_reason == TMKR_START_NOT_ATTEMPTED)
        return TMKR_ERR_9010;
    if(tmkr_reason == TMKR_START_UNKNOWN) return TMKR_ERR_3020;  // bodyless 4xx: never a key/session code
    return GetCodeForHTTPStatus(http_code);                      // 0/-1 → 3020, 429 → 3050, 5xx → 9001
}

// Short, non-technical sentence for the trader. Numbers from the problem's
// "context" are used only when the server sent them (pass -1 when absent).
string TMKRStartRefusalMessage(ENUM_TMKR_START_REFUSAL tmkr_reason,
                               long tmkr_active_sessions, long tmkr_max_sessions,
                               long tmkr_retry_after, bool tmkr_demo_only, int http_code)
{
    switch(tmkr_reason)
    {
        case TMKR_START_OK:
            return "";
        case TMKR_START_NOT_ATTEMPTED:
            return "The product could not start. Please remove it and add it again.";
        case TMKR_START_KEY_NOT_RECOGNIZED:
            return "API key not recognized. Check that the key in this product's settings matches the one in your account.";
        case TMKR_START_LICENSE_EXPIRED:
            return "Your license has expired or has not started yet. Check its dates in your account.";
        case TMKR_START_LICENSE_INACTIVE:
            if(tmkr_demo_only)
                return "This license only runs on a demo account. Use a demo account, or a license for this account type.";
            return "Your license is not active. Check its status in your account.";
        case TMKR_START_VERSION_NOT_COVERED:
            return "This version of the product is not covered by your license. Use the version your license covers.";
        case TMKR_START_SUBMISSION_NOT_TESTABLE:
            return "This test license cannot start a session: the submission is not in a testable state.";
        case TMKR_START_MAX_SESSIONS:
            if(tmkr_active_sessions >= 0 && tmkr_max_sessions > 0)
                return "Maximum concurrent sessions reached (" + IntegerToString(tmkr_active_sessions) + " of " +
                       IntegerToString(tmkr_max_sessions) + " in use). Stop this product on another chart or terminal, then try again.";
            return "Maximum concurrent sessions reached. Stop this product on another chart or terminal, then try again.";
        case TMKR_START_RATE_LIMITED:
            if(tmkr_retry_after > 0)
                return "Too many start attempts. Please wait " + IntegerToString(tmkr_retry_after) + " seconds and try again.";
            return "Too many start attempts. Please wait a moment and try again.";
        case TMKR_START_REQUEST_REJECTED:
            return "The server rejected the start request. Please contact support.";
        case TMKR_START_SERVER_ERROR:
            return "The service is temporarily unavailable. Please try again later.";
        case TMKR_START_NO_CONNECTION:
            return "Could not connect to TheMarketRobo service. Please check your internet connection and try again.";
        case TMKR_START_CONFIG_INVALID:
            return "The product's settings from the server could not be applied. Please contact support.";
        default:
            break;
    }
    return "The service refused to start this product (HTTP " + IntegerToString(http_code) + "). Please contact support.";
}

//+------------------------------------------------------------------+
//| Remove an indicator from the chart by its short name.             |
//| Returns true if the deletion call was made successfully.          |
//|                                                                    |
//| NOTE: This must NOT be called during OnInit(). In MQL5 the       |
//| indicator is not yet attached to the chart at that point. Use     |
//| the deferred-removal pattern (set a flag, remove on next          |
//| OnCalculate / OnTimer).                                            |
//+------------------------------------------------------------------+
bool TMKRRemoveIndicatorFromChart(string indicator_short_name)
{
    if(indicator_short_name == "")
    {
        Print("SDK Error: Cannot remove indicator — short name is empty. "
              "Call set_indicator_short_name() during OnInit().");
        return false;
    }

    int sub_window = TMR_ChartWindowFind(0, indicator_short_name);
    if(sub_window >= 0)
    {
        bool removed = TMR_ChartIndicatorDelete(0, sub_window, indicator_short_name);
        if(removed)
        {
            if(SDKShouldLogInfo()) Print("SDK Info: Indicator '", indicator_short_name,
                  "' removed from chart (subwindow ", sub_window, ").");
            return true;
        }
    }

    // Fallback: scan every subwindow to find and remove the indicator.
    // Handles chart-window indicators where ChartWindowFind may return -1.
    // On MQL4, TMR_ChartWindowFind returns -1 and TMR_ChartIndicatorsTotal returns 0
    // so this block is effectively a no-op.
    int total_windows = (int)TMR_ChartGetInteger(0, CHART_WINDOWS_TOTAL);
    for(int tmkr_w = 0; tmkr_w < total_windows; tmkr_w++)
    {
        int total_ind = TMR_ChartIndicatorsTotal(0, tmkr_w);
        for(int tmkr_i = total_ind - 1; tmkr_i >= 0; tmkr_i--)
        {
            if(TMR_ChartIndicatorName(0, tmkr_w, tmkr_i) == indicator_short_name)
            {
                bool removed = TMR_ChartIndicatorDelete(0, tmkr_w, indicator_short_name);
                if(removed)
                {
                    if(SDKShouldLogInfo()) Print("SDK Info: Indicator '", indicator_short_name,
                          "' removed from chart (subwindow ", tmkr_w, ", fallback scan).");
                    return true;
                }
            }
        }
    }

    Print("SDK Error: Failed to remove indicator '", indicator_short_name,
          "' from chart. It may already be removed. Error: ", GetLastError());
    return false;
}

#endif
//+------------------------------------------------------------------+
