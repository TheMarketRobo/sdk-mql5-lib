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
    CConfigField* get_field(string _key);
    CConfigField* get_field_by_index(int _idx);
    int get_field_count();
    void get_field_keys(string &keys[]);
    
    bool validate_field_value(string _key, string _value, string &reason);
    bool validate_field_value(string _key, int _value, string &reason);
    bool validate_field_value(string _key, double _value, string &reason);
    bool validate_field_value(string _key, bool _value, string &reason);
    
    int get_default_int(string _key);
    double get_default_double(string _key);
    bool get_default_bool(string _key);
    string get_default_string(string _key);
    
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

CConfigField* CConfigSchema::get_field(string _key)
{
    for(int _i = 0; _i < m_fields.Total(); _i++)
    {
        CConfigField* field = m_fields.At(_i);
        if(field != NULL && field.m_key == _key)
            return field;
    }
    return NULL;
}

// Param renamed from `index` to `idx` — see notes in Services/Json.mqh.
CConfigField* CConfigSchema::get_field_by_index(int _idx)
{
    if(_idx < 0 || _idx >= m_fields.Total())
        return NULL;
    return m_fields.At(_idx);
}

int CConfigSchema::get_field_count()
{
    return m_fields.Total();
}

void CConfigSchema::get_field_keys(string &keys[])
{
    ArrayResize(keys, m_fields.Total());
    for(int _i = 0; _i < m_fields.Total(); _i++)
    {
        CConfigField* field = m_fields.At(_i);
        if(field != NULL) keys[_i] = field.m_key;
    }
}

bool CConfigSchema::validate_field_value(string _key, string _value, string &reason)
{
    CConfigField* f = get_field(_key);
    if(f == NULL) { reason = "Field not found: " + _key; return false; }
    return f.validate_value(_value, reason);
}

bool CConfigSchema::validate_field_value(string _key, int _value, string &reason)
{
    CConfigField* f = get_field(_key);
    if(f == NULL) { reason = "Field not found: " + _key; return false; }
    return f.validate_value(_value, reason);
}

bool CConfigSchema::validate_field_value(string _key, double _value, string &reason)
{
    CConfigField* f = get_field(_key);
    if(f == NULL) { reason = "Field not found: " + _key; return false; }
    return f.validate_value(_value, reason);
}

bool CConfigSchema::validate_field_value(string _key, bool _value, string &reason)
{
    CConfigField* f = get_field(_key);
    if(f == NULL) { reason = "Field not found: " + _key; return false; }
    return f.validate_value(_value, reason);
}

int CConfigSchema::get_default_int(string _key)
{
    CConfigField* f = get_field(_key);
    return (f != NULL) ? f.m_default_int : 0;
}

double CConfigSchema::get_default_double(string _key)
{
    CConfigField* f = get_field(_key);
    return (f != NULL) ? f.m_default_double : 0.0;
}

bool CConfigSchema::get_default_bool(string _key)
{
    CConfigField* f = get_field(_key);
    return (f != NULL) ? f.m_default_bool : false;
}

string CConfigSchema::get_default_string(string _key)
{
    CConfigField* f = get_field(_key);
    return (f != NULL) ? f.m_default_string : "";
}

CJAVal* CConfigSchema::to_json()
{
    CJAVal* json = new CJAVal(JA_OBJECT);
    if(json == NULL) return NULL;
    
    CJAVal* arr = new CJAVal(JA_ARRAY);
    for(int _i = 0; _i < m_fields.Total(); _i++)
    {
        CConfigField* f = m_fields.At(_i);
        if(f != NULL) arr.Add(f.to_json());
    }
    json.Add("fields", arr);
    
    return json;
}

string CConfigSchema::to_json_string()
{
    CJAVal* json = to_json();
    if(json == NULL) return "";
    string _result = json.to_string();
    delete json;
    return _result;
}

#endif
//+------------------------------------------------------------------+

