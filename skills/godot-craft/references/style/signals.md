# GDScript Signal Conventions

This document defines the coding standards and best practices for declaring, connecting, and utilizing signals in GDScript for Godot 4.x projects. Standardizing signal usage ensures loose coupling, static type safety, and clean event flow across the codebase.

## 1. Past-Tense Verbs in Snake Case for Signal Declarations

Declare signals using past-tense verb phrases in `snake_case`.
- **Reason:** Signals represent events that have already occurred. Past-tense naming aligns with Godot's built-in signals (e.g., `pressed`, `area_entered`, `body_shape_exited`) and helps clarify that the signal is a notification of a past event, not a command to perform a future action.

```gdscript
# Good
signal health_changed(new_health: int)

signal item_collected(item_name: StringName, amount: int)

signal game_started
```

```gdscript
# Bad
signal change_health(new_health: int)

signal collect_item(item_name: StringName, amount: int)

signal start_game
```

## 2. Callable-Based Signal Connection

Connect signals using Callable-based syntax (e.g., `signal.connect(callable)`) rather than string-based connection names.
- **Reason:** Godot 4.x supports first-class Callable objects. Connecting signals using direct references allows the compiler and language server to statically verify that both the signal and target callback exist, and that their parameters are compatible. String-based connections (using `connect("signal_name", ...)` or `Callable(self, "method_name")`) bypass these checks, deferring errors to runtime and leading to silent failures during refactoring.

```gdscript
# Good
# level.gd
class_name Level extends Node2D

@onready var player: Player = $Player as Player


func _ready() -> void:
	if player:
		player.health_depleted.connect(_on_player_death)


func _on_player_death() -> void:
	var _result := get_tree().reload_current_scene()
```

```gdscript
# Bad
# level.gd
class_name Level extends Node2D


func _ready() -> void:
	# String-based connections bypass compile-time syntax checks and fail silently at runtime
	var player := $Player as Node
	if player:
		player.connect("health_depleted", Callable(self, "_on_player_death"))


func _on_player_death() -> void:
	var _result := get_tree().reload_current_scene()
```

## 3. Strict Static Typing for Signal Parameters

Explicitly declare type annotations for all parameters within signal signatures.
- **Reason:** Fully typing signal parameters prevents dynamic type mismatches when passing values across decoupled boundaries. Under strict project settings, untyped declarations trigger compilation errors or warnings. Statically typed parameters also enable autocomplete, compile-time parameter matching, and inline tooltip assistance in the Godot editor.

```gdscript
# Good
# character.gd
class_name Character extends CharacterBody2D

signal status_effect_applied(effect_id: StringName, duration: float, potency: int)

signal experience_gained(amount: int, is_bonus: bool)
```

```gdscript
# Bad
# character.gd
class_name Character extends CharacterBody2D

# Untyped parameters trigger warnings under strict linting and bypass compile-time verification
signal status_effect_applied(effect_id, duration, potency)

signal experience_gained(amount, is_bonus)
```

## 4. Signal Architecture: Bottom-Up Communication vs Direct Top-Down Calls

Use signals for bottom-up or lateral communication to decouple systems, and use direct method calls for top-down control.
- **Reason:** Adhering to the "Call Down, Signal Up" design pattern maintains clean scene hierarchies and prevents circular dependencies. Parent nodes manage the lifecycles of their children and can safely invoke their methods directly. Children, however, must never access parent nodes directly, as it tightly couples them to a specific parent context. Instead, children emit signals to notify whoever is listening, ensuring the child remains fully self-contained and reusable.

```gdscript
# Good
# health_bar.gd (Child Node)
class_name HealthBar extends TextureProgressBar

signal animation_completed


func update_value(new_value: float) -> void:
	value = clampf(new_value, min_value, max_value)
	# Update UI animation...
	animation_completed.emit()


# player.gd (Parent Node)
class_name Player extends CharacterBody2D

@onready var health_bar: HealthBar = $CanvasLayer/HealthBar as HealthBar


func _ready() -> void:
	if health_bar:
		# Decoupled bottom-up connection: Parent listens to child's signal
		health_bar.animation_completed.connect(_on_health_bar_animation_completed)


func take_damage(amount: float) -> void:
	# Clean top-down method call: Parent directs child to act
	if health_bar:
		health_bar.update_value(amount)


func _on_health_bar_animation_completed() -> void:
	print("Health bar animation finished updating.")
```

```gdscript
# Bad
# health_bar.gd (Child Node)
class_name HealthBar extends TextureProgressBar


func update_value(new_value: float) -> void:
	value = clampf(new_value, min_value, max_value)
	# Update UI animation...
	
	# Tight coupling: Child directly accesses parent, assuming its type and interface
	var player := get_parent() as Player
	if player:
		player._on_health_bar_animation_completed()
```

## 5. Checklist

- [ ] Declare signals using past-tense verb phrases in `snake_case` (e.g., `health_changed`).
- [ ] Connect signals using Callable-based syntax (e.g., `signal.connect(callable)`).
- [ ] Never use string-based signal connection names or `connect("signal_name", ...)` syntax.
- [ ] Fully type all parameters in signal declarations (e.g., `signal health_changed(new_value: int)`).
- [ ] Use signals exclusively for bottom-up and lateral communication.
- [ ] Use direct method calls for top-down control.
