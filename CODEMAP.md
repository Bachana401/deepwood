# Deepwood — Codemap

_Navigation index for fast lookup. Regenerate with `bash gen_codemap.sh`. Line numbers drift as code changes — treat as approximate anchors, confirm with a read._

`126` game scripts, ~78499 LOC. Generated 2026-07-31.

## File directory

| script | lines | purpose (first header comment) |
|--------|------:|--------------------------------|
| admin_panel.gd | 408 | One-stop dev/testing console, toggled with P. Every "OP" testing action lives |
| adventurer.gd | 756 | A living adventurer defending Deepwood (GAME_BIBLE 2.4.1). Persistent between |
| adventurer_rescue.gd | 72 | A chained adventurer awaiting rescue in the dungeon (the deep nine of |
| adventurers.gd | 100 | The twelve adventurers (GAME_BIBLE §2.4.1 "The three defenders" + the deep |
| arrival_weather.gd | 59 | THE ARRIVAL STORM (start-scene fix, 2026-07-21). The dev's canon asked for |
| arrow.gd | 498 | (no header comment) |
| assign_ui.gd | 944 | (no header comment) |
| blueprint_pickup.gd | 57 | A BLUEPRINT SATCHEL (GAME_BIBLE 5.2): the plans for one village building, |
| bond_mark.gd | 142 | THE BOND-MARK (Summoner, batch 1 — 2026-07-30). |
| boss.gd | 5095 | Dungeon boss. |
| boss_hud.gd | 192 | WUKONG-STYLE BOSS SPECTACLE (dev ask 2026-07-22). Makes every boss an EVENT: |
| build_menu.gd | 260 | THE BUILDER'S LEDGER (B key; dev request 2026-07-21). |
| build_placer.gd | 448 | THE BUILDER'S HAND (dev 2026-07-22). Raise a building from the B menu with a |
| building.gd | 2230 | (no header comment) |
| building_hitbox.gd | 15 | Buildings are Area2D nodes (for the Press-E proximity), which enemy arrows |
| building_lights.gd | 317 | Breathes life into the painted facades WITHOUT touching the approved art: |
| building_roles.gd | 116 | Role definitions per building (keyed by the building's role_key, e.g. |
| camera_shake.gd | 22 | (no header comment) |
| char_shadow.gd | 44 | Preloaded as a const by its users (const CHAR_SHADOW = preload(...)) rather than |
| chest.gd | 44 | Unique per-instance id, used as the key into GameState.chest_contents so |
| chest_ui.gd | 319 | The vault racks now hold a GRADE'S whole catalogue (76 rare items after the |
| choice_prompt.gd | 148 | A small modal decision box, styled like the DialogueBox: a title, a body line, |
| companion.gd | 830 | COMPANIONS (task: light summoner, 2026-07-29). No fourth class: a companion |
| currency_pickup.gd | 320 | "1 full in-game day" is defined by the day/night cycle's own day length, |
| day_night_cycle.gd | 514 | (no header comment) |
| death_screen.gd | 76 | main.tscn and dungeon_interior.tscn author the black shade + CountdownLabel by |
| dialogue_box.gd | 409 | A small, reusable conversation box (bottom of screen): a brass name-plate, one |
| dock_bridge.gd | 71 | A walkable wooden crossing spanning the Fishing Dock's water: stairs up, a |
| dps_dummy.gd | 89 | The Proving Grounds training dummy: an invincible target that never dies and |
| drag_state.gd | 277 | Coordinates dragging an item stack between slots -- possibly across two |
| dungeon_gate.gd | 106 | The LEAVE gate on the left of every dungeon floor (see dungeon_interior.gd). |
| dungeon_interior.gd | 2776 | Dungeons are a real separate scene the player is teleported into (see |
| dungeon_manager.gd | 18 | Dungeon combat now happens in a fully separate scene (dungeon_interior.gd) |
| dungeon_sign.gd | 50 | (no header comment) |
| dungeon_zone.gd | 24 | (no header comment) |
| embedded_stack.gd | 318 | EMBEDDED STACKS (weapon overhaul, 2026-07-29) -- the "aftermath" system for |
| enemy.gd | 2012 | Dev call 2026-07-21: sight cut 15% (was 225) -- "I don't want them to non |
| enemy_skins.gd | 200 | Shared skin builder for downloaded/generated character art. Originally for |
| equipment_ui.gd | 490 | Equipment panel, pinned to the RIGHT side of the screen (kept clear of the |
| event_boss.gd | 205 | HIDDEN EVENT BOSSES (2026-07-28). Ten secret bosses, woken by the player |
| event_boss_director.gd | 90 | HIDDEN EVENT-BOSS DIRECTOR (2026-07-28). Mounted into whatever scene the |
| farm_animal.gd | 221 | A small BLOCKY, pixel-styled farm animal (chicken / pig / cow / sheep) that |
| farm_pen.gd | 74 | A fenced pasture beside the Farm. Draws the fence + a dirt patch and spawns a |
| fish_water.gd | 23 | FISHING (pillar 3): a stretch of fishable water. The Dock's pond needs no |
| fishing.gd | 101 | (renewability pillar 3, dev-chosen 2026-07-28: the FULL loop, reforging |
| floating_text.gd | 75 | Shared floating combat text -- a damage number that rises, drifts, and fades |
| food_readout.gd | 99 | Always-visible village food gauge, top-left HUD, tucked just under the mana |
| game_state.gd | 7246 | THE DEV'S REAL SAVE IS NOT A TEST FIXTURE (global hunt 2026-07-28). |
| harvest_director.gd | 402 | THE HARVEST, AT HOME (new finale canon, 2026-07-20). |
| harvest_node.gd | 323 | A harvestable world node: a TREE (chop with the Woodsman's Axe) or a ROCK |
| hazard.gd | 308 | CREATIVE DUNGEON HAZARDS (dev report 2026-07-21: "no creative traps"). Beyond |
| hazard_zone.gd | 81 | A lingering ground hazard dropped by a boss signature ability and then left to |
| hit_fx.gd | 67 | ELEMENT IMPACT BURSTS (item-art VFX pass 2026-07-28, Terraria-hit-spark |
| homing_bolt.gd | 45 | A slow homing projectile — the Mourncaller's Keening wisps, and reusable for |
| hotbar_ui.gd | 86 | Bottom-of-screen hotbar showing the first 10 inventory slots (keys 1-9, 0). |
| house.gd | 168 | (no header comment) |
| how_to_play.gd | 117 | HOW TO PLAY -- the controls and the laws, one readable page, opened from |
| hud_orb.gd | 48 | MU Online / Diablo style liquid globe for HP or mana (dev ask 2026-07-22). |
| inventory.gd | 2326 | Shared item catalog -- every item type in the game (currency included) is |
| inventory_ui.gd | 352 | Terraria-tight pixel slots (dev ask 2026-07-22): a compact grid of bordered |
| item_tooltip.gd | 100 | A single hover tooltip shared by every item UI (inventory, chest, equipment |
| level_select_ui.gd | 121 | (no header comment) |
| magic_orb.gd | 103 | A slow homing "cursed orb" fired by the Warlock mob (special_mob.gd). It |
| main.gd | 1921 | (no header comment) |
| main_menu.gd | 189 | Whether the fresh-start flow currently in the difficulty picker should wipe |
| material_pickup.gd | 100 | A dropped material on the ground (dev ask 2026-07-22: "materials like in |
| mirror_mage.gd | 113 | THE PLUCKED HAIR (Wukong roads, 2026-07-28): when enemies press the Sage, |
| monarch_name_fx.gd | 30 | THE MONARCH NAME CYCLE (2026-07-30, dev reference clip: Terraria's Rainbow |
| morale_meter.gd | 181 | Village morale, shown in the TAB overlay directly BELOW the mana bar (kept |
| notification_stack.gd | 32 | Toasts render as BBCode (item-art name-plate pass 2026-07-28): callers can |
| npc.gd | 1392 | Points back at their entry in GameState.rescued_villagers -- info is |
| objective_banner.gd | 97 | A quiet, always-current objective ticker at the top of the VILLAGE screen, so a |
| pause_menu.gd | 262 | (no header comment) |
| player.gd | 8593 | DEV CALL (2026-07-20): the old dash covered 600*0.15 = 90px -- barely |
| playtest_journal.gd | 124 | THE FIELD JOURNAL (built for the 4-5h marathon playtest, 2026-07-21). |
| portal.gd | 74 | ONE RIFT of the Mage's Riftweaving pair (mg_p1..p3, dev request |
| road_marker.gd | 77 | THE ROAD MARKERS (polish 2026-07-20) -- the village and the pit sit |
| roster_ui.gd | 184 | THE ROSTER (polish 2026-07-20) -- every soul in Deepwood on one page. |
| sentry_totem.gd | 100 | THE PLANTED SENTRY (weapons overhaul 2026-07-28, Terraria-sentry-INSPIRED): |
| sfx_synth.gd | 136 | PROCEDURAL CHIPTUNE ONE-SHOTS (audio pass 2026-07-28): the overhaul's |
| shade.gd | 391 | A shade -- a soldier of living shadow in the Shadow Monarch's service |
| shop_ui.gd | 197 | (no header comment) |
| shrine_menu.gd | 150 | The fast-travel menu shared by the village WAYSTONE and every woken DEEP SHRINE |
| shrine_node.gd | 160 | A travel shrine. The village WAYSTONE (is_waystone = true) and every woken DEEP |
| siege_enemy.gd | 620 | A besieger: marches east out of the evil lands toward the village wall and |
| siege_manager.gd | 420 | Presents LIVE sieges while the player is in the village. Scheduling and |
| skill_tree.gd | 305 | Each class is ONE tree that actually BRANCHES. A root trunk splits into 3 |
| skill_tree_ui.gd | 508 | Skill tree window (K to toggle) + the always-visible XP bar. Everything is |
| speaker_indicator.gd | 65 | A small bobbing chevron that hovers over whoever is currently speaking in a |
| special_mob.gd | 2102 | Special dungeon mobs -- the non-humanoid monsters that spice up NORMAL |
| special_plot.gd | 92 | A SPECIAL PLOT marker (roadmap Phase 3): the ground itself, drawn. |
| speech_text.gd | 70 | Floating, window-less speech for characters: plain outlined text hovering |
| standing_torch.gd | 117 | A big free-standing brazier torch the player can PLACE anywhere on the ground |
| storm_cloud.gd | 385 | TOME AREA DENIAL (weapons overhaul 2026-07-28, Terraria-spellbook-INSPIRED, |
| story.gd | 183 | Deepwood's scripted story beats, kept in one place (canon: GAME_BIBLE §2/§9, |
| summon_post.gd | 410 | SUMMONER POSTS (batch 1 — 2026-07-30). |
| ten_ally.gd | 298 | One of the Ten, fighting beside you at the Harvest (GAME_BIBLE 9.4) -- ten |
| the_ten.gd | 61 | THE TEN (GAME_BIBLE §8) -- the capstone hostages, the truly unbreakable. |
| training_arena.gd | 238 | THE PROVING GROUND (dev, 2026-07-30). |
| trap.gd | 88 | (no header comment) |
| trophy_vault.gd | 97 | A Trophy Vault (GAME_BIBLE §8): the gilded cage where Orin keeps one of the |
| tutorial_overlay.gd | 94 | THE INTERACTIVE TUTORIAL CARD (dev 2026-07-22: "show, don't tell"). Instead of a |
| underdark.gd | 1343 | THE UNDERDARK (GAME_BIBLE §4 amendment, dev-decided 2026-07-21). |
| underdark_ambush.gd | 25 | A hidden ambush in a sunken chamber of the deep (underdark.gd _build_pits). |
| underdark_door.gd | 157 | A hidden stone door of the Underdark (GAME_BIBLE §4 amendment). Each one is |
| underdark_rune.gd | 71 | One of three rune stones that unbar a band's vault (underdark.gd). Press E. |
| underground.gd | 4692 | ── THE TERRARIA UNDERGROUND (rework, 2026-07-25) ────────────� |
| underground_pause.gd | 118 | THE CAVE'S PAUSE MENU (scan fix 2026-07-27). |
| vault_chest.gd | 134 | A Proving Grounds vault chest. Unlike a normal loot chest it's a bottomless |
| village_life.gd | 435 | Makes Deepwood feel ALIVE, and rewards the player's progress with spectacle. |
| village_log_ui.gd | 122 | THE VILLAGE LOG (GAME_BIBLE 5.9) -- press L. The village's diary: births, |
| villager.gd | 234 | Unique per-instance id so an already-rescued villager doesn't reappear (and |
| villager_menu.gd | 160 | THE VILLAGER MENU (dev ask 2026-07-27): walk up to a villager, RIGHT-CLICK, and |
| villager_quests.gd | 261 | Two things live here: |
| villager_sheet.gd | 162 | THE VILLAGER SHEET (dev call 2026-07-27). The old way of reading a villager was |
| wall.gd | 385 | The village's west rampart -- the line the siege breaks against. It has no |
| wanderer_ui.gd | 119 | THE WANDERER'S POST counter (GAME_BIBLE 5.6a) -- opened with the hands-on |
| watchtower.gd | 148 | THE WATCHTOWER (GAME_BIBLE 7.1) -- foresight, earned. A standalone |
| weapon_arena.gd | 243 | THE ARENA, AS ITS OWN SCENE (dev, 2026-07-30: "you have bad arena btw. bad |
| weapon_fx.gd | 464 | (dev order 2026-07-28: "all weapons skills and effects and aftereffects |
| weapon_projectile.gd | 11215 | One configurable projectile powering the special-attack weapons (see |
| weapon_roster.gd | 2004 | The 350-weapon roster's engine (weapons overhaul wave 2, 2026-07-28). |
| wilderness.gd | 231 | THE EAST ROAD (2026-07-21, dev request). |
| wizard.gd | 886 | ORIN, the stranded village mage. Lore: an adventurer like the player who |
| worker_figure.gd | 373 | A villager-at-work figure, spawned by building.gd when villagers are employed |
| world_map.gd | 214 | ── THE FULL MAP, EVERYWHERE (M) ────────────────── |

## Big-file outlines (sections + functions, with line numbers)

Jump anchors for the files too large to grep comfortably. `#` = section header, `»` = function.

### game_state.gd (7246 lines)
```
11     » active_save_path
37     » floor_is_cleared
40     » mark_floor_cleared
64     » is_shrine_floor
67     » shrine_revealed
70     » revealed_shrines
91     » load_game_completed
94     » mark_game_completed
103    # DEV / TEST MODE
129    # Harvest-node persistence (audit fix)
144    » ensure_harvest_seed
157    » test_populate_village
216    # XP / skill tree
240    # Equipment
281    » relic_slot_count
287    » get_equipment_total
295    » item_equip_effect
303    » get_weapon_passive_total
311    » get_bonus_total
327    » found_bonus
332    » get_equipped_item_ids
342    » set_pieces_equipped
351    » is_set_complete
358    » wielded_weapon_id
366    » get_set_bonus_total
385    » equip_item
413    » unequip_slot
438    » first_empty_relic_slot
446    » load_equipment
468    » xp_to_next_level
481    » depth_reward_mult
488    » add_xp
521    # The Shadow Monarch (hidden 7-stage passive, tied to character level)
541    » monarch_stage
550    » monarch_progress
559    » monarch_intensity
564    » monarch_bonus
587    » announce_monarch_awakening
604    » monarch_true_form
613    » get_skill_total
620    » is_skill_unlocked
627    » try_unlock_skill
658    » try_craft
684    » research_all_materials
692    » reset_skills
703    » capture_player_state
769    # Adventurers (GAME_BIBLE 2.4.1)
777    » ensure_adventurers
788    » adventurer_state
792    » rescue_adventurer
802    » kill_adventurer
811    » set_adventurer_station
827    » wall_stationed_count
838    » fighting_adventurers
856    # THE GOLD FAUCETS (GAME_BIBLE 5.6, revised canon 2026-07-17)
877    # Leader bonuses
909    # Master in-game clock
927    » time_of_day
930    » village_darkness
941    » torches_lit
944    # Village siege state (autoload-owned so assaults resolve while the player
982    # Village mage (Orin) downed/respawn state
997    # Construction-material drops (the repair economy)
1004   » _has_inventory
1007   » roll_construction_drop
1019   » grant_construction_bundle
1033   » wizard_is_down
1038   » wizard_down_progress
1044   » mark_wizard_down
1047   » clear_wizard_down
1074   » building_clear_progress
1077   » building_is_cleared
1087   » blacksmith_unlocked
1092   » building_build_stage
1107   » restore_all_buildings
1124   » building_level
1127   # BUILDING POWERS (dev law 2026-07-29)
1155   # LEADER POWERS (dev law 2026-07-29)
1171   » has_leader_power
1181   » _sounding_material
1196   » has_building_power
1201   » building_power_name
1206   # ADJACENCY SYNERGY
1229   # AURAS (roadmap Phase 4)
1263   » villager_places
1283   » in_aura
1296   » aura_reach
1305   # SPECIAL PLOTS (roadmap Phase 3)
1353   » plot_for_building
1360   » plot_at
1370   » building_plot
1374   » on_home_plot
1378   » plot_bonus
1383   # DISTRICTS (roadmap Phase 2)
1422   » district_at
1441   » building_district
1445   » in_home_district
1449   » district_bonus
1465   » refresh_layout
1500   » adjacency_links
1517   » adjacency_bonus
1526   » building_output_multiplier
1530   # DELETED BUILDINGS (dev 2026-07-22 building menu: "player can delete these
1536   » building_removed
1539   » remove_building
1563   » restore_building
1572   » remove_cottage
1613   » register_cottage
1623   » cottage_id_at
1629   » remove_placed_wall
1641   # RAISING BUILDINGS FROM THE MENU (dev 2026-07-22: build from B with a holo)
1652   » build_cost
1665   » can_afford_build
1673   » pay_build
1703   » can_place_building
1770   # THE OPENING TUTORIAL (step-gated, dev polish 2026-07-22)
1785   » tutorial_begin
1803   » tutorial_note
1818   # THE RAMPART (dev ask 2026-07-22: "make WALLS bigger... with gate,
1840   » wall_max_health
1847   » wall_defense_bonus
1850   » wall_trap_dps
1853   » wall_station_capacity
1857   » wall_upgrade_cost
1862   » can_afford_wall_upgrade
1873   » try_upgrade_wall
1916   » _mint_birth_id
1920   # THE VILLAGE LOG (GAME_BIBLE 5.9)
1933   » log_event
1944   # HOUSING (GAME_BIBLE 5.8)
1982   » villager_name
1988   » villager_home_id
1997   » kid_is_housed
2021   » _couple_expecting
2027   » update_cottage_families
2084   » effective_roll_weights
2099   » roll_regular_stat
2115   » _ready
2128   # Audio: a "Master" (Volume) bus and a dedicated "Music" bus routed into it,
2135   » setup_audio
2149   » apply_master_volume
2159   » apply_music_volume
2167   » set_master_volume
2172   » set_music_volume
2177   » save_audio_settings
2183   » _process
2203   » skip_hours
2206   » tick_village_clock
2243   # HIDDEN EVENT BOSSES (2026-07-28)
2258   » arm_hidden_events
2264   » note_kill
2267   » note_harvest_swing
2273   » note_gold_spent
2277   » note_floor_cleared_event
2280   » on_player_died_event
2291   » on_event_boss_killed
2305   » _event_stage_free
2317   » tick_hidden_events
2341   » _event_condition_met
2368   » _fire_event
2377   # Item-summoned events (Nihil's Duskmoon rite, the Master's Horn, and every
2381   » summon_event_boss
2404   » _spawn_summoned
2415   » _sun_moon_both_up
2421   # the capstone: a lifetime record of which hidden bosses have ever fallen
2429   » hidden_hunt_entries
2444   » hidden_hunt_slain_count
2451   » _note_capstone_kill
2467   # subtle ambient omens (no text): a faint tell as the player nears a trigger
2470   » _tick_event_omen
2483   » _event_omen_progress
2494   # Siege scheduling + resolution (runs in every scene)
2496   » current_siege_tier
2537   » deep_truly_empty
2540   » feast_ready
2557   » arrival_shield_on
2565   » begin_arrival_shield
2570   » orin_arrived
2575   » village_defense_power
2639   » warrior_count
2648   # DAY/NIGHT SHIFTS (GAME_BIBLE 7.3)
2657   » hour_of_day
2665   » warrior_shift
2668   » on_duty_shift
2672   » warrior_on_duty
2675   » on_duty_warrior_count
2684   » in_shift_change_window
2691   » tick_sieges
2728   » is_black_tide_number
2731   » next_siege_is_black_tide
2736   » tick_black_tide_omen
2746   » trigger_siege
2778   » tick_tide_table
2792   » tick_deep_catches
2817   # FISHING (renewability pillar 3, dev-chosen 2026-07-28)
2835   » fishing_quest_oddity
2838   » tick_fishing
2872   » fishing_turn_in
2893   # THE REAVER CARAVAN (renewability pillar 2, dev-chosen 2026-07-28)
2917   » caravan_tier
2920   » tick_caravans
2946   » trigger_caravan
2958   » resolve_caravan_offline
2972   » grant_reaver_cache
3000   # THE WEEPING HOUR (night event, dev-chosen 2026-07-28)
3026   » weeping_eligible
3037   » tick_weeping
3059   » start_weeping
3072   » end_weeping
3098   # THE LANTERN NIGHT (festival event, 2026-07-28)
3116   » lantern_eligible
3127   » tick_lantern
3152   » start_lantern
3174   » end_lantern
3190   » _away_line_summary
3216   » resolve_siege_offline
3293   » on_live_siege_ended
3312   » consume_away_report
3319   » is_building_operational
3327   # Food & hunger (Step 1: the hunger loop)
3367   » food_capacity
3371   » has_food
3376   » food_consumption_per_hour
3386   » farm_worker_count
3397   » food_production_per_hour
3414   » dock_worker_count
3424   » food_days_remaining
3431   » village_is_starving
3436   » manual_harvest_food
3443   # THE VILLAGE FOG (dev decision 2026-07-20): distance is ignorance
3452   » has_telepathy
3463   » has_communicator
3467   » try_build_whisperstone
3486   » _cost_text
3492   » village_presence
3500   » village_info_available
3506   » notify
3517   » tick_food
3547   # Villager needs & morale
3553   » is_villager_paired
3569   » villager_needs
3589   » villager_morale
3599   # Village-wide morale (0-100 internally, shown to the player as X/10)
3624   » count_adults
3631   # PERSONAL MORALE (GAME_BIBLE 5.5b)
3645   » personal_morale_target
3725   » get_personal_morale
3730   » tick_personal_morale
3743   » _tick_solitude_clock
3758   » village_morale
3776   » admin_nudge_morale
3780   » village_morale_10
3800   » register_villager_deaths
3827   » register_villagers_added
3833   » all_buildings_operational
3839   » update_morale_meter_unlock
3844   » village_morale_multiplier
3847   # Morale consequences (rewards & punishments)
3867   # THE FADING OF DEEPWOOD (dev ask 2026-07-22): the village dying is a felt,
3882   # CORRUPTION (GAME_BIBLE 10): despair made mechanical, v2
3914   » is_warrior_villager
3919   » tick_rot
3968   » _spread_infection
3993   » on_wall_broken
3998   » get_villager_hp
4003   » hospital_treat_rate
4009   » village_in_despair
4013   » village_despair_depth
4020   » _despair_rate
4025   » tick_morale_effects
4139   » notify_urgent
4147   » tick_village_peril
4175   » _on_village_emptied
4187   » rescue_pool_open
4203   » is_important_figure
4218   » _trigger_village_lost
4225   » _show_village_lost_screen
4269   » transform_villager_to_demon
4297   » _spawn_demon_at
4319   » morale_defense_multiplier
4324   » morale_birth_multiplier
4329   # High-morale rewards (the carrot)
4333   » morale_high_factor
4338   » morale_speed_bonus
4343   » morale_regen_per_sec
4350   » village_is_celebrating
4359   » tick_village_tribute
4368   » grant_village_tribute
4378   » count_workers
4390   » generate_passive_income
4446   # AUTOSAVE (polish 2026-07-20)
4455   » autosave
4473   # "WHAT NOW?" (polish 2026-07-20)
4479   » next_objective
4517   # ONE-SHOT SFX (polish pass 2026-07-20)
4527   » play_sfx
4550   # BLUEPRINTS (GAME_BIBLE 5.2, dev decision 2026-07-20)
4564   » has_blueprint
4571   » grant_blueprint
4580   # MOVABLE BUILDINGS (GAME_BIBLE 5.2, dev decision 2026-07-20)
4592   # THE MINE (GAME_BIBLE 5.7, decided 2026-07-20 delegated)
4600   » tick_mine_yield
4658   » tick_wood_gathering
4676   # THE SHRINE (GAME_BIBLE 10, decided 2026-07-20 delegated)
4685   » shrine_unlocked
4688   » shrine_ready
4691   » try_cleanse
4713   # THE WATCHTOWER (GAME_BIBLE 7.1, decided 2026-07-20 delegated)
4727   » watchtower_warning_hours
4731   » siege_clock_visible
4736   » tick_watchtower_warning
4754   # THE WANDERER'S POST (GAME_BIBLE 5.6a)
4803   » grade_rank
4809   » marketplace_merchant_staffed
4812   » tick_wanderers
4830   » _wanderer_dwell_hours
4836   » _wanderer_pool
4848   » _wanderer_price
4864   » _wanderer_arrive
4921   » wanderer_price_now
4930   » buy_from_wanderer
4958   » tick_wages
5018   » count_leader_holders
5025   » get_village_income_multiplier
5028   » get_gestation_speed_multiplier
5032   » get_school_graduation_speed_multiplier
5044   » get_barracks_graduation_speed_multiplier
5050   # LEADERSHIP AUTOMATION
5073   # THE SUPPLY CHAIN (City Machine pillar A, dev call 2026-07-29)
5091   » _add_to_store
5111   » research_yield_multiplier
5115   # THE DOMESTIC AUTOMATIONS (the automation ladder, dev law 2026-07-29)
5134   » donate_to_stores
5148   » free_cottage_ids
5158   » _next_cottage_x
5185   » auto_build_cottage
5213   » auto_pair_couples
5225   # THE VILLAGE TREASURY (City Machine, B-slice: "the Bank pays")
5234   # Barracks armory
5245   » arm_value_of
5249   » armed_warriors
5253   » forgemaster_supplying
5257   » deposit_one_arm
5285   » seated_leaders
5294   » apply_leadership_automation
5363   » auto_staff_villagers
5370   » try_auto_place
5396   » role_capacity
5402   » auto_research
5423   » auto_sell_surplus
5448   » auto_sell_village_surplus
5461   » auto_heal_villagers
5471   » auto_enroll_children
5505   » auto_repair_one
5544   # VILLAGE SELF-SUFFICIENCY (the time economy, dev vision 2026-07-22)
5556   » chore_domains
5598   » village_self_sufficiency
5615   » tick_self_sufficiency
5627   » find_available_parents
5648   » start_pairing
5664   » update_mating_houses
5685   » update_pregnancies
5697   » produce_child
5729   » remove_npc_avatar
5734   # School / Barracks enrollment
5736   # THE TEN (GAME_BIBLE §8)
5743   # THE HARVEST (GAME_BIBLE 9.3)
5754   # THE SHADOW COURT (GAME_BIBLE 11)
5760   » begin_harvest
5779   » raise_shadow_army
5798   » settle_shadow_court
5814   # NG+ (GAME_BIBLE 11): THE REWOUND HOUR
5844   » rewind_world_keep_player
5866   # THE CHRONICLE (GAME_BIBLE 11): the 100% ledger
5872   » chronicle
5945   » chronicle_check_complete
5956   » new_game_plus
5972   » break_the_cycle
5980   # THE FINALE GATE (GAME_BIBLE 9.1)
5985   » count_ruined_buildings
5993   » count_empty_role_slots
6008   » finale_gate_missing
6022   » finale_gate_open
6025   » ensure_the_ten
6030   » ten_freed
6034   » count_ten_freed
6042   » all_ten_freed
6045   » free_one_of_the_ten
6087   # The Doctor's escalating heal (GAME_BIBLE 5.5a)
6098   » doctor_heal_price
6101   » doctor_alive
6107   # HOSPITAL PAID HEALING (4.1 enforcement, dev-chosen 2026-07-28)
6117   » hospital_heal_available
6120   » hospital_heal_price
6125   » hospital_heal
6149   » _migrate_starting_civilians
6169   » decay_doctor_price
6179   » enroll_villager
6200   » update_school_enrollments
6215   » graduate_villager
6248   » load_deepest_level
6254   » record_level_reached
6265   » reset_for_new_game
6485   » has_save
6489   » save_game
6659   » load_game
7001   » delete_save
7007   » rescue_villager
7019   # Villager bonds (personal quests)
7024   » quest_event
7051   » find_villager_by_id
7059   » villager_quest_ready
7083   » turn_in_villager_quest
7106   » is_villager_rescued
7112   » assign_villager_to_role
7138   » remove_villager_by_id
7186   » remove_random_villager
7209   » report_death_toll
7233   » remove_one_skill_material
```

### boss.gd (5095 lines)
```
3      # 
15     # 
81     » _tick_swoop
114    » _fly_drive
125    » restlessness
134    » tick_reflex_step
160    # shared ability tuning
208    # apex ability tuning (the level 35+ monsters)
245    # the Fallen Wizard's passives & doomring
255    # SIGNATURE abilities (BOSSES.md §6): one distinct move per boss, spread
297    # deep tier signatures (floors 35-60)
326    # deep tier signatures (floors 65-90)
367    # Statuses on bosses: DoT yes, hard CC no.
384    » apply_status
411    » boss_status_slow_mult
418    » tick_statuses
455    # apex tier signatures (floors 95-100)
509    # weapon counter (set per boss level by dungeon_interior.gd)
571    # The Fallen Wizard's combo book (level 100 only)
1001   # REACTIVE MECHANICS
1006   # 
1125   # phase (Obito)
1141   » _time_now
1144   # reactive mechanic behaviours
1149   » _player_is_meleeing
1156   » _do_sidestep
1178   » _do_riposte
1201   » riposte_damage
1205   » _do_rhythm_counter
1229   » _ward_side
1252   » _hit_from_behind
1259   # ticked mechanics
1263   » tick_tether
1308   » _sight_to_player_blocked
1317   » _drop_tether
1324   » tick_famine
1336   » tick_traps
1345   » _plant_trap
1386   » tick_mirror
1404   » living_twins
1408   » tick_false_twin
1417   » _do_false_split
1446   » _build_true_shadow
1461   » living_rune_adds
1465   » tick_soulbind
1484   » _bind_runes
1513   » _update_rune_links
1524   » _clear_rune_links
1531   » _spawn_soulbind_feed
1551   » _reflect
1613   » tick_skyfall
1635   » tick_covenant
1665   # THE SOUL SPLIT (GAME_BIBLE 9.5)
1676   » is_final_monarch
1679   » in_mortal_window
1682   » on_soul_split_wand
1697   » _spawn_split_joke
1730   » stagger_threshold
1733   » _spawn_block_label
1737   » _spawn_guard_spark
1753   » is_phased
1758   » _spawn_phase_whiff
1777   » tick_phase
1788   » enter_phase
1799   » _refresh_phase_visual
1843   # wizard combo state (real wizard only; see WIZARD_COMBOS / drive_wizard)
1849   » _ready
1855   » configure_from_def
1984   » build_shard_aura
1988   » _make_shard
2013   » build_aura
2081   » process_passives
2124   » blink_short
2132   # procedural creature rigs
2145   » build_rig
2171   # Skinned bosses (PixelLab)
2174   » _build_boss_sprite
2191   » _update_boss_anim
2207   » _on_boss_anim_finished
2222   » _play_boss_ability_anim
2239   » _build_wizard_ground_aura
2278   » _rp
2286   » _rc
2293   » _rl
2303   » _rskull
2312   » rig_gravewarden
2330   » rig_frost
2342   » rig_cinder
2359   » rig_weaver
2377   » rig_stormcaller
2394   » rig_void
2408   » rig_seraph
2420   » rig_leviathan
2440   » rig_eclipse
2464   » rig_wizard
2486   » _wizard_void_face
2493   » _ember_block
2510   » get_display_name
2513   » _physics_process
2627   » process_hover
2639   » arena_width
2651   » effective_speed
2657   » choose_attack
2675   # The Fallen Wizard's active combo brain (level 100 only)
2739   » combo_length_for
2748   » is_wizard_boss
2753   » is_combo_boss
2758   » active_combos
2783   » drive_wizard
2813   » _orphan_abilities
2827   » _combat_drift
2840   » _drive_profile
2942   » combo_step_gap
2949   » combo_recovery_time
2957   » pick_combo_index
2968   » run_combo
2998   » run_ability
3049   » _combo_charge
3057   » _combo_dive
3065   » start_attack
3111   » set_cd
3114   » cooldown_mult
3129   » current_player_role
3139   » trigger_counter_mechanic
3155   # abilities
3157   » do_slam
3172   » do_charge
3185   » process_charge
3209   » do_barrage
3225   » do_nova
3239   » do_rain
3264   » do_teleport
3292   » do_summon
3326   » do_pillars
3354   # apex abilities
3358   » do_dive
3364   » process_dive
3390   » do_volley
3403   » do_meteors
3429   » do_vortex
3454   » do_beam
3495   » do_curse
3517   » do_doomring
3542   » allowed_clones
3546   » living_clones
3550   » do_clone
3581   # SIGNATURE ABILITIES (BOSSES.md §6)
3584   » spawn_hazard
3598   » _player_in
3603   » do_grave_grasp
3621   » do_rime_lance
3645   » do_magma_wake
3664   » do_web_snare
3683   » do_thunderstrike
3705   » do_void_rift
3734   » do_dissonant_scream
3760   » do_prayer_pyre
3781   » do_iron_maiden
3800   » do_pounce
3828   » do_splinter_burst
3847   » do_keening
3865   » do_ambush
3891   » do_impale
3918   » do_pincer_lunge
3948   » do_eruption
3972   » do_refraction
3998   » do_riposte_stance
4007   » _do_parry_counter
4016   » do_judgment
4044   » do_tidal_crush
4074   » do_black_sun
4094   » do_unwriting
4114   » _make_wall
4125   » _point_near_ray
4133   » _spawn_beam_line
4146   » _spawn_cone
4162   » _zone_marker
4174   # ability helpers
4176   » spawn_arrow
4187   » deal_player_damage
4199   » knockback_player_away
4207   » shake_camera
4211   » spawn_ring_telegraph
4226   » spawn_shockwave
4243   » spawn_ground_marker
4256   » erupt_pillar
4270   # combat / lifecycle
4272   » check_bump
4295   » flash_telegraph
4317   » apply_petrify
4323   » take_damage
4445   » enrage
4453   # PHASE TWO
4521   » phase_two
4539   » _apply_phase_two
4708   » tick_phase_two
4823   # phase-two helpers
4825   » _ground_y_here
4832   » _hatch_egg_later
4850   » _grief_pulse_later
4865   » _tick_eye_of_storm
4885   » _tick_one_soul
4905   » _tick_throne_alight
4926   » _tick_drowning
4948   » _mirror_the_player_kit
4963   » frenzy
4989   » apply_knockback
4992   » flash_hit
4999   » play_sfx
5006   » update_health_bar
5018   » _boss_hud_banner
5025   » die
5063   » play_death_animation
5076   » spawn_death_particles
```

### player.gd (8593 lines)
```
37     # Fall damage
54     # Flight (Aetherwing relic)
75     # Mana
157    # Aiming
170    » get_weapon_stats
173    » has_weapon
251    # FISHING (pillar 3, 2026-07-28): cast / bite / strike
355    » _ready
424    » maybe_play_intro
444    » grant_starter_weapons
458    » ensure_test_items
503    » ensure_admin_wand
516    » ensure_flight_relics_for_test
531    » grant_starter_gear
539    # worn-gear visuals (helmet / chest / pants overlays on the body)
543    » build_armor_visuals
570    » update_armor_visuals
583    » _apply_armor_piece
595    » build_weapon_guard
641    » update_weapon_sprite
670    # The Shadow Monarch aura (hidden 7-stage passive, see GameState)
683    » build_shadow_aura
758    » update_shadow_aura
828    # THE SHADOW MONARCH'S POWERS
867    » monarch_tick
906    » _apply_true_form
937    » can_raise_shades
940    » raise_shade
966    » _rebalance_shades
978    » shade_defend_share
983    » fire_shadow_nova
1006   » apply_fear_aura
1027   » enter_long_dark
1061   » build_wings_visual
1069   » _make_wing
1079   » update_wings
1096   » setup_body_anim
1120   » build_sprite_frames
1143   » load_frames_for
1159   » refresh_monarch_skin
1207   » _hooded_art_present
1211   » _ascended_art_present
1218   » load_texture
1240   » opaque_bounds
1261   » load_image_smart
1279   » _add_anim
1291   » current_anim_state
1320   » feet_anchor_y
1328   » update_body_anim
1396   » spawn_dash_afterimage
1417   » apply_pending_player_state
1444   » play_sfx
1451   » play_event_omen
1465   # combat/economy effect hooks. get_bonus_total = skill tree + worn gear
1468   » get_max_health
1472   » skill_damage_mult
1523   # Crit
1529   » get_crit_chance
1532   » get_crit_damage
1537   » roll_crit
1548   » force_crit
1552   # ARMOR SET-SOULS (2026-07-29, Terraria-kin set mechanics): a completed
1555   » set_soul_active
1560   » apply_soulthread
1571   » show_hit
1581   » spawn_hit_spark
1626   » hit_stop
1632   » _process
1649   » _exit_tree
1655   » _impact_feedback
1660   # Timed buffs (from food). active_buffs[key] = {"v": amount, "until": t}.
1663   # RIFTWEAVING (Mage, mg_p1..p3): the two doors, Z to weave
1675   » has_portal_skill
1680   » portal_open_cost
1685   » portal_drain_per_second
1690   » try_weave_portal
1713   » tick_portals
1725   » close_portals
1741   » try_plant_building
1821   » do_portal_teleport
1831   » add_buff
1836   » use_item
1923   » _open_hourglass_choice
1936   » _confirm_shatter_hourglass
1947   » buff_bonus
1956   » skill_cooldown_mult
1970   # Standing torches (G)
1976   » try_place_torch
2007   # Bar morale
2016   » bar_morale_active
2019   » grant_bar_morale
2032   # boss crowd-control on the PLAYER (set by boss signature abilities)
2047   » on_enemy_killed
2067   » apply_slow
2077   # boss crowd-control API (called by boss.gd signature abilities)
2079   » _cc_dur
2082   » apply_stun
2086   » apply_freeze
2090   » apply_root
2094   » apply_disorient
2098   » apply_poison
2109   » apply_pull
2115   » cc_action_locked
2120   » cc_move_locked
2126   » _poison_tick
2144   » clear_crowd_control
2156   » player_slow_mult
2162   » skill_move_speed_mult
2170   » on_equipment_changed
2179   # COMPANIONS (light summoner 2026-07-29): an item CARRIES its companion.
2189   » _reconcile_companions
2288   » summon_slot_budget
2292   » post_budget
2334   » _draw_whip_lash
2392   » _whip_link_colour
2404   » _whip_spark
2427   » whip_crack
2567   » _storm_off_mark
2613   » cast_summon
2654   » plant_post
2686   » _raise_post
2699   » redeploy_posts
2730   » _hud
2733   » update_health_display
2742   # Mana pool
2744   » get_max_mana
2747   » get_mana_regen
2750   » spend_mana
2757   » gain_mana
2764   » build_mana_bar
2797   » update_mana_display
2812   » build_orbs
2856   » update_buff_chips
2892   » update_orbs
2918   » build_player_light
2935   » build_char_shadow
2938   » apply_knockback
2953   » knockback_sign_toward
2962   » _on_spear_tip_hit
2981   » wield_weapon
3022   » select_hotbar_slot
3043   » update_weapon_guard
3070   » set_test_aim
3073   » get_aim_direction
3084   » aim_world_point
3100   # UI input guard (audit fix)
3114   » _try_open_villager_menu
3131   » ui_blocks_world_input
3140   » _tick_dig
3159   » update_weapon_visual
3206   » add_currency
3215   » take_damage
3283   » suffer_lethal
3323   » grant_iframes
3345   » start_invincibility_flash
3356   » stop_invincibility_flash
3362   » die
3422   » drop_currency_on_death
3443   » apply_difficulty_death_penalty
3453   » update_currency_display
3465   » perform_dash
3482   » perform_admin_dash
3503   # THE WUKONG ROADS
3518   # set-souls state (2026-07-29): Deadeye's stillness prime, Temper's stacks
3527   » _stone_guise_floor_key
3535   » enter_stone_guise
3548   » wukong_air_hop_allowed
3556   » somersault_ready
3565   » perform_somersault
3580   » spawn_cloudlet
3598   » tick_wukong
3606   » _tick_pillar_stance
3645   » _tick_deadeye
3664   » _tick_sanctuary
3705   » _tick_hair_clone
3731   » _make_ring
3747   » _unmake_ring
3754   » _physics_process
3951   # Flight (Aetherwing)
3953   » has_flight
3965   » has_wings
3976   » levitate_mana_rate
3982   » has_fall_immunity
3989   » update_flight
4019   # Fall damage
4022   » handle_fall_landing
4030   » apply_fall_damage
4043   » perform_secondary_attack
4054   » cast_percent_burst
4087   » spawn_ruin_burst
4103   # FISHING (pillar 3): the rod's whole grammar
4107   » _rod_fish_action
4127   » _nearest_fish_water
4143   » _tick_fishing
4166   » _fish_strike
4188   » _spawn_bobber
4213   » _fish_cancel
4222   » _clear_bobber
4245   » _foes_within
4259   » _nearest_foe_near
4276   » attack_area_bodies
4309   » singleton_busy
4315   » perform_attack
6098   # Melee combo strings
6115   » combo_length
6137   » combo_finisher_mult
6143   » combo_is_live
6149   » combo_step
6160   » reset_combo
6166   » update_combo_label
6188   # Per-weapon crit character
6192   » weapon_crit_chance_bonus
6198   » weapon_crit_damage_bonus
6210   » _slash_texture
6217   » spawn_swing_trail
6379   » weapon_grade_rank
6385   » grade_force_mult
6392   » grade_projectile_girth
6394   » grade_projectile_range
6397   » swing_slash_config
6451   » unleash_court
6505   » call_the_daybreak
6533   # 
6542   # 
6551   » fire_with_ghosts
6568   » _tick_ghost_bows
6577   » _sync_ghost_bows
6605   » _make_ghost_bow
6629   » _ghost_arrival_sparks
6655   » loose_shaped_volley
6704   » _shaft
6723   » stats_knockback_min
6726   » stats_knockback_max
6729   » call_the_kings_rain
6761   » _roof_holds_puff
6774   » launch_swing_slash
6790   » launch_projectile
6837   » throw_javelin_volley
6933   » cast_wand_projectile
6968   » cast_storm_tome
7021   » plant_sentry
7043   » staff_reach_mult
7057   » _staff_leaves
7070   » staff_note_swing
7187   # Relic powers (triggered mechanics on equipped relics; see inventory.gd
7196   » _now
7200   » has_relic_power
7212   » relic_power_value
7219   # Relic power effects (see has_relic_power)
7222   # Sage: the channelled beam (skill tree mg_s4b "Focusing Lens")
7236   » has_beam
7239   # A SMALL PERSONAL SUN (crown wand, Last-Prism-kin never 1:1)
7257   » is_prism_weapon
7260   » prism_focus_frac
7263   » stop_prism
7273   » channel_prism
7337   » _build_prism_lines
7348   » _draw_prism_beam
7365   » _draw_prism_core
7393   » beam_peak_mult
7397   » beam_ramp_mult
7400   » stop_beam
7406   » draw_beam
7424   » channel_beam
7491   » apply_omnivamp
7506   # THE BOND'S TWO PROMISES (Bondmaster, read by player.take_damage)
7510   » bond_intercept
7528   » bond_avenge
7565   » find_bond
7573   » rouse_posts
7584   » shepherd_whistle
7608   » oath_dash_to
7634   » heal
7652   » _tick_waymarks
7668   » apply_melee_skills
7729   » reflect_thorns
7743   » spawn_aegis_block
7759   » spawn_phoenix_revive
7777   » spawn_shock_ring
7800   » _unique_impact_point
7810   » on_projectile_hit
7835   » _fell_later
7859   » _toll_mark
7889   » call_a_marcher
7926   » advance_swing_charge
7952   » apply_excellent_effect
8055   # Excellent-weapon hit visuals (all procedural, world-space, self-cleaning)
8064   » spawn_lightning_bolt
8102   » _jagged_points
8118   » spawn_blood_steal
8137   » _circle_points
8145   » spawn_gold_sparks
8171   » spawn_execute_flash
8191   » collapse_singularity
8209   » spawn_singularity_visual
8239   » unleash_ragnarok
8265   » spawn_ragnarok_ring
8282   » spawn_bane_flash
8298   » spawn_chrono_flash
8326   » spawn_echo_ring
8343   » spawn_soul_wisps
8362   » closest_body
8372   » animate_sword
8385   » animate_spear
8412   » animate_bow
8422   » spawn_arrow
8559   » cast_wand
8576   » cast_wand_nuke
```

### dungeon_interior.gd (2776 lines)
```
395    » _unhandled_input
402    » _open_floor_map
421    » _all_static_rects
434    » _ready
477    » setup_exit_button
483    » start_music
505    » music_pitch_for
514    # layout selection
516    » get_layout_slot
519    » is_boss_level
523    » get_layout
529    # REGULAR FLOOR LAYOUTS
551    » get_regular_theme
554    » generate_regular_layout
573    # reachable primitives
575    » _ledge
581    » _stack
594    » _span_with_access
604    # the twelve themes
606    » _theme_terraces
619    » _theme_isles
630    » _theme_pillared_hall
640    » _theme_chasm_bridges
649    » _theme_overwatch
656    » _theme_gauntlet
671    » _theme_twin_towers
677    » _theme_amphitheatre
689    » _theme_roost
701    » _theme_warren
712    » _theme_sunken_court
721    » _theme_cascade
736    » total_boss_levels
747    » get_boss_id
765    » get_boss_counter
776    » build_counter_sequence
790    » get_boss_arena
793    » get_level_width
798    » get_level_ceiling
803    # boss arena platform generators
813    » generate_boss_platforms
847    » add_sky_tier
862    » gen_gravewarden
884    » gen_frost
906    » gen_cinder
930    » gen_weaver
954    » gen_stormcaller
977    » gen_void
997    # the deep (35-90)
1008   » gen_hollow_choir
1043   » gen_ashen_penitent
1085   » gen_gaoler
1119   » gen_sablefang
1145   » gen_effigy
1168   » gen_mourncaller
1194   » gen_unseen
1215   » gen_warden_of_nails
1246   » gen_twin_despair
1268   » gen_cinderking
1296   » gen_glass_saint
1322   » gen_last_man
1345   # apex arena generators
1351   » gen_seraph
1381   » gen_leviathan
1397   » gen_eclipse
1426   » gen_wizard
1444   # level (re)building
1446   » build_level_visuals
1476   » build_floor_surprises
1493   » _dgn_cache
1511   » _dgn_hazard
1516   » build_gates
1531   » on_gate_used
1538   » go_to_level
1544   » build_background
1572   » build_wall_layer
1599   » build_ground_and_walls
1627   » build_wall
1646   » build_platforms
1673   » build_stalactites
1690   » build_cave_life
1738   » _glow_sprite
1748   » _mushroom_cluster
1770   » _crystal_cluster
1784   » _moss_patch
1792   » _ceiling_root
1803   » make_additive_material
1811   » _ensure_ambient
1819   » build_torches
1849   » build_torch
1902   » place_mines
1931   » place_hazards
1969   » place_mine
1974   » place_player_at_entry
1987   » _place_deep_shrine
2010   # combat flow (mirrors the old overworld dungeon_manager.gd)
2014   » _softcapped_mult
2019   » get_level_scaling
2026   » spawn_level_combat
2092   » play_empty_throne
2103   » play_final_victory
2139   » spawn_deep_rescue
2189   # normal-level mob composition
2215   » block_position
2218   » op_pool_for_level
2227   » _op_band
2235   » op_fraction
2242   » spawn_level_mobs
2271   » pick_random_subset
2276   » spawn_kind
2287   » spawn_special_mob
2310   » _physics_process
2319   » spawn_enemy
2356   » assign_enemy_behavior
2377   » spawn_boss
2409   » get_material_for_level
2422   » roll_material_drop
2437   # Gear loot
2490   » roll_gear_drop
2539   » _gear_in_depth
2550   » _gear_unowned
2559   » _give_gear
2571   » register_extra_combatant
2583   » _on_combatant_died
2624   » play_orin_glimpse
2627   # PROVING GROUNDS (admin test arena)
2632   » build_proving_grounds
2693   » _proving_label
2705   » exit_dungeon
2720   » update_level_label
2747   » _straggler_hint
2773   » show_notification
```

### building.gd (2230 lines)
```
12     # Destructibility (see the damage note; HP persists in GameState)
17     # Upgrades
35     # Build / repair
166    » _ready
234    » _make_label
244    # level-scaled dimensions
254    » eff_w
257    » eff_h
264    » dock_water_half
267    # fishing (pillar 3): the "fish_water" contract the pond answers
268    » fish_kind
271    » fish_half_width
274    » fish_surface_y
280    » max_upgrade_width
284    » rebuild_geometry
314    # damage
316    » state_for_health
327    » state_for_stage
334    » compute_visual_state
339    » is_operational
342    » take_damage
369    # build / repair (staged)
371    » is_ruined
375    » repair_requirement_text
381    » has_repair_materials
388    » missing_repair_materials
399    » try_build
415    » advance_build_stage
429    » play_construction_animation
440    » spawn_build_dust
465    » restore_full
487    » update_name_label
496    » _refresh_rubble
541    » update_prompt
559    # wall torches (auto day/night lighting)
585    » build_torch_layer
646    » position_torches
660    » update_torches
673    » _add_mat
678    » _fire_gradient
684    # villagers at work (visible busy-ness once people are employed here)
710    # attached work-yards
734    » area_world_half
738    » area_offset_x
760    » employed_count
770    » play_door_anim
794    » refresh_workers
867    # attached work-yard props
868    » _a_rect
876    » _a_disc
883    » _a_line
890    # Farm crops (dynamic)
895    » _update_farm_crops
907    » _draw_crop
932    » _spawn_harvest_puff
948    » _spawn_harvest_float
961    » build_work_area
1096   # the Bar's fun music + player morale
1136   » update_bar_music
1152   # upgrades
1154   » can_upgrade
1157   » upgrade_cost
1161   » try_upgrade
1177   » effective_slots
1183   # visuals
1185   » refresh_visual
1209   » build_intact
1272   # shared tiny draw helpers for the named silhouettes
1273   » _disc
1280   » _tri
1283   » _ln
1292   » _lit_col
1295   » _win
1303   » draw_named_building
1329   » _b_government
1349   » _b_school
1366   » _b_farm
1387   » _b_hospital
1405   » _b_barracks
1427   » _b_dock
1450   » _b_lab
1470   » _b_bank
1505   » _b_blacksmith
1536   » _b_tavern
1574   » _b_bar
1627   » market_sections
1630   » _b_market
1657   » _b_builder
1685   » build_half
1699   » build_destroyed
1718   # body / roofs / features
1720   » add_body
1727   » build_roof
1766   » build_feature
1799   » add_pennant
1808   » add_window_grid
1841   » _side_centers
1850   » add_door
1855   » add_cracks
1870   » add_scorch
1885   » add_glow
1900   » add_fire
1935   » build_shine
1946   » flash_body
1953   » spawn_hit_debris
1975   # small draw helpers
1977   » add_poly
1983   » add_rect
1991   » rect_poly
1994   » ruined_body_poly
2004   » circle_poly
2011   # health bar
2013   » build_health_bar
2026   » update_health_bar
2038   # gameplay
2040   » _on_body_entered
2049   » _on_body_exited
2057   » _process
2178   » get_roles
2181   » get_role_holders
2188   » is_role_full
2191   » get_eligible_villagers
2212   » open_assign_ui
2217   » _on_child_produced
```

### enemy.gd (2012 lines)
```
120    # WILDERNESS MOBS (the lands east of the village)
164    # Status effects (see apply_status). burn/poison = damage-over-time,
188    # Behavior archetype (mechanics beyond plain melee/bow). Set by spawn:
198    # THE BESTIARY: the species signature (see ENEMY_ROSTERS). Set by
244    » _now_s
247    » move_speed
253    » signature_speed_mult
261    » status_slow_mult
269    » is_frozen
274    » apply_status
314    » is_petrified
317    » tick_statuses
340    » _refresh_status_overlay
387    » _pick_prey
406    » _retarget
417    » _ready
438    » update_body_color
443    » play_sfx
455    » apply_block_archetype
463    » apply_mixed_archetype
493    » build_character
545    » _add_skull
554    » _add_socket
557    » _add_shoulders
564    » _add_poly
570    » _add_dot
578    # Spritesheet-skinned enemies (downloaded art)
582    » _build_sprite_visual
620    » _update_enemy_anim
633    » setup_weapon_visual
649    » get_aim_direction
656    » update_weapon_icon_position
668    » _physics_process
814    » try_jump
826    » count_nearby_enemies
838    » check_bump
858    » _melee_connects
865    » try_attack
887    » finish_attack
891    » try_deal_melee_damage
911    » _telegraph_weapon
916    » animate_sword_attack
930    » animate_spear_attack
945    » animate_bow_attack
958    » _loose_arrow
968    # Behavior archetypes
976    » set_behavior
1002   # SUPER-MOB (elite) presence + signature slam
1022   » _become_super_mob
1045   » _tick_elite_slam
1061   » _elite_slam
1071   » _spawn_slam_ring
1090   » _elite_shockwave
1113   » _spawn_shock_burst
1135   » process_behavior
1162   # THE BESTIARY
1171   » is_fading
1174   » is_heaped
1177   » is_rallied
1181   » species_behaviors
1187   » _tick_signature
1217   » _hero
1222   » _hero_within
1226   # ORC: "War Cry"
1231   » war_cry
1248   » _spawn_cry_ring
1273   # BLOOD FIEND: "Bloodscent"
1278   » _tick_bloodscent
1296   » _show_frenzy
1319   # DEMON: "Emberburst"
1325   » spawn_ember_burst
1394   » _ignite_ember
1416   # WRAITH: "Fade"
1421   » fade_out
1452   # BONE GOLEM: "Reassemble"
1458   » collapse_to_heap
1474   » rise_from_heap
1488   » _set_body_visible
1504   » _spawn_heap_visual
1541   # ROTFIEND: "Miasma"
1547   » exhale_miasma
1577   # end of THE BESTIARY
1579   » _living_allies
1591   » heal_nearby_allies
1611   » summon_minions
1638   » cast_hex_bolt
1653   » perform_lunge
1668   » show_gold_mark
1675   » spawn_block_spark
1679   » spawn_status_spark
1701   » is_split
1704   » on_soul_split_wand
1725   » take_damage
1780   » apply_knockback
1795   » flash_hit
1809   » update_health_bar
1815   » die
1893   » play_death_animation
1910   » spawn_death_particles
1950   » spawn_coin_popup
1987   » spawn_material_popup
```

### inventory.gd (2326 lines)
```
807    # 
813    # 
1396   # TERRARIA-STYLE TOOLTIP (dev ask 2026-07-22)
1542   # 
1635   # 
1678   # 
1685   # 
1805   # tiny drawing primitives (children of the icon ColorRect)
1822   # armour silhouettes, one per equipment slot (tinted to the item colour)
1879   # per-item symbols (drawn in the target's 0..w / 0..h local space)
2059   # fishing icons (pillar 3): a fish, a crate, a rod, a boot
2116   # material symbols (drop-loot that used to render as a flat coloured square)
2160   » _init
2173   » get_count
2182   » add_item
2221   » remove_item
2242   » transfer_to
2258   » transfer_slot
2280   » to_save_data
2291   » can_accept
2299   » from_save_data
```

### main.gd (1921 lines)
```
179    » building_names
237    » _ready
341    » _maybe_begin_feast
370    » show_away_report
415    » generate_village
485    » spawn_special_plots
497    » building_def
506    » create_building
539    » spawn_placed_torches
548    » spawn_cottage_node
560    » generate_houses
632    » spawn_existing_villager_avatars
685    » _on_village_child_born
717    » arm_arrival_battle
724    » _check_arrival_trigger
759    » _west_wall_x
777    » stage_arrival_battle
823    » trigger_arrival_scene
840    » activate_arrival_combat
847    » _on_arrival_raider_died
889    » _check_arrival_talk
916    » _emerge_arrival_survivors
928    » _stage_arrival_tableau
1001   » _npc_ground_y
1008   » _face_entity
1022   » play_arrival_talk
1060   » _autosave_on_arrival
1063   » stamp_rewound_arrival
1072   » orin_midgame_taunt
1085   » warn_wounded_corps
1106   » build_escape_ward
1128   » _on_escape_attempt
1163   » _spawn_gauntlet_wave
1176   » _on_gauntlet_raider_died
1189   » announce_orin_arrival
1205   » spawn_adventurers
1220   » is_villager_busy_mating
1236   » offscreen_spawn
1248   » find_avatar_spawn_position
1273   » _process
1289   » _unhandled_input
1305   » _toggle_proving_ground
1313   » _open_village_map
1350   » start_music
1368   » _village_is_healthy
1378   » _tick_music
1406   » apply_save_data
1455   » generate_harvestables
1504   » spawn_harvest_node
1521   » generate_grass
1532   » generate_traps
1540   » generate_platform_traps
1564   » place_trap
1569   » generate_mountains
1671   » _extend_ridges_across_world
1706   » fence_the_camera
1714   » fit_sky_to_world
1725   » build_ground_skin
1781   » build_platform_skins
1832   » _tile_top_padding
1844   » generate_mountain_shape
1868   » generate_clouds
1897   » generate_cloud_shape
1911   » spawn_tuft
```

### underdark.gd (1343 lines)
```
27     # geometry
80     # the cave mouth
112    # doors
120    # streaming mobs
134    » _ready
178    » build_legacy_strip
219    » _seal_descent
237    » band_floor_y
242    » _stair_steps
245    » _stair_end_x
249    » _retire_surface_door
271    » _carve_ground_skin
287    » _plan_bands
323    » _build_dark_backdrop
336    » _slab
367    » _build_mouth_and_stair
439    » _climbable_platforms
447    » _build_bands
510    » _plan_shafts
540    » _is_vault_segment
546    » _build_shaft_ladders
572    » _slab_with_hole
581    » _seg_at
587    » _brazier
629    # the cave is alive
643    » _build_cave_life
672    » _cl_glow
682    » _cl_mushrooms
704    » _cl_crystals
717    » _cl_moss
725    » _cl_root
735    # the hidden doors
736    » _place_doors
791    # ore seams
792    » _place_seams
813    # streamed cave mobs (the east road's three rules, underground)
814    » _process
825    » _hold_the_dark_lit
834    » _stream_tick
861    » _band_of
864    » _stream
901    » _sector_center
907    » _prune
917    » _populate
947    » live_count
955    # traps, chests, and the rune vaults
956    » _trap
965    » _stock_chest
1000   » _add_chest
1010   » _place_chests
1029   » _plan_pits
1051   » _build_pits
1092   » spring_ambush
1121   » _build_hidden_lofts
1163   » _build_rune_vaults
1225   » rune_lit
1239   # the arch you walk into
1249   » _build_cave_prompt
1304   » _tick_cave_mouth
```

### npc.gd (1392 lines)
```
31     » _town_cluster
49     » _wall_span
66     » _village_span
131    » _ready
205    » build_visual
210    » _body_px
222    » apply_size
296    » _villager_skin
311    » _build_villager_sprite
329    » _update_villager_anim
348    » refresh_size_if_needed
356    » build_health_bar
399    » _nearest_threat
412    » _tick_defence
435    # ALIVE, NOT ALIKE (dev 2026-07-23: "make them more alive and not lookalike")
444    » _roll_temperament
460    » _nearest_threat_within
476    » _tick_flee_on_sight
492    » is_fleeing
495    » take_damage
516    » update_health_bar_fill
524    » apply_despair_visual
555    » update_health_bar_display
577    » die
591    » _physics_process
779    » cheer
787    » _apply_cheer
830    » pick_new_state
846    » find_villager_data
861    » _on_body_entered
865    » _on_body_exited
869    » _process
892    » maybe_recount_news
905    » _apply_shadow_form
911    » try_doctor_heal
947    » _play_doctor_sfx
958    » try_bond_interaction
1004   # mood talk
1014   » tick_mood_talk
1025   » say_mood_line
1031   » mood_lines
1064   » _monarch_reaction_lines
1085   » refresh_wander_bounds
1108   » get_building_for_role
1111   » roll_new_cycle
1123   » tick_building_visits
1160   » pick_visit_building
1181   » enter_building_node
1185   # THE SICK ROAD (expansion 2026-07-24)
1191   » _is_wounded
1194   » _nearest_hospital
1208   » _try_seek_care
1222   » _cancel_care
1230   » _tick_treatment
1250   » _complete_enter
1273   » exit_building
1297   » info_fields
1350   » bond_fields
1363   » show_info
1375   » speak_or_notify
1383   » open_sheet
1391   » open_menu
```

### special_mob.gd (2102 lines)
```
3      # 
18     # 
141    # Elite affixes
187    # Statuses. Special mobs used to have NO apply_status, so every burn/poison/
210    » is_petrified
213    » apply_status
265    » status_slow_mult
273    » tick_statuses
313    # the 9 new kinds (2026-07-27)
409    » _ready
456    » build_collision
486    » _physics_process
583    # per-kind behaviour
588    » act_flyer
627    » act_bomber
637    » prime_and_explode
650    » explode
663    » act_charger
702    » act_spitter
714    » act_stalker
758    » act_blink_archer
777    » act_hexer
791    » cast_hex_ring
817    » act_runecaster
824    » cast_runes
851    » act_warlock
866    # 9 MORE SPECIAL MOBS (2026-07-26) -- each a distinct trick
886    » _burst
900    » act_weaver
911    » cast_web
930    » act_leech
941    » leech_tether
968    » act_burrower
1004   » act_warper
1016   » warp_pull
1033   » act_plague
1043   » spawn_gas
1067   » act_wailer
1076   » wail
1094   » act_ballista
1101   » ballista_fire
1127   » act_swarm
1143   » act_frostling
1154   » frost_cast
1173   » spawn_frost_patch
1195   » act_sentinel
1202   » sentinel_sweep
1245   » act_brood
1261   » act_arcbinder
1272   » arc_strike
1306   » act_warchief
1321   » rally
1331   » act_voidling
1352   » act_gazer
1384   » act_skycaller
1393   » sky_rain
1423   » act_vampire
1447   » act_juggernaut
1477   # caster/teleport helpers
1479   » face_player
1485   » arena_width
1491   » teleport_to
1499   » blink_to_flank
1503   » spawn_teleport_puff
1521   » spawn_sigil
1533   » erupt_rune
1546   # shared combat
1548   » deal_contact_damage
1552   » fire_projectile
1558   » take_damage
1609   » apply_knockback
1623   » die
1638   » _spawn_brood_splits
1655   # visuals
1657   » set_flash
1664   » clear_flash
1671   » add_part
1676   » build_visual
1714   » _build_mob_sprite
1727   » _update_mob_anim
1735   » poly
1740   » circle_points
1750   » build_flyer_visual
1769   » build_bomber_visual
1786   » build_charger_visual
1804   » build_spitter_visual
1823   » build_stalker_visual
1833   » build_blink_archer_visual
1855   » build_hexer_visual
1867   » build_runecaster_visual
1884   » build_warlock_visual
1898   » _robe
1901   # the 9 new mobs' silhouettes (simple, distinct)
1902   » build_weaver_visual
1912   » build_leech_visual
1919   » build_burrower_visual
1926   » build_warper_visual
1933   » build_plague_visual
1938   » build_wailer_visual
1945   » build_ballista_visual
1953   » build_swarm_visual
1959   » build_frostling_visual
1965   » build_sentinel_visual
1971   » build_brood_visual
1978   » build_arcbinder_visual
1985   » build_warchief_visual
1994   » build_voidling_visual
2000   » build_gazer_visual
2006   » build_skycaller_visual
2014   » build_vampire_visual
2022   » build_juggernaut_visual
2031   » build_elite_glow
2045   » build_health_bar
2059   » update_health_bar
2063   » play_sfx
2071   » spawn_blast
2084   » spawn_death_particles
```

### wizard.gd (886 lines)
```
15     # Combat / survivability tuning
35     # Undying escalation
69     » apply_power_tier
80     » current_skill_name
88     # Downed / respawn
135    » _ready
172    » _physics_process
190    » _process
208    » tick_regen
217    # combat
219    » try_cast
232    » find_target
252    » cast_meteor_at
307    » apply_meteor_impact
317    » spawn_impact_fx
348    # take hits
352    » take_damage
364    » die
374    # downed / reform
376    » build_fireball
468    » enter_downed_state
500    » _hide_gfx
506    » respawn
550    » _set_fireball_flames
559    » update_ember_growth
570    » spawn_revive_flash
583    » spawn_puff
603    » _additive_material
608    # visuals
610    » build_visual
669    » _build_orin_sprite
684    » _on_orin_anim_finished
688    » build_staff
710    » start_idle_animation
719    » animate_cast
733    » face_toward
740    » build_health_bar
757    » update_health_bar_fill
761    » update_health_bar_display
782    » build_proximity_area
796    » _on_body_entered
800    » _on_body_exited
804    » build_hover_panel
829    » is_hovering
832    » update_hover_panel
837    # geometry util
839    » _circle_points
847    » _ellipse_points
857    » _flame_points
871    » _rock_points
880    » _star_points
```

### adventurer.gd (756 lines)
```
29     » play_sfx
60     # signature ability state (each adventurer runs a DIFFERENT mechanic)
99     » _ready
163    » hero_color
166    » _build_visual
287    » _refresh_prompt
295    » _apply_station_groups
303    » _physics_process
333    » _update_adv_anim
343    » _swing_lunge
360    » _tick_bark
372    » _update_hp_bar
384    » _cycle_station
408    » _station_anchor_x
446    » _village_center_x
462    » _ensure_anchor
469    » _hold_station
526    » _breached_into_village
542    » _nearest_raider
585    » _attack_damage
599    » _loose_arrow
612    » _second_raider
624    » _fight
704    » take_damage
741    » on_siege_ended
744    » die
755    » apply_knockback
```

### assign_ui.gd (944 lines)
```
6      » _ready
15     » open_for_building
20     » close
25     » esc_is_open
28     » esc_close
31     » refresh
73     » add_market_stall_section
117    » _on_stall_sell
135    » add_relocate_section
159    » add_repair_section
208    » _on_repair
229    » add_upgrade_section
369    » _on_upgrade
387    » add_research_section
441    » _on_build_whisperstone
449    » _on_research
477    » smithy_max_rank
480    » smithy_stock
522    » smithy_imports
551    » add_ward_section
567    » _on_ward_heal
585    » smithy_price
588    » add_smithy_section
607    » _on_buy_gear
630    » add_dock_section
664    » _on_fishing_turn_in
675    » add_armory_section
732    » add_stores_section
782    » _on_donate_store
795    » _on_deposit_arm
815    » add_role_section
865    » _empty_seat
879    » _villager_seat
907    » _tint_seat
917    » _on_assign
```

### day_night_cycle.gd (514 lines)
```
124    » _ready
146    » sync_from_master
159    » make_additive_material
164    » build_sun
183    » build_sun_highlight
193    » build_sun_rays
207    » setup_moon_glow_materials
219    » update_moon_glow_shape
237    » generate_moon_craters
269    » max_crater_radius_at
285    » is_point_in_moon_phase
297    » is_crater_fully_in_phase
308    » update_moon_craters
324    » build_moon_sky_glow
332    » build_circle
340    » build_moon_phase
360    » pick_new_moon_phase
378    » _process
390    » handle_debug_time_input
405    » get_darkness_factor
414    » is_night
417    » get_sun_progress
423    » get_moon_progress
436    » is_sun_moon_overlap
439    » get_parallax_anchor_x
445    » arc_position
450    » update_visuals
480    » counter_color
488    » update_moon_true_colors
509    » update_clock_label
```
