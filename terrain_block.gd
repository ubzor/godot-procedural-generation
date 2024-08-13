extends Node3D

@export var wireframe_shader_material: ShaderMaterial

@export var height_multiplier: float = 0.05
@export var noise_frequency: float = 0.02
@export var offset: Vector2

var size: float
var segments_count: int

var noise: FastNoiseLite = FastNoiseLite.new()
var thread: Thread

# Gets noise data for mesh
func get_noise_data() -> PackedByteArray:
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.02
	noise.offset = Vector3(segments_count * offset.x, segments_count * offset.y, 0)
	
	return noise.get_image(segments_count + 1, segments_count + 1, false, false, false).data.data
	
# Finds the surface normal given 3 vertices.
func get_triangle_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (b - a).cross(c - a).normalized()
	
# Generates single mesh
func generate_terrain_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	
	var verts_normals: Array[PackedVector3Array] = []
	verts_normals.resize((segments_count + 1) ** 2)
	
	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	
	var noise_data = get_noise_data()
	
	# TODO: refactor to separated functions
	
	for i in range(segments_count + 1):
		for j in range(segments_count + 1):
			verts.append(Vector3(j, noise_data[i * (segments_count + 1) + j] * height_multiplier, i))
			uvs.append(Vector2(float(j) / segments_count, float(i) / segments_count))
			
	for i in range(segments_count):
		for j in range(segments_count):
			var verts_indexes = PackedInt32Array([
				i * (segments_count + 1) + j, # top left
				i * (segments_count + 1) + j + 1, # top right
				(i + 1) * (segments_count + 1) + j, # bottom left
				(i + 1) * (segments_count + 1) + j + 1 # bottom right
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
			
	for i in range((segments_count + 1) ** 2):
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
func generate_terrain_mesh_instance() -> void:
	var mesh = generate_terrain_mesh()
	mesh.surface_set_material(0, wireframe_shader_material)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	
	call_deferred("add_terrain_mesh_to_scene", mesh_instance)
	
func add_terrain_mesh_to_scene(mesh_instance) -> void:
	call_deferred("add_child", mesh_instance)
	
	visible = false
	position.x = offset.x * size
	position.z = offset.y * size
	scale = Vector3(1, 1, 1) * (size / float(segments_count))
	
	await get_tree().create_timer(0.01).timeout
	visible = true

func _ready() -> void:
	size = get_parent().terrain_block_size
	segments_count = get_parent().terrain_block_segments_count
	
	thread = Thread.new()
	thread.start(generate_terrain_mesh_instance)
	
func _process(_delta: float) -> void:
	pass

func _exit_tree() -> void:
	thread.wait_to_finish()
