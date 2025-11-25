//+------------------------------------------------------------------+
//|                                                CConfigSchema.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CCONFIG_SCHEMA_MQH
#define CCONFIG_SCHEMA_MQH

#include <Object.mqh>
#include <Arrays/ArrayObj.mqh>
#include "CConfigField.mqh"

/**
 * @class CConfigSchema
 * @brief Container for robot configuration schema definition.
 */
class CConfigSchema : public CObject
{
private:
    CArrayObj* m_fields;

public:
    CConfigSchema();
    ~CConfigSchema();
    
    void add_field(CConfigField* field);
    CConfigField* get_field(string key);
    CConfigField* get_field_by_index(int index);
    int get_field_count();
    void get_field_keys(string &keys[]);
    
    bool validate_field_value(string key, string value, string &reason);
    bool validate_field_value(string key, int value, string &reason);
    bool validate_field_value(string key, double value, string &reason);
    bool validate_field_value(string key, bool value, string &reason);
    
    int get_default_int(string key);
    double get_default_double(string key);
    bool get_default_bool(string key);
    string get_default_string(string key);
    
    CJAVal* to_json();
    string to_json_string();
};

//+------------------------------------------------------------------+
CConfigSchema::CConfigSchema()
{
    m_fields = new CArrayObj();
    m_fields.FreeMode(true);
}

CConfigSchema::~CConfigSchema()
{
    if(CheckPointer(m_fields) == POINTER_DYNAMIC)
        delete m_fields;
}

void CConfigSchema::add_field(CConfigField* field)
{
    if(CheckPointer(field) != POINTER_INVALID)
        m_fields.Add(field);
}

CConfigField* CConfigSchema::get_field(string key)
{
    for(int i = 0; i < m_fields.Total(); i++)
    {
        CConfigField* field = m_fields.At(i);
        if(field != NULL && field.m_key == key)
            return field;
    }
    return NULL;
}

CConfigField* CConfigSchema::get_field_by_index(int index)
{
    if(index < 0 || index >= m_fields.Total())
        return NULL;
    return m_fields.At(index);
}

int CConfigSchema::get_field_count()
{
    return m_fields.Total();
}

void CConfigSchema::get_field_keys(string &keys[])
{
    ArrayResize(keys, m_fields.Total());
    for(int i = 0; i < m_fields.Total(); i++)
    {
        CConfigField* field = m_fields.At(i);
        if(field != NULL) keys[i] = field.m_key;
    }
}

bool CConfigSchema::validate_field_value(string key, string value, string &reason)
{
    CConfigField* f = get_field(key);
    if(f == NULL) { reason = "Field not found: " + key; return false; }
    return f.validate_value(value, reason);
}

bool CConfigSchema::validate_field_value(string key, int value, string &reason)
{
    CConfigField* f = get_field(key);
    if(f == NULL) { reason = "Field not found: " + key; return false; }
    return f.validate_value(value, reason);
}

bool CConfigSchema::validate_field_value(string key, double value, string &reason)
{
    CConfigField* f = get_field(key);
    if(f == NULL) { reason = "Field not found: " + key; return false; }
    return f.validate_value(value, reason);
}

bool CConfigSchema::validate_field_value(string key, bool value, string &reason)
{
    CConfigField* f = get_field(key);
    if(f == NULL) { reason = "Field not found: " + key; return false; }
    return f.validate_value(value, reason);
}

int CConfigSchema::get_default_int(string key)
{
    CConfigField* f = get_field(key);
    return (f != NULL) ? f.m_default_int : 0;
}

double CConfigSchema::get_default_double(string key)
{
    CConfigField* f = get_field(key);
    return (f != NULL) ? f.m_default_double : 0.0;
}

bool CConfigSchema::get_default_bool(string key)
{
    CConfigField* f = get_field(key);
    return (f != NULL) ? f.m_default_bool : false;
}

string CConfigSchema::get_default_string(string key)
{
    CConfigField* f = get_field(key);
    return (f != NULL) ? f.m_default_string : "";
}

CJAVal* CConfigSchema::to_json()
{
    CJAVal* json = new CJAVal(JA_OBJECT);
    if(json == NULL) return NULL;
    
    CJAVal* arr = new CJAVal(JA_ARRAY);
    for(int i = 0; i < m_fields.Total(); i++)
    {
        CConfigField* f = m_fields.At(i);
        if(f != NULL) arr.Add(f.to_json());
    }
    json.Add("fields", arr);
    
    return json;
}

string CConfigSchema::to_json_string()
{
    CJAVal* json = to_json();
    if(json == NULL) return "";
    string result = json.to_string();
    delete json;
    return result;
}

#endif
//+------------------------------------------------------------------+

