# Export Optimization and File Sizes

This guide covers rules for creating minimal engine builds via custom compilation options, asset pipeline configurations, package size reduction, and memory orphan management.

## Strip Unused Engine Modules via Custom Export Templates
For release builds, compile Godot templates from source using SCons with a custom build profile (`custom.py`) that disables unused core modules (e.g., 3D engine for 2D games, unused decoders, or advanced physics modules).
- **Reason:** A default Godot export template includes all modules, bloating build files and loading times, which is critical for web (HTML5) targets.

```python
# Good
# custom.py - SCons configuration file to exclude unused systems (Godot 4)
module_mono_enabled = "no"
disable_3d = "yes"
module_navigation_enabled = "no"
module_minimp3_enabled = "no"
module_webm_enabled = "no"
module_noise_enabled = "no"

# Bad
# custom.py - SCons configuration leaving unused modules enabled (bloated engine binary)
module_mono_enabled = "yes"
disable_3d = "no"
module_navigation_enabled = "yes"
module_noise_enabled = "yes"
```

## Filter Out Raw Assets and Exclude Source Files from PCKs
Configure the file filters in `export_presets.cfg` to target compiled and imported assets exclusively. Explicitly exclude source files (such as `.psd`, `.blend`, `.ase`, `.wav` raw sources, or documentation files).
- **Reason:** Raw asset files are duplicated alongside their `.import` equivalents inside the final PCK, drastically bloating package dimensions.

```ini
# Good
# Config entry in export_presets.cfg targeting only imported assets
[preset.0]
name="Web Release"
platform="Web"
runnable=true
custom_features=""
export_filter="all_resources"
exclude_filter="*.psd, *.blend, *.ase, *.txt, *.md, *.git*, .agents/*"

# Bad
# Config entry in export_presets.cfg with no exclusion filters (bloated package)
[preset.0]
name="Web Release"
platform="Web"
runnable=true
custom_features=""
export_filter="all_resources"
exclude_filter=""
```

## Cleanly Dispose of Dynamic Nodes to Prevent Orphan Leaks
Ensure that dynamically instantiated nodes (such as temporary UI components, impact particles, or projectile instances) are explicitly freed using `queue_free()` and removed from the active tree.
- **Reason:** Godot leaves nodes orphaned in memory if they are dereferenced but not freed, resulting in leaks that degrade frame rates and cause crashes during long play sessions.

```gdscript
# Good
# Node clearing which guarantees memory release
class_name Projectile
extends Area2D


func _ready() -> void:
	# Setup auto-cleanup timer
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func() -> void:
		queue_free()
	)


func on_impact() -> void:
	# Perform hit effects...
	queue_free()

# Bad
# Simply removing node from parent without freeing it from memory
class_name LeakingProjectile
extends Area2D

func on_impact_leak() -> void:
	var parent := get_parent()
	if parent:
		parent.remove_child(self) # Still exists in memory as an orphan!
```
