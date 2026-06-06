# Layered Architecture

Define a strict separation of concerns into Presentation, Business Logic, and Data layers to promote maintainability.

**Separate Presentation, Logic, and Data layers**
- **Reason:** Ensuring that your UI does not directly access databases or network APIs promotes maintainability, testability, and clear separation of concerns.

```dart
// Good
class UserRepository {
  final UserDataProvider _provider;
  Future<User> getUser(String id) => _provider.fetchUser(id);
}

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository _repository;
  // logic...
}

// Bad
class UserWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: http.get('...'), // UI layer directly making network calls
      builder: (...) => Text('...'),
    );
  }
}
```

**Data layer must be split into Repositories and Data Providers**
- **Reason:** Data providers handle raw CRUD operations (HTTP, DB), while repositories orchestrate these providers and transform raw data into domain models for the business logic layer.

```dart
// Good
class WeatherProvider {
  Future<RawWeather> getRawWeather(String city) async { /* HTTP GET */ }
}

class WeatherRepository {
  final WeatherProvider weatherProvider;
  Future<Weather> getWeather(String city) async {
    final raw = await weatherProvider.getRawWeather(city);
    return Weather.fromRaw(raw);
  }
}

// Bad
class WeatherRepository {
  Future<Weather> getWeather(String city) async {
    // Repository mixing network details and logic
    final response = await http.get('...'); 
    return Weather.fromJson(response.body);
  }
}
```

**Dependencies only flow inward**
- **Reason:** Business logic must not depend on UI classes (like `BuildContext` or `Widget`), and Data layers must not depend on Business logic.

```dart
// Good
class UserCubit extends Cubit<UserState> {
  final UserRepository repository;
  UserCubit(this.repository) : super(UserInitial());
  // No references to BuildContext
}

// Bad
class UserCubit extends Cubit<UserState> {
  final BuildContext context; // Business logic depends on Presentation
  UserCubit(this.context) : super(UserInitial());
}
```
