//+------------------------------------------------------------------+
//|                                                 CSDK_Options.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSDK_OPTIONS_MQH
#define CSDK_OPTIONS_MQH

/**
 * @class CSDK_Options
 * @brief Configuration options for SDK features and behavior.
 *
 * This class follows the Single Responsibility Principle by encapsulating
 * all SDK configuration options in a single, cohesive structure.
 *
 * ## Feature Toggles
 * - **enable_config_change_requests**: When true (default), the SDK processes
 *   configuration change requests from the server and sends results in heartbeats.
 * - **enable_symbol_change_requests**: When true (default), the SDK processes
 *   symbol activation change requests from the server.
 *
 * ## Token Refresh
 * - **token_refresh_threshold_seconds**: Number of seconds before token expiration
 *   to trigger proactive refresh. Default is 300 seconds (5 minutes).
 *
 * ## Usage
 * ```cpp
 * CSDK_Options options;
 * options.set_enable_config_change_requests(false);  // Disable config changes
 * options.set_enable_symbol_change_requests(false);  // Disable symbol changes
 * options.set_token_refresh_threshold_seconds(600);  // Refresh 10 min before expiry
 * ```
 */
class CSDK_Options
{
private:
    // Feature toggles
    bool m_enable_config_change_requests;
    bool m_enable_symbol_change_requests;
    
    // Token refresh settings
    int  m_token_refresh_threshold_seconds;
    
    // Validation bounds
    static const int MIN_REFRESH_THRESHOLD = 60;      // 1 minute
    static const int MAX_REFRESH_THRESHOLD = 3600;    // 1 hour
    static const int DEFAULT_REFRESH_THRESHOLD = 300; // 5 minutes

public:
    CSDK_Options();
    ~CSDK_Options();
    
    // ===========================================================================
    // CONFIG CHANGE REQUESTS
    // ===========================================================================
    
    /**
     * @brief Enables or disables configuration change request handling.
     * @param enable When false, SDK ignores config change requests from server
     *               and doesn't send config_change_results in heartbeats.
     */
    void set_enable_config_change_requests(bool enable);
    
    /**
     * @brief Checks if configuration change request handling is enabled.
     * @return true if enabled, false otherwise.
     */
    bool is_config_change_requests_enabled() const { return m_enable_config_change_requests; }
    
    // ===========================================================================
    // SYMBOL CHANGE REQUESTS
    // ===========================================================================
    
    /**
     * @brief Enables or disables symbol change request handling.
     * @param enable When false, SDK ignores symbol change requests from server
     *               and doesn't send symbols_change_results in heartbeats.
     */
    void set_enable_symbol_change_requests(bool enable);
    
    /**
     * @brief Checks if symbol change request handling is enabled.
     * @return true if enabled, false otherwise.
     */
    bool is_symbol_change_requests_enabled() const { return m_enable_symbol_change_requests; }
    
    // ===========================================================================
    // TOKEN REFRESH
    // ===========================================================================
    
    /**
     * @brief Sets the token refresh threshold in seconds.
     * @param seconds Number of seconds before expiration to trigger refresh.
     * @note Clamped to range [60, 3600]. Default is 300 (5 minutes).
     */
    void set_token_refresh_threshold_seconds(int seconds);
    
    /**
     * @brief Gets the current token refresh threshold in seconds.
     * @return Number of seconds before expiration when refresh is triggered.
     */
    int get_token_refresh_threshold_seconds() const { return m_token_refresh_threshold_seconds; }
    
    // ===========================================================================
    // UTILITY
    // ===========================================================================
    
    /**
     * @brief Creates a copy of these options.
     * @return A new CSDK_Options instance with the same settings.
     */
    CSDK_Options* clone() const;
    
    /**
     * @brief Logs the current options to the terminal.
     */
    void print_options() const;
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
CSDK_Options::CSDK_Options()
{
    // Default: all features enabled
    m_enable_config_change_requests = true;
    m_enable_symbol_change_requests = true;
    m_token_refresh_threshold_seconds = DEFAULT_REFRESH_THRESHOLD;
}

CSDK_Options::~CSDK_Options()
{
}

void CSDK_Options::set_enable_config_change_requests(bool enable)
{
    m_enable_config_change_requests = enable;
    if(!enable)
    {
        Print("SDK Options: Configuration change requests DISABLED. ",
              "Server config change requests will be ignored.");
    }
}

void CSDK_Options::set_enable_symbol_change_requests(bool enable)
{
    m_enable_symbol_change_requests = enable;
    if(!enable)
    {
        Print("SDK Options: Symbol change requests DISABLED. ",
              "Server symbol change requests will be ignored.");
    }
}

void CSDK_Options::set_token_refresh_threshold_seconds(int seconds)
{
    // Clamp to valid range
    if(seconds < MIN_REFRESH_THRESHOLD)
    {
        Print("SDK Options: Token refresh threshold too low. ",
              "Setting to minimum: ", MIN_REFRESH_THRESHOLD, " seconds.");
        seconds = MIN_REFRESH_THRESHOLD;
    }
    else if(seconds > MAX_REFRESH_THRESHOLD)
    {
        Print("SDK Options: Token refresh threshold too high. ",
              "Setting to maximum: ", MAX_REFRESH_THRESHOLD, " seconds.");
        seconds = MAX_REFRESH_THRESHOLD;
    }
    
    m_token_refresh_threshold_seconds = seconds;
}

CSDK_Options* CSDK_Options::clone() const
{
    CSDK_Options* copy = new CSDK_Options();
    if(copy != NULL)
    {
        copy.m_enable_config_change_requests = m_enable_config_change_requests;
        copy.m_enable_symbol_change_requests = m_enable_symbol_change_requests;
        copy.m_token_refresh_threshold_seconds = m_token_refresh_threshold_seconds;
    }
    return copy;
}

void CSDK_Options::print_options() const
{
    Print("=== SDK Options ===");
    Print("  Config change requests: ", m_enable_config_change_requests ? "ENABLED" : "DISABLED");
    Print("  Symbol change requests: ", m_enable_symbol_change_requests ? "ENABLED" : "DISABLED");
    Print("  Token refresh threshold: ", m_token_refresh_threshold_seconds, " seconds");
    Print("===================");
}

#endif
//+------------------------------------------------------------------+

