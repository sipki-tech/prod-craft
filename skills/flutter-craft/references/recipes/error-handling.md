# Error Handling Recipes
Global error handling, crash reporting, and boundary management in Flutter applications.

**Initialize global error handlers in `main()` before calling `runApp()`.**
- **Reason:** Captures both Flutter framework UI errors (like layout failures) and unhandled asynchronous Dart errors. Ensures every crash is logged to your crash reporting service (e.g., Crashlytics, Sentry) from the very start.
```dart
// Bad
void main() {
  runApp(MyApp());
}

// Good
void main() {
  // Ensure bindings are initialized before setting up error handlers
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Handle Flutter framework errors (UI, layout, widget lifecycle)
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log to console
    FlutterError.presentError(details);
    // Send to crash reporting
    CrashReportingService.recordFlutterError(details);
  };

  // 2. Handle unhandled asynchronous Dart errors (Futures, Streams)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    CrashReportingService.recordError(error, stackTrace, fatal: true);
    return true; // Prevents the error from propagating further
  };

  runApp(MyApp());
}
```

**Use `PlatformDispatcher.instance.onError` instead of `runZonedGuarded`.**
- **Reason:** In older Flutter versions, `runZonedGuarded` was required to catch async errors. Modern Flutter (3.3+) recommends `PlatformDispatcher.onError` as it is simpler, less intrusive to the zone hierarchy, and catches errors engine-wide.
```dart
// Bad (Legacy)
void main() {
  runZonedGuarded(() {
    runApp(MyApp());
  }, (error, stack) {
    reportError(error, stack);
  });
}

// Good (Modern)
void main() {
  PlatformDispatcher.instance.onError = (error, stack) {
    reportError(error, stack);
    return true;
  };
  runApp(MyApp());
}
```

**Provide custom `ErrorWidget.builder` for release modes to prevent the "Grey Screen of Death".**
- **Reason:** By default, framework errors show a red screen in debug and a grey screen in release mode. A custom error widget provides a branded, user-friendly fallback and can offer a "Retry" or "Return Home" action.
```dart
// Bad
// Leaving default ErrorWidget behavior which shows a scary red screen or blank grey box

// Good
void setupErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // In debug mode, keep the standard red screen for developers
    if (kDebugMode) {
      return ErrorWidget(details.exception);
    }
    
    // In release mode, show a friendly fallback UI
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            Text('Oops! Something went wrong.'),
            ElevatedButton(
              onPressed: () => AppRouter.goHome(),
              child: Text('Return Home'),
            ),
          ],
        ),
      ),
    );
  };
}
```

**Distinguish between fatal and non-fatal errors in crash reporting.**
- **Reason:** Not all exceptions should be treated as app crashes. Failing to fetch data might be a handled exception (non-fatal), while a null pointer during critical state mutation is fatal.
```dart
// Bad
try {
  await api.fetchData();
} catch (e, s) {
  // Logs a handled network error as a fatal crash
  CrashReporting.record(e, s, isFatal: true); 
}

// Good
try {
  await api.fetchData();
} catch (e, s) {
  // Log as non-fatal for observability without polluting crash metrics
  CrashReporting.record(e, s, isFatal: false);
  showErrorToUser('Failed to load data');
}
```
