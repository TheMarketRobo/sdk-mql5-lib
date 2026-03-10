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

//+------------------------------------------------------------------+
//| SDK User-Facing Error Utility                                     |
//|                                                                    |
//| All Alert() messages from the SDK flow through these helpers so   |
//| that end users always see short, non-technical messages while     |
//| programmers can still find the technical detail in the Experts    |
//| log via Print().                                                   |
//+------------------------------------------------------------------+

#define SDK_USER_PREFIX "TheMarketRobo: "

//+------------------------------------------------------------------+
//| Show a user-friendly alert (short message only)                   |
//+------------------------------------------------------------------+
void SDKUserError(string short_msg)
{
    Alert(SDK_USER_PREFIX + short_msg);
    Print("SDK User Error: ", short_msg);
}

//+------------------------------------------------------------------+
//| Show a user-friendly alert + log technical details for devs       |
//+------------------------------------------------------------------+
void SDKUserErrorWithDetails(string short_msg, string technical_detail)
{
    Alert(SDK_USER_PREFIX + short_msg);
    Print("SDK User Error: ", short_msg);
    Print("SDK Technical Detail: ", technical_detail);
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
//| Remove an indicator from the chart by its short name.             |
//| Returns true if the deletion call was made successfully.          |
//|                                                                    |
//| NOTE: This must NOT be called during OnInit(). In MQL5 the       |
//| indicator is not yet attached to the chart at that point. Use     |
//| the deferred-removal pattern (set a flag, remove on next          |
//| OnCalculate / OnTimer).                                            |
//+------------------------------------------------------------------+
bool SDKRemoveIndicatorFromChart(string indicator_short_name)
{
    if(indicator_short_name == "")
    {
        Print("SDK Warning: Cannot remove indicator — short name is empty.");
        return false;
    }
    
    int sub_window = ChartWindowFind(0, indicator_short_name);
    if(sub_window < 0)
    {
        Print("SDK Warning: Indicator '", indicator_short_name, "' not found on chart. May already be removed.");
        return false;
    }
    
    bool removed = ChartIndicatorDelete(0, sub_window, indicator_short_name);
    if(removed)
        Print("SDK Info: Indicator '", indicator_short_name, "' removed from chart (subwindow ", sub_window, ").");
    else
        Print("SDK Warning: Failed to remove indicator '", indicator_short_name, "' from chart. Error: ", GetLastError());
    
    return removed;
}

#endif
//+------------------------------------------------------------------+
