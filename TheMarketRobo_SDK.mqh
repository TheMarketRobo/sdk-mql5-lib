//+------------------------------------------------------------------+
//|                                           TheMarketRobo_SDK.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"
#property strict

/**
 * @file TheMarketRobo_SDK.mqh
 * @brief Main include file for TheMarketRobo SDK.
 *
 * Include this file in your Expert Advisor to access all SDK functionality.
 *
 * ## Quick Start
 * ```cpp
 * #include <TheMarketRobo/TheMarketRobo_SDK.mqh>
 *
 * input string InpApiKey = "";           // API Key
 * input long   InpMagicNumber = 12345;   // Magic Number
 *
 * class CMyRobotConfig : public IRobotConfig
 * {
 * public:
 *     CMyRobotConfig() { define_schema(); apply_defaults(); }
 *     virtual void define_schema() override { ... }
 *     virtual void apply_defaults() override { ... }
 *     virtual string to_json() override { ... }
 *     virtual bool update_from_json(const CJAVal &config_json) override { ... }
 *     virtual bool update_field(string field_name, string new_value) override { ... }
 *     virtual string get_field_as_string(string field_name) override { ... }
 * };
 *
 * class CMyRobot : public CTheMarketRobo_Bot_Base
 * {
 * public:
 *     CMyRobot() : CTheMarketRobo_Bot_Base("uuid-here", new CMyRobotConfig()) {}
 *     virtual void on_tick() override { ... }
 *     virtual void on_config_changed(string event_json) override { ... }
 *     virtual void on_symbol_changed(string event_json) override { ... }
 * };
 *
 * CMyRobot* robot = NULL;
 *
 * int OnInit()
 * {
 *     robot = new CMyRobot();
 *     return robot.on_init(InpApiKey, InpMagicNumber);
 * }
 *
 * void OnDeinit(const int reason) { robot.on_deinit(reason); delete robot; }
 * void OnTick() { robot.on_tick(); }
 * void OnTimer() { robot.on_timer(); }
 * void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
 * {
 *     robot.on_chart_event(id, lparam, dparam, sparam);
 * }
 * ```
 */

#ifndef THEMARKETROBO_SDK_MQH
#define THEMARKETROBO_SDK_MQH

//+------------------------------------------------------------------+
//| Core SDK Components                                               |
//+------------------------------------------------------------------+

// SDK Constants and Configuration
#include "Core/CSDKConstants.mqh"
#include "Core/CSDKOptions.mqh"

// Services
#include "Services/Json.mqh"
#include "Services/CHttpService.mqh"
#include "Services/CDataCollectorService.mqh"

// Models
#include "Models/CConfigField.mqh"
#include "Models/CConfigSchema.mqh"
#include "Models/CSessionSymbol.mqh"
#include "Models/CFinalStats.mqh"

// Interfaces
#include "Interfaces/IRobotConfig.mqh"

// Core Managers
#include "Core/CTokenManager.mqh"
#include "Core/CConfigurationManager.mqh"
#include "Core/CSymbolManager.mqh"
#include "Core/CHeartbeatManager.mqh"
#include "Core/CSessionManager.mqh"
#include "Core/CSDKContext.mqh"

// Utilities
#include "Utils/CSDK_Events.mqh"

// Main Base Class
#include "CTheMarketRobo_Bot_Base.mqh"

#endif
//+------------------------------------------------------------------+
