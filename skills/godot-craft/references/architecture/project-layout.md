# Project Layout & Structuring

Structuring projects with feature-oriented directory organizations and using stable node references.

## 1. Feature-Oriented Folders
Organize files into self-contained feature folders rather than grouping by technical type.
- **Reason:** Grouping assets, scripts, and scenes by feature isolates dependencies, allowing elements to be easily refactored, duplicated, or removed without breaking global paths. Placing related files together also reduces developer friction when navigating the codebase.

```gdscript
# Good
# File organization structure:
# res://src/player/player.tscn
# res://src/player/player.gd
# res://src/player/player_idle.png
# res://src/player/player_jump.wav

# In player_spawner.gd:
class_name PlayerSpawner extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")


func spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	if player:
		add_child(player)
```

```gdscript
# Bad
# File organization structure:
# res://scenes/player.tscn
# res://scripts/player.gd
# res://textures/player_idle.png

# In player_spawner.gd:
class_name BadPlayerSpawner extends Node2D

# Fragile, disorganized file path layout crossing multiple unrelated folders
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	if player:
		add_child(player)
```

## 2. Scene Unique Nodes (%)
Use Scene Unique Nodes instead of hardcoded relative NodePaths for references inside a scene.
- **Reason:** Hardcoded relative node paths break instantly whenever container hierarchies are nested, renamed, or rearranged in the editor. Scene Unique Nodes remain bound to the target node regardless of layout changes.

```gdscript
# Good
# inside settings_menu.gd
class_name SettingsMenu extends Control

@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	queue_free()
```

```gdscript
# Bad
# inside settings_menu.gd
class_name BadSettingsMenu extends Control

@onready var back_button: Button = $VBoxContainer/Panel/MarginContainer/HBoxContainer/BackButton

func _ready() -> void:
	# This path will crash if the panel or margin container is reorganized in the editor
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	queue_free()
```

## 3. Use .gdignore for Non-Game Directories
Place a `.gdignore` file in directories that the engine should not import.
- **Reason:** Godot's importer processes every file it finds in the project tree. Raw source assets (`.blend`, `.psd`), documentation folders, or CI scripts waste import time and pollute the FileSystem dock. A `.gdignore` file makes the directory and all its children invisible to the engine.

```gdscript
# Good
# Project root layout:
# res://src/             <- game code and assets
# res://docs/.gdignore   <- empty file; docs/ is hidden from the engine
# res://raw_assets/.gdignore  <- Blender/PSD sources excluded from import

# asset_loader.gd — only references imported resources
class_name AssetLoader extends RefCounted

static func load_sprite(path: String) -> Texture2D:
	return load(path) as Texture2D
```

```gdscript
# Bad
# Project root layout (no .gdignore):
# res://docs/design.pdf          <- imported needlessly, slows editor startup
# res://raw_assets/character.blend  <- triggers Blender importer on every scan
# res://ci/deploy.sh             <- visible in FileSystem dock, confuses artists

# All non-game files clutter the FileSystem dock and increase import times
# with no runtime benefit.
```
