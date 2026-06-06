# GDScript Code Structure

This document defines the rules and best practices for organizing the internal layout and structure of GDScript files in Godot 4.x projects. Standardizing member ordering and vertical spacing ensures consistent code readability across the development team.

## 1. Canonical Class Member Order

Maintain a strict, consistent order for all class member declarations within a script.
- **Reason:** Ordering class members consistently makes files predictable and easy to navigate. Developers can locate signals, constants, exports, lifecycle methods, and private helpers instantly without having to scan or search the entire file.
```gdscript
# Good
## Controls player movement, input handling, and animations.
@tool
class_name PlayerController
extends CharacterBody2D

signal state_changed(new_state: String)

enum MovementMode { WALK, RUN, SNEAK }

const MAX_SPEED: float = 300.0

@export_group("Movement Settings")
@export var speed: float = 200.0

@export var acceleration: float = 800.0

var current_mode: MovementMode = MovementMode.WALK

var is_active: bool = true

var _velocity_modifier: float = 1.0

var _health: int = 100

@onready var _sprite: Sprite2D = $Sprite2D as Sprite2D

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D as CollisionShape2D


func _init() -> void:
	pass


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


func apply_damage(amount: int) -> void:
	_health = maxi(0, _health - amount)
	_update_state()


func _update_state() -> void:
	if _health == 0:
		state_changed.emit("dead")
```

```gdscript
# Bad
class_name PlayerController
extends CharacterBody2D

var current_mode := 0


func _process(_delta: float) -> void:
	pass


@export var speed: float = 200.0


func apply_damage(amount: int) -> void:
	pass


const MAX_SPEED: float = 300.0

@onready var _sprite: Sprite2D = $Sprite2D as Sprite2D


func _ready() -> void:
	pass


signal state_changed(new_state: String)
```

## 2. Chronological Sequencing of Virtual and Lifecycle Methods

Arrange virtual and lifecycle methods chronologically according to their execution sequence in Godot.
- **Reason:** Structuring lifecycle methods chronologically (e.g., `_init` before `_enter_tree` / `_ready`, and `_ready` before input/processing) reflects the actual execution flow of the engine. This makes it easier to trace initialization dependencies and runtime loops.
```gdscript
# Good
func _init() -> void:
	pass


func _enter_tree() -> void:
	pass


func _ready() -> void:
	pass


func _input(event: InputEvent) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	pass


func _process(_delta: float) -> void:
	pass


func _physics_process(_delta: float) -> void:
	pass
```

```gdscript
# Bad
func _physics_process(delta: float) -> void:
	pass


func _ready() -> void:
	pass


func _init() -> void:
	pass


func _input(event: InputEvent) -> void:
	pass
```

## 3. Vertical Spacing and Blank Lines

Use a single blank line between all non-function class member declarations (including between different sections like constants, exports, and variables) and exactly two blank lines between function and method definitions.
- **Reason:** Strict spacing rules establish a consistent visual rhythm in scripts. Single blank lines keep property declarations clean and grouped, matching standard `gdformat` collapsing behavior, while exactly two blank lines between functions separate logical behavior blocks clearly.
- **Note:** Properties with multi-line inline setters or getters should also be separated by a single blank line from other declarations to keep the structure clean.
```gdscript
# Good
const BASE_VALUE: int = 10

const MULTIPLIER: float = 1.5

@export var base_speed: float = 100.0

@export var boost_speed: float = 200.0

var _current_speed: float = 0.0


func _ready() -> void:
	_current_speed = base_speed


func get_speed() -> float:
	return _current_speed
```

```gdscript
# Bad
const BASE_VALUE: int = 10
const MULTIPLIER: float = 1.5
@export var base_speed: float = 100.0

@export var boost_speed: float = 200.0
var _current_speed: float = 0.0

func _ready() -> void:
	_current_speed = base_speed
func get_speed() -> float:
	return _current_speed
```

## 4. Structured Documentation Comments

Write documentation comments prefixed with a double-hash `##` and place them directly above the target declaration with no blank line in between.
- **Reason:** Prefixing documentation with a double-hash `##` enables Godot's built-in script documentation generator to parse the comment as a description. Placing the comment directly above the declaration without a blank line binds the description to that specific class, member, or function.
```gdscript
# Good
## Controls character movement, inputs, and physical interactions.
class_name PhysicsActor
extends CharacterBody2D

## Emitted when the character falls below 0 health.
signal died

## The multiplier applied when running.
@export var run_multiplier: float = 1.5


## Calculates the speed based on current state.
func calculate_speed() -> float:
	return 10.0
```

```gdscript
# Bad
# Controls character movement, inputs, and physical interactions.
class_name PhysicsActor
extends CharacterBody2D

## Emitted when the character falls below 0 health.

signal died

# The multiplier applied when running.
@export var run_multiplier: float = 1.5

## Calculates the speed based on current state.


func calculate_speed() -> float:
	return 10.0
```

## 5. Grouping Exported Variables

Use `@export_group` and `@export_subgroup` to organize inspector properties, and keep these declarations contiguous in the code.
- **Reason:** Grouping exported variables enhances usability in the Godot inspector. Keeping the groups contiguous in the code matches the visual structure of the inspector and prevents grouping from bleeding into unrelated variables.
```gdscript
# Good
@export_group("Stats")
@export var max_health: int = 100

@export var armor: int = 50

@export_subgroup("Movement")
@export var walk_speed: float = 200.0

@export var run_speed: float = 300.0

@export_group("FX")
@export var hit_particles: GPUParticles2D = null
```

```gdscript
# Bad
@export_group("Stats")
@export var max_health: int = 100
var temporary_internal_stat: float = 0.0
@export var armor: int = 50

@export_subgroup("Movement")
@export var walk_speed: float = 200.0
# Breaking the group contiguousness with a private variable
var _is_running: bool = false
@export var run_speed: float = 300.0
```

## 6. Inner Classes Placement

Declare inner classes (`class`) at the very end of the file, after all private methods of the primary class.
- **Reason:** Keeping inner classes at the end of the file keeps the primary class structure readable, keeping secondary helper classes grouped together at the bottom without cluttering the main logic flow.
- **Note:** Member ordering and spacing rules must also be followed within nested scopes, such as inside inner classes.
```gdscript
# Good
func _ready() -> void:
	_calculate_damage()


func _calculate_damage() -> void:
	pass


class DamageData:
	var amount: int = 0

	var type: String = ""
```

```gdscript
# Bad
class DamageData:
	var amount: int = 0
	var type: String = ""


func _ready() -> void:
	_calculate_damage()


func _calculate_damage() -> void:
	pass
```
