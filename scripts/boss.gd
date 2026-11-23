extends "res://scripts/enemy.gd"
class_name BlackthornOathBoss

var boss_health_label: Label3D
var reward_paid := false
var phase_two := false

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

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	super.take_damage(amount)
	if health <= 6 and not is_dead and not phase_two:
		phase_two = true
		attack_interval = 1.0
		damage = 2
		if is_instance_valid(boss_health_label):
			boss_health_label.modulate = Color(1.0, 0.35, 0.24)
	if is_instance_valid(boss_health_label):
		var title := "THE ASHEN WARDEN · ENRAGED" if phase_two else "THE ASHEN WARDEN"
		boss_health_label.text = "%s   %d / 12" % [title, maxi(0, health)]
	if is_dead and not reward_paid:
		reward_paid = true
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("add_boss_reward"):
			scene.call("add_boss_reward")
