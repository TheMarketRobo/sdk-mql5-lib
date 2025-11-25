//+------------------------------------------------------------------+
//|                                     CTheMarketRobo_Bot_Base.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"

#ifndef CTHEMARKETROBO_BOT_BASE_MQH
#define CTHEMARKETROBO_BOT_BASE_MQH

#include "Core/CSDKContext.mqh"
#include "Core/CSDKConstants.mqh"
#include "Utils/CSDK_Events.mqh"
#include "Interfaces/IRobotConfig.mqh"

/**
 * @class CTheMarketRobo_Bot_Base
 * @brief An abstract base class for creating trading robots using TheMarketRobo SDK.
 */
class CTheMarketRobo_Bot_Base
{
protected:
    CSDKContext*    m_sdk_context;
    IRobotConfig*   m_robot_config;
    string          m_robot_version_uuid;
    int             m_token_refresh_threshold_seconds;
    bool            m_enable_config_change_requests;
    bool            m_enable_symbol_change_requests;

public:
    CTheMarketRobo_Bot_Base(string robot_version_uuid, IRobotConfig* robot_config);
    ~CTheMarketRobo_Bot_Base();

    virtual int     on_init(string api_key, long magic_number);
    virtual void    on_deinit(const int reason);
    virtual void    on_timer();
    virtual void    on_chart_event(const int id, const long &lparam, const double &dparam, const string &sparam);

    virtual void    on_tick() = 0;
    virtual void    on_config_changed(string event_json) = 0;
    virtual void    on_symbol_changed(string event_json) = 0;
    
    void            set_token_refresh_threshold(int seconds);
    int             get_token_refresh_threshold() const;
    
    void            set_enable_config_change_requests(bool enable);
    bool            is_config_change_requests_enabled() const;
    
    void            set_enable_symbol_change_requests(bool enable);
    bool            is_symbol_change_requests_enabled() const;
    
    void            print_sdk_configuration() const;
    string          get_robot_version_uuid() const;

protected:
    void            handle_termination_event(string event_json);
    void            handle_token_refresh_event(string event_json);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTheMarketRobo_Bot_Base::CTheMarketRobo_Bot_Base(string robot_version_uuid, IRobotConfig* robot_config)
{
    m_sdk_context = NULL;
    m_robot_config = robot_config;
    m_robot_version_uuid = robot_version_uuid;
    m_token_refresh_threshold_seconds = SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD;
    m_enable_config_change_requests = true;
    m_enable_symbol_change_requests = true;
    Print("SDK Info: Robot Version UUID = ", m_robot_version_uuid);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTheMarketRobo_Bot_Base::~CTheMarketRobo_Bot_Base()
{
    if(CheckPointer(m_sdk_context) == POINTER_DYNAMIC)
        delete m_sdk_context;
}

//+------------------------------------------------------------------+
//| Getters                                                           |
//+------------------------------------------------------------------+
string CTheMarketRobo_Bot_Base::get_robot_version_uuid() const { return m_robot_version_uuid; }

//+------------------------------------------------------------------+
//| Token refresh threshold                                           |
//+------------------------------------------------------------------+
void CTheMarketRobo_Bot_Base::set_token_refresh_threshold(int seconds)
{
    m_token_refresh_threshold_seconds = seconds;
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.set_token_refresh_threshold_seconds(seconds);
}

int CTheMarketRobo_Bot_Base::get_token_refresh_threshold() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        return m_sdk_context.get_token_refresh_threshold_seconds();
    return m_token_refresh_threshold_seconds;
}

//+------------------------------------------------------------------+
//| Config change requests toggle                                     |
//+------------------------------------------------------------------+
void CTheMarketRobo_Bot_Base::set_enable_config_change_requests(bool enable)
{
    m_enable_config_change_requests = enable;
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.set_enable_config_change_requests(enable);
}

bool CTheMarketRobo_Bot_Base::is_config_change_requests_enabled() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        return m_sdk_context.is_config_change_requests_enabled();
    return m_enable_config_change_requests;
}

//+------------------------------------------------------------------+
//| Symbol change requests toggle                                     |
//+------------------------------------------------------------------+
void CTheMarketRobo_Bot_Base::set_enable_symbol_change_requests(bool enable)
{
    m_enable_symbol_change_requests = enable;
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.set_enable_symbol_change_requests(enable);
}

bool CTheMarketRobo_Bot_Base::is_symbol_change_requests_enabled() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        return m_sdk_context.is_symbol_change_requests_enabled();
    return m_enable_symbol_change_requests;
}

//+------------------------------------------------------------------+
//| Print configuration                                               |
//+------------------------------------------------------------------+
void CTheMarketRobo_Bot_Base::print_sdk_configuration() const
{
    Print("=== SDK Configuration ===");
    Print("  Robot Version UUID: ", m_robot_version_uuid);
    Print("  API Base URL: ", SDK_API_BASE_URL);
    
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.print_configuration();
    else
    {
        Print("  Token refresh threshold: ", m_token_refresh_threshold_seconds, " seconds");
        Print("  Config change requests: ", m_enable_config_change_requests ? "ENABLED" : "DISABLED");
        Print("  Symbol change requests: ", m_enable_symbol_change_requests ? "ENABLED" : "DISABLED");
    }
    Print("=========================");
}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
int CTheMarketRobo_Bot_Base::on_init(string api_key, long magic_number)
{
    if(m_robot_version_uuid == "" || StringLen(m_robot_version_uuid) != SDK_UUID_LENGTH)
    {
        Print("SDK Error: Invalid robot_version_uuid. Must be a valid UUID (36 characters).");
        return INIT_FAILED;
    }
    
    if(api_key == "")
    {
        Print("SDK Error: API Key is required. Please provide a valid API key.");
        Alert("TheMarketRobo SDK: API Key is required!");
        return INIT_FAILED;
    }
    
    if(CheckPointer(m_robot_config) == POINTER_INVALID)
    {
        Print("SDK Error: Robot configuration is not valid.");
        return INIT_FAILED;
    }
    
    Print("SDK Info: Initializing with Magic Number = ", magic_number);

    m_sdk_context = new CSDKContext(api_key, m_robot_version_uuid, magic_number, m_robot_config);
    if(CheckPointer(m_sdk_context) == POINTER_INVALID)
    {
        Print("SDK Error: Failed to create SDK Context.");
        return INIT_FAILED;
    }
    
    m_sdk_context.set_token_refresh_threshold_seconds(m_token_refresh_threshold_seconds);
    m_sdk_context.set_enable_config_change_requests(m_enable_config_change_requests);
    m_sdk_context.set_enable_symbol_change_requests(m_enable_symbol_change_requests);
    
    print_sdk_configuration();

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
    EventSetTimer(1);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitialize                                                      |
//+------------------------------------------------------------------+
void CTheMarketRobo_Bot_Base::on_deinit(const int reason)
{
    Print("Deinitializing SDK...");
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.terminate("EA Shutdown: reason " + (string)reason);
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Timer                                                             |
//+------------------------------------------------------------------+
void CTheMarketRobo_Bot_Base::on_timer()
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.on_timer();
}

//+------------------------------------------------------------------+
//| Chart event                                                       |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Handle termination event                                          |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Handle token refresh event                                        |
//+------------------------------------------------------------------+
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

#endif
//+------------------------------------------------------------------+
