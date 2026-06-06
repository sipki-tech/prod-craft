# Multiplayer Network Security

This guide presents code conventions and rules for client validation, input sanitization, RPC sender verification, and rate limiting in Godot 4.

## Verify Remote Sender ID for Peer-Callable RPCs
In any RPC configured with `"any_peer"`, the server must retrieve `multiplayer.get_remote_sender_id()` and verify it matches the node's multiplayer authority or the expected sender before executing logic.
- **Reason:** Malicious clients can call RPCs on other clients' nodes or send commands representing other active players.

```gdscript
# Good
class_name SecureInteraction
extends Node


func _ready() -> void:
	# Set player peer ID as authority
	set_multiplayer_authority(name.to_int())


@rpc("any_peer", "reliable")
func request_item_use(item_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	# Verify that the sender matches the owner of this player node
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != get_multiplayer_authority():
		push_error("Unauthorized RPC invocation from client: " + str(sender_id))
		# Safely reject or kick player
		return
		
	# Process server validation logic...

# Bad
# Accepting client input without verifying who sent it
class_name ExploitInteraction
extends Node

@rpc("any_peer", "reliable")
func perform_item_use_unverified(item_id: int, player_id: int) -> void:
	# Trusting the client-supplied argument parameter player_id!
	# An attacker can supply any player's ID to use their items.
	apply_item_effects(item_id, player_id)

func apply_item_effects(item_id: int, player_id: int) -> void:
	pass
```

## Sanitize and Constrain Client Input Values
Check every client input vector, movement magnitude, and speed delta on the server. Enforce hard limits (e.g. normalize direction vectors, check max distance per frame).
- **Reason:** Cheaters can manipulate their game memory to send massive inputs, causing speed-hacks or teleportation.

```gdscript
# Good
class_name ServerPhysicsValidation
extends CharacterBody2D

const MAX_SPEED: float = 300.0

const SLOP_FACTOR: float = 1.15


func server_process_movement(client_input: Vector2, delta: float) -> void:
	if not multiplayer.is_server():
		return
		
	# Sanitize direction vectors
	var input_direction := client_input.limit_length(1.0)
	
	# Calculate expected displacement
	var expected_velocity := input_direction * MAX_SPEED
	velocity = expected_velocity
	
	move_and_slide()

# Bad
# Directly trusting the client's calculated position delta
class_name UntrustedPhysicsValidation
extends CharacterBody2D

@rpc("any_peer", "unreliable")
func sync_unverified_position(client_position: Vector2) -> void:
	# Directly applying client-supplied coordinates allows teleport hacks
	global_position = client_position
```

## Implement Rate Limiting on Client RPC Calls
Enforce request cooldowns on the server for gameplay-related RPC triggers (such as attacking, chatting, or inventory actions). Keep count of queries per second and flag or disconnect peers exceeding bounds.
- **Reason:** Client RPC floods can overload the server CPU and network buffers, causing server degradation or crashes.

```gdscript
# Good
class_name RateLimiter
extends Node

# Tracks peer ID to array of timestamps [Array[float]]
var request_history: Dictionary = {}

const MAX_REQUESTS_PER_SECOND: int = 5


func _ready() -> void:
	if multiplayer:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_disconnected(peer_id: int) -> void:
	request_history.erase(peer_id)


func is_rate_limited(peer_id: int) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if not request_history.has(peer_id):
		request_history[peer_id] = []
	
	var timestamps: Array = request_history[peer_id]
	
	# Filter old timestamps
	while timestamps.size() > 0 and now - timestamps[0] > 1.0:
		timestamps.remove_at(0)
		
	if timestamps.size() >= MAX_REQUESTS_PER_SECOND:
		return true
		
	timestamps.append(now)
	return false

# Bad
# Executing database/heavy operation on every single RPC packet received
class_name ExpensiveServerAction
extends Node

@rpc("any_peer", "reliable")
func load_user_profile() -> void:
	# Attacker can trigger this in a loop to freeze the database or server
	query_profile_db()

func query_profile_db() -> void:
	pass
```
