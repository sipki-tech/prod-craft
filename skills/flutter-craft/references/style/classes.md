# Classes

Class designs in Dart should encapsulate state, minimize boilerplate, and clearly signal the intended inheritance model using class modifiers.

**Use initializing formals and super parameters.**
- **Reason:** Writing `this.field` and `super.field` in the constructor signature eliminates redundant type declarations and manual assignments in the constructor body.
```dart
// Good
class User {
  final String name;
  User(this.name);
}

class Admin extends User {
  final String role;
  Admin(super.name, this.role);
}

// Bad
class User {
  late final String name;
  User(String name) {
    this.name = name;
  }
}
```

**Omit manual getters and setters for simple properties.**
- **Reason:** Dart does not distinguish between accessing a public field and a getter method at the call site (`obj.field`). Direct fields are simpler; upgrade them to getters later if logic is required without breaking the API.
```dart
// Good
class Box {
  double width;
  double height;
  double get area => width * height; // Derived property
}

// Bad
class Box {
  double _width;
  double get width => _width;
  set width(double value) => _width = value;
}
```

**Use named constructors to clarify instantiation variants.**
- **Reason:** Named constructors communicate the exact format or state expected. This eliminates convoluted main constructors littered with boolean flags or optional parameters.
```dart
// Good
class Connection {
  Connection.fromSocket(Socket socket);
  Connection.mock();
}

// Bad
class Connection {
  Connection(Socket? socket, {bool isMock = false}) { ... }
}
```

**Use factory constructors to return cached instances or subtypes.**
- **Reason:** A `factory` constructor acts like a static method but uses standard instantiation syntax. This encapsulates caching, singleton logic, or polymorphic returns without changing how the client instantiates the object.
```dart
// Good
class Logger {
  static final _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();
}

// Bad
class Logger {
  static Logger getInstance() => Logger._internal(); // Java-style singleton getter
}
```

**Use modern class modifiers (`interface`, `base`, `sealed`) to strictly enforce architecture.**
- **Reason:** Unrestricted inheritance creates fragile hierarchies. Dart 3 class modifiers make your API contracts explicit, preventing unintended extensions or implementations.
```dart
// Good
abstract interface class DataRepository {
  Future<void> fetch();
}

sealed class AuthResult {} // Enforces exhaustive switch statements

// Bad
abstract class DataRepository { // Vague: should this be extended or implemented?
  Future<void> fetch();
}
```
