extends Node

# Every yard trade used to run the SAME hammer-rock with a different chip
# colour -- the farmer, the sawyer and the soldier were all miming the smith.
# These checks pin the thing that actually matters: two different crafts must
# not be playing the same animation, and a craft with no art must still fall
# back rather than break.

var fails := 0

func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		printerr("PASS  ", name)
	else:
		fails += 1
		printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused:
			break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"):
				n.finish(); break

	var WF = load("res://worker_figure.gd")
	var host := Node2D.new()
	get_tree().root.add_child(host)

	# --- a craft with drawn art performs THAT craft ---
	var played := {}
	for craft in ["smith", "saw", "hoe"]:
		var f = WF.new()
		f.mode = "anvil"
		f.craft = craft
		f.spot = Vector2.ZERO
		host.add_child(f)
		await get_tree().process_frame
		check("%s: worker is skinned" % craft, f.skin_sprite != null)
		check("%s: performs its OWN drawn craft" % craft, f._plays_craft(),
			"skin=%s anim=%s" % [f.skin_sprite.sprite_frames if f.skin_sprite else "-", f.craft])
		if f._plays_craft():
			played[craft] = f.skin_sprite.animation
			check("%s: plays the '%s' animation (not the generic rock)" % [craft, craft],
				f.skin_sprite.animation == craft, "playing '%s'" % f.skin_sprite.animation)
			check("%s: no pasted-on ColorRect arm" % craft, f.arm == null)

	# --- THE POINT: the crafts are not all the same motion ---
	var distinct := {}
	for c in played:
		distinct[played[c]] = true
	check("the trades play DIFFERENT animations (%d crafts -> %d distinct)"
		% [played.size(), distinct.size()],
		played.size() >= 3 and distinct.size() == played.size(), str(played))

	# --- a craft with NO art must fall back, not break ---
	var g = WF.new()
	g.mode = "anvil"
	g.craft = "grind"          # no art drawn for this yet
	g.spot = Vector2.ZERO
	host.add_child(g)
	await get_tree().process_frame
	check("craft with no art still builds a worker", g.skin_sprite != null or g.arm != null)
	check("craft with no art falls back (doesn't claim to perform it)", not g._plays_craft())
	var rocked := false
	var r0: float = g.skin_sprite.rotation if g.skin_sprite else 0.0
	for i in range(60):
		await get_tree().physics_frame
		if g.skin_sprite and absf(g.skin_sprite.rotation - r0) > 0.01:
			rocked = true
			break
	check("...and still visibly works (falls back to the rock)", rocked)

	# --- a drawn craft must NOT also be rocked on top of its own animation ---
	var s = WF.new()
	s.mode = "anvil"
	s.craft = "smith"
	s.spot = Vector2.ZERO
	host.add_child(s)
	await get_tree().process_frame
	for i in range(30):
		await get_tree().physics_frame
	check("a drawn craft isn't double-animated (no rock on top)",
		s.skin_sprite != null and absf(s.skin_sprite.rotation) < 0.001,
		"rotation %.3f" % (s.skin_sprite.rotation if s.skin_sprite else 0.0))

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
