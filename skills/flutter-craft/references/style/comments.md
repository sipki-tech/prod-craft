# Comments

Dart's documentation conventions rely on strict formatting to properly generate API references via `dart doc`.

**Use `///` for documentation comments.**
- **Reason:** Dart tools parse triple-slash comments to build API docs. Block-style documentation comments (`/** ... */`) are considered legacy and should be avoided.
```dart
// Good
/// Authenticates the user with the remote server.
Future<void> login() async {}

// Bad
/**
 * Authenticates the user with the remote server.
 */
Future<void> login() async {}
```

**Start documentation with a concise, single-sentence summary.**
- **Reason:** The first sentence (up to the first period) is extracted for summary lists in generated documentation. It should describe the API's behavior from the caller's perspective.
```dart
// Good
/// Calculates the total area of the geometry.
///
/// This involves complex vertex traversal and should be cached.
double calculateArea() {}

// Bad
/// This function is used to calculate the area of the geometry
/// by traversing all the vertices which can be slow.
double calculateArea() {}
```

**Use square brackets `[identifier]` to reference in-scope names.**
- **Reason:** Bracketed names automatically generate hyperlinks to the referenced parameters, variables, classes, or methods in the output docs.
```dart
// Good
/// Dispatches the [event] to the registered [Listener]s.
void dispatch(Event event) {}

// Bad
/// Dispatches the `event` to the registered `Listener`s.
void dispatch(Event event) {}
```

**Avoid redundant or "stating the obvious" comments.**
- **Reason:** Comments that simply echo the method signature add noise and fall out of sync during refactoring. Document the "why" or edge cases, not just the "what".
```dart
// Good
/// Returns `true` if the device is currently on a metered network.
bool get isMetered;

// Bad
/// Gets the users.
///
/// Returns a list of [User].
List<User> getUsers() {}
```

**Use `//` for internal implementation details.**
- **Reason:** Standard double-slash comments are ignored by the doc generator. Use them inside method bodies to explain complex algorithmic decisions or hacks.
```dart
// Good
void alignPixels() {
  // Adding 0.5 prevents anti-aliasing blur on odd-pixel device ratios.
  final offset = position + 0.5;
}

// Bad
void alignPixels() {
  /// Add 0.5 to offset
  final offset = position + 0.5;
}
```
