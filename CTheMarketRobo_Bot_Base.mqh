//+------------------------------------------------------------------+
//|                                     CTheMarketRobo_Bot_Base.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"

#ifndef CTHEMARKETROBO_BOT_BASE_MQH
#define CTHEMARKETROBO_BOT_BASE_MQH

#include "Core/CSDK_Context.mqh"
#include "Core/CSDK_Constants.mqh"
#include "Utils/CSDK_Events.mqh"
#include "Interfaces/Irobot_Config.mqh"

//+------------------------------------------------------------------+
//| CTheMarketRobo_Bot_Base Class                                    |
//+------------------------------------------------------------------+
/**
 * @class CTheMarketRobo_Bot_Base
 * @brief An abstract base class for creating trading robots using TheMarketRobo SDK.
 *
 * This class handles the common SDK lifecycle events, authentication, and
 * session management behind the scenes. Developers should inherit from this
 * class to implement their specific trading logic.
 *
 * ## Parameter Categories
 *
 * ### Programmer-Defined (Hardcoded in Robot)
 * - **robot_version_uuid**: Unique identifier for this robot version (set via constructor)
 * - **Irobot_Config**: Configuration class with schema definition
 *
 * ### Customer-Provided (Input Parameters)
 * - **api_key**: Robot API key from TheMarketRobo platform (input parameter)
 * - **magic_number**: MT5 magic number to identify trades (input parameter)
 *
 * ### SDK Constants (Hardcoded in SDK)
 * - **base_url**: API endpoint (SDK_API_BASE_URL constant)
 *
 * ## Feature Configuration
 * The SDK supports optional features that can be enabled/disabled BEFORE on_init():
 * - **Config change requests**: Server-initiated configuration changes (default: enabled)
 * - **Symbol change requests**: Server-initiated symbol activation changes (default: enabled)
 * - **Token refresh threshold**: Seconds before expiration to refresh token (default: 300)
 *
 * ## Usage Example
 * ```cpp
 * // In your robot's header file
 * input string InpApiKey = "";           // API Key (Customer provides)
 * input long   InpMagicNumber = 12345;   // Magic Number (Customer provides)
 * 
 * class CMyRobotConfig : public Irobot_Config { ... };
 * 
 * class CMyRobot : public CTheMarketRobo_Bot_Base
 * {
 * public:
 *     // Programmer sets robot_version_uuid in constructor
 *     CMyRobot() : CTheMarketRobo_Bot_Base(
 *         "550e8400-e29b-41d4-a716-446655440000",  // robot_version_uuid (programmer-defined)
 *         new CMyRobotConfig()                      // config class (programmer-defined)
 *     ) {}
 *     
 *     virtual void on_tick() override { ... }
 *     virtual void on_config_changed(string event_json) override { ... }
 *     virtual void on_symbol_changed(string event_json) override { ... }
 * };
 * 
 * CMyRobot* robot = NULL;
 * 
 * int OnInit()
 * {
 *     robot = new CMyRobot();
 *     
 *     // Optional: Configure SDK features before init
 *     robot.set_enable_config_change_requests(true);
 *     
 *     // Initialize with customer-provided inputs
 *     return robot.on_init(InpApiKey, InpMagicNumber);
 * }
 * ```
 */
class CTheMarketRobo_Bot_Base
{
protected:
    CSDK_Context*   m_sdk_context;
    Irobot_Config*  m_robot_config;
    string          m_robot_version_uuid;  // Programmer-defined robot version
    
    // Configurable options (stored for deferred application)
    int             m_token_refresh_threshold_seconds;
    bool            m_enable_config_change_requests;
    bool            m_enable_symbol_change_requests;

public:
    /**
     * @brief Constructor for robot base class.
     * @param robot_version_uuid Programmer-defined unique identifier for this robot version.
     *                           This is a UUID assigned by TheMarketRobo platform when registering the robot.
     * @param robot_config Programmer-defined configuration class implementing Irobot_Config.
     */
    CTheMarketRobo_Bot_Base(string robot_version_uuid, Irobot_Config* robot_config);
    ~CTheMarketRobo_Bot_Base();

    //--- SDK Lifecycle Methods (to be called from MQL5 entry points)
    /**
     * @brief Initializes the SDK and starts the session.
     * @param api_key Customer-provided API key from TheMarketRobo platform.
     * @param magic_number Customer-provided MT5 magic number for trade identification.
     * @return INIT_SUCCEEDED on success, INIT_FAILED on failure.
     */
    virtual int     on_init(string api_key, long magic_number);
    virtual void    on_deinit(const int reason);
    virtual void    on_timer();
    virtual void    on_chart_event(const int id, const long &lparam, const double &dparam, const string &sparam);

    //--- Abstract Methods for Robot Implementation
    virtual void    on_tick() = 0;
    virtual void    on_config_changed(string event_json) = 0;
    virtual void    on_symbol_changed(string event_json) = 0;
    
    //--- SDK Feature Configuration (call BEFORE on_init())
    void            set_token_refresh_threshold(int seconds);
    int             get_token_refresh_threshold() const;
    
    void            set_enable_config_change_requests(bool enable);
    bool            is_config_change_requests_enabled() const;
    
    void            set_enable_symbol_change_requests(bool enable);
    bool            is_symbol_change_requests_enabled() const;
    
    void            print_sdk_configuration() const;
    
    //--- Getters
    string          get_robot_version_uuid() const { return m_robot_version_uuid; }

protected:
    //--- Internal Event Handlers
    void            handle_termination_event(string event_json);
    void            handle_token_refresh_event(string event_json);
};

//+------------------------------------------------------------------+
//| CTheMarketRobo_Bot_Base Implementation                           |
//+------------------------------------------------------------------+
CTheMarketRobo_Bot_Base::CTheMarketRobo_Bot_Base(string robot_version_uuid, Irobot_Config* robot_config)
{
    m_sdk_context = NULL;
    m_robot_config = robot_config;
    m_robot_version_uuid = robot_version_uuid;
    
    // Default feature configuration
    m_token_refresh_threshold_seconds = SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD;
    m_enable_config_change_requests = true;   // Enabled by default
    m_enable_symbol_change_requests = true;   // Enabled by default
    
    Print("SDK Info: Robot Version UUID = ", m_robot_version_uuid);
}

CTheMarketRobo_Bot_Base::~CTheMarketRobo_Bot_Base()
{
    if(CheckPointer(m_sdk_context) == POINTER_DYNAMIC)
        delete m_sdk_context;
}

/**
 * @brief Sets the token refresh threshold in seconds.
 * @param seconds Number of seconds before token expiration to trigger proactive refresh.
 * @note Default is 300 seconds (5 minutes). Call this BEFORE on_init() for best results.
 *       Minimum value is 60 seconds, maximum is 3600 seconds.
 */
void CTheMarketRobo_Bot_Base::set_token_refresh_threshold(int seconds)
{
    m_token_refresh_threshold_seconds = seconds;
    
    // If context already exists, update it directly
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        m_sdk_context.set_token_refresh_threshold_seconds(seconds);
    }
}

/**
 * @brief Gets the current token refresh threshold in seconds.
 * @return Number of seconds before expiration when token refresh is triggered.
 */
int CTheMarketRobo_Bot_Base::get_token_refresh_threshold() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        return m_sdk_context.get_token_refresh_threshold_seconds();
    }
    return m_token_refresh_threshold_seconds;
}

/**
 * @brief Enables or disables configuration change request handling.
 * @param enable When false, SDK ignores config change requests from server
 *               and doesn't send config_change_results in heartbeats.
 * @note Call this BEFORE on_init() for best results.
 */
void CTheMarketRobo_Bot_Base::set_enable_config_change_requests(bool enable)
{
    m_enable_config_change_requests = enable;
    
    // If context already exists, update it directly
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        m_sdk_context.set_enable_config_change_requests(enable);
    }
}

/**
 * @brief Checks if configuration change request handling is enabled.
 * @return true if enabled, false otherwise.
 */
bool CTheMarketRobo_Bot_Base::is_config_change_requests_enabled() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        return m_sdk_context.is_config_change_requests_enabled();
    }
    return m_enable_config_change_requests;
}

/**
 * @brief Enables or disables symbol change request handling.
 * @param enable When false, SDK ignores symbol change requests from server
 *               and doesn't send symbols_change_results in heartbeats.
 * @note Call this BEFORE on_init() for best results.
 */
void CTheMarketRobo_Bot_Base::set_enable_symbol_change_requests(bool enable)
{
    m_enable_symbol_change_requests = enable;
    
    // If context already exists, update it directly
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        m_sdk_context.set_enable_symbol_change_requests(enable);
    }
}

/**
 * @brief Checks if symbol change request handling is enabled.
 * @return true if enabled, false otherwise.
 */
bool CTheMarketRobo_Bot_Base::is_symbol_change_requests_enabled() const
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        return m_sdk_context.is_symbol_change_requests_enabled();
    }
    return m_enable_symbol_change_requests;
}

/**
 * @brief Prints the current SDK configuration to the terminal.
 */
void CTheMarketRobo_Bot_Base::print_sdk_configuration() const
{
    Print("=== SDK Configuration ===");
    Print("  Robot Version UUID: ", m_robot_version_uuid);
    Print("  API Base URL: ", SDK_API_BASE_URL);
    
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        m_sdk_context.print_configuration();
    }
    else
    {
        Print("  Token refresh threshold: ", m_token_refresh_threshold_seconds, " seconds");
        Print("  Config change requests: ", m_enable_config_change_requests ? "ENABLED" : "DISABLED");
        Print("  Symbol change requests: ", m_enable_symbol_change_requests ? "ENABLED" : "DISABLED");
    }
    Print("=========================");
}

/**
 * @brief Initializes the SDK and starts the session.
 * @param api_key Customer-provided API key from TheMarketRobo platform.
 * @param magic_number Customer-provided MT5 magic number for trade identification.
 * @return INIT_SUCCEEDED on success, INIT_FAILED on failure.
 */
int CTheMarketRobo_Bot_Base::on_init(string api_key, long magic_number)
{
    // Validate programmer-provided robot_version_uuid
    if(m_robot_version_uuid == "" || StringLen(m_robot_version_uuid) != SDK_UUID_LENGTH)
    {
        Print("SDK Error: Invalid robot_version_uuid. Must be a valid UUID (36 characters).");
        return INIT_FAILED;
    }
    
    // Validate customer-provided api_key
    if(api_key == "")
    {
        Print("SDK Error: API Key is required. Please provide a valid API key.");
        Alert("TheMarketRobo SDK: API Key is required!");
        return INIT_FAILED;
    }
    
    if(CheckPointer(m_robot_config) == POINTER_INVALID)
    {
        Print("SDK Error: Robot configuration is not valid.");
        return INIT_FAILED;
    }
    
    Print("SDK Info: Initializing with Magic Number = ", magic_number);

    m_sdk_context = new CSDK_Context(api_key, m_robot_version_uuid, magic_number, m_robot_config);
    if(CheckPointer(m_sdk_context) == POINTER_INVALID)
    {
        Print("SDK Error: Failed to create SDK Context.");
        return INIT_FAILED;
    }
    
    // Apply all deferred configuration settings
    m_sdk_context.set_token_refresh_threshold_seconds(m_token_refresh_threshold_seconds);
    m_sdk_context.set_enable_config_change_requests(m_enable_config_change_requests);
    m_sdk_context.set_enable_symbol_change_requests(m_enable_symbol_change_requests);
    
    // Log the applied configuration
    print_sdk_configuration();

    if(!m_sdk_context.start())
    {
        string error_msg = "SDK Error: Failed to start SDK session. Check API Key and connection. The robot will be removed.";
        Print(error_msg);
        Alert(error_msg);
        delete m_sdk_context;
        m_sdk_context = NULL;
        ExpertRemove();
        return INIT_FAILED;
    }

    Print("SDK session started successfully!");
    EventSetTimer(1);
    return INIT_SUCCEEDED;
}

void CTheMarketRobo_Bot_Base::on_deinit(const int reason)
{
    Print("Deinitializing SDK...");
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        m_sdk_context.terminate("EA Shutdown: reason " + (string)reason);
    }
    EventKillTimer();
}

void CTheMarketRobo_Bot_Base::on_timer()
{
    if(CheckPointer(m_sdk_context) != POINTER_INVALID)
    {
        m_sdk_context.on_timer();
    }
}

void CTheMarketRobo_Bot_Base::on_chart_event(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    switch(id)
    {
        case SDK_EVENT_CONFIG_CHANGED:
            on_config_changed(sparam);
            break;
        case SDK_EVENT_SYMBOL_CHANGED:
            on_symbol_changed(sparam);
            break;
        case SDK_EVENT_TERMINATION_START:
        case SDK_EVENT_TERMINATION_END:
            handle_termination_event(sparam);
            break;
        case SDK_EVENT_TOKEN_REFRESH:
            handle_token_refresh_event(sparam);
            break;
    }
}

void CTheMarketRobo_Bot_Base::handle_termination_event(string event_json)
{
    CJAVal event_data;
    if(!event_data.parse(event_json)) return;

    string reason = event_data["reason"].get_string();
    string message = "Session terminated by server. Reason: " + reason + ". Expert will be removed.";
    
    Print(message);
    Alert(message);
    ExpertRemove();
}

void CTheMarketRobo_Bot_Base::handle_token_refresh_event(string event_json)
{
    CJAVal event_data;
    if(!event_data.parse(event_json)) return;

    bool success = event_data["success"].get_bool();
    if(!success)
    {
        string message = "SDK critical error: Failed to refresh authentication token. Expert will be removed to prevent unauthorized trading.";
        Print(message);
        Alert(message);
        ExpertRemove();
    }
    else
    {
        Print("SDK Info: Authentication token refreshed successfully.");
    }
}

#endif // CTHEMARKETROBO_BOT_BASE_MQH
