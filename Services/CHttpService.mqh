//+------------------------------------------------------------------+
//|                                                 CHttpService.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CHTTP_SERVICE_MQH
#define CHTTP_SERVICE_MQH

#include <Object.mqh>
#include "Json.mqh"
#include "../Core/CSDKConstants.mqh"
#include "../Utils/CSDKLogger.mqh"
#include "../Utils/CSDKUserErrors.mqh"

//--- WinINet transport (indicators only) -----------------------------------
//  CWinINetHttpService.mqh carries `#import "kernel32.dll"` and
//  `#import "wininet.dll"`. MetaEditor records an import table entry for every
//  imported DLL in the compiled binary whether or not the code runs, so an EA
//  that only ever uses WebRequest() still ships as a product the terminal
//  reports as requiring DLL imports — and a customer running with "Allow DLL
//  imports" off sees the warning on a robot that does not need one.
//
//  An EA (or script) that will never take the indicator path can define
//  TMKR_NO_WININET *before* including the SDK. The include, the dispatch and
//  post_wininet() are then all compiled out and the two #import blocks never
//  reach the binary. Indicators must NOT define it: WebRequest() returns 4014
//  from indicator context, so WinINet is the only transport they have.
#ifndef TMKR_NO_WININET
#include "CWinINetHttpService.mqh"
#endif

#define HTTP_TIMEOUT 5000

//--- Credential redaction for logging (MQL52026#215) ------------------------
//  The debug prints in this file echo request headers and request/response
//  bodies to the Experts log, and those logs are kept (MT-CVS keeps them on
//  box #3). Every such print goes through TmrRedactForLog(), which masks the
//  token after "Bearer " and the string value of every credential key the SDK
//  sends or receives: api_key (/robot/start), jwt_token (/robot/refresh), jwt
//  (both responses) and the generic token names.
//  Plain StringFind/StringSubstr/StringGetCharacter only, so the same code
//  compiles as MQL4 and MQL5. Every StringSubstr prefix length below is > 0
//  by construction: MQL4 reads a length of 0 as "to the end of the string".

bool TmrIsJsonSpace(ushort tmkr_c)
{
    return (tmkr_c == ' ' || tmkr_c == '\t' || tmkr_c == '\n' || tmkr_c == '\r');
}

//--- "Bearer <token>" -> "Bearer ***"; the token runs to a space, quote or line end
string TmrRedactBearer(string tmkr_text)
{
    string tmkr_out = tmkr_text;
    string tmkr_scheme = "Bearer ";
    int tmkr_from = 0;
    while(tmkr_from < StringLen(tmkr_out))
    {
        int tmkr_at = StringFind(tmkr_out, tmkr_scheme, tmkr_from);
        if(tmkr_at < 0)
            break;
        int tmkr_len = StringLen(tmkr_out);
        int tmkr_start = tmkr_at + StringLen(tmkr_scheme);
        int tmkr_end = tmkr_start;
        while(tmkr_end < tmkr_len)
        {
            ushort tmkr_c = StringGetCharacter(tmkr_out, tmkr_end);
            if(TmrIsJsonSpace(tmkr_c) || tmkr_c == '"')
                break;
            tmkr_end++;
        }
        tmkr_from = tmkr_start;
        if(tmkr_end > tmkr_start)
        {
            string tmkr_tail = "";
            if(tmkr_end < tmkr_len)
                tmkr_tail = StringSubstr(tmkr_out, tmkr_end);
            tmkr_out = StringSubstr(tmkr_out, 0, tmkr_start) + "***" + tmkr_tail;
            tmkr_from = tmkr_start + 3;
        }
    }
    return tmkr_out;
}

//--- "<key>": "<value>" -> "<key>": "***" (string values only; null or a number is no secret)
string TmrRedactJsonValue(string tmkr_text, string tmkr_key)
{
    string tmkr_out = tmkr_text;
    string tmkr_needle = "\"" + tmkr_key + "\"";
    int tmkr_from = 0;
    while(tmkr_from < StringLen(tmkr_out))
    {
        int tmkr_at = StringFind(tmkr_out, tmkr_needle, tmkr_from);
        if(tmkr_at < 0)
            break;
        int tmkr_len = StringLen(tmkr_out);
        int tmkr_pos = tmkr_at + StringLen(tmkr_needle);
        tmkr_from = tmkr_pos;
        while(tmkr_pos < tmkr_len && TmrIsJsonSpace(StringGetCharacter(tmkr_out, tmkr_pos)))
            tmkr_pos++;
        if(tmkr_pos >= tmkr_len || StringGetCharacter(tmkr_out, tmkr_pos) != ':')
            continue;   // the name appeared as a value, not as a key
        tmkr_pos++;
        while(tmkr_pos < tmkr_len && TmrIsJsonSpace(StringGetCharacter(tmkr_out, tmkr_pos)))
            tmkr_pos++;
        if(tmkr_pos >= tmkr_len || StringGetCharacter(tmkr_out, tmkr_pos) != '"')
            continue;
        int tmkr_start = tmkr_pos + 1;
        int tmkr_end = tmkr_start;
        while(tmkr_end < tmkr_len)
        {
            ushort tmkr_c = StringGetCharacter(tmkr_out, tmkr_end);
            if(tmkr_c == '"')
                break;
            if(tmkr_c == '\\')
                tmkr_end++;   // skip the escaped character
            tmkr_end++;
        }
        tmkr_from = tmkr_start;
        if(tmkr_end > tmkr_start)
        {
            // A value cut off before its closing quote is masked to the end.
            string tmkr_tail = "";
            if(tmkr_end < tmkr_len)
                tmkr_tail = StringSubstr(tmkr_out, tmkr_end);
            tmkr_out = StringSubstr(tmkr_out, 0, tmkr_start) + "***" + tmkr_tail;
            tmkr_from = tmkr_start + 3;
        }
    }
    return tmkr_out;
}

//--- The one entry point every header/body print uses
string TmrRedactForLog(string tmkr_text)
{
    string tmkr_out = TmrRedactBearer(tmkr_text);
    tmkr_out = TmrRedactJsonValue(tmkr_out, "api_key");
    tmkr_out = TmrRedactJsonValue(tmkr_out, "token");
    tmkr_out = TmrRedactJsonValue(tmkr_out, "session_token");
    tmkr_out = TmrRedactJsonValue(tmkr_out, "access_token");
    tmkr_out = TmrRedactJsonValue(tmkr_out, "refresh_token");
    tmkr_out = TmrRedactJsonValue(tmkr_out, "jwt");
    tmkr_out = TmrRedactJsonValue(tmkr_out, "jwt_token");
    return tmkr_out;
}

/**
 * @class CHttpResponse
 * @brief Represents the response from an HTTP request.
 */
class CTMKR_HttpResponse : public CObject
{
public:
    int code;
    string body;
    CTMKR_JAVal* json_body;

    CTMKR_HttpResponse();
    ~CTMKR_HttpResponse();
};

//+------------------------------------------------------------------+
CTMKR_HttpResponse::CTMKR_HttpResponse() : code(0), body(""), json_body(NULL) {}

//+------------------------------------------------------------------+
CTMKR_HttpResponse::~CTMKR_HttpResponse() 
{
    if(CheckPointer(json_body) == POINTER_DYNAMIC)
        delete json_body;
}

/**
 * @class CHttpService
 * @brief A service class to handle HTTP web requests.
 *
 * Uses the SDK_API_BASE_URL constant for the API endpoint.
 */
class CTMKR_HttpService : public CObject
{
private:
    string m_base_url;
    bool m_enable_logging;
    ENUM_TMKR_PRODUCT_TYPE m_product_type;
    string m_wininet_host;
    string m_wininet_base_path;
    int    m_wininet_port;

    CTMKR_HttpResponse* post_webrequest(string endpoint, string jwt_token, string &tmkr_data);
#ifndef TMKR_NO_WININET
    CTMKR_HttpResponse* post_wininet(string endpoint, string jwt_token, string &tmkr_data);
#endif

public:
    CTMKR_HttpService(ENUM_TMKR_PRODUCT_TYPE product_type = PRODUCT_TYPE_ROBOT);
    ~CTMKR_HttpService();

    CTMKR_HttpResponse* post(string endpoint, string jwt_token, string &tmkr_data);
    string get_base_url() const;
    void set_logging(bool enable);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTMKR_HttpService::CTMKR_HttpService(ENUM_TMKR_PRODUCT_TYPE product_type)
{
    m_base_url = TMKR_API_BASE_URL;
    m_enable_logging = true;
    m_product_type = product_type;
    m_wininet_host = "";
    m_wininet_base_path = "";
    m_wininet_port = 443;

    if(m_product_type == PRODUCT_TYPE_INDICATOR)
    {
#ifdef TMKR_NO_WININET
        // WinINetParseUrl() lives in CWinINetHttpService.mqh, which this build
        // excluded. An indicator cannot reach the network here — post() below
        // refuses every request with TMKR-3011 and says why.
        TMKRErrorCoded(TMKR_ERR_3011,
                       "This build defines TMKR_NO_WININET, which removes the only network "
                       "transport an indicator has. Remove the #define — it is for EAs only.");
#else
        WinINetParseUrl(m_base_url, m_wininet_host, m_wininet_base_path, m_wininet_port);
        if(SDKShouldLogInfo())
        {
            Print("SDK Info: API Base URL = ", m_base_url, " (using WinINet for indicator)");
            Print("SDK Info: WinINet target: ", m_wininet_host, ":", m_wininet_port);
        }
#endif
    }
    else
    {
        if(SDKShouldLogInfo())
            Print("SDK Info: API Base URL = ", m_base_url);
    }
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTMKR_HttpService::~CTMKR_HttpService()
{
}

//+------------------------------------------------------------------+
//| Get base URL                                                      |
//+------------------------------------------------------------------+
string CTMKR_HttpService::get_base_url() const
{
    return m_base_url;
}

//+------------------------------------------------------------------+
//| Set logging enabled/disabled                                      |
//+------------------------------------------------------------------+
void CTMKR_HttpService::set_logging(bool enable)
{
    m_enable_logging = enable;
}

//+------------------------------------------------------------------+
//| Send POST request — dispatches to WebRequest or WinINet          |
//+------------------------------------------------------------------+
CTMKR_HttpResponse* CTMKR_HttpService::post(string endpoint, string jwt_token, string &tmkr_data)
{
    if(m_product_type == PRODUCT_TYPE_INDICATOR)
    {
#ifdef TMKR_NO_WININET
        CTMKR_HttpResponse* refused = new CTMKR_HttpResponse();
        if(refused == NULL) return NULL;
        refused.code = -1;
        refused.body = "Indicator transport removed at compile time by TMKR_NO_WININET.";
        TMKRErrorCoded(TMKR_ERR_3011,
                       "Indicator network request refused: this build defines TMKR_NO_WININET, "
                       "which compiles out the WinINet transport. Remove the #define and "
                       "recompile — TMKR_NO_WININET is for EAs only.");
        return refused;
#else
        return post_wininet(endpoint, jwt_token, tmkr_data);
#endif
    }
    return post_webrequest(endpoint, jwt_token, tmkr_data);
}

//+------------------------------------------------------------------+
//| POST via built-in WebRequest (EAs and scripts only)              |
//+------------------------------------------------------------------+
CTMKR_HttpResponse* CTMKR_HttpService::post_webrequest(string endpoint, string jwt_token, string &tmkr_data)
{
    char post_data[];
    char tmkr_result[];
    string headers = "Content-Type: application/json\r\n";
    string response_headers;
    
    if(jwt_token != "")
    {
        headers += "Authorization: Bearer " + jwt_token + "\r\n";
    }

    if(m_enable_logging && SDKShouldLogDebug())
    {
        Print("============================================================");
        Print("| SENDING HTTP REQUEST                                      |");
        Print("============================================================");
        Print("URL: ", m_base_url + endpoint);
        Print("Headers: \n", TmrRedactForLog(headers));
        Print("Body: \n", TmrRedactForLog(tmkr_data));
        Print("============================================================");
    }

    StringToCharArray(tmkr_data, post_data, 0, StringLen(tmkr_data), CP_UTF8);

    CTMKR_HttpResponse* response = new CTMKR_HttpResponse();
    if(response == NULL) return NULL;

    int res = WebRequest("POST", m_base_url + endpoint, headers, HTTP_TIMEOUT, post_data, tmkr_result, response_headers);

    if(res == -1)
    {
        int tmkr_err = GetLastError();
        response.code = -1;
        response.body = "WebRequest failed. Error code: " + (string)tmkr_err;
        // Always surface the TMKR code on a single Experts line so the user can
        // search it — WebRequest 4060 (URL not allow-listed) lands here.
        TMKRErrorCoded(GetCodeForMqlError(tmkr_err),
                       "WebRequest failed (MQL error " + (string)tmkr_err + "). " +
                       GetUserFriendlyErrorMessage(tmkr_err));
        if(m_enable_logging)
        {
            Print("============================================================");
            Print("| HTTP REQUEST FAILED                                       |");
            Print("============================================================");
            Print("Error: ", TmrRedactForLog(response.body));
            Print("============================================================");
        }
    }
    else
    {
        response.code = res;
        response.body = CharArrayToString(tmkr_result, 0, -1, CP_UTF8);
        
        if(m_enable_logging && SDKShouldLogDebug())
        {
            Print("============================================================");
            Print("| HTTP RESPONSE RECEIVED                                    |");
            Print("============================================================");
            Print("Status Code: ", res);
            Print("Body: \n", TmrRedactForLog(response.body));
            Print("============================================================");
        }

        CTMKR_JAVal* json = new CTMKR_JAVal();
        if(json != NULL)
        {
            if(json.parse(response.body))
            {
                response.json_body = json;
            }
            else
            {
                delete json;
            }
        }
    }

    return response;
}

#ifndef TMKR_NO_WININET
//+------------------------------------------------------------------+
//| POST via WinINet.dll (works from indicators)                     |
//+------------------------------------------------------------------+
CTMKR_HttpResponse* CTMKR_HttpService::post_wininet(string endpoint, string jwt_token, string &tmkr_data)
{
    string headers_str = "Content-Type: application/json\r\n";
    if(jwt_token != "")
        headers_str += "Authorization: Bearer " + jwt_token + "\r\n";

    string full_path = m_wininet_base_path + endpoint;
    // Normalise: avoid double slash when base_path is "/" and endpoint starts with "/"
    if(m_wininet_base_path == "/" && StringLen(endpoint) > 0 && StringGetCharacter(endpoint, 0) == '/')
        full_path = endpoint;

    if(m_enable_logging && SDKShouldLogDebug())
    {
        Print("============================================================");
        Print("| SENDING HTTP REQUEST (WinINet)                            |");
        Print("============================================================");
        Print("URL: https://", m_wininet_host, ":", m_wininet_port, full_path);
        Print("Headers: \n", TmrRedactForLog(headers_str));
        Print("Body: \n", TmrRedactForLog(tmkr_data));
        Print("============================================================");
    }

    CTMKR_HttpResponse* response = new CTMKR_HttpResponse();
    if(response == NULL) return NULL;

    string response_body = "";
    int tmkr_status = WinINetPost(m_wininet_host, full_path, m_wininet_port,
                              headers_str, tmkr_data, response_body);

    if(tmkr_status == -1)
    {
        response.code = -1;
        response.body = "WinINet request failed. Check DLL imports are enabled and network connectivity.";
        // Indicators reach the network via DLLs; surface the DLL-imports code.
        TMKRErrorCoded(TMKR_ERR_3010,
                       "Indicator network request failed. Enable 'Allow DLL imports' (indicator Properties > Common) and check connectivity.");
        if(m_enable_logging)
        {
            Print("============================================================");
            Print("| HTTP REQUEST FAILED (WinINet)                             |");
            Print("============================================================");
            Print("Error: ", TmrRedactForLog(response.body));
            Print("============================================================");
        }
    }
    else
    {
        response.code = tmkr_status;
        response.body = response_body;

        if(m_enable_logging && SDKShouldLogDebug())
        {
            Print("============================================================");
            Print("| HTTP RESPONSE RECEIVED (WinINet)                          |");
            Print("============================================================");
            Print("Status Code: ", tmkr_status);
            Print("Body: \n", TmrRedactForLog(response.body));
            Print("============================================================");
        }

        CTMKR_JAVal* json = new CTMKR_JAVal();
        if(json != NULL)
        {
            if(json.parse(response.body))
            {
                response.json_body = json;
            }
            else
            {
                delete json;
            }
        }
    }

    return response;
}
#endif // TMKR_NO_WININET

#endif
//+------------------------------------------------------------------+

