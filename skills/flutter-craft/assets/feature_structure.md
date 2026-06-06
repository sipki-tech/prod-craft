# Feature-First Architecture Layout

This project follows a canonical feature-first architecture, primarily using BLoC for state management and Repositories for data handling. Each feature is self-contained.

```
lib/
├── core/                           # Shared utilities, extensions, UI components, and base classes
├── main.dart                       # App entry point, bootstrap, and global providers setup
└── features/
    └── [feature_name]/             # E.g., 'authentication', 'profile', 'feed'
        ├── models/                 # Data classes and entities specific to this feature
        │   └── feature_model.dart  # E.g., user_model.dart (often generated with freezed/json_serializable)
        ├── repositories/           # Data layer - fetching and saving data for the feature
        │   └── feature_repository.dart
        ├── bloc/                   # Business logic layer using BLoC or Cubit
        │   ├── feature_bloc.dart   # The BLoC/Cubit class
        │   ├── feature_event.dart  # BLoC events (typically sealed classes)
        │   └── feature_state.dart  # BLoC state (often using freezed classes)
        └── view/                   # UI layer
            ├── feature_page.dart   # The main routable page widget, setting up the BlocProvider
            ├── feature_view.dart   # The view that consumes the BLoC state
            └── widgets/            # Smaller, reusable UI components specific to this feature
                └── feature_widget.dart
```

### Key Concepts

*   **`models/`**: Pure data entities. If using `freezed` or `json_serializable`, the generated `.g.dart` and `.freezed.dart` files live alongside them here.
*   **`repositories/`**: Abstracts data sources (APIs, local databases). The BLoC communicates with repositories, not directly with data sources.
*   **`bloc/`**: Contains the application logic. Transforms `events` (user actions) into `states` (UI states).
*   **`view/`**: Contains the presentation logic. We separate `Page` (injects dependencies like BLoC) and `View` (consumes the BLoC). `widgets/` contain smaller components used only by this feature.
