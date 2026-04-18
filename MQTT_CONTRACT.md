# MQTT Contract

## Scope

This document separates:

- the canonical MQTT topic contract for the PolyMap platform
- what this visualization repo currently implements
- where the implementation aligns with canon and where it does not

Code references in this document are based on:

- `main_scene.gd`
- `polymap_mqtt.gd`
- `telemetry_item.gd`
- `connection_dialog.gd`
- `connection_dialog.tscn`
- `global_map.gd`

## Canonical Platform Topics

The visualization should conform to these platform topics:

| Topic | Intended visualization role | Current repo status |
| --- | --- | --- |
| `PolyMap/{robot_id}/telemetry` | Subscribe and render robot pose/state telemetry | Implemented, but matched too broadly |
| `PolyMap/{robot_id}/local_map/blob` | Potential future subscribe path for robot-local map data | Not implemented |
| `PolyMap/{robot_id}/cmd/state` | Publish operator state-change commands to a robot | Implemented |
| `PolyMap/{robot_id}/cmd/manual` | Publish operator manual-action commands to a robot | Implemented |
| `PolyMap/global_map` | Subscribe and render shared global map | Implemented, but matched as a prefix rather than exact topic |

## Current Implemented MQTT Behavior

### Transport And Session Model

- MQTT client implementation: `addons/mqtt/mqtt.gd`
- MQTT protocol level: 3.1.1
- Supported connection schemes:
  - `tcp://`
  - `ssl://`
  - `ws://`
  - `wss://`
- MQTT is instantiated inside `MainScene`, not as an autoload.
- The application does not auto-connect or auto-subscribe at startup.
- Broker connection, subscribe, unsubscribe, and arbitrary publish are operator-triggered from `connection_dialog.tscn`.
- Client ID is generated at connect time as `s<random_int>`.

### Current Dialog Defaults

These are UI defaults only. They are not a platform contract.

- broker host: `192.168.178.20`
- username: `local_test`
- password: `local_pwd`
- default subscribe field: `PolyMap/#`
- default publish field: `minone/telemetry`
- default last-will topic: `godot/mywill`

The subscribe default is compatible with the canonical namespace. The publish and last-will defaults are not canonical PolyMap topics.

## Topic-By-Topic Alignment

### `PolyMap/{robot_id}/telemetry`

Canonical intent:

- topic shape: `PolyMap/{robot_id}/telemetry`
- visualization subscribes and uses the topic path to identify the robot

Current implementation:

- handled in `main_scene.gd` using helper functions in `polymap_mqtt.gd`
- message match rule is still `topic.find("telemetry") != -1`
- `robot_id` is still extracted from `topic.split("/")` using `parts[1]`
- this means the code only derives the correct `robot_id` when the topic shape is effectively `PolyMap/{robot_id}/...`
- payload is expected to be JSON

Fields currently used by the visualization:

- `orientation_rad`
- `gridX`
- `gridY`
- `robot_state`
- `agent_state`

Behavioral notes:

- missing fields are tolerated in the telemetry card via fallback values
- marker placement defaults missing `gridX`, `gridY`, and `orientation_rad` to `0`
- telemetry messages create or update one UI card per `robot_id`
- telemetry messages also create or update one 3D marker per `robot_id`

Alignment with canon:

- partially aligned
- exact canonical topics will work
- non-canonical topics containing the substring `telemetry` will also be treated as telemetry
- the implementation should be considered more permissive than canon

### `PolyMap/{robot_id}/local_map/blob`

Canonical intent:

- topic shape: `PolyMap/{robot_id}/local_map/blob`
- robot-local map payloads are published for PolyMap platform processing
- this visualization does not consume this topic directly
- PolyMap Map Manager is the component that processes robot-local map blobs and publishes `PolyMap/global_map`

Current implementation:

- no subscribe handler for `local_map`
- no payload parsing
- no visualization path uses this topic

Alignment with canon:

- intentionally ignored by this visualization

### `PolyMap/{robot_id}/cmd/state`

Canonical intent:

- topic shape: `PolyMap/{robot_id}/cmd/state`
- visualization publishes operator state-change commands for a selected robot

Current implementation:

- operator intent is emitted from `telemetry_item.gd`
- topic and payload are built in `main_scene.gd` via `polymap_mqtt.gd`
- topic is built exactly as `PolyMap/%s/cmd/state`
- `robot_id` comes from the telemetry topic that created the card
- payload type is a plain string

Implemented payloads:

- `start_manual`
- `start_auto`
- `pause`
- `standby`

Alignment with canon:

- aligned at the topic level
- current payload values are implementation-specific and should be treated as the de facto current command set for this repo

### `PolyMap/{robot_id}/cmd/manual`

Canonical intent:

- topic shape: `PolyMap/{robot_id}/cmd/manual`
- visualization publishes operator manual-action commands for a selected robot

Current implementation:

- operator intent is emitted from `telemetry_item.gd`
- topic and payload are built in `main_scene.gd` via `polymap_mqtt.gd`
- topic is built exactly as `PolyMap/%s/cmd/manual`
- `robot_id` comes from the telemetry topic that created the card
- payload type is a JSON string

Implemented payloads:

- turn:
  - `{"action":"turn", "angle_deg": <number>, "speed":200, "timeout":5000}`
- move:
  - `{"action":"move", "distance_cm": <number>, "speed": 200, "timeout":10000}`
- scan:
  - `{"action":"scan", "start_angle":30, "end_angle":150, "speed": 60, "timeout":10000}`

Alignment with canon:

- aligned at the topic level
- payload structure exists in practice, but it is not defined anywhere outside the implementation

### `PolyMap/global_map`

Canonical intent:

- topic shape: `PolyMap/global_map`
- visualization subscribes and renders the shared global map for the environment
- PolyMap Map Manager publishes this topic as the platform-level global-map output after processing robot-local map inputs

Map Manager publication shape:

```json
{
  "timestamp": "2026-04-13T12:00:00+00:00",
  "global_map": [[128, 128], [128, 128]]
}
```

Current implementation:

- handled in `main_scene.gd` using helper functions in `polymap_mqtt.gd`
- message match rule is still `topic.begins_with("PolyMap/global_map")`
- exact canonical topic works
- suffixed topics such as `PolyMap/global_map/...` also match because the check is prefix-based
- payload is expected to be JSON with a top-level `global_map` key

Payload fields currently relevant to the visualization:

- required by runtime logic:
  - `global_map`
- present in comments but ignored by runtime logic:
  - `timestamp`

`global_map` payload assumptions:

- top-level payload is a JSON object
- `global_map` is a 2D array
- cell semantics used by the renderer:
  - `128` = unknown
  - `< 128` = free
  - `> 128` = occupied

Alignment with canon:

- partially aligned
- exact canonical topic works
- implementation is more permissive than canon because it accepts any topic beginning with `PolyMap/global_map`

## Current Visualization Behavior And Robot Scope

The current runtime is not limited to a single hard-coded robot ID:

- telemetry is keyed by `robot_id`
- one telemetry card is created per `robot_id`
- one robot marker is created per `robot_id`
- command topics are published back to the same `robot_id`

However, the current visualization should still be considered single-robot-oriented in operation:

- there is one shared global map view
- there is no explicit robot selection or fleet-management workflow
- the camera follows the marker that was updated most recently
- if telemetry arrives before the first map, the marker is shown using raw telemetry grid coordinates until a map snapshot arrives
- there is no implemented handling for multiple robots contributing separate local-map topics

Practical interpretation:

- the code already contains the beginnings of multi-robot support for telemetry and command routing
- the product behavior is not yet a fully defined multi-robot global-map console

## Additional Implemented MQTT Capabilities

Beyond the canonical platform topics, the connection dialog allows operator-entered MQTT traffic:

- arbitrary subscribe topic
- arbitrary unsubscribe topic
- arbitrary publish topic and payload
- arbitrary last-will topic and payload

These are operator tools, not part of the canonical PolyMap topic contract.

## Implementation Gaps Relative To Canon

### Topic Matching

- telemetry handling is substring-based rather than exact-topic-based
- global map handling is prefix-based rather than exact-topic-based
- there is no dedicated handler for `PolyMap/{robot_id}/local_map/blob`

### Topic Defaults

- the default subscribe field `PolyMap/#` is reasonable for development
- the default publish field `minone/telemetry` is not a canonical platform topic
- the default last-will topic `godot/mywill` is not a canonical platform topic

### Payload Definition

- telemetry field usage is implied by code rather than documented as a platform schema
- `cmd/state` uses plain-string payloads
- `cmd/manual` uses JSON-string payloads
- `global_map` requires `global_map` but does not validate a stricter schema
- `timestamp` is part of the current Map Manager snapshot shape, but this visualization does not use it

### Map/Telemetry Coupling

- map rendering uses the received `global_map` dimensions
- robot marker Y-to-Z flipping now uses the last received `global_map` row count
- if no map has been received yet, robot markers are shown using raw telemetry grid coordinates

### MQTT Access Pattern

- `main_scene.gd` is now the only runtime script that talks directly to the `MQTT` node
- `connection_dialog.gd` emits broker and publish/subscribe intent signals
- `telemetry_item.gd` emits operator command intent signals
- MQTT topic and payload helper logic is centralized in `polymap_mqtt.gd`

## Recommended Cleanup

These are recommendations, not statements about current runtime behavior.

- Match telemetry only on the canonical topic pattern `PolyMap/{robot_id}/telemetry`.
- Match global map only on the canonical topic `PolyMap/global_map`.
- Replace non-canonical dialog defaults with canonical examples.
- Define a documented telemetry payload schema for the platform.
- Define a documented `cmd/manual` payload schema for the platform.
- Decide whether `cmd/state` should remain a plain string topic contract or move to JSON for consistency.
- Remove the hard-coded `120` row assumption from robot marker placement.
- Centralize MQTT topic names and payload schemas in one source of truth.
