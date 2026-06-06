# Null Safety

Dart's sound null safety system guarantees that variables cannot be null unless explicitly declared. Our null safety rules enforce strict compilation-time safety over runtime exceptions.

**Treat the bang operator (`!`) as a code smell.**
- **Reason:** Force-unwrapping overrides the compiler's safety nets and risks fatal runtime crashes. Always prefer conditional unwrapping, null-aware operators, or providing fallback values. Any use of `!` requires explicit justification.
```dart
// Good
final displayName = user?.name ?? 'Guest';
if (user != null) {
  processUser(user);
}

// Bad
final displayName = user!.name; // Will crash if user is null
```

**Strictly scope `late` variables.**
- **Reason:** The `late` keyword defers initialization checks to runtime, introducing the risk of `LateInitializationError`. Restrict `late` to expensive lazy initializations or fields initialized by framework lifecycles (e.g., Flutter's `initState`).
```dart
// Good
late final ExpensiveCache _cache = ExpensiveCache(); // Lazy initialization

// Bad
late String currentStatus; // Assigned randomly across disparate methods
```

**Prefer null-aware operators (`?.`, `??`, `??=`) over verbose manual checks.**
- **Reason:** Null-aware operators are idiomatic, concise, and often safer than manual `if` branches for accessing or assigning defaults.
```dart
// Good
final theme = userConfig?.preferences?.theme ?? defaultTheme;
cachedValue ??= computeValue();

// Bad
Theme theme = defaultTheme;
if (userConfig != null && userConfig.preferences != null && userConfig.preferences.theme != null) {
  theme = userConfig.preferences.theme;
}
```

**Do not explicitly initialize variables to `null`.**
- **Reason:** In Dart, if a variable has a nullable type, it is implicitly initialized to `null`. Adding `= null` is redundant and adds noise.
```dart
// Good
String? errorMessage;

// Bad
String? errorMessage = null;
```

**Use sealed classes or Option types for ambiguous null states.**
- **Reason:** When `null` carries semantic meaning (e.g., "loading" vs "not found" vs "error"), using `null` creates ambiguity. Explicitly model these states.
```dart
// Good
sealed class ProfileState {}
class ProfileLoading extends ProfileState {}
class ProfileLoaded extends ProfileState { final User? user; }

// Bad
User? userProfile; // Is it null because it's loading, failed, or the user has no profile?
```
