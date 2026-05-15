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
#include "TMR_Platform.mqh"

//+------------------------------------------------------------------+
//| When SDK_ENABLED is NOT defined, provide a lightweight stub       |
//| that preserves the public interface but performs no SDK operations. |
//| Developer code compiles and runs without changes.                  |
//+------------------------------------------------------------------+
#ifndef TMKR_SDK_ENABLED

#include "Interfaces/IRobotConfig.mqh"

class CTMKR_RobotBase
{
protected:
    string       m_robot_version_uuid;
    ITMKR_RobotConfig* m_robot_config;

public:
    // Robot constructor (matches full API — config pointer is stored for developer access)
    CTMKR_RobotBase(string robot_version_uuid, ITMKR_RobotConfig* robot_config)
    {
        m_robot_version_uuid = robot_version_uuid;
        m_robot_config = robot_config;
    }

    // Indicator constructor
    CTMKR_RobotBase(string robot_version_uuid)
    {
        m_robot_version_uuid = robot_version_uuid;
        m_robot_config = NULL;
    }

    ~CTMKR_RobotBase()
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

    virtual void on_deinit(const int tmkr_reason) {}
    virtual void on_timer() {}
    virtual void on_chart_event(const int tmkr_id, const long &lparam, const double &dparam, const string &sparam) {}

    // Robot callbacks (override in EA)
    virtual void on_tick() {}
    virtual void on_config_changed(string event_json) {}
    virtual void on_symbol_changed(string event_json) {}

    // Indicator callback (override in indicator)
    virtual int on_calculate(const int rates_total,
                              const int prev_calculated,
                              const datetime &tmkr_time[],
                              const double   &open[],
                              const double   &high[],
                              const double   &low[],
                              const double   &close[],
                              const long     &tick_volume[],
                              const long     &tmkr_volume[],
                              const int      &tmkr_spread[]) { return rates_total; }

    // Shared callback
    virtual void on_termination_requested(string event_json) {}

    // Configuration stubs (no-ops)
    void set_token_refresh_threshold(int seconds) {}
    int  get_token_refresh_threshold() const { return 0; }
    void set_max_heartbeat_failure_intervals(int intervals) {}
    int  get_max_heartbeat_failure_intervals() const { return TMKR_DEFAULT_MAX_HEARTBEAT_FAILURE_INTERVALS; }
    void set_enable_config_change_requests(bool enable) {}
    bool is_config_change_requests_enabled() const { return false; }
    void set_enable_symbol_change_requests(bool enable) {}
    bool is_symbol_change_requests_enabled() const { return false; }
    void print_sdk_configuration() const { if(SDKShouldLogInfo()) Print("SDK Info: SDK is disabled — no configuration to display."); }
    string get_robot_version_uuid() const { return m_robot_version_uuid; }
    // Stub mirrors the full class's NULL-context fallback: indicators are
    // constructed with the 1-arg ctor (m_robot_config == NULL); robots
    // pass a non-NULL IRobotConfig*.
    bool is_indicator_mode() const { return (m_robot_config == NULL); }
    bool is_robot_mode() const { return (m_robot_config != NULL); }
    void set_indicator_short_name(string short_name) {}
    void set_indicator_buffer_count(int count) {}
    bool is_pending_removal() const { return false; }
    bool is_killed() const { return false; }
    void set_log_level(ENUM_TMKR_LOG_LEVEL tmkr_level) { TMKRSetLogLevel(tmkr_level); }
    ENUM_TMKR_LOG_LEVEL get_log_level() const { return TMKRGetLogLevel(); }
    // Stub mode has no SDK to short-circuit, but vendor code may still
    // check tester state — answer from the live platform query.
    bool is_in_tester_mode() const { return TMR_IsInTester(); }
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
class CTMKR_RobotBase
{
protected:
    CTMKR_Context*    m_sdk_context;
    ITMKR_RobotConfig*   m_robot_config;
    string          m_robot_version_uuid;
    int             m_token_refresh_threshold_seconds;
    int             m_max_heartbeat_failure_intervals;
    bool            m_enable_config_change_requests;
    bool            m_enable_symbol_change_requests;
    string          m_indicator_short_name;   // For ChartIndicatorDelete self-removal
    bool            m_pending_removal;        // Deferred removal flag (set during init, executed on first tick/timer)
    bool            m_killed;                 // Indicator functionally dead (security: all output cleared, calc blocked)
    int             m_indicator_buffer_count; // Number of indicator buffers (for kill_indicator draw clearing)
    bool            m_in_tester_mode;         // True when running in MT4/MT5 Strategy Tester — SDK is offline

public:
    // Robot constructor — requires config object
    CTMKR_RobotBase(string robot_version_uuid, ITMKR_RobotConfig* robot_config);
    
    // Indicator constructor — no config needed
    CTMKR_RobotBase(string robot_version_uuid);
    
    ~CTMKR_RobotBase();

    // Robot init: requires magic_number for order identification
    virtual int  on_init(string api_key, long magic_number);
    
    // Indicator init: no magic_number; product type is set to INDICATOR automatically
    virtual int  on_init(string api_key);
    
    virtual void on_deinit(const int tmkr_reason);
    virtual void on_timer();
    virtual void on_chart_event(const int tmkr_id, const long &lparam, const double &dparam, const string &sparam);

    // --- Robot callbacks (override in EA) ---
    virtual void on_tick() {}
    virtual void on_config_changed(string event_json) {}
    virtual void on_symbol_changed(string event_json) {}

    // --- Indicator callback (override in indicator) ---
    virtual int  on_calculate(const int rates_total,
                              const int prev_calculated,
                              const datetime &tmkr_time[],
                              const double   &open[],
                              const double   &high[],
                              const double   &low[],
                              const double   &close[],
                              const long     &tick_volume[],
                              const long     &tmkr_volume[],
                              const int      &tmkr_spread[]) { return rates_total; }

    // --- Shared callback ---
    // Default: robots call ExpertRemove(), indicators stop the timer and alert the user.
    virtual void on_termination_requested(string event_json);
    
    void set_token_refresh_threshold(int seconds);
    int  get_token_refresh_threshold() const;
    
    void set_enable_config_change_requests(bool enable);
    bool is_config_change_requests_enabled() const;
    
    void set_enable_symbol_change_requests(bool enable);
    bool is_symbol_change_requests_enabled() const;
    
    void set_max_heartbeat_failure_intervals(int intervals);
    int  get_max_heartbeat_failure_intervals() const;
    
    void   print_sdk_configuration() const;
    string get_robot_version_uuid() const;
    bool   is_indicator_mode() const;
    bool   is_robot_mode() const;
    
    // Indicator self-removal — call set_indicator_short_name() during OnInit()
    void   set_indicator_short_name(string short_name);
    bool   is_pending_removal() const;

    // Indicator buffer count — call during OnInit() after SetIndexBuffer() calls.
    // Used by kill_indicator() to hide all draw styles on termination.
    void   set_indicator_buffer_count(int count);
    bool   is_killed() const;

    // Returns true if the SDK detected MT4/MT5 Strategy Tester at init
    // time and is running in offline mode (no auth, no HTTP, no
    // heartbeats). on_tick / on_calculate still run normally.
    bool   is_in_tester_mode() const;

    // Log level control — set before or after on_init()
    void   set_log_level(ENUM_TMKR_LOG_LEVEL tmkr_level);
    ENUM_TMKR_LOG_LEVEL get_log_level() const;

protected:
    void   remove_indicator_from_chart();
    bool   check_pending_removal();
    void   kill_indicator();
    void handle_termination_event(string event_json);
    void handle_termination_requested_event(string event_json);
    void handle_token_refresh_event(string event_json);
    
    int  init_common(string api_key, long magic_number, ENUM_TMKR_PRODUCT_TYPE product_type);
};

//+------------------------------------------------------------------+
//| Robot constructor                                                 |
//+------------------------------------------------------------------+
CTMKR_RobotBase::CTMKR_RobotBase(string robot_version_uuid, ITMKR_RobotConfig* robot_config)
{
    m_sdk_context = NULL;
    m_robot_config = robot_config;
    m_robot_version_uuid = robot_version_uuid;
    m_token_refresh_threshold_seconds = TMKR_DEFAULT_TOKEN_REFRESH_THRESHOLD;
    m_enable_config_change_requests = true;
    m_enable_symbol_change_requests = true;
    m_indicator_short_name = "";
    m_pending_removal = false;
    m_killed = false;
    m_indicator_buffer_count = 0;
    m_in_tester_mode = false;
    m_max_heartbeat_failure_intervals = TMKR_DEFAULT_MAX_HEARTBEAT_FAILURE_INTERVALS;
    if(SDKShouldLogInfo()) Print("SDK Info: Robot Version UUID = ", m_robot_version_uuid);
}

//+------------------------------------------------------------------+
//| Indicator constructor (no config)                                 |
//+------------------------------------------------------------------+
CTMKR_RobotBase::CTMKR_RobotBase(string robot_version_uuid)
{
    m_sdk_context = NULL;
    m_robot_config = NULL;
    m_robot_version_uuid = robot_version_uuid;
    m_token_refresh_threshold_seconds = TMKR_DEFAULT_TOKEN_REFRESH_THRESHOLD;
    m_enable_config_change_requests = false; // Indicators never use config changes
    m_enable_symbol_change_requests = false; // Indicators never use symbol changes
    m_indicator_short_name = "";
    m_pending_removal = false;
    m_killed = false;
    m_indicator_buffer_count = 0;
    m_in_tester_mode = false;
    m_max_heartbeat_failure_intervals = TMKR_DEFAULT_MAX_HEARTBEAT_FAILURE_INTERVALS;
    if(SDKShouldLogInfo()) Print("SDK Info: Indicator Version UUID = ", m_robot_version_uuid);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTMKR_RobotBase::~CTMKR_RobotBase()
{
    if(CheckPointer(m_sdk_context) == POINTER_DYNAMIC)
        delete m_sdk_context;
    
    if(CheckPointer(m_robot_config) == POINTER_DYNAMIC)
        delete m_robot_config;
}

//+------------------------------------------------------------------+
//| Getters                                                           |
//+------------------------------------------------------------------+
string CTMKR_RobotBase::get_robot_version_uuid() const { return m_robot_version_uuid; }

bool CTMKR_RobotBase::is_indicator_mode() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        return m_sdk_context.is_indicator();
    return (m_robot_config == NULL);
}

bool CTMKR_RobotBase::is_robot_mode() const
{
    return !is_indicator_mode();
}

//+------------------------------------------------------------------+
//| Indicator short name (for self-removal via ChartIndicatorDelete)  |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::set_indicator_short_name(string short_name)
{
    m_indicator_short_name = short_name;
}

bool CTMKR_RobotBase::is_pending_removal() const
{
    return m_pending_removal;
}

//+------------------------------------------------------------------+
//| Remove this indicator from the chart using ChartIndicatorDelete   |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::remove_indicator_from_chart()
{
    EventKillTimer();
    if(m_indicator_short_name != "")
    {
        if(!TMKRRemoveIndicatorFromChart(m_indicator_short_name))
        {
            // ChartIndicatorDelete failed (common on MQL4) — apply functional death
            kill_indicator();
            // Write persistent kill file so indicator can't restart on timeframe change
            if(CheckPointer(m_sdk_context) != POINTER_INVALID)
                m_sdk_context.write_kill_file();
        }
    }
    else
    {
        Print("SDK SECURITY ERROR: Indicator short name not set — cannot auto-remove from chart. "
              "The programmer MUST call set_indicator_short_name() during OnInit(). "
              "Without it, server-side termination cannot remove the indicator.");
        Alert("TheMarketRobo: CRITICAL — indicator could not be removed. Please remove it manually.");
        kill_indicator();  // Still kill functionality even without short name
        if(CheckPointer(m_sdk_context) != POINTER_INVALID)
            m_sdk_context.write_kill_file();
    }
}

//+------------------------------------------------------------------+
//| Check if pending removal should execute (call at top of          |
//| on_calculate / on_timer). Returns true if removal was triggered.  |
//+------------------------------------------------------------------+
bool CTMKR_RobotBase::check_pending_removal()
{
    if(m_pending_removal)
    {
        remove_indicator_from_chart();
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Set indicator buffer count — call during OnInit() after           |
//| SetIndexBuffer() calls. Used by kill_indicator() to hide draws.   |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::set_indicator_buffer_count(int count)
{
    m_indicator_buffer_count = count;
}

//+------------------------------------------------------------------+
//| Returns true if indicator has been functionally killed             |
//+------------------------------------------------------------------+
bool CTMKR_RobotBase::is_killed() const
{
    return m_killed;
}

//+------------------------------------------------------------------+
//| Returns true if SDK is running in offline tester mode             |
//+------------------------------------------------------------------+
bool CTMKR_RobotBase::is_in_tester_mode() const
{
    return m_in_tester_mode;
}

//+------------------------------------------------------------------+
//| Functionally kill the indicator — clear all visual output,        |
//| block all future calculation, and mark as dead.                   |
//| This is the security fallback when ChartIndicatorDelete fails.    |
//|                                                                    |
//| MQL4 vs MQL5 indicator-API split:                                 |
//|  - MQL4 uses the legacy `SetIndexStyle()` / `IndicatorShortName()` |
//|    free functions to set per-buffer draw type and the chart-list  |
//|    short name.                                                    |
//|  - MQL5 deprecated those in favour of `PlotIndexSetInteger()`     |
//|    (with `PLOT_DRAW_TYPE`) and `IndicatorSetString()` (with       |
//|    `INDICATOR_SHORTNAME`). Calling the MQL4 names from MQL5 source |
//|    is a hard compile error, so the guards below dispatch to the   |
//|    platform-correct API.                                          |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::kill_indicator()
{
    if(m_killed) return;  // Already dead
    m_killed = true;
    EventKillTimer();

    // Hide all indicator draw styles — lines/arrows/histograms disappear
    for(int tmkr_i = 0; tmkr_i < m_indicator_buffer_count; tmkr_i++)
    {
#ifdef __MQL4__
        SetIndexStyle(tmkr_i, DRAW_NONE);
#else
        PlotIndexSetInteger(tmkr_i, PLOT_DRAW_TYPE, DRAW_NONE);
#endif
    }

    // Blank the indicator name in chart's indicator list
#ifdef __MQL4__
    IndicatorShortName("TMR: DISABLED");
#else
    IndicatorSetString(INDICATOR_SHORTNAME, "TMR: DISABLED");
#endif

    // Force visual update so cleared draws take effect immediately
    ChartRedraw(0);

    Print("SDK Security: Indicator functionally killed — all output cleared, calculation blocked.");
}

//+------------------------------------------------------------------+
//| Shared init implementation                                        |
//+------------------------------------------------------------------+
int CTMKR_RobotBase::init_common(string api_key, long magic_number, ENUM_TMKR_PRODUCT_TYPE product_type)
{
    bool is_ind = (product_type == PRODUCT_TYPE_INDICATOR);

    //----------------------------------------------------------------
    // SDK Version + Tester Detection Diagnostic (always printed)
    //
    // Printed UNCONDITIONALLY (no log-level gate) so vendors can verify
    // which SDK version their compiled .ex5/.ex4 contains and which
    // tester-detection signal fired. If "Strategy Tester detected"
    // does NOT appear below despite running in tester, capture this
    // banner line and check (a) SDK version is current; (b) which flag
    // is missing. See docs/STRATEGY_TESTER_GUIDE.md.
    //----------------------------------------------------------------
    int tmkr_flag_tester       = (int)MQLInfoInteger(MQL_TESTER);
    int tmkr_flag_optimization = (int)MQLInfoInteger(MQL_OPTIMIZATION);
    int tmkr_flag_visual       = (int)MQLInfoInteger(MQL_VISUAL_MODE);
#ifdef __MQL5__
    int tmkr_flag_frame   = (int)MQLInfoInteger(MQL_FRAME_MODE);
    int tmkr_flag_forward = (int)MQLInfoInteger(MQL_FORWARD);
#else
    int tmkr_flag_frame   = -1;
    int tmkr_flag_forward = -1;
#endif
    Print("SDK Info: TheMarketRobo SDK v", TMKR_SDK_VERSION,
          " | platform=", TMR_PLATFORM,
          " | flags=[MQL_TESTER=", tmkr_flag_tester,
          ", MQL_OPTIMIZATION=", tmkr_flag_optimization,
          ", MQL_VISUAL_MODE=", tmkr_flag_visual,
          ", MQL_FRAME_MODE=", tmkr_flag_frame,
          ", MQL_FORWARD=", tmkr_flag_forward, "]",
          " | TMR_IsInTester=", (int)TMR_IsInTester(),
          " | matched_signal=", TMR_TesterDetectionTrace());

    //----------------------------------------------------------------
    // Strategy Tester short-circuit
    //
    // The MT4/MT5 Strategy Tester blocks WebRequest() and all network
    // functions, blocks DLL imports on cloud agents, never fires the
    // timer on MQL4, and never fires OnChartEvent in MQL5 indicators.
    // Trying to start a session would only fail noisily and slow down
    // every optimization pass.
    //
    // When tester is detected we:
    //  1. Skip API key + UUID validation (vendor can leave them empty).
    //  2. Skip CSDKContext creation — no HTTP, no DLLs, no managers.
    //  3. Skip EventSetTimer (timer is a no-op in MQL4 tester anyway).
    //  4. For robots: apply default config so on_tick() can read fields
    //     as it would in production.
    //  5. Return INIT_SUCCEEDED so the tester proceeds to OnTick/
    //     OnCalculate and the developer's logic runs normally.
    //----------------------------------------------------------------
    if(TMR_IsInTester())
    {
        m_in_tester_mode = true;
        Print("SDK Info: Strategy Tester detected (mode=", TMR_GetTesterModeLabel(),
              ") — running in offline mode. No authentication, no HTTP, no heartbeats. ",
              "Your ", (is_ind ? "indicator" : "robot"),
              " logic will execute normally; SDK lifecycle is bypassed.");

        // Apply defaults so vendor on_tick() can read config values
        // exactly as they would in a live session. apply_defaults() is
        // expected to be idempotent — most vendor configs call it in
        // their own constructor, but we call it here too so configs
        // that don't will still have valid field values in tester.
        // Live mode would normally receive these via the /robot/start
        // response; in tester there is no server, hence defaults.
        if(!is_ind && CheckPointer(m_robot_config) != POINTER_INVALID)
        {
            m_robot_config.apply_defaults();
            if(SDKShouldLogInfo()) Print("SDK Info: Tester mode — applied default robot config values.");
        }

        return INIT_SUCCEEDED;
    }

    if(m_robot_version_uuid == "" || StringLen(m_robot_version_uuid) != TMKR_UUID_LENGTH)
    {
        Print("SDK Error: Invalid robot_version_uuid. Must be a valid UUID (36 characters).");
        if(is_ind)
        {
            TMKRUserError("Setup error — invalid product configuration. Please contact support.");
            m_pending_removal = true;
        }
        return INIT_FAILED;
    }
    
    if(api_key == "")
    {
        Print("SDK Error: API Key is required. Please provide a valid API key.");
        if(is_ind)
        {
            TMKRUserError("API Key is required. Please set it in the indicator settings.");
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

    m_sdk_context = new CTMKR_Context(api_key, m_robot_version_uuid, magic_number, m_robot_config, product_type);
    if(CheckPointer(m_sdk_context) == POINTER_INVALID)
    {
        Print("SDK Error: Failed to create SDK Context.");
        if(is_ind)
        {
            TMKRUserError("Failed to start. Please try removing and re-adding the indicator.");
            m_pending_removal = true;
        }
        return INIT_FAILED;
    }
    
    m_sdk_context.set_token_refresh_threshold_seconds(m_token_refresh_threshold_seconds);
    m_sdk_context.set_max_heartbeat_failure_intervals(m_max_heartbeat_failure_intervals);
    
    // Config/symbol toggle setters are no-ops for indicators (guarded in CSDKOptions)
    m_sdk_context.set_enable_config_change_requests(m_enable_config_change_requests);
    m_sdk_context.set_enable_symbol_change_requests(m_enable_symbol_change_requests);
    
    print_sdk_configuration();

    // Security: check if this indicator was previously killed (terminated by server).
    // The kill file persists across timeframe changes to prevent session restart.
    if(is_ind && m_sdk_context.check_kill_file())
    {
        TMKRUserError("This indicator session was terminated. Please remove it from the chart.");
        m_killed = true;
        EventSetTimer(1);  // Timer fires → on_timer returns immediately due to m_killed
        return INIT_SUCCEEDED;
    }

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
            TMKRUserError("Could not connect to TheMarketRobo service. Please check your internet connection and try again.");
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
int CTMKR_RobotBase::on_init(string api_key, long magic_number)
{
    return init_common(api_key, magic_number, PRODUCT_TYPE_ROBOT);
}

//+------------------------------------------------------------------+
//| Indicator initialization (no magic number)                        |
//+------------------------------------------------------------------+
int CTMKR_RobotBase::on_init(string api_key)
{
    return init_common(api_key, 0, PRODUCT_TYPE_INDICATOR);
}

//+------------------------------------------------------------------+
//| Returns true for deinit reasons where MT5 will reinitialize the   |
//| indicator (chart change, parameter change, recompile, etc.).      |
//| The session should be preserved, not terminated.                   |
//+------------------------------------------------------------------+
bool IsNonDestructiveDeinit(int tmkr_reason)
{
    switch(tmkr_reason)
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
void CTMKR_RobotBase::on_deinit(const int tmkr_reason)
{
    if(m_in_tester_mode)
    {
        if(SDKShouldLogInfo()) Print("SDK Info: Tester deinit (reason=", tmkr_reason, ").");
        return;
    }

    string tmkr_label = is_indicator_mode() ? "Indicator" : "EA";
    if(SDKShouldLogInfo()) Print("SDK Info: Deinitializing ", tmkr_label, " SDK (reason=", tmkr_reason, ")...");

    if(CheckPointer(m_sdk_context) == POINTER_INVALID)
    {
        EventKillTimer();
        return;
    }

    // For indicators: non-destructive deinit means MT5 will reinit immediately.
    // Save session state so the new instance can resume without a new /robot/start.
    if(is_indicator_mode() && IsNonDestructiveDeinit(tmkr_reason))
    {
        if(SDKShouldLogInfo()) Print("SDK Info: Non-destructive deinit (reason ", tmkr_reason,
              ") — saving session for resumption.");
        m_sdk_context.save_session_state();
    }
    else
    {
        // Destructive deinit (or robot mode): terminate the session normally.
        m_sdk_context.clear_kill_file();  // User explicitly removed — allow fresh start later
        m_sdk_context.terminate(tmkr_label + " Shutdown: reason " + (string)tmkr_reason);
        m_sdk_context.clear_session_state();
    }

    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Timer                                                             |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::on_timer()
{
    // Tester mode: SDK is offline, nothing to do on timer.
    // (Defensive — we never call EventSetTimer in tester anyway, and
    // MQL4 ignores OnTimer in tester regardless.)
    if(m_in_tester_mode) return;

    // Security: indicator was killed — no processing allowed
    if(m_killed) return;

    // Deferred removal check — remove indicator if init failed
    if(is_indicator_mode() && check_pending_removal())
        return;

    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.on_timer();
}

//+------------------------------------------------------------------+
//| Chart event                                                       |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::on_chart_event(const int tmkr_id, const long &lparam, const double &dparam, const string &sparam)
{
    // Tester mode: SDK does not emit chart events, and MQL5 indicators
    // do not receive any chart events in tester anyway. Bail early.
    if(m_in_tester_mode) return;

    switch(tmkr_id)
    {
        case TMKR_EVENT_CONFIG_CHANGED:
            if(is_robot_mode())
                on_config_changed(sparam);
            break;
        case TMKR_EVENT_SYMBOL_CHANGED:
            if(is_robot_mode())
                on_symbol_changed(sparam);
            break;
        case TMKR_EVENT_TERMINATION_START:
        case TMKR_EVENT_TERMINATION_END:
        {
            // Guard: ignore termination events from a previous (stale) session.
            // After a non-destructive deinit → reinit cycle, the chart event queue
            // may still contain events fired by the old instance.
            if(CheckPointer(m_sdk_context) != POINTER_INVALID
               && CheckPointer(m_sdk_context.session_manager) != POINTER_INVALID)
            {
                CTMKR_JAVal guard_data;
                string sparam_copy = sparam;
                if(guard_data.parse(sparam_copy))
                {
                    CTMKR_JAVal* sid_node = guard_data["session_id"];
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
        case TMKR_EVENT_TERMINATION_REQUESTED:
            handle_termination_requested_event(sparam);
            break;
        case TMKR_EVENT_TOKEN_REFRESH:
            handle_token_refresh_event(sparam);
            break;
    }
}

//+------------------------------------------------------------------+
//| Token refresh threshold                                           |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::set_token_refresh_threshold(int seconds)
{
    m_token_refresh_threshold_seconds = seconds;
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.set_token_refresh_threshold_seconds(seconds);
}

int CTMKR_RobotBase::get_token_refresh_threshold() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        return m_sdk_context.get_token_refresh_threshold_seconds();
    return m_token_refresh_threshold_seconds;
}

//+------------------------------------------------------------------+
//| Max heartbeat failure intervals (connection-lost removal)        |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::set_max_heartbeat_failure_intervals(int intervals)
{
    m_max_heartbeat_failure_intervals = intervals;
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.set_max_heartbeat_failure_intervals(intervals);
}

int CTMKR_RobotBase::get_max_heartbeat_failure_intervals() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        return m_sdk_context.get_max_heartbeat_failure_intervals();
    return m_max_heartbeat_failure_intervals;
}

//+------------------------------------------------------------------+
//| Config change requests toggle (no-op for indicators)             |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::set_enable_config_change_requests(bool enable)
{
    m_enable_config_change_requests = enable;
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.set_enable_config_change_requests(enable);
}

bool CTMKR_RobotBase::is_config_change_requests_enabled() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        return m_sdk_context.is_config_change_requests_enabled();
    return m_enable_config_change_requests;
}

//+------------------------------------------------------------------+
//| Symbol change requests toggle (no-op for indicators)             |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::set_enable_symbol_change_requests(bool enable)
{
    m_enable_symbol_change_requests = enable;
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        m_sdk_context.set_enable_symbol_change_requests(enable);
}

bool CTMKR_RobotBase::is_symbol_change_requests_enabled() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
        return m_sdk_context.is_symbol_change_requests_enabled();
    return m_enable_symbol_change_requests;
}

//+------------------------------------------------------------------+
//| Print configuration                                               |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::print_sdk_configuration() const
{
    if(!SDKShouldLogInfo()) return;
    Print("=== SDK Configuration ===");
    Print("  Version UUID: ", m_robot_version_uuid);
    Print("  API Base URL: ", TMKR_API_BASE_URL);
    Print("  Log level: ", SDKLogLevelToString(TMKRGetLogLevel()));
    
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
void CTMKR_RobotBase::handle_termination_event(string event_json)
{
    CTMKR_JAVal event_data;
    if(!event_data.parse(event_json)) return;

    string tmkr_reason = event_data["reason"].get_string();
    
    if(is_robot_mode())
    {
        string tmkr_message = "Session terminated by server. Reason: " + tmkr_reason;
        Print(tmkr_message);
        Alert(tmkr_message);
        ExpertRemove();
    }
    else
    {
        TMKRUserErrorWithDetails(
            "Session ended. The indicator will be removed from the chart.",
            "Server termination reason: " + tmkr_reason);
        remove_indicator_from_chart();
    }
}

//+------------------------------------------------------------------+
//| Handle termination requested event (server asked to stop)         |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::handle_termination_requested_event(string event_json)
{
    CTMKR_JAVal event_data;
    if(!event_data.parse(event_json)) return;

    string tmkr_reason = event_data["reason"].get_string();
    
    Print("SDK Error: SERVER REQUESTED SESSION TERMINATION. Reason: ", tmkr_reason,
          ". ", (is_robot_mode() ? "The Expert Advisor will now terminate..." 
                                  : "The Indicator session will now terminate..."));
    
    on_termination_requested(event_json);
}

//+------------------------------------------------------------------+
//| Default termination handler (virtual — can be overridden)         |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::on_termination_requested(string event_json)
{
    CTMKR_JAVal event_data;
    string tmkr_reason = "Server requested termination";
    
    if(event_data.parse(event_json))
        tmkr_reason = event_data["reason"].get_string();
    
    if(is_robot_mode())
    {
        Alert("TheMarketRobo: Server requested termination: " + tmkr_reason);
        ExpertRemove();
    }
    else
    {
        TMKRUserErrorWithDetails(
            "Session stopped by server. The indicator will be removed from the chart.",
            "Termination reason: " + tmkr_reason);
        remove_indicator_from_chart();
    }
}

//+------------------------------------------------------------------+
//| Handle token refresh event                                        |
//+------------------------------------------------------------------+
void CTMKR_RobotBase::handle_token_refresh_event(string event_json)
{
    CTMKR_JAVal event_data;
    if(!event_data.parse(event_json)) return;

    bool success = event_data["success"].get_bool();
    if(!success)
    {
        if(is_robot_mode())
        {
            string tmkr_message = "TheMarketRobo: Authentication failed. The robot will be removed to prevent an unauthorized session.";
            Print(tmkr_message);
            Alert(tmkr_message);
            ExpertRemove();
        }
        else
        {
            TMKRUserError("Authentication failed. The indicator will be removed from the chart.");
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
void CTMKR_RobotBase::set_log_level(ENUM_TMKR_LOG_LEVEL tmkr_level)
{
    TMKRSetLogLevel(tmkr_level);
}

ENUM_TMKR_LOG_LEVEL CTMKR_RobotBase::get_log_level() const
{
    return TMKRGetLogLevel();
}

#endif // SDK_ENABLED

#endif // CTHEMARKETROBO_BASE_MQH
//+------------------------------------------------------------------+
