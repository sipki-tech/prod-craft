# Static Analysis with gdlint

Enforce GDScript code quality, naming standards, and architectural boundaries using gdlint. Integrate static analysis checks into developer pre-commit hooks and continuous integration workflows to catch bugs early.

## 1. Function Complexity Limits
- **Reason:** Keeping functions focused reduces cognitive load, improves testability, and complies with `.gdlintrc` limits (`max-arguments: 6`, `max-returns: 3`, `max-local-variables: 10`).

```gdscript
# Good


func calculate_spawn_point(player_pos: Vector2, speed: float, direction: Vector2) -> Vector2:
	var offset := direction * speed
	var target_pos := player_pos + offset
	return target_pos

# Bad
func spawn_enemy_with_attributes(
	player_pos: Vector2, 
	speed: float, 
	direction: Vector2, 
	health: int, 
	armor: int, 
	damage: int, 
	faction: String, 
	is_boss: bool
) -> Array:
	# Violates gdlint limits: 8 arguments (max 6), too many local variables
	var offset := direction * speed
	var target_pos := player_pos + offset
	var final_hp := health + armor
	var is_hostile := faction == "enemy"
	var type_label := "boss" if is_boss else "minion"
	var size_multiplier := 2.0 if is_boss else 1.0
	var detection_radius := 500.0 if is_boss else 200.0
	var loot_table := "rare" if is_boss else "common"
	var xp_reward := 100 if is_boss else 10
	var enemy_data := [target_pos, final_hp, is_hostile, type_label, size_multiplier, detection_radius, loot_table, xp_reward]
	return enemy_data
```

## 2. Private Underscore Prefix
- **Reason:** `gdlint` enforces a `^_[a-z0-9_]*$` pattern for private members to make public and private interfaces visually distinct and maintain encapsulation boundaries.

```gdscript
# Good
var _health_cache: int = 100


func _ready() -> void:
	_update_cache()


func _update_cache() -> void:
	_health_cache = 100

# Bad
var healthCache: int = 100 # Bad casing and lacks underscore prefix

func _ready() -> void:
	updateCache()

func updateCache() -> void: # Private/helper function lacks leading underscore
	healthCache = 100
```

## 3. Single Class Per File
- **Reason:** `gdlint` restricts each script to a single class definition (`max-classes: 1`) to ensure clear file-to-class mappings, clean navigation, and modular scripts.

```gdscript
# Good
# enemy_weapon.gd
class_name EnemyWeapon extends Node2D


func fire() -> void:
	pass

# Bad
# enemy.gd
class_name BadEnemy extends CharacterBody2D

# Inner class definition violates the max-classes: 1 limit
class EnemyWeapon extends Node2D:
	func fire() -> void:
		pass
```

## 4. Naming Conventions
- **Reason:** Consistent casing rules are verified by the linter to ensure a uniform style across the project (snake_case for variables/functions/signals, PascalCase for classes, CONSTANT_CASE for constants).

```gdscript
# Good
class_name PlayerController extends CharacterBody2D

signal state_changed(new_state: String)

const MAX_SPEED: float = 400.0

var move_velocity: Vector2 = Vector2.ZERO

# Bad
class_name playerController extends CharacterBody2D # PascalCase violation

signal StateChanged(newState: String) # snake_case violation

const Max_Speed: float = 400.0 # CONSTANT_CASE violation
var moveVelocity: Vector2 = Vector2.ZERO # snake_case violation
```

## 5. Inline Disable Annotations
- **Reason:** Inline disables bypass static analysis checks and should be used sparingly (such as when matching external engine callback signatures) and always documented with a clear explanation of why the rule is bypassed.

```gdscript
# Good
# gdlint: disable=unused-argument


func _on_physics_frame_ended(_delta: float) -> void:
	# Unused argument is necessary to match engine callback signature but not used here.
	pass

# Bad
func _on_physics_frame_ended(delta: float) -> void:
	# Violates unused-argument rule without prefixing or inline gdlint disable statement.
	pass
```

## 6. Structured gdlintrc Config
- **Reason:** A well-structured configuration file categorizes rules to clarify naming styles, class/function definitions, and formatting options, preventing accidental drift and simplifying adjustments.

```jsonc
// Good
// .gdlintrc at project root:
{
  "class-definitions": {
    "max-classes": 1
  },
  "function-definitions": {
    "max-arguments": 6,
    "max-returns": 3,
    "max-local-variables": 10
  },
  "variable-naming": {
    "style": "snake_case"
  },
  "function-naming": {
    "style": "snake_case"
  },
  "class-naming": {
    "style": "PascalCase"
  },
  "constant-naming": {
    "style": "CONSTANT_CASE"
  },
  "signal-naming": {
    "style": "snake_case"
  },
  "private-sub-names": {
    "pattern": "^_[a-z0-9_]*$"
  }
}

// Bad
// Relying on global default values which allow up to 10 arguments, 20 local variables, 
// and dynamic PascalCase/camelCase function naming without validation.
```

## 7. Pre-Commit Hook Integration
- **Reason:** Running `gdlint` locally on staged files prevents syntax and style regressions from reaching the remote repository, saving CI minutes and keeping the git history clean.

```yaml
# Good
# Setup a .pre-commit-config.yaml at the project root:
repos:
  - repo: https://github.com/Scony/godot-gdscript-toolkit
    rev: 4.2.2  # Matches godot-gdscript-toolkit release
    hooks:
      - id: gdlint
        name: gdlint (GDScript Linter)
        description: "Lints GDScript source code using gdlint"
        entry: gdlint
        language: python
        types: [gdscript]

# Bad
# Committing code without local static analysis checks and relying solely on CI to catch errors:
git commit -n -m "WIP: skip hooks"
```
