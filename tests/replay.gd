extends SceneTree
## Test-only pilot: drives the real input actions, collisions and ring triggers.
## No teleporting or direct velocity changes. Also used for deterministic capture.

var course
var failed := false
var frame := 0
var capture := false

func _initialize() -> void:
	call_deferred("run")

func direction_input(direction: Vector3) -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)
	if direction.x > 0:
		Input.action_press("move_right", absf(direction.x))
	else:
		Input.action_press("move_left", absf(direction.x))
	if direction.z < 0:
		Input.action_press("move_forward", absf(direction.z))
	else:
		Input.action_press("move_back", absf(direction.z))

func tick(count := 1) -> void:
	for i in count:
		await physics_frame
		frame += 1
		if capture and frame in [60, 170, 300, 500, 750]:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../preview-%04d.png" % frame)

func tap(action: String) -> void:
	Input.action_press(action)
	await tick()
	Input.action_release(action)

func run() -> void:
	var profile = load("res://tests/profile_guard.gd").new()
	profile.capture()
	capture = "--capture" in OS.get_cmdline_user_args()
	course = load("res://dash/course.tscn").instantiate()
	root.add_child(course)
	current_scene = course
	await tick(70)
	for stop in range(1, course.STOPS.size()):
		var origin: Vector3 = course.STOPS[stop - 1]
		var target: Vector3 = course.STOPS[stop]
		var direction: Vector3 = (target - origin)
		direction.y = 0
		direction = direction.normalized()
		direction_input(direction)
		var guard := 0
		while Vector2(course.player.position.x - origin.x, course.player.position.z - origin.z).length() < 1.9 and guard < 120:
			await tick()
			guard += 1
		await tap("jump")
		await tick(10)
		await tap("dash")
		var landed := false
		for i in 210:
			if "--trace" in OS.get_cmdline_user_args() and i % 12 == 0:
				print("TRACE %d.%d p=%s v=%s facing=%s dash=%s jumps=%d" % [stop, i, course.player.position, course.player.velocity, course.player.facing, course.player.dash_ready, course.player.jumps_left])
			var offset: Vector3 = target - course.player.position
			offset.y = 0
			var distance: float = offset.length()
			if distance < 1.3:
				direction_input(Vector3.ZERO)
			else:
				direction_input(offset.normalized())
			if course.player.dash_left <= 0 and course.player.dash_ready and distance > 5.0 and course.rings[stop - 1].consumed:
				await tap("dash")
			if course.player.velocity.y < 0 and course.player.position.y < target.y + 1.7 and course.player.jumps_left > 0 and distance > 3.0:
				await tap("jump")
			await tick()
			if course.player.is_on_floor() and distance < 3.3:
				landed = true
				break
			if course.player.position.y < -5:
				break
		var status := "FINISHED IN AIR" if course.finished and not landed else ("LANDED" if landed else "FAILED")
		print("HOP %d: %s | position %s | rings %d" % [stop, status, course.player.position, course.collected_count])
		if not landed and not course.finished:
			failed = true
			break
		direction_input(Vector3.ZERO)
		await tick(45)
	direction_input(Vector3.ZERO)
	if not failed:
		var destination: Vector3 = course.STOPS[-1]
		for i in 120:
			var offset: Vector3 = destination - course.player.position
			offset.y = 0
			direction_input(offset.normalized())
			await tick()
			if course.finished:
				break
		failed = not course.finished
	print("REPLAY %s | all rings %d/%d | time %.2f" % ["FAIL" if failed else "PASS", course.collected_count, course.rings.size(), course.elapsed])
	direction_input(Vector3.ZERO)
	await tick(100)
	if capture:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../preview-finish.png")
	course.queue_free()
	profile.restore()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
