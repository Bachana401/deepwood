class_name EnemySkins
extends RefCounted

# Shared builder for downloaded-spritesheet skins (CraftPix Tiny RPG packs in
# art/enemies/<skin>/). Each strip is one row of 100x100 frames; frame counts
# are read from the texture width so nothing is hardcoded per character. Used by
# both dungeon enemies (enemy.gd) and village Barracks soldiers (siege_enemy.gd,
# faction "village"). SpriteFrames are built once per skin and shared.

const FRAME_SIZE := 100
const ANIMS := {
	"idle":   {"file": "idle.png",   "fps": 8.0,  "loop": true},
	"walk":   {"file": "walk.png",   "fps": 12.0, "loop": true},
	"attack": {"file": "attack.png", "fps": 12.0, "loop": false},
	"hurt":   {"file": "hurt.png",   "fps": 14.0, "loop": false},
	"death":  {"file": "death.png",  "fps": 10.0, "loop": false},
}

static var _cache := {}

static func frames_for(skin: String) -> SpriteFrames:
	if _cache.has(skin):
		return _cache[skin]
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim in ANIMS:
		var info: Dictionary = ANIMS[anim]
		sf.add_animation(anim)
		sf.set_animation_loop(anim, info["loop"])
		sf.set_animation_speed(anim, info["fps"])
		var tex: Texture2D = load("res://art/enemies/%s/%s" % [skin, info["file"]])
		if tex == null:
			continue
		var count: int = maxi(1, int(tex.get_width() / FRAME_SIZE))
		var h: int = tex.get_height()
		for i in range(count):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, h)
			sf.add_frame(anim, at)
	_cache[skin] = sf
	return sf
