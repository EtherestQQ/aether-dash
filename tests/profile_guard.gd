extends RefCounted
## Preserve the human player's record when tests call the real finish path.
const PATH := "user://aether_dash.cfg"
var existed := false
var contents := PackedByteArray()

func capture() -> void:
	existed = FileAccess.file_exists(PATH)
	if existed:
		contents = FileAccess.get_file_as_bytes(PATH)

func restore() -> void:
	if existed:
		var file := FileAccess.open(PATH, FileAccess.WRITE)
		file.store_buffer(contents)
	elif FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
