extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not ResourceLoader.exists("res://dash/dash_player.gd"):
		push_error("FAIL: dash controller has not been implemented")
		quit(1)
		return
	var player = load("res://dash/dash_player.gd").new()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	assert(player.try_dash(Vector3.FORWARD), "First dash must be available")
	assert(not player.try_dash(Vector3.RIGHT), "Cannot dash twice without recharge")
	player.dash_left = 0.0
	player.refill_dash()
	assert(player.try_dash(Vector3.RIGHT), "Fresh recharge must permit dash")
	player._physics_process(player.dash_duration + 0.01)
	assert(Vector2(player.velocity.x, player.velocity.z).length() <= player.run_speed + 0.01, "Dash expiry must shed excess horizontal speed")
	player.reset_to(Vector3(1, 2, 3))
	assert(player.velocity == Vector3.ZERO and player.dash_left == 0.0, "Reset must cancel momentum")
	assert(player.dash_ready and player.global_position == Vector3(1, 2, 3), "Reset restores spawn and energy")
	print("PASS: dash consumption, recharge and reset")
	player.queue_free()
	quit(0)
