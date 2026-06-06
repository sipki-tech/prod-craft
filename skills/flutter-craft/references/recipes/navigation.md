# Navigation Recipes
Production patterns for declarative routing, deep linking, and navigation state management using `go_router`.

**Use strongly-typed routes with `go_router_builder` instead of raw string paths.**
- **Reason:** Prevents runtime navigation errors due to typos, ensures required parameters are provided at compile-time, and makes deep link handling explicit.
```dart
// Bad
context.go('/profile/123');

// Good
@TypedGoRoute<ProfileRoute>(path: '/profile/:id')
class ProfileRoute extends GoRouteData {
  final String id;
  const ProfileRoute({required this.id});

  @override
  Widget build(BuildContext context, GoRouterState state) => ProfileScreen(id: id);
}

// Usage
ProfileRoute(id: '123').go(context);
```

**Centralize authentication and authorization checks in router redirects.**
- **Reason:** Keeps security logic out of UI components, prevents unauthorized screens from flashing, and handles deep links uniformly.
```dart
// Bad
class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!AuthScope.of(context).isSignedIn) return LoginScreen();
    return Text('Profile');
  }
}

// Good
GoRouter(
  redirect: (context, state) {
    final isAuthenticated = authState.value.isAuthenticated;
    final isGoingToLogin = state.matchedLocation == '/login';
    
    if (!isAuthenticated && !isGoingToLogin) return '/login';
    if (isAuthenticated && isGoingToLogin) return '/';
    return null;
  },
  // ...
);
```

**Use `StatefulShellRoute` for persistent UI shells like bottom navigation bars.**
- **Reason:** Preserves the navigation state of each tab independently and avoids unnecessary widget rebuilds when switching tabs.
```dart
// Bad
// Using a standard ShellRoute or manual IndexedStack which loses nested navigation state
ShellRoute(
  builder: (context, state, child) => AppScaffold(child: child),
  routes: [ /* ... */ ],
)

// Good
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) {
    return ScaffoldWithNavBar(navigationShell: navigationShell);
  },
  branches: [
    StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => HomeScreen())]),
    StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (c, s) => SettingsScreen())]),
  ],
);
```

**Handle deep links explicitly via the `redirect` callback or custom top-level routes.**
- **Reason:** Ensures incoming links resolve to valid app states, handling missing data gracefully rather than crashing.
```dart
// Bad
// Assuming the path always contains valid data
GoRoute(
  path: '/details/:id',
  builder: (context, state) => DetailsScreen(id: int.parse(state.pathParameters['id']!)), // Can throw FormatException
)

// Good
GoRoute(
  path: '/details/:id',
  builder: (context, state) {
    final id = int.tryParse(state.pathParameters['id'] ?? '');
    if (id == null) return const ErrorScreen(message: 'Invalid item ID');
    return DetailsScreen(id: id);
  },
)
```
