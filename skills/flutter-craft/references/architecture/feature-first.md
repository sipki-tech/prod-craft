# Feature-First Architecture

Organize your codebase around vertical features rather than horizontal technical layers to improve scalability and context cohesion.

**Group files by feature, not by layer**
- **Reason:** Feature-first modularity keeps related logic (UI, Bloc, Data) together, reducing context switching and making it easier to extract features into independent packages or micro-frontends.

```text
// Good
lib/
  features/
    auth/
      presentation/
        auth_page.dart
      application/
        auth_bloc.dart
      domain/
        user.dart
      infrastructure/
        auth_repository.dart

// Bad
lib/
  blocs/
    auth_bloc.dart
    user_bloc.dart
  views/
    auth_page.dart
    user_page.dart
  models/
    user.dart
```

**Maintain strict boundaries between features**
- **Reason:** Features should not reach directly into the internals of other features. If `Feature B` needs data from `Feature A`, it should go through a shared core domain, a shared Repository, or explicitly exposed public interfaces.

```dart
// Good
// orders feature uses explicitly shared core domain models
import 'package:app/core/domain/user.dart';

// Bad
// orders feature imports directly from auth's internal infrastructure layer
import 'package:app/features/auth/infrastructure/auth_local_storage.dart';
```
