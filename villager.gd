extends Area2D

# Unique per-instance id so an already-rescued villager doesn't reappear (and
# get double-counted) when a save is continued -- see GameState.is_villager_rescued().
@export var villager_id: String = "villager_1"
@export var villager_name: String = "Elin"
@export var stat_name: String = "Farm"
@export var stat_value: int = 3
# Which building/role this villager is assigned to on rescue -- role_key is
# the building (e.g. "Farm"), role_title is their specific title there (e.g.
# "Farmer"). Two fields since some titles like "Leader" are shared across
# several buildings -- see building_roles.gd. Currently only role_key=="Farm"
# does anything (passive income, see GameState.generate_passive_income()).
@export var role_key: String = "Farm"
@export var role_title: String = "Farmer"
# Villagers are humans and have a sex ("Male"/"Female") -- used for pairing
# in mating houses (see house.gd). Enemies deliberately do NOT have this
# field; it's specific to villagers. Rescued villagers are always adults --
# only children born in mating houses start as kids.
@export var sex: String = "Female"
# One line of who they are / what happened to them, shown as a second
# notification right after the rescue confirmation. Kept vague about the
# enemy itself (still undecided) -- just the aftermath.
@export_multiline var backstory: String = "Rescued from the raid -- they'll need time to recover."

const PULSE_MIN_ALPHA = 0.55
const PULSE_MAX_ALPHA = 0.85
const RESCUE_FADE_DURATION = 0.6

# THE SORROW-CRYSTAL (GAME_BIBLE 4.2a): the taken stand frozen mid-motion,
# shackled to a crystal that actively drains their hope -- the physical
# mechanism of the Law of Despair. Freeing them means SHATTERING it, and the
# crystal is guarded: while anything hostile still stands in this pocket,
# the shackle holds. Stats are HIDDEN until they thaw at home -- every
# rescue is a wrapped gift. (The crystallized-despair material it should
# also pay out is 12-open -- identity and use undecided, deliberately
# unbuilt.)
const GUARD_RADIUS := 420.0
const CRYSTAL_COLOR = Color(0.55, 0.75, 0.95, 0.4)
const CRYSTAL_EDGE = Color(0.7, 0.6, 0.95, 0.8)

const NPC_SCRIPT = preload("res://npc.gd")
# Matches main.gd's VILLAGE_START_X/VILLAGE_Y -- used as a fallback spawn spot
# for a rescued villager's world avatar when they aren't pre-assigned to a
# specific building (role_key == "").
const VILLAGE_FALLBACK_POS = Vector2(4900.0, -100.0)

var player_inside = false
var is_rescued = false

var crystal: Node2D = null

func _ready() -> void:
	# Gone is GONE: already rescued (alive in the roster) OR rescued-then-lost
	# (permadeath -- lost_souls). Without the second check, a freed hostage who
	# later died left the roster and their crystal RESPAWNED on the road on the
	# next Continue (dev 2026-07-23: "after releasing them they should not be
	# visible"). The dungeon spawner always checked lost_souls; now the
	# hand-placed road crystals honor it too.
	if GameState.is_villager_rescued(villager_id) or GameState.lost_souls.has(villager_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	$PromptLabel.text = "[E] Shatter the Sorrow-Crystal — free " + villager_name
	build_crystal()
	start_pulse()

# The shell: a translucent prismatic diamond around the frozen figure, its
# facets breathing faintly -- unmistakably a PRISON, not a person standing.
func build_crystal() -> void:
	crystal = Node2D.new()
	add_child(crystal)
	var facet := Polygon2D.new()
	facet.polygon = PackedVector2Array([Vector2(0, -58), Vector2(24, -26), Vector2(0, 10), Vector2(-24, -26)])
	facet.color = CRYSTAL_COLOR
	crystal.add_child(facet)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(0, -58), Vector2(24, -26), Vector2(0, 10), Vector2(-24, -26), Vector2(0, -58)])
	edge.width = 2.0
	edge.default_color = CRYSTAL_EDGE
	crystal.add_child(edge)
	var t := crystal.create_tween()
	t.set_loops()
	t.tween_property(crystal, "modulate:a", 0.65, 1.2)
	t.tween_property(crystal, "modulate:a", 1.0, 1.2)

# 4.2a: the crystal is protected -- the pocket must be CLEARED first.
func guard_still_stands() -> bool:
	for e in get_tree().get_nodes_in_group("dungeon_combatant"):
		if not is_instance_valid(e) or e.is_in_group("player"):
			continue
		if "is_dead" in e and e.is_dead:
			continue
		if e.global_position.distance_to(global_position) <= GUARD_RADIUS:
			return true
	return false

func start_pulse() -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property($Body, "modulate:a", PULSE_MIN_ALPHA, 1.4)
	tween.tween_property($Body, "modulate:a", PULSE_MAX_ALPHA, 1.4)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not is_rescued:
		player_inside = true
		$PromptLabel.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		$PromptLabel.visible = false

func _process(_delta: float) -> void:
	if player_inside and not is_rescued and Input.is_action_just_pressed("interact"):
		rescue()

func rescue() -> void:
	# the shackle holds while the pocket's guard still stands (4.2a)
	if guard_still_stands():
		SpeechText.spawn(self, "The crystal's guard still stands — clear this pocket first.")
		if crystal:
			var flash = crystal.create_tween()
			flash.tween_property(crystal, "modulate", Color(1.6, 0.7, 0.7), 0.12)
			flash.tween_property(crystal, "modulate", Color(1, 1, 1), 0.25)
		return
	is_rescued = true
	$PromptLabel.visible = false
	GameState.rescue_villager({
		"id": villager_id,
		"name": villager_name,
		"sex": sex,
		"is_kid": false,
		"stat_name": stat_name,
		"stat_value": stat_value,
		"role_key": role_key,
		"role_title": role_title,
		"paired": false,
		# 4.2a: a frozen hostage shows NOTHING -- the gift unwraps at home
		"stats_hidden": true,
	})
	shatter_crystal()
	# the crystal's payout (4.2a): crystallized despair, pried loose -- the
	# stronger the soul it failed to break, the denser what's left behind
	var pl = get_tree().get_first_node_in_group("player")
	if pl and "inventory" in pl and pl.inventory:
		var shards := 2 if stat_value >= 5 else 1
		var left: int = pl.inventory.add_item("sorrowshard", shards)
		var got := shards - left
		if got > 0:
			SpeechText.spawn(self, "+%d Sorrowshard" % got)
		if left > 0:
			GameState.notify("Your bag is full — %d sorrowshard(s) left behind." % left)
	spawn_world_avatar()
	# A rescue is hard-won -- bank it NOW. The autosave is otherwise only every 180s
	# (and on floor-clear), so freeing someone then pressing Continue before that
	# fired brought the shattered Sorrow-Crystal BACK, the freed villager gone with it
	# (dev 2026-07-23: "after releasing them they should not be visible" on Continue).
	# is_villager_rescued() already gates the crystal's respawn; this makes the roster
	# entry it reads durable the instant you free them.
	GameState.autosave("freed %s" % villager_name)
	# the backstory is the villager SPEAKING -- floating text at their body,
	# not a corner notification. The mechanical reward stays WRAPPED (4.2a):
	# no stat in the toast; the reveal happens when they thaw at home.
	SpeechText.spawn(self, backstory)
	var notif = get_node_or_null("../CanvasLayer/NotificationStack")
	if notif:
		notif.show_notification("The Sorrow-Crystal shatters — %s is free. What they can do, you'll learn when they're home." % villager_name)
	monitoring = false
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($Body, "modulate:a", 0.0, RESCUE_FADE_DURATION)
	tween.tween_property($Restraint, "modulate:a", 0.0, RESCUE_FADE_DURATION)
	tween.tween_property(self, "position:y", position.y - 20.0, RESCUE_FADE_DURATION)
	tween.chain().tween_callback(queue_free)

# The breaking is INTERRUPTED drain -- the facets fly, the person thaws.
func shatter_crystal() -> void:
	if crystal == null:
		return
	for dir in [Vector2(-40, -30), Vector2(40, -30), Vector2(-30, 20), Vector2(30, 20)]:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(0, -8), Vector2(6, 2), Vector2(-5, 4)])
		shard.color = CRYSTAL_EDGE
		shard.position = Vector2(0, -24)
		add_child(shard)
		var st := shard.create_tween()
		st.set_parallel(true)
		st.tween_property(shard, "position", shard.position + dir, 0.5)
		st.tween_property(shard, "modulate:a", 0.0, 0.5)
		st.chain().tween_callback(shard.queue_free)
	crystal.queue_free()
	crystal = null

# Every rescued villager gets a real walking presence in the village, same as
# a child born from mating -- stats are never shown until this point (the
# pre-rescue hostage box has no hover/stat display at all), so nothing about
# them is visible early; this just stops them vanishing into pure data the
# instant they're freed.
func spawn_world_avatar() -> void:
	var village = get_node_or_null("../Village")
	if not village:
		return
	var npc = NPC_SCRIPT.new()
	npc.villager_id = villager_id
	npc.global_position = find_avatar_spawn_position(village)
	village.add_child(npc)

func find_avatar_spawn_position(village: Node) -> Vector2:
	if role_key != "":
		for child in village.get_children():
			if child.has_method("get_roles") and child.role_key == role_key:
				return child.global_position + Vector2(randf_range(-18.0, 18.0), -60.0)
	return VILLAGE_FALLBACK_POS
