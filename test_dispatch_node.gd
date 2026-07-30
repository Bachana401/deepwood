extends Node

# DYNAMIC DISPATCH AUDIT (2026-07-29).
#
# WHY THIS EXISTS: six weapons across three batches shipped with their verb
# wired into a branch their own weapon class never reaches. Every other audit
# stayed green, because nothing was BROKEN -- the verb was silently absent and
# the weapon quietly fell through to a plain swing or a plain arrow. Only the
# film ever caught them, one at a time:
#     Staff That Measures the Sky, The Unbent Column   staves are weapon_type
#                                                      "melee", wired to wand
#     Throne of Strings, Thunderhead, Midnight Post    BOWS, wired to wand
#     Stormherd                                        declared type "marcher",
#                                                      which has no dispatch
#
# A STATIC scan of player.gd was tried first and thrown away: the melee chain
# sits after the typed blocks, so backward-scanning misattributes branches, and
# dozens of verbs use the generic path with no branch at all. It produced false
# positives, and a noisy audit is worse than none.
#
# So this one is dynamic and blunt: EQUIP every weapon, FIRE it, and look at
# what actually appeared in the scene. "Did anything spawn?" is not enough --
# a misrouted bow still looses an ordinary arrow -- so it asserts a node of the
# verb's OWN kind is present.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

class Dummy extends StaticBody2D:
	var health := 999999
	var max_health := 999999
	var is_dead := false
	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(30, 60)
		cs.shape = sh
		add_child(cs)
	func take_damage(n: int):
		health -= n
		return true
	func apply_status(_k: String, _d: float, _m: float) -> void: pass
	func apply_knockback(_s: float, _f: float) -> void: pass

# A special's "type" is usually the projectile kind it creates, but a handful
# legitimately differ. Each entry here is a deliberate mapping, not a guess --
# if a weapon shows up unmatched, it gets FIXED or it gets a line here with a
# reason, never a silent pass.
const KIND_ALIAS := {
	"flying_slash":   ["slash"],          # launch_projectile renames it
	"javelin_volley": ["javelin"],        # ditto
	"storm_beast":    ["storm_bird"],     # Stormherd rides the runner engine
	"court_barrage":  ["courtier"],       # the Court spawns its shades
	"king_rain":      ["javelin", "crown_spear"],  # the rain drops shafts
	"multi_shot":     ["script:arrow.gd", "shot", "arrow"],
	"companion":      ["companion", "script:companion.gd"],
	"storm_flock":    ["storm_bird"],     # the flock IS a set of birds
	# these three spawn something real that simply is not a weapon_projectile
	"tome_storm":     ["script:storm_cloud.gd"],
	"sentry":         ["group:player_sentry"],
	"homing":         ["arrow", "shot", "script:arrow.gd"],  # a FLAG on a normal shaft
}

# Verbs that deliberately create NO node of their own on a single press.
# Each needs a reason; this list is meant to stay short.
const NO_NODE_EXPECTED := {
	"staff_extend": "the staff simply lengthens the melee reach; no projectile",
	"prism_converge": "a CHANNEL -- it needs the attack held, not tapped",
	"cleave": "a plain heavy swing; the hit is the melee area, not a node",
	"commandment": "a METRONOME -- the ruling lands on the ninth press, not the first",
}

# Verbs whose declared "count" is a CYCLE rather than a single press.
const COUNT_IS_A_CYCLE := {
	"omen_sigil": "The Third Omen counts to three ACROSS presses; two warnings, then the third",
}

func _ready() -> void:
	await get_tree().process_frame
	# the opening plea PAUSES the tree, and a paused tree runs no physics --
	# every probe then reads "nothing happened" regardless of the weapon
	get_tree().paused = false
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null:
			break
	if p == null:
		check("player found", false, "no player in the scene")
		_finish()
		return
	GameState.opening_done = true
	get_tree().paused = false

	var stage: Node = p.get_parent()
	for dx in [140.0, 230.0, 320.0]:
		var foe := Dummy.new()
		foe.add_to_group("course_enemy")
		stage.add_child(foe)
		foe.global_position = (p as Node2D).global_position + Vector2(dx, 20.0)
	await _settle(0.3)

	var silent := []
	var undercount := []
	var checked := 0
	for row in WeaponRoster.ROWS:
		var id := str(row[0])
		var def: Dictionary = WeaponRoster.get_def(id)
		var sp: Dictionary = def.get("special", {})
		var stype := str(sp.get("type", ""))
		if stype == "" or NO_NODE_EXPECTED.has(stype):
			continue
		checked += 1
		p.inventory.add_item(id, 1)
		# snapshot BEFORE wielding: companions are summoned by the equip hook,
		# not by the attack, so a snapshot taken after wielding counts them as
		# pre-existing and the crown reads as summoning nobody
		var pre := _snapshot(stage)
		p.wield_weapon(id)
		p.mana = p.get_max_mana()
		p.health = p.get_max_health()
		# SAMPLE CONTINUOUSLY. A single look at the end misses every verb
		# that spawns and dies inside the window -- a bolt that reaches a
		# dummy 140px away is gone long before then, and reads as silent.
		var seen := pre
		var made := {}
		p.attack_cooldown_remaining = 0.0
		p.perform_attack()
		for _step in range(14):
			await get_tree().process_frame
			for n in stage.get_children():
				if seen.has(n.get_instance_id()):
					continue
				seen[n.get_instance_id()] = true
				# Record EVERY handle a spawned node offers -- its kind, its
				# script, and its groups. Matching on `kind` alone produced a
				# dozen false alarms: storm tomes spawn a storm_cloud script,
				# sentries a totem in a group, and homing is only a FLAG on an
				# ordinary arrow. The audit should read what is there, not
				# what I assumed would be there.
				var k = n.get("kind")
				if k != null and str(k) != "":
					made[str(k)] = int(made.get(str(k), 0)) + 1
				var scr = n.get_script()
				if scr != null:
					var sk := "script:" + str(scr.resource_path).get_file()
					made[sk] = int(made.get(sk, 0)) + 1
				for g in n.get_groups():
					var gk := "group:" + str(g)
					made[gk] = int(made.get(gk, 0)) + 1
		# sweep the field between weapons. Persistent verbs (moons, beacons,
		# sentries, standing zones) otherwise pile up across 180 casts until
		# the whole run crawls and times out.
		for n2 in stage.get_children():
			if n2 == p:
				continue
			var k2 = n2.get("kind")
			var scr2 = n2.get_script()
			var is_ours: bool = (k2 != null and str(k2) != "")
			if scr2 != null and str(scr2.resource_path).ends_with("companion.gd"):
				is_ours = true
			if is_ours:
				n2.queue_free()
		var want: Array = KIND_ALIAS.get(stype, [stype])
		var best := 0
		for w in want:
			best = maxi(best, int(made.get(str(w), 0)))
		# A verb that declares a COUNT is promising a crowd. Firing one arrow
		# where the card says five is not a silent failure, but it is still
		# the verb not happening -- multi_shot has no dispatch at all and was
		# quietly loosing a single ordinary shaft.
		var want_n: int = maxi(1, int(sp.get("count", 1)))
		if COUNT_IS_A_CYCLE.has(stype):
			want_n = 1
		if best == 0:
			silent.append("%s (%s/%s) -> NOTHING fired; expected %s, got [%s]"
				% [id, str(row[2]), stype, ",".join(want),
					",".join(PackedStringArray(made.keys()))])
		elif best < want_n:
			undercount.append("%s (%s/%s) -> fired %d of the %d it promises"
				% [id, str(row[2]), stype, best, want_n])

	check("every weapon's verb actually fires when the weapon is used (%d checked)"
		% checked, silent.is_empty(), "\n        ".join(silent))
	check("every verb that promises a COUNT delivers it",
		undercount.is_empty(), "\n        ".join(undercount))
	_finish()

# instance ids of everything currently under the stage
func _snapshot(stage: Node) -> Dictionary:
	var seen := {}
	for n in stage.get_children():
		seen[n.get_instance_id()] = true
	return seen

func _settle(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout

func _finish() -> void:
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(0 if fails == 0 else 1)
