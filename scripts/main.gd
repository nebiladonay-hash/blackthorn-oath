extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const HazardScript = preload("res://scripts/hazard.gd")
const RelicScript = preload("res://scripts/relic.gd")
const LANE_WIDTH := 2.6
const SEGMENT_LENGTH := 28.0

var player: BlackthornOathPlayer
var camera: Camera3D
var segments: Array[Node3D] = []
var next_z := 0.0
var distance := 0.0
var kills := 0
var relics := 0
var relic_bank := 0
var best_distance := 0
var save_data := ConfigFile.new()
var run_over := false
var score_label: Label
var health_label: Label
var relic_label: Label
var best_label: Label
var message_label: Label
var ui_layer: CanvasLayer
var pause_button: Button
var started_at := 0.0

func _ready() -> void:
	_load_progress()
	_make_environment()
	player = PlayerScript.new()
	player.position = Vector3(0, 0.1, 2)
	add_child(player)
	player.health_changed.connect(_on_health)
	player.died.connect(_on_death)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 72
	camera.position = Vector3(0, 5.1, 11.5)
	add_child(camera)
	_make_ui()
	for i in range(5):
		_spawn_segment(-float(i) * SEGMENT_LENGTH)
	started_at = Time.get_ticks_msec() / 1000.0

func _process(delta: float) -> void:
	if run_over:
		return
	distance = maxf(distance, -player.global_position.z)
	player.forward_speed = minf(12.0 + (Time.get_ticks_msec() / 1000.0 - started_at) * 0.12, 19.0)
	score_label.text = "DISTANCE  %05d m     KILLS  %02d" % [int(distance), kills]
	relic_label.text = "RELICS  %03d   BANK  %03d" % [relics, relic_bank]
	best_label.text = "BEST  %05d m" % best_distance
	camera.global_position = camera.global_position.lerp(player.global_position + Vector3(0, 5.1, 9.5), delta * 5.0)
	camera.look_at(player.global_position + Vector3(0, 1, -5.5), Vector3.UP)
	if player.global_position.z < next_z + SEGMENT_LENGTH * 2:
		_spawn_segment(next_z)
	for i in range(segments.size() - 1, -1, -1):
		if not is_instance_valid(segments[i]):
			segments.remove_at(i)
		elif segments[i].global_position.z > player.global_position.z + SEGMENT_LENGTH * 1.8:
			segments[i].queue_free()
			segments.remove_at(i)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_touch_origin = event.position
	elif event is InputEventScreenTouch and not event.pressed:
		var delta: Vector2 = event.position - _touch_origin
		if delta.length() > 40 and not run_over:
			if absf(delta.x) > absf(delta.y):
				player.move_lane(1 if delta.x > 0 else -1)
			elif delta.y < 0:
				player.jump()
			else:
				player.slide()

var _touch_origin := Vector2.ZERO

func _make_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.012, 0.008, 0.022)
	sky_mat.sky_horizon_color = Color(0.11, 0.025, 0.035)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.19, 0.28)
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.035, 0.055)
	env.fog_density = 0.012
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -28, 0)
	light.light_color = Color(0.46, 0.48, 0.68)
	light.shadow_enabled = true
	add_child(light)

func _make_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root := Control.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root)
	score_label = Label.new()
	score_label.position = Vector2(22, 18)
	score_label.add_theme_font_size_override("font_size", 21)
	root.add_child(score_label)
	health_label = Label.new()
	health_label.position = Vector2(22, 50)
	health_label.text = "VITALITY  ♥ ♥ ♥"
	relic_label = Label.new()
	relic_label.position = Vector2(22, 80)
	relic_label.text = "RELICS  000"
	relic_label.add_theme_color_override("font_color", Color(0.95, 0.68, 0.22))
	root.add_child(relic_label)
	best_label = Label.new()
	best_label.position = Vector2(22, 108)
	best_label.text = "BEST  %05d m" % best_distance
	root.add_child(best_label)
	health_label.add_theme_color_override("font_color", Color(0.8, 0.18, 0.14))
	root.add_child(health_label)
	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.position = Vector2(-220, -70)
	message_label.size = Vector2(440, 140)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 28)
	message_label.text = "BLACKTHORN OATH\nSwipe left/right to change lanes • up to jump • down to slide\nAttack enemies and collect glowing relics"
	root.add_child(message_label)
	get_tree().create_timer(4.0).timeout.connect(func(): message_label.visible = false)
	_button(root, "◀", Vector2(24, -95), Vector2(72, 70), func(): player.move_lane(-1), Control.PRESET_BOTTOM_LEFT)
	_button(root, "▶", Vector2(105, -95), Vector2(72, 70), func(): player.move_lane(1), Control.PRESET_BOTTOM_LEFT)
	_button(root, "SLIDE", Vector2(-275, -95), Vector2(82, 70), func(): player.slide(), Control.PRESET_BOTTOM_RIGHT)
	_button(root, "JUMP", Vector2(-185, -95), Vector2(82, 70), func(): player.jump(), Control.PRESET_BOTTOM_RIGHT)
	_button(root, "ATTACK", Vector2(-95, -95), Vector2(92, 70), func(): player.attack(), Control.PRESET_BOTTOM_RIGHT)
	pause_button = _button(root, "Ⅱ", Vector2(-88, 18), Vector2(66, 56), func(): _toggle_pause(), Control.PRESET_TOP_RIGHT)

func _button(root: Control, caption: String, offset: Vector2, dimensions: Vector2, action: Callable, preset: int) -> Button:
	var b := Button.new()
	b.text = caption
	b.set_anchors_preset(preset)
	b.position = offset
	b.size = dimensions
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	b.pressed.connect(action)
	root.add_child(b)
	return b

func _spawn_segment(z: float) -> void:
	var segment := Node3D.new()
	segment.position.z = z
	add_child(segment)
	segments.append(segment)
	_box(segment, Vector3(0, -0.35, -14), Vector3(9, 0.7, SEGMENT_LENGTH), Color(0.10, 0.09, 0.11), true)
	for side in [-1, 1]:
		_box(segment, Vector3(float(side) * 4.7, 0.2, -14), Vector3(0.4, 1.1, SEGMENT_LENGTH), Color(0.045, 0.035, 0.05), true)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_add_ruins(segment, rng)
	for row in range(3):
		var lane := rng.randi_range(0, 2)
		var pz := -7.0 - float(row) * 8.0
		if rng.randf() < 0.55:
			var enemy := EnemyScript.new()
			enemy.configure(rng.randi_range(0, 2))
			enemy.position = Vector3(float(lane - 1) * LANE_WIDTH, 0, pz)
			segment.add_child(enemy)
		else:
			var hazard := HazardScript.new()
			hazard.position = Vector3(float(lane - 1) * LANE_WIDTH, 0.55, pz)
			var shape_node := CollisionShape3D.new()
			var overhead := rng.randf() < 0.5
			var obstacle_size := Vector3(1.5, 0.45, 1.5) if overhead else Vector3(1.5, 1.1, 1.5)
			hazard.position.y = 1.45 if overhead else 0.55
			var shape := BoxShape3D.new()
			shape.size = obstacle_size
			shape_node.shape = shape
			hazard.add_child(shape_node)
			_box(hazard, Vector3.ZERO, obstacle_size, Color(0.2, 0.07, 0.05))
			segment.add_child(hazard)
		var relic_lane := (lane + 1 + (row % 2)) % 3
		var relic := RelicScript.new()
		relic.position = Vector3(float(relic_lane - 1) * LANE_WIDTH, 1.15, pz - 3.5)
		segment.add_child(relic)
	next_z = z - SEGMENT_LENGTH

func _add_ruins(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.075, 0.07, 0.09)
	stone.roughness = 0.92
	var worn_stone := StandardMaterial3D.new()
	worn_stone.albedo_color = Color(0.13, 0.11, 0.12)
	worn_stone.roughness = 0.88
	var ember := StandardMaterial3D.new()
	ember.albedo_color = Color(0.9, 0.19, 0.035)
	ember.emission_enabled = true
	ember.emission = Color(0.9, 0.08, 0.012)
	for side in [-1.0, 1.0]:
		for depth in [-4.0, -19.0]:
			var height := rng.randf_range(3.4, 5.8)
			var pillar := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = rng.randf_range(0.34, 0.48)
			cylinder.bottom_radius = 0.52
			cylinder.height = height
			cylinder.radial_segments = 7
			pillar.mesh = cylinder
			pillar.position = Vector3(side * 5.55, height * 0.5, depth)
			pillar.material_override = stone
			parent.add_child(pillar)
			var base := MeshInstance3D.new()
			var base_mesh := BoxMesh.new()
			base_mesh.size = Vector3(1.35, 0.34, 1.35)
			base.mesh = base_mesh
			base.position = Vector3(side * 5.55, 0.17, depth)
			base.material_override = worn_stone
			parent.add_child(base)
			var capital := MeshInstance3D.new()
			var cap_mesh := BoxMesh.new()
			cap_mesh.size = Vector3(1.05, 0.32, 1.05)
			capital.mesh = cap_mesh
			capital.position = Vector3(side * 5.55, height + 0.08, depth)
			capital.material_override = worn_stone
			parent.add_child(capital)
			if rng.randf() < 0.7:
				var flame := MeshInstance3D.new()
				var flame_mesh := SphereMesh.new()
				flame_mesh.radius = 0.17
				flame_mesh.height = 0.34
				flame.mesh = flame_mesh
				flame.position = Vector3(side * 5.55, height + 0.38, depth)
				flame.material_override = ember
				parent.add_child(flame)
		var rubble := MeshInstance3D.new()
		var rubble_mesh := BoxMesh.new()
		rubble_mesh.size = Vector3(rng.randf_range(0.8, 1.5), rng.randf_range(0.35, 0.8), 0.75)
		rubble.mesh = rubble_mesh
		rubble.position = Vector3(side * rng.randf_range(4.8, 5.5), 0.18, rng.randf_range(-25.0, -8.0))
		rubble.rotation.z = rng.randf_range(-0.25, 0.25)
		rubble.material_override = worn_stone
		parent.add_child(rubble)

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := false) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_node.material_override = material
	mesh_node.position = pos
	parent.add_child(mesh_node)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		body.add_child(collision)
		parent.add_child(body)

func _on_health(value: int) -> void:
	health_label.text = "VITALITY  " + "♥ ".repeat(value) + "♡ ".repeat(3 - value)

func _on_death() -> void:
	run_over = true
	best_distance = maxi(best_distance, int(distance))
	_save_progress()
	best_label.text = "BEST  %05d m" % best_distance
	message_label.visible = true
	message_label.text = "YOU HAVE FALLEN\nDISTANCE %d m • KILLS %d" % [int(distance), kills]
	_button(ui_layer.get_child(0), "RESTART", Vector2(-90, 90), Vector2(180, 60), func(): get_tree().reload_current_scene(), Control.PRESET_CENTER)

func add_kill() -> void:
	kills += 1

func add_relic() -> void:
	relics += 1
	relic_bank += 1
	relic_label.text = "RELICS  %03d   BANK  %03d" % [relics, relic_bank]
	_save_progress()

func _load_progress() -> void:
	if save_data.load("user://blackthorn_oath.cfg") == OK:
		best_distance = int(save_data.get_value("progress", "best_distance", 0))
		relic_bank = int(save_data.get_value("progress", "relic_bank", 0))

func _save_progress() -> void:
	save_data.set_value("progress", "best_distance", best_distance)
	save_data.set_value("progress", "relic_bank", relic_bank)
	save_data.save("user://blackthorn_oath.cfg")

func _toggle_pause() -> void:
	if run_over:
		return
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		message_label.text = "PAUSED\nTap RESUME to return to the run"
		message_label.visible = true
		pause_button.text = "RESUME"
	else:
		message_label.visible = false
		pause_button.text = "Ⅱ"
