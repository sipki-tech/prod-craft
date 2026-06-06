# Dart 3 Class Modifiers

Control class inheritance, implementation, and instantiation strictly using Dart 3 class modifiers. These rules enforce strong API boundaries, separating internal implementation details from external usage.

**PREFER `sealed` classes to model closed, finite type hierarchies (like algebraic data types).**
- **Reason:** `sealed` allows the compiler to enforce exhaustive `switch` statements across the subtypes. It prevents external libraries from extending the class while keeping the hierarchy open within the same library.
```dart
// Good
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

// Bad
abstract class Result {}
class Success extends Result {}
class Failure extends Result {}
```

**DO use `final` for classes that should not be extended or implemented outside their defining library.**
- **Reason:** `final` guarantees that external code cannot alter the behavior of your class via inheritance or interface mocking, ensuring internal invariants are preserved.
```dart
// Good
final class Configuration {
  final String url;
  Configuration(this.url);
}

// Bad
class Configuration {
  final String url;
  Configuration(this.url);
}
```

**PREFER `interface` for classes that are meant to be pure contracts.**
- **Reason:** It explicitly communicates that the class is designed to be implemented (mocked/stubbed) but never inherited, preventing fragile base class problems.
```dart
// Good
interface class DataRepository {
  void save(String data);
}

// Bad
abstract class DataRepository {
  void save(String data);
}
```

**AVOID `base` unless creating mixins or classes where strict inheritance (but no implementation) is strictly required.**
- **Reason:** `base` forces all subtypes to also be `base`, `final`, or `sealed`, which is viral and can restrict consumers of your API unnecessarily. Use it only when overriding methods via `implements` breaks the base functionality.
```dart
// Good
base class StateTracker {
  int _count = 0;
  void increment() => _count++;
}

// Bad
base class Logger {
  void log(String msg) => print(msg);
}
```

**DO combine `abstract` with other modifiers to prevent direct instantiation of pure base classes.**
- **Reason:** Modifiers like `interface`, `base`, or `final` do not prevent instantiation on their own. Adding `abstract` clearly designates the class as an uninstantiable template.
```dart
// Good
abstract interface class Cache {
  void put(String key, Object value);
}

// Bad
interface class Cache {
  void put(String key, Object value) {}
}
```
