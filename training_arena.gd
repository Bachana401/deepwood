extends Node2D

# THE PROVING GROUND (dev, 2026-07-30).
#
# "you need to properly create place where you can test every created weapon by
# you, if it fits, then we approve."
#
# Three dummies at staged distances in front of the player, each keeping its own
# tally, and one panel that reads out everything a weapon is: its class, what it
# costs, whether it channels, how far it actually reached, how many bodies it
# actually touched, and what it actually did per second.
#
# WHY THIS EXISTS AND THE HEADLESS PROBES DO NOT REPLACE IT. Every measuring
# tool I built today answered ONE question and answered it blind:
#   tool_hitsweep       declared-vs-measured, but its range labels were fiction
#   tool_defaults_probe true distances, but no eyes on any of it
#   test_realhits       a regression guard on 22 weapons, not a survey
# None of them could tell me whether a weapon LOOKS right, and the dev has been
# telling me for a day that the reference clips are not landing. A thing you can
# stand in and watch is the only instrument that answers that.
#
# DUMMIES ARE IMMORTAL ON PURPOSE. A target that dies stops measuring, and the
# question here is what the weapon does, not how long something survives.

const NEAR := 90.0
const MID := 190.0
const FAR := 310.0
const WINDOW := 3.0        # the rolling window every dps figure is taken over

var _dummies: Array = []
var _panel: Panel = null
var _readout: RichTextLabel = null
var _t := 0.0
var _armed_at := 0.0
var _peak_reach := 0.0
var _weapon_seen := ""

class Dummy extends StaticBody2D:
	var health := 999999999
	var max_health := 999999999
	var is_dead := false
	var hits := 0
	var total := 0
	var label := "?"
	var _stamps: Array = []          # [time, damage] pairs inside the window
	var _tag: Label = null

	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(34, 64)
		cs.shape = sh
		add_child(cs)

	func _ready() -> void:
		add_to_group("course_enemy")      # so weapons see it as a real foe
		add_to_group("training_dummy")
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-17, -32), Vector2(17, -32), Vector2(17, 32), Vector2(-17, 32)])
		body.color = Color(0.42, 0.34, 0.26, 1.0)
		add_child(body)
		var band := Polygon2D.new()
		band.polygon = PackedVector2Array([
			Vector2(-17, -10), Vector2(17, -10), Vector2(17, -2), Vector2(-17, -2)])
		band.color = Color(0.80, 0.72, 0.52, 1.0)
		add_child(band)
		_tag = Label.new()
		_tag.add_theme_font_size_override("font_size", 11)
		_tag.add_theme_color_override("font_color", Color(1, 1, 1))
		_tag.position = Vector2(-46, -78)
		_tag.size = Vector2(92, 42)
		_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_tag)
		z_index = 20

	func take_damage(n: int):
		hits += 1
		total += n
		_stamps.append([Time.get_ticks_msec() / 1000.0, n])
		# a hit should be VISIBLE, or you cannot tell a whiff from a zero
		var f := Polygon2D.new()
		f.polygon = PackedVector2Array([
			Vector2(-19, -34), Vector2(19, -34), Vector2(19, 34), Vector2(-19, 34)])
		f.color = Color(1.0, 0.9, 0.6, 0.55)
		add_child(f)
		var tw := f.create_tween()
		tw.tween_property(f, "modulate:a", 0.0, 0.16)
		tw.tween_callback(f.queue_free)
		return true

	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

	func window_dps(window: float) -> float:
		var now := Time.get_ticks_msec() / 1000.0
		var keep := []
		var sum := 0
		for s in _stamps:
			if now - float(s[0]) <= window:
				keep.append(s)
				sum += int(s[1])
		_stamps = keep
		return float(sum) / window

	func reset() -> void:
		hits = 0
		total = 0
		_stamps.clear()

	func refresh(window: float) -> void:
		if _tag != null:
			_tag.text = "%s\n%d hits  %d dmg\n%.0f dps" % [label, hits, total, window_dps(window)]

func _ready() -> void:
	z_index = 30
	_build_dummies()
	_build_panel()
	set_process(true)

func _build_dummies() -> void:
	var p := _player()
	var base: Vector2 = Vector2.ZERO if p == null else (p as Node2D).global_position
	var face := 1.0
	if p != null and p.has_method("get_aim_direction"):
		var a: Vector2 = p.get_aim_direction()
		face = 1.0 if a.x >= 0.0 else -1.0
	for pair in [[NEAR, "NEAR 90"], [MID, "MID 190"], [FAR, "FAR 310"]]:
		var d := Dummy.new()
		d.label = str(pair[1])
		add_child(d)
		d.global_position = base + Vector2(float(pair[0]) * face, 0)
		_dummies.append(d)

func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	_panel = Panel.new()
	_panel.position = Vector2(16, 96)
	_panel.size = Vector2(360, 214)
	layer.add_child(_panel)
	_readout = RichTextLabel.new()
	_readout.bbcode_enabled = true
	_readout.position = Vector2(10, 8)
	_readout.size = Vector2(340, 198)
	_readout.add_theme_font_size_override("normal_font_size", 12)
	_panel.add_child(_readout)

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	_t += delta
	var p := _player()
	if p == null:
		return
	# a new weapon in hand means a new experiment: clear the slate rather than
	# letting the last weapon's numbers bleed into this one's verdict
	var wid := str(p.active_weapon_id) if "active_weapon_id" in p else ""
	if wid != _weapon_seen:
		_weapon_seen = wid
		reset_all()
	# REACH, measured rather than declared: the furthest dummy that has taken
	# anything since the last reset is how far this weapon actually goes
	for d in _dummies:
		if is_instance_valid(d):
			d.refresh(WINDOW)
			if d.hits > 0:
				_peak_reach = maxf(_peak_reach,
					absf((d as Node2D).global_position.x - (p as Node2D).global_position.x))
	if _readout != null:
		_readout.text = _describe(p)

func reset_all() -> void:
	_peak_reach = 0.0
	for d in _dummies:
		if is_instance_valid(d):
			d.reset()

func _describe(p: Node) -> String:
	var wid := str(p.active_weapon_id) if "active_weapon_id" in p else ""
	if wid == "":
		return "[b]THE PROVING GROUND[/b]\nWield something."
	var def: Dictionary = p.active_def if "active_def" in p else {}
	var special: Dictionary = def.get("special", {})
	var stype := str(special.get("type", ""))
	var wtype := str(p.active_weapon_type) if "active_weapon_type" in p else "?"
	var stats: Dictionary = p.active_stats if "active_stats" in p else {}

	var struck := 0
	var hits := 0
	var total := 0
	var dps := 0.0
	for d in _dummies:
		if not is_instance_valid(d):
			continue
		if d.hits > 0:
			struck += 1
		hits += d.hits
		total += d.total
		dps += d.window_dps(WINDOW)

	# WHAT IT COSTS. A weapon that quietly drains mana and one that is free are
	# different weapons, and the tooltip has never said which.
	var cost := float(special.get("mana", def.get("mana_cost", 0.0)))
	var cost_s := "FREE" if cost <= 0.0 else "%.0f mana" % cost
	# CHANNELLED verbs need the button HELD; a tap tells you nothing about them,
	# which is exactly how prism_converge read as broken for a week.
	var channels := stype in ["prism_converge", "beam_channel", "soul_stream"]

	var s := "[b]%s[/b]   [i]%s[/i]\n" % [str(def.get("name", wid)), wtype]
	s += "verb: %s    cost: %s%s\n" % [
		("(plain)" if stype == "" else stype), cost_s,
		"    [color=#ffd27f]HOLD TO CHANNEL[/color]" if channels else ""]
	s += "cooldown %.2fs    declared reach %.0f\n" % [
		float(stats.get("cooldown", 0.0)), float(special.get("range", 0.0))]
	s += "[b]MEASURED[/b]\n"
	s += "  reach   %.0f px  %s\n" % [_peak_reach,
		"[color=#ff8a8a](nothing landed)[/color]" if _peak_reach <= 0.0 else ""]
	s += "  targets %d of 3   %s\n" % [struck,
		"[color=#8affa0]AoE / multi[/color]" if struck > 1 else "single"]
	s += "  hits    %d      damage %d\n" % [hits, total]
	s += "  DPS     [b]%.0f[/b]  (rolling %.0fs, all dummies)\n" % [dps, WINDOW]
	s += "[i]R resets · P despawns the ground[/i]"
	return s

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_R:
		reset_all()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_P:
		queue_free()
		get_viewport().set_input_as_handled()
