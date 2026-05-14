//+------------------------------------------------------------------+
//|                                                         Json.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"
#property strict

#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayString.mqh>

//+------------------------------------------------------------------+
//| JSON value types                                                 |
//+------------------------------------------------------------------+
enum ENUM_TMKR_JA_TYPE
{
    TMKR_JA_NULL,
    TMKR_JA_OBJECT,
    TMKR_JA_ARRAY,
    TMKR_JA_STRING,
    TMKR_JA_NUMBER,
    TMKR_JA_BOOL
};

class CTMKR_JAVal;

//+------------------------------------------------------------------+
//| Class for JSON object key-value pair                             |
//+------------------------------------------------------------------+
class CTMKR_JAObj : public CObject
{
public:
    string      m_key;
    CTMKR_JAVal     *m_val;

                CTMKR_JAObj(string tmkr_key, CTMKR_JAVal *tmkr_val);
               ~CTMKR_JAObj();
};

//+------------------------------------------------------------------+
CTMKR_JAObj::CTMKR_JAObj(string tmkr_key, CTMKR_JAVal *tmkr_val) : m_key(tmkr_key), m_val(tmkr_val) {}

//+------------------------------------------------------------------+
CTMKR_JAObj::~CTMKR_JAObj()
{
    if(CheckPointer(m_val) == POINTER_DYNAMIC)
        delete m_val;
}

//+------------------------------------------------------------------+
//| Class for a JSON value                                           |
//+------------------------------------------------------------------+
class CTMKR_JAVal : public CObject
{
private:
    ENUM_TMKR_JA_TYPE m_type;
    string      m_string;
    double      m_number;
    bool        m_bool;
    CArrayObj  *m_obj;
    CArrayObj  *m_arr;

public:
                CTMKR_JAVal(ENUM_TMKR_JA_TYPE tmkr_type = TMKR_JA_NULL);
               ~CTMKR_JAVal();

    bool        parse(string &json_string);
    string      to_string();

    ENUM_TMKR_JA_TYPE get_type() const;
    string      get_string() const;
    double      get_double() const;
    long        get_long() const;
    bool        get_bool() const;
    int         count() const;

    void        set_string(const string tmkr_value);
    void        set_double(const double tmkr_value);
    void        set_long(const long tmkr_value);
    void        set_bool(const bool tmkr_value);

    bool        Add(const string tmkr_key, CTMKR_JAVal *tmkr_value);
    CTMKR_JAVal     *operator[](const string tmkr_key);
    CTMKR_JAVal     *operator[](const string tmkr_key) const;
    bool        has_key(const string tmkr_key) const;

    bool        Add(CTMKR_JAVal *tmkr_value);
    CTMKR_JAVal     *operator[](const int tmkr_idx);
    CTMKR_JAVal     *operator[](const int tmkr_idx) const;
    
    string      serialize();  // Alias for to_string

private:
    string      Escape(const string tmkr_s);
    string      Unescape(const string tmkr_s);
    bool        ParseValue(string &json, int &tmkr_pos);
    bool        ParseObject(string &json, int &tmkr_pos);
    bool        ParseArray(string &json, int &tmkr_pos);
    bool        ParseString(string &json, int &tmkr_pos);
    bool        ParseNumber(string &json, int &tmkr_pos);
    bool        ParseLiteral(string &json, int &tmkr_pos);
    void        SkipWhitespace(string &json, int &tmkr_pos);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTMKR_JAVal::CTMKR_JAVal(ENUM_TMKR_JA_TYPE tmkr_type) : m_type(tmkr_type), m_number(0), m_bool(false)
{
    m_string = "";
    if(tmkr_type == TMKR_JA_OBJECT)
        m_obj = new CArrayObj();
    else
        m_obj = NULL;

    if(tmkr_type == TMKR_JA_ARRAY)
        m_arr = new CArrayObj();
    else
        m_arr = NULL;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTMKR_JAVal::~CTMKR_JAVal()
{
    if(CheckPointer(m_obj) == POINTER_DYNAMIC)
        delete m_obj;
    if(CheckPointer(m_arr) == POINTER_DYNAMIC)
        delete m_arr;
}

//+------------------------------------------------------------------+
//| Parse JSON string                                                 |
//+------------------------------------------------------------------+
bool CTMKR_JAVal::parse(string &json_string)
{
    int tmkr_pos = 0;
    return ParseValue(json_string, tmkr_pos);
}

//+------------------------------------------------------------------+
//| Convert to JSON string                                            |
//+------------------------------------------------------------------+
string CTMKR_JAVal::to_string()
{
    switch(m_type)
    {
        case TMKR_JA_NULL: 
            return "null";
        case TMKR_JA_STRING: 
            return "\"" + Escape(m_string) + "\"";
        case TMKR_JA_NUMBER:
        {
            if(m_number == MathFloor(m_number) && MathAbs(m_number) < 1e15)
                return IntegerToString((long)m_number);
            return DoubleToString(m_number, 8);
        }
        case TMKR_JA_BOOL: 
            return m_bool ? "true" : "false";
        case TMKR_JA_OBJECT:
        {
            string tmkr_s = "{";
            // Renamed from `total` to avoid shadowing common vendor globals
            // (e.g. MQL4 EAs that declare `int total = 0;` at file scope).
            int json_total = m_obj.Total();
            for(int tmkr_i = 0; tmkr_i < json_total; tmkr_i++)
            {
                CTMKR_JAObj *tmkr_pair = m_obj.At(tmkr_i);
                tmkr_s += "\"" + Escape(tmkr_pair.m_key) + "\":" + tmkr_pair.m_val.to_string();
                if(tmkr_i < json_total - 1)
                    tmkr_s += ",";
            }
            tmkr_s += "}";
            return tmkr_s;
        }
        case TMKR_JA_ARRAY:
        {
            string tmkr_s = "[";
            // Renamed from `total` for the same reason as above.
            int json_total = m_arr.Total();
            for(int tmkr_i = 0; tmkr_i < json_total; tmkr_i++)
            {
                CTMKR_JAVal *tmkr_val = m_arr.At(tmkr_i);
                tmkr_s += tmkr_val.to_string();
                if(tmkr_i < json_total - 1)
                    tmkr_s += ",";
            }
            tmkr_s += "]";
            return tmkr_s;
        }
    }
    return "";
}

//+------------------------------------------------------------------+
//| Getters                                                           |
//+------------------------------------------------------------------+
ENUM_TMKR_JA_TYPE CTMKR_JAVal::get_type() const { return m_type; }
string CTMKR_JAVal::get_string() const { return m_string; }
double CTMKR_JAVal::get_double() const { return m_number; }
long CTMKR_JAVal::get_long() const { return (long)m_number; }
bool CTMKR_JAVal::get_bool() const { return m_bool; }

int CTMKR_JAVal::count() const
{
    if(m_type == TMKR_JA_OBJECT && m_obj != NULL) return m_obj.Total();
    if(m_type == TMKR_JA_ARRAY && m_arr != NULL) return m_arr.Total();
    return 0;
}

//+------------------------------------------------------------------+
//| Setters                                                           |
//+------------------------------------------------------------------+
void CTMKR_JAVal::set_string(const string tmkr_value)
{
    m_type = TMKR_JA_STRING;
    m_string = tmkr_value;
}

void CTMKR_JAVal::set_double(const double tmkr_value)
{
    m_type = TMKR_JA_NUMBER;
    m_number = tmkr_value;
}

void CTMKR_JAVal::set_long(const long tmkr_value)
{
    m_type = TMKR_JA_NUMBER;
    m_number = (double)tmkr_value;
}

void CTMKR_JAVal::set_bool(const bool tmkr_value)
{
    m_type = TMKR_JA_BOOL;
    m_bool = tmkr_value;
}

//+------------------------------------------------------------------+
//| Object methods                                                    |
//+------------------------------------------------------------------+
bool CTMKR_JAVal::Add(const string tmkr_key, CTMKR_JAVal* tmkr_value)
{
    if(m_type != TMKR_JA_OBJECT) return false;
    if(m_obj == NULL) m_obj = new CArrayObj();
    return m_obj.Add(new CTMKR_JAObj(tmkr_key, tmkr_value));
}

CTMKR_JAVal* CTMKR_JAVal::operator[](const string tmkr_key)
{
    if(m_type != TMKR_JA_OBJECT || m_obj == NULL) return NULL;
    for(int tmkr_i = 0; tmkr_i < m_obj.Total(); tmkr_i++)
    {
        CTMKR_JAObj* tmkr_pair = m_obj.At(tmkr_i);
        if(tmkr_pair.m_key == tmkr_key) return tmkr_pair.m_val;
    }
    return NULL;
}

CTMKR_JAVal* CTMKR_JAVal::operator[](const string tmkr_key) const
{
    if(m_type != TMKR_JA_OBJECT || m_obj == NULL) return NULL;
    for(int tmkr_i = 0; tmkr_i < m_obj.Total(); tmkr_i++)
    {
        CTMKR_JAObj* tmkr_pair = m_obj.At(tmkr_i);
        if(tmkr_pair.m_key == tmkr_key) return tmkr_pair.m_val;
    }
    return NULL;
}

//+------------------------------------------------------------------+
//| Array methods                                                     |
//+------------------------------------------------------------------+
bool CTMKR_JAVal::Add(CTMKR_JAVal* tmkr_value)
{
    if(m_type != TMKR_JA_ARRAY) return false;
    if(m_arr == NULL) m_arr = new CArrayObj();
    return m_arr.Add(tmkr_value);
}

// Params renamed from `index` to `idx` to avoid shadow warnings — vendor EAs
// sometimes declare a global `double index` (Loss Index, position index, etc.).
CTMKR_JAVal* CTMKR_JAVal::operator[](const int tmkr_idx)
{
    if(m_type != TMKR_JA_ARRAY || m_arr == NULL) return NULL;
    return m_arr.At(tmkr_idx);
}

CTMKR_JAVal* CTMKR_JAVal::operator[](const int tmkr_idx) const
{
    if(m_type != TMKR_JA_ARRAY || m_arr == NULL) return NULL;
    return m_arr.At(tmkr_idx);
}

//+------------------------------------------------------------------+
//| Check if object has a key                                         |
//+------------------------------------------------------------------+
bool CTMKR_JAVal::has_key(const string tmkr_key) const
{
    if(m_type != TMKR_JA_OBJECT || m_obj == NULL) return false;
    for(int tmkr_i = 0; tmkr_i < m_obj.Total(); tmkr_i++)
    {
        CTMKR_JAObj* tmkr_pair = m_obj.At(tmkr_i);
        if(tmkr_pair.m_key == tmkr_key) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Serialize to JSON string (alias for to_string)                    |
//+------------------------------------------------------------------+
string CTMKR_JAVal::serialize()
{
    return to_string();
}

//+------------------------------------------------------------------+
//| Skip whitespace characters                                        |
//+------------------------------------------------------------------+
void CTMKR_JAVal::SkipWhitespace(string &json, int &tmkr_pos)
{
    int tmkr_len = StringLen(json);
    while(tmkr_pos < tmkr_len)
    {
        ushort tmkr_c = StringGetCharacter(json, tmkr_pos);
        if(tmkr_c == ' ' || tmkr_c == '\t' || tmkr_c == '\n' || tmkr_c == '\r')
            tmkr_pos++;
        else
            break;
    }
}

//+------------------------------------------------------------------+
//| Parse any JSON value                                              |
//+------------------------------------------------------------------+
bool CTMKR_JAVal::ParseValue(string &json, int &tmkr_pos)
{
    SkipWhitespace(json, tmkr_pos);
    
    if(tmkr_pos >= StringLen(json))
        return false;
    
    ushort tmkr_c = StringGetCharacter(json, tmkr_pos);
    
    if(tmkr_c == '{')
        return ParseObject(json, tmkr_pos);
    if(tmkr_c == '[')
        return ParseArray(json, tmkr_pos);
    if(tmkr_c == '"')
        return ParseString(json, tmkr_pos);
    if(tmkr_c == '-' || (tmkr_c >= '0' && tmkr_c <= '9'))
        return ParseNumber(json, tmkr_pos);
    if(tmkr_c == 't' || tmkr_c == 'f' || tmkr_c == 'n')
        return ParseLiteral(json, tmkr_pos);
    
    return false;
}

//+------------------------------------------------------------------+
//| Parse JSON object                                                 |
//+------------------------------------------------------------------+
bool CTMKR_JAVal::ParseObject(string &json, int &tmkr_pos)
{
    if(StringGetCharacter(json, tmkr_pos) != '{')
        return false;
    
    m_type = TMKR_JA_OBJECT;
    if(m_obj == NULL)
        m_obj = new CArrayObj();
    
    tmkr_pos++;
    SkipWhitespace(json, tmkr_pos);
    
    if(tmkr_pos < StringLen(json) && StringGetCharacter(json, tmkr_pos) == '}')
    {
        tmkr_pos++;
        return true;
    }
    
    while(tmkr_pos < StringLen(json))
    {
        SkipWhitespace(json, tmkr_pos);
        
        if(StringGetCharacter(json, tmkr_pos) != '"')
            return false;
        
        CTMKR_JAVal* keyVal = new CTMKR_JAVal();
        if(!keyVal.ParseString(json, tmkr_pos))
        {
            delete keyVal;
            return false;
        }
        string tmkr_key = keyVal.get_string();
        delete keyVal;
        
        SkipWhitespace(json, tmkr_pos);
        
        if(tmkr_pos >= StringLen(json) || StringGetCharacter(json, tmkr_pos) != ':')
            return false;
        tmkr_pos++;
        
        SkipWhitespace(json, tmkr_pos);
        
        CTMKR_JAVal* tmkr_value = new CTMKR_JAVal();
        if(!tmkr_value.ParseValue(json, tmkr_pos))
        {
            delete tmkr_value;
            return false;
        }
        
        m_obj.Add(new CTMKR_JAObj(tmkr_key, tmkr_value));
        
        SkipWhitespace(json, tmkr_pos);
        
        if(tmkr_pos >= StringLen(json))
            return false;
        
        ushort tmkr_c = StringGetCharacter(json, tmkr_pos);
        if(tmkr_c == '}')
        {
            tmkr_pos++;
            return true;
        }
        if(tmkr_c == ',')
        {
            tmkr_pos++;
            continue;
        }
        
        return false;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Parse JSON array                                                  |
//+------------------------------------------------------------------+
bool CTMKR_JAVal::ParseArray(string &json, int &tmkr_pos)
{
    if(StringGetCharacter(json, tmkr_pos) != '[')
        return false;
    
    m_type = TMKR_JA_ARRAY;
    if(m_arr == NULL)
        m_arr = new CArrayObj();
    
    tmkr_pos++;
    SkipWhitespace(json, tmkr_pos);
    
    if(tmkr_pos < StringLen(json) && StringGetCharacter(json, tmkr_pos) == ']')
    {
        tmkr_pos++;
        return true;
    }
    
    while(tmkr_pos < StringLen(json))
    {
        SkipWhitespace(json, tmkr_pos);
        
        CTMKR_JAVal* tmkr_value = new CTMKR_JAVal();
        if(!tmkr_value.ParseValue(json, tmkr_pos))
        {
            delete tmkr_value;
            return false;
        }
        
        m_arr.Add(tmkr_value);
        
        SkipWhitespace(json, tmkr_pos);
        
        if(tmkr_pos >= StringLen(json))
            return false;
        
        ushort tmkr_c = StringGetCharacter(json, tmkr_pos);
        if(tmkr_c == ']')
        {
            tmkr_pos++;
            return true;
        }
        if(tmkr_c == ',')
        {
            tmkr_pos++;
            continue;
        }
        
        return false;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Parse JSON string                                                 |
//+------------------------------------------------------------------+
bool CTMKR_JAVal::ParseString(string &json, int &tmkr_pos)
{
    if(StringGetCharacter(json, tmkr_pos) != '"')
        return false;
    
    tmkr_pos++;
    string tmkr_result = "";
    int tmkr_len = StringLen(json);
    
    while(tmkr_pos < tmkr_len)
    {
        ushort tmkr_c = StringGetCharacter(json, tmkr_pos);
        
        if(tmkr_c == '"')
        {
            tmkr_pos++;
            m_type = TMKR_JA_STRING;
            m_string = tmkr_result;
            return true;
        }
        
        if(tmkr_c == '\\')
        {
            tmkr_pos++;
            if(tmkr_pos >= tmkr_len)
                return false;
            
            ushort escaped = StringGetCharacter(json, tmkr_pos);
            switch(escaped)
            {
                case '"':  tmkr_result += "\""; break;
                case '\\': tmkr_result += "\\"; break;
                case '/':  tmkr_result += "/"; break;
                case 'b':  tmkr_result += ShortToString(8); break;  // backspace
                case 'f':  tmkr_result += ShortToString(12); break; // form feed
                case 'n':  tmkr_result += "\n"; break;
                case 'r':  tmkr_result += "\r"; break;
                case 't':  tmkr_result += "\t"; break;
                case 'u':
                {
                    if(tmkr_pos + 4 >= tmkr_len)
                        return false;
                    string hex = StringSubstr(json, tmkr_pos + 1, 4);
                    int tmkr_code = 0;
                    for(int tmkr_i = 0; tmkr_i < 4; tmkr_i++)
                    {
                        ushort tmkr_h = StringGetCharacter(hex, tmkr_i);
                        int tmkr_val = 0;
                        if(tmkr_h >= '0' && tmkr_h <= '9') tmkr_val = tmkr_h - '0';
                        else if(tmkr_h >= 'a' && tmkr_h <= 'f') tmkr_val = tmkr_h - 'a' + 10;
                        else if(tmkr_h >= 'A' && tmkr_h <= 'F') tmkr_val = tmkr_h - 'A' + 10;
                        else return false;
                        tmkr_code = tmkr_code * 16 + tmkr_val;
                    }
                    tmkr_result += ShortToString((ushort)tmkr_code);
                    tmkr_pos += 4;
                    break;
                }
                default:
                    return false;
            }
            tmkr_pos++;
        }
        else
        {
            tmkr_result += ShortToString(tmkr_c);
            tmkr_pos++;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Parse JSON number                                                 |
//+------------------------------------------------------------------+
bool CTMKR_JAVal::ParseNumber(string &json, int &tmkr_pos)
{
    int tmkr_start = tmkr_pos;
    int tmkr_len = StringLen(json);
    
    if(tmkr_pos < tmkr_len && StringGetCharacter(json, tmkr_pos) == '-')
        tmkr_pos++;
    
    if(tmkr_pos >= tmkr_len)
        return false;
    
    ushort tmkr_c = StringGetCharacter(json, tmkr_pos);
    if(tmkr_c == '0')
    {
        tmkr_pos++;
    }
    else if(tmkr_c >= '1' && tmkr_c <= '9')
    {
        tmkr_pos++;
        while(tmkr_pos < tmkr_len)
        {
            tmkr_c = StringGetCharacter(json, tmkr_pos);
            if(tmkr_c >= '0' && tmkr_c <= '9')
                tmkr_pos++;
            else
                break;
        }
    }
    else
    {
        return false;
    }
    
    if(tmkr_pos < tmkr_len && StringGetCharacter(json, tmkr_pos) == '.')
    {
        tmkr_pos++;
        if(tmkr_pos >= tmkr_len)
            return false;
        
        tmkr_c = StringGetCharacter(json, tmkr_pos);
        if(tmkr_c < '0' || tmkr_c > '9')
            return false;
        
        while(tmkr_pos < tmkr_len)
        {
            tmkr_c = StringGetCharacter(json, tmkr_pos);
            if(tmkr_c >= '0' && tmkr_c <= '9')
                tmkr_pos++;
            else
                break;
        }
    }
    
    if(tmkr_pos < tmkr_len)
    {
        tmkr_c = StringGetCharacter(json, tmkr_pos);
        if(tmkr_c == 'e' || tmkr_c == 'E')
        {
            tmkr_pos++;
            if(tmkr_pos >= tmkr_len)
                return false;
            
            tmkr_c = StringGetCharacter(json, tmkr_pos);
            if(tmkr_c == '+' || tmkr_c == '-')
                tmkr_pos++;
            
            if(tmkr_pos >= tmkr_len)
                return false;
            
            tmkr_c = StringGetCharacter(json, tmkr_pos);
            if(tmkr_c < '0' || tmkr_c > '9')
                return false;
            
            while(tmkr_pos < tmkr_len)
            {
                tmkr_c = StringGetCharacter(json, tmkr_pos);
                if(tmkr_c >= '0' && tmkr_c <= '9')
                    tmkr_pos++;
                else
                    break;
            }
        }
    }
    
    string numStr = StringSubstr(json, tmkr_start, tmkr_pos - tmkr_start);
    m_type = TMKR_JA_NUMBER;
    m_number = StringToDouble(numStr);
    
    return true;
}

//+------------------------------------------------------------------+
//| Parse JSON literal (true, false, null)                            |
//+------------------------------------------------------------------+
bool CTMKR_JAVal::ParseLiteral(string &json, int &tmkr_pos)
{
    int tmkr_len = StringLen(json);
    
    if(tmkr_pos + 4 <= tmkr_len && StringSubstr(json, tmkr_pos, 4) == "true")
    {
        m_type = TMKR_JA_BOOL;
        m_bool = true;
        tmkr_pos += 4;
        return true;
    }
    
    if(tmkr_pos + 5 <= tmkr_len && StringSubstr(json, tmkr_pos, 5) == "false")
    {
        m_type = TMKR_JA_BOOL;
        m_bool = false;
        tmkr_pos += 5;
        return true;
    }
    
    if(tmkr_pos + 4 <= tmkr_len && StringSubstr(json, tmkr_pos, 4) == "null")
    {
        m_type = TMKR_JA_NULL;
        tmkr_pos += 4;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Escape special characters in string                               |
//+------------------------------------------------------------------+
string CTMKR_JAVal::Escape(const string tmkr_s)
{
    string tmkr_result = "";
    int tmkr_len = StringLen(tmkr_s);
    
    for(int tmkr_i = 0; tmkr_i < tmkr_len; tmkr_i++)
    {
        ushort tmkr_c = StringGetCharacter(tmkr_s, tmkr_i);
        switch(tmkr_c)
        {
            case '"':  tmkr_result += "\\\""; break;
            case '\\': tmkr_result += "\\\\"; break;
            case 8:    tmkr_result += "\\b"; break;  // backspace (0x08)
            case 12:   tmkr_result += "\\f"; break;  // form feed (0x0C)
            case '\n': tmkr_result += "\\n"; break;
            case '\r': tmkr_result += "\\r"; break;
            case '\t': tmkr_result += "\\t"; break;
            default:
                if(tmkr_c < 32)
                {
                    tmkr_result += "\\u";
                    string hex = "";
                    for(int tmkr_j = 3; tmkr_j >= 0; tmkr_j--)
                    {
                        int nibble = (tmkr_c >> (tmkr_j * 4)) & 0xF;
                        if(nibble < 10)
                            hex += ShortToString((ushort)('0' + nibble));
                        else
                            hex += ShortToString((ushort)('a' + nibble - 10));
                    }
                    tmkr_result += hex;
                }
                else
                {
                    tmkr_result += ShortToString(tmkr_c);
                }
                break;
        }
    }
    
    return tmkr_result;
}

//+------------------------------------------------------------------+
//| Unescape special characters in string                             |
//+------------------------------------------------------------------+
string CTMKR_JAVal::Unescape(const string tmkr_s)
{
    string tmkr_result = "";
    int tmkr_len = StringLen(tmkr_s);
    int tmkr_i = 0;
    
    while(tmkr_i < tmkr_len)
    {
        ushort tmkr_c = StringGetCharacter(tmkr_s, tmkr_i);
        
        if(tmkr_c == '\\' && tmkr_i + 1 < tmkr_len)
        {
            ushort tmkr_next = StringGetCharacter(tmkr_s, tmkr_i + 1);
            switch(tmkr_next)
            {
                case '"':  tmkr_result += "\""; tmkr_i += 2; break;
                case '\\': tmkr_result += "\\"; tmkr_i += 2; break;
                case '/':  tmkr_result += "/"; tmkr_i += 2; break;
                case 'b':  tmkr_result += ShortToString(8); tmkr_i += 2; break;  // backspace
                case 'f':  tmkr_result += ShortToString(12); tmkr_i += 2; break; // form feed
                case 'n':  tmkr_result += "\n"; tmkr_i += 2; break;
                case 'r':  tmkr_result += "\r"; tmkr_i += 2; break;
                case 't':  tmkr_result += "\t"; tmkr_i += 2; break;
                case 'u':
                {
                    if(tmkr_i + 5 < tmkr_len)
                    {
                        string hex = StringSubstr(tmkr_s, tmkr_i + 2, 4);
                        int tmkr_code = 0;
                        for(int tmkr_j = 0; tmkr_j < 4; tmkr_j++)
                        {
                            ushort tmkr_h = StringGetCharacter(hex, tmkr_j);
                            int tmkr_val = 0;
                            if(tmkr_h >= '0' && tmkr_h <= '9') tmkr_val = tmkr_h - '0';
                            else if(tmkr_h >= 'a' && tmkr_h <= 'f') tmkr_val = tmkr_h - 'a' + 10;
                            else if(tmkr_h >= 'A' && tmkr_h <= 'F') tmkr_val = tmkr_h - 'A' + 10;
                            tmkr_code = tmkr_code * 16 + tmkr_val;
                        }
                        tmkr_result += ShortToString((ushort)tmkr_code);
                        tmkr_i += 6;
                    }
                    else
                    {
                        tmkr_result += ShortToString(tmkr_c);
                        tmkr_i++;
                    }
                    break;
                }
                default:
                    tmkr_result += ShortToString(tmkr_c);
                    tmkr_i++;
                    break;
            }
        }
        else
        {
            tmkr_result += ShortToString(tmkr_c);
            tmkr_i++;
        }
    }
    
    return tmkr_result;
}

//+------------------------------------------------------------------+
