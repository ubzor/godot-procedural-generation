extends Node3D

@export var mesh_size: int = 64
@export var noise_frequency: float = 0.02
@export var height_multiplier: float = 0.05
@export var rendering_radius: float = 256.0

var TerrainBlock = preload("res://terrain_block.tscn")
var wireframe_shader_material: ShaderMaterial = preload("res://wireframe_shader_material.tres")

var noise: FastNoiseLite

var generating_terrain_blocks_thread: Thread
var calculating_terrain_blocks_offsets_thread: Thread
var mutex: Mutex = Mutex.new()

var terrain_blocks: Dictionary = {}
var terrain_blocks_offsets_to_add: PackedVector2Array = []
var terrain_blocks_offsets_to_remove: PackedVector2Array = []
var terrain_blocks_offsets_rendering: PackedVector2Array = []

# Init Perlin noise generator
func init_noise():
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency

# Return items present only in arr1
func difference(arr1: Array, arr2: Array):
	var only_in_arr1 = []
	for v in arr1:
		if not (v in arr2):
			only_in_arr1.append(v)
	return only_in_arr1
		
# Removes unused mesh instances
func remove_visible_terrain_mesh_instances(visible_terrain_mesh_instances_offsets):
	mutex.lock()
	
	for offset in visible_terrain_mesh_instances_offsets:
		terrain_blocks[offset].queue_free()
		terrain_blocks.erase(offset)
		
	terrain_blocks_offsets_to_remove = []
	
	mutex.unlock()
			
func get_visible_terrain_mesh_instances_offsets(camera_position: Vector3) -> PackedVector2Array:
	var offsets = PackedVector2Array()
	
	for i in range(
		int(camera_position.z / float(mesh_size) - rendering_radius / mesh_size),
		int(camera_position.z / float(mesh_size) + rendering_radius / mesh_size + 1)
	):
		for j in range(
			int(camera_position.x / float(mesh_size) - rendering_radius / mesh_size),
			int(camera_position.x / float(mesh_size) + rendering_radius / mesh_size + 1)
		):
			# TODO: more precise radius formula
			var distance_to_center_of_mesh_instance = Vector2(
				camera_position.x - j * mesh_size,
				camera_position.z - i * mesh_size
			).length()
			
			if distance_to_center_of_mesh_instance <= rendering_radius:
				offsets.append(Vector2(j, i))
	
	return offsets
	
func calculate_terrain_blocks_offsets(camera_position):
	mutex.lock()
	
	var rendered_offsets: PackedVector2Array = terrain_blocks.keys()
	var current_offsets = get_visible_terrain_mesh_instances_offsets(camera_position)
	
	var offsets_to_add = difference(current_offsets, rendered_offsets)
	var offsets_to_remove = difference(rendered_offsets, current_offsets)
	
	var new_offsets_to_add = difference(offsets_to_add, terrain_blocks_offsets_to_add)
	terrain_blocks_offsets_to_add.append_array(new_offsets_to_add)
	
	var new_offsets_to_remove = difference(offsets_to_remove, terrain_blocks_offsets_to_remove)
	terrain_blocks_offsets_to_remove.append_array(new_offsets_to_remove)

	mutex.unlock()
	
func generate_terrain_blocks():
	mutex.lock()
	var offset = terrain_blocks_offsets_to_add[0]
	terrain_blocks_offsets_rendering.append(offset)
	mutex.unlock()
	
	var terrain_block = TerrainBlock.instantiate()
	terrain_block.noise = noise
	terrain_block.wireframe_shader_material = wireframe_shader_material
	terrain_block.mesh_size = mesh_size
	terrain_block.height_multiplier = height_multiplier
	terrain_block.offset = offset
	
	mutex.lock()
	terrain_blocks[offset] = terrain_block
	terrain_blocks_offsets_rendering = []
	terrain_blocks_offsets_to_add.remove_at(0)
	mutex.unlock()
	
	call_deferred("add_child", terrain_block)

func _ready():
	init_noise()
	
func _process(_delta: float):
	if (
		(!generating_terrain_blocks_thread or !generating_terrain_blocks_thread.is_alive())
		and terrain_blocks_offsets_to_add.size()
		and !terrain_blocks_offsets_rendering.size()
	):
		generating_terrain_blocks_thread = Thread.new()
		generating_terrain_blocks_thread.start(generate_terrain_blocks)
		generating_terrain_blocks_thread.wait_to_finish()
		
	remove_visible_terrain_mesh_instances(terrain_blocks_offsets_to_remove)
	
	# Prints FPS in console
	print(Engine.get_frames_per_second())
		
func _on_camera_position_changed(camera_position):
	if !calculating_terrain_blocks_offsets_thread or !calculating_terrain_blocks_offsets_thread.is_alive():
		calculating_terrain_blocks_offsets_thread = Thread.new()
		calculating_terrain_blocks_offsets_thread.start(calculate_terrain_blocks_offsets.bind(camera_position))
		calculating_terrain_blocks_offsets_thread.wait_to_finish()
	
func _exit_tree():
	generating_terrain_blocks_thread.wait_to_finish()
	calculating_terrain_blocks_offsets_thread.wait_to_finish()
