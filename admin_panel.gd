extends CanvasLayer

# One-stop dev/testing console, toggled with P. Every "OP" testing action lives
# here as a clickable button instead of a scattered hotkey: morale nudges,
# build-all, populate, god mode, kill, heal, gold, time-skips, level unlock.
# (The T super-dash stays a movement key; G still places a torch.)

# `frame` is the visible window and owns visibility; `panel` is the SCROLLING
# content inside it, which every section still lays out with absolute positions.
var frame: Panel
var panel: Control
var morale_label: Label
var god_button: Button

const W := 340.0
const PAD := 14.0
const BW := 44.0    # small button width
const BH := 26.0
const GAP := 6.0
# The window fits inside the 648-high base UI viewport with room to spare; the
# content is taller than that on purpose and scrolls. Only CONTENT_H needs raising
# when a section is added, and getting it wrong now costs a scrollbar that stops
# early rather than a button nobody can click.
const FRAME_H := 600.0
const CONTENT_H := 900.0

func _ready() -> void:
	layer = 70
	# the console must answer P through a PAUSED tree (audit fix): every
	# dialogue beat pauses the world -- and the finale is one long chain of
	# them -- so the dev console was dead exactly when a tester most wants to
	# poke at things. Same mode the pause menu itself runs in.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("esc_window")
	_build()
	frame.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("admin_panel"):
		# P always opens the console (dev request: instant visual testing of
		# upgrades without relaunching with --dev)
		frame.visible = not frame.visible
		if frame.visible:
			refresh()
		get_viewport().set_input_as_handled()

func close() -> void:
	frame.visible = false

# The esc_window contract: pause_menu's ESC sweep calls these on every member.
# The panel JOINED the group since day one but never implemented the protocol,
# so ESC silently did nothing to it -- the comment claimed otherwise.
func esc_is_open() -> bool:
	return frame != null and frame.visible

func esc_close() -> void:
	close()

func _process(_delta: float) -> void:
	if frame != null and frame.visible:
		refresh()

func refresh() -> void:
	_refresh_warp()
	if morale_label:
		morale_label.text = "Morale: %.1f / 10   (nudge %+d)" % [GameState.village_morale_10(), GameState.morale_admin_offset / 10]
	if god_button:
		var pl = _player()
		var on: bool = pl != null and pl.god_mode
		god_button.text = "GOD MODE: %s" % ("ON" if on else "OFF")
		# green while it's live -- easy to see at a glance that you're not
		# testing the real difficulty
		god_button.add_theme_color_override("font_color",
			Color(0.5, 1.0, 0.55) if on else Color(1, 1, 1))

func _player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _notify(msg: String) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack and stack.has_method("show_notification"):
		stack.show_notification(msg)

# --- layout ---
func _build() -> void:
	# IT SCROLLS NOW, and it had to. The console grew by hand-editing a fixed height
	# every time a section was added, and it had already outgrown the screen: at 756px
	# in a 648px viewport, the MORALE header ran off the top and the Test Arena button
	# and Close ran off the bottom, unreachable. Adding THE ECLIPSE section would have
	# pushed it to 848 and made it worse. A scrolling body means a new section can
	# never again silently shove the tail out of reach, so nobody has to remember to
	# grow a magic number.
	frame = Panel.new()
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -W / 2.0 - 6.0
	frame.offset_right = W / 2.0 + 6.0
	frame.offset_top = -FRAME_H / 2.0
	frame.offset_bottom = FRAME_H / 2.0
	add_child(frame)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(4.0, 4.0)
	scroll.size = Vector2(W + 4.0, FRAME_H - 8.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)

	# the content host. Every section below still lays itself out with absolute
	# positions against a running `y`, exactly as before -- only now the tail of
	# that column scrolls into view instead of falling off the world.
	panel = Control.new()
	panel.custom_minimum_size = Vector2(W, CONTENT_H)
	scroll.add_child(panel)

	var title = Label.new()
	title.position = Vector2(PAD, 10)
	title.add_theme_font_size_override("font_size", 18)
	title.text = "ADMIN CONTROL PANEL  (P)"
	panel.add_child(title)

	var y = 46.0
	# --- Morale ---
	y = _section("MORALE", y)
	morale_label = _text("Morale: -", y)
	y += 24.0
	# row of nudge buttons: -10 -2 -1 +1 +2 +10
	var mx = PAD
	for spec in [["-10", -10], ["-2", -2], ["-1", -1], ["+1", 1], ["+2", 2], ["+10", 10]]:
		var tenths = spec[1]
		_btn(spec[0], mx, y, BW, BH, func(): GameState.admin_nudge_morale(tenths))
		mx += BW + GAP
	y += BH + GAP
	_btn("Reset morale nudge", PAD, y, 160, BH, func(): GameState.morale_admin_offset = 0)
	y += BH + 10.0

	# --- Village ---
	y = _section("VILLAGE", y)
	_btn("Build ALL buildings", PAD, y, 160, BH, _build_all)
	_btn("Populate village", PAD + 166, y, 150, BH, func():
		GameState.test_populate_village()
		_notify("Admin: village populated."))
	y += BH + 10.0

	# --- Player ---
	y = _section("PLAYER", y)
	god_button = _btn("GOD MODE: OFF", PAD, y, 150, BH, _toggle_god)
	_btn("Kill player", PAD + 156, y, 160, BH, func():
		var pl = _player()
		if pl:
			pl.god_mode = false
			pl.die())
	y += BH + GAP
	_btn("Full heal + mana", PAD, y, 150, BH, _full_heal)
	_btn("+500 gold", PAD + 156, y, 160, BH, func():
		var pl = _player()
		if pl and pl.has_method("add_currency"):
			pl.add_currency(500))
	y += BH + 10.0

	# --- World ---
	y = _section("WORLD / TIME", y)
	var tx = PAD
	for spec in [["-1 Day", -24.0], ["-1 Hr", -1.0], ["+1 Hr", 1.0], ["+1 Day", 24.0]]:
		var hrs = spec[1]
		_btn(spec[0], tx, y, 74, BH, func(): _skip_time(hrs))
		tx += 74 + GAP
	y += BH + GAP
	_btn("Unlock ALL dungeon levels", PAD, y, 220, BH, func():
		GameState.highest_unlocked_level = 999
		_notify("Admin: all dungeon levels unlocked."))
	y += BH + 12.0

	# --- Shadow Monarch (jump character level to each 1..7 stage to see the aura) ---
	y = _section("SHADOW MONARCH  (set stage / level)", y)
	var sx = PAD
	for spec in [["1", 5], ["2", 15], ["3", 30], ["4", 45], ["5", 60], ["6", 80], ["7", 100]]:
		var lvl = spec[1]
		_btn(spec[0], sx, y, 38.0, BH, func(): _set_level(lvl))
		sx += 38.0 + GAP
	y += BH + GAP
	_btn("Reset to Lv 1 (no aura)", PAD, y, 200, BH, func(): _set_level(1))
	_btn("TRUE FORM", PAD + 200 + GAP, y, 106, BH, _toggle_true_form)
	y += BH + 12.0

	# --- Buildings (set every building's level instantly to eyeball upgrades) ---
	y = _section("BUILDINGS  (instant level, visual test)", y)
	_btn("All +1", PAD, y, 92, BH, func(): _buildings_level(1))
	_btn("All MAX", PAD + 92 + GAP, y, 92, BH, func(): _buildings_level(99))
	_btn("All Lv 1", PAD + (92 + GAP) * 2.0, y, 92, BH, func(): _buildings_level(0))
	y += BH + 12.0

	# --- Warp (dev 2026-07-30: "teleport to any dungeon level of my choice, so
	# I can test weapons on different bosses"). A stepper rather than 22 boss
	# buttons: it reaches EVERY floor, not just the boss ones, and the label
	# tells you what is waiting down there before you commit to the trip.
	y = _section("WARP TO DUNGEON FLOOR", y)
	var wx := PAD
	for spec in [["<<10", -10], ["<5", -5], ["<1", -1], ["1>", 1], ["5>", 5], ["10>", 10]]:
		var step: int = spec[1]
		_btn(spec[0], wx, y, 52.0, BH, func(): _warp_step(step))
		wx += 52.0 + GAP
	_btn("BOSS >", wx, y, 62.0, BH, _warp_next_boss)
	y += BH + GAP
	warp_label = _text("", y)
	y += 22.0
	_btn("WARP DOWN", PAD, y, W - PAD * 2.0, BH, _warp_go)
	y += BH + 12.0

	# --- The eclipse (dev ask 2026-08-06: "i want to be able somehow to test
	# eclipse happening and it's boss"). In the real game this is a 3%-a-day roll
	# with a seven-day floor between them -- you could idle for an hour of real time
	# and never see one, which makes it untestable by playing. These force it.
	y = _section("THE ECLIPSE  (3%/day in the real game)", y)
	# every row must fit inside W - PAD*2 = 312px, or a button hangs off the panel
	_btn("START ECLIPSE", PAD, y, 152, BH, _force_eclipse)
	_btn("Jump to TOTALITY", PAD + 158, y, 154, BH, func():
		_force_eclipse()
		GameState.game_hours = GameState.eclipse_at_hours + GameState.ECLIPSE_DURATION_HOURS * 0.5
		var dn2 = get_tree().get_first_node_in_group("day_night_cycle")
		if dn2 and dn2.has_method("update_visuals"):
			dn2.update_visuals()
		_notify("Admin: totality — the ring is at its widest."))
	y += BH + GAP
	_btn("End", PAD, y, 56, BH, func():
		GameState.eclipse_at_hours = -1.0
		_notify("Admin: the sun is let go."))
	_btn("+3 Signets", PAD + 62, y, 104, BH, func():
		var pl = _player()
		if pl and pl.inventory:
			pl.inventory.add_item("hollow_signet", 3)
			_notify("Admin: 3x Hollow Signet. Raise one during a TRUE eclipse."))
	_btn("SUMMON BOSS", PAD + 172, y, 140, BH, _summon_hollowsun)
	y += BH + 12.0

	# --- Test arena ---
	y = _section("TEST ARENA", y)
	_btn("PROVING GROUNDS  (all items in chests + DPS dummy)", PAD, y, W - PAD * 2.0, BH, _enter_proving_grounds)
	y += BH + 12.0

	_btn("Close (P)", PAD, y, W - PAD * 2.0, BH, close)

# ==========================================================================
# WARP. Pick any floor 1..100 and drop into it directly, so a weapon can be
# tried against a specific boss without descending ninety floors to reach it.
# ==========================================================================
var _warp_level := 5
var warp_label: Label = null

func _warp_step(by: int) -> void:
	_warp_level = clampi(_warp_level + by, 1, _max_level())
	_refresh_warp()

# jump to the next floor that actually holds a boss -- the reason the dev asked
# for this at all, and 4 of every 5 floors do not have one
func _warp_next_boss() -> void:
	var top: int = _max_level()
	for n in range(_warp_level + 1, top + 1):
		if _boss_on(n) != "":
			_warp_level = n
			_refresh_warp()
			return
	# past the last boss: wrap to the first
	for n2 in range(1, top + 1):
		if _boss_on(n2) != "":
			_warp_level = n2
			break
	_refresh_warp()

func _max_level() -> int:
	# read the LIVE constant, never a copy of it -- `"MAX_LEVEL" in d` would
	# always be false (consts are not properties) and quietly pin this to a
	# hardcoded 100 that stops matching the day the dungeon gets deeper.
	# _dungeon() only ever returns dungeon_interior, which declares it.
	var d := _dungeon()
	if d != null:
		return int(d.MAX_LEVEL)
	return 100

# The panel is parented to whatever scene spawned it -- dungeon_interior in the
# dungeon, underground.gd below. Only the former knows the boss ladder, so ask
# rather than preload: admin_panel is itself preloaded BY dungeon_interior, and
# preloading it back would be a cycle.
func _dungeon() -> Node:
	var p := get_parent()
	if p != null and p.has_method("get_boss_id") and p.has_method("is_boss_level"):
		return p
	return null

func _boss_on(level: int) -> String:
	var d := _dungeon()
	if d == null:
		return ""
	if not d.is_boss_level(level):
		return ""
	return str(d.get_boss_id(level))

func _refresh_warp() -> void:
	if warp_label == null:
		return
	var boss := _boss_on(_warp_level)
	if boss != "":
		warp_label.text = "Floor %d  ·  BOSS: %s" % [_warp_level, boss.replace("_", " ").to_upper()]
		warp_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	else:
		var d := _dungeon()
		var nxt := ""
		if d != null:
			for n in range(_warp_level + 1, _max_level() + 1):
				if _boss_on(n) != "":
					nxt = "  (next boss: floor %d)" % n
					break
		warp_label.text = "Floor %d  ·  no boss%s" % [_warp_level, nxt]
		warp_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))

func _warp_go() -> void:
	# the floor must be UNLOCKED or the dungeon bounces you back to the deepest
	# level you have earned -- which silently makes this button do nothing
	GameState.highest_unlocked_level = maxi(GameState.highest_unlocked_level, _warp_level)
	GameState.proving_grounds = false
	GameState.active_dungeon_level = _warp_level
	var pl = _player()
	if pl:
		GameState.pending_player_state = GameState.capture_player_state(pl)
		# same reason as the Proving Grounds entry below: without a real exit
		# anchor you return to (0,0), under the village floor, and fall through
		GameState.pre_dungeon_position = pl.global_position
	_notify("Admin: warping to floor %d." % _warp_level)
	close()
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")

# Enter the Proving Grounds: a flat test arena (dungeon_interior in a special
# mode) with every item in labelled rarity chests and an invincible DPS dummy.
func _enter_proving_grounds() -> void:
	GameState.proving_grounds = true
	GameState.active_dungeon_level = 1
	var pl = _player()
	if pl:
		GameState.pending_player_state = GameState.capture_player_state(pl)
		# remember where to drop the player back in the village -- without this
		# the exit falls back to pre_dungeon_position's default (0,0), which is
		# below the village ground line (GROUND_Y = -39) so you'd spawn embedded
		# in the floor and fall through. (matches level_select_ui's entry.)
		GameState.pre_dungeon_position = pl.global_position
	close()
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")

# Instantly set every live building's level (no gold cost, clamped to
# MAX_LEVEL) and rebuild its geometry so upgrades can be eyeballed on the
# spot. 1 = +1 level, 99 = jump to max, 0 = back to level 1.
func _buildings_level(mode: int) -> void:
	var n := 0
	for b in get_tree().get_nodes_in_group("building"):
		if not ("building_level" in b):
			continue
		# finish construction first -- the honest start leaves most buildings
		# as ruins, and levels/facades only show on FINISHED buildings
		b.build_stage = GameState.TOTAL_BUILD_STAGES
		GameState.building_stage[b.building_name] = b.build_stage
		b.constructing = false
		b.health = b.MAX_HEALTH
		GameState.building_health[b.building_name] = b.health
		var target: int = b.building_level + 1 if mode == 1 else (b.MAX_LEVEL if mode == 99 else 1)
		target = clampi(target, 1, b.MAX_LEVEL)
		b.building_level = target
		GameState.building_levels[b.building_name] = target
		b.current_state = b.compute_visual_state()
		b.rebuild_geometry()
		n += 1
	_notify("Admin: %d buildings finished -> %s" % [n, ("+1 level" if mode == 1 else ("MAX" if mode == 99 else "level 1"))])

# 7/7's full god-form normally waits for the finale (no villagers left alive);
# forcing it lets the 2x form + novas + permanent shades be eyeballed any time.
func _toggle_true_form() -> void:
	GameState.monarch_true_form_forced = not GameState.monarch_true_form_forced
	if GameState.monarch_true_form_forced and GameState.player_level < 100:
		_set_level(100)
	_notify("Admin: Shadow Monarch true form %s" % ("FORCED ON" if GameState.monarch_true_form_forced else "off (finale-gated)"))

# Jump the character level so a stage's aura/pallor/power shows instantly.
func _set_level(lvl: int) -> void:
	# grant only the points the LEVEL JUMP earns (audit fix): the old
	# `max(points, lvl-1)` ignored spent skills, so a level-50 character with
	# a fully-bought tree who clicked a stage button walked away with 99 free
	# points ON TOP of the tree -- and P is reachable in normal play.
	var gained := maxi(0, lvl - GameState.player_level)
	GameState.player_level = lvl
	GameState.player_xp = 0
	GameState.skill_points += gained
	GameState.announce_monarch_awakening()
	var pl = _player()
	if pl and pl.has_method("update_health_display"):
		pl.update_health_display()   # max HP may scale with level
	_notify("Admin: level %d  ->  Shadow Monarch %d/7" % [lvl, GameState.monarch_stage()])

func _section(name: String, y: float) -> float:
	var l = Label.new()
	l.position = Vector2(PAD, y)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	l.text = "— " + name + " —"
	panel.add_child(l)
	return y + 22.0

func _text(txt: String, y: float) -> Label:
	var l = Label.new()
	l.position = Vector2(PAD, y)
	l.add_theme_font_size_override("font_size", 13)
	l.text = txt
	panel.add_child(l)
	return l

func _btn(txt: String, x: float, y: float, w: float, h: float, cb: Callable) -> Button:
	var b = Button.new()
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE   # keep TAB/keys free
	b.pressed.connect(cb)
	panel.add_child(b)
	return b

# --- actions ---
func _build_all() -> void:
	GameState.restore_all_buildings()
	for b in get_tree().get_nodes_in_group("building"):
		if b.has_method("restore_full"):
			b.restore_full()
	_notify("Admin: all buildings restored.")

# One switch for roaming the map: untouchable, T blink-dash without needing the
# Shadowstep Sigil, and unlimited flight without needing the Aetherwing.
func _toggle_god() -> void:
	var pl = _player()
	if pl == null:
		return
	pl.god_mode = not pl.god_mode
	if pl.god_mode:
		pl.mana = pl.get_max_mana()   # start airborne-ready (levitation burns mana)
		_notify("GOD MODE ON — invincible · T = super dash · hold Space = fly")
	else:
		_notify("GOD MODE OFF — mortal again")
	refresh()

func _full_heal() -> void:
	var pl = _player()
	if pl == null:
		return
	pl.health = pl.get_max_health()
	pl.mana = pl.get_max_mana()
	if pl.has_method("update_health_display"):
		pl.update_health_display()
	if pl.has_method("update_mana_display"):
		pl.update_mana_display()

# ==========================================================================
# THE ECLIPSE, ON DEMAND.
# ==========================================================================

# Open one HERE AND NOW rather than waiting on the roll. Note it does NOT jump
# game_hours forward to reach the next dawn: tick_village_clock plays out an entire
# skipped span in a single tick, so a jump of a few hundred hours arrives with the
# town already burned down and starving -- which then looks like the eclipse did it.
# The clock is left alone and the eclipse window is moved onto the clock instead.
func _force_eclipse() -> void:
	# CLAMPED AT ZERO, and that is not paranoia. eclipse_is_active() treats a
	# NEGATIVE eclipse_at_hours as "there has never been one" -- so on a fresh save,
	# where game_hours is still ~0, backdating by a hundredth of an hour produced
	# -0.01 and the button silently did nothing. It failed in exactly the situation
	# a tester reaches for it: a new game, five seconds after pressing P.
	GameState.eclipse_at_hours = maxf(0.0, GameState.game_hours - 0.01)
	GameState._eclipse_announced = true      # the panel is the announcement
	var dn = get_tree().get_first_node_in_group("day_night_cycle")
	if dn and dn.has_method("update_visuals"):
		dn.update_visuals()
	_notify("Admin: the moon takes the sun. Raise the Hollow Signet.")

# Straight to the fight, skipping the ring and the item. Uses the real summon path
# so the director, the arena bound and the payout are the ones the game actually
# runs -- a boss stood up by hand here would prove nothing about the real one.
func _summon_hollowsun() -> void:
	_force_eclipse()
	GameState._summon_pending = false
	for d in get_tree().get_nodes_in_group("event_boss_director"):
		d.queue_free()
	var reason: String = GameState.summon_event_boss("hollowsun", 3.0, false, true)
	if reason != "":
		_notify("Admin: refused — " + reason)
	else:
		_notify("Admin: THE HOLLOW SUN is coming. It fights in your village.")

func _skip_time(hours: float) -> void:
	GameState.skip_hours(hours)
	var dn = get_tree().get_first_node_in_group("day_night_cycle")
	if dn and dn.has_method("pick_new_moon_phase"):
		dn.pick_new_moon_phase()
