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

func update_map(data: Dictionary) -> void:
	# Extract the 2D array from the received data.
	var map_array = data["global_map"]
	
	# Update grid dimensions.
	grid_height = map_array.size()
	if grid_height > 0:
		grid_width = map_array[0].size()
	else:
		grid_width = 0
	
	# Clear only the children of the Grid node.
	for child in $Grid.get_children():
		$Grid.remove_child(child)
		child.queue_free()
	
	# Create a MultiMeshInstance3D for each cell type.
	var mm_unexplored = create_mm_for_cells(map_array, 255, Color(0, 0, 0))         # black thin cylinders
	var mm_explored   = create_mm_for_cells(map_array, 0, Color(0.8, 0.8, 0.8))     # flat tiles (light gray)
	var mm_obstacle   = create_mm_for_cells(map_array, 1, Color(1, 0, 0))           # tall red cylinders
	var mm_robot      = create_mm_for_cells(map_array, 2, Color(0, 1, 0))           # bright green sphere
	
	
	if mm_unexplored:
		$Grid.add_child(mm_unexplored)
	if mm_explored:
		$Grid.add_child(mm_explored)
	if mm_robot:
		$Grid.add_child(mm_robot)
	if mm_obstacle:
		$Grid.add_child(mm_obstacle)
	
	print("update_map complete: grid size =", grid_width, "x", grid_height)

# Helper function to create a MultiMeshInstance3D for cells of a given target value.
func create_mm_for_cells(map_array: Array, target_value: int, color: Color) -> MultiMeshInstance3D:
	var transforms = []
	var rows = map_array.size()
	if rows == 0:
		return null
	var cols = map_array[0].size()
	# print(map_array)
	for row in range(rows):
		for col in range(cols):
			if map_array[row][col] == target_value:
				var t = Transform3D.IDENTITY
				t.origin = Vector3(col * cell_size, 0, row * cell_size)
				transforms.append(t)
	if transforms.size() == 0:
		return null
	
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D  # Ensure 3D transforms are used.
	mm.instance_count = transforms.size()

	# Select a mesh based on the target value.
	var mesh: Mesh
	match target_value:
		255:
			# Unexplored: very thin black cylinder (e.g., height = 0.2, small radius
			mesh = CylinderMesh.new()
			mesh.top_radius = 0.5
			mesh.bottom_radius = 0.5
			mesh.height = 1.0
		0:
			# Explored/empty: flat tile (BoxMesh with low height)
			mesh = BoxMesh.new()
			mesh.size = Vector3(cell_size, 0.1, cell_size)
		2:
			# Robot: sphere (appears to float)
			mesh = SphereMesh.new()
			mesh.radius = 1.5
		1:
			# Obstacle: tall cylinder
			mesh = CylinderMesh.new()
			mesh.top_radius = 0.8
			mesh.bottom_radius = 0.8
			mesh.height = 4.0
		_:
			mesh = BoxMesh.new()
			mesh.size = Vector3(cell_size, 0.1, cell_size)
	
	mm.mesh = mesh

	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	
	var mm_instance = MultiMeshInstance3D.new()
	mm_instance.multimesh = mm
	
	# Create a simple uniform material.
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	mm_instance.material_override = material
	
	return mm_instance

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
