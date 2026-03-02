//+------------------------------------------------------------------+
//|                                     CTheMarketRobo_Bot_Base.mqh |
//|                        Copyright 2024, The Market Robo Inc.      |
//|                                        https://themarketrobo.com |
//+------------------------------------------------------------------+
/**
 * @file CTheMarketRobo_Bot_Base.mqh
 * @brief Backwards-compatibility alias for CTheMarketRobo_Base.
 *
 * This file is kept so that existing Expert Advisors that extend
 * CTheMarketRobo_Bot_Base require NO code changes.
 *
 * For new projects, include CTheMarketRobo_Base.mqh directly and
 * extend CTheMarketRobo_Base instead.
 */
#ifndef CTHEMARKETROBO_BOT_BASE_MQH
#define CTHEMARKETROBO_BOT_BASE_MQH

#include "CTheMarketRobo_Base.mqh"

// Alias so existing code using CTheMarketRobo_Bot_Base still compiles unchanged
#define CTheMarketRobo_Bot_Base CTheMarketRobo_Base

#endif
//+------------------------------------------------------------------+
