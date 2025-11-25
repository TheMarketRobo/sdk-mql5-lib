//+------------------------------------------------------------------+
//|                                           CSession_Manager.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSESSION_MANAGER_MQH
#define CSESSION_MANAGER_MQH

#include <Object.mqh>
#include "../Models/Cfinal_Stats.mqh"
#include "../Utils/CSDK_Events.mqh"

// Forward declaration to break circular dependency
class CSDK_Context;

/**
 * @class Csession_Manager
 * @brief Manages the overall robot session lifecycle (/start, /end, /refresh).
 */
class Csession_Manager : public CObject
{
private:
    // Session State
    ulong m_session_id;
    string m_api_key;
    string m_robot_version_uuid;
    long m_magic_number;
    bool m_is_active;

    // SDK Context
    CSDK_Context* m_context;

public:
    Csession_Manager(string api_key, string robot_version_uuid, long magic_number, CSDK_Context* context);
    ~Csession_Manager();

    bool start_session();
    bool end_session(string reason, Cfinal_Stats* final_stats);
    bool refresh_token();
    
    // Getters for internal components are no longer needed here
    // They are accessed via the context

    bool is_session_active() const { return m_is_active; }
    ulong get_session_id() const { return m_session_id; }
};

#include "CSDK_Context.mqh" // Full include for implementation

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
Csession_Manager::Csession_Manager(string api_key, string robot_version_uuid, long magic_number, CSDK_Context* context)
{
    m_api_key = api_key;
    m_robot_version_uuid = robot_version_uuid;
    m_magic_number = magic_number;
    m_session_id = 0;
    m_is_active = false;
    m_context = context;
}

Csession_Manager::~Csession_Manager()
{
    // Components are now owned by the context, so we don't delete them here.
}

/**
 * @brief Initiates and establishes a new session with the server.
 * @return true if the session was started successfully.
 * @note Request payload matches RobotStartRequest schema from API contract.
 */
bool Csession_Manager::start_session()
{
    // 1. Build request payload (matches RobotStartRequest schema)
    CJAVal* payload = new CJAVal(JA_OBJECT);
    if(payload == NULL) return false;

    // ===========================================================================
    // REQUIRED FIELDS (from RobotStartRequest)
    // ===========================================================================

    // api_key: string - Robot API key for authentication
    CJAVal* api_key_val = new CJAVal();
    api_key_val.set_string(m_api_key);
    payload.Add("api_key", api_key_val);

    // robot_version_uuid: string - Robot version UUID
    CJAVal* version_val = new CJAVal();
    version_val.set_string(m_robot_version_uuid);
    payload.Add("robot_version_uuid", version_val);
    
    // magic_number: integer - Expert Advisor magic number
    CJAVal* magic_val = new CJAVal();
    magic_val.set_long(m_magic_number);
    payload.Add("magic_number", magic_val);
    
    // account_currency: string - Account deposit currency (ISO 4217)
    CJAVal* currency_val = new CJAVal();
    currency_val.set_string(AccountInfoString(ACCOUNT_CURRENCY));
    payload.Add("account_currency", currency_val);
    
    // initial_balance: number - Starting account balance
    double initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    CJAVal* balance_val = new CJAVal();
    balance_val.set_double(NormalizeDouble(initial_balance, 2));
    payload.Add("initial_balance", balance_val);
    
    // initial_equity: number - Starting account equity
    double initial_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    CJAVal* equity_val = new CJAVal();
    equity_val.set_double(NormalizeDouble(initial_equity, 2));
    payload.Add("initial_equity", equity_val);
    
    // Initialize data collector with initial values for profit/drawdown calculations
    m_context.data_collector.initialize(initial_balance, initial_equity);

    // static_fields: object - Static trading environment data
    payload.Add("static_fields", m_context.data_collector.get_static_fields(m_magic_number));
    
    // session_symbols: array - Trading symbols with specifications
    CArrayObj* symbols_list = m_context.data_collector.get_session_symbols();
    CJAVal* symbols_array = new CJAVal(JA_ARRAY);
    if(symbols_list != NULL && symbols_array != NULL)
    {
        for(int i = 0; i < symbols_list.Total(); i++)
        {
            Csession_Symbol* symbol = symbols_list.At(i);
            symbols_array.Add(symbol.to_json());
        }
        payload.Add("session_symbols", symbols_array);
        m_context.symbol_manager.set_initial_symbols(symbols_list);
    }

    // 2. Send POST request to /start via context
    string payload_str = payload.to_string();
    Print("SDK Info: Sending start request to server...");
    Chttp_Response* response = m_context.http_service.post("/start", "", payload_str);
    delete payload; // Clean up the payload object

    if(CheckPointer(response) == POINTER_INVALID || response.code != 200)
    {
        Print("SDK Error: Start session failed. Code: ", response.code, ", Body: ", response.body);
        if(response != NULL) delete response;
        return false;
    }
    
    // 3. Process successful response (matches RobotStartResponse schema)
    CJAVal* body = response.json_body;
    
    // session_id: integer - Unique session identifier
    m_session_id = (ulong)body["session_id"].get_long();
    Print("SDK Info: Session started. Session ID: ", m_session_id);
    
    // jwt: string - JWT authentication token
    m_context.token_manager.set_token(body["jwt"].get_string());
    
    // expires_in: integer - Token validity duration in seconds
    CJAVal* expires_in_node = body["expires_in"];
    if(CheckPointer(expires_in_node) != POINTER_INVALID)
    {
        m_context.token_manager.set_expires_in((int)expires_in_node.get_long());
    }
    
    // 4. Validate and set initial configuration
    CJAVal* server_config = body["robot_config"];
    if(CheckPointer(server_config) != POINTER_INVALID && m_context.config_manager.validate_initial_config(server_config))
    {
         m_is_active = true;
    }
    else
    {
        // Handle config validation error
        Print("SDK Error: Initial configuration from server failed validation.");
        m_is_active = false;
    }
    
    // 5. Process any pending change requests from response
    CJAVal* config_change_node = body["robot_config_change_request"];
    if(CheckPointer(config_change_node) != POINTER_INVALID)
    {
        m_context.config_manager.process_change_request(config_change_node);
    }
    
    CJAVal* symbol_change_node = body["session_symbols_change_request"];
    if(CheckPointer(symbol_change_node) != POINTER_INVALID)
    {
        m_context.symbol_manager.process_change_request(symbol_change_node);
    }

    delete response;
    return m_is_active;
}

/**
 * @brief Terminates the current active session.
 * @return true if termination was acknowledged by the server.
 */
bool Csession_Manager::end_session(string reason, Cfinal_Stats* final_stats)
{
    if(!m_is_active) return false;
    
    // Fire termination start event
    STermination_Event start_event;
    start_event.reason = reason;
    start_event.success = false; // Will be updated based on result
    start_event.message = "Termination started";
    Fire_Termination_Start_Event(0, start_event);
    
    // Build payload with session_id, reason, final_stats
    CJAVal* payload = new CJAVal(JA_OBJECT);
    if(payload == NULL) return false;

    CJAVal* session_id_val = new CJAVal();
    session_id_val.set_long(m_session_id);
    payload.Add("session_id", session_id_val);

    CJAVal* reason_val = new CJAVal();
    reason_val.set_string(reason);
    payload.Add("reason", reason_val);

    if(CheckPointer(final_stats) != POINTER_INVALID)
    {
        payload.Add("final_stats", final_stats.to_json());
    }
    
    string payload_str = payload.to_string();
    Chttp_Response* response = m_context.http_service.post("/end", m_context.token_manager.get_token(), payload_str);
    delete payload;

    bool success = false;
    string message = "";
    
    if(CheckPointer(response) != POINTER_INVALID && response.code == 200)
    {
        m_is_active = false;
        success = true;
        message = "Session terminated successfully.";
        Print("SDK Info: ", message);
        delete response;
    }
    else
    {
        message = "End session failed. Code: " + (string)response.code + ", Body: " + response.body;
        Print("SDK Error: ", message);
        if(response != NULL) delete response;
    }
    
    // Fire termination end event
    STermination_Event end_event;
    end_event.reason = reason;
    end_event.success = success;
    end_event.message = message;
    Fire_Termination_End_Event(0, end_event);
    
    return success;
}

/**
 * @brief Refreshes the session's JWT.
 * @return true if the token was refreshed successfully.
 */
bool Csession_Manager::refresh_token()
{
    CJAVal* payload = new CJAVal(JA_OBJECT);
    CJAVal* token_val = new CJAVal();
    token_val.set_string(m_context.token_manager.get_token());
    payload.Add("jwt_token", token_val);
    
    string payload_str = payload.to_string();
    Chttp_Response* response = m_context.http_service.post("/refresh", "", payload_str);
    delete payload;
    
    bool success = false;
    string message = "";
    
    if(CheckPointer(response) != POINTER_INVALID && response.code == 200)
    {
        m_context.token_manager.set_token(response.json_body["jwt"].get_string());
        success = true;
        message = "Token refreshed successfully";
        delete response;
    }
    else
    {
        message = "Token refresh failed. Code: " + (string)response.code + ", Body: " + response.body;
        delete response;
    }
    
    // Fire token refresh event
    SToken_Refresh_Event event_data;
    event_data.success = success;
    event_data.message = message;
    Fire_Token_Refresh_Event(0, event_data);
    
    return success;
}

#endif
//+------------------------------------------------------------------+
