class_name ProceduralParts

static func create_mesh(parent: Node3D, mesh_type: Mesh, material: Material = null) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh_type
	if material:
		mi.material_override = material
	parent.add_child(mi)
	return mi

static func create_body(parent: Node3D, shape: Shape3D, mass: float = 1.0) -> RigidBody3D:
	var body = RigidBody3D.new()
	body.mass = mass
	parent.add_child(body)
	
	var col = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	return body

# Generates a chain of rigid bodies connected by joints
# start_pos: local to parent
# direction: direction of the chain
static func create_chain(parent: Node3D, start_pos: Vector3, direction: Vector3, length: float, segments: int, stiffness: float, thickness: float) -> Array[RigidBody3D]:
	var bodies: Array[RigidBody3D] = []
	var segment_len = length / float(segments)
	var prev_body: Node3D = parent
	
	var mat = load("res://materials/depth_mat.tres")
	
	for i in range(segments):
		var t = float(i) / float(segments)
		var pos = start_pos + direction * (segment_len * i + segment_len * 0.5)
		
		# Create Body
		var body = RigidBody3D.new()
		parent.add_child(body)
		body.top_level = true # Prevent double-transform from parent movement
		
		# Calculate global position correctly based on current parent orientation
		body.global_position = parent.global_position + (parent.global_transform.basis * pos)
		body.gravity_scale = 0.0
		body.mass = 0.5 * (1.0 - t * 0.5) # Taper mass
		
		# Disable collision with main body to prevent "explosion"
		if parent is CollisionObject3D:
			body.add_collision_exception_with(parent)
		if prev_body is CollisionObject3D and prev_body != parent:
			body.add_collision_exception_with(prev_body)
		
		# Collision
		var col = CollisionShape3D.new()
		var shape = CapsuleShape3D.new()
		shape.radius = thickness * (1.0 - t * 0.6) # Taper thickness
		shape.height = segment_len + thickness
		col.shape = shape
		body.add_child(col)
		
		# Mesh
		var mesh = CapsuleMesh.new()
		mesh.radius = shape.radius
		mesh.height = shape.height
		create_mesh(body, mesh, mat)
		
		# Align
		# Capsule is Y-aligned. If direction is not Y, we rotate.
		var global_dir = parent.global_transform.basis * direction
		if abs(global_dir.dot(parent.global_transform.basis.y)) < 0.99:
			body.look_at(body.global_position + global_dir, parent.global_transform.basis.y)
			body.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
		
		# Joint
		var joint: Joint3D
		if i == 0:
			joint = PinJoint3D.new()
		else:
			joint = Generic6DOFJoint3D.new()
			
		parent.add_child(joint)
		joint.global_position = body.global_position - global_dir * (segment_len * 0.5)
		
		joint.node_a = prev_body.get_path()
		joint.node_b = body.get_path()
			
		# Config Joint
		if joint is Generic6DOFJoint3D:
			# Only limit rotation, let linear stay "connected" naturally
			joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
			joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
			joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
			
			if stiffness > 0.8:
				joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
				joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)
				joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
				joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)
				joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
				joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)
			else:
				var limit = deg_to_rad(45)
				joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -limit)
				joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, limit)
			
		bodies.append(body)
		prev_body = body
		
	return bodies

static func create_radial_symmetry(count: int, radius: float, callback: Callable, axis: Vector3 = Vector3.UP):
	for i in range(count):
		var angle = (TAU / count) * i
		var pos: Vector3
		if axis == Vector3.UP:
			pos = Vector3(sin(angle), 0, cos(angle)) * radius
		elif axis == Vector3.FORWARD:
			pos = Vector3(sin(angle), cos(angle), 0) * radius
		elif axis == Vector3.RIGHT:
			pos = Vector3(0, sin(angle), cos(angle)) * radius
		var rot = angle
		callback.call(pos, rot)
