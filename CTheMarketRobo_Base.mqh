//+------------------------------------------------------------------+
//|                                          CTheMarketRobo_Base.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"

#ifndef CTHEMARKETROBO_BASE_MQH
#define CTHEMARKETROBO_BASE_MQH

#include "Core/CSDKContext.mqh"
#include "Core/CSDKConstants.mqh"
#include "Utils/CSDK_Events.mqh"
#include "Interfaces/IRobotConfig.mqh"

/**
 * @class CTheMarketRobo_Base
 * @brief Unified abstract base class for both Expert Advisors and Custom Indicators.
 *
 * ## Usage — Expert Advisor (Robot)
 *
 * ```mql5
 * class CMyRobot : public CTheMarketRobo_Base
 * {
 * public:
 *     CMyRobot() : CTheMarketRobo_Base("uuid-here", new CMyRobotConfig()) {}
 *     virtual void on_tick() override { ... }
 *     virtual void on_config_changed(string event_json) override { ... }
 *     virtual void on_symbol_changed(string event_json) override { ... }
 * };
 *
 * int OnInit()  { return robot.on_init(InpApiKey, InpMagicNumber); }
 * void OnTick() { robot.on_tick(); }
 * ```
 *
 * ## Usage — Custom Indicator
 *
 * ```mql5
 * class CMyIndicator : public CTheMarketRobo_Base
 * {
 * public:
 *     CMyIndicator() : CTheMarketRobo_Base("uuid-here") {}  // No config needed
 *     virtual int on_calculate(const int rates_total, const int prev_calculated,
 *                              const datetime &time[], const double &open[],
 *                              const double &high[], const double &low[],
 *                              const double &close[], const long &tick_volume[],
 *                              const long &volume[], const int &spread[]) override
 *     { ... return rates_total; }
 * };
 *
 * int OnInit()       { return indicator.on_init(InpApiKey); }
 * int OnCalculate(...) { return indicator.on_calculate(...); }
 * ```
 *
 * ## Key Differences by Product Type
 * | Feature                  | Robot               | Indicator          |
 * |--------------------------|---------------------|--------------------|
 * | on_init overload         | (api_key, magic)    | (api_key)          |
 * | Main event handler       | on_tick()           | on_calculate()     |
 * | magic_number             | Required            | Not used (omitted) |
 * | robot_config             | Yes                 | No                 |
 * | session_symbols          | Yes                 | No                 |
 * | Config change requests   | Supported           | Not supported      |
 * | Symbol change requests   | Supported           | Not supported      |
 * | Termination removal call | ExpertRemove()      | Alert + timer stop |
 */
class CTheMarketRobo_Base
{
protected:
    CSDKContext*    m_sdk_context;
    IRobotConfig*   m_robot_config;
    string          m_robot_version_uuid;
    int             m_token_refresh_threshold_seconds;
    bool            m_enable_config_change_requests;
    bool            m_enable_symbol_change_requests;

public:
    // Robot constructor — requires config object
    CTheMarketRobo_Base(string robot_version_uuid, IRobotConfig* robot_config);
    
    // Indicator constructor — no config needed
    CTheMarketRobo_Base(string robot_version_uuid);
    
    ~CTheMarketRobo_Base();

    // Robot init: requires magic_number for order identification
    virtual int  on_init(string api_key, long magic_number);
    
    // Indicator init: no magic_number; product type is set to INDICATOR automatically
    virtual int  on_init(string api_key);
    
    virtual void on_deinit(const int reason);
    virtual void on_timer();
    virtual void on_chart_event(const int id, const long &lparam, const double &dparam, const string &sparam);

    // --- Robot callbacks (override in EA) ---
    virtual void on_tick() {}
    virtual void on_config_changed(string event_json) {}
    virtual void on_symbol_changed(string event_json) {}

    // --- Indicator callback (override in indicator) ---
    virtual int  on_calculate(const int rates_total,
                              const int prev_calculated,
                              const datetime &time[],
                              const double   &open[],
                              const double   &high[],
                              const double   &low[],
                              const double   &close[],
                              const long     &tick_volume[],
                              const long     &volume[],
                              const int      &spread[]) { return rates_total; }

    // --- Shared callback ---
    // Default: robots call ExpertRemove(), indicators stop the timer and alert the user.
    virtual void on_termination_requested(string event_json);
    
    void set_token_refresh_threshold(int seconds);
    int  get_token_refresh_threshold() const;
    
    void set_enable_config_change_requests(bool enable);
    bool is_config_change_requests_enabled() const;
    
    void set_enable_symbol_change_requests(bool enable);
    bool is_symbol_change_requests_enabled() const;
    
    void   print_sdk_configuration() const;
    string get_robot_version_uuid() const;
    bool   is_indicator_mode() const;
    bool   is_robot_mode() const;

protected:
    void handle_termination_event(string event_json);
    void handle_termination_requested_event(string event_json);
    void handle_token_refresh_event(string event_json);
    
    int  init_common(string api_key, long magic_number, ENUM_SDK_PRODUCT_TYPE product_type);
};

//+------------------------------------------------------------------+
//| Robot constructor                                                 |
//+------------------------------------------------------------------+
CTheMarketRobo_Base::CTheMarketRobo_Base(string robot_version_uuid, IRobotConfig* robot_config)
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
//| Indicator constructor (no config)                                 |
//+------------------------------------------------------------------+
CTheMarketRobo_Base::CTheMarketRobo_Base(string robot_version_uuid)
{
    m_sdk_context = NULL;
    m_robot_config = NULL;
    m_robot_version_uuid = robot_version_uuid;
    m_token_refresh_threshold_seconds = SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD;
    m_enable_config_change_requests = false; // Indicators never use config changes
    m_enable_symbol_change_requests = false; // Indicators never use symbol changes
    Print("SDK Info: Indicator Version UUID = ", m_robot_version_uuid);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTheMarketRobo_Base::~CTheMarketRobo_Base()
{
    if(CheckPointer(m_sdk_context) == POINTER_DYNAMIC)
        delete m_sdk_context;
    
    if(CheckPointer(m_robot_config) == POINTER_DYNAMIC)
        delete m_robot_config;
}

//+------------------------------------------------------------------+
//| Getters                                                           |
//+------------------------------------------------------------------+
string CTheMarketRobo_Base::get_robot_version_uuid() const { return m_robot_version_uuid; }

bool CTheMarketRobo_Base::is_indicator_mode() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        return m_sdk_context.is_indicator();
    return (m_robot_config == NULL);
}

bool CTheMarketRobo_Base::is_robot_mode() const
{
    return !is_indicator_mode();
}

//+------------------------------------------------------------------+
//| Shared init implementation                                        |
//+------------------------------------------------------------------+
int CTheMarketRobo_Base::init_common(string api_key, long magic_number, ENUM_SDK_PRODUCT_TYPE product_type)
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
    
    if(product_type == PRODUCT_TYPE_ROBOT && CheckPointer(m_robot_config) == POINTER_INVALID)
    {
        Print("SDK Error: Robot configuration is not valid. Robots must provide an IRobotConfig instance.");
        return INIT_FAILED;
    }
    
    if(product_type == PRODUCT_TYPE_ROBOT)
        Print("SDK Info: Initializing ROBOT with Magic Number = ", magic_number);
    else
        Print("SDK Info: Initializing INDICATOR (no magic number)");

    m_sdk_context = new CSDKContext(api_key, m_robot_version_uuid, magic_number, m_robot_config, product_type);
    if(CheckPointer(m_sdk_context) == POINTER_INVALID)
    {
        Print("SDK Error: Failed to create SDK Context.");
        return INIT_FAILED;
    }
    
    m_sdk_context.set_token_refresh_threshold_seconds(m_token_refresh_threshold_seconds);
    
    // Config/symbol toggle setters are no-ops for indicators (guarded in CSDKOptions)
    m_sdk_context.set_enable_config_change_requests(m_enable_config_change_requests);
    m_sdk_context.set_enable_symbol_change_requests(m_enable_symbol_change_requests);
    
    print_sdk_configuration();

    if(!m_sdk_context.start())
    {
        bool is_ind = (product_type == PRODUCT_TYPE_INDICATOR);
        string program_label = is_ind ? "indicator" : "robot";
        string error_msg = "SDK Error: Failed to start SDK session. Check API Key and connection. The " + program_label + " will be removed.";
        Print(error_msg);
        Alert(error_msg);
        delete m_sdk_context;
        m_sdk_context = NULL;
        if(!is_ind)
            ExpertRemove();
        return INIT_FAILED;
    }

    Print("SDK session started successfully!");
    EventSetTimer(1);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Robot initialization                                              |
//+------------------------------------------------------------------+
int CTheMarketRobo_Base::on_init(string api_key, long magic_number)
{
    return init_common(api_key, magic_number, PRODUCT_TYPE_ROBOT);
}

//+------------------------------------------------------------------+
//| Indicator initialization (no magic number)                        |
//+------------------------------------------------------------------+
int CTheMarketRobo_Base::on_init(string api_key)
{
    return init_common(api_key, 0, PRODUCT_TYPE_INDICATOR);
}

//+------------------------------------------------------------------+
//| Deinitialize                                                      |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::on_deinit(const int reason)
{
    string label = is_indicator_mode() ? "Indicator" : "EA";
    Print("Deinitializing ", label, " SDK (reason=", reason, ")...");
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.terminate(label + " Shutdown: reason " + (string)reason);
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Timer                                                             |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::on_timer()
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.on_timer();
}

//+------------------------------------------------------------------+
//| Chart event                                                       |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::on_chart_event(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    switch(id)
    {
        case SDK_EVENT_CONFIG_CHANGED:
            // Only robots receive config change events
            if(is_robot_mode())
                on_config_changed(sparam);
            break;
        case SDK_EVENT_SYMBOL_CHANGED:
            // Only robots receive symbol change events
            if(is_robot_mode())
                on_symbol_changed(sparam);
            break;
        case SDK_EVENT_TERMINATION_START:
        case SDK_EVENT_TERMINATION_END:
            handle_termination_event(sparam);
            break;
        case SDK_EVENT_TERMINATION_REQUESTED:
            handle_termination_requested_event(sparam);
            break;
        case SDK_EVENT_TOKEN_REFRESH:
            handle_token_refresh_event(sparam);
            break;
    }
}

//+------------------------------------------------------------------+
//| Token refresh threshold                                           |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::set_token_refresh_threshold(int seconds)
{
    m_token_refresh_threshold_seconds = seconds;
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.set_token_refresh_threshold_seconds(seconds);
}

int CTheMarketRobo_Base::get_token_refresh_threshold() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        return m_sdk_context.get_token_refresh_threshold_seconds();
    return m_token_refresh_threshold_seconds;
}

//+------------------------------------------------------------------+
//| Config change requests toggle (no-op for indicators)             |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::set_enable_config_change_requests(bool enable)
{
    m_enable_config_change_requests = enable;
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.set_enable_config_change_requests(enable);
}

bool CTheMarketRobo_Base::is_config_change_requests_enabled() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        return m_sdk_context.is_config_change_requests_enabled();
    return m_enable_config_change_requests;
}

//+------------------------------------------------------------------+
//| Symbol change requests toggle (no-op for indicators)             |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::set_enable_symbol_change_requests(bool enable)
{
    m_enable_symbol_change_requests = enable;
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.set_enable_symbol_change_requests(enable);
}

bool CTheMarketRobo_Base::is_symbol_change_requests_enabled() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        return m_sdk_context.is_symbol_change_requests_enabled();
    return m_enable_symbol_change_requests;
}

//+------------------------------------------------------------------+
//| Print configuration                                               |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::print_sdk_configuration() const
{
    Print("=== SDK Configuration ===");
    Print("  Version UUID: ", m_robot_version_uuid);
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
//| Handle termination event (session already ended on server)        |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::handle_termination_event(string event_json)
{
    CJAVal event_data;
    if(!event_data.parse(event_json)) return;

    string reason = event_data["reason"].get_string();
    string message = "Session terminated by server. Reason: " + reason;
    
    Print(message);
    Alert(message);
    
    if(is_robot_mode())
        ExpertRemove();
    else
    {
        // Indicators have no self-removal function; stop the timer so
        // heartbeats cease and alert the user to remove the indicator.
        EventKillTimer();
        Print("SDK Info: Indicator session terminated. Please remove the indicator from the chart.");
    }
}

//+------------------------------------------------------------------+
//| Handle termination requested event (server asked to stop)         |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::handle_termination_requested_event(string event_json)
{
    CJAVal event_data;
    if(!event_data.parse(event_json)) return;

    string reason = event_data["reason"].get_string();
    
    Print("============================================================");
    Print("| SERVER REQUESTED SESSION TERMINATION                     |");
    Print("============================================================");
    Print("Reason: ", reason);
    Print(is_robot_mode() ? "The Expert Advisor will now terminate..." 
                           : "The Indicator session will now terminate...");
    Print("============================================================");
    
    on_termination_requested(event_json);
}

//+------------------------------------------------------------------+
//| Default termination handler (virtual — can be overridden)         |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::on_termination_requested(string event_json)
{
    CJAVal event_data;
    string reason = "Server requested termination";
    
    if(event_data.parse(event_json))
        reason = event_data["reason"].get_string();
    
    string message = "Server requested termination: " + reason;
    Alert(message);
    
    if(is_robot_mode())
    {
        ExpertRemove();
    }
    else
    {
        // Stop heartbeats; inform the user to remove the indicator manually.
        EventKillTimer();
        Print("SDK Info: Indicator timer stopped due to server-requested termination. ",
              "Please remove this indicator from the chart.");
    }
}

//+------------------------------------------------------------------+
//| Handle token refresh event                                        |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::handle_token_refresh_event(string event_json)
{
    CJAVal event_data;
    if(!event_data.parse(event_json)) return;

    bool success = event_data["success"].get_bool();
    if(!success)
    {
        string program_label = is_robot_mode() ? "Expert Advisor" : "Indicator";
        string message = "SDK critical error: Failed to refresh authentication token. " +
                         program_label + " will be removed to prevent an unauthorized session.";
        Print(message);
        Alert(message);
        
        if(is_robot_mode())
            ExpertRemove();
        else
        {
            EventKillTimer();
            Print("SDK Info: Indicator timer stopped due to token refresh failure. ",
                  "Please remove this indicator from the chart.");
        }
    }
    else
    {
        Print("SDK Info: Authentication token refreshed successfully.");
    }
}

#endif
//+------------------------------------------------------------------+
