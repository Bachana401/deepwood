class_name EnemySkins
extends RefCounted

# Shared skin builder for downloaded/generated character art. Originally for
# dungeon enemies (enemy.gd), village soldiers/raiders and corruption demons
# (siege_enemy.gd); now also serves villagers (npc.gd) and any other character
# via the optional `root` arg. A skin lives in <root><skin>/ (root defaults to
# res://art/enemies/) and may be EITHER format:
#   - CraftPix STRIP:  <anim>.png  = one horizontal row of FRAME_SIZE(100) frames
#   - PixelLab FRAMES: <anim>_1.png, <anim>_2.png, ...  = one PNG per frame
# frames_for() auto-detects. Heights differ between packs, so content_height()/
# feet_px() measure the actual character pixels from the idle frame -- bodies use
# those to normalise every skin to a consistent on-screen size and plant its feet.
# SpriteFrames + measurements are cached per (root+skin).

const FRAME_SIZE := 100    # CraftPix strip slice width
# On-screen character height (px) that PixelLab per-frame ENEMY skins normalise
# to, so every generated enemy reads at a consistent, slightly-imposing size vs
# the ~56px player. (CraftPix strip skins keep their own fixed scale until
# replaced. Non-enemy callers -- villagers -- pass their own target height.)
const TARGET_HEIGHT := 72.0
const DEFAULT_ROOT := "res://art/enemies/"

static func _dir(root: String, skin: String) -> String:
	return root + skin + "/"

# True if this skin ships as PixelLab per-frame PNGs (idle_1.png ...) rather than
# a CraftPix strip.
static func is_per_frame(skin: String, root: String = DEFAULT_ROOT) -> bool:
	return ResourceLoader.exists(_dir(root, skin) + "idle_1.png")

const ANIMS := {
	"idle":   {"fps": 8.0,  "loop": true},
	"walk":   {"fps": 12.0, "loop": true},
	"attack": {"fps": 12.0, "loop": false},
	"hurt":   {"fps": 14.0, "loop": false},
	"death":  {"fps": 10.0, "loop": false},
	# optional bespoke POWER clips (finale wizard: one per ability family);
	# skins without these files simply skip them
	"beam":     {"fps": 10.0, "loop": false},
	"summon":   {"fps": 10.0, "loop": false},
	"curse":    {"fps": 10.0, "loop": false},
	"teleport": {"fps": 12.0, "loop": false},
}

static var _cache := {}
static var _bounds_cache := {}

# The frame textures for one animation, in order. Per-frame PixelLab folders win;
# otherwise a CraftPix strip is sliced into FRAME_SIZE-wide regions.
static func _anim_frames(skin: String, anim: String, root: String = DEFAULT_ROOT) -> Array:
	var out: Array = []
	var base := _dir(root, skin)
	var i := 1
	while true:
		var p := base + "%s_%d.png" % [anim, i]
		if not ResourceLoader.exists(p):
			break
		var t: Texture2D = load(p)
		if t == null:
			break
		out.append(t)
		i += 1
	if not out.is_empty():
		return out
	# strip fallback
	var sp := base + anim + ".png"
	if not ResourceLoader.exists(sp):
		return out
	var tex: Texture2D = load(sp)
	if tex == null:
		return out
	var count: int = maxi(1, int(tex.get_width() / FRAME_SIZE))
	var h: int = tex.get_height()
	for k in range(count):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(k * FRAME_SIZE, 0, FRAME_SIZE, h)
		out.append(at)
	return out

static func frames_for(skin: String, root: String = DEFAULT_ROOT) -> SpriteFrames:
	var key := root + skin
	if _cache.has(key):
		return _cache[key]
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim in ANIMS:
		var frames := _anim_frames(skin, anim, root)
		if frames.is_empty():
			continue
		var info: Dictionary = ANIMS[anim]
		sf.add_animation(anim)
		sf.set_animation_loop(anim, info["loop"])
		sf.set_animation_speed(anim, info["fps"])
		for t in frames:
			sf.add_frame(anim, t)
	_cache[key] = sf
	return sf

# Content bounding box of the FIRST idle frame, measured from the raw source
# image (NOT AtlasTexture.get_image, which misreads strip regions): {frame_h,
# top, bottom, height}. For a CraftPix strip only the first FRAME_SIZE columns
# are scanned; for a PixelLab per-frame PNG the whole image is scanned.
static func idle_bounds(skin: String, root: String = DEFAULT_ROOT) -> Dictionary:
	var key := root + skin
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var base := _dir(root, skin)
	var res := {"frame_h": float(FRAME_SIZE), "frame_w": float(FRAME_SIZE), "top": 0.0, "bottom": float(FRAME_SIZE - 1), "height": float(FRAME_SIZE), "foot_cx": float(FRAME_SIZE) / 2.0}
	# Scan the FULL image (per-frame PNG = one frame; strip = every frame at once).
	# Scanning all frames unions the poses, so a compressed idle breath-frame
	# doesn't undercount the character's true standing height.
	var img: Image = null
	var pf := base + "idle_1.png"
	if ResourceLoader.exists(pf):
		var t: Texture2D = load(pf)
		if t != null:
			img = t.get_image()
	else:
		var sp := base + "idle.png"
		if ResourceLoader.exists(sp):
			var t2: Texture2D = load(sp)
			if t2 != null:
				img = t2.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		var top := -1
		var bot := -1
		var row_minx := PackedInt32Array()
		var row_maxx := PackedInt32Array()
		row_minx.resize(h)
		row_maxx.resize(h)
		for y in range(h):
			var rmin := -1
			var rmax := -1
			for x in range(w):
				if img.get_pixel(x, y).a > 0.15:
					if rmin < 0:
						rmin = x
					rmax = x
			row_minx[y] = rmin
			row_maxx[y] = rmax
			if rmax >= 0:
				if top < 0:
					top = y
				bot = y
		if top >= 0:
			# Horizontal centre of the FEET band (bottom ~18% of the body), so a
			# character anchors on where it STANDS -- a raised weapon or an
			# outstretched arm no longer drags its centre sideways.
			var band := maxi(2, int(round((bot - top + 1) * 0.18)))
			var fmin := w
			var fmax := -1
			for y in range(maxi(top, bot - band + 1), bot + 1):
				if row_maxx[y] >= 0:
					fmin = mini(fmin, row_minx[y])
					fmax = maxi(fmax, row_maxx[y])
			var foot_cx := (float(fmin) + float(fmax)) / 2.0 if fmax >= 0 else float(w) / 2.0
			res = {"frame_h": float(h), "frame_w": float(w), "top": float(top), "bottom": float(bot), "height": float(bot - top + 1), "foot_cx": foot_cx}
	_bounds_cache[key] = res
	return res

# Lowest visible pixel of the idle frame, relative to the frame CENTRE (positive =
# below centre) -- used to plant feet exactly on a body's ground line.
static func feet_px(skin: String, root: String = DEFAULT_ROOT) -> float:
	var b := idle_bounds(skin, root)
	return b["bottom"] - b["frame_h"] / 2.0

# Visible character height in pixels (for normalising every skin to one size).
static func content_height(skin: String, root: String = DEFAULT_ROOT) -> float:
	return maxf(1.0, idle_bounds(skin, root)["height"])

# Horizontal offset (texture px) of the character's standing centre from the
# frame centre. Feed the NEGATIVE of this into a sprite's offset.x so it stands
# centred on its node (health bar / hitbox / shadow) instead of drifting sideways.
static func hcenter_px(skin: String, root: String = DEFAULT_ROOT) -> float:
	var b := idle_bounds(skin, root)
	return b["foot_cx"] - b["frame_w"] / 2.0
