# Rendering Performance
Techniques to prevent dropped frames, manage memory, and ensure smooth rendering in production Flutter applications.

**Use lazy builders for large or infinite lists**
- **Reason:** `ListView` and `GridView` instantiate all their children immediately, causing massive memory allocation and frame drops for large data sets. `ListView.builder` only instantiates widgets that are currently visible on the screen.

```dart
// Bad
ListView(
  children: items.map((item) => ComplexItemWidget(item)).toList(),
)

// Good
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ComplexItemWidget(items[index]);
  },
)
```

**Isolate repaints with `RepaintBoundary`**
- **Reason:** Animations or heavily updated visual elements (like a playing video or loading spinner) cause their parent and siblings to repaint on every frame. Wrapping the animating widget in a `RepaintBoundary` creates a separate display list, isolating the repaint cost.

```dart
// Bad
Stack(
  children: [
    const StaticComplexBackground(),
    Positioned(
      top: 0,
      child: CircularProgressIndicator(), // Forces background to repaint
    ),
  ],
)

// Good
Stack(
  children: [
    const StaticComplexBackground(),
    Positioned(
      top: 0,
      child: const RepaintBoundary(
        child: CircularProgressIndicator(),
      ),
    ),
  ],
)
```

**Localize state to prevent unnecessary root rebuilds**
- **Reason:** Calling `setState` at the top of a deep widget tree forces every child down the tree to evaluate if it needs rebuilding. By moving state management down to the smallest possible leaf node, you restrict the rebuild scope to only the widget that actually changed.

```dart
// Bad
class _CounterPageState extends State<CounterPage> {
  int _counter = 0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ExpensiveWidgetTree(), // Rebuilds every time counter changes
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _counter++),
        child: Text('$_counter'),
      ),
    );
  }
}

// Good
class _CounterPageState extends State<CounterPage> {
  final ValueNotifier<int> _counter = ValueNotifier<int>(0);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const ExpensiveWidgetTree(), // Never rebuilds
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: _counter,
        builder: (context, value, _) {
          return FloatingActionButton(
            onPressed: () => _counter.value++,
            child: Text('$value'),
          );
        },
      ),
    );
  }
}
```

**Avoid `Opacity` in animations**
- **Reason:** Wrapping an animating widget in `Opacity` causes the widget and all its children to rebuild and repaint on every single frame of the animation. Using `FadeTransition` or `AnimatedOpacity` applies the opacity effect at the compositing phase, avoiding expensive layout and paint passes.

```dart
// Bad
AnimatedBuilder(
  animation: _controller,
  builder: (context, child) {
    return Opacity(
      opacity: _controller.value,
      child: const ComplexWidget(), // Rebuilds & repaints every frame
    );
  },
)

// Good
FadeTransition(
  opacity: _controller,
  child: const ComplexWidget(), // Painted once, composited with opacity
)
```
