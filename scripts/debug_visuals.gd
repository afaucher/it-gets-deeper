extends Node3D

var debug_mesh: ImmediateMesh
var mesh_instance: MeshInstance3D
var is_visible: bool = false

func _ready():
	mesh_instance = MeshInstance3D.new()
	debug_mesh = ImmediateMesh.new()
	mesh_instance.mesh = debug_mesh
	add_child(mesh_instance)
	
	# Create a material for the line (unshaded, bright color)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.MAGENTA
	mesh_instance.material_override = mat
	
	draw_center_line()
	mesh_instance.visible = is_visible

func _input(event):
	if event.is_action_pressed("toggle_debug"): 
		is_visible = !is_visible
		mesh_instance.visible = is_visible

func _process(_delta):
	if is_visible:
		debug_mesh.clear_surfaces()
		draw_center_line()
		draw_enemy_paths()
		if knockback_start != Vector3.ZERO:
			debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			debug_mesh.surface_set_color(Color.RED)
			debug_mesh.surface_add_vertex(knockback_start)
			debug_mesh.surface_add_vertex(knockback_start + knockback_vec)
			debug_mesh.surface_end()
			knockback_frames -= 1
			if knockback_frames <= 0:
				knockback_start = Vector3.ZERO

var knockback_start: Vector3
var knockback_vec: Vector3
var knockback_frames: int = 0

func draw_knockback(start: Vector3, vec: Vector3):
	knockback_start = start
	knockback_vec = vec
	knockback_frames = 60 # Show for 1 second

func draw_center_line():
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	debug_mesh.surface_add_vertex(Vector3(0, 0, -100))
	debug_mesh.surface_add_vertex(Vector3(0, 0, 3000))
	debug_mesh.surface_end()

func draw_enemy_paths():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		debug_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		
		# Parameters from enemy
		var start_p = enemy.start_pos
		var t_start = enemy.time_alive
		var move_speed = enemy.move_speed
		var sway_spd = enemy.sway_speed
		var sway_dist = enemy.sway_distance
		var current_z = enemy.position.z
		
		# Predict forward 3 seconds or until past player
		for i in range(20):
			var dt = i * 0.1
			var t = t_start + dt
			var dz = move_speed * dt
			
			var pred_z = current_z - dz
			var pred_x = start_p.x + sin(t * sway_spd) * sway_dist
			var pred_y = start_p.y + cos(t * sway_spd * 1.3) * sway_dist
			
			debug_mesh.surface_add_vertex(Vector3(pred_x, pred_y, pred_z))
			
		debug_mesh.surface_end()
