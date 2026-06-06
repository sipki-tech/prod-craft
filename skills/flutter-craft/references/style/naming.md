# Naming

Dart relies on distinct casing conventions to visually differentiate between types, variables, and library files.

**Use `UpperCamelCase` for classes, enum types, typedefs, and type parameters.**
- **Reason:** Standardizes type identification and distinguishes types from instances or values.
```dart
// Good
class AuthenticationService {}
enum RequestState { idle, loading, success, failure }
typedef HttpInterceptor = Future<Request> Function(Request);

// Bad
class authentication_service {}
enum requestState { IDLE, LOADING }
```

**Use `lowercase_with_underscores` for file and directory names.**
- **Reason:** File systems handle case differently; using underscores ensures predictable, cross-platform behavior.
```dart
// Good
// lib/src/network/auth_service.dart

// Bad
// lib/src/network/AuthService.dart
// lib/src/network/auth-service.dart
```

**Use `lowerCamelCase` for variables, constants, properties, and methods.**
- **Reason:** Constant variables in Dart use `lowerCamelCase` rather than `SCREAMING_SNAKE_CASE` to keep code visually consistent and less noisy.
```dart
// Good
const int defaultTimeoutMs = 5000;
final DatabaseHelper dbHelper = DatabaseHelper();
void fetchUser() {}

// Bad
const int DEFAULT_TIMEOUT_MS = 5000;
final DatabaseHelper DbHelper = DatabaseHelper();
```

**Capitalize acronyms and abbreviations as standard words.**
- **Reason:** Prevents ambiguity and improves readability when multiple acronyms are adjacent.
```dart
// Good
class HttpConnection {}
String get userId => _userId;

// Bad
class HTTPConnection {}
String get userID => _userID;
```

**Prefix private declarations with an underscore `_`.**
- **Reason:** Dart enforces library-level privacy through the `_` prefix instead of access modifier keywords.
```dart
// Good
class UserSettings {
  String _accessToken;
  void _refresh() {}
}

// Bad
class UserSettings {
  String privateAccessToken;
  void refreshPrivate() {}
}
```
