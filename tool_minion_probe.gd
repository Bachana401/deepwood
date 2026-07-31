extends Node

# THE MINION PROBE (2026-07-30).
#
# Every measuring tool in this kit watches the PLAYER swing and counts what
# lands. That is the wrong instrument for a summoner, whose weapon deals no
# damage at all: it puts a body on the field and the BODY does the work, over a
# horizon far longer than any of my 2.4s windows.
#
# Two things ride on fixing that, and they are the same missing capability:
#   1. "all last tier weapons should be giga op, all of them" -- the Monarch
#      floor currently passes the summoner families only because their own
#      median is low too. Nobody knows if a Monarch scepter is actually giga.
#   2. "many summoners operate same" -- of course they read the same. Nothing
#      in the kit could tell them apart, including me.
#
# So: cast, then WATCH. Long enough for a minion to spawn, cross the ground,
# pick a mark and work it. Record when the first damage arrives, how it ramps,
# how far out it reaches, and how many bodies it touches -- then compare those
# profiles against each other and name the ones that are genuinely alike.

const RINGS := [70.0, 190.0, 330.0]
const CAST_FOR := 2.0          # long enough to fill the minion slots
const WATCH := 9.0             # and then simply watch them work
const SAMPLE := 0.5            # dps is recorded in half-second buckets

func say(t: String) -> void: printerr(t)

class Mark extends StaticBody2D:
	var health := 999999999
	var max_health := 999999999
	var is_dead := false
	var hits := 0
	var total := 0
	var first_at := -1.0
	var born := 0.0
	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(34, 64)
		cs.shape = sh
		add_child(cs)
	func take_damage(n: int):
		hits += 1
		total += n
		if first_at < 0.0:
			first_at = Time.get_ticks_msec() / 1000.0 - born
		return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

func _summon_class(cls: String) -> bool:
	return cls in ["scepter", "totem", "whip"]

# COUNT THE BODIES WHERE THEY ACTUALLY LIVE. This scanned four groups --
# "player_companion", "companion" and friends -- and reported x0 for every
# scepter in the roster while those scepters were visibly dealing damage.
# companion.gd joins NO GROUP AT ALL; minions are held in the player's own
# `_companions` dict, and posts are the only ones with a group.
#
# Worth noting beyond this tool: a summoned body that is in no group cannot be
# found by anything else in the game either -- no sweep, no aura, no boss
# ability, no audit. That is a real gap, just not this probe's to close.
func _live_bodies(p: Node) -> int:
	var n := 0
	for g in ["summon_post", "player_sentry"]:
		for c in get_tree().get_nodes_in_group(g):
			if is_instance_valid(c):
				n += 1
	if p != null and "_companions" in p:
		for key in p._companions:
			var c2 = p._companions[key]
			if is_instance_valid(c2) and c2.get("summoned") == true:
				n += 1
	return n

func _ready() -> void:
	await get_tree().process_frame
	get_tree().paused = false
	var p: Node = null
	for i in range(1800):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		say("ABORTED: no player"); get_tree().quit(0); return
	GameState.opening_done = true
	get_tree().paused = false
	var stage: Node = p.get_parent()

	var rows := []
	say("\n=== THE MINION PROBE: cast, then watch for %.0fs ===" % WATCH)
	for row in WeaponRoster.ROWS:
		if not _summon_class(str(row[2])):
			continue
		var id := str(row[0])
		var def: Dictionary = WeaponRoster.get_def(id)
		if def.is_empty():
			continue
		var ex: Dictionary = row[7]
		var body_kind := str(ex.get("m_kind", ex.get("s_kind", ex.get("tag_fx", "-"))))

		# clear the field so the last summoner's bodies cannot do this one's work
		for g in ["summon_post", "player_sentry"]:
			for c in get_tree().get_nodes_in_group(g):
				if is_instance_valid(c):
					c.queue_free()
		# and the minions, which live in the player rather than in a group
		if "_companions" in p:
			for key in p._companions:
				var prev = p._companions[key]
				if is_instance_valid(prev):
					prev.queue_free()
		await get_tree().process_frame

		p.inventory.add_item(id, 1)
		p.wield_weapon(id)
		p.mana = p.get_max_mana()
		p.health = p.get_max_health()
		p.set_test_aim(Vector2.RIGHT)
		var aim := Vector2.RIGHT
		var marks := []
		var t0 := Time.get_ticks_msec() / 1000.0
		for r in RINGS:
			var m := Mark.new()
			m.born = t0
			m.add_to_group("course_enemy")
			stage.add_child(m)
			m.global_position = (p as Node2D).global_position + aim.normalized() * r
			marks.append(m)
		await get_tree().process_frame

		# CAST -- holding the button, cooldown-ruled, and topping mana back up
		# because a summoner that runs dry stops being measured for its minion
		var t := 0.0
		while t < CAST_FOR:
			p.mana = p.get_max_mana()
			p.perform_attack()
			await get_tree().process_frame
			t += get_process_delta_time()
		var bodies := _live_bodies(p)

		# WATCH. The player does nothing at all from here: whatever lands now is
		# the minion's own work, which is the entire point.
		var ramp := []
		var last_total := 0
		var w := 0.0
		while w < WATCH:
			await get_tree().create_timer(SAMPLE, true).timeout
			w += SAMPLE
			var run := 0
			for m in marks:
				run += m.total
			ramp.append(int(round(float(run - last_total) / SAMPLE)))
			last_total = run

		var struck := 0
		var hits := 0
		var total := 0
		var reach := 0.0
		var first := -1.0
		for i in range(marks.size()):
			var m = marks[i]
			if m.hits > 0:
				struck += 1
				reach = maxf(reach, float(RINGS[i]))
				if first < 0.0 or (m.first_at >= 0.0 and m.first_at < first):
					first = m.first_at
			hits += m.hits
			total += m.total
			m.queue_free()

		rows.append({
			"name": str(def.get("name", id)), "tier": int(row[3]),
			"cls": str(row[2]), "verb": str(row[4]), "body": body_kind,
			"bodies": bodies, "hits": hits, "dmg": total,
			"dps": float(total) / WATCH, "reach": reach, "struck": struck,
			"first": first, "ramp": ramp,
		})
		await get_tree().process_frame

	say("\n--- WHAT EACH SUMMONER ACTUALLY DOES ---")
	for r in rows:
		say("  T%d %-7s %-26s %-13s body=%-11s x%d  first %5s  reach %3.0f  tgt %d/3  dps %6.1f"
			% [r["tier"], r["cls"], r["name"], r["verb"], r["body"], r["bodies"],
				("never" if float(r["first"]) < 0.0 else "%.1fs" % float(r["first"])),
				r["reach"], r["struck"], r["dps"]])

	# ---- THE SAMENESS QUESTION, answered by BEHAVIOUR instead of by name -----
	# Two summoners "operate the same" when what their bodies DO is the same:
	# how many arrive, how fast they engage, how far they reach and how hard
	# they work. Buckets are coarse on purpose -- this is looking for twins, not
	# for rounding differences.
	var sigs := {}
	for r in rows:
		var sig := "%s|n%d|f%d|r%d|d%d" % [
			r["body"], int(r["bodies"]),
			int(floor(maxf(float(r["first"]), 0.0) / 1.5)),
			int(float(r["reach"]) / 120.0),
			int(float(r["dps"]) / 25.0)]
		if not sigs.has(sig):
			sigs[sig] = []
		sigs[sig].append("T%d %s" % [r["tier"], r["name"]])
	var twins := []
	for sig in sigs:
		if sigs[sig].size() > 1:
			twins.append("%s  ->  %s" % [sig, ", ".join(sigs[sig])])
	twins.sort()
	say("\n=== SUMMONERS THAT OPERATE THE SAME (%d groups) ===" % twins.size())
	for t2 in twins:
		say("  " + t2)
	say("\n=== %d summoners probed, %d distinct profiles ===" % [rows.size(), sigs.size()])
	get_tree().quit(0)
