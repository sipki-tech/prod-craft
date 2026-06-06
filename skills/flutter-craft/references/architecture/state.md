# State Management

Choose the right tool for managing different kinds of state in your Flutter app to avoid over-engineering or messy architectures.

**Use setState for Ephemeral (Local) UI State**
- **Reason:** Ephemeral state, like a single widget's animation controller, a form text field value, or an open/closed toggle, doesn't need the boilerplate of a BLoC.

```dart
// Good
class _MyWidgetState extends State<MyWidget> {
  bool _isExpanded = false;
  void _toggle() => setState(() => _isExpanded = !_isExpanded);
  
  @override
  Widget build(BuildContext context) => Switch(value: _isExpanded, onChanged: (_) => _toggle());
}

// Bad
// Over-engineering a simple UI toggle with a BLoC
class ExpansionBloc extends Bloc<ExpansionEvent, bool> { ... }
```

**Use ValueNotifier for simple reactive state without BLoC boilerplate**
- **Reason:** When you need a lightweight way to pass reactive state down a widget tree without complex business logic, `ValueNotifier` is built-in and highly performant.

```dart
// Good
final ValueNotifier<int> pageNotifier = ValueNotifier<int>(0);

ValueListenableBuilder<int>(
  valueListenable: pageNotifier,
  builder: (context, page, child) => Text('Page $page'),
);

// Bad
class PageCubit extends Cubit<int> {
  PageCubit() : super(0);
  void updatePage(int page) => emit(page);
}
// Using a Cubit for a simple local page index is overkill.
```

**Use BLoC/Cubit for App (Global) State and complex logic**
- **Reason:** State that is shared across multiple features (e.g. Authentication, User Profile, Cart) or involves complex asynchronous logic, caching, or transformation should be managed by a predictable state container like BLoC.

```dart
// Good
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc(this.repository) : super(CartEmpty()) {
    on<AddItem>((event, emit) async {
      emit(CartLoading());
      await repository.add(event.item);
      emit(CartLoaded(await repository.getItems()));
    });
  }
}

// Bad
// Managing global cart state inside a StatefulWidget at the top of the tree.
class _MyAppState extends State<MyApp> {
  List<Item> _cart = [];
  // Complex async logic mixed with UI
}
```
