# Error Handling
Patterns for exception safety, typed failures, and predictable error propagation in Dart applications.

**Use a `Result` type pattern for expected domain errors**
- **Reason:** Throwing exceptions for predictable business logic failures (like invalid input or network timeouts) breaks control flow and hides errors from the type system. Returning a `Result` forces the caller to explicitly handle success and failure cases.

```dart
// Good
sealed class Result<T> {}
class Success<T> extends Result<T> { final T data; Success(this.data); }
class Failure<T> extends Result<T> { final String error; Failure(this.error); }

Result<User> fetchUser(int id) {
  if (id < 0) return Failure("Invalid ID");
  return Success(User(id));
}

// Bad
User fetchUser(int id) {
  if (id < 0) throw Exception("Invalid ID"); // Caller might forget to catch
  return User(id);
}
```

**Catch specific exception types rather than using raw `catch (e)`**
- **Reason:** Catching all exceptions indiscriminately can swallow critical programming errors (like `TypeError` or `RangeError`), making debugging impossible. Always target the specific exceptions you know how to recover from.

```dart
// Good
try {
  await api.submitData();
} on SocketException catch (e) {
  showOfflineUI();
} on HttpException catch (e) {
  showServerWarning(e.message);
}

// Bad
try {
  await api.submitData();
} catch (e) {
  // Swallows everything, even typos in the code
  print("Something went wrong");
}
```

**Avoid using `throw` for control flow**
- **Reason:** Exceptions are computationally expensive and are meant for exceptional, unexpected states. Using them to jump out of loops or signal expected conditions (like end-of-file) is an anti-pattern.

```dart
// Good
bool isValidPassword(String password) {
  if (password.length < 8) return false;
  if (!password.contains(RegExp(r'[A-Z]'))) return false;
  return true;
}

// Bad
bool isValidPassword(String password) {
  try {
    if (password.length < 8) throw FormatException();
    if (!password.contains(RegExp(r'[A-Z]'))) throw FormatException();
    return true;
  } catch (e) {
    return false;
  }
}
```

**Rethrow caught exceptions using `rethrow` instead of `throw e`**
- **Reason:** `rethrow` preserves the original stack trace, making it much easier to track down the root cause of the error. `throw e` resets the stack trace to the catch block.

```dart
// Good
try {
  await file.readAsString();
} on FileSystemException catch (e) {
  logError(e);
  rethrow; // Stack trace preserved
}

// Bad
try {
  await file.readAsString();
} on FileSystemException catch (e) {
  logError(e);
  throw e; // Original stack trace lost
}
```
