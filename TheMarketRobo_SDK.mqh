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
 * Include this file in your Expert Advisor or Custom Indicator to access all SDK functionality.
 *
 * @note Programmer obligations: By using this SDK you must comply with the Programmer Obligations
 *       (see PROGRAMMER_OBLIGATIONS.md in this folder). You must not include any name, link, or
 *       address that redirects the customer to the vendor or any third party; the product must
 *       always be identified as The Market Robo with the sole URL https://www.themarketrobo.com/.
 *       You must not implement any function or behaviour that triggers after a certain time or
 *       condition (e.g. alerts or messages) that introduce or promote third parties or other programmers.
 *
 * ## Quick Start — Expert Advisor (Robot)
 * ```cpp
 * #include <TheMarketRobo/TheMarketRobo_SDK.mqh>
 *
 * input string InpApiKey      = "";      // API Key
 * input long   InpMagicNumber = 12345;   // Magic Number
 *
 * class CMyRobotConfig : public IRobotConfig { ... };
 *
 * class CMyRobot : public CTheMarketRobo_Base
 * {
 * public:
 *     CMyRobot() : CTheMarketRobo_Base("uuid-here", new CMyRobotConfig()) {}
 *     virtual void on_tick() override { ... }
 *     virtual void on_config_changed(string event_json) override { ... }
 *     virtual void on_symbol_changed(string event_json) override { ... }
 * };
 *
 * CMyRobot* robot = NULL;
 * int OnInit()    { robot = new CMyRobot(); return robot.on_init(InpApiKey, InpMagicNumber); }
 * void OnDeinit(const int reason) { robot.on_deinit(reason); delete robot; }
 * void OnTick()   { robot.on_tick(); }
 * void OnTimer()  { robot.on_timer(); }
 * void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
 *     { robot.on_chart_event(id, lparam, dparam, sparam); }
 * ```
 *
 * ## Quick Start — Custom Indicator
 * ```cpp
 * #include <TheMarketRobo/TheMarketRobo_SDK.mqh>
 *
 * input string InpApiKey = "";           // API Key
 *
 * class CMyIndicator : public CTheMarketRobo_Base
 * {
 * public:
 *     // No IRobotConfig needed — pass only the UUID
 *     CMyIndicator() : CTheMarketRobo_Base("uuid-here") {}
 *     virtual int on_calculate(const int rates_total, const int prev_calculated,
 *                              const datetime &time[], const double &open[],
 *                              const double &high[], const double &low[],
 *                              const double &close[], const long &tick_volume[],
 *                              const long &volume[], const int &spread[]) override
 *     { ... return rates_total; }
 * };
 *
 * CMyIndicator* indicator = NULL;
 * int OnInit()    { indicator = new CMyIndicator(); return indicator.on_init(InpApiKey); }
 * void OnDeinit(const int reason) { indicator.on_deinit(reason); delete indicator; }
 * int OnCalculate(const int rates_total, const int prev_calculated,
 *                 const datetime &time[], const double &open[], const double &high[],
 *                 const double &low[], const double &close[], const long &tick_volume[],
 *                 const long &volume[], const int &spread[])
 *     { return indicator.on_calculate(rates_total, prev_calculated, time, open, high, low,
 *                                     close, tick_volume, volume, spread); }
 * void OnTimer()  { indicator.on_timer(); }
 * void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
 *     { indicator.on_chart_event(id, lparam, dparam, sparam); }
 * ```
 *
 * ## Backwards Compatibility
 * CTheMarketRobo_Bot_Base is still available as a typedef alias for CTheMarketRobo_Base.
 * Existing robots require NO code changes.
 */

#ifndef THEMARKETROBO_SDK_MQH
#define THEMARKETROBO_SDK_MQH

//+------------------------------------------------------------------+
//| Core SDK Components                                               |
//+------------------------------------------------------------------+

// SDK Constants — always included (contains SDK_ENABLED toggle)
#include "Core/CSDKConstants.mqh"

// ----- Always compiled (pure data structures, no network/DLL code) -----

// JSON parser
#include "Services/Json.mqh"

// Models
#include "Models/CConfigField.mqh"
#include "Models/CConfigSchema.mqh"
#include "Models/CSessionSymbol.mqh"
#include "Models/CFinalStats.mqh"

// Interfaces (developer config classes extend IRobotConfig)
#include "Interfaces/IRobotConfig.mqh"

// Logger (global log level + level-check helpers — include before other utils)
#include "Utils/CSDKLogger.mqh"

// Utilities (events, error messages)
#include "Utils/CSDK_Events.mqh"
#include "Utils/CSDKUserErrors.mqh"

// ----- Only compiled when SDK is enabled (network, managers, DLLs) -----

#ifdef SDK_ENABLED

// SDK Options
#include "Core/CSDKOptions.mqh"

// HTTP Services (includes WinINet DLL imports for indicators)
#include "Services/CHttpService.mqh"
#include "Services/CDataCollectorService.mqh"

// Core Managers
#include "Core/CTokenManager.mqh"
#include "Core/CConfigurationManager.mqh"
#include "Core/CSymbolManager.mqh"
#include "Core/CHeartbeatManager.mqh"
#include "Core/CSessionManager.mqh"
#include "Core/CSDKContext.mqh"

#endif // SDK_ENABLED

// Unified Base Class (supports both robots and indicators)
// Contains full implementation when SDK_ENABLED, lightweight stub otherwise
#include "CTheMarketRobo_Base.mqh"

// Backwards-compatibility alias — existing robots using CTheMarketRobo_Bot_Base compile unchanged
#include "CTheMarketRobo_Bot_Base.mqh"

#endif // THEMARKETROBO_SDK_MQH
//+------------------------------------------------------------------+

