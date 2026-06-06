# Forms Recipes
Production best practices for building robust, user-friendly forms, handling validation, and managing controller lifecycles.

**Always dispose controllers and focus nodes in a StatefulWidget's `dispose` method.**
- **Reason:** Failing to dispose `TextEditingController` and `FocusNode` instances causes memory leaks and leaves active listeners that trigger exceptions if updated after the widget is unmounted.
```dart
// Bad
class _MyFormState extends State<MyForm> {
  final _controller = TextEditingController(); // Never disposed
  
  @override
  Widget build(BuildContext context) => TextField(controller: _controller);
}

// Good
class _MyFormState extends State<MyForm> {
  late final TextEditingController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) => TextField(controller: _controller);
}
```

**Use `AutovalidateMode.onUserInteraction` instead of `always` or `disabled`.**
- **Reason:** Validating immediately (`always`) shows aggressive errors before the user even types, while `disabled` only validates on submit. `onUserInteraction` provides immediate feedback only after the user starts engaging with the field.
```dart
// Bad
Form(
  autovalidateMode: AutovalidateMode.always,
  child: Column( /* ... */ ),
)

// Good
Form(
  autovalidateMode: AutovalidateMode.onUserInteraction,
  child: Column( /* ... */ ),
)
```

**Extract validation logic into pure functions outside of the widget tree.**
- **Reason:** Keeps the UI code clean, enables reuse across different forms, and makes validators easily unit-testable without requiring a Flutter environment.
```dart
// Bad
TextFormField(
  validator: (value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!value.contains('@')) return 'Invalid email';
    return null;
  },
)

// Good
class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) return 'Invalid email format';
    return null;
  }
}

TextFormField(
  validator: Validators.email,
)
```

**Use a `GlobalKey<FormState>` to validate and save the entire form at once.**
- **Reason:** Centralizes the submission logic and avoids manually checking every single controller's value before proceeding.
```dart
// Bad
void submit() {
  if (emailController.text.isNotEmpty && passwordController.text.length > 6) {
    // Brittle, duplicates validation logic
    api.login(emailController.text, passwordController.text);
  }
}

// Good
final _formKey = GlobalKey<FormState>();

void submit() {
  if (_formKey.currentState?.validate() ?? false) {
    _formKey.currentState?.save(); // Triggers onSaved callbacks if needed
    api.login(emailController.text, passwordController.text);
  }
}
```
