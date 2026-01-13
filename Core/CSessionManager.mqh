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

class CSDKContext;

/**
 * @class CSessionManager
 * @brief Manages the overall robot session lifecycle (/start, /end, /refresh).
 */
class CSessionManager : public CObject
{
private:
    ulong m_session_id;
    string m_api_key;
    string m_robot_version_uuid;
    long m_magic_number;
    bool m_is_active;
    CSDKContext* m_context;

public:
    CSessionManager(string api_key, string robot_version_uuid, long magic_number, CSDKContext* context);
    ~CSessionManager();

    bool start_session();
    bool end_session(string reason, CFinalStats* final_stats);
    bool refresh_token();
    
    bool is_session_active() const;
    ulong get_session_id() const;
};

#include "CSDKContext.mqh"

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSessionManager::CSessionManager(string api_key, string robot_version_uuid, long magic_number, CSDKContext* context)
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
CSessionManager::~CSessionManager()
{
}

//+------------------------------------------------------------------+
//| Returns session active status                                     |
//+------------------------------------------------------------------+
bool CSessionManager::is_session_active() const
{
    return m_is_active;
}

//+------------------------------------------------------------------+
//| Returns session ID                                                |
//+------------------------------------------------------------------+
ulong CSessionManager::get_session_id() const
{
    return m_session_id;
}

//+------------------------------------------------------------------+
//| Start a new session with the server                               |
//+------------------------------------------------------------------+
bool CSessionManager::start_session()
{
    CJAVal* payload = new CJAVal(JA_OBJECT);
    if(payload == NULL) return false;

    CJAVal* api_key_val = new CJAVal();
    api_key_val.set_string(m_api_key);
    payload.Add("api_key", api_key_val);

    CJAVal* version_val = new CJAVal();
    version_val.set_string(m_robot_version_uuid);
    payload.Add("robot_version_uuid", version_val);
    
    CJAVal* magic_val = new CJAVal();
    magic_val.set_long(m_magic_number);
    payload.Add("magic_number", magic_val);
    
    CJAVal* currency_val = new CJAVal();
    currency_val.set_string(AccountInfoString(ACCOUNT_CURRENCY));
    payload.Add("account_currency", currency_val);
    
    double initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    CJAVal* balance_val = new CJAVal();
    balance_val.set_double(NormalizeDouble(initial_balance, 2));
    payload.Add("initial_balance", balance_val);
    
    double initial_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    CJAVal* equity_val = new CJAVal();
    equity_val.set_double(NormalizeDouble(initial_equity, 2));
    payload.Add("initial_equity", equity_val);
    
    Print("SDK Debug: Collecting static fields...");
    m_context.data_collector.initialize(initial_balance, initial_equity);

    payload.Add("static_fields", m_context.data_collector.get_static_fields(m_magic_number));
    
    Print("SDK Debug: Collecting session symbols...");
    CArrayObj* symbols_list = m_context.data_collector.get_session_symbols();
    CJAVal* symbols_array = new CJAVal(JA_ARRAY);
    if(symbols_list != NULL && symbols_array != NULL)
    {
        for(int i = 0; i < symbols_list.Total(); i++)
        {
            CSessionSymbol* symbol = symbols_list.At(i);
            symbols_array.Add(symbol.to_json());
        }
        payload.Add("session_symbols", symbols_array);
        m_context.symbol_manager.set_initial_symbols(symbols_list);
    }

    Print("SDK Debug: Serializing payload...");
    string payload_str = payload.to_string();
    Print("SDK Debug: Payload size: ", StringLen(payload_str));
    Print("SDK Info: Sending start request to server...");
    CHttpResponse* response = m_context.http_service.post("/robot/start", "", payload_str);
    delete payload;

    if(CheckPointer(response) == POINTER_INVALID || response.code != 200)
    {
        Print("SDK Error: Start session failed. Code: ", response.code, ", Body: ", response.body);
        if(response != NULL) delete response;
        return false;
    }
    
    CJAVal* body = response.json_body;
    
    m_session_id = (ulong)body["session_id"].get_long();
    Print("SDK Info: Session started. Session ID: ", m_session_id);
    
    m_context.token_manager.set_token(body["jwt"].get_string());
    
    CJAVal* expires_in_node = body["expires_in"];
    if(CheckPointer(expires_in_node) != POINTER_INVALID)
    {
        m_context.token_manager.set_expires_in((int)expires_in_node.get_long());
    }
    
    CJAVal* server_config = body["robot_config"];
    if(CheckPointer(server_config) != POINTER_INVALID && m_context.config_manager.validate_initial_config(server_config))
    {
         m_is_active = true;
    }
    else
    {
        Print("SDK Error: Initial configuration from server failed validation.");
        m_is_active = false;
    }
    
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

//+------------------------------------------------------------------+
//| End the current session                                           |
//+------------------------------------------------------------------+
bool CSessionManager::end_session(string reason, CFinalStats* final_stats)
{
    if(!m_is_active) return false;
    
    STermination_Event start_event;
    start_event.reason = reason;
    start_event.success = false;
    start_event.message = "Termination started";
    Fire_Termination_Start_Event(0, start_event);
    
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
    CHttpResponse* response = m_context.http_service.post("/robot/end", m_context.token_manager.get_token(), payload_str);
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
    
    STermination_Event end_event;
    end_event.reason = reason;
    end_event.success = success;
    end_event.message = message;
    Fire_Termination_End_Event(0, end_event);
    
    return success;
}

//+------------------------------------------------------------------+
//| Refresh the JWT token                                             |
//+------------------------------------------------------------------+
bool CSessionManager::refresh_token()
{
    CJAVal* payload = new CJAVal(JA_OBJECT);
    CJAVal* token_val = new CJAVal();
    token_val.set_string(m_context.token_manager.get_token());
    payload.Add("jwt_token", token_val);
    
    string payload_str = payload.to_string();
    CHttpResponse* response = m_context.http_service.post("/robot/refresh", "", payload_str);
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
    
    SToken_Refresh_Event event_data;
    event_data.success = success;
    event_data.message = message;
    Fire_Token_Refresh_Event(0, event_data);
    
    return success;
}

#endif
//+------------------------------------------------------------------+

