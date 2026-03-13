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

#include "Core/CSDKConstants.mqh"
#include "Utils/CSDKLogger.mqh"

//+------------------------------------------------------------------+
//| When SDK_ENABLED is NOT defined, provide a lightweight stub       |
//| that preserves the public interface but performs no SDK operations. |
//| Developer code compiles and runs without changes.                  |
//+------------------------------------------------------------------+
#ifndef SDK_ENABLED

#include "Interfaces/IRobotConfig.mqh"

class CTheMarketRobo_Base
{
protected:
    string       m_robot_version_uuid;
    IRobotConfig* m_robot_config;

public:
    // Robot constructor (matches full API — config pointer is stored for developer access)
    CTheMarketRobo_Base(string robot_version_uuid, IRobotConfig* robot_config)
    {
        m_robot_version_uuid = robot_version_uuid;
        m_robot_config = robot_config;
    }

    // Indicator constructor
    CTheMarketRobo_Base(string robot_version_uuid)
    {
        m_robot_version_uuid = robot_version_uuid;
        m_robot_config = NULL;
    }

    ~CTheMarketRobo_Base()
    {
        if(CheckPointer(m_robot_config) == POINTER_DYNAMIC)
            delete m_robot_config;
    }

    // Robot init — returns success immediately
    virtual int on_init(string api_key, long magic_number)
    {
        if(SDKShouldLogInfo()) Print("SDK Info: SDK_ENABLED is not defined — running in standalone mode.");
        return INIT_SUCCEEDED;
    }

    // Indicator init — returns success immediately
    virtual int on_init(string api_key)
    {
        if(SDKShouldLogInfo()) Print("SDK Info: SDK_ENABLED is not defined — running in standalone mode.");
        return INIT_SUCCEEDED;
    }

    virtual void on_deinit(const int reason) {}
    virtual void on_timer() {}
    virtual void on_chart_event(const int id, const long &lparam, const double &dparam, const string &sparam) {}

    // Robot callbacks (override in EA)
    virtual void on_tick() {}
    virtual void on_config_changed(string event_json) {}
    virtual void on_symbol_changed(string event_json) {}

    // Indicator callback (override in indicator)
    virtual int on_calculate(const int rates_total,
                              const int prev_calculated,
                              const datetime &time[],
                              const double   &open[],
                              const double   &high[],
                              const double   &low[],
                              const double   &close[],
                              const long     &tick_volume[],
                              const long     &volume[],
                              const int      &spread[]) { return rates_total; }

    // Shared callback
    virtual void on_termination_requested(string event_json) {}

    // Configuration stubs (no-ops)
    void set_token_refresh_threshold(int seconds) {}
    int  get_token_refresh_threshold() const { return 0; }
    void set_enable_config_change_requests(bool enable) {}
    bool is_config_change_requests_enabled() const { return false; }
    void set_enable_symbol_change_requests(bool enable) {}
    bool is_symbol_change_requests_enabled() const { return false; }
    void print_sdk_configuration() const { if(SDKShouldLogInfo()) Print("SDK Info: SDK is disabled — no configuration to display."); }
    string get_robot_version_uuid() const { return m_robot_version_uuid; }
    bool is_indicator_mode() const { return false; }
    bool is_robot_mode() const { return true; }
    void set_indicator_short_name(string short_name) {}
    bool is_pending_removal() const { return false; }
    void set_log_level(ENUM_SDK_LOG_LEVEL level) { SDKSetLogLevel(level); }
    ENUM_SDK_LOG_LEVEL get_log_level() const { return SDKGetLogLevel(); }
};

#else // SDK_ENABLED is defined — full SDK implementation follows

#include "Core/CSDKContext.mqh"
#include "Core/CSDKConstants.mqh"
#include "Utils/CSDK_Events.mqh"
#include "Utils/CSDKUserErrors.mqh"
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
    string          m_indicator_short_name;   // For ChartIndicatorDelete self-removal
    bool            m_pending_removal;        // Deferred removal flag (set during init, executed on first tick/timer)

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
    
    // Indicator self-removal — call set_indicator_short_name() during OnInit()
    void   set_indicator_short_name(string short_name);
    bool   is_pending_removal() const;

    // Log level control — set before or after on_init()
    void   set_log_level(ENUM_SDK_LOG_LEVEL level);
    ENUM_SDK_LOG_LEVEL get_log_level() const;

protected:
    void   remove_indicator_from_chart();
    bool   check_pending_removal();
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
    m_indicator_short_name = "";
    m_pending_removal = false;
    if(SDKShouldLogInfo()) Print("SDK Info: Robot Version UUID = ", m_robot_version_uuid);
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
    m_indicator_short_name = "";
    m_pending_removal = false;
    if(SDKShouldLogInfo()) Print("SDK Info: Indicator Version UUID = ", m_robot_version_uuid);
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
//| Indicator short name (for self-removal via ChartIndicatorDelete)  |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::set_indicator_short_name(string short_name)
{
    m_indicator_short_name = short_name;
}

bool CTheMarketRobo_Base::is_pending_removal() const
{
    return m_pending_removal;
}

//+------------------------------------------------------------------+
//| Remove this indicator from the chart using ChartIndicatorDelete   |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::remove_indicator_from_chart()
{
    EventKillTimer();
    if(m_indicator_short_name != "")
    {
        SDKRemoveIndicatorFromChart(m_indicator_short_name);
    }
    else
    {
        Print("SDK SECURITY ERROR: Indicator short name not set — cannot auto-remove from chart. "
              "The programmer MUST call set_indicator_short_name() during OnInit(). "
              "Without it, server-side termination cannot remove the indicator.");
        Alert("TheMarketRobo: CRITICAL — indicator could not be removed. Please remove it manually.");
    }
}

//+------------------------------------------------------------------+
//| Check if pending removal should execute (call at top of          |
//| on_calculate / on_timer). Returns true if removal was triggered.  |
//+------------------------------------------------------------------+
bool CTheMarketRobo_Base::check_pending_removal()
{
    if(m_pending_removal)
    {
        remove_indicator_from_chart();
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Shared init implementation                                        |
//+------------------------------------------------------------------+
int CTheMarketRobo_Base::init_common(string api_key, long magic_number, ENUM_SDK_PRODUCT_TYPE product_type)
{
    bool is_ind = (product_type == PRODUCT_TYPE_INDICATOR);

    if(m_robot_version_uuid == "" || StringLen(m_robot_version_uuid) != SDK_UUID_LENGTH)
    {
        Print("SDK Error: Invalid robot_version_uuid. Must be a valid UUID (36 characters).");
        if(is_ind)
        {
            SDKUserError("Setup error — invalid product configuration. Please contact support.");
            m_pending_removal = true;
        }
        return INIT_FAILED;
    }
    
    if(api_key == "")
    {
        Print("SDK Error: API Key is required. Please provide a valid API key.");
        if(is_ind)
        {
            SDKUserError("API Key is required. Please set it in the indicator settings.");
            m_pending_removal = true;
        }
        else
            Alert("TheMarketRobo: API Key is required!");
        return INIT_FAILED;
    }
    
    if(product_type == PRODUCT_TYPE_ROBOT && CheckPointer(m_robot_config) == POINTER_INVALID)
    {
        Print("SDK Error: Robot configuration is not valid. Robots must provide an IRobotConfig instance.");
        return INIT_FAILED;
    }
    
    if(is_ind && m_indicator_short_name == "")
    {
        Print("SDK SECURITY WARNING: set_indicator_short_name() was not called before on_init(). "
              "Server-side termination will NOT be able to remove this indicator from the chart. "
              "Call set_indicator_short_name() in OnInit() BEFORE calling on_init().");
    }

    if(SDKShouldLogInfo())
    {
        if(product_type == PRODUCT_TYPE_ROBOT)
            Print("SDK Info: Initializing ROBOT with Magic Number = ", magic_number);
        else
            Print("SDK Info: Initializing INDICATOR (no magic number)");
    }

    m_sdk_context = new CSDKContext(api_key, m_robot_version_uuid, magic_number, m_robot_config, product_type);
    if(CheckPointer(m_sdk_context) == POINTER_INVALID)
    {
        Print("SDK Error: Failed to create SDK Context.");
        if(is_ind)
        {
            SDKUserError("Failed to start. Please try removing and re-adding the indicator.");
            m_pending_removal = true;
        }
        return INIT_FAILED;
    }
    
    m_sdk_context.set_token_refresh_threshold_seconds(m_token_refresh_threshold_seconds);
    
    // Config/symbol toggle setters are no-ops for indicators (guarded in CSDKOptions)
    m_sdk_context.set_enable_config_change_requests(m_enable_config_change_requests);
    m_sdk_context.set_enable_symbol_change_requests(m_enable_symbol_change_requests);
    
    print_sdk_configuration();

    // For indicators: try to resume a previously saved session (from a
    // non-destructive deinit like chart change / parameter change).
    if(is_ind && m_sdk_context.try_restore_session())
    {
        if(SDKShouldLogInfo()) Print("SDK Info: Session resumed successfully!");
        EventSetTimer(1);
        return INIT_SUCCEEDED;
    }

    if(!m_sdk_context.start())
    {
        delete m_sdk_context;
        m_sdk_context = NULL;
        
        if(is_ind)
        {
            SDKUserError("Could not connect to TheMarketRobo service. Please check your internet connection and try again.");
            m_pending_removal = true;
        }
        else
        {
            Alert("TheMarketRobo: Could not connect to the service. The robot will be removed.");
            ExpertRemove();
        }
        return INIT_FAILED;
    }

    if(SDKShouldLogInfo()) Print("SDK Info: Session started successfully!");
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
//| Returns true for deinit reasons where MT5 will reinitialize the   |
//| indicator (chart change, parameter change, recompile, etc.).      |
//| The session should be preserved, not terminated.                   |
//+------------------------------------------------------------------+
bool IsNonDestructiveDeinit(int reason)
{
    switch(reason)
    {
        case REASON_CHARTCHANGE:   // 3 — symbol or period changed
        case REASON_PARAMETERS:    // 5 — input parameters changed
        case REASON_RECOMPILE:     // 2 — recompiled
        case REASON_ACCOUNT:       // 6 — account changed
        case REASON_TEMPLATE:      // 8 — template applied
            return true;
        default:                   // 0-PROGRAM, 1-REMOVE, 4-CHARTCLOSE, others
            return false;
    }
}

//+------------------------------------------------------------------+
//| Deinitialize                                                      |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::on_deinit(const int reason)
{
    string label = is_indicator_mode() ? "Indicator" : "EA";
    if(SDKShouldLogInfo()) Print("SDK Info: Deinitializing ", label, " SDK (reason=", reason, ")...");

    if(CheckPointer(m_sdk_context) == POINTER_INVALID)
    {
        EventKillTimer();
        return;
    }

    // For indicators: non-destructive deinit means MT5 will reinit immediately.
    // Save session state so the new instance can resume without a new /robot/start.
    if(is_indicator_mode() && IsNonDestructiveDeinit(reason))
    {
        if(SDKShouldLogInfo()) Print("SDK Info: Non-destructive deinit (reason ", reason,
              ") — saving session for resumption.");
        m_sdk_context.save_session_state();
    }
    else
    {
        // Destructive deinit (or robot mode): terminate the session normally.
        m_sdk_context.terminate(label + " Shutdown: reason " + (string)reason);
        m_sdk_context.clear_session_state();
    }

    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Timer                                                             |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::on_timer()
{
    // Deferred removal check — remove indicator if init failed
    if(is_indicator_mode() && check_pending_removal())
        return;

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
            if(is_robot_mode())
                on_config_changed(sparam);
            break;
        case SDK_EVENT_SYMBOL_CHANGED:
            if(is_robot_mode())
                on_symbol_changed(sparam);
            break;
        case SDK_EVENT_TERMINATION_START:
        case SDK_EVENT_TERMINATION_END:
        {
            // Guard: ignore termination events from a previous (stale) session.
            // After a non-destructive deinit → reinit cycle, the chart event queue
            // may still contain events fired by the old instance.
            if(CheckPointer(m_sdk_context) != POINTER_INVALID
               && CheckPointer(m_sdk_context.session_manager) != POINTER_INVALID)
            {
                CJAVal guard_data;
                string sparam_copy = sparam;
                if(guard_data.parse(sparam_copy))
                {
                    CJAVal* sid_node = guard_data["session_id"];
                    if(CheckPointer(sid_node) != POINTER_INVALID)
                    {
                        ulong event_sid = (ulong)sid_node.get_long();
                        ulong current_sid = m_sdk_context.session_manager.get_session_id();
                        if(event_sid != 0 && current_sid != 0 && event_sid != current_sid)
                        {
                            if(SDKShouldLogWarning()) Print("SDK Warning: Ignoring stale termination event from session ",
                                  event_sid, " (current session: ", current_sid, ").");
                            break;
                        }
                    }
                }
            }
            handle_termination_event(sparam);
            break;
        }
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
    if(!SDKShouldLogInfo()) return;
    Print("=== SDK Configuration ===");
    Print("  Version UUID: ", m_robot_version_uuid);
    Print("  API Base URL: ", SDK_API_BASE_URL);
    Print("  Log level: ", SDKLogLevelToString(SDKGetLogLevel()));
    
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
    
    if(is_robot_mode())
    {
        string message = "Session terminated by server. Reason: " + reason;
        Print(message);
        Alert(message);
        ExpertRemove();
    }
    else
    {
        SDKUserErrorWithDetails(
            "Session ended. The indicator will be removed from the chart.",
            "Server termination reason: " + reason);
        remove_indicator_from_chart();
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
    
    Print("SDK Error: SERVER REQUESTED SESSION TERMINATION. Reason: ", reason,
          ". ", (is_robot_mode() ? "The Expert Advisor will now terminate..." 
                                  : "The Indicator session will now terminate..."));
    
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
    
    if(is_robot_mode())
    {
        Alert("TheMarketRobo: Server requested termination: " + reason);
        ExpertRemove();
    }
    else
    {
        SDKUserErrorWithDetails(
            "Session stopped by server. The indicator will be removed from the chart.",
            "Termination reason: " + reason);
        remove_indicator_from_chart();
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
        if(is_robot_mode())
        {
            string message = "TheMarketRobo: Authentication failed. The robot will be removed to prevent an unauthorized session.";
            Print(message);
            Alert(message);
            ExpertRemove();
        }
        else
        {
            SDKUserError("Authentication failed. The indicator will be removed from the chart.");
            remove_indicator_from_chart();
        }
    }
    else
    {
        if(SDKShouldLogInfo()) Print("SDK Info: Authentication token refreshed successfully.");
    }
}

//+------------------------------------------------------------------+
//| Log level                                                         |
//+------------------------------------------------------------------+
void CTheMarketRobo_Base::set_log_level(ENUM_SDK_LOG_LEVEL level)
{
    SDKSetLogLevel(level);
}

ENUM_SDK_LOG_LEVEL CTheMarketRobo_Base::get_log_level() const
{
    return SDKGetLogLevel();
}

#endif // SDK_ENABLED

#endif // CTHEMARKETROBO_BASE_MQH
//+------------------------------------------------------------------+
