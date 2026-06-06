# Platform-Specific Settings

This guide details the adjustments required for running games across desktop, mobile, and web targets, including feature tag switches, input scaling, and responsive design configs.

## Use Feature Tags for Platform-Specific Branching
Execute platform-specific optimizations, graphical presets, or directory paths using `OS.has_feature()` checks instead of querying platform names.
- **Reason:** Feature tags are built-in, standardized flags that match environments accurately across console, mobile, and web builds.

```gdscript
# Good
class_name GraphicsSettings
extends Node


func apply_platform_settings() -> void:
	if OS.has_feature("mobile"):
		# Set low shadow quality for mobile
		get_viewport().positional_shadow_atlas_size = 1024
	elif OS.has_feature("pc"):
		# Enable advanced shadow parameters for desktop
		get_viewport().positional_shadow_atlas_size = 4096
	
	if OS.has_feature("web"):
		# Disable heavy post processing on browsers
		var viewport := get_viewport()
		if viewport:
			viewport.use_debanding = false

# Bad
# Querying specific hardware OS name strings which are prone to change or failure
class_name FragileGraphicsSettings
extends Node

func apply_fragile_settings() -> void:
	var os_name := OS.get_name()
	if os_name == "Android" or os_name == "iOS": # Misses iPadOS or specific Android targets
		get_viewport().positional_shadow_atlas_size = 1024
```

## Wrap Native Platform SDKs behind Abstract Interface Classes
Decouple third-party platform integrations (such as Steamworks, Epic Games Store, or mobile store APIs) behind custom wrapper classes using composition. Use feature tags to load dummy or mock SDK classes on platforms that do not support them.
- **Reason:** Prevents project-wide crash and load failures when running scripts that import target platform binaries.

```gdscript
# Good
# Abstract platform interface wrapper (achievements_service.gd)
class_name PlatformAchievements
extends Node


static func get_instance() -> PlatformAchievements:
	if OS.has_feature("steam"):
		return load("res://addons/steam/steam_achievements.gd").new() as PlatformAchievements
	else:
		return load("res://addons/dummy_achievements.gd").new() as PlatformAchievements


func unlock_achievement(_id: String) -> void:
	pass

# Inside res://addons/steam/steam_achievements.gd:
# class_name SteamAchievements
# extends PlatformAchievements
#
# func unlock_achievement(id: String) -> void:
# 	# Access the Steam singleton dynamically to avoid compilation crash on platforms without GodotSteam
# 	var steam: Object = Engine.get_singleton("Steam")
# 	if steam:
# 		steam.call("setAchievement", id)

# Bad
# Calling platform-specific singletons statically, causing compile errors on unsupported platforms
class_name BadAchievementTrigger
extends Node

func on_level_complete() -> void:
	# Steam is a global class/singleton. Accessing it statically causes parsing/compilation crashes on non-Steam builds.
	Steam.setAchievement("LEVEL_COMPLETE") 
```

## Dynamically Configure UI Offsets using Safe Area Guidelines
On mobile devices, dynamically read the hardware display boundaries using `DisplayServer.get_display_safe_area()` and offset the interactive user interface nodes using anchors or margin offsets.
- **Reason:** Ignoring safe boundaries results in HUD buttons or interactive elements being cut off by notch indicators or curved screen edges.

```gdscript
# Good
class_name ResponsiveUI
extends Control

@onready var main_container: MarginContainer = %MainMarginContainer


func _ready() -> void:
	adjust_ui_margins()
	get_viewport().size_changed.connect(adjust_ui_margins)


func adjust_ui_margins() -> void:
	# Get the hardware-safe screen boundaries in screen space
	var safe_area := DisplayServer.get_display_safe_area()
	var screen_size := DisplayServer.screen_get_size()
	var viewport_size := get_viewport().get_visible_rect().size
	
	if screen_size.x == 0 or screen_size.y == 0:
		return
		
	# Scale the safe area margins by the ratio of viewport size to screen size
	var scale_factor := Vector2(viewport_size) / Vector2(screen_size)
	var top := int(safe_area.position.y * scale_factor.y)
	var left := int(safe_area.position.x * scale_factor.x)
	var bottom := int((screen_size.y - safe_area.end.y) * scale_factor.y)
	var right := int((screen_size.x - safe_area.end.x) * scale_factor.x)
	
	main_container.add_theme_constant_override("margin_top", top)
	main_container.add_theme_constant_override("margin_left", left)
	main_container.add_theme_constant_override("margin_bottom", bottom)
	main_container.add_theme_constant_override("margin_right", right)

# Bad
# Hardcoding UI offsets or positions based on assumed default resolution
class_name RigidUI
extends Control

@onready var action_button: Button = %ActionButton

func _ready() -> void:
	# Hardcoding absolute position; fails to adapt to notch or safe areas
	action_button.position = Vector2(20.0, 20.0)
```
