# AGENTS.md

This repository is a Godot 4.5 based mission-control visualization and operator-console project for the PolyMap / Minone robotics system.

## Product Direction

The primary use case is to follow, monitor, and assist an autonomous robot that maps physical space using minimal sensors. The visualization began partly as a debug/operator tool, but the intended direction is a broader mission-control interface.

Assume this visualization is one subsystem within the larger PolyMap / Minone system. It is not a standalone demo app, and it should not be treated as separate from robot firmware, platform services, or the evolving autonomy stack.

The current product focus is a single active exploration robot with operator visibility and intervention. Future expansion to multi-robot workflows is expected, so avoid design choices that hard-code single-robot assumptions into core architecture.

## Sources of Truth

Use the following hierarchy when analyzing or modifying this repository:

- Runtime code is the source of truth for **currently implemented behavior**.
- `MQTT_CONTRACT.md` is the source of truth for:
  - canonical platform MQTT topics
  - current repository alignment with that contract
  - known implementation gaps
  - recommended cleanup direction
- Documentation should clearly distinguish between:
  - current implemented behavior
  - canonical platform intent
  - recommended or proposed refactor direction

Prefer verified behavior from code over stale comments, historical assumptions, or outdated notes.

## Core Working Assumptions

- This repository owns visualization, operator interaction, and related UI/UX behavior.
- It does **not** own robot firmware behavior or core mapping algorithms.
- MQTT is the integration boundary between this visualization and the wider PolyMap / Minone system.
- Existing behavior should be preserved unless a task explicitly requests a behavior change.
- Prototype history may explain some design choices, but current and intended product direction matters more than legacy/debug origins.

## Priorities

When working in this repository, prioritize the following:

1. Understand the current implemented behavior before proposing changes.
2. Preserve working runtime behavior unless the task explicitly asks for change.
3. Prefer small, reversible refactors over broad rewrites.
4. Keep documentation concise, technical, and explicit about what is implemented today.
5. Separate architectural cleanup from behavioral change.
6. Improve structure in ways that make the codebase easier to maintain and easier for Codex to extend safely.

## Architecture Principles

### General

- Favor clear boundaries between UI, runtime orchestration, and protocol/domain logic.
- Avoid hidden coupling between scenes through fragile node-path lookups.
- Prefer explicit ownership of state and message handling.
- Keep responsibilities narrow and easy to inspect.

### Godot Structure

- We are using Godot 4.5.1 or later.
- Preserve the existing project entry point unless explicitly asked to change it.
- Always use @onready for node references. Prefer composition over inheritance.
- When adding nodes to a scene, use the .tscn format.
- Favor scenes for composition and scripts for behavior.
- Keep scene scripts lean where practical.
- Move reusable or non-visual logic into plain GDScript classes or service-style scripts where that improves clarity.
- Preserve signal wiring and scene responsibilities unless the task includes deliberate restructuring.

### Dependency Management

- Avoid hard-coded scene-tree paths such as `/root/...` for runtime dependencies.
- Prefer signals, injected references, controller nodes, or service-style access patterns over brittle node-path lookups.
- Do not introduce new hidden runtime dependencies between leaf UI nodes and top-level application nodes.

### MQTT and Domain Boundaries

- Do not spread MQTT topic parsing across multiple unrelated UI scripts.
- Centralize MQTT topic names, topic parsing, and payload-shape handling.
- Treat raw MQTT transport concerns separately from domain interpretation.
- UI components should not be responsible for interpreting arbitrary MQTT topics.
- Leaf UI nodes should prefer emitting operator intent rather than directly implementing transport behavior, unless the current task explicitly preserves existing coupling.

## UI/UX Direction

This project should evolve toward a **mission-control** interface rather than remain a pure debug panel.

Favor:

- spatial awareness
- operator confidence
- clear robot state visibility
- command feedback
- readable telemetry hierarchy
- restrained, technical visual design

Avoid:

- cluttered debug-tool presentation
- game-like styling that obscures operational clarity
- decorative complexity that does not improve operator understanding

The primary operator workflow is:

1. observe map progress
2. inspect robot telemetry and autonomy state
3. detect stale, risky, or abnormal conditions
4. intervene with commands when needed
5. regain situational awareness quickly after intervention

Design first for one active exploration robot, but do not bake single-robot assumptions into protocol, state, or data model layers if they can be avoided cleanly.

## Documentation Rules

When documenting runtime behavior or MQTT behavior:

- clearly separate **implemented behavior** from **canonical contract**
- clearly separate **current behavior** from **recommended cleanup**
- do not describe desired architecture as if it is already implemented
- do not invent platform guarantees that are not present in code or contract docs

Documentation should be brief, technical, and useful to future maintainers and coding agents.

## Safe Changes

The following are generally safe to propose or implement unless a task says otherwise:

- extracting constants
- centralizing MQTT topic handling
- centralizing payload-shape handling
- replacing brittle node-path lookups with signals or injected references
- moving reusable logic out of UI scripts
- clarifying runtime/documentation boundaries
- improving technical docs
- introducing lightweight controller/service layers where they reduce coupling
- removing obvious duplication without altering behavior

## Changes That Require Explicit Approval

Do not make these changes unless the task explicitly requests them:

- changing canonical MQTT topic names
- changing command payload semantics
- changing externally visible topic shapes
- removing operator-facing controls
- changing the project entry scene
- changing coordinate conventions or map-orientation rules without updating related docs
- broad runtime rewrites justified only by style preference
- replacing working implemented behavior with speculative architecture

## Refactor Expectations

A good refactor in this repository should:

- preserve behavior first
- reduce coupling
- make contracts easier to see
- make state flow easier to follow
- improve Codex-readability of the codebase
- avoid unnecessary churn in scene structure or public-facing behavior

Prefer refactors that expose seams for future work, such as:

- centralized contract definitions
- explicit message routing
- clearer ownership of robot state
- clearer separation between UI intent and transport operations

## Coding Guidance for Agents

When proposing or generating code:

- inspect existing code paths before suggesting replacements
- align naming with the repository’s current domain language
- keep patches focused and local when possible
- avoid introducing parallel architectures unless migration is explicit
- do not assume undocumented abstractions already exist
- do not silently broaden behavior while attempting to “clean up” code

If behavior is ambiguous, state what is implemented today and what is being inferred.

## Done Criteria for Refactor Work

A refactor is not complete unless all of the following remain true:

- the project still opens and runs from the current entry scene
- no new hard-coded scene-path coupling is introduced
- MQTT contract logic is not further duplicated across UI scripts
- current implemented behavior is either preserved or explicitly documented as changed
- relevant documentation is updated when contract assumptions or runtime behavior change
- the resulting structure is easier, not harder, for a future coding agent to extend safely