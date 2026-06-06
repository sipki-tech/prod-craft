# Integration and Scene Testing in Godot

Standards for testing multi-node scenes, user interface (UI) interactions, and signals in Godot 4. This guide focuses on SceneTree lifecycle management, yield/wait conditions, and proper cleanup to avoid leaks.

## 1. Node Cleanup Management
- **Reason:** Godot nodes added to the SceneTree will persist in memory if not explicitly removed and freed. GUT's `add_child_autofree()` automatically cleans up nodes at the end of the test. If manually instantiated, nodes must be cleaned up in the `after_each()` method. GdUnit4 uses `auto_free()` to track nodes and release them after test execution.

```gdscript
# Good
extends GutTest

func test_enemy_spawner_adds_child() -> void:
	var spawner_scene: PackedScene = load("res://src/combat/enemy_spawner.tscn")
	var spawner := spawner_scene.instantiate() as EnemySpawner
	
	# Adds to tree and registers for autofree
	add_child_autofree(spawner)
	
	spawner.spawn_enemy()
	assert_eq(spawner.get_child_count(), 1, "Should have spawned 1 enemy node")

# Good
# extends GdUnitTestSuite
# func test_enemy_spawner() -> void:
#	var spawner: EnemySpawner = auto_free(load("res://src/combat/enemy_spawner.tscn").instantiate()) as EnemySpawner
#	spawner.spawn_enemy()
#	assert_int(spawner.get_child_count()).is_equal(1)

# Bad
extends GutTest

func test_enemy_spawner_leaks() -> void:
	var spawner_scene: PackedScene = load("res://src/combat/enemy_spawner.tscn")
	var spawner := spawner_scene.instantiate() as EnemySpawner
	
	# Leaks spawner and all its children after the test runs
	get_tree().root.add_child(spawner)
	spawner.spawn_enemy()
	assert_eq(spawner.get_child_count(), 1)
```

## 2. Signal Assertion Watchers
- **Reason:** Built-in signal watching simplifies tests and ensures they are thread-safe and run cleanly without boilerplate connect/disconnect code that could leak references.

```gdscript
# Good
extends GutTest

func test_health_component_emits_died_signal() -> void:
	var health := HealthComponent.new()
	add_child_autofree(health)
	health.max_health = 100
	health.health = 10
	
	watch_signals(health)
	health.take_damage(20)
	
	assert_signal_emitted(health, "died", "Should emit 'died' signal when health reaches 0")
	assert_signal_emit_count(health, "died", 1)

# Good
# extends GdUnitTestSuite
# func test_health_component() -> void:
#	var health: HealthComponent = auto_free(HealthComponent.new()) as HealthComponent
#	var monitor := monitor_signals(health)
#	health.take_damage(100)
#	await assert_signal(health).is_emitted("died")

# Bad
extends GutTest

var _died_emitted := false

func _on_died() -> void:
	_died_emitted = true

func test_health_component_emits_died_manual() -> void:
	var health := HealthComponent.new()
	health.max_health = 100
	health.health = 10
	health.died.connect(_on_died) # High risk of leaving signal connected or leaking references
	
	health.take_damage(20)
	assert_true(_died_emitted)
	
	# Missing disconnect!
```

## 3. Input Event Simulation
- **Reason:** Directly emitting `button.pressed` or calling `_pressed()` bypasses node state checks (like `disabled`, `visible`, and focus) or parent control layout blocking (e.g. mouse filter). Simulating events via GUT's `InputSender` or `Input.parse_input_event()` executes the engine's standard event propagation pipeline, ensuring the UI behaves exactly as it would for a player.

```gdscript
# Good
extends GutTest

func test_menu_button_click_interaction() -> void:
	var menu_scene: PackedScene = load("res://src/ui/main_menu.tscn")
	var menu := menu_scene.instantiate() as MainMenu
	add_child_autofree(menu)
	
	var start_button: Button = menu.get_start_button()
	
	# Create input sender and execute click sequence
	var sender := InputSender.new(start_button)
	sender.mouse_left_button_down().wait("50ms").mouse_left_button_up()
	await sender.idle
	
	assert_true(menu.is_transitioning, "Menu should begin transition on physical click event")

# Bad
extends GutTest

func test_menu_button_click_fake() -> void:
	var menu_scene: PackedScene = load("res://src/ui/main_menu.tscn")
	var menu := menu_scene.instantiate() as MainMenu
	add_child_autofree(menu)
	
	var start_button: Button = menu.get_start_button()
	# Fails to verify if start_button is disabled or hidden by overlay control!
	start_button.pressed.emit()
	
	assert_true(menu.is_transitioning)
```

## 4. Frame Yield Waiting
- **Reason:** UI changes and scene transitions often require a process frame or physics frame to update their layouts, focus, or visual states. Directly asserting on values right after an event without yielding will cause false negatives due to deferred processing.

```gdscript
# Good
extends GutTest

func test_menu_button_transition() -> void:
	var menu_scene: PackedScene = load("res://src/ui/main_menu.tscn")
	var menu := menu_scene.instantiate() as MainMenu
	add_child_autofree(menu)
	
	var start_button: Button = menu.get_start_button()
	start_button.pressed.emit()
	
	# Yield a frame for UI transitions and state changes to run
	await wait_seconds(0.1)
	
	assert_true(menu.is_transitioning, "Menu should start transition after press")

# Bad
extends GutTest

func test_menu_button_transition_failed() -> void:
	var menu_scene: PackedScene = load("res://src/ui/main_menu.tscn")
	var menu := menu_scene.instantiate() as MainMenu
	add_child_autofree(menu)
	
	var start_button: Button = menu.get_start_button() as Button
	start_button.pressed.emit()
	
	# Fails because UI state hasn't updated in this frame
	assert_true(menu.is_transitioning)
```

## 5. Teardown State Reset
- **Reason:** Autoloads and global singletons persist in memory across the entire test runner execution. Unclean state from a previous test can leak into subsequent tests, causing unexpected dependencies and flaky test results.

```gdscript
# Good
extends GutTest


func after_each() -> void:
	# Reset global configuration
	GameConfig.reset_to_defaults()
	# Clear active players
	PlayerManager.clear_players()


func test_first_run_config() -> void:
	GameConfig.set_value("volume", 0.5)
	assert_eq(GameConfig.get_value("volume"), 0.5, "Should set config volume correctly")

# Bad
extends GutTest

func test_first_run_config_dirty() -> void:
	GameConfig.set_value("volume", 0.5)
	assert_eq(GameConfig.get_value("volume"), 0.5)
	# If next test relies on volume default (e.g. 1.0), it will fail!
```
