//+------------------------------------------------------------------+
//|                                                CSDK_Events.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"

#ifndef CSDK_EVENTS_MQH
#define CSDK_EVENTS_MQH

//+------------------------------------------------------------------+
//| SDK Event Constants                                              |
//+------------------------------------------------------------------+
#define SDK_EVENT_CONFIG_CHANGED          (CHARTEVENT_CUSTOM + 1000)
#define SDK_EVENT_SYMBOL_CHANGED          (CHARTEVENT_CUSTOM + 1001)
#define SDK_EVENT_TERMINATION_START       (CHARTEVENT_CUSTOM + 1002)
#define SDK_EVENT_TERMINATION_END         (CHARTEVENT_CUSTOM + 1003)
#define SDK_EVENT_TOKEN_REFRESH           (CHARTEVENT_CUSTOM + 1004)
#define SDK_EVENT_TERMINATION_REQUESTED   (CHARTEVENT_CUSTOM + 1005)  // Server requested termination

//+------------------------------------------------------------------+
//| Event Data Structures                                            |
//+------------------------------------------------------------------+

/**
 * @struct SConfig_Change_Event
 * @brief Event data for configuration changes
 */
struct SConfig_Change_Event
{
    string field_name;
    string old_value;
    string new_value;
    
    /**
     * @brief Converts the event data to JSON string for sparam
     */
    string to_json()
    {
        return StringFormat("{\"type\":\"config_change\",\"field\":\"%s\",\"old_value\":\"%s\",\"new_value\":\"%s\"}",
                          field_name, old_value, new_value);
    }
};

/**
 * @struct SSymbol_Change_Event
 * @brief Event data for symbol status changes
 */
struct SSymbol_Change_Event
{
    string symbol;
    bool active_to_trade;
    
    /**
     * @brief Converts the event data to JSON string for sparam
     */
    string to_json()
    {
        return StringFormat("{\"type\":\"symbol_change\",\"symbol\":\"%s\",\"active_to_trade\":%s}",
                          symbol, active_to_trade ? "true" : "false");
    }
};

/**
 * @struct STermination_Event
 * @brief Event data for session termination
 */
struct STermination_Event
{
    string reason;
    bool success;
    string message;
    ulong session_id;
    
    /**
     * @brief Converts the event data to JSON string for sparam
     */
    string to_json()
    {
        return StringFormat("{\"type\":\"termination\",\"reason\":\"%s\",\"success\":%s,\"message\":\"%s\",\"session_id\":%s}",
                          reason, success ? "true" : "false", message,
                          IntegerToString(session_id));
    }
};

/**
 * @struct SToken_Refresh_Event
 * @brief Event data for token refresh
 */
struct SToken_Refresh_Event
{
    bool success;
    string message;
    
    /**
     * @brief Converts the event data to JSON string for sparam
     */
    string to_json()
    {
        return StringFormat("{\"type\":\"token_refresh\",\"success\":%s,\"message\":\"%s\"}",
                          success ? "true" : "false", message);
    }
};

//+------------------------------------------------------------------+
//| Event Helper Functions                                           |
//+------------------------------------------------------------------+

/**
 * @brief Fires a configuration change event
 * @param chart_id Chart ID (0 for current chart)
 * @param event_data The configuration change event data
 */
void Fire_Config_Change_Event(long chart_id, const SConfig_Change_Event &event_data)
{
    SConfig_Change_Event temp_event;
    temp_event.field_name = event_data.field_name;
    temp_event.old_value = event_data.old_value;
    temp_event.new_value = event_data.new_value;
    EventChartCustom(chart_id, SDK_EVENT_CONFIG_CHANGED - CHARTEVENT_CUSTOM, 0, 0, temp_event.to_json());
}

/**
 * @brief Fires a symbol change event
 * @param chart_id Chart ID (0 for current chart)
 * @param event_data The symbol change event data
 */
void Fire_Symbol_Change_Event(long chart_id, const SSymbol_Change_Event &event_data)
{
    SSymbol_Change_Event temp_event;
    temp_event.symbol = event_data.symbol;
    temp_event.active_to_trade = event_data.active_to_trade;
    EventChartCustom(chart_id, SDK_EVENT_SYMBOL_CHANGED - CHARTEVENT_CUSTOM, 0, 0, temp_event.to_json());
}

/**
 * @brief Fires a termination start event
 * @param chart_id Chart ID (0 for current chart)
 * @param event_data The termination event data
 */
void Fire_Termination_Start_Event(long chart_id, const STermination_Event &event_data)
{
    STermination_Event temp_event;
    temp_event.reason = event_data.reason;
    temp_event.success = event_data.success;
    temp_event.message = event_data.message;
    EventChartCustom(chart_id, SDK_EVENT_TERMINATION_START - CHARTEVENT_CUSTOM, 0, 0, temp_event.to_json());
}

/**
 * @brief Fires a termination end event
 * @param chart_id Chart ID (0 for current chart)
 * @param event_data The termination event data
 */
void Fire_Termination_End_Event(long chart_id, const STermination_Event &event_data)
{
    STermination_Event temp_event;
    temp_event.reason = event_data.reason;
    temp_event.success = event_data.success;
    temp_event.message = event_data.message;
    EventChartCustom(chart_id, SDK_EVENT_TERMINATION_END - CHARTEVENT_CUSTOM, 0, 0, temp_event.to_json());
}

/**
 * @brief Fires a token refresh event
 * @param chart_id Chart ID (0 for current chart)
 * @param event_data The token refresh event data
 */
void Fire_Token_Refresh_Event(long chart_id, const SToken_Refresh_Event &event_data)
{
    SToken_Refresh_Event temp_event;
    temp_event.success = event_data.success;
    temp_event.message = event_data.message;
    EventChartCustom(chart_id, SDK_EVENT_TOKEN_REFRESH - CHARTEVENT_CUSTOM, 0, 0, temp_event.to_json());
}

/**
 * @brief Fires a termination requested event (server requested termination)
 * @param chart_id Chart ID (0 for current chart)
 * @param event_json JSON string with termination details ({"reason": "..."})
 */
void Fire_Termination_Requested_Event(long chart_id, string event_json)
{
    EventChartCustom(chart_id, SDK_EVENT_TERMINATION_REQUESTED - CHARTEVENT_CUSTOM, 0, 0, event_json);
}

#endif // CSDK_EVENTS_MQH
//+------------------------------------------------------------------+
