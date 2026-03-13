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
#include "CWinINetHttpService.mqh"

#define HTTP_TIMEOUT 5000

/**
 * @class CHttpResponse
 * @brief Represents the response from an HTTP request.
 */
class CHttpResponse : public CObject
{
public:
    int code;
    string body;
    CJAVal* json_body;

    CHttpResponse();
    ~CHttpResponse();
};

//+------------------------------------------------------------------+
CHttpResponse::CHttpResponse() : code(0), body(""), json_body(NULL) {}

//+------------------------------------------------------------------+
CHttpResponse::~CHttpResponse() 
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
class CHttpService : public CObject
{
private:
    string m_base_url;
    bool m_enable_logging;
    ENUM_SDK_PRODUCT_TYPE m_product_type;
    string m_wininet_host;
    string m_wininet_base_path;
    int    m_wininet_port;

    CHttpResponse* post_webrequest(string endpoint, string jwt_token, string &data);
    CHttpResponse* post_wininet(string endpoint, string jwt_token, string &data);

public:
    CHttpService(ENUM_SDK_PRODUCT_TYPE product_type = PRODUCT_TYPE_ROBOT);
    ~CHttpService();

    CHttpResponse* post(string endpoint, string jwt_token, string &data);
    string get_base_url() const;
    void set_logging(bool enable);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CHttpService::CHttpService(ENUM_SDK_PRODUCT_TYPE product_type)
{
    m_base_url = SDK_API_BASE_URL;
    m_enable_logging = true;
    m_product_type = product_type;
    m_wininet_host = "";
    m_wininet_base_path = "";
    m_wininet_port = 443;

    if(m_product_type == PRODUCT_TYPE_INDICATOR)
    {
        WinINetParseUrl(m_base_url, m_wininet_host, m_wininet_base_path, m_wininet_port);
        if(SDKShouldLogInfo())
        {
            Print("SDK Info: API Base URL = ", m_base_url, " (using WinINet for indicator)");
            Print("SDK Info: WinINet target: ", m_wininet_host, ":", m_wininet_port);
        }
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
CHttpService::~CHttpService()
{
}

//+------------------------------------------------------------------+
//| Get base URL                                                      |
//+------------------------------------------------------------------+
string CHttpService::get_base_url() const
{
    return m_base_url;
}

//+------------------------------------------------------------------+
//| Set logging enabled/disabled                                      |
//+------------------------------------------------------------------+
void CHttpService::set_logging(bool enable)
{
    m_enable_logging = enable;
}

//+------------------------------------------------------------------+
//| Send POST request — dispatches to WebRequest or WinINet          |
//+------------------------------------------------------------------+
CHttpResponse* CHttpService::post(string endpoint, string jwt_token, string &data)
{
    if(m_product_type == PRODUCT_TYPE_INDICATOR)
        return post_wininet(endpoint, jwt_token, data);
    return post_webrequest(endpoint, jwt_token, data);
}

//+------------------------------------------------------------------+
//| POST via built-in WebRequest (EAs and scripts only)              |
//+------------------------------------------------------------------+
CHttpResponse* CHttpService::post_webrequest(string endpoint, string jwt_token, string &data)
{
    char post_data[];
    char result[];
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
        Print("Headers: \n", headers);
        Print("Body: \n", data);
        Print("============================================================");
    }

    StringToCharArray(data, post_data, 0, StringLen(data), CP_UTF8);

    CHttpResponse* response = new CHttpResponse();
    if(response == NULL) return NULL;

    int res = WebRequest("POST", m_base_url + endpoint, headers, HTTP_TIMEOUT, post_data, result, response_headers);

    if(res == -1)
    {
        response.code = -1;
        response.body = "WebRequest failed. Error code: " + (string)GetLastError();
        if(m_enable_logging)
        {
            Print("============================================================");
            Print("| HTTP REQUEST FAILED                                       |");
            Print("============================================================");
            Print("Error: ", response.body);
            Print("============================================================");
        }
    }
    else
    {
        response.code = res;
        response.body = CharArrayToString(result, 0, -1, CP_UTF8);
        
        if(m_enable_logging && SDKShouldLogDebug())
        {
            Print("============================================================");
            Print("| HTTP RESPONSE RECEIVED                                    |");
            Print("============================================================");
            Print("Status Code: ", res);
            Print("Body: \n", response.body);
            Print("============================================================");
        }

        CJAVal* json = new CJAVal();
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

//+------------------------------------------------------------------+
//| POST via WinINet.dll (works from indicators)                     |
//+------------------------------------------------------------------+
CHttpResponse* CHttpService::post_wininet(string endpoint, string jwt_token, string &data)
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
        Print("Headers: \n", headers_str);
        Print("Body: \n", data);
        Print("============================================================");
    }

    CHttpResponse* response = new CHttpResponse();
    if(response == NULL) return NULL;

    string response_body = "";
    int status = WinINetPost(m_wininet_host, full_path, m_wininet_port,
                              headers_str, data, response_body);

    if(status == -1)
    {
        response.code = -1;
        response.body = "WinINet request failed. Check DLL imports are enabled and network connectivity.";
        if(m_enable_logging)
        {
            Print("============================================================");
            Print("| HTTP REQUEST FAILED (WinINet)                             |");
            Print("============================================================");
            Print("Error: ", response.body);
            Print("============================================================");
        }
    }
    else
    {
        response.code = status;
        response.body = response_body;

        if(m_enable_logging && SDKShouldLogDebug())
        {
            Print("============================================================");
            Print("| HTTP RESPONSE RECEIVED (WinINet)                          |");
            Print("============================================================");
            Print("Status Code: ", status);
            Print("Body: \n", response.body);
            Print("============================================================");
        }

        CJAVal* json = new CJAVal();
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

#endif
//+------------------------------------------------------------------+

