extends CharacterBody3D
## Camera-aligned platform controller. Dash is a single charge, refilled on landing or a fresh ring.

signal dashed
signal landed
signal fell
signal jumped

@export var run_speed: float = 8.0
@export var acceleration: float = 38.0
@export var jump_speed: float = 10.5
@export var gravity_force: float = 27.0
@export var dash_speed: float = 30.0
@export var dash_duration: float = 0.23
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.13

var dash_ready := true
var dash_left := 0.0
var dash_direction := Vector3.FORWARD
var facing := Vector3.FORWARD
var coyote_left := 0.0
var jump_buffer := 0.0
var jumps_left := 2
var controls_enabled := true
var visual: Node3D
var animation: AnimationPlayer

func _ready() -> void:
	name = "Runner"
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.2
	collider.shape = capsule
	collider.position.y = 0.6
	add_child(collider)
	if ResourceLoader.exists("res://objects/character.tscn"):
		visual = load("res://objects/character.tscn").instantiate()
		add_child(visual)
		animation = visual.get_node_or_null("AnimationPlayer")

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return
	var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(axes.x, 0, axes.y)
	if direction.length_squared() > 0.01:
		facing = direction.normalized()
	if is_on_floor():
		coyote_left = coyote_time
		jumps_left = 2
		refill_dash()
	else:
		coyote_left = maxf(0, coyote_left - delta)
		if coyote_left <= 0 and jumps_left == 2:
			jumps_left = 1
	jump_buffer = maxf(0, jump_buffer - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = jump_buffer_time
	if Input.is_action_just_pressed("dash"):
		try_dash(facing)
	if dash_left > 0:
		dash_left = maxf(0, dash_left - delta)
		velocity = dash_direction * dash_speed
		velocity.y = 1.0
		# Keep dash distance bounded and return control immediately after the burst.
		if dash_left <= 0:
			velocity.x = dash_direction.x * run_speed
			velocity.z = dash_direction.z * run_speed
	else:
		velocity.x = move_toward(velocity.x, direction.x * run_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * run_speed, acceleration * delta)
		if is_on_floor() and velocity.y < 0:
			velocity.y = 0
		else:
			velocity.y -= gravity_force * delta
		if jump_buffer > 0 and jumps_left > 0:
			velocity.y = jump_speed
			jumps_left -= 1
			coyote_left = 0
			jump_buffer = 0
			jumped.emit()
			if visual:
				visual.scale = Vector3(0.85, 1.2, 0.85)
	var grounded_before_move := is_on_floor()
	move_and_slide()
	if is_on_floor() and not grounded_before_move:
		landed.emit()
	if visual:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(facing.x, facing.z), 12 * delta)
		visual.scale = visual.scale.lerp(Vector3.ONE, minf(1, delta * 12))
	if animation:
		var next := "jump" if not is_on_floor() else ("walk" if direction.length_squared() > 0.01 else "idle")
		if animation.has_animation(next) and animation.current_animation != next:
			animation.play(next, 0.12)
	if global_position.y < -12:
		fell.emit()

func try_dash(direction: Vector3) -> bool:
	if not controls_enabled or not dash_ready or dash_left > 0:
		return false
	dash_ready = false
	dash_direction = Vector3(direction.x, 0, direction.z).normalized()
	if dash_direction.length_squared() < 0.01:
		dash_direction = facing
	dash_left = dash_duration
	dashed.emit()
	return true

func refill_dash() -> void:
	dash_ready = true

func reset_to(spawn_position: Vector3) -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	dash_left = 0
	dash_ready = true
	jumps_left = 2
	jump_buffer = 0
	coyote_left = 0
	facing = Vector3.FORWARD
	controls_enabled = true
