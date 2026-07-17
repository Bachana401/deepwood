extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 900.0
const DASH_SPEED = 600.0
const DASH_DURATION = 0.15
const DOUBLE_TAP_WINDOW = 0.3
const DASH_COOLDOWN = 0.5

# Blink-dash bound to T -- now a REAL player ability granted only by the
# Shadowstep Sigil relic (relic_power "blink"), not an always-on admin power.
# Speed was halved (was 7x DASH_SPEED, far too OP) and the old 10-second
# god-mode invulnerability is now a short dodge i-frame, so it plays like a
# proper dodge-roll instead of "press T to be immortal".
const ADMIN_DASH_SPEED = DASH_SPEED * 3.5
const ADMIN_DASH_INVINCIBILITY_SECONDS = 0.6

const ARROW_SCENE = preload("res://arrow.tscn")

const SFX_SWORD = preload("res://audio/sword_swing.wav")
const SFX_SPEAR = preload("res://audio/spear_thrust.wav")
const SFX_BOW = preload("res://audio/bow_shot.wav")
const SFX_HURT = preload("res://audio/player_hurt.wav")
const SFX_DEATH = preload("res://audio/player_death.wav")
const SFX_JUMP = preload("res://audio/jump.wav")
const SFX_DASH = preload("res://audio/dash.wav")

# Base pool. 100 was fine for the early course but left the player a one-shot
# at the deep dungeon levels; 160 gives a real buffer that skill-tree HP nodes
# and armour/relics then build on for the L100 boss (whose eased curve now
# hits for ~200, survivable once you've progressed).
const MAX_HEALTH = 160
# --- Fall damage ---
# You take damage for landing after a fall taller than FALL_SAFE_DISTANCE.
# The safe distance sits comfortably above a double-jump's height so ordinary
# jumping never hurts; only real drops (high platforms, cliffs) do. Any
# equipped relic carrying "fall_immunity" (Aetherwing, Featherfall Charm)
# cancels it entirely. Tracked by fall APEX (position), since velocity.y is
# zeroed the instant you touch ground.
const FALL_SAFE_DISTANCE = 300.0
const FALL_DAMAGE_PER_PIXEL = 0.15
var fall_apex_y := 0.0
var was_grounded_fall := true
var has_touched_ground := false

# --- Flight (Aetherwing relic) ---
# Hold Space in the air to soar upward; a 10-second budget drains while flying
# and refills whenever you're on the ground. Releasing Space (or running the
# budget dry) lets you fall at NORMAL speed -- the wings just cancel the fall
# damage (via fall_immunity), they don't slow the drop.
const FLIGHT_MAX_SECONDS = 10.0
const FLIGHT_RISE_SPEED = -300.0   # brisk ascent while holding Space
var flight_time_left := FLIGHT_MAX_SECONDS
var flight_depleted_notified := false
var wings_left: Polygon2D = null
var wings_right: Polygon2D = null
var wing_flap_phase := 0.0

# --- Mana ---
# One shared pool under the HP bar. Today only wands spend it (their screen
# nuke finally has a real cost) and Soulthirst refills it on hit; future class
# abilities draw from the same pool. Gear can raise the cap (max_mana, flat)
# and speed the refill (mana_regen, fraction: 0.5 = +50%).
const BASE_MAX_MANA = 90.0    # up from 50 -- enough to actually cast through a boss fight
const BASE_MANA_REGEN = 4.0   # points per second
const DEFAULT_WAND_MANA_COST = 30
var mana: float = BASE_MAX_MANA
var mana_bar_fill: ColorRect = null
var mana_label: Label = null
const BOUNCE_DURATION = 0.1
const INVINCIBILITY_DURATION = 1.0
const DEATH_COUNTDOWN_SECONDS = 7.0
const CURRENCY_DROP_FRACTION = 0.77

const CURRENCY_PICKUP_SCRIPT = preload("res://currency_pickup.gd")
# Special-attack projectiles (flying slashes, javelins, fireballs, the hook,
# the boomerang...) -- launched by perform_attack from a weapon's "special".
const WEAPON_PROJECTILE_SCRIPT = preload("res://weapon_projectile.gd")

# 40 slots (8 rows of 5). The catalog keeps growing (30+ weapons, 20+ relics),
# and the test backfill drops a big pile of showpiece gear in at once, so the
# bag needs headroom. The inventory panel sizes itself from this (see
# inventory_ui.build_slots).
const INVENTORY_CAPACITY = 55
# 9999 starting gold was a debug leftover from before real inventory slots
# existed -- at 999/stack that alone would fill 10 of 15 slots on a brand
# new save. Dropped to a sane starting amount now that currency is a real
# stackable item.
const STARTING_CURRENCY = 50
# Silver/bronze are separate denominations, not automatically convertible to
# gold -- shop prices, the death drop, and passive income all still run on
# gold only. These starting amounts just give the player something to see
# and drag around immediately.
const STARTING_SILVER = 20
const STARTING_BRONZE = 15

# Enemy groups the player's area effects (wand nuke, Thundercaller chain) sweep.
# Includes the village siege attackers so those weapons help defend the walls.
const HOSTILE_GROUPS = ["course_enemy", "dungeon_combatant", "siege_enemy"]

# Every weapon is an inventory item now (see inventory.gd). The player wields
# ONE at a time by picking its inventory slot with the hotbar keys (1-9, 0).
# The active weapon's id/type/stats/def are cached here; "" = unarmed.
const HOTBAR_SIZE = 10
var active_weapon_id: String = ""
var active_weapon_type: String = ""   # "melee" | "spear" | "bow" | "wand"
var active_stats: Dictionary = {}
var active_def: Dictionary = {}
var selected_hotbar_slot: int = 0

var attack_cooldown_remaining = 0.0
var weapon_anim_tween: Tween = null
var spear_hit_bodies: Array = []
var is_attacking = false

# --- Levitation ---
# The character never physically holds weapons: he's a telekinetic -- his
# weapons FLOAT beside him wrapped in an arcane aura, moved by magic (that is
# why the body needs no per-weapon swing frames; the weapon itself moves).
# The Mage skill tree's "Levitate: Extended Reach/Distant Hand" nodes add
# levitate_range: the weapon then follows the mouse up to that far from his
# body and attacks there -- remote telekinetic strikes.
const LEVITATE_AURA_COLOR = Color(0.62, 0.42, 0.95, 0.28)
# On every left-click attack the hand flares with telekinetic energy for this
# long, so it reads as "he levitates/hurls the weapon" each time he strikes.
const LEVITATE_FLASH_TIME = 0.32
# How long the aim/levitation pose lingers after the last mouse move before he
# settles back to idle. Moving the cursor keeps refreshing it.
const MOUSE_AIM_HOLD = 0.35
# Innate free-float radius everyone has (the basic "Levitate" skill): even a
# Sword-class player's weapon drifts around him and can be tugged this far
# toward the cursor. The Mage tree's Levitate nodes add levitate_bonus_range()
# on top for true long-range telekinetic strikes.
const BASE_LEVITATE_RANGE = 26.0
var levitate_time := 0.0
var levitate_flash := 0.0       # counts down after each attack; drives the hand flare
var mouse_aim_timer := 0.0      # >0 briefly after the mouse moves -> play the aim/levitation frames
var aim_retract_timer := 0.0    # after the mouse stops, play the aim frames in REVERSE (hand retracts)
var aim_was_forward := false    # was he aiming last frame? (edge-detects the "mouse stopped" moment)
var aim_reversed := false       # currently playing the aim animation backwards?
var levitate_glow: Polygon2D = null
var hand_glow: Polygon2D = null
var levitate_sparkles: CPUParticles2D = null

func levitate_bonus_range() -> float:
	return GameState.get_skill_total("levitate_range")

# How far the weapon may float from the body: the innate short range plus any
# Mage Levitate skill bonus.
func levitate_max_range() -> float:
	return BASE_LEVITATE_RANGE + levitate_bonus_range()

# Hover rule (testable): the weapon follows the mouse but is bounded to
# [base_offset, base_offset + max_range] -- it never clips into the body and
# never floats past his telekinetic reach.
func clamped_hover(dist_to_mouse: float, base_offset: float) -> float:
	return clamp(dist_to_mouse, base_offset, base_offset + levitate_max_range())

func hover_for_mouse(base_offset: float) -> float:
	return clamped_hover((get_global_mouse_position() - global_position).length(), base_offset)

# A gentle, organic wander so the weapon reads as magically suspended -- it
# hovers and drifts a few px around its anchor rather than sitting rigidly.
func levitate_float_offset() -> Vector2:
	return Vector2(
		sin(levitate_time * 2.1) * 4.0 + sin(levitate_time * 0.9 + 0.7) * 2.2,
		cos(levitate_time * 1.7) * 3.6 + sin(levitate_time * 2.9 + 1.3) * 2.0)

func get_weapon_stats() -> Dictionary:
	return active_stats

func has_weapon() -> bool:
	return active_weapon_id != "" and not active_stats.is_empty()

var health = MAX_HEALTH
var invincible = false
# Absolute Time.get_ticks_msec()/1000.0 the current admin-dash invincibility
# window ends at -- lets a repeated T press extend the window without an
# earlier, still-pending "turn it off" call cutting it short.
var admin_invincible_until = 0.0
# GOD MODE (admin panel, P). One switch, three powers, so the map can be roamed
# and new content reached fast: nothing can hurt you, T blink-dashes without the
# Shadowstep Sigil, and you fly on Space without the Aetherwing -- on an
# unlimited budget, because a 10s wing that strands you mid-map is no use for
# testing. Purely a test tool: it grants nothing the player can earn, and every
# gate it opens is checked against god_mode ONLY here (see has_flight, the T
# dash in _physics_process, and take_damage).
var god_mode := false
var knockback_immune_until := 0.0   # no re-knockback until this time (post-hit window)
var is_dead = false
var undying_used := false   # Living Fortress: the once-per-life lethal-hit save has fired

# currency is now a real inventory item ("coin_gold") instead of a bare int
# -- this property just proxies to the inventory so every EXISTING call site
# (player.currency >= X, player.currency -= X, save/load, etc.) keeps
# working unchanged. The inventory itself is the actual source of truth.
# Silver/bronze coins exist in the inventory too but are separate items --
# "currency" only ever means gold.
var inventory: Inventory = Inventory.new(INVENTORY_CAPACITY)
var currency: int:
	get:
		return inventory.get_count("coin_gold")
	set(value):
		var delta = value - inventory.get_count("coin_gold")
		if delta > 0:
			inventory.add_item("coin_gold", delta)
		elif delta < 0:
			inventory.remove_item("coin_gold", -delta)

var facing_direction = 1
var original_color: Color
var spawn_position: Vector2
var has_double_jump = false
var jumps_used = 0
var has_dash = false
var is_dashing = false
var is_knocked_back = false
var last_left_press_time = -10.0
var last_right_press_time = -10.0
var last_dash_time = -10.0
var invincibility_tween: Tween = null

var helmet_visual: Polygon2D = null
var chest_visual: Polygon2D = null
var pants_visual: Polygon2D = null
var weapon_guard: ColorRect = null

# Pixel-art body = an AnimatedSprite2D assembled from PNGs in art/. Drop
# numbered frames (from 1) to fill each state:
#   player_idle_N.png / player_walk_N.png / player_jump_N.png / player_attack_N.png
# A single player_idle.png (or player.png) also works as a one-frame idle. Any
# state with no frames of its own falls back to the idle frame -- and if that
# fallback is a single frame, a gentle procedural walk-bob keeps it alive. No
# art at all -> the placeholder box. All hit-flash/death tint drives body_visual.
const IDLE_SINGLE_PATHS = ["res://art/player_idle.png", "res://art/player.png"]
const SPRITE_TARGET_HEIGHT = 56.1   # 66 - 15% (character shrunk to suit the bigger village)

# From 5/7 the hero pulls his hood up and hides his face -- he has gone so
# corpse-pale that he will not be looked at (the awakening line at that stage is
# literally "The hood hides what you are becoming"). That's a SEPARATE skin
# folder: the base hero art is never touched, and if art/hooded/ is absent he
# simply stays bare-headed at every stage. See refresh_monarch_skin.
const BASE_ART := "res://art/player_"
const HOODED_ART := "res://art/hooded/player_"
const HOOD_STAGE := 5
var _hooded := false
var _art_prefix := BASE_ART
const WALK_BOB_AMP = 2.5
const WALK_BOB_SPEED = 12.0
# procedural "juice" tuning (all applied on top of the single idle sprite)
const RUN_LEAN_DEG = 3.0
const DASH_LEAN_DEG = 14.0
const LAND_SQUASH_TIME = 0.16
const HURT_SHAKE_TIME = 0.28
# Every player action is its own animation. Drop numbered frames in art/ to
# fill any of them (e.g. player_walk_1.png, player_walk_2.png, player_jump_1.png,
# player_death_1.png ...). Anything you haven't drawn yet falls back to the idle
# frame + procedural motion, so states light up one at a time as you add art.
# NOTE (developer decision 2026-07-14): attacking / mouse movement plays NO
# body animation -- the weapon's own visuals carry the attack. The body only
# ever plays movement states. Each jump in the chain gets its own animation.
const ANIM_DEFS = [
	{"name": "idle", "fps": 8.0, "loop": true},   # 8-frame fight-stance idle (PixelLab)
	{"name": "walk", "fps": 12.0, "loop": true},  # filled with RUN frames -- A/D reads as running
	{"name": "jump", "fps": 8.0, "loop": false},  # first jump
	{"name": "jump2", "fps": 10.0, "loop": false},# double jump (its own animation)
	{"name": "jump3", "fps": 10.0, "loop": false},# triple jump (its own animation, future skill)
	{"name": "fall", "fps": 8.0, "loop": false},
	{"name": "land", "fps": 14.0, "loop": false},
	{"name": "dash", "fps": 12.0, "loop": false},
	{"name": "hurt", "fps": 12.0, "loop": false},
	{"name": "death", "fps": 8.0, "loop": false},
]
var body_anim: AnimatedSprite2D = null
var body_visual: CanvasItem = null
var anim_base_y = 0.0
var base_scale := Vector2.ONE
var real_anims: Dictionary = {}  # which states have their own frames (vs idle fallback)
var current_jump_anim := "jump"  # which jump of the chain is playing (jump / jump2 / jump3)
var was_on_floor := true
var land_timer := 0.0
var hurt_timer := 0.0
var afterimage_cd := 0.0

func _ready() -> void:
	original_color = $ColorRect.color
	spawn_position = global_position
	$AttackArea/CollisionShape2D.shape = $AttackArea/CollisionShape2D.shape.duplicate()
	$SpearTipArea.body_entered.connect(_on_spear_tip_hit)
	# worn-gear visuals + the held-weapon crossguard are built before any
	# equip call so equip_weapon/on_equipment_changed can drive them.
	build_armor_visuals()
	build_weapon_guard()
	build_levitate_aura()
	build_wings_visual()
	build_mana_bar()
	# keep the held weapon drawn in front of the body armor
	$WeaponIcon.z_index = 3
	$BowVisual.z_index = 3
	$WeaponTip.z_index = 3
	setup_body_anim()
	# a save loaded at 5/7+ (or a dungeon re-entry) must come up hooded already,
	# not spend a frame bare-headed before monarch_tick catches it
	refresh_monarch_skin()
	build_shadow_aura()
	# entering/exiting the dungeon interior is a real scene transition, which
	# re-instances (and re-_ready()s) a fresh Player -- restore the carried-
	# over state instead of re-granting starting resources in that case.
	if not GameState.pending_player_state.is_empty():
		apply_pending_player_state()
	else:
		# weapons FIRST so they land in the first hotbar slots (1=sword, 2=spear,
		# 3=bow, 4=wand, 5=Vampiric Fang, 6=Thundercaller) for easy testing.
		grant_starter_weapons()
		# the real game starts with NO money -- gold is earned from kills + the
		# village economy. --dev seeds a purse so the shop can be tried at once.
		if GameState.dev_mode:
			inventory.add_item("coin_gold", STARTING_CURRENCY)
			inventory.add_item("coin_silver", STARTING_SILVER)
			inventory.add_item("coin_bronze", STARTING_BRONZE)
		grant_starter_gear()
		wield_weapon("wpn_sword")
	# admin Ruin Wand + flight relics are guaranteed present. On a NEW game
	# this call sticks; on CONTINUE, main.gd's apply_save_data() reloads the
	# saved inventory AFTER this _ready() and would wipe them, so main.gd calls
	# ensure_test_items() again once the save is loaded (same for dungeon
	# returns via apply_pending_player_state above).
	ensure_test_items()
	# fall-damage tracking baseline (don't count the spawn drop as a fall)
	fall_apex_y = global_position.y
	was_grounded_fall = is_on_floor()
	# armor/relic bonuses + HP sync (survives dungeon scene swaps)
	on_equipment_changed()
	update_currency_display()
	update_health_display()
	update_mana_display()
	# the opening plea (once, on a fresh real game, in the village)
	call_deferred("maybe_play_intro")

# Fires the scripted opening the first time a new game begins in the village.
# Skipped on Continue (seen_intro persisted), inside the dungeon, and in dev mode.
func maybe_play_intro() -> void:
	if GameState.dev_mode or GameState.seen_intro or GameState.in_dungeon:
		return
	GameState.seen_intro = true
	DialogueBox.play(self, Story.OPENING)

# TEST: hands the player every basic weapon at the start so the whole hotbar
# is usable immediately (1=sword ... 6=Thundercaller, 7=ADMIN Ruin Wand,
# 8=axe, 9=pickaxe). Set gear and the newer Excellent weapons are NOT granted
# -- they drop from dungeon bosses (see dungeon_interior.gd roll_gear_drop).
func grant_starter_weapons() -> void:
	# The REAL game starts weak: just a plain sword and the two gathering tools
	# (needed for the repair loop). The spear/bow are shop purchases, and every
	# Excellent/set weapon is dungeon loot. --dev restores the full test hotbar.
	# NB: wpn_wand (classic screen-nuke) is an admin item, never a player weapon.
	var starter = ["wpn_sword", "tool_axe", "tool_pickaxe"]
	if GameState.dev_mode:
		starter = ["wpn_sword", "wpn_spear", "wpn_bow", "exc_vampiric", "exc_thunder", "wpn_admin_ruin", "tool_axe", "tool_pickaxe"]
	for item_id in starter:
		inventory.add_item(item_id, 1)

# All the guaranteed-for-testing items in one call, safe to run repeatedly.
# MUST run after any inventory load (new-game grant, Continue's save load, or
# dungeon-return snapshot) or the load overwrites what it added.
func ensure_test_items() -> void:
	# ALL test scaffolding (admin wand, flight relics, showpiece gear) is dev-only.
	# In the real game this is a no-op, so a New Game / Continue stays honest.
	if not GameState.dev_mode:
		return
	ensure_admin_wand()
	ensure_flight_relics_for_test()
	# test scaffolding: the showpiece weapons + OP relics on hand immediately so
	# they can be tried without farming dungeon drops. Remove once done testing.
	var test_gear = [
		"exc_ragnarok", "exc_wizardsbane", "wpn_tempest", "exc_doom", "exc_singularity",
		"exc_worldsplitter", "exc_dawnbreaker",
		"relic_godheart", "relic_warlord", "relic_fortune", "relic_celerity",
		"relic_phoenix", "relic_thorns", "relic_aegis", "relic_vampire", "relic_juggernaut",
		# batch: new weapons (maces/javelins/daggers/caster mythics)
		"wpn_dagger", "wpn_mace", "wpn_greatsword", "wpn_warhammer", "wpn_javelin", "wpn_harpoon",
		"exc_earthshaker", "exc_gungnir", "exc_shadowblade", "exc_frostmourne", "exc_voidcaller", "exc_stormfury",
		# batch: gloves + boots + the Dragonscale 5-slot set
		"gloves_assassin", "boots_storm", "gloves_titan", "boots_titan",
		"helm_dragon", "armor_dragon", "pants_dragon", "gloves_dragon", "boots_dragon",
		# batch: consumables + crafting ingredients
		"potion_health", "potion_mana", "food_stew", "food_feast", "food_sage",
		"herb", "raw_meat",
		# batch: status wands + on-kill/ward/economy relics
		"exc_voidcaller", "wpn_iciclewand", "relic_reaper", "relic_ward", "relic_steward",
	]
	var equipped_ids = GameState.get_equipped_item_ids()
	for gid in test_gear:
		if inventory.get_count(gid) == 0 and active_weapon_id != gid and not (gid in equipped_ids):
			inventory.add_item(gid, 1)
	# top up crafting ingredients so recipes can be tried (only once, on the
	# first load that has none)
	if inventory.get_count("herb") < 6:
		inventory.add_item("herb", 6 - inventory.get_count("herb"))
	if inventory.get_count("raw_meat") < 6:
		inventory.add_item("raw_meat", 6 - inventory.get_count("raw_meat"))
	# a load happened -> the UI panels may be showing a stale bag; refresh them
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui and inv_ui.has_method("refresh"):
		inv_ui.refresh()

# The admin Ruin Wand should always be on hand for testing, even on saves
# made before it existed. If it's already somewhere (bag or wielded) do
# nothing; otherwise drop it into hotbar slot 7 (index 6) when that slot is
# free, else the first open slot.
func ensure_admin_wand() -> void:
	if inventory.get_count("wpn_admin_ruin") > 0 or active_weapon_id == "wpn_admin_ruin":
		return
	if inventory.slots.size() > 6 and inventory.slots[6] == null:
		inventory.slots[6] = {"item_id": "wpn_admin_ruin", "count": 1}
	else:
		inventory.add_item("wpn_admin_ruin", 1)

# Test scaffolding: make sure the flight relics exist so wings can be tried
# right away, even on a save from before they existed, and auto-equip the
# Aetherwing into a free relic slot so flight works without opening the gear
# panel first. (They also drop legitimately from dungeon bosses -- see
# dungeon_interior.gd GEAR_RELIC_IDS. Remove this once flight is dialed in.)
func ensure_flight_relics_for_test() -> void:
	var equipped = GameState.get_equipped_item_ids()
	for rid in ["relic_wings", "relic_feather", "relic_blink"]:
		if inventory.get_count(rid) == 0 and not (rid in equipped):
			inventory.add_item(rid, 1)
	# auto-equip the flight wings + Shadowstep Sigil so flight (Space) and the
	# blink-dash (T) both work immediately for testing
	for rid in ["relic_wings", "relic_blink"]:
		if not (rid in GameState.get_equipped_item_ids()) and inventory.get_count(rid) > 0:
			var slot = GameState.first_empty_relic_slot()
			if slot >= 0:
				GameState.equip_item(rid, self, slot)

# Temporary: sample armor + relics so the equipment panel is usable. Weapons
# are granted separately (grant_starter_weapons). Replaced by loot later.
func grant_starter_gear() -> void:
	# a basic leather kit to start; relics are loot, so --dev seeds two for testing
	var gear = ["helm_leather", "armor_leather", "pants_leather"]
	if GameState.dev_mode:
		gear.append_array(["relic_vigor", "relic_swiftness"])
	for item_id in gear:
		inventory.add_item(item_id, 1)

# --- worn-gear visuals (helmet / chest / pants overlays on the body) ---
# The body ColorRect spans x[-16,16] y[-24,24]. These sit over the head,
# torso, and legs, tinted to the equipped item's colour and shown/hidden by
# update_armor_visuals(). Relics deliberately have no worn visual.
func build_armor_visuals() -> void:
	helmet_visual = Polygon2D.new()
	helmet_visual.polygon = PackedVector2Array([
		Vector2(-17, -9), Vector2(-17, -17), Vector2(-12, -24), Vector2(0, -27),
		Vector2(12, -24), Vector2(17, -17), Vector2(17, -9),
	])
	helmet_visual.z_index = 1
	helmet_visual.visible = false
	add_child(helmet_visual)

	chest_visual = Polygon2D.new()
	chest_visual.polygon = PackedVector2Array([
		Vector2(-16, -8), Vector2(16, -8), Vector2(15, 11), Vector2(-15, 11),
	])
	chest_visual.z_index = 1
	chest_visual.visible = false
	add_child(chest_visual)

	pants_visual = Polygon2D.new()
	pants_visual.polygon = PackedVector2Array([
		Vector2(-15, 11), Vector2(15, 11), Vector2(15, 24), Vector2(4, 24),
		Vector2(2, 15), Vector2(-2, 15), Vector2(-4, 24), Vector2(-15, 24),
	])
	pants_visual.z_index = 1
	pants_visual.visible = false
	add_child(pants_visual)

func update_armor_visuals() -> void:
	# With the real character sprite active, the flat placeholder armor overlays
	# would only clutter it -- keep them hidden (armor still applies its stats;
	# real gear sprites will layer here later). The box fallback still shows them.
	if body_anim:
		if helmet_visual: helmet_visual.visible = false
		if chest_visual: chest_visual.visible = false
		if pants_visual: pants_visual.visible = false
		return
	_apply_armor_piece(helmet_visual, GameState.equipment.get("helmet", ""))
	_apply_armor_piece(chest_visual, GameState.equipment.get("chest", ""))
	_apply_armor_piece(pants_visual, GameState.equipment.get("pants", ""))

func _apply_armor_piece(node: Polygon2D, item_id: String) -> void:
	if not node:
		return
	if item_id == "":
		node.visible = false
	else:
		node.visible = true
		node.color = Inventory.get_item_def(item_id).get("color", Color(0.5, 0.5, 0.5, 1))

# A small perpendicular crossguard child of the WeaponIcon (so it inherits
# the icon's swing/aim transform automatically) -- makes melee weapons read
# as bladed weapons rather than plain bars. Hidden for bow/wand.
func build_weapon_guard() -> void:
	weapon_guard = ColorRect.new()
	weapon_guard.color = Color(0.32, 0.24, 0.14, 1.0)
	weapon_guard.visible = false
	weapon_guard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$WeaponIcon.add_child(weapon_guard)

# The telekinesis dressing: a soft violet aura that hangs around the floating
# weapon, faint sparkles drifting off it, and a small glow at the character's
# hand -- together they read as "he is holding the weapon with magic".
func build_levitate_aura() -> void:
	var add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	levitate_glow = Polygon2D.new()
	levitate_glow.polygon = _levitate_circle(16.0, 18)
	levitate_glow.color = LEVITATE_AURA_COLOR
	levitate_glow.material = add_mat
	levitate_glow.z_index = 2   # just under the weapon (z 3)
	levitate_glow.visible = false
	add_child(levitate_glow)

	hand_glow = Polygon2D.new()
	hand_glow.polygon = _levitate_circle(5.0, 12)
	hand_glow.color = Color(0.7, 0.5, 1.0, 0.5)
	hand_glow.material = add_mat
	hand_glow.z_index = 4   # over the body, near his hand
	hand_glow.visible = false
	add_child(hand_glow)

	levitate_sparkles = CPUParticles2D.new()
	levitate_sparkles.amount = 8
	levitate_sparkles.lifetime = 0.7
	levitate_sparkles.direction = Vector2(0, -1)
	levitate_sparkles.spread = 180.0
	levitate_sparkles.gravity = Vector2(0, -26)
	levitate_sparkles.initial_velocity_min = 4.0
	levitate_sparkles.initial_velocity_max = 14.0
	levitate_sparkles.scale_amount_min = 0.8
	levitate_sparkles.scale_amount_max = 1.8
	levitate_sparkles.color = Color(0.75, 0.55, 1.0, 0.8)
	levitate_sparkles.z_index = 2
	levitate_sparkles.emitting = false
	add_child(levitate_sparkles)

# --- The Shadow Monarch aura (hidden 7-stage passive, see GameState) ---
# A real animated shadow aura (PixelLab, art/shadow_aura_N.png) layered BEHIND
# the body that GROWS with the monarch stage -- from a tight wisp at 1/7 to an
# engulfing storm at 7/7 -- plus a paling shader that drains the sprite's colour
# toward corpse-pale. Driven by GameState.monarch_stage()/monarch_intensity();
# purely visual, the power itself rides get_bonus_total.
const SHADOW_AURA_FRAMES := 13
var shadow_aura: AnimatedSprite2D = null
var shadow_emit: CPUParticles2D = null   # dark wisps pouring OFF his body (the "source")
var monarch_shader_mat: ShaderMaterial = null
var _aura_stage := -1
var _aura_pulse := 0.0

func build_shadow_aura() -> void:
	# NOTE: load the FULL 128x128 frames directly -- NOT via load_texture(), which
	# auto-trims + bottom-anchors for characters and would shove this radial aura
	# off-centre. Keeping the whole canvas means centered=true lands its true
	# centre behind the body.
	var frames: Array = []
	for i in range(1, SHADOW_AURA_FRAMES + 1):
		var path = "res://art/shadow_aura_%d.png" % i
		if not ResourceLoader.exists(path):
			break
		var t = load(path)
		if t == null:
			break
		frames.append(t)
	if not frames.is_empty():
		var sf = SpriteFrames.new()
		sf.remove_animation("default")
		sf.add_animation("swirl")
		sf.set_animation_loop("swirl", true)
		sf.set_animation_speed("swirl", 12.0)
		for tex in frames:
			sf.add_frame("swirl", tex)
		shadow_aura = AnimatedSprite2D.new()
		shadow_aura.name = "ShadowAura"
		shadow_aura.sprite_frames = sf
		shadow_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# z 0 (NOT negative): a negative z dropped it below the whole world so
		# buildings/mountains covered it. At z 0 it sits in the player's own draw
		# plane (above the world, like his body) and is kept BEHIND the body by
		# child order (move_child below).
		shadow_aura.z_index = 0
		shadow_aura.position = Vector2(0, -4)    # the body's visual centre (feet +24, height 56)
		shadow_aura.visible = false
		shadow_aura.play("swirl")
		add_child(shadow_aura)
	# Dark shadow wisps that EMIT from his body (a rectangle over the torso) and
	# stream outward -- this makes HIM read as the source of the shadow, not a
	# disc pasted behind him.
	shadow_emit = CPUParticles2D.new()
	shadow_emit.name = "ShadowEmit"
	shadow_emit.z_index = 0                   # same plane as the body; ordered behind it below
	shadow_emit.position = Vector2(0, -4)    # the body's visual centre
	shadow_emit.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	shadow_emit.emission_rect_extents = Vector2(10, 26)  # spans head-to-ankles
	shadow_emit.direction = Vector2(0, -1)
	shadow_emit.spread = 180.0               # billow out in every direction
	shadow_emit.gravity = Vector2(0, -10)    # drift up as it dissipates
	shadow_emit.initial_velocity_min = 8.0
	shadow_emit.initial_velocity_max = 26.0
	shadow_emit.lifetime = 0.9
	shadow_emit.amount = 8
	shadow_emit.scale_amount_min = 1.4
	shadow_emit.scale_amount_max = 3.0
	var ramp = Gradient.new()               # fade dark -> transparent
	ramp.set_color(0, Color(0.13, 0.04, 0.22, 0.72))
	ramp.set_color(1, Color(0.05, 0.02, 0.10, 0.0))
	shadow_emit.color_ramp = ramp
	shadow_emit.emitting = false
	add_child(shadow_emit)
	# paling shader on the body sprite (real desaturation + lift, not just modulate,
	# so hit-flash / invincibility modulate still layer on top cleanly)
	if body_anim != null:
		monarch_shader_mat = ShaderMaterial.new()
		var sh = Shader.new()
		sh.code = "shader_type canvas_item;\nuniform float pallor : hint_range(0.0,1.0) = 0.0;\nvoid fragment(){\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat g = dot(c.rgb, vec3(0.299,0.587,0.114));\n\tvec3 pale = vec3(g)*1.1 + 0.06;\n\tpale = mix(pale, vec3(0.72,0.74,0.82), 0.25);\n\tCOLOR = vec4(mix(c.rgb, pale, pallor), c.a);\n}"
		monarch_shader_mat.shader = sh
		body_anim.material = monarch_shader_mat
	# Draw order: at equal z the child list decides. Put the aura + wisps just
	# BEHIND the body so they sit behind him but still in the player's above-world
	# plane (aura -> wisps -> body).
	if body_anim != null:
		if shadow_aura != null:
			move_child(shadow_aura, body_anim.get_index())
		move_child(shadow_emit, body_anim.get_index())

func update_shadow_aura(delta: float) -> void:
	var stage = GameState.monarch_stage()
	var inten = GameState.monarch_intensity()
	if monarch_shader_mat != null:
		var pallor = clampf((inten - 0.12) / 0.7, 0.0, 1.0) * 0.85
		monarch_shader_mat.set_shader_parameter("pallor", pallor)
	# SIZE stays a faint whisper early (eased hard); COLOUR/OPACITY ramps up a bit
	# sooner so it never reads as a dull transparent smudge.
	var e = pow(inten, 2.0)
	var ci = pow(inten, 1.4)
	_aura_pulse += delta
	var breathe = 1.0 + 0.10 * sin(_aura_pulse * 2.6)   # slow living pulse
	# tendril layer: grows richer + less transparent + a glowing violet cast per
	# stage, with a gentle breathing pulse so it feels alive
	if shadow_aura != null:
		shadow_aura.visible = stage >= 1
		if stage >= 1:
			var sc = lerpf(0.12, 1.25, e) * (0.97 + 0.03 * sin(_aura_pulse * 2.6))
			if monarch_true_form_active:
				sc *= 1.7   # the true form's aura swallows him whole
			shadow_aura.scale = Vector2(sc, sc)
			var a = clampf(lerpf(0.24, 1.0, ci) * breathe, 0.0, 1.0)
			shadow_aura.modulate = Color(1.0 + 0.28 * ci, 0.82 - 0.06 * ci, 1.0 + 0.6 * ci, a)
	# emitted wisps pouring off his body -- the "source". Reallocate particle
	# params only when the stage actually changes (amount realloc is not free).
	if shadow_emit != null:
		shadow_emit.emitting = stage >= 1
		if stage != _aura_stage:
			_aura_stage = stage
			shadow_emit.amount = maxi(1, int(lerpf(2.0, 46.0, e)))
			shadow_emit.initial_velocity_max = lerpf(9.0, 46.0, e)
			shadow_emit.scale_amount_max = lerpf(1.3, 4.4, e)
			# vivid violet that deepens + gets less transparent as the stage climbs
			shadow_emit.color_ramp.set_color(0, Color(0.52, 0.2, 0.98, lerpf(0.35, 1.0, ci)))
			shadow_emit.color_ramp.set_color(1, Color(0.16, 0.04, 0.32, 0.0))

# ========================= THE SHADOW MONARCH'S POWERS ========================
# The OP half of the hidden 7-stage passive (design: VILLAGE_SYSTEMS.md 8b).
#   3/7 Shadowstep      -- dashes have full i-frames + a torn-shadow trail
#   4/7 Dread Sovereign -- a constant aura of dread slows every foe near you
#   5/7 Rise, Shade     -- kills tear the foe's shadow free to fight for you
#   6/7 The Long Dark   -- a lethal hit melts you into shadow, not a grave
#   7/7 true form       -- 2x size, permanent shades, shadow novas, doubled
#                          lifesteal. It only fully manifests when no villager
#                          is left alive to see it (or forced from the P panel).

const LONG_DARK_COOLDOWN := 75.0
const LONG_DARK_DURATION := 2.6
const DREAD_AURA_RADIUS := 170.0
const NOVA_PERIOD := 5.0
const NOVA_RADIUS := 260.0
const SHADE_LIFETIME := 12.0

var monarch_iframes_until := 0.0
var monarch_long_dark_ready_at := 0.0
var monarch_dread_accum := 0.0
var monarch_nova_accum := 0.0
var monarch_shades: Array = []
var monarch_true_form_active := false
var monarch_scale_mult := 1.0

func monarch_tick(delta: float) -> void:
	var stage = GameState.monarch_stage()
	refresh_monarch_skin()   # the hood goes up at 5/7 (no-op unless that changed)
	# Dread Sovereign (4/7+): proximity to the Monarch is itself a wound --
	# foes near you move as if wading through the dark.
	if stage >= 4 and not is_dead:
		monarch_dread_accum += delta
		if monarch_dread_accum >= 0.5:
			monarch_dread_accum = 0.0
			for group_name in HOSTILE_GROUPS:
				for e in get_tree().get_nodes_in_group(group_name):
					if not is_instance_valid(e) or not e.has_method("apply_status"):
						continue
					if "is_dead" in e and e.is_dead:
						continue
					if global_position.distance_to(e.global_position) <= DREAD_AURA_RADIUS:
						e.apply_status("slow", 0.8, 0.62)
	# the true form manifests/withdraws by itself the moment its condition flips
	var tf: bool = GameState.monarch_true_form()
	if tf != monarch_true_form_active:
		monarch_true_form_active = tf
		_apply_true_form(tf)
	if tf and not is_dead:
		monarch_nova_accum += delta
		if monarch_nova_accum >= NOVA_PERIOD:
			monarch_nova_accum = 0.0
			fire_shadow_nova()

func _apply_true_form(on: bool) -> void:
	# The 2x god-form is VISUAL scale only (collision untouched, so gameplay
	# stays fair): base_scale feeds every animated pose, and feet_anchor_y()
	# re-plants the giant's feet on the ground line every frame.
	var m: float = 1.6 if on else 1.0
	base_scale = base_scale / monarch_scale_mult * m
	monarch_scale_mult = m
	if on:
		spawn_shock_ring(global_position, NOVA_RADIUS, Color(0.55, 0.2, 1.0, 0.95))
		if has_node("Camera2D"):
			$Camera2D.shake(10.0, 0.5)
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("There is no one left to hide from. The Shadow Monarch stands revealed.")

# Rise, Shade (5/7+): the slain foe's shadow tears free of the ground and
# serves. Temporary soldiers below 7/7; the true form keeps a standing army.
func raise_shade() -> void:
	monarch_shades = monarch_shades.filter(func(s): return is_instance_valid(s))
	var true_form: bool = GameState.monarch_true_form()
	var cap: int = 4 if true_form else 2
	if monarch_shades.size() >= cap:
		return
	var shade = load("res://shade.gd").new()
	shade.owner_player = self
	shade.damage = int(round((8.0 + GameState.player_level * 0.55) * (1.6 if true_form else 1.0)))
	shade.expires_at = 0.0 if true_form else (_now() + SHADE_LIFETIME)
	get_parent().add_child(shade)
	shade.global_position = global_position + Vector2(randf_range(-26.0, 26.0), 0.0)
	monarch_shades.append(shade)

# The true form's heartbeat: every few seconds the dark detonates outward.
# Only rings visibly when it actually catches someone -- no spam in the village.
func fire_shadow_nova() -> void:
	var dmg = 30 + GameState.player_level
	var hit := 0
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) <= NOVA_RADIUS:
				e.take_damage(dmg)
				hit += 1
	if hit > 0:
		spawn_shock_ring(global_position, NOVA_RADIUS, Color(0.5, 0.15, 0.95, 0.9))

# The Long Dark (6/7+): death reached for you and closed on shadow. The body
# melts into living dark -- unkillable while it knits itself back together.
func enter_long_dark() -> void:
	health = 1
	update_health_display()
	invincible = true
	stop_invincibility_flash()
	body_visual.modulate = Color(0.08, 0.02, 0.16, 0.85)
	spawn_shock_ring(global_position, 200.0, Color(0.45, 0.1, 0.9, 0.95))
	if has_node("Camera2D"):
		$Camera2D.shake(8.0, 0.4)
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("The Long Dark: death reached for you and closed on shadow.")
	# knit back to 40% HP across the shadow-form, then reform in flesh
	var heal_target = int(get_max_health() * 0.40)
	var steps := 8
	for i in range(steps):
		await get_tree().create_timer(LONG_DARK_DURATION / steps).timeout
		if is_dead:
			return
		health = mini(get_max_health(), maxi(health, int(round(lerpf(1.0, float(heal_target), float(i + 1) / steps)))))
		update_health_display()
	body_visual.modulate = Color(1, 1, 1, 1)
	invincible = false

# Two feathered wings on the character's back, hidden until the Aetherwing
# relic is equipped. They sit behind the body (z -1) and flap -- fast while
# actively flying, a slow idle sway otherwise.
func build_wings_visual() -> void:
	wings_left = _make_wing(-1)
	wings_right = _make_wing(1)
	wings_left.visible = false
	wings_right.visible = false
	add_child(wings_left)
	add_child(wings_right)

func _make_wing(dir: int) -> Polygon2D:
	var wing = Polygon2D.new()
	wing.polygon = PackedVector2Array([
		Vector2(0, -4), Vector2(dir * -22, -20), Vector2(dir * -30, -6),
		Vector2(dir * -24, 2), Vector2(dir * -30, 10), Vector2(dir * -18, 12), Vector2(0, 8)])
	wing.color = Color(0.92, 0.95, 1.0, 0.92)
	wing.position = Vector2(dir * 5, -4)
	wing.z_index = -1
	return wing

func update_wings(flying: bool) -> void:
	if not wings_left:
		return
	var winged = has_flight()
	wings_left.visible = winged
	wings_right.visible = winged
	if not winged:
		return
	wing_flap_phase += get_physics_process_delta_time() * (22.0 if flying else 4.0)
	var amp = 0.6 if flying else 0.16
	var flap = sin(wing_flap_phase) * amp
	wings_left.rotation = flap
	wings_right.rotation = -flap

func _levitate_circle(radius: float, sides: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(sides):
		var ang = TAU * float(i) / sides
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts

# Follows the floating weapon every frame: glow + sparkles wrap the weapon's
# visual centre, the hand glow sits at his side toward it, and the aura gently
# pulses. Hidden when unarmed.
# Duration of one play-through of the aim animation (used to time the retract).
func _aim_length() -> float:
	if body_anim and body_anim.sprite_frames.has_animation("aim"):
		var n = body_anim.sprite_frames.get_frame_count("aim")
		var fps = body_anim.sprite_frames.get_animation_speed("aim")
		if fps > 0.0:
			return float(n) / fps
	return 0.3

# Left-click "cast": the hand orb flares and a fresh puff of telekinetic
# sparkles bursts, so every strike reads as him hurling the levitated weapon.
func trigger_levitate_flash() -> void:
	levitate_flash = LEVITATE_FLASH_TIME
	if levitate_sparkles and has_weapon():
		levitate_sparkles.restart()

func update_levitate_aura(aim_dir: Vector2, hover: float, free_float: Vector2 = Vector2.ZERO) -> void:
	if not levitate_glow:
		return
	var armed = has_weapon()
	levitate_glow.visible = armed
	hand_glow.visible = armed
	levitate_sparkles.emitting = armed
	if not armed:
		return
	var reach = active_stats.icon_size.x if active_weapon_type != "bow" else 0.0
	var center = aim_dir * (hover + reach * 0.5) + free_float
	# flash: 1.0 right after a click, decaying to 0 -- the telekinetic "cast" pop
	var flash = levitate_flash / LEVITATE_FLASH_TIME
	var pulse = 1.0 + 0.12 * sin(levitate_time * 3.2) + flash * 0.5
	levitate_glow.position = center
	levitate_glow.scale = Vector2.ONE * pulse * max(1.0, max(active_stats.icon_size.x, active_stats.icon_size.y) / 22.0)
	levitate_sparkles.position = center
	# hand orb sits at the leading hand and swells + brightens as he hurls it
	hand_glow.position = aim_dir * 10.0 + Vector2(0, -6)
	hand_glow.scale = Vector2.ONE * (1.0 + 0.2 * sin(levitate_time * 5.1) + flash * 1.7)
	hand_glow.modulate = Color(1, 1, 1, 1.0 + flash * 1.6)

# Swaps the placeholder box for the pixel-art sprite when the art exists.
# Scaled by height and feet-aligned to the bottom of the collision body so it
# stands on the ground; falls back to the ColorRect box if the file is missing.
func setup_body_anim() -> void:
	var frames = build_sprite_frames()
	if frames == null:
		body_visual = $ColorRect  # no art -> keep the placeholder box
		return
	body_anim = AnimatedSprite2D.new()
	body_anim.sprite_frames = frames
	body_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_anim.centered = true
	var tex = frames.get_frame_texture("idle", 0)
	var sc = SPRITE_TARGET_HEIGHT / float(max(tex.get_height(), 1))
	base_scale = Vector2(sc, sc) * monarch_scale_mult   # survives a skin reload in true form
	body_anim.scale = base_scale
	anim_base_y = 24.0 - SPRITE_TARGET_HEIGHT / 2.0  # feet on the ground line
	body_anim.position = Vector2(0, anim_base_y)
	body_anim.z_index = 0
	add_child(body_anim)
	body_anim.play("idle")
	$ColorRect.visible = false
	body_visual = body_anim

# Builds the SpriteFrames from whatever art exists. Returns null if there's no
# idle art at all (so the caller keeps the box).
func build_sprite_frames():
	var idle_frames = load_frames_for("idle")
	var idle_real = not idle_frames.is_empty()
	if idle_frames.is_empty():
		for p in IDLE_SINGLE_PATHS:
			var t = load_texture(p)
			if t:
				idle_frames = [t]
				break
	if idle_frames.is_empty():
		return null
	var sf = SpriteFrames.new()
	sf.remove_animation("default")
	real_anims = {}
	for def in ANIM_DEFS:
		var nm = def.name
		var fr = idle_frames if nm == "idle" else load_frames_for(nm)
		real_anims[nm] = idle_real if nm == "idle" else not fr.is_empty()
		if fr.is_empty():
			fr = idle_frames  # fall back to the idle frame so play(state) always works
		_add_anim(sf, nm, fr, def.fps, def.loop)
	return sf

func load_frames_for(anim: String) -> Array:
	var out = []
	var i = 1
	while true:
		var t = load_texture("%s%s_%d.png" % [_art_prefix, anim, i])
		if t == null:
			break
		out.append(t)
		i += 1
	return out

# Swaps the hero between his bare-headed art and the hooded art as the Monarch
# rises past 5/7 (and back, if a stage is ever taken away). Rebuilds the frames
# in place, keeping whatever animation was playing, and re-derives base_scale
# because the hooded art trims to its own height. A no-op unless the stage
# actually crossed the line, so it's safe to call every frame.
func refresh_monarch_skin() -> void:
	if body_anim == null:
		return
	var want: bool = GameState.monarch_stage() >= HOOD_STAGE and _hooded_art_present()
	if want == _hooded:
		return
	_hooded = want
	_art_prefix = HOODED_ART if want else BASE_ART
	var sf = build_sprite_frames()
	if sf == null:                      # art vanished mid-run: keep what we have
		_hooded = not want
		_art_prefix = HOODED_ART if _hooded else BASE_ART
		return
	var was: String = body_anim.animation
	var fr: int = body_anim.frame
	body_anim.sprite_frames = sf
	# base_scale is deliberately NOT re-derived here. The hooded art trims ~6px
	# taller than the bare head, so normalising it to SPRITE_TARGET_HEIGHT again
	# would shrink his BODY to make room for the cowl -- he'd look like he got
	# smaller when the hood went up. Keeping the base art's scale means the body
	# stays exactly the size it was and the hood simply adds height, which is
	# what pulling a hood up actually looks like. feet_anchor_y() re-plants him
	# per frame, so the taller art still stands on the ground.
	if sf.has_animation(was):
		body_anim.play(was)
		body_anim.frame = mini(fr, maxi(sf.get_frame_count(was) - 1, 0))
	else:
		body_anim.play("idle")

func _hooded_art_present() -> bool:
	return ResourceLoader.exists(HOODED_ART + "idle_1.png") \
		or FileAccess.file_exists(HOODED_ART + "idle_1.png")

# Accepts an imported resource OR a loose not-yet-imported PNG, and auto-trims
# transparent margins so the character fills the frame (feet at the bottom) no
# matter how the PNG was cropped.
func load_texture(path: String) -> Texture2D:
	var img: Image = null
	# prefer the imported resource, but fall back to decoding the raw PNG (which
	# works even if the import is missing/broken -- e.g. file just dropped in).
	if ResourceLoader.exists(path):
		var t = load(path)
		if t:
			img = t.get_image()
	if img == null:
		img = load_image_smart(path)
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	# trim to the character, ignoring faint stray AI noise (alpha threshold, not
	# Godot's get_used_rect which keeps any pixel with alpha > 0)
	var used = opaque_bounds(img, 0.35)
	if used.size.x > 0 and used.size.y > 0 and used != Rect2i(Vector2i.ZERO, img.get_size()):
		img = img.get_region(used)
	return ImageTexture.create_from_image(img)

# Bounding box of pixels more opaque than `threshold` (coarse scan for speed).
func opaque_bounds(img: Image, threshold: float) -> Rect2i:
	var w = img.get_width()
	var h = img.get_height()
	var step = 3
	var minx = w
	var miny = h
	var maxx = -1
	var maxy = -1
	for y in range(0, h, step):
		for x in range(0, w, step):
			if img.get_pixel(x, y).a > threshold:
				minx = min(minx, x)
				maxx = max(maxx, x)
				miny = min(miny, y)
				maxy = max(maxy, y)
	if maxx < 0:
		return Rect2i(Vector2i.ZERO, img.get_size())
	return Rect2i(minx, miny, maxx - minx + step, maxy - miny + step).intersection(Rect2i(0, 0, w, h))

# Decodes an image by its ACTUAL content (magic bytes), not its file extension
# -- so a mislabeled .png (e.g. a JPEG renamed) or a correct PNG both load.
func load_image_smart(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var bytes = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 12:
		return null
	var img = Image.new()
	var err = ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		err = img.load_png_from_buffer(bytes)      # PNG
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = img.load_jpg_from_buffer(bytes)      # JPEG (no alpha)
	elif bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[8] == 0x57 and bytes[9] == 0x45:
		err = img.load_webp_from_buffer(bytes)     # WEBP
	else:
		err = img.load(path)
	return img if err == OK else null

func _add_anim(sf: SpriteFrames, anim: String, textures: Array, fps: float, loops: bool) -> void:
	if not sf.has_animation(anim):
		sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loops)
	for t in textures:
		sf.add_frame(anim, t)

# Picks the animation from the player's current action and flips to face the
# move direction. When a state has no real frames of its own, a small bob keeps
# the single idle frame from sliding around lifelessly.
# Which action the player is doing right now, mapped to an animation name.
# Moving the mouse means the player is telekinetically aiming the levitated
# object, so refresh the aim-pose timer (consumed in current_anim_state).
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_aim_timer = MOUSE_AIM_HOLD

func current_anim_state() -> String:
	if is_dead:
		return "death"
	if hurt_timer > 0.0:
		return "hurt"
	if is_dashing:
		return "dash"
	if not is_on_floor():
		# each jump in the chain has its own animation (jump / jump2 / jump3);
		# fall back to the plain jump if that variant has no frames yet
		if velocity.y < 0.0:
			return current_jump_anim if real_anims.get(current_jump_anim, false) else "jump"
		return "fall"
	if land_timer > 0.0:
		return "land"
	if absf(velocity.x) > 12.0:
		return "walk"
	return "idle"

# Node y that puts the CURRENT frame's bottom edge (feet) on the ground line
# (+24 = bottom of the collision body), whatever height that frame was drawn at.
func feet_anchor_y() -> float:
	if not body_anim:
		return anim_base_y
	var tex = body_anim.sprite_frames.get_frame_texture(body_anim.animation, body_anim.frame)
	if tex == null:
		return anim_base_y
	return 24.0 - (tex.get_height() * base_scale.y) / 2.0

func update_body_anim(delta: float) -> void:
	if not body_anim:
		return
	# tick timers
	var on_floor = is_on_floor()
	if on_floor and not was_on_floor:
		land_timer = LAND_SQUASH_TIME   # just landed
	was_on_floor = on_floor
	if land_timer > 0.0:
		land_timer -= delta
	if hurt_timer > 0.0:
		hurt_timer -= delta
	# (2026-07-14) attacking / mouse movement no longer plays any body animation
	# -- the weapon's own visuals carry the attack; the body just moves.

	var state = current_anim_state()
	if body_anim.animation != state:
		body_anim.play(state)
	body_anim.flip_h = facing_direction < 0

	# If this state has its OWN drawn frames, let them do the work -- no
	# procedural distortion on top. Anchor by FEET per-frame so poses that were
	# drawn at different sizes/positions still stand on the ground (fixes the
	# floating/sinking between AI frames).
	if real_anims.get(state, false):
		body_anim.rotation = 0.0
		body_anim.scale = base_scale
		body_anim.position = Vector2(0, feet_anchor_y())
		if state == "dash":
			spawn_dash_afterimage(delta)
		return

	# Dead with no death frames -> the topple tween in die() owns the transform.
	if state == "death":
		return

	# Otherwise: procedural fallback for this state (single idle frame).
	var target_scale = base_scale
	var target_rot = 0.0
	var target_y = feet_anchor_y()
	var now = Time.get_ticks_msec() / 1000.0
	match state:
		"dash":
			target_scale = base_scale * Vector2(1.18, 0.86)
			target_rot = deg_to_rad(DASH_LEAN_DEG * facing_direction)
			spawn_dash_afterimage(delta)
		"jump":
			target_scale = base_scale * Vector2(0.9, 1.14)
		"fall":
			target_scale = base_scale * Vector2(0.96, 1.06)
			target_rot = deg_to_rad(4.0 * facing_direction)
		"land":
			var k = land_timer / LAND_SQUASH_TIME
			target_scale = base_scale * Vector2(lerp(1.0, 1.2, k), lerp(1.0, 0.8, k))
		"walk":
			target_y = feet_anchor_y() - absf(sin(now * WALK_BOB_SPEED)) * WALK_BOB_AMP
			target_rot = deg_to_rad(RUN_LEAN_DEG * facing_direction)
		"hurt":
			pass  # shake handled below
		_:
			target_scale = base_scale * Vector2(1.0, 1.0 + sin(now * 2.0) * 0.012)  # idle breathe

	var shake = (sin(hurt_timer * 90.0) * 2.2) if state == "hurt" else 0.0
	body_anim.scale = body_anim.scale.lerp(target_scale, 0.3)
	body_anim.rotation = lerp_angle(body_anim.rotation, target_rot, 0.3)
	body_anim.position = Vector2(shake, target_y)

# Faded trailing copies during a dash.
func spawn_dash_afterimage(delta: float) -> void:
	afterimage_cd -= delta
	if afterimage_cd > 0.0:
		return
	afterimage_cd = 0.045
	var ghost = Sprite2D.new()
	ghost.texture = body_anim.sprite_frames.get_frame_texture(body_anim.animation, body_anim.frame)
	ghost.centered = true
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.scale = body_anim.scale
	ghost.flip_h = body_anim.flip_h
	ghost.rotation = body_anim.global_rotation
	ghost.global_position = body_anim.global_position
	# Shadowstep (3/7+): the trail is torn shadow, not light
	ghost.modulate = Color(0.38, 0.14, 0.7, 0.6) if GameState.monarch_stage() >= 3 else Color(0.6, 0.75, 1.0, 0.5)
	ghost.z_index = -1
	get_parent().add_child(ghost)
	var tw = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)

func apply_pending_player_state() -> void:
	var data = GameState.pending_player_state
	GameState.pending_player_state = {}
	if data.has("inventory"):
		inventory.from_save_data(data["inventory"])
	if data.has("has_dash"):
		has_dash = data["has_dash"]
	if data.has("has_double_jump"):
		has_double_jump = data["has_double_jump"]
	if data.has("health"):
		health = data["health"]
	if data.has("mana"):
		mana = float(data["mana"])
	# re-wield whatever weapon was in hand (weapons live in the inventory now)
	var eq = str(data.get("active_weapon_id", "wpn_sword"))
	if not wield_weapon(eq):
		wield_weapon("wpn_sword")

func play_sfx(stream: AudioStream) -> void:
	$SFXPlayer.stream = stream
	$SFXPlayer.play()

# --- combat/economy effect hooks. get_bonus_total = skill tree + worn gear
# (armor/relics), so equipping gear flows through the same math as skills. ---

func get_max_health() -> int:
	return MAX_HEALTH + int(round(GameState.get_bonus_total("max_health")))

# `weapon` is a weapon_type: "melee" | "spear" | "bow" | "wand".
func skill_damage_mult(weapon: String) -> float:
	var base := 1.0
	if weapon == "melee" or weapon == "spear":
		base = 1.0 + GameState.get_bonus_total("melee_damage")
	elif weapon == "bow":
		base = 1.0 + GameState.get_bonus_total("bow_damage")
	elif weapon == "wand":
		# scales the Mage's PROJECTILE wands (Emberstaff etc.); the classic
		# nuke wand doesn't deal numeric damage so it ignores this.
		base = 1.0 + GameState.get_bonus_total("wand_damage")
		# Mystic Spellblade: wand damage grows with your Mana pool
		var m2d = GameState.get_bonus_total("mana_to_damage")
		if m2d > 0.0:
			base += m2d * get_max_mana()
	# Warrior's Feast and other food buffs add flat damage to every weapon
	base += buff_bonus("all_damage")
	# Juggernaut Idol (berserk): the lower your HP, the harder you hit, ramping
	# to +relic_value at 1 HP.
	if has_relic_power("berserk"):
		var missing = clamp(1.0 - float(health) / float(get_max_health()), 0.0, 1.0)
		base += relic_power_value("berserk", 0.5) * missing
	# Berserker Blood Rage: swing harder while badly hurt (under 40% HP)
	var lowhp = GameState.get_bonus_total("low_hp_damage_mult")
	if lowhp > 0.0 and float(health) <= float(get_max_health()) * 0.40:
		base += lowhp
	# Avatar of Slaughter / Godslayer: each recent kill stacks bonus damage
	if rampage_stacks > 0:
		if _now() < rampage_until:
			base += GameState.get_bonus_total("on_kill_rampage") * rampage_stacks
		else:
			rampage_stacks = 0
	return base

# Avatar of Slaughter (on_kill_rampage): kills stack a short damage frenzy.
var rampage_stacks: int = 0
var rampage_until: float = 0.0
const RAMPAGE_MAX_STACKS = 10
const RAMPAGE_DURATION = 5.0

# --- Crit ---
# Everyone has a small base crit; gear/relics/skills (crit_chance/crit_damage)
# and food (Sage's Supper) stack on top. Rolled per hit in roll_crit.
const BASE_CRIT_CHANCE = 0.05
const BASE_CRIT_DAMAGE = 0.5

func get_crit_chance() -> float:
	return clamp(BASE_CRIT_CHANCE + GameState.get_bonus_total("crit_chance") + buff_bonus("crit_chance"), 0.0, 1.0)

func get_crit_damage() -> float:
	return BASE_CRIT_DAMAGE + GameState.get_bonus_total("crit_damage")

# Rolls a crit against a base amount. Returns [final_amount, is_crit].
func roll_crit(base: int) -> Array:
	if base > 0 and randf() < get_crit_chance():
		return [int(round(base * (1.0 + get_crit_damage()))), true]
	return [base, false]

# Pop a floating damage number over a struck enemy.
func show_hit(target: Node2D, amount: int, is_crit: bool) -> void:
	if is_instance_valid(target):
		FloatingText.spawn(get_parent(), target.global_position, amount, is_crit)

# --- Timed buffs (from food). active_buffs[key] = {"v": amount, "until": t}. ---
var active_buffs: Dictionary = {}

func add_buff(key: String, value: float, duration: float) -> void:
	active_buffs[key] = {"v": value, "until": _now() + duration}

# Consume one of item_id from the bag and apply its use_effect. Returns true if
# it was actually used (so the UI knows to remove one).
func use_item(item_id: String) -> bool:
	var def = Inventory.get_item_def(item_id)
	if def.get("category", "") != "consumable" or inventory.get_count(item_id) <= 0:
		return false
	var eff = def.get("use_effect", {})
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if eff.has("heal_hp"):
		health = min(get_max_health(), health + int(eff.heal_hp))
		update_health_display()
	if eff.has("heal_mana"):
		gain_mana(float(eff.heal_mana))
	if eff.has("buff"):
		add_buff(str(eff.buff), float(eff.get("value", 0.0)), float(eff.get("duration", 30.0)))
	if eff.get("reset_skills", false):
		GameState.reset_skills()
		on_equipment_changed()
	inventory.remove_item(item_id, 1)
	if stack:
		stack.show_notification("Used " + Inventory.get_display_name(item_id) + ".")
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui and inv_ui.has_method("refresh"):
		inv_ui.refresh()
	return true

func buff_bonus(key: String) -> float:
	var b = active_buffs.get(key, null)
	if b == null:
		return 0.0
	if _now() >= b.until:
		active_buffs.erase(key)
		return 0.0
	return b.v

func skill_cooldown_mult(weapon: String) -> float:
	var reduction = 0.0
	if weapon == "melee" or weapon == "spear":
		reduction = GameState.get_bonus_total("melee_cooldown")
	elif weapon == "bow":
		reduction = GameState.get_bonus_total("bow_cooldown")
	elif weapon == "wand":
		reduction = GameState.get_bonus_total("wand_cooldown")
	return max(0.3, 1.0 - reduction)

# --- Standing torches (G) ---
# Plants a big brazier torch at the player's feet: a much larger, richer light
# pool than the wall torches. Costs materials; persists via GameState.
const STANDING_TORCH_SCRIPT = preload("res://standing_torch.gd")
const STANDING_TORCH_COST = {"wood": 2, "resin": 1}

func try_place_torch() -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if GameState.in_dungeon:
		if stack:
			stack.show_notification("Standing torches can only be placed in the overworld.")
		return
	var missing = []
	for mat in STANDING_TORCH_COST:
		if inventory.get_count(mat) < STANDING_TORCH_COST[mat]:
			missing.append("%s %d/%d" % [Inventory.get_display_name(mat), inventory.get_count(mat), STANDING_TORCH_COST[mat]])
	if not missing.is_empty():
		if stack:
			stack.show_notification("A standing torch needs: " + ", ".join(missing))
		return
	for mat in STANDING_TORCH_COST:
		inventory.remove_item(mat, int(STANDING_TORCH_COST[mat]))
	var spot = Vector2(global_position.x, global_position.y + 24.0)   # at the feet
	var torch = STANDING_TORCH_SCRIPT.new()
	torch.position = spot   # parent is the scene root, so this is world-space
	get_parent().add_child(torch)
	GameState.placed_torches.append({"x": spot.x, "y": spot.y})
	if stack:
		stack.show_notification("Standing torch planted (2 Wood, 1 Resin). It lights at dusk.")

# --- Bar morale ---
# Stepping into the (built) Bar lifts the player's spirits: +10% move speed for
# a few in-game hours. Granted by building.gd's Bar on entry; re-entering after
# it lapses refreshes it.
const BAR_MORALE_BONUS = 0.10
const BAR_MORALE_HOURS = 3.0
var bar_morale_until := -1.0e9
var morale_hp_accum := 0.0   # banks fractional high-morale HP regen (HP is an int)

func bar_morale_active() -> bool:
	return GameState.game_hours < bar_morale_until

func grant_bar_morale() -> void:
	if bar_morale_active():
		return
	bar_morale_until = GameState.game_hours + BAR_MORALE_HOURS
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("The Bar lifts your spirits! +%d%% move speed for %d hours." % [int(BAR_MORALE_BONUS * 100), int(BAR_MORALE_HOURS)])

# Enemy casters chill you: a temporary move-speed slow. status_resistance gear
# shortens it (folded in when the slow is applied).
var enemy_slow_until := 0.0
var enemy_slow_factor := 1.0

# Called by enemies/bosses when they die to player damage. Reaper's Toll heals
# on kill.
func on_enemy_killed() -> void:
	if has_relic_power("reaper"):
		health = min(get_max_health(), health + 8)
		update_health_display()
		gain_mana(5.0)
	# Avatar of Slaughter / Godslayer: each kill refreshes and grows the frenzy
	if GameState.get_bonus_total("on_kill_rampage") > 0.0:
		if _now() >= rampage_until:
			rampage_stacks = 0
		rampage_stacks = mini(RAMPAGE_MAX_STACKS, rampage_stacks + 1)
		rampage_until = _now() + RAMPAGE_DURATION
	# Rise, Shade (5/7+): the slain foe's shadow tears free and serves
	if GameState.monarch_stage() >= 5:
		raise_shade()
	# advance any "slay N foes" villager bonds
	GameState.quest_event("slay", "", 1)

func apply_slow(duration: float, factor: float) -> void:
	# a status-resistance relic cuts the slow's duration
	var resist = clamp(GameState.get_bonus_total("status_resistance"), 0.0, 0.9)
	enemy_slow_until = max(enemy_slow_until, _now() + duration * (1.0 - resist))
	enemy_slow_factor = min(enemy_slow_factor, factor)

func player_slow_mult() -> float:
	if _now() < enemy_slow_until:
		return enemy_slow_factor
	enemy_slow_factor = 1.0
	return 1.0

func skill_move_speed_mult() -> float:
	var morale = BAR_MORALE_BONUS if bar_morale_active() else 0.0
	# a joyful village gives every step a spring (up to +12% at 10/10 morale)
	return (1.0 + GameState.get_bonus_total("move_speed") + morale + GameState.morale_speed_bonus() + buff_bonus("move_speed")) * player_slow_mult()

# Called by GameState whenever a piece of gear (armor/relic) is equipped or
# unequipped, and on every hotbar wield -- both can change set bonuses, so
# refresh armor visuals and clamp HP/mana to their (possibly new) maxima.
func on_equipment_changed() -> void:
	update_armor_visuals()
	health = min(health, get_max_health())
	mana = min(mana, get_max_mana())
	update_health_display()
	update_mana_display()

func update_health_display() -> void:
	var percent = clamp(float(health) / get_max_health(), 0.0, 1.0)
	$"../CanvasLayer/HealthBarFill".size.x = 100 * percent
	$"../CanvasLayer/HealthLabel".text = str(max(health, 0)) + "/" + str(get_max_health())

# --- Mana pool ---

func get_max_mana() -> float:
	return BASE_MAX_MANA + GameState.get_bonus_total("max_mana")

func get_mana_regen() -> float:
	return BASE_MANA_REGEN * (1.0 + GameState.get_bonus_total("mana_regen"))

func spend_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	update_mana_display()
	return true

func gain_mana(amount: float) -> void:
	mana = min(get_max_mana(), mana + amount)
	update_mana_display()

# The HP bar lives in each scene's .tscn; the mana bar is built here in code
# so it appears identically under the HP bar in BOTH main.tscn and
# dungeon_interior.tscn without touching either scene file.
func build_mana_bar() -> void:
	var layer = get_node_or_null("../CanvasLayer")
	if not layer:
		return
	var bg = ColorRect.new()
	bg.name = "ManaBarBG"
	bg.offset_left = 20.0
	bg.offset_top = 96.0
	bg.offset_right = 120.0
	bg.offset_bottom = 108.0
	bg.color = Color(0.05, 0.08, 0.2, 1)
	layer.add_child(bg)
	mana_bar_fill = ColorRect.new()
	mana_bar_fill.name = "ManaBarFill"
	mana_bar_fill.offset_left = 20.0
	mana_bar_fill.offset_top = 96.0
	mana_bar_fill.offset_right = 120.0
	mana_bar_fill.offset_bottom = 108.0
	mana_bar_fill.color = Color(0.25, 0.5, 0.95, 1)
	layer.add_child(mana_bar_fill)
	mana_label = Label.new()
	mana_label.name = "ManaLabel"
	mana_label.offset_left = 126.0
	mana_label.offset_top = 92.0
	mana_label.offset_right = 200.0
	mana_label.offset_bottom = 112.0
	mana_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	mana_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	mana_label.add_theme_constant_override("outline_size", 4)
	mana_label.add_theme_font_size_override("font_size", 14)
	layer.add_child(mana_label)
	update_mana_display()

func update_mana_display() -> void:
	if not mana_bar_fill:
		return
	var max_mana = get_max_mana()
	var percent = clamp(mana / max(max_mana, 1.0), 0.0, 1.0)
	mana_bar_fill.size.x = 100 * percent
	if mana_label:
		mana_label.text = str(int(mana)) + "/" + str(int(max_mana))

func apply_knockback(direction_sign: int, distance: float) -> void:
	if is_dead:
		return
	# Knockback shares the post-hit invincibility window: the first bounce lands
	# and opens an immunity window of the same length as the damage i-frames, so
	# the player can't be chain-knocked 2-3 times in a row by clustered hits.
	var now = Time.get_ticks_msec() / 1000.0
	if now < knockback_immune_until:
		return
	knockback_immune_until = now + INVINCIBILITY_DURATION
	is_knocked_back = true
	velocity.x = direction_sign * (distance / BOUNCE_DURATION)
	await get_tree().create_timer(BOUNCE_DURATION).timeout
	is_knocked_back = false

func knockback_sign_toward(body: Node2D) -> int:
	var s = sign(body.global_position.x - global_position.x)
	if s == 0:
		s = facing_direction
	return s

func _on_spear_tip_hit(body: Node2D) -> void:
	if body in spear_hit_bodies:
		return
	spear_hit_bodies.append(body)
	var stats = active_stats
	if body.has_method("take_damage"):
		var r = roll_crit(int(round(stats.damage * skill_damage_mult("spear"))))
		body.take_damage(r[0])
		show_hit(body, r[0], r[1])
		apply_omnivamp(r[0])
		apply_melee_skills(body, r[0])
	if body.has_method("apply_knockback"):
		var knockback_distance = randf_range(stats.knockback_min, stats.knockback_max)
		body.apply_knockback(knockback_sign_toward(body), knockback_distance)

# Wields the weapon ITEM `item_id` (must be a "weapon" category item). Caches
# its stats/type/def and configures the held-weapon visuals. Returns false for
# non-weapons.
func wield_weapon(item_id: String) -> bool:
	var def = Inventory.get_item_def(item_id)
	if def.get("category", "") != "weapon":
		return false
	var stats = def.get("weapon_stats", {})
	if stats.is_empty():
		return false
	active_weapon_id = item_id
	active_def = def
	active_stats = stats
	active_weapon_type = def.get("weapon_type", "melee")
	$AttackArea/CollisionShape2D.shape.size = stats.area_size
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	$WeaponIcon.size = stats.icon_size
	$WeaponIcon.color = stats.icon_color
	$WeaponIcon.rotation_degrees = 0.0
	$WeaponIcon.scale = Vector2.ONE
	$WeaponIcon.pivot_offset = Vector2(0.0, stats.icon_size.y / 2.0)
	update_weapon_guard()
	update_weapon_visual(stats.icon_offset)
	# wielding can complete (or break) a class set's full weapon tier, which
	# can change max HP/mana -- re-sync exactly like an equip would.
	on_equipment_changed()
	return true

# Hotbar select: index 0-9 = inventory slots 1-10. Wields the weapon in that
# slot; a non-weapon (or empty) slot does nothing.
func select_hotbar_slot(index: int) -> void:
	selected_hotbar_slot = index
	if index >= inventory.slots.size():
		return
	var slot = inventory.slots[index]
	if slot == null or Inventory.get_category(slot.item_id) != "weapon":
		return
	if slot.item_id == active_weapon_id:
		return
	if wield_weapon(slot.item_id):
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("Wielding " + Inventory.get_display_name(slot.item_id))

# Shows/sizes the crossguard for bladed melee weapons (melee/spear), hides it
# for bow and wand. The guard is a child of WeaponIcon, so it swings/aims with
# the weapon automatically.
func update_weapon_guard() -> void:
	if not weapon_guard:
		return
	if active_weapon_type == "bow" or active_weapon_type == "wand" or active_stats.is_empty():
		weapon_guard.visible = false
		return
	var guard_height = active_stats.icon_size.y + 12.0
	weapon_guard.size = Vector2(5.0, guard_height)
	weapon_guard.position = Vector2(active_stats.icon_size.x * 0.16, (active_stats.icon_size.y - guard_height) / 2.0)
	weapon_guard.visible = true

func get_aim_direction() -> Vector2:
	var to_mouse = get_global_mouse_position() - global_position
	if to_mouse.length() < 1.0:
		return Vector2(facing_direction, 0)
	return to_mouse.normalized()

func update_weapon_visual(offset: float) -> void:
	if not has_weapon():
		$WeaponIcon.visible = false
		$BowVisual.visible = false
		$WeaponTip.visible = false
		update_levitate_aura(Vector2.RIGHT, 0.0)
		return
	var stats = active_stats
	var aim_dir = get_aim_direction()
	# Levitation: the weapon floats toward the mouse, bounded to his reach, and
	# drifts organically (free_float) + tilts (wobble) so it reads as suspended
	# by magic rather than rigidly leashed. Visual-only -- hitboxes stay on the
	# aim line (extended by hover_extra so far-flung strikes land correctly).
	var hover = hover_for_mouse(offset)
	var hover_extra = hover - offset
	var free_float = levitate_float_offset()
	var wobble = sin(levitate_time * 2.4) * 0.10
	$WeaponTip.visible = false
	$BowVisual.visible = false
	if active_weapon_type == "bow":
		$WeaponIcon.visible = false
		$BowVisual.visible = true
		$BowVisual.position = aim_dir * hover + free_float
		$BowVisual.rotation = aim_dir.angle() + wobble
		$BowVisual.scale = Vector2.ONE
	else:
		$WeaponIcon.visible = true
		$WeaponIcon.position = aim_dir * hover + free_float - $WeaponIcon.pivot_offset
		$WeaponIcon.rotation = aim_dir.angle() + wobble
		$AttackArea.position = aim_dir * (stats.range_offset + hover_extra)
		$AttackArea.rotation = aim_dir.angle()
		if active_weapon_type == "spear":
			$WeaponTip.visible = true
			var tip_pos = aim_dir * (hover + stats.icon_size.x)
			$WeaponTip.position = tip_pos + free_float
			$WeaponTip.rotation = aim_dir.angle() + wobble
			$WeaponTip.scale = Vector2.ONE
			$SpearTipArea.position = tip_pos
	update_levitate_aura(aim_dir, hover, free_float)

func add_currency(amount: int) -> void:
	currency += amount
	$"../CanvasLayer/CurrencyLabel".text = "Currency: " + str(currency)
	print("Currency: ", currency)

func take_damage(amount: int) -> void:
	if invincible or is_dead or god_mode:
		return
	if _now() < monarch_iframes_until:
		return   # Shadowstep: mid-dash the Monarch simply isn't there
	# Evasion (Riposte / Evasion / Blink Step): a chance to dodge the hit whole
	var dodge = GameState.get_bonus_total("dodge_chance")
	if dodge > 0.0 and randf() < dodge:
		FloatingText.spawn(get_parent(), global_position + Vector2(0, -20), 0, false, Color(0.7, 0.95, 1.0))
		var dt = Label.new(); dt.text = "Dodge"; dt.z_index = 100
		dt.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))
		dt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8)); dt.add_theme_constant_override("outline_size", 4)
		get_parent().add_child(dt); dt.global_position = global_position + Vector2(-14, -34)
		var dtw = dt.create_tween()
		dtw.tween_property(dt, "global_position:y", dt.global_position.y - 30, 0.5)
		dtw.parallel().tween_property(dt, "modulate:a", 0.0, 0.5); dtw.tween_callback(dt.queue_free)
		return
	# Aegis Ward: a shield fully swallows one hit every few seconds
	if has_relic_power("aegis") and _now() >= aegis_ready_at:
		aegis_ready_at = _now() + AEGIS_COOLDOWN
		spawn_aegis_block()
		return
	amount = int(round(amount * (1.0 - clamp(GameState.get_bonus_total("damage_reduction"), 0.0, 0.75))))
	# Mana Barrier (Mystic): a share of the hit is paid from Mana, not HP
	var msf = clamp(GameState.get_bonus_total("mana_shield"), 0.0, 0.8)
	if msf > 0.0 and mana > 0.0:
		var absorb = min(mana, float(amount) * msf)
		mana -= absorb
		amount = maxi(0, amount - int(round(absorb)))
		update_mana_display()
	health -= amount
	update_health_display()
	play_sfx(SFX_HURT)
	hurt_timer = HURT_SHAKE_TIME
	if has_node("Camera2D"):
		$Camera2D.shake(4.0, 0.15)
	# Thorns: skill (Spiked Armor) + relic (Thornmail) both reflect the pain
	var thorns_frac = GameState.get_bonus_total("thorns")
	if has_relic_power("thorns"):
		thorns_frac += relic_power_value("thorns", 0.4)
	if thorns_frac > 0.0:
		reflect_thorns(int(round(amount * thorns_frac)))
	if health <= 0:
		# The Long Dark (6/7+): a lethal blow cannot kill what is already
		# shadow. Outranks Living Fortress so the skill charge is kept.
		if GameState.monarch_stage() >= 6 and _now() >= monarch_long_dark_ready_at:
			monarch_long_dark_ready_at = _now() + LONG_DARK_COOLDOWN
			enter_long_dark()
			return
		# Living Fortress (undying): once per life, refuse to fall -- snap back
		# to 20% HP with a burst of i-frames instead of dying.
		if GameState.get_bonus_total("undying") > 0.0 and not undying_used:
			undying_used = true
			health = maxi(1, int(get_max_health() * 0.20))
			update_health_display()
			spawn_shock_ring(global_position, 200.0, Color(1.0, 0.85, 0.3, 0.95))
			var stack = get_tree().get_first_node_in_group("notification_stack")
			if stack:
				stack.show_notification("Living Fortress: you refuse to fall!")
			invincible = true
			start_invincibility_flash()
			var ut = get_tree().create_timer(INVINCIBILITY_DURATION * 2.0)
			ut.timeout.connect(func():
				if not is_dead:
					stop_invincibility_flash()
					invincible = false)
			return
		die()
		return
	invincible = true
	start_invincibility_flash()
	await get_tree().create_timer(INVINCIBILITY_DURATION).timeout
	stop_invincibility_flash()
	invincible = false

func start_invincibility_flash() -> void:
	if invincibility_tween:
		invincibility_tween.kill()
	body_visual.modulate = Color(1.0, 0.35, 0.35, 1.0)
	var color_tween = create_tween()
	color_tween.tween_property(body_visual, "modulate", Color(1, 1, 1, 1), 0.15)
	invincibility_tween = create_tween()
	invincibility_tween.set_loops()
	invincibility_tween.tween_property(body_visual, "modulate:a", 0.25, 0.1)
	invincibility_tween.tween_property(body_visual, "modulate:a", 1.0, 0.1)

func stop_invincibility_flash() -> void:
	if invincibility_tween:
		invincibility_tween.kill()
		invincibility_tween = null
	body_visual.modulate.a = 1.0

func die() -> void:
	# Phoenix Heart: cheat death -- back up at half health, off cooldown
	if has_relic_power("phoenix") and _now() >= phoenix_ready_at:
		phoenix_ready_at = _now() + PHOENIX_COOLDOWN
		health = maxi(1, int(get_max_health() * 0.5))
		update_health_display()
		spawn_phoenix_revive()
		invincible = true
		start_invincibility_flash()
		var t = get_tree().create_timer(INVINCIBILITY_DURATION)
		t.timeout.connect(func():
			if not is_dead:
				stop_invincibility_flash()
				invincible = false)
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("The Phoenix Heart blazes -- you rise again!")
		return
	is_dead = true
	velocity = Vector2.ZERO
	play_sfx(SFX_DEATH)
	stop_invincibility_flash()
	body_visual.modulate = Color(0.55, 0.2, 0.2, 1.0)
	# topple over as he dies -- but only if you haven't drawn real death frames
	# (those play themselves; update_body_anim yields the transform while dead)
	if body_anim and not real_anims.get("death", false):
		var topple = create_tween()
		topple.tween_property(body_anim, "rotation", deg_to_rad(82.0 * facing_direction), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	drop_currency_on_death()
	apply_difficulty_death_penalty()

	var death_screen = get_node_or_null("../DeathScreen")
	if GameState.TEST_INSTANT_RESPAWN:
		# testing: no countdown -- just step out of the physics callback that
		# may have killed us, then respawn immediately.
		await get_tree().process_frame
	elif death_screen:
		await death_screen.run_death_sequence(DEATH_COUNTDOWN_SECONDS)
	else:
		await get_tree().create_timer(DEATH_COUNTDOWN_SECONDS).timeout

	health = get_max_health()
	global_position = spawn_position
	body_visual.modulate = Color(1, 1, 1, 1)
	if body_anim:
		body_anim.rotation = 0.0
		body_anim.scale = base_scale
		body_anim.position = Vector2(0, anim_base_y)
	invincible = false
	is_dead = false
	update_health_display()

# All difficulties drop currency on death -- the amount stays in the world
# as a pickup (see currency_pickup.gd) for a full in-game day before it
# despawns, rather than being lost outright.
func drop_currency_on_death() -> void:
	var drop_amount = int(round(currency * CURRENCY_DROP_FRACTION))
	if drop_amount <= 0:
		return
	currency -= drop_amount
	update_currency_display()
	var pickup = CURRENCY_PICKUP_SCRIPT.new()
	pickup.global_position = global_position
	pickup.setup(drop_amount, true)
	# die() can be reached from an Area2D physics callback (an arrow's
	# body_entered, mid physics-step) -- adding a new collider synchronously
	# there hits Godot's "can't change state while flushing queries"
	# restriction, so this has to go through the deferred queue instead.
	get_parent().call_deferred("add_child", pickup)

# Medium/Hard difficulties additionally take something more permanent on
# death. Both hooks are stubs until the villager/skill-material systems
# exist -- this just guarantees they fire correctly once they do.
func apply_difficulty_death_penalty() -> void:
	match GameState.difficulty:
		"Medium":
			GameState.remove_random_villager()
		"Hard":
			GameState.remove_random_villager()
			GameState.remove_one_skill_material()

func update_currency_display() -> void:
	$"../CanvasLayer/CurrencyLabel".text = "Currency: " + str(currency)

func perform_dash(dash_direction: int) -> void:
	if not has_dash or is_dashing:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_dash_time < DASH_COOLDOWN:
		return
	last_dash_time = now
	is_dashing = true
	# Shadowstep (3/7+): the Monarch dashes BETWEEN shadows -- untouchable for
	# the whole dash (the trail tints dark in spawn_dash_afterimage).
	if GameState.monarch_stage() >= 3:
		monarch_iframes_until = now + DASH_DURATION + 0.08
	play_sfx(SFX_DASH)
	velocity.x = dash_direction * DASH_SPEED
	await get_tree().create_timer(DASH_DURATION).timeout
	is_dashing = false

func perform_admin_dash() -> void:
	if is_dashing:
		return
	is_dashing = true
	invincible = true
	play_sfx(SFX_DASH)
	var input_dir = Input.get_axis("move_left", "move_right")
	var dash_direction = int(sign(input_dir)) if input_dir != 0 else facing_direction
	velocity.x = dash_direction * ADMIN_DASH_SPEED
	await get_tree().create_timer(DASH_DURATION).timeout
	is_dashing = false
	var now = Time.get_ticks_msec() / 1000.0
	admin_invincible_until = now + ADMIN_DASH_INVINCIBILITY_SECONDS
	var my_expiry = admin_invincible_until
	await get_tree().create_timer(ADMIN_DASH_INVINCIBILITY_SECONDS).timeout
	# only clear invincibility if nothing extended the window since this
	# specific dash scheduled it (a later T press pushes admin_invincible_until
	# further out, so this stale check simply becomes a no-op).
	if my_expiry == admin_invincible_until:
		invincible = false

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# fall-damage apex: remember the highest point of the current airtime so we
	# can measure the drop on landing (only once we've touched ground at least
	# once, so spawning slightly above the floor never counts as a fall).
	if is_on_floor():
		fall_apex_y = global_position.y
	elif has_touched_ground:
		fall_apex_y = min(fall_apex_y, global_position.y)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		jumps_used = 0

	update_flight(delta)

	if attack_cooldown_remaining > 0:
		attack_cooldown_remaining -= delta

	# mana trickles back constantly; gear/set bonuses speed it up
	if mana < get_max_mana():
		mana = min(get_max_mana(), mana + get_mana_regen() * delta)
		update_mana_display()

	# a thriving village slowly mends its hero's wounds (up to +2 HP/s at 10/10).
	# HP is an int, so bank the fractional healing until it totals a whole point.
	var morale_regen = GameState.morale_regen_per_sec()
	if morale_regen > 0.0 and health > 0 and health < get_max_health():
		morale_hp_accum += morale_regen * delta
		if morale_hp_accum >= 1.0:
			var whole = int(morale_hp_accum)
			morale_hp_accum -= whole
			health = min(get_max_health(), health + whole)
			update_health_display()

	# hotbar: keys 1-9 and 0 pick inventory slots 0-9; wield the weapon there
	for i in range(HOTBAR_SIZE):
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			select_hotbar_slot(i)

	# T = blink-dash: the Shadowstep Sigil relic earns it, god mode just gives it
	if Input.is_action_just_pressed("admin_dash") and (has_relic_power("blink") or god_mode):
		perform_admin_dash()

	if Input.is_action_just_pressed("place_torch"):
		try_place_torch()

	if Input.is_action_just_pressed("move_left"):
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_left_press_time < DOUBLE_TAP_WINDOW:
			perform_dash(-1)
		last_left_press_time = now

	if Input.is_action_just_pressed("move_right"):
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_right_press_time < DOUBLE_TAP_WINDOW:
			perform_dash(1)
		last_right_press_time = now

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			jumps_used = 1
			current_jump_anim = "jump"
			play_sfx(SFX_JUMP)
		elif has_double_jump and jumps_used < 2:
			velocity.y = JUMP_VELOCITY
			jumps_used = 2
			current_jump_anim = "jump2"   # the double jump has its own animation
			play_sfx(SFX_JUMP)

	var direction = Input.get_axis("move_left", "move_right")
	if direction:
		facing_direction = sign(direction)
	levitate_time += get_physics_process_delta_time()
	if levitate_flash > 0.0:
		levitate_flash = max(0.0, levitate_flash - get_physics_process_delta_time())
	if has_weapon() and not is_attacking:
		update_weapon_visual(active_stats.icon_offset)

	if not is_dashing and not is_knocked_back:
		velocity.x = direction * SPEED * skill_move_speed_mult()

	# Hold left-click to keep attacking: the weapon auto-fires on cooldown and the
	# hand flares each shot. (The dedicated attack body pose -- the future
	# two-hands-up frame -- isn't wired yet; these frames are now the aim pose.)
	if Input.is_action_pressed("attack"):
		var was_ready = attack_cooldown_remaining <= 0.0 and has_weapon()
		perform_attack()
		if was_ready and attack_cooldown_remaining > 0.0:
			trigger_levitate_flash()   # per-shot telekinetic pop

	# right-click = the admin Ruin Wand's no-aim percent burst (see below)
	if Input.is_action_just_pressed("secondary_attack"):
		perform_secondary_attack()

	move_and_slide()
	handle_fall_landing()
	# drive the sprite animation after movement (needs final velocity/floor state)
	update_body_anim(delta)
	update_shadow_aura(delta)
	monarch_tick(delta)

# --- Flight (Aetherwing) ---
func has_flight() -> bool:
	return god_mode or GameState.get_bonus_total("flight") > 0.0

func has_fall_immunity() -> bool:
	# god mode flies, so it must not be killed by its own landing
	return god_mode or GameState.get_bonus_total("fall_immunity") > 0.0

# Runs every frame after gravity. With wings equipped: on the ground it refills
# the flight budget; in the air, holding Space soars (draining the budget) and
# otherwise you glide down gently. Without wings this is a no-op.
func update_flight(delta: float) -> void:
	var flying = false
	if has_flight():
		if is_on_floor():
			flight_time_left = FLIGHT_MAX_SECONDS
			flight_depleted_notified = false
		elif Input.is_action_pressed("jump") and (flight_time_left > 0.0 or god_mode):
			flying = true
			# god mode never runs out of wing -- the point is to cross the map
			if not god_mode:
				flight_time_left = max(0.0, flight_time_left - delta)
			velocity.y = FLIGHT_RISE_SPEED
			if flight_time_left == 0.0 and not flight_depleted_notified:
				flight_depleted_notified = true
				var stack = get_tree().get_first_node_in_group("notification_stack")
				if stack:
					stack.show_notification("Wings spent -- touch ground to recharge.")
		# else: not holding Space (or budget spent) -> plain gravity fall. The
		# wings don't slow it; fall_immunity just spares you the landing damage.
	update_wings(flying)

# --- Fall damage ---
# Fires once on each ground landing. A drop past the safe distance hurts,
# scaled by how far past it fell -- unless a fall_immunity relic is worn.
func handle_fall_landing() -> void:
	var grounded = is_on_floor()
	if grounded and not was_grounded_fall:
		if has_touched_ground:
			apply_fall_damage(global_position.y - fall_apex_y)
		has_touched_ground = true
	was_grounded_fall = grounded

func apply_fall_damage(fall_distance: float) -> void:
	if fall_distance <= FALL_SAFE_DISTANCE:
		return
	if has_fall_immunity():
		return   # wings / featherfall absorb the impact
	var dmg = int(round((fall_distance - FALL_SAFE_DISTANCE) * FALL_DAMAGE_PER_PIXEL))
	if dmg > 0:
		take_damage(dmg)

# Right-click. Only the admin Ruin Wand does anything on it right now: a
# no-aim burst that shears a flat % of MAX HP off every enemy nearby. Kept as
# its own path (not perform_attack) so left-click stays the normal attack and
# the two never fight over the cooldown.
func perform_secondary_attack() -> void:
	if not has_weapon():
		return
	var special = active_def.get("special", {})
	if str(special.get("type", "")) == "percent_burst":
		cast_percent_burst(special)

# Sears `percent` of each nearby enemy's MAX HP -- ignores every damage
# modifier and armor, so it's a predictable share of the health bar. At 5%
# that's ~20 casts to fell anything, boss included, which is exactly enough to
# walk a final boss through all of its phases for testing.
func cast_percent_burst(special: Dictionary) -> void:
	if attack_cooldown_remaining > 0:
		return
	attack_cooldown_remaining = active_stats.cooldown * skill_cooldown_mult("wand")
	play_sfx(SFX_BOW)
	var icon = $WeaponIcon
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	weapon_anim_tween = create_tween()
	weapon_anim_tween.tween_property(icon, "scale", Vector2(1.4, 1.4), 0.08)
	weapon_anim_tween.tween_property(icon, "scale", Vector2.ONE, 0.15)
	var radius = float(special.get("radius", 280.0))
	var percent = float(special.get("percent", 0.05))
	spawn_ruin_burst(radius)
	var hit_any = false
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) > radius:
				continue
			# 5% of MAX HP, min 1 so tiny-HP foes still take a chip
			var pool = int(e.max_health) if "max_health" in e else int(e.health)
			e.take_damage(max(1, int(round(pool * percent))))
			hit_any = true
	if not hit_any:
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("Ruin Wand: no enemy in range.")

# A red shockwave ring showing the Ruin Wand's reach on each cast.
func spawn_ruin_burst(radius: float) -> void:
	var ring = Line2D.new()
	var pts = _circle_points(radius, 40)
	pts.append(pts[0])
	ring.points = pts
	ring.width = 4.0
	ring.default_color = Color(0.95, 0.2, 0.25, 0.85)
	ring.z_index = 45
	get_parent().add_child(ring)
	ring.global_position = global_position
	ring.scale = Vector2(0.2, 0.2)
	var t = ring.create_tween()
	t.tween_property(ring, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	t.tween_callback(ring.queue_free)

func perform_attack() -> void:
	if attack_cooldown_remaining > 0 or not has_weapon():
		return
	var stats = active_stats
	var special = active_def.get("special", {})
	var special_type = str(special.get("type", ""))
	# the Ruin Wand is a no-aim burst -- left-click casts the same thing as
	# right-click so it never fires a stray projectile
	if special_type == "percent_burst":
		cast_percent_burst(special)
		return
	if active_weapon_type == "wand":
		# wands draw on the mana pool -- refusing the cast costs no cooldown
		var cost = int(active_def.get("mana_cost", DEFAULT_WAND_MANA_COST))
		if not spend_mana(cost):
			var stack = get_tree().get_first_node_in_group("notification_stack")
			if stack:
				stack.show_notification("Not enough mana (%d/%d)." % [int(mana), cost])
			return
		attack_cooldown_remaining = stats.cooldown * skill_cooldown_mult(active_weapon_type)
		if special.is_empty():
			cast_wand()   # ADMIN screen-nuke (instakill everything)
		elif special_type == "nuke":
			cast_wand_nuke(special)   # Runeweave Scepter -- big FINITE screen AoE
		else:
			cast_wand_projectile(special)   # Emberstaff / Icicle Wand ...
		return
	attack_cooldown_remaining = stats.cooldown * skill_cooldown_mult(active_weapon_type)
	if active_weapon_type == "bow":
		animate_bow(stats)
		return
	if active_weapon_type == "spear":
		if special_type == "javelin_volley":
			throw_javelin_volley(special)
		else:
			animate_spear(stats)
		return
	# thrown "melee" weapons: the whole attack IS the projectile
	if special_type == "hook" or special_type == "boomerang":
		play_sfx(SFX_SWORD)
		animate_sword()
		launch_projectile(special, get_aim_direction(), int(special.get("damage", stats.damage)))
		return
	# melee swing (also the swing for an Excellent weapon) -- the strike lands
	# wherever the levitating blade currently hovers (telekinetic range attack)
	var is_excellent = active_def.has("unique_effect")
	var aim_dir = get_aim_direction()
	var hover_extra = hover_for_mouse(stats.icon_offset) - stats.icon_offset
	$AttackArea.position = aim_dir * (stats.range_offset + hover_extra)
	$AttackArea.rotation = aim_dir.angle()
	# a wielded gathering tool works the harvest nodes inside the swing area
	# (trees want the axe, rocks the pickaxe -- see harvest_node.gd)
	var tool_type = str(active_def.get("tool_type", ""))
	if tool_type != "":
		for area in $AttackArea.get_overlapping_areas():
			if area.is_in_group("harvestable") and area.has_method("take_tool_hit"):
				area.take_tool_hit(tool_type, self)
	var bodies = $AttackArea.get_overlapping_bodies()
	if special_type == "cleave":
		# the Sunderer carves through EVERY body in the arc, not just one
		var cleave_total = 0
		for body in bodies:
			if body.has_method("take_damage"):
				var cr = roll_crit(int(round(stats.damage * skill_damage_mult("melee"))))
				body.take_damage(cr[0])
				show_hit(body, cr[0], cr[1])
				apply_melee_skills(body, cr[0])
				cleave_total += cr[0]
			if body.has_method("apply_knockback"):
				body.apply_knockback(knockback_sign_toward(body), randf_range(stats.knockback_min, stats.knockback_max))
		apply_omnivamp(cleave_total)
	else:
		var target = closest_body(bodies)
		if target:
			# Excellent weapons are classless -- no skill-tree damage scaling.
			var mult = 1.0 if is_excellent else skill_damage_mult("melee")
			var cr = roll_crit(int(round(stats.damage * mult)))
			var dealt = cr[0]
			if target.has_method("take_damage"):
				target.take_damage(dealt)
				show_hit(target, dealt, cr[1])
				apply_omnivamp(dealt)
				apply_melee_skills(target, dealt)
			if target.has_method("apply_knockback"):
				var knockback_distance = randf_range(stats.knockback_min, stats.knockback_max)
				target.apply_knockback(knockback_sign_toward(target), knockback_distance)
			if is_excellent:
				apply_excellent_effect(target, dealt)
	# the Windcutter's signature: the swing releases a slash that flies onward
	if special_type == "flying_slash":
		launch_projectile(special, aim_dir, int(round(special.get("damage", 10) * skill_damage_mult("melee"))))
	animate_sword()

# Spawns a weapon_projectile.gd configured from a weapon's "special" dict.
# The special's type maps onto the projectile's kind ("flying_slash" flies as
# a "slash", each javelin of a volley as a "javelin").
func launch_projectile(cfg: Dictionary, dir: Vector2, dmg: int, is_crit: bool = false) -> void:
	var p = WEAPON_PROJECTILE_SCRIPT.new()
	p.is_crit = is_crit
	var kind = str(cfg.get("type", "slash"))
	match kind:
		"flying_slash": kind = "slash"
		"javelin_volley": kind = "javelin"
	p.kind = kind
	p.direction = dir.normalized()
	p.speed = float(cfg.get("speed", 500.0))
	p.damage = dmg
	p.max_distance = float(cfg.get("range", 450.0))
	p.pierce = bool(cfg.get("pierce", kind in ["slash", "javelin"]))
	p.aoe_radius = float(cfg.get("aoe", 0.0))
	# a weapon's own status wins; otherwise the Elementalist's Ignite skill rides
	# the cast so a plain wand still burns once you've taken the keystone.
	var status = cfg.get("status", {})
	if status.is_empty():
		var sb = GameState.get_bonus_total("on_hit_burn")
		if sb > 0.0:
			status = {"kind": "burn", "dur": 3.0, "mag": sb}
	p.on_hit_status = status
	p.source = self
	p.position = global_position + dir * 34.0
	get_parent().add_child(p)

# Stormlance: no thrust -- conjure a fan of spectral javelins and let fly.
func throw_javelin_volley(special: Dictionary) -> void:
	play_sfx(SFX_SPEAR)
	var icon = $WeaponIcon
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	weapon_anim_tween = create_tween()
	weapon_anim_tween.tween_property(icon, "scale", Vector2(1.25, 1.25), 0.07)
	weapon_anim_tween.tween_property(icon, "scale", Vector2.ONE, 0.12)
	var count = int(special.get("count", 3))
	var spread = deg_to_rad(float(special.get("spread_deg", 10.0)))
	var aim = get_aim_direction()
	var dmg = int(round(special.get("damage", 10) * skill_damage_mult("spear")))
	for i in range(count):
		var frac = 0.5 if count <= 1 else float(i) / float(count - 1)
		var cr = roll_crit(dmg)
		launch_projectile(special, aim.rotated(lerp(-spread, spread, frac)), cr[0], cr[1])

# Emberstaff / Icicle Wand: a cast that launches a real projectile instead of
# the classic wand's screen nuke. Scales with the Mage tree's wand_damage.
func cast_wand_projectile(special: Dictionary) -> void:
	play_sfx(SFX_BOW)
	var icon = $WeaponIcon
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	weapon_anim_tween = create_tween()
	weapon_anim_tween.tween_property(icon, "scale", Vector2(1.4, 1.4), 0.08)
	weapon_anim_tween.tween_property(icon, "scale", Vector2.ONE, 0.15)
	var cr = roll_crit(int(round(special.get("damage", 10) * skill_damage_mult("wand"))))
	launch_projectile(special, get_aim_direction(), cr[0], cr[1])

# Echo Rift: counts strikes so every 3rd one repeats its damage.
var echo_hit_counter: int = 0
# Ragnarok Blade: counts strikes so every Nth one erupts.
var ragnarok_charge: int = 0
# Singularity Edge: counts strikes so every Nth one collapses a black hole.
var singularity_counter: int = 0

# --- Relic powers (triggered mechanics on equipped relics; see inventory.gd
# relic_power). Cooldown-gated ones track their next-ready time. ---
var phoenix_ready_at := 0.0   # Phoenix Heart: revive off cooldown
var aegis_ready_at := 0.0     # Aegis Ward: shield off cooldown
const PHOENIX_COOLDOWN = 45.0
const AEGIS_COOLDOWN = 6.0

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# Is a relic granting `power` currently equipped?
func has_relic_power(power: String) -> bool:
	for id in GameState.get_equipped_item_ids():
		if Inventory.get_item_def(id).get("relic_power", "") == power:
			return true
	return false

# The relic_value of the first equipped relic with `power` (else `fallback`).
func relic_power_value(power: String, fallback: float) -> float:
	for id in GameState.get_equipped_item_ids():
		var def = Inventory.get_item_def(id)
		if def.get("relic_power", "") == power:
			return def.get("relic_value", fallback)
	return fallback

# --- Relic power effects (see has_relic_power) ---

# Vampire Lord's Signet: heal a share of melee damage dealt this swing.
func apply_omnivamp(total_damage: int) -> void:
	if total_damage <= 0 or not has_relic_power("omnivamp"):
		return
	var heal = int(round(total_damage * relic_power_value("omnivamp", 0.25) * (2.0 if monarch_true_form_active else 1.0)))
	if heal > 0:
		health = min(get_max_health(), health + heal)
		update_health_display()

# Skill-tree melee keystones fired on each landed melee/spear hit: Bloodthirst
# (lifesteal), Warden/Elementalist on-hit status (unusual on melee but general),
# and Executioner (instakill low-HP fodder).
func apply_melee_skills(target: Node2D, dealt: int) -> void:
	if not is_instance_valid(target):
		return
	var ls = GameState.get_bonus_total("lifesteal")
	if monarch_true_form_active:
		ls *= 2.0   # 7/7 true form: the dark drinks twice as deep
	if ls > 0.0 and dealt > 0:
		health = min(get_max_health(), health + int(round(dealt * ls)))
		update_health_display()
	if target.has_method("apply_status"):
		var b = GameState.get_bonus_total("on_hit_burn")
		if b > 0.0: target.apply_status("burn", 3.0, b)
		var po = GameState.get_bonus_total("on_hit_poison")
		if po > 0.0: target.apply_status("poison", 4.0, po)
		if GameState.get_bonus_total("on_hit_slow") > 0.0: target.apply_status("slow", 2.5, 0.6)
	var ex = GameState.get_bonus_total("execute_threshold")
	if ex > 0.0 and not ("boss_id" in target) and "max_health" in target and "health" in target and target.has_method("take_damage"):
		if float(target.health) <= float(target.max_health) * ex and float(target.health) > 0.0:
			spawn_execute_flash(target.global_position)
			target.take_damage(999999)
			# Headhunter: reaping a foe stitches you back together
			var eh = GameState.get_bonus_total("execute_heal")
			if eh > 0.0:
				health = min(get_max_health(), health + int(round(get_max_health() * eh)))
				update_health_display()

# Thornmail: deal `dmg` to every enemy near the player.
func reflect_thorns(dmg: int) -> void:
	if dmg <= 0:
		return
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) <= 220.0:
				e.take_damage(dmg)
	spawn_shock_ring(global_position, 220.0, Color(0.95, 0.35, 0.3, 0.9))

# Aegis Ward: a bright blocking flash around the player.
func spawn_aegis_block() -> void:
	play_sfx(SFX_HURT)
	var ring = Line2D.new()
	var pts = _circle_points(30.0, 28)
	pts.append(pts[0])
	ring.points = pts
	ring.width = 5.0
	ring.default_color = Color(0.6, 0.85, 1.0, 0.95)
	ring.z_index = 50
	add_child(ring)
	var t = ring.create_tween()
	t.tween_property(ring, "scale", Vector2(1.6, 1.6), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.25)
	t.tween_callback(ring.queue_free)

# Phoenix Heart: a golden-orange fire burst as the player rises.
func spawn_phoenix_revive() -> void:
	if has_node("Camera2D"):
		$Camera2D.shake(9.0, 0.4)
	for r in [40.0, 70.0]:
		var ring = Line2D.new()
		var pts = _circle_points(r, 34)
		pts.append(pts[0])
		ring.points = pts
		ring.width = 5.0
		ring.default_color = Color(1.0, 0.55, 0.15, 0.95)
		ring.z_index = 50
		add_child(ring)
		var t = ring.create_tween()
		t.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(ring, "modulate:a", 0.0, 0.45)
		t.tween_callback(ring.queue_free)

# Generic expanding ring in world space (shockwave / thorns pulse).
func spawn_shock_ring(center: Vector2, radius: float, col: Color = Color(1.0, 0.6, 0.2, 0.9)) -> void:
	var ring = Line2D.new()
	var pts = _circle_points(radius, 40)
	pts.append(pts[0])
	ring.points = pts
	ring.width = 5.0
	ring.default_color = col
	ring.z_index = 46
	get_parent().add_child(ring)
	ring.global_position = center
	ring.scale = Vector2(0.15, 0.15)
	var t = ring.create_tween()
	t.tween_property(ring, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	t.tween_callback(ring.queue_free)

# The unique effect of the active Excellent weapon, fired on each melee hit.
func apply_excellent_effect(target: Node2D, damage_dealt: int) -> void:
	# any weapon carrying an on_hit_status (e.g. Frostmourne's chill) applies it
	var st = active_def.get("on_hit_status", {})
	if not st.is_empty() and is_instance_valid(target) and target.has_method("apply_status"):
		target.apply_status(str(st.get("kind", "slow")), float(st.get("dur", 3.0)), float(st.get("mag", 0.0)))
	var effect = active_def.get("unique_effect", "")
	if effect == "gold_touch":
		# Midas Edge -- pain into profit
		var gold = int(round(damage_dealt * active_def.get("unique_value", 0.0)))
		if gold > 0:
			add_currency(gold)
			if is_instance_valid(target):
				spawn_gold_sparks(target.global_position, gold)
		return
	if effect == "echo":
		# Echo Rift -- every 3rd strike repeats the full blow
		echo_hit_counter += 1
		if echo_hit_counter % 3 == 0 and is_instance_valid(target):
			var extra = int(round(damage_dealt * active_def.get("unique_value", 1.0)))
			if target.has_method("take_damage"):
				target.take_damage(extra)
			spawn_echo_ring(target.global_position)
		return
	if effect == "manasteal":
		# Soulthirst -- drink the foe's spirit
		gain_mana(float(active_def.get("unique_value", 0)))
		if is_instance_valid(target):
			spawn_soul_wisps(target.global_position)
		return
	if effect == "chrono":
		# Chrono Edge -- a chance to rewind the swing entirely
		if randf() < float(active_def.get("unique_value", 0.25)):
			attack_cooldown_remaining = 0.0
			spawn_chrono_flash()
		return
	if effect == "bossbane":
		# Wizardsbane -- mana sustain on every hit, huge bonus vs bosses
		gain_mana(float(active_def.get("mana_on_hit", 0)))
		if is_instance_valid(target) and "boss_id" in target and target.has_method("take_damage"):
			var extra = int(round(damage_dealt * active_def.get("unique_value", 1.5)))
			if extra > 0:
				target.take_damage(extra)
				spawn_bane_flash(target.global_position)
		return
	if effect == "ragnarok":
		# Ragnarok Blade -- every hit throws a slash and stokes the storm;
		# the Nth hit erupts into a screen-clearing ultimate.
		launch_projectile({"type": "flying_slash", "speed": 560.0, "range": 470.0}, get_aim_direction(), 14)
		ragnarok_charge += 1
		if ragnarok_charge >= int(active_def.get("unique_value", 8)):
			ragnarok_charge = 0
			unleash_ragnarok()
		return
	if effect == "execute":
		# Doombringer -- delete low-HP fodder outright; bosses take bonus instead
		if not is_instance_valid(target) or not target.has_method("take_damage"):
			return
		if "boss_id" in target:
			var extra = int(round(damage_dealt * active_def.get("boss_bonus", 0.5)))
			if extra > 0:
				target.take_damage(extra)
		elif "max_health" in target and "health" in target:
			if float(target.health) <= float(target.max_health) * active_def.get("unique_value", 0.18):
				spawn_execute_flash(target.global_position)
				target.take_damage(999999)
		return
	if effect == "singularity":
		# Singularity Edge -- every Nth hit collapses a black hole at the target
		singularity_counter += 1
		if singularity_counter % int(active_def.get("unique_value", 5)) == 0 and is_instance_valid(target):
			collapse_singularity(target.global_position, active_def.get("unique_radius", 320.0), damage_dealt)
		return
	if effect == "shockwave":
		# Worldsplitter -- every blow blasts a wide radius around the target
		if is_instance_valid(target):
			var radius = active_def.get("unique_radius", 260.0)
			var blast = int(round(damage_dealt * active_def.get("unique_value", 0.6)))
			for group_name in HOSTILE_GROUPS:
				for e in get_tree().get_nodes_in_group(group_name):
					if e == target or not is_instance_valid(e) or not e.has_method("take_damage"):
						continue
					if "is_dead" in e and e.is_dead:
						continue
					if target.global_position.distance_to(e.global_position) <= radius:
						e.take_damage(blast)
			spawn_shock_ring(target.global_position, radius)
		return
	if effect == "radiance":
		# Dawnbreaker -- heal on hit + a piercing sun-slash
		var heal = int(round(damage_dealt * active_def.get("unique_value", 0.2)))
		if heal > 0:
			health = min(get_max_health(), health + heal)
			update_health_display()
		launch_projectile({"type": "flying_slash", "speed": 540.0, "range": 460.0}, get_aim_direction(), int(round(damage_dealt * 0.5)))
		return
	if effect == "lifesteal":
		var heal = int(round(damage_dealt * active_def.get("unique_value", 0.0)))
		health = min(get_max_health(), health + heal)
		update_health_display()
		if heal > 0 and is_instance_valid(target):
			spawn_blood_steal(target.global_position)
	elif effect == "chain":
		var radius = active_def.get("unique_radius", 0.0)
		var zap = int(active_def.get("unique_value", 0))
		for group_name in HOSTILE_GROUPS:
			for e in get_tree().get_nodes_in_group(group_name):
				if e == target or not is_instance_valid(e):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if target.global_position.distance_to(e.global_position) <= radius and e.has_method("take_damage"):
					e.take_damage(zap)
					spawn_lightning_bolt(target.global_position, e.global_position)

# --- Excellent-weapon hit visuals (all procedural, world-space, self-cleaning) ---

const LIGHTNING_CORE_COLOR = Color(0.7, 0.9, 1.0, 1.0)
const LIGHTNING_GLOW_COLOR = Color(0.4, 0.65, 1.0, 0.35)
const BLOOD_COLOR = Color(0.72, 0.05, 0.1, 0.95)

# A flickering jagged bolt from one enemy to another (Thundercaller's chain).
# Placed at from_pos with points relative to it, so it lands correctly no
# matter what transform the parent level node has.
func spawn_lightning_bolt(from_pos: Vector2, to_pos: Vector2) -> void:
	var local_end = to_pos - from_pos
	var glow = Line2D.new()
	glow.width = 8.0
	glow.default_color = LIGHTNING_GLOW_COLOR
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.z_index = 49
	var core = Line2D.new()
	core.width = 3.0
	core.default_color = LIGHTNING_CORE_COLOR
	core.joint_mode = Line2D.LINE_JOINT_ROUND
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	core.z_index = 50
	var pts = _jagged_points(Vector2.ZERO, local_end)
	core.points = pts
	glow.points = pts
	get_parent().add_child(glow)
	get_parent().add_child(core)
	glow.global_position = from_pos
	core.global_position = from_pos
	# flicker once, then fade out and free
	var t = core.create_tween()
	t.tween_interval(0.05)
	t.tween_callback(func():
		if is_instance_valid(core):
			var p = _jagged_points(Vector2.ZERO, local_end)
			core.points = p
			glow.points = p)
	t.tween_interval(0.04)
	t.tween_property(core, "modulate:a", 0.0, 0.18)
	t.parallel().tween_property(glow, "modulate:a", 0.0, 0.18)
	t.tween_callback(func():
		if is_instance_valid(glow): glow.queue_free()
		if is_instance_valid(core): core.queue_free())

# Builds a lightning path from a to b with perpendicular random kinks.
func _jagged_points(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var segments = 7
	var dir = b - a
	var length = dir.length()
	var perp = Vector2(-dir.y, dir.x).normalized() if length > 0.01 else Vector2.UP
	for i in range(segments + 1):
		var frac = float(i) / segments
		var base = a + dir * frac
		if i != 0 and i != segments:
			base += perp * randf_range(-1.0, 1.0) * length * 0.09
		pts.append(base)
	return pts

# Red droplets streaming from the struck enemy back into the player, selling
# the Vampiric Fang's life-drain.
func spawn_blood_steal(from_pos: Vector2) -> void:
	var to_pos = global_position
	for i in range(7):
		var drop = Polygon2D.new()
		drop.polygon = _circle_points(randf_range(2.0, 4.0), 8)
		drop.color = BLOOD_COLOR
		drop.z_index = 48
		get_parent().add_child(drop)
		drop.global_position = from_pos + Vector2(randf_range(-11, 11), randf_range(-16, 6))
		var mid = drop.global_position.lerp(to_pos, 0.5) + Vector2(randf_range(-18, 18), randf_range(-28, -6))
		var dur = randf_range(0.26, 0.46)
		var move = drop.create_tween()
		move.tween_property(drop, "global_position", mid, dur * 0.5).set_trans(Tween.TRANS_SINE)
		move.tween_property(drop, "global_position", to_pos, dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		var fade = drop.create_tween()
		fade.tween_interval(dur * 0.55)
		fade.tween_property(drop, "modulate:a", 0.0, dur * 0.45)
		fade.tween_callback(drop.queue_free)

func _circle_points(radius: float, sides: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(sides):
		var ang = TAU * float(i) / sides
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts

# Midas Edge: gold coins burst up from the struck enemy and a "+N" drifts off.
func spawn_gold_sparks(from_pos: Vector2, gold: int) -> void:
	for i in range(5):
		var coin = Polygon2D.new()
		coin.polygon = _circle_points(randf_range(2.0, 3.5), 8)
		coin.color = Color(1.0, 0.84, 0.2, 0.95)
		coin.z_index = 48
		get_parent().add_child(coin)
		coin.global_position = from_pos + Vector2(randf_range(-10, 10), randf_range(-8, 4))
		var t = coin.create_tween()
		t.tween_property(coin, "global_position", coin.global_position + Vector2(randf_range(-16, 16), randf_range(-34, -18)), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(coin, "modulate:a", 0.0, 0.4)
		t.tween_callback(coin.queue_free)
	var tag = Label.new()
	tag.text = "+%d" % gold
	tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1))
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	tag.add_theme_constant_override("outline_size", 3)
	tag.z_index = 49
	get_parent().add_child(tag)
	tag.global_position = from_pos + Vector2(-8, -30)
	var tt = tag.create_tween()
	tt.tween_property(tag, "global_position:y", tag.global_position.y - 26.0, 0.5)
	tt.parallel().tween_property(tag, "modulate:a", 0.0, 0.5)
	tt.tween_callback(tag.queue_free)

# Doombringer execute: a crimson X-slash flashes where a foe is culled.
func spawn_execute_flash(at_pos: Vector2) -> void:
	for ang in [0.7, -0.7]:
		var bar = ColorRect.new()
		bar.size = Vector2(46, 5)
		bar.position = Vector2(-23, -2.5)
		bar.color = Color(0.9, 0.1, 0.15, 0.95)
		bar.pivot_offset = Vector2(23, 2.5)
		bar.rotation = ang
		bar.z_index = 50
		var holder = Node2D.new()
		holder.z_index = 50
		get_parent().add_child(holder)
		holder.global_position = at_pos
		holder.add_child(bar)
		var t = holder.create_tween()
		t.tween_property(bar, "modulate:a", 0.0, 0.3)
		t.tween_callback(holder.queue_free)

# Singularity Edge: drag every nearby enemy toward one point, damage them, and
# paint an imploding purple void there.
func collapse_singularity(center: Vector2, radius: float, damage_dealt: int) -> void:
	if has_node("Camera2D"):
		$Camera2D.shake(7.0, 0.35)
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if center.distance_to(e.global_position) > radius:
				continue
			if e.has_method("apply_knockback"):
				var dx = center.x - e.global_position.x
				var pull_sign = 1 if dx >= 0.0 else -1
				e.apply_knockback(pull_sign, min(absf(dx), radius))
			e.take_damage(int(round(damage_dealt * 1.5)))
	spawn_singularity_visual(center)

func spawn_singularity_visual(center: Vector2) -> void:
	# a dark core that swells then implodes, ringed by an inward-collapsing halo
	var core = Polygon2D.new()
	core.polygon = _circle_points(26.0, 22)
	core.color = Color(0.15, 0.02, 0.25, 0.92)
	core.z_index = 47
	get_parent().add_child(core)
	core.global_position = center
	core.scale = Vector2(0.2, 0.2)
	var ct = core.create_tween()
	ct.tween_property(core, "scale", Vector2(1.6, 1.6), 0.22).set_trans(Tween.TRANS_SINE)
	ct.tween_property(core, "scale", Vector2(0.05, 0.05), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	ct.parallel().tween_property(core, "modulate:a", 0.0, 0.18)
	ct.tween_callback(core.queue_free)
	var halo = Line2D.new()
	var pts = _circle_points(80.0, 32)
	pts.append(pts[0])
	halo.points = pts
	halo.width = 4.0
	halo.default_color = Color(0.7, 0.4, 1.0, 0.9)
	halo.z_index = 47
	get_parent().add_child(halo)
	halo.global_position = center
	var ht = halo.create_tween()
	ht.tween_property(halo, "scale", Vector2(0.1, 0.1), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ht.parallel().tween_property(halo, "modulate:a", 0.0, 0.34)
	ht.tween_callback(halo.queue_free)

# Ragnarok Blade eruption: a 12-way slash nova + a meteor barrage raining
# around the player + a big shockwave ring. The showpiece ultimate.
func unleash_ragnarok() -> void:
	play_sfx(SFX_SWORD)
	if has_node("Camera2D"):
		$Camera2D.shake(11.0, 0.5)
	# 12 flying slashes in a full ring
	for i in range(12):
		var dir = Vector2.RIGHT.rotated(TAU * float(i) / 12.0)
		launch_projectile({"type": "flying_slash", "speed": 520.0, "range": 520.0}, dir, 20)
	# a barrage of meteors (AoE fireballs) plunging down around the player
	for i in range(6):
		var mp = WEAPON_PROJECTILE_SCRIPT.new()
		mp.kind = "fireball"
		mp.direction = Vector2.DOWN
		mp.speed = 720.0
		mp.damage = 30
		mp.max_distance = 620.0
		mp.aoe_radius = 120.0
		mp.source = self
		mp.position = Vector2(global_position.x + randf_range(-340.0, 340.0), global_position.y - 560.0)
		get_parent().add_child(mp)
	spawn_ragnarok_ring()
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("RAGNAROK!")

# The expanding fire shockwave that marks the eruption.
func spawn_ragnarok_ring() -> void:
	var ring = Line2D.new()
	var pts = _circle_points(40.0, 48)
	pts.append(pts[0])
	ring.points = pts
	ring.width = 6.0
	ring.default_color = Color(1.0, 0.6, 0.15, 0.9)
	ring.z_index = 46
	get_parent().add_child(ring)
	ring.global_position = global_position
	ring.scale = Vector2(0.3, 0.3)
	var t = ring.create_tween()
	t.tween_property(ring, "scale", Vector2(7.0, 7.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.4)
	t.tween_callback(ring.queue_free)

# Wizardsbane: a pale rune-burst on the boss where the bane damage lands.
func spawn_bane_flash(at_pos: Vector2) -> void:
	for i in range(6):
		var shard = Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(0, -9), Vector2(2.5, 0), Vector2(0, 9), Vector2(-2.5, 0)])
		shard.color = Color(0.7, 1.0, 0.85, 0.95)
		shard.rotation = TAU * float(i) / 6.0
		shard.z_index = 49
		get_parent().add_child(shard)
		shard.global_position = at_pos
		var dir = Vector2(cos(shard.rotation - PI / 2.0), sin(shard.rotation - PI / 2.0))
		var t = shard.create_tween()
		t.tween_property(shard, "global_position", at_pos + dir * 40.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(shard, "modulate:a", 0.0, 0.24)
		t.tween_callback(shard.queue_free)

# Chrono Edge: a golden clock-ring blinks around the player as time rewinds.
func spawn_chrono_flash() -> void:
	var ring = Line2D.new()
	var pts = _circle_points(18.0, 24)
	pts.append(pts[0])
	ring.points = pts
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.9, 0.4, 0.95)
	ring.z_index = 49
	get_parent().add_child(ring)
	ring.global_position = global_position
	# a single "clock hand" sweeping backwards sells the rewind
	var hand = Line2D.new()
	hand.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -14)])
	hand.width = 3.0
	hand.default_color = Color(1.0, 0.95, 0.6, 1.0)
	hand.z_index = 50
	get_parent().add_child(hand)
	hand.global_position = global_position
	var t = ring.create_tween()
	t.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	t.tween_callback(ring.queue_free)
	var h = hand.create_tween()
	h.tween_property(hand, "rotation", -TAU * 0.75, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	h.parallel().tween_property(hand, "modulate:a", 0.0, 0.3)
	h.tween_callback(hand.queue_free)

# Echo Rift: a cyan shock-ring snaps open where the echoed blow lands.
func spawn_echo_ring(at_pos: Vector2) -> void:
	var ring = Line2D.new()
	var pts = _circle_points(10.0, 20)
	pts.append(pts[0])   # close the loop
	ring.points = pts
	ring.width = 3.0
	ring.default_color = Color(0.5, 0.9, 0.95, 0.9)
	ring.z_index = 49
	get_parent().add_child(ring)
	ring.global_position = at_pos
	var t = ring.create_tween()
	t.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	t.tween_callback(ring.queue_free)

# Soulthirst: violet wisps stream from the struck enemy into the player,
# selling the mana drain (same choreography as the Fang's blood drops).
func spawn_soul_wisps(from_pos: Vector2) -> void:
	var to_pos = global_position
	for i in range(6):
		var wisp = Polygon2D.new()
		wisp.polygon = _circle_points(randf_range(2.0, 4.0), 8)
		wisp.color = Color(0.6, 0.4, 1.0, 0.9)
		wisp.z_index = 48
		get_parent().add_child(wisp)
		wisp.global_position = from_pos + Vector2(randf_range(-11, 11), randf_range(-16, 6))
		var mid = wisp.global_position.lerp(to_pos, 0.5) + Vector2(randf_range(-18, 18), randf_range(-28, -6))
		var dur = randf_range(0.26, 0.46)
		var move = wisp.create_tween()
		move.tween_property(wisp, "global_position", mid, dur * 0.5).set_trans(Tween.TRANS_SINE)
		move.tween_property(wisp, "global_position", to_pos, dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		var fade = wisp.create_tween()
		fade.tween_interval(dur * 0.55)
		fade.tween_property(wisp, "modulate:a", 0.0, dur * 0.45)
		fade.tween_callback(wisp.queue_free)

func closest_body(bodies: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist = INF
	for body in bodies:
		var dist = global_position.distance_to(body.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = body
	return nearest

func animate_sword() -> void:
	play_sfx(SFX_SWORD)
	var icon = $WeaponIcon
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	is_attacking = true
	var base_angle = get_aim_direction().angle()
	icon.rotation = base_angle - deg_to_rad(60)
	weapon_anim_tween = create_tween()
	weapon_anim_tween.tween_property(icon, "rotation", base_angle + deg_to_rad(60), 0.1)
	weapon_anim_tween.tween_property(icon, "rotation", base_angle, 0.08)
	weapon_anim_tween.tween_callback(func(): is_attacking = false)

func animate_spear(stats: Dictionary) -> void:
	play_sfx(SFX_SPEAR)
	var base_offset = stats.icon_offset
	var lunge_offset = base_offset + 30.0
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	is_attacking = true
	spear_hit_bodies.clear()
	$SpearTipArea.monitoring = true
	weapon_anim_tween = create_tween()
	weapon_anim_tween.tween_method(update_weapon_visual, base_offset, lunge_offset, 0.1)
	weapon_anim_tween.tween_method(update_weapon_visual, lunge_offset, base_offset, 0.15)
	weapon_anim_tween.tween_callback(func(): $SpearTipArea.monitoring = false)
	weapon_anim_tween.tween_callback(func(): is_attacking = false)

func animate_bow(stats: Dictionary) -> void:
	play_sfx(SFX_BOW)
	var bow = $BowVisual
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	weapon_anim_tween = create_tween()
	weapon_anim_tween.tween_property(bow, "scale", Vector2(1.3, 1.3), 0.06)
	weapon_anim_tween.tween_property(bow, "scale", Vector2.ONE, 0.1)
	spawn_arrow(stats, get_aim_direction())

func spawn_arrow(stats: Dictionary, aim_dir: Vector2) -> void:
	# a bow's "special" can fan the shot out (count), make every arrow hunt on
	# its own (homing), or BOTH (Tempest Bow's storm_shot) -- plain bows fire
	# the single straight arrow.
	var special = active_def.get("special", {})
	var special_type = str(special.get("type", ""))
	var count = int(special.get("count", 1)) if special.has("count") else 1
	# Ranger multishot keystones (Twin Shot / Arrow Storm / Tempest) add arrows
	count += int(GameState.get_bonus_total("multishot"))
	# Warden keystones make arrows carry statuses. These now STACK -- Venom
	# (poison) plus a fork of Frost (slow) or Flame (burn) all ride the arrow.
	var arrow_statuses := []
	var poi = GameState.get_bonus_total("on_hit_poison")
	if poi > 0.0:
		arrow_statuses.append({"kind": "poison", "dur": 4.0, "mag": poi})
	if GameState.get_bonus_total("on_hit_slow") > 0.0:
		arrow_statuses.append({"kind": "slow", "dur": 3.0, "mag": 0.55})
	var abn = GameState.get_bonus_total("on_hit_burn")
	if abn > 0.0:
		arrow_statuses.append({"kind": "burn", "dur": 3.0, "mag": abn})
	if count < 1:
		count = 1
	# Seeker Arrows / Tempest (arrow_homing) make every shaft hunt; Piercing Shot
	# (arrow_pierce) punches through foes; Contagion (poison_spread) leaps poison.
	var homing = bool(special.get("homing", false)) or special_type == "homing" or GameState.get_bonus_total("arrow_homing") > 0.0
	var pierce_count = int(GameState.get_bonus_total("arrow_pierce"))
	var spreads_poison = GameState.get_bonus_total("poison_spread") > 0.0
	var spread = deg_to_rad(float(special.get("spread_deg", 0.0)))
	var hover = hover_for_mouse(stats.icon_offset)
	for i in range(count):
		var dir = aim_dir
		if count > 1:
			dir = aim_dir.rotated(lerp(-spread, spread, float(i) / float(count - 1)))
		var arrow = ARROW_SCENE.instantiate()
		# loose from wherever the levitating bow hovers (may be far out with
		# the Levitate skills), not from the character's body
		arrow.position = global_position + dir * (hover + 8.0)
		var cr = roll_crit(int(round(stats.damage * skill_damage_mult("bow"))))
		arrow.setup(dir, cr[0], stats.knockback_min, stats.knockback_max, 4)
		arrow.is_crit = cr[1]
		arrow.homing = homing
		arrow.enemy_statuses = arrow_statuses
		arrow.pierce_count = pierce_count
		arrow.poison_spread = spreads_poison
		get_parent().add_child(arrow)

func cast_wand() -> void:
	play_sfx(SFX_BOW)
	var icon = $WeaponIcon
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	weapon_anim_tween = create_tween()
	weapon_anim_tween.tween_property(icon, "scale", Vector2(1.4, 1.4), 0.08)
	weapon_anim_tween.tween_property(icon, "scale", Vector2.ONE, 0.15)

	for group_name in HOSTILE_GROUPS:
		for enemy in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(enemy) and enemy.has_method("take_damage") and "is_dead" in enemy and not enemy.is_dead:
				enemy.take_damage(999999)

# The Runeweave Scepter's real (finite) screen-wipe: a big burst of arcane
# damage to every enemy on screen, scaled by the Mage tree's Wand DMG. Wipes
# trash outright, chunks bosses -- unlike the admin wand it does NOT instakill.
func cast_wand_nuke(special: Dictionary) -> void:
	play_sfx(SFX_BOW)
	var icon = $WeaponIcon
	if weapon_anim_tween:
		weapon_anim_tween.kill()
	weapon_anim_tween = create_tween()
	weapon_anim_tween.tween_property(icon, "scale", Vector2(1.4, 1.4), 0.08)
	weapon_anim_tween.tween_property(icon, "scale", Vector2.ONE, 0.15)
	if has_node("Camera2D"):
		$Camera2D.shake(6.0, 0.25)
	var dmg = int(round(float(special.get("damage", 200)) * skill_damage_mult("wand")))
	for group_name in HOSTILE_GROUPS:
		for enemy in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(enemy) and enemy.has_method("take_damage") and "is_dead" in enemy and not enemy.is_dead:
				var cr = roll_crit(dmg)
				enemy.take_damage(cr[0])
				show_hit(enemy, cr[0], cr[1])
	spawn_shock_ring(global_position, 380.0, Color(0.6, 0.4, 1.0, 0.85))
