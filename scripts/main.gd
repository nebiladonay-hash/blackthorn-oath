extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const HazardScript = preload("res://scripts/hazard.gd")
const RelicScript = preload("res://scripts/relic.gd")
const SCORE_PATH := "res://audio/blackthorn_cinematic_ambience.wav"

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
	_build_distant_silhouette()
	_build_player_and_camera()
	_build_interface()
	_build_ashfall()
	_start_soundtrack()
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
	stone_material.set_shader_parameter("base_tint", Color(0.25, 0.23, 0.24, 1.0))
	stone_material.set_shader_parameter("roughness_value", 0.92)
	dark_stone_material = ShaderMaterial.new()
	dark_stone_material.shader = stone_shader
	dark_stone_material.set_shader_parameter("base_tint", Color(0.095, 0.085, 0.10, 1.0))
	dark_stone_material.set_shader_parameter("roughness_value", 0.96)
	worn_stone_material = ShaderMaterial.new()
	worn_stone_material.shader = stone_shader
	worn_stone_material.set_shader_parameter("base_tint", Color(0.34, 0.28, 0.24, 1.0))
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
	environment.ambient_light_color = Color(0.37, 0.33, 0.45)
	environment.ambient_light_energy = 0.78
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.65
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 0.92
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.105, 0.048, 0.06)
	environment.fog_density = 0.0048
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 0.82
	world.environment = environment
	add_child(world)

	var moonlight := DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-35, -28, 0)
	moonlight.light_color = Color(0.59, 0.63, 0.83)
	moonlight.light_energy = 1.18
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

	camera = Camera3D.new()
	camera.name = "CinematicCamera"
	camera.current = true
	camera.fov = 48.0
	camera.near = 0.08
	camera.far = 320.0
	camera.position = Vector3(22.0, 15.5, 20.0)
	add_child(camera)
	camera.look_at(Vector3(0, 15.0, -108.0), Vector3.UP)

func _build_cathedral_landmark() -> void:
	var facade_z: float = -112.0
	var facade := Node3D.new()
	facade.name = "TheLastCathedral"
	facade.position.z = facade_z
	add_child(facade)

	# Main nave: layered stone masses, buttresses, cornices and upper rose window.
	_box(facade, Vector3(0, 12.0, 0), Vector3(19.0, 23.0, 4.5), dark_stone_material)
	_box(facade, Vector3(0, 23.55, 0.05), Vector3(20.2, 0.5, 5.2), stone_material)
	_box(facade, Vector3(0, 2.2, -0.2), Vector3(20.5, 4.2, 5.5), stone_material)
	_box(facade, Vector3(0, 1.05, 0.0), Vector3(23.0, 1.3, 7.0), worn_stone_material)

	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		_add_cathedral_tower(facade, side * 12.0, 0.0, 31.0, 7.0)
		_box(facade, Vector3(side * 8.2, 10.5, 0.0), Vector3(2.2, 19.0, 5.4), stone_material)
		_box(facade, Vector3(side * 9.7, 11.0, 0.0), Vector3(1.0, 21.0, 6.0), dark_stone_material)
		_box(facade, Vector3(side * 8.2, 20.4, 0.0), Vector3(2.7, 0.7, 6.1), worn_stone_material)
		_add_front_gothic_arch(facade, Vector3(side * 5.1, 4.2, -2.32), 4.7, 8.4, 0.7, worn_stone_material)
		_box(facade, Vector3(side * 5.1, 8.15, -2.25), Vector3(3.4, 4.3, 0.12), glass_material)
		_box(facade, Vector3(side * 5.1, 8.1, -2.36), Vector3(0.12, 5.3, 0.15), gold_material)
		_box(facade, Vector3(side * 5.1, 8.0, -2.36), Vector3(3.7, 0.12, 0.15), gold_material)
		_add_buttress(facade, side * 8.9, 0.0, 0.0, 16.0)
		_add_buttress(facade, side * 8.9, 0.0, -1.8, 16.0)

	# Grand central entrance: two independently hinged iron-bound gates.
	_add_front_gothic_arch(facade, Vector3(0, 1.6, -2.42), 7.2, 13.8, 0.8, worn_stone_material)
	var gate_wood := _standard_material(Color(0.038, 0.018, 0.024), 0.36, 0.58)
	cathedral_gate_left = Node3D.new()
	cathedral_gate_left.position = Vector3(-3.0, 0.0, -2.65)
	facade.add_child(cathedral_gate_left)
	cathedral_gate_right = Node3D.new()
	cathedral_gate_right.position = Vector3(3.0, 0.0, -2.65)
	facade.add_child(cathedral_gate_right)
	for gate_side in range(2):
		var gate: Node3D = cathedral_gate_left if gate_side == 0 else cathedral_gate_right
		var panel_center: float = 1.5 if gate_side == 0 else -1.5
		_box(gate, Vector3(panel_center, 6.65, 0.0), Vector3(3.0, 13.3, 0.3), gate_wood)
		for rail_index in range(8):
			var rail_y: float = 0.9 + float(rail_index) * 1.65
			_box(gate, Vector3(panel_center, rail_y, -0.19), Vector3(2.85, 0.11, 0.12), gold_material)
		for rib_index in range(4):
			var rib_x: float = panel_center - 1.05 + float(rib_index) * 0.7
			_box(gate, Vector3(rib_x, 6.7, -0.2), Vector3(0.12, 12.8, 0.12), metal_material)
		_box(gate, Vector3(panel_center, 6.7, -0.28), Vector3(0.5, 1.8, 0.12), gold_material)
	_add_front_gothic_arch(facade, Vector3(0, 10.9, -2.7), 5.4, 6.6, 0.25, gold_material)
	_add_gate_guardian(facade)

	# Rose window and stained-glass halo.
	var rose := MeshInstance3D.new()
	var rose_mesh := TorusMesh.new()
	rose_mesh.inner_radius = 1.55
	rose_mesh.outer_radius = 1.82
	rose_mesh.rings = 16
	rose_mesh.ring_segments = 48
	rose.mesh = rose_mesh
	rose.position = Vector3(0, 19.0, -2.5)
	rose.material_override = gold_material
	facade.add_child(rose)
	var inner_rose := MeshInstance3D.new()
	var inner_mesh := TorusMesh.new()
	inner_mesh.inner_radius = 0.82
	inner_mesh.outer_radius = 1.0
	inner_mesh.rings = 12
	inner_mesh.ring_segments = 36
	inner_rose.mesh = inner_mesh
	inner_rose.position = Vector3(0, 19.0, -2.52)
	inner_rose.material_override = ember_material
	facade.add_child(inner_rose)
	_box(facade, Vector3(0, 19.0, -2.53), Vector3(0.12, 3.35, 0.12), gold_material)
	_box(facade, Vector3(0, 19.0, -2.53), Vector3(3.35, 0.12, 0.12), gold_material)
	_box(facade, Vector3(0, 19.0, -2.54), Vector3(2.55, 0.08, 0.1), glass_material)
	_box(facade, Vector3(0, 19.0, -2.54), Vector3(0.08, 2.55, 0.1), glass_material)

	# Roofline and spines rise behind the facade.
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(20.0, 6.0, 6.0)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, 26.2, 1.0)
	roof.material_override = dark_stone_material
	facade.add_child(roof)
	for spike_index in range(9):
		var x: float = -8.0 + float(spike_index) * 2.0
		_make_spire(facade, Vector3(x, 26.4, -0.8), 3.0, 0.42, metal_material)

	# Two monumental statues guard the gate.
	_add_cathedral_sentinel(facade, -6.1)
	_add_cathedral_sentinel(facade, 6.1)

	# Broad approach steps make the cathedral feel grounded in the world.
	for step_index in range(8):
		var step_width: float = 15.5 + float(step_index) * 1.5
		var step_depth: float = 1.0 + float(step_index) * 0.18
		_box(facade, Vector3(0, 0.3 + float(step_index) * 0.13, 1.5 + float(step_index) * 1.1), Vector3(step_width, 0.42, step_depth), worn_stone_material, true)

	# A dim pulse waits behind the gate until the cinematic reveal.
	portal_light = OmniLight3D.new()
	portal_light.position = Vector3(0, 5.0, -6.6)
	portal_light.light_color = Color(0.82, 0.045, 0.018)
	portal_light.light_energy = 0.28
	portal_light.omni_range = 23.0
	facade.add_child(portal_light)

func _add_gate_guardian(parent: Node3D) -> void:
	gate_guardian = Node3D.new()
	gate_guardian.name = "TheBellWarden"
	gate_guardian.position = Vector3(0, 0, -8.4)
	gate_guardian.visible = false
	parent.add_child(gate_guardian)
	var black_iron := _standard_material(Color(0.022, 0.025, 0.035), 0.94, 0.22)
	var dark_bone := _standard_material(Color(0.12, 0.095, 0.095), 0.22, 0.84)
	var blood_glow := _standard_material(Color(0.74, 0.018, 0.012), 0.1, 0.18, Color(1.0, 0.008, 0.002), 4.5)
	_box(gate_guardian, Vector3(0, 6.1, 0), Vector3(2.8, 4.2, 1.4), black_iron)
	_box(gate_guardian, Vector3(0, 7.2, -0.1), Vector3(3.4, 1.1, 1.8), dark_bone)
	_sphere(gate_guardian, Vector3(0, 8.6, -0.05), Vector3(1.4, 1.55, 1.05), black_iron)
	_box(gate_guardian, Vector3(0, 8.38, -0.55), Vector3(0.9, 0.22, 0.12), dark_bone)
	_sphere(gate_guardian, Vector3(-0.3, 8.5, -0.58), Vector3(0.18, 0.12, 0.08), blood_glow)
	_sphere(gate_guardian, Vector3(0.3, 8.5, -0.58), Vector3(0.18, 0.12, 0.08), blood_glow)
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		_box(gate_guardian, Vector3(side * 1.9, 6.25, 0), Vector3(1.05, 3.7, 1.0), black_iron)
		_capsule(gate_guardian, Vector3(side * 2.0, 4.3, 0), 0.38, 1.5, dark_bone)
		_box(gate_guardian, Vector3(side * 0.72, 3.1, 0.0), Vector3(0.85, 3.4, 1.0), black_iron)
		_box(gate_guardian, Vector3(side * 0.8, 1.1, -0.2), Vector3(0.9, 1.8, 1.25), dark_bone)
		# Crown-like broken horns silhouette the Warden against the portal.
		var horn := MeshInstance3D.new()
		var horn_mesh := CylinderMesh.new()
		horn_mesh.top_radius = 0.025
		horn_mesh.bottom_radius = 0.28
		horn_mesh.height = 2.0
		horn_mesh.radial_segments = 7
		horn.mesh = horn_mesh
		horn.position = Vector3(side * 0.58, 9.9, 0.05)
		horn.rotation.z = side * deg_to_rad(24.0)
		horn.material_override = black_iron
		gate_guardian.add_child(horn)
	_box(gate_guardian, Vector3(1.7, 4.8, -0.35), Vector3(0.18, 6.8, 0.18), metal_material)
	_box(gate_guardian, Vector3(1.7, 7.2, -0.35), Vector3(1.6, 0.42, 0.3), black_iron)

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
	var ridge_material := _standard_material(Color(0.022, 0.018, 0.035), 0.0, 1.0)
	for row in range(3):
		var z: float = -42.0 - float(row) * 28.0
		for peak_index in range(9):
			var side: float = -1.0 if peak_index % 2 == 0 else 1.0
			var x: float = side * (18.0 + float(peak_index / 2) * 7.0)
			var height: float = 12.0 + float((peak_index * 7 + row * 3) % 15)
			var peak := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.03
			mesh.bottom_radius = 7.5 + float(peak_index % 4)
			mesh.height = height
			mesh.radial_segments = 7
			peak.mesh = mesh
			peak.position = Vector3(x, height * 0.5 - 2.0, z - float(peak_index % 3) * 5.0)
			peak.material_override = ridge_material
			horizon.add_child(peak)

	# Far watchtowers puncture the fog beyond the cathedral.
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		for tower_index in range(3):
			var tower_z: float = -72.0 - float(tower_index) * 23.0
			var tower_x: float = side * (22.0 + float(tower_index) * 5.0)
			_box(horizon, Vector3(tower_x, 7.0, tower_z), Vector3(3.4, 14.0, 3.4), ridge_material)
			_make_spire(horizon, Vector3(tower_x, 14.0, tower_z), 9.0, 2.6, ridge_material)

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
	intro_title_label.set_anchors_preset(Control.PRESET_CENTER)
	intro_title_label.position = Vector2(-310, -100)
	intro_title_label.size = Vector2(620, 205)
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
	hud_panel.size = Vector2(338, 132)
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

	menu_panel = _make_overlay_panel(root_ui, Vector2(495, 444))
	menu_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	menu_panel.position = Vector2(54, -222)
	var menu_box := VBoxContainer.new()
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 17)
	menu_panel.add_child(menu_box)
	var eyebrow := _label("THE ASHEN KINGDOM  /  CHAPTER I", 13, Color(0.8, 0.35, 0.26))
	menu_box.add_child(eyebrow)
	var title := _label("BLACKTHORN\nOATH", 49, Color(0.95, 0.89, 0.79))
	title.add_theme_constant_override("line_spacing", -8)
	menu_box.add_child(title)
	var description := _label("The bells have fallen silent.\nSomething beneath the cathedral has begun to wake.", 16, Color(0.74, 0.69, 0.68))
	menu_box.add_child(description)
	var start := _button(menu_box, "ENTER THE RUINS", Vector2.ZERO, Vector2(0, 62), _start_run, Control.PRESET_TOP_LEFT, 19)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var controls_hint := _label("SWIPE  move / jump / slide     •     TAP  strike", 13, Color(0.67, 0.62, 0.64))
	menu_box.add_child(controls_hint)
	var footer := _label("BEST  %05d m        RELICS  %03d" % [best_distance, relic_bank], 12, Color(0.57, 0.53, 0.56))
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

	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0.008, 0.006, 0.012, 1.0)
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(fade_overlay)

func _update_cinematic(delta: float) -> void:
	intro_elapsed += delta
	var t: float = intro_elapsed
	if t < 4.2:
		var amount: float = _ease((t - 0.0) / 4.2)
		camera.global_position = Vector3(22.0, 17.0, 23.0).lerp(Vector3(11.0, 11.5, 4.0), amount)
		camera.look_at(Vector3(0, 15.0, -112.0), Vector3.UP)
		_set_cinematic_copy("THE NORTH ONCE KNEW THE SOUND OF BELLS.", "", 0.0)
	elif t < 8.0:
		var amount: float = _ease((t - 4.2) / 3.8)
		camera.global_position = Vector3(11.0, 11.5, 4.0).lerp(Vector3(-9.0, 7.0, -55.0), amount)
		camera.look_at(Vector3(0, 12.0, -112.0), Vector3.UP)
		var gate_amount: float = _ease((t - 5.35) / 2.45)
		cathedral_gate_left.rotation.y = -0.94 * gate_amount
		cathedral_gate_right.rotation.y = 0.94 * gate_amount
		gate_guardian.visible = gate_amount > 0.28
		portal_light.light_energy = 0.28 + gate_amount * 4.4
		portal_light.light_color = Color(0.82, 0.045, 0.018).lerp(Color(1.0, 0.12, 0.025), gate_amount)
		var reveal_line: String = "THEN THE BELLS BEGAN TO ANSWER THEMSELVES." if t < 6.4 else "SOMETHING ANSWERED FROM WITHIN."
		_set_cinematic_copy(reveal_line, "", 0.0)
		if t > 7.35:
			camera.global_position += Vector3(sin(t * 68.0) * 0.035, cos(t * 54.0) * 0.022, 0.0)
	elif t < 11.5:
		var amount: float = _ease((t - 8.0) / 3.5)
		camera.global_position = Vector3(-9.0, 7.0, -55.0).lerp(Vector3(3.4, 2.7, 0.2), amount)
		camera.look_at(Vector3(0, 1.45, -3.0), Vector3.UP)
		_set_cinematic_copy("THE KINGDOM FELL. THE DEAD REMAINED.", "", 0.0)
	elif t < 15.0:
		var amount: float = _ease((t - 11.5) / 3.5)
		camera.global_position = Vector3(3.4, 2.7, 0.2).lerp(Vector3(0.0, 4.3, 7.4), amount)
		camera.look_at(Vector3(0, 1.1, -17.0), Vector3.UP)
		_set_cinematic_copy("ONE KNIGHT. ONE ROAD. NO WAY BACK.", "BLACKTHORN\nOATH", 1.0)
	elif t < INTRO_LENGTH:
		camera.global_position = Vector3(0, 4.3, 7.4).lerp(Vector3(0, 4.15, 7.8), _ease((t - 15.0) / 3.0))
		camera.look_at(Vector3(0, 1.0, -17.0), Vector3.UP)
		_set_cinematic_copy("THE OATH DOES NOT END WITH DEATH.", "BLACKTHORN\nOATH", 0.92)
	else:
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
	cathedral_gate_left.rotation.y = -0.94
	cathedral_gate_right.rotation.y = 0.94
	gate_guardian.visible = true
	portal_light.light_energy = 4.68
	_finish_intro()

func _start_run() -> void:
	if not intro_complete or game_started:
		return
	game_started = true
	game_over = false
	paused = false
	menu_panel.hide()
	hud.show()
	controls.show()
	pause_button.text = "Ⅱ"
	player.forward_speed = 12.0
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
	var wall_height: float = 7.2 if serial % 3 != 1 else 5.4
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		var wall_x: float = side * 6.25
		_box(parent, Vector3(wall_x, wall_height * 0.5, -SEGMENT_LENGTH * 0.5), Vector3(0.85, wall_height, SEGMENT_LENGTH), dark_stone_material)
		_box(parent, Vector3(wall_x, wall_height, -SEGMENT_LENGTH * 0.5), Vector3(1.25, 0.42, SEGMENT_LENGTH), worn_stone_material)
		for pillar_index in range(4):
			var pillar_z: float = -3.0 - float(pillar_index) * 8.4
			_box(parent, Vector3(side * 5.82, wall_height * 0.5, pillar_z), Vector3(0.78, wall_height + 0.45, 1.1), stone_material)
			_box(parent, Vector3(side * 5.82, 0.3, pillar_z), Vector3(1.2, 0.6, 1.45), worn_stone_material)
			_box(parent, Vector3(side * 5.82, wall_height, pillar_z), Vector3(1.25, 0.5, 1.4), worn_stone_material)
			_box(parent, Vector3(side * 5.42, wall_height * 0.53, pillar_z), Vector3(0.28, wall_height * 0.9, 0.38), gold_material)
			if serial % 3 == 0 and pillar_index % 2 == 0:
				_add_brazier(parent, side * 5.15, 1.5, pillar_z - 1.7)
		if serial % 3 == 1:
			_add_hanging_banner(parent, side * 5.78, 6.6, -14.0)
		elif serial % 3 == 2:
			_add_wall_statue(parent, side * 5.72, 2.8, -19.0)
		else:
			_add_broken_column(parent, side * 7.4, wall_height, -23.0)

	# A few fractured slabs and masonry chunks interrupt the clean road edges.
	for debris_index in range(5):
		var side: float = -1.0 if debris_index % 2 == 0 else 1.0
		var z: float = -3.0 - float(debris_index) * 5.1
		var rock_size := Vector3(0.55 + float(debris_index % 3) * 0.28, 0.3 + float(debris_index % 2) * 0.25, 0.65)
		var rock := _box(parent, Vector3(side * (4.55 + float(debris_index % 2) * 0.25), 0.15, z), rock_size, worn_stone_material)
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
	var target_position: Vector3 = player.global_position + Vector3(0, 4.15, 8.1)
	camera.global_position = camera.global_position.lerp(target_position, minf(delta * 6.0, 1.0))
	camera.look_at(player.global_position + Vector3(0, 1.1, -6.3), Vector3.UP)
	camera.fov = lerpf(camera.fov, 59.0, delta * 1.2)

func _idle_camera(delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player):
		return
	var time: float = Time.get_ticks_msec() / 1000.0
	var sway := Vector3(sin(time * 0.19) * 0.28, 0.04 * sin(time * 0.3), 0.0)
	var target_position: Vector3 = player.global_position + Vector3(0, 4.3, 8.5) + sway
	camera.global_position = camera.global_position.lerp(target_position, minf(delta * 1.7, 1.0))
	camera.look_at(player.global_position + Vector3(0, 1.0, -8.0), Vector3.UP)

func _update_hud() -> void:
	if not is_instance_valid(score_label) or not is_instance_valid(player):
		return
	score_label.text = "DISTANCE   %05d m      KILLS  %02d" % [int(distance), kills]
	health_label.text = "VITALITY   " + "♥  ".repeat(player.health) + "♡  ".repeat(3 - player.health)
	relic_label.text = "RELICS   %03d    /    RESERVE  %03d" % [relics, relic_bank]
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
	_save_progress()
	modal_title.text = "OATH BROKEN"
	modal_body.text = "DISTANCE  %d m     KILLS  %d\nRELICS FOUND  %d\nBEST RUN  %d m" % [int(distance), kills, relics, best_distance]
	modal_action.text = "RUN AGAIN"
	modal_panel.show()
	_update_hud()

func add_kill() -> void:
	kills += 1

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
