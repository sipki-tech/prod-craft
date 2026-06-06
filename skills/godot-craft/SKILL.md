---
name: godot-craft
description: "Professional Godot 4 (GDScript) craft: idiomatic style, clean scene architecture, composition over inheritance, testing (GUT/GdUnit4), performance optimization, game design patterns, multiplayer networking, and export pipelines — distilled from the official Godot documentation, gdtoolkit, community best practices, and production game development patterns. Use when: writing, reviewing, or refactoring GDScript code or scene files; static typing, signals, custom Resources, node composition, UI layouts; unit/integration testing, mocking; linting with gdlint, formatting with gdformat, CI/CD pipelines; CPU/GPU profiling, draw calls, memory management, object pooling; state machines, component patterns, observers; multiplayer synchronization, RPCs, server authority, client-side validation; custom export templates, desktop/mobile/web deployments. ACTIVELY TRIGGER whenever generating, modifying, or reviewing Godot projects or GDScript in a professional context, even if not explicitly requested. Not for basic syntax tutorials."
---

# `godot-craft`

Idiomatic, professional-grade standards for Godot 4 and GDScript: style, architecture, testing, tooling, performance, patterns, networking, and export.

## How to Use This Skill
**Do not implement from this file.** It is only the entry point. Find the precise rules in the **Navigation Map**, load only the few files relevant to the task, and enforce them.

👉 **[Read MAP.md](./MAP.md)** 👈

## When to Use
- Writing, reviewing, or refactoring GDScript code or scene files (`.tscn`) in a professional Godot codebase.
- Structuring nodes, scenes, and custom Resources to build reusable game features.
- Setting up or fixing unit tests, integration tests, or CI/CD pipelines.
- Optimizing game performance (profiling, draw calls, physics, allocations, or pooling).
- Designing multiplayer synchronization, state machines, component-based nodes, or custom Resource architectures.

## Decision Flow — which files to load
- Naming / static typing / member ordering / enums / comments / signals → `style/*`
- Scene architecture / "Call Down, Signal Up" / singletons / project layout / scene trees → `architecture/*`
- Unit tests / mocking / integration tests / headless test runner / CI → `testing/*`
- gdtoolkit / gdlint / gdformat / project settings / editor warnings → `toolkit/*`
- Profiling / GDScript speed / rendering / physics / pooling → `performance/*`
- State machines / component patterns / observers / custom Resources → `patterns/*`
- Multiplayer architecture / synchronization / RPCs / server authority / network security → `networking/*`
- Export pipelines / itch.io & Steam deployments / PCK size optimization / platform settings → `export/*`

## Non-Negotiables
Three rules cut across every file:
1. **Static typing is mandatory everywhere.** Every variable, function parameter, and return value must have a static type or use type inference `:=`. Enable project-wide warnings for untyped declarations and unsafe access as errors. (`references/style/typing.md`)
2. **Composition over inheritance; scenes must be independently runnable.** Build complex behaviors via small, focused nodes/components. Every scene (`.tscn`) must be capable of running on its own for testing, with dependencies injected at the root of the scene. (`references/architecture/composition.md`)
3. **No fragile node references.** Do not call `get_parent()` or use hardcoded node paths. Connect nodes dynamically via `@export` variables or use `%` unique node names inside a scene. Use "Call Down, Signal Up" to communicate up the hierarchy. (`references/architecture/signals.md`, `references/architecture/scene-design.md`)

## Review Checklist
Run before approving GDScript / Godot changes:
1. **Static Typing**: No untyped variables, parameters, or return types; no implicit `Variant` unless explicitly intended and documented.
2. **Node Referencing**: No `get_parent()` calls or hardcoded paths; dependencies injected via `@export` or resolved via `%` Unique Name.
3. **Scene Cohesion**: Scenes are self-contained, independently runnable, and expose a clean API via public methods and signals.
4. **Member Ordering**: GDScript files strictly adhere to the canonical member order (signals -> enums -> consts -> @export -> @onready -> lifecycle -> public -> private).
5. **Signal Connection**: Signals connected via code use callable-based syntax (`signal.connect(callable)`); no string-based connects.
6. **Singletons/Autoloads**: Singletons are restricted to global cross-cutting services (e.g. AudioManager, SceneTransitioner, GameState), not used for simple scene coordination.
7. **Testing**: Business logic and scene interactions are covered by unit/integration tests using GUT or GdUnit4, and run clean headlessly in CI.
8. **Tooling Check**: Code passes `gdlint` rules and `gdformat` formatting checks; zero warnings in the editor output.
9. **Performance & Memory**: Critical loops avoid `$Node` path lookups and memory allocations; all dynamic connections are cleaned up or nodes freed using `queue_free()`.
10. **State Management**: Complex behaviors use state machines or components rather than monolithic scripts with nested `if/else` ladders.

Always apply these standards when writing or reviewing Godot 4 / GDScript code.
