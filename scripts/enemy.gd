extends RigidBody3D

@export var move_speed: float = 10.0
@export var sway_speed: float = 2.0
@export var sway_distance: float = 5.0
@export var showcase_mode: bool = false

var start_pos: Vector3
var time_alive: float = 0.0

var health: float = 30.0

enum Pattern { SINE, ZIGZAG, STOP_GO, ROBOTIC }
@export var current_pattern: Pattern = Pattern.SINE
@export var randomize_pattern: bool = true
var pattern_timer: float = 0.0
var pattern_state: int = 0 # Used for STOP_GO phases

func _ready():
	add_to_group("enemies")
	start_pos = global_position
	# RigidBody setup
	gravity_scale = 0.0 
	freeze = true 
	
	# Remove default mesh/shape if they exist, or hide them
	if has_node("MeshInstance3D"):
		$MeshInstance3D.hide() # Hide default
	# Keep default collision for gameplay hit detection, but maybe resize it?
	
	connect("body_entered", _on_body_entered)
	
	if randomize_pattern:
		current_pattern = Pattern.values().pick_random()
	
	generate_visuals()

func generate_visuals():
	# Clear previous visuals if any (simple check for children that are MeshInstance3D or RigidBody3D)
	# This avoids duplicating if called multiple times
	for child in get_children():
		if child is MeshInstance3D and child.name != "MeshInstance3D": # Don't delete original if checking by name
			child.queue_free()
		if child is RigidBody3D:
			child.queue_free()
	
	var mat = load("res://materials/depth_mat.tres")
	
	match current_pattern:
		Pattern.SINE: # Jellyfish
			# Central Sphere
			var mesh = SphereMesh.new()
			mesh.radius = 1.5 # 1.0 * 1.5
			mesh.height = 3.0 # 2.0 * 1.5
			ProceduralParts.create_mesh(self, mesh, mat)
			
			# Radial Tentacles
			ProceduralParts.create_radial_symmetry(6, 1.2, func(pos, _angle):
				# Start pos relative to center
				var start = pos + Vector3(0, -0.75, 0)
				# Spread out slightly
				var dir = (pos + Vector3(0, -2, 0)).normalized() 
				ProceduralParts.create_chain(self, start, dir, 4.5, 6, 0.05, 0.2) # Reduced stiffness 0.1 -> 0.05
			)
			
		Pattern.ZIGZAG: # Urchin / Starfish
			# Central Prism/Ico
			var mesh = PrismMesh.new()
			mesh.size = Vector3(3, 3, 3) # 2 * 1.5
			ProceduralParts.create_mesh(self, mesh, mat)
			
			# Spikes radiating in XY plane (Side view)
			ProceduralParts.create_radial_symmetry(8, 0.75, func(pos, _angle):
				var dir = pos.normalized()
				var start = dir * 1.5
				ProceduralParts.create_chain(self, start, dir, 3.0, 3, 1.0, 0.3)
			, Vector3.FORWARD) # Use FORWARD axis for XY plane symmetry
			
		Pattern.STOP_GO: # Beetle
			# Central Box
			var mesh = BoxMesh.new()
			mesh.size = Vector3(2.25, 1.5, 3.0) # 1.5 * 1.5 ...
			ProceduralParts.create_mesh(self, mesh, mat)
			
			# Horizontal Legs
			# Side Left
			for z in [-0.75, 0.75]:
				ProceduralParts.create_chain(self, Vector3(-1.2, 0, z), Vector3(-1, -0.5, 0).normalized(), 2.25, 3, 0.2, 0.2) # Reduced stiffness 0.5 -> 0.2
			# Side Right
			for z in [-0.75, 0.75]:
				ProceduralParts.create_chain(self, Vector3(1.2, 0, z), Vector3(1, -0.5, 0).normalized(), 2.25, 3, 0.2, 0.2) # Reduced stiffness 0.5 -> 0.2

		Pattern.ROBOTIC: # Construct
			# Torus
			var mesh = TorusMesh.new()
			mesh.outer_radius = 1.5
			mesh.inner_radius = 0.9
			ProceduralParts.create_mesh(self, mesh, mat)
			
			# Central Core
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.6; cyl.bottom_radius = 0.6; cyl.height = 3.75
			ProceduralParts.create_mesh(self, cyl, mat)
			
			# Fractal Arms
			ProceduralParts.create_radial_symmetry(3, 1.5, func(pos, _angle):
				var dir = pos.normalized()
				var _chain = ProceduralParts.create_chain(self, pos, dir, 3.0, 4, 0.4, 0.3) # Reduced stiffness 0.9 -> 0.4
			)

func _process(delta):
	# Only manual move if alive (frozen physics)
	if !freeze: return
	
	time_alive += delta
	
	var z_speed = move_speed
	var x_offset = 0.0
	var y_offset = 0.0
	
	match current_pattern:
		Pattern.SINE:
			x_offset = sin(time_alive * sway_speed) * sway_distance
			y_offset = cos(time_alive * sway_speed * 1.3) * sway_distance
			
		Pattern.ZIGZAG:
			# Sharp triangle wave
			var period = 2.0
			var phase = fmod(time_alive, period) / period # 0..1
			var wave = abs(phase - 0.5) * 4.0 - 1.0 # -1..1..-1 triangle
			x_offset = wave * sway_distance
			y_offset = (abs(fmod(time_alive * 0.7, period) / period - 0.5) * 4.0 - 1.0) * sway_distance
			
		Pattern.STOP_GO:
			pattern_timer += delta
			if pattern_state == 0: # Move
				if pattern_timer > 2.0:
					pattern_state = 1
					pattern_timer = 0
			elif pattern_state == 1: # Stop
				z_speed = 0.0
				if pattern_timer > 0.5:
					pattern_state = 2 # Surge
					pattern_timer = 0
			elif pattern_state == 2: # Surge / Reverse?
				z_speed = move_speed * 2.0
				if randf() < 0.005: 
					z_speed = -move_speed
				
				if pattern_timer > 1.0:
					pattern_state = 0
					pattern_timer = 0
					
			x_offset = sin(time_alive) * (sway_distance * 0.2)
			
		Pattern.ROBOTIC:
			# Robotic movement: Move in straight lines, change direction instantly
			var step_interval = 0.5
			var step_index = floor(time_alive / step_interval)
			
			# Use hash/noise of step index to determine target
			var random_step = sin(step_index * 12.9898) * 43758.5453
			# Map -1..1
			var step_val = fmod(abs(random_step), 2.0) - 1.0 
			
			var target_x = step_val * sway_distance
			var target_y = cos(step_index * 45.0) * sway_distance
			
			# Interpolate current offset to target
			var step_phase = fmod(time_alive, step_interval) / step_interval
			
			# Previous step for start point
			var prev_step = sin((step_index - 1.0) * 12.9898) * 43758.5453
			var prev_val = fmod(abs(prev_step), 2.0) - 1.0
			var start_x = prev_val * sway_distance
			var start_y = cos((step_index - 1.0) * 45.0) * sway_distance
			
			x_offset = lerp(start_x, target_x, step_phase)
			y_offset = lerp(start_y, target_y, step_phase)
	
	# Manual movement while alive/frozen
	var new_pos = global_position
	if !showcase_mode:
		new_pos.z -= z_speed * delta
	new_pos.x = start_pos.x + x_offset
	new_pos.y = start_pos.y + y_offset
	global_position = new_pos
	
	# Cleanup
	if global_position.z < -100:
		queue_free()

func _on_body_entered(body):
	if body.has_method("take_damage") and body.name == "Player":
		body.take_damage(20, global_position)
		die(global_position)

func take_damage(amount: float, source_pos: Vector3 = Vector3.ZERO):
	health -= amount
	if health <= 0:
		die(source_pos)

func die(source_pos: Vector3):
	# Ragdoll mode
	freeze = false
	gravity_scale = 1.0
	lock_rotation = false
	axis_lock_angular_x = false
	axis_lock_angular_z = false
	
	# Apply impulse away from source
	if source_pos != Vector3.ZERO:
		var dir = (global_position - source_pos).normalized()
		apply_central_impulse(dir * 20.0)
		apply_torque_impulse(Vector3(randf(), randf(), randf()) * 10.0)
	
	# Remove from group so it stops interacting as an "enemy"?
	remove_from_group("enemies")
	
	# Cleanup timer
	await get_tree().create_timer(5.0).timeout
	queue_free()

func init(pos: Vector3):
	global_position = pos
	start_pos = pos
