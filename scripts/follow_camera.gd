extends Camera3D

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 3, -6) # Behind(-Z) and Above(+Y) relative to player? 
# If player moves +Z, behind is -Z.
@export var smooth_speed: float = 5.0
@export var side_switch_threshold: float = 2.0

var target: Node3D
var current_side_offset: float = 0.0

func _ready():
	if target_path:
		target = get_node(target_path)

func _process(delta):
	if !target: return
	
	var target_pos = target.global_position
	
	# Logic to switch sides based on movement could go here.
	# For now, let's keep it simple: strict follow with offset.
	
	var desired_pos = target_pos + offset
	# Adjust Z offset to always be behind player (who is moving +Z)
	# If offset.z is negative, and we add to target (+Z), we are at (Target + (-Constant)). correct.
	
	global_position = global_position.lerp(desired_pos, smooth_speed * delta)
	
	look_at(target.global_position + Vector3(0, 0, 5)) # Look ahead of player
