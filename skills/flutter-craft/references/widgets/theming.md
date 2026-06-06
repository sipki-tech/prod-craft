# Theming and Design Tokens
Rules for implementing scalable, cohesive styling utilizing Material 3, `ThemeData`, and design tokens.

**Define colors through `ColorScheme` instead of raw hex values**
- **Reason:** Hardcoding colors throughout the UI creates a fragmented design system and makes supporting dark mode exceptionally difficult. Utilizing `Theme.of(context).colorScheme` ensures elements adapt naturally to light/dark themes and dynamic palettes (like Material 3's Material You).

```dart
// Bad
Container(
  color: const Color(0xFFE0E0E0),
  child: const Text(
    'Warning',
    style: TextStyle(color: Color(0xFFD32F2F)),
  ),
)

// Good
Container(
  color: Theme.of(context).colorScheme.surfaceContainer,
  child: Text(
    'Warning',
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  ),
)
```

**Use `TextTheme` for typographic scale**
- **Reason:** Manually defining `fontSize`, `fontWeight`, and `fontFamily` across widgets causes visual inconsistencies. `TextTheme` provides a standardized scale (e.g., `headlineLarge`, `bodyMedium`) that can be overridden globally at the `ThemeData` level.

```dart
// Bad
const Text(
  'Page Title',
  style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.15,
  ),
)

// Good
Text(
  'Page Title',
  style: Theme.of(context).textTheme.headlineSmall,
)
```

**Implement design tokens using Theme extensions**
- **Reason:** If the design system includes semantic properties not covered by the default `ThemeData` (e.g., specific brand gradients, custom success state colors, or standardized border radii), overriding existing theme properties leads to confusion. `ThemeExtension` allows for strongly-typed, scalable custom design tokens.

```dart
// Bad
class AppColors {
  static const brandGradient = LinearGradient(colors: [Colors.blue, Colors.purple]);
  static const successColor = Colors.green;
}

// In widget:
Container(color: AppColors.successColor) // Doesn't adapt to dark mode

// Good
class CustomColors extends ThemeExtension<CustomColors> {
  const CustomColors({
    required this.success,
    required this.brandGradient,
  });

  final Color success;
  final Gradient brandGradient;

  @override
  ThemeExtension<CustomColors> copyWith({
    Color? success,
    Gradient? brandGradient,
  }) {
    return CustomColors(
      success: success ?? this.success,
      brandGradient: brandGradient ?? this.brandGradient,
    );
  }
  
  @override
  ThemeExtension<CustomColors> lerp(
    covariant ThemeExtension<CustomColors>? other,
    double t,
  ) {
    if (other is! CustomColors) return this;
    return CustomColors(
      success: Color.lerp(success, other.success, t)!,
      brandGradient: Gradient.lerp(brandGradient, other.brandGradient, t)!,
    );
  }
}

// In widget:
Container(
  color: Theme.of(context).extension<CustomColors>()?.success,
)
```
