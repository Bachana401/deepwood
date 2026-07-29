# Deepwood — Codemap

_Navigation index for fast lookup. Regenerate with `bash gen_codemap.sh`. Line numbers drift as code changes — treat as approximate anchors, confirm with a read._

`118` game scripts, ~55798 LOC. Generated 2026-07-29.

## File directory

| script | lines | purpose (first header comment) |
|--------|------:|--------------------------------|
| admin_panel.gd | 299 | One-stop dev/testing console, toggled with P. Every "OP" testing action lives |
| adventurer.gd | 756 | A living adventurer defending Deepwood (GAME_BIBLE 2.4.1). Persistent between |
| adventurer_rescue.gd | 72 | A chained adventurer awaiting rescue in the dungeon (the deep nine of |
| adventurers.gd | 100 | The twelve adventurers (GAME_BIBLE §2.4.1 "The three defenders" + the deep |
| arrival_weather.gd | 59 | THE ARRIVAL STORM (start-scene fix, 2026-07-21). The dev's canon asked for |
| arrow.gd | 220 | (no header comment) |
| assign_ui.gd | 831 | (no header comment) |
| blueprint_pickup.gd | 57 | A BLUEPRINT SATCHEL (GAME_BIBLE 5.2): the plans for one village building, |
| boss.gd | 5095 | Dungeon boss. |
| boss_hud.gd | 192 | WUKONG-STYLE BOSS SPECTACLE (dev ask 2026-07-22). Makes every boss an EVENT: |
| build_menu.gd | 260 | THE BUILDER'S LEDGER (B key; dev request 2026-07-21). |
| build_placer.gd | 435 | THE BUILDER'S HAND (dev 2026-07-22). Raise a building from the B menu with a |
| building.gd | 2230 | (no header comment) |
| building_hitbox.gd | 15 | Buildings are Area2D nodes (for the Press-E proximity), which enemy arrows |
| building_lights.gd | 317 | Breathes life into the painted facades WITHOUT touching the approved art: |
| building_roles.gd | 111 | Role definitions per building (keyed by the building's role_key, e.g. |
| camera_shake.gd | 22 | (no header comment) |
| char_shadow.gd | 44 | Preloaded as a const by its users (const CHAR_SHADOW = preload(...)) rather than |
| chest.gd | 44 | Unique per-instance id, used as the key into GameState.chest_contents so |
| chest_ui.gd | 319 | The vault racks now hold a GRADE'S whole catalogue (76 rare items after the |
| choice_prompt.gd | 148 | A small modal decision box, styled like the DialogueBox: a title, a body line, |
| companion.gd | 204 | COMPANIONS (task: light summoner, 2026-07-29). No fourth class: a companion |
| currency_pickup.gd | 111 | "1 full in-game day" is defined by the day/night cycle's own day length, |
| day_night_cycle.gd | 514 | (no header comment) |
| death_screen.gd | 76 | main.tscn and dungeon_interior.tscn author the black shade + CountdownLabel by |
| dialogue_box.gd | 409 | A small, reusable conversation box (bottom of screen): a brass name-plate, one |
| dock_bridge.gd | 71 | A walkable wooden crossing spanning the Fishing Dock's water: stairs up, a |
| dps_dummy.gd | 89 | The Proving Grounds training dummy: an invincible target that never dies and |
| drag_state.gd | 277 | Coordinates dragging an item stack between slots -- possibly across two |
| dungeon_gate.gd | 106 | The LEAVE gate on the left of every dungeon floor (see dungeon_interior.gd). |
| dungeon_interior.gd | 2718 | Dungeons are a real separate scene the player is teleported into (see |
| dungeon_manager.gd | 18 | Dungeon combat now happens in a fully separate scene (dungeon_interior.gd) |
| dungeon_sign.gd | 50 | (no header comment) |
| dungeon_zone.gd | 24 | (no header comment) |
| enemy.gd | 1469 | Dev call 2026-07-21: sight cut 15% (was 225) -- "I don't want them to non |
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
| game_state.gd | 6472 | THE DEV'S REAL SAVE IS NOT A TEST FIXTURE (global hunt 2026-07-28). |
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
| inventory.gd | 2251 | Shared item catalog -- every item type in the game (currency included) is |
| inventory_ui.gd | 352 | Terraria-tight pixel slots (dev ask 2026-07-22): a compact grid of bordered |
| item_tooltip.gd | 94 | A single hover tooltip shared by every item UI (inventory, chest, equipment |
| level_select_ui.gd | 121 | (no header comment) |
| magic_orb.gd | 103 | A slow homing "cursed orb" fired by the Warlock mob (special_mob.gd). It |
| main.gd | 1834 | (no header comment) |
| main_menu.gd | 189 | Whether the fresh-start flow currently in the difficulty picker should wipe |
| material_pickup.gd | 100 | A dropped material on the ground (dev ask 2026-07-22: "materials like in |
| mirror_mage.gd | 113 | THE PLUCKED HAIR (Wukong roads, 2026-07-28): when enemies press the Sage, |
| morale_meter.gd | 181 | Village morale, shown in the TAB overlay directly BELOW the mana bar (kept |
| notification_stack.gd | 32 | Toasts render as BBCode (item-art name-plate pass 2026-07-28): callers can |
| npc.gd | 1392 | Points back at their entry in GameState.rescued_villagers -- info is |
| objective_banner.gd | 97 | A quiet, always-current objective ticker at the top of the VILLAGE screen, so a |
| pause_menu.gd | 262 | (no header comment) |
| player.gd | 5249 | DEV CALL (2026-07-20): the old dash covered 600*0.15 = 90px -- barely |
| playtest_journal.gd | 124 | THE FIELD JOURNAL (built for the 4-5h marathon playtest, 2026-07-21). |
| portal.gd | 74 | ONE RIFT of the Mage's Riftweaving pair (mg_p1..p3, dev request |
| road_marker.gd | 77 | THE ROAD MARKERS (polish 2026-07-20) -- the village and the pit sit |
| roster_ui.gd | 184 | THE ROSTER (polish 2026-07-20) -- every soul in Deepwood on one page. |
| sentry_totem.gd | 98 | THE PLANTED SENTRY (weapons overhaul 2026-07-28, Terraria-sentry-INSPIRED): |
| sfx_synth.gd | 136 | PROCEDURAL CHIPTUNE ONE-SHOTS (audio pass 2026-07-28): the overhaul's |
| shade.gd | 391 | A shade -- a soldier of living shadow in the Shadow Monarch's service |
| shop_ui.gd | 191 | (no header comment) |
| shrine_menu.gd | 150 | The fast-travel menu shared by the village WAYSTONE and every woken DEEP SHRINE |
| shrine_node.gd | 160 | A travel shrine. The village WAYSTONE (is_waystone = true) and every woken DEEP |
| siege_enemy.gd | 620 | A besieger: marches east out of the evil lands toward the village wall and |
| siege_manager.gd | 420 | Presents LIVE sieges while the player is in the village. Scheduling and |
| skill_tree.gd | 262 | Each class is ONE tree that actually BRANCHES. A root trunk splits into 3 |
| skill_tree_ui.gd | 498 | Skill tree window (K to toggle) + the always-visible XP bar. Everything is |
| speaker_indicator.gd | 65 | A small bobbing chevron that hovers over whoever is currently speaking in a |
| special_mob.gd | 2102 | Special dungeon mobs -- the non-humanoid monsters that spice up NORMAL |
| speech_text.gd | 70 | Floating, window-less speech for characters: plain outlined text hovering |
| standing_torch.gd | 117 | A big free-standing brazier torch the player can PLACE anywhere on the ground |
| storm_cloud.gd | 381 | TOME AREA DENIAL (weapons overhaul 2026-07-28, Terraria-spellbook-INSPIRED, |
| story.gd | 183 | Deepwood's scripted story beats, kept in one place (canon: GAME_BIBLE §2/§9, |
| ten_ally.gd | 298 | One of the Ten, fighting beside you at the Harvest (GAME_BIBLE 9.4) -- ten |
| the_ten.gd | 61 | THE TEN (GAME_BIBLE §8) -- the capstone hostages, the truly unbreakable. |
| trap.gd | 88 | (no header comment) |
| trophy_vault.gd | 97 | A Trophy Vault (GAME_BIBLE §8): the gilded cage where Orin keeps one of the |
| tutorial_overlay.gd | 94 | THE INTERACTIVE TUTORIAL CARD (dev 2026-07-22: "show, don't tell"). Instead of a |
| underdark.gd | 1343 | THE UNDERDARK (GAME_BIBLE §4 amendment, dev-decided 2026-07-21). |
| underdark_ambush.gd | 25 | A hidden ambush in a sunken chamber of the deep (underdark.gd _build_pits). |
| underdark_door.gd | 157 | A hidden stone door of the Underdark (GAME_BIBLE §4 amendment). Each one is |
| underdark_rune.gd | 71 | One of three rune stones that unbar a band's vault (underdark.gd). Press E. |
| underground.gd | 1415 | ── THE TERRARIA UNDERGROUND (rework, 2026-07-25) ────────────� |
| underground_pause.gd | 118 | THE CAVE'S PAUSE MENU (scan fix 2026-07-27). |
| vault_chest.gd | 134 | A Proving Grounds vault chest. Unlike a normal loot chest it's a bottomless |
| village_life.gd | 435 | Makes Deepwood feel ALIVE, and rewards the player's progress with spectacle. |
| village_log_ui.gd | 122 | THE VILLAGE LOG (GAME_BIBLE 5.9) -- press L. The village's diary: births, |
| villager.gd | 234 | Unique per-instance id so an already-rescued villager doesn't reappear (and |
| villager_menu.gd | 160 | THE VILLAGER MENU (dev ask 2026-07-27): walk up to a villager, RIGHT-CLICK, and |
| villager_quests.gd | 254 | Two things live here: |
| villager_sheet.gd | 162 | THE VILLAGER SHEET (dev call 2026-07-27). The old way of reading a villager was |
| wall.gd | 385 | The village's west rampart -- the line the siege breaks against. It has no |
| wanderer_ui.gd | 119 | THE WANDERER'S POST counter (GAME_BIBLE 5.6a) -- opened with the hands-on |
| watchtower.gd | 148 | THE WATCHTOWER (GAME_BIBLE 7.1) -- foresight, earned. A standalone |
| weapon_fx.gd | 462 | (dev order 2026-07-28: "all weapons skills and effects and aftereffects |
| weapon_projectile.gd | 1078 | One configurable projectile powering the special-attack weapons (see |
| weapon_roster.gd | 718 | The 350-weapon roster's engine (weapons overhaul wave 2, 2026-07-28). |
| wilderness.gd | 231 | THE EAST ROAD (2026-07-21, dev request). |
| wizard.gd | 886 | ORIN, the stranded village mage. Lore: an adventurer like the player who |
| worker_figure.gd | 373 | A villager-at-work figure, spawned by building.gd when villagers are employed |

## Big-file outlines (sections + functions, with line numbers)

Jump anchors for the files too large to grep comfortably. `#` = section header, `»` = function.

### game_state.gd (6472 lines)
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
124    # Harvest-node persistence (audit fix)
139    » ensure_harvest_seed
152    » test_populate_village
211    # XP / skill tree
225    # Equipment
266    » relic_slot_count
272    » get_equipment_total
280    » item_equip_effect
288    » get_weapon_passive_total
296    » get_bonus_total
299    » get_equipped_item_ids
309    » set_pieces_equipped
318    » is_set_complete
325    » wielded_weapon_id
333    » get_set_bonus_total
352    » equip_item
380    » unequip_slot
405    » first_empty_relic_slot
413    » load_equipment
435    » xp_to_next_level
448    » depth_reward_mult
455    » add_xp
488    # The Shadow Monarch (hidden 7-stage passive, tied to character level)
508    » monarch_stage
517    » monarch_progress
526    » monarch_intensity
531    » monarch_bonus
554    » announce_monarch_awakening
571    » monarch_true_form
580    » get_skill_total
587    » is_skill_unlocked
594    » try_unlock_skill
625    » try_craft
651    » research_all_materials
659    » reset_skills
670    » capture_player_state
727    # Adventurers (GAME_BIBLE 2.4.1)
735    » ensure_adventurers
746    » adventurer_state
750    » rescue_adventurer
760    » kill_adventurer
769    » set_adventurer_station
785    » wall_stationed_count
796    » fighting_adventurers
814    # THE GOLD FAUCETS (GAME_BIBLE 5.6, revised canon 2026-07-17)
835    # Leader bonuses
856    # Master in-game clock
874    » time_of_day
877    » village_darkness
888    » torches_lit
891    # Village siege state (autoload-owned so assaults resolve while the player
923    # Village mage (Orin) downed/respawn state
938    # Construction-material drops (the repair economy)
945    » _has_inventory
948    » roll_construction_drop
960    » grant_construction_bundle
974    » wizard_is_down
979    » wizard_down_progress
985    » mark_wizard_down
988    » clear_wizard_down
1015   » building_clear_progress
1018   » building_is_cleared
1028   » blacksmith_unlocked
1033   » building_build_stage
1048   » restore_all_buildings
1059   » building_level
1062   » building_output_multiplier
1065   # DELETED BUILDINGS (dev 2026-07-22 building menu: "player can delete these
1071   » building_removed
1074   » remove_building
1098   » restore_building
1107   » remove_cottage
1148   » register_cottage
1158   » cottage_id_at
1164   » remove_placed_wall
1176   # RAISING BUILDINGS FROM THE MENU (dev 2026-07-22: build from B with a holo)
1187   » build_cost
1200   » can_afford_build
1208   » pay_build
1238   » can_place_building
1305   # THE OPENING TUTORIAL (step-gated, dev polish 2026-07-22)
1320   » tutorial_begin
1338   » tutorial_note
1353   # THE RAMPART (dev ask 2026-07-22: "make WALLS bigger... with gate,
1375   » wall_max_health
1382   » wall_defense_bonus
1385   » wall_trap_dps
1388   » wall_station_capacity
1392   » wall_upgrade_cost
1397   » can_afford_wall_upgrade
1408   » try_upgrade_wall
1451   » _mint_birth_id
1455   # THE VILLAGE LOG (GAME_BIBLE 5.9)
1468   » log_event
1479   # HOUSING (GAME_BIBLE 5.8)
1517   » villager_name
1523   » villager_home_id
1532   » kid_is_housed
1556   » _couple_expecting
1562   » update_cottage_families
1619   » effective_roll_weights
1634   » roll_regular_stat
1650   » _ready
1663   # Audio: a "Master" (Volume) bus and a dedicated "Music" bus routed into it,
1670   » setup_audio
1684   » apply_master_volume
1694   » apply_music_volume
1702   » set_master_volume
1707   » set_music_volume
1712   » save_audio_settings
1718   » _process
1738   » skip_hours
1741   » tick_village_clock
1774   # HIDDEN EVENT BOSSES (2026-07-28)
1789   » arm_hidden_events
1795   » note_kill
1798   » note_harvest_swing
1804   » note_gold_spent
1808   » note_floor_cleared_event
1811   » on_player_died_event
1822   » on_event_boss_killed
1836   » _event_stage_free
1848   » tick_hidden_events
1872   » _event_condition_met
1899   » _fire_event
1908   # Item-summoned events (Nihil's Duskmoon rite, the Master's Horn, and every
1912   » summon_event_boss
1935   » _spawn_summoned
1946   » _sun_moon_both_up
1952   # the capstone: a lifetime record of which hidden bosses have ever fallen
1960   » hidden_hunt_entries
1975   » hidden_hunt_slain_count
1982   » _note_capstone_kill
1998   # subtle ambient omens (no text): a faint tell as the player nears a trigger
2001   » _tick_event_omen
2014   » _event_omen_progress
2025   # Siege scheduling + resolution (runs in every scene)
2027   » current_siege_tier
2068   » deep_truly_empty
2071   » feast_ready
2088   » arrival_shield_on
2096   » begin_arrival_shield
2101   » orin_arrived
2106   » village_defense_power
2153   » warrior_count
2162   # DAY/NIGHT SHIFTS (GAME_BIBLE 7.3)
2171   » hour_of_day
2179   » warrior_shift
2182   » on_duty_shift
2186   » warrior_on_duty
2189   » on_duty_warrior_count
2198   » in_shift_change_window
2205   » tick_sieges
2242   » is_black_tide_number
2245   » next_siege_is_black_tide
2250   » tick_black_tide_omen
2260   » trigger_siege
2290   » tick_deep_catches
2313   # FISHING (renewability pillar 3, dev-chosen 2026-07-28)
2331   » fishing_quest_oddity
2334   » tick_fishing
2368   » fishing_turn_in
2389   # THE REAVER CARAVAN (renewability pillar 2, dev-chosen 2026-07-28)
2413   » caravan_tier
2416   » tick_caravans
2442   » trigger_caravan
2454   » resolve_caravan_offline
2468   » grant_reaver_cache
2496   # THE WEEPING HOUR (night event, dev-chosen 2026-07-28)
2522   » weeping_eligible
2533   » tick_weeping
2555   » start_weeping
2568   » end_weeping
2594   # THE LANTERN NIGHT (festival event, 2026-07-28)
2612   » lantern_eligible
2623   » tick_lantern
2648   » start_lantern
2670   » end_lantern
2683   » resolve_siege_offline
2731   » on_live_siege_ended
2750   » consume_away_report
2757   » is_building_operational
2765   # Food & hunger (Step 1: the hunger loop)
2803   » food_capacity
2807   » has_food
2812   » food_consumption_per_hour
2822   » farm_worker_count
2833   » food_production_per_hour
2842   » dock_worker_count
2852   » food_days_remaining
2859   » village_is_starving
2864   » manual_harvest_food
2871   # THE VILLAGE FOG (dev decision 2026-07-20): distance is ignorance
2880   » has_telepathy
2891   » has_communicator
2895   » try_build_whisperstone
2914   » _cost_text
2920   » village_presence
2928   » village_info_available
2934   » notify
2945   » tick_food
2963   # Villager needs & morale
2969   » is_villager_paired
2985   » villager_needs
3005   » villager_morale
3015   # Village-wide morale (0-100 internally, shown to the player as X/10)
3040   » count_adults
3047   # PERSONAL MORALE (GAME_BIBLE 5.5b)
3061   » personal_morale_target
3132   » get_personal_morale
3137   » tick_personal_morale
3150   » _tick_solitude_clock
3165   » village_morale
3179   » admin_nudge_morale
3183   » village_morale_10
3203   » register_villager_deaths
3230   » register_villagers_added
3236   » all_buildings_operational
3242   » update_morale_meter_unlock
3247   » village_morale_multiplier
3250   # Morale consequences (rewards & punishments)
3270   # THE FADING OF DEEPWOOD (dev ask 2026-07-22): the village dying is a felt,
3285   # CORRUPTION (GAME_BIBLE 10): despair made mechanical, v2
3317   » is_warrior_villager
3322   » tick_rot
3357   » _spread_infection
3382   » on_wall_broken
3387   » get_villager_hp
3392   » hospital_treat_rate
3398   » village_in_despair
3402   » village_despair_depth
3409   » _despair_rate
3414   » tick_morale_effects
3522   » notify_urgent
3530   » tick_village_peril
3558   » _on_village_emptied
3570   » rescue_pool_open
3586   » is_important_figure
3601   » _trigger_village_lost
3608   » _show_village_lost_screen
3652   » transform_villager_to_demon
3680   » _spawn_demon_at
3702   » morale_defense_multiplier
3707   » morale_birth_multiplier
3712   # High-morale rewards (the carrot)
3716   » morale_high_factor
3721   » morale_speed_bonus
3726   » morale_regen_per_sec
3733   » village_is_celebrating
3742   » tick_village_tribute
3751   » grant_village_tribute
3761   » count_workers
3773   » generate_passive_income
3821   # AUTOSAVE (polish 2026-07-20)
3830   » autosave
3848   # "WHAT NOW?" (polish 2026-07-20)
3854   » next_objective
3892   # ONE-SHOT SFX (polish pass 2026-07-20)
3902   » play_sfx
3925   # BLUEPRINTS (GAME_BIBLE 5.2, dev decision 2026-07-20)
3939   » has_blueprint
3946   » grant_blueprint
3955   # MOVABLE BUILDINGS (GAME_BIBLE 5.2, dev decision 2026-07-20)
3967   # THE MINE (GAME_BIBLE 5.7, decided 2026-07-20 delegated)
3975   » tick_mine_yield
4017   » tick_wood_gathering
4035   # THE SHRINE (GAME_BIBLE 10, decided 2026-07-20 delegated)
4044   » shrine_unlocked
4047   » shrine_ready
4050   » try_cleanse
4072   # THE WATCHTOWER (GAME_BIBLE 7.1, decided 2026-07-20 delegated)
4086   » watchtower_warning_hours
4090   » siege_clock_visible
4095   » tick_watchtower_warning
4113   # THE WANDERER'S POST (GAME_BIBLE 5.6a)
4161   » grade_rank
4167   » marketplace_merchant_staffed
4170   » tick_wanderers
4183   » _wanderer_dwell_hours
4189   » _wanderer_pool
4201   » _wanderer_price
4217   » _wanderer_arrive
4274   » wanderer_price_now
4283   » buy_from_wanderer
4311   » tick_wages
4367   » count_leader_holders
4374   » get_village_income_multiplier
4377   » get_gestation_speed_multiplier
4381   » get_school_graduation_speed_multiplier
4384   » get_barracks_graduation_speed_multiplier
4389   # LEADERSHIP AUTOMATION
4407   # THE SUPPLY CHAIN (City Machine pillar A, dev call 2026-07-29)
4428   » research_yield_multiplier
4431   # THE DOMESTIC AUTOMATIONS (the automation ladder, dev law 2026-07-29)
4450   » donate_to_stores
4464   » free_cottage_ids
4474   » _next_cottage_x
4490   » auto_build_cottage
4515   » auto_pair_couples
4526   # THE VILLAGE TREASURY (City Machine, B-slice: "the Bank pays")
4535   # Barracks armory
4546   » arm_value_of
4550   » armed_warriors
4554   » forgemaster_supplying
4558   » deposit_one_arm
4586   » seated_leaders
4595   » apply_leadership_automation
4645   » auto_staff_villagers
4652   » try_auto_place
4678   » role_capacity
4684   » auto_research
4701   » auto_sell_surplus
4726   » auto_sell_village_surplus
4738   » auto_heal_villagers
4745   » auto_enroll_children
4779   » auto_repair_one
4818   # VILLAGE SELF-SUFFICIENCY (the time economy, dev vision 2026-07-22)
4830   » chore_domains
4872   » village_self_sufficiency
4889   » tick_self_sufficiency
4901   » find_available_parents
4922   » start_pairing
4938   » update_mating_houses
4959   » update_pregnancies
4971   » produce_child
5003   » remove_npc_avatar
5008   # School / Barracks enrollment
5010   # THE TEN (GAME_BIBLE §8)
5017   # THE HARVEST (GAME_BIBLE 9.3)
5028   # THE SHADOW COURT (GAME_BIBLE 11)
5034   » begin_harvest
5053   » raise_shadow_army
5072   » settle_shadow_court
5088   # NG+ (GAME_BIBLE 11): THE REWOUND HOUR
5118   » rewind_world_keep_player
5140   # THE CHRONICLE (GAME_BIBLE 11): the 100% ledger
5146   » chronicle
5219   » chronicle_check_complete
5230   » new_game_plus
5246   » break_the_cycle
5254   # THE FINALE GATE (GAME_BIBLE 9.1)
5259   » count_ruined_buildings
5267   » count_empty_role_slots
5282   » finale_gate_missing
5296   » finale_gate_open
5299   » ensure_the_ten
5304   » ten_freed
5308   » count_ten_freed
5316   » all_ten_freed
5319   » free_one_of_the_ten
5361   # The Doctor's escalating heal (GAME_BIBLE 5.5a)
5372   » doctor_heal_price
5375   » doctor_alive
5381   # HOSPITAL PAID HEALING (4.1 enforcement, dev-chosen 2026-07-28)
5391   » hospital_heal_available
5394   » hospital_heal_price
5399   » hospital_heal
5423   » _migrate_starting_civilians
5443   » decay_doctor_price
5453   » enroll_villager
5474   » update_school_enrollments
5489   » graduate_villager
5522   » load_deepest_level
5528   » record_level_reached
5539   » reset_for_new_game
5747   » has_save
5751   » save_game
5913   » load_game
6227   » delete_save
6233   » rescue_villager
6245   # Villager bonds (personal quests)
6250   » quest_event
6277   » find_villager_by_id
6285   » villager_quest_ready
6309   » turn_in_villager_quest
6332   » is_villager_rescued
6338   » assign_villager_to_role
6364   » remove_villager_by_id
6412   » remove_random_villager
6435   » report_death_toll
6459   » remove_one_skill_material
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

### player.gd (5249 lines)
```
37     # Fall damage
54     # Flight (Aetherwing relic)
75     # Mana
147    # Aiming
160    » get_weapon_stats
163    » has_weapon
233    # FISHING (pillar 3, 2026-07-28): cast / bite / strike
337    » _ready
402    » maybe_play_intro
422    » grant_starter_weapons
436    » ensure_test_items
481    » ensure_admin_wand
494    » ensure_flight_relics_for_test
509    » grant_starter_gear
517    # worn-gear visuals (helmet / chest / pants overlays on the body)
521    » build_armor_visuals
548    » update_armor_visuals
561    » _apply_armor_piece
573    » build_weapon_guard
611    » update_weapon_sprite
640    # The Shadow Monarch aura (hidden 7-stage passive, see GameState)
653    » build_shadow_aura
728    » update_shadow_aura
798    # THE SHADOW MONARCH'S POWERS
827    » monarch_tick
866    » _apply_true_form
897    » can_raise_shades
900    » raise_shade
926    » _rebalance_shades
938    » shade_defend_share
943    » fire_shadow_nova
966    » apply_fear_aura
987    » enter_long_dark
1021   » build_wings_visual
1029   » _make_wing
1039   » update_wings
1056   » setup_body_anim
1080   » build_sprite_frames
1103   » load_frames_for
1119   » refresh_monarch_skin
1167   » _hooded_art_present
1171   » _ascended_art_present
1178   » load_texture
1200   » opaque_bounds
1221   » load_image_smart
1239   » _add_anim
1251   » current_anim_state
1280   » feet_anchor_y
1288   » update_body_anim
1356   » spawn_dash_afterimage
1377   » apply_pending_player_state
1404   » play_sfx
1411   » play_event_omen
1425   # combat/economy effect hooks. get_bonus_total = skill tree + worn gear
1428   » get_max_health
1432   » skill_damage_mult
1478   # Crit
1484   » get_crit_chance
1487   » get_crit_damage
1492   » roll_crit
1503   » force_crit
1507   # ARMOR SET-SOULS (2026-07-29, Terraria-kin set mechanics): a completed
1510   » set_soul_active
1515   » apply_soulthread
1526   » show_hit
1536   » spawn_hit_spark
1581   » hit_stop
1587   » _process
1594   » _exit_tree
1600   » _impact_feedback
1605   # Timed buffs (from food). active_buffs[key] = {"v": amount, "until": t}.
1608   # RIFTWEAVING (Mage, mg_p1..p3): the two doors, Z to weave
1620   » has_portal_skill
1625   » portal_open_cost
1630   » portal_drain_per_second
1635   » try_weave_portal
1658   » tick_portals
1670   » close_portals
1686   » try_plant_building
1755   » do_portal_teleport
1765   » add_buff
1770   » use_item
1857   » _open_hourglass_choice
1870   » _confirm_shatter_hourglass
1881   » buff_bonus
1890   » skill_cooldown_mult
1900   # Standing torches (G)
1906   » try_place_torch
1930   # Bar morale
1939   » bar_morale_active
1942   » grant_bar_morale
1955   # boss crowd-control on the PLAYER (set by boss signature abilities)
1970   » on_enemy_killed
1990   » apply_slow
2000   # boss crowd-control API (called by boss.gd signature abilities)
2002   » _cc_dur
2005   » apply_stun
2009   » apply_freeze
2013   » apply_root
2017   » apply_disorient
2021   » apply_poison
2032   » apply_pull
2038   » cc_action_locked
2043   » cc_move_locked
2049   » _poison_tick
2067   » clear_crowd_control
2079   » player_slow_mult
2085   » skill_move_speed_mult
2093   » on_equipment_changed
2101   # COMPANIONS (light summoner 2026-07-29): an item CARRIES its companion.
2109   » _reconcile_companions
2139   » update_health_display
2144   # Mana pool
2146   » get_max_mana
2149   » get_mana_regen
2152   » spend_mana
2159   » gain_mana
2166   » build_mana_bar
2199   » update_mana_display
2214   » build_orbs
2258   » update_buff_chips
2294   » update_orbs
2320   » build_player_light
2337   » build_char_shadow
2340   » apply_knockback
2355   » knockback_sign_toward
2361   » _on_spear_tip_hit
2379   » wield_weapon
2420   » select_hotbar_slot
2441   » update_weapon_guard
2454   » get_aim_direction
2463   » aim_world_point
2477   # UI input guard (audit fix)
2491   » _try_open_villager_menu
2508   » ui_blocks_world_input
2517   » _tick_dig
2536   » update_weapon_visual
2578   » add_currency
2587   » take_damage
2647   » suffer_lethal
2687   » grant_iframes
2709   » start_invincibility_flash
2720   » stop_invincibility_flash
2726   » die
2786   » drop_currency_on_death
2807   » apply_difficulty_death_penalty
2817   » update_currency_display
2826   » perform_dash
2843   » perform_admin_dash
2864   # THE WUKONG ROADS
2879   # set-souls state (2026-07-29): Deadeye's stillness prime, Temper's stacks
2888   » _stone_guise_floor_key
2896   » enter_stone_guise
2909   » wukong_air_hop_allowed
2917   » somersault_ready
2926   » perform_somersault
2941   » spawn_cloudlet
2959   » tick_wukong
2967   » _tick_pillar_stance
3006   » _tick_deadeye
3025   » _tick_sanctuary
3066   » _tick_hair_clone
3092   » _make_ring
3108   » _unmake_ring
3115   » _physics_process
3301   # Flight (Aetherwing)
3303   » has_flight
3315   » has_wings
3326   » levitate_mana_rate
3332   » has_fall_immunity
3339   » update_flight
3369   # Fall damage
3372   » handle_fall_landing
3380   » apply_fall_damage
3393   » perform_secondary_attack
3404   » cast_percent_burst
3437   » spawn_ruin_burst
3453   # FISHING (pillar 3): the rod's whole grammar
3457   » _rod_fish_action
3477   » _nearest_fish_water
3493   » _tick_fishing
3516   » _fish_strike
3538   » _spawn_bobber
3563   » _fish_cancel
3572   » _clear_bobber
3577   » perform_attack
3785   # Melee combo strings
3802   » combo_length
3824   » combo_finisher_mult
3830   » combo_is_live
3836   » combo_step
3847   » reset_combo
3853   » update_combo_label
3875   # Per-weapon crit character
3879   » weapon_crit_chance_bonus
3885   » weapon_crit_damage_bonus
3897   » _slash_texture
3904   » spawn_swing_trail
4018   » weapon_grade_rank
4024   » grade_force_mult
4031   » grade_projectile_girth
4033   » grade_projectile_range
4036   » swing_slash_config
4083   » launch_swing_slash
4099   » launch_projectile
4142   » throw_javelin_volley
4161   » cast_wand_projectile
4193   » cast_storm_tome
4243   » plant_sentry
4265   » staff_reach_mult
4275   » staff_note_swing
4332   # Relic powers (triggered mechanics on equipped relics; see inventory.gd
4341   » _now
4345   » has_relic_power
4357   » relic_power_value
4364   # Relic power effects (see has_relic_power)
4367   # Sage: the channelled beam (skill tree mg_s4b "Focusing Lens")
4381   » has_beam
4384   » beam_peak_mult
4388   » beam_ramp_mult
4391   » stop_beam
4397   » draw_beam
4415   » channel_beam
4482   » apply_omnivamp
4493   » apply_melee_skills
4554   » reflect_thorns
4568   » spawn_aegis_block
4584   » spawn_phoenix_revive
4602   » spawn_shock_ring
4625   » _unique_impact_point
4635   » on_projectile_hit
4648   » advance_swing_charge
4674   » apply_excellent_effect
4777   # Excellent-weapon hit visuals (all procedural, world-space, self-cleaning)
4786   » spawn_lightning_bolt
4824   » _jagged_points
4840   » spawn_blood_steal
4859   » _circle_points
4867   » spawn_gold_sparks
4893   » spawn_execute_flash
4913   » collapse_singularity
4931   » spawn_singularity_visual
4961   » unleash_ragnarok
4987   » spawn_ragnarok_ring
5004   » spawn_bane_flash
5020   » spawn_chrono_flash
5048   » spawn_echo_ring
5065   » spawn_soul_wisps
5084   » closest_body
5094   » animate_sword
5107   » animate_spear
5122   » animate_bow
5132   » spawn_arrow
5215   » cast_wand
5232   » cast_wand_nuke
```

### dungeon_interior.gd (2718 lines)
```
388    » _ready
431    » setup_exit_button
437    » start_music
459    » music_pitch_for
468    # layout selection
470    » get_layout_slot
473    » is_boss_level
477    » get_layout
483    # REGULAR FLOOR LAYOUTS
505    » get_regular_theme
508    » generate_regular_layout
527    # reachable primitives
529    » _ledge
535    » _stack
548    » _span_with_access
558    # the twelve themes
560    » _theme_terraces
573    » _theme_isles
584    » _theme_pillared_hall
594    » _theme_chasm_bridges
603    » _theme_overwatch
610    » _theme_gauntlet
625    » _theme_twin_towers
631    » _theme_amphitheatre
643    » _theme_roost
655    » _theme_warren
666    » _theme_sunken_court
675    » _theme_cascade
690    » total_boss_levels
701    » get_boss_id
719    » get_boss_counter
730    » build_counter_sequence
744    » get_boss_arena
747    » get_level_width
752    » get_level_ceiling
757    # boss arena platform generators
767    » generate_boss_platforms
801    » add_sky_tier
816    » gen_gravewarden
838    » gen_frost
860    » gen_cinder
884    » gen_weaver
908    » gen_stormcaller
931    » gen_void
951    # the deep (35-90)
962    » gen_hollow_choir
997    » gen_ashen_penitent
1039   » gen_gaoler
1073   » gen_sablefang
1099   » gen_effigy
1122   » gen_mourncaller
1148   » gen_unseen
1169   » gen_warden_of_nails
1200   » gen_twin_despair
1222   » gen_cinderking
1250   » gen_glass_saint
1276   » gen_last_man
1299   # apex arena generators
1305   » gen_seraph
1335   » gen_leviathan
1351   » gen_eclipse
1380   » gen_wizard
1398   # level (re)building
1400   » build_level_visuals
1430   » build_floor_surprises
1447   » _dgn_cache
1465   » _dgn_hazard
1470   » build_gates
1485   » on_gate_used
1492   » go_to_level
1498   » build_background
1526   » build_wall_layer
1553   » build_ground_and_walls
1581   » build_wall
1600   » build_platforms
1627   » build_stalactites
1644   » build_cave_life
1692   » _glow_sprite
1702   » _mushroom_cluster
1724   » _crystal_cluster
1738   » _moss_patch
1746   » _ceiling_root
1757   » make_additive_material
1765   » _ensure_ambient
1773   » build_torches
1803   » build_torch
1856   » place_mines
1885   » place_hazards
1923   » place_mine
1928   » place_player_at_entry
1941   » _place_deep_shrine
1964   # combat flow (mirrors the old overworld dungeon_manager.gd)
1968   » _softcapped_mult
1973   » get_level_scaling
1980   » spawn_level_combat
2046   » play_empty_throne
2057   » play_final_victory
2093   » spawn_deep_rescue
2143   # normal-level mob composition
2169   » block_position
2172   » op_pool_for_level
2181   » _op_band
2189   » op_fraction
2196   » spawn_level_mobs
2225   » pick_random_subset
2230   » spawn_kind
2241   » spawn_special_mob
2264   » _physics_process
2273   » spawn_enemy
2310   » assign_enemy_behavior
2322   » spawn_boss
2354   » get_material_for_level
2367   » roll_material_drop
2382   # Gear loot
2432   » roll_gear_drop
2481   » _gear_in_depth
2492   » _gear_unowned
2501   » _give_gear
2513   » register_extra_combatant
2525   » _on_combatant_died
2566   » play_orin_glimpse
2569   # PROVING GROUNDS (admin test arena)
2574   » build_proving_grounds
2635   » _proving_label
2647   » exit_dungeon
2662   » update_level_label
2689   » _straggler_hint
2715   » show_notification
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

### enemy.gd (1469 lines)
```
103    # WILDERNESS MOBS (the lands east of the village)
147    # Status effects (see apply_status). burn/poison = damage-over-time,
171    # Behavior archetype (mechanics beyond plain melee/bow). Set by spawn:
181    » _now_s
184    » move_speed
187    » status_slow_mult
195    » is_frozen
200    » apply_status
240    » is_petrified
243    » tick_statuses
266    » _refresh_status_overlay
313    » _pick_prey
332    » _retarget
343    » _ready
364    » update_body_color
369    » play_sfx
381    » apply_block_archetype
389    » apply_mixed_archetype
412    » build_character
464    » _add_skull
473    » _add_socket
476    » _add_shoulders
483    » _add_poly
489    » _add_dot
497    # Spritesheet-skinned enemies (downloaded art)
501    » _build_sprite_visual
539    » _update_enemy_anim
552    » setup_weapon_visual
568    » get_aim_direction
575    » update_weapon_icon_position
587    » _physics_process
721    » try_jump
733    » count_nearby_enemies
745    » check_bump
765    » _melee_connects
772    » try_attack
792    » finish_attack
796    » try_deal_melee_damage
816    » _telegraph_weapon
821    » animate_sword_attack
835    » animate_spear_attack
850    » animate_bow_attack
863    » _loose_arrow
873    # Behavior archetypes
881    » set_behavior
907    # SUPER-MOB (elite) presence + signature slam
927    » _become_super_mob
950    » _tick_elite_slam
966    » _elite_slam
976    » _spawn_slam_ring
995    » _elite_shockwave
1018   » _spawn_shock_burst
1040   » process_behavior
1067   » _living_allies
1079   » heal_nearby_allies
1099   » summon_minions
1126   » cast_hex_bolt
1141   » perform_lunge
1156   » show_gold_mark
1163   » spawn_block_spark
1167   » spawn_status_spark
1189   » is_split
1192   » on_soul_split_wand
1213   » take_damage
1247   » apply_knockback
1262   » flash_hit
1276   » update_health_bar
1282   » die
1350   » play_death_animation
1367   » spawn_death_particles
1407   » spawn_coin_popup
1444   » spawn_material_popup
```

### inventory.gd (2251 lines)
```
793    # 
801    # 
1345   # TERRARIA-STYLE TOOLTIP (dev ask 2026-07-22)
1478   # 
1571   # 
1614   # 
1621   # 
1741   # tiny drawing primitives (children of the icon ColorRect)
1758   # armour silhouettes, one per equipment slot (tinted to the item colour)
1815   # per-item symbols (drawn in the target's 0..w / 0..h local space)
1995   # fishing icons (pillar 3): a fish, a crate, a rod, a boot
2052   # material symbols (drop-loot that used to render as a flat coloured square)
2096   » _init
2109   » get_count
2118   » add_item
2157   » remove_item
2178   » transfer_to
2194   » transfer_slot
2216   » to_save_data
2227   » can_accept
2235   » from_save_data
```

### main.gd (1834 lines)
```
178    » building_names
236    » _ready
340    » _maybe_begin_feast
369    » show_away_report
414    » generate_village
478    » building_def
487    » create_building
520    » spawn_placed_torches
529    » spawn_cottage_node
541    » generate_houses
613    » spawn_existing_villager_avatars
666    » _on_village_child_born
698    » arm_arrival_battle
705    » _check_arrival_trigger
740    » _west_wall_x
758    » stage_arrival_battle
804    » trigger_arrival_scene
821    » activate_arrival_combat
828    » _on_arrival_raider_died
870    » _check_arrival_talk
897    » _emerge_arrival_survivors
909    » _stage_arrival_tableau
982    » _npc_ground_y
989    » _face_entity
1003   » play_arrival_talk
1041   » _autosave_on_arrival
1044   » stamp_rewound_arrival
1053   » orin_midgame_taunt
1066   » warn_wounded_corps
1087   » build_escape_ward
1109   » _on_escape_attempt
1144   » _spawn_gauntlet_wave
1157   » _on_gauntlet_raider_died
1170   » announce_orin_arrival
1186   » spawn_adventurers
1201   » is_villager_busy_mating
1217   » offscreen_spawn
1229   » find_avatar_spawn_position
1254   » _process
1263   » start_music
1281   » _village_is_healthy
1291   » _tick_music
1319   » apply_save_data
1368   » generate_harvestables
1417   » spawn_harvest_node
1434   » generate_grass
1445   » generate_traps
1453   » generate_platform_traps
1477   » place_trap
1482   » generate_mountains
1584   » _extend_ridges_across_world
1619   » fence_the_camera
1627   » fit_sky_to_world
1638   » build_ground_skin
1694   » build_platform_skins
1745   » _tile_top_padding
1757   » generate_mountain_shape
1781   » generate_clouds
1810   » generate_cloud_shape
1824   » spawn_tuft
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

### assign_ui.gd (831 lines)
```
6      » _ready
11     » open_for_building
16     » close
21     » esc_is_open
24     » esc_close
27     » refresh
69     » add_market_stall_section
113    » _on_stall_sell
131    » add_relocate_section
155    » add_repair_section
204    » _on_repair
225    » add_upgrade_section
256    » _on_upgrade
274    » add_research_section
328    » _on_build_whisperstone
336    » _on_research
364    » smithy_max_rank
367    » smithy_stock
409    » smithy_imports
438    » add_ward_section
454    » _on_ward_heal
472    » smithy_price
475    » add_smithy_section
494    » _on_buy_gear
517    » add_dock_section
551    » _on_fishing_turn_in
562    » add_armory_section
619    » add_stores_section
669    » _on_donate_store
682    » _on_deposit_arm
702    » add_role_section
752    » _empty_seat
766    » _villager_seat
794    » _tint_seat
804    » _on_assign
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
