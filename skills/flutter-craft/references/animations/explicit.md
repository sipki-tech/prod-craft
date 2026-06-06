# Explicit Animations

Explicit animations grant fine-grained control using an `AnimationController`, enabling looping, reversing, and sequencing. They are essential for complex choreography and interactions that must be programmatically driven.

**Always dispose of `AnimationController` instances.**
- **Reason:** Controllers allocate resources and attach listeners to the `TickerProvider`. Failing to dispose of them leads to severe memory leaks and background processing when the widget is unmounted.

```dart
// Good
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}

// Bad
@override
void dispose() {
  // Missing _controller.dispose();
  super.dispose();
}
```

**Scope rebuilds tightly using `AnimatedBuilder` instead of calling `setState`.**
- **Reason:** Calling `setState` inside a controller's listener rebuilds the entire widget tree for every animation frame (60-120 times per second). `AnimatedBuilder` isolates the rebuild only to the parts of the tree that actually change.

```dart
// Good
AnimatedBuilder(
  animation: _controller,
  builder: (context, child) {
    return Transform.rotate(
      angle: _controller.value * 2 * math.pi,
      child: child,
    );
  },
  child: const ExpensiveWidget(), // Child is built once and passed in
)

// Bad
@override
void initState() {
  super.initState();
  _controller.addListener(() => setState(() {}));
}

@override
Widget build(BuildContext context) {
  return Transform.rotate(
    angle: _controller.value * 2 * math.pi,
    child: const ExpensiveWidget(), // Rebuilds 60 times a second
  );
}
```

**Compose curves and interpolations clearly using `CurvedAnimation` and `Tween`.**
- **Reason:** Applying a `Curve` directly inside a `Tween` evaluation is rigid. Wrapping the controller in a `CurvedAnimation` and passing it to a `Tween`'s `animate()` method cleanly separates the timeline logic from the value interpolation logic.

```dart
// Good
final _curvedAnimation = CurvedAnimation(
  parent: _controller,
  curve: Curves.easeInOutBack,
);
final _sizeAnimation = Tween<double>(begin: 0.0, end: 100.0).animate(_curvedAnimation);

// Bad
// Manually transforming the controller value with a curve inside a builder
AnimatedBuilder(
  animation: _controller,
  builder: (context, child) {
    final curvedValue = Curves.easeInOutBack.transform(_controller.value);
    final size = 0.0 + (100.0 - 0.0) * curvedValue;
    return Container(width: size, height: size);
  },
)
```
