# Deepwood — Codemap

_Navigation index for fast lookup. Regenerate with `bash gen_codemap.sh`. Line numbers drift as code changes — treat as approximate anchors, confirm with a read._

`130` game scripts, ~82664 LOC. Generated 2026-08-06.

## File directory

| script | lines | purpose (first header comment) |
|--------|------:|--------------------------------|
| admin_panel.gd | 497 | One-stop dev/testing console, toggled with P. Every "OP" testing action lives |
| adventurer.gd | 756 | A living adventurer defending Deepwood (GAME_BIBLE 2.4.1). Persistent between |
| adventurer_rescue.gd | 72 | A chained adventurer awaiting rescue in the dungeon (the deep nine of |
| adventurers.gd | 100 | The twelve adventurers (GAME_BIBLE §2.4.1 "The three defenders" + the deep |
| arrival_weather.gd | 59 | THE ARRIVAL STORM (start-scene fix, 2026-07-21). The dev's canon asked for |
| arrow.gd | 503 | (no header comment) |
| assign_ui.gd | 1103 | (no header comment) |
| blueprint_pickup.gd | 57 | A BLUEPRINT SATCHEL (GAME_BIBLE 5.2): the plans for one village building, |
| bond_mark.gd | 142 | THE BOND-MARK (Summoner, batch 1 — 2026-07-30). |
| boss.gd | 5172 | Dungeon boss. |
| boss_hud.gd | 192 | WUKONG-STYLE BOSS SPECTACLE (dev ask 2026-07-22). Makes every boss an EVENT: |
| build_menu.gd | 260 | THE BUILDER'S LEDGER (B key; dev request 2026-07-21). |
| build_placer.gd | 448 | THE BUILDER'S HAND (dev 2026-07-22). Raise a building from the B menu with a |
| building.gd | 2253 | (no header comment) |
| building_hitbox.gd | 15 | Buildings are Area2D nodes (for the Press-E proximity), which enemy arrows |
| building_lights.gd | 317 | Breathes life into the painted facades WITHOUT touching the approved art: |
| building_roles.gd | 120 | Role definitions per building (keyed by the building's role_key, e.g. |
| camera_shake.gd | 22 | (no header comment) |
| char_shadow.gd | 44 | Preloaded as a const by its users (const CHAR_SHADOW = preload(...)) rather than |
| chest.gd | 44 | Unique per-instance id, used as the key into GameState.chest_contents so |
| chest_ui.gd | 319 | The vault racks now hold a GRADE'S whole catalogue (76 rare items after the |
| choice_prompt.gd | 148 | A small modal decision box, styled like the DialogueBox: a title, a body line, |
| companion.gd | 830 | COMPANIONS (task: light summoner, 2026-07-29). No fourth class: a companion |
| currency_pickup.gd | 320 | "1 full in-game day" is defined by the day/night cycle's own day length, |
| day_night_cycle.gd | 769 | (no header comment) |
| death_screen.gd | 76 | main.tscn and dungeon_interior.tscn author the black shade + CountdownLabel by |
| dialogue_box.gd | 409 | A small, reusable conversation box (bottom of screen): a brass name-plate, one |
| dock_bridge.gd | 71 | A walkable wooden crossing spanning the Fishing Dock's water: stairs up, a |
| dps_dummy.gd | 89 | The Proving Grounds training dummy: an invincible target that never dies and |
| drag_state.gd | 277 | Coordinates dragging an item stack between slots -- possibly across two |
| dungeon_gate.gd | 106 | The LEAVE gate on the left of every dungeon floor (see dungeon_interior.gd). |
| dungeon_interior.gd | 2783 | Dungeons are a real separate scene the player is teleported into (see |
| dungeon_manager.gd | 18 | Dungeon combat now happens in a fully separate scene (dungeon_interior.gd) |
| dungeon_sign.gd | 50 | (no header comment) |
| dungeon_zone.gd | 24 | (no header comment) |
| embedded_stack.gd | 318 | EMBEDDED STACKS (weapon overhaul, 2026-07-29) -- the "aftermath" system for |
| enemy.gd | 2012 | Dev call 2026-07-21: sight cut 15% (was 225) -- "I don't want them to non |
| enemy_skins.gd | 200 | Shared skin builder for downloaded/generated character art. Originally for |
| equipment_ui.gd | 490 | Equipment panel, pinned to the RIGHT side of the screen (kept clear of the |
| event_boss.gd | 244 | HIDDEN EVENT BOSSES (2026-07-28). Ten secret bosses, woken by the player |
| event_boss_director.gd | 90 | HIDDEN EVENT-BOSS DIRECTOR (2026-07-28). Mounted into whatever scene the |
| farm_animal.gd | 221 | A small BLOCKY, pixel-styled farm animal (chicken / pig / cow / sheep) that |
| farm_pen.gd | 74 | A fenced pasture beside the Farm. Draws the fence + a dirt patch and spawns a |
| fish_water.gd | 23 | FISHING (pillar 3): a stretch of fishable water. The Dock's pond needs no |
| fishing.gd | 101 | (renewability pillar 3, dev-chosen 2026-07-28: the FULL loop, reforging |
| floating_text.gd | 75 | Shared floating combat text -- a damage number that rises, drifts, and fades |
| food_readout.gd | 99 | Always-visible village food gauge, top-left HUD, tucked just under the mana |
| game_state.gd | 8618 | THE DEV'S REAL SAVE IS NOT A TEST FIXTURE (global hunt 2026-07-28). |
| harvest_director.gd | 402 | THE HARVEST, AT HOME (new finale canon, 2026-07-20). |
| harvest_node.gd | 323 | A harvestable world node: a TREE (chop with the Woodsman's Axe) or a ROCK |
| hazard.gd | 308 | CREATIVE DUNGEON HAZARDS (dev report 2026-07-21: "no creative traps"). Beyond |
| hazard_zone.gd | 81 | A lingering ground hazard dropped by a boss signature ability and then left to |
| hit_fx.gd | 67 | ELEMENT IMPACT BURSTS (item-art VFX pass 2026-07-28, Terraria-hit-spark |
| homing_bolt.gd | 45 | A slow homing projectile — the Mourncaller's Keening wisps, and reusable for |
| hotbar_ui.gd | 86 | Bottom-of-screen hotbar showing the first 10 inventory slots (keys 1-9, 0). |
| house.gd | 175 | (no header comment) |
| how_to_play.gd | 117 | HOW TO PLAY -- the controls and the laws, one readable page, opened from |
| hud_orb.gd | 48 | MU Online / Diablo style liquid globe for HP or mana (dev ask 2026-07-22). |
| inventory.gd | 2369 | Shared item catalog -- every item type in the game (currency included) is |
| inventory_ui.gd | 352 | Terraria-tight pixel slots (dev ask 2026-07-22): a compact grid of bordered |
| item_tooltip.gd | 100 | A single hover tooltip shared by every item UI (inventory, chest, equipment |
| level_select_ui.gd | 141 | (no header comment) |
| magic_orb.gd | 103 | A slow homing "cursed orb" fired by the Warlock mob (special_mob.gd). It |
| main.gd | 1936 | (no header comment) |
| main_menu.gd | 189 | Whether the fresh-start flow currently in the difficulty picker should wipe |
| material_pickup.gd | 100 | A dropped material on the ground (dev ask 2026-07-22: "materials like in |
| mirror_mage.gd | 113 | THE PLUCKED HAIR (Wukong roads, 2026-07-28): when enemies press the Sage, |
| monarch_name_fx.gd | 30 | THE MONARCH NAME CYCLE (2026-07-30, dev reference clip: Terraria's Rainbow |
| morale_meter.gd | 204 | Village morale, shown in the TAB overlay directly BELOW the mana bar (kept |
| notification_stack.gd | 32 | Toasts render as BBCode (item-art name-plate pass 2026-07-28): callers can |
| npc.gd | 1392 | Points back at their entry in GameState.rescued_villagers -- info is |
| objective_banner.gd | 97 | A quiet, always-current objective ticker at the top of the VILLAGE screen, so a |
| pause_menu.gd | 270 | (no header comment) |
| player.gd | 8655 | DEV CALL (2026-07-20): the old dash covered 600*0.15 = 90px -- barely |
| playtest_journal.gd | 124 | THE FIELD JOURNAL (built for the 4-5h marathon playtest, 2026-07-21). |
| portal.gd | 74 | ONE RIFT of the Mage's Riftweaving pair (mg_p1..p3, dev request |
| presence_light.gd | 44 | COUNTERING THE NIGHT, for the village's read-only presence layers. |
| road_marker.gd | 77 | THE ROAD MARKERS (polish 2026-07-20) -- the village and the pit sit |
| roster_ui.gd | 184 | THE ROSTER (polish 2026-07-20) -- every soul in Deepwood on one page. |
| sentry_totem.gd | 100 | THE PLANTED SENTRY (weapons overhaul 2026-07-28, Terraria-sentry-INSPIRED): |
| sfx_synth.gd | 456 | PROCEDURAL CHIPTUNE ONE-SHOTS (audio pass 2026-07-28): the overhaul's |
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
| special_plot.gd | 212 | A SPECIAL PLOT marker (roadmap Phase 3): the ground itself, drawn. |
| speech_text.gd | 70 | Floating, window-less speech for characters: plain outlined text hovering |
| standing_torch.gd | 117 | A big free-standing brazier torch the player can PLACE anywhere on the ground |
| storm_cloud.gd | 385 | TOME AREA DENIAL (weapons overhaul 2026-07-28, Terraria-spellbook-INSPIRED, |
| story.gd | 183 | Deepwood's scripted story beats, kept in one place (canon: GAME_BIBLE §2/§9, |
| summon_post.gd | 410 | SUMMONER POSTS (batch 1 — 2026-07-30). |
| synergy_lanterns.gd | 229 | ADJACENCY, MADE VISIBLE (dev call 2026-07-30). Of the four placement rules this |
| ten_ally.gd | 298 | One of the Ten, fighting beside you at the Harvest (GAME_BIBLE 9.4) -- ten |
| the_ten.gd | 61 | THE TEN (GAME_BIBLE §8) -- the capstone hostages, the truly unbreakable. |
| training_arena.gd | 238 | THE PROVING GROUND (dev, 2026-07-30). |
| trap.gd | 88 | (no header comment) |
| trophy_vault.gd | 97 | A Trophy Vault (GAME_BIBLE §8): the gilded cage where Orin keeps one of the |
| tutorial_overlay.gd | 94 | THE INTERACTIVE TUTORIAL CARD (dev 2026-07-22: "show, don't tell"). Instead of a |
| underdark.gd | 1385 | THE UNDERDARK (GAME_BIBLE §4 amendment, dev-decided 2026-07-21). |
| underdark_ambush.gd | 25 | A hidden ambush in a sunken chamber of the deep (underdark.gd _build_pits). |
| underdark_door.gd | 157 | A hidden stone door of the Underdark (GAME_BIBLE §4 amendment). Each one is |
| underdark_rune.gd | 71 | One of three rune stones that unbar a band's vault (underdark.gd). Press E. |
| underground.gd | 4701 | ── THE TERRARIA UNDERGROUND (rework, 2026-07-25) ────────────� |
| underground_pause.gd | 118 | THE CAVE'S PAUSE MENU (scan fix 2026-07-27). |
| vault_chest.gd | 134 | A Proving Grounds vault chest. Unlike a normal loot chest it's a bottomless |
| village_crests.gd | 227 | THE ROOFLINE: who is in charge here, and what they can do about it. |
| village_life.gd | 435 | Makes Deepwood feel ALIVE, and rewards the player's progress with spectacle. |
| village_log_ui.gd | 122 | THE VILLAGE LOG (GAME_BIBLE 5.9) -- press L. The village's diary: births, |
| village_presence.gd | 535 | THE VILLAGE MADE VISIBLE (dev call 2026-07-30: "i don't like these" -> the |
| villager.gd | 234 | Unique per-instance id so an already-rescued villager doesn't reappear (and |
| villager_menu.gd | 160 | THE VILLAGER MENU (dev ask 2026-07-27): walk up to a villager, RIGHT-CLICK, and |
| villager_quests.gd | 261 | Two things live here: |
| villager_sheet.gd | 162 | THE VILLAGER SHEET (dev call 2026-07-27). The old way of reading a villager was |
| wall.gd | 385 | The village's west rampart -- the line the siege breaks against. It has no |
| wanderer_ui.gd | 119 | THE WANDERER'S POST counter (GAME_BIBLE 5.6a) -- opened with the hands-on |
| watchtower.gd | 148 | THE WATCHTOWER (GAME_BIBLE 7.1) -- foresight, earned. A standalone |
| weapon_arena.gd | 243 | THE ARENA, AS ITS OWN SCENE (dev, 2026-07-30: "you have bad arena btw. bad |
| weapon_fx.gd | 474 | (dev order 2026-07-28: "all weapons skills and effects and aftereffects |
| weapon_projectile.gd | 11629 | One configurable projectile powering the special-attack weapons (see |
| weapon_roster.gd | 2004 | The 350-weapon roster's engine (weapons overhaul wave 2, 2026-07-28). |
| wilderness.gd | 231 | THE EAST ROAD (2026-07-21, dev request). |
| wizard.gd | 886 | ORIN, the stranded village mage. Lore: an adventurer like the player who |
| worker_figure.gd | 373 | A villager-at-work figure, spawned by building.gd when villagers are employed |
| world_map.gd | 221 | ── THE FULL MAP, EVERYWHERE (M) ────────────────── |

## Big-file outlines (sections + functions, with line numbers)

Jump anchors for the files too large to grep comfortably. `#` = section header, `»` = function.

### game_state.gd (8618 lines)
```
11     » active_save_path
31     » deepest_level_path
56     » floor_is_cleared
59     » mark_floor_cleared
83     » is_shrine_floor
86     » shrine_revealed
89     » revealed_shrines
110    » load_game_completed
113    » mark_game_completed
122    # DEV / TEST MODE
148    # Harvest-node persistence (audit fix)
163    » ensure_harvest_seed
176    » test_populate_village
235    # XP / skill tree
259    # Equipment
300    » relic_slot_count
306    » get_equipment_total
314    » item_equip_effect
322    » get_weapon_passive_total
330    » get_bonus_total
346    » found_bonus
351    » get_equipped_item_ids
361    » set_pieces_equipped
370    » is_set_complete
377    » wielded_weapon_id
385    » get_set_bonus_total
404    » equip_item
432    » unequip_slot
457    » first_empty_relic_slot
465    » load_equipment
487    » xp_to_next_level
500    » depth_reward_mult
507    » add_xp
540    # The Shadow Monarch (hidden 7-stage passive, tied to character level)
560    » monarch_stage
569    » monarch_progress
578    » monarch_intensity
583    » monarch_bonus
606    » announce_monarch_awakening
623    » monarch_true_form
632    » get_skill_total
639    » is_skill_unlocked
646    » try_unlock_skill
677    » try_craft
703    » research_all_materials
711    » reset_skills
722    » capture_player_state
788    # Adventurers (GAME_BIBLE 2.4.1)
796    » ensure_adventurers
807    » adventurer_state
811    » rescue_adventurer
821    » kill_adventurer
830    » set_adventurer_station
846    » wall_stationed_count
857    » fighting_adventurers
875    # THE GOLD FAUCETS (GAME_BIBLE 5.6, revised canon 2026-07-17)
896    # Leader bonuses
928    # Master in-game clock
946    » time_of_day
949    » village_darkness
960    » torches_lit
963    # Village siege state (autoload-owned so assaults resolve while the player
1001   # Village mage (Orin) downed/respawn state
1016   # Construction-material drops (the repair economy)
1023   » _has_inventory
1026   » roll_construction_drop
1038   » grant_construction_bundle
1052   » wizard_is_down
1057   » wizard_down_progress
1063   » mark_wizard_down
1066   » clear_wizard_down
1093   » building_clear_progress
1096   » building_is_cleared
1106   » blacksmith_unlocked
1111   » building_build_stage
1126   » restore_all_buildings
1143   » building_level
1146   # BUILDING POWERS (dev law 2026-07-29)
1179   # LEADER POWERS (dev law 2026-07-29)
1195   » has_leader_power
1205   » _sounding_material
1229   » has_building_power
1238   » building_power_staffed
1245   » building_power_name
1250   # ADJACENCY SYNERGY
1273   # AURAS (roadmap Phase 4)
1307   » villager_places
1327   » in_aura
1340   » aura_reach
1349   # SPECIAL PLOTS (roadmap Phase 3)
1397   » plot_for_building
1404   » plot_at
1414   » building_plot
1418   » on_home_plot
1422   » plot_bonus
1427   # DISTRICTS (roadmap Phase 2)
1466   » district_at
1485   » building_district
1489   » in_home_district
1493   » district_bonus
1509   » refresh_layout
1544   » adjacency_links
1561   » adjacency_bonus
1585   » building_condition
1601   » building_output_multiplier
1606   # DELETED BUILDINGS (dev 2026-07-22 building menu: "player can delete these
1612   » building_removed
1615   » remove_building
1639   » restore_building
1648   » remove_cottage
1689   » register_cottage
1699   » cottage_id_at
1705   » remove_placed_wall
1717   # RAISING BUILDINGS FROM THE MENU (dev 2026-07-22: build from B with a holo)
1728   » build_cost
1741   » can_afford_build
1749   » pay_build
1779   » can_place_building
1846   # THE OPENING TUTORIAL (step-gated, dev polish 2026-07-22)
1861   » tutorial_begin
1879   » tutorial_note
1894   # THE RAMPART (dev ask 2026-07-22: "make WALLS bigger... with gate,
1916   » wall_max_health
1923   » wall_defense_bonus
1926   » wall_trap_dps
1929   » wall_station_capacity
1933   » wall_upgrade_cost
1938   » can_afford_wall_upgrade
1949   » try_upgrade_wall
1992   » _mint_birth_id
1996   # THE VILLAGE LOG (GAME_BIBLE 5.9)
2009   » log_event
2020   # HOUSING (GAME_BIBLE 5.8)
2058   » villager_name
2064   » villager_home_id
2073   » kid_is_housed
2097   » _couple_expecting
2103   » update_cottage_families
2160   » effective_roll_weights
2175   » roll_regular_stat
2191   » _ready
2204   # Audio: a "Master" (Volume) bus and a dedicated "Music" bus routed into it,
2211   » setup_audio
2225   » apply_master_volume
2235   » apply_music_volume
2243   » set_master_volume
2248   » set_music_volume
2253   » save_audio_settings
2259   » _process
2279   » skip_hours
2282   » tick_village_clock
2323   # HIDDEN EVENT BOSSES (2026-07-28)
2338   » arm_hidden_events
2344   » note_kill
2347   » note_harvest_swing
2353   » note_gold_spent
2357   » note_floor_cleared_event
2360   » on_player_died_event
2371   » on_event_boss_killed
2385   » _event_stage_free
2397   » tick_hidden_events
2421   » _event_condition_met
2448   » _fire_event
2457   # THE ECLIPSE (dev design 2026-08-06)
2486   » eclipse_is_active
2493   » hours_since_eclipse
2499   » eclipse_progress
2505   » tick_eclipse
2538   » hours_until_time_of_day
2542   » eclipse_is_pending
2546   » is_true_eclipse
2549   # Item-summoned events (Nihil's Duskmoon rite, the Master's Horn, and every
2553   » summon_event_boss
2581   » _spawn_summoned
2592   » _sun_moon_both_up
2598   # the capstone: a lifetime record of which hidden bosses have ever fallen
2606   » hidden_hunt_entries
2621   » hidden_hunt_slain_count
2628   » _note_capstone_kill
2644   # subtle ambient omens (no text): a faint tell as the player nears a trigger
2647   » _tick_event_omen
2660   » _event_omen_progress
2671   # Siege scheduling + resolution (runs in every scene)
2673   » current_siege_tier
2714   » deep_truly_empty
2717   » feast_ready
2734   » arrival_shield_on
2742   » begin_arrival_shield
2747   » orin_arrived
2752   # THE PATROLS (dev design 2026-07-30)
2794   » block_of_floor
2797   » block_floor_range
2802   » block_is_cleared
2809   » block_creep_of
2812   » patrol_at
2815   » posted_warriors
2822   » warriors_available_to_post
2825   » post_patrol
2845   » first_fallen_block
2851   » floor_is_road_blocked
2855   # THE MUSTER RUNS ITSELF (automation ladder, floor 65)
2872   » warchief_holds_the_deep
2877   » garrison_needed
2888   » _warchief_posts_the_watch
2902   » tick_patrols
2921   » _block_falls
2948   » _patrol_earnings
2984   » _patrol_find_gear
3010   » village_defense_power
3081   » warrior_count
3090   # DAY/NIGHT SHIFTS (GAME_BIBLE 7.3)
3099   » hour_of_day
3107   » warrior_shift
3110   » on_duty_shift
3114   » warrior_on_duty
3117   » on_duty_warrior_count
3126   » in_shift_change_window
3133   » tick_sieges
3170   » is_black_tide_number
3173   » next_siege_is_black_tide
3178   » tick_black_tide_omen
3188   » trigger_siege
3220   » tick_tide_table
3234   » tick_deep_catches
3259   # FISHING (renewability pillar 3, dev-chosen 2026-07-28)
3277   » fishing_quest_oddity
3280   » tick_fishing
3314   » fishing_turn_in
3335   # THE REAVER CARAVAN (renewability pillar 2, dev-chosen 2026-07-28)
3359   » caravan_tier
3362   » tick_caravans
3388   » trigger_caravan
3400   » resolve_caravan_offline
3414   » grant_reaver_cache
3442   # THE WEEPING HOUR (night event, dev-chosen 2026-07-28)
3468   » weeping_eligible
3479   » tick_weeping
3501   » start_weeping
3514   » end_weeping
3540   # THE LANTERN NIGHT (festival event, 2026-07-28)
3558   » lantern_eligible
3569   » tick_lantern
3594   » start_lantern
3616   » end_lantern
3632   » _away_line_summary
3658   » resolve_siege_offline
3735   » on_live_siege_ended
3754   » consume_away_report
3761   » is_building_operational
3769   # Food & hunger (Step 1: the hunger loop)
3809   » food_capacity
3813   » has_food
3818   » food_consumption_per_hour
3828   » farm_worker_count
3839   » food_production_per_hour
3856   » dock_worker_count
3866   » food_days_remaining
3873   » village_is_starving
3878   » manual_harvest_food
3885   # THE VILLAGE FOG (dev decision 2026-07-20): distance is ignorance
3894   » has_telepathy
3905   » has_communicator
3909   » try_build_whisperstone
3928   » _cost_text
3934   » village_presence
3942   » village_info_available
3948   » notify
3959   » tick_food
3989   # Villager needs & morale
3995   » is_villager_paired
4011   » villager_needs
4031   » villager_morale
4041   # Village-wide morale (0-100 internally, shown to the player as X/10)
4066   » count_adults
4073   # PERSONAL MORALE (GAME_BIBLE 5.5b)
4087   » personal_morale_target
4175   » get_personal_morale
4180   » tick_personal_morale
4193   » _tick_solitude_clock
4208   » village_morale
4226   » admin_nudge_morale
4230   » village_morale_10
4250   » register_villager_deaths
4277   » register_villagers_added
4283   » all_buildings_operational
4289   » update_morale_meter_unlock
4294   » village_morale_multiplier
4297   # Morale consequences (rewards & punishments)
4317   # THE FADING OF DEEPWOOD (dev ask 2026-07-22): the village dying is a felt,
4332   # CORRUPTION (GAME_BIBLE 10): despair made mechanical, v2
4364   » is_warrior_villager
4369   » tick_rot
4418   » _spread_infection
4443   » on_wall_broken
4448   # FIRE (dev design 2026-08-06)
4477   » fire_count
4480   » building_is_burning
4484   » _fire_suppression
4490   » tick_fire
4511   » _fire_day
4561   » _fire_guts
4576   » _resync_building_node
4581   # THE SICKNESS (dev design 2026-08-06)
4605   # TWO STRAINS (dev ruling 2026-08-06)
4640   # the late strain
4646   # IMMUNITY: THE THING THAT LETS AN OUTBREAK END
4672   » villager_is_immune
4676   » _grant_immunity
4683   » sick_count
4686   » plague_count
4689   » villager_has_plague
4693   » plague_is_possible
4696   » villager_is_sick
4701   » _can_sicken
4728   » _lives_touch
4739   » _home_x
4756   » _share_a_workplace
4760   » tick_sickness
4796   » _sickness_day
4880   » _begin_outbreak
4911   » _reap_the_sick
4948   » get_villager_hp
4953   » hospital_treat_rate
4959   » village_in_despair
4963   » village_despair_depth
4970   » _despair_rate
4975   » tick_morale_effects
5097   » notify_urgent
5105   » tick_village_peril
5133   » _on_village_emptied
5145   » rescue_pool_open
5161   » is_important_figure
5176   » _trigger_village_lost
5183   » _show_village_lost_screen
5227   » transform_villager_to_demon
5255   » _spawn_demon_at
5277   » morale_defense_multiplier
5282   » morale_birth_multiplier
5287   # High-morale rewards (the carrot)
5291   » morale_high_factor
5296   » morale_speed_bonus
5301   » morale_regen_per_sec
5308   » village_is_celebrating
5317   » tick_village_tribute
5326   » grant_village_tribute
5336   » count_workers
5348   » generate_passive_income
5404   # AUTOSAVE (polish 2026-07-20)
5413   » autosave
5431   # "WHAT NOW?" (polish 2026-07-20)
5437   » next_objective
5475   # ONE-SHOT SFX (polish pass 2026-07-20)
5485   » play_sfx
5508   # BLUEPRINTS (GAME_BIBLE 5.2, dev decision 2026-07-20)
5522   » has_blueprint
5529   » grant_blueprint
5538   # MOVABLE BUILDINGS (GAME_BIBLE 5.2, dev decision 2026-07-20)
5550   # THE MINE (GAME_BIBLE 5.7, decided 2026-07-20 delegated)
5558   » tick_mine_yield
5616   » tick_wood_gathering
5634   # THE SHRINE (GAME_BIBLE 10, decided 2026-07-20 delegated)
5643   » shrine_unlocked
5646   » shrine_ready
5649   » try_cleanse
5671   # THE WATCHTOWER (GAME_BIBLE 7.1, decided 2026-07-20 delegated)
5685   » watchtower_warning_hours
5689   » siege_clock_visible
5694   » tick_watchtower_warning
5712   # THE WANDERER'S POST (GAME_BIBLE 5.6a)
5761   » grade_rank
5767   » marketplace_merchant_staffed
5770   » tick_wanderers
5788   » _wanderer_dwell_hours
5794   » _wanderer_pool
5806   » _wanderer_price
5822   » _wanderer_arrive
5879   » wanderer_price_now
5888   » buy_from_wanderer
5916   » tick_wages
5976   » count_leader_holders
5983   » get_village_income_multiplier
5986   » get_gestation_speed_multiplier
5990   » get_school_graduation_speed_multiplier
6002   » get_barracks_graduation_speed_multiplier
6008   # LEADERSHIP AUTOMATION
6031   # THE SUPPLY CHAIN (City Machine pillar A, dev call 2026-07-29)
6049   » _add_to_store
6069   » research_yield_multiplier
6073   # THE DOMESTIC AUTOMATIONS (the automation ladder, dev law 2026-07-29)
6092   » donate_to_stores
6106   # LODGING (dev design 2026-07-30)
6117   » cottage_occupant_ids
6128   » cottage_is_pair
6132   » cottage_lone_occupant
6137   » _seeking_home
6153   » house_unpaired_adults
6189   » pair_housemates
6208   » free_cottage_ids
6218   » _next_cottage_x
6245   » auto_build_cottage
6273   » auto_pair_couples
6292   # THE VILLAGE TREASURY (City Machine, B-slice: "the Bank pays")
6301   # Barracks armory
6312   » arm_value_of
6316   » armed_warriors
6320   » forgemaster_supplying
6324   » deposit_one_arm
6352   » seated_leaders
6361   » apply_leadership_automation
6441   » auto_staff_villagers
6454   » reseat_mismatched_workers
6476   » try_auto_place
6502   » role_capacity
6508   » auto_research
6529   » auto_sell_surplus
6554   » auto_sell_village_surplus
6567   » auto_heal_villagers
6577   # THE SCHOOLING POLICY (dev design 2026-07-30)
6596   » schooling_is_delegated
6605   » chancellor_wants_warriors
6613   » next_schooling_destination
6630   » _advance_intake
6633   » auto_enroll_children
6695   » auto_repair_one
6764   » _auto_mend_one
6792   » _finish_repair_stage
6803   # VILLAGE SELF-SUFFICIENCY (the time economy, dev vision 2026-07-22)
6815   » chore_domains
6865   » village_self_sufficiency
6882   » tick_self_sufficiency
6894   » find_available_parents
6915   » start_pairing
6931   » update_mating_houses
6952   » update_pregnancies
6964   » produce_child
6996   » remove_npc_avatar
7001   # School / Barracks enrollment
7003   # THE TEN (GAME_BIBLE §8)
7010   # THE HARVEST (GAME_BIBLE 9.3)
7021   # THE SHADOW COURT (GAME_BIBLE 11)
7027   » begin_harvest
7046   » raise_shadow_army
7065   » settle_shadow_court
7081   # NG+ (GAME_BIBLE 11): THE REWOUND HOUR
7111   » rewind_world_keep_player
7133   # THE CHRONICLE (GAME_BIBLE 11): the 100% ledger
7139   » chronicle
7212   » chronicle_check_complete
7223   » new_game_plus
7239   » break_the_cycle
7247   # THE FINALE GATE (GAME_BIBLE 9.1)
7252   » count_ruined_buildings
7260   » count_empty_role_slots
7275   » finale_gate_missing
7289   » finale_gate_open
7292   » ensure_the_ten
7297   » ten_freed
7301   » count_ten_freed
7309   » all_ten_freed
7312   » free_one_of_the_ten
7354   # The Doctor's escalating heal (GAME_BIBLE 5.5a)
7365   » doctor_heal_price
7368   » doctor_alive
7374   # HOSPITAL PAID HEALING (4.1 enforcement, dev-chosen 2026-07-28)
7384   » hospital_heal_available
7387   » hospital_heal_price
7392   » hospital_heal
7416   » _migrate_starting_civilians
7436   » decay_doctor_price
7446   » enroll_villager
7467   » update_school_enrollments
7482   » graduate_villager
7515   » load_deepest_level
7522   » record_level_reached
7533   » reset_for_new_game
7772   » has_save
7776   » save_game
7975   » load_game
8373   » delete_save
8379   » rescue_villager
8391   # Villager bonds (personal quests)
8396   » quest_event
8423   » find_villager_by_id
8431   » villager_quest_ready
8455   » turn_in_villager_quest
8478   » is_villager_rescued
8484   » assign_villager_to_role
8510   » remove_villager_by_id
8558   » remove_random_villager
8581   » report_death_toll
8605   » remove_one_skill_material
```

### boss.gd (5172 lines)
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
1020   # REACTIVE MECHANICS
1025   # 
1144   # phase (Obito)
1160   » _time_now
1163   # reactive mechanic behaviours
1168   » _player_is_meleeing
1175   » _do_sidestep
1197   » _do_riposte
1220   » riposte_damage
1224   » _do_rhythm_counter
1248   » _ward_side
1271   » _hit_from_behind
1278   # ticked mechanics
1282   » tick_tether
1327   » _sight_to_player_blocked
1336   » _drop_tether
1343   » tick_famine
1355   » tick_traps
1364   » _plant_trap
1405   » tick_mirror
1423   » living_twins
1427   » tick_false_twin
1436   » _do_false_split
1465   » _build_true_shadow
1480   » living_rune_adds
1484   » tick_soulbind
1503   » _bind_runes
1532   » _update_rune_links
1543   » _clear_rune_links
1550   » _spawn_soulbind_feed
1570   » _reflect
1632   » tick_skyfall
1654   » tick_covenant
1684   # THE SOUL SPLIT (GAME_BIBLE 9.5)
1695   » is_final_monarch
1698   » in_mortal_window
1701   » on_soul_split_wand
1716   » _spawn_split_joke
1749   » stagger_threshold
1752   » _spawn_block_label
1756   » _spawn_guard_spark
1772   » is_phased
1777   » _spawn_phase_whiff
1796   » tick_phase
1807   » enter_phase
1818   » _refresh_phase_visual
1862   # wizard combo state (real wizard only; see WIZARD_COMBOS / drive_wizard)
1868   » _ready
1874   » configure_from_def
2003   » build_shard_aura
2007   » _make_shard
2032   » build_aura
2100   » process_passives
2143   » blink_short
2151   # procedural creature rigs
2164   » build_rig
2190   # Skinned bosses (PixelLab)
2193   » _build_boss_sprite
2210   » _update_boss_anim
2226   » _on_boss_anim_finished
2241   » _play_boss_ability_anim
2258   » _build_wizard_ground_aura
2306   » _rp
2314   » _rc
2321   » _rl
2331   » _rskull
2340   » rig_gravewarden
2358   » rig_frost
2370   » rig_cinder
2387   » rig_weaver
2405   » rig_stormcaller
2422   » rig_void
2436   » rig_seraph
2448   » rig_leviathan
2468   » rig_eclipse
2492   » rig_wizard
2514   » _wizard_void_face
2521   » _ember_block
2538   » get_display_name
2541   » _physics_process
2655   » process_hover
2667   » arena_width
2679   » effective_speed
2685   » choose_attack
2703   # The Fallen Wizard's active combo brain (level 100 only)
2770   » combo_length_for
2779   » is_wizard_boss
2784   » is_combo_boss
2789   » active_combos
2814   » drive_wizard
2844   » _orphan_abilities
2858   » _combat_drift
2871   » _drive_profile
2973   » combo_step_gap
2980   » combo_recovery_time
2988   » pick_combo_index
2999   » run_combo
3029   » run_ability
3080   » _combo_charge
3088   » _combo_dive
3096   » start_attack
3142   » set_cd
3145   » cooldown_mult
3160   » current_player_role
3170   » trigger_counter_mechanic
3186   # abilities
3188   » do_slam
3203   » do_charge
3216   » process_charge
3240   » do_barrage
3256   » do_nova
3270   » do_rain
3295   » do_teleport
3323   » do_summon
3357   » do_pillars
3386   # apex abilities
3390   » do_dive
3396   » process_dive
3422   » do_volley
3435   » do_meteors
3462   » do_vortex
3487   » do_beam
3528   » do_curse
3550   » do_doomring
3575   » allowed_clones
3579   » living_clones
3583   » do_clone
3614   # SIGNATURE ABILITIES (BOSSES.md §6)
3617   » spawn_hazard
3631   » _player_in
3636   » do_grave_grasp
3654   » do_rime_lance
3678   » do_magma_wake
3697   » do_web_snare
3716   » do_thunderstrike
3738   » do_void_rift
3767   » do_dissonant_scream
3793   » do_prayer_pyre
3814   » do_iron_maiden
3833   » do_pounce
3861   » do_splinter_burst
3880   » do_keening
3898   » do_ambush
3924   » do_impale
3951   » do_pincer_lunge
3981   » do_eruption
4005   » do_refraction
4031   » do_riposte_stance
4040   » _do_parry_counter
4049   » do_judgment
4077   » do_tidal_crush
4107   » do_black_sun
4127   » do_unwriting
4147   » _make_wall
4158   » _point_near_ray
4166   » _spawn_beam_line
4179   » _spawn_cone
4195   » _zone_marker
4207   # ability helpers
4209   » spawn_arrow
4220   » deal_player_damage
4232   » knockback_player_away
4240   » shake_camera
4244   » spawn_ring_telegraph
4276   » _raze_ground_at
4290   » spawn_shockwave
4307   » spawn_ground_marker
4320   » erupt_pillar
4334   # combat / lifecycle
4336   » check_bump
4359   » flash_telegraph
4381   » apply_petrify
4387   » take_damage
4509   » enrage
4517   # PHASE TWO
4586   » phase_two
4604   » _apply_phase_two
4785   » tick_phase_two
4900   # phase-two helpers
4902   » _ground_y_here
4909   » _hatch_egg_later
4927   » _grief_pulse_later
4942   » _tick_eye_of_storm
4962   » _tick_one_soul
4982   » _tick_throne_alight
5003   » _tick_drowning
5025   » _mirror_the_player_kit
5040   » frenzy
5066   » apply_knockback
5069   » flash_hit
5076   » play_sfx
5083   » update_health_bar
5095   » _boss_hud_banner
5102   » die
5140   » play_death_animation
5153   » spawn_death_particles
```

### player.gd (8655 lines)
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
1924   » _open_hourglass_choice
1937   » _confirm_shatter_hourglass
1948   » buff_bonus
1957   » skill_cooldown_mult
1971   # Standing torches (G)
1977   » try_place_torch
2008   # Bar morale
2017   » bar_morale_active
2020   » grant_bar_morale
2033   # boss crowd-control on the PLAYER (set by boss signature abilities)
2048   » on_enemy_killed
2068   » apply_slow
2078   # boss crowd-control API (called by boss.gd signature abilities)
2080   » _cc_dur
2083   » apply_stun
2087   » apply_freeze
2091   » apply_root
2095   » apply_disorient
2099   » apply_poison
2110   » apply_pull
2116   » cc_action_locked
2121   » cc_move_locked
2127   » _poison_tick
2145   » clear_crowd_control
2157   » player_slow_mult
2163   » skill_move_speed_mult
2171   » on_equipment_changed
2180   # COMPANIONS (light summoner 2026-07-29): an item CARRIES its companion.
2190   » _reconcile_companions
2289   » summon_slot_budget
2293   » post_budget
2335   » _draw_whip_lash
2393   » _whip_link_colour
2405   » _whip_spark
2428   » whip_crack
2568   » _storm_off_mark
2614   » cast_summon
2655   » plant_post
2687   » _raise_post
2700   » redeploy_posts
2731   » _hud
2734   » update_health_display
2743   # Mana pool
2745   » get_max_mana
2748   » get_mana_regen
2751   » spend_mana
2758   » gain_mana
2765   » build_mana_bar
2798   » update_mana_display
2813   » build_orbs
2857   » update_buff_chips
2893   » update_orbs
2919   » build_player_light
2936   » build_char_shadow
2939   » apply_knockback
2954   » knockback_sign_toward
2963   » _on_spear_tip_hit
2982   » wield_weapon
3023   » select_hotbar_slot
3044   » update_weapon_guard
3071   » set_test_aim
3074   » get_aim_direction
3085   » aim_world_point
3101   # UI input guard (audit fix)
3115   » _try_open_villager_menu
3132   » ui_blocks_world_input
3141   » _tick_dig
3160   » update_weapon_visual
3207   » add_currency
3216   » take_damage
3284   » suffer_lethal
3324   » grant_iframes
3346   » start_invincibility_flash
3357   » stop_invincibility_flash
3363   » die
3423   » drop_currency_on_death
3444   » apply_difficulty_death_penalty
3454   » update_currency_display
3466   » perform_dash
3483   » perform_admin_dash
3504   # THE WUKONG ROADS
3519   # set-souls state (2026-07-29): Deadeye's stillness prime, Temper's stacks
3528   » _stone_guise_floor_key
3536   » enter_stone_guise
3549   » wukong_air_hop_allowed
3557   » somersault_ready
3566   » perform_somersault
3581   » spawn_cloudlet
3599   » tick_wukong
3607   » _tick_pillar_stance
3646   » _tick_deadeye
3665   » _tick_sanctuary
3706   » _tick_hair_clone
3732   » _make_ring
3748   » _unmake_ring
3755   » _physics_process
3952   # Flight (Aetherwing)
3954   » has_flight
3966   » has_wings
3977   » levitate_mana_rate
3983   » has_fall_immunity
3990   » update_flight
4020   # Fall damage
4023   » handle_fall_landing
4031   » apply_fall_damage
4044   » perform_secondary_attack
4055   » cast_percent_burst
4088   » spawn_ruin_burst
4104   # FISHING (pillar 3): the rod's whole grammar
4108   » _rod_fish_action
4128   » _nearest_fish_water
4144   » _tick_fishing
4167   » _fish_strike
4189   » _spawn_bobber
4214   » _fish_cancel
4223   » _clear_bobber
4246   » _foes_within
4260   » _nearest_foe_near
4277   » attack_area_bodies
4310   » singleton_busy
4316   » perform_attack
6099   # Melee combo strings
6116   » combo_length
6138   » combo_finisher_mult
6144   » combo_is_live
6150   » combo_step
6161   » reset_combo
6167   » update_combo_label
6189   # Per-weapon crit character
6193   » weapon_crit_chance_bonus
6199   » weapon_crit_damage_bonus
6211   » _slash_texture
6218   » spawn_swing_trail
6380   » weapon_grade_rank
6386   » grade_force_mult
6393   » grade_projectile_girth
6395   » grade_projectile_range
6398   » swing_slash_config
6452   » unleash_court
6506   » call_the_daybreak
6534   # 
6543   # 
6552   » fire_with_ghosts
6569   » _tick_ghost_bows
6578   » _sync_ghost_bows
6606   » _make_ghost_bow
6630   » _ghost_arrival_sparks
6656   » loose_shaped_volley
6705   » _shaft
6724   » stats_knockback_min
6727   » stats_knockback_max
6730   » call_the_kings_rain
6765   » _roof_holds_puff
6778   » launch_swing_slash
6799   » launch_projectile
6847   » throw_javelin_volley
6943   » cast_wand_projectile
6978   » cast_storm_tome
7031   » plant_sentry
7053   » staff_reach_mult
7067   » _staff_leaves
7080   » staff_note_swing
7197   # Relic powers (triggered mechanics on equipped relics; see inventory.gd
7206   » _now
7210   » has_relic_power
7222   » relic_power_value
7229   # Relic power effects (see has_relic_power)
7232   # Sage: the channelled beam (skill tree mg_s4b "Focusing Lens")
7246   » has_beam
7249   # A SMALL PERSONAL SUN (crown wand, Last-Prism-kin never 1:1)
7267   » is_prism_weapon
7270   » prism_focus_frac
7273   » stop_prism
7283   » channel_prism
7347   » _build_prism_lines
7358   » _draw_prism_beam
7375   » _draw_prism_core
7403   » beam_peak_mult
7407   » beam_ramp_mult
7410   » stop_beam
7416   » draw_beam
7434   » channel_beam
7501   » apply_omnivamp
7516   # THE BOND'S TWO PROMISES (Bondmaster, read by player.take_damage)
7520   » bond_intercept
7538   » bond_avenge
7575   » find_bond
7583   » rouse_posts
7594   » shepherd_whistle
7618   » oath_dash_to
7644   » heal
7662   » _tick_waymarks
7678   » apply_melee_skills
7739   » reflect_thorns
7753   » spawn_aegis_block
7769   » spawn_phoenix_revive
7787   » spawn_shock_ring
7815   » spawn_ground_quake
7821   » _ground_quake_now
7854   » _unique_impact_point
7864   » on_projectile_hit
7889   » _fell_later
7913   » _toll_mark
7943   » call_a_marcher
7988   » advance_swing_charge
8014   » apply_excellent_effect
8117   # Excellent-weapon hit visuals (all procedural, world-space, self-cleaning)
8126   » spawn_lightning_bolt
8164   » _jagged_points
8180   » spawn_blood_steal
8199   » _circle_points
8207   » spawn_gold_sparks
8233   » spawn_execute_flash
8253   » collapse_singularity
8271   » spawn_singularity_visual
8301   » unleash_ragnarok
8327   » spawn_ragnarok_ring
8344   » spawn_bane_flash
8360   » spawn_chrono_flash
8388   » spawn_echo_ring
8405   » spawn_soul_wisps
8424   » closest_body
8434   » animate_sword
8447   » animate_spear
8474   » animate_bow
8484   » spawn_arrow
8621   » cast_wand
8638   » cast_wand_nuke
```

### dungeon_interior.gd (2783 lines)
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
2497   » roll_gear_drop
2546   » _gear_in_depth
2557   » _gear_unowned
2566   » _give_gear
2578   » register_extra_combatant
2590   » _on_combatant_died
2631   » play_orin_glimpse
2634   # PROVING GROUNDS (admin test arena)
2639   » build_proving_grounds
2700   » _proving_label
2712   » exit_dungeon
2727   » update_level_label
2754   » _straggler_hint
2780   » show_notification
```

### building.gd (2253 lines)
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
426    » sync_from_state
438    » advance_build_stage
452    » play_construction_animation
463    » spawn_build_dust
488    » restore_full
510    » update_name_label
519    » _refresh_rubble
564    » update_prompt
582    # wall torches (auto day/night lighting)
608    » build_torch_layer
669    » position_torches
683    » update_torches
696    » _add_mat
701    » _fire_gradient
707    # villagers at work (visible busy-ness once people are employed here)
733    # attached work-yards
757    » area_world_half
761    » area_offset_x
783    » employed_count
793    » play_door_anim
817    » refresh_workers
890    # attached work-yard props
891    » _a_rect
899    » _a_disc
906    » _a_line
913    # Farm crops (dynamic)
918    » _update_farm_crops
930    » _draw_crop
955    » _spawn_harvest_puff
971    » _spawn_harvest_float
984    » build_work_area
1119   # the Bar's fun music + player morale
1159   » update_bar_music
1175   # upgrades
1177   » can_upgrade
1180   » upgrade_cost
1184   » try_upgrade
1200   » effective_slots
1206   # visuals
1208   » refresh_visual
1232   » build_intact
1295   # shared tiny draw helpers for the named silhouettes
1296   » _disc
1303   » _tri
1306   » _ln
1315   » _lit_col
1318   » _win
1326   » draw_named_building
1352   » _b_government
1372   » _b_school
1389   » _b_farm
1410   » _b_hospital
1428   » _b_barracks
1450   » _b_dock
1473   » _b_lab
1493   » _b_bank
1528   » _b_blacksmith
1559   » _b_tavern
1597   » _b_bar
1650   » market_sections
1653   » _b_market
1680   » _b_builder
1708   » build_half
1722   » build_destroyed
1741   # body / roofs / features
1743   » add_body
1750   » build_roof
1789   » build_feature
1822   » add_pennant
1831   » add_window_grid
1864   » _side_centers
1873   » add_door
1878   » add_cracks
1893   » add_scorch
1908   » add_glow
1923   » add_fire
1958   » build_shine
1969   » flash_body
1976   » spawn_hit_debris
1998   # small draw helpers
2000   » add_poly
2006   » add_rect
2014   » rect_poly
2017   » ruined_body_poly
2027   » circle_poly
2034   # health bar
2036   » build_health_bar
2049   » update_health_bar
2061   # gameplay
2063   » _on_body_entered
2072   » _on_body_exited
2080   » _process
2201   » get_roles
2204   » get_role_holders
2211   » is_role_full
2214   » get_eligible_villagers
2235   » open_assign_ui
2240   » _on_child_produced
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

### inventory.gd (2369 lines)
```
823    # 
829    # 
1424   # TERRARIA-STYLE TOOLTIP (dev ask 2026-07-22)
1570   # 
1663   # 
1706   # 
1713   # 
1834   # tiny drawing primitives (children of the icon ColorRect)
1851   # armour silhouettes, one per equipment slot (tinted to the item colour)
1908   # per-item symbols (drawn in the target's 0..w / 0..h local space)
2088   # fishing icons (pillar 3): a fish, a crate, a rod, a boot
2145   # material symbols (drop-loot that used to render as a flat coloured square)
2203   » _init
2216   » get_count
2225   » add_item
2264   » remove_item
2285   » transfer_to
2301   » transfer_slot
2323   » to_save_data
2334   » can_accept
2342   » from_save_data
```

### main.gd (1936 lines)
```
181    » building_names
239    » _ready
343    » _maybe_begin_feast
372    » show_away_report
417    » generate_village
492    » spawn_presence_layer
500    » spawn_special_plots
512    » building_def
521    » create_building
554    » spawn_placed_torches
563    » spawn_cottage_node
575    » generate_houses
647    » spawn_existing_villager_avatars
700    » _on_village_child_born
732    » arm_arrival_battle
739    » _check_arrival_trigger
774    » _west_wall_x
792    » stage_arrival_battle
838    » trigger_arrival_scene
855    » activate_arrival_combat
862    » _on_arrival_raider_died
904    » _check_arrival_talk
931    » _emerge_arrival_survivors
943    » _stage_arrival_tableau
1016   » _npc_ground_y
1023   » _face_entity
1037   » play_arrival_talk
1075   » _autosave_on_arrival
1078   » stamp_rewound_arrival
1087   » orin_midgame_taunt
1100   » warn_wounded_corps
1121   » build_escape_ward
1143   » _on_escape_attempt
1178   » _spawn_gauntlet_wave
1191   » _on_gauntlet_raider_died
1204   » announce_orin_arrival
1220   » spawn_adventurers
1235   » is_villager_busy_mating
1251   » offscreen_spawn
1263   » find_avatar_spawn_position
1288   » _process
1304   » _unhandled_input
1320   » _toggle_proving_ground
1328   » _open_village_map
1365   » start_music
1383   » _village_is_healthy
1393   » _tick_music
1421   » apply_save_data
1470   » generate_harvestables
1519   » spawn_harvest_node
1536   » generate_grass
1547   » generate_traps
1555   » generate_platform_traps
1579   » place_trap
1584   » generate_mountains
1686   » _extend_ridges_across_world
1721   » fence_the_camera
1729   » fit_sky_to_world
1740   » build_ground_skin
1796   » build_platform_skins
1847   » _tile_top_padding
1859   » generate_mountain_shape
1883   » generate_clouds
1912   » generate_cloud_shape
1926   » spawn_tuft
```

### underdark.gd (1385 lines)
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
329    » _plan_bands
365    » _build_dark_backdrop
378    » _slab
409    » _build_mouth_and_stair
481    » _climbable_platforms
489    » _build_bands
552    » _plan_shafts
582    » _is_vault_segment
588    » _build_shaft_ladders
614    » _slab_with_hole
623    » _seg_at
629    » _brazier
671    # the cave is alive
685    » _build_cave_life
714    » _cl_glow
724    » _cl_mushrooms
746    » _cl_crystals
759    » _cl_moss
767    » _cl_root
777    # the hidden doors
778    » _place_doors
833    # ore seams
834    » _place_seams
855    # streamed cave mobs (the east road's three rules, underground)
856    » _process
867    » _hold_the_dark_lit
876    » _stream_tick
903    » _band_of
906    » _stream
943    » _sector_center
949    » _prune
959    » _populate
989    » live_count
997    # traps, chests, and the rune vaults
998    » _trap
1007   » _stock_chest
1042   » _add_chest
1052   » _place_chests
1071   » _plan_pits
1093   » _build_pits
1134   » spring_ambush
1163   » _build_hidden_lofts
1205   » _build_rune_vaults
1267   » rune_lit
1281   # the arch you walk into
1291   » _build_cave_prompt
1346   » _tick_cave_mouth
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

### assign_ui.gd (1103 lines)
```
6      » _ready
15     » open_for_building
20     » close
25     » esc_is_open
28     » esc_close
31     » refresh
76     » add_market_stall_section
120    » _on_stall_sell
138    » add_relocate_section
162    » add_repair_section
211    » _on_repair
232    » add_upgrade_section
389    » _on_upgrade
407    » add_research_section
461    » _on_build_whisperstone
469    » _on_research
497    » smithy_max_rank
500    » smithy_stock
542    » smithy_imports
571    » add_ward_section
587    » _on_ward_heal
605    » smithy_price
608    » add_smithy_section
627    » _on_buy_gear
650    » add_dock_section
684    » _on_fishing_turn_in
695    » add_armory_section
752    » add_stores_section
806    » add_schooling_section
851    » _on_set_school_share
862    » _on_donate_store
878    » add_patrol_section
950    » _on_patrol_change
954    » _on_deposit_arm
974    » add_role_section
1024   » _empty_seat
1038   » _villager_seat
1066   » _tint_seat
1076   » _on_assign
```

### day_night_cycle.gd (769 lines)
```
132    » _ready
154    » sync_from_master
167    » make_additive_material
172    » build_sun
191    » build_sun_highlight
201    » build_sun_rays
215    » setup_moon_glow_materials
227    » update_moon_glow_shape
245    » generate_moon_craters
277    » max_crater_radius_at
293    » is_point_in_moon_phase
305    » is_crater_fully_in_phase
316    » update_moon_craters
332    » build_moon_sky_glow
340    » build_circle
348    » build_moon_phase
368    » pick_new_moon_phase
386    » _process
398    » handle_debug_time_input
413    » get_darkness_factor
422    » is_night
425    » get_sun_progress
431    » get_moon_progress
444    » is_sun_moon_overlap
464    » get_parallax_anchor_x
473    » arc_position
478    » update_visuals
533    # THE RING (dev design 2026-08-06)
579    » _build_eclipse_ring
600    » _update_eclipse_ring
649    » _eclipse_sky_pos
679    » update_sun_eclipse
714    » counter_color
722    » update_moon_true_colors
764    » update_clock_label
```
