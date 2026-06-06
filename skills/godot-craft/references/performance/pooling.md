# Object Pooling Guidelines

A collection of performance rules and guidelines for object pooling in Godot 4.x using GDScript 2.0. This guide explains how to pre-allocate, recycle, and manage nodes to avoid runtime heap allocation stuttering.

## 1. Pool High-Frequency Nodes
- **Reason:** In Godot 4.x, instantiating nodes (`PackedScene.instantiate()`) and destroying them (`Node.queue_free()`) are highly CPU-intensive operations. Instantiation forces dynamic memory allocations on the heap for the node, its components, properties, and script states. Calling `queue_free()` delays deallocation to the end of the frame, resulting in high heap memory churn, fragmentation, and potential garbage collection stutter. For high-frequency, short-lived nodes (such as bullets, impact VFX, and debris), this pattern causes CPU spikes and micro-stuttering. Pooling shifts the instantiation cost to scene load boundaries by reusing a fixed array of pre-allocated nodes.

```gdscript
# Good
# bullet_spawner.gd
extends Node2D

@export var bullet_pool: ObjectPool = null

const FIRE_RATE_COOLDOWN: float = 0.1

var _cooldown_timer: float = 0.0


func _physics_process(delta: float) -> void:
	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0 and Input.is_action_pressed("shoot"):
		_cooldown_timer = FIRE_RATE_COOLDOWN
		_spawn_bullet()


func _spawn_bullet() -> void:
	if bullet_pool:
		var spawn_data: Dictionary = {
			"global_position": global_position,
			"direction": Vector2.RIGHT.rotated(global_rotation)
		}
		# Retrieve from pre-allocated pool without dynamic instantiating
		var bullet: Node = bullet_pool.retrieve(null, spawn_data)
		if not bullet:
			push_warning("Bullet Pool exhausted, spawn skipped.")
```

```gdscript
# Bad
# bad_bullet_spawner.gd
extends Node2D

@export var bullet_scene: PackedScene = null
const FIRE_RATE_COOLDOWN: float = 0.1
var _cooldown_timer: float = 0.0

func _physics_process(delta: float) -> void:
	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0 and Input.is_action_pressed("shoot"):
		_cooldown_timer = FIRE_RATE_COOLDOWN
		_spawn_bullet()

func _spawn_bullet() -> void:
	# Bypassing the pool and allocating new heap memory every frame
	if bullet_scene:
		var bullet: Node2D = bullet_scene.instantiate() as Node2D
		bullet.global_position = global_position
		bullet.rotation = global_rotation
		get_tree().root.add_child(bullet) # Costly SceneTree modifications
```

---

## 2. State Toggle Deactivation
- **Reason:** Adding and removing nodes from the scene tree (`Node.add_child()` and `Node.remove_child()`) triggers deep recursive notifications (`NOTIFICATION_ENTER_TREE`, `NOTIFICATION_READY`, `NOTIFICATION_EXIT_TREE`) across the node's entire sub-hierarchy. This forces the RenderingServer to invalidate draw lists and canvas items, and requires the PhysicsServer to dynamically reregister collision shapes and rebuild broadphase spatial partitioning structures (such as BVH). To avoid this cost, keep pooled nodes within the scene tree (optionally using in-place pooling under the pool node itself) but disable them by hiding visibility (`visible = false`), pausing processing (`process_mode = Node.PROCESS_MODE_DISABLED`), and disabling collision shapes and Area monitoring.

```gdscript
# Good
# pooled_bullet.gd
class_name PooledBullet extends Area2D

var pool_owner: ObjectPool = null

var velocity: Vector2 = Vector2.ZERO

@onready var collision_shape: CollisionShape2D = $CollisionShape2D as CollisionShape2D


# Activation hook called by the ObjectPool manager
func on_pool_activate(init_data: Dictionary) -> void:
	if init_data.has("global_position"):
		global_position = init_data["global_position"] as Vector2
	if init_data.has("direction"):
		velocity = (init_data["direction"] as Vector2) * 600.0
		rotation = velocity.angle()
	
	# Reset states
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


# Deactivation hook called by the ObjectPool manager
func on_pool_deactivate() -> void:
	velocity = Vector2.ZERO
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _physics_process(delta: float) -> void:
	global_position += velocity * delta


func _on_body_entered(_body: Node) -> void:
	# Instead of freeing, recycle itself via the pool owner
	if is_instance_valid(pool_owner):
		pool_owner.recycle(self)
	else:
		queue_free()
```

```gdscript
# Bad
# bad_bullet.gd
extends Area2D

var velocity: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	global_position += velocity * delta

func _on_body_entered(_body: Node) -> void:
	# Deallocation forces garbage collection and heap fragmentation
	queue_free()
```

---

## 3. Preload Cached Scenes
- **Reason:** Loading scene resources during active gameplay via `load("res://...")` triggers synchronous file I/O operations on the main thread, resulting in immediate frame drops and stuttering. Furthermore, dynamic loading makes it impossible for the GPU to prepare shaders, leading to compilation stalls when the object is rendered for the first time. Preloading resources using `preload("res://...")` at the script level or during a structured loading screen caching phase compiles the scene into memory before gameplay starts, ensuring seamless frame timing.

```gdscript
# Good
# projectile_manager.gd
extends Node

# Solved at script compile-time/load-time
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile.tscn")

@onready var pool: ObjectPool = $ObjectPool as ObjectPool


func _ready() -> void:
	if pool:
		pool.scene = PROJECTILE_SCENE
		pool.prepopulate(50)
```

```gdscript
# Bad
# bad_projectile_manager.gd
extends Node

@onready var pool: ObjectPool = $ObjectPool as ObjectPool

func spawn_projectile(type: String) -> void:
	# Synchronous disk I/O blocks the main thread during gameplay
	var scene_path: String = "res://scenes/projectile_%s.tscn" % type
	var scene: PackedScene = load(scene_path) as PackedScene
	
	if pool and scene:
		pool.scene = scene
		var proj: Node = pool.retrieve()
```

---

## 4. Local vs Global Pools
- **Reason:** Global pools (Autoload Singletons) persist throughout the entire lifecycle of the application. If scene-specific objects (such as Level 1's snowballs, Level 2's sandstorms, or unique level enemies) are stored in a global pool, they remain in memory after the level is unloaded, resulting in memory leaks. Furthermore, global pools increase the base memory footprint. Using local object pools placed directly within the level or spawner scenes leverages Godot's SceneTree lifecycle: when the parent level is freed, the local pool and all its pre-allocated nodes are automatically destroyed by the engine, ensuring clean garbage collection without manual teardown code.

```gdscript
# Good
# level_scene.gd
extends Node2D

# This pool is local to the scene hierarchy. When Level 1 is freed, 
# this ObjectPool and all its pre-allocated nodes are cleanly destroyed.
@onready var vfx_pool: ObjectPool = $LocalVFXPool as ObjectPool


func trigger_explosion(pos: Vector2) -> void:
	var _unused: Node = vfx_pool.retrieve(null, {"global_position": pos})
```

```gdscript
# Bad
# global_pool_autoload.gd (Autoload / Singleton)
extends Node

# Storing level-specific assets in a global singleton causes memory leaks 
# across scene transitions since these nodes are never cleared.
var pools: Dictionary = {}

func get_bullet(type: String) -> Node:
	if not pools.has(type):
		var scene: PackedScene = load("res://scenes/%s.tscn" % type) as PackedScene
		var pool: ObjectPool = ObjectPool.new()
		pool.scene = scene
		add_child(pool)
		pools[type] = pool
	return (pools[type] as ObjectPool).retrieve()
```

---

## 5. Top-Level Transform Decoupling
- **Reason:** When in-place pooling is used, objects remain as children of the pool container (or spawner). If the parent node (e.g., a player's weapon, or the player character) moves or rotates, all active child objects (e.g., projectiles) will inherit that movement and drift incorrectly in world space. To prevent this, active pooled CanvasItem or Node3D objects must decouple their transform from the parent by setting `top_level = true` (or calling `set_as_top_level(true)`) upon activation. When deactivated and returned to the pool, `top_level` must be restored to `false` so they remain cleanly anchored under the pool's hierarchy.

```gdscript
# Good
# projectile.gd
extends Area2D

var pool_owner: ObjectPool = null


func on_pool_activate(init_data: Dictionary) -> void:
	# Decouple transform from parent when activated so it moves independently in world space
	top_level = true
	if init_data.has("global_position"):
		global_position = init_data["global_position"] as Vector2
	# Reset other states...


func on_pool_deactivate() -> void:
	# Re-couple transform to parent when returned to pool so it doesn't drift or float separately
	top_level = false
	# Disable other states...
```

```gdscript
# Bad
# bad_projectile.gd
extends Area2D

func on_pool_activate(init_data: Dictionary) -> void:
	# Without top_level = true, if the spawner/weapon moves,
	# this projectile will move along with it, defying physical expectations.
	if init_data.has("global_position"):
		global_position = init_data["global_position"] as Vector2
```

---

## 6. Recycle via Pool
- **Reason:** The purpose of object pooling is to bypass heap allocations/deallocations and `SceneTree` notification overhead. Calling `queue_free()` directly on a pooled object destroys it permanently, forcing the pool to allocate a new instance later, which defeats the performance optimization. Furthermore, destroying a node externally leaves a dangling reference in the pool's tracking arrays. While the pool handles invalid nodes lazily to prevent crashes, this adds overhead to array operations and breaks consistency. Always return the node to its pool by calling `pool.recycle(node)`.

```gdscript
# Good
# character.gd
extends Area2D

var pool_owner: ObjectPool = null


func _on_body_entered(_body: Node) -> void:
	# Correctly return the object to the pool for reuse
	if is_instance_valid(pool_owner):
		pool_owner.recycle(self)
	else:
		queue_free() # Fallback only if not managed by a pool
```

```gdscript
# Bad
# bad_character.gd
extends Area2D

func _on_body_entered(_body: Node) -> void:
	# Destroys the node entirely, causing heap churn and leaving invalid references in the pool
	queue_free()
```

---

## Reference Implementation

Production-grade pool components are available as copy-paste starters:
- [`assets/object_pool.gd`](../../assets/object_pool.gd) — ObjectPool component
- [`assets/object_pool_manager.gd`](../../assets/object_pool_manager.gd) — ObjectPoolManager singleton
