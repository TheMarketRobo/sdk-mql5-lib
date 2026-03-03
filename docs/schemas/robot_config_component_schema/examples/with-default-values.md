# Robot Config: Schema and Default Values

## Overview

Your robot configuration has two parts:

1. **config_fields (schema)** — Defines the structure: field types, keys, labels, validation (min/max, options), groups, and conditional display (`dependsOn`). Each field has a `default` property that describes the initial value for that field.
2. **default_config (values)** — A flat JSON object whose keys are the field `key`s and whose values are the default values. It must match the schema: every required field key must appear, every key must be a valid field key, and every value must satisfy the field’s type and constraints.

When you submit a robot version on the Vendor Portal, both the schema and the default values are validated. If either fails, submission is blocked.

## Simple Example

### Config fields (schema)

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
      "maximum": 20
    },
    {
      "type": "boolean",
      "key": "use_trailing_stop",
      "label": "Use Trailing Stop Loss",
      "required": true,
      "default": false
    },
    {
      "type": "radio",
      "key": "trading_mode",
      "label": "Trading Mode",
      "required": true,
      "default": "moderate",
      "options": [
        {"value": "conservative", "label": "Conservative"},
        {"value": "moderate", "label": "Moderate"},
        {"value": "aggressive", "label": "Aggressive"}
      ]
    }
  ]
}
```

### Corresponding default_config

```json
{
  "max_trades": 5,
  "use_trailing_stop": false,
  "trading_mode": "moderate"
}
```

- Each field’s `key` becomes a property name in `default_config`.
- The value must match the field’s `default` type and constraints (e.g. integer in range, one of the radio options).

## Complex example: groups and dependsOn

Groups and `dependsOn` only affect how the UI is organized and which fields are shown; they do not change the shape of `default_config`. It remains a flat object.

### Example schema (excerpt)

- `max_trades` (integer), `stop_loss_pips` (decimal), `use_trailing_stop` (boolean), `trailing_stop_distance` (decimal, dependsOn `use_trailing_stop`), `trading_sessions` (multiple).

### Example default_config

```json
{
  "max_trades": 5,
  "stop_loss_pips": 20.0,
  "use_trailing_stop": false,
  "trailing_stop_distance": 15.0,
  "trading_sessions": ["london", "newyork"]
}
```

- Conditional fields like `trailing_stop_distance` still have a default value; that value is used when the dependency is satisfied (e.g. when the customer turns on trailing stop).

## Type-specific default values

| Type     | default in schema | default_config value      |
|----------|-------------------|---------------------------|
| integer  | integer           | Integer, within min/max   |
| decimal  | number            | Number, within min/max    |
| boolean  | true/false        | `true` or `false`          |
| radio    | one option value  | One of the option values  |
| multiple | array of values   | Array of option values, length between minSelections and maxSelections |

## Validation rules (reminder)

- All required field keys must appear in `default_config`.
- Every key in `default_config` must be a field `key` in the schema.
- Values must match types and constraints (min/max, options, min/max selections).
- For radio, the default must be one of the option values.
- For multiple, the default array must only contain option values and respect min/max selections.

See [../validation-rules.md](../validation-rules.md) for the full list. The Vendor Portal runs this validation before allowing submission.
