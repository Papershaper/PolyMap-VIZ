# PolyMap_VIZ

## Overview

- Godot 4.5 project for the visualization and operator-console side of the PolyMap / Minone system.
- Renders a global occupancy map in 3D, shows per-robot telemetry, and can publish operator commands over MQTT.
- This repo does not contain robot firmware or map-generation logic. It connects to those systems over MQTT.

## Current Repository Role

- Main runtime entry point: `project.godot` -> `MainScene.tscn`.
- The main scene embeds:
  - an in-tree MQTT client node
  - a 3D map viewport
  - a telemetry/control panel
  - an MQTT connection / subscribe / publish dialog
- There is no MQTT autoload singleton. MQTT lives inside `MainScene`.

## Main Scenes And Scripts

- `MainScene.tscn` / `main_scene.gd`
  - Main operator UI.
  - Owns the in-tree MQTT node and all runtime MQTT calls.
  - Routes incoming MQTT messages into map updates and telemetry cards via `polymap_mqtt.gd`.
  - Handles `Clear` and `Reset` UI actions.
- `polymap_mqtt.gd`
  - Narrow PolyMap MQTT helper.
  - Centralizes topic matching, topic building, and message encode/decode helpers used by the runtime.
- `global_map_scene.tscn` / `global_map.gd`
  - 3D global map renderer.
  - Builds a `MultiMesh` from the incoming `global_map` array.
  - Creates and updates robot markers from telemetry using the current map dimensions.
- `telemetry_item.tscn` / `telemetry_item.gd`
  - Per-robot telemetry card.
  - Displays pose and state fields.
  - Emits operator command intent for that robot back to `MainScene`.
- `connection_dialog.tscn` / `connection_dialog.gd`
  - Manual broker connect/disconnect UI.
  - Manual subscribe, unsubscribe, and arbitrary publish UI.
  - Emits broker and publish/subscribe intent back to `MainScene`.
- `addons/mqtt/mqtt.gd`
  - Local MQTT 3.1.1 client implementation used by the main scene.
- `mqttexample.tscn` / `mqttexample.gd`
  - Generic MQTT demo scene.
  - Present in the repo, but not the project entry point.

## MQTT Integration Summary

- The app does not auto-connect or auto-subscribe on startup.
- Operator flow is:
  - run the project
  - open the `MQTT` dialog
  - connect to a broker
  - subscribe to one or more topics
- Default connection UI values currently ship as:
  - host `192.168.178.20`
  - protocol `tcp://`
  - port `1883`
  - username `local_test`
  - password `local_pwd`
- Implemented message handling in the runtime scene:
  - topics beginning with `PolyMap/global_map` are currently still parsed as global map updates
  - any topic containing `telemetry` is currently still parsed as robot telemetry
- The UI also publishes commands:
  - `PolyMap/<robot_id>/cmd/state`
  - `PolyMap/<robot_id>/cmd/manual`
- Detailed topic and payload notes are in `MQTT_CONTRACT.md`.

## Visualization And Control Behavior

- Global map messages are expected to contain a `global_map` 2D array.
- The map is rendered as a colored 3D grid:
  - `128` is treated as unknown
  - values below `128` are treated as free
  - values above `128` are treated as occupied
- Telemetry messages create one telemetry card per robot ID.
- Telemetry cards show:
  - `orientation_rad`
  - `gridX`
  - `gridY`
  - `robot_state`
  - `agent_state`
- Telemetry also drives robot marker placement in the 3D view.
- Once a `global_map` has been received, robot marker Y/Z placement uses the received map height.
- If telemetry arrives before the first map, the marker is shown using raw telemetry grid coordinates until a map arrives and reprojection can occur.
- Operator controls available from each telemetry card:
  - state changes: `Manual`, `Autonomous`, `Pause`, `Standby`
  - manual actions: `Move`, `Turn`, `Scan`
- `Clear` removes the current rendered map.
- `Reset` resets the chase-camera view.

## Run Notes

- Open the project in Godot 4.5 and run the default scene.
- Use the `MQTT` button to open broker controls.
- The default subscription field is `PolyMap/#`.
- No persistent broker profile or topic config is defined in the repo.

## Current Limitations

- MQTT topic handling is split across multiple scripts instead of one contract definition.
- Telemetry parsing assumes the robot ID is the second topic segment.
- Telemetry matching is broad: any subscribed topic containing `telemetry` is treated as telemetry.
- Topic matching is still intentionally permissive during the current migration, even though the helper now centralizes it.
