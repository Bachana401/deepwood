extends CharacterBody2D

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 900.0
# DEV CALL (2026-07-20): the old dash covered 600*0.15 = 90px -- barely
# half a body length, a shuffle pretending to be a dash. Doubled to 180px
# the right way: FASTER (not floatier) and a touch longer.
const DASH_SPEED = 900.0
const DASH_DURATION = 0.2
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
# the last solid ground we stood on -- a fall-out-of-the-world safety net snaps
# us back here instead of falling forever (a gap, or collision not built yet).
var _last_ground_pos := Vector2.ZERO
const FALL_RECOVER_DROP := 2500.0    # a drop this far below the last ground = the void

# --- Flight (Aetherwing relic) ---
# Hold Space in the air to levitate upward. EVERY class can do this -- it costs
# MANA, and that cost is the only thing limiting it, so you can't hang in the
# air for long. A Mage pays a reduced rate AND carries a far deeper pool, so a
# Mage naturally stays aloft longest; a Sword class gets a short hop and lands.
# Releasing Space (or running dry) lets you fall at NORMAL speed -- levitation
# doesn't slow the drop, and only fall_immunity spares you the landing.
const FLIGHT_RISE_SPEED = -300.0        # brisk ascent while holding Space
const LEVITATE_MANA_PER_SEC = 16.0      # base mana burned per second aloft
const LEVITATE_MAGE_DISCOUNT = 0.55     # a Mage's native element -- much cheaper
# The Monarch does not need feathers. From the first stirring of the shadow
# (1/7, character level 5) he simply stops obeying the ground -- the Aetherwing
# is only ever a shortcut to something he was always going to grow into. This
# now gates only the WINGS VISUAL, not the ability.
const LEVITATE_STAGE = 1
var is_levitating := false         # airborne under his own power -> levitate clip
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
# MU Online / Diablo liquid globes (dev ask 2026-07-22) -- the HUD's HP + mana.
const HUD_ORB = preload("res://hud_orb.gd")
var hp_orb: Control = null
var mana_orb: Control = null
var buff_row: HBoxContainer = null   # the buff/debuff chips above the HP globe
var _chip_accum := 0.0
# The light the player carries -- a warm pool so the Terraria-dark dungeon is
# always readable right around the hero. On only where it's dark (the dungeon).
var player_light: PointLight2D = null
var _tile_world_checked := false     # cache: a scene either has a tile_world or never will
var _in_tile_world := false
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
# How far apart two things must be vertically before they count as standing on
# different ground (used by building relocation -- see try_plant_building).
const SAME_GROUND_Y = 400.0
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
# (selected_hotbar_slot removed by the audit: written on every hotbar press,
# read by nothing -- the hotbar highlight derives from active_weapon_id.)

var attack_cooldown_remaining = 0.0
var weapon_anim_tween: Tween = null
var spear_hit_bodies: Array = []
var is_attacking = false

# --- Aiming ---
# Weapons are HELD, not levitated. The cursor sets the DIRECTION of a swing;
# it never sets the distance. Every bit of reach comes from the weapon's own
# stats (range_offset / area_size), so melee stays melee: a spear outranges a
# dagger because a spear is longer, and no skill can drag your blade across
# the room.
# (The mouse-aim-pose subsystem -- MOUSE_AIM_HOLD, mouse_aim_timer, the
# retract/reverse flags, _aim_length() and the _input that fed them -- was
# removed by the audit: nothing ever consumed any of it (current_anim_state
# never read the timer, ANIM_DEFS has no "aim" state), yet the node subscribed
# to every mouse-motion event to keep it warm. Re-add alongside a real aim
# animation if one ships.)

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
			var left := inventory.add_item("coin_gold", delta)
			if left > 0:
				# a FULL bag holding zero gold has no stack to grow -- awarded
				# coin was silently DESTROYED here (the one edge the raised
				# max_stack doesn't cover). Spill it at the player's feet
				# instead, exactly like death does; it waits until space frees.
				# ONE pile, not one pickup per kill: a floor's worth of kills
				# with a full bag used to litter dozens of bobbing coin nodes,
				# each with its own tween and day-long despawn timer -- and the
				# player was never told why their income read as zero. Merge
				# into a nearby spilled pile and say it once.
				var merged := false
				for cp in get_tree().get_nodes_in_group("currency_pickup"):
					if is_instance_valid(cp) \
							and cp.global_position.distance_to(global_position) < 120.0:
						cp.amount += left
						if cp.has_method("refresh_label"):
							cp.refresh_label()
						merged = true
						break
				if not merged:
					var pickup = CURRENCY_PICKUP_SCRIPT.new()
					pickup.global_position = global_position
					pickup.setup(left, true)
					if get_parent() != null:
						get_parent().call_deferred("add_child", pickup)
				if _now() > _spill_warned_at + 8.0:
					_spill_warned_at = _now()
					var stack = get_tree().get_first_node_in_group("notification_stack")
					if stack:
						stack.show_notification("💰 Your bag is full — gold is piling up at your feet.")
		elif delta < 0:
			inventory.remove_item("coin_gold", -delta)

var _spill_warned_at := -100.0

# === FISHING (pillar 3, 2026-07-28): cast / bite / strike ===
# A wielded rod near "fish_water" CASTS on attack instead of swinging; the
# water bites after a rod-tier gap (fishing.gd), and a second swing inside
# the window is the STRIKE that lands the roll. Walking off drags the line
# dead. State lives here; tables and rolls live in fishing.gd.
var _fish_state := ""              # "" idle | "wait" | "bite"
var _fish_timer := 0.0
var _fish_zone: Node = null
var _fish_cast_pos := Vector2.ZERO
var _fish_bobber: Node2D = null
const FISH_BITE_WINDOW := 1.4      # generous: fishing is a rest, not a reflex test
const FISH_DRIFT_CANCEL := 46.0    # wander this far and the line goes dead

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
var weapon_sprite: Sprite2D = null   # item-art overhaul: the held weapon's real sprite (art/items/<id>.png), else hidden and the ColorRect bar shows

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
# At 7/7, when there is no one left alive to see it, he stops wearing the man
# entirely: crowned, armoured, cloaked, with fire where his face was. A third
# skin folder on the same swap as the hood -- absent art just leaves him hooded.
const ASCENDED_ART := "res://art/ascended/player_"
const HOOD_STAGE := 5
var _hooded := false
var _ascended := false
var _art_prefix := BASE_ART
# The man's own drawn scale, set once from the base art. Every other skin sizes
# itself relative to this rather than to whatever sprite happens to be loaded.
var _man_scale := Vector2.ONE
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
	# The Monarch's own idle, worn from 5/7 (the moment the hood goes up): he
	# stops standing like a brawler with his fists up and stands like a
	# sovereign. Slower, because nothing about him needs to hurry.
	{"name": "monarchidle", "fps": 6.0, "loop": true},
	# Hanging in the air under his own power -- feet loose, coat drifting up.
	# Without this he played the JUMP frames the whole time he hovered.
	{"name": "levitate", "fps": 7.0, "loop": true},
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
	build_wings_visual()
	build_mana_bar()
	build_orbs()
	build_player_light()
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
		else:
			# a FOUNDER'S CACHE (dev bug 2026-07-23: the tutorial demanded a wall the
			# penniless new player could never afford). Timber + stone JUST enough to
			# raise the first wall, farm and cottage -- the tutorial builds, which cost
			# no gold. Kept lean (dev: "too much wood") so you don't start on a pile.
			inventory.add_item("wood", 20)
			inventory.add_item("stone", 12)
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
	# the PROLOGUE ends -> the ARRIVAL begins (new canon): the calamity orphan
	# reaches the treeline, the bond completes (the choking beat), and he walks
	# straight into the three defenders' fight -- combat learned in company
	# The prologue plays, and then he is ALONE on the road (dev 2026-07-21).
	# The fight is no longer waiting a few steps from where he wakes: he walks
	# the whole road by himself, and only finds the three defenders when the
	# village wall comes into view. main.gd arms that trigger; see _check_arrival.
	DialogueBox.play(self, Story.PROLOGUE, func():
		var m = get_parent()
		if m and m.has_method("arm_arrival_battle"):
			m.arm_arrival_battle())

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
	# The real held-weapon sprite: a Sprite2D CHILD of WeaponIcon, so it inherits
	# the exact same aim rotation (WeaponIcon rotates to the cursor about the grip
	# pivot) AND the swing scale-punch for free. The art is authored DIAGONALLY
	# (blade to the upper-right); update_weapon_sprite rotates it +45deg so the
	# blade lands along WeaponIcon's +x (the aim axis) and scales it to the
	# weapon's reach. Hidden until a real-art weapon is wielded.
	weapon_sprite = Sprite2D.new()
	weapon_sprite.centered = true
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.visible = false
	weapon_sprite.z_index = 1        # in front of the (transparent) bar
	$WeaponIcon.add_child(weapon_sprite)

# Shows the wielded weapon's real sprite when one exists (art/items/<id>.png),
# and blanks the fallback ColorRect bar + crossguard so they don't show through
# behind it. Returns true when a texture is in use, so the guard update can skip
# the bar treatment. The SAME texture is the inventory icon -- bag and hand match.
# In-hand render of the diagonal weapon art (2026-07-28 calibration). The art
# is drawn with the blade to the UPPER-RIGHT (~-45deg on screen). WeaponIcon
# already rotates to the aim (its local +x = the aim direction) and pivots about
# the grip, so we only set the sprite's LOCAL transform once per wield:
#   * rotate +HELD_ROT_DEG so the NE blade lines up with local +x (the aim),
#   * scale so the blade spans ~the weapon's reach,
#   * push the centre out along +x so the grip sits near the hand and the blade
#     reaches forward.
# Tunable so it can be eyeballed via screenshots. Bows keep their own BowVisual.
const HELD_SPRITE_ENABLED := true
const HELD_ROT_DEG := 45.0        # NE-authored blade -> WeaponIcon +x
const HELD_BLADE_FRAC := 0.80     # fraction of the square art the blade spans
const HELD_LEN_MULT := 1.25       # blade reach relative to the weapon's icon length
const HELD_MIN_LEN := 30.0
const HELD_BOW_HEIGHT := 40.0     # on-screen bow height in hand (BowVisual was 28)
func update_weapon_sprite() -> bool:
	if not weapon_sprite:
		return false
	var tex: Texture2D = Inventory.icon_texture(active_weapon_id) if has_weapon() else null
	# bows draw their own procedural bow (BowVisual); everything else (melee/
	# spear/wand) shows the real sprite in hand
	if not HELD_SPRITE_ENABLED or tex == null:
		weapon_sprite.visible = false
		return false
	weapon_sprite.texture = tex
	if active_weapon_type == "bow":
		# bows are AUTHORED upright (the pose for aiming east): no extra local
		# rotation -- WeaponIcon's aim rotation tilts the whole bow toward the
		# cursor, exactly like Terraria. Held at the grip, sized by height.
		var s_b: float = HELD_BOW_HEIGHT / float(tex.get_height())
		weapon_sprite.scale = Vector2(s_b, s_b)
		weapon_sprite.rotation = 0.0
		weapon_sprite.position = Vector2(6.0, active_stats.icon_size.y * 0.5)
	else:
		var blade_len: float = maxf(active_stats.icon_size.x, HELD_MIN_LEN) * HELD_LEN_MULT
		var s: float = blade_len / (float(tex.get_width()) * HELD_BLADE_FRAC)
		weapon_sprite.scale = Vector2(s, s)
		weapon_sprite.rotation = deg_to_rad(HELD_ROT_DEG)
		# centre placed along the aim axis (+x), lifted to the grip line (pivot.y)
		weapon_sprite.position = Vector2(blade_len * 0.5, active_stats.icon_size.y * 0.5)
	weapon_sprite.visible = true
	$WeaponIcon.color = Color(0, 0, 0, 0)   # hide the fallback bar; the sprite carries the look
	return true

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
		sh.code = MONARCH_PALLOR_SHADER
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

# The Monarch goes corpse-pale as he rises -- but a man losing his colour does
# NOT bleach his coat, his hair and his boots with him. The old shader drained
# the WHOLE sprite toward grey, which is why he faded into a washed-out smudge
# instead of a pale man in dark clothes.
#
# Only SKIN drains now. His palette separates cleanly (sampled from the art):
#   skin  0.94,0.74,0.68 + two shadow tones -- warm, ordered r>=g>=b, bright
#   coat  0.14,0.15,0.24 -- blue-dominant, b > r
#   trim  0.51,0.09,0.42 -- magenta, g < b
#   hair  0.04,0.02,0.03 -- near black
# so the mask is: warm ordering, bright enough not to be hair/boots, warm
# enough not to be neutral grey, not so warm it catches the magenta trim.
# Everything that isn't skin passes through untouched, at any stage.
const MONARCH_PALLOR_SHADER := """
shader_type canvas_item;
uniform float pallor : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float mx = max(c.r, max(c.g, c.b));
	float warmth = c.r - c.b;
	float is_skin =
		  step(c.b, c.g)          // g >= b
		* step(c.g, c.r)          // r >= g   (warm skin ordering)
		* step(0.50, mx)          // bright   (not the black hair or boots)
		* step(0.10, warmth)      // warm     (not neutral grey/steel)
		* step(warmth, 0.52);     // not the coat's saturated magenta trim
	// corpse-pale: drain the blood but keep the shading that models the face
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 pale = mix(vec3(lum), vec3(0.86, 0.88, 0.93), 0.5) * 1.02;
	COLOR = vec4(mix(c.rgb, pale, pallor * is_skin), c.a);
}
"""

# ========================= THE SHADOW MONARCH'S POWERS ========================
# The OP half of the hidden 7-stage passive (design: VILLAGE_SYSTEMS.md 8b).
#   3/7 Shadowstep      -- dashes have full i-frames + a torn-shadow trail
#   4/7 Dread Sovereign -- a constant aura of dread slows every foe near you
#   5/7 Rise, Shade     -- kills tear the foe's shadow free to fight for you
#   6/7 The Long Dark   -- a lethal hit melts you into shadow, not a grave
#   7/7 true form       -- 2x size, permanent shades, shadow novas, doubled
#                          lifesteal. It only fully manifests when no villager
#                          is left alive to see it (or forced from the P panel).

# How much taller than the man the god-form stands. Dev: "tower him... 1.7x size
# of original character" -- tall is better than wide, because width only buys an
# illogical hitbox. Visual only; collision never changes.
const TRUE_FORM_SCALE := 1.7
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
	# the true form novas on its own; Dominion's "Deadly Presence" grants the
	# same periodic detonation to the mortal Monarch, faster the more power taken
	if (tf or GameState.get_skill_total("nova_passive") > 0.0) and not is_dead:
		monarch_nova_accum += delta
		var period := NOVA_PERIOD * (0.7 if not tf else 1.0)
		if monarch_nova_accum >= period:
			monarch_nova_accum = 0.0
			fire_shadow_nova()
	# Dominion's "Sovereign's Dread": a standing aura that saps the will of
	# everything near the Monarch -- a periodic slow, no button to press
	var fear := GameState.get_skill_total("fear_aura")
	if fear > 0.0 and not is_dead:
		fear_aura_accum += delta
		if fear_aura_accum >= FEAR_AURA_PERIOD:
			fear_aura_accum = 0.0
			apply_fear_aura(fear)

func _apply_true_form(on: bool) -> void:
	# The god-form is VISUAL scale only (collision untouched, so gameplay stays
	# fair): base_scale feeds every animated pose, and feet_anchor_y() re-plants
	# the giant's feet on the ground line every frame.
	#
	# Dev's call: TOWER him -- tall reads as god, wide just reads as a fat
	# hitbox. 1.7x the man's height, and the ascended art is drawn tall and
	# narrow (aspect 0.41 vs the man's 0.38) so he gains almost no width doing
	# it. He swaps to the ascended SKIN first, so the scale lands on the right
	# sprite rather than blowing up the hooded one for a frame.
	var m: float = TRUE_FORM_SCALE if on else 1.0
	monarch_scale_mult = m
	# Swap the skin FIRST: refresh_monarch_skin sizes the ascended sprite itself
	# (it has its own proportions) and re-applies _man_scale * mult for the
	# others -- so the scale always lands on the sprite it was computed for,
	# rather than blowing up the hooded art for a frame.
	refresh_monarch_skin()
	if not _ascended:
		base_scale = _man_scale * m   # no ascended art: the old grow-the-man path
	if on:
		spawn_shock_ring(global_position, NOVA_RADIUS, Color(0.55, 0.2, 1.0, 0.95))
		if has_node("Camera2D"):
			$Camera2D.shake(10.0, 0.5)
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("There is no one left to hide from. The Shadow Monarch stands revealed.")

# Rise, Shade (5/7+): the slain foe's shadow tears free of the ground and
# serves. Temporary soldiers below 7/7; the true form keeps a standing army.
# A Shadow Monarch may RAISE shades from the skill tree, not only from reaching
# monarch stage 5 by levelling. The Legion spec is built entirely on these keys.
func can_raise_shades() -> bool:
	return GameState.monarch_stage() >= 5 or GameState.get_skill_total("shade_unlock") > 0.0

func raise_shade() -> void:
	monarch_shades = monarch_shades.filter(func(s): return is_instance_valid(s))
	var true_form: bool = GameState.monarch_true_form()
	# Legion's "Growing Host" nodes add to the cap; the true form's own +2 stacks
	var cap: int = (4 if true_form else 2) + int(GameState.get_skill_total("shade_cap"))
	if monarch_shades.size() >= cap:
		return
	var shade = load("res://shade.gd").new()
	shade.owner_player = self
	# Legion's "Deathless Legion" makes shades hit far harder
	var dmg_mult := (1.6 if true_form else 1.0) * (1.0 + GameState.get_skill_total("shade_damage"))
	shade.damage = int(round((8.0 + GameState.player_level * 0.55) * dmg_mult))
	# a shade bursts when it falls if the tree grants it
	shade.explode_frac = GameState.get_skill_total("shade_explode")
	# permanent in the true form OR once the Legion keystone is taken
	var permanent := true_form or GameState.get_skill_total("shade_permanent") > 0.0
	shade.expires_at = 0.0 if permanent else (_now() + SHADE_LIFETIME)
	get_parent().add_child(shade)
	shade.global_position = global_position + Vector2(randf_range(-26.0, 26.0), 0.0)
	monarch_shades.append(shade)
	_rebalance_shades()

# A legion, not a swarm: some of the dead hunt for him, the rest stand between
# him and what's coming. Re-split every time the army changes size so you never
# end up with all-attack (no screen) or all-defend (nothing dies) -- and so a
# lone shade always hunts rather than guarding an unthreatened king.
func _rebalance_shades() -> void:
	monarch_shades = monarch_shades.filter(func(s): return is_instance_valid(s))
	var n: int = monarch_shades.size()
	if n == 0:
		return
	var want_guards: int = 0 if n < 2 else int(round(n * shade_defend_share()))
	want_guards = clampi(want_guards, 0, n - 1)   # never ALL guards
	for i in range(n):
		monarch_shades[i].role = 1 if i < want_guards else 0   # Role.DEFEND / ATTACK

# How much of the legion guards. The true form has bodies to spare, so it can
# afford a real screen.
func shade_defend_share() -> float:
	return 0.5 if monarch_true_form_active else 0.34

# The true form's heartbeat: every few seconds the dark detonates outward.
# Only rings visibly when it actually catches someone -- no spam in the village.
func fire_shadow_nova() -> void:
	# Dominion's "Crown of Ruin" nodes swell the blast's damage and reach
	var power := 1.0 + GameState.get_skill_total("nova_power")
	var dmg = int(round((30 + GameState.player_level) * power))
	var radius := NOVA_RADIUS * (1.0 + GameState.get_skill_total("nova_power") * 0.5)
	var hit := 0
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) <= radius:
				e.take_damage(dmg)
				hit += 1
	if hit > 0:
		spawn_shock_ring(global_position, radius, Color(0.5, 0.15, 0.95, 0.9))

# The dread aura: everything within reach is slowed, its will sapped. Magnitude
# is how deep the slow bites (Sovereign's Dread stacks it toward a hard chill).
const FEAR_AURA_PERIOD := 1.0
const FEAR_AURA_RADIUS := 240.0
var fear_aura_accum := 0.0
func apply_fear_aura(magnitude: float) -> void:
	var slowed := false
	for group_name in HOSTILE_GROUPS:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e) or ("is_dead" in e and e.is_dead):
				continue
			if global_position.distance_to(e.global_position) > FEAR_AURA_RADIUS:
				continue
			# apply_status is the CC interface every enemy family actually has --
			# the old apply_slow call matched a method NO enemy implements, so the
			# whole Dominion fear line (keystone, fork and the 6-point ultimate)
			# silently did nothing. Magnitude here is slow STRENGTH (more fear =
			# slower); apply_status("slow") wants the resulting speed FACTOR.
			if e.has_method("apply_status"):
				e.apply_status("slow", FEAR_AURA_PERIOD + 0.4, clampf(1.0 - magnitude, 0.15, 0.9))
				slowed = true
	if slowed and randf() < 0.25:
		spawn_shock_ring(global_position, FEAR_AURA_RADIUS, Color(0.35, 0.1, 0.6, 0.35))

# The Long Dark (6/7+): death reached for you and closed on shadow. The body
# melts into living dark -- unkillable while it knits itself back together.
func enter_long_dark() -> void:
	health = 1
	update_health_display()
	# claim the shared window for the WHOLE knit-back, so an ordinary hit's
	# 1-second timer can't resume mid-Long-Dark and switch invulnerability off
	_iframe_until = maxf(_iframe_until, _now() + LONG_DARK_DURATION)
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
	# only drop the guard if no LONGER window is still running (see grant_iframes).
	# This path awaits real timers for the whole knit-back, so its own end is
	# "now" -- anything still pending must be a later grant.
	if _now() >= _iframe_until - 0.01:
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
	var winged = has_wings()
	wings_left.visible = winged
	wings_right.visible = winged
	if not winged:
		return
	wing_flap_phase += get_physics_process_delta_time() * (22.0 if flying else 4.0)
	var amp = 0.6 if flying else 0.16
	var flap = sin(wing_flap_phase) * amp
	wings_left.rotation = flap
	wings_right.rotation = -flap

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
	_man_scale = Vector2(sc, sc)                        # the MAN's size, the baseline for everything
	base_scale = _man_scale * monarch_scale_mult        # survives a skin reload in true form
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
	# three skins, deepest first: ascended (7/7 true form) > hooded (5/7+) > the man
	var want_asc: bool = monarch_true_form_active and _ascended_art_present()
	var want_hood: bool = GameState.monarch_stage() >= HOOD_STAGE and _hooded_art_present()
	if want_asc == _ascended and want_hood == _hooded:
		return
	var prev_asc := _ascended
	var prev_hood := _hooded
	_ascended = want_asc
	_hooded = want_hood
	_art_prefix = ASCENDED_ART if want_asc else (HOODED_ART if want_hood else BASE_ART)
	var sf = build_sprite_frames()
	if sf == null:                      # art vanished mid-run: keep what we have
		_ascended = prev_asc
		_hooded = prev_hood
		_art_prefix = ASCENDED_ART if _ascended else (HOODED_ART if _hooded else BASE_ART)
		return
	var was: String = body_anim.animation
	var fr: int = body_anim.frame
	body_anim.sprite_frames = sf
	# Sizing rule differs by skin, on purpose:
	#
	# base/hooded -- do NOT re-derive. The hooded art trims ~6px taller than the
	#   bare head, so re-normalising would shrink his BODY to fit the cowl into
	#   the same silhouette; he'd look like he got smaller when the hood went up.
	#   Keeping the man's own scale means the hood simply ADDS height.
	# ascended  -- DO re-derive, to TRUE_FORM_SCALE x the man's height. It's a
	#   different sprite with its own proportions, so the man's scale would size
	#   it by accident. This is what makes him tower.
	if _ascended:
		var at = sf.get_frame_texture("monarchidle", 0)
		if at == null:
			at = sf.get_frame_texture("idle", 0)
		if at != null:
			var asc_sc: float = (SPRITE_TARGET_HEIGHT * TRUE_FORM_SCALE) / float(maxi(at.get_height(), 1))
			base_scale = Vector2(asc_sc, asc_sc)
	else:
		# back to a man: his own scale, times whatever the true form is doing
		base_scale = _man_scale * monarch_scale_mult
	body_anim.scale = base_scale
	if sf.has_animation(was):
		body_anim.play(was)
		body_anim.frame = mini(fr, maxi(sf.get_frame_count(was) - 1, 0))
	else:
		body_anim.play("idle")

func _hooded_art_present() -> bool:
	return ResourceLoader.exists(HOODED_ART + "idle_1.png") \
		or FileAccess.file_exists(HOODED_ART + "idle_1.png")

func _ascended_art_present() -> bool:
	return ResourceLoader.exists(ASCENDED_ART + "monarchidle_1.png") \
		or FileAccess.file_exists(ASCENDED_ART + "monarchidle_1.png")

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
func current_anim_state() -> String:
	if is_dead:
		return "death"
	if hurt_timer > 0.0:
		return "hurt"
	if is_dashing:
		return "dash"
	if not is_on_floor():
		# hanging in the air under his own power is not jumping -- he hovers
		if is_levitating and real_anims.get("levitate", false):
			return "levitate"
		# each jump in the chain has its own animation (jump / jump2 / jump3);
		# fall back to the plain jump if that variant has no frames yet
		if velocity.y < 0.0:
			return current_jump_anim if real_anims.get(current_jump_anim, false) else "jump"
		return "fall"
	if land_timer > 0.0:
		return "land"
	if absf(velocity.x) > 12.0:
		return "walk"
	# Once the hood is up he is already a monarch, and he stands like one --
	# settled, shoulders squared, fists at his sides. The fists-up brawler idle
	# belongs to the man he used to be, and is only worn below 5/7.
	if _hooded and real_anims.get("monarchidle", false):
		return "monarchidle"
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
	# restore the swap-surviving transients (see GameState.capture_player_state):
	# relic/skill cooldowns, the once-per-life save, and live food buffs
	for f in ["phoenix_ready_at", "aegis_ready_at", "gorgon_ready_at",
			"monarch_long_dark_ready_at", "undying_used", "rampage_stacks",
			"rampage_until"]:
		if data.has(f):
			set(f, data[f])
	if data.has("active_buffs") and data["active_buffs"] is Dictionary:
		active_buffs = data["active_buffs"]

func play_sfx(stream: AudioStream) -> void:
	$SFXPlayer.stream = stream
	$SFXPlayer.play()

# A HIDDEN-EVENT OMEN (2026-07-28): the world dims for a single beat as the
# player nears a secret trigger. No text, no marker -- just a felt "something is
# close". A transient full-screen CanvasLayer that fades in and back out.
func play_event_omen() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 40
	var rect := ColorRect.new()
	rect.color = Color(0.02, 0.0, 0.05, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(rect)
	add_child(cl)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.24, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(rect, "color:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(cl.queue_free)

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
	# TEMPER (Bulwark set-soul, Beetle-kin): every blow you WEATHER hardens the
	# next you land -- +6% melee per stack, up to three, fading if unfed
	if (weapon == "melee" or weapon == "spear") and _temper_stacks > 0:
		if _now() < _temper_until:
			base += 0.06 * float(_temper_stacks)
		else:
			_temper_stacks = 0
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
	return clamp(BASE_CRIT_CHANCE + GameState.get_bonus_total("crit_chance") + buff_bonus("crit_chance") + weapon_crit_chance_bonus(), 0.0, 1.0)

func get_crit_damage() -> float:
	return BASE_CRIT_DAMAGE + GameState.get_bonus_total("crit_damage") + weapon_crit_damage_bonus()

# Rolls a crit against a base amount. Returns [final_amount, is_crit].
var last_hit_was_crit := false
func roll_crit(base: int) -> Array:
	# the one choke point every damage roll passes -- remembered so
	# WeaponFx.on_hit (called downstream in apply_melee_skills, which never
	# receives the flag) can pay crit-keyed effects like frostbloom
	if base > 0 and randf() < get_crit_chance():
		last_hit_was_crit = true
		return [int(round(base * (1.0 + get_crit_damage()))), true]
	last_hit_was_crit = false
	return [base, false]

# a crit by DECREE, no dice: the Deadeye set-soul's certain shot
func force_crit(base: int) -> Array:
	last_hit_was_crit = true
	return [int(round(base * (1.0 + get_crit_damage()))), true]

# --- ARMOR SET-SOULS (2026-07-29, Terraria-kin set mechanics): a completed
# marquee set carries a TRIGGERED soul on top of its stats, alive with ANY
# weapon of its class (Spectre works with any magic weapon -- so do these).
func set_soul_active(set_id: String) -> bool:
	return GameState.is_set_complete(set_id)

# SOULTHREAD (Runeweave, Spectre-kin): a tenth of the wand damage you deal
# threads back to you as life.
func apply_soulthread(dealt: int) -> void:
	if dealt <= 0 or not set_soul_active("runeweave"):
		return
	if active_weapon_type != "wand" and active_weapon_type != "staff":
		return
	var heal = int(round(dealt * 0.10))
	if heal > 0:
		health = min(get_max_health(), health + heal)
		update_health_display()

# Pop a floating damage number over a struck enemy.
func show_hit(target: Node2D, amount: int, is_crit: bool) -> void:
	if is_instance_valid(target):
		FloatingText.spawn(get_parent(), target.global_position, amount, is_crit)
		spawn_hit_spark(target.global_position + Vector2(0, -20.0), is_crit)

# IMPACT SPARK (combat feel, 2026-07-22). Enemies already FLASH when hit, but nothing
# burst at the point of contact -- the little radial "connect" that makes a swing feel
# like it bit. A short spray of streaks (hot gold + bigger for a crit) reads on EVERY
# hit, additive on top of the flash/knockback/number, and DOESN'T touch the hit-stop
# (which the author keeps for the punchy moments on purpose). Cheap + self-freeing.
func spawn_hit_spark(pos: Vector2, crit: bool) -> void:
	var world := get_parent()
	if world == null:
		return
	var col := Color(1.0, 0.9, 0.35) if crit else Color(1.0, 1.0, 1.0)
	var count := 8 if crit else 5
	var reach := 26.0 if crit else 16.0
	var life := 0.13 if crit else 0.09
	for i in range(count):
		var a := TAU * (float(i) / float(count)) + randf_range(-0.3, 0.3)
		var dir := Vector2(cos(a), sin(a))
		var streak := Line2D.new()
		streak.width = 3.0 if crit else 2.0
		streak.default_color = col
		streak.points = PackedVector2Array([dir * (reach * 0.3), dir * reach * randf_range(0.85, 1.15)])
		streak.z_index = 40
		world.add_child(streak)
		streak.global_position = pos
		var t := streak.create_tween()
		t.parallel().tween_property(streak, "modulate:a", 0.0, life)
		t.parallel().tween_property(streak, "scale", Vector2(1.5, 1.5), life)
		t.chain().tween_callback(streak.queue_free)
	if crit:   # a crit also flashes a bright disc, so it's unmistakable
		var disc := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in range(10):
			var ang := TAU * float(i) / 10.0
			pts.append(Vector2(cos(ang), sin(ang)) * 14.0)
		disc.polygon = pts
		disc.color = Color(1.0, 0.95, 0.6, 0.55)
		disc.z_index = 39
		world.add_child(disc)
		disc.global_position = pos
		var td := disc.create_tween()
		td.parallel().tween_property(disc, "modulate:a", 0.0, 0.14)
		td.parallel().tween_property(disc, "scale", Vector2(2.0, 2.0), 0.14)
		td.chain().tween_callback(disc.queue_free)

# HIT-STOP (combat juice, dev polish 2026-07-21). A big blow lands harder when the
# whole world hangs for a heartbeat on impact. Only fires for the punchy moments
# (crits, finishers, kills), never every tap, so it stays special. The restore
# timer IGNORES time_scale (4th arg) so it isn't itself slowed to a crawl, and a
# shared deadline means a later hit can extend the freeze but an earlier one can
# never cut a later one short.
var _hitstop_end := 0.0
func hit_stop(dur := 0.07) -> void:
	if god_mode:
		return
	_hitstop_end = maxf(_hitstop_end, (Time.get_ticks_msec() / 1000.0) + dur)
	Engine.time_scale = 0.02

func _process(_delta: float) -> void:
	# Restore the freeze in REAL (wall-clock) time. _process runs every RENDERED
	# frame no matter the time_scale, so this can never get stuck in slow-mo the way
	# a time_scaled create_timer did. Cheap: one compare per frame.
	if Engine.time_scale < 1.0 and (Time.get_ticks_msec() / 1000.0) >= _hitstop_end:
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	# leaving the scene mid-freeze must never carry the slow-mo into the next one
	Engine.time_scale = 1.0

# The full impact package for a punchy landed blow: freeze-frame + camera kick.
# strong (a crit) hits harder than a plain finisher.
func _impact_feedback(strong: bool) -> void:
	hit_stop(0.08 if strong else 0.055)
	if has_node("Camera2D"):
		$Camera2D.shake(6.5 if strong else 4.0, 0.18)

# --- Timed buffs (from food). active_buffs[key] = {"v": amount, "until": t}. ---
var active_buffs: Dictionary = {}

# --- RIFTWEAVING (Mage, mg_p1..p3): the two doors, Z to weave ---
# Open the orange rift where you stand, the blue one elsewhere, step into
# either to exit the other. Opening costs mana; the DRAIN starts the moment
# the second door stands, and the pair collapses when the well runs dry.
# The upgrade nodes are what let you hold the doors open.
const PORTAL_SCRIPT = preload("res://portal.gd")
const PORTAL_OPEN_COST := 12.0
const PORTAL_DRAIN_PER_SEC := 9.0
var portal_a: Node2D = null
var portal_b: Node2D = null
var _portal_immune_until := 0.0

func has_portal_skill() -> bool:
	# god mode carries the doors free (dev request): Z works everywhere,
	# no skill, no cost, no drain -- pure testing convenience
	return god_mode or GameState.get_bonus_total("portal_unlock") > 0.0

func portal_open_cost() -> float:
	if god_mode:
		return 0.0
	return PORTAL_OPEN_COST * (1.0 - GameState.get_bonus_total("portal_open_cut"))

func portal_drain_per_second() -> float:
	if god_mode:
		return 0.0
	return PORTAL_DRAIN_PER_SEC * maxf(0.15, 1.0 - GameState.get_bonus_total("portal_drain_cut"))

func try_weave_portal() -> void:
	if portal_a != null and portal_b != null:
		close_portals("You collapse the rifts.")
		return
	var cost := portal_open_cost()
	if mana < cost:
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("Not enough mana to tear a rift (%d)." % int(ceil(cost)))
		return
	mana -= cost
	update_mana_display()
	var p = PORTAL_SCRIPT.new()
	p.owner_player = self
	p.is_orange = portal_a == null
	get_parent().add_child(p)
	p.global_position = global_position
	GameState.play_sfx(GameState.SFX_CHIME, 1.5 if portal_a == null else 0.9, global_position)
	if portal_a == null:
		portal_a = p
	else:
		portal_b = p   # the second door stands -- the drain begins (see tick_portals)

func tick_portals(delta: float) -> void:
	if portal_a == null or portal_b == null:
		return
	if is_dead or not is_instance_valid(portal_a) or not is_instance_valid(portal_b):
		close_portals()
		return
	mana -= portal_drain_per_second() * delta
	if mana <= 0.0:
		mana = 0.0
		close_portals("The rifts collapse — your mana is spent.")
	update_mana_display()

func close_portals(msg := "") -> void:
	if portal_a != null or portal_b != null:
		GameState.play_sfx(GameState.SFX_CHIME, 0.55, global_position)
	for p in [portal_a, portal_b]:
		if p != null and is_instance_valid(p):
			p.collapse()
	portal_a = null
	portal_b = null
	if msg != "":
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification(msg)

# MOVABLE BUILDINGS (5.2): plant the packed building where the player
# stands -- spacing and the two ramparts respected, costs charged HERE so
# changing your mind was free.
func try_plant_building() -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	var name := GameState.moving_building
	var mover: Node = null
	for b in get_tree().get_nodes_in_group("building"):
		if str(b.building_name) == name:
			mover = b
			break
	if mover == null:
		GameState.moving_building = ""
		return
	var x := global_position.x
	# inside the ramparts, with breathing room (de-magic'd 2026-07-24). The plant
	# path keeps a FAR east fallback (PLANT_EAST_NO_WALL_X) on purpose: with no east
	# rampart yet you can walk a packed building well out east onto open ground --
	# test_construction plants against this very sentinel. (The build menu caps
	# tighter; the two paths are deliberately different.)
	var west_x := GameState.SURFACE_WEST_FALLBACK_X
	var east_x := GameState.PLANT_EAST_NO_WALL_X
	for w in get_tree().get_nodes_in_group("village_wall"):
		if "flank" in w and w.flank == "east":
			east_x = w.global_position.x
		else:
			west_x = w.global_position.x
	if x < west_x + GameState.BUILD_INSIDE_MARGIN or x > east_x - GameState.BUILD_INSIDE_MARGIN:
		if stack:
			stack.show_notification("The %s must stand INSIDE the ramparts." % name)
		return
	# clear of every other structure: buildings, cottages, the tower.
	# EFFECTIVE widths on both sides (audit fix): footprints grow up to x1.4
	# with upgrades while `width` stays the base, so base-width tests let two
	# upgraded halls end up permanently drawn inside each other.
	var my_half: float = (mover.eff_w() if mover.has_method("eff_w") else float(mover.width)) / 2.0
	for other in get_tree().get_nodes_in_group("building"):
		if other == mover:
			continue
		var other_half: float = (other.eff_w() if other.has_method("eff_w") else float(other.width)) / 2.0
		if absf(x - other.global_position.x) < my_half + other_half + GameState.RELOCATE_CLEARANCE:
			if stack:
				stack.show_notification("Too close to the %s — find clearer ground." % other.building_name)
			return
	for node in get_tree().get_nodes_in_group("village_structure"):
		# ...that share this GROUND. The clearance test compared x alone, which
		# was fine while every structure stood in the village -- but the
		# Underdark's chests are village_structures too, strung the whole width
		# of the map a kilometre DOWN. Without a height check they reserved the
		# surface above themselves and the player could barely plant anywhere.
		if absf(global_position.y - node.global_position.y) > SAME_GROUND_Y:
			continue
		if absf(x - node.global_position.x) < my_half + 60.0 + GameState.RELOCATE_CLEARANCE:
			if stack:
				stack.show_notification("Too close to a structure — find clearer ground.")
			return
	# the price, at the plant
	if currency < GameState.RELOCATE_GOLD or inventory.get_count("wood") < GameState.RELOCATE_WOOD:
		if stack:
			stack.show_notification("Planting the %s needs %dg + %d wood." % [name, GameState.RELOCATE_GOLD, GameState.RELOCATE_WOOD])
		return
	add_currency(-GameState.RELOCATE_GOLD)
	inventory.remove_item("wood", GameState.RELOCATE_WOOD)
	GameState.play_sfx(GameState.SFX_THUD, 1.4, Vector2(x, global_position.y))
	mover.global_position.x = x
	GameState.building_positions[name] = x
	GameState.moving_building = ""
	GameState.log_event("village", "The %s was moved to new ground." % name)
	if stack:
		stack.show_notification("🏗 The %s stands on its new ground." % name)

# Called DEFERRED by the door the player stepped into (never mid-flush).
func do_portal_teleport(from: Node2D) -> void:
	var to: Node2D = portal_b if from == portal_a else portal_a
	if to == null or not is_instance_valid(to):
		return
	if _now() < _portal_immune_until:
		return
	_portal_immune_until = _now() + 0.6   # no ping-pong: one step per crossing
	global_position = to.global_position
	velocity = Vector2.ZERO

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
	# THE REWOUND HOUR (GAME_BIBLE 11): a world must not end on a misclick,
	# so the turn takes two uses -- arm, then confirm inside five seconds.
	if eff.get("rewind_world", false):
		if GameState.harvested_villagers.size() > 0 and not GameState.despair_dead:
			# insurance for future flows: no rewinding out of a raging Harvest
			if stack:
				stack.show_notification("The sands refuse to turn while the Harvest rages.")
			return false
		# THE TWO ROADS (GAME_BIBLE 11/12): turn the glass and run the world again,
		# stronger -- or shatter it, break the cycle, and let Deepwood stand for
		# good. A world-ending choice deserves a real prompt, never a stray click.
		_open_hourglass_choice(item_id)
		return true
	# Event-boss summon items (re-summon tokens / Duskmoon Effigy / Hunter's Horn):
	# the item is only spent if the summon actually takes (right time, no other
	# event live). GameState returns "" on success, else a short reason.
	var summon_id := str(eff.get("summon_event", ""))
	if summon_id != "":
		var reason: String = GameState.summon_event_boss(summon_id, float(eff.get("delay", 0.0)), bool(eff.get("eclipse", false)))
		if reason != "":
			if stack:
				stack.show_notification(reason)
			return false
		inventory.remove_item(item_id, 1)
		var iu = get_tree().get_first_node_in_group("inventory_ui")
		if iu and iu.has_method("refresh"):
			iu.refresh()
		return true
	# FISHING (pillar 3): prying open a fished-up crate. The crate IS its loot
	# table (fishing.gd), with "gold" riding the haul as a pseudo-id. Without
	# this branch a crate fell through to the generic tail and vanished for
	# NOTHING -- consumed, no loot, no message worth the name.
	if eff.get("open_crate", false):
		var haul: Array = Fishing.crate_loot(item_id)
		# the crate leaves the bag FIRST (bug hunt 2026-07-28): granting into a
		# full bag before removing it wasted the very slot the crate frees
		inventory.remove_item(item_id, 1)
		var lines := []
		var spilled := false
		for l in haul:
			var lid := str(l.get("id", ""))
			var cnt := int(l.get("count", 1))
			if lid == "gold":
				currency += cnt
				update_currency_display()
				lines.append("%dg" % cnt)
			else:
				var leftover: int = inventory.add_item(lid, cnt)
				if leftover < cnt:
					lines.append("%s x%d" % [Inventory.get_display_name(lid), cnt - leftover])
				if leftover > 0:
					spilled = true
		if stack:
			var msg: String = ("Pried open: %s." % ", ".join(lines)) if lines.size() > 0 else "Pried open — nothing but river silt."
			if spilled:
				msg += " (Some of it wouldn't fit your bag.)"
			stack.show_notification(msg)
		var crate_ui = get_tree().get_first_node_in_group("inventory_ui")
		if crate_ui and crate_ui.has_method("refresh"):
			crate_ui.refresh()
		return true
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
		stack.show_notification("Used " + Inventory.name_bbcode(item_id) + ".")
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui and inv_ui.has_method("refresh"):
		inv_ui.refresh()
	return true

# THE REWOUND HOUR's two roads (11/12). Both only reachable post-victory, since
# the hourglass is only ever granted as a victory spoil.
func _open_hourglass_choice(item_id: String) -> void:
	ChoicePrompt.open(self, "⌛ THE REWOUND HOUR",
		"The sands wait on your word. Turn the glass and the world begins again from ruin — and you keep everything you are, everything you carry. Or shatter it, break the cycle, and let Deepwood stand as it is: won, whole, and never unmade.",
		[
			{"label": "Turn it — rewind the world, run it again stronger", "cb": func():
				inventory.remove_item(item_id, 1)
				GameState.new_game_plus(self)},
			{"label": "Shatter it — end the cycle forever", "danger": true, "cb": func():
				_confirm_shatter_hourglass(item_id)},
			{"label": "Not yet", "cb": func(): return},
		])

# A world ends only on a deliberate, doubled yes.
func _confirm_shatter_hourglass(item_id: String) -> void:
	ChoicePrompt.open(self, "SHATTER THE HOURGLASS?",
		"This cannot be undone. There will be no more turnings, no more runs — only Deepwood, standing, forever yours. Break it?",
		[
			{"label": "Shatter it — let Deepwood stand forever", "danger": true, "cb": func():
				inventory.remove_item(item_id, inventory.get_count(item_id))
				GameState.break_the_cycle(self)
				DialogueBox.play(self, Story.TRUE_ENDING)},
			{"label": "Keep it", "cb": func(): return},
		])

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

# --- boss crowd-control on the PLAYER (set by boss signature abilities) ---
# Every one respects the status_resistance relic and is a no-op under god_mode,
# and all are absolute deadlines (_now() + dur) so they ALWAYS expire on their
# own — a boss can never permanently lock control. Cleared on respawn too.
var stun_until := 0.0        # stun: no actions at all (move/jump/dash/attack)
var freeze_until := 0.0      # freeze: hard stun + can't even be slid (velocity.x pinned 0)
var root_until := 0.0        # root: can't move/jump/dash, but CAN still attack
var disorient_until := 0.0   # disorient/"make you miss": movement axis inverted
var poison_until := 0.0      # poison: damage-over-time
var poison_dps := 0.0
var _poison_accum := 0.0
var pull_vel_x := 0.0        # per-frame horizontal pull (void rift etc.), consumed each frame

# Called by enemies/bosses when they die to player damage. Reaper's Toll heals
# on kill.
func on_enemy_killed() -> void:
	# the wielded weapon's own on-kill soul (WeaponFx: harvest/haste/soulwisp)
	WeaponFx.on_kill(self, global_position)
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
	# Rise, Shade: the slain foe's shadow tears free and serves -- from monarch
	# stage 5, OR from the Legion skill line the moment it's taken
	if can_raise_shades():
		raise_shade()
	# advance any "slay N foes" villager bonds
	GameState.quest_event("slay", "", 1)

func apply_slow(duration: float, factor: float) -> void:
	# a status-resistance relic cuts the slow's duration
	var resist = clamp(GameState.get_bonus_total("status_resistance"), 0.0, 0.9)
	# reset a lapsed slow first, else a strong-but-expired factor sticks onto a later weak
	# slow for its whole (extended) window.
	if _now() >= enemy_slow_until:
		enemy_slow_factor = 1.0
	enemy_slow_until = max(enemy_slow_until, _now() + duration * (1.0 - resist))
	enemy_slow_factor = min(enemy_slow_factor, factor)

# --- boss crowd-control API (called by boss.gd signature abilities) ---
# status_resistance shortens every one; god_mode ignores them all.
func _cc_dur(duration: float) -> float:
	return duration * (1.0 - clamp(GameState.get_bonus_total("status_resistance"), 0.0, 0.9))

func apply_stun(duration: float) -> void:
	if god_mode or is_dead: return
	stun_until = max(stun_until, _now() + _cc_dur(duration))

func apply_freeze(duration: float) -> void:
	if god_mode or is_dead: return
	freeze_until = max(freeze_until, _now() + _cc_dur(duration))

func apply_root(duration: float) -> void:
	if god_mode or is_dead: return
	root_until = max(root_until, _now() + _cc_dur(duration))

func apply_disorient(duration: float) -> void:
	if god_mode or is_dead: return
	disorient_until = max(disorient_until, _now() + _cc_dur(duration))

func apply_poison(duration: float, dps: float) -> void:
	if god_mode or is_dead: return
	# a lapsed poison must not lend its magnitude to the next: reset first if the prior
	# poison already expired, else a later WEAK poison inherits an earlier STRONG dps.
	if _now() >= poison_until:
		poison_dps = 0.0
	poison_until = max(poison_until, _now() + _cc_dur(duration))
	poison_dps = max(poison_dps, dps)

# Sustained horizontal pull toward a point (Void Rift). Called every frame while
# the pull is active; consumed once in _physics_process.
func apply_pull(source_x: float, strength: float) -> void:
	if god_mode or is_dead: return
	var dir = signf(source_x - global_position.x)
	pull_vel_x += dir * strength * (1.0 - clamp(GameState.get_bonus_total("status_resistance"), 0.0, 0.9))

# stun/freeze: no actions at all. Root does NOT hard-lock (you can still swing).
func cc_action_locked() -> bool:
	if god_mode: return false
	return _now() < stun_until or _now() < freeze_until

# stun/freeze/root: cannot move, jump, or dash.
func cc_move_locked() -> bool:
	if god_mode: return false
	return cc_action_locked() or _now() < root_until

# a quiet damage-over-time tick: no hurt-sfx/shake/dodge spam, but a lethal tick
# routes through take_damage so all death-saves (Long Dark / Undying / Phoenix) fire.
func _poison_tick(dmg: int) -> void:
	if is_dead or god_mode: return
	dmg = int(round(dmg * (1.0 - clamp(GameState.get_bonus_total("damage_reduction"), 0.0, 0.75))))
	if dmg <= 0: return
	if health - dmg <= 0:
		# A lethal DoT is not dodged by hit-i-frames (poison does not care that
		# something else just hit you), and it does NOT go back through
		# take_damage: that would run the mitigation/mana-shield/thorns pipeline
		# on a fake number. Straight to the shared death cascade instead.
		health = 0
		update_health_display()
		suffer_lethal()
		return
	health -= dmg
	update_health_display()
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -20), dmg, false, Color(0.5, 0.9, 0.4))

# Wipe all CC — called on respawn so nothing survives a death.
func clear_crowd_control() -> void:
	stun_until = 0.0
	freeze_until = 0.0
	root_until = 0.0
	disorient_until = 0.0
	poison_until = 0.0
	poison_dps = 0.0
	_poison_accum = 0.0
	pull_vel_x = 0.0
	enemy_slow_until = 0.0     # a caster's chill dies with the rest on respawn
	enemy_slow_factor = 1.0

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
	_reconcile_companions()

# --- COMPANIONS (light summoner 2026-07-29): an item CARRIES its companion.
# Wield or wear the carrier and it walks with you; put it away and it bows
# out. Reconciled here because every wield and every equip funnels through
# on_equipment_changed -- one hook, no save plumbing (companions re-derive
# from what you hold).
const COMPANION_SCRIPT = preload("res://companion.gd")
var _companions := {}   # source item id -> companion node

func _reconcile_companions() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var wanted := {}
	if has_weapon() and str(active_def.get("companion", "")) != "":
		wanted[active_weapon_id] = active_def
	for id in GameState.get_equipped_item_ids():
		var idef = Inventory.get_item_def(id)
		if str(idef.get("companion", "")) != "":
			wanted[id] = idef
	for sid in _companions.keys():
		if not wanted.has(sid) or not is_instance_valid(_companions[sid]):
			if is_instance_valid(_companions[sid]):
				_companions[sid].queue_free()
			_companions.erase(sid)
	var idx := 0
	for sid in wanted:
		if not _companions.has(sid):
			var c = COMPANION_SCRIPT.new()
			c.kind = str(wanted[sid].get("companion", "blade"))
			c.damage = int(wanted[sid].get("c_damage", 12))
			c.gap = float(wanted[sid].get("c_gap", 1.8))
			c.source_id = sid
			c.player = self
			c.position = global_position + Vector2(0, -46)
			get_parent().add_child(c)
			_companions[sid] = c
		_companions[sid].slot = idx
		idx += 1

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

# The MU-style HP + mana globes (dev ask 2026-07-22). They replace the top-left
# bars: the old bar nodes are hidden (kept alive so the legacy update_*_display
# calls that still poke them never error), and two liquid globes are seated in
# the bottom corners, flanking the hotbar. Built here in code so they ride into
# both main.tscn and dungeon_interior.tscn without editing either scene.
const ORB_D := 104.0
func build_orbs() -> void:
	var layer = get_node_or_null("../CanvasLayer")
	if layer == null:
		return
	for n in ["HealthBarFill", "HealthLabel", "HealthBarBG", "HealthBar",
			"ManaBarBG", "ManaBarFill", "ManaLabel"]:
		var old = layer.get_node_or_null(n)
		if old:
			old.visible = false

	hp_orb = HUD_ORB.new()
	layer.add_child(hp_orb)
	hp_orb.setup(Color(0.95, 0.24, 0.22), Color(0.42, 0.03, 0.05), Color(0.62, 0.44, 0.24))
	hp_orb.anchor_top = 1.0; hp_orb.anchor_bottom = 1.0
	hp_orb.offset_left = 20.0; hp_orb.offset_right = 20.0 + ORB_D
	hp_orb.offset_top = -(ORB_D + 12.0); hp_orb.offset_bottom = -12.0

	mana_orb = HUD_ORB.new()
	layer.add_child(mana_orb)
	mana_orb.setup(Color(0.32, 0.62, 1.0), Color(0.05, 0.12, 0.5), Color(0.44, 0.5, 0.66))
	mana_orb.anchor_left = 1.0; mana_orb.anchor_right = 1.0
	mana_orb.anchor_top = 1.0; mana_orb.anchor_bottom = 1.0
	mana_orb.offset_right = -20.0; mana_orb.offset_left = -20.0 - ORB_D
	mana_orb.offset_top = -(ORB_D + 12.0); mana_orb.offset_bottom = -12.0

	# the buff/debuff row: living chips above the HP globe. Food buffs and
	# stances read gold-ish; what's been done TO you reads in its own colour.
	buff_row = HBoxContainer.new()
	layer.add_child(buff_row)
	buff_row.anchor_top = 1.0; buff_row.anchor_bottom = 1.0
	buff_row.offset_left = 20.0
	buff_row.offset_right = 520.0
	buff_row.offset_top = -(ORB_D + 12.0 + 30.0)
	buff_row.offset_bottom = -(ORB_D + 12.0 + 4.0)
	buff_row.add_theme_constant_override("separation", 10)
	update_orbs()

# The chips: every timed thing on the player, named and counted down, in one
# glance -- food buffs, stances, and everything the world has done to you.
# Rebuilt at ~3Hz (a handful of Labels; churn is nothing at this rate).
const BUFF_CHIP_LABELS = {"all_damage": "Well Fed", "move_speed": "Swift",
	"max_health": "Hearty", "damage_reduction": "Stoneskin",
	"crit_chance": "Keen", "gold_gain": "Lucky", "xp_gain": "Wise"}

func update_buff_chips() -> void:
	if buff_row == null:
		return
	for c in buff_row.get_children():
		c.queue_free()
	var n := _now()
	var chips := []   # [text, colour]
	for key in active_buffs.keys():
		var b = active_buffs[key]
		var left := maxf(0.0, float(b.get("until", 0.0)) - n)
		if left <= 0.0:
			continue
		chips.append(["%s %ds" % [BUFF_CHIP_LABELS.get(key, str(key).capitalize()), int(ceil(left))],
			Color(1.0, 0.85, 0.4)])
	if pillar_planted:
		chips.append(["Pillar Stance", Color(1.0, 0.85, 0.35)])
	if _sanctuary_ring != null:
		chips.append(["Sanctuary", Color(0.55, 0.85, 1.0)])
	for d in [["Poisoned", poison_until, Color(0.5, 0.9, 0.4)],
			["Stunned", stun_until, Color(1.0, 0.6, 0.3)],
			["Rooted", root_until, Color(0.8, 0.65, 0.4)],
			["Frozen", freeze_until, Color(0.6, 0.9, 1.0)],
			["Disoriented", disorient_until, Color(0.9, 0.5, 0.95)]]:
		if n < float(d[1]):
			chips.append(["%s %ds" % [d[0], int(ceil(float(d[1]) - n))], d[2]])
	for ch in chips:
		var l := Label.new()
		l.text = ch[0]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", ch[1])
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 4)
		buff_row.add_child(l)

# Feed the globes the live pools every frame -- cheap, and it catches passive
# regen/drain that never routes through update_*_display.
func update_orbs() -> void:
	if hp_orb:
		hp_orb.set_values(float(health), float(get_max_health()))
	if mana_orb:
		mana_orb.set_values(mana, get_max_mana())

# The warm pool the hero carries. A real PointLight2D so it reads against the
# dungeon's CanvasModulate dark; enabled only in the dungeon (a clean signal),
# so it never washes out the daylit village.
static var _plight_tex: GradientTexture2D = null
static func _player_light_tex() -> GradientTexture2D:
	if _plight_tex == null:
		# a SMOOTH falloff (dev: the old light read as "a round circle, a sun") --
		# a soft core that fades gradually into the dark, no hard disc edge
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.28, 0.6, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.82), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0)])
		_plight_tex = GradientTexture2D.new()
		_plight_tex.gradient = g
		_plight_tex.width = 128
		_plight_tex.height = 128
		_plight_tex.fill = GradientTexture2D.FILL_RADIAL
		_plight_tex.fill_from = Vector2(0.5, 0.5)
		_plight_tex.fill_to = Vector2(1.0, 0.5)
	return _plight_tex

func build_player_light() -> void:
	player_light = PointLight2D.new()
	player_light.texture = _player_light_tex()
	# 5.2 (trimmed from 6.2): a gentle pool, not a tight sun -- and a smaller light
	# is cheaper to fill, since 2D lights were the dungeon's main lag.
	player_light.texture_scale = 5.2
	player_light.color = Color(1.0, 0.88, 0.66)
	player_light.energy = 0.55                # softer, so it blends instead of glaring
	player_light.shadow_enabled = false
	player_light.position = Vector2(0, -18)
	player_light.enabled = false
	add_child(player_light)
	build_char_shadow(self, 0.5)              # a small grounding shadow at the feet

# The grounding shadow now lives in char_shadow.gd so every character shares it
# (dev: "create shadows... so the game feels smoother"). Kept as a thin wrapper
# so existing callers are undisturbed; the player's feet sit at local y 24.
func build_char_shadow(host: Node2D, width: float) -> void:
	preload("res://char_shadow.gd").attach(host, width, 24.0)

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
	# sizing (blade length, swing arc, reach) is derived from the weapon's swing
	# speed rather than authored -- see Inventory.weapon_stats_for
	var stats = Inventory.weapon_stats_for(item_id)
	if stats.is_empty():
		return false
	active_weapon_id = item_id
	active_def = def
	active_stats = stats
	active_weapon_type = def.get("weapon_type", "melee")
	reset_combo()   # a string belongs to the weapon that started it
	WeaponFx.on_wield(self)   # rhythm counters and ramps belong to a wield too
	$AttackArea/CollisionShape2D.shape.size = stats.area_size
	if weapon_anim_tween:
		weapon_anim_tween.kill()
		# a killed tween SKIPS its pending callbacks -- so clear the attack-state
		# flags they would have reset. Otherwise swapping weapons mid-swing leaves
		# the spear-tip area monitoring (phantom hits that read the NEW weapon's
		# stats) and is_attacking stuck true (the held weapon stops aiming).
		$SpearTipArea.monitoring = false
		is_attacking = false
	$WeaponIcon.size = stats.icon_size
	$WeaponIcon.color = stats.icon_color
	$WeaponIcon.rotation_degrees = 0.0
	$WeaponIcon.scale = Vector2.ONE
	$WeaponIcon.pivot_offset = Vector2(0.0, stats.icon_size.y / 2.0)
	var has_art := update_weapon_sprite()   # real sprite wins; blanks the bar when present
	update_weapon_guard(has_art)
	update_weapon_visual(stats.icon_offset)
	# wielding can complete (or break) a class set's full weapon tier, which
	# can change max HP/mana -- re-sync exactly like an equip would.
	on_equipment_changed()
	return true

# Hotbar select: index 0-9 = inventory slots 1-10. Wields a weapon; DRINKS a
# consumable (audit fix: the keys used to silently do nothing on a potion slot
# even though the hotbar happily displayed it -- the TAB bag's right-click was
# the only way to use one). Anything else (or empty) does nothing.
func select_hotbar_slot(index: int) -> void:
	if index >= inventory.slots.size():
		return
	var slot = inventory.slots[index]
	if slot == null:
		return
	if Inventory.get_category(slot.item_id) == "consumable":
		use_item(slot.item_id)
		return
	if Inventory.get_category(slot.item_id) != "weapon":
		return
	if slot.item_id == active_weapon_id:
		return
	if wield_weapon(slot.item_id):
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("Wielding " + Inventory.name_bbcode(slot.item_id))

# Shows/sizes the crossguard for bladed melee weapons (melee/spear), hides it
# for bow and wand. The guard is a child of WeaponIcon, so it swings/aims with
# the weapon automatically.
func update_weapon_guard(has_art := false) -> void:
	if not weapon_guard:
		return
	# a real sprite already draws its own guard/hilt -- the fallback crossguard
	# would only poke out behind it
	if has_art or active_weapon_type == "bow" or active_weapon_type == "wand" or active_stats.is_empty():
		weapon_guard.visible = false
		return
	var guard_height = active_stats.icon_size.y + 12.0
	weapon_guard.size = Vector2(5.0, guard_height)
	weapon_guard.position = Vector2(active_stats.icon_size.x * 0.16, (active_stats.icon_size.y - guard_height) / 2.0)
	weapon_guard.visible = true

func get_aim_direction() -> Vector2:
	var to_mouse = aim_world_point() - global_position
	if to_mouse.length() < 1.0:
		return Vector2(facing_direction, 0)
	return to_mouse.normalized()

# Where the player is aiming, in world space. On touch devices there is no
# mouse worth trusting, so the touch layer auto-aims (nearest enemy, facing
# side preferred). Everywhere else this is exactly get_global_mouse_position().
func aim_world_point() -> Vector2:
	if TouchControls.active:
		return TouchControls.aim_point_for(self)
	return get_global_mouse_position()

# TERRARIA MINING (2026-07-25): while a pickaxe is wielded, HOLD left-click to dig
# the tile at the cursor in a minable tile world (group "tile_world"). Hold SHIFT
# for smart-cursor -- it auto-targets the nearest tile toward the aim, no
# pixel-precise pointing. Only fires when such a world exists (the underground),
# so it never touches the village.
const DIG_INTERVAL := 0.14
const DIG_REACH := 6.0 * 16.0
var _dig_cd := 0.0

# --- UI input guard (audit fix) ----------------------------------------------
# World mouse actions are POLLED (Input.is_action_pressed), which ignores both
# Control focus and set_input_as_handled -- so clicking a skill node also swung
# the wielded weapon (a five-node shopping trip drained the mana pool), and
# dragging bag items over an opaque panel fired spells / mined real tiles the
# player couldn't see. Any open esc-window panel blocks attack/secondary/dig;
# movement stays free on purpose (walking out of a zone is how its panel closes).
# How close you must stand to right-click a villager into conversation. Roughly
# the same reach the E-prompt uses, so "close enough to talk" reads the same way
# whichever button you press.
const VILLAGER_MENU_RANGE := 150.0

# Opens the nearest in-range villager's menu. Returns true if it took the click,
# so the caller knows not to also swing/cast with it.
func _try_open_villager_menu() -> bool:
	var best: Node = null
	var best_d := VILLAGER_MENU_RANGE
	for n in get_tree().get_nodes_in_group("npc"):
		if not is_instance_valid(n) or not n.has_method("open_menu"):
			continue
		if "is_in_building" in n and n.is_in_building:
			continue          # indoors: nobody to talk to out here
		var d: float = global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best == null:
		return false
	best.open_menu()
	return true

func ui_blocks_world_input() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	if f != null and (f is LineEdit or f is TextEdit):
		return true
	for w in get_tree().get_nodes_in_group("esc_window"):
		if is_instance_valid(w) and w.has_method("esc_is_open") and w.esc_is_open():
			return true
	return false

func _tick_dig(delta: float) -> void:
	_dig_cd -= delta
	if typeof(active_def) != TYPE_DICTIONARY or str(active_def.get("tool_type", "")) != "pickaxe":
		return
	if not Input.is_action_pressed("attack") or GameState.placing_building:
		return
	if ui_blocks_world_input():
		return
	if _dig_cd > 0.0:
		return
	var world = get_tree().get_first_node_in_group("tile_world")
	if world == null or not world.has_method("mine_at"):
		return
	_dig_cd = DIG_INTERVAL
	# fingers aren't pixel-precise: touch play always digs with the smart cursor
	var smart := Input.is_key_pressed(KEY_SHIFT) or TouchControls.active
	var tier: int = int(active_def.get("pick_tier", 1))   # deeper biomes gate on the pickaxe tier
	world.mine_at(aim_world_point(), global_position, DIG_REACH, smart, tier, self)

func update_weapon_visual(offset: float) -> void:
	if not has_weapon():
		$WeaponIcon.visible = false
		$BowVisual.visible = false
		$WeaponTip.visible = false
		return
	var stats = active_stats
	var aim_dir = get_aim_direction()
	# The weapon is HELD, not levitated. It sits at a fixed distance from the
	# body and only ROTATES to point at the cursor: the mouse sets direction,
	# never distance. All reach comes from the weapon's own stats, so a spear
	# outranges a dagger because the spear is longer -- not because you can drag
	# the blade further from your hand.
	$WeaponTip.visible = false
	$BowVisual.visible = false
	if active_weapon_type == "bow":
		# inventory == hand (dev): a bow with real art shows THAT sprite in the
		# hand (WeaponIcon carries it, bar transparent); the procedural
		# BowVisual only remains for art-less bows
		var bow_has_art: bool = weapon_sprite != null and weapon_sprite.visible
		$WeaponIcon.visible = bow_has_art
		if bow_has_art:
			$WeaponIcon.position = aim_dir * offset - $WeaponIcon.pivot_offset
			$WeaponIcon.rotation = aim_dir.angle()
		$BowVisual.visible = not bow_has_art
		$BowVisual.position = aim_dir * offset
		$BowVisual.rotation = aim_dir.angle()
		$BowVisual.scale = Vector2.ONE
	else:
		$WeaponIcon.visible = true
		$WeaponIcon.position = aim_dir * offset - $WeaponIcon.pivot_offset
		$WeaponIcon.rotation = aim_dir.angle()
		$AttackArea.position = aim_dir * stats.range_offset
		$AttackArea.rotation = aim_dir.angle()
		if active_weapon_type == "spear":
			$WeaponTip.visible = true
			var tip_pos = aim_dir * (offset + stats.icon_size.x)
			$WeaponTip.position = tip_pos
			$WeaponTip.rotation = aim_dir.angle()
			$WeaponTip.scale = Vector2.ONE
			$SpearTipArea.position = tip_pos

func add_currency(amount: int) -> void:
	currency += amount
	# a negative amount is a SPEND -- feeds the Effigy King's hidden trigger
	if amount < 0:
		GameState.note_gold_spent(-amount)
	# one writer for the HUD row -- this used to stamp the old "Currency:"
	# format here, silently overwriting the Lv/XP readout on every pickup
	update_currency_display()

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
	# The Immovable Pillar: planted, he simply hurts less (stacks into the cap)
	var dr := GameState.get_bonus_total("damage_reduction") + (0.35 if pillar_planted else 0.0)
	amount = int(round(amount * (1.0 - clamp(dr, 0.0, 0.75))))
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
	# TEMPER (Bulwark set-soul): the blow you just weathered hardens you --
	# read in skill_damage_mult's melee branch
	if amount > 0 and set_soul_active("bulwark"):
		_temper_stacks = mini(3, _temper_stacks + 1)
		_temper_until = _now() + 6.0
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
		suffer_lethal()
		return
	grant_iframes(INVINCIBILITY_DURATION)

# THE DEATH CASCADE, in ONE place. Reached either by a blow that empties the bar
# or by a lethal damage-over-time tick -- a DoT must NOT be routed back through
# take_damage() with a huge sentinel number, because everything above this line
# (damage_reduction, Mana Barrier, Thorns) would then run on that sentinel: a
# 9999 "kill me" reflected ~3,100 thorns damage to every enemy in range and
# drained the whole mana pool in one tick.
func suffer_lethal() -> void:
	if is_dead:
		return
	# The Long Dark (6/7+): a lethal blow cannot kill what is already shadow.
	# Outranks Living Fortress so the skill charge is kept.
	if GameState.monarch_stage() >= 6 and _now() >= monarch_long_dark_ready_at:
		monarch_long_dark_ready_at = _now() + LONG_DARK_COOLDOWN
		enter_long_dark()
		return
	# Stone Guise (rune): the killing blow lands on STONE instead -- once per
	# dungeon floor. Sits above Living Fortress so the rarer per-life charge
	# is preserved; below the Long Dark for the same reason.
	if GameState.get_bonus_total("stone_guise") > 0.0 and stone_guise_floor != _stone_guise_floor_key():
		stone_guise_floor = _stone_guise_floor_key()
		health = 1
		update_health_display()
		enter_stone_guise()
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
		grant_iframes(INVINCIBILITY_DURATION * 2.0)
		return
	die()

# INVULNERABILITY IS OWNED BY ITS DEADLINE, never by whichever timer happens to
# fire first. Each grant pushes a shared deadline forward and only the timer that
# finds the deadline actually reached clears the flag -- otherwise an ordinary
# 1-second hit window, granted BEFORE a death save, resumed a second later and
# switched off the Long Dark's 2.6s (or Living Fortress's 2s) protection, killing
# a player the design says cannot die and spending the charge for nothing.
var _iframe_until := 0.0

func grant_iframes(seconds: float) -> void:
	# Compare DEADLINES, never the clock at fire time. SceneTreeTimer obeys
	# Engine.time_scale (hit-stop slows it; a sped-up test runs it fast) while
	# _now() is wall clock, so "has my deadline passed yet?" asked on wake could
	# answer NO for the very window that just ended -- and then nothing ever
	# cleared the flag: the player was permanently invulnerable, which a boss
	# arena test caught as "took no damage in 15s". Each timer knows the end it
	# was granted; it defers only to a strictly LATER one.
	var my_end := _now() + seconds
	_iframe_until = maxf(_iframe_until, my_end)
	invincible = true
	start_invincibility_flash()
	var iid := get_instance_id()
	get_tree().create_timer(seconds).timeout.connect(func():
		var s = instance_from_id(iid)
		if s == null or not is_instance_valid(s):
			return
		if my_end < s._iframe_until - 0.01:
			return          # a longer window is still running -- it owns the flag
		s.stop_invincibility_flash()
		s.invincible = false)

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
	GameState.on_player_died_event()   # breaks the no-death floor streak (Warden trigger)
	velocity = Vector2.ZERO
	play_sfx(SFX_DEATH)
	stop_invincibility_flash()
	body_visual.modulate = Color(0.55, 0.2, 0.2, 1.0)
	# topple over as he dies -- but only if you haven't drawn real death frames
	# (those play themselves; update_body_anim yields the transform while dead)
	if body_anim and not real_anims.get("death", false):
		var topple = create_tween()
		topple.tween_property(body_anim, "rotation", deg_to_rad(82.0 * facing_direction), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	GameState.last_death_toll = ""       # Easy deaths cost gold only
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
	undying_used = false    # a new life re-arms the once-per-life Living Fortress save
	clear_crowd_control()   # never let a boss CC survive a death
	update_health_display()

# All difficulties drop currency on death -- the amount stays in the world
# as a pickup (see currency_pickup.gd) for a full in-game day before it
# despawns, rather than being lost outright.
func drop_currency_on_death() -> void:
	# Dorian Vail, the Coinbinder (the Ten): half of any gold dropped in death
	# is insured -- it simply never leaves your purse
	var frac := CURRENCY_DROP_FRACTION * (0.5 if GameState.ten_freed("ten_dorian") else 1.0)
	var drop_amount = int(round(currency * frac))
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
# death: Medium names a death toll, Hard also burns one identified skill
# material. Both the toll and the material systems are live (see GameState).
func apply_difficulty_death_penalty() -> void:
	# the cost is NAMED (see report_death_toll) -- a silent permanent loss
	# is the cruellest way to teach a rule
	match GameState.difficulty:
		"Medium":
			GameState.report_death_toll("Medium")
		"Hard":
			GameState.report_death_toll("Hard")
			GameState.remove_one_skill_material()

func update_currency_display() -> void:
	# levels are the game's reward engine (the depth pays) -- the current
	# level and the road to the next live on the HUD, not only inside K
	if GameState.player_level >= GameState.PLAYER_LEVEL_CAP:
		$"../CanvasLayer/CurrencyLabel".text = "Lv 100 — Shadow Sovereign   •   %dg" % currency
	else:
		$"../CanvasLayer/CurrencyLabel".text = "Lv %d  (%d/%d)   •   %dg" % [
			GameState.player_level, GameState.player_xp, GameState.xp_to_next_level(), currency]

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

# ============================ THE WUKONG ROADS ============================
# (2026-07-28) Eight tree skills + three relic-runes lifted from the Monkey
# King's kit in spirit, never in copy. The tree grants the keys
# (somersault / pillar_stance / cloud_step / golden_gaze / stillness /
# hair_clone / clone_burst / monarch_air); these functions are the mechanics.
# monarch_air grants BOTH air tricks, so every check sums the two keys.

var somersault_ready_at := 0.0
var pillar_planted := false
var _choir_shots := 0          # A Choir of One: counts to the seventh voice
var _pillar_hold := 0.0        # how long DOWN has been held on the floor
var _pillar_next_arc := 0.0
var _pillar_ring: Node2D = null
var _still_t := 0.0            # sanctuary: how long we've stood truly still
var _sanctuary_ring: Node2D = null
# --- set-souls state (2026-07-29): Deadeye's stillness prime, Temper's stacks
var _deadeye_t := 0.0
var _deadeye_primed := false
var _temper_stacks := 0
var _temper_until := 0.0
var hair_ready_at := 0.0
var stone_guise_floor := ""    # the floor key where the stone last saved us

# once per FLOOR, not per life: each new depth (or the village) re-arms it
func _stone_guise_floor_key() -> String:
	if GameState.in_dungeon:
		var di = get_tree().get_first_node_in_group("level_director")
		if di != null and "current_level" in di:
			return "floor_%d" % int(di.current_level)
	return "village"

# Become the statue: untouchable and unmoving for 1.5s while the world howls.
func enter_stone_guise() -> void:
	grant_iframes(1.6)
	root_until = maxf(root_until, _now() + 1.5)
	var old_mod := modulate
	modulate = Color(0.62, 0.6, 0.58, 1.0)   # grey the whole figure to granite
	spawn_shock_ring(global_position, 90.0, Color(0.7, 0.68, 0.62, 0.9))
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("Stone Guise: the blow lands on stone.")
	var t := create_tween()
	t.tween_interval(1.5)
	t.tween_property(self, "modulate", old_mod, 0.3)

func wukong_air_hop_allowed() -> bool:
	if GameState.get_bonus_total("cloud_step") + GameState.get_bonus_total("monarch_air") <= 0.0:
		return false
	# one hop beyond the natural chain: 2nd for a single-jumper, 3rd past a
	# double jump -- the cloudlet is always the LAST stair
	var total := 2 + (1 if has_double_jump else 0)
	return jumps_used >= 1 and jumps_used < total

func somersault_ready() -> bool:
	if GameState.get_bonus_total("somersault") + GameState.get_bonus_total("monarch_air") <= 0.0:
		return false
	return _now() >= somersault_ready_at and not is_dashing

# The flip: a mid-air forward dash that borrows the dash machinery, so the
# afterimages, the dash pose and the velocity handoff all come for free --
# and the body actually TURNS OVER (a somersault that doesn't somersault
# reads as a plain air-dash; polish pass 2026-07-28).
func perform_somersault() -> void:
	somersault_ready_at = _now() + 3.0
	is_dashing = true
	play_sfx(SFX_DASH)
	velocity.x = facing_direction * 640.0
	velocity.y = JUMP_VELOCITY * 0.5
	grant_iframes(0.35)   # untouchable for a blink, exactly as promised
	if body_anim != null:
		var spin := create_tween()
		spin.tween_property(body_anim, "rotation",
			TAU * float(facing_direction), 0.28).from(0.0)
		spin.tween_callback(func(): body_anim.rotation = 0.0)
	await get_tree().create_timer(0.28).timeout
	is_dashing = false

func spawn_cloudlet() -> void:
	var puff := CPUParticles2D.new()
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.amount = 10
	puff.lifetime = 0.4
	puff.spread = 180.0
	puff.gravity = Vector2(0, -30)
	puff.initial_velocity_min = 20.0
	puff.initial_velocity_max = 70.0
	puff.scale_amount_min = 3.0
	puff.scale_amount_max = 6.0
	puff.color = Color(0.95, 0.97, 1.0, 0.8)
	get_parent().add_child(puff)
	puff.global_position = global_position + Vector2(0, 12)
	puff.emitting = true
	puff.finished.connect(puff.queue_free)

func tick_wukong(delta: float) -> void:
	_tick_pillar_stance(delta)
	_tick_sanctuary(delta)
	_tick_deadeye(delta)
	_tick_hair_clone()

# The Immovable Pillar: hold S on the ground half a second to PLANT. Rooted
# (+35% DR, read in take_damage) while the blade answers on its own clock.
func _tick_pillar_stance(delta: float) -> void:
	var want: bool = GameState.get_bonus_total("pillar_stance") > 0.0 \
		and is_on_floor() and Input.is_key_pressed(KEY_S) \
		and not cc_move_locked() and not is_dashing and not is_dead
	if not want:
		if pillar_planted:
			pillar_planted = false
			_unmake_ring(_pillar_ring)
			_pillar_ring = null
		_pillar_hold = 0.0
		return
	_pillar_hold += delta
	if not pillar_planted and _pillar_hold >= 0.5:
		pillar_planted = true
		_pillar_next_arc = _now() + 0.4
		_pillar_ring = _make_ring(52.0, Color(1.0, 0.85, 0.35, 0.5))
	if pillar_planted and _now() >= _pillar_next_arc:
		_pillar_next_arc = _now() + 0.8
		var base_dmg: float = float(active_stats.get("damage", 4)) if has_weapon() else 4.0
		var dmg := maxi(1, int(round(base_dmg * 0.6 * skill_damage_mult("melee"))))
		var struck := false
		for group_name in ["course_enemy", "dungeon_combatant", "siege_enemy"]:
			for e in get_tree().get_nodes_in_group(group_name):
				if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if global_position.distance_to(e.global_position) <= 110.0:
					e.take_damage(dmg)
					struck = true
		if struck:
			spawn_shock_ring(global_position, 110.0, Color(1.0, 0.85, 0.35, 0.8))
			SfxSynth.play_at(self, global_position, "thump", -10.0)

# Circle of Sanctuary (rune): stand TRULY still for a second and a ward ring
# rises; enemy shots die at its edge. A single step breaks it.
# DEADEYE (Windstalker set-soul, Shroomite-kin): stand truly still for a
# breath and the next volley you loose is a CERTAIN crit. The prime is shown:
# the weapon icon glints. Movement spends nothing -- only loosing does.
func _tick_deadeye(delta: float) -> void:
	if not set_soul_active("windstalker") or is_dead:
		_deadeye_t = 0.0
		_deadeye_primed = false
		return
	if velocity.length() >= 24.0:
		_deadeye_t = 0.0
		_deadeye_primed = false
		return
	_deadeye_t += delta
	if _deadeye_t >= 0.9 and not _deadeye_primed:
		_deadeye_primed = true
		SfxSynth.play_at(self, global_position, "chime", -16.0, 1.8)
		if has_node("WeaponIcon"):
			var wi = $WeaponIcon
			var tw := create_tween()
			tw.tween_property(wi, "modulate", Color(1.6, 1.6, 1.2), 0.12)
			tw.tween_property(wi, "modulate", Color.WHITE, 0.25)

func _tick_sanctuary(delta: float) -> void:
	var has_rune := GameState.get_bonus_total("sanctuary") > 0.0
	# "still" is about intent, not altitude: near-zero velocity is enough (the
	# ring may stand on a cloud), and a little idle drift doesn't break it
	var still := has_rune and not is_dead and velocity.length() < 24.0
	if not still:
		_still_t = 0.0
		if _sanctuary_ring != null:
			_unmake_ring(_sanctuary_ring)
			_sanctuary_ring = null
		return
	_still_t += delta
	if _still_t < 1.0:
		return
	if _sanctuary_ring == null:
		_sanctuary_ring = _make_ring(100.0, Color(0.55, 0.85, 1.0, 0.45))
	for group_name in ["enemy_projectile", "hostile_projectile", "boss_projectile"]:
		for pr in get_tree().get_nodes_in_group(group_name):
			if pr is Node2D and is_instance_valid(pr) \
					and global_position.distance_to(pr.global_position) <= 100.0:
				# the ward is SEEN working: each shot dies as a soft blue pop
				# at the point the circle refused it (polish 2026-07-28)
				var pop := CPUParticles2D.new()
				pop.one_shot = true
				pop.explosiveness = 1.0
				pop.amount = 8
				pop.lifetime = 0.3
				pop.spread = 180.0
				pop.initial_velocity_min = 40.0
				pop.initial_velocity_max = 90.0
				pop.scale_amount_min = 2.0
				pop.scale_amount_max = 4.0
				pop.color = Color(0.6, 0.88, 1.0, 0.9)
				get_parent().add_child(pop)
				pop.global_position = (pr as Node2D).global_position
				pop.emitting = true
				pop.finished.connect(pop.queue_free)
				SfxSynth.play_at(self, (pr as Node2D).global_position, "pop", -12.0, 1.2)
				pr.queue_free()

# The Plucked Hair: enemies close + the cooldown up = the mirror-mage stands.
func _tick_hair_clone() -> void:
	if GameState.get_bonus_total("hair_clone") <= 0.0 or is_dead:
		return
	if _now() < hair_ready_at:
		return
	if get_tree().get_first_node_in_group("player_mirror") != null:
		return
	var threat := false
	for group_name in ["course_enemy", "dungeon_combatant", "siege_enemy"]:
		for e in get_tree().get_nodes_in_group(group_name):
			if e is Node2D and is_instance_valid(e) and not ("is_dead" in e and e.is_dead) \
					and global_position.distance_to(e.global_position) <= 420.0:
				threat = true
				break
		if threat:
			break
	if not threat:
		return
	hair_ready_at = _now() + 20.0
	var mirror = load("res://mirror_mage.gd").new()
	mirror.source = self
	mirror.damage = maxi(4, int(round((8.0 + GameState.player_level * 0.5) * (1.0 + GameState.get_bonus_total("wand_damage")) * 0.5)))
	get_parent().add_child(mirror)
	mirror.global_position = global_position + Vector2(-facing_direction * 40.0, 0.0)

# a standing ground-ring that follows the player until unmade
func _make_ring(radius: float, col: Color) -> Node2D:
	var ring := Node2D.new()
	var line := Line2D.new()
	line.width = 5.0   # 3px at half-alpha vanished at night (EYES 2026-07-28)
	line.default_color = Color(col.r, col.g, col.b, minf(col.a + 0.35, 1.0))
	var pts := PackedVector2Array()
	for i in range(25):
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a) * radius, sin(a) * radius * 0.35))
	line.points = pts
	ring.add_child(line)
	ring.z_index = 3
	add_child(ring)
	ring.position = Vector2(0, 8)
	return ring

func _unmake_ring(ring: Node2D) -> void:
	if ring == null or not is_instance_valid(ring):
		return
	var t := ring.create_tween()
	t.tween_property(ring, "modulate:a", 0.0, 0.25)
	t.tween_callback(ring.queue_free)

func _physics_process(delta: float) -> void:
	update_orbs()   # keep the HP/mana globes tracking live pools (incl. passive regen)
	if player_light:
		# carry a light through the dark places: the dungeon, and the Underdark
		# (deep below the surface, where main.tscn's own CanvasModulate dims it)
		# carry the torch through the dark places: dungeons, AND the tile Underground (now
		# Terraria-dim, so the light is needed to see past a small radius).
		if not _tile_world_checked:
			_tile_world_checked = true    # query the group ONCE, not every physics frame
			_in_tile_world = is_inside_tree() and get_tree().get_first_node_in_group("tile_world") != null
		player_light.enabled = GameState.in_dungeon or global_position.y > 300.0 or _in_tile_world
	if is_dead:
		return
	# both rift doors standing = the drain runs (Riftweaving)
	tick_portals(delta)
	tick_wukong(delta)   # pillar stance / sanctuary ring / the plucked hair
	_tick_fishing(delta)   # a waiting line ticks toward its bite (pillar 3)
	_chip_accum += delta
	if _chip_accum >= 0.3:
		_chip_accum = 0.0
		update_buff_chips()

	# fall-damage apex: remember the highest point of the current airtime so we
	# can measure the drop on landing (only once we've touched ground at least
	# once, so spawning slightly above the floor never counts as a fall).
	if is_on_floor():
		fall_apex_y = global_position.y
		_last_ground_pos = global_position
	elif has_touched_ground:
		fall_apex_y = min(fall_apex_y, global_position.y)
		# THE VOID GUARD: if we've fallen far below the last ground we stood on, we've
		# dropped out of the world (a gap, or collision not yet built after a load) --
		# recover to that ground instead of falling forever (dev report 2026-07-22).
		if global_position.y > _last_ground_pos.y + FALL_RECOVER_DROP:
			global_position = _last_ground_pos
			velocity = Vector2.ZERO

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

	# boss poison DoT (a signature ability): ticks while active, expires on its own
	if _now() < poison_until and not god_mode and not is_dead:
		_poison_accum += poison_dps * delta
		if _poison_accum >= 1.0:
			var whole = int(_poison_accum)
			_poison_accum -= whole
			_poison_tick(whole)

	# boss crowd-control gates for this frame (stun/freeze block everything; root
	# blocks movement but allows attacks)
	var cc_hard := cc_action_locked()
	var cc_stuck := cc_move_locked()

	# hotbar: keys 1-9 and 0 pick inventory slots 0-9; wield the weapon there.
	# Gated like attack/dig (audit fix): now that a hotbar press can DRINK a
	# consumable, a stray "1" with the bag or skill tree open destroyed a potion
	# the player didn't need -- while the same press couldn't swing a weapon,
	# which is the inconsistency that made it a bug.
	if not ui_blocks_world_input():
		for i in range(HOTBAR_SIZE):
			if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
				select_hotbar_slot(i)

	# T = blink-dash: the Shadowstep Sigil relic earns it, god mode just gives it
	if Input.is_action_just_pressed("admin_dash") and not cc_stuck and (has_relic_power("blink") or god_mode):
		perform_admin_dash()

	if Input.is_action_just_pressed("place_torch"):
		try_place_torch()

	# Riftweaving (Mage): Z weaves the doors -- see try_weave_portal
	if Input.is_action_just_pressed("portal") and has_portal_skill():
		try_weave_portal()

	# MOVABLE BUILDINGS (5.2): a packed building plants where you stand on H
	if Input.is_action_just_pressed("harvest") and GameState.moving_building != "" and not GameState.in_dungeon:
		try_plant_building()

	if Input.is_action_just_pressed("move_left"):
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_left_press_time < DOUBLE_TAP_WINDOW and not cc_stuck:
			perform_dash(-1)
		last_left_press_time = now

	if Input.is_action_just_pressed("move_right"):
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_right_press_time < DOUBLE_TAP_WINDOW and not cc_stuck:
			perform_dash(1)
		last_right_press_time = now

	if Input.is_action_just_pressed("jump") and not cc_stuck:
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
		elif wukong_air_hop_allowed():
			# Cloud Step (Wukong road): one more hop off a cloudlet that only
			# exists for the instant the sole needs it
			velocity.y = JUMP_VELOCITY * 0.92
			current_jump_anim = "jump3" if jumps_used >= 2 else "jump2"
			jumps_used += 1
			spawn_cloudlet()
			play_sfx(SFX_JUMP)
		elif somersault_ready():
			perform_somersault()   # all hops spent: the press becomes the flip

	var direction = Input.get_axis("move_left", "move_right")
	if cc_stuck or pillar_planted:
		direction = 0.0                       # stun/freeze/root/pillar: rooted in place
	elif _now() < disorient_until and not god_mode:
		direction = -direction                # disorient: your controls betray you
	if direction:
		facing_direction = sign(direction)
	if has_weapon() and not is_attacking:
		update_weapon_visual(active_stats.icon_offset)
	update_combo_label()

	if not is_dashing and not is_knocked_back:
		velocity.x = direction * SPEED * skill_move_speed_mult()
		if _now() < freeze_until and not god_mode:
			velocity.x = 0.0                  # frozen solid: can't even be slid
		velocity.x += pull_vel_x              # boss pull (Void Rift) rides on top
	pull_vel_x = 0.0                          # consumed this frame

	# Hold left-click to keep attacking: the weapon auto-fires on cooldown and the
	# hand flares each shot. (The dedicated attack body pose -- the future
	# two-hands-up frame -- isn't wired yet; these frames are now the aim pose.)
	# Root still lets you swing; only stun/freeze (cc_hard) locks attacks out.
	if Input.is_action_pressed("attack") and not cc_hard and not GameState.placing_building \
			and not ui_blocks_world_input():
		# a channelling Sage pours a beam instead of firing bolts; everyone
		# else falls through to the normal per-cooldown attack
		# (a click that places/deletes a building must not ALSO swing a weapon,
		# and a click on an OPEN PANEL must not reach the world at all)
		if not channel_beam(delta):
			perform_attack()
	else:
		stop_beam()
	_tick_dig(delta)

	# right-click near a VILLAGER opens their menu (Talk / Ask for Quest / Show me
	# stats / Leave the village -- villager_menu.gd). Handled HERE, ahead of the
	# off-hand attack, so one press can't both open the menu and fire a spell:
	# attacks are polled from the Input singleton, so a menu opening elsewhere in
	# the same frame could not consume the click.
	if Input.is_action_just_pressed("secondary_attack") and not cc_hard \
			and not ui_blocks_world_input():
		if not _try_open_villager_menu():
			perform_secondary_attack()

	move_and_slide()
	handle_fall_landing()
	# drive the sprite animation after movement (needs final velocity/floor state)
	update_body_anim(delta)
	update_shadow_aura(delta)
	monarch_tick(delta)

# --- Flight (Aetherwing) ---
# Levitation is universal now -- mana is the gate, not a relic or a class.
func has_flight() -> bool:
	return true

# The feathered wings are still an EARNED look: the Aetherwing relic, or the
# Monarch outgrowing the ground. Everyone else levitates bare.
# DEV CALL (2026-07-20): no wings in the beginning. They used to sprout at
# monarch stage 1 -- character level FIVE, minutes into a run, feathers on
# a shadow. The ability (levitation, mana-priced) is untouched; the VISUAL
# now waits for the Veiled stage (5/7, level 60), where what emerges reads
# as the Monarch's own shadow made shape -- or for the Aetherwing relic,
# whose whole identity is "bought wings you can see".
const WINGS_STAGE = 5
func has_wings() -> bool:
	return god_mode \
		or GameState.monarch_stage() >= WINGS_STAGE \
		or GameState.get_bonus_total("flight") > 0.0

# Mana burned per second aloft. A Mage pays far less. Never free -- a floor of
# 1/sec keeps levitation from becoming permanent flight no matter how it's
# stacked. (The old "levitate_cost" skill modifier was a DEAD READ -- no node,
# item or boon ever granted the key after levitation was stripped from the class
# trees -- so the audit removed it, 2026-07-23. If a discount skill returns some
# day, grant + read the key together.)
func levitate_mana_rate() -> float:
	var rate := LEVITATE_MANA_PER_SEC
	if GameState.chosen_class == "Mage":
		rate *= LEVITATE_MAGE_DISCOUNT
	return maxf(1.0, rate)

func has_fall_immunity() -> bool:
	# god mode flies, so it must not be killed by its own landing
	return god_mode or GameState.get_bonus_total("fall_immunity") > 0.0

# Runs every frame after gravity. With wings equipped: on the ground it refills
# the flight budget; in the air, holding Space soars (draining the budget) and
# otherwise you glide down gently. Without wings this is a no-op.
func update_flight(delta: float) -> void:
	# DEV CALL (2026-07-21, live playtest): "my character is still able to
	# fly, idk why." The ABILITY now shares the wings' own gate -- the soul
	# is too weak to lift you until the Veiled stage (5/7, level 60), or
	# until the Aetherwing relic does the lifting for you. Early mobility is
	# the double jump and the dash, as it should be.
	var flying = false
	if is_on_floor():
		flight_depleted_notified = false
	elif Input.is_action_pressed("jump") and has_wings():
		if god_mode:
			# god mode never runs dry -- the point is to cross the map
			flying = true
			velocity.y = FLIGHT_RISE_SPEED
		else:
			var cost := levitate_mana_rate() * delta
			if mana >= cost:
				spend_mana(cost)
				flying = true
				velocity.y = FLIGHT_RISE_SPEED
			elif not flight_depleted_notified:
				flight_depleted_notified = true
				var stack = get_tree().get_first_node_in_group("notification_stack")
				if stack:
					stack.show_notification("Out of mana -- you drop out of the air.")
	# else: not holding Space (or out of mana) -> plain gravity fall. Levitation
	# doesn't slow it; fall_immunity just spares you the landing damage.
	is_levitating = flying
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

# --- FISHING (pillar 3): the rod's whole grammar ----------------------------
# Attack with a rod resolves here first. Returns true when the swing was a
# fishing action (cast / recast / strike) -- perform_attack then stops, so a
# rod at the waterside never windmills at the pond.
func _rod_fish_action() -> bool:
	if _fish_state == "bite":
		_fish_strike()
		return true
	var zone := _nearest_fish_water()
	if zone == null:
		# no water in reach: the rod swings on as a truly pitiful stick
		if _fish_state != "":
			_fish_cancel("")
		return false
	# cast -- or an impatient recast, which re-rolls the wait honestly
	_fish_zone = zone
	_fish_state = "wait"
	var gap: Array = Fishing.bite_gap(active_weapon_id)
	_fish_timer = randf_range(float(gap[0]), float(gap[1]))
	_fish_cast_pos = global_position
	_spawn_bobber(zone)
	animate_sword()   # the cast flick
	return true

func _nearest_fish_water() -> Node:
	var best: Node = null
	var best_dx := 1.0e9
	for n in get_tree().get_nodes_in_group("fish_water"):
		if not (is_instance_valid(n) and n.has_method("fish_half_width")):
			continue
		var dx: float = absf(n.global_position.x - global_position.x)
		# reach a little past the water's edge; the dy guard keeps a villager's
		# pond from answering a line cast eight bands under the earth
		if dx <= float(n.fish_half_width()) + 60.0 \
				and absf(float(n.fish_surface_y()) - global_position.y) <= 420.0 \
				and dx < best_dx:
			best = n
			best_dx = dx
	return best

func _tick_fishing(delta: float) -> void:
	if _fish_state == "":
		return
	# stowing the rod, losing the water, or wandering off drags the line dead
	if str(active_def.get("tool_type", "")) != "rod" \
			or not is_instance_valid(_fish_zone) \
			or global_position.distance_to(_fish_cast_pos) > FISH_DRIFT_CANCEL:
		_fish_cancel("")
		return
	_fish_timer -= delta
	if _fish_state == "wait" and _fish_timer <= 0.0:
		_fish_state = "bite"
		_fish_timer = FISH_BITE_WINDOW
		if is_instance_valid(_fish_bobber):
			_fish_bobber.modulate = Color(1.0, 0.85, 0.35)
			_fish_bobber.scale = Vector2(1.9, 1.9)
		play_sfx(SFX_JUMP)   # the closest thing the kit has to a plop
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("The line BITES — swing to land it!")
	elif _fish_state == "bite" and _fish_timer <= 0.0:
		_fish_cancel("The water goes still.")

func _fish_strike() -> void:
	var kind := "village"
	if is_instance_valid(_fish_zone):
		kind = str(_fish_zone.fish_kind())
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var got: String = Fishing.roll_catch(kind, Fishing.rod_tier(active_weapon_id), rng)
	var stack = get_tree().get_first_node_in_group("notification_stack")
	animate_sword()   # the landing yank
	if inventory.add_item(got, 1) > 0:
		if stack:
			stack.show_notification("Your bag is full — the catch slips back into the dark.")
	else:
		if stack:
			stack.show_notification("Caught: %s [%s]!" % [Inventory.name_bbcode(got), Inventory.get_grade_name(got)])
			if got == GameState.fishing_quest_oddity():
				stack.show_notification("The %s! Doran will want to see this." % Inventory.name_bbcode(got))
		var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
		if inv_ui and inv_ui.has_method("refresh"):
			inv_ui.refresh()
	_fish_cancel("")

func _spawn_bobber(zone: Node) -> void:
	_clear_bobber()
	var half: float = float(zone.fish_half_width())
	var bx: float = clampf(global_position.x + float(facing_direction) * 52.0,
		zone.global_position.x - half * 0.92, zone.global_position.x + half * 0.92)
	var b := Node2D.new()
	b.z_as_relative = false
	b.z_index = 30
	# big enough to read at the 0.6 world zoom (a 7px dot rendered ~4px and
	# vanished against the water -- EYES 2026-07-28)
	var dot := ColorRect.new()
	dot.color = Color(0.92, 0.28, 0.22)
	dot.size = Vector2(10, 10)
	dot.position = Vector2(-5.0, -6.0)
	b.add_child(dot)
	var gleam := ColorRect.new()
	gleam.color = Color(1.0, 0.95, 0.9, 0.9)
	gleam.size = Vector2(4, 3)
	gleam.position = Vector2(-3.0, -5.0)
	b.add_child(gleam)
	zone.add_child(b)
	# +2: straddle the drawn waterline (EYES: at -2 the float hung in the air)
	b.global_position = Vector2(bx, float(zone.fish_surface_y()) + 2.0)
	_fish_bobber = b

func _fish_cancel(msg: String) -> void:
	_fish_state = ""
	_fish_zone = null
	_clear_bobber()
	if msg != "":
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification(msg)

func _clear_bobber() -> void:
	if is_instance_valid(_fish_bobber):
		_fish_bobber.queue_free()
	_fish_bobber = null

func perform_attack() -> void:
	if attack_cooldown_remaining > 0 or not has_weapon():
		return
	# FISHING (pillar 3): a wielded rod near open water CASTS instead of
	# swinging -- and the swing while the water bites IS the strike.
	if str(active_def.get("tool_type", "")) == "rod" and _rod_fish_action():
		attack_cooldown_remaining = active_stats.cooldown
		return
	WeaponFx.on_swing(self)   # rhythm counters (stormcall's every-Nth and kin)
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
			# ONLY the admin test wand may nuke. "No special authored" used to
			# route here for ANY wand -- three ordinary loot wands shipped
			# without one and one-clicked every enemy on screen to death for 4
			# mana. (wpn_admin_ruin never reaches this branch at all: its
			# percent_burst special exits above, so listing it here was dead
			# code describing an arrangement the flow cannot produce.) An
			# unrecognised special-less wand fails safe: a plain force bolt
			# from its own weapon_stats damage.
			if active_weapon_id == "wpn_wand":
				cast_wand()   # ADMIN screen-nuke (instakill everything)
			else:
				cast_wand_projectile({"type": "frost_shard",
					"damage": stats.damage, "speed": 560.0, "range": 460.0})
		elif special_type == "nuke":
			cast_wand_nuke(special)   # Runeweave Scepter -- big FINITE screen AoE
		elif special_type == "tome_storm":
			cast_storm_tome(special)  # area denial: a stormlet works the aimed ground
		elif special_type == "sentry":
			plant_sentry(special)     # a watching totem stood at your feet
		else:
			cast_wand_projectile(special)   # Emberstaff / Icicle Wand ...
		return
	attack_cooldown_remaining = stats.cooldown * skill_cooldown_mult(active_weapon_type)
	if active_weapon_type == "bow":
		# behavior-library bows (roster wave 2): a mortar bow / leaping bolt /
		# burst bow fires ITS behavior instead of a plain shaft
		if special_type in ["lob", "ricochet", "cluster"]:
			play_sfx(SFX_BOW)
			var cr_b = roll_crit(int(round(special.get("damage", stats.damage) * skill_damage_mult("bow"))))
			launch_projectile(special, get_aim_direction(), cr_b[0], cr_b[1])
			return
		animate_bow(stats)
		return
	if active_weapon_type == "spear":
		if special_type == "javelin_volley":
			throw_javelin_volley(special)
		else:
			animate_spear(stats)
		return
	# thrown "melee" weapons: the whole attack IS the projectile (the soulwheel
	# and the lash joined the hook and boomerang here -- weapons overhaul wave 1)
	if special_type in ["hook", "boomerang", "orbiter", "lash", "chain_maul"]:
		play_sfx(SFX_SWORD)
		animate_sword()
		launch_projectile(special, get_aim_direction(), int(special.get("damage", stats.damage)))
		return
	# melee swing (also the swing for an Excellent weapon) -- the strike lands at
	# the weapon's own reach in the direction of the cursor. Distance to the
	# cursor is irrelevant: melee is melee.
	var is_excellent = active_def.has("unique_effect")
	# remembered so the swing's charge tick knows where (and how hard) it landed;
	# both stay null/0 on a clean miss, and the charge still advances
	_last_swing_target = null
	_last_swing_damage = 0
	var aim_dir = get_aim_direction()
	# staff_reach_mult: the Wukong staves lengthen with a landed combo (1.0 for
	# every other weapon -- see staff_note_swing)
	$AttackArea.position = aim_dir * stats.range_offset * staff_reach_mult()
	$AttackArea.rotation = aim_dir.angle()
	# advance the combo string for this swing; the multiplier it returns is >1
	# only on the finisher
	var combo_mult := combo_step()
	var is_finisher: bool = combo_mult > 1.0
	# the swing itself leaves a trail -- fired here, BEFORE anything is hit, so
	# cutting empty air still draws the arc. A finisher carves a bigger one.
	spawn_swing_trail(aim_dir, stats, is_finisher)
	# a wielded gathering tool works the harvest node it's swung at (trees want the
	# axe, rocks the pickaxe -- see harvest_node.gd). This used to read
	# $AttackArea.get_overlapping_areas(), but a harvest node sits on the DEFAULT
	# collision layer (1) while AttackArea only monitors the enemy layer (mask 4) --
	# so the swing never saw a tree or rock and gathering silently did nothing (dev
	# report 2026-07-22: "mining and chopping wood doesn't work"). Detect by the
	# `harvestable` GROUP within the swing's reach instead, so it's immune to layer
	# config: swing the nearest tree/rock you're standing next to.
	var tool_type = str(active_def.get("tool_type", ""))
	if tool_type != "":
		var reach: float = float(stats.range_offset) + 56.0
		var best: Node = null
		var best_dx: float = reach
		for node in get_tree().get_nodes_in_group("harvestable"):
			if not (is_instance_valid(node) and node.has_method("take_tool_hit")):
				continue
			var dx: float = absf(node.global_position.x - global_position.x)
			var dy: float = absf(node.global_position.y - global_position.y)
			if dx <= best_dx and dy <= 150.0:
				best = node
				best_dx = dx
		if best != null:
			best.take_tool_hit(tool_type, self)
	elif not GameState.seen_gather_hint:
		# swinging a plain WEAPON at a tree/rock -- the new player who doesn't know
		# gathering needs a tool. Teach it ONCE, at the exact moment of confusion, so
		# "I hit the tree and nothing happened" never becomes a bug report.
		for node in get_tree().get_nodes_in_group("harvestable"):
			if is_instance_valid(node) and node.has_method("take_tool_hit") \
					and absf(node.global_position.x - global_position.x) <= 92.0 \
					and absf(node.global_position.y - global_position.y) <= 150.0:
				GameState.seen_gather_hint = true
				var st = get_tree().get_first_node_in_group("notification_stack")
				if st:
					st.show_notification("That needs a TOOL — wield your Woodsman's Axe (trees) or Miner's Pickaxe (rock) from the hotbar, then swing.")
				break
	var bodies = $AttackArea.get_overlapping_bodies()
	if special_type == "cleave":
		# the Sunderer carves through EVERY body in the arc, not just one
		var cleave_total = 0
		for body in bodies:
			if body.has_method("take_damage"):
				var cr = roll_crit(int(round(stats.damage * skill_damage_mult("melee") * combo_mult)))
				body.take_damage(cr[0])
				show_hit(body, cr[0], cr[1])
				apply_melee_skills(body, cr[0])
				cleave_total += cr[0]
			if body.has_method("apply_knockback"):
				var kb = randf_range(stats.knockback_min, stats.knockback_max) * (1.6 if is_finisher else 1.0) * grade_force_mult()
				body.apply_knockback(knockback_sign_toward(body), kb)
		apply_omnivamp(cleave_total)
	else:
		var target = closest_body(bodies)
		if target:
			# Excellent weapons keep HALF of your build's damage scaling (dev call
			# 2026-07-28: a build should ENABLE the flagship, not replace it, nor
			# scale it to infinity). Crit, lifesteal, on-hit DoTs and execute still
			# apply in FULL (roll_crit below / apply_melee_skills).
			var mult := skill_damage_mult("melee")
			if is_excellent:
				mult = 1.0 + (mult - 1.0) * EXCELLENT_SKILL_SCALE
			var cr = roll_crit(int(round(stats.damage * mult * combo_mult)))
			var dealt = cr[0]
			# The Patient Knife: the FIRST cut is the deepest -- +40% against
			# a foe still standing at full health
			if str(active_def.get("special", {}).get("rider", "")) == "patient" \
					and "health" in target and "max_health" in target \
					and int(target.health) >= int(target.max_health):
				dealt = int(round(dealt * 1.4))
			_last_swing_target = target
			_last_swing_damage = dealt
			if target.has_method("take_damage"):
				# A boss can absorb a blow outright (parry, phase, sidestep,
				# stagger guard, soulbind). Printing a damage number anyway was
				# a lie: you'd hammer a Frost Monarch, watch numbers pour out,
				# and its bar would never move. Only report what actually landed.
				var landed = target.take_damage(dealt)
				if landed == null or landed:
					show_hit(target, dealt, cr[1])
					apply_omnivamp(dealt)
					apply_melee_skills(target, dealt)
					# JUICE: the punchy blows hang the world a beat + kick the camera
					if cr[1] or is_finisher:
						_impact_feedback(cr[1])
				else:
					_last_swing_damage = 0
			if target.has_method("apply_knockback"):
				# a finisher doesn't just hurt more, it sends them
				var knockback_distance = randf_range(stats.knockback_min, stats.knockback_max) * (1.6 if is_finisher else 1.0) * grade_force_mult()
				target.apply_knockback(knockback_sign_toward(target), knockback_distance)
			if is_excellent:
				apply_excellent_effect(target, dealt)
	# the Windcutter's signature: the swing releases a slash that flies onward
	if special_type == "flying_slash":
		launch_projectile(special, aim_dir, int(round(special.get("damage", 10) * skill_damage_mult("melee"))))
	# The Last Word: the swing looses a ghost-image of an ancestor blade --
	# out, whirl, home (the projectile owns the whole flight)
	elif special_type == "zenith_blade":
		launch_projectile(special, aim_dir, int(round(special.get("damage", 10) * skill_damage_mult("melee"))))
	# THE WHOLE COURT, SPINNING: the swing calls the people you brought home --
	# several shades at once, each carrying a different ancestor blade
	elif special_type == "court_barrage":
		unleash_court(special, aim_dir)
	# High-grade blades hurl the swing itself forward as a crescent. This is how
	# a melee weapon earns ranged comfort -- the replacement for the old
	# levitation reach, except you EARN it by finding the weapon instead of
	# everyone having it from level one. It rides on top of the normal swing, so
	# the blade still hits whatever is standing next to you as well.
	var swing_slash: Dictionary = swing_slash_config()
	if not swing_slash.is_empty():
		launch_swing_slash(swing_slash, aim_dir, stats)
	# the swing itself winds up any charge-style unique -- a whiff still counts
	advance_swing_charge(_last_swing_target, _last_swing_damage)
	# the extending staff reads this swing: a LANDED hit draws it longer, a
	# whiff shrinks it back, and the fourth landed hit is the pillar slam
	staff_note_swing(_last_swing_target != null,
		global_position + aim_dir * stats.range_offset * staff_reach_mult())
	animate_sword()

# --- Melee combo strings ---
# Consecutive swings chain into a string ending in a heavier finisher. How LONG
# that string runs is derived from swing speed, exactly as size is: a light
# quick blade flurries through four hits for a modest payoff, a ponderous maul
# gets only two but the second lands like a truck. So "combo" becomes another
# dial that separates weapons without anyone hand-authoring it per weapon, and
# it cannot contradict the roster's other rules.
# Excellent (unique-effect) melee weapons keep this FRACTION of your build's
# flat damage multiplier -- half, so a damage build still lifts the flagship
# without letting the best weapons scale away from everything else.
const EXCELLENT_SKILL_SCALE = 0.5

const COMBO_WINDOW_MULT = 2.2      # how long after a swing the chain stays live
var combo_index := 0               # hits into the current string
var combo_expire_at := 0.0
var combo_label: Label = null

func combo_length() -> int:
	if not has_weapon() or active_weapon_type != "melee":
		return 1
	var cd := float(active_stats.get("cooldown", 0.4))
	if cd <= 0.30:
		return 4        # flurry
	if cd <= 0.50:
		return 3
	return 2            # wind up, SLAM

# Every string averages the SAME multiplier (1.25x) over its length, so combos
# reward maintaining a chain without quietly rebalancing the roster.
#
# The sizing of these is counterintuitive on purpose. A SHORT string reaches its
# finisher far more often -- a 2-hit string finishes every other swing, a 4-hit
# string only every fourth -- so the short string needs the SMALLER finisher to
# come out even. Giving the maul the big multiplier "because it's heavy" handed
# heavy weapons a ~51% damage buff over light ones by accident.
#
# The felt difference between a dagger tap and a maul slam comes from base
# damage instead (Warhammer 35 vs Twin Fangs 6), which is where it belongs: the
# maul's finisher is still by far the biggest number on screen.
func combo_finisher_mult() -> float:
	match combo_length():
		4: return 2.0      # (1 + 1 + 1 + 2.00) / 4 = 1.25
		3: return 1.75     # (1 + 1 + 1.75)     / 3 = 1.25
		_: return 1.5      # (1 + 1.50)         / 2 = 1.25

func combo_is_live() -> bool:
	return combo_index > 0 and _now() <= combo_expire_at

# Advances the combo for THIS swing and returns the damage multiplier it earns.
# Let the window lapse and the string resets -- you cannot bank a finisher and
# wander off with it.
func combo_step() -> float:
	if not has_weapon() or active_weapon_type != "melee":
		return 1.0
	var now := _now()
	if now > combo_expire_at:
		combo_index = 0
	var finisher: bool = combo_index >= combo_length() - 1
	combo_expire_at = now + float(active_stats.get("cooldown", 0.4)) * COMBO_WINDOW_MULT
	combo_index = (combo_index + 1) % combo_length()
	return combo_finisher_mult() if finisher else 1.0

func reset_combo() -> void:
	combo_index = 0
	combo_expire_at = 0.0

# A small readout so the string is legible while you swing -- without it a combo
# is invisible and the finisher just feels like a random big hit.
func update_combo_label() -> void:
	if combo_label == null:
		combo_label = Label.new()
		combo_label.add_theme_font_size_override("font_size", 13)
		combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		combo_label.add_theme_constant_override("outline_size", 4)
		combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		combo_label.position = Vector2(-50, -104)
		combo_label.size = Vector2(100, 18)
		combo_label.z_index = 40
		combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(combo_label)
	if not combo_is_live():
		combo_label.visible = false
		return
	combo_label.visible = true
	# the step about to land is the one worth flagging
	var next_is_finisher: bool = combo_index >= combo_length() - 1
	combo_label.text = ("FINISHER!" if next_is_finisher else "COMBO x%d" % combo_index)
	combo_label.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.35) if next_is_finisher else Color(0.85, 0.9, 1.0))

# --- Per-weapon crit character ---
# Derived from speed, so it never contradicts the size/combo rules: quick blades
# find gaps often (crit CHANCE), heavy weapons crit rarely but devastate when
# they land (crit DAMAGE). This rides on top of whatever gear and skills give.
func weapon_crit_chance_bonus() -> float:
	if not has_weapon() or active_weapon_type != "melee":
		return 0.0
	var t := clampf((float(active_stats.get("cooldown", 0.4)) - 0.18) / 0.72, 0.0, 1.0)
	return lerpf(0.10, 0.0, t)

func weapon_crit_damage_bonus() -> float:
	if not has_weapon() or active_weapon_type != "melee":
		return 0.0
	var t := clampf((float(active_stats.get("cooldown", 0.4)) - 0.18) / 0.72, 0.0, 1.0)
	return lerpf(0.0, 0.60, t)

# The crescent a swing leaves behind. Drawn on EVERY swing, hit or miss, so the
# weapon has weight even when you cut empty air. Its sweep, thickness, glow and
# lifetime all scale with the weapon's grade, so a Mythic blade carves a wide
# bright arc where a Common one barely smudges the air -- the grade is something
# you can SEE in the swing rather than only read in a tooltip.
var _slash_tex_cache = 0   # 0 = unchecked, null = none, Texture2D = loaded
func _slash_texture() -> Texture2D:
	if typeof(_slash_tex_cache) != TYPE_INT:
		return _slash_tex_cache
	var path := "res://art/effects/slash_arc.png"
	_slash_tex_cache = load(path) if ResourceLoader.exists(path) else null
	return _slash_tex_cache

func spawn_swing_trail(aim_dir: Vector2, stats: Dictionary, finisher := false) -> void:
	var grade: String = Inventory.ITEM_GRADES.get(active_weapon_id, "common")
	var rank: int = int(Inventory.GRADE_DEFS.get(grade, {}).get("rank", 1))
	# element-first colour (item-art overhaul 2026-07-28): the crescent reads as
	# the weapon's element -- fire swings orange, ice swings pale-blue -- blended
	# a touch toward the weapon's own colour so twin fire weapons still differ.
	var elem: String = Inventory.element_of(active_weapon_id)
	var col: Color = Inventory.element_fx(elem)["tint"]
	if elem == "physical":
		col = active_def.get("color", Color(1, 1, 1))   # plain steel keeps its own hue
	else:
		col = col.lerp(active_def.get("color", col), 0.35)
	var radius := float(stats.range_offset) + float(stats.area_size.y) * 0.5
	var arc := deg_to_rad(70.0 + rank * 11.0)         # higher grade sweeps wider
	var thickness := 4.0 + rank * 2.8
	radius += rank * 3.0                              # and reaches further out
	if finisher:
		# the closing blow of a string reads bigger than the taps before it
		arc *= 1.5
		thickness *= 1.8
		radius += 6.0
	# Texture-first (item-art Phase 1): a real crescent sprite at
	# art/effects/slash_arc.png replaces the procedural polygon, MODULATED by the
	# element colour so one white swoosh sheet serves every element. Authored
	# convention: crescent fills the canvas, the hand-edge at the LEFT, bulging
	# right. Falls back to the polygon below until the sprite exists.
	var slash_tex: Texture2D = _slash_texture()
	if slash_tex != null:
		var spr := Sprite2D.new()
		spr.texture = slash_tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.modulate = Color(col.r, col.g, col.b, 0.55 + rank * 0.07)
		var smat := CanvasItemMaterial.new()
		smat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		spr.material = smat
		spr.centered = false
		var span := radius * 2.0 * sin(arc * 0.5)      # vertical reach of the arc
		spr.scale = Vector2(radius / slash_tex.get_width(), span / slash_tex.get_height())
		spr.offset = Vector2(0.0, -slash_tex.get_height() * 0.5)  # hand at left-centre
		spr.rotation = aim_dir.angle()
		spr.z_index = 6
		add_child(spr)
		var slife := 0.15 + rank * 0.035
		var stw := spr.create_tween()
		stw.set_parallel(true)
		stw.tween_property(spr, "modulate:a", 0.0, slife)
		stw.tween_property(spr, "scale", spr.scale * (1.08 + rank * 0.02), slife)
		stw.set_parallel(false)
		stw.tween_callback(spr.queue_free)
		return
	var steps := 12
	var pts := PackedVector2Array()
	for i in range(steps + 1):                         # outer edge
		var a: float = lerpf(-arc * 0.5, arc * 0.5, float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	for i in range(steps, -1, -1):                     # inner edge, back along the arc
		var a: float = lerpf(-arc * 0.5, arc * 0.5, float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * (radius - thickness))
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = Color(col.r, col.g, col.b, 0.28 + rank * 0.085)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	poly.material = mat
	poly.rotation = aim_dir.angle()
	poly.z_index = 6
	add_child(poly)
	# CORE EDGE (VFX pass 2026-07-28): a thin bright crescent riding the outer
	# rim of the soft arc -- the Terraria trick: swings read as a crisp bright
	# EDGE with a soft glow behind it, not one translucent smear. Drawn in the
	# element's glow colour so a fire swing's edge burns hotter than its body.
	var edge_glow: Color = Inventory.element_fx(elem).get("glow", col)
	var epts := PackedVector2Array()
	var ethick := maxf(2.5, thickness * 0.3)
	for i in range(steps + 1):
		var ea: float = lerpf(-arc * 0.5, arc * 0.5, float(i) / steps)
		epts.append(Vector2(cos(ea), sin(ea)) * radius)
	for i in range(steps, -1, -1):
		var ea2: float = lerpf(-arc * 0.5, arc * 0.5, float(i) / steps)
		epts.append(Vector2(cos(ea2), sin(ea2)) * (radius - ethick))
	var edge := Polygon2D.new()
	edge.polygon = epts
	edge.color = Color(edge_glow.r, edge_glow.g, edge_glow.b, 0.75 + rank * 0.04)
	edge.material = mat
	poly.add_child(edge)   # child of the arc: shares its rotation, fade and death
	# the tween belongs to the trail itself, so it dies with it rather than
	# outliving the node it animates
	var life := 0.15 + rank * 0.035
	var tw := poly.create_tween()
	tw.set_parallel(true)
	tw.tween_property(poly, "modulate:a", 0.0, life)
	tw.tween_property(poly, "scale", Vector2.ONE * (1.08 + rank * 0.02), life)
	tw.set_parallel(false)
	tw.tween_callback(poly.queue_free)

# The slash a weapon throws with its swing. Every melee weapon of RARE or better
# gets one, derived from its grade -- an explicit "swing_slash" entry only adds
# flavour (a status rider) on top. Grade drives all three of the things that
# make a slash feel powerful:
#
#   girth  -- how much space the crescent occupies, visual AND hitbox together
#   reach  -- how far across the room it travels
#   speed  -- how hard it leaves the blade
#
# so a Mythic weapon hurls a huge fast wall of force while a Rare one flicks a
# modest crescent. Damage stays a FRACTION of the weapon's own hit, so reaching
# out never beats walking up and swinging -- the power is in the spectacle and
# the coverage, not in the number.
const SLASH_MIN_RANK = 3        # rare and up

# How much a weapon's GRADE amplifies its physical presence -- how far it throws
# what it hits, how much room its arc takes. Kept deliberately separate from
# damage: a mythic weapon should feel overwhelming to swing, not merely print a
# bigger number. Every weapon benefits, not just the ones that throw slashes.
func weapon_grade_rank() -> int:
	if not has_weapon():
		return 0
	var g: String = Inventory.ITEM_GRADES.get(active_weapon_id, "")
	return int(Inventory.GRADE_DEFS.get(g, {}).get("rank", 0))

func grade_force_mult() -> float:
	return 1.0 + weapon_grade_rank() * 0.16     # mythic sends them ~2x as far

# Ranged weapons earn the same presence melee did: a mythic bow looses a visibly
# heavier shaft that carries further, a mythic wand throws a fatter bolt. Scaled
# more gently than a melee slash (which lands once per swing) because ranged
# weapons put a projectile in the air constantly.
func grade_projectile_girth() -> float:
	return 1.0 + weapon_grade_rank() * 0.22     # mythic ~2.3x
func grade_projectile_range() -> float:
	return 1.0 + weapon_grade_rank() * 0.13     # mythic ~1.8x

func swing_slash_config() -> Dictionary:
	if not has_weapon() or active_weapon_type != "melee":
		return {}
	var grade: String = Inventory.ITEM_GRADES.get(active_weapon_id, "")
	var rank: int = int(Inventory.GRADE_DEFS.get(grade, {}).get("rank", 0))
	var explicit: Dictionary = active_def.get("swing_slash", {})
	if rank < SLASH_MIN_RANK and explicit.is_empty():
		return {}
	# A weapon that already HAS a signature does not get a second one. Handing
	# every good weapon the same crescent made the whole top of the roster feel
	# identical -- an Excellent's identity is its unique effect, so that IS its
	# thrown thing. Only weapons with nothing of their own get a derived one.
	if active_def.has("unique_effect") and explicit.is_empty():
		return {}
	# ...and the ones that do get it don't all get a crescent. What a weapon
	# throws follows its archetype: a quick blade flicks a slash, a mid-weight
	# hurls a point that punches through a line, a heavy weapon lobs a slow
	# burst that detonates where it lands.
	var cd := float(active_stats.get("cooldown", 0.4))
	var kind := "flying_slash"
	var aoe := 0.0
	var speed_scale := 1.0
	# thresholds picked against the ACTUAL roster so all three bands are
	# populated -- at 0.34/0.60 the middle band held exactly one weapon
	if cd >= 0.78:
		kind = "flying_slash"
		aoe = 120.0 + rank * 14.0     # a detonating shock, not a clean cut
		speed_scale = 0.72            # you can see it coming
	elif cd >= 0.45:
		kind = "javelin_volley"       # a hurled point that punches through a line
		speed_scale = 1.15
	var out := {
		"type": kind,
		"aoe": aoe,
		"damage_mult": 0.30 + rank * 0.05,        # rare 0.45 -> mythic 0.60
		"girth": 1.0 + rank * 0.42,               # rare 2.26 -> mythic 3.52
		"range": 300.0 + rank * 95.0,             # rare 585  -> mythic 870
		"speed": (460.0 + rank * 40.0) * speed_scale,
	}
	# An authored entry contributes FLAVOUR ONLY -- a status rider. Geometry is
	# always derived, so a hand-written entry can never lag behind a later
	# tuning pass (which is exactly what happened when the first six carried
	# their own range and quietly stayed at 340px while everything else grew).
	if explicit.has("status"):
		out["status"] = explicit["status"]
	return out

# THE WHOLE COURT, SPINNING (crown melee, First-Fractal-kin never 1:1): every
# swing materialises a rank of courtiers -- shades of the villagers you
# rescued -- fanned around the wielder, each wearing a DIFFERENT ancestor
# tint, each finding its own mark and sweeping. The court fights beside you.
# Deliberately busy: the culmination weapon is allowed to break the crown rule.
const COURT_SCRIPT = preload("res://weapon_projectile.gd")
var _court_cycle := 0
func unleash_court(special: Dictionary, aim_dir: Vector2) -> void:
	var n: int = int(special.get("count", 4))
	var reach := float(special.get("range", 420.0))
	var base := int(round(float(special.get("damage", 10)) * skill_damage_mult("melee")))
	# gather the marks first: the court SPREADS across the row, one shade per
	# body where it can, doubling up only when the court outnumbers the foes
	var marks: Array = []
	for group_name in ["course_enemy", "dungeon_combatant", "siege_enemy"]:
		for e in get_tree().get_nodes_in_group(group_name):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method("take_damage"):
				continue
			if "is_dead" in e and e.is_dead:
				continue
			if global_position.distance_to(e.global_position) <= reach \
					and (e.global_position - global_position).dot(aim_dir) > -40.0:
				marks.append(e)
	marks.sort_custom(func(a, b): return global_position.distance_to(a.global_position) \
		< global_position.distance_to(b.global_position))
	# each shade rolls its own crit -- the court is many people, not one blow
	for i in range(n):
		var cr = roll_crit(base)
		var c = COURT_SCRIPT.new()
		c.kind = "courtier"
		c.court_index = _court_cycle + i
		c.damage = cr[0]
		c.is_crit = cr[1]
		c.direction = aim_dir
		c.max_distance = reach
		c.girth = maxf(0.4, float(special.get("girth", 1.0)))
		c.element = Inventory.element_of(active_weapon_id)
		c.on_hit_status = special.get("status", {})
		c.source = self
		if not marks.is_empty():
			c.court_target = marks[i % marks.size()].global_position
		# fanned rank: spread across the swing arc, alternating high and low so
		# the court reads as a LINE of people, not a stack
		var spread := deg_to_rad(52.0)
		var frac := 0.0 if n <= 1 else float(i) / float(n - 1) - 0.5
		var off := aim_dir.rotated(frac * spread) * 46.0 + Vector2(0, -18.0 + 26.0 * float(i % 2))
		c.position = global_position + off
		get_parent().add_child(c)
	_court_cycle = (_court_cycle + n) % WeaponFx.LEGACY_TINTS.size()
	SfxSynth.play_at(self, global_position, "chime", -10.0, 0.8)

func launch_swing_slash(cfg: Dictionary, dir: Vector2, stats: Dictionary) -> void:
	var mult := float(cfg.get("damage_mult", 0.5))
	var dmg := maxi(1, int(round(float(stats.damage) * mult * skill_damage_mult("melee"))))
	var cr = roll_crit(dmg)
	launch_projectile({
		"type": cfg.get("type", "flying_slash"),
		"speed": cfg.get("speed", 520.0),
		"range": cfg.get("range", 300.0),
		"girth": cfg.get("girth", 1.0),
		"aoe": cfg.get("aoe", 0.0),
		"status": cfg.get("status", {}),
	}, dir, cr[0], cr[1])

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
	# behavior-library knobs (wave 1): only read by the kinds that use them
	p.dwell = float(cfg.get("dwell", 2.2))
	p.bounces = int(cfg.get("bounces", 3))
	p.shards = int(cfg.get("shards", 5))
	p.rider = str(cfg.get("rider", ""))   # flagship bespoke behavior
	# a weapon may colour its thrown crescent (Terra standard: the beam wears
	# the blade's own identity, not a stock wind-blue)
	var tint_arr = cfg.get("tint", [])
	if tint_arr is Array and tint_arr.size() >= 3:
		p.beam_tint = Color(float(tint_arr[0]), float(tint_arr[1]), float(tint_arr[2]))
	# grade-driven scale: bigger crescent, bigger hitbox, same maths everywhere
	p.girth = maxf(0.4, float(cfg.get("girth", 1.0)))
	p.element = Inventory.element_of(active_weapon_id)   # VFX: hit bursts in the weapon's colour
	# a weapon's own status wins; otherwise the Elementalist's Ignite skill rides
	# the cast so a plain wand still burns once you've taken the keystone.
	var status = cfg.get("status", {})
	if status.is_empty():
		var sb = GameState.get_bonus_total("on_hit_burn")
		if sb > 0.0:
			status = {"kind": "burn", "dur": 3.0, "mag": sb}
	p.on_hit_status = status
	p.source = self
	# Stillness (Wukong road) procs only off true WAND casts, so the flag
	# rides the projectile from the one place every cast passes through
	p.from_wand = str(active_def.get("weapon_type", "")) == "wand"
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
	# a higher-grade wand throws a visibly fatter bolt that carries further --
	# multiplied onto the tier's own size (verb sweep 2026-07-29), never
	# replacing it: what the weapon IS times how well this one was made
	var cast: Dictionary = special.duplicate(true)
	cast["girth"] = grade_projectile_girth() * float(special.get("girth", 1.0))
	cast["range"] = float(special.get("range", 450.0)) * grade_projectile_range()
	# THE FLOOD OF SOULS (tome batch 3b): one cast, a STREAM -- three souls
	# leave the book a beat apart, each bending toward the nearest living thing
	if str(cast.get("type", "")) == "soul_stream":
		var n: int = int(cast.get("count", 3))
		launch_projectile(cast, get_aim_direction(), cr[0], cr[1])
		for si in range(n - 1):
			get_tree().create_timer(0.14 * float(si + 1), false).timeout.connect(
				func():
					if is_instance_valid(self) and not is_dead:
						launch_projectile(cast, get_aim_direction(), cr[0], cr[1]))
		return
	launch_projectile(cast, get_aim_direction(), cr[0], cr[1])

# TOME STORM (behavior library 2026-07-28): conjure a stormlet over the aimed
# ground -- clamped to the tome's reach -- that rains strikes for a few
# seconds while you fight elsewhere. Deepwood's area denial, spellbook-kin.
const STORM_CLOUD_SCRIPT = preload("res://storm_cloud.gd")
func cast_storm_tome(special: Dictionary) -> void:
	play_sfx(SFX_BOW)
	var cr = roll_crit(int(round(special.get("damage", 8) * skill_damage_mult("wand"))))
	var aim_at := aim_world_point()
	var max_reach := float(special.get("range", 520.0))
	var to_aim := aim_at - global_position
	if to_aim.length() > max_reach:
		aim_at = global_position + to_aim.normalized() * max_reach
	var cloud = STORM_CLOUD_SCRIPT.new()
	cloud.damage = cr[0]
	cloud.radius = float(special.get("radius", 130.0))
	cloud.duration = float(special.get("dur", 4.5))
	cloud.strike_gap = float(special.get("gap", 0.4))
	cloud.tint = active_def.get("color", Color(0.55, 0.75, 1.0))
	cloud.source = self
	# TOME VERBS (attack-verb overhaul): no two tomes cast the same shape --
	# the row's tome_kind picks the zone's whole character
	var tkind := str(special.get("tome_kind", ""))
	cloud.mire_mode = tkind == "mire"
	cloud.coven_mode = tkind == "coven"
	cloud.column_mode = tkind == "column"
	cloud.lure_mode = tkind == "lure"
	cloud.tide_mode = tkind == "tide"
	cloud.flood_mode = tkind == "flood"
	cloud.facing = facing_direction
	# GRAND TOME OF RAINS: twin flanking clouds instead of one
	if tkind == "twin":
		cloud.radius *= 0.6
		cloud.damage = maxi(1, int(round(cloud.damage * 0.75)))
		var cloud2 = STORM_CLOUD_SCRIPT.new()
		cloud2.damage = cloud.damage
		cloud2.radius = cloud.radius
		cloud2.duration = cloud.duration
		cloud2.strike_gap = cloud.strike_gap
		cloud2.tint = cloud.tint
		cloud2.source = self
		get_parent().add_child(cloud2)
		cloud2.global_position = aim_at + Vector2(cloud.radius * 1.4, 0)
		aim_at += Vector2(-cloud.radius * 1.4, 0)
	# What the Sky Charges: this storm WALKS toward prey -- and every strike
	# now also drops a FLARE out of the dark (tome batch 3, Lunar-Flare kin)
	cloud.drift = str(special.get("rider", "")) == "walker"
	cloud.flare_strikes = cloud.drift
	get_parent().add_child(cloud)
	cloud.global_position = aim_at

# THE SENTRY (behavior library 2026-07-28): plant ONE watching totem at your
# feet. Planting again moves it -- the mage borrows a single post, never an
# army (armies are the Monarch's).
const SENTRY_TOTEM_SCRIPT = preload("res://sentry_totem.gd")
func plant_sentry(special: Dictionary) -> void:
	play_sfx(SFX_BOW)
	for old in get_tree().get_nodes_in_group("player_sentry"):
		if is_instance_valid(old):
			old.queue_free()
	var totem = SENTRY_TOTEM_SCRIPT.new()
	totem.add_to_group("player_sentry")
	totem.damage = int(round(special.get("damage", 7) * skill_damage_mult("wand")))
	totem.lifetime = float(special.get("dur", 16.0))
	totem.fire_gap = float(special.get("gap", 0.85))
	totem.tint = active_def.get("color", Color(0.55, 0.75, 1.0))
	totem.source = self
	get_parent().add_child(totem)
	totem.global_position = global_position + Vector2(0, 4)

# THE EXTENDING STAFF (Wukong line, 2026-07-28 -- inspired, never copied):
# each landed swing within the combo window LENGTHENS the staff, up to ~2.4x
# reach; the fourth strike is a PILLAR SLAM -- a short knock-up burst at the
# staff's head. Break the rhythm and the staff shrinks back to a walking
# stick. Consumed where melee reach is applied (perform_attack).
var _staff_combo := 0
var _staff_last_hit_at := -100.0
func staff_reach_mult() -> float:
	if str(active_def.get("special", {}).get("type", "")) != "staff_extend":
		return 1.0
	if _now() - _staff_last_hit_at > 1.6:
		_staff_combo = 0   # the rhythm broke; the staff remembers nothing
	# The Riddle Staff (rune): the staff answers one more question -- the
	# combo may draw it a FOURTH stage longer
	var cap := 4 if GameState.get_bonus_total("staff_mastery") > 0.0 else 3
	return 1.0 + 0.45 * float(mini(_staff_combo, cap))

func staff_note_swing(landed: bool, at: Vector2) -> void:
	if str(active_def.get("special", {}).get("type", "")) != "staff_extend":
		return
	if not landed:
		_staff_combo = 0
		return
	_staff_last_hit_at = _now()
	_staff_combo += 1
	# with the Riddle Staff the rhythm holds one beat longer: four growing
	# stages, and the SLAM falls on the fifth
	var slam_at := 5 if GameState.get_bonus_total("staff_mastery") > 0.0 else 4
	if _staff_combo >= slam_at:
		_staff_combo = 0
		# PILLAR SLAM: the head of the fully-drawn staff strikes the earth
		# (the Riddle Staff rune deepens the slam by a quarter)
		SfxSynth.play_at(self, at, "thump", -8.0, 0.8)   # deeper than the pillar's
		var slam_mult := 0.8 * (1.25 if GameState.get_bonus_total("staff_mastery") > 0.0 else 1.0)
		var slam_dmg := int(round(active_stats.damage * slam_mult * skill_damage_mult("melee")))
		for group_name in ["course_enemy", "dungeon_combatant", "siege_enemy"]:
			for e in get_tree().get_nodes_in_group(group_name):
				if not is_instance_valid(e) or not e.has_method("take_damage"):
					continue
				if "is_dead" in e and e.is_dead:
					continue
				if at.distance_to(e.global_position) <= 110.0:
					e.take_damage(slam_dmg)
					FloatingText.spawn(get_parent(), e.global_position, slam_dmg, false)
					if e.has_method("apply_knockback"):
						e.apply_knockback(1 if e.global_position.x >= at.x else -1, 160.0)
		# the slam reads: a ground-crack ring at the strike point
		var ring := Line2D.new()
		var pts := PackedVector2Array()
		for i in range(15):
			var a := TAU * float(i) / 14.0
			pts.append(Vector2(cos(a), sin(a) * 0.4) * 46.0)
		ring.points = pts
		ring.width = 3.0
		ring.default_color = Color(1.0, 0.85, 0.4, 0.9)
		ring.z_index = 44
		get_parent().add_child(ring)
		ring.global_position = at
		var t := ring.create_tween()
		t.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.25)
		t.parallel().tween_property(ring, "modulate:a", 0.0, 0.25)
		t.tween_callback(ring.queue_free)

# Echo Rift: counts strikes so every 3rd one repeats its damage.
# what the current swing connected with, so the swing's charge tick can land its
# payload there (null + 0 on a miss)
var _last_swing_target: Node2D = null
var _last_swing_damage: int = 0
var echo_hit_counter: int = 0
# Ragnarok Blade: counts strikes so every Nth one erupts.
var ragnarok_charge: int = 0
# Singularity Edge: counts strikes so every Nth one collapses a black hole.
var singularity_counter: int = 0

# --- Relic powers (triggered mechanics on equipped relics; see inventory.gd
# relic_power). Cooldown-gated ones track their next-ready time. ---
var phoenix_ready_at := 0.0   # Phoenix Heart: revive off cooldown
var aegis_ready_at := 0.0     # Aegis Ward: shield off cooldown
var gorgon_ready_at := 0.0    # Gorgon's Gaze: petrify-on-hit off cooldown
const PHOENIX_COOLDOWN = 45.0
const AEGIS_COOLDOWN = 6.0
const GORGON_COOLDOWN = 13.0  # long CD -- one big petrify, not a chain

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# Is a relic granting `power` currently equipped?
func has_relic_power(power: String) -> bool:
	for id in GameState.get_equipped_item_ids():
		var def = Inventory.get_item_def(id)
		if def.get("relic_power", "") == power:
			return true
		# combined relics (Ankh-kin 2026-07-29) fold several powers into one
		# item and carry them as "relic_powers" (plural)
		if power in def.get("relic_powers", []):
			return true
	return false

# The relic_value of the first equipped relic with `power` (else `fallback`).
func relic_power_value(power: String, fallback: float) -> float:
	for id in GameState.get_equipped_item_ids():
		var def = Inventory.get_item_def(id)
		if def.get("relic_power", "") == power or power in def.get("relic_powers", []):
			return def.get("relic_value", fallback)
	return fallback

# --- Relic power effects (see has_relic_power) ---

# Vampire Lord's Signet: heal a share of melee damage dealt this swing.
# --- Sage: the channelled beam (skill tree mg_s4b "Focusing Lens") ---
# Hold attack with a wand and instead of firing discrete bolts you pour out a
# continuous beam. Its damage RAMPS the longer it stays connected to the same
# target; moving your feet, or letting anything break line of sight, cuts the
# channel and the ramp falls back to the floor. That's the Sage's trade: stand
# still in the open (where everything can hit you) and your damage compounds.
const BEAM_RANGE = 520.0
const BEAM_RAMP_TIME = 3.0      # seconds of unbroken contact to reach the peak
const BEAM_BASE_PEAK = 2.5      # 1.0x -> 2.5x before any skill bonuses
const BEAM_TICK = 0.15          # how often the beam applies damage
var beam_connect_time := 0.0    # unbroken seconds on target -- drives the ramp
var beam_tick_timer := 0.0
var beam_line: Line2D = null

func has_beam() -> bool:
	return GameState.get_skill_total("beam_channel") > 0.0

func beam_peak_mult() -> float:
	return BEAM_BASE_PEAK + GameState.get_skill_total("beam_ramp")

# The ramp is a pure function of contact time, so it's directly testable.
func beam_ramp_mult() -> float:
	return lerp(1.0, beam_peak_mult(), clamp(beam_connect_time / BEAM_RAMP_TIME, 0.0, 1.0))

func stop_beam() -> void:
	beam_connect_time = 0.0
	beam_tick_timer = 0.0
	if beam_line != null:
		beam_line.visible = false

func draw_beam(end_point: Vector2) -> void:
	if beam_line == null:
		beam_line = Line2D.new()
		beam_line.width = 5.0
		beam_line.z_index = 5
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		beam_line.material = mat
		add_child(beam_line)
	# brighter and fatter as the ramp climbs, so you can SEE it charging
	var t = clamp((beam_ramp_mult() - 1.0) / max(0.01, beam_peak_mult() - 1.0), 0.0, 1.0)
	beam_line.visible = true
	beam_line.width = lerp(4.0, 11.0, t)
	beam_line.default_color = Color(0.55, 0.75, 1.0).lerp(Color(1.0, 0.95, 0.6), t)
	beam_line.points = PackedVector2Array([Vector2.ZERO, to_local(end_point)])

# Returns true if the beam handled this frame's attack input (so the caller
# skips the ordinary attack).
func channel_beam(delta: float) -> bool:
	if not has_beam() or not has_weapon() or active_weapon_type != "wand":
		return false
	# A WAND WITH A JOB OF ITS OWN IS NOT A BEAM EMITTER. The Focusing Lens used
	# to swallow the left-click of EVERY wand, the Soul Split Wand included --
	# and that wand is the only thing that opens the Monarch's mortal window, so
	# a Sage who took the keystone could never finish the game (the finale boss
	# resets to 1 HP on every killing blow). The screen-wipes are the same story:
	# their whole cast is the payload, not a sustained ray. Those wands keep
	# their own attack; every ordinary wand still channels.
	var sp: Dictionary = active_def.get("special", {})
	var st := str(sp.get("type", ""))
	if st == "soul_split" or st == "nuke" or st == "percent_burst":
		stop_beam()
		return false
	var stats = active_stats
	# planting your feet is the cost -- any movement cuts the channel
	if absf(velocity.x) > 1.0 or not is_on_floor():
		stop_beam()
		return true
	var dir = get_aim_direction()
	var space = get_world_2d().direct_space_state
	var q = PhysicsRayQueryParameters2D.create(global_position, global_position + dir * BEAM_RANGE)
	q.collision_mask = 1 | 4        # walls break line of sight; enemies are layer 4
	q.exclude = [self]
	var hit = space.intersect_ray(q)
	var end_point = global_position + dir * BEAM_RANGE
	var target: Node = null
	if hit:
		end_point = hit.position
		var c = hit.collider
		if c != null and c.has_method("take_damage") and "is_dead" in c and not c.is_dead:
			target = c
	draw_beam(end_point)
	if target == null:
		beam_connect_time = 0.0     # contact lost: the ramp resets
		beam_tick_timer = 0.0
		return true
	beam_connect_time += delta
	# mana drains continuously: the wand's per-shot cost spread over its fire rate
	var drain = float(active_def.get("mana_cost", 0)) / maxf(0.1, stats.cooldown) * delta
	if drain > 0.0 and not spend_mana(drain):
		stop_beam()
		return true
	beam_tick_timer += delta
	while beam_tick_timer >= BEAM_TICK:
		beam_tick_timer -= BEAM_TICK
		# at ramp 1.0 the beam matches the wand's ordinary DPS; the ramp is the gain.
		# Wand damage lives in special.damage (weapon_stats.damage is 0 on every
		# special wand) -- the previous "fix" read a top-level active_def.damage
		# key that NO weapon def has, so the fallback was still weapon_stats' 0
		# and the beam dealt a flat 1/tick at full mana cost, silently replacing
		# the wand's real attack. Pull from the same place cast_wand_projectile
		# does, with plain-stats wands (no special) falling back to stats.damage.
		var wand_dmg := float(active_def.get("special", {}).get("damage", 0.0))
		if wand_dmg <= 0.0:
			wand_dmg = float(stats.damage)
		var dps = wand_dmg / maxf(0.1, stats.cooldown)
		var amount = maxi(1, int(round(dps * BEAM_TICK * beam_ramp_mult() * skill_damage_mult("wand"))))
		var cr = roll_crit(amount)
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(cr[0])
			show_hit(target, cr[0], cr[1])
			apply_omnivamp(cr[0])
			apply_soulthread(cr[0])   # Runeweave set-soul: the beam threads life
	return true

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
	# The Kindly End: every poisoned foe it strikes gives one HP back --
	# a mercy that flows the wrong way
	if str(active_def.get("special", {}).get("rider", "")) == "kindly" and dealt > 0 \
			and "status_poison_until" in target \
			and float(target.status_poison_until) > Time.get_ticks_msec() / 1000.0:
		health = min(get_max_health(), health + 1)
		update_health_display()
	if target.has_method("apply_status"):
		var b = GameState.get_bonus_total("on_hit_burn")
		if b > 0.0: target.apply_status("burn", 3.0, b)
		var po = GameState.get_bonus_total("on_hit_poison")
		if po > 0.0: target.apply_status("poison", 4.0, po)
		if GameState.get_bonus_total("on_hit_slow") > 0.0: target.apply_status("slow", 2.5, 0.6)
		# the WEAPON's own rider (roster wave 2): a blade that burns or chills
		# carries its status in its special dict, landing with every blow
		var wst: Dictionary = active_def.get("special", {}).get("status", {})
		if not wst.is_empty():
			target.apply_status(str(wst.get("kind", "burn")),
				float(wst.get("dur", 3.0)), float(wst.get("mag", 4.0)))
	# Gorgon's Gaze: a long-cooldown PETRIFY on hit -- the struck foe turns to
	# stone (and takes bonus damage while stoned). Apex/undying bosses resist, so
	# the cooldown is only spent when it actually LANDS.
	if has_relic_power("petrify") and _now() >= gorgon_ready_at and dealt > 0:
		var dur = relic_power_value("petrify", 3.0)
		var landed = false
		if "boss_id" in target and target.has_method("apply_petrify"):
			landed = target.apply_petrify(dur)
		elif target.has_method("apply_status"):
			target.apply_status("petrify", dur, 0.0)
			landed = true
		if landed:
			gorgon_ready_at = _now() + GORGON_COOLDOWN
			spawn_shock_ring(target.global_position, 60.0, Color(0.6, 0.6, 0.62, 0.9))
	# THE WEAPON'S OWN SOUL (WeaponFx, 2026-07-28): every landed blow runs
	# the wielded weapon's unique fx -- the ladder's uniqueness engine
	WeaponFx.on_hit(self, target, dealt, last_hit_was_crit)
	# element impact burst (VFX pass): the blow pops in the weapon's colour
	if target is Node2D:
		HitFx.burst(get_parent(), (target as Node2D).global_position,
			Inventory.element_of(active_weapon_id), last_hit_was_crit)
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
# Guards against a unique that launches a projectile whose hit re-triggers the
# same unique, which would launch another projectile, forever.
var _in_projectile_unique := false

# Where a charged payload should land: on whatever you hit, or -- if the swing
# caught nothing but air -- out at the weapon's reach along your aim.
func _unique_impact_point(target: Node2D) -> Vector2:
	if is_instance_valid(target):
		return target.global_position
	var reach: float = float(active_stats.get("range_offset", 50)) + 40.0
	return global_position + get_aim_direction() * reach

# A weapon's SLASH (or any projectile it throws) carries its owner's signature.
# Previously a unique only fired when the blade itself connected, so a weapon
# whose whole identity is reaching out was strictly worse at the range it was
# built for. Now a crescent that lands is a hit like any other.
func on_projectile_hit(target: Node2D, damage_dealt: int) -> void:
	if _in_projectile_unique or not has_weapon():
		return
	_in_projectile_unique = true
	apply_excellent_effect(target, damage_dealt)
	apply_melee_skills(target, damage_dealt)
	apply_soulthread(damage_dealt)   # Runeweave set-soul: wand damage -> life
	_in_projectile_unique = false

# Charge-style uniques wind up on every SWING, hit or miss. Whiffing still
# counts: what matters is how many times you have swung, so a charged payload
# can never be denied by a boss stepping out of range on exactly the wrong
# frame. When the charge completes it fires wherever you were aiming.
func advance_swing_charge(target: Node2D = null, damage_dealt: int = 0) -> void:
	if not has_weapon():
		return
	var effect := str(active_def.get("unique_effect", ""))
	match effect:
		"ragnarok":
			ragnarok_charge += 1
			if ragnarok_charge >= int(active_def.get("unique_value", 8)):
				ragnarok_charge = 0
				unleash_ragnarok()
		"singularity":
			singularity_counter += 1
			if singularity_counter % maxi(1, int(active_def.get("unique_value", 5))) == 0:
				collapse_singularity(_unique_impact_point(target),
					active_def.get("unique_radius", 320.0),
					damage_dealt if damage_dealt > 0 else int(active_stats.get("damage", 10)))
		"echo":
			echo_hit_counter += 1
			if echo_hit_counter % 3 == 0:
				var at := _unique_impact_point(target)
				var extra := int(round(float(damage_dealt if damage_dealt > 0 else int(active_stats.get("damage", 10)))
					* float(active_def.get("unique_value", 1.0))))
				if is_instance_valid(target) and target.has_method("take_damage"):
					target.take_damage(extra)
				spawn_echo_ring(at)

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
		return   # charge-driven: see advance_swing_charge
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
		# the storm is stoked by SWINGING (see advance_swing_charge), not by
		# connecting -- landing a blow only adds the extra slash
		if not _in_projectile_unique:
			launch_projectile({"type": "flying_slash", "speed": 560.0, "range": 470.0}, get_aim_direction(), 14)
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
		return   # charge-driven: see advance_swing_charge
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
		# Dawnbreaker -- heal on hit + a piercing sun-slash. The slash must NOT re-spawn
		# from its OWN hits, or each pierced enemy launches another and it cascades into
		# an exponential flood of slashes + heals. Guard mirrors ragnarok's above.
		var heal = int(round(damage_dealt * active_def.get("unique_value", 0.2)))
		if heal > 0:
			health = min(get_max_health(), health + heal)
			update_health_display()
		if not _in_projectile_unique:
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
	# A Choir of One: every SEVENTH shot the whole choir answers -- a free
	# three-arrow fan on top of the single voice
	if str(special.get("rider", "")) == "choir":
		_choir_shots += 1
		if _choir_shots >= 7:
			_choir_shots = 0
			count = maxi(count, 3)
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
	# a bow AUTHORED to pierce (roster wave 2: Veilpiercer and kin) punches
	# through a couple of bodies on its own, stacking with the tree's pierce
	if bool(special.get("pierce", false)):
		pierce_count += 2
	# ...and a bow's own status rider (a chilling string, a venomed nock)
	# joins the tree-granted ones on every shaft
	var wst: Dictionary = special.get("status", {})
	if not wst.is_empty():
		arrow_statuses.append({"kind": str(wst.get("kind", "burn")),
			"dur": float(wst.get("dur", 3.0)), "mag": float(wst.get("mag", 4.0))})
	var spreads_poison = GameState.get_bonus_total("poison_spread") > 0.0
	var spread = deg_to_rad(float(special.get("spread_deg", 0.0)))
	# skill-granted multishot on a PLAIN bow (no authored spread) used to spawn
	# every arrow at the identical position/direction/speed -- permanent
	# lockstep, one invisible fat arrow into one target. The whole Ranger spec
	# silently degraded to a single-target multiplier. Default the fan so
	# Twin Shot / Arrow Storm / Tempest visibly fan on any bow.
	if count > 1 and spread <= 0.0:
		spread = deg_to_rad(4.0 * float(count - 1))
	for i in range(count):
		var dir = aim_dir
		if count > 1:
			dir = aim_dir.rotated(lerp(-spread, spread, float(i) / float(count - 1)))
		var arrow = ARROW_SCENE.instantiate()
		# loose from the held bow rather than from the middle of his body
		arrow.position = global_position + dir * (stats.icon_offset + 8.0)
		# DEADEYE (Windstalker set-soul): a primed stillness makes this whole
		# volley CERTAIN -- every shaft of it flies as a crit
		var cr = force_crit(int(round(stats.damage * skill_damage_mult("bow")))) \
			if _deadeye_primed else roll_crit(int(round(stats.damage * skill_damage_mult("bow"))))
		arrow.setup(dir, cr[0], stats.knockback_min, stats.knockback_max, 4)
		arrow.is_crit = cr[1]
		arrow.homing = homing
		arrow.enemy_statuses = arrow_statuses
		arrow.execute_threshold = GameState.get_bonus_total("execute_threshold")   # Killshot
		arrow.execute_heal = GameState.get_bonus_total("execute_heal")             # Headhunter
		arrow.pierce_count = pierce_count
		arrow.poison_spread = spreads_poison
		# grade presence: a heavier shaft that carries further (set BEFORE
		# add_child so the arrow's _ready applies it)
		arrow.girth = grade_projectile_girth()
		arrow.max_range = arrow.DEFAULT_MAX_RANGE * grade_projectile_range()
		arrow.element = Inventory.element_of(active_weapon_id)   # VFX: hit bursts in the bow's colour
		get_parent().add_child(arrow)
	# loosing SPENDS the Deadeye prime; the next certainty is earned by
	# another breath of stillness
	if _deadeye_primed:
		_deadeye_primed = false
		_deadeye_t = 0.0

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
