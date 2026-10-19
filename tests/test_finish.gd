extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	var profile = load("res://tests/profile_guard.gd").new()
	profile.capture()
	var course = load("res://dash/course.tscn").instantiate()
	root.add_child(course)
	current_scene = course
	await process_frame
	# Put the runner at the approach to the finish, then cross it using actual dash physics.
	course.player.reset_to(course.STOPS[-1] + Vector3(0, 1.4, 4))
	course.collected_count = course.rings.size()
	check(course.player.try_dash(Vector3.FORWARD), "Dash begins on approach")
	for i in 20:
		await physics_frame
		if course.finished:
			break
	check(course.finished, "Airborne dash through finish must win")
	check(not course.player.is_on_floor(), "Dash case must finish before landing")
	# Missing rings must still reject the same airborne crossing.
	course.restart_run()
	course.player.reset_to(course.STOPS[-1] + Vector3(0, 1.4, 4))
	course.player.try_dash(Vector3.FORWARD)
	for i in 20:
		await physics_frame
	check(not course.finished, "Dash cannot bypass the ring requirement")
	# The existing walking route remains supported.
	course.restart_run()
	course.player.reset_to(course.STOPS[-1] + Vector3(0, 0.06, 3.1))
	course.collected_count = course.rings.size()
	Input.action_press("move_forward")
	for i in 60:
		await physics_frame
		if course.finished:
			break
	Input.action_release("move_forward")
	check(course.finished, "Walking through finish must still win")
	check(course.player.is_on_floor(), "Walking case must be grounded")
	await create_timer(0.4).timeout
	profile.restore()
	course.queue_free()
	await process_frame
	print("FINISH TESTS: %d failures" % failures)
	quit(1 if failures else 0)
