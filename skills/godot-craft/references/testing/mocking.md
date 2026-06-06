# Mocking and Doubling in Godot

Guidelines for mocking, stubbing, and spying in Godot 4. This document details how to use GUT's doubling system to isolate dependencies, mock Autoloads (Singletons), double Resources, and decide when to use mocks.

## 1. Framework Test Doubles
- **Reason:** Testing frameworks dynamically generate typed test doubles, allowing you to stub return values and spy on method calls with minimal boilerplate. Custom mock implementations are tedious to write, error-prone, and fall out of sync with real APIs when production code changes.

```gdscript
# Good
extends GutTest

func test_inventory_item_add() -> void:
	# Double the Logger dependency
	var mock_logger: Logger = double(Logger).new()
	stub(mock_logger, "log_info").to_return(null)
	
	var inventory := Inventory.new(mock_logger)
	inventory.add_item("sword")
	
	assert_called(mock_logger, "log_info", ["Added item: sword"])

# Good
# extends GdUnitTestSuite
# func test_inventory_item_add() -> void:
#	var mock_logger: Logger = mock(Logger) as Logger
#	do_return(null).on(mock_logger).log_info("Added item: sword")
#	var inventory: Inventory = Inventory.new(mock_logger) as Inventory
#	inventory.add_item("sword")
#	verify(mock_logger, times(1)).log_info("Added item: sword")

# Bad
extends GutTest

class MockLogger extends RefCounted:
	var called_with: Array[String] = []
	func log_info(msg: String) -> void:
		called_with.append(msg)

func test_inventory_item_add() -> void:
	var mock_logger := MockLogger.new()
	var inventory := Inventory.new(mock_logger)
	inventory.add_item("sword")
	assert_eq(mock_logger.called_with[0], "Added item: sword")
```

## 2. Injectable Autoloads
- **Reason:** Autoloads are globally accessible, which tightly couples scripts to global state. Swapping Autoloads out during testing or injecting them via public properties ensures tests can run in isolation without side effects affecting subsequent test cases.

```gdscript
# Good
# File: res://src/ui/button_clicker.gd
extends Button
class_name ButtonClicker

# Injectable property, defaults to global Autoload in production
var audio_service: AudioService = AudioManager


func _pressed() -> void:
	audio_service.play_sound("click")


# File: res://tests/ui/test_button_clicker.gd
extends GutTest


func test_button_clicks_play_sound() -> void:
	var mock_audio: AudioService = double(AudioService).new()
	stub(mock_audio, "play_sound").to_return(null)
	
	var button := ButtonClicker.new()
	button.audio_service = mock_audio
	button._pressed()
	
	assert_called(mock_audio, "play_sound", ["click"])

# Bad
# File: res://src/ui/button_clicker.gd
extends Button

func _pressed() -> void:
	AudioManager.play_sound("click") # Hard dependency on Autoload
```

## 3. Transient Resource Instances
- **Reason:** Custom Resources hold configuration and game data. Doubling them or passing transient instances in-memory avoids disk I/O overhead and prevents tests from failing when external asset files are modified or moved.

```gdscript
# Good
extends GutTest

func test_item_database_lookup() -> void:
	var test_item := ItemData.new()
	test_item.id = "sword"
	test_item.damage = 15
	
	var db := ItemDatabase.new()
	db.register_item(test_item)
	
	assert_eq(db.get_damage("sword"), 15, "Database should register and retrieve transient item damage")

# Bad
extends GutTest

func test_item_database_lookup() -> void:
	# Fragile: if sword.tres is deleted, renamed, or modified, this test breaks
	var test_item: ItemData = load("res://data/items/sword.tres")
	var db := ItemDatabase.new()
	db.register_item(test_item)
	assert_eq(db.get_damage("sword"), 15)
```

## 4. Path-Based Doubling
- **Reason:** GUT's `double()` function requires a class name or a path string. If a script does not define a global `class_name` (to avoid namespace pollution), you must pass its project-relative resource path to compile the double correctly. Passing the raw script variable will crash the double generator.

```gdscript
# Good
extends GutTest

func test_damage_modifier() -> void:
	# Double via script path
	var mock_modifier: RefCounted = double("res://src/combat/damage_modifier.gd").new() as RefCounted
	stub(mock_modifier, "get_multiplier").to_return(1.5)
	
	var combat := CombatEngine.new(mock_modifier)
	assert_eq(combat.process_damage(10), 15, "CombatEngine should apply the mock modifier multiplier")

# Bad
extends GutTest

const ModifierScript := preload("res://src/combat/damage_modifier.gd")

func test_damage_modifier_fail() -> void:
	# This will throw a runtime error in GUT because the script has no global class name identifier
	var mock_modifier: RefCounted = double(ModifierScript).new() as RefCounted
	assert_not_null(mock_modifier)
```

## 5. Boundary-Only Mocking
- **Reason:** Over-mocking leads to brittle tests that verify the mock configuration rather than the system's behavior. Mocking should be reserved for boundaries where real execution is slow, has side effects, or is non-deterministic.

```gdscript
# Good
extends GutTest

func test_fetch_user_profile() -> void:
	var mock_client: APIClient = double(APIClient).new()
	stub(mock_client, "request_user_data").to_return({"name": "Gamer123"})
	
	var manager := ProfileManager.new(mock_client)
	var profile := manager.get_profile(42)
	
	assert_eq(profile.username, "Gamer123", "Profile username should match stubbed API response")

# Bad
extends GutTest

func test_vector_addition() -> void:
	# Brittle and unnecessary: just use Vector2 directly!
	var mock_vec: Vector2 = double(Vector2).new() # Errors out; built-in types cannot be doubled
```
