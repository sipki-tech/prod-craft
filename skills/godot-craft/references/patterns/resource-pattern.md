# Custom Resource Architecture

Utilizing custom Resource classes for data containment, configuration sharing, and strategy patterns.

## 1. Separate Config from Code
Use custom Resource definitions to isolate static configuration data from runtime script logic.
- **Reason:** Hardcoding configuration values inside scripts forces developers to modify code to adjust gameplay balance. Custom resources allow configuration to be saved as `.tres` files, edited visually in the Inspector, and shared across many node instances.

```gdscript
# Good
# item_data.gd
class_name ItemData extends Resource

@export var display_name: String = "Sword"

@export var damage: int = 10

@export var gold_value: int = 50

# inventory_slot.gd
class_name InventorySlot extends Node

@export var item: ItemData
```

```gdscript
# Bad
# item.gd
class_name BadItem extends Node

# Static stats inside entity scripts cause duplication and prevent visual editing
@export var display_name: String = "Sword"
@export var damage: int = 10
@export var gold_value: int = 50
```

## 2. Duplicate Mutable Resources
Clone custom resources at runtime if any of their fields will be modified.
- **Reason:** Godot shares Resource instances in memory by default. If an entity mutates a value on its assigned resource, that change affects all other entities sharing the same resource file. Duplicating at runtime gives each entity a private copy.

```gdscript
# Good
# weapon.gd
class_name Weapon extends Node2D

@export var base_data: WeaponData

var runtime_data: WeaponData


func _ready() -> void:
	if base_data:
		# Duplicate to ensure local mutation doesn't affect other instances
		runtime_data = base_data.duplicate() as WeaponData


func fire() -> void:
	if runtime_data and runtime_data.ammo_capacity > 0:
		runtime_data.ammo_capacity -= 1
```

```gdscript
# Bad
# weapon.gd
class_name BadWeapon extends Node2D

@export var weapon_data: WeaponData

func fire() -> void:
	if weapon_data and weapon_data.ammo_capacity > 0:
		# Modifying shared resource affects ALL weapons using this file!
		weapon_data.ammo_capacity -= 1
```

## 3. Resource Strategy Pattern
Use `@export` Resource subclasses for pluggable behaviors (Strategy pattern) instead of deep inheritance trees.
- **Reason:** Creating a class hierarchy for every behavior variant (e.g. `FastEnemy`, `SlowEnemy`, `FlyingEnemy`) causes combinatorial explosion. Exporting a base Resource type lets designers swap behaviors in the Inspector without touching code.

```gdscript
# Good
# movement_strategy.gd
class_name MovementStrategy extends Resource

func move(body: CharacterBody2D, _delta: float) -> void:
	push_error("MovementStrategy.move() must be overridden")

# walk_strategy.gd
class_name WalkStrategy extends MovementStrategy

@export var walk_speed: float = 100.0

func move(body: CharacterBody2D, _delta: float) -> void:
	body.velocity.x = walk_speed
	body.move_and_slide()

# enemy.gd
class_name Enemy extends CharacterBody2D

@export var movement: MovementStrategy

func _physics_process(delta: float) -> void:
	if movement:
		movement.move(self, delta)
```

```gdscript
# Bad
# Inheritance explosion — one subclass per variant
class_name WalkingEnemy extends CharacterBody2D

@export var walk_speed: float = 100.0

func _physics_process(_delta: float) -> void:
	velocity.x = walk_speed
	move_and_slide()

# flying_enemy.gd — duplicates most logic just to change movement
class_name FlyingEnemy extends CharacterBody2D

@export var fly_speed: float = 150.0

func _physics_process(_delta: float) -> void:
	velocity = Vector2(fly_speed, sin(Time.get_ticks_msec() * 0.005) * 50.0)
	move_and_slide()
```
