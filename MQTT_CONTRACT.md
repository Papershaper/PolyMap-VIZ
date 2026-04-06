# MQTT Contract

## Current Implemented MQTT Behavior

### Transport And Connection Model

- MQTT client implementation: `addons/mqtt/mqtt.gd`
- MQTT protocol level: 3.1.1
- Supported connection schemes:
  - `tcp://`
  - `ssl://`
  - `ws://`
  - `wss://`
- MQTT is instantiated inside `MainScene`, not as an autoload.
- Connection, subscribe, unsubscribe, and publish are all operator-triggered from `connection_dialog.tscn`.
- Current dialog defaults:
  - broker host `192.168.178.20`
  - username `local_test`
  - password `local_pwd`
  - default subscribe field `PolyMap/#`
  - default publish field `minone/telemetry`
  - default last-will topic `godot/mywill`
- Client ID is generated at connect time as `s<random_int>`.

### Current Topics Used By This Repo

- Subscribed and interpreted by runtime code:
  - `PolyMap/global_map`
    - Direction: subscribe
    - Matching rule in code: `topic.begins_with("PolyMap/global_map")`
    - Notes: any suffix after `PolyMap/global_map` also matches because the check is prefix-based
  - `telemetry`
    - Direction: subscribe
    - Matching rule in code: any topic where `topic.find("telemetry") != -1`
    - Notes: this is a substring match, not a namespace match
- Published by runtime control UI:
  - `PolyMap/<robot_id>/cmd/state`
    - Direction: publish
  - `PolyMap/<robot_id>/cmd/manual`
    - Direction: publish
- Additional operator-entered MQTT traffic supported by the dialog:
  - arbitrary subscribe topic
    - Direction: subscribe
  - arbitrary publish topic
    - Direction: publish
  - arbitrary last-will topic
    - Direction: publish on disconnect by broker, if configured

### Payload Assumptions

- `PolyMap/global_map...`
  - Expected payload type: JSON string
  - Expected top-level shape: object
  - Required key used by code: `global_map`
  - Optional key mentioned in code comments: `timestamp`
  - `timestamp` is currently ignored by runtime logic
  - `global_map` is assumed to be a 2D array
  - Cell value assumptions:
    - `128` = unknown
    - `< 128` = free
    - `> 128` = occupied
- Telemetry topics
  - Expected payload type: JSON string
  - Expected top-level shape: object
  - Fields read by UI and marker logic:
    - `orientation_rad`
    - `gridX`
    - `gridY`
    - `robot_state`
    - `agent_state`
  - Missing fields are tolerated in the telemetry panel with fallback text or zero values
- `PolyMap/<robot_id>/cmd/state`
  - Payload type: plain string
  - Implemented payloads:
    - `start_manual`
    - `start_auto`
    - `pause`
    - `standby`
- `PolyMap/<robot_id>/cmd/manual`
  - Payload type: JSON string
  - Implemented payloads:
    - `{"action":"turn", "angle_deg": <number>, "speed":200, "timeout":5000}`
    - `{"action":"move", "distance_cm": <number>, "speed": 200, "timeout":10000}`
    - `{"action":"scan", "start_angle":30, "end_angle":150, "speed": 60, "timeout":10000}`

### Robot Identity And Namespace Assumptions

- Robot identity is derived from telemetry topic structure, not payload content.
- Telemetry handling assumes:
  - `topic.split("/")`
  - `parts.size() >= 3`
  - `robot_id = parts[1]`
- Example shape implied by code:
  - `PolyMap/<robot_id>/telemetry`
- Command publishing reuses that same `robot_id` in:
  - `PolyMap/<robot_id>/cmd/state`
  - `PolyMap/<robot_id>/cmd/manual`
- Global map handling is anchored to the `PolyMap` namespace.
- Telemetry handling is not anchored to `PolyMap`; any subscribed topic containing `telemetry` is accepted.

### Map Payload Assumptions

- The map renderer uses the received `global_map` array dimensions for rendering.
- Robot marker placement does not use the received map height.
- Marker Y-to-Z flipping currently assumes a fixed row count of `120`.
- This means marker placement can disagree with the rendered map if the incoming map height is not `120`.

### Does This Project Send Commands?

- Yes.
- It is not a subscribe-only visualization.
- Implemented operator-originated command paths:
  - state changes from telemetry cards
  - manual move / turn / scan commands from telemetry cards
  - arbitrary manual publish from the MQTT connection dialog

### Mismatches And Ambiguities Across Files

- Topic knowledge is split across:
  - `main_scene.gd`
  - `telemetry_item.gd`
  - `connection_dialog.tscn`
- Runtime topic parsing and UI defaults are not fully aligned:
  - runtime map handling expects `PolyMap/global_map...`
  - runtime telemetry handling accepts any topic containing `telemetry`
  - default subscribe UI text is `PolyMap/#`
  - default publish UI text is `minone/telemetry`
- Payload styles are mixed:
  - state commands use raw strings
  - manual commands use JSON strings
- MQTT node lookup is inconsistent:
  - `connection_dialog.gd` uses relative lookup `../MQTT`
  - `telemetry_item.gd` uses absolute lookup `/root/MainScene/MQTT`
- No single constants file defines broker defaults, topic names, or payload schemas.

## Recommended Next Contract Cleanup

- Define one explicit topic contract and keep it in one source of truth.
- Replace substring telemetry matching with exact topic patterns.
- Standardize command payload encoding so state and manual commands use the same format.
- Define the required telemetry schema and required global map schema in versioned form.
- Remove or rename UI defaults that are demo-only or mismatched with runtime expectations.
- Make robot marker placement use the received map dimensions instead of the hard-coded `120` rows.
- Centralize MQTT access so runtime code does not depend on `/root/MainScene/MQTT`.
