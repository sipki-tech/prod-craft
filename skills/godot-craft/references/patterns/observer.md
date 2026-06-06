# Observer Pattern

Implementing decoupled event systems using localized observers and managing signal lifecycles cleanly.

## 1. Local vs Global Buses
Use local signals for sub-system coordination and global buses only for cross-cutting game-wide events.
- **Reason:** Directing all communication through a single massive global event bus introduces namespace clutter and makes isolating or testing sub-menus, widgets, or entities impossible. Keep local communication within a scene boundary.

```gdscript
# Good
# settings_menu.gd
class_name SettingsMenu extends Control

signal setting_toggled(setting_name: String, is_enabled: bool)


# setting_toggle.gd
class_name SettingToggle extends CheckButton

@export var setting_id: String = ""


func _on_toggled(button_pressed: bool) -> void:
	# Local parent is notified, keeping the module self-contained
	var menu := get_owner() as SettingsMenu
	if menu:
		menu.setting_toggled.emit(setting_id, button_pressed)
```

```gdscript
# Bad
# global_event_bus.gd (Autoloaded as GlobalEventBus)
extends Node
signal settings_menu_toggle_updated(id: String, state: bool)

# setting_toggle.gd
class_name BadSettingToggle extends CheckButton

@export var setting_id: String = ""

func _on_toggled(button_pressed: bool) -> void:
	# Global bus for local UI elements prevents clean scene testing
	GlobalEventBus.settings_menu_toggle_updated.emit(setting_id, button_pressed)
```

## 2. Dynamic Connection Cleanup
Always disconnect dynamic signal connections in `_exit_tree` to prevent memory leaks.
- **Reason:** Godot auto-cleans connections between scene-tree nodes when freed, but dynamic connections to persistent singletons (Autoloads) or resources will prevent garbage collection and cause leaks.

```gdscript
# Good
class_name ScoreWidget extends Label


func _ready() -> void:
	EventBus.score_updated.connect(_on_score_updated)


func _exit_tree() -> void:
	# Disconnect when exiting if bound to a persistent Autoload
	if EventBus.score_updated.is_connected(_on_score_updated):
		EventBus.score_updated.disconnect(_on_score_updated)


func _on_score_updated(new_score: int) -> void:
	text = "Score: " + str(new_score)
```

```gdscript
# Bad
class_name BadScoreWidget extends Label

func _ready() -> void:
	# Bound to persistent singleton without cleanup — leaks memory
	EventBus.score_updated.connect(_on_score_updated)

func _on_score_updated(new_score: int) -> void:
	text = "Score: " + str(new_score)
```

## 3. Await for One-Time Events
Use `await` for one-shot signal waits instead of `CONNECT_ONE_SHOT` flag callbacks.
- **Reason:** `await` keeps logic in a linear flow, preserves variable scope, and requires no manual cleanup. `CONNECT_ONE_SHOT` splits logic across callbacks and is error-prone when code paths grow complex.

```gdscript
# Good
func spawn_enemy(pos: Vector2) -> void:
	var enemy := preload("res://src/enemy.tscn").instantiate()
	add_child(enemy)
	enemy.global_position = pos
	# Linear flow — wait for death, then continue
	await enemy.tree_exited
	score += 1
```

```gdscript
# Bad
func spawn_enemy(pos: Vector2) -> void:
	var enemy := preload("res://src/enemy.tscn").instantiate()
	add_child(enemy)
	enemy.global_position = pos
	# One-shot flag splits logic into a separate callback
	enemy.tree_exited.connect(_on_enemy_died, CONNECT_ONE_SHOT)

func _on_enemy_died() -> void:
	score += 1
```
