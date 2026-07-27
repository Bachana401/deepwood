class_name SpeechText
extends Node2D

# Floating, window-less speech for characters: plain outlined text hovering
# above the speaker's head, following them as they move, staying up long
# enough to read (scaled by text length), then fading out. Used for NPC
# "talking" moments (rescue lines, Press-E introductions) -- system messages
# (purchases, level-ups, level-cleared) still use the corner NotificationStack.
const MAX_WIDTH = 230.0
const HEAD_OFFSET = Vector2(0, -52)
const FADE_SECONDS = 0.5
# ~1.8s base + 50ms per character reads comfortably; clamped so one-word
# lines don't blink away and long backstories don't linger forever.
const MIN_SECONDS = 2.5
const MAX_SECONDS = 8.0

var target: Node2D = null
var last_known_position = Vector2.ZERO

static func spawn(speaker: Node2D, text: String) -> void:
	if speaker == null or not is_instance_valid(speaker):
		return
	var world = speaker.get_parent()
	if world == null:
		return
	# a speaker starting a new line replaces their previous one instead of
	# stacking two overlapping texts on the same head
	if speaker.has_meta("active_speech"):
		var old = speaker.get_meta("active_speech")
		if is_instance_valid(old):
			old.queue_free()
	var speech = SpeechText.new()
	speech.target = speaker
	speech.global_position = speaker.global_position + HEAD_OFFSET
	world.add_child(speech)
	speech.show_text(text)
	speaker.set_meta("active_speech", speech)

func show_text(text: String) -> void:
	add_to_group("speech_text")   # so live bubbles are findable (tests, sweeps)
	z_index = 200
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(MAX_WIDTH, 0)
	label.size = Vector2(MAX_WIDTH, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)
	# anchor the text block so it sits fully ABOVE the head no matter how
	# many lines it wraps to (layout height only settles after this frame)
	position_label.call_deferred(label)

	var duration = clamp(1.8 + text.length() * 0.05, MIN_SECONDS, MAX_SECONDS)
	var tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(queue_free)

func position_label(label: Label) -> void:
	label.position = Vector2(-MAX_WIDTH / 2.0, -label.size.y)

func _process(_delta: float) -> void:
	# follow the speaker while they exist; if they despawn mid-line (e.g. a
	# rescued hostage fading out), the text simply stays where they were.
	if target != null and is_instance_valid(target):
		global_position = target.global_position + HEAD_OFFSET
