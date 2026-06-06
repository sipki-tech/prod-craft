# Project Layout & File Structure

This document defines the canonical, feature-first directory structure for production Flutter applications. It enforces clear boundaries between features and separates concerns between the app shell, business logic, and reusable components.

## Directory Structure

```text
lib/
├── app/                    # App widget, router, theme, DI
│   ├── app.dart
│   ├── router.dart
│   └── theme.dart
├── features/               # Feature modules (the core of the app)
│   └── <feature_name>/
│       ├── data/           # Repositories, data sources, DTOs
│       │   ├── <feature>_repository.dart
│       │   └── models/
│       ├── logic/          # BLoC / Cubit + Events + States
│       │   ├── <feature>_bloc.dart
│       │   ├── <feature>_event.dart
│       │   └── <feature>_state.dart
│       └── view/           # Widgets, pages, dialogs
│           ├── <feature>_page.dart
│           └── widgets/
├── shared/                 # Cross-feature: constants, extensions, common widgets
│   ├── constants/
│   ├── extensions/
│   └── widgets/
├── l10n/                   # Localization ARB files
└── main.dart               # Entry point, runApp, DI init

test/
├── features/               # Mirrors lib/features/
│   └── <feature_name>/
│       ├── data/
│       ├── logic/
│       └── view/
├── helpers/                # Shared test utilities, fakes, pump helpers
└── golden/                 # Golden test files (if separated)
```

## The `app/` Directory Explained
The `app/` directory acts as the shell of your application. It configures everything necessary to boot the app before handing off to individual features.
- `app.dart`: Contains the root `MaterialApp` or `CupertinoApp` widget.
- `router.dart`: Configures the global navigation layer (e.g., `go_router`).
- `theme.dart`: Defines the global `ThemeData` and `ColorScheme`.
- Dependency injection initialization (e.g. `service_locator.dart` if using `get_it`) also belongs here or alongside `main.dart`.

## Where Does It Go?

| What are you building? | Where does it go? |
|---|---|
| **New BLoC / Cubit** | `lib/features/<feature_name>/logic/` |
| **New Screen / Page** | `lib/features/<feature_name>/view/<feature_name>_page.dart` |
| **Feature-specific Widget** | `lib/features/<feature_name>/view/widgets/` |
| **Cross-feature Widget** | `lib/shared/widgets/` |
| **New Repository** | `lib/features/<feature_name>/data/` |
| **Data Model / Entity** | `lib/features/<feature_name>/data/models/` |
| **New Route / Deep Link** | Add to `lib/app/router.dart` (if using global routing) |
| **API Client / Network Layer** | `lib/shared/network/` or a dedicated core feature |
| **Unit Test for BLoC** | `test/features/<feature_name>/logic/<feature>_bloc_test.dart` |
| **Widget Test for Screen** | `test/features/<feature_name>/view/<feature>_page_test.dart` |
