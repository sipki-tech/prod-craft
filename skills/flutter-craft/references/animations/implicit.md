# Implicit Animations

Implicit animations handle state changes automatically without managing an `AnimationController`. They are ideal for straightforward, non-repeating transitions triggered by simple state updates like size, color, or opacity.

**Prefer implicit animations for simple "fire-and-forget" state changes.**
- **Reason:** Manually managing an `AnimationController` for a single value interpolation creates unnecessary boilerplate and increases the risk of memory leaks.

```dart
// Good
AnimatedOpacity(
  opacity: _isVisible ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 300),
  child: const Text('Hello'),
)

// Bad
// Creating a full AnimationController, Tween, and AnimatedBuilder just to fade in a widget.
AnimatedBuilder(
  animation: _opacityController,
  builder: (context, child) => Opacity(
    opacity: _opacityController.value,
    child: child,
  ),
  child: const Text('Hello'),
)
```

**Use AnimatedSwitcher to smoothly transition between different child widgets.**
- **Reason:** `AnimatedSwitcher` automatically orchestrates fading (or other transitions) between an old child and a new child based on widget keys, avoiding jarring immediate swaps.

```dart
// Good
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: _isLoading 
    ? const CircularProgressIndicator(key: ValueKey('loading'))
    : const Text('Loaded', key: ValueKey('text')),
)

// Bad
// Swapping widgets abruptly without transition, causing a harsh UI update.
_isLoading ? const CircularProgressIndicator() : const Text('Loaded')
```

**Use AnimatedContainer for multi-property layout changes.**
- **Reason:** `AnimatedContainer` interpolates changes across dimensions, colors, padding, and alignment simultaneously without needing multiple implicit widgets.

```dart
// Good
AnimatedContainer(
  duration: const Duration(milliseconds: 400),
  curve: Curves.easeInOut,
  width: _isExpanded ? 200 : 100,
  height: _isExpanded ? 100 : 50,
  color: _isExpanded ? Colors.blue : Colors.red,
  child: const FlutterLogo(),
)

// Bad
// Stacking multiple specific implicit animators which increases tree depth and complexity.
AnimatedSize(
  duration: const Duration(milliseconds: 400),
  child: AnimatedContainer( // Or having custom tweens for color and size
    duration: const Duration(milliseconds: 400),
    color: _isExpanded ? Colors.blue : Colors.red,
    width: _isExpanded ? 200 : 100,
    height: _isExpanded ? 100 : 50,
  ),
)
```
