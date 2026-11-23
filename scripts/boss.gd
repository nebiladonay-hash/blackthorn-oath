extends "res://scripts/enemy.gd"
class_name BlackthornOathBoss

var boss_health_label: Label3D
var reward_paid := false
var phase := 1
var slam_warning := 0.0
var slam_cooldown := 1.2
var warning_lane_x := 0.0
var strike_telegraph: MeshInstance3D
var telegraph_material: StandardMaterial3D

func _ready() -> void:
	super._ready()
	health = 12
	damage = 1
	attack_interval = 1.5
	scale = Vector3(1.42, 1.42, 1.42)
	boss_health_label = Label3D.new()
	boss_health_label.name = "WardenHealth"
	boss_health_label.text = "THE ASHEN WARDEN   12 / 12"
	boss_health_label.position = Vector3(0.0, 3.45, 0.0)
	boss_health_label.font_size = 38
	boss_health_label.outline_size = 8
	boss_health_label.modulate = Color(0.92, 0.72, 0.53)
	boss_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(boss_health_label)
	_build_strike_telegraph()

func _build_strike_telegraph() -> void:
	strike_telegraph = MeshInstance3D.new()
	strike_telegraph.name = "HeavyStrikeLaneWarning"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.25, 0.035, 7.0)
	strike_telegraph.mesh = mesh
	telegraph_material = StandardMaterial3D.new()
	telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_material.albedo_color = Color(0.82, 0.025, 0.012, 0.34)
	telegraph_material.emission_enabled = true
	telegraph_material.emission = Color(0.95, 0.025, 0.008)
	telegraph_material.emission_energy_multiplier = 1.25
	telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	strike_telegraph.material_override = telegraph_material
	strike_telegraph.position = Vector3(0.0, 0.045, 1.5)
	strike_telegraph.visible = false
	add_child(strike_telegraph)

func _process(delta: float) -> void:
	super._process(delta)
	if is_dead or not is_instance_valid(player) or player.dead:
		return
	slam_cooldown = maxf(0.0, slam_cooldown - delta)
	if slam_warning > 0.0:
		slam_warning = maxf(0.0, slam_warning - delta)
		if is_instance_valid(boss_health_label):
			boss_health_label.text = "ASHEN WARDEN  ·  HEAVY STRIKE"
		if is_instance_valid(strike_telegraph):
			strike_telegraph.visible = true
			telegraph_material.albedo_color.a = 0.24 + 0.18 * absf(sin(Time.get_ticks_msec() * 0.018))
		if slam_warning <= 0.0:
			var distance_z := absf(player.global_position.z - global_position.z)
			var distance_x := absf(player.global_position.x - warning_lane_x)
			if distance_z <= 3.6 and distance_x <= 1.1:
				player.take_damage(1 if phase < 3 else 2)
				var impact_scene := get_tree().current_scene
				if impact_scene != null and impact_scene.has_method("play_sfx"):
					impact_scene.call("play_sfx", "impact", global_position)
			if is_instance_valid(strike_telegraph):
				strike_telegraph.visible = false
			slam_cooldown = 2.7 if phase == 1 else (2.25 if phase == 2 else 1.85)
			_refresh_boss_label()
		return
	var distance_z := absf(player.global_position.z - global_position.z)
	var distance_x := absf(player.global_position.x - global_position.x)
	if slam_cooldown <= 0.0 and distance_z <= 12.5 and distance_z >= 7.0 and distance_x <= 1.45:
		slam_warning = 0.82 if phase < 3 else 0.68
		warning_lane_x = player.global_position.x
		if is_instance_valid(strike_telegraph):
			strike_telegraph.position.x = warning_lane_x - global_position.x
			strike_telegraph.visible = true
		_play_enemy_animation("sword_attack")
		var warning_scene := get_tree().current_scene
		if warning_scene != null and warning_scene.has_method("play_sfx"):
			warning_scene.call("play_sfx", "creature", global_position)
		if is_instance_valid(boss_health_label):
			boss_health_label.text = "ASHEN WARDEN  ·  HEAVY STRIKE"

func _refresh_boss_label() -> void:
	if not is_instance_valid(boss_health_label):
		return
	boss_health_label.text = "THE ASHEN WARDEN  ·  PHASE %d  ·  %d / 12" % [phase, maxi(0, health)]

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	super.take_damage(amount)
	var next_phase := 1 if health > 8 else (2 if health > 4 else 3)
	if next_phase != phase and not is_dead:
		phase = next_phase
		attack_interval = 1.5 if phase == 1 else (1.15 if phase == 2 else 0.85)
		damage = 1 if phase < 3 else 2
		slam_cooldown = minf(slam_cooldown, 0.8)
		_play_enemy_animation("sword_attack")
		if is_instance_valid(boss_health_label):
			boss_health_label.modulate = Color(0.92, 0.72, 0.53) if phase == 1 else (Color(1.0, 0.48, 0.28) if phase == 2 else Color(1.0, 0.2, 0.12))
	_refresh_boss_label()
	if is_dead and not reward_paid:
		reward_paid = true
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("add_boss_reward"):
			scene.call("add_boss_reward")
