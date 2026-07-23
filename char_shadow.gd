extends RefCounted
# Preloaded as a const by its users (const CHAR_SHADOW = preload(...)) rather than
# referenced by a global class_name, so it resolves in headless test runs that
# don't re-import the project.

# A small, soft shadow blot planted under a character so it reads as standing ON
# the ground, not floating (dev: "create shadows... so the game feels smoother").
# Extracted from player.gd so enemies, villagers and the rest can share the exact
# same grounding shadow. Cheap + static: one tinted radial sprite, no light.
#
# `feet_y` is the character's LOCAL ground line (where its feet meet the floor):
#   player 24, enemy SPRITE_GROUND_Y (20), villager 18*body_scale. Like the
# player's, the shadow rides with the body when it hops -- consistent everywhere.

static var _tex: GradientTexture2D = null

static func _shadow_tex() -> GradientTexture2D:
	if _tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.28, 0.6, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.82), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0)])
		_tex = GradientTexture2D.new()
		_tex.gradient = g
		_tex.width = 128
		_tex.height = 128
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)
	return _tex

# Attach a shadow to `host` (skips if it already has one). `width` scales the
# blot (0.5 ~ a human-sized character); `feet_y` is the local ground line.
static func attach(host: Node2D, width: float, feet_y: float = 24.0) -> void:
	if host == null or host.has_node("CharShadow"):
		return
	var sh := Sprite2D.new()
	sh.name = "CharShadow"
	sh.texture = _shadow_tex()
	sh.modulate = Color(0, 0, 0, 0.30)
	sh.scale = Vector2(width, width * 0.32)      # flattened to the ground plane
	sh.position = Vector2(0, feet_y)
	sh.z_index = -4                              # under the body, over the floor
	sh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	host.add_child(sh)
