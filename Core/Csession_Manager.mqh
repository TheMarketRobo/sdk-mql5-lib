//+------------------------------------------------------------------+
//|                                           CSession_Manager.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSESSION_MANAGER_MQH
#define CSESSION_MANAGER_MQH

#include <Object.mqh>
#include "../Models/Cfinal_Stats.mqh"

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
    string m_robot_version;
    long m_magic_number;
    bool m_is_active;

    // SDK Context
    CSDK_Context* m_context;

public:
    Csession_Manager(string api_key, string robot_version, long magic_number, CSDK_Context* context);
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
Csession_Manager::Csession_Manager(string api_key, string robot_version, long magic_number, CSDK_Context* context)
{
    m_api_key = api_key;
    m_robot_version = robot_version;
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
 */
bool Csession_Manager::start_session()
{
    // 1. Build request payload
    CJAVal* payload = new CJAVal(JA_OBJECT);
    if(payload == NULL) return false;

    CJAVal* api_key_val = new CJAVal();
    api_key_val.set_string(m_api_key);
    payload.Add("api_key", api_key_val);

    CJAVal* version_val = new CJAVal();
    version_val.set_string(m_robot_version);
    payload.Add("robot_version", version_val);

    // Get static fields and session symbols from the collector via context
    payload.Add("static_fields", m_context.data_collector.get_static_fields(m_magic_number));
    
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
    Chttp_Response* response = m_context.http_service.post("/start", "", payload_str);
    delete payload; // Clean up the payload object

    if(CheckPointer(response) == POINTER_INVALID || response.code != 200)
    {
        // TODO: Log the error from response.body
        Print("SDK Error: Start session failed. Code: ", response.code, ", Body: ", response.body);
        if(response != NULL) delete response;
        return false;
    }
    
    // 3. Process successful response
    CJAVal* body = response.json_body;
    m_session_id = (ulong)body["session_id"].get_long();
    m_context.token_manager.set_token(body["jwt"].get_string());
    
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
        // Consider terminating the session if config is invalid
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

    if(CheckPointer(response) != POINTER_INVALID && response.code == 200)
    {
        m_is_active = false;
        Print("SDK Info: Session terminated successfully.");
        delete response;
        return true;
    }
    
    Print("SDK Error: End session failed. Code: ", response.code, ", Body: ", response.body);
    if(response != NULL) delete response;
    return false;
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
    
    if(CheckPointer(response) != POINTER_INVALID && response.code == 200)
    {
        m_context.token_manager.set_token(response.json_body["jwt"].get_string());
        delete response;
        return true;
    }

    delete response;
    return false;
}

#endif
//+------------------------------------------------------------------+
