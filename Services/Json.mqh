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
enum ENUM_JA_TYPE
{
    JA_NULL,
    JA_OBJECT,
    JA_ARRAY,
    JA_STRING,
    JA_NUMBER,
    JA_BOOL
};

class CJAVal;

//+------------------------------------------------------------------+
//| Class for JSON object key-value pair                             |
//+------------------------------------------------------------------+
class CJAObj : public CObject
{
public:
    string      m_key;
    CJAVal     *m_val;

                CJAObj(string _key, CJAVal *val);
               ~CJAObj();
};

//+------------------------------------------------------------------+
CJAObj::CJAObj(string _key, CJAVal *val) : m_key(_key), m_val(val) {}

//+------------------------------------------------------------------+
CJAObj::~CJAObj()
{
    if(CheckPointer(m_val) == POINTER_DYNAMIC)
        delete m_val;
}

//+------------------------------------------------------------------+
//| Class for a JSON value                                           |
//+------------------------------------------------------------------+
class CJAVal : public CObject
{
private:
    ENUM_JA_TYPE m_type;
    string      m_string;
    double      m_number;
    bool        m_bool;
    CArrayObj  *m_obj;
    CArrayObj  *m_arr;

public:
                CJAVal(ENUM_JA_TYPE type = JA_NULL);
               ~CJAVal();

    bool        parse(string &json_string);
    string      to_string();

    ENUM_JA_TYPE get_type() const;
    string      get_string() const;
    double      get_double() const;
    long        get_long() const;
    bool        get_bool() const;
    int         _count() const;

    void        set_string(const string _value);
    void        set_double(const double _value);
    void        set_long(const long _value);
    void        set_bool(const bool _value);

    bool        Add(const string _key, CJAVal *_value);
    CJAVal     *operator[](const string _key);
    CJAVal     *operator[](const string _key) const;
    bool        has_key(const string _key) const;

    bool        Add(CJAVal *_value);
    CJAVal     *operator[](const int _idx);
    CJAVal     *operator[](const int _idx) const;
    
    string      serialize();  // Alias for to_string

private:
    string      Escape(const string s);
    string      Unescape(const string s);
    bool        ParseValue(string &json, int &_pos);
    bool        ParseObject(string &json, int &_pos);
    bool        ParseArray(string &json, int &_pos);
    bool        ParseString(string &json, int &_pos);
    bool        ParseNumber(string &json, int &_pos);
    bool        ParseLiteral(string &json, int &_pos);
    void        SkipWhitespace(string &json, int &_pos);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CJAVal::CJAVal(ENUM_JA_TYPE type) : m_type(type), m_number(0), m_bool(false)
{
    m_string = "";
    if(type == JA_OBJECT)
        m_obj = new CArrayObj();
    else
        m_obj = NULL;

    if(type == JA_ARRAY)
        m_arr = new CArrayObj();
    else
        m_arr = NULL;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CJAVal::~CJAVal()
{
    if(CheckPointer(m_obj) == POINTER_DYNAMIC)
        delete m_obj;
    if(CheckPointer(m_arr) == POINTER_DYNAMIC)
        delete m_arr;
}

//+------------------------------------------------------------------+
//| Parse JSON string                                                 |
//+------------------------------------------------------------------+
bool CJAVal::parse(string &json_string)
{
    int _pos = 0;
    return ParseValue(json_string, _pos);
}

//+------------------------------------------------------------------+
//| Convert to JSON string                                            |
//+------------------------------------------------------------------+
string CJAVal::to_string()
{
    switch(m_type)
    {
        case JA_NULL: 
            return "null";
        case JA_STRING: 
            return "\"" + Escape(m_string) + "\"";
        case JA_NUMBER:
        {
            if(m_number == MathFloor(m_number) && MathAbs(m_number) < 1e15)
                return IntegerToString((long)m_number);
            return DoubleToString(m_number, 8);
        }
        case JA_BOOL: 
            return m_bool ? "true" : "false";
        case JA_OBJECT:
        {
            string s = "{";
            // Renamed from `total` to avoid shadowing common vendor globals
            // (e.g. MQL4 EAs that declare `int total = 0;` at file scope).
            int json_total = m_obj.Total();
            for(int _i = 0; _i < json_total; _i++)
            {
                CJAObj *pair = m_obj.At(_i);
                s += "\"" + Escape(pair.m_key) + "\":" + pair.m_val.to_string();
                if(_i < json_total - 1)
                    s += ",";
            }
            s += "}";
            return s;
        }
        case JA_ARRAY:
        {
            string s = "[";
            // Renamed from `total` for the same reason as above.
            int json_total = m_arr.Total();
            for(int _i = 0; _i < json_total; _i++)
            {
                CJAVal *val = m_arr.At(_i);
                s += val.to_string();
                if(_i < json_total - 1)
                    s += ",";
            }
            s += "]";
            return s;
        }
    }
    return "";
}

//+------------------------------------------------------------------+
//| Getters                                                           |
//+------------------------------------------------------------------+
ENUM_JA_TYPE CJAVal::get_type() const { return m_type; }
string CJAVal::get_string() const { return m_string; }
double CJAVal::get_double() const { return m_number; }
long CJAVal::get_long() const { return (long)m_number; }
bool CJAVal::get_bool() const { return m_bool; }

int CJAVal::_count() const
{
    if(m_type == JA_OBJECT && m_obj != NULL) return m_obj.Total();
    if(m_type == JA_ARRAY && m_arr != NULL) return m_arr.Total();
    return 0;
}

//+------------------------------------------------------------------+
//| Setters                                                           |
//+------------------------------------------------------------------+
void CJAVal::set_string(const string _value)
{
    m_type = JA_STRING;
    m_string = _value;
}

void CJAVal::set_double(const double _value)
{
    m_type = JA_NUMBER;
    m_number = _value;
}

void CJAVal::set_long(const long _value)
{
    m_type = JA_NUMBER;
    m_number = (double)_value;
}

void CJAVal::set_bool(const bool _value)
{
    m_type = JA_BOOL;
    m_bool = _value;
}

//+------------------------------------------------------------------+
//| Object methods                                                    |
//+------------------------------------------------------------------+
bool CJAVal::Add(const string _key, CJAVal* _value)
{
    if(m_type != JA_OBJECT) return false;
    if(m_obj == NULL) m_obj = new CArrayObj();
    return m_obj.Add(new CJAObj(_key, _value));
}

CJAVal* CJAVal::operator[](const string _key)
{
    if(m_type != JA_OBJECT || m_obj == NULL) return NULL;
    for(int _i = 0; _i < m_obj.Total(); _i++)
    {
        CJAObj* pair = m_obj.At(_i);
        if(pair.m_key == _key) return pair.m_val;
    }
    return NULL;
}

CJAVal* CJAVal::operator[](const string _key) const
{
    if(m_type != JA_OBJECT || m_obj == NULL) return NULL;
    for(int _i = 0; _i < m_obj.Total(); _i++)
    {
        CJAObj* pair = m_obj.At(_i);
        if(pair.m_key == _key) return pair.m_val;
    }
    return NULL;
}

//+------------------------------------------------------------------+
//| Array methods                                                     |
//+------------------------------------------------------------------+
bool CJAVal::Add(CJAVal* _value)
{
    if(m_type != JA_ARRAY) return false;
    if(m_arr == NULL) m_arr = new CArrayObj();
    return m_arr.Add(_value);
}

// Params renamed from `index` to `idx` to avoid shadow warnings — vendor EAs
// sometimes declare a global `double index` (Loss Index, position index, etc.).
CJAVal* CJAVal::operator[](const int _idx)
{
    if(m_type != JA_ARRAY || m_arr == NULL) return NULL;
    return m_arr.At(_idx);
}

CJAVal* CJAVal::operator[](const int _idx) const
{
    if(m_type != JA_ARRAY || m_arr == NULL) return NULL;
    return m_arr.At(_idx);
}

//+------------------------------------------------------------------+
//| Check if object has a key                                         |
//+------------------------------------------------------------------+
bool CJAVal::has_key(const string _key) const
{
    if(m_type != JA_OBJECT || m_obj == NULL) return false;
    for(int _i = 0; _i < m_obj.Total(); _i++)
    {
        CJAObj* pair = m_obj.At(_i);
        if(pair.m_key == _key) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Serialize to JSON string (alias for to_string)                    |
//+------------------------------------------------------------------+
string CJAVal::serialize()
{
    return to_string();
}

//+------------------------------------------------------------------+
//| Skip whitespace characters                                        |
//+------------------------------------------------------------------+
void CJAVal::SkipWhitespace(string &json, int &_pos)
{
    int _len = StringLen(json);
    while(_pos < _len)
    {
        ushort c = StringGetCharacter(json, _pos);
        if(c == ' ' || c == '\t' || c == '\n' || c == '\r')
            _pos++;
        else
            break;
    }
}

//+------------------------------------------------------------------+
//| Parse any JSON value                                              |
//+------------------------------------------------------------------+
bool CJAVal::ParseValue(string &json, int &_pos)
{
    SkipWhitespace(json, _pos);
    
    if(_pos >= StringLen(json))
        return false;
    
    ushort c = StringGetCharacter(json, _pos);
    
    if(c == '{')
        return ParseObject(json, _pos);
    if(c == '[')
        return ParseArray(json, _pos);
    if(c == '"')
        return ParseString(json, _pos);
    if(c == '-' || (c >= '0' && c <= '9'))
        return ParseNumber(json, _pos);
    if(c == 't' || c == 'f' || c == 'n')
        return ParseLiteral(json, _pos);
    
    return false;
}

//+------------------------------------------------------------------+
//| Parse JSON object                                                 |
//+------------------------------------------------------------------+
bool CJAVal::ParseObject(string &json, int &_pos)
{
    if(StringGetCharacter(json, _pos) != '{')
        return false;
    
    m_type = JA_OBJECT;
    if(m_obj == NULL)
        m_obj = new CArrayObj();
    
    _pos++;
    SkipWhitespace(json, _pos);
    
    if(_pos < StringLen(json) && StringGetCharacter(json, _pos) == '}')
    {
        _pos++;
        return true;
    }
    
    while(_pos < StringLen(json))
    {
        SkipWhitespace(json, _pos);
        
        if(StringGetCharacter(json, _pos) != '"')
            return false;
        
        CJAVal* keyVal = new CJAVal();
        if(!keyVal.ParseString(json, _pos))
        {
            delete keyVal;
            return false;
        }
        string _key = keyVal.get_string();
        delete keyVal;
        
        SkipWhitespace(json, _pos);
        
        if(_pos >= StringLen(json) || StringGetCharacter(json, _pos) != ':')
            return false;
        _pos++;
        
        SkipWhitespace(json, _pos);
        
        CJAVal* _value = new CJAVal();
        if(!_value.ParseValue(json, _pos))
        {
            delete _value;
            return false;
        }
        
        m_obj.Add(new CJAObj(_key, _value));
        
        SkipWhitespace(json, _pos);
        
        if(_pos >= StringLen(json))
            return false;
        
        ushort c = StringGetCharacter(json, _pos);
        if(c == '}')
        {
            _pos++;
            return true;
        }
        if(c == ',')
        {
            _pos++;
            continue;
        }
        
        return false;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Parse JSON array                                                  |
//+------------------------------------------------------------------+
bool CJAVal::ParseArray(string &json, int &_pos)
{
    if(StringGetCharacter(json, _pos) != '[')
        return false;
    
    m_type = JA_ARRAY;
    if(m_arr == NULL)
        m_arr = new CArrayObj();
    
    _pos++;
    SkipWhitespace(json, _pos);
    
    if(_pos < StringLen(json) && StringGetCharacter(json, _pos) == ']')
    {
        _pos++;
        return true;
    }
    
    while(_pos < StringLen(json))
    {
        SkipWhitespace(json, _pos);
        
        CJAVal* _value = new CJAVal();
        if(!_value.ParseValue(json, _pos))
        {
            delete _value;
            return false;
        }
        
        m_arr.Add(_value);
        
        SkipWhitespace(json, _pos);
        
        if(_pos >= StringLen(json))
            return false;
        
        ushort c = StringGetCharacter(json, _pos);
        if(c == ']')
        {
            _pos++;
            return true;
        }
        if(c == ',')
        {
            _pos++;
            continue;
        }
        
        return false;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Parse JSON string                                                 |
//+------------------------------------------------------------------+
bool CJAVal::ParseString(string &json, int &_pos)
{
    if(StringGetCharacter(json, _pos) != '"')
        return false;
    
    _pos++;
    string _result = "";
    int _len = StringLen(json);
    
    while(_pos < _len)
    {
        ushort c = StringGetCharacter(json, _pos);
        
        if(c == '"')
        {
            _pos++;
            m_type = JA_STRING;
            m_string = _result;
            return true;
        }
        
        if(c == '\\')
        {
            _pos++;
            if(_pos >= _len)
                return false;
            
            ushort escaped = StringGetCharacter(json, _pos);
            switch(escaped)
            {
                case '"':  _result += "\""; break;
                case '\\': _result += "\\"; break;
                case '/':  _result += "/"; break;
                case 'b':  _result += ShortToString(8); break;  // backspace
                case 'f':  _result += ShortToString(12); break; // form feed
                case 'n':  _result += "\n"; break;
                case 'r':  _result += "\r"; break;
                case 't':  _result += "\t"; break;
                case 'u':
                {
                    if(_pos + 4 >= _len)
                        return false;
                    string hex = StringSubstr(json, _pos + 1, 4);
                    int code = 0;
                    for(int _i = 0; _i < 4; _i++)
                    {
                        ushort h = StringGetCharacter(hex, _i);
                        int val = 0;
                        if(h >= '0' && h <= '9') val = h - '0';
                        else if(h >= 'a' && h <= 'f') val = h - 'a' + 10;
                        else if(h >= 'A' && h <= 'F') val = h - 'A' + 10;
                        else return false;
                        code = code * 16 + val;
                    }
                    _result += ShortToString((ushort)code);
                    _pos += 4;
                    break;
                }
                default:
                    return false;
            }
            _pos++;
        }
        else
        {
            _result += ShortToString(c);
            _pos++;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Parse JSON number                                                 |
//+------------------------------------------------------------------+
bool CJAVal::ParseNumber(string &json, int &_pos)
{
    int start = _pos;
    int _len = StringLen(json);
    
    if(_pos < _len && StringGetCharacter(json, _pos) == '-')
        _pos++;
    
    if(_pos >= _len)
        return false;
    
    ushort c = StringGetCharacter(json, _pos);
    if(c == '0')
    {
        _pos++;
    }
    else if(c >= '1' && c <= '9')
    {
        _pos++;
        while(_pos < _len)
        {
            c = StringGetCharacter(json, _pos);
            if(c >= '0' && c <= '9')
                _pos++;
            else
                break;
        }
    }
    else
    {
        return false;
    }
    
    if(_pos < _len && StringGetCharacter(json, _pos) == '.')
    {
        _pos++;
        if(_pos >= _len)
            return false;
        
        c = StringGetCharacter(json, _pos);
        if(c < '0' || c > '9')
            return false;
        
        while(_pos < _len)
        {
            c = StringGetCharacter(json, _pos);
            if(c >= '0' && c <= '9')
                _pos++;
            else
                break;
        }
    }
    
    if(_pos < _len)
    {
        c = StringGetCharacter(json, _pos);
        if(c == 'e' || c == 'E')
        {
            _pos++;
            if(_pos >= _len)
                return false;
            
            c = StringGetCharacter(json, _pos);
            if(c == '+' || c == '-')
                _pos++;
            
            if(_pos >= _len)
                return false;
            
            c = StringGetCharacter(json, _pos);
            if(c < '0' || c > '9')
                return false;
            
            while(_pos < _len)
            {
                c = StringGetCharacter(json, _pos);
                if(c >= '0' && c <= '9')
                    _pos++;
                else
                    break;
            }
        }
    }
    
    string numStr = StringSubstr(json, start, _pos - start);
    m_type = JA_NUMBER;
    m_number = StringToDouble(numStr);
    
    return true;
}

//+------------------------------------------------------------------+
//| Parse JSON literal (true, false, null)                            |
//+------------------------------------------------------------------+
bool CJAVal::ParseLiteral(string &json, int &_pos)
{
    int _len = StringLen(json);
    
    if(_pos + 4 <= _len && StringSubstr(json, _pos, 4) == "true")
    {
        m_type = JA_BOOL;
        m_bool = true;
        _pos += 4;
        return true;
    }
    
    if(_pos + 5 <= _len && StringSubstr(json, _pos, 5) == "false")
    {
        m_type = JA_BOOL;
        m_bool = false;
        _pos += 5;
        return true;
    }
    
    if(_pos + 4 <= _len && StringSubstr(json, _pos, 4) == "null")
    {
        m_type = JA_NULL;
        _pos += 4;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Escape special characters in string                               |
//+------------------------------------------------------------------+
string CJAVal::Escape(const string s)
{
    string _result = "";
    int _len = StringLen(s);
    
    for(int _i = 0; _i < _len; _i++)
    {
        ushort c = StringGetCharacter(s, _i);
        switch(c)
        {
            case '"':  _result += "\\\""; break;
            case '\\': _result += "\\\\"; break;
            case 8:    _result += "\\b"; break;  // backspace (0x08)
            case 12:   _result += "\\f"; break;  // form feed (0x0C)
            case '\n': _result += "\\n"; break;
            case '\r': _result += "\\r"; break;
            case '\t': _result += "\\t"; break;
            default:
                if(c < 32)
                {
                    _result += "\\u";
                    string hex = "";
                    for(int _j = 3; _j >= 0; _j--)
                    {
                        int nibble = (c >> (_j * 4)) & 0xF;
                        if(nibble < 10)
                            hex += ShortToString((ushort)('0' + nibble));
                        else
                            hex += ShortToString((ushort)('a' + nibble - 10));
                    }
                    _result += hex;
                }
                else
                {
                    _result += ShortToString(c);
                }
                break;
        }
    }
    
    return _result;
}

//+------------------------------------------------------------------+
//| Unescape special characters in string                             |
//+------------------------------------------------------------------+
string CJAVal::Unescape(const string s)
{
    string _result = "";
    int _len = StringLen(s);
    int _i = 0;
    
    while(_i < _len)
    {
        ushort c = StringGetCharacter(s, _i);
        
        if(c == '\\' && _i + 1 < _len)
        {
            ushort next = StringGetCharacter(s, _i + 1);
            switch(next)
            {
                case '"':  _result += "\""; _i += 2; break;
                case '\\': _result += "\\"; _i += 2; break;
                case '/':  _result += "/"; _i += 2; break;
                case 'b':  _result += ShortToString(8); _i += 2; break;  // backspace
                case 'f':  _result += ShortToString(12); _i += 2; break; // form feed
                case 'n':  _result += "\n"; _i += 2; break;
                case 'r':  _result += "\r"; _i += 2; break;
                case 't':  _result += "\t"; _i += 2; break;
                case 'u':
                {
                    if(_i + 5 < _len)
                    {
                        string hex = StringSubstr(s, _i + 2, 4);
                        int code = 0;
                        for(int _j = 0; _j < 4; _j++)
                        {
                            ushort h = StringGetCharacter(hex, _j);
                            int val = 0;
                            if(h >= '0' && h <= '9') val = h - '0';
                            else if(h >= 'a' && h <= 'f') val = h - 'a' + 10;
                            else if(h >= 'A' && h <= 'F') val = h - 'A' + 10;
                            code = code * 16 + val;
                        }
                        _result += ShortToString((ushort)code);
                        _i += 6;
                    }
                    else
                    {
                        _result += ShortToString(c);
                        _i++;
                    }
                    break;
                }
                default:
                    _result += ShortToString(c);
                    _i++;
                    break;
            }
        }
        else
        {
            _result += ShortToString(c);
            _i++;
        }
    }
    
    return _result;
}

//+------------------------------------------------------------------+
