extends CharacterBody3D

@export var forward_speed: float = 20.0
@export var move_speed: float = 15.0
@export var acceleration: float = 5.0
@export var bounce_strength: float = 1.5

# Gameplay Stats
@export var max_ammo: float = 100.0
@export var ammo_consumption: float = 10.0
@export var reload_rate: float = 30.0
@export var reload_delay: float = 2.0
@export var penalty_amount: float = 15.0

var current_ammo: float
var is_reloading: bool = false
var reload_timer: float = 0.0
var score: int = 0
var damage_level: float = 0.0

signal ammo_changed(value)
signal score_changed(value)
signal damage_changed(value)
signal choke_changed(index)

var choke_settings = [1.0, 4.0, 7.0]
var current_choke_index = 0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	
	if event.is_action_pressed("adjust_choke"):
		current_choke_index = (current_choke_index + 1) % choke_settings.size()
		choke_changed.emit(current_choke_index)
	
	if event.is_action_pressed("choke_up"):
		current_choke_index = min(current_choke_index + 1, choke_settings.size() - 1)
		choke_changed.emit(current_choke_index)
		
	if event.is_action_pressed("choke_down"):
		current_choke_index = max(current_choke_index - 1, 0)
		choke_changed.emit(current_choke_index)

func _ready():
	add_to_group("player")
	current_ammo = max_ammo
	var mesh_instance = $MeshInstance3D
	if mesh_instance:
		mesh_instance.material_override = load("res://materials/depth_mat.tres")

func _process(delta):
	handle_shooting(delta)
	handle_reloading(delta)

func handle_shooting(delta):
	if shot_cooldown > 0:
		shot_cooldown -= delta
		
	if Input.is_action_pressed("fire"):
		reload_timer = reload_delay
		
		if is_reloading:
			if Input.is_action_just_pressed("fire"): 
				current_ammo = max(0, current_ammo - penalty_amount)
				ammo_changed.emit(current_ammo)
		elif current_ammo > 0:
			current_ammo -= ammo_consumption * delta * 5.0 
			if current_ammo <= 0:
				current_ammo = 0
				start_reload()
			ammo_changed.emit(current_ammo)
			
			spawn_projectile()

var projectile_scene = preload("res://scenes/projectile.tscn")
var shot_cooldown: float = 0.0

func spawn_projectile():
	if shot_cooldown > 0: return
	shot_cooldown = 0.1
	
	if projectile_scene:
		var proj = projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position
		
		var aim_point = get_mouse_aim_point()
		proj.look_at(aim_point)
		
		# Apply Spread
		var spread_deg = choke_settings[current_choke_index]
		var spread_rad = deg_to_rad(spread_deg)
		var rand_x = randf_range(-spread_rad/2, spread_rad/2)
		var rand_y = randf_range(-spread_rad/2, spread_rad/2)
		
		proj.rotate_object_local(Vector3.UP, rand_x)
		proj.rotate_object_local(Vector3.RIGHT, rand_y)

func get_mouse_aim_point() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return global_position - global_transform.basis.z * 100.0
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	# Raycast to find 3D point
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 1000.0)
	query.collision_mask = 5 # World (1) + Enemy (4)
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	else:
		# Fallback to a point 100 units away
		return ray_origin + ray_dir * 100.0

func handle_reloading(delta):
	if !Input.is_action_pressed("fire") and not is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			start_reload()
	
	if is_reloading:
		current_ammo += reload_rate * delta
		if current_ammo >= max_ammo:
			current_ammo = max_ammo
			is_reloading = false
		ammo_changed.emit(current_ammo)

func start_reload():
	is_reloading = true

func take_damage(amount: float, source_pos: Vector3 = Vector3.ZERO):
	damage_level += amount
	damage_changed.emit(damage_level / 100.0)
	
	if source_pos != Vector3.ZERO:
		var direction = (global_position - source_pos).normalized()
		# Flatten to XY plane for gameplay clarity? User said "horizontal and vertical plane"
		# which implies 3D or at least relative to surface.
		# For enemy collision, just push away.
		# Wall Force is 12.5. Enemy is 75% of Wall = 9.375
		apply_knockback(direction, 9.375)

func _physics_process(delta):
	var target_velocity = Vector3.ZERO
	target_velocity.z = forward_speed
	
	score += int(forward_speed * delta)
	score_changed.emit(score)

	# Knockback Handling
	if knockback_timer > 0:
		knockback_timer -= delta
		velocity = knockback_velocity
		move_and_slide()
		return # Skip normal movement input

	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	target_velocity.x = -input_dir.x * move_speed
	target_velocity.y = -input_dir.y * move_speed 
	
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta * 100)
	velocity.y = move_toward(velocity.y, target_velocity.y, acceleration * delta * 100)
	velocity.z = target_velocity.z
	
	move_and_slide()
	
	# Rotation: Face velocity direction
	if velocity.length_squared() > 1.0:
		var target_dir = velocity.normalized()
		# Avoid looking straight up/down to prevent gimbal lock
		if abs(target_dir.dot(Vector3.UP)) < 0.99:
			var target_basis = Basis.looking_at(target_dir, Vector3.UP)
			# Slerp for smooth rotation
			global_transform.basis = global_transform.basis.slerp(target_basis, delta * 10.0)
	
	if get_slide_collision_count() > 0:
		var collision = get_slide_collision(0)
		var normal = collision.get_normal()
		
		# Bounce logic / Knockback
		# Reduced by 75% (was 50.0) -> 12.5
		apply_knockback(normal, 12.5)
		# Penalty
		damage_level += 5.0 * delta * 10.0
		damage_changed.emit(damage_level / 100.0)
	
	# Update Global Status for cleanup scripts (depth-based)
	GlobalStatus.player_z = global_position.z

var knockback_velocity: Vector3
var knockback_timer: float = 0.0

func add_score(amount: int):
	score += amount
	score_changed.emit(score)

func apply_knockback(direction: Vector3, force: float):
	# Restrict to XY plane (cancel Z motion)
	direction.z = 0
	direction = direction.normalized()
	
	knockback_velocity = direction * force
	knockback_timer = 0.25
	# Debug visualization
	var debug = get_node_or_null("/root/Main/DebugVisuals")
	if debug and debug.has_method("draw_knockback"):
		debug.draw_knockback(global_position, direction * 5.0) # Visual scale
