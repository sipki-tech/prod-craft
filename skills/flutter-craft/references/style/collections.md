# Collections

Dart collections should be constructed and manipulated declaratively using literals, spreads, and collection-level control flow operators.

**Use collection literals instead of constructors.**
- **Reason:** Literals (`[]`, `{}`, `<Type>{}`) are concise, idiomatic, and immediately recognizable, whereas class constructors are verbose.
```dart
// Good
final names = <String>[];
final config = <String, dynamic>{};
final uniqueIds = <int>{};

// Bad
final names = List<String>.empty(growable: true);
final config = Map<String, dynamic>();
final uniqueIds = Set<int>();
```

**Use `.isEmpty` and `.isNotEmpty` instead of `.length`.**
- **Reason:** For some `Iterable` implementations, checking `.length` requires iterating over the entire collection (`O(N)`). `.isEmpty` is guaranteed to be `O(1)`.
```dart
// Good
if (items.isEmpty) return;
if (queue.isNotEmpty) process(queue);

// Bad
if (items.length == 0) return;
if (queue.length > 0) process(queue);
```

**Use collection `if` and `for` instead of imperative mutation.**
- **Reason:** Control-flow operators in collections allow you to build dynamic lists or maps declaratively. This enables you to declare collections as `final` rather than mutating them.
```dart
// Good
final menu = [
  'Home',
  if (isAdmin) 'Admin Panel',
  for (final category in categories) category.name,
];

// Bad
final menu = ['Home'];
if (isAdmin) {
  menu.add('Admin Panel');
}
for (final category in categories) {
  menu.add(category.name);
}
```

**Use the spread operator (`...` and `...?`) to concatenate collections.**
- **Reason:** Spread operators are visually integrated into the literal, avoiding noisy `.addAll()` calls and manual null checks.
```dart
// Good
final combinedData = [...cachedData, ...?freshData];

// Bad
final combinedData = <Data>[];
combinedData.addAll(cachedData);
if (freshData != null) {
  combinedData.addAll(freshData);
}
```

**Avoid `.forEach()`; prefer `for-in` loops.**
- **Reason:** `for-in` loops are more readable, support standard control flow (`break`, `continue`, `return`), and safely handle `async`/`await` operations. `.forEach()` fails silently with async operations.
```dart
// Good
for (final user in users) {
  await user.syncData();
}

// Bad
users.forEach((user) async {
  await user.syncData(); // Unsafe: The loop doesn't wait for the Future
});
```
