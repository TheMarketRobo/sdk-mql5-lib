//+------------------------------------------------------------------+
//|                                                  CSDKOptions.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSDK_OPTIONS_MQH
#define CSDK_OPTIONS_MQH

/**
 * @class CSDKOptions
 * @brief Configuration options for SDK features and behavior.
 *
 * This class follows the Single Responsibility Principle by encapsulating
 * all SDK configuration options in a single, cohesive structure.
 */
class CSDKOptions
{
private:
    bool m_enable_config_change_requests;
    bool m_enable_symbol_change_requests;
    int  m_token_refresh_threshold_seconds;
    
    static const int MIN_REFRESH_THRESHOLD = 60;
    static const int MAX_REFRESH_THRESHOLD = 3600;
    static const int DEFAULT_REFRESH_THRESHOLD = 300;

public:
    CSDKOptions();
    ~CSDKOptions();
    
    void set_enable_config_change_requests(bool enable);
    bool is_config_change_requests_enabled() const;
    
    void set_enable_symbol_change_requests(bool enable);
    bool is_symbol_change_requests_enabled() const;
    
    void set_token_refresh_threshold_seconds(int seconds);
    int get_token_refresh_threshold_seconds() const;
    
    CSDKOptions* clone() const;
    void print_options() const;
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSDKOptions::CSDKOptions()
{
    m_enable_config_change_requests = true;
    m_enable_symbol_change_requests = true;
    m_token_refresh_threshold_seconds = DEFAULT_REFRESH_THRESHOLD;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSDKOptions::~CSDKOptions()
{
}

//+------------------------------------------------------------------+
//| Config change requests toggle                                     |
//+------------------------------------------------------------------+
void CSDKOptions::set_enable_config_change_requests(bool enable)
{
    m_enable_config_change_requests = enable;
    if(!enable)
    {
        Print("SDK Options: Configuration change requests DISABLED. ",
              "Server config change requests will be ignored.");
    }
}

bool CSDKOptions::is_config_change_requests_enabled() const
{
    return m_enable_config_change_requests;
}

//+------------------------------------------------------------------+
//| Symbol change requests toggle                                     |
//+------------------------------------------------------------------+
void CSDKOptions::set_enable_symbol_change_requests(bool enable)
{
    m_enable_symbol_change_requests = enable;
    if(!enable)
    {
        Print("SDK Options: Symbol change requests DISABLED. ",
              "Server symbol change requests will be ignored.");
    }
}

bool CSDKOptions::is_symbol_change_requests_enabled() const
{
    return m_enable_symbol_change_requests;
}

//+------------------------------------------------------------------+
//| Token refresh threshold                                           |
//+------------------------------------------------------------------+
void CSDKOptions::set_token_refresh_threshold_seconds(int seconds)
{
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

int CSDKOptions::get_token_refresh_threshold_seconds() const
{
    return m_token_refresh_threshold_seconds;
}

//+------------------------------------------------------------------+
//| Clone                                                             |
//+------------------------------------------------------------------+
CSDKOptions* CSDKOptions::clone() const
{
    CSDKOptions* copy = new CSDKOptions();
    if(copy != NULL)
    {
        copy.m_enable_config_change_requests = m_enable_config_change_requests;
        copy.m_enable_symbol_change_requests = m_enable_symbol_change_requests;
        copy.m_token_refresh_threshold_seconds = m_token_refresh_threshold_seconds;
    }
    return copy;
}

//+------------------------------------------------------------------+
//| Print options                                                     |
//+------------------------------------------------------------------+
void CSDKOptions::print_options() const
{
    Print("=== SDK Options ===");
    Print("  Config change requests: ", m_enable_config_change_requests ? "ENABLED" : "DISABLED");
    Print("  Symbol change requests: ", m_enable_symbol_change_requests ? "ENABLED" : "DISABLED");
    Print("  Token refresh threshold: ", m_token_refresh_threshold_seconds, " seconds");
    Print("===================");
}

#endif
//+------------------------------------------------------------------+

