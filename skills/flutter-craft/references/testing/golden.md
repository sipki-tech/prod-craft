# Golden Testing

Golden tests compare the visual output of a widget against a pre-rendered reference image to catch unintended UI regressions. They are essential for ensuring pixel-perfect layouts and consistent theming across different device form factors.

**Use `matchesGoldenFile` to assert visual correctness**
- **Reason:** Golden tests ensure that the UI renders exactly as expected, catching unintended visual regressions pixel-by-pixel.
```dart
// Good
testWidgets('Button looks correct', (tester) async {
  await tester.pumpWidget(const MyApp());
  await expectLater(
    find.byType(MyButton),
    matchesGoldenFile('goldens/my_button.png'),
  );
});
```
```dart
// Bad
testWidgets('Button looks correct', (tester) async {
  await tester.pumpWidget(const MyApp());
  // Missing visual assertion, only checks existence
  expect(find.byType(MyButton), findsOneWidget); 
});
```

**Load required fonts before running golden tests**
- **Reason:** Flutter tests use a default fallback font (Ahem) that renders text as black boxes. Loading real fonts ensures the text renders correctly in the golden images.
```dart
// Good
setUpAll(() async {
  await loadAppFonts(); // Load Material or custom fonts
});

testWidgets('Text renders with font', (tester) async {
  await tester.pumpWidget(const MyApp());
  await expectLater(find.byType(Text), matchesGoldenFile('goldens/text.png'));
});
```
```dart
// Bad
testWidgets('Text renders with font', (tester) async {
  await tester.pumpWidget(const MyApp());
  // Text will render as unreadable Ahem blocks
  await expectLater(find.byType(Text), matchesGoldenFile('goldens/text.png'));
});
```

**Isolate golden tests to specific platforms or configurations**
- **Reason:** Font rendering and anti-aliasing differ across platforms (macOS, Linux, Windows), which can cause flaky golden tests if run on different machines.
```dart
// Good
testWidgets('Home page visual', (tester) async {
  await tester.pumpWidget(const HomePage());
  await expectLater(find.byType(HomePage), matchesGoldenFile('goldens/home.png'));
}, skip: !Platform.isMacOS); // Only run goldens on macOS for consistency
```
```dart
// Bad
testWidgets('Home page visual', (tester) async {
  await tester.pumpWidget(const HomePage());
  // May pass on developer machine but fail in CI due to OS differences
  await expectLater(find.byType(HomePage), matchesGoldenFile('goldens/home.png'));
});
```
