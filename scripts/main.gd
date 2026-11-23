extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const HazardScript = preload("res://scripts/hazard.gd")
const RelicScript = preload("res://scripts/relic.gd")
const SCORE_PATH := "res://audio/blackthorn_cinematic_ambience.wav"
const CATHEDRAL_MODEL_PATH := "res://assets/models/generic-gothic-cathedral.glb"
const WARDEN_MODEL_PATH := "res://assets/models/t1-sentinel.glb"

const LANE_WIDTH: float = 2.6
const SEGMENT_LENGTH: float = 32.0
const INTRO_LENGTH: float = 18.0

var player: BlackthornOathPlayer
var camera: Camera3D
var soundtrack: AudioStreamPlayer
var ash_particles: CPUParticles3D
var segments: Array[Node3D] = []
var next_segment_z: float = 0.0
var segment_serial: int = 0

var distance: float = 0.0
var kills: int = 0
var relics: int = 0
var relic_bank: int = 0
var coin_wallet: int = 0
var blade_level: int = 0
var vitality_level: int = 0
var fortune_level: int = 0
var best_distance: int = 0
var save_data := ConfigFile.new()

var intro_active: bool = true
var intro_complete: bool = false
var intro_elapsed: float = 0.0
var game_started: bool = false
var game_over: bool = false
var paused: bool = false
var run_started_at: float = 0.0
var tutorial_timer: float = 0.0
var touch_start: Vector2 = Vector2.ZERO
var touch_tracking: bool = false

var root_ui: Control
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
var coin_label: Label
var shop_panel: PanelContainer
var shop_status_label: Label
var contracts_panel: PanelContainer
var contracts_status_label: Label
var daily_key: String = ""
var daily_kills: int = 0
var daily_relics: int = 0
var daily_distance: int = 0
var daily_distance_last_sample: int = 0
var daily_claimed: Array[bool] = [false, false, false]
var lifetime_kills: int = 0
var lifetime_relics: int = 0
var lifetime_runs: int = 0
var lifetime_distance: int = 0
var subtitle_label: Label
var intro_title_label: Label
var intro_kicker_label: Label
var skip_intro_button: Button
var tutorial_label: Label
var top_letterbox: ColorRect
var bottom_letterbox: ColorRect
var fade_overlay: ColorRect

var stone_material: ShaderMaterial
var dark_stone_material: ShaderMaterial
var worn_stone_material: ShaderMaterial
var metal_material: StandardMaterial3D
var gold_material: StandardMaterial3D
var ember_material: StandardMaterial3D
var glass_material: StandardMaterial3D
var banner_shader: Shader
var cathedral_gate_left: Node3D
var cathedral_gate_right: Node3D
var portal_light: OmniLight3D
var gate_guardian: Node3D

func _ready() -> void:
	_load_progress()
	_make_material_library()
	_build_environment()
	_build_cathedral_landmark()
	_build_kaykit_dungeon_dressing()
	_build_distant_silhouette()
	_build_player_and_camera()
	_build_interface()
	_build_ashfall()
	_start_soundtrack()
	_load_sfx_library()
	for i in range(7):
		_spawn_segment(-float(i) * SEGMENT_LENGTH)
	_update_hud()
	_fade_from_black()

func _process(delta: float) -> void:
	if intro_active:
		_update_cinematic(delta)
		return
	if not game_started or paused or game_over:
		_idle_camera(delta)
		return

	distance = maxf(distance, -player.global_position.z - 3.0)
	var measured_distance := int(distance)
	var distance_delta := maxi(0, measured_distance - daily_distance_last_sample)
	daily_distance_last_sample = measured_distance
	if distance_delta > 0:
		daily_distance += distance_delta
		_update_contracts_ui()
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - run_started_at
	player.forward_speed = minf(12.0 + elapsed * 0.14, 18.5)
	_update_hud()
	_follow_camera(delta)
	_update_track()
	if tutorial_timer > 0.0:
		tutorial_timer = maxf(0.0, tutorial_timer - delta)
		tutorial_label.modulate.a = clampf(tutorial_timer, 0.0, 1.0)
		if tutorial_timer <= 0.0:
			tutorial_label.hide()

func _input(event: InputEvent) -> void:
	if not game_started or paused or game_over:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
			touch_tracking = true
		elif touch_tracking:
			var swipe: Vector2 = (event as InputEventScreenTouch).position - touch_start
			touch_tracking = false
			if swipe.length() >= 38.0:
				if absf(swipe.x) > absf(swipe.y):
					player.move_lane(1 if swipe.x > 0.0 else -1)
				elif swipe.y < 0.0:
					player.jump()
				else:
					player.slide()

func _make_material_library() -> void:
	var stone_shader := Shader.new()
	stone_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_tint : source_color = vec4(0.16, 0.15, 0.17, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.88;
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
void fragment() {
	vec2 p = UV * vec2(13.0, 9.0);
	float broad = noise21(p * 0.34);
	float grain = noise21(p * 3.2);
	float grit = noise21(p * 15.0);
	float seam = smoothstep(0.78, 0.92, noise21(p * vec2(3.0, 7.0)));
	float value = 0.68 + broad * 0.22 + grain * 0.13 + grit * 0.055 - seam * 0.09;
	ALBEDO = base_tint.rgb * value;
	ROUGHNESS = clamp(roughness_value + (grit - 0.5) * 0.08, 0.65, 1.0);
	METALLIC = 0.035;
}
"""
	stone_material = ShaderMaterial.new()
	stone_material.shader = stone_shader
	stone_material.set_shader_parameter("base_tint", Color(0.37, 0.34, 0.32, 1.0))
	stone_material.set_shader_parameter("roughness_value", 0.92)
	dark_stone_material = ShaderMaterial.new()
	dark_stone_material.shader = stone_shader
	dark_stone_material.set_shader_parameter("base_tint", Color(0.16, 0.145, 0.16, 1.0))
	dark_stone_material.set_shader_parameter("roughness_value", 0.96)
	worn_stone_material = ShaderMaterial.new()
	worn_stone_material.shader = stone_shader
	worn_stone_material.set_shader_parameter("base_tint", Color(0.46, 0.39, 0.32, 1.0))
	worn_stone_material.set_shader_parameter("roughness_value", 0.9)

	metal_material = _standard_material(Color(0.13, 0.145, 0.18), 0.88, 0.27)
	gold_material = _standard_material(Color(0.58, 0.34, 0.13), 0.78, 0.34)
	ember_material = _standard_material(Color(0.9, 0.15, 0.035), 0.1, 0.28, Color(1.0, 0.055, 0.008), 3.2)
	glass_material = _standard_material(Color(0.13, 0.035, 0.09), 0.2, 0.22, Color(0.27, 0.015, 0.12), 1.8)

	banner_shader = Shader.new()
	banner_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 cloth_color : source_color = vec4(0.19, 0.018, 0.035, 1.0);
uniform vec4 edge_color : source_color = vec4(0.65, 0.35, 0.12, 1.0);
void vertex() {
	float wave = sin(TIME * 1.35 + UV.y * 5.8) * UV.y * 0.16;
	VERTEX.x += wave;
	VERTEX.z += cos(TIME * 1.1 + UV.y * 4.4) * UV.y * 0.09;
}
void fragment() {
	float border = step(UV.x, 0.045) + step(0.955, UV.x);
	float folds = 0.85 + 0.15 * sin(UV.x * 24.0 + UV.y * 2.0);
	ALBEDO = mix(cloth_color.rgb, edge_color.rgb, clamp(border, 0.0, 1.0)) * folds;
	ROUGHNESS = 0.91;
}
"""

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.009, 0.008, 0.022)
	sky_material.sky_horizon_color = Color(0.14, 0.042, 0.052)
	sky_material.ground_bottom_color = Color(0.008, 0.006, 0.014)
	sky_material.ground_horizon_color = Color(0.065, 0.027, 0.035)
	sky_material.sun_angle_max = 12.0
	sky_material.sun_curve = 0.12
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.52, 0.50, 0.58)
	environment.ambient_light_energy = 0.88
	environment.tonemap_exposure = 0.98
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.42
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 0.92
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.15, 0.105, 0.12)
	environment.fog_density = 0.0027
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.91
	world.environment = environment
	add_child(world)

	var moonlight := DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-35, -28, 0)
	moonlight.light_color = Color(0.76, 0.79, 0.92)
	moonlight.light_energy = 1.28
	moonlight.shadow_enabled = true
	moonlight.directional_shadow_max_distance = 95.0
	moonlight.shadow_bias = 0.035
	add_child(moonlight)

	var crimson_fill := OmniLight3D.new()
	crimson_fill.position = Vector3(0, 8.0, -24.0)
	crimson_fill.light_color = Color(0.46, 0.045, 0.055)
	crimson_fill.light_energy = 1.15
	crimson_fill.omni_range = 38.0
	add_child(crimson_fill)

func _build_player_and_camera() -> void:
	player = PlayerScript.new()
	player.name = "OathboundKnight"
	player.position = Vector3(0, 0, -3.0)
	player.forward_speed = 0.0
	add_child(player)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	_apply_player_upgrades()

	camera = Camera3D.new()
	camera.name = "CinematicCamera"
	camera.current = true
	camera.fov = 54.0
	camera.near = 0.08
	camera.far = 320.0
	camera.position = Vector3(22.0, 15.5, 20.0)
	add_child(camera)
	camera.look_at(Vector3(0, 16.0, -154.0), Vector3.UP)

func _build_cathedral_landmark() -> void:
	# A full-scale cathedral mesh anchors the skyline. The foreground gatehouse is
	# kept separate so the Bell Warden is visible through the open portal.
	var cathedral_added := false
	if ResourceLoader.exists(CATHEDRAL_MODEL_PATH):
		var cathedral_scene: PackedScene = load(CATHEDRAL_MODEL_PATH) as PackedScene
		if cathedral_scene != null:
			var cathedral: Node3D = cathedral_scene.instantiate() as Node3D
			cathedral.name = "ImportedGothicCathedral"
			cathedral.position = Vector3(0, 0, -145)
			cathedral.scale = Vector3(0.64, 0.64, 0.64)
			cathedral.rotation.y = PI
			add_child(cathedral)
			_apply_asset_tint(cathedral, Color(0.58, 0.60, 0.64, 1.0))
			cathedral_added = true
	if not cathedral_added:
		_build_cathedral_fallback()

	var gatehouse := Node3D.new()
	gatehouse.name = "OuterGateOfTheLastCathedral"
	gatehouse.position.z = -94.0
	add_child(gatehouse)

	# Two monumental piers and a pointed arch frame the open approach.
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		var x: float = side * 7.1
		_box(gatehouse, Vector3(x, 8.4, 0), Vector3(2.0, 16.8, 2.2), dark_stone_material)
		_box(gatehouse, Vector3(x, 0.55, -0.08), Vector3(2.8, 1.1, 3.0), worn_stone_material)
		_box(gatehouse, Vector3(x, 16.7, -0.05), Vector3(3.0, 0.7, 3.1), worn_stone_material)
		_box(gatehouse, Vector3(x, 17.3, -0.05), Vector3(2.45, 0.16, 2.6), gold_material)
		_make_spire(gatehouse, Vector3(x, 17.3, 0.0), 5.2, 0.64, metal_material)
		_add_brazier(gatehouse, side * 8.3, 2.6, -0.8)
	_add_front_gothic_arch(gatehouse, Vector3(0, 0.05, -0.6), 14.2, 18.0, 1.25, worn_stone_material)
	_box(gatehouse, Vector3(0, 17.65, -0.58), Vector3(9.8, 0.72, 1.4), dark_stone_material)
	_box(gatehouse, Vector3(0, 18.1, -0.58), Vector3(8.8, 0.14, 1.5), gold_material)

	# Two independently hinged leaves leave a wide sight line into the cathedral.
	var gate_wood := _standard_material(Color(0.055, 0.028, 0.028), 0.46, 0.55)
	cathedral_gate_left = Node3D.new()
	cathedral_gate_left.position = Vector3(-3.15, 0, -1.15)
	gatehouse.add_child(cathedral_gate_left)
	cathedral_gate_right = Node3D.new()
	cathedral_gate_right.position = Vector3(3.15, 0, -1.15)
	gatehouse.add_child(cathedral_gate_right)
	for gate_side in range(2):
		var gate: Node3D = cathedral_gate_left if gate_side == 0 else cathedral_gate_right
		var panel_center: float = 1.55 if gate_side == 0 else -1.55
		_box(gate, Vector3(panel_center, 6.5, 0), Vector3(3.1, 13.0, 0.34), gate_wood)
		for rail_index in range(8):
			var rail_y: float = 0.65 + float(rail_index) * 1.65
			_box(gate, Vector3(panel_center, rail_y, -0.22), Vector3(3.0, 0.13, 0.16), gold_material)
		for rib_index in range(4):
			var rib_x: float = panel_center - 1.12 + float(rib_index) * 0.75
			_box(gate, Vector3(rib_x, 6.5, -0.25), Vector3(0.14, 12.7, 0.15), metal_material)
		_box(gate, Vector3(panel_center, 6.6, -0.34), Vector3(0.52, 1.8, 0.14), gold_material)

	_add_gate_guardian(gatehouse)
	portal_light = OmniLight3D.new()
	portal_light.position = Vector3(0, 8.2, -1.0)
	portal_light.light_color = Color(0.92, 0.10, 0.025)
	portal_light.light_energy = 0.45
	portal_light.omni_range = 24.0
	gatehouse.add_child(portal_light)

	# Broad forecourt steps establish a clear approach to the portal.
	for step_index in range(7):
		var width: float = 17.0 + float(step_index) * 1.2
		_box(gatehouse, Vector3(0, 0.16 + float(step_index) * 0.12, 1.0 + float(step_index) * 1.0), Vector3(width, 0.32, 1.1), worn_stone_material, true)
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		_box(gatehouse, Vector3(side * 10.0, 2.0, -7.0), Vector3(2.2, 4.0, 1.1), dark_stone_material)
		_box(gatehouse, Vector3(side * 11.0, 5.0, -7.0), Vector3(3.0, 0.55, 1.5), worn_stone_material)

func _build_cathedral_fallback() -> void:
	var fallback := Node3D.new()
	fallback.name = "ProceduralCathedralFallback"
	fallback.position.z = -158.0
	add_child(fallback)
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		var x: float = side * 11.0
		_box(fallback, Vector3(x, 17.0, 0), Vector3(8.0, 34.0, 12.0), dark_stone_material)
		_box(fallback, Vector3(x, 34.0, -5.4), Vector3(8.5, 1.0, 1.5), worn_stone_material)
		_make_spire(fallback, Vector3(x, 34.0, 0), 18.0, 2.6, gold_material)
		_add_buttress(fallback, side * 7.0, 0, 2.0, 25.0)
	_box(fallback, Vector3(0, 29.0, 0), Vector3(17.0, 10.0, 10.0), dark_stone_material)
	_box(fallback, Vector3(0, 34.0, -5.4), Vector3(18.0, 0.8, 1.3), worn_stone_material)
	_make_spire(fallback, Vector3(0, 34.0, 0), 16.0, 1.8, metal_material)


func _add_gate_guardian(parent: Node3D) -> void:
	gate_guardian = Node3D.new()
	gate_guardian.name = "TheBellWarden"
	gate_guardian.position = Vector3(0, 0, -5.2)
	gate_guardian.visible = false
	parent.add_child(gate_guardian)

	if ResourceLoader.exists(WARDEN_MODEL_PATH):
		var sentinel_scene: PackedScene = load(WARDEN_MODEL_PATH) as PackedScene
		if sentinel_scene != null:
			var sentinel: Node3D = sentinel_scene.instantiate() as Node3D
			if sentinel != null:
				sentinel.name = "RiggedBellWarden"
				sentinel.rotation.y = PI
				gate_guardian.add_child(sentinel)
				_fit_asset_height(sentinel, 8.6)
				_apply_asset_tint(sentinel, Color(0.36, 0.34, 0.40, 1.0))
				var animation_nodes := sentinel.find_children("*", "AnimationPlayer", true, false)
				if not animation_nodes.is_empty():
					var animation_player := animation_nodes[0] as AnimationPlayer
					animation_player.add_to_group("shared_combat_animation_source")
					if animation_player.has_animation("idle"):
						animation_player.play("idle")
				# Broken crown spikes and red eyes give the sentinel its own boss identity.
				_make_spire(gate_guardian, Vector3(-0.5, 7.45, 0.05), 2.25, 0.22, dark_stone_material)
				_make_spire(gate_guardian, Vector3(0.5, 7.45, 0.05), 2.25, 0.22, dark_stone_material)
				var warden_eyes := _standard_material(Color(0.95, 0.018, 0.008), 0.08, 0.18, Color(1.0, 0.008, 0.002), 4.8)
				for face_z in [-0.42, 0.42]:
					_sphere(gate_guardian, Vector3(-0.2, 7.12, face_z), Vector3(0.12, 0.09, 0.055), warden_eyes)
					_sphere(gate_guardian, Vector3(0.2, 7.12, face_z), Vector3(0.12, 0.09, 0.055), warden_eyes)
				var eye_light := OmniLight3D.new()
				eye_light.position = Vector3(0, 7.1, 0)
				eye_light.light_color = Color(1.0, 0.025, 0.008)
				eye_light.light_energy = 0.65
				eye_light.omni_range = 3.2
				eye_light.shadow_enabled = false
				gate_guardian.add_child(eye_light)
				_sphere(gate_guardian, Vector3(0, 3.8, -0.42), Vector3(0.3, 0.42, 0.08), ember_material)
				return

	_build_procedural_gate_guardian()

func _build_procedural_gate_guardian() -> void:
	var black_iron := _standard_material(Color(0.08, 0.085, 0.11), 0.86, 0.3)
	var ash_bone := _standard_material(Color(0.28, 0.23, 0.22), 0.12, 0.86)
	var blood_glow := _standard_material(Color(0.95, 0.025, 0.01), 0.08, 0.2, Color(1.0, 0.012, 0.002), 4.2)
	_box(gate_guardian, Vector3(0, 5.2, 0), Vector3(2.6, 3.5, 1.3), black_iron)
	_box(gate_guardian, Vector3(0, 6.15, -0.12), Vector3(3.6, 1.35, 1.55), metal_material)
	_sphere(gate_guardian, Vector3(0, 7.45, -0.02), Vector3(1.35, 1.55, 1.05), black_iron)
	_sphere(gate_guardian, Vector3(-0.28, 7.44, -0.61), Vector3(0.19, 0.14, 0.08), blood_glow)
	_sphere(gate_guardian, Vector3(0.28, 7.44, -0.61), Vector3(0.19, 0.14, 0.08), blood_glow)
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		_box(gate_guardian, Vector3(side * 1.78, 6.1, -0.02), Vector3(1.1, 1.55, 1.25), black_iron)
		_capsule(gate_guardian, Vector3(side * 1.9, 4.65, -0.02), 0.33, 1.65, ash_bone)
		_box(gate_guardian, Vector3(side * 0.72, 2.7, 0.0), Vector3(0.82, 2.9, 0.92), black_iron)

func _add_cathedral_tower(parent: Node3D, x: float, base_y: float, height: float, width: float) -> void:
	var tower := Node3D.new()
	tower.position = Vector3(x, base_y, 0)
	parent.add_child(tower)
	_box(tower, Vector3.ZERO, Vector3(width, height * 0.74, width), dark_stone_material)
	_box(tower, Vector3(0, height * 0.37, -width * 0.52), Vector3(width * 0.74, height * 0.61, 0.22), stone_material)
	for level in range(4):
		var y: float = 2.5 + float(level) * 5.2
		_box(tower, Vector3(0, y, -width * 0.57), Vector3(width * 1.22, 0.36, 0.65), worn_stone_material)
		_box(tower, Vector3(0, y + 0.2, -width * 0.57), Vector3(width * 1.07, 0.12, 0.76), gold_material)
		for side_index in range(2):
			var side: float = -1.0 if side_index == 0 else 1.0
			_box(tower, Vector3(side * width * 0.37, y + 1.1, -width * 0.58), Vector3(0.42, 2.3, 0.23), stone_material)
	_add_front_gothic_arch(tower, Vector3(0, height * 0.38, -width * 0.56), width * 0.42, height * 0.27, 0.22, worn_stone_material)
	_box(tower, Vector3(0, height * 0.39, -width * 0.6), Vector3(width * 0.27, height * 0.18, 0.08), glass_material)
	var roof := MeshInstance3D.new()
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.05
	roof_mesh.bottom_radius = width * 0.68
	roof_mesh.height = height * 0.29
	roof_mesh.radial_segments = 8
	roof.mesh = roof_mesh
	roof.position = Vector3(0, height * 0.87, 0)
	roof.material_override = metal_material
	tower.add_child(roof)
	_make_spire(tower, Vector3(0, height * 1.02, 0), 4.2, 0.42, gold_material)

func _add_front_gothic_arch(parent: Node3D, center: Vector3, width: float, height: float, depth: float, material: Material) -> void:
	var spring: float = height * 0.52
	var pillar_width: float = maxf(0.28, width * 0.085)
	_box(parent, center + Vector3(-width * 0.5 + pillar_width * 0.5, spring * 0.5, 0), Vector3(pillar_width, spring, depth), material)
	_box(parent, center + Vector3(width * 0.5 - pillar_width * 0.5, spring * 0.5, 0), Vector3(pillar_width, spring, depth), material)
	_box(parent, center + Vector3(-width * 0.5, 0.18, 0), Vector3(pillar_width * 1.7, 0.36, depth * 1.35), worn_stone_material)
	_box(parent, center + Vector3(width * 0.5, 0.18, 0), Vector3(pillar_width * 1.7, 0.36, depth * 1.35), worn_stone_material)
	var half_width: float = width * 0.5
	var arch_height: float = height - spring
	for segment_index in range(14):
		var x0: float = -half_width + float(segment_index) * (width / 14.0)
		var x1: float = x0 + width / 14.0
		var normalized0: float = absf(x0 / half_width)
		var normalized1: float = absf(x1 / half_width)
		var y0: float = spring + arch_height * (1.0 - pow(normalized0, 0.72))
		var y1: float = spring + arch_height * (1.0 - pow(normalized1, 0.72))
		var midpoint: Vector3 = center + Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0)
		var segment_length: float = Vector2(x1 - x0, y1 - y0).length()
		var beam := _box(parent, midpoint, Vector3(segment_length + 0.11, pillar_width, depth), material)
		beam.rotation.z = atan2(y1 - y0, x1 - x0)

func _add_buttress(parent: Node3D, x: float, y: float, z: float, height: float) -> void:
	var buttress := _box(parent, Vector3(x, y + height * 0.48, z), Vector3(1.2, height * 0.96, 1.35), dark_stone_material)
	buttress.rotation.z = deg_to_rad(-7.0 if x > 0.0 else 7.0)
	_box(parent, Vector3(x, y + height, z), Vector3(2.0, 0.55, 1.8), worn_stone_material)
	_box(parent, Vector3(x, y + 1.4, z), Vector3(1.55, 0.4, 1.6), stone_material)

func _add_cathedral_sentinel(parent: Node3D, x: float) -> void:
	var plinth := Vector3(x, 1.3, -3.55)
	_box(parent, plinth, Vector3(1.75, 2.6, 1.65), worn_stone_material)
	_box(parent, plinth + Vector3(0, 1.55, 0), Vector3(2.05, 0.3, 1.95), gold_material)
	_capsule(parent, plinth + Vector3(0, 3.3, 0), 0.47, 3.2, dark_stone_material)
	_box(parent, plinth + Vector3(0, 3.3, -0.15), Vector3(1.15, 1.25, 0.8), stone_material)
	_sphere(parent, plinth + Vector3(0, 5.1, -0.08), Vector3(0.78, 0.9, 0.72), dark_stone_material)
	_box(parent, plinth + Vector3(0, 4.9, -0.52), Vector3(0.55, 0.1, 0.08), ember_material)
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		_box(parent, plinth + Vector3(side * 0.82, 3.8, 0), Vector3(0.42, 2.25, 0.48), dark_stone_material)
		_box(parent, plinth + Vector3(side * 0.82, 2.65, -0.1), Vector3(0.48, 0.42, 0.56), gold_material)

func _make_spire(parent: Node3D, position: Vector3, height: float, radius: float, material: Material) -> void:
	var spire := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.015
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	spire.mesh = mesh
	spire.position = position + Vector3(0, height * 0.5, 0)
	spire.material_override = material
	parent.add_child(spire)
	var finial := MeshInstance3D.new()
	var finial_mesh := SphereMesh.new()
	finial_mesh.radius = radius * 0.14
	finial_mesh.height = radius * 0.28
	finial.mesh = finial_mesh
	finial.position = position + Vector3(0, height, 0)
	finial.material_override = gold_material
	parent.add_child(finial)

func _build_distant_silhouette() -> void:
	var horizon := Node3D.new()
	horizon.name = "AshenHorizon"
	add_child(horizon)

	# Continuous surrounding ground removes the empty void around the road.
	var earth := MeshInstance3D.new()
	var earth_mesh := PlaneMesh.new()
	earth_mesh.size = Vector2(230.0, 390.0)
	earth.mesh = earth_mesh
	earth.position = Vector3(0, -1.25, -150.0)
	earth.material_override = _make_ash_ground_material()
	horizon.add_child(earth)

	var ridge_material := _standard_material(Color(0.075, 0.068, 0.09), 0.03, 0.98)
	_build_mountain_ridge(horizon, -1.0, ridge_material)
	_build_mountain_ridge(horizon, 1.0, ridge_material)

	# Wind-bent dead trees and weathered boulders break up the broad terrain plane.
	var terrain_rng := RandomNumberGenerator.new()
	terrain_rng.seed = 28471
	for tree_index in range(9):
		var side: float = -1.0 if tree_index % 2 == 0 else 1.0
		var tree_x: float = side * terrain_rng.randf_range(17.0, 34.0)
		var tree_z: float = terrain_rng.randf_range(-118.0, -24.0)
		var tree_height: float = terrain_rng.randf_range(6.5, 11.5)
		_add_dead_tree(horizon, Vector3(tree_x, -0.7, tree_z), tree_height)
	for rock_index in range(18):
		var side: float = -1.0 if rock_index % 2 == 0 else 1.0
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 0.5
		rock_mesh.height = 1.0
		rock.mesh = rock_mesh
		rock.scale = Vector3(terrain_rng.randf_range(1.0, 2.8), terrain_rng.randf_range(0.45, 1.1), terrain_rng.randf_range(0.8, 2.2))
		rock.position = Vector3(side * terrain_rng.randf_range(11.0, 28.0), -0.35, terrain_rng.randf_range(-128.0, -18.0))
		rock.rotation = Vector3(terrain_rng.randf_range(-0.4, 0.4), terrain_rng.randf_range(0.0, TAU), terrain_rng.randf_range(-0.4, 0.4))
		rock.material_override = _standard_material(Color(0.16, 0.12, 0.12), 0.04, 0.96)
		horizon.add_child(rock)

	# Watchtowers puncture the ridgeline at different depths.
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		for tower_index in range(3):
			var tower_z: float = -62.0 - float(tower_index) * 42.0
			var tower_x: float = side * (27.0 + float(tower_index) * 4.0)
			_box(horizon, Vector3(tower_x, 7.0, tower_z), Vector3(3.2, 14.0, 3.2), dark_stone_material)
			_box(horizon, Vector3(tower_x, 14.0, tower_z), Vector3(4.4, 0.7, 4.4), worn_stone_material)
			_make_spire(horizon, Vector3(tower_x, 14.2, tower_z), 8.0, 1.5, metal_material)

func _make_ash_ground_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		total += noise21(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.48;
	}
	return total;
}
void fragment() {
	vec2 p = UV * vec2(92.0, 138.0);
	float broad = fbm(p * 0.08);
	float grain = fbm(p * 0.78);
	float cracks = smoothstep(0.78, 0.93, noise21(p * 1.65));
	vec3 dark_rock = vec3(0.045, 0.040, 0.052);
	vec3 warm_ash = vec3(0.15, 0.105, 0.10);
	vec3 stone = mix(dark_rock, warm_ash, broad * 0.78 + 0.08);
	stone += (grain - 0.5) * 0.045;
	stone *= 1.0 - cracks * 0.22;
	ALBEDO = stone;
	ROUGHNESS = 0.96;
	METALLIC = 0.02;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _add_dead_tree(parent: Node3D, origin: Vector3, height: float) -> void:
	var bark := _standard_material(Color(0.075, 0.050, 0.045), 0.0, 0.98)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.07
	trunk_mesh.bottom_radius = 0.42
	trunk_mesh.height = height
	trunk_mesh.radial_segments = 6
	trunk.mesh = trunk_mesh
	trunk.position = origin + Vector3(0, height * 0.5, 0)
	trunk.rotation.z = 0.09 if origin.x > 0.0 else -0.09
	trunk.material_override = bark
	parent.add_child(trunk)
	for branch_index in range(4):
		var side: float = -1.0 if branch_index % 2 == 0 else 1.0
		var branch_height: float = height * (0.44 + float(branch_index) * 0.105)
		var branch_length: float = 1.7 + float(branch_index % 3) * 0.65
		var branch := MeshInstance3D.new()
		var branch_mesh := CylinderMesh.new()
		branch_mesh.top_radius = 0.025
		branch_mesh.bottom_radius = 0.12
		branch_mesh.height = branch_length
		branch_mesh.radial_segments = 5
		branch.mesh = branch_mesh
		branch.position = origin + Vector3(side * branch_length * 0.34, branch_height, 0)
		branch.rotation.z = -side * 0.82
		branch.material_override = bark
		parent.add_child(branch)

func _build_mountain_ridge(parent: Node3D, side: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array = []
	var x_steps: int = 36
	var z_steps: int = 24
	for z_index in range(z_steps + 1):
		var row: Array = []
		var depth: float = 22.0 + float(z_index) * 10.5
		for x_index in range(x_steps + 1):
			var u: float = float(x_index) / float(x_steps)
			var x_distance: float = 12.0 + u * 58.0
			var broad: float = sin(u * PI * 2.6 + side * 0.7) * 4.0
			var sharp: float = pow(maxf(0.0, sin(u * PI * 7.0 + side * 1.8)), 3.0) * 12.0
			var broken: float = sin(u * 41.0 + float(z_index) * 0.31) * 1.4
			var height: float = 7.0 + broad + sharp + broken - float(z_index) * 0.06
			row.append(Vector3(side * x_distance, height, -depth))
		points.append(row)
	for z_index in range(z_steps):
		for x_index in range(x_steps):
			var a: Vector3 = points[z_index][x_index]
			var b: Vector3 = points[z_index][x_index + 1]
			var c_point: Vector3 = points[z_index + 1][x_index]
			var d: Vector3 = points[z_index + 1][x_index + 1]
			if side > 0.0:
				surface.add_vertex(a); surface.add_vertex(c_point); surface.add_vertex(b)
				surface.add_vertex(b); surface.add_vertex(c_point); surface.add_vertex(d)
			else:
				surface.add_vertex(a); surface.add_vertex(b); surface.add_vertex(c_point)
				surface.add_vertex(b); surface.add_vertex(d); surface.add_vertex(c_point)
	surface.generate_normals()
	var ridge := MeshInstance3D.new()
	ridge.mesh = surface.commit()
	ridge.material_override = material
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ridge)


func _build_ashfall() -> void:
	ash_particles = CPUParticles3D.new()
	ash_particles.name = "AshInTheWind"
	ash_particles.amount = 105
	ash_particles.lifetime = 9.0
	ash_particles.preprocess = 4.0
	ash_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash_particles.emission_box_extents = Vector3(12.0, 7.0, 42.0)
	ash_particles.direction = Vector3(0.18, 0.35, -1.0)
	ash_particles.spread = 16.0
	ash_particles.initial_velocity_min = 0.12
	ash_particles.initial_velocity_max = 0.62
	ash_particles.gravity = Vector3(0.0, -0.025, 0.0)
	ash_particles.scale_amount_min = 0.018
	ash_particles.scale_amount_max = 0.055
	ash_particles.color = Color(0.72, 0.58, 0.49, 0.68)
	ash_particles.position = Vector3(0, 5.0, -12.0)
	var fleck := SphereMesh.new()
	fleck.radius = 0.045
	fleck.height = 0.09
	var fleck_material := _standard_material(Color(0.74, 0.48, 0.29), 0.0, 1.0, Color(0.25, 0.08, 0.025), 0.45)
	ash_particles.mesh = fleck
	ash_particles.material_override = fleck_material
	add_child(ash_particles)

var sfx_library: Dictionary = {}
var sfx_rng := RandomNumberGenerator.new()

func _load_sfx_library() -> void:
	sfx_rng.randomize()
	sfx_library = {"sword": [], "impact": [], "footstep": [], "creature": [], "pickup": []}
	_scan_sfx_directory("res://audio/sfx")
	for kind in sfx_library.keys():
		print("SFX_LIBRARY ", kind, " count=", (sfx_library[kind] as Array).size())

func _scan_sfx_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		var extension := file_name.get_extension().to_lower()
		if extension not in ["wav", "ogg", "mp3"]:
			continue
		var stream := load(path.path_join(file_name)) as AudioStream
		if stream == null:
			continue
		var normalized := file_name.to_lower()
		var category := ""
		if normalized.contains("sword") or normalized.contains("swoosh") or normalized.contains("swish") or normalized.contains("swing") or normalized.contains("slash") or normalized.contains("weapon"):
			category = "sword"
		elif normalized.contains("step") or normalized.contains("foot") or normalized.contains("walk") or normalized.contains("run") or normalized.contains("chainmail") or normalized.contains("armor-light"):
			category = "footstep"
		elif normalized.contains("growl") or normalized.contains("roar") or normalized.contains("snarl") or normalized.contains("monster") or normalized.contains("ogre") or normalized.contains("giant") or normalized.contains("bite") or normalized.contains("grunt"):
			category = "creature"
		elif normalized.contains("coin") or normalized.contains("collect") or normalized.contains("pickup") or normalized.contains("item"):
			category = "pickup"
		elif normalized.contains("hit") or normalized.contains("impact") or normalized.contains("clash") or normalized.contains("metal") or normalized.contains("block") or normalized.contains("punch"):
			category = "impact"
		if category != "":
			(sfx_library[category] as Array).append(stream)
	for subdirectory in directory.get_directories():
		_scan_sfx_directory(path.path_join(subdirectory))

func play_sfx(kind: String, world_position: Vector3 = Vector3.ZERO) -> void:
	var candidates: Array = sfx_library.get(kind, [])
	if candidates.is_empty():
		return
	var stream := candidates[sfx_rng.randi_range(0, candidates.size() - 1)] as AudioStream
	if stream == null:
		return
	var source := AudioStreamPlayer3D.new()
	source.stream = stream
	source.volume_db = -5.0 if kind == "impact" else -8.0
	source.unit_size = 8.0
	source.max_distance = 36.0
	source.position = world_position
	add_child(source)
	source.finished.connect(source.queue_free)
	source.play()

func _start_soundtrack() -> void:
	var audio_stream := load(SCORE_PATH) as AudioStreamWAV
	if audio_stream == null:
		return
	audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio_stream.loop_begin = 0
	audio_stream.loop_end = audio_stream.mix_rate * 24
	soundtrack = AudioStreamPlayer.new()
	soundtrack.name = "OriginalDarkFantasyScore"
	soundtrack.stream = audio_stream
	soundtrack.volume_db = -13.5
	soundtrack.bus = "Master"
	add_child(soundtrack)
	soundtrack.play()

func _fade_from_black() -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, 2.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): fade_overlay.hide())

func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "CinematicAndGameUI"
	add_child(canvas)
	root_ui = Control.new()
	root_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root_ui)

	top_letterbox = ColorRect.new()
	top_letterbox.color = Color(0.008, 0.006, 0.012, 0.95)
	top_letterbox.anchor_right = 1.0
	top_letterbox.offset_bottom = 45.0
	root_ui.add_child(top_letterbox)
	bottom_letterbox = ColorRect.new()
	bottom_letterbox.color = Color(0.008, 0.006, 0.012, 0.95)
	bottom_letterbox.anchor_top = 1.0
	bottom_letterbox.anchor_right = 1.0
	bottom_letterbox.offset_top = -48.0
	root_ui.add_child(bottom_letterbox)

	intro_kicker_label = _label("A DARK FANTASY RUNNER", 13, Color(0.8, 0.42, 0.28))
	intro_kicker_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	intro_kicker_label.position = Vector2(-160, 76)
	intro_kicker_label.size = Vector2(320, 25)
	intro_kicker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_ui.add_child(intro_kicker_label)

	intro_title_label = _label("", 54, Color(0.95, 0.88, 0.78))
	intro_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	intro_title_label.position = Vector2(-310, 85)
	intro_title_label.size = Vector2(620, 155)
	intro_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	intro_title_label.add_theme_constant_override("shadow_offset_x", 3)
	intro_title_label.add_theme_constant_override("shadow_offset_y", 4)
	intro_title_label.hide()
	root_ui.add_child(intro_title_label)

	subtitle_label = _label("", 20, Color(0.91, 0.85, 0.79))
	subtitle_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle_label.position = Vector2(-560, -118)
	subtitle_label.size = Vector2(1120, 42)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	root_ui.add_child(subtitle_label)

	skip_intro_button = _button(root_ui, "SKIP  ›", Vector2(-126, 66), Vector2(102, 42), _skip_intro, Control.PRESET_TOP_RIGHT, 13)
	skip_intro_button.position = Vector2(-128, 61)

	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.visible = false
	root_ui.add_child(hud)
	var hud_panel := PanelContainer.new()
	hud_panel.position = Vector2(24, 62)
	hud_panel.size = Vector2(338, 158)
	hud_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.016, 0.025, 0.76), Color(0.27, 0.17, 0.15), 10))
	hud.add_child(hud_panel)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 5)
	hud_panel.add_child(stats)
	score_label = _label("DISTANCE   00000 m      KILLS  00", 17, Color(0.92, 0.86, 0.78))
	stats.add_child(score_label)
	health_label = _label("VITALITY   ♥  ♥  ♥", 17, Color(0.88, 0.22, 0.18))
	stats.add_child(health_label)
	relic_label = _label("RELICS   000    /    RESERVE  000", 14, Color(0.9, 0.62, 0.25))
	stats.add_child(relic_label)
	coin_label = _label("COINS   00000", 14, Color(0.96, 0.75, 0.32))
	stats.add_child(coin_label)
	best_label = _label("BEST RUN   00000 m", 13, Color(0.65, 0.63, 0.68))
	stats.add_child(best_label)

	controls = Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.visible = false
	root_ui.add_child(controls)
	_button(controls, "‹", Vector2(25, -102), Vector2(74, 72), func(): player.move_lane(-1), Control.PRESET_BOTTOM_LEFT, 28)
	_button(controls, "›", Vector2(108, -102), Vector2(74, 72), func(): player.move_lane(1), Control.PRESET_BOTTOM_LEFT, 28)
	_button(controls, "SLIDE", Vector2(-285, -101), Vector2(86, 72), func(): player.slide(), Control.PRESET_BOTTOM_RIGHT, 14)
	_button(controls, "JUMP", Vector2(-190, -101), Vector2(86, 72), func(): player.jump(), Control.PRESET_BOTTOM_RIGHT, 16)
	_button(controls, "STRIKE", Vector2(-95, -101), Vector2(86, 72), func(): player.attack(), Control.PRESET_BOTTOM_RIGHT, 14)
	pause_button = _button(controls, "Ⅱ", Vector2(-88, 61), Vector2(64, 54), _toggle_pause, Control.PRESET_TOP_RIGHT, 20)

	tutorial_label = _label("SWIPE TO MOVE     ↑ JUMP     ↓ SLIDE     TAP STRIKE", 15, Color(0.95, 0.84, 0.69))
	tutorial_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tutorial_label.position = Vector2(-420, 62)
	tutorial_label.size = Vector2(840, 34)
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.hide()
	controls.add_child(tutorial_label)

	# CenterContainer provides consistent placement across phone aspect ratios.
	var menu_row := HBoxContainer.new()
	menu_row.name = "TitleMenuLayout"
	menu_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_row.offset_left = 28
	menu_row.offset_right = -28
	menu_row.offset_top = 42
	menu_row.offset_bottom = -42
	root_ui.add_child(menu_row)

	var menu_slot := CenterContainer.new()
	menu_slot.name = "TitleMenuSlot"
	menu_slot.custom_minimum_size = Vector2(425, 0)
	menu_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_row.add_child(menu_slot)

	menu_panel = PanelContainer.new()
	menu_panel.name = "TitleMenuPanel"
	menu_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_panel.custom_minimum_size = Vector2(410, 398)
	menu_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.014, 0.012, 0.02, 0.95), Color(0.47, 0.23, 0.18), 14))
	menu_slot.add_child(menu_panel)

	var menu_spacer := Control.new()
	menu_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_row.add_child(menu_spacer)

	var menu_box := VBoxContainer.new()
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 13)
	menu_panel.add_child(menu_box)

	var eyebrow := _label("THE ASHEN KINGDOM  /  CHAPTER I", 12, Color(0.8, 0.42, 0.31))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(eyebrow)

	var title := _label("BLACKTHORN\nOATH", 43, Color(0.96, 0.90, 0.81))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("line_spacing", -8)
	menu_box.add_child(title)

	var description := _label("The bells have fallen silent.\nSomething beneath the cathedral has begun to wake.", 14, Color(0.82, 0.76, 0.72))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(description)

	var start := _button(menu_box, "ENTER THE RUINS", Vector2.ZERO, Vector2(0, 56), _start_run, Control.PRESET_TOP_LEFT, 18)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shop_entry := _button(menu_box, "THE ARMOURY  /  SHOP", Vector2.ZERO, Vector2(0, 44), _open_shop, Control.PRESET_TOP_LEFT, 15)
	shop_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var contracts_entry := _button(menu_box, "DAILY CONTRACTS", Vector2.ZERO, Vector2(0, 42), _open_contracts, Control.PRESET_TOP_LEFT, 14)
	contracts_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var controls_hint := _label("SWIPE  MOVE / JUMP / SLIDE     •     TAP  STRIKE", 12, Color(0.73, 0.68, 0.68))
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(controls_hint)

	var footer := _label("BEST  %05d m    RELICS  %03d    COINS  %05d" % [best_distance, relic_bank, coin_wallet], 11, Color(0.67, 0.61, 0.61))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(footer)
	menu_panel.hide()


	modal_panel = _make_overlay_panel(root_ui, Vector2(460, 276))
	modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	modal_panel.position = Vector2(-230, -138)
	modal_panel.hide()
	var modal_box := VBoxContainer.new()
	modal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_box.add_theme_constant_override("separation", 18)
	modal_panel.add_child(modal_box)
	modal_title = _label("PAUSED", 34, Color(0.95, 0.87, 0.77))
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(modal_title)
	modal_body = _label("The wind carries the bells through the ruins.", 15, Color(0.73, 0.68, 0.68))
	modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_box.add_child(modal_body)
	modal_action = _button(modal_box, "RESUME", Vector2.ZERO, Vector2(0, 58), _on_modal_action_pressed, Control.PRESET_TOP_LEFT, 18)
	modal_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pause_shop := _button(modal_box, "OPEN ARMOURY", Vector2.ZERO, Vector2(0, 46), _open_shop, Control.PRESET_TOP_LEFT, 15)
	pause_shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	shop_panel = _make_overlay_panel(root_ui, Vector2(500, 430))
	shop_panel.name = "ArmouryShop"
	shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	shop_panel.position = Vector2(-250, -215)
	shop_panel.hide()
	var shop_box := VBoxContainer.new()
	shop_box.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_box.add_theme_constant_override("separation", 12)
	shop_panel.add_child(shop_box)
	var shop_title := _label("THE ASHEN ARMOURY", 30, Color(0.96, 0.88, 0.76))
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_box.add_child(shop_title)
	shop_status_label = _label("", 15, Color(0.94, 0.73, 0.35))
	shop_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_box.add_child(shop_status_label)
	var blade_buy := _button(shop_box, "TEMPERED EDGE  ·  80 COINS", Vector2.ZERO, Vector2(0, 52), func(): _buy_upgrade("blade"), Control.PRESET_TOP_LEFT, 15)
	blade_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vitality_buy := _button(shop_box, "VITALITY RUNE  ·  100 COINS", Vector2.ZERO, Vector2(0, 52), func(): _buy_upgrade("vitality"), Control.PRESET_TOP_LEFT, 15)
	vitality_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fortune_buy := _button(shop_box, "GILDED OATH  ·  120 COINS", Vector2.ZERO, Vector2(0, 52), func(): _buy_upgrade("fortune"), Control.PRESET_TOP_LEFT, 15)
	fortune_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shop_close := _button(shop_box, "CLOSE", Vector2.ZERO, Vector2(0, 44), _close_shop, Control.PRESET_TOP_LEFT, 14)
	shop_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	contracts_panel = _make_overlay_panel(root_ui, Vector2(520, 390))
	contracts_panel.name = "DailyContracts"
	contracts_panel.set_anchors_preset(Control.PRESET_CENTER)
	contracts_panel.position = Vector2(-260, -195)
	contracts_panel.hide()
	var contracts_box := VBoxContainer.new()
	contracts_box.alignment = BoxContainer.ALIGNMENT_CENTER
	contracts_box.add_theme_constant_override("separation", 12)
	contracts_panel.add_child(contracts_box)
	var contracts_title := _label("THE GUILD'S DAILY CONTRACTS", 27, Color(0.96, 0.88, 0.76))
	contracts_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contracts_box.add_child(contracts_title)
	contracts_status_label = _label("", 14, Color(0.94, 0.73, 0.35))
	contracts_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contracts_box.add_child(contracts_status_label)
	var contract_kills := _button(contracts_box, "HUNT 10 FOES  ·  REWARD 60 COINS", Vector2.ZERO, Vector2(0, 52), func(): _claim_contract(0), Control.PRESET_TOP_LEFT, 14)
	contract_kills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var contract_relics := _button(contracts_box, "RECOVER 6 RELICS  ·  REWARD 45 COINS", Vector2.ZERO, Vector2(0, 52), func(): _claim_contract(1), Control.PRESET_TOP_LEFT, 14)
	contract_relics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var contract_distance := _button(contracts_box, "TRAVEL 350 M  ·  REWARD 80 COINS", Vector2.ZERO, Vector2(0, 52), func(): _claim_contract(2), Control.PRESET_TOP_LEFT, 14)
	contract_distance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var contracts_close := _button(contracts_box, "CLOSE", Vector2.ZERO, Vector2(0, 44), _close_contracts, Control.PRESET_TOP_LEFT, 14)
	contracts_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0.008, 0.006, 0.012, 1.0)
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(fade_overlay)

func _update_cinematic(delta: float) -> void:
	intro_elapsed += delta
	var t: float = intro_elapsed
	if t < 4.2:
		var amount: float = _ease(t / 4.2)
		camera.global_position = Vector3(0.0, 34.0, -24.0).lerp(Vector3(0.0, 25.0, -59.0), amount)
		camera.look_at(Vector3(0, 18.0, -145.0), Vector3.UP)
		camera.fov = lerpf(50.0, 45.0, amount)
		_set_cinematic_copy("THE NORTH ONCE KNEW THE SOUND OF BELLS.", "", 0.0)
	elif t < 8.0:
		var amount: float = _ease((t - 4.2) / 3.8)
		camera.global_position = Vector3(0.0, 18.0, -66.0).lerp(Vector3(0.0, 10.5, -84.0), amount)
		camera.look_at(Vector3(0.0, 5.7, -99.0), Vector3.UP)
		camera.fov = lerpf(48.0, 39.0, amount)
		var gate_amount: float = _ease((t - 5.1) / 2.55)
		cathedral_gate_left.rotation.y = -1.38 * gate_amount
		cathedral_gate_right.rotation.y = 1.38 * gate_amount
		gate_guardian.visible = gate_amount > 0.2
		portal_light.light_energy = 0.55 + gate_amount * 3.2
		portal_light.light_color = Color(0.72, 0.035, 0.025).lerp(Color(1.0, 0.12, 0.035), gate_amount)
		var reveal_line: String = "THEN THE BELLS BEGAN TO ANSWER THEMSELVES." if t < 6.35 else "SOMETHING ANSWERED FROM WITHIN."
		_set_cinematic_copy(reveal_line, "", 0.0)
	elif t < 11.5:
		var amount: float = _ease((t - 8.0) / 3.5)
		camera.global_position = Vector3(0.0, 10.5, -84.0).lerp(Vector3(0.0, 8.0, -88.5), amount)
		camera.look_at(Vector3(0.0, 5.2, -99.0), Vector3.UP)
		camera.fov = lerpf(39.0, 43.0, amount)
		if t > 9.2:
			camera.global_position += Vector3(sin(t * 18.0) * 0.018, cos(t * 14.0) * 0.014, 0.0)
		_set_cinematic_copy("THE KINGDOM FELL. THE DEAD REMAINED.", "", 0.0)
	elif t < 15.0:
		var amount: float = _ease((t - 11.5) / 3.5)
		player.face_for_menu()
		camera.global_position = Vector3(0.4, 2.5, 6.6).lerp(Vector3(0.2, 2.75, 6.0), amount)
		camera.look_at(Vector3(0.0, 1.05, -3.0), Vector3.UP)
		camera.fov = lerpf(40.0, 44.0, amount)
		_set_cinematic_copy("ONE KNIGHT. ONE ROAD. NO WAY BACK.", "", 0.0)
	else:
		var amount: float = _ease((t - 15.0) / 3.0)
		camera.global_position = Vector3(0.4, 3.0, -8.0).lerp(Vector3(0.2, 3.2, -8.4), amount)
		camera.look_at(Vector3(0.0, 1.1, -3.0), Vector3.UP)
		camera.fov = lerpf(46.0, 44.0, amount)
		_set_cinematic_copy("THE OATH DOES NOT END WITH DEATH.", "BLACKTHORN\nOATH", 1.0)
		if t >= INTRO_LENGTH:
			_finish_intro()


func _set_cinematic_copy(subtitle: String, title: String, title_alpha: float) -> void:
	if subtitle_label.text != subtitle:
		subtitle_label.text = subtitle
	if title == "":
		intro_title_label.hide()
	else:
		intro_title_label.text = title
		intro_title_label.show()
		intro_title_label.modulate.a = title_alpha
		intro_kicker_label.hide()
	subtitle_label.modulate.a = 1.0

func _finish_intro() -> void:
	intro_active = false
	intro_complete = true
	player.lane = 2
	player.global_position.x = player.lane_width
	player.face_for_menu()
	subtitle_label.hide()
	intro_title_label.hide()
	intro_kicker_label.hide()
	skip_intro_button.hide()
	menu_panel.show()
	var fade := create_tween()
	fade.tween_property(menu_panel, "modulate:a", 1.0, 0.65).from(0.0)

func _skip_intro() -> void:
	if not intro_active:
		return
	intro_elapsed = INTRO_LENGTH
	cathedral_gate_left.rotation.y = -1.38
	cathedral_gate_right.rotation.y = 1.38
	gate_guardian.visible = true
	portal_light.light_energy = 3.75
	_finish_intro()

func _start_run() -> void:
	if not intro_complete or game_started:
		return
	game_started = true
	game_over = false
	paused = false
	player.lane = 1
	player.health = player.max_health
	player.dead = false
	player.global_position.x = 0.0
	player.face_for_run()
	menu_panel.hide()
	hud.show()
	controls.show()
	pause_button.text = "Ⅱ"
	player.forward_speed = 12.0
	daily_distance_last_sample = int(distance)
	run_started_at = Time.get_ticks_msec() / 1000.0
	tutorial_timer = 5.0
	tutorial_label.show()
	tutorial_label.modulate.a = 1.0
	camera.fov = 55.0

func _toggle_pause() -> void:
	if not game_started or game_over:
		return
	if paused:
		_resume_run()
		return
	paused = true
	get_tree().paused = true
	modal_title.text = "PAUSED"
	modal_body.text = "The dead do not tire. Take a breath."
	modal_action.text = "RESUME"
	modal_panel.show()
	pause_button.text = "▶"

func _resume_run() -> void:
	paused = false
	get_tree().paused = false
	modal_panel.hide()
	pause_button.text = "Ⅱ"

func _on_modal_action_pressed() -> void:
	if game_over:
		get_tree().reload_current_scene()
	else:
		_resume_run()

func _make_overlay_panel(parent: Control, dimensions: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-dimensions.x * 0.5, -dimensions.y * 0.5)
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.014, 0.012, 0.02, 0.88), Color(0.39, 0.19, 0.15), 14))
	parent.add_child(panel)
	return panel

func _panel_style(fill: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 27
	style.content_margin_right = 27
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	return style

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.86))
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
	button.add_theme_color_override("font_pressed_color", Color(0.95, 0.5, 0.32))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.045, 0.032, 0.04, 0.92)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.13, 0.055, 0.05, 0.98)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.29, 0.07, 0.055, 0.98)))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(0.47, 0.24, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _spawn_segment(segment_z: float) -> void:
	var segment := Node3D.new()
	segment.name = "RoadSegment_%02d" % segment_serial
	segment.position.z = segment_z
	add_child(segment)
	segments.append(segment)

	# The road is built in three broad stone lanes with chipped edge courses.
	_box(segment, Vector3(0, -0.32, -SEGMENT_LENGTH * 0.5), Vector3(10.2, 0.64, SEGMENT_LENGTH), dark_stone_material, true)
	_box(segment, Vector3(-5.12, 0.08, -SEGMENT_LENGTH * 0.5), Vector3(0.36, 0.62, SEGMENT_LENGTH), worn_stone_material, true)
	_box(segment, Vector3(5.12, 0.08, -SEGMENT_LENGTH * 0.5), Vector3(0.36, 0.62, SEGMENT_LENGTH), worn_stone_material, true)
	for lane_edge in [-1.3, 1.3]:
		_box(segment, Vector3(lane_edge, 0.012, -SEGMENT_LENGTH * 0.5), Vector3(0.055, 0.025, SEGMENT_LENGTH - 0.5), gold_material)
	for slab_index in range(11):
		var slab_z: float = -1.5 - float(slab_index) * 2.75
		for lane_index in range(3):
			var lane_x: float = float(lane_index - 1) * LANE_WIDTH
			var variation: float = 0.06 if (slab_index + lane_index) % 2 == 0 else -0.06
			var slab := _box(segment, Vector3(lane_x + variation, 0.035, slab_z), Vector3(2.46, 0.08, 2.58), stone_material)
			slab.rotation.y = variation * 0.3

	_add_segment_architecture(segment, segment_serial)
	_add_segment_props(segment, segment_serial)

	# Give the player a short safe runway before introducing the first enemy pattern.
	if segment_serial < 2:
		for relic_index in range(5):
			var relic := RelicScript.new()
			var lane: int = relic_index % 3
			relic.position = Vector3(float(lane - 1) * LANE_WIDTH, 1.35, -8.0 - float(relic_index) * 4.6)
			segment.add_child(relic)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = 19417 + segment_serial * 811
		for row in range(3):
			var lane: int = rng.randi_range(0, 2)
			var obstacle_z: float = -10.0 - float(row) * 9.0
			if rng.randf() < 0.62:
				var enemy := EnemyScript.new()
				enemy.configure(rng.randi_range(0, 2))
				enemy.position = Vector3(float(lane - 1) * LANE_WIDTH, 0, obstacle_z)
				segment.add_child(enemy)
			else:
				_add_hazard(segment, lane, obstacle_z, rng.randf() < 0.42)
			var relic_lane: int = (lane + 1 + row % 2) % 3
			var relic := RelicScript.new()
			relic.position = Vector3(float(relic_lane - 1) * LANE_WIDTH, 1.3, obstacle_z - 3.2)
			segment.add_child(relic)
	next_segment_z = segment_z - SEGMENT_LENGTH
	segment_serial += 1

func _add_segment_architecture(parent: Node3D, serial: int) -> void:
	# Open-air ruined cloister: spaced arcades replace the solid tunnel walls.
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		for pillar_index in range(4):
			var pillar_z: float = -3.0 - float(pillar_index) * 8.5
			var x: float = side * 6.15
			var pillar_height: float = 7.0 if serial % 3 != 1 else 5.8
			_box(parent, Vector3(x, pillar_height * 0.5, pillar_z), Vector3(0.92, pillar_height, 1.3), dark_stone_material)
			_box(parent, Vector3(x, 0.28, pillar_z), Vector3(1.45, 0.56, 1.75), worn_stone_material)
			_box(parent, Vector3(x, pillar_height, pillar_z), Vector3(1.5, 0.48, 1.8), stone_material)
			_box(parent, Vector3(side * 5.65, pillar_height * 0.58, pillar_z), Vector3(0.18, pillar_height * 0.82, 0.2), gold_material)
			if serial % 3 == 0 and pillar_index % 2 == 0:
				_add_brazier(parent, side * 5.35, 1.45, pillar_z - 1.8)
		if serial % 3 == 1:
			_add_hanging_banner(parent, side * 5.78, 6.2, -14.0)
		elif serial % 3 == 2:
			_add_wall_statue(parent, side * 5.72, 2.8, -19.0)
		else:
			_add_broken_column(parent, side * 7.4, 7.0, -23.0)

	# Keep the corridor open to the skyline; only rare broken lintels cross a side bay.
	if serial % 5 == 0:
		_box(parent, Vector3(0, 7.8, -24.5), Vector3(6.4, 0.38, 0.65), worn_stone_material)

	# Broken parapets and stone fragments keep the road edges visually grounded.
	for debris_index in range(7):
		var side: float = -1.0 if debris_index % 2 == 0 else 1.0
		var z: float = -2.0 - float(debris_index) * 4.1
		var rock_size := Vector3(0.65 + float(debris_index % 3) * 0.26, 0.3 + float(debris_index % 2) * 0.25, 0.8)
		var rock := _box(parent, Vector3(side * (4.9 + float(debris_index % 2) * 0.2), 0.16, z), rock_size, worn_stone_material)
		rock.rotation.y = float(debris_index) * 0.43
		rock.rotation.z = -0.12 if debris_index % 2 == 0 else 0.16


func _add_segment_props(parent: Node3D, serial: int) -> void:
	# Suspended iron chains and broken cross-beams appear in alternating bays.
	if serial % 2 == 0:
		for link_index in range(7):
			var z: float = -7.0 - float(link_index) * 0.55
			var chain := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.035
			mesh.bottom_radius = 0.035
			mesh.height = 0.65
			mesh.radial_segments = 6
			chain.mesh = mesh
			chain.position = Vector3(4.0, 5.8 - float(link_index) * 0.42, z)
			chain.rotation.z = 0.12
			chain.material_override = metal_material
			parent.add_child(chain)
		_box(parent, Vector3(0, 5.2, -10.8), Vector3(8.4, 0.2, 0.25), metal_material)

	if serial % 3 == 0:
		_add_hanging_banner(parent, -5.72, 6.1, -26.0)
	if serial % 4 == 2:
		_add_broken_altar(parent, 3.9, -24.5)

func _add_hanging_banner(parent: Node3D, x: float, y: float, z: float) -> void:
	_box(parent, Vector3(x, y + 1.05, z), Vector3(0.08, 2.2, 0.08), gold_material)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.035
	pole_mesh.bottom_radius = 0.035
	pole_mesh.height = 1.8
	pole.mesh = pole_mesh
	pole.position = Vector3(x, y + 1.9, z)
	pole.rotation.z = PI * 0.5
	pole.material_override = gold_material
	parent.add_child(pole)
	var banner := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.35, 2.15)
	plane.subdivide_width = 7
	plane.subdivide_depth = 9
	banner.mesh = plane
	banner.position = Vector3(x, y, z + 0.15)
	banner.rotation_degrees.x = 90.0
	var cloth := ShaderMaterial.new()
	cloth.shader = banner_shader
	cloth.set_shader_parameter("cloth_color", Color(0.19, 0.012, 0.035, 1.0))
	cloth.set_shader_parameter("edge_color", Color(0.65, 0.33, 0.11, 1.0))
	banner.material_override = cloth
	parent.add_child(banner)
	_box(parent, Vector3(x, y - 0.72, z + 0.18), Vector3(0.24, 0.28, 0.09), gold_material)

func _add_brazier(parent: Node3D, x: float, y: float, z: float) -> void:
	_box(parent, Vector3(x, y * 0.5, z), Vector3(0.42, y, 0.42), dark_stone_material)
	_box(parent, Vector3(x, y, z), Vector3(0.84, 0.18, 0.84), gold_material)
	var bowl := MeshInstance3D.new()
	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius = 0.46
	bowl_mesh.bottom_radius = 0.28
	bowl_mesh.height = 0.32
	bowl_mesh.radial_segments = 8
	bowl.mesh = bowl_mesh
	bowl.position = Vector3(x, y + 0.25, z)
	bowl.material_override = metal_material
	parent.add_child(bowl)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.22
	flame_mesh.height = 0.52
	flame.mesh = flame_mesh
	flame.position = Vector3(x, y + 0.65, z)
	flame.scale = Vector3(0.75, 1.5, 0.75)
	flame.material_override = ember_material
	parent.add_child(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(x, y + 0.82, z)
	light.light_color = Color(1.0, 0.21, 0.075)
	light.light_energy = 1.7
	light.omni_range = 8.0
	parent.add_child(light)

func _add_wall_statue(parent: Node3D, x: float, y: float, z: float) -> void:
	_box(parent, Vector3(x, y * 0.5, z), Vector3(0.45, y, 0.48), worn_stone_material)
	_capsule(parent, Vector3(x, y + 0.55, z), 0.22, 1.2, dark_stone_material)
	_sphere(parent, Vector3(x, y + 1.32, z - 0.05), Vector3(0.48, 0.56, 0.42), stone_material)
	_box(parent, Vector3(x, y + 1.27, z - 0.28), Vector3(0.28, 0.055, 0.04), ember_material)
	_box(parent, Vector3(x - 0.32, y + 0.5, z), Vector3(0.58, 0.17, 0.2), dark_stone_material)
	_box(parent, Vector3(x + 0.32, y + 0.5, z), Vector3(0.58, 0.17, 0.2), dark_stone_material)

func _add_broken_column(parent: Node3D, x: float, wall_height: float, z: float) -> void:
	var column := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.56
	mesh.height = wall_height * 0.52
	mesh.radial_segments = 8
	column.mesh = mesh
	column.position = Vector3(x, wall_height * 0.25, z)
	column.rotation.z = -0.08
	column.material_override = worn_stone_material
	parent.add_child(column)
	_box(parent, Vector3(x + 0.2, wall_height * 0.53, z), Vector3(1.3, 0.32, 1.2), stone_material).rotation.z = -0.15

func _add_broken_altar(parent: Node3D, x: float, z: float) -> void:
	_box(parent, Vector3(x, 0.42, z), Vector3(1.4, 0.84, 1.2), dark_stone_material)
	_box(parent, Vector3(x, 0.9, z), Vector3(1.8, 0.18, 1.5), worn_stone_material)
	_box(parent, Vector3(x, 1.65, z), Vector3(0.18, 1.4, 0.18), gold_material)
	_box(parent, Vector3(x, 2.0, z), Vector3(0.95, 0.14, 0.12), gold_material)
	var ember := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.26
	ember.mesh = mesh
	ember.position = Vector3(x, 2.35, z)
	ember.material_override = ember_material
	parent.add_child(ember)

func _add_hazard(parent: Node3D, lane: int, z: float, overhead: bool) -> void:
	var hazard := HazardScript.new()
	var size := Vector3(1.65, 0.45, 1.5) if overhead else Vector3(1.55, 1.05, 1.5)
	hazard.position = Vector3(float(lane - 1) * LANE_WIDTH, 1.38 if overhead else 0.52, z)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	hazard.add_child(collision)
	_box(hazard, Vector3.ZERO, size, _standard_material(Color(0.15, 0.045, 0.04), 0.68, 0.44, Color(0.13, 0.012, 0.004), 0.8))
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
			spike.material_override = metal_material
			hazard.add_child(spike)
	parent.add_child(hazard)

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
	var target_position: Vector3 = player.global_position + Vector3(0, 3.15, 6.4)
	camera.global_position = camera.global_position.lerp(target_position, minf(delta * 6.0, 1.0))
	camera.look_at(player.global_position + Vector3(0, 1.0, -6.8), Vector3.UP)
	camera.fov = lerpf(camera.fov, 55.0, delta * 1.2)

func _idle_camera(delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player):
		return
	if intro_complete and not game_started and not game_over:
		# Front hero portrait from the starting side, with the cathedral approach behind him.
		var menu_camera_position: Vector3 = player.global_position + Vector3(-0.55, 2.9, 7.4)
		camera.global_position = camera.global_position.lerp(menu_camera_position, minf(delta * 3.0, 1.0))
		camera.look_at(player.global_position + Vector3(-0.25, 1.05, -5.0), Vector3.UP)
		camera.fov = lerpf(camera.fov, 45.0, delta * 2.0)
		return
	var time: float = Time.get_ticks_msec() / 1000.0
	var sway := Vector3(sin(time * 0.19) * 0.28, 0.04 * sin(time * 0.3), 0.0)
	var target_position: Vector3 = player.global_position + Vector3(0, 3.35, 6.8) + sway
	camera.global_position = camera.global_position.lerp(target_position, minf(delta * 1.7, 1.0))
	camera.look_at(player.global_position + Vector3(0, 1.0, -8.0), Vector3.UP)


func _update_hud() -> void:
	if not is_instance_valid(score_label) or not is_instance_valid(player):
		return
	score_label.text = "DISTANCE   %05d m      KILLS  %02d" % [int(distance), kills]
	health_label.text = "VITALITY   " + "♥  ".repeat(player.health) + "♡  ".repeat(maxi(0, player.max_health - player.health))
	relic_label.text = "RELICS   %03d    /    RESERVE  %03d" % [relics, relic_bank]
	coin_label.text = "COINS   %05d" % coin_wallet
	best_label.text = "BEST RUN   %05d m" % best_distance

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
	lifetime_runs += 1
	lifetime_distance += int(distance)
	_save_progress()
	modal_title.text = "OATH BROKEN"
	modal_body.text = "DISTANCE  %d m     KILLS  %d\nRELICS FOUND  %d\nBEST RUN  %d m" % [int(distance), kills, relics, best_distance]
	modal_action.text = "RUN AGAIN"
	modal_panel.show()
	_update_hud()

func add_kill() -> void:
	kills += 1
	lifetime_kills += 1
	daily_kills += 1
	coin_wallet += 5 + fortune_level
	_save_progress()
	_update_hud()
	_update_contracts_ui()

func add_relic() -> void:
	relics += 1
	relic_bank += 1
	lifetime_relics += 1
	daily_relics += 1
	coin_wallet += 10
	_save_progress()
	_update_hud()
	_update_contracts_ui()

func _load_progress() -> void:
	if save_data.load("user://blackthorn_oath.cfg") == OK:
		best_distance = int(save_data.get_value("progress", "best_distance", 0))
		relic_bank = int(save_data.get_value("progress", "relic_bank", 0))
		coin_wallet = int(save_data.get_value("progress", "coin_wallet", 0))
		blade_level = int(save_data.get_value("upgrades", "blade", 0))
		vitality_level = int(save_data.get_value("upgrades", "vitality", 0))
		fortune_level = int(save_data.get_value("upgrades", "fortune", 0))
		lifetime_kills = int(save_data.get_value("lifetime", "kills", 0))
		lifetime_relics = int(save_data.get_value("lifetime", "relics", 0))
		lifetime_runs = int(save_data.get_value("lifetime", "runs", 0))
		lifetime_distance = int(save_data.get_value("lifetime", "distance", 0))
		daily_key = str(save_data.get_value("daily", "date", ""))
		daily_kills = int(save_data.get_value("daily", "kills", 0))
		daily_relics = int(save_data.get_value("daily", "relics", 0))
		daily_distance = int(save_data.get_value("daily", "distance", 0))
		var loaded_claims: Array = save_data.get_value("daily", "claimed", [false, false, false])
		if loaded_claims.size() >= 3:
			daily_claimed = [bool(loaded_claims[0]), bool(loaded_claims[1]), bool(loaded_claims[2])]
	_ensure_daily_contracts()

func _save_progress() -> void:
	save_data.set_value("progress", "best_distance", best_distance)
	save_data.set_value("progress", "relic_bank", relic_bank)
	save_data.set_value("progress", "coin_wallet", coin_wallet)
	save_data.set_value("upgrades", "blade", blade_level)
	save_data.set_value("upgrades", "vitality", vitality_level)
	save_data.set_value("upgrades", "fortune", fortune_level)
	save_data.set_value("lifetime", "kills", lifetime_kills)
	save_data.set_value("lifetime", "relics", lifetime_relics)
	save_data.set_value("lifetime", "runs", lifetime_runs)
	save_data.set_value("lifetime", "distance", lifetime_distance)
	save_data.set_value("daily", "date", daily_key)
	save_data.set_value("daily", "kills", daily_kills)
	save_data.set_value("daily", "relics", daily_relics)
	save_data.set_value("daily", "distance", daily_distance)
	save_data.set_value("daily", "claimed", daily_claimed)
	save_data.save("user://blackthorn_oath.cfg")

func _ensure_daily_contracts() -> void:
	var today := Time.get_date_string_from_system()
	if daily_key != today:
		daily_key = today
		daily_kills = 0
		daily_relics = 0
		daily_distance = 0
		daily_claimed = [false, false, false]
		_save_progress()

func _open_contracts() -> void:
	_ensure_daily_contracts()
	_update_contracts_ui()
	contracts_panel.show()
	if is_instance_valid(menu_panel):
		menu_panel.hide()

func _close_contracts() -> void:
	contracts_panel.hide()
	if not game_started:
		menu_panel.show()

func _update_contracts_ui() -> void:
	if not is_instance_valid(contracts_status_label):
		return
	var kill_state := "CLAIMED" if daily_claimed[0] else ("READY TO CLAIM" if daily_kills >= 10 else "%d / 10" % mini(daily_kills, 10))
	var relic_state := "CLAIMED" if daily_claimed[1] else ("READY TO CLAIM" if daily_relics >= 6 else "%d / 6" % mini(daily_relics, 6))
	var distance_state := "CLAIMED" if daily_claimed[2] else ("READY TO CLAIM" if daily_distance >= 350 else "%d / 350 M" % mini(daily_distance, 350))
	contracts_status_label.text = "KILLS  %s     RELICS  %s\nDISTANCE  %s     ·     RESETS DAILY" % [kill_state, relic_state, distance_state]
	if is_instance_valid(coin_label):
		coin_label.text = "COINS   %05d" % coin_wallet

func _claim_contract(index: int) -> void:
	_ensure_daily_contracts()
	var goals := [10, 6, 350]
	var rewards := [60, 45, 80]
	var progress := [daily_kills, daily_relics, daily_distance]
	if index < 0 or index >= goals.size() or daily_claimed[index]:
		return
	if progress[index] < goals[index]:
		contracts_status_label.text = "CONTRACT NOT COMPLETE YET."
		return
	daily_claimed[index] = true
	coin_wallet += rewards[index]
	_save_progress()
	_update_contracts_ui()
	contracts_status_label.text += "\nREWARD COLLECTED  ·  +%d COINS" % rewards[index]

func _apply_asset_tint(root: Node3D, tint: Color) -> void:
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := item as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.get_active_material(surface_index)
			if source_material is BaseMaterial3D:
				var adjusted := (source_material as BaseMaterial3D).duplicate() as BaseMaterial3D
				adjusted.albedo_color = adjusted.albedo_color * tint
				adjusted.roughness = maxf(adjusted.roughness, 0.58)
				mesh_instance.set_surface_override_material(surface_index, adjusted)

func _fit_asset_height(root: Node3D, target_height: float) -> void:
	var combined := AABB()
	var has_bounds := false
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := item as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform: Transform3D = root.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds: AABB = mesh_instance.get_aabb() * relative_transform
		if has_bounds:
			combined = combined.merge(mesh_bounds)
		else:
			combined = mesh_bounds
			has_bounds = true
	if not has_bounds or combined.size.y <= 0.001:
		return
	var fit_scale: float = target_height / combined.size.y
	root.scale = Vector3.ONE * fit_scale
	root.position.y = -combined.position.y * fit_scale

func _standard_material(color: Color, metallic: float = 0.0, roughness: float = 0.8, emission: Color = Color.BLACK, energy: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
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

func _sphere(parent: Node3D, pos: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	node.mesh = mesh
	node.scale = scale_value
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node

func _capsule(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node

func _ease(value: float) -> float:
	var x: float = clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


# KayKit Dungeon Remastered CC0 environment dressing.
# Kept as static imported GLBs so the existing lane/gameplay geometry is untouched.
func _build_kaykit_dungeon_dressing() -> void:
	var placements: Array[Dictionary] = [
		{"asset": "torch_mounted.gltf.glb", "position": Vector3(-4.35, 2.0, -5.5), "rotation": 0.0, "scale": 1.0},
		{"asset": "torch_mounted.gltf.glb", "position": Vector3(4.35, 2.0, -5.5), "rotation": PI, "scale": 1.0},
		{"asset": "pillar_decorated.gltf.glb", "position": Vector3(-5.0, 0.0, -13.0), "rotation": 0.0, "scale": 1.25},
		{"asset": "pillar_decorated.gltf.glb", "position": Vector3(5.0, 0.0, -13.0), "rotation": 0.0, "scale": 1.25},
		{"asset": "barrel_large_decorated.gltf.glb", "position": Vector3(-4.6, 0.0, -19.0), "rotation": 0.35, "scale": 1.0},
		{"asset": "chest_gold.glb", "position": Vector3(4.65, 0.0, -26.0), "rotation": -0.25, "scale": 0.85},
		{"asset": "torch_lit.gltf.glb", "position": Vector3(-4.4, 0.0, -31.0), "rotation": 0.0, "scale": 1.0},
		{"asset": "torch_lit.gltf.glb", "position": Vector3(4.4, 0.0, -31.0), "rotation": 0.0, "scale": 1.0}
	]
	var root := Node3D.new()
	root.name = "KayKitDungeonProps"
	add_child(root)
	for entry in placements:
		var path := "res://assets/kaykit_dungeon/" + String(entry["asset"])
		if not ResourceLoader.exists(path):
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var prop := packed.instantiate() as Node3D
		if prop == null:
			continue
		prop.position = entry["position"]
		prop.rotation.y = float(entry["rotation"])
		prop.scale = Vector3.ONE * float(entry["scale"])
		root.add_child(prop)


func _apply_player_upgrades() -> void:
	if not is_instance_valid(player):
		return
	player.attack_power = 1 + blade_level
	player.max_health = 3 + vitality_level
	player.health = player.max_health

func _open_shop() -> void:
	if game_started and not game_over:
		paused = true
		get_tree().paused = true
	shop_status_label.text = "PURSE  %d COINS     ·     EDGE %d     ·     VITALITY %d" % [coin_wallet, blade_level, vitality_level]
	shop_panel.show()
	if is_instance_valid(modal_panel):
		modal_panel.hide()

func _close_shop() -> void:
	shop_panel.hide()
	if game_started and not game_over:
		_resume_run()

func _buy_upgrade(kind: String) -> void:
	var cost := 0
	match kind:
		"blade":
			cost = 80 + blade_level * 65
		"vitality":
			cost = 100 + vitality_level * 80
		"fortune":
			cost = 120 + fortune_level * 90
	if coin_wallet < cost:
		shop_status_label.text = "NOT ENOUGH COINS  ·  NEED %d" % cost
		return
	coin_wallet -= cost
	match kind:
		"blade":
			blade_level += 1
		"vitality":
			vitality_level += 1
		"fortune":
			fortune_level += 1
	_apply_player_upgrades()
	_save_progress()
	shop_status_label.text = "PURCHASED  ·  %d COINS REMAIN" % coin_wallet
	_update_hud()
