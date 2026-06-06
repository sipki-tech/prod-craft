# GDScript Enum Conventions

This document defines the rules and conventions for declaring and using enums in GDScript within Godot 4.x projects. Standardizing enum usage ensures static type safety, avoids magic values, and enhances code readability and maintainability.

## 1. PascalCase for Enum Names and CONSTANT_CASE for Values

Use `PascalCase` for named enums, and use `CONSTANT_CASE` for their values without repeating the enum's name as a prefix.
- **Reason:** Using PascalCase for the enum name distinguishes it as a custom type signature in the class scope, aligning it with other class names and types in Godot 4.x/GDScript 2.0. Using CONSTANT_CASE for enum values highlights that they are immutable constants, and omitting the enum name as a prefix avoids redundant repetition when referring to them (e.g., `State.IDLE` instead of `State.STATE_IDLE`).

```gdscript
# Good
extends Node

enum CharacterState {
	IDLE,
	RUNNING,
	JUMPING,
}

var current_state: CharacterState = CharacterState.IDLE
```

```gdscript
# Bad
extends Node

# Named enum does not use PascalCase, and values repeat the enum name and are lowercase
enum character_state {
	CHARACTER_STATE_idle,
	CHARACTER_STATE_running,
	CHARACTER_STATE_jumping,
}

var current_state: character_state = character_state.CHARACTER_STATE_idle
```

## 2. Prefer Named Enums for Type Safety

Always define enums with a name to create a strong type signature, avoiding anonymous (unnamed) enums.
- **Reason:** Named enums create a distinct static type in GDScript 2.0, allowing you to use them in function parameter signatures, variable type annotations, and return types. Anonymous enums are treated as global constants and do not provide static type safety.

```gdscript
# Good
extends Node

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
}

var current_state: GameState = GameState.MENU


func set_state(new_state: GameState) -> void:
	current_state = new_state
```

```gdscript
# Bad
extends Node

# Anonymous enum does not create a type signature, and values default to global constants
enum {
	STATE_MENU,
	STATE_PLAYING,
	STATE_PAUSED,
}

# Cannot use the enum name as a type annotation, must fallback to generic int
var current_state: int = STATE_MENU


# Parameter lacks strict type safety, allowing any integer to be passed
func set_state(new_state: int) -> void:
	current_state = new_state
```

> **Style Warning: Avoid Raw Integer Comparisons**
> Do not compare named enum variables directly to raw integer literals (e.g., `current_state == 0` or `if current_state == 0:`). Since enums are integers under the hood in GDScript, this compiles but bypasses all type safety benefits and autocompletion. Always compare against the fully qualified enum member (e.g., `current_state == GameState.MENU`).

## 3. Exhaustive Match Statements Without Wildcards

Explicitly handle every enum member in `match` statements, avoiding wildcards (`_`) unless catching unexpected or corrupted states with runtime warnings/assertions (defensive programming fallback).
- **Reason:** The GDScript compiler does not perform compile-time match exhaustiveness checks on enums. Explicitly listing all members is a visual check for developers during code review to ensure all cases are handled and enables defensive assertions to catch unhandled values at runtime. The wildcard pattern (`_`) should only be used as a defensive fallback to raise assertions or warnings for corrupted or unexpected states, rather than as a general catch-all that silently hides omissions when new enum values are added.

```gdscript
# Good
extends Node

enum WeaponType {
	SWORD,
	BOW,
	STAFF,
}

var equipped_weapon: WeaponType = WeaponType.SWORD


func get_weapon_damage(weapon: WeaponType) -> int:
	match weapon:
		WeaponType.SWORD:
			return 15
		WeaponType.BOW:
			return 10
		WeaponType.STAFF:
			return 8
		_:
			push_error("Unhandled weapon type: %s" % weapon)
			assert(false, "Unhandled weapon type")
			return 0


func is_weapon_ranged(weapon: WeaponType) -> bool:
	match weapon:
		WeaponType.BOW:
			return true
		WeaponType.SWORD, WeaponType.STAFF:
			return false
		_:
			push_error("Unhandled weapon type: %s" % weapon)
			assert(false, "Unhandled weapon type")
			return false
```

```gdscript
# Bad
extends Node

enum WeaponType {
	SWORD,
	BOW,
	STAFF,
}

var equipped_weapon: WeaponType = WeaponType.SWORD


func get_weapon_damage(weapon: WeaponType) -> int:
	match weapon:
		WeaponType.SWORD:
			return 15
		_:
			# Lazy catch-all hides missing cases if new weapons are added (e.g., BOW and STAFF return 0)
			return 0
```

## 4. Use Enums instead of Magic Strings or Booleans for Multi-State Logic

Represent states, modes, or categories with named enums instead of magic strings or multiple boolean variables (boolean soup).
- **Reason:** Representing mutually exclusive states, modes, or categories using named enums provides static validation and code completion. Using magic strings is prone to typos, and using multiple booleans (boolean soup) can lead to invalid states (e.g., a player being both `is_jumping = true` and `is_swimming = true` simultaneously) and is harder to maintain.

```gdscript
# Good
extends Node

enum MovementState {
	IDLE,
	WALKING,
	RUNNING,
	JUMPING,
}

var current_state: MovementState = MovementState.IDLE


func update_movement(delta: float) -> void:
	match current_state:
		MovementState.IDLE:
			_process_idle(delta)
		MovementState.WALKING:
			_process_walking(delta)
		MovementState.RUNNING:
			_process_running(delta)
		MovementState.JUMPING:
			_process_jumping(delta)


func _process_idle(_delta: float) -> void:
	pass


func _process_walking(_delta: float) -> void:
	pass


func _process_running(_delta: float) -> void:
	pass


func _process_jumping(_delta: float) -> void:
	pass
```

```gdscript
# Bad
extends Node

var is_idle: bool = true

var is_walking: bool = false

var is_running: bool = false

var is_jumping: bool = false

var movement_mode: String = "idle"


func update_movement(delta: float) -> void:
	# High risk of invalid state combinations (e.g., multiple booleans true at once)
	if movement_mode == "idlee": # Typo in string goes undetected at compile-time
		_process_idle(delta)
	elif is_walking:
		_process_walking(delta)
	elif is_running:
		_process_running(delta)
	elif is_jumping:
		_process_jumping(delta)


func _process_idle(_delta: float) -> void:
	pass


func _process_walking(_delta: float) -> void:
	pass


func _process_running(_delta: float) -> void:
	pass


func _process_jumping(_delta: float) -> void:
	pass
```

## 5. Checklist

- [ ] Use `PascalCase` for named enums (e.g., `CharacterState`).
- [ ] Use `CONSTANT_CASE` for enum values (e.g., `IDLE`).
- [ ] Omit the enum name as a prefix in its values to avoid redundancy (e.g., `State.IDLE` instead of `State.STATE_IDLE`).
- [ ] Prefer named enums over anonymous enums to ensure static type safety, variable annotations, and autocompletion.
- [ ] Avoid comparing named enums directly to raw integer literals (e.g., `current_state == 0` or `if current_state == 0:`).
- [ ] Write exhaustive `match` statements that explicitly list all enum members for readability and code review.
- [ ] Use wildcard patterns (`_`) in `match` statements only as defensive fallbacks (with assertions/errors) to catch unexpected runtime values, rather than as general catch-alls.
- [ ] Use enums instead of magic strings or multiple boolean variables (boolean soup) for multi-state logic.

