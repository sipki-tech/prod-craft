# 🗺️ Roadmap: Language Skills for Vercel Ecosystem

This repository contains specialized AI agent skills for different programming languages, built for the open **Vercel `npx skills` CLI ecosystem**. 

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

## 📌 Phase 2: Dart
*Skill Name: `dart-craft`*
*Focus: Flutter integration, async programming, null safety, and state management.*
- [ ] Create `skills/dart-craft/` folder structure
- [ ] Detail UI/Widget composition patterns
- [ ] Async/await, Futures, and Streams handling
- [ ] Sound null safety guidelines
- [ ] BLoC/Provider state management idioms (if applicable)

## 📌 Phase 3: Swift
*Skill Name: `swift-craft`*
*Focus: Protocol-oriented programming, SwiftUI, safety, and conciseness.*
- [ ] Create `skills/swift-craft/` folder structure
- [ ] Protocol-oriented programming idioms
- [ ] Optionals and safe unwrapping (`guard let`, `if let`)
- [ ] SwiftUI declarative syntax and state (`@State`, `@Binding`)
- [ ] Combine / async-await for asynchronous tasks

## 📌 Phase 4: Kotlin
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
