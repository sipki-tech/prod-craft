# Dependency Injection

Manage dependencies cleanly using Service Locators (get_it) and Provider patterns (BlocProvider) to ensure testability and clear lifecycles.

**Provide BLoCs using BlocProvider, not global instances**
- **Reason:** `BlocProvider` manages the lifecycle of the BLoC (automatically closing it) and scopes it to the specific widget tree that needs it.

```dart
// Good
BlocProvider(
  create: (context) => UserBloc(repository: getIt<UserRepository>()),
  child: const UserView(),
);

// Bad
final globalUserBloc = UserBloc(); // Memory leak and hard to test

Widget build(BuildContext context) {
  return UserView(bloc: globalUserBloc);
}
```

**Use get_it for Repositories and Services, scoped appropriately**
- **Reason:** Singletons are fine for stateless services, but Repositories and Providers often need factory injection or lazy singletons to manage resources efficiently and allow easy mocking during tests.

```dart
// Good
final getIt = GetIt.instance;

void setup() {
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());
  getIt.registerFactory<UserRepository>(() => UserRepository(getIt()));
}

// Bad
class UserRepository {
  // Tightly coupled, hard to mock in tests
  final ApiClient api = ApiClient(); 
}
```

**Never inject BuildContext into Services or Blocs**
- **Reason:** Context is exclusively a presentation layer construct. Injecting it down into the application or domain layers violates the dependency rule and causes memory leaks.

```dart
// Good
class NavigationService {
  final GlobalKey<NavigatorState> navigatorKey;
  NavigationService(this.navigatorKey);
  void go(String route) => navigatorKey.currentState?.pushNamed(route);
}

// Bad
class NavigationService {
  final BuildContext context;
  NavigationService(this.context);
  void go(String route) => Navigator.of(context).pushNamed(route);
}
```
