# Unit Testing

Unit tests focus on verifying the logic of individual functions, methods, or classes in isolation. They are the fastest and most reliable way to catch bugs early in the development lifecycle.

**Test a single class or function in isolation**
- **Reason:** Unit tests should run fast and focus on the business logic of a single unit without external dependencies.
```dart
// Good
void main() {
  test('Counter increments value', () {
    final counter = Counter();
    counter.increment();
    expect(counter.value, 1);
  });
}
```
```dart
// Bad
void main() {
  test('Counter increments value with UI', () {
    final counter = Counter();
    // Involves widget testing logic in a unit test
    expect(find.text('0'), findsOneWidget);
  });
}
```

**Group related tests together using the `group` function**
- **Reason:** Grouping tests makes the test output easier to read and allows setting up shared preconditions using `setUp` and `tearDown`.
```dart
// Good
void main() {
  group('StringParser', () {
    test('parses empty string', () {
      // ...
    });
    test('parses valid string', () {
      // ...
    });
  });
}
```
```dart
// Bad
void main() {
  test('StringParser parses empty string', () {
    // ...
  });
  test('StringParser parses valid string', () {
    // ...
  });
}
```

**Use descriptive test names that explain the expected behavior**
- **Reason:** Clear test names act as documentation and make it easier to understand what failed when a test breaks.
```dart
// Good
test('Calculator.add returns sum of two positive numbers', () {
  expect(Calculator.add(2, 3), 5);
});
```
```dart
// Bad
test('test add', () {
  expect(Calculator.add(2, 3), 5);
});
```
