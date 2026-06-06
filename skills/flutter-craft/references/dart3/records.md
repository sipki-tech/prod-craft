# Dart 3 Records

Records provide a lightweight, type-safe way to group multiple values without the boilerplate of defining dedicated classes. Use them for ad-hoc data structures, multiple return values, and scoped local state.

**PREFER records over custom classes for private, library-local data grouping.**
- **Reason:** Records eliminate the boilerplate of writing `class` definitions, constructors, and `hashCode`/`==` overrides for simple, ephemeral data passed between private methods.
```dart
// Good
(String, int) _getLatestUser() {
  return ('Alice', 24);
}

// Bad
class _UserData {
  final String name;
  final int age;
  _UserData(this.name, this.age);
}
_UserData _getLatestUser() {
  return _UserData('Alice', 24);
}
```

**DO use named fields in records when returning three or more values, or when types are ambiguous.**
- **Reason:** Positional fields with the same type (e.g., `(double, double)`) are error-prone because the caller can easily swap them. Named fields provide explicit context and safety at the call site.
```dart
// Good
({double lat, double lng}) getCoordinates() {
  return (lat: 37.77, lng: -122.41);
}

// Bad
(double, double) getCoordinates() {
  return (37.77, -122.41);
}
```

**AVOID using records for public APIs that expose complex domain models.**
- **Reason:** Records lack methods, cannot implement interfaces, and their schema cannot be documented or extended centrally. Domain models with behavior or broad reuse should remain nominal classes.
```dart
// Good
class UserProfile {
  final String id;
  final String name;
  bool get isValid => id.isNotEmpty;
  UserProfile({required this.id, required this.name});
}

// Bad
typedef UserProfile = ({String id, String name});
```

**DO use records to cleanly return both a result and an error status.**
- **Reason:** It provides a lightweight alternative to `Either` or `Result` wrappers for simple internal operations without introducing a third-party dependency or generic class overhead.
```dart
// Good
({bool success, String? errorMessage}) validateInput(String input) {
  if (input.isEmpty) return (success: false, errorMessage: 'Empty');
  return (success: true, errorMessage: null);
}

// Bad
Map<String, dynamic> validateInput(String input) {
  if (input.isEmpty) return {'success': false, 'error': 'Empty'};
  return {'success': true};
}
```

**PREFER destructuring records immediately upon receipt.**
- **Reason:** Accessing fields via `$1` or `$2` reduces readability and loses semantics. Destructuring binds the values to meaningful local variables right away.
```dart
// Good
final (name, age) = getUserInfo();
print('User $name is $age years old.');

// Bad
final info = getUserInfo();
print('User ${info.$1} is ${info.$2} years old.');
```
