extends CharacterBody3D

# Player Car Movement Rules:
## Movement should be relative to the direction the front of the player car is facing
## When pressing the acceleration button, the car should accelerate in the direction of the front of the car
## When turning, acceleration should be applied orthogonally to the direction the car is facing depending on the direction of the turn
## When braking, the car should decelerate in the direction of the front of the car
## The car should not be able to move faster than max_speed

# TODO List:
## Features:
### - Add drifting mechanic
### - Add camera shake when accelerating
## Bugs:
### - Car turning acceleration increases exponentially as difference between car position and velocity decreases
### - Near zero pivot point when turning during transition from reverse to drive

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
@export var reverse_speed := 5.0
@export var max_acceleration := 2.5
@export var turn_angle := PI/6

@export_group("Wheels")
@export var wheel_radius := 0.5
@export var wheel_width := 0.2

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
	var input_dir := Vector3(raw_dir.x, 0.0, -raw_dir.y)
	#var relative_input := basis * input_dir

	# Calculate forward movement based on the direction the car is facing
	var forward_dir := -basis.z
	var accel_dir := input_dir.z * basis.z
	var turn_dir := input_dir.x * basis.x

	var forward_velocity = velocity.length()
	change_state(forward_velocity,-input_dir.z)

	# Calculate the player's velocity based on the current state
	var player_velocity := Vector3.ZERO
	match (curr_state):
		CarStates.DRIVE:
			if (forward_velocity < 0.0):
				player_velocity = Vector3.ZERO
			else:
				player_velocity = accel_dir * max_speed
		CarStates.REVERSE:
			player_velocity = accel_dir * reverse_speed
		CarStates.NEUTRAL:
			player_velocity = Vector3.ZERO

	var wheel_steering := Vector3.ZERO
	var front_wheel := (scale.z/4.0) * forward_dir
	var back_wheel := (scale.z/4.0) * -forward_dir
	if (forward_velocity != 0.0 && !turn_dir.is_zero_approx()):
		# Used to decide car handling at steering angles greater than max_turn_amount
		#var max_turn_amount = (forward_velocity/max_speed) * 0.8
		var steering_x = turn_dir * cos(turn_angle)
		var steering_y = accel_dir * sin(turn_angle)
		# Turning is perpendicular to and dependent on the direction the car is facing
		wheel_steering = (turn_dir + steering_x + steering_y)*player_velocity.length()
		#print("Difference: ", (180/PI)*angle_difference(atan2(wheel_steering.z, wheel_steering.x), atan2(turn_dir.z, turn_dir.x)))

	front_wheel += wheel_steering
	back_wheel += player_velocity

	print("Wheel Steering: ", wheel_steering.length())

	velocity = velocity.move_toward(front_wheel + back_wheel, max_acceleration * delta)

	#move_camera(camera_offset + pos + Vector3(0.0, forward_velocity * 0.1, 0.0))
	move_camera((1.0 * camera_offset) + pos)
	move_and_slide()

	if (curr_state == CarStates.DRIVE && forward_velocity > 0.0):
		look_at(global_position + velocity)
	elif (curr_state == CarStates.REVERSE || forward_velocity < 0.0):
		look_at(global_position - velocity)

	var debug_obj := [
		#velocity,
		#relative_input,
		#accel_dir,
		#turn_dir,
		#wheel_steering,
		#player_velocity,
		#front_wheel,
		#back_wheel,
		#-global_transform.basis.x.normalized(),
		#-global_transform.basis.z.normalized(),
	]

	draw_debug_lines(global_transform.origin + Vector3(0.0,5.0,0.0),debug_obj,debug_colors)