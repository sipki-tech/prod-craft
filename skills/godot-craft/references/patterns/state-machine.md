# Finite State Machines

Structuring and implementing state machines to manage complex branching behaviors cleanly in GDScript 4.

## 1. Node-Based States
Model complex behaviors using a node-per-state pattern instead of a monolithic enum match block.
- **Reason:** Large enums with big match blocks inside physics processes grow unmaintainable and violate single responsibility. Splitting states into separate child nodes isolates state-specific logic, simplifying debugging, testing, and extension.

```gdscript
# Good
# state.gd
class_name State extends Node

var actor: CharacterBody2D

var state_machine: StateMachine


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass

# state_machine.gd
class_name StateMachine extends Node

@export var initial_state: State

@onready var current_state: State = initial_state


func _ready() -> void:
	for child: Node in get_children():
		if child is State:
			var state_node := child as State
			state_node.state_machine = self
			state_node.actor = get_parent() as CharacterBody2D
	if current_state:
		current_state.enter()


func transition_to(target_state_name: String) -> void:
	if not has_node(target_state_name):
		return
	if current_state:
		current_state.exit()
	current_state = get_node(target_state_name) as State
	if current_state:
		current_state.enter()
```

```gdscript
# Bad
# player.gd
class_name BadPlayer extends CharacterBody2D

enum StateType { IDLE, RUN, JUMP, FALL }
var current_state: StateType = StateType.IDLE

func _physics_process(_delta: float) -> void:
	# Monolithic match blocks grow endlessly and make debugging hard
	match current_state:
		StateType.IDLE:
			if velocity.x != 0:
				current_state = StateType.RUN
		StateType.RUN:
			if velocity.x == 0:
				current_state = StateType.IDLE
			elif not is_on_floor():
				current_state = StateType.FALL
		StateType.JUMP:
			pass
		StateType.FALL:
			if is_on_floor():
				current_state = StateType.IDLE
```

## 2. Central Transition Controller
Transition states through the state machine coordinator, never by swapping scripts or bypassing lifecycle.
- **Reason:** Directly swapping scripts or calling transitions without checking current states leads to orphaned routines, duplicate connections, and untraceable lifecycle transitions. The state machine coordinator ensures safe exits and entries.

```gdscript
# Good
# idle_state.gd
class_name IdleState extends State


func physics_update(_delta: float) -> void:
	if actor and not actor.is_on_floor():
		# Requests transition via state machine to orchestrate entry/exit
		if state_machine:
			state_machine.transition_to("Fall")
```

```gdscript
# Bad
# idle_state.gd
class_name BadIdleState extends Node

func physics_update(_delta: float) -> void:
	var actor := get_parent().get_parent() as CharacterBody2D
	if actor and not actor.is_on_floor():
		# Direct script swap bypasses state machine exits and lifecycle
		var fall_state := load("res://src/player/states/fall_state.gd") as Script
		if fall_state:
			get_parent().set_script(fall_state)
```
