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
var slide_timer := 0.0
var hit_shape: CollisionShape3D
var visual_body: MeshInstance3D
var standing_height := 1.7
var sliding_height := 0.9

func _ready() -> void:
	add_to_group("player")
	hit_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = standing_height
	hit_shape.shape = capsule
	hit_shape.position.y = standing_height * 0.5
	add_child(hit_shape)
	visual_body = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = standing_height
	visual_body.mesh = mesh
	var armor := StandardMaterial3D.new()
	armor.albedo_color = Color(0.12, 0.095, 0.12)
	armor.metallic = 0.75
	visual_body.material_override = armor
	visual_body.position.y = standing_height * 0.5
	add_child(visual_body)

func _physics_process(delta: float) -> void:
	if dead:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if slide_timer > 0.0:
		slide_timer = maxf(0.0, slide_timer - delta)
		if slide_timer == 0.0:
			_set_sliding(false)
	if Input.is_action_just_pressed("slide"):
		slide()
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
	move_and_slide()

func move_lane(direction: int) -> void:
	lane = clampi(lane + direction, 0, 2)

func jump() -> void:
	if is_on_floor() and slide_timer <= 0.0:
		velocity.y = jump_velocity

func slide() -> void:
	if is_on_floor() and slide_timer <= 0.0:
		slide_timer = 0.72
		_set_sliding(true)

func _set_sliding(enabled: bool) -> void:
	var capsule := hit_shape.shape as CapsuleShape3D
	capsule.height = sliding_height if enabled else standing_height
	hit_shape.position.y = capsule.height * 0.5
	var mesh := visual_body.mesh as CapsuleMesh
	mesh.height = sliding_height if enabled else standing_height
	visual_body.position.y = mesh.height * 0.5

func attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.48
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var d: Vector3 = enemy.global_position - global_position
			if absf(d.x) < 1.5 and d.z > -3.0 and d.z < 1.0:
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
