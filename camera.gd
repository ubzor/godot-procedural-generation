extends Marker3D

@export var min_distance: float = 10.0
@export var max_distance: float = 100.0
@export var initial_distance: float = 20.0
@export var zoom_sensitivity: float = 200.0
@export var move_speed: float = 1.0
@export var rotation_sensitivity: float = 0.00004
@export var min_rotation_angle: float = -PI/2
@export var max_rotation_angle: float = -PI/8
@export var initial_position: Vector3 = Vector3(0, 0, 0)
@export var initial_rotation: Vector3 = Vector3(-PI/4, 0, 0)

var is_rotating: bool = false

signal position_changed(position: Vector3)

func get_forward_vector() -> Vector3:
	return Vector3(
		-global_transform.basis.z.x,
		0.0,
		-global_transform.basis.z.z
	).normalized()
	
func get_right_vector() -> Vector3:
	return get_forward_vector().rotated(Vector3(0, 1, 0), -PI/2)

func _ready() -> void:
	position = initial_position
	rotation = initial_rotation
	$Camera3D.position.z = initial_distance
	position_changed.emit(position)

func _process(delta: float) -> void:
	# Move
	if Input.is_action_pressed("move_forward") \
	or Input.is_action_pressed("move_back") \
	or Input.is_action_pressed("move_left") \
	or Input.is_action_pressed("move_right"):
		var speed = $Camera3D.position.z * move_speed * delta
		
		if Input.is_action_pressed("move_forward"):
			position += get_forward_vector() * speed
		if Input.is_action_pressed("move_back"):
			position -= get_forward_vector() * speed
		if Input.is_action_pressed("move_left"):
			position -= get_right_vector() * speed
		if Input.is_action_pressed("move_right"):
			position += get_right_vector() * speed
	
		position_changed.emit(position)
	
	# Zoom in/out
	var mouse_wheel_up = 1 if Input.is_action_just_released("zoom_out") else 0
	var mouse_wheel_down = -1 if Input.is_action_just_released("zoom_in") else 0
	var mouse_wheel_value = mouse_wheel_up + mouse_wheel_down
	
	if mouse_wheel_value > 0:
		if $Camera3D.position.z + delta * zoom_sensitivity >= max_distance:
			$Camera3D.position.z = max_distance
		else:
			$Camera3D.position.z += delta * zoom_sensitivity
	elif mouse_wheel_value < 0:
		if $Camera3D.position.z - delta * zoom_sensitivity <= min_distance:
			$Camera3D.position.z = min_distance
		else:
			$Camera3D.position.z -= delta * zoom_sensitivity

func _input(event) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			# set camera is rotating
			MouseButton.MOUSE_BUTTON_RIGHT:
				is_rotating = event.pressed
	elif event is InputEventMouseMotion:
		# Rotate camera
		if is_rotating:
			rotation.y -= event.velocity.x * rotation_sensitivity
			rotation.x = clamp(
				rotation.x - event.velocity.y * rotation_sensitivity,
				min_rotation_angle,
				max_rotation_angle
			)
