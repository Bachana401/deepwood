extends RefCounted
# COUNTERING THE NIGHT, for the village's read-only presence layers.
#
# main.tscn's CanvasModulate multiplies EVERY CanvasItem in the world by the
# hour's colour, and at midnight that colour is (0.16, 0.18, 0.34). A ward light
# drawn in full green (0.42, 0.98, 0.62) therefore lands on screen at
# (0.07, 0.18, 0.21) -- about a fifth of the brightness it was drawn at, on a
# screen that is already dark. That is the whole reason the aura pools were
# invisible in play, and no amount of raising their alpha could have fixed it:
# alpha only interpolates toward a colour the modulate is about to crush anyway.
#
# day_night_cycle.gd already solved this once, for the moon: divide the colour by
# the canvas colour BEFORE drawing, and the engine's multiply puts it back where
# you wanted it. This is that trick, packaged for the presence layers.
#
# ⚠ THE RULE FOR WHEN TO USE IT: lift things that EMIT (a ward light, a lantern
# flame, a burning sigil, the letters on a lit sign). Never lift things that
# merely EXIST -- stone, wood, earth, cloth, a crate. A village that gets dark at
# night is correct; a ward that goes out at night is a lie about the rules.

# The hour's canvas colour, or white if the scene has no CanvasModulate (the
# arena and tool harnesses do not).
static func canvas(node: CanvasItem) -> Color:
	var t: SceneTree = node.get_tree()
	if t == null:
		return Color(1, 1, 1, 1)
	var scene: Node = t.current_scene
	if scene == null:
		return Color(1, 1, 1, 1)
	var cm: Node = scene.get_node_or_null("CanvasModulate")
	if cm != null and cm is CanvasModulate:
		return (cm as CanvasModulate).color
	return Color(1, 1, 1, 1)

# `c` pre-divided by the canvas colour, so it survives the multiply. Per channel,
# because the night tint is blue and a single scalar would shift every ward light
# blue with it. `amount` blends between the raw colour (0.0) and the fully
# restored one (1.0); the cap keeps a black canvas from producing infinities.
static func lift(c: Color, m: Color, amount: float = 1.0) -> Color:
	return Color(
		c.r * lerpf(1.0, minf(1.0 / maxf(m.r, 0.06), 6.0), amount),
		c.g * lerpf(1.0, minf(1.0 / maxf(m.g, 0.06), 6.0), amount),
		c.b * lerpf(1.0, minf(1.0 / maxf(m.b, 0.06), 6.0), amount),
		c.a)
