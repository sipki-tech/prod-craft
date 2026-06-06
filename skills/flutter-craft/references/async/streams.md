# Streams & Data Flow
Best practices for handling continuous data streams, event pipelines, and stream resource management in Dart.

**Always close `StreamController` and cancel `StreamSubscription`**
- **Reason:** Unclosed stream controllers and active subscriptions cause memory leaks and zombie processes that continue reacting to events after they are no longer needed.

```dart
// Good
class SensorReader {
  final _controller = StreamController<int>();
  Stream<int> get data => _controller.stream;

  void dispose() {
    _controller.close();
  }
}

// Bad
class SensorReader {
  final _controller = StreamController<int>();
  Stream<int> get data => _controller.stream;
  // Missing dispose method to close the controller
}
```

**Use `async*` and `yield` for generating streams instead of manual controllers**
- **Reason:** Generator functions (`async*`) are less error-prone, automatically handle pause/resume/cancel events, and make the data-emission logic much easier to read.

```dart
// Good
Stream<int> countdown(int from) async* {
  for (int i = from; i > 0; i--) {
    await Future.delayed(Duration(seconds: 1));
    yield i;
  }
}

// Bad
Stream<int> countdown(int from) {
  final controller = StreamController<int>();
  int current = from;
  Timer.periodic(Duration(seconds: 1), (timer) {
    if (current > 0) {
      controller.add(current--);
    } else {
      timer.cancel();
      controller.close();
    }
  });
  return controller.stream;
}
```

**Prefer broadcast streams for events with multiple listeners**
- **Reason:** Single-subscription streams throw an error if listened to more than once. Use `StreamController.broadcast()` or `.asBroadcastStream()` if UI components or multiple services need the same data.

```dart
// Good
class AuthState {
  final _controller = StreamController<User>.broadcast();
  Stream<User> get userStream => _controller.stream;
}

// Bad
class AuthState {
  final _controller = StreamController<User>();
  Stream<User> get userStream => _controller.stream; // Will crash on second listener
}
```

**Transform streams using high-level operators over manual listening**
- **Reason:** Built-in operators like `map`, `where`, `asyncMap`, and `expand` are optimized, correctly handle errors, and propagate stream state (like pause/cancel) properly.

```dart
// Good
Stream<String> getValidNames(Stream<String> input) {
  return input
      .where((name) => name.isNotEmpty)
      .map((name) => name.trim());
}

// Bad
Stream<String> getValidNames(Stream<String> input) async* {
  await for (final name in input) {
    if (name.isNotEmpty) {
      yield name.trim();
    }
  }
}
```
