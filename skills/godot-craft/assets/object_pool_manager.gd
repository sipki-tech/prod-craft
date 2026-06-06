# object_pool_manager.gd
class_name ObjectPoolManager extends Node

# Store active pool structures
# Keys: StringName (Pool ID), Values: ObjectPool instances
var _pools: Dictionary[StringName, ObjectPool] = {}


## Registers an existing ObjectPool instance under a unique identifier.
func register_pool(pool_id: StringName, pool: ObjectPool) -> void:
	if not is_instance_valid(pool):
		push_error("ObjectPoolManager: Cannot register an invalid or freed ObjectPool.")
		return
		
	if _pools.has(pool_id):
		push_warning("ObjectPoolManager: Pool ID '%s' is already registered. Overwriting." % pool_id)
		var old_pool: ObjectPool = _pools[pool_id] as ObjectPool
		if is_instance_valid(old_pool) and old_pool.get_parent() == self:
			old_pool.queue_free()
			
	_pools[pool_id] = pool
	# Only reparent if the pool is parentless to preserve its local scene lifecycle
	if not pool.get_parent():
		add_child(pool)


## Dynamically creates and registers a pool.
func create_pool(
	pool_id: StringName, 
	scene: PackedScene, 
	initial_size: int = 32, 
	max_size: int = 128,
	use_reparenting: bool = false
) -> ObjectPool:
	var pool: ObjectPool = ObjectPool.new()
	pool.name = "Pool_" + String(pool_id)
	pool.scene = scene
	pool.initial_size = initial_size
	pool.max_size = max_size
	pool.use_reparenting = use_reparenting
	
	register_pool(pool_id, pool)
	return pool


## Retrieves an object from the specified pool.
func retrieve(pool_id: StringName, spawn_parent: Node = null, init_data: Dictionary = {}) -> Node:
	if not _pools.has(pool_id):
		push_error("ObjectPoolManager: No pool registered under ID '%s'." % pool_id)
		return null
		
	var pool: ObjectPool = _pools[pool_id] as ObjectPool
	if not is_instance_valid(pool):
		_pools.erase(pool_id)
		push_error("ObjectPoolManager: Pool under ID '%s' has been freed." % pool_id)
		return null
		
	return pool.retrieve(spawn_parent, init_data)


## Recycles an object back into the specified pool.
func recycle(pool_id: StringName, object: Node) -> void:
	if not _pools.has(pool_id):
		push_error("ObjectPoolManager: No pool registered under ID '%s'." % pool_id)
		return
		
	var pool: ObjectPool = _pools[pool_id] as ObjectPool
	if not is_instance_valid(pool):
		_pools.erase(pool_id)
		push_error("ObjectPoolManager: Pool under ID '%s' has been freed." % pool_id)
		return
		
	pool.recycle(object)


## Removes and clears inactive objects from pools. If pool_id is empty, clears all registered pools.
func clear_pools(pool_id: StringName = &"") -> void:
	if not pool_id.is_empty():
		if _pools.has(pool_id):
			var pool: ObjectPool = _pools[pool_id] as ObjectPool
			if is_instance_valid(pool):
				pool.clear_inactive()
			else:
				_pools.erase(pool_id)
	else:
		var ids_to_erase: Array[StringName] = []
		for id: StringName in _pools:
			var pool: ObjectPool = _pools[id] as ObjectPool
			if is_instance_valid(pool):
				pool.clear_inactive()
			else:
				ids_to_erase.append(id)
		for id: StringName in ids_to_erase:
			_pools.erase(id)


## Unregisters a pool from the manager. Optionally destroys the pool node.
func unregister_pool(pool_id: StringName, free_pool_node: bool = true) -> void:
	if _pools.has(pool_id):
		var pool: ObjectPool = _pools[pool_id] as ObjectPool
		_pools.erase(pool_id)
		if free_pool_node and is_instance_valid(pool):
			pool.queue_free()
