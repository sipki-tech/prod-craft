# Widget Testing

Widget tests simulate user interactions and verify that individual widgets build and behave as expected. They run in a headless environment, providing a balance between unit test speed and integration test confidence.

**Use `pumpWidget` to build the widget under test**
- **Reason:** `pumpWidget` initializes the widget tree in the test environment, which is required before interacting with or verifying widgets.
```dart
// Good
testWidgets('MyWidget has a title and message', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: MyWidget()));
  expect(find.text('Title'), findsOneWidget);
});
```
```dart
// Bad
testWidgets('MyWidget has a title and message', (tester) async {
  final widget = MyWidget();
  // Fails because the widget is not attached to the tree
  expect(find.text('Title'), findsOneWidget); 
});
```

**Use `pumpAndSettle` when animating or waiting for microtasks to finish**
- **Reason:** When a widget triggers animations or async state changes, `pumpAndSettle` repeatedly pumps the UI until no more frames are scheduled, ensuring the widget is in a final state.
```dart
// Good
testWidgets('Navigates to new page', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.byKey(const Key('nav_button')));
  await tester.pumpAndSettle();
  expect(find.text('New Page'), findsOneWidget);
});
```
```dart
// Bad
testWidgets('Navigates to new page', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.byKey(const Key('nav_button')));
  await tester.pump(); // Animation hasn't finished yet
  expect(find.text('New Page'), findsOneWidget);
});
```

**Find widgets by Key instead of text when possible**
- **Reason:** Text can change due to localization or minor copy updates. Keys provide a stable identifier for testing UI interactions.
```dart
// Good
testWidgets('Taps the submit button', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.byKey(const Key('submit_button')));
  await tester.pump();
});
```
```dart
// Bad
testWidgets('Taps the submit button', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.text('Submit')); // Breaks if text changes to "Save"
  await tester.pump();
});
```
