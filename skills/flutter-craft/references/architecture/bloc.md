# BLoC Pattern

Strict rules for using the BLoC (Business Logic Component) pattern for predictable state management.

**States MUST be immutable and freezed**
- **Reason:** Immutable states prevent unintended side-effects and allow BLoC to accurately detect state changes through value equality.

```dart
// Good
@freezed
class UserState with _$UserState {
  const factory UserState.initial() = _Initial;
  const factory UserState.loading() = _Loading;
  const factory UserState.success(User user) = _Success;
}

// Bad
class UserState {
  User? user;
  bool isLoading;
  UserState({this.user, this.isLoading = false}); // Mutable state
}
```

**Events MUST be sealed classes**
- **Reason:** Sealed classes enforce exhaustive `switch` or `map` handling, ensuring every event is explicitly handled by the BLoC without fallback errors.

```dart
// Good
sealed class CounterEvent {}
final class CounterIncrementPressed extends CounterEvent {}
final class CounterDecrementPressed extends CounterEvent {}

// Bad
class CounterEvent {
  final String type; // String-based typing is error-prone
  CounterEvent(this.type);
}
```

**Do not couple BLoCs tightly together**
- **Reason:** Injecting one BLoC into another creates tight coupling. Instead, connect them via `BlocListener` in the Presentation layer or by listening to reactive streams from the Repository in the Domain layer.

```dart
// Good
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is Authenticated) {
      context.read<ProfileBloc>().add(LoadProfile());
    }
  },
  child: ProfileWidget(),
)

// Bad
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final AuthBloc authBloc; // Tight coupling
  ProfileBloc(this.authBloc) {
    authBloc.stream.listen((state) { ... });
  }
}
```

**Use Cubit for simple state, Bloc for complex event-driven state**
- **Reason:** `Cubit` exposes simple methods and has less boilerplate, ideal for simple state transitions. `Bloc` uses explicit events and is better for complex interactions, debounce/throttle pipelines, and traceability.

```dart
// Good
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.light);
  void toggleTheme() => emit(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
}

// Bad
class ThemeBloc extends Bloc<ThemeEvent, ThemeMode> {
  // Overkill for a simple toggle
  ThemeBloc() : super(ThemeMode.light) {
    on<ToggleThemeEvent>((event, emit) => emit(...));
  }
}
```
