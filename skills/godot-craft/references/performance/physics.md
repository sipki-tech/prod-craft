# Physics Performance Guidelines

A collection of performance rules and guidelines for physics simulation in Godot 4.x using GDScript 2.0. This guide focuses on optimizing broadphase/narrowphase collision checks, raycasting, body sleeping states, and physics tick decoupling.

## 1. Primitive Collider Shapes
- **Reason:** Resolving collisions requires the physics engine to calculate intersection points and depth. Primitive shape colliders (Box, Sphere, Capsule) use simple, exact mathematical formulas that execute instantly on the CPU. Convex hulls require complex projections (GJK/EPA), while Trimesh (concave) colliders require traversing a Bounding Volume Hierarchy (BVH) tree and checking intersection against hundreds of individual triangles. Dynamic bodies must use primitives or low-vertex compound shapes to prevent physics solver slowdowns.

```gdscript
# Good
# dynamic_object.gd
extends RigidBody3D


func _ready() -> void:
	# Approximate complex geometry using compound primitive colliders
	var box_collider: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 0.5, 1.0)
	box_collider.shape = box_shape
	add_child(box_collider)
	
	var sphere_collider: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 0.4
	sphere_collider.shape = sphere_shape
	sphere_collider.position = Vector3(0.0, 0.4, 0.0)
	add_child(sphere_collider)
```

```gdscript
# Bad
# dynamic_object.gd
extends RigidBody3D

func _ready() -> void:
	# Using a Trimesh (ConcavePolygonShape3D) on a dynamic RigidBody3D.
	# Calculating collision checks on dynamic-on-dynamic concave structures
	# is extremely CPU-expensive, leading to unstable physics simulations and crashes.
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var mesh_node: MeshInstance3D = $MeshInstance3D as MeshInstance3D
	
	if mesh_node and mesh_node.mesh:
		collision_shape.shape = mesh_node.mesh.create_trimesh_shape()
		add_child(collision_shape)
```

## 2. Physics Interpolation
- **Reason:** Setting a high physics tick rate (e.g., 120 ticks/sec) to prevent visual stutter forces the CPU physics engine to process the solver, friction, and constraints twice as often, which severely impacts performance. Godot 4 features built-in physics interpolation. By lowering the physics tick rate (e.g., 50 or 60 ticks/sec) and enabling interpolation, the visual representation updates smoothly at arbitrary monitor refresh rates (e.g., 144Hz) while cutting physics CPU usage in half.

```gdscript
# Good
# physics_setup.gd
extends Node


func _ready() -> void:
	# Restrict simulation tick rate to conserve CPU
	Engine.physics_ticks_per_second = 60
	
	# Enable native physics interpolation globally.
	# Visual nodes will interpolate smoothly between physics steps on high-refresh screens.
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	var _unused: Error = ProjectSettings.save()
```

```gdscript
# Bad
# physics_setup.gd
extends Node

func _ready() -> void:
	# Artificially boosting physics ticks to match 144Hz monitors.
	# The CPU physics thread runs 2.4x more solver iterations, leading to massive frametime spikes.
	Engine.physics_ticks_per_second = 144
```

## 3. Direct Space State Queries
- **Reason:** `RayCast3D` and `ShapeCast3D` nodes participate in the SceneTree hierarchy, incurring coordinate transformation synchronization, node traversal, and update overhead every frame. For mass queries (e.g., shotgun pellet paths, AI line-of-sight checks, crowd ground-alignment), accessing `PhysicsDirectSpaceState3D` directly queries the physics server in C++, bypassing SceneTree overhead entirely.

```gdscript
# Good
# raycast_manager.gd
extends Node3D


func perform_mass_raycasts(origin: Vector3, directions: Array[Vector3]) -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	
	for dir: Vector3 in directions:
		var target: Vector3 = origin + dir * 50.0
		# Query parameters are lightweight resources that don't bind to the SceneTree
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target)
		query.collision_mask = 1 # Match only specific collision layer
		
		var result: Dictionary = space_state.intersect_ray(query)
		if not result.is_empty():
			var hit_collider: Node = result["collider"] as Node
			var hit_pos: Vector3 = result["position"] as Vector3
			_on_hit_detected(hit_collider, hit_pos)


func _on_hit_detected(_collider: Node, _pos: Vector3) -> void:
	pass
```

```gdscript
# Bad
# raycast_manager.gd
extends Node3D

@onready var raycast_pool: Node3D = $RaycastPool as Node3D

func perform_mass_raycasts_bad(origin: Vector3, directions: Array[Vector3]) -> void:
	# Spawning and updating multiple RayCast3D child nodes in a loop.
	# Changing global transforms and calling force_raycast_update() forces the engine
	# to sync spatial matrices and traverse nodes, causing heavy CPU bottlenecks.
	var index: int = 0
	for dir: Vector3 in directions:
		var raycast: RayCast3D = raycast_pool.get_child(index) as RayCast3D
		raycast.global_position = origin
		raycast.target_position = dir * 50.0
		raycast.force_raycast_update()
		
		if raycast.is_colliding():
			_on_hit_detected(raycast.get_collider(), raycast.get_collision_point())
		index += 1

func _on_hit_detected(_collider: Node, _pos: Vector3) -> void:
	pass
```

## 4. Body Sleep Management
- **Reason:** Rigids and Character bodies require CPU integration and solver loops even if they are resting or stationary. Ensure `sleeping_enabled` is active on `RigidBody3D` to allow the engine to automatically put bodies to sleep when their velocity drops. For script-driven dynamic objects, disable script-level physics processes entirely via `set_physics_process(false)` when they are out of range or idle.

```gdscript
# Good
# environmental_debris.gd
extends RigidBody3D

@onready var notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D as VisibleOnScreenNotifier3D


func _ready() -> void:
	# Allow the physics server to sleep the body when resting
	sleeping_enabled = true
	
	notifier.screen_exited.connect(_on_screen_exited)
	notifier.screen_entered.connect(_on_screen_entered)


func _on_screen_exited() -> void:
	# Freeze the physics simulation and turn off scripts when off-screen
	freeze = true
	set_physics_process(false)


func _on_screen_entered() -> void:
	# Resume physics evaluation when visible
	freeze = false
	set_physics_process(true)
```

```gdscript
# Bad
# environmental_debris.gd
extends RigidBody3D

func _physics_process(_delta: float) -> void:
	# Unconditionally running scripts and keeping the body dynamic.
	# If sleeping_enabled is false, the engine evaluates solver velocity and collisions
	# even when the object is stationary, wasting massive CPU cycles across thousands of nodes.
	sleeping_enabled = false
```

## 5. Collision Layer Bitmasks
- **Reason:** The physics engine runs a broadphase sweep-and-prune to find overlapping bounding boxes before executing expensive narrowphase intersection checks. If all objects reside on the default collision Layer 1 and mask Layer 1, the engine is forced to evaluate every object against every other object, resulting in $O(N^2)$ complexity. Isolating entities to specific collision layers and masks prevents unrelated bodies (e.g., dynamic bullets colliding with other bullets) from ever entering narrowphase checks.

```gdscript
# Good
# combat_spawner.gd
extends Node3D

# Setup collision layers based on project definition
const LAYER_WORLD: int = 1

const LAYER_ENEMIES: int = 3

const LAYER_PLAYER_PROJECTILE: int = 4


func spawn_player_projectile(spawn_pos: Vector3, velocity: Vector3) -> Area3D:
	var bullet: Area3D = Area3D.new()
	# Clear all layers (bullet does not need to be detected by anything else)
	bullet.collision_layer = 0
	
	# Set mask to check collisions ONLY with World (Layer 1) and Enemies (Layer 3)
	bullet.collision_mask = (1 << (LAYER_WORLD - 1)) | (1 << (LAYER_ENEMIES - 1))
	
	bullet.global_position = spawn_pos
	add_child(bullet)
	return bullet
```

```gdscript
# Bad
# combat_spawner.gd
extends Node3D

func spawn_player_projectile_bad(spawn_pos: Vector3, _velocity: Vector3) -> Area3D:
	var bullet: Area3D = Area3D.new()
	# Leaving collision layer and mask on default (Layer 1).
	# The physics engine will perform broadphase and narrowphase overlap checks
	# against other bullets, players, background objects, and particles.
	bullet.collision_layer = 1
	bullet.collision_mask = 1
	
	bullet.global_position = spawn_pos
	add_child(bullet)
	return bullet
```
