# Responsive and Adaptive Layouts
Best practices for handling multi-device sizing, diverse aspect ratios, and platform-specific behaviors.

**Use `LayoutBuilder` for local responsive sizing, not `MediaQuery`**
- **Reason:** `MediaQuery.of(context).size` forces a rebuild of the widget whenever the screen size changes (e.g., keyboard pops up or rotation), even if the widget's constraints don't change. `LayoutBuilder` scopes constraints to the parent widget, keeping components decoupled from the global screen size.

```dart
// Bad
@override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  return Container(
    width: screenWidth > 600 ? 300 : screenWidth,
    child: const Text('Content'),
  );
}

// Good
@override
Widget build(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return Container(
        width: constraints.maxWidth > 600 ? 300 : constraints.maxWidth,
        child: const Text('Content'),
      );
    },
  );
}
```

**Define semantic breakpoints for layout shifts**
- **Reason:** Hardcoding pixel values across multiple widgets leads to inconsistent layout shifts. Define a centralized set of screen breakpoints and adapt the UI structure (e.g., Row vs Column, Sidebar vs Drawer) based on these logical boundaries.

```dart
// Bad
Widget build(BuildContext context) {
  if (MediaQuery.of(context).size.width > 800) {
    return _TabletLayout();
  } else {
    return _MobileLayout();
  }
}

// Good
enum ScreenSize { small, medium, large }

ScreenSize getScreenSize(double width) {
  if (width >= 1024) return ScreenSize.large;
  if (width >= 600) return ScreenSize.medium;
  return ScreenSize.small;
}

@override
Widget build(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final size = getScreenSize(constraints.maxWidth);
      return switch (size) {
        ScreenSize.large => const DesktopLayout(),
        ScreenSize.medium => const TabletLayout(),
        ScreenSize.small => const MobileLayout(),
      };
    },
  );
}
```

**Separate responsive layout from adaptive behavior**
- **Reason:** "Responsive" means adjusting the layout (grids, margins) based on size. "Adaptive" means altering input paradigms and platform conventions (e.g., touch vs mouse, iOS switches vs Android switches). Confusing the two makes cross-platform code brittle.

```dart
// Bad
Widget build(BuildContext context) {
  // Conflating screen size with platform input conventions
  if (MediaQuery.of(context).size.width > 600) {
    return MouseRegion(child: CupertinoSwitch(value: true, onChanged: (_) {}));
  }
  return Switch(value: true, onChanged: (_) {});
}

// Good
Widget build(BuildContext context) {
  // Adaptive behavior based on platform/input
  final isApple = defaultTargetPlatform == TargetPlatform.iOS || 
                  defaultTargetPlatform == TargetPlatform.macOS;
  
  final switchWidget = isApple 
      ? CupertinoSwitch(value: true, onChanged: (_) {})
      : Switch(value: true, onChanged: (_) {});

  // Responsive layout based on constraints
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth > 600) {
        return Row(children: [const Text('Settings'), switchWidget]);
      }
      return Column(children: [const Text('Settings'), switchWidget]);
    },
  );
}
```
