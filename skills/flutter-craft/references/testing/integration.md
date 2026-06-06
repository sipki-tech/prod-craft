# Integration Testing

Integration tests run the full application on a real device or emulator to verify that all components work together seamlessly. They simulate end-to-end user journeys and are crucial for catching issues that only occur in real-world environments.

**Use `IntegrationTestWidgetsFlutterBinding` to run tests on real devices**
- **Reason:** Integration tests must drive the app on a real device or emulator to test the full stack, including native platform integrations.
```dart
// Good
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-end login flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    // ... test interactions
  });
}
```
```dart
// Bad
void main() {
  // Missing IntegrationTestWidgetsFlutterBinding
  testWidgets('End-to-end login flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    // ... test interactions
  });
}
```

**Interact with the app exactly as a user would**
- **Reason:** Integration tests evaluate the application from the user's perspective. Avoid bypassing UI constraints or directly manipulating state.
```dart
// Good
testWidgets('User can submit form', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('email_input')), 'test@example.com');
  await tester.tap(find.byKey(const Key('submit_btn')));
  await tester.pumpAndSettle();
  expect(find.text('Success'), findsOneWidget);
});
```
```dart
// Bad
testWidgets('User can submit form', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  // Bypassing UI interaction by calling controllers directly
  GetIt.I<FormController>().submit('test@example.com');
  await tester.pumpAndSettle();
});
```

**Group complex flows into smaller, logical steps**
- **Reason:** Long end-to-end tests can be difficult to debug. Structuring them into logical steps or separate test files makes failures easier to isolate.
```dart
// Good
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Checkout Flow', () {
    testWidgets('Adds item to cart', (tester) async { /* ... */ });
    testWidgets('Proceeds to payment', (tester) async { /* ... */ });
    testWidgets('Completes order', (tester) async { /* ... */ });
  });
}
```
```dart
// Bad
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Entire checkout flow', (tester) async {
    // 500 lines of interactions and assertions in a single test
  });
}
```
