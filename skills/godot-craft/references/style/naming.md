# GDScript Naming Conventions

This document defines the naming conventions for GDScript within Godot 4.x projects. Standardizing these naming patterns guarantees clean code readability, prevents cross-platform file conflicts, and aligns development with the engine's built-in APIs.

## 1. Snake Case for Files, Variables, and Functions

Use `snake_case` for file names, variable names, and function names.
- **Reason:** GDScript and Godot's built-in APIs are built on `snake_case` conventions. Standardizing files, variables, and functions in `snake_case` keeps code consistent with the engine and avoids cross-platform file loading issues on case-sensitive operating systems.
```gdscript
# Good
# File: res://src/characters/player_controller.gd
var character_speed: float = 300.0


func move_to_position(target: Vector2) -> void:
	pass

# Bad
# File: res://src/characters/PlayerController.gd
var characterSpeed: float = 300.0

func MoveToPosition(target: Vector2) -> void:
	pass
```

## 2. PascalCase for Classes and Scene Nodes

Use `PascalCase` for class definitions (`class_name`) and scene node names.
- **Reason:** PascalCase distinguishes types and objects in the scene tree from instance variables and functions, aligning custom classes and node names with Godot's built-in node classes.
```gdscript
# Good
# In script:
class_name PlayerController
extends CharacterBody2D

# In Scene Tree:
# Player (CharacterBody2D)
# └── CollisionShape2D

# Bad
# In script:
class_name player_controller
extends CharacterBody2D

# In Scene Tree:
# player_node (CharacterBody2D)
# └── collision_shape_2d
```

## 3. CONSTANT_CASE for Constants

Use `CONSTANT_CASE` for all constant names.
- **Reason:** CONSTANT_CASE (screaming snake case) highlights read-only values, configuration flags, and magic numbers at a glance, making them visually distinct from mutable state variables.
```gdscript
# Good
const MAX_HEALTH: int = 100

const DEFAULT_SPEED: float = 400.0

# Bad
const max_health: int = 100
const defaultSpeed: float = 400.0
```

## 4. Past-Tense Verbs for Signals

Use past-tense verb phrases in `snake_case` for signal declarations.
- **Reason:** Signals represent events that have already occurred. Past-tense naming aligns with Godot's built-in signals (e.g., `pressed`, `area_entered`) and helps clarify the sender-receiver flow in asynchronous event handling.
```gdscript
# Good
signal health_changed(new_health: int)

signal level_completed

# Bad
signal change_health(new_health: int)
signal complete_level
```

## 5. Single Leading Underscore for Private/Internal Members

Prefix private variables, private functions, and virtual methods/overrides with a single leading underscore `_`.
- **Reason:** GDScript does not feature native access modifiers like `private` or `protected`. The leading underscore serves as a standard visibility convention indicating to developers that a member is for internal or override use only.
```gdscript
# Good
var _stealth_timer: Timer


func _ready() -> void:
	_initialize_attributes()


func _initialize_attributes() -> void:
	pass

# Bad
var stealth_timer: Timer

func ready() -> void:
	initialize_attributes()

func initialize_attributes() -> void:
	pass
```

## 6. Scene Unique Nodes

Use the percent sign `%` prefix to reference scene-unique nodes, keeping node names in `PascalCase`.
- **Reason:** Scene Unique Nodes are accessed using the `%` prefix syntax in GDScript. Naming them in `PascalCase` maintains consistency with node-naming conventions and keeps node references decoupled from the specific scene tree hierarchy.
```gdscript
# Good
@onready var main_menu: Control = %MainMenu

@onready var status_label: Label = %StatusLabel

# Bad
@onready var main_menu: Control = $CanvasLayer/MainMenu
@onready var status_label: Label = %status_label
```
