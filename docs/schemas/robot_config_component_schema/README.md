# Robot Config Component Schema

## Important for Vendors

**The configuration you define for your robot MUST conform to this schema.** Only Expert Advisors (robots) have configurable parameters; Custom Indicators do not use this schema. When you submit a robot version on the **Vendor Portal**, the platform **validates your configuration schema** against this component schema before allowing submission. If validation fails, you will see errors and must fix your config (field types, keys, defaults, and constraints) to match these rules. Your MQL5 `IRobotConfig` implementation (e.g. `define_schema()`, `to_json()`, `update_from_json()`) should produce a structure that matches this schema so that the dashboard and backend stay in sync with your EA.

---

## Purpose

The **Robot Config Component Schema** is a meta-schema that defines the valid building blocks (components) vendors can use to create robot-specific configuration schemas. This establishes a standard contract between the platform and robot developers for defining configurable parameters.

## What is This?

This is NOT a robot configuration itself. Instead, it's the **rule system** that defines:
- What types of configuration fields are allowed (integer, decimal, boolean, radio, multiple)
- What properties each field type must/can have
- Validation constraints for configuration values
- UI rendering hints for the customer dashboard

## The Flow

```
┌─────────────────────────────────────────────────────────┐
│ 1. Component Schema (This Document)                     │
│    Defines: integer, decimal, boolean, radio, multiple  │
│    Platform-defined, versioned                          │
└────────────────────┬────────────────────────────────────┘
                     │ Vendors use these rules
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Robot Config Schema (Vendor Creates)                 │
│    Example: "max_trades" (integer, min:1, max:20)       │
│    Stored with robot version; validated on submit      │
└────────────────────┬────────────────────────────────────┘
                     │ Frontend interprets
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Customer Dashboard (Renders UI)                      │
│    Renders: Number input, toggles, dropdowns            │
│    Customer interacts with configuration                │
└────────────────────┬────────────────────────────────────┘
                     │ Validates
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Customer Config Changes                              │
│    Validated against vendor's robot config schema       │
│    Pushed to EA via SDK (on_config_changed)             │
└─────────────────────────────────────────────────────────┘
```

## Component Types

Five core component types:

| Component Type | Purpose | Example Use Case |
|----------------|---------|------------------|
| `integer` | Whole number input | Maximum trades: 1-20 |
| `decimal` | Floating point input | Stop loss: 0.5-2.5 |
| `boolean` | True/false toggle | Enable trailing stop |
| `radio` | Single choice from options | Trading mode: Conservative/Aggressive |
| `multiple` | Multiple choice from options | Trading sessions: London/New York/Tokyo |

### Common Properties (all types)

**Required:** `type`, `key`, `label`, `required`, `default`  
**Optional:** `description`, `placeholder`, `tooltip`, `group`, `order`, `disabled`, `hidden`, `dependsOn`

- **key**: Unique field identifier. Must match pattern `^[a-z][a-z0-9_]*$` (lowercase, underscores, no spaces). This key is used in `default_config` and in your MQL5 config class.
- **group** / **order**: Organize fields into sections in the UI.
- **dependsOn**: Conditional display (e.g. show "Trailing distance" only when "Use trailing stop" is true).

### Integer

- `minimum`, `maximum`, `step` (optional). Default must be integer within range.

### Decimal

- `minimum`, `maximum`, `step`, `precision` (optional). Default must be number within range.

### Boolean

- No type-specific properties. Default must be `true` or `false`.

### Radio

- `options` (required): array of `{ "value": string|number, "label": string }`, at least 2 options. Default must be one of the option values.

### Multiple

- `options` (required): same as radio. `minSelections`, `maxSelections` (optional). Default must be array of option values, length within min/max.

### Conditional display (dependsOn)

```json
"dependsOn": {
  "field": "use_trailing_stop",
  "condition": "equals",
  "value": true
}
```

Supported conditions: `equals`, `notEquals`, `greaterThan`, `lessThan`, `greaterThanOrEqual`, `lessThanOrEqual`, `contains`, `notContains`.

## Robot Config Schema Structure

Vendors create a JSON object with a `fields` array:

```json
{
  "fields": [
    {
      "type": "integer",
      "key": "max_trades",
      "label": "Maximum Concurrent Trades",
      "required": true,
      "default": 5,
      "minimum": 1,
      "maximum": 20,
      "step": 1,
      "description": "Maximum number of trades to open simultaneously",
      "group": "Risk Management",
      "order": 1
    }
  ]
}
```

- Each field must match one component type.
- All `key` values must be unique.
- Your `default_config` (separate JSON) must have keys matching each field `key`, with values that satisfy the field's type and constraints.

## Validation at Submission

When you submit a robot version on the Vendor Portal:

- The platform validates your `config_fields` (schema) against this component schema.
- It also validates your `default_config` (default values) against the schema: required keys present, types correct, values within min/max and options.
- If anything fails, submission is blocked and errors are shown. Fix the schema and/or defaults to conform to this document and the [validation rules](./validation-rules.md).

## Examples

- [Simple robot config](./examples/simple-robot-config.json) — A minimal set of fields (integer, decimal, boolean, radio, multiple).
- [Complex robot config](./examples/complex-robot-config.json) — Many fields, groups, and conditional fields (dependsOn).
- [Default values and schema](./examples/with-default-values.md) — How `default_config` relates to the schema and validation.

For how the SDK delivers config/symbol change requests and how you implement the robot side (request/response flow, `update_field`, `on_config_changed`, `on_symbol_changed`), see the main [Architecture Overview](../README.md#config-change-and-symbol-change--requestresponse-and-vendor-implementation).

## Related

- [Validation rules](./validation-rules.md) — Detailed validation rules for submission and runtime.
- [SDK Integration Booklet](../SDK_INTEGRATION_BOOKLET.md) — How to implement `IRobotConfig` in MQL5 so your EA matches this schema.
