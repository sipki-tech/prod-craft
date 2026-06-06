# Unit Testing in Godot

Standards and best practices for writing isolated unit tests in Godot 4 using GUT and GdUnit4. This guide covers framework selection, naming conventions, assertion hygiene, testability, and test directory structure.

## 1. Framework Selection
- **Reason:** GUT (Godot Unit Test) is written in pure GDScript, runs as an addon, and is simple to configure. GdUnit4 offers a fluent API, runner-level parallelization, and robust memory leak tracking, but adds complexity and external plugin dependencies. Selecting the right tool ensures tests remain fast, maintainable, and aligned with project scale.

```gdscript
# Good
extends GutTest

func test_add_numbers() -> void:
	var calc := Calculator.new()
	assert_eq(calc.add(2, 3), 5, "Should add correctly")

# Good
# extends GdUnitTestSuite
# func test_add_numbers() -> void:
#	var calc := Calculator.new()
#	assert_int(calc.add(2, 3)).is_equal(5)

# Bad
extends GutTest

func test_add_numbers() -> void:
	var calc := Calculator.new()
	var result: int = calc.add(2, 3)
	if result != 5: # Silent comparison without proper assertions
		fail_test("Calculations failed")
```

## 2. Test File Naming
- **Reason:** Test runners (both GUT and GdUnit4) rely on standard wildcards like `test_*.gd` to locate and execute test cases headlessly. Directory mirroring makes it trivial to locate the corresponding test for any given source file and keeps the project organized.

```gdscript
# Good
# Test file is res://tests/core/test_calculator.gd
# File: res://tests/core/test_calculator.gd
extends GutTest

func test_calculator_initialization() -> void:
	var calc := Calculator.new()
	assert_not_null(calc, "Calculator instance should not be null")

# Bad
# File: res://src/core/calculator_test.gd
extends GutTest

func test_calculator() -> void:
	var calc := Calculator.new()
	assert_not_null(calc)
```

## 3. Logic Decoupling
- **Reason:** Scripts that inherit from Node require scene tree instantiation to be tested, which makes unit testing slow and error-prone. Extracting logic into pure `RefCounted` or `Resource` classes allows instant, headless unit testing without a SceneTree.

```gdscript
# Good
# File: res://src/combat/damage_calculator.gd
extends RefCounted
class_name DamageCalculator


func calculate_damage(base_damage: int, defense: int) -> int:
	return max(1, base_damage - defense)


# File: res://tests/combat/test_damage_calculator.gd
extends GutTest


func test_damage_calculation() -> void:
	var calc := DamageCalculator.new()
	assert_eq(calc.calculate_damage(10, 3), 7, "Damage calculation should account for defense")

# Bad
# File: res://src/combat/combatant.gd
extends Node2D
class_name Combatant

@export var base_damage := 10
@export var defense := 3
var health := 100

func _ready() -> void:
	# Hard to test because it relies on Node2D lifecycle and scene tree setup
	take_damage(base_damage)

func take_damage(damage: int) -> void:
	var final_damage := max(1, damage - defense)
	health -= final_damage
```

## 4. Explicit Typed Assertions
- **Reason:** GDScript 2.0 enforces strict type safety; writing untyped or loosely-typed tests can mask type mismatches in the production code or cause tests to fail silently or cryptically at runtime. Descriptive messages help debug CI failures quickly.

```gdscript
# Good
extends GutTest

func test_player_health_heal() -> void:
	var player := Player.new()
	player.health = 50
	player.heal(25)
	var expected_health: int = 75
	assert_eq(player.health, expected_health, "Player health should increase to 75 after healing 25")

# Bad
extends GutTest

func test_player_health_heal() -> void:
	var player := Player.new()
	player.health = 50
	player.heal(25)
	assert_eq(player.health, 75) # No failure context, untyped variables
```

## 5. No Test class_name
- **Reason:** Declaring a `class_name` registers the class globally in Godot's class search. Since tests are only run during development and CI, having global names for test suites pollutes autocomplete, increases editor initialization time, and introduces potential naming conflicts.

```gdscript
# Good
# File: res://tests/core/test_calculator.gd
extends GutTest

func test_calculation() -> void:
	pass

# Bad
# File: res://tests/core/test_calculator.gd
extends GutTest
class_name TestCalculator # Pollutes global namespace and editor search

func test_calculation() -> void:
	pass
```

## 6. Deterministic Tests
- **Reason:** Tests must produce identical results across runs and systems. Using unseeded RNG or waiting for real-world execution time (e.g. system clock) makes tests non-deterministic and leads to flaky CI pipelines.

```gdscript
# Good
extends GutTest

func test_critical_hit_with_seed() -> void:
	var roller := RandomRoller.new()
	# Seed the generator to guarantee deterministic outcomes
	roller.rng.seed = 12345
	
	# Assuming a seed of 12345 results in a critical hit
	assert_true(roller.roll_crit(0.1), "Crit roll should succeed deterministically with seed 12345")

# Bad
extends GutTest

func test_critical_hit_flaky() -> void:
	var roller := RandomRoller.new()
	# No seed means this test succeeds or fails randomly on every run
	assert_true(roller.roll_crit(0.1))
```
