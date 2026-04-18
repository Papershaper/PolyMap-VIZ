extends Node3D

# Define grid parameters (will be updated dynamically)
var cell_size: float = 1.0
var current_map_cols: int = 0
var current_map_rows: int = 0
var latest_robot_poses: Dictionary = {}

const MARKER_HEIGHT := 2.0
const MARKER_BASE_RADIUS := 1.0

@onready var grid = $Grid
@onready var map_floor = $MapFloor
@onready var robot_markers = $RobotMarkers
@onready var camera_rig = $CameraRig


func _ready():
	camera_rig.set_markers_container(robot_markers)

func clear_map() -> void:
	# Clear only the children of the Grid node.
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

func update_robot_marker(robot_id: String, pose_data: Dictionary) -> void:
	latest_robot_poses[robot_id] = pose_data.duplicate(true)
	var marker = _get_or_create_marker(robot_id)
	_apply_pose_to_marker(marker, pose_data)
	camera_rig.follow_target(marker)
	print("Updated marker for robot:", robot_id, "at position", marker.position, "with rotation", marker.rotation)

func update_map(data: Dictionary) -> void:
	var map_array = data.get("global_map", [])
	var rows = map_array.size()
	if rows == 0:
		return
	var cols = map_array[0].size()
	current_map_rows = rows
	current_map_cols = cols

	# clear previous
	clear_map()
	_update_map_floor()

	# build single MultiMesh for all cells
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors     = true
	mm.instance_count   = rows * cols

	# one flat tile for every cell
	var mesh = BoxMesh.new()
	mesh.size = Vector3(cell_size, 1.0, cell_size)
	mm.mesh = mesh

	# instance container
	var inst = MultiMeshInstance3D.new()
	inst.multimesh = mm
	
	# 5) Give it a shader that uses vertex-colors + glow
	var shader = Shader.new()
	shader.code = """
		shader_type spatial;
		render_mode unshaded, cull_disabled, depth_prepass_alpha;

		uniform float glow_boost : hint_range(0.0, 10.0) = 2.0;

		void fragment() {
			ALBEDO   = COLOR.rgb;
			ALPHA    = COLOR.a;
			EMISSION = COLOR.rgb * glow_boost;
		}
	"""

	# material that uses per-instance colours + alpha
	var mat = ShaderMaterial.new()
	mat.shader = shader
	inst.material_override = mat

	# Predefine obstacle‐height range (in world units)
	var obs_min_h = 0.5
	var obs_max_h = 2.0
	
	# populate transforms + colours
	var idx = 0
	for row in range(rows):
		for col in range(cols):
			# position each cell, flipping Y → Z so row 0 is at back
			var t = Transform3D.IDENTITY
			var flipped = rows - 1 - row
			t.origin = Vector3(col * cell_size, 0, flipped * cell_size)
			mm.set_instance_transform(idx, t)

			# scale
			var raw = int(map_array[row][col])
			var scale_vec = Vector3.ONE

			if raw == 128:
				# unknown → shrink to 80%
				scale_vec = Vector3(0.8, 0.8, 0.8)
			elif raw < 128:
				# free → very flat
				scale_vec = Vector3(1, 0.1, 1)
			else:
				# occupied → height between obs_min_h…obs_max_h
				var norm = float(raw - 129) / float(255 - 129)
				var h = lerp(obs_min_h, obs_max_h, norm)
				scale_vec = Vector3(1, h, 1)
			# apply local-scale
			t = t.scaled_local(scale_vec)

			# c) write transform & colour
			mm.set_instance_transform(idx, t)
			mm.set_instance_color(idx, byte_to_color(raw))
			idx += 1

	grid.add_child(inst)
	_reproject_all_robot_markers()
	print("Map updated: ", cols, "×", rows)


func reset_view() -> void:
	camera_rig.reset_view()
		
func byte_to_color(v: int) -> Color:
	# 128 = unknown slate‐gray
	if v == 128:
		return Color(0, 0, 0, 1.0)

	var t: float
	var r0:int; var g0:int; var b0:int
	var r1:int; var g1:int; var b1:int
	var a0:int = 0; var a1:int = 255

	if v < 81:
		t = v / 80.0
		r0 = 17;  g0 = 22;  b0 = 66    # indigo
		r1 = 0;   g1 = 191; b1 = 255   # azure
		a1 = 50                      # α→0.2
	elif v < 128:
		t = (v - 81) / 47.0
		r0 = 0;   g0 = 191; b0 = 255   # azure
		r1 = 0;   g1 = 255; b1 = 160   # teal
		a0 = 50;  a1 = 100             # α 0.2→0.4
	elif v < 201:
		t = (v - 129) / 71.0
		r0 = 0;   g0 = 255; b0 = 160   # teal
		r1 = 122; g1 = 255; b1 = 0     # lime-neon
		a0 = 128; a1 = 178             # α 0.5→0.7
	else:
		t = (v - 201) / 54.0
		r0 = 122; g0 = 255; b0 = 0     # lime-neon
		r1 = 255; g1 = 145; b1 = 0     # hot-amber
		a0 = 204; a1 = 255             # α 0.8→1.0

	# normalize & lerp
	var c_start = Color(r0/255.0, g0/255.0, b0/255.0)
	var c_end   = Color(r1/255.0, g1/255.0, b1/255.0)
	var base    = c_start.lerp(c_end, t)
	var alpha   = lerp(a0, a1, t) / 255.0
	return Color(base.r, base.g, base.b, alpha)


func occupancy_to_colour(val: int) -> Color:
	# val ∈ [0..255], 128 = unknown
	# TODO: adjust these mappings to taste!
	if val == 128:
		# unexplored: light grey, very transparent
		return Color(0.5,0.5,0.5, 0.1)
	elif val < 128:
		# free cells: map 127→0  → alpha [0.1..0.5], brightness white→grey
		var norm = float(127 - val) / 127.0
		var alpha = lerp(0.1, 0.5, norm)
		var grey  = lerp(1.0, 0.7, norm)
		return Color(grey, grey, grey, alpha)
	else:
		# occupied: map 129→255 → alpha [0.5..1.0], brightness grey→black
		var norm = float(val - 129) / float(255 - 129)
		var alpha = lerp(0.5, 1.0, norm)
		var grey  = lerp(0.7, 0.0, norm)
		return Color(grey, grey, grey, alpha)


func _update_map_floor() -> void:
	if current_map_rows <= 0 or current_map_cols <= 0:
		return
	map_floor.size = Vector3(current_map_cols * cell_size, 0.05, current_map_rows * cell_size)
	map_floor.position = Vector3(current_map_cols * cell_size / 2.0, -0.5, current_map_rows * cell_size / 2.0)


func _reproject_all_robot_markers() -> void:
	for robot_id in latest_robot_poses.keys():
		var marker = _get_or_create_marker(robot_id)
		_apply_pose_to_marker(marker, latest_robot_poses[robot_id])


func _get_or_create_marker(robot_id: String) -> MeshInstance3D:
	var marker = robot_markers.get_node_or_null(robot_id) as MeshInstance3D
	if marker != null:
		return marker

	marker = MeshInstance3D.new()
	marker.name = robot_id

	var cone = CylinderMesh.new()
	cone.height = MARKER_HEIGHT
	cone.top_radius = 0.0
	cone.bottom_radius = MARKER_BASE_RADIUS
	marker.mesh = cone

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0.5, 0)
	marker.material_override = material

	robot_markers.add_child(marker)
	return marker


func _apply_pose_to_marker(marker: MeshInstance3D, pose_data: Dictionary) -> void:
	marker.position = _pose_to_world_position(pose_data)
	var orientation_rad = pose_data.get("orientation_rad", 0.0)
	marker.rotation = Vector3(-PI / 2, orientation_rad - PI / 2, 0)
	marker.position.y += MARKER_HEIGHT / 2.0


func _pose_to_world_position(pose_data: Dictionary) -> Vector3:
	var grid_x = float(pose_data.get("gridX", 0))
	var grid_y = float(pose_data.get("gridY", 0))
	var z = grid_y
	if current_map_rows > 0:
		z = current_map_rows - 1 - grid_y
	return Vector3(grid_x * cell_size + cell_size / 2.0, 0, z * cell_size + cell_size / 2.0)
		
