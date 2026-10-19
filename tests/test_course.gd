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
	var landings := [0]
	course.player.landed.connect(func(): landings[0] += 1)
	course.player.position = Vector3(0, 3, 1)
	for i in 70:
		await physics_frame
	check(landings[0] == 1, "A physical landing must emit once")
	course.player.set_physics_process(false)
	check(not course.try_finish(), "Finish must reject a run with missing rings")
	var ring = course.rings[0]
	check(ring.consume(course.player), "Fresh ring accepts player")
	check(not ring.consume(course.player), "Same ring cannot grant another recharge")
	check(course.collected_count == 1, "Duplicate trigger must not increase progress")
	course.player.velocity = Vector3(20, -30, 5)
	course.elapsed = 12
	course.restart_run()
	await create_timer(0.4).timeout
	check(ring.hoop.transparency == 0.0, "Immediate restart must cancel collection fade")
	check(not ring.consumed and course.collected_count == 0, "Restart resets rings")
	check(course.elapsed == 0 and course.player.velocity == Vector3.ZERO, "Restart clears time and momentum")
	course.started = true
	course.elapsed = 4
	course.set_paused(true)
	await create_timer(0.15, true).timeout
	check(course.elapsed == 4, "Pause freezes the clock")
	var escape := InputEventAction.new()
	escape.action = "pause_run"
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(not paused, "Escape must resume while the course is paused")
	course.set_paused(false)
	for item in course.rings:
		item.consume(course.player)
	check(course.try_finish(), "All rings unlock finish")
	check(course.finished and not course.player.controls_enabled, "Finish locks movement")
	course.restart_run()
	check(not course.finished and course.player.controls_enabled, "Restart after finish restores movement")
	await create_timer(0.4).timeout
	print("COURSE TESTS: %d failures" % failures)
	profile.restore()
	course.queue_free()
	await process_frame
	quit(1 if failures else 0)
