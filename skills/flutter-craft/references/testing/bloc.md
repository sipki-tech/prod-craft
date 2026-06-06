# BLoC Testing

BLoC tests ensure that the application's state management logic correctly transitions between states in response to events. They rely on the `bloc_test` package to simplify testing state emissions and interactions with dependencies.

**Use `blocTest` from the `bloc_test` package for testing Blocs and Cubits**
- **Reason:** `blocTest` abstracts the boilerplate of subscribing to state streams and waiting for events to be processed, making tests concise and robust.
```dart
// Good
blocTest<CounterBloc, int>(
  'emits [1] when Increment is added',
  build: () => CounterBloc(),
  act: (bloc) => bloc.add(Increment()),
  expect: () => [1],
);
```
```dart
// Bad
test('emits [1] when Increment is added', () async {
  final bloc = CounterBloc();
  bloc.add(Increment());
  await expectLater(bloc.stream, emitsInOrder([1]));
});
```

**Mock dependencies injected into the Bloc**
- **Reason:** Blocs should be tested for their state transition logic, not for the behavior of their underlying repositories or services.
```dart
// Good
blocTest<UserBloc, UserState>(
  'emits [UserLoaded] when fetch succeeds',
  build: () {
    when(() => mockUserRepository.fetchUser()).thenAnswer((_) async => user);
    return UserBloc(repository: mockUserRepository);
  },
  act: (bloc) => bloc.add(FetchUser()),
  expect: () => [UserLoading(), UserLoaded(user)],
);
```
```dart
// Bad
blocTest<UserBloc, UserState>(
  'emits [UserLoaded] when fetch succeeds',
  // Uses a real repository that makes HTTP calls
  build: () => UserBloc(repository: RealUserRepository()), 
  act: (bloc) => bloc.add(FetchUser()),
  expect: () => [UserLoading(), UserLoaded(user)],
);
```

**Define `setUp` logic for common Mock behaviors**
- **Reason:** Setting up mocks in `setUp` reduces duplication across `blocTest` cases in the same group.
```dart
// Good
group('AuthBloc', () {
  setUp(() {
    when(() => mockAuthRepo.isLoggedIn()).thenReturn(true);
  });

  blocTest<AuthBloc, AuthState>(
    'emits authenticated state',
    build: () => AuthBloc(mockAuthRepo),
    expect: () => [Authenticated()],
  );
});
```
```dart
// Bad
group('AuthBloc', () {
  blocTest<AuthBloc, AuthState>(
    'emits authenticated state',
    build: () {
      when(() => mockAuthRepo.isLoggedIn()).thenReturn(true);
      return AuthBloc(mockAuthRepo);
    },
    expect: () => [Authenticated()],
  );
});
```
