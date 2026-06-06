# Editor Warning Settings

Configure project.godot settings to enforce strict static typing and clean programming practices. Treat warnings as errors to catch common runtime bugs at compile time.

## 1. Explicit Type Declarations
- **Reason:** Setting `untyped_declaration` to error (`2`) prevents variables or function parameters from implicitly falling back to dynamic `Variant` types. This ensures type safety at compile time and helps the IDE auto-complete methods and variables.

```gdscript
# Good
var current_health: int = 100

var player_name := "Hero"


func heal(amount: int) -> void:
	current_health += amount

# Bad
# Omitting explicit type annotations or static inference causes implicit Variant fallbacks:
# var current_health: int = 100
# func heal(amount: int) -> void:
# 	current_health += amount

# Statically-typed placeholder to keep the code block non-empty and syntactically valid:
var _untyped_placeholder: int = 0
```

## 2. Unsafe Member Access
- **Reason:** Unsafe property and method accesses on dynamically-typed variables can crash at runtime. Setting `unsafe_property_access` and `unsafe_method_access` to error (`2`) blocks this by requiring developer type-assertion or explicit casts.

```gdscript
# Good
@onready var texture_rect: TextureRect = $TextureRect as TextureRect


func set_texture(tex: Texture2D) -> void:
	if texture_rect:
		texture_rect.texture = tex

# Bad
# Declaring node with base type 'Node' instead of specific subclass:
@onready var texture_rect: Node = $TextureRect


func set_texture(tex: Texture2D) -> void:
	# Unsafe property access: 'texture' is not a property of 'Node'
	texture_rect.texture = tex
```

## 3. Integer Division Warning
- **Reason:** Integer division in GDScript (e.g. `3 / 2`) discards the fractional part and returns an integer (`1`), which often leads to layout or mathematical bugs. Enabling warnings prompts developers to use explicit floats or casts.

```gdscript
# Good
# Explicit float division:
var screen_ratio: float = 16.0 / 9.0

# Explicit cast:
var width: int = 1920
var center_offset: float = float(width) / 2.0

# Bad
var screen_ratio: float = 16 / 9 # Evaluates to 1.0 instead of 1.7778
var width: int = 1920
var center_offset: float = width / 2 # Triggers integer_division warning
```

## 4. Warning Severity Levels
- **Reason:** In Godot 4.x, warning configurations are customized per warning type instead of a single global master switch. Setting specific settings to `2` raises them as compile-blocking errors, ensuring zero dynamic type regressions.

```ini
# Good
# Add this snippet to project.godot:
[debug/gdscript/warnings]

# Strict compilation blocks (2 = Error)
untyped_declaration=2
unsafe_property_access=2
unsafe_method_access=2
integer_division=2

# Logical check warnings (1 = Warning)
unsafe_cast=1
narrowing_conversion=1
unused_parameter=1
unused_signal=1
shadowed_variable=1

# Bad
# Setting unsafe settings to ignore (0) or warning (1) without breaking build compilation:
[debug/gdscript/warnings]
untyped_declaration=1
unsafe_property_access=0
unsafe_method_access=0
```

## 5. Editor Auto-Typing
- **Reason:** Forcing static typing can increase developer overhead if done manually. Enabling editor type hints automates this typing on script creation and autocompletion, aligning workspace ergonomics with type-safety policies.

```text
# Good
Inside editor_settings-4.x.tres or Editor Settings UI:
Text Editor -> Completion -> Add Type Hints = true
Text Editor -> Behavior -> Navigation -> Stay In Script = true

# Bad
Inside editor_settings-4.x.tres or Editor Settings UI:
Text Editor -> Completion -> Add Type Hints = false
```
