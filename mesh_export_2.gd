extends Node

func _ready() -> void:
	# Path to your robot scene.
	var robot_scene_path = "res://robot_minone.tscn"
	var packed_scene = load(robot_scene_path)
	if not packed_scene:
		push_error("Failed to load robot scene at: " + robot_scene_path)
		get_tree().quit()
		return
	
	# Instance the robot scene.
	var robot_instance = packed_scene.instantiate()
	# Add to the tree so global transforms are updated.
	add_child(robot_instance)
	
	# Combine all meshes.
	var combined_mesh = combine_meshes(robot_instance)
	if combined_mesh:
		var save_path = "res://robot_mesh.tres"
		var err = ResourceSaver.save(save_path, combined_mesh)
		if err == OK:
			print("Combined mesh saved successfully to ", save_path)
		else:
			push_error("Error saving mesh resource: " + str(err))
	else:
		push_error("No MeshInstance3D nodes found to combine!")
	
	# Clean up the temporary instance.
	remove_child(robot_instance)
	robot_instance.queue_free()
	
	# Quit the scene (optional if running as one-shot tool).
	get_tree().quit()


# Recursive helper: collects all MeshInstance3D nodes.
func get_mesh_instances(node: Node) -> Array:
	var instances = []
	if node is MeshInstance3D:
		instances.append(node)
	for child in node.get_children():
		instances += get_mesh_instances(child)
	return instances


# Combines meshes from all MeshInstance3D nodes into one ArrayMesh.
func combine_meshes(root: Node) -> ArrayMesh:
	var combined_mesh = ArrayMesh.new()
	var mesh_instances = get_mesh_instances(root)
	if mesh_instances.size() == 0:
		return null
	
	# Loop through each MeshInstance3D.
	for mi in mesh_instances:
		if not mi.mesh:
			continue
		var surface_count = mi.mesh.get_surface_count()
		for surface in range(surface_count):
			# Get the arrays for the surface.
			var arrays = mi.mesh.surface_get_arrays(surface)
			
			# Transform vertices to global space using the node's global transform.
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if vertices:
				for i in range(vertices.size()):
					# Use the multiplication operator to transform the vertex.
					vertices[i] = mi.global_transform * vertices[i]
			
			# Transform normals properly using the Basis multiplication operator.
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			if normals:
				for i in range(normals.size()):
					normals[i] = (mi.global_transform.basis * normals[i]).normalized()
			
			# Get the primitive type (e.g., TRIANGLES) and add the surface.
			var prim_type = mi.mesh.surface_get_primitive_type(surface)
			combined_mesh.add_surface_from_arrays(prim_type, arrays)
	
	return combined_mesh
