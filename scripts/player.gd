extends CharacterBody3D
class_name BlackthornOathPlayer

signal health_changed(value: int)
signal died

@export var forward_speed := 12.0
@export var lane_width := 2.6
@export var jump_velocity := 10.5
var lane := 1
var health := 3
var dead := false
var invulnerability := 0.0
var attack_cooldown := 0.0

func _ready() -> void:
	add_to_group("player")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.7
	body.mesh = mesh
	var armor := StandardMaterial3D.new()
	armor.albedo_color = Color(0.12, 0.095, 0.12)
	armor.metallic = 0.75
	body.material_override = armor
	body.position.y = 0.85
	add_child(body)

func _physics_process(delta: float) -> void:
	if dead:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if Input.is_action_just_pressed("lane_left"):
		move_lane(-1)
	if Input.is_action_just_pressed("lane_right"):
		move_lane(1)
	if Input.is_action_just_pressed("jump"):
		jump()
	if Input.is_action_just_pressed("attack"):
		attack()
	global_position.x = move_toward(global_position.x, float(lane - 1) * lane_width, 13.0 * delta)
	velocity.z = -forward_speed
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	move_and_slide()

func move_lane(direction: int) -> void:
	lane = clampi(lane + direction, 0, 2)

func jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity

func attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var d: Vector3 = enemy.global_position - global_position
			if absf(d.x) < 1.5 and d.z > -2.5 and d.z < 1.0:
				enemy.take_damage(1)

func take_damage(amount: int = 1) -> void:
	if dead or invulnerability > 0.0:
		return
	health = maxi(0, health - amount)
	invulnerability = 1.0
	health_changed.emit(health)
	if health == 0:
		dead = true
		died.emit()
