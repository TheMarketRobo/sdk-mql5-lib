//+------------------------------------------------------------------+
//|                                                  CSDKOptions.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CSDK_OPTIONS_MQH
#define CSDK_OPTIONS_MQH

#include "CSDKConstants.mqh"

//--- Constants for token refresh thresholds
#define SDK_MIN_REFRESH_THRESHOLD  60
#define SDK_MAX_REFRESH_THRESHOLD  3600
#define SDK_DEFAULT_REFRESH_THRESHOLD 300

/**
 * @class CSDKOptions
 * @brief Configuration options for SDK features and behavior.
 *
 * Encapsulates all SDK configuration including product type, feature toggles,
 * and token management settings.
 *
 * Key rule: config and symbol change requests are always disabled for
 * PRODUCT_TYPE_INDICATOR and cannot be re-enabled.
 */
class CSDKOptions
{
private:
    ENUM_SDK_PRODUCT_TYPE m_product_type;
    bool m_enable_config_change_requests;
    bool m_enable_symbol_change_requests;
    int  m_token_refresh_threshold_seconds;

public:
    CSDKOptions();
    ~CSDKOptions();
    
    void set_product_type(ENUM_SDK_PRODUCT_TYPE type);
    ENUM_SDK_PRODUCT_TYPE get_product_type() const;
    bool is_indicator() const;
    bool is_robot() const;
    
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
    m_product_type = PRODUCT_TYPE_ROBOT;
    m_enable_config_change_requests = true;
    m_enable_symbol_change_requests = true;
    m_token_refresh_threshold_seconds = SDK_DEFAULT_REFRESH_THRESHOLD;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSDKOptions::~CSDKOptions()
{
}

//+------------------------------------------------------------------+
//| Product type                                                      |
//+------------------------------------------------------------------+
void CSDKOptions::set_product_type(ENUM_SDK_PRODUCT_TYPE type)
{
    m_product_type = type;
    if(type == PRODUCT_TYPE_INDICATOR)
    {
        // Indicators never support remote config or symbol changes — enforce immediately.
        m_enable_config_change_requests = false;
        m_enable_symbol_change_requests = false;
        Print("SDK Options: Product type set to INDICATOR. ",
              "Config and symbol change requests are permanently disabled.");
    }
}

ENUM_SDK_PRODUCT_TYPE CSDKOptions::get_product_type() const
{
    return m_product_type;
}

bool CSDKOptions::is_indicator() const
{
    return m_product_type == PRODUCT_TYPE_INDICATOR;
}

bool CSDKOptions::is_robot() const
{
    return m_product_type == PRODUCT_TYPE_ROBOT;
}

//+------------------------------------------------------------------+
//| Config change requests toggle                                     |
//+------------------------------------------------------------------+
void CSDKOptions::set_enable_config_change_requests(bool enable)
{
    if(m_product_type == PRODUCT_TYPE_INDICATOR)
    {
        Print("SDK Warning: Config change requests cannot be enabled for INDICATOR product type. Ignored.");
        return;
    }
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
    if(m_product_type == PRODUCT_TYPE_INDICATOR)
    {
        Print("SDK Warning: Symbol change requests cannot be enabled for INDICATOR product type. Ignored.");
        return;
    }
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
    if(seconds < SDK_MIN_REFRESH_THRESHOLD)
    {
        Print("SDK Options: Token refresh threshold too low. ",
              "Setting to minimum: ", SDK_MIN_REFRESH_THRESHOLD, " seconds.");
        seconds = SDK_MIN_REFRESH_THRESHOLD;
    }
    else if(seconds > SDK_MAX_REFRESH_THRESHOLD)
    {
        Print("SDK Options: Token refresh threshold too high. ",
              "Setting to maximum: ", SDK_MAX_REFRESH_THRESHOLD, " seconds.");
        seconds = SDK_MAX_REFRESH_THRESHOLD;
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
        copy.m_product_type = m_product_type;
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
    Print("  Product type: ", (m_product_type == PRODUCT_TYPE_INDICATOR) ? "INDICATOR" : "ROBOT");
    Print("  Config change requests: ", m_enable_config_change_requests ? "ENABLED" : "DISABLED");
    Print("  Symbol change requests: ", m_enable_symbol_change_requests ? "ENABLED" : "DISABLED");
    Print("  Token refresh threshold: ", m_token_refresh_threshold_seconds, " seconds");
    Print("===================");
}

#endif
//+------------------------------------------------------------------+

