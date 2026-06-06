# Signal Coordination

Coordinating node communication via "Call Down, Signal Up" to ensure clean separation of concerns and type safety.

## 1. Call Down, Signal Up
Adhere strictly to the "Call Down, Signal Up" principle for scene node communication.
- **Reason:** Parent nodes can safely know about and invoke methods on their direct children because they manage their lifecycle. However, child nodes must never call methods or access properties of their parents directly; instead, they emit signals to notify parents of events, decoupling the child node.

```gdscript
# Good
# weapon.gd
class_name Weapon extends Node2D

signal weapon_fired(remaining_ammo: int)

@export var ammo_capacity: int = 30

@onready var current_ammo: int = ammo_capacity


func fire() -> void:
	if current_ammo > 0:
		current_ammo -= 1
		weapon_fired.emit(current_ammo)
```

```gdscript
# Bad
# weapon.gd
class_name BadWeapon extends Node2D

func fire() -> void:
	# Fragile direct coupling: child assumes parent type and details
	var player := get_parent() as CharacterBody2D
	if player:
		player.ammo_count -= 1
		player.update_hud_display()
```

## 2. Callable-Based Connections
Connect signals using Callable-based syntax rather than string-based names.
- **Reason:** Callable connections are checked by the compiler and parser, enabling syntax highlighting, autocomplete, and static analysis errors for mismatched method names. String-based connections defer failures to runtime and fail silently if target methods are renamed.

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
class_name BadLevel extends Node2D

func _ready() -> void:
	# Typeless string connections fail silently at runtime and bypass compiler checks
	var player := $Player as Node
	if player:
		player.connect("health_depleted", Callable(self, "_on_player_death"))

func _on_player_death() -> void:
	var _result := get_tree().reload_current_scene()
```

## 3. Avoid Signal Chains Longer Than Two Nodes
Use a global event bus Autoload instead of re-emitting signals through intermediate nodes.
- **Reason:** Signal bubbling — where a child emits to a parent, who re-emits to their parent — creates tight coupling to the scene tree structure. Moving or rearranging nodes breaks the chain. A lightweight event bus decouples distant nodes entirely.

```gdscript
# Good
# game_events.gd (Autoloaded as GameEvents)
extends Node

signal player_scored(points: int)

# coin.gd
class_name Coin extends Area2D

func _on_body_entered(_body: Node2D) -> void:
	GameEvents.player_scored.emit(10)
	queue_free()

# hud.gd — connects directly to the bus, no intermediaries
class_name HUD extends CanvasLayer

func _ready() -> void:
	GameEvents.player_scored.connect(_on_player_scored)

func _on_player_scored(points: int) -> void:
	%ScoreLabel.text = str(points)
```

```gdscript
# Bad
# coin.gd — bubbles signal through every parent
class_name BadCoin extends Area2D

signal coin_collected(points: int)

func _on_body_entered(_body: Node2D) -> void:
	coin_collected.emit(10)
	queue_free()

# level.gd — acts as unnecessary relay
class_name BadLevel extends Node2D

signal score_updated(points: int)

func _ready() -> void:
	for coin: Node in get_children():
		if coin.has_signal("coin_collected"):
			coin.coin_collected.connect(_relay_score)

func _relay_score(points: int) -> void:
	score_updated.emit(points)
```
