//+------------------------------------------------------------------+
//|                                     CTheMarketRobo_Bot_Base.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"

#ifndef CTHEMARKETROBO_BOT_BASE_MQH
#define CTHEMARKETROBO_BOT_BASE_MQH

#include "Core/CSDK_Context.mqh"
#include "Utils/CSDK_Events.mqh"
#include "Interfaces/Irobot_Config.mqh"

//+------------------------------------------------------------------+
//| CTheMarketRobo_Bot_Base Class                                    |
//+------------------------------------------------------------------+
/**
 * @class CTheMarketRobo_Bot_Base
 * @brief An abstract base class for creating trading robots using TheMarketRobo SDK.
 *
 * This class handles the common SDK lifecycle events, authentication, and
 * session management behind the scenes. Developers should inherit from this
 * class to implement their specific trading logic.
 *
 * ## Token Refresh Configuration
 * The SDK implements proactive token refresh to ensure uninterrupted API access.
 * By default, tokens are refreshed 300 seconds (5 minutes) before expiration.
 * Use set_token_refresh_threshold() to customize this behavior.
 *
 * ## Usage Example
 * ```cpp
 * class MyRobot : public CTheMarketRobo_Bot_Base
 * {
 * public:
 *     MyRobot(Irobot_Config* config) : CTheMarketRobo_Bot_Base(config) {}
 *     
 *     int on_init(string api_key, string robot_version_uuid, long magic_number, string base_url)
 *     {
 *         // Optional: Customize token refresh threshold (default: 300 seconds)
 *         set_token_refresh_threshold(600); // Refresh 10 minutes before expiration
 *         
 *         return CTheMarketRobo_Bot_Base::on_init(api_key, robot_version_uuid, magic_number, base_url);
 *     }
 * };
 * ```
 */
class CTheMarketRobo_Bot_Base
{
protected:
    CSDK_Context*   m_sdk_context;
    Irobot_Config*  m_robot_config;
    int             m_token_refresh_threshold_seconds;  // Configurable refresh threshold

public:
    CTheMarketRobo_Bot_Base(Irobot_Config* robot_config);
    ~CTheMarketRobo_Bot_Base();

    //--- SDK Lifecycle Methods (to be called from MQL5 entry points)
    virtual int     on_init(string api_key, string robot_version_uuid, long magic_number, string base_url);
    virtual void    on_deinit(const int reason);
    virtual void    on_timer();
    virtual void    on_chart_event(const int id, const long &lparam, const double &dparam, const string &sparam);

    //--- Abstract Methods for Robot Implementation
    virtual void    on_tick() = 0;
    virtual void    on_config_changed(string event_json) = 0;
    virtual void    on_symbol_changed(string event_json) = 0;
    
    //--- Token Refresh Configuration
    void            set_token_refresh_threshold(int seconds);
    int             get_token_refresh_threshold() const;

protected:
    //--- Internal Event Handlers
    void            handle_termination_event(string event_json);
    void            handle_token_refresh_event(string event_json);
};

//+------------------------------------------------------------------+
//| CTheMarketRobo_Bot_Base Implementation                           |
//+------------------------------------------------------------------+
CTheMarketRobo_Bot_Base::CTheMarketRobo_Bot_Base(Irobot_Config* robot_config)
{
    m_sdk_context = NULL;
    m_robot_config = robot_config;
    m_token_refresh_threshold_seconds = 300; // Default: 5 minutes before expiration
}

CTheMarketRobo_Bot_Base::~CTheMarketRobo_Bot_Base()
{
    if(CheckPointer(m_sdk_context) == POINTER_DYNAMIC)
        delete m_sdk_context;
}

/**
 * @brief Sets the token refresh threshold in seconds.
 * @param seconds Number of seconds before token expiration to trigger proactive refresh.
 * @note Default is 300 seconds (5 minutes). Call this BEFORE on_init() for the setting to take effect.
 *       Minimum value is 60 seconds, maximum is 3600 seconds.
 *
 * ## Example
 * ```cpp
 * int MyRobot::on_init(...)
 * {
 *     set_token_refresh_threshold(600); // Refresh 10 minutes before expiration
 *     return CTheMarketRobo_Bot_Base::on_init(...);
 * }
 * ```
 */
void CTheMarketRobo_Bot_Base::set_token_refresh_threshold(int seconds)
{
    m_token_refresh_threshold_seconds = seconds;
    
    // If context already exists, update it directly
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        m_sdk_context.set_token_refresh_threshold_seconds(seconds);
    }
}

/**
 * @brief Gets the current token refresh threshold in seconds.
 * @return Number of seconds before expiration when token refresh is triggered.
 */
int CTheMarketRobo_Bot_Base::get_token_refresh_threshold() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        return m_sdk_context.get_token_refresh_threshold_seconds();
    }
    return m_token_refresh_threshold_seconds;
}

int CTheMarketRobo_Bot_Base::on_init(string api_key, string robot_version_uuid, long magic_number, string base_url)
{
    if(CheckPointer(m_robot_config) == POINTER_INVALID)
    {
        Print("SDK Error: Robot configuration is not valid.");
        return INIT_FAILED;
    }

    m_sdk_context = new CSDK_Context(api_key, robot_version_uuid, magic_number, m_robot_config, base_url);
    if(CheckPointer(m_sdk_context) == POINTER_INVALID)
    {
        Print("SDK Error: Failed to create SDK Context.");
        return INIT_FAILED;
    }
    
    // Apply the token refresh threshold configuration
    m_sdk_context.set_token_refresh_threshold_seconds(m_token_refresh_threshold_seconds);

    if(!m_sdk_context.start())
    {
        string error_msg = "SDK Error: Failed to start SDK session. Check API Key and connection. The robot will be removed.";
        Print(error_msg);
        Alert(error_msg);
        delete m_sdk_context;
        m_sdk_context = NULL;
        ExpertRemove();
        return INIT_FAILED;
    }

    Print("SDK session started successfully!");
    Print("SDK Info: Token will be refreshed ", m_token_refresh_threshold_seconds, " seconds before expiration.");
    EventSetTimer(1);
    return INIT_SUCCEEDED;
}

void CTheMarketRobo_Bot_Base::on_deinit(const int reason)
{
    Print("Deinitializing SDK...");
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        m_sdk_context.terminate("EA Shutdown: reason " + (string)reason);
    }
    EventKillTimer();
}

void CTheMarketRobo_Bot_Base::on_timer()
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        m_sdk_context.on_timer();
    }
}

void CTheMarketRobo_Bot_Base::on_chart_event(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    switch(id)
    {
        case SDK_EVENT_CONFIG_CHANGED:
            on_config_changed(sparam);
            break;
        case SDK_EVENT_SYMBOL_CHANGED:
            on_symbol_changed(sparam);
            break;
        case SDK_EVENT_TERMINATION_START:
        case SDK_EVENT_TERMINATION_END:
            handle_termination_event(sparam);
            break;
        case SDK_EVENT_TOKEN_REFRESH:
            handle_token_refresh_event(sparam);
            break;
    }
}

void CTheMarketRobo_Bot_Base::handle_termination_event(string event_json)
{
    CJAVal event_data;
    if(!event_data.parse(event_json)) return;

    string reason = event_data["reason"].get_string();
    string message = "Session terminated by server. Reason: " + reason + ". Expert will be removed.";
    
    Print(message);
    Alert(message);
    ExpertRemove();
}

void CTheMarketRobo_Bot_Base::handle_token_refresh_event(string event_json)
{
    CJAVal event_data;
    if(!event_data.parse(event_json)) return;

    bool success = event_data["success"].get_bool();
    if(!success)
    {
        string message = "SDK critical error: Failed to refresh authentication token. Expert will be removed to prevent unauthorized trading.";
        Print(message);
        Alert(message);
        ExpertRemove();
    }
    else
    {
        Print("SDK Info: Authentication token refreshed successfully.");
    }
}

#endif // CTHEMARKETROBO_BOT_BASE_MQH
