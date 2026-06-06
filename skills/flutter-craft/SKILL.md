---
name: flutter-craft
description: "Production-grade standards for Dart and Flutter. Enforces layered architecture, BLoC/Cubit state management, widget composition, Effective Dart style, sound null safety, and strict testing practices (unit, widget, golden, integration). Covers Dart 3 patterns, freezed, mocktail, go_router, performance profiling, accessibility, theming, and analysis_options."
---

# flutter-craft

## How to Use This Skill
Do not implement from this file. It is only the entry point. Find the precise rules in the Navigation Map, load only the few files relevant to the task, and enforce them.

👉 **[Go to Navigation Map (MAP.md)](./MAP.md)**

## When to Use
- Writing, reviewing, or refactoring Dart code in a professional codebase.
- Composing or decomposing Flutter widgets.
- Designing state management with BLoC/Cubit.
- Setting up or fixing tests (unit, widget, golden, integration).
- Configuring linting, CI, or code generation.
- Designing navigation, forms, theming, or animations.
- Reviewing accessibility or performance.

## Decision Flow
If you have a question about... -> Read this category:
- Naming / type annotation / null safety / imports → `style/*`
- Pattern matching / sealed classes / class modifiers → `dart3/*`
- async/await / Streams / Isolates / error handling → `async/*`
- Where does this code go? / layering / BLoC / DI / feature folders → `architecture/*`
- Widget composition / keys / rebuild / responsive / theme → `widgets/*`
- Animations / curves / hero / implicit vs explicit → `animations/*`
- Unit / widget / BLoC / golden / integration test → `testing/*`
- Lint config / build_runner / CI / pub → `toolkit/*`
- Navigation / forms / i18n / platform channels → `recipes/*`
- Secure storage / obfuscation / certificate pinning → `security/*`
- Accessibility / semantics / screen readers → `accessibility/*`
- Performance / rebuild optimization / shader warmup → `widgets/*`

## Non-Negotiables
1. **State is immutable.** BLoC/Cubit states are `@immutable` classes (or `freezed`). Never mutate state in place; always emit a new state instance.
2. **Null safety is sound.** Never use `!` without a comment justifying why. Prefer null-aware operators, flow analysis, and pattern matching.
3. **Widgets are small and composable.** Extract widgets to classes (not methods) for reuse and performance. Constructors should be `const` wherever possible.
4. **Every public API has a doc comment.** Use `///` with clear first sentence, parameters documented, return values stated.

## Review Checklist
1. Dependency rule intact — no upward imports; view layer free of data/repository types.
2. BLoC/Cubit states are `@immutable`; no mutable fields; events are `sealed` classes.
3. Null safety upheld — no unguarded `!` operators; `late` only where lifecycle guarantees it.
4. Widget tree decomposed — no methods returning widgets; extracted widgets have `const` constructors.
5. `Key` used on dynamically reordered or conditionally shown widget lists.
6. Animations dispose their `AnimationController` in `dispose()`.
7. Every `StreamSubscription` and `TextEditingController` is disposed.
8. Unit tests cover business logic; widget tests cover UI behavior; golden tests cover visual regression.
9. Mocking uses `mocktail`; only boundary dependencies are mocked.
10. `Semantics` widgets and labels present for interactive elements (accessibility).
11. No hardcoded strings in UI — all user-facing text goes through i18n.
12. `flutter analyze` reports zero issues; analysis_options.yaml uses strict rules.
13. Generated code (`*.g.dart`, `*.freezed.dart`) is up to date and committed.
14. `pubspec.yaml` has explicit version constraints; no `any` dependencies.
