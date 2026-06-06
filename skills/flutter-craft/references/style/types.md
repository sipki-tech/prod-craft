# Types

Type annotations in Dart should provide clarity for both the compiler and the developer, without causing unnecessary verbosity.

**Prefer type inference for local variables.**
- **Reason:** Keeps the code concise. Dart's analyzer strongly infers types from the assignment.
```dart
// Good
final users = <User>[];
var count = 0;

// Bad
final List<User> users = <User>[];
int count = 0;
```

**Annotate types for public interfaces and parameters.**
- **Reason:** Public APIs serve as contracts. Explicit types ensure the caller knows exactly what to provide and expect, without relying on inference.
```dart
// Good
String formatGreeting(String name) {
  return 'Hello, $name';
}

// Bad
formatGreeting(name) {
  return 'Hello, $name';
}
```

**Avoid `dynamic` unless interacting with untyped sources.**
- **Reason:** `dynamic` disables static analysis and null safety. Use `Object?` if a value can be anything, which forces explicit type checks before usage.
```dart
// Good
void handleResponse(Object? response) {
  if (response is Map<String, dynamic>) {
    // Safely casted
  }
}

// Bad
void handleResponse(dynamic response) {
  print(response['id']); // Dangerous, runtime exceptions likely
}
```

**Avoid redundant type arguments on generic instantiations.**
- **Reason:** Dart infers generic types from the variable declaration or context.
```dart
// Good
Set<String> validIds = {};
final Map<String, int> scores = {};

// Bad
Set<String> validIds = <String>{};
final scores = Map<String, int>();
```

**Use typedefs for complex function signatures.**
- **Reason:** Improves readability, provides semantic meaning, and centralizes the definition of reusable callback signatures.
```dart
// Good
typedef UserCallback = void Function(User user, {required bool isNew});
void registerListener(UserCallback callback) {}

// Bad
void registerListener(void Function(User user, {required bool isNew}) callback) {}
```
