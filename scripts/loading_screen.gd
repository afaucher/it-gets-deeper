extends CanvasLayer

@export var tunnel_generator_path: NodePath
var tunnel_generator: Node
var _timer: float = 0.0

func _ready():
	if tunnel_generator_path:
		tunnel_generator = get_node(tunnel_generator_path)
		if tunnel_generator:
			tunnel_generator.generation_finished.connect(_on_generation_complete)
	
	# Ensure it's on top and visible
	layer = 100
	visible = true
	$Control/Label.text = "Digging... 0%"

func _process(delta):
	if not visible: return
	
	_timer += delta
	if _timer >= 1.0:
		_timer = 0.0
		if tunnel_generator and tunnel_generator.has_method("get_generation_progress"):
			var progress = tunnel_generator.get_generation_progress()
			$Control/Label.text = "Digging... %d%%" % int(progress * 100)

func _on_generation_complete():
	$Control/Label.text = "Digging... 100%"
	var tween = create_tween()
	tween.tween_property($Control, "modulate:a", 0.0, 0.5)
	tween.tween_callback(self.queue_free)
