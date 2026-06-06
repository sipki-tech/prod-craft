# Scene Design Patterns

Structuring shallow scene trees, managing dependency injection at the scene root, and establishing internal scene wiring.

## 1. Flat Scene Hierarchies
Maintain flat, shallow scene hierarchies and delegate nested layout blocks to sub-scenes.
- **Reason:** Deeply nested scene trees increase processing overhead and make nodes difficult to locate or refactor. Delegating complex sub-hierarchies to dedicated sub-scenes creates logical boundaries and ensures components are individually testable and reusable.

```gdscript
# Good
# character_hud.gd
class_name CharacterHUD extends CanvasLayer

@onready var status_bar: StatusBar = %StatusBar as StatusBar

@onready var inventory_panel: InventoryPanel = %InventoryPanel as InventoryPanel


func update_display(health: float, items: Array[String]) -> void:
	if status_bar:
		status_bar.set_health(health)
	if inventory_panel:
		inventory_panel.display_items(items)
```

```gdscript
# Bad
# character_hud.gd
class_name BadCharacterHUD extends CanvasLayer

func update_display(health: float, _items: Array[String]) -> void:
	# Accessing deeply nested nodes inside the parent class violates separation of concerns
	# and breaks if any sub-container is modified
	var health_bar := $Layout/Container/LeftPanel/BarContainer/HealthProgress as ProgressBar
	if health_bar:
		health_bar.value = health
```

## 2. Inject Dependencies at Initialization
Inject external runtime dependencies into nodes during initialization rather than letting children pull or query them.
- **Reason:** Searching the scene tree using absolute paths (e.g. `get_node("/root/...")`) or traversing parent nodes couples a script directly to its runtime parent hierarchy. Injecting dependencies during setup keeps the script reusable in different levels, systems, or test benches.

```gdscript
# Good
# enemy_spawner.gd
class_name EnemySpawner extends Node2D

@export var level_boundary: CollisionShape2D


func initialize(boundary: CollisionShape2D) -> void:
	level_boundary = boundary


func _ready() -> void:
	assert(level_boundary != null, "Level boundary must be injected before ready!")
```

```gdscript
# Bad
# enemy_spawner.gd
class_name BadEnemySpawner extends Node2D

var level_boundary: CollisionShape2D

func _ready() -> void:
	# Traverses hierarchy looking for specific node names, breaking portability and scene isolation
	level_boundary = get_node("/root/World/LevelLayout/LevelBoundary") as CollisionShape2D
```

## 3. Validate @export Dependencies with @tool
Use `@tool` scripts to warn designers when required `@export` properties are unset.
- **Reason:** Missing exports are silent until runtime, where they cause null-reference crashes. A `@tool` script with `_get_configuration_warnings()` surfaces problems as yellow triangles in the editor scene tree, catching errors before anyone presses Play.

```gdscript
# Good
@tool
class_name Checkpoint extends Area2D

@export var respawn_point: Marker2D


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if respawn_point == null:
		warnings.append("Respawn Point must be assigned in the Inspector.")
	return warnings
```

```gdscript
# Bad
class_name BadCheckpoint extends Area2D

@export var respawn_point: Marker2D

func _ready() -> void:
	# Crash only discovered at runtime when a player hits the checkpoint
	respawn_point.global_position
```

## 4. One Script per Scene Root
Attach a single coordinating script to the scene root; delegate distinct behaviors to child component scripts.
- **Reason:** Multiple scripts on the root or scattered logic across arbitrary child nodes make it unclear where behavior lives. A single root script acts as the public API of the scene, forwarding work to focused child components that each own one responsibility.

```gdscript
# Good
# player.gd — single root script coordinates children
class_name Player extends CharacterBody2D

@onready var health: HealthComponent = $HealthComponent
@onready var weapon: Weapon = $Weapon


func _ready() -> void:
	health.health_depleted.connect(_on_death)


func _on_death() -> void:
	queue_free()
```

```gdscript
# Bad
# player.gd — root script duplicates child responsibility
class_name BadPlayer extends CharacterBody2D

var current_health: int = 100
var ammo: int = 30

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		queue_free()

# Logic that belongs in a Weapon component is mixed into the root,
# making it impossible to reuse or test independently.
func fire() -> void:
	ammo -= 1
```
