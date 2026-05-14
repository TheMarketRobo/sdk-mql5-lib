//+------------------------------------------------------------------+
//|                                                  CSDKContext.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSDK_CONTEXT_MQH
#define CSDK_CONTEXT_MQH

#include <Object.mqh>
#include "CSDKOptions.mqh"
#include "CSDKConstants.mqh"
#include "CSessionManager.mqh"
#include "CHeartbeatManager.mqh"
#include "CTokenManager.mqh"
#include "CConfigurationManager.mqh"
#include "CSymbolManager.mqh"
#include "../Utils/CSDKLogger.mqh"
#include "../Services/CHttpService.mqh"
#include "../Services/CDataCollectorService.mqh"
#include "../Interfaces/IRobotConfig.mqh"
#include "../Utils/CSDK_Events.mqh"

/**
 * @class CSDKContext
 * @brief A service container for managing the lifecycle and dependencies of all SDK components.
 *
 * When product_type is PRODUCT_TYPE_INDICATOR:
 * - magic_number is ignored (pass 0)
 * - config may be NULL; config_manager and symbol_manager are disabled
 * - Session start payload omits magic_number, robot_config, and session_symbols
 * - Heartbeat payload omits config/symbol change results
 */
class CTMKR_Context : public CObject
{
private:
    CTMKR_Options* m_options;

public:
    CTMKR_SessionManager*       session_manager;
    CTMKR_HeartbeatManager*     heartbeat_manager;
    CTMKR_TokenManager*         token_manager;
    CTMKR_ConfigurationManager* config_manager;
    CTMKR_SymbolManager*        symbol_manager;
    CTMKR_HttpService*          http_service;
    CTMKR_DataCollectorService* data_collector;
    ITMKR_RobotConfig*          robot_config;

public:
    CTMKR_Context(string api_key, string robot_version_uuid, long magic_number, ITMKR_RobotConfig* config,
                ENUM_TMKR_PRODUCT_TYPE product_type = PRODUCT_TYPE_ROBOT);
    ~CTMKR_Context();

    bool start();
    bool try_restore_session();
    void save_session_state();
    void clear_session_state();
    void write_kill_file();
    bool check_kill_file() const;
    void clear_kill_file();
    void on_timer();
    void terminate(string tmkr_reason);
    
    void set_token_refresh_threshold_seconds(int seconds);
    int  get_token_refresh_threshold_seconds() const;
    
    void set_enable_config_change_requests(bool enable);
    bool is_config_change_requests_enabled() const;
    
    void set_enable_symbol_change_requests(bool enable);
    bool is_symbol_change_requests_enabled() const;
    
    void set_max_heartbeat_failure_intervals(int intervals);
    int  get_max_heartbeat_failure_intervals() const;
    
    CTMKR_Options* get_options() const;
    void print_configuration() const;
    
    bool is_indicator() const;
    bool is_robot() const;
    ENUM_TMKR_PRODUCT_TYPE get_product_type() const;

private:
    string get_state_filename() const;
    string get_kill_filename() const;
    int   m_consecutive_heartbeat_failures;
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTMKR_Context::CSDKContext(string api_key, string robot_version_uuid, long magic_number, ITMKR_RobotConfig* config,
                         ENUM_TMKR_PRODUCT_TYPE product_type)
{
    m_options             = NULL;
    session_manager       = NULL;
    heartbeat_manager     = NULL;
    token_manager         = NULL;
    config_manager        = NULL;
    symbol_manager        = NULL;
    http_service          = NULL;
    data_collector        = NULL;
    robot_config          = NULL;

    m_consecutive_heartbeat_failures = 0;

    if(SDKShouldLogInfo()) Print("SDK Info: TheMarketRobo SDK v", TMKR_SDK_VERSION);
    if(SDKShouldLogInfo()) Print("SDK Info: API Base URL = ", TMKR_API_BASE_URL);
    if(SDKShouldLogInfo()) Print("SDK Info: Product type = ", (product_type == PRODUCT_TYPE_INDICATOR) ? "INDICATOR" : "ROBOT");

    robot_config = config;
    
    m_options = new CTMKR_Options();
    if(CheckPointer(m_options) == POINTER_INVALID) { Print("SDK Error: Failed to create CSDKOptions"); return; }
    
    // Apply product type — this also enforces indicator restrictions on config/symbol toggles
    m_options.set_product_type(product_type);

    http_service = new CTMKR_HttpService(product_type);
    if(CheckPointer(http_service) == POINTER_INVALID) { Print("SDK Error: Failed to create CHttpService"); return; }

    data_collector = new CTMKR_DataCollectorService();
    if(CheckPointer(data_collector) == POINTER_INVALID) { Print("SDK Error: Failed to create CDataCollectorService"); return; }

    token_manager = new CTMKR_TokenManager();
    if(CheckPointer(token_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CTokenManager"); return; }

    // For indicators, robot_config is NULL — config_manager is created but permanently disabled.
    config_manager = new CTMKR_ConfigurationManager(robot_config);
    if(CheckPointer(config_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CConfigurationManager"); return; }
    if(product_type == PRODUCT_TYPE_INDICATOR)
        config_manager.set_enabled(false);

    symbol_manager = new CTMKR_SymbolManager();
    if(CheckPointer(symbol_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CSymbolManager"); return; }
    if(product_type == PRODUCT_TYPE_INDICATOR)
        symbol_manager.set_enabled(false);
    
    session_manager = new CTMKR_SessionManager(api_key, robot_version_uuid, magic_number, GetPointer(this));
    if(CheckPointer(session_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CSessionManager"); return; }

    heartbeat_manager = new CTMKR_HeartbeatManager(GetPointer(this));
    if(CheckPointer(heartbeat_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CHeartbeatManager"); return; }
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTMKR_Context::~CTMKR_Context()
{
    if(CheckPointer(heartbeat_manager) == POINTER_DYNAMIC) delete heartbeat_manager;
    if(CheckPointer(session_manager) == POINTER_DYNAMIC) delete session_manager;
    if(CheckPointer(symbol_manager) == POINTER_DYNAMIC) delete symbol_manager;
    if(CheckPointer(config_manager) == POINTER_DYNAMIC) delete config_manager;
    if(CheckPointer(token_manager) == POINTER_DYNAMIC) delete token_manager;
    if(CheckPointer(data_collector) == POINTER_DYNAMIC) delete data_collector;
    if(CheckPointer(http_service) == POINTER_DYNAMIC) delete http_service;
    if(CheckPointer(m_options) == POINTER_DYNAMIC) delete m_options;
}

//+------------------------------------------------------------------+
//| Start session                                                     |
//+------------------------------------------------------------------+
bool CTMKR_Context::start()
{
    if(CheckPointer(session_manager) == POINTER_INVALID) return false;
    return session_manager.start_session();
}

//+------------------------------------------------------------------+
//| Build the state filename unique to this chart + API key           |
//+------------------------------------------------------------------+
string CTMKR_Context::get_state_filename() const
{
    string api_key = "";
    if(CheckPointer(session_manager) != POINTER_INVALID)
        api_key = session_manager.get_api_key();
    string key_prefix = StringSubstr(api_key, 0, 8);
    return "TMR_session_" + IntegerToString(ChartID()) + "_" + key_prefix + ".dat";
}

//+------------------------------------------------------------------+
//| Save session state to file for resumption after non-destructive   |
//| deinit (chart change, parameter change, recompile, etc.)          |
//+------------------------------------------------------------------+
void CTMKR_Context::save_session_state()
{
    if(CheckPointer(session_manager) == POINTER_INVALID || !session_manager.is_session_active())
        return;

    string fname = get_state_filename();
    int handle = FileOpen(fname, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(handle == INVALID_HANDLE)
    {
        if(SDKShouldLogWarning()) Print("SDK Warning: Could not save session state (FileOpen failed).");
        return;
    }

    string jwt = token_manager.get_token();
    int    expires_in = token_manager.get_expires_in();
    long   exp_ts = token_manager.get_expiration_timestamp();
    ulong  sid = session_manager.get_session_id();
    string api_key = session_manager.get_api_key();

    // Format: session_id|expires_in|expiration_ts|api_key|jwt (jwt last because it contains no '|')
    string tmkr_line = IntegerToString(sid) + "|"
                + IntegerToString(expires_in) + "|"
                + IntegerToString(exp_ts) + "|"
                + api_key + "|"
                + jwt;
    FileWriteString(handle, tmkr_line);
    FileClose(handle);

    if(SDKShouldLogInfo()) Print("SDK Info: Session state saved for resumption (session ", sid, ").");
}

//+------------------------------------------------------------------+
//| Try to restore a previously saved session. Returns true if the    |
//| session was successfully resumed (no /robot/start needed).        |
//+------------------------------------------------------------------+
bool CTMKR_Context::try_restore_session()
{
    string fname = get_state_filename();

    if(!FileIsExist(fname))
        return false;

    int handle = FileOpen(fname, FILE_READ | FILE_TXT | FILE_ANSI);
    if(handle == INVALID_HANDLE)
    {
        if(SDKShouldLogInfo()) Print("SDK Info: Session state file exists but could not be opened.");
        return false;
    }

    string tmkr_line = FileReadString(handle);
    FileClose(handle);
    FileDelete(fname);

    if(tmkr_line == "")
        return false;

    // Parse: session_id|expires_in|expiration_ts|api_key|jwt
    string parts[];
    int count = StringSplit(tmkr_line, '|', parts);
    if(count < 5)
    {
        if(SDKShouldLogWarning()) Print("SDK Warning: Corrupt session state file (expected 5 fields, got ", count, ").");
        return false;
    }

    ulong  saved_sid     = (ulong)StringToInteger(parts[0]);
    int    saved_exp_in  = (int)StringToInteger(parts[1]);
    long   saved_exp_ts  = (long)StringToInteger(parts[2]);
    string saved_api_key = parts[3];
    string saved_jwt     = parts[4];

    // Validate the API key matches (user might have changed inputs)
    if(saved_api_key != session_manager.get_api_key())
    {
        if(SDKShouldLogInfo()) Print("SDK Info: Saved session API key mismatch — starting fresh session.");
        return false;
    }

    // Check token expiry — if already expired, start fresh
    if(saved_exp_ts > 0 && (long)TimeLocal() >= saved_exp_ts)
    {
        if(SDKShouldLogInfo()) Print("SDK Info: Saved session token expired — starting fresh session.");
        return false;
    }

    // Restore token and resume session
    token_manager.restore_token(saved_jwt, saved_exp_in);
    if(!token_manager.is_token_set())
    {
        if(SDKShouldLogWarning()) Print("SDK Warning: Saved token could not be decoded — starting fresh session.");
        return false;
    }

    session_manager.resume_session(saved_sid);
    if(SDKShouldLogInfo()) Print("SDK Info: Session resumed after chart reinit (session ", saved_sid, ").");
    return true;
}

//+------------------------------------------------------------------+
//| Delete saved session state file (destructive deinit)              |
//+------------------------------------------------------------------+
void CTMKR_Context::clear_session_state()
{
    string fname = get_state_filename();
    if(FileIsExist(fname))
        FileDelete(fname);
}

//+------------------------------------------------------------------+
//| Build the kill filename (same pattern as session state file)       |
//+------------------------------------------------------------------+
string CTMKR_Context::get_kill_filename() const
{
    string api_key = "";
    if(CheckPointer(session_manager) != POINTER_INVALID)
        api_key = session_manager.get_api_key();
    string key_prefix = StringSubstr(api_key, 0, 8);
    return "TMR_killed_" + IntegerToString(ChartID()) + "_" + key_prefix + ".dat";
}

//+------------------------------------------------------------------+
//| Write a persistent kill file — blocks indicator restart after      |
//| timeframe change. Deleted only on destructive deinit (user removes |
//| indicator from chart) to allow a fresh session later.              |
//+------------------------------------------------------------------+
void CTMKR_Context::write_kill_file()
{
    string fname = get_kill_filename();
    int handle = FileOpen(fname, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(handle != INVALID_HANDLE)
    {
        FileWriteString(handle, "KILLED:" + TimeToString(TimeLocal()));
        FileClose(handle);
        if(SDKShouldLogInfo()) Print("SDK Security: Kill file written — indicator blocked from restart.");
    }
}

//+------------------------------------------------------------------+
//| Check if a kill file exists (indicator was previously terminated)  |
//+------------------------------------------------------------------+
bool CTMKR_Context::check_kill_file() const
{
    return FileIsExist(get_kill_filename());
}

//+------------------------------------------------------------------+
//| Delete the kill file (destructive deinit — allow fresh start)      |
//+------------------------------------------------------------------+
void CTMKR_Context::clear_kill_file()
{
    string fname = get_kill_filename();
    if(FileIsExist(fname))
    {
        FileDelete(fname);
        if(SDKShouldLogInfo()) Print("SDK Info: Kill file cleared — fresh session allowed.");
    }
}

//+------------------------------------------------------------------+
//| On timer                                                          |
//+------------------------------------------------------------------+
void CTMKR_Context::on_timer()
{
    // Check if session manager is valid
    if(CheckPointer(session_manager) == POINTER_INVALID)
    {
        if(SDKShouldLogDebug()) Print("SDK Debug: on_timer() - Session manager is INVALID, skipping");
        return;
    }
    
    // Check if session is active
    if(!session_manager.is_session_active())
    {
        if(SDKShouldLogDebug()) Print("SDK Debug: on_timer() - Session is NOT ACTIVE, skipping heartbeat");
        return;
    }
    
    // Check if token needs refresh
    if(token_manager.should_refresh_token())
    {
        if(SDKShouldLogDebug()) Print("SDK Debug: Token refresh required, refreshing...");
        session_manager.refresh_token();
    }
    
    // Check heartbeat manager validity
    if(CheckPointer(heartbeat_manager) == POINTER_INVALID)
    {
        if(SDKShouldLogDebug()) Print("SDK Debug: on_timer() - Heartbeat manager is INVALID");
        return;
    }
    
    // Check if it's time to send heartbeat
    if(!heartbeat_manager.is_time_to_send())
    {
        // Only log occasionally to avoid spam (every 30 seconds)
        // Use TimeLocal() instead of TimeCurrent() because TimeCurrent() doesn't
        // advance when the market is closed (weekends/holidays)
        static datetime last_waiting_log = 0;
        if(TimeLocal() - last_waiting_log >= 30)
        {
            if(SDKShouldLogDebug()) Print("SDK Debug: Waiting for heartbeat interval...");
            last_waiting_log = TimeLocal();
        }
        return;
    }
    
    // Build heartbeat payload
    if(SDKShouldLogDebug()) Print("SDK Debug: Building heartbeat payload...");
    CTMKR_JAVal* payload = heartbeat_manager.build_heartbeat_payload();
    if(CheckPointer(payload) == POINTER_INVALID)
    {
        Print("SDK Error: Failed to build heartbeat payload");
        return;
    }
    
    // Send heartbeat
    string payload_str = payload.to_string();
    if(SDKShouldLogDebug()) Print("SDK Debug: Sending heartbeat request...");
    CTMKR_HttpResponse* response = http_service.post("/robot/heartbeat", token_manager.get_token(), payload_str);

    if(CheckPointer(response) == POINTER_INVALID)
    {
        Print("SDK Error: Heartbeat request failed - NULL response");
        m_consecutive_heartbeat_failures++;
        if(m_consecutive_heartbeat_failures >= m_options.get_max_heartbeat_failure_intervals())
        {
            Print("SDK Error: Connection lost — ", m_consecutive_heartbeat_failures,
                  " consecutive heartbeat failures (max ", m_options.get_max_heartbeat_failure_intervals(),
                  "). Removing product from chart.");
            string tmkr_reason = "Connection lost: maximum heartbeat failure intervals (" +
                            IntegerToString(m_options.get_max_heartbeat_failure_intervals()) + ") exceeded.";
            terminate(tmkr_reason);
            CTMKR_JAVal event_json(TMKR_JA_OBJECT);
            CTMKR_JAVal* reason_val = new CTMKR_JAVal();
            reason_val.set_string(tmkr_reason);
            event_json.Add("reason", reason_val);
            Fire_Termination_Requested_Event(0, event_json.to_string());
        }
        return;
    }
    
    if(response.code == 200)
    {
        m_consecutive_heartbeat_failures = 0;
        if(SDKShouldLogInfo()) Print("SDK Info: Heartbeat sent successfully (HTTP 200)");
        heartbeat_manager.process_heartbeat_response(response.json_body);
    }
    else if(response.code == 409)
    {
        // Sequence error - sync with server and retry
        if(SDKShouldLogWarning()) Print("SDK Warning: Heartbeat sequence mismatch (HTTP 409), syncing...");
        if(CheckPointer(response.json_body) != POINTER_INVALID)
        {
            if(heartbeat_manager.handle_sequence_error(response.json_body))
            {
                if(SDKShouldLogInfo()) Print("SDK Info: Sequence synced successfully, will retry next interval");
            }
            else
            {
                if(SDKShouldLogWarning()) Print("SDK Warning: Could not sync sequence from server response");
                // Reset state anyway to try again
                heartbeat_manager.reset_confirmation_state();
            }
        }
        else
        {
            if(SDKShouldLogWarning()) Print("SDK Warning: No JSON body in 409 response, resetting state");
            heartbeat_manager.reset_confirmation_state();
        }
    }
    else
    {
        Print("SDK Error: Heartbeat failed with HTTP code: ", response.code);
        Print("SDK Error: Response body: ", response.body);
        
        m_consecutive_heartbeat_failures++;
        if(m_consecutive_heartbeat_failures >= m_options.get_max_heartbeat_failure_intervals())
        {
            Print("SDK Error: Connection lost — ", m_consecutive_heartbeat_failures,
                  " consecutive heartbeat failures (max ", m_options.get_max_heartbeat_failure_intervals(),
                  "). Removing product from chart.");
            string tmkr_reason = "Connection lost: maximum heartbeat failure intervals (" +
                            IntegerToString(m_options.get_max_heartbeat_failure_intervals()) + ") exceeded.";
            terminate(tmkr_reason);
            CTMKR_JAVal event_json(TMKR_JA_OBJECT);
            CTMKR_JAVal* reason_val = new CTMKR_JAVal();
            reason_val.set_string(tmkr_reason);
            event_json.Add("reason", reason_val);
            Fire_Termination_Requested_Event(0, event_json.to_string());
            delete response;
            return;
        }
        
        // For transient errors (5xx, network issues), reset state to allow retry
        if(response.code >= 500 || response.code == 0)
        {
            if(SDKShouldLogInfo()) Print("SDK Info: Transient error, will retry heartbeat (failure count: ", m_consecutive_heartbeat_failures, "/", m_options.get_max_heartbeat_failure_intervals(), ")");
            heartbeat_manager.reset_confirmation_state();
        }
    }
    
    delete response;
}

//+------------------------------------------------------------------+
//| Terminate session                                                 |
//+------------------------------------------------------------------+
void CTMKR_Context::terminate(string tmkr_reason)
{
    if(CheckPointer(session_manager) != POINTER_INVALID && session_manager.is_session_active())
    {
        CTMKR_FinalStats* stats = new CTMKR_FinalStats();
        session_manager.end_session(tmkr_reason, stats);
        delete stats;
    }
}

//+------------------------------------------------------------------+
//| Token refresh threshold                                           |
//+------------------------------------------------------------------+
void CTMKR_Context::set_token_refresh_threshold_seconds(int seconds)
{
    if(CheckPointer(token_manager) != POINTER_INVALID)
        token_manager.set_refresh_threshold_seconds(seconds);
}

int CTMKR_Context::get_token_refresh_threshold_seconds() const
{
    if(CheckPointer(token_manager) != POINTER_INVALID)
        return token_manager.get_refresh_threshold_seconds();
    return 300;
}

//+------------------------------------------------------------------+
//| Config change requests toggle                                     |
//+------------------------------------------------------------------+
void CTMKR_Context::set_enable_config_change_requests(bool enable)
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        m_options.set_enable_config_change_requests(enable);
    if(CheckPointer(config_manager) != POINTER_INVALID)
        config_manager.set_enabled(enable);
}

bool CTMKR_Context::is_config_change_requests_enabled() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        return m_options.is_config_change_requests_enabled();
    return true;
}

//+------------------------------------------------------------------+
//| Symbol change requests toggle                                     |
//+------------------------------------------------------------------+
void CTMKR_Context::set_enable_symbol_change_requests(bool enable)
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        m_options.set_enable_symbol_change_requests(enable);
    if(CheckPointer(symbol_manager) != POINTER_INVALID)
        symbol_manager.set_enabled(enable);
}

bool CTMKR_Context::is_symbol_change_requests_enabled() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        return m_options.is_symbol_change_requests_enabled();
    return true;
}

//+------------------------------------------------------------------+
//| Max heartbeat failure intervals (connection-lost removal)         |
//+------------------------------------------------------------------+
void CTMKR_Context::set_max_heartbeat_failure_intervals(int intervals)
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        m_options.set_max_heartbeat_failure_intervals(intervals);
}

int CTMKR_Context::get_max_heartbeat_failure_intervals() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        return m_options.get_max_heartbeat_failure_intervals();
    return TMKR_DEFAULT_MAX_HEARTBEAT_FAILURE_INTERVALS;
}

//+------------------------------------------------------------------+
//| Options access                                                    |
//+------------------------------------------------------------------+
CTMKR_Options* CTMKR_Context::get_options() const
{
    return m_options;
}

//+------------------------------------------------------------------+
//| Print configuration                                               |
//+------------------------------------------------------------------+
void CTMKR_Context::print_configuration() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        m_options.print_options();
}

//+------------------------------------------------------------------+
//| Product type helpers                                              |
//+------------------------------------------------------------------+
bool CTMKR_Context::is_indicator() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        return m_options.is_indicator();
    return false;
}

bool CTMKR_Context::is_robot() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        return m_options.is_robot();
    return true;
}

ENUM_TMKR_PRODUCT_TYPE CTMKR_Context::get_product_type() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        return m_options.get_product_type();
    return PRODUCT_TYPE_ROBOT;
}

#endif
//+------------------------------------------------------------------+

