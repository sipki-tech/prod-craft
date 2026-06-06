# Scene Composition

Designing scenes using composition over inheritance, ensuring modular development and independent testability.

## 1. Prefer Composition Over Inheritance
Extend entity behaviors by composing scenes and nodes instead of deep class hierarchies.
- **Reason:** Deep class inheritance creates rigid coupling and fragile code dependencies, making classes hard to test and maintain. Composition breaks behavior into self-contained nodes that can be combined dynamically and reused across entirely different entity types.

```gdscript
# Good
# health_component.gd
class_name HealthComponent extends Node

signal health_changed(new_health: int)

signal health_depleted()

@export var max_health: int = 100

@onready var current_health: int = max_health


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health)
	if current_health <= 0:
		health_depleted.emit()

# enemy.gd
class_name Enemy extends CharacterBody2D

@onready var health_component: HealthComponent = $HealthComponent


func _ready() -> void:
	health_component.health_depleted.connect(_on_death)


func _on_death() -> void:
	queue_free()
```

```gdscript
# Bad
# actor.gd
class_name Actor extends CharacterBody2D

var health: int = 100

func take_damage(amount: int) -> void:
	health -= amount

# enemy.gd
class_name BadEnemy extends Actor

func _physics_process(_delta: float) -> void:
	# Enemy inherits all code from Actor directly, coupling physics movement and health logic
	if health <= 0:
		queue_free()
```

## 2. Self-Contained Scenes
Ensure every scene is independently runnable by resolving or injecting dependencies.
- **Reason:** Scenes that assume their location in the main tree or rely on direct access to parent nodes will crash when run on their own in the editor or when instantiated by tests. Decoupling dependencies through root-level exports or standard initialization methods ensures scenes are robust and easily testable.

```gdscript
# Good
# enemy_ui.gd
class_name EnemyUI extends Control

@export var health_component: HealthComponent


func _ready() -> void:
	if health_component:
		health_component.health_changed.connect(_on_health_changed)


func _on_health_changed(new_health: int) -> void:
	var progress_bar := $ProgressBar as ProgressBar
	if progress_bar:
		progress_bar.value = new_health
```

```gdscript
# Bad
# enemy_ui.gd
class_name BadEnemyUI extends Control

func _ready() -> void:
	# Violates independent runnability by assuming a rigid parent structure
	var parent_enemy := get_parent() as CharacterBody2D
	if parent_enemy:
		var health_comp := parent_enemy.get_node("HealthComponent") as HealthComponent
		if health_comp:
			health_comp.health_changed.connect(_on_health_changed)

func _on_health_changed(new_health: int) -> void:
	var progress_bar := $ProgressBar as ProgressBar
	if progress_bar:
		progress_bar.value = new_health
```
