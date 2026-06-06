# object_pool.gd
@icon("res://icons/object_pool.svg") # Optional icon reference
class_name ObjectPool extends Node

## Signal emitted when an object is retrieved.
signal object_retrieved(object: Node)
## Signal emitted when an object is recycled.
signal object_recycled(object: Node)

@export_category("Pool Configuration")
## The PackedScene template to instantiate for this pool.
@export var scene: PackedScene = null
## The number of objects to pre-allocate during ready/initialization.
@export var initial_size: int = 32
## The maximum limit of objects this pool can manage to prevent runaway memory usage.
@export var max_size: int = 128
## If true, the pool allocates new instances on retrieve if empty (up to max_size).
@export var allow_growth: bool = true
## If true, retrieving an object from an exhausted pool reclaims the oldest active object.
@export var enable_eviction: bool = false
## If true, objects are reparented to a gameplay node when active, and returned back when inactive.
## If false, objects remain children of the pool container (optimized, avoids tree changes).
@export var use_reparenting: bool = false

# Internal lists to track object state
var _active_list: Array[Node] = []
var _inactive_list: Array[Node] = []

func _ready() -> void:
	# Prepopulate the pool if a scene is specified
	if scene:
		prepopulate(initial_size)


## Prepopulates the pool by instantiating the specified amount of objects.
func prepopulate(amount: int) -> void:
	if not scene:
		push_error("ObjectPool '%s': Cannot prepopulate with a null scene." % name)
		return
		
	var available_capacity: int = max_size - get_total_count()
	var to_instantiate: int = clampi(amount, 0, available_capacity)
	
	for i: int in range(to_instantiate):
		var obj: Node = _create_instance()
		if obj:
			_deactivate_object(obj)
			_inactive_list.append(obj)


## Retrieves an object from the pool, activating it.
## If use_reparenting is true, the node will be parented to [param spawn_parent].
## [param init_data] is passed to the object's `on_pool_activate` method if implemented.
func retrieve(spawn_parent: Node = null, init_data: Dictionary = {}) -> Node:
	var obj: Node = null
	
	# 1. Try to fetch from the inactive list, lazily cleaning up any externally freed nodes
	while not _inactive_list.is_empty():
		var temp: Node = _inactive_list.pop_back()
		if is_instance_valid(temp):
			obj = temp
			break
	
	# 2. If empty, allocate a new one if permitted by constraints
	if not obj and allow_growth and get_total_count() < max_size:
		obj = _create_instance()
		
	# 3. If pool is completely exhausted and eviction is enabled, reclaim the oldest active object
	if not obj and enable_eviction:
		_sanitize_active_list()
		while not _active_list.is_empty():
			var oldest: Node = _active_list[0]
			_active_list.remove_at(0)
			if is_instance_valid(oldest):
				_deactivate_object(oldest)
				obj = oldest
				push_warning("ObjectPool '%s': Evicted oldest active object due to pool exhaustion." % name)
				break
		
	if obj:
		_activate_object(obj, spawn_parent, init_data)
		_active_list.append(obj)
		object_retrieved.emit(obj)
		return obj
		
	push_error("ObjectPool '%s': Failed to retrieve object. Pool is exhausted and growth/eviction are disabled." % name)
	return null


## Recycles an active object back into the pool.
func recycle(obj: Node) -> void:
	if not is_instance_valid(obj):
		return
		
	var active_index: int = _active_list.find(obj)
	if active_index != -1:
		_active_list.remove_at(active_index)
		_deactivate_object(obj)
		_inactive_list.append(obj)
		object_recycled.emit(obj)
	else:
		if _inactive_list.has(obj):
			push_warning("ObjectPool '%s': Tried to recycle object '%s' that is already inactive." % [name, obj.name])
		else:
			push_error("ObjectPool '%s': Tried to recycle object '%s' that does not belong to this pool." % [name, obj.name])


## Frees all currently inactive objects to reclaim system memory.
func clear_inactive() -> void:
	for obj: Node in _inactive_list:
		if is_instance_valid(obj):
			obj.queue_free()
	_inactive_list.clear()


## Resizes the pool. Shrinks inactive capacity or prepopulates up to the new size.
func resize(new_size: int) -> void:
	_sanitize_active_list()
	_sanitize_inactive_list()
	var current_total: int = get_total_count()
	
	if new_size < current_total:
		var shrink_by: int = current_total - new_size
		var destroyed_count: int = 0
		while destroyed_count < shrink_by and not _inactive_list.is_empty():
			var obj: Node = _inactive_list.pop_back()
			if is_instance_valid(obj):
				obj.queue_free()
			destroyed_count += 1
		if destroyed_count < shrink_by:
			push_warning("ObjectPool '%s': Resized to %d, but only shrank to %d because remaining objects are currently active." % [name, new_size, get_total_count()])
	elif new_size > current_total:
		var grow_by: int = new_size - current_total
		prepopulate(grow_by)


## Returns the total number of managed objects (both active and inactive).
func get_total_count() -> int:
	return _active_list.size() + _inactive_list.size()


## Returns the current count of active objects.
func get_active_count() -> int:
	return _active_list.size()


## Returns the current count of inactive objects.
func get_inactive_count() -> int:
	return _inactive_list.size()


# Instantiates the PackedScene, registers owner reference, and adds to container
func _create_instance() -> Node:
	var obj: Node = scene.instantiate()
	if not obj:
		push_error("ObjectPool '%s': Instantiation failed." % name)
		return null
		
	# Inject a reference of this pool to allow self-recycling
	if obj.has_method("set_pool_owner"):
		obj.call("set_pool_owner", self)
	elif "pool_owner" in obj:
		obj.set("pool_owner", self)
		
	# In-place pooling nodes are children of the pool, preventing frozen subtrees
	add_child(obj)
	return obj


# Activates object states, handles reparenting, and invokes object callbacks
func _activate_object(obj: Node, spawn_parent: Node, init_data: Dictionary) -> void:
	if use_reparenting and is_instance_valid(spawn_parent):
		if obj.get_parent() != spawn_parent:
			obj.reparent(spawn_parent)
			
	if not use_reparenting:
		if obj is CanvasItem:
			(obj as CanvasItem).top_level = true
		elif obj is Node3D:
			(obj as Node3D).top_level = true
			
	# Enable processing. Because we do not parent inactive objects to a disabled 
	# subcontainer, setting PROCESS_MODE_INHERIT makes the node active immediately.
	obj.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Enable visibility
	if obj is CanvasItem:
		(obj as CanvasItem).visible = true
	elif obj is Node3D:
		(obj as Node3D).visible = true
		
	# Restore collisions and Area monitoring/monitorable states
	_toggle_collisions(obj, true)
	
	# Execute optional activation hook
	if obj.has_method("on_pool_activate"):
		obj.call("on_pool_activate", init_data)


# Deactivates object states, reparents back to container, and invokes object callbacks
func _deactivate_object(obj: Node) -> void:
	# Execute optional deactivation hook first so the object can save state if needed
	if obj.has_method("on_pool_deactivate"):
		obj.call("on_pool_deactivate")
		
	# Disable processing
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Hide rendering representation
	if obj is CanvasItem:
		(obj as CanvasItem).visible = false
	elif obj is Node3D:
		(obj as Node3D).visible = false
		
	if not use_reparenting:
		if obj is CanvasItem:
			(obj as CanvasItem).top_level = false
		elif obj is Node3D:
			(obj as Node3D).top_level = false
			
	# Disable collision shapes recursively and stop physics overlap detection
	_toggle_collisions(obj, false)
	
	# Return to pool if reparented
	if use_reparenting and obj.get_parent() != self:
		obj.call_deferred("reparent", self)


# Recursively locates collision shapes and toggles their disabled state and monitoring
func _toggle_collisions(node: Node, enabled: bool) -> void:
	if node is Area2D:
		(node as Area2D).set_deferred("monitoring", enabled)
		(node as Area2D).set_deferred("monitorable", enabled)
	elif node is Area3D:
		(node as Area3D).set_deferred("monitoring", enabled)
		(node as Area3D).set_deferred("monitorable", enabled)
		
	for child: Node in node.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not enabled)
		elif child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", not enabled)
		elif child is CollisionPolygon2D:
			(child as CollisionPolygon2D).set_deferred("disabled", not enabled)
		elif child is CollisionPolygon3D:
			(child as CollisionPolygon3D).set_deferred("disabled", not enabled)
		
		# Recurse down the hierarchy
		if child.get_child_count() > 0:
			_toggle_collisions(child, enabled)


# Sanitizes active list by removing invalid (freed) instances in-place without garbage allocation
func _sanitize_active_list() -> void:
	var i: int = _active_list.size() - 1
	while i >= 0:
		if not is_instance_valid(_active_list[i]):
			_active_list.remove_at(i)
		i -= 1


# Sanitizes inactive list by removing invalid (freed) instances in-place without garbage allocation
func _sanitize_inactive_list() -> void:
	var i: int = _inactive_list.size() - 1
	while i >= 0:
		if not is_instance_valid(_inactive_list[i]):
			_inactive_list.remove_at(i)
		i -= 1
