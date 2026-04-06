extends Node3D

@export var default_distance := 25.0
@export var min_distance     :=  5.0
@export var max_distance     := 100.0
@export var height_offset    := 3.0
@export var zoom_speed       :=  2.0
@export var orbit_speed      := 0.005

@export var default_pitch := -15.0  # degrees
@export var min_pitch     := -75.0
@export var max_pitch     :=  -5.0

var _markers: Node3D
var _target:  Node3D
var _distance: float
var _yaw:      float = 0.0
var _pitch:    float

func _ready():
	# RobotMarkers is a sibling under GlobalMapScene
	if get_parent().has_node("RobotMarkers"):
		_markers = get_parent().get_node("RobotMarkers") as Node3D
	else:
		push_warning("CameraRig: no RobotMarkers under " + get_parent().name)
	_distance = default_distance
	_pitch    = deg_to_rad(default_pitch)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func follow_target(node: Node3D) -> void:
	"""Call this from your map code as soon as you spawn/update the robot marker."""
	_target = node


func reset_view() -> void:
	_distance = default_distance
	_yaw      = 0.0
	_pitch    = deg_to_rad(default_pitch)


func _unhandled_input(event):
	# Orbit around target with right-mouse drag
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw   -= event.relative.x * orbit_speed
		_pitch  = clamp(
			_pitch - event.relative.y * orbit_speed,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

	# Dolly‐zoom in/out with wheel
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = max(min_distance, _distance - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = min(max_distance, _distance + zoom_speed)


func _process(_delta):
	# If nothing set yet, auto-follow the first child of RobotMarkers
	if not _target and _markers and _markers.get_child_count() > 0:
		follow_target(_markers.get_child(0))
	if not _target:
		return

	# 1) Put the rig at the robot’s world position
	var base_pos = _target.global_transform.origin
	base_pos.y += height_offset
	global_transform.origin = base_pos

	# 2) Compute camera offset in local space
	var rot = Basis()
	rot = rot.rotated(Vector3.UP,    _yaw)
	rot = rot.rotated(Vector3.RIGHT, _pitch)
	var offset = rot * Vector3(0, 0, _distance)

	# 3) Place & aim the child camera
	$ChaseCam.transform.origin = offset
	$ChaseCam.look_at(global_transform.origin, Vector3.UP)
