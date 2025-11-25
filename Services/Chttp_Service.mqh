//+------------------------------------------------------------------+
//|                                                Chttp_Service.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#ifndef CHTTP_SERVICE_MQH
#define CHTTP_SERVICE_MQH

#include <Object.mqh>
#include "Json.mqh"
#include "../Core/CSDK_Constants.mqh"

#define HTTP_TIMEOUT 5000 // 5 seconds

/**
 * @class Chttp_Response
 * @brief Represents the response from an HTTP request.
 */
class Chttp_Response : public CObject
{
public:
    int code;
    string body;
    CJAVal* json_body;

    Chttp_Response() : code(0), body(""), json_body(NULL) {}
    ~Chttp_Response() 
    {
        if(CheckPointer(json_body) == POINTER_DYNAMIC)
            delete json_body;
    }
};

/**
 * @class Chttp_Service
 * @brief A service class to handle HTTP web requests.
 *
 * Uses the SDK_API_BASE_URL constant for the API endpoint.
 */
class Chttp_Service : public CObject
{
private:
    string m_base_url;

public:
    Chttp_Service();
    ~Chttp_Service();

    Chttp_Response* post(string endpoint, string jwt_token, string &data);
    
    string get_base_url() const { return m_base_url; }
};

//+------------------------------------------------------------------+
//| Implementation                                                   |
//+------------------------------------------------------------------+
Chttp_Service::Chttp_Service()
{
    // Use SDK constant for base URL
    m_base_url = SDK_API_BASE_URL;
    Print("SDK Info: API Base URL = ", m_base_url);
}

Chttp_Service::~Chttp_Service()
{
}

/**
 * @brief Sends a POST request to a specified endpoint.
 * @param endpoint The API endpoint (e.g., "/start").
 * @param jwt_token The JWT token for authorization. Can be empty.
 * @param data The JSON string data to send in the request body.
 * @return A Chttp_Response object with the server's response.
 */
Chttp_Response* Chttp_Service::post(string endpoint, string jwt_token, string &data)
{
    char post_data[];
    char result[];
    string headers = "Content-Type: application/json\r\n";
    string response_headers; // Variable to store response headers
    if(jwt_token != "")
    {
        headers += "Authorization: Bearer " + jwt_token + "\r\n";
    }

    StringToCharArray(data, post_data, 0, StringLen(data), CP_UTF8);

    Chttp_Response* response = new Chttp_Response();
    if(response == NULL) return NULL;

    int res = WebRequest("POST", m_base_url + endpoint, headers, HTTP_TIMEOUT, post_data, result, response_headers);

    if(res == -1)
    {
        response.code = -1; // Network error
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
                delete json; // Parsing failed
            }
        }
    }

    return response;
}

#endif
//+------------------------------------------------------------------+
