# GDScript Performance Guidelines

A collection of performance guidelines for writing high-performance GDScript 2.0 code in Godot 4.x. This guide focuses on minimizing VM overhead, caching node lookups, reducing garbage collection pressure, and avoiding frame polling.

## 1. Static Typing for Speed
- **Reason:** In GDScript, untyped variables, parameters, and return types are stored within the `Variant` type wrapper. Operating on dynamic `Variant`s forces the GDScript Virtual Machine (VM) to perform runtime type resolution, operator compatibility checks, and member lookup via string-name hash tables (Variant dispatch). Explicitly typing your code allows the GDScript 2.0 compiler to resolve member offsets and bind C++ function pointers at load time. This enables the VM to execute type-specific bytecode directly, achieving a **2x to 5x speedup** for arithmetic and iteration logic. Additionally, packed arrays (e.g. `PackedVector2Array`) store elements contiguously in memory as raw C++ structs rather than generic arrays of `Variant` pointers, improving CPU L1/L2 cache locality and bypassing element-level heap allocations.

```gdscript
# Good


# Static typing allows the compiler to generate optimized bytecode and direct C++ pointer calls
func process_points(points: PackedVector2Array) -> float:
	var total_distance: float = 0.0
	for i: int in range(points.size() - 1):
		# Resolved at bind-time, invoking C++ directly and bypassing Variant dispatch
		total_distance += points[i].distance_to(points[i + 1])
	return total_distance
```

```gdscript
# Bad
# Generic arrays and dynamic Variant typing force dynamic dispatch and runtime lookups
func process_points(points: Array) -> Variant:
	var total_distance: Variant = 0.0
	for i: int in range(points.size() - 1):
		# Every array index access and addition is resolved dynamically
		total_distance += points[i].distance_to(points[i + 1])
	return total_distance
```

---

## 2. Cache Node References
- **Reason:** The `$NodeName` shorthand is syntactic sugar for `get_node("NodeName")`. Every call to `get_node()` requires Godot to parse the node path string, hash the name, and traverse the `SceneTree` recursively matching child names. Performing this look-up inside `_process()` or `_physics_process()` (which run 60+ times per second per node) creates an expensive CPU bottleneck due to string matching and cache misses. Storing the node pointer in a statically-typed class member during initialization resolves the node path lookup exactly once. Subsequent accesses execute via O(1) direct pointer dereferencing, completely bypassing the scene tree traversal pipeline.

```gdscript
# Good
# Cache references in @onready variables, reducing access in process to O(1) pointer dereferencing
extends CharacterBody2D

@onready var sprite: Sprite2D = $Visuals/Sprite2D as Sprite2D

@onready var footstep_player: AudioStreamPlayer2D = $Audio/FootstepPlayer as AudioStreamPlayer2D


func _process(delta: float) -> void:
	# Direct O(1) variable access, bypassing scene tree lookup overhead
	sprite.position = velocity * delta
	footstep_player.volume_db = -20.0
```

```gdscript
# Bad
# Accessing nodes via paths or shorthands inside a process loop causes scene tree traversal every frame
extends CharacterBody2D

func _process(delta: float) -> void:
	# Traverses the tree and parses the path on every frame
	var sprite_node: Sprite2D = $Visuals/Sprite2D as Sprite2D
	sprite_node.position = velocity * delta
	var footstep_node: AudioStreamPlayer2D = $Audio/FootstepPlayer as AudioStreamPlayer2D
	footstep_node.volume_db = -20.0
```

---

## 3. Lightweight Data Storage
- **Reason:** In Godot, a `Node` (and class inheriting from it like `Node2D` or `Node3D`) is a heavy-weight C++ object. Nodes register with the `SceneTree`, manage coordinate transforms, handle rendering and physics pipelines, listen to notifications, and maintain signals and group lists. Spawning a `Node` solely to store structured data (such as inventory items, quest entries, or a 100x100 grid cells map) wastes hundreds of bytes of memory per element and increases SceneTree traversal costs. In contrast, native dictionaries, arrays, or classes that do not inherit from `Node` (which default to inheriting from `RefCounted`) are lightweight. A `RefCounted` object is managed via automatic reference counting, allocates and deallocates memory quickly, does not register with the `SceneTree`, and bypasses all rendering/physics notification updates, reducing both RAM footprint and garbage-collection overhead.

```gdscript
# Good
# Represent pure data and state using lightweight classes (RefCounted) or native Dictionaries/Arrays
# cell_data.gd (Default base class is RefCounted)
class_name CellData

var cell_id: int

var height_val: float

var biome_type: StringName


func _init(id: int, h_val: float, b_type: StringName) -> void:
	cell_id = id
	height_val = h_val
	biome_type = b_type

# terrain_generator.gd
extends Node

var map_data: Array[CellData] = []


func generate_map(width: int, height: int) -> void:
	map_data.resize(width * height)
	for x: int in range(width):
		for y: int in range(height):
			var index: int = x * height + y
			# Instantiates a lightweight RefCounted object with zero SceneTree or rendering overhead
			map_data[index] = CellData.new(index, randf(), &"Grassland")
```

```gdscript
# Bad
# Creating a Node instance for each data element introduces heavy C++ object and scene tree overhead
# cell_node.gd
extends Node2D

var cell_id: int
var height_val: float
var biome_type: StringName

# terrain_generator.gd
extends Node

func generate_map(width: int, height: int) -> void:
	for x: int in range(width):
		for y: int in range(height):
			# Heavy C++ object allocation for an entity that doesn't need physics, rendering, or lifecycle processing
			var cell: Node2D = Node2D.new()
			cell.set_script(preload("cell_node.gd"))
			cell.set("cell_id", x * height + y)
			cell.set("height_val", randf())
			cell.set("biome_type", &"Grassland")
			add_child(cell) # Registers the node in the SceneTree, increasing update and traversal costs
```

---

## 4. Object Pool Allocations
- **Reason:** Instantiating objects (using `.new()` or `.instantiate()`) requires a heap allocation, which is a relatively slow, non-deterministic operation that can lead to memory fragmentation. In GDScript, dynamically allocating short-lived arrays, dictionaries, or custom classes inside hot paths (such as `_process()` loops) puts continuous pressure on the memory allocator. For nodes, the cost is higher because `queue_free()` does not immediately free memory. Instead, it places the node on a deferred deletion queue, which is processed in a batch at the end of the frame. Constantly adding and deleting nodes causes periodic GC/cleanup spikes, leading to frame-rate hitching (micro-stuttering). Implementing an object pool pre-allocates a fixed block of nodes at startup and recycles them by toggling their visibility and processing modes. This moves memory allocation cost to loading screens and ensures gameplay remains allocation-free.

```gdscript
# Good
# Implement object pooling to pre-allocate and reuse resources without runtime allocations
# bullet_pool.gd
extends Node

@export var bullet_scene: PackedScene = null

@export var pool_size: int = 50

var _pool: Array[Node2D] = []

var _active_bullets: Array[Node2D] = []


func _ready() -> void:
	# Pre-allocate bullets during initialization (e.g., scene load)
	for i: int in range(pool_size):
		var bullet: Node2D = bullet_scene.instantiate() as Node2D
		bullet.visible = false
		bullet.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(bullet)
		_pool.append(bullet)


func spawn_bullet(spawn_position: Vector2, spawn_rotation: float) -> Node2D:
	var bullet: Node2D = null
	if _pool.is_empty():
		# Recycle the oldest active bullet if the pool is exhausted to prevent allocations
		if not _active_bullets.is_empty():
			bullet = _active_bullets.pop_front() as Node2D
			bullet.global_position = spawn_position
			bullet.global_rotation = spawn_rotation
			_active_bullets.append(bullet)
	else:
		bullet = _pool.pop_back() as Node2D
		bullet.global_position = spawn_position
		bullet.global_rotation = spawn_rotation
		bullet.visible = true
		bullet.process_mode = Node.PROCESS_MODE_INHERIT
		_active_bullets.append(bullet)
	return bullet


func recycle_bullet(bullet: Node2D) -> void:
	# Disable visual rendering and physics/script processing instead of freeing
	bullet.visible = false
	bullet.process_mode = Node.PROCESS_MODE_DISABLED
	var _removed: bool = _active_bullets.erase(bullet)
	_pool.append(bullet)
```

```gdscript
# Bad
# Spawning and freeing nodes on the fly causes memory fragmentation and frame-end stuttering
# shooter.gd
extends Node2D

@export var bullet_scene: PackedScene = null

func fire_weapon() -> void:
	# Instantiates a heavy node object on every trigger
	var bullet: Node2D = bullet_scene.instantiate() as Node2D
	bullet.global_position = global_position
	get_parent().add_child(bullet)
```

---

## 5. Reuse Data Structures
- **Reason:** In GDScript, dynamically allocating short-lived arrays, dictionaries, or custom classes inside hot paths (such as `_process()` loops) puts continuous pressure on the memory allocator. Instantiating a new array or dictionary on every frame forces a heap allocation, which triggers garbage collection overhead and potential performance degradation. Reusing class-level data structures and calling `.clear()` retains their backing capacity, completely avoiding dynamic reallocations and reducing GC pressure.

```gdscript
# Good
# Reuse a class-level array and clear it to retain the backing capacity, preventing dynamic re-allocation
extends Node

var _cached_active_targets: Array[Node2D] = []

var targets: Array[Node2D] = []


func _process(delta: float) -> void:
	_cached_active_targets.clear() # Clears elements but retains allocated capacity
	for target: Node2D in targets:
		if target.is_active:
			_cached_active_targets.append(target)
	_process_targets(_cached_active_targets)


func _process_targets(list: Array[Node2D]) -> void:
	pass
```

```gdscript
# Bad
# Allocates a new array on every frame inside _process()
extends Node

var targets: Array[Node2D] = []

func _process(delta: float) -> void:
	var active_targets: Array[Node2D] = []
	for target: Node2D in targets:
		if target.is_active:
			active_targets.append(target)
	_process_targets(active_targets)

func _process_targets(list: Array[Node2D]) -> void:
	pass
```

---

## 6. Reactive Signal Architecture
- **Reason:** Every active node that implements `_process()` or `_physics_process()` receives a frame callback from the engine. This triggers a context switch from the C++ engine core to the GDScript VM (script dispatch). When hundreds of nodes run process callbacks, the combined context-switch overhead consumes several milliseconds of frame time, even if the scripts do nothing or only check simple boolean flags. Polling state (e.g. checking distances or variable values every frame) is highly inefficient. Transitioning to a reactive architecture using **Signals** (which propagate events instantly and only when state changes) and **Timers** (which throttle periodic checks) completely eliminates idle processing overhead. Furthermore, explicitly calling `set_process(false)` or `set_physics_process(false)` on inactive nodes tells the engine to skip dispatching frame updates to those nodes entirely, freeing up valuable CPU cycles.

```gdscript
# Good
# Transition to a reactive, signal-driven architecture and disable frame updates
# health_hud.gd
extends Label


func setup_player(player: PlayerCharacter) -> void:
	# Event-driven GUI update: execute only when the player health signal fires
	player.health_changed.connect(_on_player_health_changed)
	text = "Health: %d" % player.health
	set_process(false) # Disable process loop completely


func _on_player_health_changed(new_health: int) -> void:
	text = "Health: %d" % new_health

# enemy_ai.gd
extends CharacterBody2D

@onready var detection_area: Area2D = $DetectionArea as Area2D

@onready var decision_timer: Timer = $DecisionTimer as Timer


func _ready() -> void:
	# Reactive physical tracking via C++ physics engine signals
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	
	# Throttle periodic AI decision-making (e.g., checking paths) instead of running on every frame
	decision_timer.timeout.connect(_on_decision_timeout)
	decision_timer.start(0.25) # Run 4 times per second instead of 60+
	
	set_process(false)
	set_physics_process(false)


func _on_body_entered(body: Node) -> void:
	if body is PlayerCharacter:
		_alert_enemy()


func _on_body_exited(body: Node) -> void:
	if body is PlayerCharacter:
		_deescalate_enemy()


func _on_decision_timeout() -> void:
	_update_pathfinding_logic()


func _alert_enemy() -> void:
	pass


func _deescalate_enemy() -> void:
	pass


func _update_pathfinding_logic() -> void:
	pass
```

```gdscript
# Bad
# Polling a player's distance and health every frame wastes CPU cycles and context switches
# health_hud.gd
extends Label

var player: PlayerCharacter = null

func _process(delta: float) -> void:
	# Polling player health every frame even if it rarely changes
	if player:
		text = "Health: %d" % player.health

# enemy_ai.gd
extends CharacterBody2D

var player: PlayerCharacter = null

func _process(delta: float) -> void:
	# Polling player distance every frame for AI states
	if player and global_position.distance_to(player.global_position) < 150.0:
		_alert_enemy()

func _alert_enemy() -> void:
	pass
```
