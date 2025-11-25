//+------------------------------------------------------------------+
//|                                                CSDK_Context.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSDK_CONTEXT_MQH
#define CSDK_CONTEXT_MQH

#include <Object.mqh>
#include "CSDK_Options.mqh"
#include "CSDK_Constants.mqh"
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
 *
 * ## Customer-Provided Parameters
 * The following parameters are provided by the customer (end user), not the robot programmer:
 * - **api_key**: Robot API key obtained from TheMarketRobo platform
 * - **magic_number**: MT5 magic number to identify trades from this robot
 *
 * ## Programmer-Provided Parameters
 * The following are defined by the robot programmer:
 * - **robot_version_uuid**: Unique identifier for this robot version
 * - **Irobot_Config**: Configuration class with schema definition
 *
 * ## SDK Configuration (Hardcoded)
 * - **API Base URL**: Uses SDK_API_BASE_URL constant (staging environment)
 *
 * ## Feature Configuration
 * The SDK supports optional features that can be enabled/disabled:
 * - **Config change requests**: Server-initiated configuration changes
 * - **Symbol change requests**: Server-initiated symbol activation changes
 * - **Token refresh**: Proactive JWT token refresh before expiration
 *
 * ## Components
 * - session_manager: Manages session lifecycle (/start, /end, /refresh)
 * - heartbeat_manager: Manages periodic heartbeat communication
 * - token_manager: Manages JWT token storage and proactive refresh
 * - config_manager: Manages robot configuration changes (optional)
 * - symbol_manager: Manages symbol activation changes (optional)
 * - http_service: HTTP client for API communication
 * - data_collector: Collects static and dynamic data from MQL5
 */
class CSDK_Context : public CObject
{
private:
    CSDK_Options* m_options;  // SDK configuration options

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
    /**
     * @brief Creates the SDK context.
     * @param api_key Customer-provided API key from TheMarketRobo platform.
     * @param robot_version_uuid Programmer-defined robot version UUID.
     * @param magic_number Customer-provided MT5 magic number for trade identification.
     * @param config Programmer-defined configuration class implementing Irobot_Config.
     */
    CSDK_Context(string api_key, string robot_version_uuid, long magic_number, Irobot_Config* config);
    ~CSDK_Context();

    bool start();
    void on_timer();
    void terminate(string reason);
    
    // ===========================================================================
    // FEATURE CONFIGURATION
    // ===========================================================================
    
    // Token Refresh Configuration
    void set_token_refresh_threshold_seconds(int seconds);
    int  get_token_refresh_threshold_seconds() const;
    
    // Config Change Requests (optional feature)
    void set_enable_config_change_requests(bool enable);
    bool is_config_change_requests_enabled() const;
    
    // Symbol Change Requests (optional feature)
    void set_enable_symbol_change_requests(bool enable);
    bool is_symbol_change_requests_enabled() const;
    
    // Get options object for advanced configuration
    CSDK_Options* get_options() const { return m_options; }
    
    // Print current configuration
    void print_configuration() const;
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
CSDK_Context::CSDK_Context(string api_key, string robot_version_uuid, long magic_number, Irobot_Config* config)
{
    // Initialize all pointers to NULL
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

    // Store developer interfaces
    robot_config = config;
    
    // Create options container first
    m_options = new CSDK_Options();
    if(CheckPointer(m_options) == POINTER_INVALID) { Print("SDK Error: Failed to create CSDK_Options"); return; }

    // Create services first (lowest level dependencies)
    // HTTP service uses SDK_API_BASE_URL constant automatically
    http_service = new Chttp_Service();
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
    if(CheckPointer(m_options) == POINTER_DYNAMIC) delete m_options;
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

/**
 * @brief Sets the token refresh threshold in seconds.
 * @param seconds Number of seconds before expiration to trigger proactive refresh.
 * @note Default is 300 seconds (5 minutes). Minimum is 60 seconds, maximum is 3600 seconds.
 *       Call this BEFORE calling start() for the setting to take effect.
 */
void CSDK_Context::set_token_refresh_threshold_seconds(int seconds)
{
    if(CheckPointer(token_manager) != POINTER_INVALID)
    {
        token_manager.set_refresh_threshold_seconds(seconds);
    }
}

/**
 * @brief Gets the current token refresh threshold in seconds.
 * @return Number of seconds before expiration when token refresh is triggered.
 */
int CSDK_Context::get_token_refresh_threshold_seconds() const
{
    if(CheckPointer(token_manager) != POINTER_INVALID)
    {
        return token_manager.get_refresh_threshold_seconds();
    }
    return 300; // Default value
}

/**
 * @brief Enables or disables configuration change request handling.
 * @param enable When false, SDK ignores config change requests from server
 *               and doesn't send config_change_results in heartbeats.
 * @note Call this BEFORE start() for the setting to take effect on session start.
 */
void CSDK_Context::set_enable_config_change_requests(bool enable)
{
    if(CheckPointer(m_options) != POINTER_INVALID)
    {
        m_options.set_enable_config_change_requests(enable);
    }
    
    if(CheckPointer(config_manager) != POINTER_INVALID)
    {
        config_manager.set_enabled(enable);
    }
}

/**
 * @brief Checks if configuration change request handling is enabled.
 * @return true if enabled, false otherwise.
 */
bool CSDK_Context::is_config_change_requests_enabled() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
    {
        return m_options.is_config_change_requests_enabled();
    }
    return true; // Default
}

/**
 * @brief Enables or disables symbol change request handling.
 * @param enable When false, SDK ignores symbol change requests from server
 *               and doesn't send symbols_change_results in heartbeats.
 * @note Call this BEFORE start() for the setting to take effect on session start.
 */
void CSDK_Context::set_enable_symbol_change_requests(bool enable)
{
    if(CheckPointer(m_options) != POINTER_INVALID)
    {
        m_options.set_enable_symbol_change_requests(enable);
    }
    
    if(CheckPointer(symbol_manager) != POINTER_INVALID)
    {
        symbol_manager.set_enabled(enable);
    }
}

/**
 * @brief Checks if symbol change request handling is enabled.
 * @return true if enabled, false otherwise.
 */
bool CSDK_Context::is_symbol_change_requests_enabled() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
    {
        return m_options.is_symbol_change_requests_enabled();
    }
    return true; // Default
}

/**
 * @brief Prints the current SDK configuration to the terminal.
 */
void CSDK_Context::print_configuration() const
{
    if(CheckPointer(m_options) != POINTER_INVALID)
    {
        m_options.print_options();
    }
}

#endif
//+------------------------------------------------------------------+
