# Widget Composition
Actionable rules for composing Flutter widgets efficiently, prioritizing modularity and the widget tree lifecycle over procedural code.

**Extract widgets, not methods**
- **Reason:** Extracting sub-trees into independent `StatelessWidget` classes preserves the Flutter framework's ability to cache and short-circuit widget rebuilds. A helper method returning a widget forces the framework to rebuild that sub-tree every time the parent builds, discarding performance optimizations.

```dart
// Bad
Widget _buildHeader(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(title, style: Theme.of(context).textTheme.headlineLarge),
  );
}

@override
Widget build(BuildContext context) {
  return Column(
    children: [
      _buildHeader(context, 'Title'),
      const Text('Content'),
    ],
  );
}

// Good
class _Header extends StatelessWidget {
  const _Header({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(title, style: Theme.of(context).textTheme.headlineLarge),
    );
  }
}

@override
Widget build(BuildContext context) {
  return Column(
    children: [
      const _Header(title: 'Title'),
      const Text('Content'),
    ],
  );
}
```

**Always use `const` constructors where possible**
- **Reason:** `const` widgets are evaluated at compile time. During runtime rebuilds, the framework compares `const` widget instances by reference and skips rebuilding their entire sub-trees if the references match, significantly reducing CPU usage.

```dart
// Bad
@override
Widget build(BuildContext context) {
  return Container(
    margin: EdgeInsets.all(16.0),
    child: Text('Static Text'),
  );
}

// Good
@override
Widget build(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(16.0),
    child: Text('Static Text'),
  );
}
```

**Use `Key`s to preserve state across widget tree manipulations**
- **Reason:** When replacing, reordering, or animating widgets of the same type, the framework uses `Key`s to identify instances. Without keys, stateful widgets may lose or incorrectly share state because the element tree matches them based solely on their runtime type.

```dart
// Bad
final List<Item> items = getItems();

ListView(
  children: items.map((item) => ItemCard(item: item)).toList(),
)

// Good
final List<Item> items = getItems();

ListView(
  children: items.map((item) => ItemCard(
    key: ValueKey(item.id),
    item: item,
  )).toList(),
)
```
