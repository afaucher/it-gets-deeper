extends Node3D

@export var tunnel_length: int = 2000
@export var chunk_size: int = 50
@export var tunnel_radius: float = 20.0
@export var noise_scale: float = 0.05
@export var iso_level: float = 0.0
@export var grid_size: int = 1

var noise: FastNoiseLite
var crystal_noise: FastNoiseLite
var pipe_noise: FastNoiseLite

signal generation_finished

# Tables loaded from JSON
var EDGE_VERTEX_INDICES = []
var TRIANGLE_TABLE = []

@export var view_distance: int = 1500 # How far ahead to generate (buffer for pop-in)
@export var cleanup_distance: int = 300 # How far behind to keep

var _active_chunks = {} # z_start -> MeshInstance3D
var _generating_chunks = {} # z_start -> bool (true if currently generating)

var player: Node3D

func get_generation_progress() -> float:
	if _total_chunks == 0: return 0.0
	return float(_finished_chunks) / float(_total_chunks)

func get_loaded_chunk_range() -> Vector2:
	if _active_chunks.is_empty():
		# If empty, return a signal value or just 0s, but maybe log it?
		return Vector2.ZERO
	var keys = _active_chunks.keys()
	keys.sort()
	return Vector2(keys[0], keys[-1])

func get_generating_chunk_range() -> Vector2:
	if _generating_chunks.is_empty():
		return Vector2.ZERO
	var keys = _generating_chunks.keys()
	keys.sort()
	return Vector2(keys[0], keys[-1])

func get_generating_chunk_count() -> int:
	return _generating_chunks.size()

func _ready():
	load_tables()

	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = noise_scale
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

	crystal_noise = FastNoiseLite.new()
	crystal_noise.seed = randi()
	crystal_noise.frequency = 0.05
	crystal_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	crystal_noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	crystal_noise.cellular_jitter = 1.0
	
	pipe_noise = FastNoiseLite.new()
	pipe_noise.seed = randi()
	pipe_noise.frequency = 0.1 # Higher freq for more variety
	pipe_noise.noise_type = FastNoiseLite.TYPE_VALUE
	
	# Start generation
	generate_initial_chunks()

func load_tables():
	var file = FileAccess.open("res://tables.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			var data = json.data
			EDGE_VERTEX_INDICES = data["EDGE_VERTEX_INDICES"]
			TRIANGLE_TABLE = data["TRIANGLE_TABLE"]
			print("Tables loaded successfully.")
		else:
			push_error("Failed to parse tables.json: ", json.get_error_message())
	else:
		push_error("Failed to open tables.json")

func _process(delta):
	if not player:
		player = get_node_or_null("../Player")
		return
		
	var player_z = player.global_position.z
	
	# Check for new chunks ahead
	var active_z_start = floor(player_z / chunk_size) * chunk_size
	
	# Generate ahead
	# Increased multiplier to ensure we are always generating well ahead
	for i in range(view_distance / chunk_size + 4):
		var target_z = active_z_start + i * chunk_size
		if not _active_chunks.has(target_z) and not _generating_chunks.has(target_z):
			generate_chunk_threaded(target_z)
			
	# Cleanup behind
	var cleanup_threshold = active_z_start - cleanup_distance
	var chunks_to_remove = []
	for z in _active_chunks.keys():
		if z < cleanup_threshold:
			chunks_to_remove.append(z)
			
	for z in chunks_to_remove:
		unload_chunk(z)

func unload_chunk(z_start: int):
	if _active_chunks.has(z_start):
		var mesh_inst = _active_chunks[z_start]
		mesh_inst.queue_free()
		_active_chunks.erase(z_start)

var _total_chunks: int = 0
var _finished_chunks: int = 0

func generate_initial_chunks():
	print("Starting initial generation...")
	var initial_length = 4000 # Preload massive section
	var chunks_needed = initial_length / chunk_size
	
	_total_chunks = chunks_needed
	_finished_chunks = 0
	
	for i in range(chunks_needed):
		generate_chunk_threaded(i * chunk_size)

func generate_chunk_threaded(z_start: int):
	_generating_chunks[z_start] = true
	WorkerThreadPool.add_task(Callable(self, "_generate_chunk_task").bind(z_start))

func _generate_chunk_task(z_start: int):
	var chunk_start = Time.get_ticks_msec()
	
	# Create SurfaceTool in thread
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_size = 30
	
	# Generate mesh data
	for z in range(z_start, z_start + chunk_size, grid_size):
		for y in range(-half_size, half_size, grid_size):
			for x in range(-half_size, half_size, grid_size):
				process_cube(Vector3(x, y, z), st)
	
	st.index()
	st.generate_normals()
	var mesh = st.commit()
	
	# Defer adding to tree
	call_deferred("_finalize_chunk", mesh, z_start)

func _finalize_chunk(mesh: Mesh, z_start: int):
	# Safety check if we're exiting or node is freed
	if not is_inside_tree(): return
	
	_generating_chunks.erase(z_start)
	
	var chunk_mesh = MeshInstance3D.new()
	chunk_mesh.mesh = mesh
	# Load material (cached by Godot resource loader generally, or we can preload it in a var)
	if not material_cache:
		material_cache = load("res://materials/depth_mat.tres")
	chunk_mesh.material_override = material_cache
	
	add_child(chunk_mesh)
	chunk_mesh.position = Vector3(0,0,0)
	chunk_mesh.create_trimesh_collision() # Enable collisions
	
	_active_chunks[z_start] = chunk_mesh
	
	_finished_chunks += 1
	# Check if this was part of initial batch
	if _finished_chunks == _total_chunks:
		print("Initial chunks complete.")
		generation_finished.emit()

var material_cache: Material

# ... (interpolation logic)

func process_cube(pos: Vector3, st: SurfaceTool):
	var cube_values = []
	var cube_corners = [
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1),
		Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)
	]
	
	for i in range(8):
		var corner_global = pos + cube_corners[i] * grid_size
		cube_values.append(get_density(corner_global))
		
	var cube_index = 0
	if cube_values[0] < iso_level: cube_index |= 1
	if cube_values[1] < iso_level: cube_index |= 2
	if cube_values[2] < iso_level: cube_index |= 4
	if cube_values[3] < iso_level: cube_index |= 8
	if cube_values[4] < iso_level: cube_index |= 16
	if cube_values[5] < iso_level: cube_index |= 32
	if cube_values[6] < iso_level: cube_index |= 64
	if cube_values[7] < iso_level: cube_index |= 128
	
	var edges = TRIANGLE_TABLE[cube_index]
	
	for i in range(0, edges.size() - 1, 3):
		if edges[i] == -1: break
		
		var e1 = edges[i]
		var e2 = edges[i+1]
		var e3 = edges[i+2]
		
		var v1 = interpolate_vertex(pos, cube_corners, cube_values, e1)
		var v2 = interpolate_vertex(pos, cube_corners, cube_values, e2)
		var v3 = interpolate_vertex(pos, cube_corners, cube_values, e3)
		
		st.add_vertex(v1)
		st.add_vertex(v2)
		st.add_vertex(v3)

func interpolate_vertex(pos: Vector3, corners: Array, values: Array, edge_index: int) -> Vector3:
	var v1_idx = EDGE_VERTEX_INDICES[edge_index][0]
	var v2_idx = EDGE_VERTEX_INDICES[edge_index][1]
	
	var p1 = pos + corners[v1_idx] * grid_size
	var p2 = pos + corners[v2_idx] * grid_size
	
	var val1 = values[v1_idx]
	var val2 = values[v2_idx]
	
	if abs(val2 - val1) < 0.00001: return p1
	
	var t = (iso_level - val1) / (val2 - val1)
	return p1.lerp(p2, t)

func get_density(pos: Vector3) -> float:
	# 1. Base Tunnel (Cylinder)
	var tunnel_dist = sqrt(pos.x * pos.x + pos.y * pos.y)
	var base_density = tunnel_dist - tunnel_radius
	
	# 2. Wall Noise (Perlin)
	var noise_val1 = noise.get_noise_3d(pos.x, pos.y, pos.z)
	var noise_val2 = noise.get_noise_3d(pos.x * 2.0, pos.y * 2.0, pos.z * 2.0)
	base_density += (noise_val1 + noise_val2 * 0.5) * 10.0
	
	# 3. Crystals (Cellular Noise)
	# We want them to protrude from walls.
	var cry_val = crystal_noise.get_noise_3d(pos.x, pos.y, pos.z)
	if cry_val > 0.6: # Dense spots
		# Make density MORE POSITIVE (Solid)
		# Add a spike
		base_density += (cry_val - 0.6) * 40.0
		
	# 4. Obstructions (Pipes/Poles)
	
	# Determine "block" for pipes (e.g. every 50 units is a potential slot)
	var block_size = 50.0
	var block_idx = floor(pos.z / block_size)
	
	# Use noise to check if this block has a pipe cluster
	# get_noise_1d returns -1 to 1.
	# We want irregular clusters. 
	var pipe_seed_val = pipe_noise.get_noise_1d(block_idx * 10.0)
	
	var obstruction_val = -100.0
	
	if pipe_seed_val > 0.3: # 35% chance of a pipe cluster in this block
		# Determine if vertical or horizontal
		# Use a different frequency/seed for orientation
		var orient_val = pipe_noise.get_noise_1d(block_idx * 50.0 + 1000.0)
		var radius_val = pipe_noise.get_noise_1d(block_idx * 25.0 + 500.0)
		
		# Map radius: -1..1 -> 1.5..4.0
		var pipe_radius = 1.5 + (radius_val + 1.0) * 1.25
		
		var center_z_local = pos.z - (block_idx * block_size + block_size * 0.5)
		
		if orient_val > 0.0:
			# Vertical Pole (Cylinder along Y)
			# Distance from pole axis (X=0 approx, Z=mid)
			# Add some jitter to X position?
			var x_offset = (orient_val - 0.5) * 20.0 # -10 to 10
			var pole_dist = sqrt((pos.x - x_offset) * (pos.x - x_offset) + center_z_local * center_z_local)
			obstruction_val = pipe_radius - pole_dist
		else:
			# Horizontal Pipe (Along X)
			var y_offset = (orient_val + 0.5) * 20.0 # -10 to 10
			var pipe_dist = sqrt((pos.y - y_offset) * (pos.y - y_offset) + center_z_local * center_z_local)
			obstruction_val = pipe_radius - pipe_dist

	# Combine with tunnel (Union)
	return max(base_density, obstruction_val)
