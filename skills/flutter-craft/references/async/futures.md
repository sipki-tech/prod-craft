# Futures & Asynchrony
Guidelines for managing asynchronous operations, concurrent execution, and future completion in Dart.

**Prefer `async`/`await` over raw `Future` `.then()` callbacks**
- **Reason:** `async`/`await` flattens callback hell, making asynchronous logic read like synchronous code and simplifying error handling with `try`/`catch`.

```dart
// Good
Future<int> fetchTotal() async {
  try {
    final user = await fetchUser();
    return await fetchScore(user.id);
  } catch (e) {
    return 0;
  }
}

// Bad
Future<int> fetchTotal() {
  return fetchUser().then((user) {
    return fetchScore(user.id);
  }).catchError((e) {
    return 0;
  });
}
```

**Use `Future.wait` for independent parallel operations**
- **Reason:** Executing independent asynchronous tasks sequentially wastes time. `Future.wait` runs them in parallel and waits for all to complete.

```dart
// Good
Future<void> loadDashboard() async {
  final results = await Future.wait([
    fetchProfile(),
    fetchNotifications(),
  ]);
  render(results[0], results[1]);
}

// Bad
Future<void> loadDashboard() async {
  final profile = await fetchProfile();
  final notifications = await fetchNotifications();
  render(profile, notifications);
}
```

**Avoid returning `null` from Futures when no value is expected**
- **Reason:** If a `Future` doesn't produce a value, use `Future<void>` rather than `Future<Null>` or `Future<dynamic>`. It clarifies intent and prevents misuse of the result.

```dart
// Good
Future<void> savePreferences(Preferences prefs) async {
  await db.write(prefs);
}

// Bad
Future<Null> savePreferences(Preferences prefs) async {
  await db.write(prefs);
  return null;
}
```

**Do not use `async` when a function only returns a `Future` directly**
- **Reason:** Marking a function `async` introduces overhead (allocating an extra Future wrapper). If you're simply passing along a Future, return it directly.

```dart
// Good
Future<User> getUser() {
  return apiClient.fetchUser();
}

// Bad
Future<User> getUser() async {
  return await apiClient.fetchUser();
}
```
