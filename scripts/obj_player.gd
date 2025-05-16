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
var state_max := 30.0
var state_min := 0.0

@export_group("Camera")
@export var camera_offset := Vector3(0.0,10.0,0.0)

@export_group("Movement")
@export var max_speed := 30.0
@export var min_speed := -10.0
@export var max_acceleration := 16.0
@export var turn_angle := PI/6
@export var friction := -0.2
@export var drag := -0.01

@onready var camera := $Camera3D

var iter := 0

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

## Recursively calculates the top speed of the car using given friction and drag coefficients
## Top speed can be defined as V_n = (F_Drag * V_(n-1)^2) + (F_Friction * V_(n-1)) + V_(n-1) + a
func calc_top_speed(input_velocity: Vector3) -> float:
	var new_friction := calc_friction(input_velocity)
	var new_speed := input_velocity + Vector3(max_acceleration,0,0) + new_friction
	var delta_velocity := new_speed.length() - input_velocity.length()
	if (delta_velocity < 0.00001):
		return new_speed.length()
	else:
		print("Iter ", iter, " - ", new_speed.length())
		iter += 1
		return calc_top_speed(new_speed)

func move_camera(new_position: Vector3) -> void:
	camera.global_transform.origin = new_position

func change_state(state: CarStates, velocity_y: float,dir_y: float) -> CarStates:
	match(state):
		CarStates.DRIVE:
			if (velocity_y == 0.0 and dir_y == 0.0):
				state = CarStates.NEUTRAL
				print("New State: NEUTRAL")
			if (velocity_y < 0.0 and dir_y < 0.0):
				state = CarStates.REVERSE
				print("New State: REVERSE")
		CarStates.NEUTRAL:
			if (dir_y > 0.0):
				state = CarStates.DRIVE
				print("New State: DRIVE")
			elif (dir_y < 0.0):
				state = CarStates.REVERSE
				print("New State: REVERSE")
		CarStates.REVERSE:
			if (dir_y >= 0.0):
				state = CarStates.NEUTRAL
				print("New State: NEUTRAL")

	return state

func set_speed(state: CarStates) -> void:
	match(state):
		CarStates.DRIVE:
			state_max = max_speed
			state_min = 0.0
		CarStates.NEUTRAL:
			state_max = 0.0
			state_min = 0.0
		CarStates.REVERSE:
			state_max = 0.0
			state_min = min_speed

func calc_steering(angle: float, player_turn_dir: Vector3, player_accel_dir: Vector3) -> Vector3:
	if (curr_state == CarStates.REVERSE):
		angle *= -1.0
	# Used to decide car handling at steering angles greater than max_turn_amount (for oversteering and understeering)
	#var max_turn_amount = (prev_velocity/max_speed) * 0.8
	var steering_x = player_turn_dir * cos(angle)
	var steering_y = player_accel_dir * sin(angle)
	# Turning is perpendicular to and dependent on the direction the car is facing
	var steering = steering_x + steering_y

	return steering 

func calc_friction(obj_velocity: Vector3) -> Vector3:
	var frictional_force = obj_velocity * friction
	var drag_force = obj_velocity * obj_velocity.length() * drag
	var net_friction = frictional_force + drag_force

	return net_friction

func _ready() -> void:
	var top_speed := calc_top_speed(velocity)
	print("Top Speed: ", top_speed)

func _physics_process(delta: float) -> void:
	# Reset debug nodes each frame to prevent clutter
	clear_debug_nodes()

	# Get raw input from the player
	var raw_dir := Input.get_vector("turn_left", "turn_right", "brake", "accelerate")
	var input_dir := Vector3(raw_dir.x, 0.0, -raw_dir.y)

	# Calculate forward movement based on the direction the car is facing
	var forward_dir := -basis.z
	var accel_dir := input_dir.z * basis.z
	var turn_dir := input_dir.x * basis.x

	var prev_velocity = velocity.dot(forward_dir)
	var prev_state = curr_state
	curr_state = change_state(curr_state, prev_velocity, -input_dir.z)
	if (curr_state != prev_state):
		set_speed(curr_state)

	#!! BUG: Turning causes a small amount of friction to be applied to the car every frame, even when net friction is 0
	var wheel_steering := Vector3.ZERO
	var front_wheel := global_position + (forward_dir * (scale.z/2.0))
	var back_wheel := global_position - (forward_dir * (scale.z/2.0))
	if (prev_velocity != 0.0 && !turn_dir.is_zero_approx()):
		wheel_steering = calc_steering(turn_angle, turn_dir, accel_dir)

	# Set velocity for each pair of wheels depending on their role
	front_wheel += (velocity + wheel_steering) * delta
	back_wheel += velocity * delta
	var new_heading = (front_wheel - back_wheel).normalized()

	# Calculate player velocity
	#var net_friction = calc_friction(velocity)
	var net_friction = Vector3.ZERO
	velocity = (new_heading * prev_velocity) + (max_acceleration * accel_dir * delta) + (net_friction * delta)
	
	var curr_velocity = velocity.dot(forward_dir)
	if (!accel_dir.is_zero_approx()):
		if (curr_velocity > state_max):
			print("PeePee")
			velocity = velocity.normalized() * abs(state_max)
		# Ensure that the car does not start at velocity of 0 when shifting to drive
		elif (accel_dir.z > 0.0 && curr_velocity < state_min):
			print("PooPoo")
			velocity = velocity.normalized() * abs(state_min)

	move_camera(camera_offset + global_position + Vector3(0.0, (velocity.length()/max_speed) * 5.0, 0.0))
	#move_camera((1.0 * camera_offset) + global_position)

	move_and_slide()
	if (curr_velocity > 0.0):
		look_at(global_position + velocity)
	elif (curr_velocity < 0.0):
		look_at(global_position - velocity)

	var debug_obj := [
		velocity,
		#relative_input,
		accel_dir,
		turn_dir,
		wheel_steering,
		#-global_transform.basis.x.normalized(),
		#-global_transform.basis.z.normalized(),
	]

	draw_debug_lines(global_position + Vector3(0.0,5.0,0.0),debug_obj,debug_colors)

	draw_debug_lines(global_position + Vector3(0.0,5.0,0.0),[front_wheel - global_position],[Color.GRAY])
	draw_debug_lines(global_position + Vector3(0.0,5.0,0.0),[back_wheel - global_position],[Color.WHITE])