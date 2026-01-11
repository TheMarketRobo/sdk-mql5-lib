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
class IRobotConfig
{
protected:
    CConfigSchema* m_schema;

public:
    IRobotConfig();
    virtual ~IRobotConfig();
    
    //==========================================================================
    // SCHEMA DEFINITION (Programmer must implement)
    //==========================================================================
    
    virtual void define_schema() = 0;
    virtual void apply_defaults() = 0;
    
    //==========================================================================
    // CONFIGURATION VALIDATION (SDK uses these)
    //==========================================================================
    
    virtual bool validate_field(string field_name, string new_value, string &reason);
    virtual string to_json() = 0;
    virtual bool update_from_json(const CJAVal &config_json) = 0;
    virtual bool update_field(string field_name, string new_value) = 0;
    virtual string get_field_as_string(string field_name) = 0;
    virtual void get_field_names(string &field_names[]);
    
    //==========================================================================
    // SCHEMA ACCESS
    //==========================================================================
    
    CConfigSchema* get_schema();
    string get_schema_json();
    CConfigField* get_field_definition(string key);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
IRobotConfig::IRobotConfig()
{
    m_schema = new CConfigSchema();
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
IRobotConfig::~IRobotConfig()
{
    if(CheckPointer(m_schema) == POINTER_DYNAMIC)
        delete m_schema;
}

//+------------------------------------------------------------------+
//| Get schema                                                        |
//+------------------------------------------------------------------+
CConfigSchema* IRobotConfig::get_schema()
{
    return m_schema;
}

//+------------------------------------------------------------------+
//| Validate field using schema                                       |
//+------------------------------------------------------------------+
bool IRobotConfig::validate_field(string field_name, string new_value, string &reason)
{
    if(CheckPointer(m_schema) == POINTER_INVALID)
    {
        reason = "Schema not initialized";
        return false;
    }
    
    CConfigField* field = m_schema.get_field(field_name);
    if(field == NULL)
    {
        reason = "Field not found: " + field_name;
        return false;
    }
    
    switch(field.m_type)
    {
        case CONFIG_FIELD_INTEGER:
        {
            int value = (int)StringToInteger(new_value);
            return field.validate_value(value, reason);
        }
        case CONFIG_FIELD_DECIMAL:
        {
            double value = StringToDouble(new_value);
            return field.validate_value(value, reason);
        }
        case CONFIG_FIELD_BOOLEAN:
        {
            bool value = (new_value == "true" || new_value == "1");
            return field.validate_value(value, reason);
        }
        case CONFIG_FIELD_RADIO:
        {
            return field.validate_value(new_value, reason);
        }
        case CONFIG_FIELD_MULTIPLE:
        {
            return true;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get field names from schema                                       |
//+------------------------------------------------------------------+
void IRobotConfig::get_field_names(string &field_names[])
{
    if(CheckPointer(m_schema) != POINTER_INVALID)
    {
        m_schema.get_field_keys(field_names);
    }
}

//+------------------------------------------------------------------+
//| Get schema as JSON                                                |
//+------------------------------------------------------------------+
string IRobotConfig::get_schema_json()
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
CConfigField* IRobotConfig::get_field_definition(string key)
{
    if(CheckPointer(m_schema) != POINTER_INVALID)
    {
        return m_schema.get_field(key);
    }
    return NULL;
}

#endif
//+------------------------------------------------------------------+

