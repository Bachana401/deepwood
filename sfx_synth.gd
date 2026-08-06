class_name SfxSynth
extends RefCounted

# PROCEDURAL CHIPTUNE ONE-SHOTS (audio pass 2026-07-28): the overhaul's
# mechanics shipped visually loud and half-SILENT -- storm strikes, the ward
# pop, the flail hurl, ricochet pings, the pillar's counter-arc. Rather than
# shipping more wav files, tiny PCM buffers are synthesized ONCE per recipe,
# cached, and played through self-freeing AudioStreamPlayer2D nodes so every
# effect sounds from WHERE it happens. Chip-style by design: it matches the
# pixel look the way the procedural polygons do.

const RATE := 22050
static var _cache: Dictionary = {}

# Names already complained about, so a bad recipe scolds once and not once per
# swing. (The `_cache` short-circuit in `_bank()` would mostly do this on its
# own; this holds the line even if something clears the cache mid-run.)
static var _unknown_seen: Dictionary = {}

# --- THE VILLAGE SET (audio pass 2026-08-06) ---
# Everything the town grew this month -- patrols walking into the deep, the
# sickness, fire, and the eclipse -- shipped with a toast and no sound at all.
# These are the recipe keys for it. Recipes are still addressed as bare strings
# everywhere else ("crack", "chime"); the constants exist because these eight
# are called from ONE file by a different department, and a mistyped string
# does not fail loudly -- it falls through `_:` and plays 50ms of silence.
const SFX_PATROL_OUT: String = "patrol_out"
const SFX_PATROL_HOME: String = "patrol_home"
const SFX_PATROL_FIND: String = "patrol_find"
const SFX_PATROL_LOST: String = "patrol_lost"
const SFX_OUTBREAK: String = "outbreak"
const SFX_FIRE_ALARM: String = "fire_alarm"
const SFX_FIRE_DOUSED: String = "fire_doused"
const SFX_ECLIPSE: String = "eclipse"

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	s.data = bytes
	return s

# --- three shop tools, so the longer recipes below stay readable ---
# Same vocabulary as the six originals (sine, noise, a power envelope); the
# square is the one addition, and only because a horn and an alarm bell have to
# CUT and a pure sine only hums.
static func _sq(cycles: float, duty: float = 0.5) -> float:
	return 1.0 if fposmod(cycles, 1.0) < duty else -1.0

# Mix one decaying note into a buffer at a given second. Every note starts its
# own phase at zero and ramps in over 4ms, which is what keeps a melody free of
# the clicks a mid-buffer frequency change would otherwise leave behind.
# Returns the buffer so the call site reads as `out = _add_tone(out, ...)` and
# stays correct whichever way the engine passes a packed array.
static func _add_tone(buf: PackedFloat32Array, at_sec: float, hz: float, dur: float,
		amp: float, decay: float, sq_mix: float = 0.0) -> PackedFloat32Array:
	var start: int = int(float(RATE) * at_sec)
	var ln: int = maxi(1, int(float(RATE) * dur))
	var atk: float = float(RATE) * 0.004
	for j in range(ln):
		var k: int = start + j
		if k < 0 or k >= buf.size():
			continue
		var ct: float = float(j) / float(ln)
		var e: float = pow(maxf(0.0, 1.0 - ct), decay) * minf(1.0, float(j) / atk)
		var cyc: float = hz * (float(j) / float(RATE))
		buf[k] += (sin(TAU * cyc) * (1.0 - sq_mix) + _sq(cyc) * sq_mix) * e * amp
	return buf

# Peak-normalize. The village recipes stack five or six voices; scaling once at
# the end beats hand-tuning every gain against the ±1.0 clamp in _wav().
static func _norm(buf: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var hi: float = 0.0
	for i in range(buf.size()):
		hi = maxf(hi, absf(buf[i]))
	if hi <= 0.0001:
		return buf
	var g: float = peak / hi
	for i in range(buf.size()):
		buf[i] = buf[i] * g
	return buf

# THE ROSTER -- every name `_bank()` below actually answers to, in one place a
# caller can read back. A recipe is a bare string at ~45 call sites and nothing
# in GDScript checks one: a typo does not fail, it falls through to `_:` and
# plays 50ms of silence, so the sound simply never happens and nothing anywhere
# says so. It is not theoretical -- "thud" was written for "thump" on the
# brazier throne and on the Anvil of Endings, and both landed mute.
# Keep this list and the `match` below in step; QA can walk one against the
# other so a recipe cannot be added in only one of the two places.
const RECIPES: Array = [
	"crack", "pop", "thump", "whoosh", "chime", "tear",
	"patrol_out", "patrol_home", "patrol_find", "patrol_lost",
	"outbreak", "fire_alarm", "fire_doused", "eclipse",
]

static func has_recipe(recipe: String) -> bool:
	return RECIPES.has(recipe)

# NOTE: must NOT be named `_get` -- that's Object's reserved property virtual
# (_get(StringName) -> Variant); the signature clash fails the whole script's
# compile, which silently turns every SfxSynth.play_at() into a "nonexistent
# function" (audio-pass fix 2026-07-28).
static func _bank(recipe: String) -> AudioStreamWAV:
	if _cache.has(recipe):
		return _cache[recipe]
	var out := PackedFloat32Array()
	var n := 0
	match recipe:
		"crack":
			# lightning: a hard noise burst, gone in a blink
			n = int(RATE * 0.16)
			out.resize(n)
			for i in range(n):
				var t := float(i) / float(n)
				out[i] = (randf() * 2.0 - 1.0) * pow(1.0 - t, 3.0) * 0.9
		"pop":
			# a soft bubble: a pitched blip inside a puff of noise
			n = int(RATE * 0.12)
			out.resize(n)
			for i in range(n):
				var t := float(i) / float(n)
				var env := pow(1.0 - t, 2.0)
				out[i] = (sin(TAU * 620.0 * (float(i) / RATE)) * 0.5 \
					+ (randf() * 2.0 - 1.0) * 0.25) * env * 0.7
		"thump":
			# the earth answering: a low sine with a click of onset
			n = int(RATE * 0.22)
			out.resize(n)
			for i in range(n):
				var t := float(i) / float(n)
				var env := pow(1.0 - t, 2.2)
				var f := 82.0 - 30.0 * t   # the pitch falls as it lands
				out[i] = (sin(TAU * f * (float(i) / RATE)) * 0.9 \
					+ ((randf() * 2.0 - 1.0) * 0.3 if i < RATE / 200 else 0.0)) * env
		"whoosh":
			# air torn open: noise that swells and lets go
			n = int(RATE * 0.3)
			out.resize(n)
			for i in range(n):
				var t := float(i) / float(n)
				var env := sin(PI * pow(t, 0.7)) * 0.55
				out[i] = (randf() * 2.0 - 1.0) * env
		"chime":
			# the stopping word: a cold bell with one high harmonic
			n = int(RATE * 0.35)
			out.resize(n)
			for i in range(n):
				var t := float(i) / float(n)
				var env := pow(1.0 - t, 1.6)
				var ph := float(i) / RATE
				out[i] = (sin(TAU * 1320.0 * ph) * 0.5 + sin(TAU * 1980.0 * ph) * 0.2) * env * 0.7
		"tear":
			# dark cloth ripping: noise whose body slides downward
			n = int(RATE * 0.25)
			out.resize(n)
			for i in range(n):
				var t := float(i) / float(n)
				var env := pow(1.0 - t, 1.4)
				var f := 240.0 - 160.0 * t
				out[i] = ((randf() * 2.0 - 1.0) * 0.5 \
					+ sin(TAU * f * (float(i) / RATE)) * 0.35) * env * 0.8
		# ================= THE VILLAGE SET (2026-08-06) =================
		"patrol_out":
			# THE GATE OPENS. Four boot-falls at a march tempo, under a horn
			# that climbs a fourth and STOPS there. A fourth left hanging is
			# an order given and not yet answered -- departure with purpose,
			# and the risk sitting in the interval that never resolves.
			n = int(RATE * 0.80)
			out.resize(n)
			for i in range(n):
				var ph: float = float(i) / float(RATE)
				var step: float = fposmod(ph, 0.17)
				var senv: float = pow(maxf(0.0, 1.0 - step / 0.13), 3.0)
				var boot: float = 0.0
				if ph < 0.70:      # past that the column is out of earshot
					boot = sin(TAU * 116.0 * step) * senv * 0.5 \
						+ (randf() * 2.0 - 1.0) * senv * senv * 0.12
				out[i] = boot
			out = _add_tone(out, 0.06, 220.00, 0.30, 0.30, 0.5, 0.35)
			out = _add_tone(out, 0.34, 293.33, 0.44, 0.32, 0.8, 0.35)
			out = _norm(out, 0.85)

		"patrol_home":
			# THE HAUL COMES UP. A purse tipped out -- nine bright coin ticks
			# -- over a two-note lift that climbs a fourth and SETTLES on it.
			# The relief half of the pair: they are back, that is the news,
			# and there is nothing rare in the sack.
			n = int(RATE * 0.62)
			out.resize(n)
			out = _add_tone(out, 0.00, 293.66, 0.22, 0.30, 1.0, 0.12)
			out = _add_tone(out, 0.16, 392.00, 0.46, 0.34, 1.4, 0.12)
			var purse: Array = [1046.5, 1244.5, 1396.9, 1568.0, 1864.7]
			for _c in range(9):
				out = _add_tone(out, randf_range(0.04, 0.44),
					float(purse[randi() % purse.size()]), 0.07, 0.26, 4.0)
			out = _norm(out, 0.80)

		"patrol_find":
			# THE FIND. Deliberately the same purse -- so the ear hears the
			# family -- except the lift does not stop at the fourth. It climbs
			# a whole major triad to an octave bell that rings on after the
			# coins have landed. That extra step IS the rarity.
			n = int(RATE * 1.00)
			out.resize(n)
			out = _add_tone(out, 0.00, 392.00, 0.14, 0.26, 1.6, 0.10)
			out = _add_tone(out, 0.09, 493.88, 0.14, 0.26, 1.6, 0.10)
			out = _add_tone(out, 0.18, 587.33, 0.16, 0.28, 1.6, 0.10)
			out = _add_tone(out, 0.27, 783.99, 0.70, 0.30, 1.3, 0.06)
			out = _add_tone(out, 0.27, 1567.98, 0.66, 0.10, 1.8)
			var shine: Array = [1568.0, 1864.7, 2093.0, 2349.3]
			for _c2 in range(7):
				out = _add_tone(out, randf_range(0.06, 0.50),
					float(shine[randi() % shine.size()]), 0.06, 0.22, 4.5)
			out = _norm(out, 0.85)

		"patrol_lost":
			# THEY DID NOT COME BACK. No noise in this one at all -- noise is
			# what makes a failure buzzer, and this is not a failure, it is a
			# loss. One dry far-off knock, then three notes walking DOWN to an
			# open fifth that never closes, over two detuned drones beating
			# slowly against each other like a room where nobody is speaking.
			n = int(RATE * 1.55)
			out.resize(n)
			for i in range(n):
				var ph2: float = float(i) / float(RATE)
				var t2: float = float(i) / float(n)
				var swell: float = minf(1.0, ph2 / 0.25) * pow(1.0 - t2, 1.1)
				out[i] = (sin(TAU * 130.81 * ph2) + sin(TAU * 131.72 * ph2)) * 0.07 * swell
			out = _add_tone(out, 0.00, 58.00, 0.36, 0.42, 2.6)
			out = _add_tone(out, 0.14, 392.00, 0.44, 0.28, 1.5)
			out = _add_tone(out, 0.46, 349.23, 0.46, 0.25, 1.5)
			out = _add_tone(out, 0.80, 261.63, 0.72, 0.29, 1.0)
			out = _norm(out, 0.72)

		"outbreak":
			# SOMETHING WRONG UNDER THE FLOOR. Two low tones a few hertz apart,
			# beating against each other about four times a second -- the
			# queasy interval, not a scary one -- with a slow breath of noise
			# moving beneath them, and one sour tritone surfacing halfway
			# through and sinking again. It CREEPS IN: the envelope has no
			# attack at all, which is what separates unease from alarm.
			n = int(RATE * 1.30)
			out.resize(n)
			for i in range(n):
				var ph3: float = float(i) / float(RATE)
				var t3: float = float(i) / float(n)
				var env3: float = minf(1.0, ph3 / 0.40) * pow(1.0 - t3, 1.1)
				var beat: float = sin(TAU * 96.0 * ph3) + sin(TAU * 99.7 * ph3)
				var breath: float = (randf() * 2.0 - 1.0) \
					* (0.35 + 0.35 * sin(TAU * 1.7 * ph3)) * 0.09
				out[i] = (beat * 0.18 + breath) * env3
			out = _add_tone(out, 0.42, 466.16, 0.55, 0.085, 1.8, 0.12)
			out = _add_tone(out, 0.42, 659.26, 0.55, 0.070, 1.8, 0.12)
			out = _norm(out, 0.70)

		"fire_alarm":
			# THE LOUDEST THING THE VILLAGE OWNS, and meant to be: fire jumps
			# to the next hall by morning, so this one has to move the player
			# NOW. A hand-bell swung in a tritone -- six strokes, square-edged
			# so it cuts -- over a roar and two dozen sparks. Normalized
			# hardest of the whole set on purpose.
			n = int(RATE * 0.95)
			out.resize(n)
			for i in range(n):
				var t4: float = float(i) / float(n)
				out[i] = (randf() * 2.0 - 1.0) * pow(1.0 - t4, 1.3) * 0.13
			for s in range(6):
				var hz4: float = 880.00 if s % 2 == 0 else 622.25
				out = _add_tone(out, 0.02 + 0.115 * float(s), hz4, 0.12, 0.34, 0.7, 0.65)
			for _c3 in range(24):
				out = _add_tone(out, randf_range(0.0, 0.90),
					randf_range(1400.0, 5200.0), 0.006, 0.22, 3.0)
			out = _norm(out, 0.95)

		"fire_doused":
			# THE BLAZE LETS GO. A hiss that falls away with the steam sliding
			# down under it, then one low note settling into the ash.
			# Resolution, not a fanfare -- the hall is still standing and that
			# is the whole of the good news.
			n = int(RATE * 0.80)
			out.resize(n)
			for i in range(n):
				var ph5: float = float(i) / float(RATE)
				var t5: float = float(i) / float(n)
				var env5: float = minf(1.0, ph5 / 0.03) * pow(1.0 - t5, 1.8)
				# 430Hz down to 100 -- written as the INTEGRAL of the linear
				# sweep so the phase stays continuous and the slide can't tick
				var steam: float = sin(TAU * (430.0 * ph5 - 206.25 * ph5 * ph5)) * 0.16
				out[i] = ((randf() * 2.0 - 1.0) * 0.34 + steam) * env5
			out = _add_tone(out, 0.44, 174.61, 0.34, 0.26, 1.6, 0.10)
			out = _norm(out, 0.78)

		"eclipse":
			# THE SUN GOES OUT. The longest one-shot in the game by four times
			# over, because a stinger can only say "something happened" and
			# this one has to say "it stopped".
			#   1. THE INTAKE (0.00-0.72) -- noise and a rising sweep coming up
			#      out of nothing. The world leaning toward the moment.
			#   2. THE TAKING (0.72) -- the bottom drops out: a sub falling
			#      110Hz -> 26Hz with the sky cracking open over it.
			#   3. THE DARK HOLDS (0.72-3.40) -- a TRITONE drone at 55/78Hz,
			#      lower than anything else in this file goes. A tritone is the
			#      interval that cannot resolve; HELD rather than struck, it
			#      stops sounding like an event and starts sounding like a
			#      condition. That is the whole trick of this recipe.
			#   4. THE RING (1.00-3.40) -- one thin high line, two voices 5Hz
			#      apart so it breathes, dead steady, and the LAST voice
			#      standing once the drone has gone. The hot red circle.
			# Three heartbeats underneath, each further from the last, are the
			# only thing in it still moving.
			n = int(RATE * 3.40)
			out.resize(n)
			var total: float = float(n) / float(RATE)
			var strike: float = 0.72
			for i in range(n):
				var ph6: float = float(i) / float(RATE)
				var v: float = 0.0
				if ph6 < strike:
					var ie: float = pow(ph6 / strike, 2.4)
					v += (randf() * 2.0 - 1.0) * ie * 0.22
					v += sin(TAU * (60.0 * ph6 + 105.0 * ph6 * ph6 / strike)) * ie * 0.16
				else:
					var d: float = ph6 - strike
					var de: float = pow(maxf(0.0, 1.0 - d / 1.10), 1.5)
					v += sin(TAU * (110.0 * d - 38.0 * d * d)) * de * 0.55
					if d < 0.09:
						v += (randf() * 2.0 - 1.0) * pow(1.0 - d / 0.09, 2.0) * 0.55
					var he: float = minf(1.0, d / 0.30) * minf(1.0, (total - ph6) / 0.50)
					v += (sin(TAU * 55.00 * d) + sin(TAU * 77.78 * d)) * he * 0.15
					v += (sin(TAU * 110.00 * d) + sin(TAU * 155.56 * d)) * he * 0.045
				if ph6 > 1.00:
					var r: float = ph6 - 1.00
					var re: float = minf(1.0, r / 0.45) * minf(1.0, (total - ph6) / 0.28)
					v += (sin(TAU * 1568.0 * r) + sin(TAU * 1573.0 * r)) * re * 0.055
				out[i] = v
			out = _add_tone(out, 1.05, 41.20, 0.34, 0.42, 2.2)
			out = _add_tone(out, 1.90, 38.89, 0.36, 0.30, 2.2)
			out = _add_tone(out, 2.85, 36.71, 0.40, 0.18, 2.2)
			out = _norm(out, 0.96)

		_:
			# NOT A RECIPE -- and this used to be the quietest bug in the game.
			# A misspelled name cost nothing at runtime: it arrived here, got
			# 50ms of silence, and the effect it was written for just never
			# made a sound. Invisible in play, invisible to a sweep, invisible
			# to the suite (the buffer is non-empty, so even "does it
			# synthesize samples" passes). It says so now, the first time it is
			# asked for. The silence stays -- a shipped game must not start
			# buzzing at a player over a developer's typo -- but the log will
			# name the string, and `has_recipe()` above lets a test catch it
			# before anyone has to hear it.
			if not _unknown_seen.has(recipe):
				_unknown_seen[recipe] = true
				push_error("SfxSynth: no recipe named \"%s\" -- that call site is playing silence. Known recipes: %s" % [recipe, str(RECIPES)])
			n = int(RATE * 0.05)
			out.resize(n)
	_cache[recipe] = _wav(out)
	return _cache[recipe]

# Fire-and-forget positional playback. The player node parents to the scene
# ROOT so it outlives whatever spawned it (a bursting projectile frees itself
# the same frame it wants to be heard).
static func play_at(host: Node, at: Vector2, recipe: String, volume_db := -10.0, pitch := 1.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	var pl := AudioStreamPlayer2D.new()
	pl.stream = _bank(recipe)
	pl.volume_db = volume_db
	pl.pitch_scale = maxf(0.1, pitch * randf_range(0.94, 1.06))
	pl.max_distance = 900.0
	host.get_tree().root.add_child(pl)
	pl.global_position = at
	pl.play()
	pl.finished.connect(pl.queue_free)

# Non-positional variant for UI moments (the death countdown, screen-wide
# reveals) -- same recipes, no place in the world to sound from.
static func play_ui(host: Node, recipe: String, volume_db := -10.0, pitch := 1.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	var pl := AudioStreamPlayer.new()
	pl.stream = _bank(recipe)
	pl.volume_db = volume_db
	pl.pitch_scale = maxf(0.1, pitch)
	host.get_tree().root.add_child(pl)
	pl.play()
	pl.finished.connect(pl.queue_free)

# THE VILLAGE EVENTS PLAY THROUGH HERE, not through play_ui() directly.
# The town clock is handed `hours_passed` in one lump -- a load, a debug skip,
# catching up on time the player spent in the deep -- and every DAILY roll
# inside it (fires starting, patrols paying out, the sickness spreading) then
# resolves in a single frame. Twenty toasts stack up harmlessly in a log; twenty
# alarm bells on top of each other are a wall of mud that says nothing. So a
# recipe cannot re-trigger inside `min_gap` real seconds: the first one is heard
# cleanly and the rest are dropped, which is exactly how a player would hear a
# village anyway.
# THE MIX LIVES HERE, not at the call sites. The department that tunes these
# owns this file; the department that TRIGGERS them owns game_state.gd, and it
# should not have to carry a decibel number whose effect it cannot hear. So the
# hand-off line is `SfxSynth.play_village(self, SfxSynth.SFX_X)` and nothing
# else -- every level and throttle in the village set can be retuned without
# anyone reopening a 7,000-line file. Each entry is [volume_db, min_gap_sec].
const VILLAGE_MIX: Dictionary = {
	"patrol_out": [-8.0, 1.5],
	"patrol_home": [-10.0, 2.0],
	"patrol_find": [-8.0, 2.0],
	"patrol_lost": [-7.0, 3.0],
	"outbreak": [-9.0, 3.0],
	"fire_alarm": [-5.0, 2.0],     # the loudest thing the village is allowed
	"fire_doused": [-10.0, 2.0],
	"eclipse": [-3.0, 10.0],       # loudest in the game, and it may not stutter
}

static var _last_played: Dictionary = {}

static func play_village(host: Node, recipe: String, volume_db: float = NAN,
		min_gap: float = NAN, pitch: float = 1.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	var mix: Array = VILLAGE_MIX.get(recipe, [-8.0, 1.5])
	var vol: float = float(mix[0]) if is_nan(volume_db) else volume_db
	var gap: float = float(mix[1]) if is_nan(min_gap) else min_gap
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var prev: float = float(_last_played.get(recipe, -9999.0))
	if now - prev < gap:
		return
	_last_played[recipe] = now
	play_ui(host, recipe, vol, pitch)

# Did this recipe sound in the last `within` seconds? Lets a call site stand
# down when a better sound already covered the same beat -- the patrol's rare
# FIND and its ordinary homecoming resolve in the same frame, and the find
# should not be muddied by the coin lift underneath it.
static func played_recently(recipe: String, within: float = 2.0) -> bool:
	var prev: float = float(_last_played.get(recipe, -9999.0))
	return (float(Time.get_ticks_msec()) / 1000.0) - prev < within

# The same fire-and-forget for an EXISTING wav (the explosion, the bow...).
static func play_stream_at(host: Node, at: Vector2, stream: AudioStream, volume_db := -8.0) -> void:
	if host == null or not host.is_inside_tree() or stream == null:
		return
	var pl := AudioStreamPlayer2D.new()
	pl.stream = stream
	pl.volume_db = volume_db
	pl.pitch_scale = randf_range(0.94, 1.06)
	pl.max_distance = 900.0
	host.get_tree().root.add_child(pl)
	pl.global_position = at
	pl.play()
	pl.finished.connect(pl.queue_free)
