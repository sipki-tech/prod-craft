# Multiplayer Synchronization and RPCs

This guide defines procedures for synchronizing property states using MultiplayerSpawner and MultiplayerSynchronizer nodes, configuring RPC annotations, and managing bandwidth.

## Use MultiplayerSpawner for Dynamic Node Instantiation
Replicate dynamic gameplay entities (e.g., players, projectiles, and drop items) across clients by configuring a `MultiplayerSpawner` targeting a dedicated container node. Always spawn entities on the server, and ensure client-side instances explicitly set their multiplayer authority.
- **Reason:** Instantiating nodes manually via RPCs is prone to race conditions and fails to synchronize state with late-joining clients. Furthermore, `MultiplayerSpawner` does not automatically synchronize multiplayer authority to client-side instances; clients will default to authority 1 (server) unless they explicitly call `set_multiplayer_authority` during initialization.

```gdscript
# Good
class_name SpawnManager
extends Node

@export var spawner: MultiplayerSpawner

@export var spawn_container: Node2D

@export var player_scene: PackedScene


func _ready() -> void:
	spawner.spawn_path = spawn_container.get_path()
	# The scene must be added to the auto-spawn list
	spawner.add_spawnable_scene(player_scene.resource_path)


func spawn_player_for_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var player_instance := player_scene.instantiate() as Node2D
	player_instance.name = str(peer_id)
	player_instance.set_multiplayer_authority(peer_id)
	spawn_container.add_child(player_instance)

# Inside the spawned player scene's script (e.g., player.gd):
# class_name Player
# extends CharacterBody2D
#
# func _enter_tree() -> void:
# 	# The client-side instance must explicitly set its authority matching the node name
# 	set_multiplayer_authority(name.to_int())

# Bad
# Manual RPC spawning, which late-joining clients will miss completely
class_name FragileSpawnManager
extends Node

@export var player_scene: PackedScene

func request_spawn_player() -> void:
	spawn_player_rpc.rpc(multiplayer.get_unique_id())

@rpc("any_peer")
func spawn_player_rpc(peer_id: int) -> void:
	var player_instance := player_scene.instantiate() as Node2D
	player_instance.name = str(peer_id)
	add_child(player_instance) # Late joiners will never get this node!
```

## Limit MultiplayerSynchronizer to High-Frequency Continuous Variables
Use `MultiplayerSynchronizer` nodes strictly for continuous state replication (like movement coordinates, velocities, or character orientations). Mark replication channels as `unreliable` to optimize packet processing.
- **Reason:** Over-using reliable synchronizers on low-frequency actions leads to buffer bloating and packet overhead.

```gdscript
# Good
# Synchronizing continuous variables with unreliable replication
class_name PlayerMovementSync
extends CharacterBody2D

@onready var synchronizer: MultiplayerSynchronizer = %MultiplayerSynchronizer


func _ready() -> void:
	# Programmatic configuration of synchronization properties
	var config := SceneReplicationConfig.new()
	
	# Add position property to sync. Position must sync unreliably for movement.
	var path := NodePath(".:global_position")
	config.add_property(path)
	config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	
	synchronizer.replication_config = config

# Bad
# Sending high-frequency updates via reliable custom RPC calls manually
class_name ManualMovementSync
extends CharacterBody2D

func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority():
		sync_position_reliable.rpc(global_position)

@rpc("any_peer", "reliable") # Slices frame bandwidth and queues packets
func sync_position_reliable(pos: Vector2) -> void:
	global_position = pos
```

## Explicitly Define RPC Properties and Transmission Types
Avoid using blank `@rpc` annotations. Always declare authority filters (`"authority"` or `"any_peer"`) and transmission modes (`"reliable"`, `"unreliable"`, or `"unreliable_ordered"`).
- **Reason:** Blank annotations default to unsafe client-to-server calls and can result in state corruption or network bottlenecks.

```gdscript
# Good
class_name SecureCombat
extends Node


# Explicitly defining that only the server authority broadcasts this reliably
@rpc("authority", "reliable")
func update_score(team_id: int, score: int) -> void:
	pass


# Explicitly defining that any peer can send this, but unreliably (high frequency inputs)
@rpc("any_peer", "unreliable_ordered")
func send_input_vector(vec: Vector2) -> void:
	pass

# Bad
# Ambiguous RPC annotations using default values
class_name AmbiguousCombat
extends Node

@rpc # Defaults to any_peer, reliable which is a security risk and slow
func trigger_player_action(action_id: int) -> void:
	pass
```
