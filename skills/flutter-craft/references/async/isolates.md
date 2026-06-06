# Isolates & Concurrency
Guidelines for heavy computation, multi-threading, and safe message passing between isolates in Dart.

**Offload heavy computation to isolates using `Isolate.run`**
- **Reason:** Dart is single-threaded. CPU-intensive tasks (like JSON parsing, image processing, or complex math) block the event loop, causing frame drops. `Isolate.run` provides a simple, safe way to spawn an isolate, run a computation, and return the result.

```dart
// Good
Future<Data> parseLargeJson(String jsonString) async {
  return await Isolate.run(() => parseJsonStrictly(jsonString));
}

// Bad
Future<Data> parseLargeJson(String jsonString) async {
  // Blocks the main UI thread during parsing
  return parseJsonStrictly(jsonString);
}
```

**Pass only primitive types and simple data structures between isolates**
- **Reason:** Isolates don't share memory. Complex objects containing closures, streams, or native resources cannot be safely serialized and sent across isolate boundaries.

```dart
// Good
Future<void> processImage(List<int> imageBytes) async {
  final result = await Isolate.run(() => applyFilter(imageBytes));
}

// Bad
Future<void> processImage(ImageProcessor processor) async {
  // ImageProcessor might contain non-transferable state or closures
  final result = await Isolate.run(() => processor.applyFilter());
}
```

**Keep long-running isolates alive with `ReceivePort` communication**
- **Reason:** Repeatedly spawning isolates for frequent, small tasks creates significant overhead. For ongoing background work, spawn a single isolate and use a `SendPort`/`ReceivePort` stream to exchange messages.

```dart
// Good
void startBackgroundWorker() async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_workerLoop, receivePort.sendPort);
  // Communicate via ports for ongoing tasks
}

// Bad
void performFrequentTasks(List<Task> tasks) async {
  for (final task in tasks) {
    // Spawning an isolate per small task is too expensive
    await Isolate.run(() => process(task));
  }
}
```

**Handle isolate errors explicitly**
- **Reason:** Exceptions thrown inside an isolate do not automatically propagate to the main thread. Always wrap isolate computations in `try`/`catch` or configure error ports to capture crashes.

```dart
// Good
Future<int> safeCompute(int value) async {
  return await Isolate.run(() {
    try {
      return riskyCalculation(value);
    } catch (e) {
      return -1; // Fallback value
    }
  });
}

// Bad
Future<int> safeCompute(int value) async {
  return await Isolate.run(() {
    // Unhandled exception here will terminate the isolate silently
    return riskyCalculation(value);
  });
}
```
