extends Node3D

@export var mesh_size: int = 64
@export var noise_frequency: float = 0.02
@export var height_multiplier: float = 0.05
@export var rendering_radius: int = 512

var wireframe_shader_material: ShaderMaterial = preload("res://wireframe_shader_material.tres")

var noise: FastNoiseLite
var current_camera_position = null
var visible_mesh_instances: Dictionary = {}

# Init Perlin noise generator
func init_noise():
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency

# Gets noise data for mesh
func get_noise_data(offset: Vector2):
	noise.offset = Vector3(mesh_size * offset.x, mesh_size * offset.y, 0)
	return noise.get_image(mesh_size + 1, mesh_size + 1, false, false, false).data.data

# Finds the surface normal given 3 vertices.
func get_triangle_normal(a: Vector3, b: Vector3, c: Vector3):
	return (b - a).cross(c - a).normalized()

# Return items present only in arr1
func difference(arr1: Array, arr2: Array):
	var only_in_arr1 = []
	for v in arr1:
		if not (v in arr2):
			only_in_arr1.append(v)
	return only_in_arr1

# Generates single mesh
func generate_terrain_mesh(offset: Vector2):
	var mesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	
	var verts_normals: Array[PackedVector3Array] = []
	verts_normals.resize((mesh_size + 1) ** 2)
	
	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	
	var noise_data = get_noise_data(offset)
	
	# TODO: refactor to separated functions
	
	for i in range(mesh_size + 1):
		for j in range(mesh_size + 1):
			verts.append(Vector3(j, noise_data[i * (mesh_size + 1) + j] * height_multiplier, i))
			uvs.append(Vector2(float(j) / mesh_size, float(i) / mesh_size))
			
	for i in range(mesh_size):
		for j in range(mesh_size):
			var verts_indexes = PackedInt32Array([
				i * (mesh_size + 1) + j, # top left
				i * (mesh_size + 1) + j + 1, # top right
				(i + 1) * (mesh_size + 1) + j, # bottom left
				(i + 1) * (mesh_size + 1) + j + 1 # bottom right
			])
			
			var normal1 = get_triangle_normal(
				verts[verts_indexes[0]],
				verts[verts_indexes[1]],
				verts[verts_indexes[3]]
			)
			
			var normal2 = get_triangle_normal(
				verts[verts_indexes[0]],
				verts[verts_indexes[3]],
				verts[verts_indexes[2]]
			)
			
			verts_normals[verts_indexes[0]].append_array([normal1, normal2])
			verts_normals[verts_indexes[1]].append(normal1)
			verts_normals[verts_indexes[2]].append(normal2)
			verts_normals[verts_indexes[3]].append_array([normal1, normal2])
			
			indices.append_array([
				# First triangle, clockwise
				verts_indexes[0], verts_indexes[1], verts_indexes[3],
				
				# Second triangle, clockwise
				verts_indexes[0], verts_indexes[3],	verts_indexes[2]
			])
			
	for i in range((mesh_size + 1) ** 2):
		var normal = Vector3(0, 0, 0)
		for j in range(verts_normals[i].size()):
			normal += verts_normals[i][j]
		normals.append(normal.normalized())
				
	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_INDEX] = indices
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	
	return mesh
	
# Generates single mesh instance
func generate_terrain_mesh_instance(offset: Vector2):
	var mesh = generate_terrain_mesh(offset)
	mesh.surface_set_material(0, wireframe_shader_material)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.position.x = offset.x * mesh_size
	mesh_instance.position.z = offset.y * mesh_size
	mesh_instance.mesh = mesh
	
	return mesh_instance
	
# Generates terrain mesh instance for each offset
# TODO: types
func generate_visible_terrain_mesh_instances(visible_terrain_mesh_instances_offsets):
	for offset in visible_terrain_mesh_instances_offsets:
		visible_mesh_instances[offset] = generate_terrain_mesh_instance(offset)
		add_child(visible_mesh_instances[offset])
		
# Removes unused mesh instances
func remove_visible_terrain_mesh_instances(visible_terrain_mesh_instances_offsets):
	for offset in visible_terrain_mesh_instances_offsets:
		visible_mesh_instances[offset].queue_free()
		visible_mesh_instances.erase(offset)
			
func get_visible_terrain_mesh_instances_offsets(position: Vector3):
	var offsets = PackedVector2Array()
	
	for i in range(
		int(position.z / mesh_size - rendering_radius / mesh_size),
		int(position.z / mesh_size + rendering_radius / mesh_size + 1)
	):
		for j in range(
			int(position.x / mesh_size - rendering_radius / mesh_size),
			int(position.x / mesh_size + rendering_radius / mesh_size + 1)
		):
			# TODO: more precise radius formula
			var distance_to_center_of_mesh_instance = Vector2(
				position.x - j * mesh_size,
				position.z - i * mesh_size
			).length()
			
			if distance_to_center_of_mesh_instance <= rendering_radius:
				offsets.append(Vector2(j, i))
	
	return offsets

func _ready():
	init_noise()

func _process(delta: float):
	pass

func _on_camera_position_changed(position):
	if current_camera_position != null:
		var previous_offsets = get_visible_terrain_mesh_instances_offsets(current_camera_position)
		var current_offsets = get_visible_terrain_mesh_instances_offsets(position)
		
		var offsets_to_remove = difference(previous_offsets, current_offsets)
		var offsets_to_add = difference(current_offsets, previous_offsets)
		
		generate_visible_terrain_mesh_instances(offsets_to_add)
		remove_visible_terrain_mesh_instances(offsets_to_remove)
	else:
		var offsets = get_visible_terrain_mesh_instances_offsets(position)
		generate_visible_terrain_mesh_instances(offsets)
	
	current_camera_position = position
