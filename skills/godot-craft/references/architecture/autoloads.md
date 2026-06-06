# Autoload Boundaries

Restricting singletons to global cross-cutting services and using decoupled communication structures to prevent spaghetti dependencies.

## 1. Restrict Autoloads to Cross-Cutting Services
Only use Autoloads for global, cross-cutting services or stateless system event brokers.
- **Reason:** Overusing singletons creates global hidden state, making the codebase highly coupled and difficult to test. Game state, player inventory, or level coordination should be managed via dependency injection or passed down the scene tree rather than stored in global variables.

```gdscript
# Good
# audio_manager.gd (Autoloaded as AudioManager)
extends Node


func play_sfx(sound_stream: AudioStream) -> void:
	# Cross-cutting service that doesn't hold state of individual scenes
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = sound_stream
	player.play()
	player.finished.connect(player.queue_free)
```

```gdscript
# Bad
# game_globals.gd (Autoloaded as GameGlobals)
extends Node

# Sharing gameplay-specific state globally prevents scene isolation and causes tight coupling
var active_player: CharacterBody2D
var current_enemy_count: int = 0
var last_hit_position: Vector2
```

## 2. No Hard References to Dynamic Nodes
Autoloads must not retain hard references to dynamic, short-lived nodes or scenes.
- **Reason:** Storing references to instanced nodes (like enemies or the current player) in a global singleton leads to memory leaks and invalid null-pointer references when those nodes are freed. Use WeakRef or ID-based lookups instead.

```gdscript
# Good
# player_tracker.gd (Autoloaded as PlayerTracker)
extends Node

var _player_ref: WeakRef = weakref(null)


func register_player(player: CharacterBody2D) -> void:
	_player_ref = weakref(player)


func get_player() -> CharacterBody2D:
	return _player_ref.get_ref() as CharacterBody2D
```

```gdscript
# Bad
# player_tracker.gd (Autoloaded as PlayerTracker)
extends Node

# Strong reference prevents garbage collection and causes memory leaks when player is freed
var player: CharacterBody2D
```

## 3. Provide a reset() Method for Testability
Add an explicit `reset()` method that restores all mutable state to default values.
- **Reason:** Autoloads persist across scene changes and test runs. Without a reset method, state from a previous test or scene leaks into the next, producing flaky tests and hard-to-reproduce bugs. Calling `reset()` in a test `before_each()` guarantees a clean baseline.

```gdscript
# Good
# score_manager.gd (Autoloaded as ScoreManager)
extends Node

var _score: int = 0
var _high_score: int = 0


func add_points(amount: int) -> void:
	_score += amount
	_high_score = max(_high_score, _score)


func reset() -> void:
	_score = 0
	_high_score = 0
```

```gdscript
# Bad
# score_manager.gd (Autoloaded as ScoreManager)
extends Node

var _score: int = 0
var _high_score: int = 0

func add_points(amount: int) -> void:
	_score += amount
	_high_score = max(_high_score, _score)

# No reset method — tests must reload the entire SceneTree or manually
# mirror every variable, which is fragile and error-prone.
```

## 4. Use Typed Signal Parameters in Event Buses
Define signal parameters with explicit types on Autoload event buses.
- **Reason:** Untyped signals lose all compile-time safety; callers can emit wrong argument types or counts and errors only surface at runtime. Typed parameters enable editor autocomplete, static analysis warnings, and self-documenting APIs.

```gdscript
# Good
# game_events.gd (Autoloaded as GameEvents)
extends Node

signal enemy_defeated(enemy_name: String, position: Vector2)
signal health_changed(new_health: int, max_health: int)
```

```gdscript
# Bad
# game_events.gd (Autoloaded as GameEvents)
extends Node

signal enemy_defeated  # No parameter types — callers can emit anything
signal health_changed  # Consumers must guess the argument shape
```
