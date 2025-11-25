//+------------------------------------------------------------------+
//|                                           TheMarketRobo_SDK.mqh |
//|                        Copyright 2024, The Market Robo Inc. |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, The Market Robo Inc."
#property link      "https://themarketrobo.com"
#property version   "1.00"

/**
 * @file TheMarketRobo_SDK.mqh
 * @brief Single-include file for The Market Robo SDK.
 *
 * This file exposes all the classes required for robot development.
 * Include this one file in your Expert Advisor.
 *
 * ## Quick Start
 * ```cpp
 * #include <TheMarketRobo_SDK.mqh>
 *
 * // Customer input parameters
 * input string InpApiKey = "";         // API Key
 * input long   InpMagicNumber = 12345; // Magic Number
 *
 * // Your robot configuration class
 * class CMyConfig : public Irobot_Config
 * {
 * private:
 *     int m_max_trades;
 *     
 * protected:
 *     virtual void define_schema() override
 *     {
 *         m_schema.add_field(
 *             CConfig_Field::create_integer("max_trades", "Max Trades", true, 5)
 *                 .with_range(1, 20)
 *         );
 *     }
 *     
 *     virtual void apply_defaults() override
 *     {
 *         m_max_trades = m_schema.get_default_int("max_trades");
 *     }
 *     
 *     // Implement remaining abstract methods...
 * };
 *
 * // Your robot class
 * class CMyRobot : public CTheMarketRobo_Bot_Base
 * {
 * public:
 *     CMyRobot() : CTheMarketRobo_Bot_Base(
 *         "your-robot-version-uuid-here",
 *         new CMyConfig()
 *     ) {}
 *     
 *     virtual void on_tick() override { }
 *     virtual void on_config_changed(string event_json) override { }
 *     virtual void on_symbol_changed(string event_json) override { }
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
 * void OnChartEvent(const int id, const long& l, const double& d, const string& s) 
 * { robot.on_chart_event(id, l, d, s); }
 * ```
 */

//=============================================================================
// Configuration Schema Classes (for defining robot config schema in code)
//=============================================================================
#include "Models/CConfig_Field.mqh"     // Field types: integer, decimal, boolean, radio, multiple
#include "Models/CConfig_Schema.mqh"    // Schema container for all fields

//=============================================================================
// Developer-facing Interfaces and Base Classes
//=============================================================================
#include "Interfaces/Irobot_Config.mqh"  // Abstract config class with schema support
#include "CTheMarketRobo_Bot_Base.mqh"   // Main robot base class

//=============================================================================
// SDK Constants (for reference)
//=============================================================================
#include "Core/CSDK_Constants.mqh"       // SDK version, API URLs, defaults
