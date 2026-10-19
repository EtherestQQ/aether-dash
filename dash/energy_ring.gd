extends Area3D

signal collected(ring)

var index := 0
var consumed := false
var hoop: MeshInstance3D
var halo: MeshInstance3D
var clock := 0.0
var collection_tween: Tween

func setup(number: int, tint: Color) -> void:
	index = number
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.65
	shape.shape = sphere
	add_child(shape)
	hoop = make_hoop(1.2, 1.36, tint)
	add_child(hoop)
	halo = make_hoop(1.48, 1.5, Color(tint, 0.3))
	add_child(halo)
	body_entered.connect(_on_body_entered)

func make_hoop(inner: float, outer: float, tint: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 12
	instance.mesh = mesh
	instance.rotation.x = PI / 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	if tint.a < 1:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func _process(delta: float) -> void:
	clock += delta
	if consumed:
		return
	hoop.rotation.z = sin(clock * 2) * 0.04
	halo.scale = Vector3.ONE * (1.0 + sin(clock * 3) * 0.035)

func _on_body_entered(body: Node3D) -> void:
	if consumed or not body.has_method("refill_dash"):
		return
	consume(body)

func consume(body: Node3D) -> bool:
	if consumed:
		return false
	consumed = true
	body.refill_dash()
	collected.emit(self)
	collection_tween = create_tween().set_parallel(true)
	collection_tween.tween_property(hoop, "scale", Vector3.ONE * 1.15, 0.15)
	collection_tween.tween_property(hoop, "transparency", 1.0, 0.15)
	collection_tween.tween_property(halo, "transparency", 1.0, 0.15)
	return true

func reset_ring() -> void:
	consumed = false
	if collection_tween:
		collection_tween.kill()
	if hoop:
		hoop.scale = Vector3.ONE
		hoop.transparency = 0
		halo.transparency = 0
