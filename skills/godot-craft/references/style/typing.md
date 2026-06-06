# GDScript Static Typing Guidelines

This document defines the rules and best practices for enforcing strict static typing in GDScript for Godot 4.x projects. Standardizing static typing guarantees runtime safety, prevents common bugs, enhances editor support, and optimizes execution performance.

## 1. Mandatory Static Typing for All Declarations

Declare explicit types or use static type inference for all variables, constants, and parameters.
- **Reason:** Static typing eliminates runtime dynamic type errors (like operations on mismatched types) and provides the compiler and editor with clear type definitions to enable full autocomplete and inline errors before running the game.

```gdscript
# Good
extends Node

var max_speed: float = 250.0

const COOLDOWN_TIME: float = 1.5


func apply_boost(factor: float) -> void:
	var adjusted_speed: float = max_speed * factor
```

```gdscript
# Bad
extends Node

# Fails: untyped_declaration error under strict settings
var max_speed = 250.0
const COOLDOWN_TIME = 1.5

func apply_boost(factor):
	var adjusted_speed = max_speed * factor
```

## 2. Type Inference vs Explicit Type Annotations

Use static type inference (`:=`) only when the type is obvious from the literal, constructor, or explicit cast. Use explicit annotations when initializing to `null`, declaring `@export` variables, or resolving base types.
- **Reason:** Static type inference (`:=`) reduces redundant type noise when the assigned value is clear. However, explicit annotations are required for exports to ensure correctness in the Inspector, and for variables initialized to `null` or base class types (like `Node`) to prevent compilation errors under strict project settings.

```gdscript
# Good
extends CharacterBody2D

# 1. Literals and constants (type is obvious and fully resolved)
var score := 0

var velocity_vector := Vector2.ZERO

# 2. Constructors (type is fully resolved)
var timer := Timer.new()

# 3. Explicit casts to resolve specific type (prevents base type inference)
@warning_ignore("unsafe_cast")
@onready var target_sprite := $Sprite2D as Sprite2D

# 4. Explicit annotations for exports and null initializers
@export var max_health: int = 100

var cached_node: Sprite2D = null


func _physics_process(_delta: float) -> void:
	if get_slide_collision_count() > 0:
		var collider: Object = get_slide_collision(0).get_collider()
		# Use localized warning ignore immediately after runtime check (see Section 6)
		if collider is Enemy:
			@warning_ignore("unsafe_cast")
			var enemy := collider as Enemy
			enemy.take_damage(10)
```

```gdscript
# Bad
extends CharacterBody2D

# 1. Redundant explicit annotations
var score: int = 0
var velocity_vector: Vector2 = Vector2.ZERO

# 2. Avoid inference for inspector variables (exports need explicit type)
@export var max_health := 100

# 3. Fails to infer type or results in untyped variable
var cached_node := null

# 4. Implicit Base Type Inference (Unsafe)
# $Sprite2D is inferred as Node (base class), leading to compile errors when accessing Sprite2D properties
@onready var target_sprite := $Sprite2D

func _physics_process(_delta: float) -> void:
	# 5. Calling instance method at class scope (Syntax/Runtime error)
	# var target_enemy := get_collider() 

	# 6. Referencing undefined variable 'collider' or using unsafe implicit inference
	var target_enemy := get_slide_collision(0).get_collider() # Inferred as Object
	target_enemy.take_damage(10) # Fails: unsafe_method_access (or compile error: method not found in Object)
```

## 3. Mandatory Function Return Types

Specify an explicit return type for all function signatures using the `->` operator, including `-> void` for functions that do not return a value.
- **Reason:** Declaring return types enforces strict API contracts for custom methods, enabling the compiler to check caller-callee compatibility and preventing developers from accidentally using return values of side-effect-only functions.

```gdscript
# Good
extends Node

var health: int = 100

var max_health: int = 100


func update_health(amount: int) -> void:
	health = clampi(health + amount, 0, max_health)


func is_alive() -> bool:
	return health > 0
```

```gdscript
# Bad
extends Node

var health: int = 100
var max_health: int = 100

# Fails: untyped_declaration error (missing return types)
func update_health(amount: int):
	health = clampi(health + amount, 0, max_health)

func is_alive():
	return health > 0
```

## 4. Strict Project Settings Enforcements

Configure project settings (`project.godot`) to treat untyped declarations and unsafe accesses as compile-time errors.
- **Reason:** Enforcing static typing through Godot's debug settings automated compile checks ensures developers cannot commit dynamically typed code, catching unsafe property/method accesses and untyped variables during development and CI.

```gdscript
# Good
# project.godot setting: debug/gdscript/warnings/untyped_declaration=2 (Error)
# project.godot setting: debug/gdscript/warnings/unsafe_method_access=2 (Error)

extends Node2D

@warning_ignore("unsafe_cast")
@onready var player_node: CharacterBody2D = $Player as CharacterBody2D


func _physics_process(_delta: float) -> void:
	if player_node:
		player_node.move_and_slide()  # Fully type-safe and compiles cleanly
```

```gdscript
# Bad
# project.godot setting: debug/gdscript/warnings/untyped_declaration=2 (Error)
# project.godot setting: debug/gdscript/warnings/unsafe_method_access=2 (Error)

extends Node2D

# 1. Fails: untyped_declaration error
@onready var player_node_untyped = $Player  

# 2. Infers Node base class (statically safe but limits usage)
@onready var player_node_inferred := $Player  

func _physics_process(_delta: float) -> void:
	# 3. Fails: "Method 'move_and_slide' not found in base 'Node'."
	# player_node_inferred.move_and_slide()

	# 4. Fails: untyped_declaration error under strict settings
	var player_dynamic = $Player
	player_dynamic.move_and_slide()
```

## 5. Performance Benefits of Static Typing

Leverage static typing to bypass dynamic dispatch and enable optimized GDScript bytecode execution.
- **Reason:** In Godot 4, statically typed variables and parameters allow the GDScript compiler to generate direct VM instructions. This avoids costly hash-map lookups for method/property resolution, resulting in 2-3x execution speedups, especially in loops and physics logic.

```gdscript
# Good
extends Node


# Strict types allow direct, optimized method calls and arithmetic operations in the VM
func process_points(points: PackedVector2Array) -> float:
	var total_distance: float = 0.0
	for i: int in range(points.size() - 1):
		total_distance += points[i].distance_to(points[i + 1])
	return total_distance
```

```gdscript
# Bad
extends Node

# Untyped elements in generic Array force dynamic lookup overhead
func process_points(points: Array) -> float:
	var total_distance: float = 0.0
	for i in range(points.size() - 1):
		# Unsafe method access (distance_to) on untyped elements
		total_distance += points[i].distance_to(points[i + 1])
	return total_distance
```

## 6. Resolving Warning-as-Errors and Casting Safely

When project settings enforce strict code quality, downcasting base classes to specific types will trigger `unsafe_cast` warnings. Address these warnings using localized `@warning_ignore("unsafe_cast")` annotations only after validating the type with an explicit runtime check.
- **Reason:** In strict projects, downcasting triggers compile-time `unsafe_cast` errors, creating a deadlock when casting generic API parameters (e.g., `body: Node` in signal callbacks). To resolve this safely, perform a runtime type check using the `is` operator, and then apply a localized `@warning_ignore("unsafe_cast")` annotation to proceed with the cast. Unconditional warning suppression without a runtime type check is strictly prohibited.

```gdscript
# Good
extends Area2D


# Strategy 1: Localized warning suppression after explicit runtime type check
# Note: Statement-level @warning_ignore annotations require Godot 4.2+
func _on_body_entered(body: Node) -> void:
	if body is Enemy:
		@warning_ignore("unsafe_cast")
		var enemy := body as Enemy  # Safe downcast verified by runtime 'is' check
		enemy.take_damage(10)


# Strategy 2: Polymorphism using a typed base class/interface parent
# Note: Statement-level @warning_ignore annotations require Godot 4.2+
func _on_body_entered_poly(body: Node) -> void:
	if body is Damageable:
		@warning_ignore("unsafe_cast")
		var damageable := body as Damageable
		damageable.take_damage(10)
```

```gdscript
# Bad
extends Area2D

# 1. Direct unsafe cast triggering unsafe_cast warning (blocks compilation)
func _on_body_entered(body: Node) -> void:
	var enemy := body as Enemy  # Warning: unsafe_cast
	if enemy:
		enemy.take_damage(10)

# 2. Bypassing warnings using inline suppression without runtime validation (PROHIBITED)
func _on_body_entered_bypass(body: Node) -> void:
	@warning_ignore("unsafe_cast")
	var enemy := body as Enemy  # Suppressed warning without performing safety 'is' check first
	if enemy:
		enemy.take_damage(10)
```

> **Note:** Statement-level `@warning_ignore` annotations (placed directly above variables or statements within a function rather than at the function or class level) require Godot 4.2+.
