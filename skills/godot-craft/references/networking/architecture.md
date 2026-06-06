# Multiplayer Networking Architecture

This guide defines the core networking architecture standards for Godot 4 games, detailing server authority models, dynamic network peer setup, and transport protocol selection.

## Enforce Server-Authoritative Gameplay State
All gameplay-affecting state modifications (such as health changes, damage application, item collection, and score tracking) must be performed by the server. Clients must send inputs or requests, rather than broadcasting their calculated state.
- **Reason:** Trusting client-side gameplay calculations leads to synchronization errors and makes cheating trivial.

```gdscript
# Good
# Server script executing authority check and applying modifications
class_name HealthComponent
extends Node

signal health_changed(new_health: int)

signal health_depleted()

@export var max_health: int = 100

var current_health: int = max_health


func damage(amount: int) -> void:
	# Only modify health on the server (network authority)
	if not multiplayer.is_server():
		return
	
	current_health = clampi(current_health - amount, 0, max_health)
	health_changed.emit(current_health)
	if current_health <= 0:
		health_depleted.emit()

# Bad
# Client script modifying its own health and broadcasting the changes
class_name FragileHealthComponent
extends Node

@export var health: int = 100

func take_damage_client_side(amount: int) -> void:
	# Modifies health directly on client and broadcasts it, trusting client calculations
	health -= amount
	update_health_on_server.rpc(health)

@rpc("any_peer")
func update_health_on_server(new_health: int) -> void:
	health = new_health
```

## Dynamically Select Networking Transport by Target Platform
Do not hardcode network peers; configure transport setup dynamically based on build configuration, platform capabilities, or command-line arguments. Use ENet for native desktop, WebRTC or WebSockets for HTML5 exports, and GodotSteam for Steam P2P.
- **Reason:** Hardware platforms and execution environments have distinct socket compatibility and network constraints.

```gdscript
# Good
class_name NetworkSetup
extends Node


func initialize_peer(port: int, address: String) -> Error:
	var peer: MultiplayerPeer
	var err: Error = OK
	
	if OS.has_feature("web"):
		# Browsers require WebSockets or WebRTC
		var ws_peer := WebSocketMultiplayerPeer.new()
		err = ws_peer.create_client("ws://" + address + ":" + str(port))
		if err != OK:
			return err
		peer = ws_peer
	else:
		# Native platforms can use high-performance UDP ENet
		var enet_peer := ENetMultiplayerPeer.new()
		err = enet_peer.create_client(address, port)
		if err != OK:
			return err
		peer = enet_peer
		
	multiplayer.multiplayer_peer = peer
	return OK

# Bad
# Hardcoding ENet client setup which crashes or fails on HTML5/Web platforms
class_name RigidNetworkSetup
extends Node

func initialize_rigid_peer() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 7777)
	multiplayer.multiplayer_peer = peer # Will fail on web exports
```

## Isolate Host and Connection Lifecycle from Gameplay Scenes
Manage connection establishment, disconnection, and host cleanup in a dedicated service class (e.g., an Autoloaded `NetworkManager`), keeping network initialization decoupled from user interface and spatial gameplay scenes.
- **Reason:** Keeping lifecycle management in dynamic scenes leads to lost signals, memory leaks, and broken reconnection procedures.

```gdscript
# Good
# Dedicated, decoupled NetworkManager autoload service
extends Node

signal connection_established()

signal connection_failed()


func host_server(port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
	return err


func disconnect_network() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

# Bad
# Coupling networking setup and UI variables directly in a level script
extends Node2D

@onready var host_button: Button = %HostButton

func _ready() -> void:
	host_button.pressed.connect(func() -> void:
		var peer := ENetMultiplayerPeer.new()
		peer.create_server(7777)
		multiplayer.multiplayer_peer = peer
	)
```
