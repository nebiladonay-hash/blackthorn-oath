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
var next_segment_z := 0.0
var distance := 0.0
var kills := 0
var relics := 0
var relic_bank := 0
var best_distance := 0
var save_data := ConfigFile.new()

var game_started := false
var game_over := false
var paused := false
var run_started_at := 0.0
var touch_start := Vector2.ZERO
var touch_tracking := false

var hud: Control
var controls: Control
var menu_panel: PanelContainer
var modal_panel: PanelContainer
var score_label: Label
var health_label: Label
var relic_label: Label
var best_label: Label
var modal_title: Label
var modal_body: Label
var modal_action: Button
var pause_button: Button

func _ready() -> void:
	_load_progress()
	_build_environment()
	_build_player_and_camera()
	_build_interface()
	for i in range(6):
		_spawn_segment(-float(i) * SEGMENT_LENGTH)
	_update_hud()

func _process(delta: float) -> void:
	if not game_started or paused or game_over:
		_idle_camera(delta)
		return
	distance = maxf(distance, -player.global_position.z - 3.0)
	var elapsed := Time.get_ticks_msec() / 1000.0 - run_started_at
	player.forward_speed = minf(12.0 + elapsed * 0.16, 19.0)
	_update_hud()
	_follow_camera(delta)
	_update_track()

func _input(event: InputEvent) -> void:
	if not game_started or paused or game_over:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
			touch_tracking = true
		elif touch_tracking:
			var swipe := event.position - touch_start
			touch_tracking = false
			if swipe.length() >= 38.0:
				if absf(swipe.x) > absf(swipe.y):
					player.move_lane(1 if swipe.x > 0.0 else -1)
				elif swipe.y < 0.0:
					player.jump()
				else:
					player.slide()

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.012, 0.009, 0.022)
	sky_material.sky_horizon_color = Color(0.12, 0.035, 0.045)
	sky_material.ground_bottom_color = Color(0.008, 0.006, 0.012)
	sky_material.ground_horizon_color = Color(0.045, 0.022, 0.03)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.34, 0.31, 0.39)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.095, 0.045, 0.06)
	environment.fog_density = 0.006
	world.environment = environment
	add_child(world)

	var moonlight := DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-48, -28, 0)
	moonlight.light_color = Color(0.63, 0.65, 0.82)
	moonlight.light_energy = 1.15
	moonlight.shadow_enabled = true
	add_child(moonlight)

	var red_fill := OmniLight3D.new()
	red_fill.position = Vector3(0, 4.0, -9.0)
	red_fill.light_color = Color(0.48, 0.075, 0.065)
	red_fill.light_energy = 1.5
	red_fill.omni_range = 22.0
	add_child(red_fill)

func _build_player_and_camera() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(0, 0, -3.0)
	player.forward_speed = 0.0
	add_child(player)

	camera = Camera3D.new()
	camera.name = "GameplayCamera"
	camera.current = true
	camera.fov = 61.0
	camera.near = 0.08
	camera.far = 120.0
	camera.position = player.global_position + Vector3(0, 4.0, 8.2)
	add_child(camera)
	camera.look_at(player.global_position + Vector3(0, 1.0, -6.0), Vector3.UP)

func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "GameUI"
	add_child(canvas)
	var root := Control.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.visible = false
	root.add_child(hud)
	var hud_panel := PanelContainer.new()
	hud_panel.position = Vector2(22, 18)
	hud_panel.size = Vector2(320, 132)
	hud_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.022, 0.032, 0.86), Color(0.36, 0.19, 0.16)))
	hud.add_child(hud_panel)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 5)
	hud_panel.add_child(stats)
	score_label = _label("DISTANCE  00000 m     KILLS  00", 19, Color(0.92, 0.86, 0.78))
	stats.add_child(score_label)
	health_label = _label("VITALITY   ♥  ♥  ♥", 18, Color(0.88, 0.19, 0.16))
	stats.add_child(health_label)
	relic_label = _label("RELICS  000   /   BANK  000", 15, Color(0.93, 0.65, 0.25))
	stats.add_child(relic_label)
	best_label = _label("BEST  00000 m", 14, Color(0.65, 0.63, 0.7))
	stats.add_child(best_label)

	controls = Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.visible = false
	root.add_child(controls)
	_button(controls, "◀", Vector2(26, -98), Vector2(78, 76), func(): player.move_lane(-1), Control.PRESET_BOTTOM_LEFT, 25)
	_button(controls, "▶", Vector2(114, -98), Vector2(78, 76), func(): player.move_lane(1), Control.PRESET_BOTTOM_LEFT, 25)
	_button(controls, "SLIDE", Vector2(-282, -98), Vector2(86, 76), func(): player.slide(), Control.PRESET_BOTTOM_RIGHT, 15)
	_button(controls, "JUMP", Vector2(-188, -98), Vector2(86, 76), func(): player.jump(), Control.PRESET_BOTTOM_RIGHT, 17)
	_button(controls, "ATTACK", Vector2(-94, -98), Vector2(86, 76), func(): player.attack(), Control.PRESET_BOTTOM_RIGHT, 15)
	pause_button = _button(controls, "Ⅱ", Vector2(-94, 18), Vector2(76, 56), _toggle_pause, Control.PRESET_TOP_RIGHT, 20)

	menu_panel = _make_overlay_panel(root, Vector2(660, 440))
	menu_panel.position = Vector2(-330, -220)
	var menu_box := VBoxContainer.new()
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 16)
	menu_panel.add_child(menu_box)
	var eyebrow := _label("A KINGDOM BURIED IN ASH", 14, Color(0.79, 0.34, 0.25))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(eyebrow)
	var title := _label("BLACKTHORN\nOATH", 47, Color(0.94, 0.88, 0.79))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0.1, 0.0, 0.0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	menu_box.add_child(title)
	var subtitle := _label("RUN. FIGHT. SURVIVE THE HOLLOW.", 17, Color(0.78, 0.67, 0.61))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(subtitle)
	var instructions := _label("SWIPE  move  /  jump  /  slide\nATTACK  strike enemies before they reach you\nCOLLECT  lost relics to build your reserve", 15, Color(0.68, 0.67, 0.7))
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_line_spacing_override("line_spacing", 6)
	menu_box.add_child(instructions)
	var start := _button(menu_box, "ENTER THE RUINS", Vector2.ZERO, Vector2(0, 62), _start_run, Control.PRESET_TOP_LEFT, 20)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var footer := _label("BEST DISTANCE  %05d m     RELIC RESERVE  %03d" % [best_distance, relic_bank], 13, Color(0.62, 0.57, 0.59))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(footer)

	modal_panel = _make_overlay_panel(root, Vector2(470, 280))
	modal_panel.position = Vector2(-235, -140)
	modal_panel.visible = false
	var modal_box := VBoxContainer.new()
	modal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_box.add_theme_constant_override("separation", 16)
	modal_panel.add_child(modal_box)
	modal_title = _label("PAUSED", 34, Color(0.94, 0.86, 0.75))
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(modal_title)
	modal_body = _label("The ruins are silent. Your oath remains.", 15, Color(0.72, 0.67, 0.68))
	modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(modal_body)
	modal_action = _button(modal_box, "RESUME", Vector2.ZERO, Vector2(0, 58), _resume_run, Control.PRESET_TOP_LEFT, 19)
	modal_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _start_run() -> void:
	game_started = true
	game_over = false
	paused = false
	menu_panel.hide()
	hud.show()
	controls.show()
	pause_button.text = "Ⅱ"
	player.forward_speed = 12.0
	run_started_at = Time.get_ticks_msec() / 1000.0

func _toggle_pause() -> void:
	if not game_started or game_over:
		return
	if paused:
		_resume_run()
		return
	paused = true
	get_tree().paused = true
	modal_title.text = "PAUSED"
	modal_body.text = "Catch your breath. The Hollow is still waiting."
	modal_action.text = "RESUME"
	modal_action.pressed.disconnect(_resume_run)
	modal_action.pressed.connect(_resume_run)
	modal_panel.show()
	pause_button.text = "▶"

func _resume_run() -> void:
	paused = false
	get_tree().paused = false
	modal_panel.hide()
	pause_button.text = "Ⅱ"

func _show_game_over() -> void:
	game_over = true
	game_started = false
	paused = false
	get_tree().paused = false
	best_distance = maxi(best_distance, int(distance))
	_save_progress()
	modal_title.text = "OATH BROKEN"
	modal_body.text = "DISTANCE  %d m     KILLS  %d\nRELICS FOUND  %d\nBEST RUN  %d m" % [int(distance), kills, relics, best_distance]
	modal_action.text = "RUN AGAIN"
	for connection in modal_action.pressed.get_connections():
		modal_action.pressed.disconnect(connection.callable)
	modal_action.pressed.connect(func(): get_tree().reload_current_scene())
	modal_panel.show()

func _make_overlay_panel(parent: Control, dimensions: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-dimensions.x * 0.5, -dimensions.y * 0.5)
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.018, 0.027, 0.96), Color(0.42, 0.2, 0.16)))
	parent.add_child(panel)
	return panel

func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	return style

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _button(parent: Control, caption: String, offset: Vector2, dimensions: Vector2, action: Callable, preset: int, font_size: int) -> Button:
	var button := Button.new()
	button.text = caption
	button.set_anchors_preset(preset)
	button.position = offset
	button.size = dimensions
	button.custom_minimum_size = dimensions
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.94, 0.86, 0.76))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.85))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.075, 0.045, 0.055, 0.93)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.17, 0.07, 0.065, 0.97)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.34, 0.075, 0.055, 0.98)))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(0.53, 0.25, 0.19)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _spawn_segment(segment_z: float) -> void:
	var segment := Node3D.new()
	segment.name = "RuinedTrack_%d" % segments.size()
	segment.position.z = segment_z
	add_child(segment)
	segments.append(segment)

	_box(segment, Vector3(0, -0.36, -14), Vector3(9.4, 0.72, SEGMENT_LENGTH), _mat(Color(0.105, 0.095, 0.105), 0.12, 0.92), true)
	_box(segment, Vector3(-4.78, 0.16, -14), Vector3(0.24, 0.32, SEGMENT_LENGTH), _mat(Color(0.36, 0.17, 0.12), 0.25, 0.8))
	_box(segment, Vector3(4.78, 0.16, -14), Vector3(0.24, 0.32, SEGMENT_LENGTH), _mat(Color(0.36, 0.17, 0.12), 0.25, 0.8))

	# Stone lane seams and short center dashes make the three lanes legible.
	for lane_edge in [-1.3, 1.3]:
		_box(segment, Vector3(lane_edge, 0.012, -14), Vector3(0.035, 0.025, 27.5), _mat(Color(0.25, 0.21, 0.2), 0.05, 0.9))
	for dash in range(6):
		_box(segment, Vector3(0, 0.018, -2.5 - float(dash) * 4.2), Vector3(0.07, 0.025, 1.4), _mat(Color(0.39, 0.25, 0.2), 0.08, 0.78))

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_add_arch_and_ruins(segment, rng)

	for row in range(3):
		var lane := rng.randi_range(0, 2)
		var obstacle_z := -8.0 - float(row) * 8.0
		if rng.randf() < 0.58:
			var enemy := EnemyScript.new()
			enemy.configure(rng.randi_range(0, 2))
			enemy.position = Vector3(float(lane - 1) * LANE_WIDTH, 0, obstacle_z)
			segment.add_child(enemy)
		else:
			var hazard := HazardScript.new()
			var overhead := rng.randf() < 0.45
			var size := Vector3(1.55, 0.42, 1.5) if overhead else Vector3(1.55, 1.1, 1.5)
			hazard.position = Vector3(float(lane - 1) * LANE_WIDTH, 1.43 if overhead else 0.55, obstacle_z)
			var collision := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = size
			collision.shape = box_shape
			hazard.add_child(collision)
			_box(hazard, Vector3.ZERO, size, _mat(Color(0.18, 0.065, 0.055), 0.6, 0.48, Color(0.17, 0.015, 0.006)))
			if not overhead:
				for spike_index in range(3):
					var spike := MeshInstance3D.new()
					var spike_mesh := CylinderMesh.new()
					spike_mesh.top_radius = 0.012
					spike_mesh.bottom_radius = 0.22
					spike_mesh.height = 0.58
					spike_mesh.radial_segments = 6
					spike.mesh = spike_mesh
					spike.position = Vector3(-0.43 + float(spike_index) * 0.43, 0.78, 0)
					spike.material_override = _mat(Color(0.52, 0.55, 0.6), 0.88, 0.25)
					hazard.add_child(spike)
			segment.add_child(hazard)

		var relic := RelicScript.new()
		var relic_lane := (lane + 1 + row % 2) % 3
		relic.position = Vector3(float(relic_lane - 1) * LANE_WIDTH, 1.3, obstacle_z - 3.0)
		segment.add_child(relic)

	next_segment_z = segment_z - SEGMENT_LENGTH

func _add_arch_and_ruins(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var old_stone := _mat(Color(0.075, 0.07, 0.085), 0.18, 0.95)
	var cut_stone := _mat(Color(0.16, 0.14, 0.15), 0.16, 0.88)
	var ember := _mat(Color(0.85, 0.19, 0.055), 0.15, 0.35, Color(0.9, 0.075, 0.012))

	# A gate arch gives the road a visible destination and scale.
	for side in [-1.0, 1.0]:
		var x := side * 5.1
		_box(parent, Vector3(x, 2.15, -13.8), Vector3(0.95, 4.3, 1.0), old_stone)
		_box(parent, Vector3(x, 4.35, -13.8), Vector3(1.35, 0.45, 1.35), cut_stone)
		_box(parent, Vector3(x, 0.22, -13.8), Vector3(1.35, 0.44, 1.35), cut_stone)
		_box(parent, Vector3(x, 4.62, -13.8), Vector3(1.15, 0.12, 1.15), ember)
	_box(parent, Vector3(0, 4.35, -13.8), Vector3(10.8, 0.52, 0.85), old_stone)
	_box(parent, Vector3(0, 4.65, -13.8), Vector3(10.8, 0.12, 0.92), cut_stone)

	# Broken pillars and torch heads beyond the safe track edge.
	for side in [-1.0, 1.0]:
		for z in [-4.0, -23.0]:
			var height := rng.randf_range(2.8, 4.7)
			var column := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.34
			mesh.bottom_radius = 0.5
			mesh.height = height
			mesh.radial_segments = 7
			column.mesh = mesh
			column.position = Vector3(side * 6.4, height * 0.5, z)
			column.material_override = old_stone
			parent.add_child(column)
			_box(parent, Vector3(side * 6.4, 0.18, z), Vector3(1.25, 0.36, 1.25), cut_stone)
			var fire := MeshInstance3D.new()
			var fire_mesh := SphereMesh.new()
			fire_mesh.radius = 0.19
			fire_mesh.height = 0.42
			fire.mesh = fire_mesh
			fire.position = Vector3(side * 6.4, height + 0.38, z)
			fire.material_override = ember
			parent.add_child(fire)

		var rubble := MeshInstance3D.new()
		var rubble_mesh := BoxMesh.new()
		rubble_mesh.size = Vector3(rng.randf_range(0.7, 1.5), rng.randf_range(0.25, 0.65), 0.8)
		rubble.mesh = rubble_mesh
		rubble.position = Vector3(side * rng.randf_range(4.9, 5.5), 0.18, rng.randf_range(-26.0, -6.0))
		rubble.rotation.z = rng.randf_range(-0.3, 0.3)
		rubble.material_override = cut_stone
		parent.add_child(rubble)

func _update_track() -> void:
	if player.global_position.z < next_segment_z + SEGMENT_LENGTH * 2.0:
		_spawn_segment(next_segment_z)
	for i in range(segments.size() - 1, -1, -1):
		var segment := segments[i]
		if not is_instance_valid(segment):
			segments.remove_at(i)
		elif segment.global_position.z > player.global_position.z + SEGMENT_LENGTH * 1.8:
			segment.queue_free()
			segments.remove_at(i)

func _follow_camera(delta: float) -> void:
	var target_position := player.global_position + Vector3(0, 4.0, 8.2)
	camera.global_position = camera.global_position.lerp(target_position, minf(delta * 7.0, 1.0))
	camera.look_at(player.global_position + Vector3(0, 1.05, -6.2), Vector3.UP)

func _idle_camera(delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player):
		return
	var t := Time.get_ticks_msec() / 1000.0
	var desired := player.global_position + Vector3(sin(t * 0.22) * 0.16, 4.05, 8.2)
	camera.global_position = camera.global_position.lerp(desired, minf(delta * 2.0, 1.0))
	camera.look_at(player.global_position + Vector3(0, 1.0, -6.0), Vector3.UP)

func _update_hud() -> void:
	if not is_instance_valid(score_label):
		return
	score_label.text = "DISTANCE  %05d m      KILLS  %02d" % [int(distance), kills]
	health_label.text = "VITALITY   " + "♥  ".repeat(player.health) + "♡  ".repeat(3 - player.health)
	relic_label.text = "RELICS  %03d    /    RESERVE  %03d" % [relics, relic_bank]
	best_label.text = "BEST RUN  %05d m" % best_distance

func _on_health_changed(value: int) -> void:
	_update_hud()

func _on_player_died() -> void:
	_show_game_over()

func _show_game_over() -> void:
	game_over = true
	game_started = false
	paused = false
	get_tree().paused = false
	best_distance = maxi(best_distance, int(distance))
	_save_progress()
	modal_title.text = "OATH BROKEN"
	modal_body.text = "DISTANCE  %d m     KILLS  %d\nRELICS FOUND  %d\nBEST RUN  %d m" % [int(distance), kills, relics, best_distance]
	modal_action.text = "RUN AGAIN"
	for connection in modal_action.pressed.get_connections():
		modal_action.pressed.disconnect(connection.callable)
	modal_action.pressed.connect(func(): get_tree().reload_current_scene())
	modal_panel.show()
	_update_hud()

func _add_kill() -> void:
	kills += 1

func add_kill() -> void:
	_add_kill()

func add_relic() -> void:
	relics += 1
	relic_bank += 1
	_save_progress()
	_update_hud()

func _load_progress() -> void:
	if save_data.load("user://blackthorn_oath.cfg") == OK:
		best_distance = int(save_data.get_value("progress", "best_distance", 0))
		relic_bank = int(save_data.get_value("progress", "relic_bank", 0))

func _save_progress() -> void:
	save_data.set_value("progress", "best_distance", best_distance)
	save_data.set_value("progress", "relic_bank", relic_bank)
	save_data.save("user://blackthorn_oath.cfg")

func _mat(color: Color, metal: float = 0.0, rough: float = 0.8, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.7
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, solid: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		parent.add_child(body)
	return node
