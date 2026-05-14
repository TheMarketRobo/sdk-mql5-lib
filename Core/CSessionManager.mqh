//+------------------------------------------------------------------+
//|                                               CSessionManager.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSESSION_MANAGER_MQH
#define CSESSION_MANAGER_MQH

#include <Object.mqh>
#include "../Models/CFinalStats.mqh"
#include "../Utils/CSDK_Events.mqh"
#include "../Utils/CSDKLogger.mqh"

class CTMKR_Context;

/**
 * @class CSessionManager
 * @brief Manages the overall robot session lifecycle (/start, /end, /refresh).
 */
class CTMKR_SessionManager : public CObject
{
private:
    ulong m_session_id;
    string m_api_key;
    string m_robot_version_uuid;
    long m_magic_number;
    bool m_is_active;
    CTMKR_Context* m_context;

public:
    CTMKR_SessionManager(string api_key, string robot_version_uuid, long magic_number, CTMKR_Context* context);
    ~CTMKR_SessionManager();

    bool start_session();
    bool resume_session(ulong session_id);
    bool end_session(string tmkr_reason, CTMKR_FinalStats* final_stats);
    bool refresh_token();
    
    bool is_session_active() const;
    ulong get_session_id() const;
    string get_api_key() const;
};

#include "CSDKContext.mqh"

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTMKR_SessionManager::CSessionManager(string api_key, string robot_version_uuid, long magic_number, CTMKR_Context* context)
{
    m_api_key = api_key;
    m_robot_version_uuid = robot_version_uuid;
    m_magic_number = magic_number;
    m_session_id = 0;
    m_is_active = false;
    m_context = context;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTMKR_SessionManager::~CTMKR_SessionManager()
{
}

//+------------------------------------------------------------------+
//| Returns session active status                                     |
//+------------------------------------------------------------------+
bool CTMKR_SessionManager::is_session_active() const
{
    return m_is_active;
}

//+------------------------------------------------------------------+
//| Returns session ID                                                |
//+------------------------------------------------------------------+
ulong CTMKR_SessionManager::get_session_id() const
{
    return m_session_id;
}

//+------------------------------------------------------------------+
//| Returns the API key                                               |
//+------------------------------------------------------------------+
string CTMKR_SessionManager::get_api_key() const
{
    return m_api_key;
}

//+------------------------------------------------------------------+
//| Resume a previously saved session (no HTTP call to /robot/start). |
//| The backend session is still alive; we just restore local state.  |
//+------------------------------------------------------------------+
bool CTMKR_SessionManager::resume_session(ulong session_id)
{
    m_session_id = session_id;
    m_is_active  = true;
    m_context.heartbeat_manager.set_session_id(session_id);
    m_context.heartbeat_manager.request_immediate_heartbeat();
    if(SDKShouldLogInfo()) Print("SDK Info: Resumed existing session. Session ID: ", m_session_id);
    return true;
}

//+------------------------------------------------------------------+
//| Start a new session with the server                               |
//+------------------------------------------------------------------+
bool CTMKR_SessionManager::start_session()
{
    bool is_indicator = m_context.is_indicator();
    
    // IMPORTANT: Wait for account data to be available before starting
    // AccountInfoDouble returns 0 when called in OnInit before the terminal
    // receives any ticks from the server
    if(SDKShouldLogInfo()) Print("SDK Info: Checking account data availability...");
    
    if(!m_context.data_collector.wait_for_account_data(10)) // Wait up to 10 seconds
    {
        if(SDKShouldLogWarning()) Print("SDK Warning: Starting session without full account data - values may be 0");
    }
    
    CTMKR_JAVal* payload = new CTMKR_JAVal(TMKR_JA_OBJECT);
    if(payload == NULL) return false;

    CTMKR_JAVal* api_key_val = new CTMKR_JAVal();
    api_key_val.set_string(m_api_key);
    payload.Add("api_key", api_key_val);

    CTMKR_JAVal* version_val = new CTMKR_JAVal();
    version_val.set_string(m_robot_version_uuid);
    payload.Add("robot_version_uuid", version_val);
    
    // Robots send magic_number; indicators omit it (no order tracking)
    if(!is_indicator)
    {
        CTMKR_JAVal* magic_val = new CTMKR_JAVal();
        magic_val.set_long(m_magic_number);
        payload.Add("magic_number", magic_val);
    }
    
    CTMKR_JAVal* currency_val = new CTMKR_JAVal();
    currency_val.set_string(AccountInfoString(ACCOUNT_CURRENCY));
    payload.Add("account_currency", currency_val);
    
    // Get initial balance/equity (real values after waiting above)
    double initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double initial_equity  = AccountInfoDouble(ACCOUNT_EQUITY);
    
    if(SDKShouldLogDebug()) Print("SDK Debug: Initial Balance: ", initial_balance, ", Initial Equity: ", initial_equity);
    
    CTMKR_JAVal* balance_val = new CTMKR_JAVal();
    balance_val.set_double(NormalizeDouble(initial_balance, 2));
    payload.Add("initial_balance", balance_val);
    
    CTMKR_JAVal* equity_val = new CTMKR_JAVal();
    equity_val.set_double(NormalizeDouble(initial_equity, 2));
    payload.Add("initial_equity", equity_val);
    
    if(SDKShouldLogDebug()) Print("SDK Debug: Collecting static fields...");
    m_context.data_collector.initialize(initial_balance, initial_equity);

    // Indicators pass 0 for magic_number in static_fields; robots pass the real value
    long magic_for_static = is_indicator ? 0 : m_magic_number;
    payload.Add("static_fields", m_context.data_collector.get_static_fields(magic_for_static));
    
    // Robots collect and send session symbols; indicators skip this entirely
    if(!is_indicator)
    {
        if(SDKShouldLogDebug()) Print("SDK Debug: Collecting session symbols...");
        CArrayObj* symbols_list = m_context.data_collector.get_session_symbols();
        CTMKR_JAVal* symbols_array = new CTMKR_JAVal(TMKR_JA_ARRAY);
        if(symbols_list != NULL && symbols_array != NULL)
        {
            for(int tmkr_i = 0; tmkr_i < symbols_list.Total(); tmkr_i++)
            {
                CTMKR_SessionSymbol* tmkr_symbol = symbols_list.At(tmkr_i);
                symbols_array.Add(tmkr_symbol.to_json());
            }
            payload.Add("session_symbols", symbols_array);
            m_context.symbol_manager.set_initial_symbols(symbols_list);
        }
    }

    if(SDKShouldLogDebug()) Print("SDK Debug: Serializing payload...");
    string payload_str = payload.to_string();
    if(SDKShouldLogDebug()) Print("SDK Debug: Payload size: ", StringLen(payload_str));
    if(SDKShouldLogInfo()) Print("SDK Info: Sending start request to server...");
    // API Gateway requires Authorization header to be present for the authorizer to invoke,
    // even for the /start endpoint where we use the API key in the body.
    CTMKR_HttpResponse* response = m_context.http_service.post("/robot/start", "api-key-start", payload_str);
    delete payload;

    if(CheckPointer(response) == POINTER_INVALID || response.code != 200)
    {
        Print("SDK Error: Start session failed. Code: ", response.code, ", Body: ", response.body);
        if(response != NULL) delete response;
        return false;
    }
    
    CTMKR_JAVal* body = response.json_body;
    
    // Server returns session_id as string, need to parse it
    CTMKR_JAVal* session_id_node = body["session_id"];
    if(CheckPointer(session_id_node) != POINTER_INVALID)
    {
        // Try string first (server returns it as string), then fall back to long
        string session_id_str = session_id_node.get_string();
        if(session_id_str != "" && session_id_str != "0")
        {
            m_session_id = (ulong)StringToInteger(session_id_str);
        }
        else
        {
            m_session_id = (ulong)session_id_node.get_long();
        }
    }
    if(SDKShouldLogInfo()) Print("SDK Info: Session started. Session ID: ", m_session_id);
    
    // Pass session ID to heartbeat manager
    m_context.heartbeat_manager.set_session_id(m_session_id);
    
    m_context.token_manager.set_token(body["jwt"].get_string());
    
    CTMKR_JAVal* expires_in_node = body["expires_in"];
    if(CheckPointer(expires_in_node) != POINTER_INVALID)
    {
        m_context.token_manager.set_expires_in((int)expires_in_node.get_long());
    }
    
    // Indicators never receive robot_config from server — session is active immediately.
    // Robots validate the initial config from the server.
    if(is_indicator)
    {
        if(SDKShouldLogInfo()) Print("SDK Info: Indicator session started — no robot_config expected. Session is ACTIVE.");
        m_is_active = true;
    }
    else
    {
        CTMKR_JAVal* server_config = body["robot_config"];
        if(CheckPointer(server_config) == POINTER_INVALID)
        {
            if(SDKShouldLogWarning()) Print("SDK Warning: No robot_config received from server, session will be marked as active");
            m_is_active = true;
        }
        else if(m_context.config_manager.validate_initial_config(server_config))
        {
            if(SDKShouldLogInfo()) Print("SDK Info: Initial configuration validated successfully, session is ACTIVE");
            m_is_active = true;
        }
        else
        {
            Print("SDK Error: Initial configuration from server failed validation. Session NOT active - heartbeats will NOT be sent!");
            m_is_active = false;
        }
        
        // Process any initial change requests (robots only)
        CTMKR_JAVal* config_change_node = body["robot_config_change_request"];
        if(CheckPointer(config_change_node) != POINTER_INVALID)
        {
            m_context.config_manager.process_change_request(config_change_node);
        }
        
        CTMKR_JAVal* symbol_change_node = body["session_symbols_change_request"];
        if(CheckPointer(symbol_change_node) != POINTER_INVALID)
        {
            m_context.symbol_manager.process_change_request(symbol_change_node);
        }
    }

    delete response;
    return m_is_active;
}

//+------------------------------------------------------------------+
//| End the current session                                           |
//+------------------------------------------------------------------+
bool CTMKR_SessionManager::end_session(string tmkr_reason, CTMKR_FinalStats* final_stats)
{
    if(!m_is_active) return false;
    
    STMKR_TerminationEvent start_event;
    start_event.reason = tmkr_reason;
    start_event.success = false;
    start_event.message = "Termination started";
    start_event.session_id = m_session_id;
    Fire_Termination_Start_Event(0, start_event);
    
    CTMKR_JAVal* payload = new CTMKR_JAVal(TMKR_JA_OBJECT);
    if(payload == NULL) return false;

    CTMKR_JAVal* session_id_val = new CTMKR_JAVal();
    session_id_val.set_long(m_session_id);
    payload.Add("session_id", session_id_val);

    CTMKR_JAVal* reason_val = new CTMKR_JAVal();
    reason_val.set_string(tmkr_reason);
    payload.Add("reason", reason_val);

    if(CheckPointer(final_stats) != POINTER_INVALID)
    {
        payload.Add("final_stats", final_stats.to_json());
    }
    
    string payload_str = payload.to_string();
    CTMKR_HttpResponse* response = m_context.http_service.post("/robot/end", m_context.token_manager.get_token(), payload_str);
    delete payload;

    bool success = false;
    string tmkr_message = "";
    
    if(CheckPointer(response) != POINTER_INVALID && response.code == 200)
    {
        m_is_active = false;
        success = true;
        tmkr_message = "Session terminated successfully.";
        if(SDKShouldLogInfo()) Print("SDK Info: ", tmkr_message);
        delete response;
    }
    else
    {
        tmkr_message = "End session failed. Code: " + (string)response.code + ", Body: " + response.body;
        Print("SDK Error: ", tmkr_message);
        if(response != NULL) delete response;
    }
    
    STMKR_TerminationEvent end_event;
    end_event.reason = tmkr_reason;
    end_event.success = success;
    end_event.message = tmkr_message;
    end_event.session_id = m_session_id;
    Fire_Termination_End_Event(0, end_event);
    
    return success;
}

//+------------------------------------------------------------------+
//| Refresh the JWT token                                             |
//+------------------------------------------------------------------+
bool CTMKR_SessionManager::refresh_token()
{
    string current_token = m_context.token_manager.get_token();
    
    CTMKR_JAVal* payload = new CTMKR_JAVal(TMKR_JA_OBJECT);
    CTMKR_JAVal* token_val = new CTMKR_JAVal();
    token_val.set_string(current_token);
    payload.Add("jwt_token", token_val);
    
    string payload_str = payload.to_string();
    // Pass current token for Authorization header - required by the authorizer
    CTMKR_HttpResponse* response = m_context.http_service.post("/robot/refresh", current_token, payload_str);
    delete payload;
    
    bool success = false;
    string tmkr_message = "";
    
    if(CheckPointer(response) != POINTER_INVALID && response.code == 200)
    {
        m_context.token_manager.set_token(response.json_body["jwt"].get_string());
        success = true;
        tmkr_message = "Token refreshed successfully";
        delete response;
    }
    else
    {
        tmkr_message = "Token refresh failed. Code: " + (string)response.code + ", Body: " + response.body;
        delete response;
    }
    
    STMKR_TokenRefreshEvent event_data;
    event_data.success = success;
    event_data.message = tmkr_message;
    Fire_Token_Refresh_Event(0, event_data);
    
    return success;
}

#endif
//+------------------------------------------------------------------+

