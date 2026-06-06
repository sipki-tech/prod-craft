# Mocking

Mocking isolates the unit under test by replacing complex or unpredictable external dependencies with controllable test doubles. This guarantees that tests remain deterministic and focused solely on the component's internal logic.

**Use `mocktail` or `mockito` to generate test doubles**
- **Reason:** These packages provide powerful APIs to simulate complex behaviors, verify interactions, and control return values without writing manual mock classes.
```dart
// Good
class MockUserRepository extends Mock implements UserRepository {}

void main() {
  test('returns user', () {
    final repo = MockUserRepository();
    when(() => repo.getUser()).thenReturn(User('Alice'));
    expect(repo.getUser().name, 'Alice');
  });
}
```
```dart
// Bad
class FakeUserRepository implements UserRepository {
  @override
  User getUser() => User('Alice'); // Manual override, hard to change per test
}
```

**Verify interactions with mocks to ensure correct usage**
- **Reason:** Verifying method calls ensures that your business logic correctly invokes the necessary dependencies with the expected arguments.
```dart
// Good
test('saves data when form is submitted', () async {
  await controller.submit(data);
  verify(() => mockRepository.saveData(data)).called(1);
});
```
```dart
// Bad
test('saves data when form is submitted', () async {
  await controller.submit(data);
  // Missing verification, no guarantee the repository was actually called
});
```

**Use `registerFallbackValue` for complex types in mocktail**
- **Reason:** `mocktail` needs fallback values to support the `any()` matcher for non-primitive types, preventing runtime type errors.
```dart
// Good
setUpAll(() {
  registerFallbackValue(User(id: '0', name: 'fallback'));
});

test('updates user', () {
  when(() => repo.updateUser(any())).thenAnswer((_) async => true);
});
```
```dart
// Bad
test('updates user', () {
  // Fails at runtime because mocktail doesn't know how to create a dummy User
  when(() => repo.updateUser(any())).thenAnswer((_) async => true);
});
```
