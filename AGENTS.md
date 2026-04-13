# AGENTS.md

This repository is a Godot-based mission-control visualization and operator-console project for the PolyMap / Minone robotics system.

## Product Direction

The primary use case is to follow and assist an autonomous robot that maps physical space using minimal sensors. The visualization began partly as a debug/operator tool, but the target direction is a broader mission-control interface.

Assume the visualization is part of the same system as Minone firmware and PolyMap platform services. Do not treat it as an isolated demo app.

## Sources Of Truth

* Runtime code is the source of truth for currently implemented behavior.
* `MQTT_CONTRACT.md` is the source of truth for canonical platform MQTT topics, current repo alignment, and recommended cleanup.
* Documentation must separate:

  * current implemented behavior
  * canonical platform intent
  * proposed cleanup or refactor direction

Prefer facts from code over stale comments or old docs.

## Priorities

* Understand current implemented behavior before proposing changes.
* Preserve working runtime behavior unless the task explicitly requests a behavior change.
* Prefer small, reversible refactors over broad rewrites.
* Keep documentation concise, technical, and explicit about current vs desired state.
* Note simulation or prototype artifacts if present, but do not overemphasize prototype history.

## Architecture Rules

* Avoid hard-coded scene-tree paths such as `/root/...` for runtime dependencies.
* Prefer signals, injected references, or controller/service nodes over direct scene-path lookups.
* Do not spread MQTT topic parsing across UI components.
* Centralize MQTT topic names, topic parsing, and payload shape handling.
* Keep scene scripts lean. Move reusable logic into plain GDScript classes or service-style scripts where practical.
* UI components should emit operator intent; publishing MQTT directly from leaf UI nodes should be avoided unless explicitly required by the current architecture.

## Godot Conventions

* Preserve the current project entry point unless explicitly asked to change it.
* Favor scene composition for structure and scripts for behavior.
* Avoid hidden coupling between scenes through fragile node lookups.
* Preserve signal wiring and scene responsibilities unless the task includes a deliberate architectural refactor.

## UI/UX Direction

* Favor mission-control clarity over debug-tool clutter or game-like styling.
* Emphasize spatial awareness, robot state visibility, operator confidence, and command feedback.
* The primary workflow is:

  * observe map progress
  * inspect telemetry
  * detect stale or problematic robot state
  * issue operator commands when needed
* Optimize first for a single active exploration robot, while avoiding assumptions that prevent future multi-robot workflows.

## Safe Changes

These are generally safe unless the task says otherwise:

* extracting constants
* centralizing MQTT topic handling
* replacing direct node-path coupling with signals or injected dependencies
* moving reusable logic out of UI scripts
* improving technical documentation
* clarifying schema and contract boundaries

## Changes That Require Explicit Approval

Do not make these changes unless explicitly requested:

* changing canonical MQTT topic names
* changing command payload semantics
* removing operator-facing controls
* changing scene entry points
* changing coordinate conventions or map orientation rules without updating contract docs
* broad runtime rewrites justified only by style preference

## Documentation Rules

When documenting MQTT or runtime behavior, always distinguish between:

* current implemented behavior
* canonical platform contract
* recommended cleanup

Do not present recommended architecture as if it is already implemented.

## Done Criteria For Refactor Work

A refactor is not complete unless all of the following remain true:

* the project still opens and runs from the current entry scene
* no new hard-coded scene-path coupling is introduced
* MQTT contract logic is not duplicated across multiple UI scripts
* documentation is updated when runtime behavior or contract assumptions change
