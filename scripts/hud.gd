extends Control

@export var player_path: NodePath
var player

@onready var damage_label = $VBoxContainer/DamageLabel
@onready var score_label = $VBoxContainer/ScoreLabel
@onready var ammo_label = $VBoxContainer/AmmoLabel
@onready var ammo_bar = $VBoxContainer/AmmoBar


var debug_label: Label
var tunnel_gen: Node

func _ready():
	# Create debug label programmatically
	debug_label = Label.new()
	# Preset Middle Left
	debug_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_KEEP_SIZE, 10)
	
	debug_label.modulate = Color.YELLOW
	debug_label.visible = false # targeted_debug_mode (default off)
	add_child(debug_label)
	
	if player_path:
		player = get_node(player_path)
		if player:
			player.ammo_changed.connect(_on_ammo_changed)
			player.score_changed.connect(_on_score_changed)
			player.damage_changed.connect(_on_damage_changed)
			# Init values
			_on_ammo_changed(player.current_ammo)
			
	tunnel_gen = get_node_or_null("/root/Main/TunnelGenerator") # Adjust path if needed, usually peer to player

func _input(event):
	if event.is_action_pressed("toggle_debug"):
		if debug_label:
			debug_label.visible = !debug_label.visible

func _process(delta):
	if debug_label and debug_label.visible and player and tunnel_gen:
		var p_pos = player.global_position
		var range = tunnel_gen.get_loaded_chunk_range()
		var gen_range = tunnel_gen.get_generating_chunk_range()
		var gen_count = tunnel_gen.get_generating_chunk_count()
		# WorkerThreadPool defaults to processor count usually
		var thread_count = OS.get_processor_count()
		debug_label.text = "Player Z: %.1f\nLoaded Chunks: %.0f to %.0f\nGenerating: %.0f to %.0f (Count: %d)\nLogical Cores: %d" % [p_pos.z, range.x, range.y, gen_range.x, gen_range.y, gen_count, thread_count]

func _on_ammo_changed(value):
	ammo_label.text = "Ammo: %d" % int(value)
	ammo_bar.value = value

func _on_score_changed(value):
	score_label.text = "Score: %d" % value

func _on_damage_changed(value):
	damage_label.text = "Damage: %d%%" % int(value * 100)
