# TheMarketRobo SDK — Developer Integration Booklet

**A Step-by-Step Guide for MQL5 Programmers**

> Version 1.0 · February 2026
> Copyright © 2024-2026, The Market Robo Inc.
> https://themarketrobo.com

---

## Table of Contents

1. [Welcome](#1-welcome)
2. [What Is TheMarketRobo SDK?](#2-what-is-themarketrobo-sdk)
3. [Prerequisites](#3-prerequisites)
4. [Installation](#4-installation)
5. [Architecture Overview](#5-architecture-overview)
6. [Quick Start — Your First Integration in 15 Minutes](#6-quick-start--your-first-integration-in-15-minutes)
7. [Step-by-Step: Building Your Configuration Class](#7-step-by-step-building-your-configuration-class)
8. [Step-by-Step: Building Your Robot Class](#8-step-by-step-building-your-robot-class)
9. [Step-by-Step: Wiring Up the MQL5 Event Handlers](#9-step-by-step-wiring-up-the-mql5-event-handlers)
10. [Field Types Reference](#10-field-types-reference)
11. [Advanced Features](#11-advanced-features)
12. [SDK Lifecycle — What Happens Under the Hood](#12-sdk-lifecycle--what-happens-under-the-hood)
13. [Error Handling & Troubleshooting](#13-error-handling--troubleshooting)
14. [Best Practices & Tips](#14-best-practices--tips)
15. [Complete Template — Copy & Customize](#15-complete-template--copy--customize)
16. [FAQ](#16-faq)
17. [Glossary](#17-glossary)

---

## 1. Welcome

Welcome to TheMarketRobo SDK integration guide! This booklet will teach you, step by step, how to integrate MQL5 **Expert Advisors (EAs)** and **Custom Indicators** with TheMarketRobo platform.

**Who is this for?**
- MQL5 developers who have (or want to build) an EA or Custom Indicator
- Beginner to intermediate programmers who want to connect their robot or indicator to TheMarketRobo cloud dashboard
- Vendors who want to distribute their robots or indicators through TheMarketRobo marketplace

**What you will learn:**
- How to install the SDK files
- How to define a configuration schema (EAs only) so customers can adjust your robot's settings from the web dashboard
- How to handle real-time configuration and symbol changes from the server (EAs only)
- How to properly initialize, run, and shut down the SDK alongside your EA or Indicator
- How **Custom Indicators** use the same base class with a simpler flow (no config, no magic number)

**What you will NOT need:**
- You do **not** need to write any HTTP, networking, or JSON code
- You do **not** need to understand JWT tokens or authentication
- You do **not** need to change your trading logic

The SDK handles all of that for you. You just need to tell it **what your settings are** and **what to do when they change**.

---

## 2. What Is TheMarketRobo SDK?

TheMarketRobo SDK is a **library** that you include in your MQL5 **Expert Advisor or Custom Indicator**. It creates a **live connection** between your program running on MetaTrader 5 and TheMarketRobo cloud platform.

**Supported product types:**
- **Expert Advisor (Robot)** — Full integration: config schema, magic number, session symbols, remote config and symbol changes.
- **Custom Indicator** — Same base class (`CTheMarketRobo_Base`) with a **one-argument constructor** (indicator version UUID only); no config class, no magic number, no config/symbol change requests; session registration and heartbeats only.

This connection allows:

| Feature | Description |
|---|---|
| **Remote Configuration** | Customers change robot settings from a web dashboard (no need to restart the EA) |
| **Symbol Management** | Customers can enable/disable trading symbols remotely |
| **Session Monitoring** | Real-time heartbeats report account balance, equity, drawdown, and profit |
| **Authentication** | Secure JWT-based authentication with automatic token refresh |
| **Graceful Shutdown** | Server can request the EA/Indicator to stop; the EA reports final stats; Indicators stop the timer and alert the user (no self-removal API) |

```
┌─────────────────────┐         ┌──────────────────────────┐
│   MetaTrader 5      │         │  TheMarketRobo Cloud     │
│                     │         │                          │
│  ┌───────────────┐  │  HTTPS  │  ┌────────────────────┐  │
│  │ Your EA or    │  │◄───────►│  │ Customer Dashboard │  │
│  │ Indicator     │  │         │  └────────────────────┘  │
│  │  + SDK        │  │         │                          │
│  └───────────────┘  │         │                          │
└─────────────────────┘         └──────────────────────────┘
```

---

## 3. Prerequisites

Before starting, make sure you have:

- [x] **MetaTrader 5** installed and running
- [x] **MetaEditor** for writing MQL5 code
- [x] **An existing EA or Custom Indicator** that you want to integrate (or a new project)
- [x] **API Key** from TheMarketRobo platform (you'll get this after registration)
- [x] **Robot Version UUID** or **Indicator Version UUID** assigned on the platform (same UUID field in API; use it in the one-arg constructor for indicators, two-arg for EAs)

> [!IMPORTANT]
> You must add TheMarketRobo API URL to MetaTrader's "Allowed URLs" list.
> Go to: **Tools → Options → Expert Advisors → Allow WebRequest for listed URL:**
> Add: `https://api.staging.themarketrobo.com` (staging) or `https://api.themarketrobo.com` (production)

> **Local testing:** Generate a new **test license** from your Vendor Portal and use its API key for development. Use the staging URL above; do not use production licenses for testing.

**Documentation scope — data covered here vs elsewhere**
- **This booklet:** Integration steps, config schema (EAs), callbacks, lifecycle, token/heartbeat defaults, Indicator vs EA differences, troubleshooting, template. All code samples and constants (e.g. token refresh 60s, heartbeat 60s max 300s) match the SDK source.
- **Not covered in detail here (see API_REFERENCE.md and docs/api/important-notes.md):** Exact request/response JSON for `/robot/start`, `/robot/heartbeat`, `/robot/refresh`, `/robot/end`; full list of HTTP/API error codes and retry behavior; `SDK_API_BASE_URL` and staging/production URL handling inside the SDK; heartbeat payload field names and types; `CFinalStats` and shutdown reason values.

---

## 4. Installation

### Step 1 — Copy SDK Files

Copy the entire `themarketrobo` folder into your MetaTrader 5 `Include` directory:

```
MQL5/
├── Experts/
│   └── MyRobot/
│       └── MyRobot.mq5          ← Your EA file
├── Include/
│   └── themarketrobo/           ← Copy this folder here (lowercase name)
│       ├── TheMarketRobo_SDK.mqh   (main include file)
│       ├── CTheMarketRobo_Base.mqh (unified base for EAs and Indicators)
│       ├── CTheMarketRobo_Bot_Base.mqh (alias for CTheMarketRobo_Base; backwards compatibility)
│       ├── Core/
│       ├── Interfaces/
│       ├── Models/
│       ├── Services/
│       └── Utils/
```

### Step 2 — Verify Installation

In MetaEditor, create a new test file and add this line:

```mql5
#include <themarketrobo/TheMarketRobo_SDK.mqh>
```

If it compiles without errors, the SDK is installed correctly. ✅

> [!TIP]
> You only need to include **one file** — `TheMarketRobo_SDK.mqh`. It automatically includes all the other SDK components for you.

---

## 5. Architecture Overview

The SDK has a clean, layered architecture. Here's what each piece does:

```
┌──────────────────────────────────────────────────────────┐
│                    YOUR EXPERT ADVISOR                    │
│  ┌─────────────────────┐  ┌─────────────────────────┐   │
│  │  YourRobotConfig    │  │  YourBot / YourIndicator│   │
│  │  (extends           │  │  (extends               │   │
│  │   IRobotConfig)     │  │   CTheMarketRobo_Base)   │   │
│  └──────────┬──────────┘  └──────────┬──────────────┘   │
└─────────────┼───────────────────────┼───────────────────┘
              │ YOUR CODE ABOVE       │
──────────────┼───────────────────────┼─── SDK BOUNDARY ───
              │ SDK CODE BELOW        │
┌─────────────┼───────────────────────┼───────────────────┐
│  ┌──────────▼───────────────────────▼──────────────┐    │
│  │              CSDKContext (orchestrator)          │    │
│  │  ┌──────────────┐  ┌────────────────────────┐   │    │
│  │  │ SessionMgr   │  │ HeartbeatMgr           │   │    │
│  │  │ (start/end)  │  │ (periodic pings)       │   │    │
│  │  ├──────────────┤  ├────────────────────────┤   │    │
│  │  │ TokenMgr     │  │ ConfigMgr              │   │    │
│  │  │ (JWT auth)   │  │ (setting changes)      │   │    │
│  │  ├──────────────┤  ├────────────────────────┤   │    │
│  │  │ SymbolMgr    │  │ DataCollector          │   │    │
│  │  │ (watchlist)  │  │ (account/terminal)     │   │    │
│  │  └──────────────┘  └────────────────────────┘   │    │
│  └─────────────────────────────────────────────────┘    │
│  ┌───────────────────────────────────────────────────┐  │
│  │  HttpService  │  Json  │  Events  │  Constants    │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**As a developer, you only interact with two classes:**
1. **`IRobotConfig`** — Define your robot's configurable settings (**Expert Advisors only**; Custom Indicators do not use this)
2. **`CTheMarketRobo_Base`** — Your EA or Custom Indicator class extends this base. (The name `CTheMarketRobo_Bot_Base` is an alias and works the same for EAs.)

Everything else (HTTP calls, heartbeats, tokens, JSON) is handled automatically.

---

## 6. Quick Start — Your First Integration in 15 Minutes

Here is the **minimum viable integration**. We'll explain each part in detail later.

```mql5
//+------------------------------------------------------------------+
//| MyRobot.mq5 — Minimal SDK Integration                            |
//+------------------------------------------------------------------+
#include <themarketrobo/TheMarketRobo_SDK.mqh>

// ===== INPUT PARAMETERS =====
input string InpApiKey = "";  // API Key (from TheMarketRobo dashboard)

// ===== CONSTANTS =====
const string ROBOT_VERSION_UUID = "your-uuid-here";  // From TheMarketRobo

// ===== STEP 1: Configuration Class =====
class CMyConfig : public IRobotConfig
{
private:
    double m_lot_size;

public:
    CMyConfig() : IRobotConfig()
    {
        define_schema();
        apply_defaults();
    }
    ~CMyConfig() {}

    virtual void define_schema() override
    {
        if(CheckPointer(m_schema) == POINTER_INVALID) return;

        m_schema.add_field(
            CConfigField::create_decimal("lot_size", "Lot Size", true, 0.01)
                .with_range(0.01, 10.0)
                .with_step(0.01)
                .with_precision(2)
                .with_description("Trade size in lots")
                .with_group("Risk", 1)
        );
    }

    virtual void apply_defaults() override
    {
        m_lot_size = 0.01;
    }

    virtual string to_json() override
    {
        CJAVal config(JA_OBJECT);
        CJAVal* v = new CJAVal(); v.set_double(m_lot_size);
        config.Add("lot_size", v);
        return config.serialize();
    }

    virtual bool update_from_json(const CJAVal &config_json) override
    {
        if(config_json.has_key("lot_size"))
            m_lot_size = config_json["lot_size"].get_double();
        return true;
    }

    virtual bool update_field(string field_name, string new_value) override
    {
        if(field_name == "lot_size")
        {
            m_lot_size = StringToDouble(new_value);
            return true;
        }
        return false;
    }

    virtual string get_field_as_string(string field_name) override
    {
        if(field_name == "lot_size")
            return DoubleToString(m_lot_size, 2);
        return "";
    }

    // Getter for your trading logic
    double get_lot_size() const { return m_lot_size; }
};


// ===== STEP 2: Robot Class =====
// You can use CTheMarketRobo_Base or the alias CTheMarketRobo_Bot_Base; both refer to the same class.
class CMyBot : public CTheMarketRobo_Base
{
public:
    CMyBot() : CTheMarketRobo_Base(ROBOT_VERSION_UUID, new CMyConfig())
    {
    }
    ~CMyBot() {}

    virtual void on_tick() override
    {
        // *** YOUR TRADING LOGIC GOES HERE ***
        // Use ((CMyConfig*)m_robot_config).get_lot_size()
        // to access the current lot size
    }

    virtual void on_config_changed(string event_json) override
    {
        Print("Config changed! Details: ", event_json);
        // The SDK already applied the change.
        // React here if needed (e.g. recalculate indicators).
    }

    virtual void on_symbol_changed(string event_json) override
    {
        Print("Symbol changed! Details: ", event_json);
    }
};


// ===== STEP 3: Global Variable =====
CMyBot* g_robot = NULL;


// ===== STEP 4: MQL5 Event Handlers =====
int OnInit()
{
    if(InpApiKey == "")
    {
        Alert("API Key is required!");
        return INIT_PARAMETERS_INCORRECT;
    }

    MathSrand((int)TimeLocal());
    long magic = MathRand() * MathRand() + (long)GetTickCount();

    g_robot = new CMyBot();
    if(CheckPointer(g_robot) == POINTER_INVALID) return INIT_FAILED;

    int result = g_robot.on_init(InpApiKey, magic);
    if(result != INIT_SUCCEEDED) return result;

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    if(CheckPointer(g_robot) != POINTER_INVALID)
    {
        g_robot.on_deinit(reason);
        delete g_robot;
        g_robot = NULL;
    }
}

void OnTick()
{
    if(CheckPointer(g_robot) != POINTER_INVALID)
        g_robot.on_tick();
}

void OnTimer()
{
    if(CheckPointer(g_robot) != POINTER_INVALID)
        g_robot.on_timer();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if(CheckPointer(g_robot) != POINTER_INVALID)
        g_robot.on_chart_event(id, lparam, dparam, sparam);
}
```

That's it for Expert Advisors! Compile and attach to a chart with a valid API key.

---

## 6.5 Quick Start — Your First Indicator in 15 Minutes

The process is simpler for a **Custom Indicator**: use the same base class with the **one-argument constructor** (indicator version UUID only). No config class and no magic number; the SDK handles session registration and heartbeats only.

```mql5
//+------------------------------------------------------------------+
//| MyIndicator.mq5 — Minimal SDK Integration                        |
//+------------------------------------------------------------------+
#include <themarketrobo/TheMarketRobo_SDK.mqh>

// ===== INPUT PARAMETERS =====
input string InpApiKey = "";  // API Key (from TheMarketRobo dashboard)

// ===== CONSTANTS =====
const string INDICATOR_VERSION_UUID = "your-uuid-here";  // From TheMarketRobo (indicator version)

// ===== STEP 1: Indicator Class =====
class CMyIndicator : public CTheMarketRobo_Base
{
public:
    CMyIndicator() : CTheMarketRobo_Base(INDICATOR_VERSION_UUID) {}  // One-arg constructor only
    ~CMyIndicator() {}

    virtual int on_calculate(const int rates_total, const int prev_calculated,
                             const datetime &time[], const double &open[],
                             const double &high[], const double &low[],
                             const double &close[], const long &tick_volume[],
                             const long &volume[], const int &spread[]) override
    {
        // *** YOUR CUSTOM INDICATOR LOGIC GOES HERE ***
        return rates_total;
    }
};

// ===== STEP 2: Global Variable =====
CMyIndicator* g_indicator = NULL;

// ===== STEP 3: MQL5 Event Handlers =====
int OnInit()
{
    if(InpApiKey == "")
    {
        Alert("API Key is required!");
        return INIT_PARAMETERS_INCORRECT;
    }

    g_indicator = new CMyIndicator();
    if(CheckPointer(g_indicator) == POINTER_INVALID) return INIT_FAILED;

    // No magic number required for custom indicators
    return g_indicator.on_init(InpApiKey);
}

void OnDeinit(const int reason)
{
    if(CheckPointer(g_indicator) != POINTER_INVALID)
    {
        g_indicator.on_deinit(reason);
        delete g_indicator;
        g_indicator = NULL;
    }
}

void OnTimer()
{
    if(CheckPointer(g_indicator) != POINTER_INVALID) g_indicator.on_timer();
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[],
                const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
{
    if(CheckPointer(g_indicator) != POINTER_INVALID)
        return g_indicator.on_calculate(rates_total, prev_calculated, time, open, high, low, close, tick_volume, volume, spread);
    return rates_total;
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(CheckPointer(g_indicator) != POINTER_INVALID) g_indicator.on_chart_event(id, lparam, dparam, sparam);
}
```

That's it for Indicators! Compile and attach to a chart with a valid API key.

---

## 7. Step-by-Step: Building Your Configuration Class

The **configuration class** is the most important part of your integration. It tells TheMarketRobo what settings your robot has, so customers can adjust them from the web dashboard.

### 7.1 — Create the Class

Your config class must extend `IRobotConfig` and implement **six methods**:

```mql5
class CMyConfig : public IRobotConfig
{
public:
    // Required: constructor MUST call define_schema() then apply_defaults()
    CMyConfig() : IRobotConfig()
    {
        define_schema();      // Tell the SDK about your fields
        apply_defaults();     // Set the initial values
    }

    virtual void   define_schema() override;
    virtual void   apply_defaults() override;
    virtual string to_json() override;
    virtual bool   update_from_json(const CJAVal &config_json) override;
    virtual bool   update_field(string field_name, string new_value) override;
    virtual string get_field_as_string(string field_name) override;
};
```

| Method | Purpose | When the SDK calls it |
|---|---|---|
| `define_schema()` | Declares field names, types, ranges, defaults | Once, during constructor |
| `apply_defaults()` | Sets your member variables to default values | Once, during constructor |
| `to_json()` | Serializes current config → JSON string | When reporting to server |
| `update_from_json()` | Bulk update from server JSON | When session starts |
| `update_field()` | Update a single field by name | When a config change is received |
| `get_field_as_string()` | Return any field as a string | For SDK validation |

### 7.2 — Declaring Member Variables

For every setting your robot has, declare a private member variable:

```mql5
class CMyConfig : public IRobotConfig
{
private:
    // Numeric settings
    int    m_max_trades;           // How many trades to open at once
    double m_lot_size;             // Trade size
    double m_stop_loss_pips;       // Stop loss distance

    // Boolean settings
    bool   m_use_trailing_stop;    // Enable/disable feature

    // Selection settings
    string m_strategy;             // "scalping", "swing", etc.

    // Multi-select settings
    string m_active_sessions[];    // Array of selected options

    // ...more fields as needed
};
```

### 7.3 — Defining the Schema

Inside `define_schema()`, you use the **builder pattern** to define each field. The SDK provides five field types:

#### Integer Field

```mql5
m_schema.add_field(
    CConfigField::create_integer("max_trades", "Maximum Trades", true, 5)
        .with_range(1, 50)          // Min and max values
        .with_step(1)               // Increment step
        .with_description("Maximum concurrent trades")
        .with_tooltip("Recommended: 3-10 for beginners")
        .with_group("Risk Management", 1)  // Group name + order within group
);
```

#### Decimal Field

```mql5
m_schema.add_field(
    CConfigField::create_decimal("lot_size", "Lot Size", true, 0.01)
        .with_range(0.01, 10.0)
        .with_step(0.01)
        .with_precision(2)          // Decimal places
        .with_description("Trade size in lots")
        .with_group("Risk Management", 2)
);
```

#### Boolean Field

```mql5
m_schema.add_field(
    CConfigField::create_boolean("use_trailing", "Use Trailing Stop", true, false)
        .with_description("Enable trailing stop loss")
        .with_group("Advanced", 1)
);
```

#### Radio Field (Single Selection)

```mql5
m_schema.add_field(
    CConfigField::create_radio("strategy", "Trading Strategy", true, "scalping")
        .with_option("scalping", "Scalping")        // value, label
        .with_option("swing", "Swing Trading")
        .with_option("position", "Position Trading")
        .with_description("Select your trading strategy")
        .with_group("Strategy", 1)
);
```

#### Multiple Field (Multi Selection)

```mql5
string defaults[];
ArrayResize(defaults, 2);
defaults[0] = "london";
defaults[1] = "newyork";

m_schema.add_field(
    CConfigField::create_multiple("sessions", "Trading Sessions", true)
        .with_option("tokyo", "Tokyo Session")
        .with_option("london", "London Session")
        .with_option("newyork", "New York Session")
        .with_option("sydney", "Sydney Session")
        .with_selection_limits(1, 4)       // Min 1, max 4 selections
        .with_default_selections(defaults)
        .with_description("Select active trading sessions")
        .with_group("Schedule", 1)
);
```

### 7.4 — Field Dependencies

Some fields should only appear when another field has a specific value. Use **dependencies**:

```mql5
// "trailing_distance" only shows when "use_trailing" is TRUE
CConfigDependency* dep = new CConfigDependency();
dep.set_bool_value("use_trailing", CONDITION_EQUALS, true);

m_schema.add_field(
    CConfigField::create_decimal("trailing_distance", "Trailing Distance (pips)", true, 15.0)
        .with_range(5.0, 100.0)
        .with_depends_on(dep)    // ← This is the dependency
        .with_group("Advanced", 2)
);
```

Available dependency conditions:

| Condition | Description |
|---|---|
| `CONDITION_EQUALS` | Field equals the specified value |
| `CONDITION_NOT_EQUALS` | Field does NOT equal the specified value |
| `CONDITION_GREATER_THAN` | Field is greater than (numeric) |
| `CONDITION_LESS_THAN` | Field is less than (numeric) |
| `CONDITION_GREATER_THAN_OR_EQUAL` | Field is ≥ (numeric) |
| `CONDITION_LESS_THAN_OR_EQUAL` | Field is ≤ (numeric) |
| `CONDITION_CONTAINS` | Field contains value |
| `CONDITION_NOT_CONTAINS` | Field does not contain value |

Dependency type setters:

```mql5
dep.set_string_value("field_name", CONDITION_EQUALS, "some_value");
dep.set_numeric_value("field_name", CONDITION_GREATER_THAN, 5.0);
dep.set_bool_value("field_name", CONDITION_EQUALS, true);
```

### 7.5 — Implementing apply_defaults()

Simply set each member variable to its default value:

```mql5
virtual void apply_defaults() override
{
    m_max_trades = 5;
    m_lot_size = 0.01;
    m_stop_loss_pips = 20.0;
    m_use_trailing_stop = false;
    m_strategy = "scalping";

    ArrayResize(m_active_sessions, 2);
    m_active_sessions[0] = "london";
    m_active_sessions[1] = "newyork";
}
```

> [!IMPORTANT]
> The default values in `apply_defaults()` **must match** the defaults you declared in `define_schema()`. If `create_integer(...)` says default is `5`, then `apply_defaults()` must also set the variable to `5`.

### 7.6 — Implementing to_json()

Serialize your current settings into a JSON object:

```mql5
virtual string to_json() override
{
    CJAVal config(JA_OBJECT);

    // Integer: use set_long()
    CJAVal* v1 = new CJAVal(); v1.set_long(m_max_trades);
    config.Add("max_trades", v1);

    // Decimal: use set_double()
    CJAVal* v2 = new CJAVal(); v2.set_double(m_lot_size);
    config.Add("lot_size", v2);

    // Boolean: use set_bool()
    CJAVal* v3 = new CJAVal(); v3.set_bool(m_use_trailing_stop);
    config.Add("use_trailing", v3);

    // String/Radio: use set_string()
    CJAVal* v4 = new CJAVal(); v4.set_string(m_strategy);
    config.Add("strategy", v4);

    // Array/Multiple: build a JA_ARRAY
    CJAVal* arr = new CJAVal(JA_ARRAY);
    for(int i = 0; i < ArraySize(m_active_sessions); i++)
    {
        CJAVal* s = new CJAVal(); s.set_string(m_active_sessions[i]);
        arr.Add(s);
    }
    config.Add("sessions", arr);

    return config.serialize();
}
```

### 7.7 — Implementing update_from_json()

This is called when the session starts and the server sends the current configuration:

```mql5
virtual bool update_from_json(const CJAVal &config_json) override
{
    // Use has_key() to safely check before reading
    if(config_json.has_key("max_trades"))
        m_max_trades = (int)config_json["max_trades"].get_long();

    if(config_json.has_key("lot_size"))
        m_lot_size = config_json["lot_size"].get_double();

    if(config_json.has_key("use_trailing"))
        m_use_trailing_stop = config_json["use_trailing"].get_bool();

    if(config_json.has_key("strategy"))
        m_strategy = config_json["strategy"].get_string();

    // For arrays: handled separately through other mechanisms

    Print("Config updated from server JSON");
    return true;
}
```

### 7.8 — Implementing update_field() and get_field_as_string()

These handle individual field changes:

```mql5
virtual bool update_field(string field_name, string new_value) override
{
    if(field_name == "max_trades")
    {
        m_max_trades = (int)StringToInteger(new_value);
        return true;
    }
    if(field_name == "lot_size")
    {
        m_lot_size = StringToDouble(new_value);
        return true;
    }
    if(field_name == "use_trailing")
    {
        m_use_trailing_stop = (new_value == "true" || new_value == "1");
        return true;
    }
    if(field_name == "strategy")
    {
        m_strategy = new_value;
        return true;
    }

    Print("Unknown field: ", field_name);
    return false;
}

virtual string get_field_as_string(string field_name) override
{
    if(field_name == "max_trades")   return IntegerToString(m_max_trades);
    if(field_name == "lot_size")     return DoubleToString(m_lot_size, 2);
    if(field_name == "use_trailing") return m_use_trailing_stop ? "true" : "false";
    if(field_name == "strategy")     return m_strategy;
    return "";
}
```

### 7.9 — Adding Getter Methods

Add public getter methods so your robot class can read the current config values:

```mql5
public:
    int    get_max_trades()      const { return m_max_trades; }
    double get_lot_size()        const { return m_lot_size; }
    double get_stop_loss_pips()  const { return m_stop_loss_pips; }
    bool   get_use_trailing()    const { return m_use_trailing_stop; }
    string get_strategy()        const { return m_strategy; }
```

---

## 8. Step-by-Step: Building Your Robot Class

### 8.1 — Extend The Base Class

Your EA class extends **CTheMarketRobo_Base** (or the alias **CTheMarketRobo_Bot_Base**). The base class provides **default empty implementations** for the three callbacks, so you override them in your EA; they are not pure virtual.

```mql5
class CMyBot : public CTheMarketRobo_Base
{
public:
    CMyBot();
    ~CMyBot();

    // Override these three methods for your EA:
    virtual void on_tick() override;
    virtual void on_config_changed(string event_json) override;
    virtual void on_symbol_changed(string event_json) override;

    // Optional: override for custom termination handling (default: Alert + ExpertRemove)
    // virtual void on_termination_requested(string event_json) override;
};
```

### 8.2 — Constructor

The constructor **must** call the parent constructor with two arguments:
1. Your **Robot Version UUID** (string)
2. A **new instance** of your config class (pointer)

```mql5
CMyBot::CMyBot()
    : CTheMarketRobo_Base(ROBOT_VERSION_UUID, new CMyConfig())
{
    // Your initialization code here
    Print("My robot initialized!");
}
```

(You can also use `CTheMarketRobo_Bot_Base` — it is an alias for `CTheMarketRobo_Base`.)

> [!CAUTION]
> Use `new CMyConfig()` — the SDK takes ownership and will delete it automatically. Do NOT delete it yourself.

### 8.3 — on_tick() — Your Trading Logic

This is where your **existing trading logic** goes. The SDK does not interfere with it.

```mql5
virtual void on_tick() override
{
    // Access your config values through the m_robot_config pointer:
    CMyConfig* config = (CMyConfig*)m_robot_config;

    double lot = config.get_lot_size();
    int max  = config.get_max_trades();

    // === YOUR EXISTING TRADING LOGIC ===
    // Open trades, manage positions, etc.
    // The SDK does NOT touch your trades.
    // ===================================
}
```

### 8.4 — on_config_changed() — React to Config Changes

This method is called when a customer changes settings from the web dashboard. **The SDK has already applied the new values** to your config object before calling this method.

```mql5
virtual void on_config_changed(string event_json) override
{
    Print("Configuration changed! Details: ", event_json);

    // Example: recalculate based on new lot size
    CMyConfig* config = (CMyConfig*)m_robot_config;
    double new_lot = config.get_lot_size();
    Print("New lot size: ", new_lot);

    // Optionally alert the user
    Alert("Robot settings have been updated from the dashboard!");
}
```

**What `event_json` contains:**
```json
{
    "type": "config_change",
    "field": "lot_size",
    "old_value": "0.01",
    "new_value": "0.05"
}
```

### 8.5 — on_symbol_changed() — React to Symbol Changes

This method is called when a customer enables or disables a trading symbol from the dashboard.

```mql5
virtual void on_symbol_changed(string event_json) override
{
    Print("Symbol changed! Details: ", event_json);

    // Example: close all positions on a disabled symbol
    CJAVal event;
    if(event.parse(event_json))
    {
        string symbol  = event["symbol"].get_string();
        bool   active  = event["active_to_trade"].get_bool();

        if(!active)
        {
            Print("Symbol ", symbol, " has been disabled. Consider closing positions.");
            // Your logic to close positions for this symbol
        }
    }
}
```

### 8.6 — on_termination_requested() — Optional Override

By default, when the server requests the EA to stop, the SDK shows an alert and calls `ExpertRemove()`. For **Custom Indicators**, the default is to stop the timer (`EventKillTimer()`) and print a message asking the user to remove the indicator (indicators have no self-removal API). You can override this for custom cleanup:

```mql5
virtual void on_termination_requested(string event_json) override
{
    CJAVal event_data;
    if(event_data.parse(event_json))
    {
        string reason = event_data["reason"].get_string();
        Print("Server wants us to stop. Reason: ", reason);
    }

    // Close all open positions first (EA only)
    // ... your cleanup logic ...

    // Then remove the EA (or for Indicator: just stop timer; user removes manually)
    Alert("Shutting down as requested by server.");
    ExpertRemove();
}
```

---

## 9. Step-by-Step: Wiring Up the MQL5 Event Handlers

MQL5 uses specific event handler functions that MetaTrader calls automatically. You need to connect five of them to your robot:

### 9.1 — Global Variable

```mql5
CMyBot* g_robot = NULL;
```

### 9.2 — OnInit()

```mql5
int OnInit()
{
    // 1. Validate API Key
    if(InpApiKey == "")
    {
        Alert("API Key is required!");
        return INIT_PARAMETERS_INCORRECT;
    }

    // 2. Generate a unique magic number
    MathSrand((int)TimeLocal());
    long magic = MathRand() * MathRand() + (long)GetTickCount();

    // 3. Create robot instance
    g_robot = new CMyBot();
    if(CheckPointer(g_robot) == POINTER_INVALID)
        return INIT_FAILED;

    // 4. Initialize SDK connection
    //    This will: authenticate, collect account data,
    //    gather watchlist symbols, start the session
    int result = g_robot.on_init(InpApiKey, magic);
    if(result != INIT_SUCCEEDED)
        return result;

    Print("Robot ready and connected to TheMarketRobo!");
    return INIT_SUCCEEDED;
}
```

### 9.3 — OnDeinit()

```mql5
void OnDeinit(const int reason)
{
    if(CheckPointer(g_robot) != POINTER_INVALID)
    {
        // Gracefully end session and report final stats
        g_robot.on_deinit(reason);

        // Free memory
        delete g_robot;
        g_robot = NULL;
    }
}
```

### 9.4 — OnTick()

```mql5
void OnTick()
{
    if(CheckPointer(g_robot) != POINTER_INVALID)
        g_robot.on_tick();
}
```

### 9.5 — OnTimer()

```mql5
void OnTimer()
{
    if(CheckPointer(g_robot) != POINTER_INVALID)
        g_robot.on_timer();
}
```

> [!NOTE]
> The SDK automatically sets up a 1-second timer during `on_init()`. The timer handles heartbeats and token refreshing. **Do not call `EventKillTimer()`** yourself — the SDK manages it.

### 9.6 — OnChartEvent()

```mql5
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if(CheckPointer(g_robot) != POINTER_INVALID)
        g_robot.on_chart_event(id, lparam, dparam, sparam);
}
```

> [!IMPORTANT]
> The SDK uses **custom chart events** internally to dispatch config/symbol changes. If you already use `OnChartEvent` for your own purposes, make sure to call `g_robot.on_chart_event()` **first**, then handle your own events.

---

## 10. Field Types Reference

| Type | Create Method | Value Type | Example |
|---|---|---|---|
| **Integer** | `create_integer(key, label, required, default)` | Whole numbers | Max trades: 5 |
| **Decimal** | `create_decimal(key, label, required, default)` | Floating-point | Lot size: 0.01 |
| **Boolean** | `create_boolean(key, label, required, default)` | True/False | Use trailing: false |
| **Radio** | `create_radio(key, label, required, default)` | Single selection | Strategy: "scalping" |
| **Multiple** | `create_multiple(key, label, required)` | Multi selection | Sessions: ["london","newyork"] |

### Builder Methods (available on all field types):

| Method | Description |
|---|---|
| `.with_description(text)` | Help text shown to the customer |
| `.with_tooltip(text)` | Hover tooltip text |
| `.with_placeholder(text)` | Placeholder text for input fields |
| `.with_group(name, order)` | Group name and position within the group |
| `.with_disabled(bool)` | Disable the field (read-only) |
| `.with_hidden(bool)` | Hide the field from the UI |
| `.with_range(min, max)` | Min/max constraints (integer & decimal) |
| `.with_step(value)` | Increment step (integer & decimal) |
| `.with_precision(digits)` | Decimal places (decimal only) |
| `.with_option(value, label)` | Add a selectable option (radio & multiple) |
| `.with_option_numeric(value, label)` | Add numeric option (radio & multiple) |
| `.with_selection_limits(min, max)` | Min/max selections (multiple only) |
| `.with_default_selections(arr)` | Default selected options (multiple only) |
| `.with_depends_on(dependency)` | Conditional visibility |

---

## 11. Advanced Features

### 11.1 — Disabling Config Change Requests

If you don't want the server to be able to change your config remotely:

```mql5
CMyBot::CMyBot()
    : CTheMarketRobo_Base(ROBOT_VERSION_UUID, new CMyConfig())
{
    set_enable_config_change_requests(false);
}
```

### 11.2 — Disabling Symbol Change Requests

```mql5
set_enable_symbol_change_requests(false);
```

### 11.3 — Adjusting Token Refresh Threshold

By default, the JWT token is refreshed **60 seconds** before expiration (`SDK_DEFAULT_TOKEN_REFRESH_THRESHOLD` in the SDK). You can change this:

```mql5
set_token_refresh_threshold(120);  // Refresh 120 seconds before expiration
```

Valid range: **60–3600** seconds. Call **before** `on_init()`. If you set the threshold greater than or equal to the JWT expiration time (e.g. 300 seconds), the SDK will trigger refresh immediately.

### 11.4 — Printing SDK Configuration

For debugging, you can print the current SDK configuration:

```mql5
g_robot.print_sdk_configuration();
```

Output:
```
=== SDK Configuration ===
  Robot Version UUID: 263b48b2-efae-4528-9acf-b4456d7c9e37
  API Base URL: https://api.staging.themarketrobo.com
=== SDK Options ===
  Config change requests: ENABLED
  Symbol change requests: ENABLED
  Token refresh threshold: 60 seconds
=========================
```

---

## 12. SDK Lifecycle — What Happens Under the Hood

Understanding the SDK lifecycle helps with debugging. The flow below is for **Expert Advisors**. For **Custom Indicators**, use `on_init(api_key)` only (no magic); start payload omits magic and session symbols; heartbeats omit config/symbol change requests and results; on shutdown or token failure the SDK stops the timer and alerts the user (no `ExpertRemove()`).

```
┌────────────────────────────────────────────────────────────────┐
│                     SDK LIFECYCLE FLOW                         │
└────────────────────────────────────────────────────────────────┘

  OnInit()
    │
    ▼
  g_robot.on_init(api_key, magic)
    │
    ├─ 1. Validate API key & UUID
    ├─ 2. Wait for account data (up to 10 seconds)
    ├─ 3. Create SDK Context (all managers)
    ├─ 4. Collect static data (account, terminal, broker info)
    ├─ 5. Collect watchlist symbols (Market Watch)
    ├─ 6. POST /robot/start → Server
    │     ├─ Send: api_key, uuid, magic, static_data, symbols
    │     └─ Receive: session_id, jwt, config, change_requests
    ├─ 7. Store JWT token
    ├─ 8. Validate initial server configuration
    ├─ 9. Start 1-second timer for heartbeats
    └─ 10. Session is now ACTIVE ✅

          ┌─────────────── RUNNING ───────────────┐
          │                                        │
  OnTick  │  g_robot.on_tick()                     │
    │     │   └─ Calls YOUR on_tick()             │
    │     │      (your trading logic runs here)    │
    │     │                                        │
  OnTimer │  g_robot.on_timer()                    │
    │     │   ├─ Check if token needs refresh      │
    │     │   ├─ If time to heartbeat:             │
    │     │   │    POST /robot/heartbeat → Server  │
    │     │   │    ├─ Send: sequence, dynamic_data │
    │     │   │    │        config_results,         │
    │     │   │    │        symbol_results          │
    │     │   │    └─ Receive: interval,            │
    │     │   │              config_changes,        │
    │     │   │              symbol_changes,        │
    │     │   │              termination_request     │
    │     │   └─ Process server commands            │
    │     │       ├─ Config changes → on_config_changed()
    │     │       ├─ Symbol changes → on_symbol_changed()
    │     │       └─ Termination  → on_termination_requested()
          └────────────────────────────────────────┘

  OnDeinit()
    │
    ▼
  g_robot.on_deinit(reason)
    │
    ├─ 1. POST /robot/end → Server
    │     ├─ Send: session_id, reason, final_stats
    │     └─ Receive: confirmation
    ├─ 2. Kill timer
    └─ 3. Session ENDED

  delete g_robot
    │
    └─ Destructor cleans up all managers and memory
```

### Key Concepts:

- **Heartbeat** — The SDK sends a periodic "I'm alive" message to the server. The default interval is **60 seconds** (`SDK_DEFAULT_HEARTBEAT_INTERVAL`); the server can adjust it (max **300 seconds**). The SDK uses **TimeLocal()** for timing so heartbeats continue when the market is closed.
- **Sequence Number** — Each heartbeat has an incrementing sequence number. If they get out of sync (HTTP 409 error), the SDK auto-corrects from the server response (`context.expected_sequence` or `context.current_sequence`).
- **Dynamic Data** — Every heartbeat includes current balance, equity, margin, drawdown, and profit/loss since session start.
- **Change Results** — When the server requests a config/symbol change (EAs only), the results (accepted/rejected) are included in the next heartbeat. Indicators do not send or receive config/symbol change requests.

---

## 13. Error Handling & Troubleshooting

### Common Errors and Solutions

| Error Message | Cause | Solution |
|---|---|---|
| `WebRequest failed. Error code: 4060` | URL not in allowed list | Add the API URL to Tools → Options → Expert Advisors |
| `API Key is required!` | Empty API key | Set the `InpApiKey` input parameter |
| `Invalid robot_version_uuid` | Wrong UUID length | Ensure UUID is exactly 36 characters (e.g., `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`) |
| `Start session failed` | Server rejected the request | Check API key validity and internet connection; for local testing use a **test license** API key from your Vendor Portal with the staging URL |
| `Token refresh failed` | Session may have expired | The SDK will remove the EA or stop the Indicator timer if it can't refresh; restart the program |
| `Heartbeat sequence mismatch (409)` | Out-of-sync heartbeats | SDK auto-corrects this; no action needed |

### Debugging Tips

1. **Check the Experts tab** in MetaTrader 5 — the SDK logs extensively with `SDK Info:`, `SDK Debug:`, `SDK Warning:`, and `SDK Error:` prefixes.

2. **Enable logging** (on by default):
   ```mql5
   // The HTTP service logs all requests/responses
   // Look for "SENDING HTTP REQUEST" and "HTTP RESPONSE RECEIVED" blocks
   ```

3. **Test with the staging environment** before going to production. For local testing, generate a new **test license** from your Vendor Portal and use its API key with the staging URL.

4. **Use `Alert()`** in your `on_config_changed()` and `on_symbol_changed()` methods during development to visually see when changes arrive.

---

## 14. Best Practices & Tips

### ✅ DO

- **Keep field keys consistent** — Use `snake_case` for all field keys (e.g., `max_trades`, `lot_size`)
- **Always check pointers** — Use `CheckPointer(ptr) != POINTER_INVALID` before accessing any pointer
- **Match defaults** — Ensure `define_schema()` and `apply_defaults()` use the same default values
- **Group related fields** — Use `.with_group()` to organize settings logically for customers
- **Add descriptions** — Every field should have a clear `.with_description()` for customer understanding
- **Use tooltips** — Add `.with_tooltip()` for fields that need extra explanation
- **Handle all fields** — Every field in `define_schema()` must be handled by `update_field()`, `get_field_as_string()`, `to_json()`, and `update_from_json()`
- **Use dependencies** — Hide fields that are irrelevant (e.g., trailing stop distance when trailing stop is off)
- **Validate in on_tick()** — Always use getters from your config object rather than hardcoded values

### ❌ DON'T

- **Don't delete `m_robot_config`** — The base class destructor handles this
- **Don't call `EventKillTimer()`** — The SDK manages the timer
- **Don't call `EventSetTimer()`** after `on_init()` — This could overwrite the SDK's timer
- **Don't modify SDK source files** — Treat the SDK as a black box; customization happens in your classes only
- **Don't use `TimeCurrent()` for time checks** — Use `TimeLocal()` or `TimeGMT()` instead (market time doesn't advance on weekends)
- **Don't block `OnTimer()`** — Keep your timer processing fast so heartbeats run on schedule

---

## 15. Complete Template — Copy & Customize

Below is a complete, production-ready template you can copy and modify for your own robot. Replace the `TODO` comments with your actual implementation.

```mql5
//+------------------------------------------------------------------+
//| MyTradingRobot.mq5                                                |
//| Copyright 2024, Your Company Name                                 |
//| https://yourwebsite.com                                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Company Name"
#property link      "https://yourwebsite.com"
#property version   "1.00"
#property strict

// SDK Include
#include <themarketrobo/TheMarketRobo_SDK.mqh>

// Input Parameters
input string InpApiKey = "";  // API Key

// Constants
const string ROBOT_VERSION_UUID = "TODO-your-uuid-here";


//+------------------------------------------------------------------+
//| CONFIGURATION CLASS                                                |
//+------------------------------------------------------------------+
class CMyRobotConfig : public IRobotConfig
{
private:
    // TODO: Declare your configuration member variables
    int    m_max_trades;
    double m_lot_size;
    double m_stop_loss;
    double m_take_profit;
    bool   m_use_trailing;
    double m_trailing_distance;

public:
    CMyRobotConfig() : IRobotConfig()
    {
        define_schema();
        apply_defaults();
    }
    ~CMyRobotConfig() {}

    // ----- Getters (for your trading logic) -----
    int    get_max_trades()        const { return m_max_trades; }
    double get_lot_size()          const { return m_lot_size; }
    double get_stop_loss()         const { return m_stop_loss; }
    double get_take_profit()       const { return m_take_profit; }
    bool   get_use_trailing()      const { return m_use_trailing; }
    double get_trailing_distance() const { return m_trailing_distance; }

    // ----- Schema Definition -----
    virtual void define_schema() override
    {
        if(CheckPointer(m_schema) == POINTER_INVALID) return;

        // TODO: Define your fields here

        m_schema.add_field(
            CConfigField::create_integer("max_trades", "Max Trades", true, 3)
                .with_range(1, 20)
                .with_step(1)
                .with_description("Maximum concurrent trades")
                .with_group("Risk", 1)
        );

        m_schema.add_field(
            CConfigField::create_decimal("lot_size", "Lot Size", true, 0.01)
                .with_range(0.01, 5.0)
                .with_step(0.01)
                .with_precision(2)
                .with_description("Position size in lots")
                .with_group("Risk", 2)
        );

        m_schema.add_field(
            CConfigField::create_decimal("stop_loss", "Stop Loss (pips)", true, 30.0)
                .with_range(5.0, 200.0)
                .with_step(5.0)
                .with_precision(1)
                .with_description("Stop loss distance")
                .with_group("Risk", 3)
        );

        m_schema.add_field(
            CConfigField::create_decimal("take_profit", "Take Profit (pips)", true, 60.0)
                .with_range(5.0, 500.0)
                .with_step(5.0)
                .with_precision(1)
                .with_description("Take profit distance")
                .with_group("Risk", 4)
        );

        m_schema.add_field(
            CConfigField::create_boolean("use_trailing", "Use Trailing Stop", true, false)
                .with_description("Enable trailing stop loss")
                .with_group("Advanced", 1)
        );

        CConfigDependency* dep_trail = new CConfigDependency();
        dep_trail.set_bool_value("use_trailing", CONDITION_EQUALS, true);
        m_schema.add_field(
            CConfigField::create_decimal("trailing_distance", "Trailing Distance (pips)", true, 15.0)
                .with_range(5.0, 100.0)
                .with_step(5.0)
                .with_precision(1)
                .with_description("Trailing stop distance in pips")
                .with_group("Advanced", 2)
                .with_depends_on(dep_trail)
        );
    }

    // ----- Default Values -----
    virtual void apply_defaults() override
    {
        m_max_trades = 3;
        m_lot_size = 0.01;
        m_stop_loss = 30.0;
        m_take_profit = 60.0;
        m_use_trailing = false;
        m_trailing_distance = 15.0;
    }

    // ----- Serialize to JSON -----
    virtual string to_json() override
    {
        CJAVal c(JA_OBJECT);
        CJAVal* v1 = new CJAVal(); v1.set_long(m_max_trades);            c.Add("max_trades", v1);
        CJAVal* v2 = new CJAVal(); v2.set_double(m_lot_size);            c.Add("lot_size", v2);
        CJAVal* v3 = new CJAVal(); v3.set_double(m_stop_loss);           c.Add("stop_loss", v3);
        CJAVal* v4 = new CJAVal(); v4.set_double(m_take_profit);         c.Add("take_profit", v4);
        CJAVal* v5 = new CJAVal(); v5.set_bool(m_use_trailing);          c.Add("use_trailing", v5);
        CJAVal* v6 = new CJAVal(); v6.set_double(m_trailing_distance);   c.Add("trailing_distance", v6);
        return c.serialize();
    }

    // ----- Bulk Update from JSON -----
    virtual bool update_from_json(const CJAVal &j) override
    {
        if(j.has_key("max_trades"))        m_max_trades        = (int)j["max_trades"].get_long();
        if(j.has_key("lot_size"))          m_lot_size          = j["lot_size"].get_double();
        if(j.has_key("stop_loss"))         m_stop_loss         = j["stop_loss"].get_double();
        if(j.has_key("take_profit"))       m_take_profit       = j["take_profit"].get_double();
        if(j.has_key("use_trailing"))      m_use_trailing      = j["use_trailing"].get_bool();
        if(j.has_key("trailing_distance")) m_trailing_distance = j["trailing_distance"].get_double();
        return true;
    }

    // ----- Single Field Update -----
    virtual bool update_field(string f, string v) override
    {
        if(f == "max_trades")        { m_max_trades        = (int)StringToInteger(v);              return true; }
        if(f == "lot_size")          { m_lot_size          = StringToDouble(v);                    return true; }
        if(f == "stop_loss")         { m_stop_loss         = StringToDouble(v);                    return true; }
        if(f == "take_profit")       { m_take_profit       = StringToDouble(v);                    return true; }
        if(f == "use_trailing")      { m_use_trailing      = (v == "true" || v == "1");            return true; }
        if(f == "trailing_distance") { m_trailing_distance = StringToDouble(v);                    return true; }
        return false;
    }

    // ----- Get Field as String -----
    virtual string get_field_as_string(string f) override
    {
        if(f == "max_trades")        return IntegerToString(m_max_trades);
        if(f == "lot_size")          return DoubleToString(m_lot_size, 2);
        if(f == "stop_loss")         return DoubleToString(m_stop_loss, 1);
        if(f == "take_profit")       return DoubleToString(m_take_profit, 1);
        if(f == "use_trailing")      return m_use_trailing ? "true" : "false";
        if(f == "trailing_distance") return DoubleToString(m_trailing_distance, 1);
        return "";
    }
};


//+------------------------------------------------------------------+
//| ROBOT CLASS                                                        |
//+------------------------------------------------------------------+
class CMyRobot : public CTheMarketRobo_Base
{
public:
    CMyRobot()
        : CTheMarketRobo_Base(ROBOT_VERSION_UUID, new CMyRobotConfig())
    {
        Print("My Robot initialized!");
    }

    ~CMyRobot()
    {
        Print("My Robot destroyed.");
    }

    virtual void on_tick() override
    {
        CMyRobotConfig* cfg = (CMyRobotConfig*)m_robot_config;

        // TODO: Your trading logic here
        // Examples of reading config:
        //   double lot   = cfg.get_lot_size();
        //   double sl    = cfg.get_stop_loss();
        //   double tp    = cfg.get_take_profit();
        //   int    max   = cfg.get_max_trades();
        //   bool   trail = cfg.get_use_trailing();
    }

    virtual void on_config_changed(string event_json) override
    {
        Print("Config changed: ", event_json);
        Alert("Robot configuration has been updated!");

        // TODO: React to config changes if needed
        // The new values are already applied at this point.
    }

    virtual void on_symbol_changed(string event_json) override
    {
        Print("Symbol changed: ", event_json);
        Alert("Symbol status changed!");

        // TODO: React to symbol changes (e.g., close positions)
    }
};


//+------------------------------------------------------------------+
//| GLOBAL VARIABLE                                                    |
//+------------------------------------------------------------------+
CMyRobot* g_robot = NULL;


//+------------------------------------------------------------------+
//| MQL5 EVENT HANDLERS                                                |
//+------------------------------------------------------------------+
int OnInit()
{
    if(InpApiKey == "")
    {
        Alert("API Key is required!");
        return INIT_PARAMETERS_INCORRECT;
    }

    MathSrand((int)TimeLocal());
    long magic = MathRand() * MathRand() + (long)GetTickCount();

    g_robot = new CMyRobot();
    if(CheckPointer(g_robot) == POINTER_INVALID) return INIT_FAILED;

    int result = g_robot.on_init(InpApiKey, magic);
    if(result != INIT_SUCCEEDED) return result;

    Print("Robot connected to TheMarketRobo! Ready to trade.");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    if(CheckPointer(g_robot) != POINTER_INVALID)
    {
        g_robot.on_deinit(reason);
        delete g_robot;
        g_robot = NULL;
    }
}

void OnTick()
{
    if(CheckPointer(g_robot) != POINTER_INVALID)
        g_robot.on_tick();
}

void OnTimer()
{
    if(CheckPointer(g_robot) != POINTER_INVALID)
        g_robot.on_timer();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if(CheckPointer(g_robot) != POINTER_INVALID)
        g_robot.on_chart_event(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
```

---

## 16. FAQ

### Q: Do I need to change my trading logic?
**A:** No. Your trading logic stays exactly the same. You just wrap it inside the `on_tick()` method and read settings from the config object instead of hard-coded values or MQL5 `input` parameters.

### Q: Can I still use MQL5 `input` parameters?
**A:** Yes, for the API Key (and anything not controlled by the dashboard). But for settings that customers should control remotely, use the SDK config schema instead.

### Q: What happens if the internet disconnects?
**A:** Your EA continues running and trading normally. Heartbeats will fail but the EA won't stop. When the connection is restored, heartbeats resume. However, if the JWT token expires and can't be refreshed, the SDK will remove the EA to prevent unauthorized trading.

### Q: Can I have fields that are NOT sent to the dashboard?
**A:** Yes. Simply don't define them in `define_schema()`. You can still have private member variables and `input` parameters for internal use.

### Q: What is the Magic Number for?
**A:** The Magic Number uniquely identifies orders placed by this specific EA instance. It's sent to the server for session tracking. The SDK generates one randomly, but you can also use a fixed one.

### Q: How many config fields can I define?
**A:** There is no hard limit. The sample EA demonstrates 19 fields, but you can have as many as needed.

### Q: What happens when a field update fails validation?
**A:** The SDK automatically validates changes against your schema (min/max ranges, valid options, etc.). Rejected changes are reported back to the server with an error code. Your EA is only updated with valid values.

### Q: Can I reject a config change programmatically?
**A:** Currently, validation is based on your schema definition (ranges, valid options). The SDK validates against the schema and accepts/rejects accordingly. If you need custom validation, set strict ranges in your schema.

### Q: How often do heartbeats occur?
**A:** Default is every 60 seconds. The server can adjust this interval (up to 300 seconds max) via heartbeat responses.

### Q: Does the SDK collect my trading data?
**A:** The SDK collects and reports **account-level** data (balance, equity, margin, drawdown) during heartbeats. It does **not** access individual trade history, order details, or trading strategies.

### Q: Why do Indicators not require a magic number or config class?
**A:** Indicators are used for chart analysis and do not place orders, so no magic number is needed for trade identification. The platform supports remote configuration and symbol tracking for **Expert Advisors**; Custom Indicators use the same SDK for session registration and heartbeats only, with a **one-argument constructor** (indicator version UUID). On server-requested termination or token failure, the SDK stops the timer and alerts the user to remove the indicator (there is no self-removal API for indicators).

---

## 17. Glossary

| Term | Definition |
|---|---|
| **API Key** | A secret string that authenticates your customer with TheMarketRobo backend |
| **Robot Version UUID** / **Indicator Version UUID** | A unique identifier (36 characters) assigned to your robot or indicator version on the platform. Same API field name; use in constructor (one-arg for indicators, two-arg for EAs). |
| **JWT (JSON Web Token)** | A secure authentication token used for API communication after login |
| **Heartbeat** | A periodic message sent to the server saying "I'm still running" with current account data |
| **Session** | The period from when the EA starts (`/start`) to when it stops (`/end`) |
| **Schema** | The definition of what configuration fields your robot has (types, ranges, defaults) |
| **Config Change Request** | A server message telling the robot to update a setting value |
| **Symbol Change Request** | A server message telling the robot to enable/disable a trading symbol |
| **Magic Number** | A unique number identifying trades opened by this specific EA instance |
| **Watchlist / Market Watch** | The list of symbols currently visible in MetaTrader's Market Watch panel |
| **Builder Pattern** | A coding pattern where you chain method calls (`.with_range().with_step()`) to configure an object |
| **Dynamic Data** | Real-time data sent in heartbeats (balance, equity, margin, drawdown) |
| **Static Data** | One-time data sent at session start (account info, terminal info, broker info) |
| **Sequence Number** | An incrementing counter ensuring heartbeats are processed in order |
| **Dependency** | A rule that makes a field visible only when another field has a specific value |

---

> **Need help?** Contact TheMarketRobo support at support@themarketrobo.com
> **API Documentation:** https://api.themarketrobo.com/docs
> **Dashboard:** https://app.themarketrobo.com

---

*© 2024-2026 The Market Robo Inc. All rights reserved.*
