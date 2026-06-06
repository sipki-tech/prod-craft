# `godot-craft` Navigation Map

Load only the files relevant to your current task. Each row says when to read it. Three cross-cutting rules underpin everything: **static typing is mandatory everywhere** (`style/typing.md`), **composition over inheritance** (`architecture/composition.md`), and **no fragile node references** (`architecture/scene-design.md`).

## 🎨 Style

| File | When to Read |
|---|---|
| [`style/naming.md`](./references/style/naming.md) | Naming files, classes, variables, constants, methods, and signals. |
| [`style/typing.md`](./references/style/typing.md) | Enforcing static typing, type inference, return types, and editor warnings. |
| [`style/structure.md`](./references/style/structure.md) | Structuring GDScript member layout (variables, lifecycles, public/private methods). |
| [`style/enums.md`](./references/style/enums.md) | Designing enums, constant-case values, and pattern matching. |
| [`style/comments.md`](./references/style/comments.md) | Writing API-level `##` comments and inline explanations. |
| [`style/signals.md`](./references/style/signals.md) | Defining and naming signals, parameter typing, and method mapping. |

## 🏗️ Architecture

| File | When to Read |
|---|---|
| [`architecture/composition.md`](./references/architecture/composition.md) | Designing scenes with composition over inheritance, and independent testing. |
| [`architecture/signals.md`](./references/architecture/signals.md) | Coordinating node communication via "Call Down, Signal Up" without direct coupling. |
| [`architecture/autoloads.md`](./references/architecture/autoloads.md) | Utilizing singletons appropriately vs using dependency injection. |
| [`architecture/project-layout.md`](./references/architecture/project-layout.md) | Organizing feature folders, managing assets, and using unique node names. |
| [`architecture/scene-design.md`](./references/architecture/scene-design.md) | Designing shallow scene trees, injecting dependencies, and internal wiring. |

## 🧪 Testing

| File | When to Read |
|---|---|
| [`testing/unit.md`](./references/testing/unit.md) | Writing unit tests using GUT/GdUnit4, decoupling logic, and mirroring directories. |
| [`testing/mocking.md`](./references/testing/mocking.md) | Stubbing/spying using GUT doubling, and creating test doubles for Autoloads and Resources. |
| [`testing/integration.md`](./references/testing/integration.md) | Testing multi-node/scene interactions, UI events, signals, and cleanup. |
| [`testing/ci.md`](./references/testing/ci.md) | Running tests headlessly in CI, configuring leak checks, and excluding tests from builds. |

## 🛠️ Toolkit

| File | When to Read |
|---|---|
| [`toolkit/linting.md`](./references/toolkit/linting.md) | Linter rules with `gdlint`, `.gdlintrc` configuration, and pre-commit checks. |
| [`toolkit/formatting.md`](./references/toolkit/formatting.md) | Style formatting with `gdformat`, configuration, and checking in CI. |
| [`toolkit/ci.md`](./references/toolkit/ci.md) | Integrating linting, formatting, headless tests, and exports in GitHub Actions. |
| [`toolkit/editor.md`](./references/toolkit/editor.md) | Configuring Godot project settings to raise quality warnings and treat them as errors. |

## ⚡ Performance

| File | When to Read |
|---|---|
| [`performance/profiling.md`](./references/performance/profiling.md) | Profiling CPU, GPU, monitors, and finding bottlenecks using the debugger. |
| [`performance/gdscript.md`](./references/performance/gdscript.md) | Optimizing GDScript code, reducing allocations, and caching node references. |
| [`performance/rendering.md`](./references/performance/rendering.md) | Reducing draw calls, optimizing lightmaps, and managing visibility culling. |
| [`performance/physics.md`](./references/performance/physics.md) | Selecting colliders, setting tick rates, layer masking, and sleeping inactive bodies. |
| [`performance/pooling.md`](./references/performance/pooling.md) | Implementing object pooling for high-frequency objects (projectiles, particles). |

## 🎮 Patterns

| File | When to Read |
|---|---|
| [`patterns/state-machine.md`](./references/patterns/state-machine.md) | Choosing and implementing finite state machines (enums vs nodes vs resources). |
| [`patterns/component.md`](./references/patterns/component.md) | Building modular behaviors (e.g. HealthComponent) as reusable child nodes. |
| [`patterns/observer.md`](./references/patterns/observer.md) | Decoupling features using the Observer pattern and managing signal lifecycles. |
| [`patterns/resource-pattern.md`](./references/patterns/resource-pattern.md) | Using custom Resource classes for pluggable data, strategies, and configurations. |

## 🌐 Networking

| File | When to Read |
|---|---|
| [`networking/architecture.md`](./references/networking/architecture.md) | Structuring client-server/P2P authority, and choosing network protocols. |
| [`networking/synchronization.md`](./references/networking/synchronization.md) | Replicating state with MultiplayerSpawner, MultiplayerSynchronizer, and RPCs. |
| [`networking/security.md`](./references/networking/security.md) | Hardening game state validation and mitigating client-side cheats. |

## 📦 Export

| File | When to Read |
|---|---|
| [`export/pipeline.md`](./references/export/pipeline.md) | Automating exports via CLI command line, butler, and SteamPipe. |
| [`export/optimization.md`](./references/export/optimization.md) | Reducing build/PCK sizes, custom export templates, and cleanup. |
| [`export/platforms.md`](./references/export/platforms.md) | Adjusting platform-specific inputs, graphics settings, and feature tags. |

## 📦 Assets (copy-paste starters)

| File | Use |
|---|---|
| [`assets/gdlintrc`](./assets/gdlintrc) | Opinionated `.gdlintrc` configuration for `gdlint`. |
| [`assets/gdformatrc`](./assets/gdformatrc) | Style formatter configurations for `gdformat`. |
| [`assets/ci-godot.yml`](./assets/ci-godot.yml) | GitHub Actions CI/CD pipeline template (lint, format, test, export). |
| [`assets/project_settings.md`](./assets/project_settings.md) | Project settings snippet for strict code quality alerts and warnings-as-errors. |
| [`assets/object_pool.gd`](./assets/object_pool.gd) | Production-grade ObjectPool node component for scene-local pooling. |
| [`assets/object_pool_manager.gd`](./assets/object_pool_manager.gd) | Global ObjectPoolManager singleton for cross-scene pool access. |
