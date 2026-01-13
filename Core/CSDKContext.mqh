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
#include "../Services/CHttpService.mqh"
#include "../Services/CDataCollectorService.mqh"
#include "../Interfaces/IRobotConfig.mqh"

/**
 * @class CSDKContext
 * @brief A service container for managing the lifecycle and dependencies of all SDK components.
 */
class CSDKContext : public CObject
{
private:
    CSDKOptions* m_options;

public:
    CSessionManager*       session_manager;
    CHeartbeatManager*     heartbeat_manager;
    CTokenManager*         token_manager;
    CConfigurationManager* config_manager;
    CSymbolManager*        symbol_manager;
    CHttpService*          http_service;
    CDataCollectorService* data_collector;
    IRobotConfig*          robot_config;

public:
    CSDKContext(string api_key, string robot_version_uuid, long magic_number, IRobotConfig* config);
    ~CSDKContext();

    bool start();
    void on_timer();
    void terminate(string reason);
    
    void set_token_refresh_threshold_seconds(int seconds);
    int  get_token_refresh_threshold_seconds() const;
    
    void set_enable_config_change_requests(bool enable);
    bool is_config_change_requests_enabled() const;
    
    void set_enable_symbol_change_requests(bool enable);
    bool is_symbol_change_requests_enabled() const;
    
    CSDKOptions* get_options() const;
    void print_configuration() const;
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSDKContext::CSDKContext(string api_key, string robot_version_uuid, long magic_number, IRobotConfig* config)
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

    Print("SDK Info: TheMarketRobo SDK v", SDK_VERSION);
    Print("SDK Info: API Base URL = ", SDK_API_BASE_URL);

    robot_config = config;
    
    m_options = new CSDKOptions();
    if(CheckPointer(m_options) == POINTER_INVALID) { Print("SDK Error: Failed to create CSDKOptions"); return; }

    http_service = new CHttpService();
    if(CheckPointer(http_service) == POINTER_INVALID) { Print("SDK Error: Failed to create CHttpService"); return; }

    data_collector = new CDataCollectorService();
    if(CheckPointer(data_collector) == POINTER_INVALID) { Print("SDK Error: Failed to create CDataCollectorService"); return; }

    token_manager = new CTokenManager();
    if(CheckPointer(token_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CTokenManager"); return; }

    config_manager = new CConfigurationManager(robot_config);
    if(CheckPointer(config_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CConfigurationManager"); return; }

    symbol_manager = new CSymbolManager();
    if(CheckPointer(symbol_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CSymbolManager"); return; }
    
    session_manager = new CSessionManager(api_key, robot_version_uuid, magic_number, GetPointer(this));
    if(CheckPointer(session_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CSessionManager"); return; }

    heartbeat_manager = new CHeartbeatManager(GetPointer(this));
    if(CheckPointer(heartbeat_manager) == POINTER_INVALID) { Print("SDK Error: Failed to create CHeartbeatManager"); return; }
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSDKContext::~CSDKContext()
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
bool CSDKContext::start()
{
    if(CheckPointer(session_manager) == POINTER_INVALID) return false;
    return session_manager.start_session();
}

//+------------------------------------------------------------------+
//| On timer                                                          |
//+------------------------------------------------------------------+
void CSDKContext::on_timer()
{
    if(CheckPointer(session_manager) == POINTER_INVALID || !session_manager.is_session_active())
        return;
        
    if(token_manager.should_refresh_token())
    {
        session_manager.refresh_token();
    }
    
    if(CheckPointer(heartbeat_manager) != POINTER_INVALID && heartbeat_manager.is_time_to_send())
    {
        CJAVal* payload = heartbeat_manager.build_heartbeat_payload();
        if(CheckPointer(payload) != POINTER_INVALID)
        {
            string payload_str = payload.to_string();
            CHttpResponse* response = http_service.post("/robot/heartbeat", token_manager.get_token(), payload_str);

            if(CheckPointer(response) != POINTER_INVALID && response.code == 200)
            {
                heartbeat_manager.process_heartbeat_response(response.json_body);
            }
            if(response != NULL) delete response;
        }
    }
}

//+------------------------------------------------------------------+
//| Terminate session                                                 |
//+------------------------------------------------------------------+
void CSDKContext::terminate(string reason)
{
    if(CheckPointer(session_manager) != POINTER_INVALID && session_manager.is_session_active())
    {
        CFinalStats* stats = new CFinalStats();
        session_manager.end_session(reason, stats);
        delete stats;
    }
}

//+------------------------------------------------------------------+
//| Token refresh threshold                                           |
//+------------------------------------------------------------------+
void CSDKContext::set_token_refresh_threshold_seconds(int seconds)
{
    if(CheckPointer(token_manager) != POINTER_INVALID)
        token_manager.set_refresh_threshold_seconds(seconds);
}

int CSDKContext::get_token_refresh_threshold_seconds() const
{
    if(CheckPointer(token_manager) != POINTER_INVALID)
        return token_manager.get_refresh_threshold_seconds();
    return 300;
}

//+------------------------------------------------------------------+
//| Config change requests toggle                                     |
//+------------------------------------------------------------------+
void CSDKContext::set_enable_config_change_requests(bool enable)
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        m_options.set_enable_config_change_requests(enable);
    if(CheckPointer(config_manager) != POINTER_INVALID)
        config_manager.set_enabled(enable);
}

bool CSDKContext::is_config_change_requests_enabled() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        return m_options.is_config_change_requests_enabled();
    return true;
}

//+------------------------------------------------------------------+
//| Symbol change requests toggle                                     |
//+------------------------------------------------------------------+
void CSDKContext::set_enable_symbol_change_requests(bool enable)
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        m_options.set_enable_symbol_change_requests(enable);
    if(CheckPointer(symbol_manager) != POINTER_INVALID)
        symbol_manager.set_enabled(enable);
}

bool CSDKContext::is_symbol_change_requests_enabled() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        return m_options.is_symbol_change_requests_enabled();
    return true;
}

//+------------------------------------------------------------------+
//| Options access                                                    |
//+------------------------------------------------------------------+
CSDKOptions* CSDKContext::get_options() const
{
    return m_options;
}

//+------------------------------------------------------------------+
//| Print configuration                                               |
//+------------------------------------------------------------------+
void CSDKContext::print_configuration() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
        m_options.print_options();
}

#endif
//+------------------------------------------------------------------+

