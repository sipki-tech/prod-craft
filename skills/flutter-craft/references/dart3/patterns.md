# Dart 3 Patterns

Leverage Dart 3 pattern matching to extract data, handle complex control flow, and validate object shapes declaratively. These rules define how to use destructuring and pattern matching safely in production.

**PREFER using exhaustive switch statements over `if-else` chains for sealed classes and enums.**
- **Reason:** The compiler guarantees exhaustiveness for sealed types, ensuring that new subtypes must be explicitly handled, which eliminates unhandled states at runtime.
```dart
// Good
switch (networkResponse) {
  case Success(data: final data):
    handleData(data);
  case Failure(error: final error):
    handleError(error);
}

// Bad
if (networkResponse is Success) {
  handleData(networkResponse.data);
} else if (networkResponse is Failure) {
  handleError(networkResponse.error);
}
```

**DO use destructuring to extract multiple fields from an object or record.**
- **Reason:** It reduces boilerplate variable declarations, removes redundant getter calls, and closely binds the variable declaration to its usage.
```dart
// Good
final User(:name, :age) = user;
print('Name: $name, Age: $age');

// Bad
final name = user.name;
final age = user.age;
print('Name: $name, Age: $age');
```

**AVOID overusing nested pattern matching that makes logic difficult to read.**
- **Reason:** Deeply nested patterns (e.g., extracting values from nested maps inside switch expressions) can become unreadable. Extract into variables or separate functions if the nesting exceeds two levels.
```dart
// Good
final json = {'user': {'name': 'Alice', 'role': 'admin'}};
if (json case {'user': final user}) {
  if (user case {'name': String name, 'role': 'admin'}) {
    grantAccess(name);
  }
}

// Bad
final json = {'user': {'name': 'Alice', 'role': 'admin'}};
if (json case {'user': {'name': String name, 'role': 'admin'}}) {
  grantAccess(name);
}
```

**PREFER `if-case` for single-condition shape validation and extraction.**
- **Reason:** It elegantly combines type promotion, null checks, and assignment in a single line, rather than using multiple `if` conditions and `is` checks.
```dart
// Good
if (response case {'status': 200, 'data': List data}) {
  processData(data);
}

// Bad
if (response is Map && response['status'] == 200 && response['data'] is List) {
  processData(response['data'] as List);
}
```

**DO use logical-or (`|`) patterns to group identical branch outcomes in switch statements.**
- **Reason:** Grouping identical outcomes reduces code duplication and centralizes the logic for shared states.
```dart
// Good
switch (shape) {
  case Square(size: var s) | Circle(size: var s):
    print('Size is $s');
  case Rectangle():
    print('Rectangle');
}

// Bad
switch (shape) {
  case Square(size: var s):
    print('Size is $s');
  case Circle(size: var s):
    print('Size is $s');
  case Rectangle():
    print('Rectangle');
}
```
