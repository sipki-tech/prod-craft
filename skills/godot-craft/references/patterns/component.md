# Component Pattern

Building decoupled gameplay behaviors using independent component nodes and clean static APIs.

## 1. Signal-Based Communication
Components communicate with their owner through signals or generic interfaces, never by accessing owner internals.
- **Reason:** If a component queries arbitrary fields on the owner or expects a specific owner class, it cannot be reused on other node types. Interacting through signals or generic interfaces keeps the component modular.

```gdscript
# Good
# health_component.gd
class_name HealthComponent extends Node

signal health_changed(new_health: float)

signal health_depleted()

@export var max_health: float = 100.0

@onready var current_health: float = max_health


func take_damage(amount: float) -> void:
	current_health = clamp(current_health - amount, 0.0, max_health)
	health_changed.emit(current_health)
	if current_health <= 0.0:
		health_depleted.emit()
```

```gdscript
# Bad
# health_component.gd
class_name BadHealthComponent extends Node

func take_damage(amount: float) -> void:
	var parent := get_parent() as Node
	if parent:
		# Directly modifies parent variables and forces parent to have specific fields
		parent.set("health", parent.get("health") - amount)
		if parent.get("health") <= 0:
			parent.call("die")
```

## 2. Inspector References
Set inter-component dependencies via @export in the Inspector rather than run-time tree traversal.
- **Reason:** Finding sibling components using string-based paths (e.g. `get_node("../HitboxComponent")`) breaks if nodes are renamed or reorganized. Exporting variables allows dependencies to be set visually in the editor.

```gdscript
# Good
# hitbox_component.gd
class_name HitboxComponent extends Area2D

@export var health_component: HealthComponent


func take_damage(amount: float) -> void:
	if health_component:
		health_component.take_damage(amount)
```

```gdscript
# Bad
# hitbox_component.gd
class_name BadHitboxComponent extends Area2D

func take_damage(amount: float) -> void:
	# Fragile relative traversal that breaks if nodes are reorganized
	var parent := get_parent() as Node
	if parent:
		var health := parent.get_node("HealthComponent") as HealthComponent
		if health:
			health.current_health -= amount
```

## 3. Single Responsibility
Keep one component to one job; split God-components that handle multiple unrelated concerns.
- **Reason:** A component that manages health, input, and animation together cannot be reused independently and becomes hard to debug. Smaller focused components compose freely across different entity types.

```gdscript
# Good
# Each component does exactly one thing and can be mixed into any entity
class_name MovementComponent extends Node

@export var speed: float = 200.0

var direction: Vector2 = Vector2.ZERO


func apply_movement(body: CharacterBody2D, delta: float) -> void:
	body.velocity = direction * speed
	body.move_and_slide()


# input_component.gd
class_name InputComponent extends Node

signal direction_changed(direction: Vector2)


func _process(_delta: float) -> void:
	var dir := Input.get_vector("left", "right", "up", "down")
	direction_changed.emit(dir)
```

```gdscript
# Bad
# God-component handling movement, input, and animation in one script
class_name BadPlayerComponent extends Node

@export var speed: float = 200.0

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody2D
	if not body:
		return
	# Input + movement + animation all tangled together
	var dir := Input.get_vector("left", "right", "up", "down")
	body.velocity = dir * speed
	body.move_and_slide()
	var sprite := body.get_node("Sprite2D") as Sprite2D
	if sprite:
		sprite.flip_h = dir.x < 0
```
