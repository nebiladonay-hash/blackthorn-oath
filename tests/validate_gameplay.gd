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

	# Economy regression: kill rewards, persistent wallet, armoury purchase,
	# and the purchased weapon stat must all stay connected.
	var wallet_before: int = scene.coin_wallet
	scene.add_kill()
	if scene.coin_wallet != wallet_before + 5:
		push_error("GAMEPLAY_TEST: kill did not award five coins")
		scene.queue_free()
		quit(11)
		return
	scene.coin_wallet = 100
	scene._buy_upgrade("blade")
	if scene.coin_wallet != 20 or player.attack_power != 2 or scene.blade_level != 1:
		push_error("GAMEPLAY_TEST: armoury blade purchase did not apply and persist")
		scene.queue_free()
		quit(12)
		return
	player.attack_power = 1
	print("GAMEPLAY_ECONOMY_OK wallet=", scene.coin_wallet, " blade_level=", scene.blade_level)

	# Daily contract claim must pay once, persist its claimed state, and reject duplicates.
	var wallet_before_contract: int = scene.coin_wallet
	scene.daily_kills = 10
	scene._claim_contract(0)
	if scene.coin_wallet != wallet_before_contract + 60 or not scene.daily_claimed[0]:
		push_error("GAMEPLAY_TEST: completed daily kill contract did not pay")
		scene.queue_free()
		quit(13)
		return
	scene._claim_contract(0)
	if scene.coin_wallet != wallet_before_contract + 60:
		push_error("GAMEPLAY_TEST: daily contract reward could be claimed twice")
		scene.queue_free()
		quit(14)
		return
	print("GAMEPLAY_DAILY_CONTRACT_OK reward=60")

	# Consumable inventory must persist through the shop, heal exactly one point,
	# and decrement only when a flask is actually used.
	scene.coin_wallet = 100
	scene._buy_upgrade("flask")
	if scene.coin_wallet != 55 or scene.healing_flasks != 1:
		push_error("GAMEPLAY_TEST: healing flask purchase failed")
		scene.queue_free()
		quit(15)
		return
	player.health = maxi(1, player.max_health - 1)
	var health_before_flask: int = player.health
	scene._use_healing_flask()
	if player.health != health_before_flask + 1 or scene.healing_flasks != 0:
		push_error("GAMEPLAY_TEST: healing flask did not heal and consume correctly")
		scene.queue_free()
		quit(16)
		return
	print("GAMEPLAY_INVENTORY_OK healing_flask=consumed")

	player.attack_power = 1
	var enemy := BlackthornOathEnemy.new()
	enemy.configure(BlackthornOathEnemy.EnemyType.HOLLOW_GUARD)
	enemy.position = player.position + Vector3(0.0, 0.0, -5.0)
	scene.add_child(enemy)
	enemy.attack_timer = 999.0
	var enemy_z := enemy.global_position.z

	for frame_index in range(90):
		await physics_frame

	if player.global_position.z <= enemy_z + 0.25:
		push_error("GAMEPLAY_TEST: player passed through the enemy collider")
		scene.queue_free()
		quit(2)
		return
	print("GAMEPLAY_COLLISION_OK player_z=", player.global_position.z, " enemy_z=", enemy_z)

	if player.imported_model == null or not is_equal_approx(player.imported_model.rotation.y, PI):
		push_error("GAMEPLAY_TEST: runner is not facing down the -Z track")
		scene.queue_free()
		quit(7)
		return
	if player.imported_animation == null or player._resolve_imported_animation("attack") == StringName():
		push_error("GAMEPLAY_TEST: KayKit native attack animation is missing")
		scene.queue_free()
		quit(3)
		return
	if not str(player.imported_animation.current_animation).to_lower().contains("run"):
		push_error("GAMEPLAY_TEST: player is not playing a KayKit running clip: %s" % player.imported_animation.current_animation)
		scene.queue_free()
		quit(4)
		return
	print("GAMEPLAY_ANIMATION_OK ", player.imported_animation.current_animation)

	# Isolate the sword arc from the enemy's autonomous attack cycle and
	# runner translation; the moving-target timing is exercised in live play.
	enemy.attack_timer = 999.0
	player.forward_speed = 0.0
	var enemy_health_before := enemy.health
	player.attack()
	# Melee damage is intentionally delayed until the blade reaches its impact
	# frame. Wait through that authored wind-up instead of checking on input.
	await create_timer(0.24).timeout
	if enemy.health != enemy_health_before - 1:
		push_error("GAMEPLAY_TEST: sword attack did not damage enemy")
		scene.queue_free()
		quit(5)
		return
	if not str(player.imported_animation.current_animation).to_lower().contains("attack"):
		push_error("GAMEPLAY_TEST: KayKit sword attack animation did not start: %s" % player.imported_animation.current_animation)
		scene.queue_free()
		quit(8)
		return
	if enemy.imported_animation == null or enemy.imported_animation.current_animation != "hit_chest":
		push_error("GAMEPLAY_TEST: enemy hit reaction animation did not start")
		scene.queue_free()
		quit(9)
		return
	print("GAMEPLAY_COMBAT_OK player=", player.imported_animation.current_animation, " enemy=", enemy.imported_animation.current_animation)

	player.attack_cooldown = 0.0
	player.attack()
	await create_timer(0.24).timeout
	if not enemy.is_dead or enemy.imported_animation.current_animation != "death":
		push_error("GAMEPLAY_TEST: enemy death animation did not start")
		scene.queue_free()
		quit(10)
		return
	print("GAMEPLAY_DEATH_OK ", enemy.imported_animation.current_animation)

	player.move_lane(1)
	for frame_index in range(30):
		await physics_frame
	if player.global_position.x < 0.35:
		push_error("GAMEPLAY_TEST: physics-based lane movement failed")
		scene.queue_free()
		quit(6)
		return
	print("GAMEPLAY_LANE_OK x=", player.global_position.x)

	# Ashen Warden boss: higher health, readable world-space health display,
	# ordinary kill payout plus one-time boss reward.
	var boss := BlackthornOathBoss.new()
	boss.position = player.global_position + Vector3(0.0, 0.0, -4.0)
	scene.add_child(boss)
	await process_frame
	if boss.health != 12 or boss.boss_health_label == null:
		push_error("GAMEPLAY_TEST: Ashen Warden did not initialize with its health display")
		scene.queue_free()
		quit(17)
		return
	var boss_wallet_before: int = scene.coin_wallet
	var boss_relics_before: int = scene.relic_bank
	boss.take_damage(11)
	if boss.health != 1 or boss.is_dead:
		push_error("GAMEPLAY_TEST: boss damage phase did not preserve remaining health")
		scene.queue_free()
		quit(18)
		return
	boss.take_damage(1)
	if not boss.is_dead or not boss.reward_paid:
		push_error("GAMEPLAY_TEST: boss death or one-time reward did not trigger")
		scene.queue_free()
		quit(19)
		return
	if scene.coin_wallet != boss_wallet_before + 55 or scene.relic_bank != boss_relics_before + 3:
		push_error("GAMEPLAY_TEST: boss reward payout was incorrect")
		scene.queue_free()
		quit(20)
		return
	boss.take_damage(5)
	if scene.coin_wallet != boss_wallet_before + 55:
		push_error("GAMEPLAY_TEST: boss reward could be paid more than once")
		scene.queue_free()
		quit(21)
		return
	print("GAMEPLAY_BOSS_OK health=12 reward=50 coins+3 relics")

	print("GAMEPLAY_VALIDATION_COMPLETE")
	scene.queue_free()
	await process_frame
	quit(0)
