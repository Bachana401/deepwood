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
		_:
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
