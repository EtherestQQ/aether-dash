extends CanvasLayer

signal restart_requested
signal resume_requested
signal motion_changed(value)
signal pause_requested

var timer_label: Label
var rings_label: Label
var energy_label: Label
var hint: Label
var progress: ProgressBar
var overlay: Panel
var overlay_title: Label
var overlay_body: Label
var root: Control
const CYAN := Color("65f5e4")
const INK := Color("0b152b")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel(Vector2(28, 25), Vector2(265, 88))
	text("AETHER / DASH", Vector2(46, 34), 27, Color.WHITE)
	text("A SMALL LEAP INTO THE UNKNOWN", Vector2(47, 75), 11, CYAN)
	panel(Vector2(920, 25), Vector2(330, 88))
	timer_label = text("00.00", Vector2(940, 34), 30, Color.WHITE)
	rings_label = text("RINGS   0 / 7", Vector2(1090, 45), 16, CYAN)
	energy_label = text("DASH READY", Vector2(940, 78), 11, CYAN)
	progress = ProgressBar.new()
	progress.position = Vector2(30, 127)
	progress.size = Vector2(1220, 3)
	progress.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color("192943")
	var fill := StyleBoxFlat.new()
	fill.bg_color = CYAN
	progress.add_theme_stylebox_override("background", track)
	progress.add_theme_stylebox_override("fill", fill)
	root.add_child(progress)
	progress.size = Vector2(1220, 3)
	hint = text("FOLLOW THE CYAN RINGS", Vector2(0, 157), 18, Color.WHITE)
	hint.size.x = 1280
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel(Vector2(285, 653), Vector2(710, 42))
	var controls := text("WASD  MOVE     SPACE  DOUBLE JUMP     SHIFT  DASH     R  RESTART     ESC  PAUSE", Vector2(300, 665), 12, Color("bfcee0"))
	controls.size.x = 680
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text("01 / SKYLINE CIRCUIT", Vector2(30, 676), 11, Color("8ba3c7"))
	text("GODOT 4  /  PROTOTYPE", Vector2(1085, 676), 11, Color("8ba3c7"))
	overlay = panel(Vector2(400, 235), Vector2(480, 270))
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_title = text("PAUSED", Vector2(430, 263), 34, Color.WHITE)
	overlay_body = text("Take a breath. The sky can wait.", Vector2(430, 315), 16, Color("bfcee0"))
	var resume := button("CONTINUE", Vector2(430, 362), func(): resume_requested.emit())
	resume.name = "Continue"
	button("RESTART RUN", Vector2(646, 362), func(): restart_requested.emit())
	var toggle := CheckButton.new()
	toggle.text = "Reduced motion"
	toggle.position = Vector2(430, 426)
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.toggled.connect(func(value): motion_changed.emit(value))
	root.add_child(toggle)
	# Overlay children use a separate group so they can all hide together.
	for child in root.get_children():
		if child == overlay or child.position.y >= 235 and child.position.y <= 470:
			child.add_to_group("pause_ui")
	show_overlay(false)

func _unhandled_input(event: InputEvent) -> void:
	# Input must remain active even while the gameplay tree is paused.
	if event.is_action_pressed("restart"):
		restart_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_run"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()

func style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 9
	s.corner_radius_top_right = 9
	s.corner_radius_bottom_left = 9
	s.corner_radius_bottom_right = 9
	return s

func panel(pos: Vector2, dimensions: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = dimensions
	p.add_theme_stylebox_override("panel", style(Color(0.025, 0.055, 0.12, 0.9)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	return p

func text(content: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label

func button(content: String, pos: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = content
	b.position = pos
	b.size = Vector2(200, 44)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_stylebox_override("normal", style(CYAN))
	b.add_theme_stylebox_override("hover", style(Color.WHITE))
	b.pressed.connect(action)
	root.add_child(b)
	return b

func update_run(seconds: float, count: int, total: int, ready: bool) -> void:
	timer_label.text = "%05.2f" % seconds
	rings_label.text = "RINGS   %d / %d" % [count, total]
	energy_label.text = "DASH READY  /  SHIFT" if ready else "DASH EMPTY  /  LAND OR HIT A RING"
	energy_label.modulate = CYAN if ready else Color("ffb584")
	progress.value = float(count) / maxf(1, total) * 100

func show_overlay(shown: bool, completed := false, seconds := 0.0) -> void:
	for node in get_tree().get_nodes_in_group("pause_ui"):
		node.visible = shown
	overlay_title.text = "CIRCUIT COMPLETE" if completed else "PAUSED"
	overlay_title.add_theme_font_size_override("font_size", 28 if completed else 34)
	overlay_body.text = "%.2f seconds. One more run?" % seconds if completed else "Take a breath. The sky can wait."
	root.get_node("Continue").disabled = completed
