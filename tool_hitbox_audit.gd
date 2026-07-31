extends Node

# THE HITBOX AUDIT (2026-07-30).
#
# "projectiles all parts should deal damage, some parts deal some don't."
#
# The collision box defaults to Vector2(36, 20) NO MATTER HOW BIG a projectile
# is drawn. The Crown's Sorrow painted a bundle 158px long and damaged in the
# middle 36 of it -- four fifths of what the player could see was decoration.
# I fixed that by hand-listing twelve kinds in DRAWN_HITBOX, which is fine for
# twelve and useless for the ~146 _build_ functions in the file: the same bug
# is certainly hiding in others and I would be guessing at which.
#
# So MEASURE it. Instantiate every kind the roster actually uses, walk the
# visual it builds, take the bounding box of every Polygon2D and Line2D in it,
# and hold that against the collision shape. Anything drawn much larger than it
# can hit is a weapon lying to the player about its own reach.
#
# This is a survey, not a gate -- it always exits 0. Some overhang is correct:
# a bloom, a glow, a trail SHOULD spill past the hitbox. What matters is the
# ratio and the list, read by someone who knows which is which.

const PROJ := preload("res://weapon_projectile.gd")

func say(t: String) -> void: printerr(t)

# THE BODY, NOT THE HALO. The first run of this measured every drawn node and
# came back with a wall of kinds "drawn 6x their hitbox" -- at suspiciously
# identical sizes, 156x152 and 124x121 over and over. That was _enrich_visual's
# BLOOM, which it adds to nearly everything, and a bloom is supposed to spill
# past the hitbox. A glow that reached only as far as the damage would look
# like a sticker.
#
# So skip the light and measure the solid: anything additive, and anything
# faint enough to read as atmosphere rather than as the weapon.
func _is_glow(n: Node) -> bool:
	var ci := n as CanvasItem
	if ci == null:
		return false
	if ci.modulate.a < 0.5:
		return true
	var m := ci.material as CanvasItemMaterial
	if m != null and m.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
		return true
	if n is Polygon2D and (n as Polygon2D).color.a < 0.55:
		return true
	if n is Line2D and (n as Line2D).default_color.a < 0.55:
		return true
	return false

func _bounds_of(n: Node, acc: Rect2, first: bool) -> Array:
	var r := acc
	var got := not first
	if _is_glow(n):
		# its children are part of the same glow -- do not descend
		return [r, got]
	if n is Polygon2D:
		var poly: PackedVector2Array = (n as Polygon2D).polygon
		for p in poly:
			var wp: Vector2 = (n as Node2D).position + p * (n as Node2D).scale
			if not got:
				r = Rect2(wp, Vector2.ZERO)
				got = true
			else:
				r = r.expand(wp)
	elif n is Line2D:
		for p in (n as Line2D).points:
			var wp2: Vector2 = (n as Node2D).position + p * (n as Node2D).scale
			if not got:
				r = Rect2(wp2, Vector2.ZERO)
				got = true
			else:
				r = r.expand(wp2)
	for c in n.get_children():
		var res := _bounds_of(c, r, not got)
		r = res[0]
		got = got or res[1]
	return [r, got]

func _ready() -> void:
	await get_tree().process_frame

	# every kind the ROSTER actually produces -- not every case label, since a
	# kind no weapon reaches is tool_deadverb_audit's problem, not this one
	var kinds := {}
	for row in WeaponRoster.ROWS:
		var def: Dictionary = WeaponRoster.get_def(str(row[0]))
		if def.is_empty():
			continue
		var t := str(def.get("special", {}).get("type", ""))
		if t != "":
			kinds[t] = str(def.get("name", row[0]))

	say("\n=== HITBOX vs PICTURE: %d kinds ===" % kinds.size())
	var rows := []
	for k in kinds:
		var pr = PROJ.new()
		pr.kind = k
		pr.direction = Vector2.RIGHT
		pr.damage = 10
		pr.speed = 400.0
		pr.max_distance = 300.0
		add_child(pr)
		await get_tree().process_frame
		var box := Vector2.ZERO
		for c in pr.get_children():
			if c is CollisionShape2D and (c as CollisionShape2D).shape is RectangleShape2D:
				box = ((c as CollisionShape2D).shape as RectangleShape2D).size
		var drawn := Rect2()
		if pr.visual != null and is_instance_valid(pr.visual):
			var res := _bounds_of(pr.visual, Rect2(), true)
			drawn = res[0]
		pr.queue_free()
		await get_tree().process_frame
		if box == Vector2.ZERO or drawn.size == Vector2.ZERO:
			continue
		var rx: float = drawn.size.x / maxf(1.0, box.x)
		var ry: float = drawn.size.y / maxf(1.0, box.y)
		rows.append([maxf(rx, ry), k, str(kinds[k]), drawn.size, box])

	rows.sort_custom(func(a, b): return a[0] > b[0])
	say("  %-9s %-18s %-24s %-16s %s" % ["ratio", "kind", "a weapon using it", "drawn", "hitbox"])
	for r in rows:
		var flag := ""
		if float(r[0]) >= 3.0:
			flag = "  <-- DRAWN MUCH LARGER THAN IT HITS"
		elif float(r[0]) >= 2.0:
			flag = "  <-- check"
		say("  %-9.1f %-18s %-24s %-16s %s%s" % [r[0], r[1], r[2],
			"%.0fx%.0f" % [r[3].x, r[3].y], "%.0fx%.0f" % [r[4].x, r[4].y], flag])

	var bad := 0
	for r in rows:
		if float(r[0]) >= 3.0:
			bad += 1
	say("\n=== %d kinds measured | %d drawn 3x their hitbox or worse ===" % [rows.size(), bad])
	say("(some overhang is CORRECT -- a bloom, a glow and a trail should spill.")
	say(" the list is for a human to read, not a number to drive to zero.)")
	get_tree().quit(0)
