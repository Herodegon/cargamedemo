extends CharacterBody3D

# Player Car Movement Rules:
# Movement should be relative to the direction the front of the player car is facing
# When pressing the acceleration button, the car should accelerate in the direction of the front of the car
# When turning, acceleration should be applied orthogonally to the direction the car is facing depending on the direction of the turn
# When braking, the car should decelerate in the direction of the front of the car
# The car should not be able to move faster than max_speed

enum CarStates {
	DRIVE,
	DRIFT,
	NEUTRAL,
	REVERSE
}

var debug_nodes := []
const debug_colors := [
	Color.RED,
	Color.GREEN,
	Color.BLUE,
	Color.YELLOW,
	Color.MAGENTA,
	Color.CYAN
]

var curr_state := CarStates.DRIVE

@export_group("Camera")
@export var camera_offset := Vector3(0.0,10.0,0.0)

@export_group("Movement")
@export var max_speed := 50.0
@export var reverse_speed := 10.0
@export var acceleration := 10.0
@export var turn_speed := deg_to_rad(30.0)

@onready var camera := $Camera3D

## Creates 3D lines in real time for visualizing velocity, acceleration, position, etc.
## Meshes instantiated are added to the root tree, and must be managed/freed manually
func draw_debug_lines(obj_pos: Vector3, nodes: Array, colors: Array) -> void:
	for i in nodes.size():
		debug_nodes.append(DebugDrawTool.line(obj_pos, obj_pos + nodes[i], colors[i]))

## Empty debug children each frame to prevent clutter and allow lines to be redrawn
func clear_debug_nodes() -> void:
	for node in debug_nodes:
		node.queue_free()
	debug_nodes.clear()

## Returns the difference between the center of the player car and the front node
## This difference is the direction the front of the car is facing
func get_front_vector() -> Vector3:
	return -global_transform.basis.z.normalized()

func move_camera(new_position: Vector3) -> void:
	camera.global_transform.origin = new_position

func change_state(velocity_y: float,dir_y: float) -> void:
	match(curr_state):
		CarStates.DRIVE:
			#print("DRIVE")
			if (velocity_y == 0.0 and dir_y == 0.0):
				curr_state = CarStates.NEUTRAL
		CarStates.NEUTRAL:
			#print("NEUTRAL")
			if (dir_y > 0.0):
				curr_state = CarStates.DRIVE
			elif (dir_y < 0.0):
				curr_state = CarStates.REVERSE
		CarStates.REVERSE:
			#print("REVERSE")
			if (dir_y >= 0.0):
				curr_state = CarStates.NEUTRAL

func _physics_process(delta: float) -> void:
	clear_debug_nodes()

	var pos := global_transform.origin

	# Get raw input from the player
	var raw_dir := Input.get_vector("turn_left","turn_right","brake","accelerate")

	# Calculate forward movement based on the direction the car is facing
	var forward_dir := get_front_vector()
	var move_dir := (forward_dir * raw_dir.y).normalized()

	var forward_velocity = velocity.dot(forward_dir)
	change_state(forward_velocity,raw_dir.y)

	if (raw_dir.x != 0.0):
		var turn_rate = turn_speed * delta
		var max_turn_amount = (forward_velocity/max_speed) * 0.8
		rotate_y(-raw_dir.x * turn_rate)

	# Calculate the player's velocity based on the current state
	var player_velocity := Vector3.ZERO
	match (curr_state):
		CarStates.DRIVE:
			if (forward_velocity < 0.0):
				player_velocity = Vector3.ZERO
			else:
				player_velocity = move_dir * max_speed
		CarStates.REVERSE:
			player_velocity = move_dir * reverse_speed
		CarStates.NEUTRAL:
			player_velocity = Vector3.ZERO

	velocity = velocity.move_toward(player_velocity, acceleration * delta)

	move_camera(camera_offset + pos + Vector3(0.0, forward_velocity * 0.1, 0.0))
	move_and_slide()

	var debug_obj := [
		velocity,
		-global_transform.basis.x.normalized(),
		-global_transform.basis.z.normalized(),
	]

	draw_debug_lines(global_transform.origin + Vector3(0.0,5.0,0.0),debug_obj,debug_colors)