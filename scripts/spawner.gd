extends Node3D

@export var player_path: NodePath
@export var enemy_scene: PackedScene
@export var spawn_distance: float = 200.0
@export var wave_interval: float = 50.0 # Distance between waves
@export var min_rows: int = 1
@export var max_rows: int = 3
@export var min_cols: int = 1
@export var max_cols: int = 3
@export var spacing: float = 8.0

@export var crate_scene: PackedScene
@export var wire_bundle_scene: PackedScene

var player: Node3D
var next_spawn_z: float = 50.0
# Separate trackers for objects
var next_object_z: float = 50.0
var object_interval: float = 50.0 # Increased frequency (was 100)

func _ready():
	if player_path:
		player = get_node(player_path)
	
	# Initial spawn ahead
	next_spawn_z = player.global_position.z + spawn_distance

func _process(_delta):
	if !player: return
	
	if player.global_position.z + spawn_distance > next_spawn_z:
		spawn_wave()
		next_spawn_z += wave_interval

	if player.global_position.z + spawn_distance > next_object_z:
		spawn_environment_objects()
		next_object_z += object_interval

func spawn_environment_objects():
	# 1. Try to spawn a Wire Bundle (50% chance)
	if wire_bundle_scene and randf() > 0.5:
		spawn_wire_bundle()
		
	# 2. Try to spawn Crate Cluster (50% chance)
	if crate_scene and randf() > 0.5:
		var count = randi_range(1, 3)
		for i in range(count):
			spawn_crate()

func spawn_wire_bundle():
	var space_state = get_world_3d().direct_space_state
	# Pick random angle
	var angle = randf() * TAU
	var dir = Vector3(sin(angle), cos(angle), 0).normalized()
	
	var z_pos = next_object_z + randf_range(-20, 20)
	var from = Vector3(0, 0, z_pos)
	var to = from + dir * 60.0 # Tunnel radius is ~30-40?
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var point_a = result.position
		
		# Find second point nearby (Longer span: 20-50m)
		var z_offset = randf_range(20.0, 50.0)
		var from_b = Vector3(0, 0, z_pos + z_offset)
		var to_b = from_b + dir * 60.0
		var query_b = PhysicsRayQueryParameters3D.create(from_b, to_b)
		var result_b = space_state.intersect_ray(query_b)
		
		if result_b:
			var point_b = result_b.position
			
			var wire = wire_bundle_scene.instantiate()
			get_parent().add_child(wire)
			# Needs more sag for longer wires (5-15m)
			if wire.has_method("init"):
				wire.init(point_a, point_b, randf_range(5.0, 15.0))

func spawn_crate():
	var space_state = get_world_3d().direct_space_state
	var z_pos = next_object_z + randf_range(-20, 20)
	# Raycast DOWN
	var from = Vector3(0, 5, z_pos) 
	var to = Vector3(0, -50, z_pos)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var pos = result.position
		var crate = crate_scene.instantiate()
		get_parent().add_child(crate)
		crate.global_position = pos + Vector3.UP * 1.5 
		crate.rotation = Vector3(randf()*TAU, randf()*TAU, randf()*TAU)

func spawn_wave():
	var rows = randi_range(min_rows, max_rows)
	var cols = randi_range(min_cols, max_cols)
	
	# Calculate block size
	var block_width = (cols - 1) * spacing
	var block_height = (rows - 1) * spacing
	
	# Determine safe center position
	# Tunnel radius ~20. Safe area radius ~10 to avoid walls.
	var safe_radius = 10.0
	
	# Calculate available offset range
	var max_offset_x = safe_radius - (block_width / 2.0)
	var max_offset_y = safe_radius - (block_height / 2.0)
	
	if max_offset_x < 0: max_offset_x = 0
	if max_offset_y < 0: max_offset_y = 0
	
	var center_x = randf_range(-max_offset_x, max_offset_x)
	var center_y = randf_range(-max_offset_y, max_offset_y)
	
	var start_x = center_x - (block_width / 2.0)
	var start_y = center_y - (block_height / 2.0)
	
	for r in range(rows):
		for c in range(cols):
			var pos = Vector3(
				start_x + c * spacing,
				start_y + r * spacing,
				next_spawn_z
			)
			spawn_enemy(pos)

func spawn_enemy(pos: Vector3):
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		get_parent().add_child(enemy) # Add to Main scene, not Spawner
		if enemy.has_method("init"):
			enemy.init(pos)
		else:
			enemy.global_position = pos
