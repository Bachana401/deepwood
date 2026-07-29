extends Node
# Touch-layer QC probe: boots the real game windowed (run WITHOUT --headless),
# waits for the world to settle, saves ONE full-viewport screenshot (the touch
# overlay renders on CanvasLayer 90 and must be visible in it), then quits.
#
#   DEEPWOOD_TOUCH=1 MONARCH_TEST="res://mobile/tool_touch_shot.gd" Godot.exe --path .
#   TOUCH_SHOT=<abs path.png> overrides the output location.

func _ready() -> void:
	for i in range(120):
		await get_tree().process_frame
	printerr("my viewport=", get_viewport(), "  root=", get_tree().root)
	for c in get_tree().root.get_children():
		var extra := " layer=%d visible=%s" % [c.layer, c.visible] if c is CanvasLayer else ""
		printerr("  root child: ", c.name, " (", c.get_class(), ")", extra)
	var img := get_viewport().get_texture().get_image()
	var p := OS.get_environment("TOUCH_SHOT")
	if p == "":
		p = "user://touch_shot.png"
	img.save_png(p)
	printerr("touch shot saved: ", p, "  overlay_active=", TouchControls.active,
		"  buttons=", TouchControls._buttons.size())
	get_tree().quit(0)
