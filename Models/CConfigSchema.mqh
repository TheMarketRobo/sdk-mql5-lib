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
    CConfigField* get_field(string tmkr_key);
    CConfigField* get_field_by_index(int tmkr_idx);
    int get_field_count();
    void get_field_keys(string &keys[]);
    
    bool validate_field_value(string tmkr_key, string tmkr_value, string &tmkr_reason);
    bool validate_field_value(string tmkr_key, int tmkr_value, string &tmkr_reason);
    bool validate_field_value(string tmkr_key, double tmkr_value, string &tmkr_reason);
    bool validate_field_value(string tmkr_key, bool tmkr_value, string &tmkr_reason);
    
    int get_default_int(string tmkr_key);
    double get_default_double(string tmkr_key);
    bool get_default_bool(string tmkr_key);
    string get_default_string(string tmkr_key);
    
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

CConfigField* CConfigSchema::get_field(string tmkr_key)
{
    for(int tmkr_i = 0; tmkr_i < m_fields.Total(); tmkr_i++)
    {
        CConfigField* field = m_fields.At(tmkr_i);
        if(field != NULL && field.m_key == tmkr_key)
            return field;
    }
    return NULL;
}

// Param renamed from `index` to `idx` — see notes in Services/Json.mqh.
CConfigField* CConfigSchema::get_field_by_index(int tmkr_idx)
{
    if(tmkr_idx < 0 || tmkr_idx >= m_fields.Total())
        return NULL;
    return m_fields.At(tmkr_idx);
}

int CConfigSchema::get_field_count()
{
    return m_fields.Total();
}

void CConfigSchema::get_field_keys(string &keys[])
{
    ArrayResize(keys, m_fields.Total());
    for(int tmkr_i = 0; tmkr_i < m_fields.Total(); tmkr_i++)
    {
        CConfigField* field = m_fields.At(tmkr_i);
        if(field != NULL) keys[tmkr_i] = field.m_key;
    }
}

bool CConfigSchema::validate_field_value(string tmkr_key, string tmkr_value, string &tmkr_reason)
{
    CConfigField* tmkr_f = get_field(tmkr_key);
    if(tmkr_f == NULL) { tmkr_reason = "Field not found: " + tmkr_key; return false; }
    return tmkr_f.validate_value(tmkr_value, tmkr_reason);
}

bool CConfigSchema::validate_field_value(string tmkr_key, int tmkr_value, string &tmkr_reason)
{
    CConfigField* tmkr_f = get_field(tmkr_key);
    if(tmkr_f == NULL) { tmkr_reason = "Field not found: " + tmkr_key; return false; }
    return tmkr_f.validate_value(tmkr_value, tmkr_reason);
}

bool CConfigSchema::validate_field_value(string tmkr_key, double tmkr_value, string &tmkr_reason)
{
    CConfigField* tmkr_f = get_field(tmkr_key);
    if(tmkr_f == NULL) { tmkr_reason = "Field not found: " + tmkr_key; return false; }
    return tmkr_f.validate_value(tmkr_value, tmkr_reason);
}

bool CConfigSchema::validate_field_value(string tmkr_key, bool tmkr_value, string &tmkr_reason)
{
    CConfigField* tmkr_f = get_field(tmkr_key);
    if(tmkr_f == NULL) { tmkr_reason = "Field not found: " + tmkr_key; return false; }
    return tmkr_f.validate_value(tmkr_value, tmkr_reason);
}

int CConfigSchema::get_default_int(string tmkr_key)
{
    CConfigField* tmkr_f = get_field(tmkr_key);
    return (tmkr_f != NULL) ? tmkr_f.m_default_int : 0;
}

double CConfigSchema::get_default_double(string tmkr_key)
{
    CConfigField* tmkr_f = get_field(tmkr_key);
    return (tmkr_f != NULL) ? tmkr_f.m_default_double : 0.0;
}

bool CConfigSchema::get_default_bool(string tmkr_key)
{
    CConfigField* tmkr_f = get_field(tmkr_key);
    return (tmkr_f != NULL) ? tmkr_f.m_default_bool : false;
}

string CConfigSchema::get_default_string(string tmkr_key)
{
    CConfigField* tmkr_f = get_field(tmkr_key);
    return (tmkr_f != NULL) ? tmkr_f.m_default_string : "";
}

CJAVal* CConfigSchema::to_json()
{
    CJAVal* json = new CJAVal(JA_OBJECT);
    if(json == NULL) return NULL;
    
    CJAVal* tmkr_arr = new CJAVal(JA_ARRAY);
    for(int tmkr_i = 0; tmkr_i < m_fields.Total(); tmkr_i++)
    {
        CConfigField* tmkr_f = m_fields.At(tmkr_i);
        if(tmkr_f != NULL) tmkr_arr.Add(tmkr_f.to_json());
    }
    json.Add("fields", tmkr_arr);
    
    return json;
}

string CConfigSchema::to_json_string()
{
    CJAVal* json = to_json();
    if(json == NULL) return "";
    string tmkr_result = json.to_string();
    delete json;
    return tmkr_result;
}

#endif
//+------------------------------------------------------------------+

