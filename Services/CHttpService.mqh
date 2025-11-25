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

public:
    CHttpService();
    ~CHttpService();

    CHttpResponse* post(string endpoint, string jwt_token, string &data);
    string get_base_url() const;
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CHttpService::CHttpService()
{
    m_base_url = SDK_API_BASE_URL;
    Print("SDK Info: API Base URL = ", m_base_url);
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
//| Send POST request                                                 |
//+------------------------------------------------------------------+
CHttpResponse* CHttpService::post(string endpoint, string jwt_token, string &data)
{
    char post_data[];
    char result[];
    string headers = "Content-Type: application/json\r\n";
    string response_headers;
    
    if(jwt_token != "")
    {
        headers += "Authorization: Bearer " + jwt_token + "\r\n";
    }

    StringToCharArray(data, post_data, 0, StringLen(data), CP_UTF8);

    CHttpResponse* response = new CHttpResponse();
    if(response == NULL) return NULL;

    int res = WebRequest("POST", m_base_url + endpoint, headers, HTTP_TIMEOUT, post_data, result, response_headers);

    if(res == -1)
    {
        response.code = -1;
        response.body = "WebRequest failed. Error code: " + (string)GetLastError();
    }
    else
    {
        response.code = res;
        response.body = CharArrayToString(result, 0, -1, CP_UTF8);
        
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

