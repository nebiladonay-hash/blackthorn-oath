extends SceneTree

func _initialize() -> void:
	call_deferred("_run_gameplay_checks")

func _run_gameplay_checks() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("GAMEPLAY_TEST: main scene could not be loaded")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	scene._skip_intro()
	scene._start_run()
	var player := scene.player as BlackthornOathPlayer
	if player == null:
		push_error("GAMEPLAY_TEST: player was not created")
		scene.queue_free()
		quit(1)
		return

	var enemy := BlackthornOathEnemy.new()
	enemy.configure(BlackthornOathEnemy.EnemyType.HOLLOW_GUARD)
	enemy.position = player.position + Vector3(0.0, 0.0, -5.0)
	scene.add_child(enemy)
	var enemy_z := enemy.global_position.z

	for frame_index in range(90):
		await physics_frame

	if player.global_position.z <= enemy_z + 0.25:
		push_error("GAMEPLAY_TEST: player passed through the enemy collider")
		scene.queue_free()
		quit(2)
		return
	print("GAMEPLAY_COLLISION_OK player_z=", player.global_position.z, " enemy_z=", enemy_z)

	if player.imported_animation == null or not player.imported_animation.has_animation("combat/sword_attack"):
		push_error("GAMEPLAY_TEST: imported sword attack animation is missing")
		scene.queue_free()
		quit(3)
		return
	if not str(player.imported_animation.current_animation).contains("sprint"):
		push_error("GAMEPLAY_TEST: player is not playing the sprint clip while running: %s" % player.imported_animation.current_animation)
		scene.queue_free()
		quit(4)
		return
	print("GAMEPLAY_ANIMATION_OK ", player.imported_animation.current_animation)

	var enemy_health_before := enemy.health
	player.attack()
	if enemy.health != enemy_health_before - 1:
		push_error("GAMEPLAY_TEST: sword attack did not damage enemy")
		scene.queue_free()
		quit(5)
		return
	print("GAMEPLAY_COMBAT_OK enemy_health=", enemy.health)

	player.move_lane(1)
	for frame_index in range(30):
		await physics_frame
	if player.global_position.x < 0.35:
		push_error("GAMEPLAY_TEST: physics-based lane movement failed")
		scene.queue_free()
		quit(6)
		return
	print("GAMEPLAY_LANE_OK x=", player.global_position.x)

	print("GAMEPLAY_VALIDATION_COMPLETE")
	scene.queue_free()
	await process_frame
	quit(0)
