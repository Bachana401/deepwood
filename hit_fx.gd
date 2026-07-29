class_name HitFx
extends RefCounted

# ELEMENT IMPACT BURSTS (item-art VFX pass 2026-07-28, Terraria-hit-spark
# INSPIRED, never copied). One shared primitive: every landed blow pops a
# crisp little burst in the WEAPON'S ELEMENT colour -- fire hits flash
# orange shards, ice hits flash pale-blue, plain steel sparks white. Reads
# instantly, dies fast (0.2s), all additive so it glows without lighting.
#
# Call HitFx.burst(parent, world_pos, element, crit) from any hit path.
# `element` is an Inventory.ELEMENTS key (resolve via Inventory.element_of);
# crits burst half again bigger with a ring so they FEEL like crits.

static func burst(parent: Node, world_pos: Vector2, element: String, crit := false) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var fx: Dictionary = Inventory.element_fx(element)
	var tint: Color = fx.get("tint", Color(0.9, 0.92, 0.98))
	var glow: Color = fx.get("glow", tint)
	var root := Node2D.new()
	root.z_index = 40
	parent.add_child(root)
	root.global_position = world_pos
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var scale_up := 1.5 if crit else 1.0
	# the shards: six thin kites thrown outward from the point of impact
	var n := 6
	for i in range(n):
		var a := TAU * float(i) / float(n) + randf_range(-0.25, 0.25)
		var dir := Vector2(cos(a), sin(a))
		var length := randf_range(9.0, 15.0) * scale_up
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2.ZERO, dir.rotated(0.35) * length * 0.35,
			dir * length, dir.rotated(-0.35) * length * 0.35])
		shard.color = Color(tint.r, tint.g, tint.b, 0.95)
		shard.material = mat
		root.add_child(shard)
	# the core flash: a small bright diamond of the glow colour
	var core := Polygon2D.new()
	var c := 5.0 * scale_up
	core.polygon = PackedVector2Array([Vector2(-c, 0), Vector2(0, -c), Vector2(c, 0), Vector2(0, c)])
	core.color = Color(glow.r, glow.g, glow.b, 1.0)
	core.material = mat
	root.add_child(core)
	# crits earn a ring that snaps outward -- the eye reads "that one mattered"
	if crit:
		var ring := Line2D.new()
		var rp := PackedVector2Array()
		for i in range(17):
			var a2 := TAU * float(i) / 16.0
			rp.append(Vector2(cos(a2), sin(a2)) * 7.0)
		ring.points = rp
		ring.width = 2.5
		ring.default_color = Color(glow.r, glow.g, glow.b, 0.9)
		ring.material = mat
		root.add_child(ring)
		var rt := ring.create_tween()
		rt.tween_property(ring, "scale", Vector2.ONE * 3.2, 0.2).set_ease(Tween.EASE_OUT)
	# one tween owns the whole burst: pop out, fade, free
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "scale", Vector2.ONE * 1.35, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "modulate:a", 0.0, 0.22)
	tw.set_parallel(false)
	tw.tween_callback(root.queue_free)
