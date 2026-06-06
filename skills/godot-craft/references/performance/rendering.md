# Rendering Performance Guidelines

A collection of performance rules and guidelines for rendering in Godot 4.x using GDScript 2.0. This guide focuses on minimizing draw calls, optimizing materials, leveraging LOD systems, and reducing GPU rendering overhead.

## 1. MultiMesh Instancing
- **Reason:** Every standard `MeshInstance3D` in the SceneTree executes an independent draw call, requiring the CPU to communicate mesh state, transform matrices, and material parameters to the GPU. For high-count repetitive assets (e.g., grass, stones, foliage, debris), this driver overhead saturates the CPU, creating a rendering bottleneck. `MultiMeshInstance3D` consolidates thousands of identical meshes into a single draw call by uploading instance transform matrices and per-instance color data in a single GPU buffer (instanced rendering), dropping driver overhead to near zero.

```gdscript
# Good
# foliage_manager.gd
extends Node3D

@export var grass_mesh: Mesh = null

@export var density: int = 1000


func _ready() -> void:
	var multimesh_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	var multimesh: MultiMesh = MultiMesh.new()
	
	# Configure transform format and instance count
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = grass_mesh
	multimesh.instance_count = density
	
	# Populate transforms and colors in a single setup loop
	for i: int in range(density):
		var pos: Vector3 = Vector3(randf_range(-10.0, 10.0), 0.0, randf_range(-10.0, 10.0))
		var xform: Transform3D = Transform3D(Basis().scaled(Vector3.ONE * randf_range(0.8, 1.2)), pos)
		multimesh.set_instance_transform(i, xform)
		multimesh.set_instance_color(i, Color(0.8, randf_range(0.9, 1.0), 0.8))
		
	multimesh_instance.multimesh = multimesh
	add_child(multimesh_instance)
```

```gdscript
# Bad
# foliage_manager.gd
extends Node3D

@export var grass_mesh: Mesh = null
@export var density: int = 1000

func _ready() -> void:
	# Spawning 1000 individual MeshInstance3D nodes creates 1000 separate draw calls.
	# The CPU will spend substantial time synchronizing transforms and submitting command buffers to the GPU.
	for i: int in range(density):
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.mesh = grass_mesh
		mesh_instance.position = Vector3(randf_range(-10.0, 10.0), 0.0, randf_range(-10.0, 10.0))
		add_child(mesh_instance)
```

---

## 2. Material Consolidation
- **Reason:** GPUs achieve peak throughput when rendering consecutive primitives sharing identical shader pipelines, textures, and uniforms. Applying unique materials or loading separate textures forces a GPU render state change, which flushes the draw pipeline and breaks automatic batching. Reusing material resources and packing multiple 2D textures into a single texture atlas (`AtlasTexture`) allows Godot to merge consecutive draw commands, resulting in massive batching performance gains.

```gdscript
# Good
# sprite_spawner.gd
extends Node2D

@export var shared_sheet: Texture2D = null


func spawn_sprite(region: Rect2, pos: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	# AtlasTexture reuses the parent texture sheet, allowing Godot's 2D batcher
	# to group these sprites into a single draw call.
	var atlas_tex: AtlasTexture = AtlasTexture.new()
	atlas_tex.atlas = shared_sheet
	atlas_tex.region = region
	
	sprite.texture = atlas_tex
	sprite.position = pos
	add_child(sprite)
	return sprite
```

```gdscript
# Bad
# sprite_spawner.gd
extends Node2D

func spawn_sprite_bad(texture_path: String, pos: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	# Loading separate individual image files binds a unique texture unit to the GPU
	# for each sprite, breaking the 2D batcher and forcing a separate draw call for every node.
	sprite.texture = load(texture_path) as Texture2D
	sprite.position = pos
	add_child(sprite)
	return sprite
```

---

## 3. LOD and Visibility Ranges
- **Reason:** Rendering high-polygon geometry far from the camera wastes vertex processing resources and leads to sub-pixel triangles that do not affect the output image. While Godot 4 generates automatic mesh LODs upon import, developers should supplement this with manual Hierarchical LOD (HLOD) culling using the `visibility_range_*` properties. This completely unloads high-detail meshes and replaces them with low-complexity proxies or culls them entirely at a distance, saving vertex budget and draw calls.

```gdscript
# Good
# lod_manager.gd
extends Node3D


func configure_lod_hierarchy(high_poly: MeshInstance3D, low_poly: MeshInstance3D) -> void:
	# Configure high-poly mesh to cull beyond 30 meters
	high_poly.visibility_range_begin = 0.0
	high_poly.visibility_range_end = 30.0
	# Use self-fading to transition smoothly without popping
	high_poly.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	
	# Configure low-poly proxy mesh to become active between 30 and 150 meters
	low_poly.visibility_range_begin = 30.0
	low_poly.visibility_range_end = 150.0
	low_poly.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
```

```gdscript
# Bad
# lod_manager.gd
extends Node3D

@onready var camera: Camera3D = get_viewport().get_camera_3d() as Camera3D
@onready var high_poly: MeshInstance3D = $HighPolyMesh as MeshInstance3D
@onready var low_poly: MeshInstance3D = $LowPolyMesh as MeshInstance3D

func _process(_delta: float) -> void:
	# Performing manual distance checks on the CPU in _process for numerous objects
	# introduces script overhead, and toggling .visible breaks automatic batching transitions
	# and causes visual popping compared to native visibility ranges.
	var distance: float = global_position.distance_to(camera.global_position)
	if distance < 30.0:
		high_poly.visible = true
		low_poly.visible = false
	elif distance < 150.0:
		high_poly.visible = false
		low_poly.visible = true
	else:
		high_poly.visible = false
		low_poly.visible = false
```

---

## 4. LightmapGI Baking
- **Reason:** Dynamic shadows require rendering the scene from the perspective of each light source to generate real-time shadow maps, multiplying draw calls and pixel fill costs per light. `LightmapGI` precomputes direct and indirect global illumination, storing them in optimized lightmap textures. At runtime, static meshes read lighting and soft shadows from a single texture lookup, allowing multiple dynamic light setups to be completely disabled.

```gdscript
# Good
# static_level_builder.gd
extends Node3D


func configure_static_geometry(mesh_instance: MeshInstance3D) -> void:
	# Tag the geometry for baking. This enables LightmapGI to include the mesh
	# in the lightmap calculations and apply precomputed lighting.
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
```

```gdscript
# Bad
# static_level_builder.gd
extends Node3D

func configure_static_geometry_bad(mesh_instance: MeshInstance3D) -> void:
	# Leaving static meshes as dynamic and using real-time shadow-casting lights.
	# The GPU is forced to generate shadow maps on every single frame for geometry that never moves.
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	
	var light: OmniLight3D = OmniLight3D.new()
	light.shadow_enabled = true
	add_child(light)
```

---

## 5. Shadow Cascade Tuning
- **Reason:** Real-time shadow rendering is a primary GPU bottleneck. High directional shadow resolutions and excessive cascades saturate GPU fill-rate and memory bandwidth. Restricting shadow max distance, reducing cascade splits, and lowering resolution limits (e.g., from 4096px to 2048px or 1024px) focuses the shadow budget tightly around the camera, recovering massive frame execution time.

```gdscript
# Good
# light_optimizer.gd
extends Node3D


func optimize_directional_light(light: DirectionalLight3D) -> void:
	light.shadow_enabled = true
	
	# Pull shadow max distance in to focus shadow maps on close geometry
	light.directional_shadow_max_distance = 60.0
	
	# Tune cascade split positions (splits normalized from 0.0 to 1.0)
	# Target 3 cascades (optimal balance of draw calls and quality) rather than 4
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_split_1 = 0.1  # 6m
	light.directional_shadow_split_2 = 0.35 # 21m
	light.directional_shadow_split_3 = 0.7  # 42m
```

```gdscript
# Bad
# light_optimizer.gd
extends Node3D

func optimize_directional_light_bad(light: DirectionalLight3D) -> void:
	light.shadow_enabled = true
	
	# Unnecessarily long shadow distance renders distant objects into the shadow map,
	# causing low texel density near the camera and massive draw call overhead.
	light.directional_shadow_max_distance = 400.0
	
	# Maximum cascades mode generates 4 separate frustum slices, forcing the GPU
	# to draw overlapping geometry 4 times per frame.
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
```

---

## 6. Grid Frustum Culling
- **Reason:** Godot performs frustum culling on a per-node basis using bounding boxes (AABBs). If a procedural or static level is combined into a single monolithic mesh, its AABB will always overlap the camera frustum, forcing the GPU to process all vertices even if 95% of the level is behind the camera. Partitioning the map into a grid of distinct spatial chunks allows the engine to immediately cull off-screen nodes at the SceneTree level.

```gdscript
# Good
# grid_map_builder.gd
extends Node3D

const CHUNK_SIZE: float = 16.0


# Partitioning level into spatial chunks lets Godot's frustum culling
# discard off-screen chunks before sending draw commands.
func create_chunk(grid_coords: Vector3) -> MeshInstance3D:
	var chunk_mesh: MeshInstance3D = MeshInstance3D.new()
	chunk_mesh.mesh = _generate_combined_chunk_geometry(grid_coords)
	chunk_mesh.global_position = grid_coords * CHUNK_SIZE
	add_child(chunk_mesh)
	return chunk_mesh


func _generate_combined_chunk_geometry(_coords: Vector3) -> ArrayMesh:
	return ArrayMesh.new()
```

```gdscript
# Bad
# grid_map_builder.gd
extends Node3D

# Generating one giant mesh for the entire map means the camera frustum
# will almost always touch the bounding box, forcing the engine to render
# the whole map even if only a single block is visible.
func create_monolithic_level() -> MeshInstance3D:
	var level_mesh: MeshInstance3D = MeshInstance3D.new()
	level_mesh.mesh = _generate_massive_combined_world()
	add_child(level_mesh)
	return level_mesh

func _generate_massive_combined_world() -> ArrayMesh:
	return ArrayMesh.new()
```

---

## 7. Off-Screen Suspension
- **Reason:** Even when frustum culling removes off-screen nodes from rendering, their CPU components (`_process`, `_physics_process`, pathfinding, animation evaluation, and particle emission) still update every frame by default. Connecting a `VisibleOnScreenNotifier3D` to script execution and animations stops unnecessary updates, saving critical CPU headroom.

```gdscript
# Good
# enemy_controller.gd
extends CharacterBody3D

@onready var notifier: VisibleOnScreenNotifier3D = $VisibleOnScreenNotifier3D as VisibleOnScreenNotifier3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer as AnimationPlayer

@onready var particles: GPUParticles3D = $GPUParticles3D as GPUParticles3D


func _ready() -> void:
	notifier.screen_entered.connect(_on_screen_entered)
	notifier.screen_exited.connect(_on_screen_exited)
	
	# Check initial state
	if not notifier.is_on_screen():
		_on_screen_exited()


func _physics_process(_delta: float) -> void:
	# Heavy AI and steering calculations run only when visible
	_run_movement_logic()


func _on_screen_entered() -> void:
	set_physics_process(true)
	set_process(true)
	anim_player.play("walk")
	particles.emitting = true


func _on_screen_exited() -> void:
	set_physics_process(false)
	set_process(false)
	anim_player.stop()
	particles.emitting = false


func _run_movement_logic() -> void:
	move_and_slide()
```

```gdscript
# Bad
# enemy_controller.gd
extends CharacterBody3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer as AnimationPlayer
@onready var particles: GPUParticles3D = $GPUParticles3D as GPUParticles3D

func _physics_process(_delta: float) -> void:
	# Unconditionally running full AI routing, animations, and particle emissions
	# for hundreds of off-screen enemies wastes CPU time.
	_run_movement_logic()
	if not anim_player.is_playing():
		anim_player.play("walk")
	particles.emitting = true

func _run_movement_logic() -> void:
	move_and_slide()
```

---

## 8. CSG Bake to Mesh
- **Reason:** Constructive Solid Geometry (CSG) nodes evaluate mesh boolean operations on the CPU. CSG geometry has inefficient vertex layouts, does not support automatic LOD generation, and prevents batching. They must be baked into static `MeshInstance3D` nodes in editor scripts or replaced before deployment to secure clean GPU geometry.

```gdscript
# Good
# csg_baker.gd
extends EditorScript


# Run this script in the editor to bake active CSG combinations to StaticMesh
func _run() -> void:
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	var csg_combiner: CSGCombiner3D = edited_root.find_child("LevelCSG") as CSGCombiner3D
	
	if csg_combiner:
		# Extract the compiled meshes (Index 0 is transform, 1 is the mesh data)
		var mesh_data: Mesh = csg_combiner.get_meshes()[1] as Mesh
		var static_mesh_node: MeshInstance3D = MeshInstance3D.new()
		static_mesh_node.name = "BakedStaticLevel"
		static_mesh_node.mesh = mesh_data
		
		# Replace CSG combiner in the scene tree
		csg_combiner.replace_by(static_mesh_node)
		csg_combiner.free()
```

```gdscript
# Bad
# level.gd
extends Node3D

# Leaving CSG nodes in the live production scene forces the engine to compile
# CSG boolean subtraction/union on load, and lacks optimized LOD vertex streams.
@onready var csg_combiner: CSGCombiner3D = $LevelCSG as CSGCombiner3D
```
