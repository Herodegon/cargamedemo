extends CharacterBody3D

# Player Car Movement Rules:
## Movement should be relative to the direction the front of the player car is facing
## When pressing the acceleration button, the car should accelerate in the direction of the front of the car
## When turning, acceleration should be applied orthogonally to the direction the car is facing depending on the direction of the turn
## When braking, the car should decelerate in the direction of the front of the car
## The car should not be able to move faster than max_speed

# TODO List:
## Features:
### [ ] - Add drifting mechanic
### [ ] - Add jump mechanic
### [ ] - Add pitch spin when midair
### [ ] - Add yaw spin when midair
### [ ] - Add camera shake when accelerating
## Bugs:
### [X] - Car turning acceleration increases exponentially as difference between car position and velocity decreases
### [X] - Near zero pivot point when turning during transition from reverse to drive

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

## When true, drift is applied to front and back wheels
var is_handbrake_applied := false
var acceleration_angle := 0.0

var is_friction_enabled := true
var is_debug_enabled := false

@export_group("Camera")
@export var camera_offset := Vector3(0.0,10.0,0.0)

@export_group("Movement")
@export var max_speed := 30.0				# Highest speed possible by max gear. 		  		   Default: 30.0
@export var min_speed := -10.0				# Lowest speed possible in reverse.   		  		   Default: -10.0
@export var max_acceleration := 10.0		# Rate of acceleration by the car each frame. 		   Default: 16.0
@export var turn_angle := PI/6				# Angle from front wheels where turn force is applied. Default: PI/6
@export var turn_strength := 2.0			# Magnitude of turn angle. 							   Default: 1.0
@export var spin_angle := PI/6              # Angle from front wheels where spin force is applied. Default: PI/6
@export var friction := -0.2				# Force to reduce acceleration. 					   Default: -0.2
@export var drag := -0.01					# Force to reduce acceleration as velocity increases.  Default: -0.01

@onready var camera := $Camera3D

## Creates 3D lines in real time for visualizing velocity, acceleration, position, etc.
## Meshes instantiated are added to the root tree, and must be managed/freed manually
func draw_debug_lines(obj_pos: Vector3, nodes: Array, colors: Array) -> void:
	for i in nodes.size():
		debug_nodes.append(DebugDrawTool.line(obj_pos, obj_pos + nodes[i], colors[i]))

func draw_debug_circles(obj_pos: Vector3, radii: Array, colors: Array) -> void:
	for i in radii.size():
		debug_nodes.append(DebugDrawTool.circle(obj_pos, radii[i], colors[i]))

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
		return calc_top_speed(new_speed)

func move_camera(new_position: Vector3) -> void:
	camera.global_transform.origin = new_position

func shift_gear(state: CarStates, velocity_y: float, dir_y: float) -> CarStates:
	match(state):
		CarStates.DRIVE:
			if (velocity_y == 0.0 and dir_y == 0.0):
				state = CarStates.NEUTRAL
				print("New State: NEUTRAL")
			if (velocity_y < 0.0 and dir_y > 0.0):
				state = CarStates.REVERSE
				print("New State: REVERSE")
		CarStates.NEUTRAL:
			if (dir_y < 0.0):
				state = CarStates.DRIVE
				print("New State: DRIVE")
			elif (dir_y > 0.0):
				state = CarStates.REVERSE
				print("New State: REVERSE")
		CarStates.REVERSE:
			if (dir_y <= 0.0):
				state = CarStates.NEUTRAL
				print("New State: NEUTRAL")

	return state

func get_gear_speed(state: CarStates) -> void:
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
	var steering_x = player_turn_dir * cos(angle)
	var steering_y = player_accel_dir * sin(angle)
	# Turning is perpendicular to and dependent on the direction the car is facing
	var steering = (steering_x + steering_y) * turn_strength

	return steering 

func calc_friction(obj_velocity: Vector3) -> Vector3:
	var frictional_force = obj_velocity * friction
	var drag_force = obj_velocity * obj_velocity.length() * drag
	var net_friction = frictional_force + drag_force

	return net_friction

func _ready() -> void:
	var top_speed := calc_top_speed(velocity)
	print("Top Speed: ", top_speed)

func _input(event: InputEvent) -> void:
	if (event.is_pressed()):
		if (Input.is_physical_key_pressed(KEY_F)):
			is_friction_enabled = !is_friction_enabled
			print("Friction: ", is_friction_enabled)
		if (Input.is_physical_key_pressed(KEY_P)):
			is_debug_enabled = !is_debug_enabled
			print("Debug: ", is_debug_enabled)

func _physics_process(delta: float) -> void:
	# Reset debug nodes each frame to prevent clutter
	clear_debug_nodes()

	# Get raw input from the player
	var raw_dir := Input.get_vector("turn_left", "turn_right", "brake", "accelerate")
	var input_dir := Vector3(raw_dir.x, 0.0, -raw_dir.y)

	# Calculate forward movement based on the direction the car is facing
	var forward_dir := -basis.z
	if (is_handbrake_applied):
		forward_dir = velocity.normalized()
	var accel_dir := input_dir.z * basis.z
	var turn_dir := input_dir.x * basis.x 

	var prev_velocity = velocity.dot(forward_dir)
	var prev_state = curr_state
	curr_state = shift_gear(curr_state, prev_velocity, input_dir.z)
	if (curr_state != prev_state):
		get_gear_speed(curr_state)

	#!! BUG: Turning causes a small amount of friction to be applied to the car every frame, even when net friction is 0
	var wheel_steering := Vector3.ZERO
	var front_wheel := global_position + (forward_dir * (scale.z/2.0))
	var back_wheel := global_position - (forward_dir * (scale.z/2.0))
	if (prev_velocity != 0.0 && !turn_dir.is_zero_approx()):
		wheel_steering = calc_steering(turn_angle, turn_dir, accel_dir)
		if (curr_state != CarStates.REVERSE && input_dir.z > 0.0 && is_handbrake_applied == false):
			print("Drift Time")
			is_handbrake_applied = true
	elif (is_handbrake_applied == true):
		is_handbrake_applied = false
		acceleration_angle = 0.0

	# Set velocity for each pair of wheels depending on their role
	front_wheel += (velocity + wheel_steering) * delta
	back_wheel += velocity * delta
	var new_heading = (front_wheel - back_wheel).normalized()

	# Calculate player velocity
	var net_friction = Vector3.ZERO
	if (is_friction_enabled):
		net_friction = calc_friction(velocity)
	var acceleration_force = max_acceleration * (accel_dir + wheel_steering).normalized() * delta
	var net_friction_force = net_friction * delta
	var new_velocity = (new_heading * prev_velocity) + acceleration_force + net_friction_force

	velocity = new_velocity
	print("Velocity: ", velocity.dot(forward_dir))
	
	var curr_velocity = velocity.dot(forward_dir)
	if (!accel_dir.is_zero_approx()):
		if (input_dir.z < 0.0 && curr_velocity > state_max):
			velocity = velocity.normalized() * abs(state_max)
		# Ensure that the car does not start at velocity of 0 when shifting to drive
		elif (input_dir.z > 0.0 && curr_velocity < state_min):
			velocity = velocity.normalized() * abs(state_min)

	move_camera(camera_offset + global_position + Vector3(0.0, (velocity.length()/max_speed) * 5.0, 0.0))
	#move_camera((1.0 * camera_offset) + global_position)

	move_and_slide()
	if (curr_velocity > 0.0):
		look_at(global_position + velocity)
	elif (curr_velocity < 0.0):
		look_at(global_position - velocity)

	if (is_debug_enabled):
		var debug_obj := [
			#velocity,
			#handbrake_velocity,
			#relative_input,
			forward_dir,
			acceleration_force,
			#accel_dir,
			#turn_dir,
			#wheel_steering,
			#-global_transform.basis.x.normalized(),
			#-global_transform.basis.z.normalized(),
		]

		draw_debug_lines(global_position + Vector3(0.0,5.0,0.0),debug_obj,debug_colors)

		# Display the front and back wheels
		draw_debug_lines(global_position + Vector3(0.0,5.0,0.0),[front_wheel - global_position],[Color.GRAY])
		draw_debug_lines(global_position + Vector3(0.0,5.0,0.0),[back_wheel - global_position],[Color.WHITE])

		# Display turning circles
		var turn_velocity = velocity.length()/turn_strength
		draw_debug_circles(global_position + (basis.x * turn_velocity),[turn_velocity],[Color.YELLOW])
		draw_debug_circles(global_position - (basis.x * turn_velocity),[turn_velocity],[Color.GREEN])