# 🗺️ Roadmap: prod-craft Skills

This repository contains specialized AI agent skills for different programming languages and game engines, built for the open **Vercel `npx skills` CLI ecosystem**. 

These skills focus on professional "craft" rather than basic syntax — covering style, tooling, architecture, and recipes for experienced developers.

## 📁 Repository Structure
Following the Vercel multi-skill repository standard, all skills live in the `skills/` directory. Each skill contains a `SKILL.md` file with YAML frontmatter, a `MAP.md` for navigation, and `references/` for deep-dive documentation.

## 📌 Phase 1: Go (Golang) — ✅ Complete
*Skill Name: `go-craft`*
*Focus: Professional Go style, tooling, clean architecture, data, testing, security, observability, and recipes.*
- [x] Create `skills/go-craft/` structure
- [x] Write `SKILL.md` (frontmatter, When to Use, Decision Flow, Review Checklist) and full `MAP.md`
- [x] Implement `references/style/` (naming, errors, concurrency, structure, context, interfaces, enums, structs, functions, comments, time, slices-maps, generics)
- [x] Implement `references/architecture/` (clean, decorator, domain-modeling, transactions, wiring)
- [x] Implement `references/data/` (database, migrations, caching)
- [x] Implement `references/testing/` (unit, parallel, mocking, integration, fixtures-golden)
- [x] Implement `references/toolkit/` (linting, testing, protobuf, dev, observability, ci)
- [x] Implement `references/recipes/` (middleware, graceful-shutdown, config, grpc-api, background-jobs)
- [x] Implement `references/security/` (security, auth)
- [x] Implement `references/project.md` (standard layout)
- [x] Add `assets/` templates (golangci.yml, Taskfile.yml, contracts.go.tmpl, app_test_skeleton.go.tmpl, migration_phase.sql.tmpl)

## 📌 Phase 2: Protocol Buffers — ✅ Complete
*Skill Name: `proto-craft`*
*Focus: Schema design, wire compatibility, API design (AIPs), EasyP toolchain, protovalidate.*
- [x] Create `skills/proto-craft/` structure
- [x] Write `SKILL.md` and `MAP.md`
- [x] Implement `references/` (style, schema, api, toolkit)
- [x] Add `assets/` (easyp.yaml, Taskfile, example.proto)

## 📌 Phase 3: Flutter / Dart 3 — ✅ Complete
*Skill Name: `flutter-craft`*
*Focus: Widget composition, BLoC architecture, async programming, null safety, testing, and accessibility.*
- [x] Create `skills/flutter-craft/` structure
- [x] Write `SKILL.md` and `MAP.md`
- [x] Implement `references/style/` (naming, types, imports, classes, collections, comments, null-safety)
- [x] Implement `references/architecture/` (layered, feature-first, bloc, state, di, domain-modeling)
- [x] Implement `references/widgets/` (composition, performance, responsive, theming)
- [x] Implement `references/async/` (futures, streams, isolates, errors)
- [x] Implement `references/dart3/` (patterns, records, class-modifiers)
- [x] Implement `references/testing/` (unit, widget, golden, bloc, mocking, integration)
- [x] Implement `references/toolkit/` (linting, codegen, ci, pub)
- [x] Implement `references/recipes/` (navigation, forms, i18n, error-handling, platform-channels)
- [x] Implement `references/accessibility/` and `references/security/`
- [x] Add `assets/` (analysis_options.yaml, bloc_skeleton.dart.tmpl, widget_test_skeleton.dart.tmpl, feature_structure.md)

## 📌 Phase 4: Godot 4 / GDScript — ✅ Complete
*Skill Name: `godot-craft`*
*Focus: Static typing, composition over inheritance, scene design, state machines, networking, object pooling, and CI.*
- [x] Create `skills/godot-craft/` structure
- [x] Write `SKILL.md` (Non-Negotiables, Decision Flow, Review Checklist) and `MAP.md`
- [x] Implement `references/style/` (naming, typing, structure, enums, comments, signals)
- [x] Implement `references/architecture/` (composition, signals, autoloads, project-layout, scene-design)
- [x] Implement `references/patterns/` (state-machine, component, observer, resource-pattern)
- [x] Implement `references/testing/` (unit, mocking, integration, ci)
- [x] Implement `references/toolkit/` (linting, formatting, ci, editor)
- [x] Implement `references/performance/` (profiling, gdscript, rendering, physics, pooling)
- [x] Implement `references/networking/` (architecture, synchronization, security)
- [x] Implement `references/export/` (pipeline, optimization, platforms)
- [x] Add `assets/` (gdlintrc, gdformatrc, ci-godot.yml, project_settings.md, object_pool.gd, object_pool_manager.gd)

## 📌 Phase 5: Swift
*Skill Name: `swift-craft`*
*Focus: Protocol-oriented programming, SwiftUI, safety, and conciseness.*
- [ ] Create `skills/swift-craft/` folder structure
- [ ] Protocol-oriented programming idioms
- [ ] Optionals and safe unwrapping (`guard let`, `if let`)
- [ ] SwiftUI declarative syntax and state (`@State`, `@Binding`)
- [ ] Combine / async-await for asynchronous tasks

## 📌 Phase 6: Kotlin
*Skill Name: `kotlin-craft`*
*Focus: Coroutines, expressive syntax, Android specifics, and null safety.*
- [ ] Create `skills/kotlin-craft/` folder structure
- [ ] Idiomatic Kotlin (extension functions, data classes, sealed classes)
- [ ] Coroutines and Flows for async operations
- [ ] Null safety mechanisms (`?`, `!!`, `?:`)
- [ ] Jetpack Compose patterns (if applicable)

## 📈 Future Expansions
- Publishing the repository for public usage via `npx skills`.
- Testing the skills against real-world refactoring tasks.
- Potential new languages: Rust, TypeScript, Python.
