extends Node3D

@export var segment_length: float = 1.0
@export var segment_radius: float = 0.3 # Increased 3x (0.1 -> 0.3)
@export var segment_count: int = 10 
@export var color: Color = Color(0.1, 0.1, 0.1)

func init(start_pos: Vector3, end_pos: Vector3, sag: float = 2.0):
	# Calculate total distance
	var diff = end_pos - start_pos
	var dist = diff.length()
	var dir = diff.normalized()
	
	# Adjust segment count based on distance to avoid stretching
	var required_segments = ceil(dist / segment_length)
	# Add significant extra for slack/length
	required_segments = int(required_segments * 1.5)
	# Clamp to reasonable values (increased limit)
	segment_count = clampi(required_segments, 5, 60)
	
	# Create segments
	var prev_body: RigidBody3D = null
	
	for i in range(segment_count):
		var t = float(i) / float(segment_count - 1)
		
		# Linear position
		var linear_pos = start_pos.lerp(end_pos, t)
		# Add sag (parabola)
		# 4 * t * (1-t) is a parabola 0..1..0
		var sag_offset = Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		var pos = linear_pos + sag_offset
		
		# Calculate direction for rotation (look at next pos, or tangent)
		var next_t = float(i + 1) / float(segment_count - 1)
		var next_linear = start_pos.lerp(end_pos, next_t)
		var next_sag = Vector3.DOWN * sag * 4.0 * next_t * (1.0 - next_t)
		var next_pos = next_linear + next_sag
		
		if i == segment_count - 1:
			# For last segment, look back at prev (or use same dir as prev)
			next_pos = pos + (pos - prev_body.position) if prev_body else pos + Vector3.DOWN
			
		var body = create_segment(pos, next_pos)
		add_child(body)
		
		if i == 0:
			# Pin first segment to static world (or freeze it?)
			# Actually, simpler to just freeze the first and last bodies?
			# But we want them to hang.
			# Let's create a PinJoint to a static anchor if needed.
			# For simplicity: Freeze the first and last segment.
			body.freeze = true
			body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		elif i == segment_count - 1:
			body.freeze = true
			body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		
		if prev_body:
			join_bodies(prev_body, body)
		
		prev_body = body

func create_segment(pos: Vector3, look_target: Vector3) -> RigidBody3D:
	var body = RigidBody3D.new()
	body.position = pos
	body.mass = 1.0
	
	# Create Mesh and Collision first
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = segment_radius
	shape.height = segment_length + 0.2
	col.shape = shape
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = segment_radius
	mesh.bottom_radius = segment_radius
	mesh.height = segment_length
	mesh_inst.mesh = mesh
	# Use depth material
	if ResourceLoader.exists("res://materials/depth_mat.tres"):
		mesh_inst.material_override = load("res://materials/depth_mat.tres")
	
	# Rotate children so their Y (height) aligns with -Z (Forward)
	# Rotate -90 degrees around X axis
	var align_rot = Vector3(deg_to_rad(-90), 0, 0)
	col.rotation = align_rot
	mesh_inst.rotation = align_rot
	
	body.add_child(col)
	body.add_child(mesh_inst)
	
	# Now set body orientation
	# Construct Basis manually to avoid 'not in tree' look_at issues
	var forward = (look_target - pos).normalized()
	if forward.length_squared() > 0.001:
		# Godot's look_at aligns -Z to target
		if abs(forward.dot(Vector3.UP)) < 0.99:
			body.basis = Basis.looking_at(forward, Vector3.UP)
		else:
			body.basis = Basis.looking_at(forward, Vector3.RIGHT)
			
	return body

func join_bodies(a: RigidBody3D, b: RigidBody3D):
	var joint = PinJoint3D.new()
	add_child(joint)
	joint.global_position = (a.global_position + b.global_position) / 2.0
	joint.node_a = a.get_path()
func _process(_delta):
	if global_position.z < GlobalStatus.player_z - 100:
		queue_free()
