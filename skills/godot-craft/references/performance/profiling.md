# Performance Profiling

A guide to measuring, monitoring, and identifying bottlenecks in Godot 4.x games using GDScript 2.0.

## 1. Measure First
- **Reason:** Premature optimization leads to complex, brittle, and hard-to-maintain code, often without solving the actual bottleneck. Implementing custom pooling, complex data structures, or rewriting routines in C++ based on guesswork consumes valuable time. Using Godot's built-in `Performance` singleton allows developers to gather engine-level metrics (such as active nodes, memory footprints, and frame times) under realistic workloads. Gathering metrics manually in script execution (e.g., subtracting `Time.get_ticks_usec()` results every frame) consumes CPU cycles, allocates memory, and adds overhead in GDScript, distorting the profile data. Wrapping diagnostics inside `OS.is_debug_build()` blocks ensures profiling code compiles out or is skipped in production builds.

```gdscript
# Good
# performance_monitor.gd
extends CanvasLayer

@export var monitor_interval: float = 0.5

@onready var _stats_label: Label = %StatsLabel

var _time_since_update: float = 0.0


func _ready() -> void:
	# Disable processing completely in release builds to avoid all monitor query overhead
	if not OS.is_debug_build():
		set_process(false)
		hide()


func _process(delta: float) -> void:
	_time_since_update += delta
	if _time_since_update >= monitor_interval:
		_time_since_update = 0.0
		_update_metrics_display()


func _update_metrics_display() -> void:
	# Querying the engine monitors programmatically is accurate and lightweight
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var process_time_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var static_mem_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	
	_stats_label.text = "FPS: %d\nProcess: %.2f ms\nStatic Mem: %.2f MB" % [
		int(fps), 
		process_time_ms, 
		static_mem_mb
	]
```

```gdscript
# Bad
# performance_monitor.gd
extends CanvasLayer

@onready var stats_label: Label = $StatsLabel

var _last_frame_ticks: int = 0

func _process(delta: float) -> void:
	# Unconditional manual metric calculation runs in production builds.
	# Subtracting time ticks on every frame adds unnecessary GDScript execution overhead.
	var current_ticks: int = Time.get_ticks_usec()
	var frame_duration_ms: float = (current_ticks - _last_frame_ticks) / 1000.0
	_last_frame_ticks = current_ticks
	
	# Updating the UI label on every single frame forces the engine to recalculate
	# text layout, perform heap allocations for string formatting, and redraw the label.
	# This creates a significant CPU bottleneck itself, distorting profiling metrics.
	var raw_fps: float = 0.0
	if delta > 0.0:
		raw_fps = 1.0 / delta
	stats_label.text = "FPS: %.1f\nProcess: %.2f ms" % [raw_fps, frame_duration_ms]
```

---

## 2. Thread Bottleneck Isolation
- **Reason:** A game frame consists of independent execution threads and engine servers. Distinguishing between `TIME_PROCESS` (which tracks script callbacks outside of physics and rendering setup) and `TIME_PHYSICS` (which tracks physics step calculations and collision solver cycles) is critical. For instance, a physics-heavy game with hundreds of active collision shapes will show high physics frame time, while a script-heavy UI or visual effects setup will consume process frame time. Manually tracing these in GDScript using custom timestamps is prone to thread synchronization errors and lacks access to Godot's internal server timings. By querying specific built-in monitors (such as `TIME_PHYSICS`, `TIME_NAVIGATION_PROCESS`, and `OBJECT_NODE_COUNT`), developers can identify exactly which engine server is struggling and focus optimization efforts appropriately.

```gdscript
# Good
# diagnostic_reporter.gd
extends Node

@export var report_interval_sec: float = 2.0

var _timer: float = 0.0


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= report_interval_sec:
		_timer = 0.0
		_evaluate_engine_threads()


func _evaluate_engine_threads() -> void:
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS) * 1000.0
	var navigation_ms: float = Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0
	var node_count: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	if physics_ms > 12.0:
		# Alert developer to physics-specific bottlenecks (e.g. colliders, collision layers)
		push_warning("Physics thread bottleneck: %.2f ms. Node count: %d" % [physics_ms, node_count])
	if process_ms > 12.0:
		# Alert developer to script-specific bottlenecks
		push_warning("Process thread bottleneck: %.2f ms" % process_ms)
	if navigation_ms > 4.0:
		# Alert developer to pathfinding or map updates overload
		push_warning("Navigation map update bottleneck: %.2f ms" % navigation_ms)
```

```gdscript
# Bad
# diagnostic_reporter.gd
extends Node

# Running checks inside _physics_process with high frequency (60-120 ticks/sec).
# Logging to console via print() blocks the calling thread, resulting in performance drops.
# It also confuses process-level bottlenecks with physics-level bottlenecks.
func _physics_process(delta: float) -> void:
	var start_time: int = Time.get_ticks_usec()
	
	# Simulating heavy operations
	_do_heavy_calculations()
	
	var elapsed_ms: float = (Time.get_ticks_usec() - start_time) / 1000.0
	print("[Physics Step] duration: ", elapsed_ms, " ms")
	
func _do_heavy_calculations() -> void:
	pass
```

---

## 3. Modular Profiling Functions
- **Reason:** The Godot Editor CPU Profiler captures execution times and call counts at the function boundary. If a script executes all of its complex behaviors (such as pathfinding, line-of-sight checks, state updates, and animation handling) in a single monolithic lifecycle method (e.g. `_physics_process()`), the profiler is forced to attribute the combined execution time to that single lifecycle function. This forces developers to guess which lines of code are causing frame spikes. Breaking complex routines into smaller, statically-typed helper functions exposes each logic block as a separate entry in the Profiler stack. This enables rapid identification of slow routines (e.g., finding that pathfinding queries, rather than physics calculations, are consuming 80% of script execution time) and prevents optimization efforts from being misdirected.

```gdscript
# Good
# modular_enemy_ai.gd
extends CharacterBody2D

var _target: Node2D = null


func _physics_process(delta: float) -> void:
	if _target == null:
		return
		
	# Separating logic into modular helper functions lets the CPU Profiler
	# accurately track execution cost per system.
	_update_pathfinding()
	_detect_enemies_in_range()
	_apply_steering_movement(delta)


func _update_pathfinding() -> void:
	# Profiler tracks this separately. If pathfinding is slow, it will show up here.
	var path_distance: float = global_position.distance_to(_target.global_position)
	if path_distance > 100.0:
		# Simulation of navigation path update
		pass


func _detect_enemies_in_range() -> void:
	# Profiler tracks raycasting/vision check execution time.
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, _target.global_position)
	var result: Dictionary = space_state.intersect_ray(query)
	if not result.is_empty():
		pass


func _apply_steering_movement(delta: float) -> void:
	# Profiler tracks physical translation and steering calculations.
	velocity = (global_position.direction_to(_target.global_position) * 200.0)
	move_and_slide()
```

```gdscript
# Bad
# monolithic_enemy_ai.gd
extends CharacterBody2D

var _target: Node2D = null

func _physics_process(delta: float) -> void:
	# Monolithic implementation.
	# The CPU Profiler will only show total execution time under "_physics_process".
	# The developer cannot distinguish whether navigation checks, raycasting, or movement is slow.
	if _target != null:
		# 1. Pathfinding/Distance logic
		var path_distance: float = global_position.distance_to(_target.global_position)
		if path_distance > 100.0:
			# Navigation simulation...
			pass
			
		# 2. Raycasting vision check
		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, _target.global_position)
		var result: Dictionary = space_state.intersect_ray(query)
		if not result.is_empty():
			pass
			
		# 3. Steering and movement updates
		velocity = (global_position.direction_to(_target.global_position) * 200.0)
		move_and_slide()
```

---

## 4. RenderingServer Monitoring
- **Reason:** Rendering bottlenecks typically fall into two categories: CPU-side driver overhead (high draw call count) or GPU-side overload (high vertex/primitive count or complex fragment shaders). Programmatically querying `RenderingServer.get_rendering_info()` helps developers isolate these bottlenecks. For example, a high draw call count (`RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`) means the CPU is overwhelmed by organizing and sending rendering commands to the graphics API, which can be mitigated by combining meshes, using `MultiMeshInstance3D`, or leveraging automatic 2D batching. In contrast, a high primitive count (`RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME`) indicates that the GPU is vertex-bound, requiring mesh simplification, LOD configurations, or occlusion culling. Querying this info via script avoids manual scene tree traversal, which is slow and ignores engine culling states.

```gdscript
# Good
# render_monitor.gd
extends Node

@export var diagnostic_interval: float = 1.0

var _timer: float = 0.0


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= diagnostic_interval:
		_timer = 0.0
		_analyze_rendering_pipeline()


func _analyze_rendering_pipeline() -> void:
	# Querying the RenderingServer directly captures actual pipeline metrics for the frame
	var draw_calls: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	)
	var primitives: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
	)
	var objects: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME
	)
	
	# CPU Driver overhead threshold check
	if draw_calls > 800:
		push_warning("High Draw Calls: %d on %d objects. Use MultiMesh or merge meshes." % [
			draw_calls, 
			objects
		])
		
	# GPU Vertex limit check
	if primitives > 1000000:
		push_warning("High Primitives: %d. Implement LOD, reduce geometry, or enable occlusion culling." % primitives)
```

```gdscript
# Bad
# manual_render_scanner.gd
extends Node

# Traversing the SceneTree to estimate rendering cost is extremely slow,
# generates garbage collection overhead, and is highly inaccurate because
# it ignores frustum culling, occlusion culling, and batching.
func _process(delta: float) -> void:
	var total_mesh_instances: int = 0
	var total_estimated_vertices: int = 0
	
	_recursive_scan(get_tree().root, total_mesh_instances, total_estimated_vertices)

func _recursive_scan(node: Node, meshes: int, vertices: int) -> void:
	if node is MeshInstance3D:
		meshes += 1
		if node.mesh:
			# Calling get_faces() on a Mesh is incredibly slow as it downloads
			# geometry data from the GPU back to the CPU, stalling the rendering pipeline.
			vertices += node.mesh.get_faces().size()
			
	for child: Node in node.get_children():
		_recursive_scan(child, meshes, vertices)
```

---

## 5. Target Hardware Profiling
- **Reason:** Developers have a limited time budget to render each frame (e.g., 16.67ms for 60 FPS, 33.33ms for 30 FPS). Attempting to optimize code segments without knowing which subsystem (Script Execution, Physics, Render Driver, or GPU fragment shading) is consuming the largest portion of this budget leads to wasted effort. Furthermore, profiling must be performed on hardware representative of the target platform using release-like builds. Godot's debug builds introduce validation checks, execution hooks, and assertions that disproportionately slow down script execution compared to C++ engine operations. This can mislead a developer into optimizing a GDScript routine that would normally run twice as fast in a production build, while ignoring a genuine physics or vertex bottleneck that remains constant.

```gdscript
# Good
# performance_diagnostics.gd
extends Node


# A tiered diagnostics reporter to identify the biggest cost center
func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		

func run_diagnostics() -> void:
	var total_frame_time: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_time: float = Performance.get_monitor(Performance.TIME_PHYSICS) * 1000.0
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	
	# Determine if CPU script execution/engine loop or GPU bottleneck dominates
	print("--- FRAME BUDGET STATUS (Target: 16.67ms) ---")
	print("Total Process Frame Time: %.2f ms" % total_frame_time)
	print("Physics Frame Time: %.2f ms" % physics_time)
	print("FPS: %.1f" % fps)
	
	if total_frame_time > 16.67:
		var draw_calls: int = RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		)
		var objects: int = RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME
		)
		
		if draw_calls > 800 and objects > 500:
			print("Verdict: Bottleneck is CPU-to-GPU command pipeline (Draw Call Bound).")
		elif physics_time > total_frame_time * 0.6:
			print("Verdict: Bottleneck is Physics Thread (Collision/Solver Bound).")
		else:
			print("Verdict: Bottleneck is likely heavy GDScript execution or GPU Pixel fillrate.")
```

```gdscript
# Bad
# guesswork_optimizer.gd
extends Node

var _cache_map: Dictionary = {}

# Re-implementing mathematical operations or caching basic calculations in complex
# scripts based on guesswork, without checking if GDScript execution time is actually
# the biggest cost center on target hardware.
func get_distance_squared(a: Vector2, b: Vector2) -> float:
	var cache_key: String = "%s_%s" % [a, b] # Allocates strings, creating high GC pressure
	if _cache_map.has(cache_key):
		return _cache_map[cache_key] as float
		
	# A simple vector operation takes negligible CPU cycles compared to the dictionary lookup,
	# string conversion, and garbage collection overhead created by the cache.
	var result: float = (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
	_cache_map[cache_key] = result
	return result
```
