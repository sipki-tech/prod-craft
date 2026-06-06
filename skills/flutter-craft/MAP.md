# flutter-craft Navigation Map

## 🎨 Dart Style
| File | When to Read |
|---|---|
| [`style/naming.md`](./references/style/naming.md) | Naming packages, files, classes, variables, constants, import prefixes. |
| [`style/types.md`](./references/style/types.md) | Type annotations, when to omit, `dynamic` vs `Object?`, type promotion. |
| [`style/null-safety.md`](./references/style/null-safety.md) | Sound null safety, `late`, `!`, null-aware operators, flow analysis. |
| [`style/collections.md`](./references/style/collections.md) | Literal syntax, spread, collection-if/for, `Iterable` vs `List`, `Map`. |
| [`style/classes.md`](./references/style/classes.md) | Constructors (const, factory, named, redirecting), mixins, extensions. |
| [`style/comments.md`](./references/style/comments.md) | Doc comments `///`, Markdown, what to document, TODO ownership. |
| [`style/imports.md`](./references/style/imports.md) | Import ordering, `show`/`hide`, relative vs package, no `part`. |

## ⚡ Dart 3 Features
| File | When to Read |
|---|---|
| [`dart3/patterns.md`](./references/dart3/patterns.md) | Pattern matching, destructuring, switch expressions, guard clauses. |
| [`dart3/class-modifiers.md`](./references/dart3/class-modifiers.md) | `sealed`, `final`, `base`, `interface`, `mixin` — when and why. |
| [`dart3/records.md`](./references/dart3/records.md) | Record types, positional vs named fields, return multiple values. |

## 🔄 Async & Data Flow
| File | When to Read |
|---|---|
| [`async/futures.md`](./references/async/futures.md) | `async`/`await` vs `.then()`, `Future.wait`, `Completer`, `unawaited`. |
| [`async/streams.md`](./references/async/streams.md) | Single vs broadcast, `StreamController`, `async*`/`yield`, backpressure. |
| [`async/isolates.md`](./references/async/isolates.md) | `Isolate.run`, `compute()`, when CPU-bound vs I/O-bound, message passing. |
| [`async/errors.md`](./references/async/errors.md) | `Exception` vs `Error`, custom exceptions, `Result` pattern with sealed classes, `try`/`catch` scope. |

## 🏗️ Architecture
| File | When to Read |
|---|---|
| [`architecture/layered.md`](./references/architecture/layered.md) | Flutter layered architecture: UI (Views + ViewModels), Data (Repos + Services), dependency rule. |
| [`architecture/bloc.md`](./references/architecture/bloc.md) | BLoC pattern: Events, States, Cubits, BlocProvider/Builder/Listener/Consumer, Cubit vs Bloc. |
| [`architecture/feature-first.md`](./references/architecture/feature-first.md) | Feature-first folder structure vs layer-first, module boundaries. |
| [`architecture/di.md`](./references/architecture/di.md) | Dependency injection: `get_it`, `BlocProvider`, service locator, scoping. |
| [`architecture/domain-modeling.md`](./references/architecture/domain-modeling.md) | Entities, value objects, `freezed` for immutable models, `copyWith`, JSON serialization. |
| [`architecture/state.md`](./references/architecture/state.md) | Ephemeral vs app state, when `setState` vs `ValueNotifier` vs Cubit vs Bloc. |

## 🧩 Widgets & UI
| File | When to Read |
|---|---|
| [`widgets/composition.md`](./references/widgets/composition.md) | Widget decomposition, extract widgets vs methods, const constructors, `Key` usage. |
| [`widgets/performance.md`](./references/widgets/performance.md) | Avoiding unnecessary rebuilds, `const`, `RepaintBoundary`, `ListView.builder`, shader warmup. |
| [`widgets/responsive.md`](./references/widgets/responsive.md) | `LayoutBuilder`, `MediaQuery`, adaptive vs responsive, breakpoints. |
| [`widgets/theming.md`](./references/widgets/theming.md) | `ThemeData`, `ColorScheme`, `TextTheme`, Material 3, dark mode, design tokens. |

## 🎬 Animations
| File | When to Read |
|---|---|
| [`animations/implicit.md`](./references/animations/implicit.md) | `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSwitcher` — when and how. |
| [`animations/explicit.md`](./references/animations/explicit.md) | `AnimationController`, `Tween`, `CurvedAnimation`, `AnimatedBuilder`, lifecycle. |
| [`animations/hero.md`](./references/animations/hero.md) | Hero transitions, `flightShuttleBuilder`, cross-page animations. |

## ♿ Accessibility
| File | When to Read |
|---|---|
| [`accessibility/semantics.md`](./references/accessibility/semantics.md) | `Semantics` widget, labels, hints, screen reader support, focus, contrast. |

## 🧪 Testing
| File | When to Read |
|---|---|
| [`testing/unit.md`](./references/testing/unit.md) | `test` package, `group`, `setUp`/`tearDown`, matchers, testing pure Dart. |
| [`testing/widget.md`](./references/testing/widget.md) | `testWidgets`, `WidgetTester`, `find.*`, `pump`, `pumpAndSettle`, testing behavior. |
| [`testing/bloc.md`](./references/testing/bloc.md) | `bloc_test`, `blocTest()`, `act`, `expect`, `seed`, testing Cubits and Blocs. |
| [`testing/mocking.md`](./references/testing/mocking.md) | `mocktail`, `Mock`, `when`, `verify`, `any()`, faking repositories. |
| [`testing/golden.md`](./references/testing/golden.md) | Golden files, deterministic fonts, CI env, `matchesGoldenFile`, update workflow. |
| [`testing/integration.md`](./references/testing/integration.md) | `integration_test`, `IntegrationTestWidgetsFlutterBinding`, patrol. |

## 🛠️ Toolkit
| File | When to Read |
|---|---|
| [`toolkit/linting.md`](./references/toolkit/linting.md) | `analysis_options.yaml`, `very_good_analysis`, custom rules, `// ignore` policy. |
| [`toolkit/codegen.md`](./references/toolkit/codegen.md) | `build_runner`, `freezed`, `json_serializable`, managing generated code. |
| [`toolkit/ci.md`](./references/toolkit/ci.md) | CI pipeline: `flutter analyze`, `flutter test`, coverage, golden CI, versioning. |
| [`toolkit/pub.md`](./references/toolkit/pub.md) | `pubspec.yaml`, version constraints, `pub upgrade`, `pub outdated`, lock file. |

## 🍳 Recipes
| File | When to Read |
|---|---|
| [`recipes/navigation.md`](./references/recipes/navigation.md) | `go_router`, declarative routing, deep links, guards, shell routes, nested navigation. |
| [`recipes/forms.md`](./references/recipes/forms.md) | `Form`, `FormField`, validators, `TextEditingController` lifecycle, auto-validation. |
| [`recipes/i18n.md`](./references/recipes/i18n.md) | `flutter_localizations`, ARB files, `intl`, generated locale classes. |
| [`recipes/platform-channels.md`](./references/recipes/platform-channels.md) | Method channels, event channels, Pigeon for type-safe native interop. |
| [`recipes/error-handling.md`](./references/recipes/error-handling.md) | Global error handling (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`), crash reporting integration. |

## 🔒 Security
| File | When to Read |
|---|---|
| [`security/security.md`](./references/security/security.md) | `flutter_secure_storage`, obfuscation, certificate pinning, API key handling, no secrets in client. |

## 📦 Assets (copy-paste starters)
| File | When to Read |
|---|---|
| [`assets/analysis_options.yaml`](./assets/analysis_options.yaml) | Strict lint config (VGV-based). |
| [`assets/feature_structure.md`](./assets/feature_structure.md) | Reference template for feature-first BLoC + Repository folder layout. |
| [`assets/bloc_skeleton.dart.tmpl`](./assets/bloc_skeleton.dart.tmpl) | BLoC/Cubit + Events + State skeleton with freezed. |
| [`assets/widget_test_skeleton.dart.tmpl`](./assets/widget_test_skeleton.dart.tmpl) | Widget test skeleton with mocktail + pump. |
