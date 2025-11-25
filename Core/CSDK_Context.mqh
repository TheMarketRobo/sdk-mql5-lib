//+------------------------------------------------------------------+
//|                                                CSDK_Context.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSDK_CONTEXT_MQH
#define CSDK_CONTEXT_MQH

#include <Object.mqh>
#include "Csession_Manager.mqh"
#include "CHeartbeat_Manager.mqh"
#include "CToken_Manager.mqh"
#include "Cconfiguration_Manager.mqh"
#include "CSymbol_Manager.mqh"
#include "../Services/Chttp_Service.mqh"
#include "../Services/Cdata_Collector_Service.mqh"
#include "../Interfaces/Irobot_Config.mqh"

/**
 * @class CSDK_Context
 * @brief A service container for managing the lifecycle and dependencies of all SDK components.
 */
class CSDK_Context : public CObject
{
public:
    // Core Managers and Services
    Csession_Manager*       session_manager;
    CHeartbeat_Manager*     heartbeat_manager;
    CToken_Manager*         token_manager;
    Cconfiguration_Manager* config_manager;
    CSymbol_Manager*        symbol_manager;
    Chttp_Service*          http_service;
    Cdata_Collector_Service* data_collector;
    
    // Developer Interfaces
    Irobot_Config*          robot_config;

public:
    CSDK_Context(string api_key, string robot_version_uuid, long magic_number, Irobot_Config* config, string base_url);
    ~CSDK_Context();

    bool start();
    void on_timer();
    void terminate(string reason);
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
CSDK_Context::CSDK_Context(string api_key, string robot_version_uuid, long magic_number, Irobot_Config* config, string base_url)
{
    // Initialize all pointers to NULL
    session_manager       = NULL;
    heartbeat_manager     = NULL;
    token_manager         = NULL;
    config_manager        = NULL;
    symbol_manager        = NULL;
    http_service          = NULL;
    data_collector        = NULL;
    robot_config          = NULL;

    // Store developer interfaces
    robot_config = config;

    // Create services first (lowest level dependencies)
    http_service = new Chttp_Service(base_url);
    if(CheckPointer(http_service) == POINTER_INVALID) { Print("SDK Error: Failed to create Chttp_Service"); return; }

    data_collector = new Cdata_Collector_Service();
    if(CheckPointer(data_collector) == POINTER_INVALID) { Print("SDK Error: Failed to create Cdata_Collector_Service"); return; }

    // Create core managers
    token_manager = new CToken_Manager();
    if(CheckPointer(token_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CToken_Manager"); return; }

    config_manager = new Cconfiguration_Manager(robot_config);
    if(CheckPointer(config_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create Cconfiguration_Manager"); return; }

    symbol_manager = new CSymbol_Manager();
    if(CheckPointer(symbol_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CSymbol_Manager"); return; }
    
    // Create high-level managers that use other components
    session_manager = new Csession_Manager(api_key, robot_version_uuid, magic_number, GetPointer(this));
    if(CheckPointer(session_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create Csession_Manager"); return; }

    heartbeat_manager = new CHeartbeat_Manager(GetPointer(this));
    if(CheckPointer(heartbeat_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CHeartbeat_Manager"); return; }
}

CSDK_Context::~CSDK_Context()
{
    // Delete all managed objects in reverse order of creation
    if(CheckPointer(heartbeat_manager) == POINTER_DYNAMIC) delete heartbeat_manager;
    if(CheckPointer(session_manager) == POINTER_DYNAMIC) delete session_manager;
    if(CheckPointer(symbol_manager) == POINTER_DYNAMIC) delete symbol_manager;
    if(CheckPointer(config_manager) == POINTER_DYNAMIC) delete config_manager;
    if(CheckPointer(token_manager) == POINTER_DYNAMIC) delete token_manager;
    if(CheckPointer(data_collector) == POINTER_DYNAMIC) delete data_collector;
    if(CheckPointer(http_service) == POINTER_DYNAMIC) delete http_service;
}

/**
 * @brief Starts the session with the server.
 * @return true on success.
 */
bool CSDK_Context::start()
{
    if(CheckPointer(session_manager) == POINTER_INVALID) return false;
    return session_manager.start_session();
}

/**
 * @brief Main tick handler for the SDK. Must be called from the EA's OnTimer().
 */
void CSDK_Context::on_timer()
{
    if(CheckPointer(session_manager) == POINTER_INVALID || !session_manager.is_session_active())
        return;
        
    // 1. Token Refresh Logic
    if(token_manager.should_refresh_token())
    {
        session_manager.refresh_token();
    }
    
    // 2. Heartbeat Logic
    if(CheckPointer(heartbeat_manager) != POINTER_INVALID && heartbeat_manager.is_time_to_send())
    {
        CJAVal* payload = heartbeat_manager.build_heartbeat_payload();
        if(CheckPointer(payload) != POINTER_INVALID)
        {
            string payload_str = payload.to_string();
            Chttp_Response* response = http_service.post("/heartbeat", token_manager.get_token(), payload_str);

            if(CheckPointer(response) != POINTER_INVALID && response.code == 200)
            {
                heartbeat_manager.process_heartbeat_response(response.json_body);
            }
            // Simplified error handling for now
            if(response != NULL) delete response;
        }
    }
}

/**
 * @brief Terminates the session gracefully.
 */
void CSDK_Context::terminate(string reason)
{
    if(CheckPointer(session_manager) != POINTER_INVALID && session_manager.is_session_active())
    {
        Cfinal_Stats* stats = new Cfinal_Stats();
        // Developer is responsible for populating stats.
        session_manager.end_session(reason, stats);
        delete stats;
    }
}

#endif
//+------------------------------------------------------------------+
