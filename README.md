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
  - Connects MQTT signals.
  - Routes incoming MQTT messages into map updates and telemetry cards.
  - Handles `Clear` and `Reset` UI actions.
- `global_map_scene.tscn` / `global_map.gd`
  - 3D global map renderer.
  - Builds a `MultiMesh` from the incoming `global_map` array.
  - Creates and updates robot markers from telemetry.
- `telemetry_item.tscn` / `telemetry_item.gd`
  - Per-robot telemetry card.
  - Displays pose and state fields.
  - Publishes state and manual command topics for that robot.
- `connection_dialog.tscn` / `connection_dialog.gd`
  - Manual broker connect/disconnect UI.
  - Manual subscribe, unsubscribe, and arbitrary publish UI.
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
  - topics beginning with `PolyMap/global_map` are parsed as global map updates
  - any topic containing `telemetry` is parsed as robot telemetry
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
- Robot marker placement uses a hard-coded `120` row flip, while map rendering uses the actual received map height.
- `telemetry_item.gd` looks up the MQTT node via `/root/MainScene/MQTT`, which couples the control cards to the current scene path.
