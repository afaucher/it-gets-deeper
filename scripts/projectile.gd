extends Area3D

@export var speed: float = 100.0
@export var life_time: float = 3.0

func _ready():
	var mesh = $MeshInstance3D
	if mesh:
		mesh.material_override = load("res://materials/depth_mat.tres")

func _process(delta):
	position += transform.basis.z * speed * delta
	
	life_time -= delta
	if life_time <= 0:
		queue_free()

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(10)
	queue_free()

func _on_area_entered(area):
	if area.has_method("take_damage"):
		area.take_damage(10)
		queue_free()
