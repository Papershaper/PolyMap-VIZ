extends Node3D

# Define grid parameters (will be updated dynamically)
var grid_width: int = 20    # number of cells along x
var grid_height: int = 20   # number of cells along z
var cell_size: float = 1.0
# Adjust these limits as needed.
var min_fov: float = 10.0
var max_fov: float = 90.0
var zoom_step: float = 5.0

func _ready():
	# Optionally, initialize or wait for the first update.
	pass

func clear_map() -> void:
	# Clear only the children of the Grid node.
	for child in $Grid.get_children():
		$Grid.remove_child(child)
		child.queue_free()

func update_robot_marker(robot_id: String, pose_data: Dictionary) -> void:
	# Ensure a container node for robot markers exists. We'll call it "RobotMarkers"
	var markers = get_node_or_null("RobotMarkers")
	if markers == null:
		markers = Node3D.new()
		markers.name = "RobotMarkers"
		add_child(markers)

	# Remove any existing marker for this robot_id.
	var existing_marker = markers.get_node_or_null(robot_id)
	if existing_marker:
		markers.remove_child(existing_marker)
		existing_marker.queue_free()

	# Create a new MeshInstance3D for the marker.
	var marker = MeshInstance3D.new()
	marker.name = robot_id  # so we can look it up later

	# Create a ConeMesh as a simple visual indicator.
	var cone = CylinderMesh.new()
	cone.height = 2.0             # Height of the cone.
	cone.top_radius = 0.0          # Tip of the cone.
	cone.bottom_radius = 1.0       # Base radius.
	marker.mesh = cone

	# Create a simple material to make the marker distinct.
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0.5, 0)  # Orange color, for example.
	marker.material_override = material

	# Calculate the position using gridX and gridY from the telemetry data.
	# Assuming that gridX and gridY are provided in telemetry and correspond to grid indices.
	var grid_x = pose_data.get("gridX", 0)
	var grid_y = pose_data.get("gridY", 0)
	# Position the marker; you might want to use the center of the cell by adding half of cell_size.
	var rows = 120  #/* the same map_array.size() you used in update_map */;
	var flipped_grid_y = rows - 1 - grid_y
	var pos = Vector3(grid_x * cell_size + cell_size / 2.0, 0, flipped_grid_y * cell_size + cell_size / 2.0)
	marker.position = pos

	# Set the marker's rotation.
	# First, rotate -90° around the X axis so the cone's tip (originally up) points forward (-Z).
	# Then, rotate around Y by the telemetry orientation (orientation_rad).
	var orientation_rad = pose_data.get("orientation_rad", 0.0)
	marker.rotation = Vector3(-PI/2, orientation_rad -PI/2, 0)
	
	# Optionally, adjust the height so the cone appears above the map.
	# For example, raise it by half its height:
	marker.position.y += cone.height / 2.0

	# Add the marker to the markers container.
	markers.add_child(marker)
	print("Updated marker for robot:", robot_id, "at position", pos, "with rotation", marker.rotation)

func update_map(data: Dictionary) -> void:
	var map_array = data.get("global_map", [])
	var rows = map_array.size()
	if rows == 0:
		return
	var cols = map_array[0].size()

	# clear previous
	clear_map()

	# build MultiMesh
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors     = true
	mm.instance_count   = rows * cols

	# one flat tile for every cell
	var mesh = BoxMesh.new()
	mesh.size = Vector3(cell_size, 0.1, cell_size)
	mm.mesh = mesh

	# instance container
	var inst = MultiMeshInstance3D.new()
	inst.multimesh = mm

	# material that uses per-instance colours + alpha
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	#mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	inst.material_override = mat

	# populate transforms + colours
	var idx = 0
	for row in range(rows):
		for col in range(cols):
			var t = Transform3D.IDENTITY
			var flipped = rows - 1 - row
			t.origin = Vector3(col * cell_size, 0, flipped * cell_size)
			mm.set_instance_transform(idx, t)

			var raw = int(map_array[row][col])
			mm.set_instance_color(idx, occupancy_to_colour(raw))
			idx += 1

	$Grid.add_child(inst)
	print("Map updated: ", cols, "×", rows)


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
		



func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Check if the event occurred over the viewport.
		# You might want to check the global mouse position if you have multiple viewports.
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_out()

func zoom_in() -> void:
	# Decrease FOV to zoom in, clamping to a minimum value.
	$Camera3D.fov = max(min_fov, $Camera3D.fov - zoom_step)
	# print("Zooming in: FOV =", $Camera3D.fov)

func zoom_out() -> void:
	# Increase FOV to zoom out, clamping to a maximum value.
	$Camera3D.fov = min(max_fov, $Camera3D.fov + zoom_step)
	# print("Zooming out: FOV =", $Camera3D.fov)
