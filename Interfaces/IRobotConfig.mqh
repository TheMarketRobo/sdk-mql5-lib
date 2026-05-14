//+------------------------------------------------------------------+
//|                                                 IRobotConfig.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef IROBOT_CONFIG_MQH
#define IROBOT_CONFIG_MQH

#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"
#property strict

#include "../Services/Json.mqh"
#include "../Models/CConfigSchema.mqh"

/**
 * @class IRobotConfig
 * @brief Abstract base class for a robot's configuration with schema support.
 *
 * Developers must inherit from this class to define their robot's specific
 * configuration parameters.
 */
class ITMKR_RobotConfig
{
protected:
    CTMKR_ConfigSchema* m_schema;

public:
    ITMKR_RobotConfig();
    virtual ~ITMKR_RobotConfig();
    
    //==========================================================================
    // SCHEMA DEFINITION (Programmer must implement)
    //==========================================================================
    
    virtual void define_schema() = 0;
    virtual void apply_defaults() = 0;
    
    //==========================================================================
    // CONFIGURATION VALIDATION (SDK uses these)
    //==========================================================================
    
    virtual bool validate_field(string field_name, string new_value, string &tmkr_reason);
    virtual string to_json() = 0;
    virtual bool update_from_json(const CTMKR_JAVal &config_json) = 0;
    virtual bool update_field(string field_name, string new_value) = 0;
    virtual string get_field_as_string(string field_name) = 0;
    virtual void get_field_names(string &field_names[]);
    
    //==========================================================================
    // SCHEMA ACCESS
    //==========================================================================
    
    CTMKR_ConfigSchema* get_schema();
    string get_schema_json();
    CTMKR_ConfigField* get_field_definition(string tmkr_key);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
ITMKR_RobotConfig::IRobotConfig()
{
    m_schema = new CTMKR_ConfigSchema();
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
ITMKR_RobotConfig::~ITMKR_RobotConfig()
{
    if(CheckPointer(m_schema) == POINTER_DYNAMIC)
        delete m_schema;
}

//+------------------------------------------------------------------+
//| Get schema                                                        |
//+------------------------------------------------------------------+
CTMKR_ConfigSchema* ITMKR_RobotConfig::get_schema()
{
    return m_schema;
}

//+------------------------------------------------------------------+
//| Validate field using schema                                       |
//+------------------------------------------------------------------+
bool ITMKR_RobotConfig::validate_field(string field_name, string new_value, string &tmkr_reason)
{
    if(CheckPointer(m_schema) == POINTER_INVALID)
    {
        tmkr_reason = "Schema not initialized";
        return false;
    }
    
    CTMKR_ConfigField* field = m_schema.get_field(field_name);
    if(field == NULL)
    {
        tmkr_reason = "Field not found: " + field_name;
        return false;
    }
    
    switch(field.m_type)
    {
        case TMKR_CONFIG_FIELD_INTEGER:
        {
            int tmkr_value = (int)StringToInteger(new_value);
            return field.validate_value(tmkr_value, tmkr_reason);
        }
        case TMKR_CONFIG_FIELD_DECIMAL:
        {
            double tmkr_value = StringToDouble(new_value);
            return field.validate_value(tmkr_value, tmkr_reason);
        }
        case TMKR_CONFIG_FIELD_BOOLEAN:
        {
            bool tmkr_value = (new_value == "true" || new_value == "1");
            return field.validate_value(tmkr_value, tmkr_reason);
        }
        case TMKR_CONFIG_FIELD_RADIO:
        {
            return field.validate_value(new_value, tmkr_reason);
        }
        case TMKR_CONFIG_FIELD_MULTIPLE:
        {
            return true;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get field names from schema                                       |
//+------------------------------------------------------------------+
void ITMKR_RobotConfig::get_field_names(string &field_names[])
{
    if(CheckPointer(m_schema) != POINTER_INVALID)
    {
        m_schema.get_field_keys(field_names);
    }
}

//+------------------------------------------------------------------+
//| Get schema as JSON                                                |
//+------------------------------------------------------------------+
string ITMKR_RobotConfig::get_schema_json()
{
    if(CheckPointer(m_schema) != POINTER_INVALID)
    {
        return m_schema.to_json_string();
    }
    return "{}";
}

//+------------------------------------------------------------------+
//| Get field definition                                              |
//+------------------------------------------------------------------+
CTMKR_ConfigField* ITMKR_RobotConfig::get_field_definition(string tmkr_key)
{
    if(CheckPointer(m_schema) != POINTER_INVALID)
    {
        return m_schema.get_field(tmkr_key);
    }
    return NULL;
}

#endif
//+------------------------------------------------------------------+

