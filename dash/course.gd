extends Node3D
## One compact course. No checkpoint logic: a fall resets the complete run.

const PlayerScript = preload("res://dash/dash_player.gd")
const RingScript = preload("res://dash/energy_ring.gd")
const HudScript = preload("res://dash/hud.gd")
const CYAN := Color("65f5e4")
const CORAL := Color("ff9a76")
const STOPS: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0, 0.4, -13), Vector3(6, 0.8, -26), Vector3(-3, 1.2, -39), Vector3(4, 1.5, -52), Vector3(-4, 1.8, -65), Vector3(0, 2.2, -78), Vector3(0, 2.2, -91)]

var player
var hud
var camera: Camera3D
var rings: Array = []
var collected_count := 0
var elapsed := 0.0
var started := false
var finished := false
var reduced_motion := false
var finish_gate: MeshInstance3D
var message_time := 0.0
var trail_clock := 0.0
var world_clock := 0.0
var best_time := 0.0
var sound_pool: Array[AudioStreamPlayer] = []

func _exit_tree() -> void:
	# Release active Ogg playback before the audio server shuts down.
	for audio in sound_pool:
		audio.stop()
		audio.stream = null
	sound_pool.clear()

func _ready() -> void:
	build_environment()
	setup_inputs()
	for i in STOPS.size():
		build_island(STOPS[i], i)
	for i in STOPS.size() - 1:
		var ring = RingScript.new()
		add_child(ring)
		ring.position = STOPS[i].lerp(STOPS[i + 1], 0.5) + Vector3(0, 1.65, 0)
		ring.setup(i, CYAN)
		ring.rotation.y = atan2(STOPS[i + 1].x - STOPS[i].x, STOPS[i + 1].z - STOPS[i].z)
		ring.collected.connect(_on_ring_collected)
		rings.append(ring)
	build_finish()
	player = PlayerScript.new()
	add_child(player)
	player.position = STOPS[0] + Vector3(0, 0.1, 1)
	player.dashed.connect(_on_dash)
	player.jumped.connect(func(): play_sound("res://sounds/jump.ogg", -17))
	player.landed.connect(func(): play_sound("res://sounds/land.ogg", -19))
	player.fell.connect(func(): restart_run("MISSED IT? ANOTHER LEAP."))
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 65
	camera.far = 500
	reset_camera()
	hud = HudScript.new()
	add_child(hud)
	hud.restart_requested.connect(func(): restart_run())
	hud.resume_requested.connect(func(): set_paused(false))
	hud.motion_changed.connect(func(value): reduced_motion = value)
	hud.pause_requested.connect(func():
		if not finished:
			set_paused(not get_tree().paused)
	)
	hud.hint.text = "JUMP, THEN SHIFT TO DASH THROUGH THE CYAN RING"
	message_time = 5
	for i in 6:
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		sound_pool.append(audio)
	var save := ConfigFile.new()
	if save.load("user://aether_dash.cfg") == OK:
		best_time = save.get_value("record", "best_seconds", 0.0)

func setup_inputs() -> void:
	for entry in [["dash", KEY_SHIFT], ["restart", KEY_R], ["pause_run", KEY_ESCAPE]]:
		if not InputMap.has_action(entry[0]):
			InputMap.add_action(entry[0])
			var event := InputEventKey.new()
			event.physical_keycode = entry[1]
			InputMap.action_add_event(entry[0], event)

func _process(delta: float) -> void:
	if not player or not hud:
		return
	world_clock += delta
	if not started and not finished and (Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0 or Input.is_action_pressed("jump") or Input.is_action_pressed("dash")):
		started = true
	if started and not finished:
		elapsed += delta
	hud.update_run(elapsed, collected_count, rings.size(), player.dash_ready)
	message_time = maxf(0, message_time - delta)
	if message_time <= 0:
		hud.hint.text = "ALL RINGS FOUND / REACH THE CORAL GATE" if collected_count == rings.size() else "RINGS REFILL YOUR DASH / KEEP THE CHAIN ALIVE"
	var target: Vector3 = player.global_position + Vector3(0, 6.2, 10)
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-7.0 * delta))
	camera.look_at(player.global_position + Vector3(0, 1.0, -3.8))
	var target_fov := 65.0 if reduced_motion or player.dash_left <= 0 else 74.0
	camera.fov = lerpf(camera.fov, target_fov, minf(1, delta * 9))
	trail_clock += delta
	if player.dash_left > 0 and trail_clock > 0.035 and not reduced_motion:
		trail_clock = 0
		burst(player.global_position + Vector3(0, 0.5, 0), CYAN, 0.16)
	# The finish accepts airborne crossings, including an active dash.
	if player.global_position.distance_to(STOPS[-1]) < 2.5 and not finished:
		try_finish()

func set_paused(value: bool) -> void:
	get_tree().paused = value
	hud.show_overlay(value)

func restart_run(message := "FRESH RUN / MAKE IT FLOW") -> void:
	get_tree().paused = false
	finished = false
	started = false
	elapsed = 0
	collected_count = 0
	for ring in rings:
		ring.reset_ring()
	player.reset_to(STOPS[0] + Vector3(0, 0.1, 1))
	reset_camera()
	if hud:
		hud.show_overlay(false)
		hud.hint.text = message
	message_time = 3

func reset_camera() -> void:
	camera.global_position = player.global_position + Vector3(0, 6.2, 10)
	camera.look_at(player.global_position + Vector3(0, 1, -3.8))

func _on_dash() -> void:
	play_sound("res://sounds/jump.ogg", -13, 1.5)

func _on_ring_collected(ring) -> void:
	collected_count += 1
	play_sound("res://sounds/coin.ogg", -10, 1.0 + collected_count * 0.08)
	burst(ring.global_position, CYAN, 0.28)
	hud.hint.text = "ENERGY RESTORED  /  %d OF %d" % [collected_count, rings.size()]
	message_time = 1.3

func try_finish() -> bool:
	if finished or collected_count != rings.size():
		return false
	finished = true
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	if player.animation:
		player.animation.play("idle", 0.15)
	if best_time <= 0 or elapsed < best_time:
		best_time = elapsed
		var save := ConfigFile.new()
		save.set_value("record", "best_seconds", best_time)
		save.save("user://aether_dash.cfg")
	hud.show_overlay(true, true, elapsed)
	hud.overlay_body.text += "  Best: %.2fs" % best_time
	play_sound("res://sounds/coin.ogg", -8, 1.6)
	return true

func play_sound(path: String, volume := -14.0, pitch := 1.0) -> void:
	if not ResourceLoader.exists(path):
		return
	for audio in sound_pool:
		if not audio.playing:
			audio.stream = load(path)
			audio.volume_db = volume
			audio.pitch_scale = pitch
			audio.play()
			break

func material(color: Color, unlit := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	if unlit:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, bottom := -1.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius if bottom < 0 else bottom
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material(color)
	parent.add_child(instance)
	return instance

func build_island(at: Vector3, number: int) -> void:
	var island := StaticBody3D.new()
	add_child(island)
	island.position = at
	island.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.4
	shape.height = 0.72
	collision.shape = shape
	collision.position.y = -0.3
	island.add_child(collision)
	cylinder(island, Vector3(0, -0.3, 0), 3.6, 0.6, Color("263652"))
	cylinder(island, Vector3(0, 0.01, 0), 3.45, 0.1, Color("466577"))
	cylinder(island, Vector3(0, -0.95, 0), 3.2, 1.1, Color("17203b"), 1.2)
	var rim := cylinder(island, Vector3(0, -0.35, 0), 3.65, 0.07, CYAN if number < STOPS.size() - 1 else CORAL)
	rim.material_override = material(CYAN if number < STOPS.size() - 1 else CORAL, true)
	var label := Label3D.new()
	label.text = "%02d" % (number + 1)
	label.font_size = 100
	label.pixel_size = 0.014
	label.modulate = Color("a5cdd5")
	label.position = Vector3(0, 0.075, 1.4)
	label.rotation_degrees.x = -90
	label.no_depth_test = false
	island.add_child(label)
	# Short luminous runway markings make the next leap legible.
	for mark in 3:
		var cube := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.025, 0.4)
		cube.mesh = box
		cube.position = Vector3(0, 0.075, -1.0 - mark * 0.65)
		cube.material_override = material(CYAN, true)
		island.add_child(cube)
	var beacon := cylinder(island, Vector3(-2.4, 0.35, 0), 0.09, 0.7, Color("324663"))
	cylinder(beacon, Vector3(0, 0.4, 0), 0.17, 0.13, CORAL)

func build_finish() -> void:
	finish_gate = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.7
	torus.outer_radius = 1.9
	finish_gate.mesh = torus
	finish_gate.rotation.x = PI / 2
	finish_gate.position = STOPS[-1] + Vector3(0, 1.9, -0.5)
	finish_gate.material_override = material(CORAL, true)
	add_child(finish_gate)
	var label := Label3D.new()
	label.text = "FINISH"
	label.position = STOPS[-1] + Vector3(0, 4.2, -0.5)
	label.font_size = 60
	label.modulate = CORAL
	add_child(label)

func build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("07172e")
	sky_mat.sky_horizon_color = Color("537587")
	sky_mat.ground_bottom_color = Color("07172e")
	sky_mat.ground_horizon_color = Color("537587")
	sky_mat.sun_angle_max = 0
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aec9e8")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("ffe7c1")
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	add_child(sun)
	var rng := RandomNumberGenerator.new()
	rng.seed = 713
	for i in 65:
		var rock := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		var scale_value := rng.randf_range(2, 8)
		mesh.size = Vector3(scale_value, scale_value * 1.6, scale_value)
		rock.mesh = mesh
		rock.position = Vector3(rng.randf_range(-65, 65), rng.randf_range(-24, -10), rng.randf_range(-155, 20))
		rock.rotation = Vector3(rng.randf(), rng.randf() * TAU, PI)
		rock.material_override = material(Color("213b54"))
		add_child(rock)
	for i in 90:
		var star := MeshInstance3D.new()
		var dot := SphereMesh.new()
		dot.radius = 0.055
		dot.height = 0.11
		star.mesh = dot
		star.position = Vector3(rng.randf_range(-60, 60), rng.randf_range(3, 35), rng.randf_range(-150, 10))
		star.material_override = material(Color("9ebfca"), true)
		add_child(star)

func burst(at: Vector3, color: Color, size_value: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = size_value
	mesh.height = size_value * 2
	var particle := MeshInstance3D.new()
	particle.mesh = mesh
	particle.material_override = material(color, true)
	particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particle)
	particle.global_position = at
	var tween := create_tween().set_parallel(true)
	tween.tween_property(particle, "scale", Vector3.ONE * 0.05, 0.25)
	tween.tween_property(particle, "transparency", 1.0, 0.25)
	tween.chain().tween_callback(particle.queue_free)
