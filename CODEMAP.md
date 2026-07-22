# Deepwood — Codemap

_Navigation index for fast lookup. Regenerate with `bash gen_codemap.sh`. Line numbers drift as code changes — treat as approximate anchors, confirm with a read._

`98` game scripts, ~38619 LOC. Generated 2026-07-22.

## File directory

| script | lines | purpose (first header comment) |
|--------|------:|--------------------------------|
| admin_panel.gd | 289 | One-stop dev/testing console, toggled with P. Every "OP" testing action lives |
| adventurer.gd | 606 | A living adventurer defending Deepwood (GAME_BIBLE 2.4.1). Persistent between |
| adventurer_rescue.gd | 69 | A chained adventurer awaiting rescue in the dungeon (the deep nine of |
| adventurers.gd | 100 | The twelve adventurers (GAME_BIBLE §2.4.1 "The three defenders" + the deep |
| arrival_weather.gd | 59 | THE ARRIVAL STORM (start-scene fix, 2026-07-21). The dev's canon asked for |
| arrow.gd | 182 | (no header comment) |
| assign_ui.gd | 519 | (no header comment) |
| blueprint_pickup.gd | 57 | A BLUEPRINT SATCHEL (GAME_BIBLE 5.2): the plans for one village building, |
| boss.gd | 3989 | Dungeon boss. |
| build_menu.gd | 242 | THE BUILDER'S LEDGER (B key; dev request 2026-07-21). |
| building.gd | 2234 | (no header comment) |
| building_hitbox.gd | 15 | Buildings are Area2D nodes (for the Press-E proximity), which enemy arrows |
| building_lights.gd | 303 | Breathes life into the painted facades WITHOUT touching the approved art: |
| building_roles.gd | 111 | Role definitions per building (keyed by the building's role_key, e.g. |
| camera_shake.gd | 15 | (no header comment) |
| chest.gd | 44 | Unique per-instance id, used as the key into GameState.chest_contents so |
| chest_ui.gd | 274 | (no header comment) |
| cottage_plot.gd | 109 | The empty plot at the end of the cottage row (GAME_BIBLE 5.8): housing is |
| currency_pickup.gd | 99 | "1 full in-game day" is defined by the day/night cycle's own day length, |
| day_night_cycle.gd | 501 | (no header comment) |
| death_screen.gd | 41 | The cost of dying, said ON the black screen itself -- the toast version |
| dialogue_box.gd | 113 | A small, reusable conversation box (bottom of screen): speaker name + one line, |
| dock_bridge.gd | 70 | A walkable wooden crossing spanning the Fishing Dock's water: stairs up, a |
| dps_dummy.gd | 89 | The Proving Grounds training dummy: an invincible target that never dies and |
| drag_state.gd | 196 | Coordinates dragging an item stack between slots -- possibly across two |
| dungeon_gate.gd | 106 | The LEAVE gate on the left of every dungeon floor (see dungeon_interior.gd). |
| dungeon_interior.gd | 2443 | Dungeons are a real separate scene the player is teleported into (see |
| dungeon_manager.gd | 18 | Dungeon combat now happens in a fully separate scene (dungeon_interior.gd) |
| dungeon_sign.gd | 50 | (no header comment) |
| dungeon_zone.gd | 24 | (no header comment) |
| enemy.gd | 1396 | Dev call 2026-07-21: sight cut 15% (was 225) -- "I don't want them to non |
| enemy_skins.gd | 196 | Shared skin builder for downloaded/generated character art. Originally for |
| equipment_ui.gd | 388 | Equipment panel, pinned to the RIGHT side of the screen (kept clear of the |
| farm_animal.gd | 221 | A small BLOCKY, pixel-styled farm animal (chicken / pig / cow / sheep) that |
| farm_pen.gd | 73 | A fenced pasture beside the Farm. Draws the fence + a dirt patch and spawns a |
| floating_text.gd | 75 | Shared floating combat text -- a damage number that rises, drifts, and fades |
| food_readout.gd | 93 | Always-visible village food gauge, top-left HUD, tucked just under the mana |
| game_state.gd | 4003 | Deepest dungeon level ever reached in a single run -- a high-score style |
| harvest_director.gd | 309 | THE HARVEST, AT HOME (new finale canon, 2026-07-20). |
| harvest_node.gd | 232 | A harvestable world node: a TREE (chop with the Woodsman's Axe) or a ROCK |
| hazard.gd | 277 | CREATIVE DUNGEON HAZARDS (dev report 2026-07-21: "no creative traps"). Beyond |
| hazard_zone.gd | 61 | A lingering ground hazard dropped by a boss signature ability and then left to |
| homing_bolt.gd | 41 | A slow homing projectile — the Mourncaller's Keening wisps, and reusable for |
| hotbar_ui.gd | 76 | Bottom-of-screen hotbar showing the first 10 inventory slots (keys 1-9, 0). |
| house.gd | 162 | (no header comment) |
| how_to_play.gd | 117 | HOW TO PLAY -- the controls and the laws, one readable page, opened from |
| inventory.gd | 1337 | Shared item catalog -- every item type in the game (currency included) is |
| inventory_ui.gd | 294 | tallest the bag may get in UI units -- the base viewport is 648 high, so this |
| item_tooltip.gd | 69 | A single hover tooltip shared by every item UI (inventory, chest, equipment |
| level_select_ui.gd | 106 | (no header comment) |
| magic_orb.gd | 102 | A slow homing "cursed orb" fired by the Warlock mob (special_mob.gd). It |
| main.gd | 1294 | (no header comment) |
| main_menu.gd | 185 | Whether the fresh-start flow currently in the difficulty picker should wipe |
| morale_meter.gd | 170 | Village morale, shown in the TAB overlay directly BELOW the mana bar (kept |
| notification_stack.gd | 25 | (no header comment) |
| npc.gd | 1086 | Points back at their entry in GameState.rescued_villagers -- info is |
| objective_banner.gd | 64 | A quiet, always-current objective ticker at the top of the VILLAGE screen, so a |
| pause_menu.gd | 207 | (no header comment) |
| player.gd | 3807 | DEV CALL (2026-07-20): the old dash covered 600*0.15 = 90px -- barely |
| playtest_journal.gd | 106 | THE FIELD JOURNAL (built for the 4-5h marathon playtest, 2026-07-21). |
| portal.gd | 74 | ONE RIFT of the Mage's Riftweaving pair (mg_p1..p3, dev request |
| road_marker.gd | 77 | THE ROAD MARKERS (polish 2026-07-20) -- the village and the pit sit |
| roster_ui.gd | 184 | THE ROSTER (polish 2026-07-20) -- every soul in Deepwood on one page. |
| shade.gd | 357 | A shade -- a soldier of living shadow in the Shadow Monarch's service |
| shop_sign.gd | 94 | (no header comment) |
| shop_stall.gd | 129 | THE SHOP HAD NO SHOP (dev call 2026-07-21). It was a floating "SHOP" sign |
| shop_ui.gd | 178 | (no header comment) |
| shop_zone.gd | 28 | (no header comment) |
| shrine_menu.gd | 127 | The fast-travel menu shared by the village WAYSTONE and every woken DEEP SHRINE |
| shrine_node.gd | 160 | A travel shrine. The village WAYSTONE (is_waystone = true) and every woken DEEP |
| siege_enemy.gd | 492 | A besieger: marches east out of the evil lands toward the village wall and |
| siege_manager.gd | 232 | Presents LIVE sieges while the player is in the village. Scheduling and |
| skill_tree.gd | 246 | Each class is ONE tree that actually BRANCHES. A root trunk splits into 3 |
| skill_tree_ui.gd | 464 | Skill tree window (K to toggle) + the always-visible XP bar. Everything is |
| special_mob.gd | 1048 | Special dungeon mobs -- the non-humanoid monsters that spice up NORMAL |
| speech_text.gd | 69 | Floating, window-less speech for characters: plain outlined text hovering |
| standing_torch.gd | 117 | A big free-standing brazier torch the player can PLACE anywhere on the ground |
| story.gd | 156 | Deepwood's scripted story beats, kept in one place (canon: GAME_BIBLE §2/§9, |
| ten_ally.gd | 112 | One of the Ten, fighting beside you at the Harvest (GAME_BIBLE 9.4) -- ten |
| the_ten.gd | 61 | THE TEN (GAME_BIBLE §8) -- the capstone hostages, the truly unbreakable. |
| trap.gd | 82 | (no header comment) |
| trophy_vault.gd | 94 | A Trophy Vault (GAME_BIBLE §8): the gilded cage where Orin keeps one of the |
| underdark.gd | 1065 | THE UNDERDARK (GAME_BIBLE §4 amendment, dev-decided 2026-07-21). |
| underdark_ambush.gd | 25 | A hidden ambush in a sunken chamber of the deep (underdark.gd _build_pits). |
| underdark_door.gd | 106 | A hidden stone door of the Underdark (GAME_BIBLE §4 amendment). Each one is |
| underdark_rune.gd | 71 | One of three rune stones that unbar a band's vault (underdark.gd). Press E. |
| vault_chest.gd | 134 | A Proving Grounds vault chest. Unlike a normal loot chest it's a bottomless |
| village_life.gd | 348 | Makes Deepwood feel ALIVE, and rewards the player's progress with spectacle. |
| village_log_ui.gd | 122 | THE VILLAGE LOG (GAME_BIBLE 5.9) -- press L. The village's diary: births, |
| villager.gd | 198 | Unique per-instance id so an already-rescued villager doesn't reappear (and |
| villager_quests.gd | 240 | Two things live here: |
| wall.gd | 195 | The village's west rampart -- the line the siege breaks against. It has no |
| wanderer_ui.gd | 93 | THE WANDERER'S POST counter (GAME_BIBLE 5.6a) -- opened with the hands-on |
| watchtower.gd | 144 | THE WATCHTOWER (GAME_BIBLE 7.1) -- foresight, earned. A standalone |
| weapon_projectile.gd | 302 | One configurable projectile powering the special-attack weapons (see |
| wilderness.gd | 209 | THE EAST ROAD (2026-07-21, dev request). |
| wizard.gd | 876 | ORIN, the stranded village mage. Lore: an adventurer like the player who |
| worker_figure.gd | 371 | A villager-at-work figure, spawned by building.gd when villagers are employed |

## Big-file outlines (sections + functions, with line numbers)

Jump anchors for the files too large to grep comfortably. `#` = section header, `»` = function.

### game_state.gd (4003 lines)
```
26     » floor_is_cleared
29     » mark_floor_cleared
46     » is_shrine_floor
49     » shrine_revealed
52     » revealed_shrines
73     » load_game_completed
76     » mark_game_completed
85     # DEV / TEST MODE
114    » test_populate_village
169    # XP / skill tree
183    # Equipment
206    » relic_slot_count
215    » get_equipment_total
223    » item_equip_effect
231    » get_weapon_passive_total
239    » get_bonus_total
242    » get_equipped_item_ids
252    » set_pieces_equipped
261    » is_set_complete
268    » wielded_weapon_id
276    » get_set_bonus_total
295    » equip_item
323    » unequip_slot
340    » first_empty_relic_slot
348    » load_equipment
358    » xp_to_next_level
371    » depth_reward_mult
378    » add_xp
408    # The Shadow Monarch (hidden 7-stage passive, tied to character level)
428    » monarch_stage
437    » monarch_progress
446    » monarch_intensity
451    » monarch_bonus
474    » announce_monarch_awakening
491    » monarch_true_form
500    » get_skill_total
507    » is_skill_unlocked
514    » try_unlock_skill
545    » try_craft
563    » research_all_materials
571    » reset_skills
582    » capture_player_state
622    # Adventurers (GAME_BIBLE 2.4.1)
630    » ensure_adventurers
641    » adventurer_state
645    » rescue_adventurer
655    » kill_adventurer
664    » set_adventurer_station
671    » fighting_adventurers
689    # THE GOLD FAUCETS (GAME_BIBLE 5.6, revised canon 2026-07-17)
709    # Leader bonuses
730    # Master in-game clock
748    » time_of_day
751    » village_darkness
762    » torches_lit
765    # Village siege state (autoload-owned so assaults resolve while the player
780    # Village mage (Orin) downed/respawn state
795    # Construction-material drops (the repair economy)
802    » _has_inventory
805    » roll_construction_drop
817    » grant_construction_bundle
827    » wizard_is_down
832    » wizard_down_progress
838    » mark_wizard_down
841    » clear_wizard_down
867    » building_clear_progress
870    » building_is_cleared
880    » blacksmith_unlocked
885    » building_build_stage
900    » restore_all_buildings
911    » building_level
914    » building_output_multiplier
940    » _mint_birth_id
944    # THE VILLAGE LOG (GAME_BIBLE 5.9)
957    » log_event
968    # HOUSING (GAME_BIBLE 5.8)
979    » villager_name
985    » villager_home_id
994    » kid_is_housed
1008   » _couple_expecting
1014   » update_cottage_families
1066   » effective_roll_weights
1081   » roll_regular_stat
1097   » _ready
1110   # Audio: a "Master" (Volume) bus and a dedicated "Music" bus routed into it,
1117   » setup_audio
1131   » apply_master_volume
1135   » apply_music_volume
1142   » set_master_volume
1147   » set_music_volume
1152   » save_audio_settings
1158   » _process
1178   » skip_hours
1181   » tick_village_clock
1205   # Siege scheduling + resolution (runs in every scene)
1207   » current_siege_tier
1242   » deep_truly_empty
1245   » feast_ready
1262   » arrival_shield_on
1270   » begin_arrival_shield
1275   » orin_arrived
1280   » village_defense_power
1314   » warrior_count
1323   # DAY/NIGHT SHIFTS (GAME_BIBLE 7.3)
1332   » hour_of_day
1335   » warrior_shift
1338   » on_duty_shift
1342   » warrior_on_duty
1345   » on_duty_warrior_count
1354   » in_shift_change_window
1361   » tick_sieges
1380   » trigger_siege
1399   » tick_deep_catches
1418   » resolve_siege_offline
1462   » on_live_siege_ended
1481   » consume_away_report
1488   » is_building_operational
1491   # Food & hunger (Step 1: the hunger loop)
1521   » food_capacity
1525   » has_food
1529   » food_consumption_per_hour
1533   » farm_worker_count
1544   » food_production_per_hour
1553   » dock_worker_count
1563   » food_days_remaining
1570   » village_is_starving
1575   » manual_harvest_food
1582   # THE VILLAGE FOG (dev decision 2026-07-20): distance is ignorance
1591   » has_telepathy
1594   » village_presence
1602   » village_info_available
1608   » notify
1619   » tick_food
1637   # Villager needs & morale
1643   » is_villager_paired
1659   » villager_needs
1679   » villager_morale
1689   # Village-wide morale (0-100 internally, shown to the player as X/10)
1709   » count_adults
1716   # PERSONAL MORALE (GAME_BIBLE 5.5b)
1730   » personal_morale_target
1773   » get_personal_morale
1778   » tick_personal_morale
1787   » village_morale
1801   » admin_nudge_morale
1805   » village_morale_10
1821   » register_villager_deaths
1847   » register_villagers_added
1853   » all_buildings_operational
1859   » update_morale_meter_unlock
1864   » village_morale_multiplier
1867   # Morale consequences (rewards & punishments)
1879   # CORRUPTION (GAME_BIBLE 10): despair made mechanical, v2
1911   » is_warrior_villager
1916   » tick_rot
1947   » _spread_infection
1972   » on_wall_broken
1977   » get_villager_hp
1980   » village_in_despair
1984   » village_despair_depth
1991   » _despair_rate
1996   » tick_morale_effects
2092   » transform_villager_to_demon
2120   » _spawn_demon_at
2137   » morale_defense_multiplier
2142   » morale_birth_multiplier
2147   # High-morale rewards (the carrot)
2151   » morale_high_factor
2156   » morale_speed_bonus
2161   » morale_regen_per_sec
2168   » village_is_celebrating
2177   » tick_village_tribute
2186   » grant_village_tribute
2196   » count_workers
2208   » generate_passive_income
2241   # AUTOSAVE (polish 2026-07-20)
2250   » autosave
2268   # "WHAT NOW?" (polish 2026-07-20)
2274   » next_objective
2312   # ONE-SHOT SFX (polish pass 2026-07-20)
2322   » play_sfx
2345   # BLUEPRINTS (GAME_BIBLE 5.2, dev decision 2026-07-20)
2359   » has_blueprint
2362   » grant_blueprint
2371   # MOVABLE BUILDINGS (GAME_BIBLE 5.2, dev decision 2026-07-20)
2383   # THE MINE (GAME_BIBLE 5.7, decided 2026-07-20 delegated)
2391   » tick_mine_yield
2416   # THE SHRINE (GAME_BIBLE 10, decided 2026-07-20 delegated)
2425   » shrine_unlocked
2428   » shrine_ready
2431   » try_cleanse
2452   # THE WATCHTOWER (GAME_BIBLE 7.1, decided 2026-07-20 delegated)
2466   » watchtower_warning_hours
2470   » siege_clock_visible
2475   » tick_watchtower_warning
2487   # THE WANDERER'S POST (GAME_BIBLE 5.6a)
2507   » grade_rank
2513   » marketplace_merchant_staffed
2516   » tick_wanderers
2529   » _wanderer_dwell_hours
2535   » _wanderer_pool
2547   » _wanderer_price
2560   » _wanderer_arrive
2584   » wanderer_price_now
2593   » buy_from_wanderer
2621   » tick_wages
2653   » count_leader_holders
2660   » get_village_income_multiplier
2663   » get_gestation_speed_multiplier
2667   » get_school_graduation_speed_multiplier
2670   » get_barracks_graduation_speed_multiplier
2675   # LEADERSHIP AUTOMATION
2693   # Barracks armory
2704   » arm_value_of
2708   » armed_warriors
2712   » forgemaster_supplying
2716   » deposit_one_arm
2732   » seated_leaders
2739   » apply_leadership_automation
2775   » auto_staff_villagers
2782   » try_auto_place
2801   » auto_research
2810   » auto_sell_surplus
2825   » auto_heal_villagers
2832   » auto_enroll_children
2847   » auto_repair_one
2865   » find_available_parents
2880   » start_pairing
2896   » update_mating_houses
2917   » update_pregnancies
2929   » produce_child
2961   » remove_npc_avatar
2966   # School / Barracks enrollment
2968   # THE TEN (GAME_BIBLE §8)
2975   # THE HARVEST (GAME_BIBLE 9.3)
2983   # THE SHADOW COURT (GAME_BIBLE 11)
2989   » begin_harvest
3008   » raise_shadow_army
3021   » settle_shadow_court
3025   # NG+ (GAME_BIBLE 11): THE REWOUND HOUR
3041   » rewind_world_keep_player
3063   # THE CHRONICLE (GAME_BIBLE 11): the 100% ledger
3069   » chronicle
3142   » chronicle_check_complete
3153   » new_game_plus
3164   # THE FINALE GATE (GAME_BIBLE 9.1)
3169   » count_ruined_buildings
3177   » count_empty_role_slots
3192   » finale_gate_missing
3206   » finale_gate_open
3209   » ensure_the_ten
3214   » ten_freed
3218   » count_ten_freed
3226   » all_ten_freed
3229   » free_one_of_the_ten
3271   # The Doctor's escalating heal (GAME_BIBLE 5.5a)
3282   » doctor_heal_price
3285   » doctor_alive
3296   » _migrate_starting_civilians
3316   » decay_doctor_price
3326   » enroll_villager
3342   » update_school_enrollments
3357   » graduate_villager
3390   » load_deepest_level
3396   » record_level_reached
3407   » reset_for_new_game
3543   » has_save
3546   » save_game
3639   » load_game
3788   » delete_save
3792   » rescue_villager
3803   # Villager bonds (personal quests)
3808   » quest_event
3830   » find_villager_by_id
3838   » villager_quest_ready
3854   » turn_in_villager_quest
3872   » is_villager_rescued
3878   » assign_villager_to_role
3904   » remove_villager_by_id
3944   » remove_random_villager
3966   » report_death_toll
3990   » remove_one_skill_material
```

### boss.gd (3989 lines)
```
3      # 
15     # 
60     # shared ability tuning
108    # apex ability tuning (the level 35+ monsters)
145    # the Fallen Wizard's passives & doomring
155    # SIGNATURE abilities (BOSSES.md §6): one distinct move per boss, spread
197    # deep tier signatures (floors 35-60)
226    # deep tier signatures (floors 65-90)
267    # Statuses on bosses: DoT yes, hard CC no.
284    » apply_status
304    » boss_status_slow_mult
311    » tick_statuses
330    # apex tier signatures (floors 95-100)
384    # weapon counter (set per boss level by dungeon_interior.gd)
446    # The Fallen Wizard's combo book (level 100 only)
784    # REACTIVE MECHANICS
789    # 
908    # phase (Obito)
924    » _time_now
927    # reactive mechanic behaviours
932    » _player_is_meleeing
939    » _do_sidestep
961    » _do_riposte
984    » riposte_damage
988    » _do_rhythm_counter
1000   » _hit_from_behind
1007   # ticked mechanics
1011   » tick_tether
1056   » _sight_to_player_blocked
1065   » _drop_tether
1072   » tick_famine
1084   » tick_traps
1092   » _plant_trap
1122   » tick_mirror
1140   » living_twins
1144   » tick_false_twin
1153   » _do_false_split
1173   » _build_true_shadow
1188   » living_rune_adds
1192   » tick_soulbind
1211   » _bind_runes
1236   » _update_rune_links
1247   » _clear_rune_links
1254   » _spawn_soulbind_feed
1270   » _reflect
1304   » tick_skyfall
1326   » tick_covenant
1352   # THE SOUL SPLIT (GAME_BIBLE 9.5)
1363   » is_final_monarch
1366   » in_mortal_window
1369   » on_soul_split_wand
1384   » _spawn_split_joke
1417   » stagger_threshold
1420   » _spawn_block_label
1424   » _spawn_guard_spark
1440   » is_phased
1445   » _spawn_phase_whiff
1464   » tick_phase
1475   » enter_phase
1482   » _refresh_phase_visual
1519   # wizard combo state (real wizard only; see WIZARD_COMBOS / drive_wizard)
1525   » _ready
1531   » configure_from_def
1632   » build_shard_aura
1636   » _make_shard
1661   » build_aura
1729   » process_passives
1772   » blink_short
1780   # procedural creature rigs
1793   » build_rig
1819   # Skinned bosses (PixelLab)
1822   » _build_boss_sprite
1839   » _update_boss_anim
1855   » _on_boss_anim_finished
1870   » _play_boss_ability_anim
1887   » _build_wizard_ground_aura
1926   » _rp
1934   » _rc
1941   » _rl
1951   » _rskull
1960   » rig_gravewarden
1978   » rig_frost
1990   » rig_cinder
2007   » rig_weaver
2025   » rig_stormcaller
2042   » rig_void
2056   » rig_seraph
2068   » rig_leviathan
2088   » rig_eclipse
2112   » rig_wizard
2134   » _wizard_void_face
2141   » _ember_block
2158   » get_display_name
2161   » _physics_process
2261   » process_hover
2271   » arena_width
2278   » effective_speed
2284   » choose_attack
2302   # The Fallen Wizard's active combo brain (level 100 only)
2354   » combo_length_for
2363   » is_wizard_boss
2368   » is_combo_boss
2373   » active_combos
2398   » drive_wizard
2413   » _drive_profile
2475   » combo_step_gap
2482   » combo_recovery_time
2490   » pick_combo_index
2501   » run_combo
2520   » run_ability
2559   » start_attack
2605   » set_cd
2608   » cooldown_mult
2622   » current_player_role
2632   » trigger_counter_mechanic
2648   # abilities
2650   » do_slam
2665   » do_charge
2678   » process_charge
2702   » do_barrage
2718   » do_nova
2732   » do_rain
2757   » do_teleport
2785   » do_summon
2807   » do_pillars
2835   # apex abilities
2839   » do_dive
2845   » process_dive
2871   » do_volley
2884   » do_meteors
2910   » do_vortex
2935   » do_beam
2976   » do_curse
2998   » do_doomring
3023   » allowed_clones
3027   » living_clones
3031   » do_clone
3055   # SIGNATURE ABILITIES (BOSSES.md §6)
3058   » spawn_hazard
3071   » _player_in
3076   » do_grave_grasp
3094   » do_rime_lance
3118   » do_magma_wake
3137   » do_web_snare
3152   » do_thunderstrike
3174   » do_void_rift
3203   » do_dissonant_scream
3229   » do_prayer_pyre
3250   » do_iron_maiden
3269   » do_pounce
3297   » do_splinter_burst
3316   » do_keening
3334   » do_ambush
3360   » do_impale
3384   » do_pincer_lunge
3414   » do_eruption
3438   » do_refraction
3464   » do_riposte_stance
3473   » _do_parry_counter
3482   » do_judgment
3510   » do_tidal_crush
3540   » do_black_sun
3560   » do_unwriting
3580   » _make_wall
3591   » _point_near_ray
3599   » _spawn_beam_line
3612   » _spawn_cone
3628   » _zone_marker
3640   # ability helpers
3642   » spawn_arrow
3653   » deal_player_damage
3665   » knockback_player_away
3673   » shake_camera
3677   » spawn_ring_telegraph
3692   » spawn_shockwave
3709   » spawn_ground_marker
3722   » erupt_pillar
3736   # combat / lifecycle
3738   » check_bump
3749   » flash_telegraph
3761   » apply_petrify
3767   » take_damage
3889   » enrage
3896   » frenzy
3921   » apply_knockback
3924   » flash_hit
3931   » play_sfx
3935   » update_health_bar
3939   » die
3957   » play_death_animation
3970   » spawn_death_particles
```

### player.gd (3807 lines)
```
37     # Fall damage
54     # Flight (Aetherwing relic)
75     # Mana
135    # Aiming
149    » get_weapon_stats
152    » has_weapon
280    » _ready
336    » maybe_play_intro
356    » grant_starter_weapons
370    » ensure_test_items
415    » ensure_admin_wand
428    » ensure_flight_relics_for_test
443    » grant_starter_gear
451    # worn-gear visuals (helmet / chest / pants overlays on the body)
455    » build_armor_visuals
482    » update_armor_visuals
495    » _apply_armor_piece
507    » build_weapon_guard
514    # The Shadow Monarch aura (hidden 7-stage passive, see GameState)
527    » build_shadow_aura
602    » update_shadow_aura
672    # THE SHADOW MONARCH'S POWERS
701    » monarch_tick
740    » _apply_true_form
771    » can_raise_shades
774    » raise_shade
800    » _rebalance_shades
812    » shade_defend_share
817    » fire_shadow_nova
840    » apply_fear_aura
856    » enter_long_dark
883    » build_wings_visual
891    » _make_wing
901    » update_wings
916    » _aim_length
927    » setup_body_anim
951    » build_sprite_frames
974    » load_frames_for
990    » refresh_monarch_skin
1038   » _hooded_art_present
1042   » _ascended_art_present
1049   » load_texture
1071   » opaque_bounds
1092   » load_image_smart
1110   » _add_anim
1124   » _input
1128   » current_anim_state
1157   » feet_anchor_y
1165   » update_body_anim
1233   » spawn_dash_afterimage
1254   » apply_pending_player_state
1272   » play_sfx
1276   # combat/economy effect hooks. get_bonus_total = skill tree + worn gear
1279   » get_max_health
1283   » skill_damage_mult
1322   # Crit
1328   » get_crit_chance
1331   » get_crit_damage
1335   » roll_crit
1341   » show_hit
1352   » hit_stop
1358   » _process
1365   » _exit_tree
1371   » _impact_feedback
1376   # Timed buffs (from food). active_buffs[key] = {"v": amount, "until": t}.
1380   # RIFTWEAVING (Mage, mg_p1..p3): the two doors, Z to weave
1392   » has_portal_skill
1397   » portal_open_cost
1402   » portal_drain_per_second
1407   » try_weave_portal
1430   » tick_portals
1442   » close_portals
1458   » try_plant_building
1519   » do_portal_teleport
1529   » add_buff
1534   » use_item
1574   » buff_bonus
1583   » skill_cooldown_mult
1593   # Standing torches (G)
1599   » try_place_torch
1623   # Bar morale
1632   » bar_morale_active
1635   » grant_bar_morale
1648   # boss crowd-control on the PLAYER (set by boss signature abilities)
1663   » on_enemy_killed
1681   » apply_slow
1687   # boss crowd-control API (called by boss.gd signature abilities)
1689   » _cc_dur
1692   » apply_stun
1696   » apply_freeze
1700   » apply_root
1704   » apply_disorient
1708   » apply_poison
1715   » apply_pull
1721   » cc_action_locked
1726   » cc_move_locked
1732   » _poison_tick
1745   » clear_crowd_control
1755   » player_slow_mult
1761   » skill_move_speed_mult
1769   » on_equipment_changed
1776   » update_health_display
1781   # Mana pool
1783   » get_max_mana
1786   » get_mana_regen
1789   » spend_mana
1796   » gain_mana
1803   » build_mana_bar
1836   » update_mana_display
1845   » apply_knockback
1860   » knockback_sign_toward
1866   » _on_spear_tip_hit
1884   » wield_weapon
1915   » select_hotbar_slot
1932   » update_weapon_guard
1943   » get_aim_direction
1949   » update_weapon_visual
1984   » add_currency
1990   » take_damage
2065   » start_invincibility_flash
2076   » stop_invincibility_flash
2082   » die
2140   » drop_currency_on_death
2161   » apply_difficulty_death_penalty
2171   » update_currency_display
2180   » perform_dash
2197   » perform_admin_dash
2218   » _physics_process
2363   # Flight (Aetherwing)
2365   » has_flight
2377   » has_wings
2385   » levitate_mana_rate
2391   » has_fall_immunity
2398   » update_flight
2428   # Fall damage
2431   » handle_fall_landing
2439   » apply_fall_damage
2452   » perform_secondary_attack
2463   » cast_percent_burst
2496   » spawn_ruin_burst
2512   » perform_attack
2656   # Melee combo strings
2668   » combo_length
2690   » combo_finisher_mult
2696   » combo_is_live
2702   » combo_step
2713   » reset_combo
2719   » update_combo_label
2741   # Per-weapon crit character
2745   » weapon_crit_chance_bonus
2751   » weapon_crit_damage_bonus
2762   » spawn_swing_trail
2821   » weapon_grade_rank
2827   » grade_force_mult
2834   » grade_projectile_girth
2836   » grade_projectile_range
2839   » swing_slash_config
2886   » launch_swing_slash
2902   » launch_projectile
2931   » throw_javelin_volley
2950   » cast_wand_projectile
2976   # Relic powers (triggered mechanics on equipped relics; see inventory.gd
2985   » _now
2989   » has_relic_power
2996   » relic_power_value
3003   # Relic power effects (see has_relic_power)
3006   # Sage: the channelled beam (skill tree mg_s4b "Focusing Lens")
3020   » has_beam
3023   » beam_peak_mult
3027   » beam_ramp_mult
3030   » stop_beam
3036   » draw_beam
3054   » channel_beam
3099   » apply_omnivamp
3110   » apply_melee_skills
3151   » reflect_thorns
3165   » spawn_aegis_block
3181   » spawn_phoenix_revive
3199   » spawn_shock_ring
3222   » _unique_impact_point
3232   » on_projectile_hit
3244   » advance_swing_charge
3270   » apply_excellent_effect
3370   # Excellent-weapon hit visuals (all procedural, world-space, self-cleaning)
3379   » spawn_lightning_bolt
3417   » _jagged_points
3433   » spawn_blood_steal
3452   » _circle_points
3460   » spawn_gold_sparks
3486   » spawn_execute_flash
3506   » collapse_singularity
3524   » spawn_singularity_visual
3554   » unleash_ragnarok
3580   » spawn_ragnarok_ring
3597   » spawn_bane_flash
3613   » spawn_chrono_flash
3641   » spawn_echo_ring
3658   » spawn_soul_wisps
3677   » closest_body
3687   » animate_sword
3700   » animate_spear
3715   » animate_bow
3725   » spawn_arrow
3773   » cast_wand
3790   » cast_wand_nuke
```

### dungeon_interior.gd (2443 lines)
```
365    » _ready
395    » setup_exit_button
404    » start_music
426    » music_pitch_for
435    # layout selection
437    » get_layout_slot
440    » is_boss_level
444    » get_layout
450    # REGULAR FLOOR LAYOUTS
472    » get_regular_theme
475    » generate_regular_layout
494    # reachable primitives
496    » _ledge
502    » _stack
515    » _span_with_access
525    # the twelve themes
527    » _theme_terraces
540    » _theme_isles
551    » _theme_pillared_hall
561    » _theme_chasm_bridges
570    » _theme_overwatch
577    » _theme_gauntlet
587    » _theme_twin_towers
593    » _theme_amphitheatre
605    » _theme_roost
617    » _theme_warren
628    » _theme_sunken_court
637    » _theme_cascade
652    » total_boss_levels
659    » get_boss_id
677    » get_boss_counter
683    » build_counter_sequence
697    » get_boss_arena
700    » get_level_width
705    » get_level_ceiling
710    # boss arena platform generators
720    » generate_boss_platforms
754    » add_sky_tier
769    » gen_gravewarden
791    » gen_frost
813    » gen_cinder
837    » gen_weaver
861    » gen_stormcaller
884    » gen_void
904    # the deep (35-90)
915    » gen_hollow_choir
941    » gen_ashen_penitent
968    » gen_gaoler
994    » gen_sablefang
1020   » gen_effigy
1043   » gen_mourncaller
1069   » gen_unseen
1090   » gen_warden_of_nails
1114   » gen_twin_despair
1136   » gen_cinderking
1164   » gen_glass_saint
1190   » gen_last_man
1213   # apex arena generators
1219   » gen_seraph
1245   » gen_leviathan
1261   » gen_eclipse
1290   » gen_wizard
1308   # level (re)building
1310   » build_level_visuals
1339   » build_floor_surprises
1356   » _dgn_cache
1372   » _dgn_hazard
1377   » build_gates
1392   » on_gate_used
1399   » go_to_level
1405   » build_background
1433   » build_wall_layer
1460   » build_ground_and_walls
1488   » build_wall
1507   » build_platforms
1534   » build_stalactites
1546   » make_additive_material
1551   » build_torches
1578   » build_torch
1616   » place_mines
1642   » place_hazards
1668   » place_mine
1673   » place_player_at_entry
1686   » _place_deep_shrine
1709   # combat flow (mirrors the old overworld dungeon_manager.gd)
1713   » _softcapped_mult
1718   » get_level_scaling
1725   » spawn_level_combat
1779   » play_empty_throne
1790   » play_final_victory
1824   » spawn_deep_rescue
1871   # normal-level mob composition
1891   » block_position
1894   » op_pool_for_level
1902   » op_fraction
1909   » spawn_level_mobs
1938   » pick_random_subset
1943   » spawn_kind
1954   » spawn_special_mob
1969   # THE HARVEST (GAME_BIBLE 9.3 / 9.4)
1984   » _physics_process
2024   » _apply_devour_tier
2038   » _spawn_transformed
2070   » spawn_enemy
2107   » assign_enemy_behavior
2119   » spawn_boss
2151   » get_material_for_level
2164   » roll_material_drop
2174   # Gear loot
2216   » roll_gear_drop
2249   » _gear_unowned
2258   » _give_gear
2267   » _on_combatant_died
2308   » play_orin_glimpse
2311   # PROVING GROUNDS (admin test arena)
2316   » build_proving_grounds
2370   » _proving_label
2382   » exit_dungeon
2392   » update_level_label
2419   » _straggler_hint
2440   » show_notification
```

### building.gd (2234 lines)
```
12     # Destructibility (see the damage note; HP persists in GameState)
17     # Upgrades
35     # Build / repair
158    » _ready
215    » _make_label
225    # level-scaled dimensions
235    » eff_w
238    » eff_h
245    » dock_water_half
250    » max_upgrade_width
254    » rebuild_geometry
284    # damage
286    » state_for_health
297    » state_for_stage
304    » compute_visual_state
309    » is_operational
312    » take_damage
339    # build / repair (staged)
341    » is_ruined
345    » repair_requirement_text
351    » has_repair_materials
358    » missing_repair_materials
369    » try_build
385    » advance_build_stage
399    » play_construction_animation
410    » spawn_build_dust
435    » restore_full
451    » update_name_label
460    » _refresh_rubble
508    » attempt_clear_rubble
528    » spawn_clear_dust
541    » attempt_field_build
567    » update_prompt
587    # wall torches (auto day/night lighting)
613    » build_torch_layer
674    » position_torches
688    » update_torches
701    » _add_mat
706    » _fire_gradient
712    # villagers at work (visible busy-ness once people are employed here)
738    # attached work-yards
762    » area_world_half
766    » area_offset_x
788    » employed_count
798    » play_door_anim
822    » refresh_workers
895    # attached work-yard props
896    » _a_rect
904    » _a_disc
911    » _a_line
918    # Farm crops (dynamic)
923    » _update_farm_crops
935    » _draw_crop
960    » _spawn_harvest_puff
976    » _spawn_harvest_float
989    » build_work_area
1124   # the Bar's fun music + player morale
1164   » update_bar_music
1180   # upgrades
1182   » can_upgrade
1185   » upgrade_cost
1189   » try_upgrade
1205   » effective_slots
1211   # visuals
1213   » refresh_visual
1237   » build_intact
1290   # shared tiny draw helpers for the named silhouettes
1291   » _disc
1298   » _tri
1301   » _ln
1310   » _lit_col
1313   » _win
1321   » draw_named_building
1347   » _b_government
1367   » _b_school
1384   » _b_farm
1405   » _b_hospital
1423   » _b_barracks
1445   » _b_dock
1468   » _b_lab
1488   » _b_bank
1523   » _b_blacksmith
1554   » _b_tavern
1592   » _b_bar
1645   » market_sections
1648   » _b_market
1675   » _b_builder
1703   » build_half
1717   » build_destroyed
1736   # body / roofs / features
1738   » add_body
1745   » build_roof
1784   » build_feature
1817   » add_pennant
1826   » add_window_grid
1859   » _side_centers
1868   » add_door
1873   » add_cracks
1888   » add_scorch
1903   » add_glow
1918   » add_fire
1953   » build_shine
1964   » flash_body
1971   » spawn_hit_debris
1993   # small draw helpers
1995   » add_poly
2001   » add_rect
2009   » rect_poly
2012   » ruined_body_poly
2022   » circle_poly
2029   # health bar
2031   » build_health_bar
2044   » update_health_bar
2056   # gameplay
2058   » _on_body_entered
2067   » _on_body_exited
2075   » _process
2188   » get_roles
2191   » get_role_holders
2198   » is_role_full
2201   » get_eligible_villagers
2222   » open_assign_ui
2227   » _on_child_produced
```

### enemy.gd (1396 lines)
```
103    # WILDERNESS MOBS (the lands east of the village)
148    # Status effects (see apply_status). burn/poison = damage-over-time,
166    # Behavior archetype (mechanics beyond plain melee/bow). Set by spawn:
176    » _now_s
179    » move_speed
182    » status_slow_mult
185    » is_frozen
190    » apply_status
210    » is_petrified
213    » tick_statuses
235    » _refresh_status_overlay
282    » _pick_prey
301    » _retarget
310    » _ready
328    » update_body_color
331    » play_sfx
340    » apply_block_archetype
348    » apply_mixed_archetype
371    » build_character
423    » _add_skull
432    » _add_socket
435    » _add_shoulders
442    » _add_poly
448    » _add_dot
456    # Spritesheet-skinned enemies (downloaded art)
460    » _build_sprite_visual
488    » _update_enemy_anim
500    » setup_weapon_visual
514    » get_aim_direction
521    » update_weapon_icon_position
533    » _physics_process
663    » try_jump
675    » count_nearby_enemies
687    » check_bump
706    » _melee_connects
713    » try_attack
733    » finish_attack
737    » try_deal_melee_damage
749    » _telegraph_weapon
754    » animate_sword_attack
768    » animate_spear_attack
783    » animate_bow_attack
796    » _loose_arrow
806    # Behavior archetypes
814    » set_behavior
840    # SUPER-MOB (elite) presence + signature slam
860    » _become_super_mob
883    » _tick_elite_slam
899    » _elite_slam
909    » _spawn_slam_ring
928    » _elite_shockwave
951    » _spawn_shock_burst
973    » process_behavior
1000   » _living_allies
1012   » heal_nearby_allies
1025   » summon_minions
1046   » cast_hex_bolt
1061   » perform_lunge
1074   » spawn_block_spark
1078   » spawn_status_spark
1100   » on_soul_split_wand
1121   » take_damage
1145   » apply_knockback
1153   » flash_hit
1165   » update_health_bar
1169   » die
1243   » _wait_until_unwatched
1254   » play_death_animation
1271   » spawn_death_particles
1311   » spawn_coin_popup
1348   » spawn_material_popup
1373   » respawn
```

### inventory.gd (1337 lines)
```
496    # 
504    # 
798    # 
891    # 
898    # 
961    # tiny drawing primitives (children of the icon ColorRect)
978    # armour silhouettes, one per equipment slot (tinted to the item colour)
1035   # per-item symbols (drawn in the target's 0..w / 0..h local space)
1212   » _init
1222   » get_count
1231   » add_item
1263   » remove_item
1284   » transfer_to
1300   » transfer_slot
1322   » to_save_data
1331   » from_save_data
```

### main.gd (1294 lines)
```
211    » _ready
277    » _maybe_begin_feast
300    » show_away_report
326    » generate_village
373    » spawn_placed_torches
379    » generate_houses
442    » spawn_existing_villager_avatars
479    » arm_arrival_battle
486    » _check_arrival_trigger
519    » begin_arrival_battle
553    » _on_arrival_raider_died
576    » _check_arrival_talk
600    » play_arrival_talk
635    » _autosave_on_arrival
638    » stamp_rewound_arrival
647    » orin_midgame_taunt
660    » warn_wounded_corps
681    » build_escape_ward
703    » _on_escape_attempt
738    » _spawn_gauntlet_wave
751    » _on_gauntlet_raider_died
764    » announce_orin_arrival
780    » spawn_adventurers
795    » is_villager_busy_mating
811    » offscreen_spawn
823    » find_avatar_spawn_position
839    » _process
847    » start_music
855    » apply_save_data
894    » generate_harvestables
936    » spawn_harvest_node
949    » generate_grass
960    » generate_traps
968    » generate_platform_traps
992    » place_trap
997    » generate_mountains
1099   » _extend_ridges_across_world
1134   » fence_the_camera
1142   » fit_sky_to_world
1153   » build_ground_skin
1205   » _tile_top_padding
1217   » generate_mountain_shape
1241   » generate_clouds
1270   » generate_cloud_shape
1284   » spawn_tuft
```

### underdark.gd (1065 lines)
```
27     # geometry
80     # the cave mouth
112    # doors
120    # streaming mobs
134    » _ready
170    » band_floor_y
175    » _stair_steps
178    » _stair_end_x
182    » _retire_surface_door
204    » _carve_ground_skin
220    » _plan_bands
256    » _build_dark_backdrop
264    » _slab
295    » _build_mouth_and_stair
367    » _climbable_platforms
375    » _build_bands
438    » _plan_shafts
460    » _build_shaft_ladders
486    » _slab_with_hole
495    » _seg_at
501    » _brazier
543    # the hidden doors
544    » _place_doors
586    # ore seams
587    » _place_seams
598    # streamed cave mobs (the east road's three rules, underground)
599    » _process
610    » _hold_the_dark_lit
617    » _stream_tick
630    » _band_of
633    » _stream
661    » _sector_center
667    » _prune
677    » _populate
707    » live_count
715    # traps, chests, and the rune vaults
716    » _trap
725    » _stock_chest
750    » _add_chest
760    » _place_chests
779    » _plan_pits
801    » _build_pits
837    » spring_ambush
866    » _build_hidden_lofts
908    » _build_rune_vaults
951    » rune_lit
965    # the arch you walk into
975    » _build_cave_prompt
1030   » _tick_cave_mouth
```

### npc.gd (1086 lines)
```
28     » _village_span
105    » _ready
179    » build_visual
184    » _body_px
196    » apply_size
255    » _villager_skin
271    » _build_villager_sprite
287    » _update_villager_anim
295    » refresh_size_if_needed
300    » build_hover_panel
324    » build_health_bar
366    » _nearest_threat
379    » _tick_defence
396    » is_fleeing
399    » take_damage
412    » update_health_bar_fill
420    » apply_despair_visual
446    » update_health_bar_display
468    » die
476    » _physics_process
619    » cheer
627    » _apply_cheer
670    » pick_new_state
679    » find_villager_data
685    » _on_body_entered
689    » _on_body_exited
693    » _process
717    » _apply_shadow_form
723    » try_doctor_heal
759    » _play_doctor_sfx
770    » try_bond_interaction
795    # mood talk
805    » tick_mood_talk
816    » say_mood_line
822    » mood_lines
855    » _monarch_reaction_lines
876    » refresh_wander_bounds
888    » get_building_for_role
891    » roll_new_cycle
903    » tick_building_visits
934    » pick_visit_building
952    » enter_building_node
956    » _complete_enter
968    » exit_building
986    » info_fields
1039   » bond_fields
1052   » show_info
1063   » is_hovering
1066   » update_hover_panel
```

### special_mob.gd (1048 lines)
```
3      # 
18     # 
85     # Elite affixes
131    # Statuses. Special mobs used to have NO apply_status, so every burn/poison/
144    » apply_status
164    » status_slow_mult
167    » tick_statuses
258    » _ready
303    » build_collision
319    » _physics_process
372    # per-kind behaviour
374    » act_flyer
391    » act_bomber
401    » prime_and_explode
414    » explode
427    » act_charger
466    » act_spitter
478    » act_stalker
522    » act_blink_archer
537    » act_hexer
551    » cast_hex_ring
572    » act_runecaster
579    » cast_runes
604    » act_warlock
619    # caster/teleport helpers
621    » face_player
627    » arena_width
633    » teleport_to
641    » blink_to_flank
645    » spawn_teleport_puff
663    » spawn_sigil
675    » erupt_rune
688    # shared combat
690    » deal_contact_damage
694    » fire_projectile
700    » take_damage
727    » apply_knockback
735    » die
748    # visuals
750    » set_flash
757    » clear_flash
764    » add_part
769    » build_visual
789    » _build_mob_sprite
802    » _update_mob_anim
810    » poly
815    » circle_points
825    » build_flyer_visual
844    » build_bomber_visual
861    » build_charger_visual
879    » build_spitter_visual
898    » build_stalker_visual
908    » build_blink_archer_visual
930    » build_hexer_visual
942    » build_runecaster_visual
959    » build_warlock_visual
973    » _robe
977    » build_elite_glow
991    » build_health_bar
1005   » update_health_bar
1009   » play_sfx
1017   » spawn_blast
1030   » spawn_death_particles
```

### wizard.gd (876 lines)
```
15     # Combat / survivability tuning
35     # Undying escalation
69     » apply_power_tier
80     » current_skill_name
88     # Downed / respawn
135    » _ready
171    » _physics_process
189    » _process
207    » tick_regen
216    # combat
218    » try_cast
231    » find_target
251    » cast_meteor_at
297    » apply_meteor_impact
307    » spawn_impact_fx
338    # take hits
342    » take_damage
354    » die
364    # downed / reform
366    » build_fireball
458    » enter_downed_state
490    » _hide_gfx
496    » respawn
540    » _set_fireball_flames
549    » update_ember_growth
560    » spawn_revive_flash
573    » spawn_puff
593    » _additive_material
598    # visuals
600    » build_visual
659    » _build_orin_sprite
674    » _on_orin_anim_finished
678    » build_staff
700    » start_idle_animation
709    » animate_cast
723    » face_toward
730    » build_health_bar
747    » update_health_bar_fill
751    » update_health_bar_display
772    » build_proximity_area
786    » _on_body_entered
790    » _on_body_exited
794    » build_hover_panel
819    » is_hovering
822    » update_hover_panel
827    # geometry util
829    » _circle_points
837    » _ellipse_points
847    » _flame_points
861    » _rock_points
870    » _star_points
```

### adventurer.gd (606 lines)
```
29     » play_sfx
52     # signature ability state (each adventurer runs a DIFFERENT mechanic)
91     » _ready
137    » hero_color
140    » _build_visual
257    » _refresh_prompt
265    » _apply_station_groups
273    » _physics_process
299    » _separate
317    » _tick_bark
329    » _update_hp_bar
341    » _cycle_station
353    » _station_anchor_x
391    » _village_center_x
407    » _ensure_anchor
414    » _hold_station
433    » _nearest_raider
453    » _attack_damage
467    » _loose_arrow
480    » _second_raider
492    » _fight
554    » take_damage
591    » on_siege_ended
594    » die
605    » apply_knockback
```

### assign_ui.gd (519 lines)
```
6      » _ready
11     » open_for_building
16     » close
20     » esc_is_open
23     » esc_close
26     » refresh
65     » add_market_stall_section
109    » _on_stall_sell
127    » add_relocate_section
145    » add_repair_section
191    » _on_repair
212    » add_upgrade_section
243    » _on_upgrade
261    » add_research_section
290    » _on_research
314    » smithy_max_rank
317    » smithy_stock
339    » smithy_price
342    » add_smithy_section
361    » _on_buy_gear
384    » add_armory_section
434    » _on_deposit_arm
447    » add_role_section
492    » _on_assign
```

### day_night_cycle.gd (501 lines)
```
124    » _ready
151    » make_additive_material
156    » build_sun
175    » build_sun_highlight
185    » build_sun_rays
199    » setup_moon_glow_materials
211    » update_moon_glow_shape
229    » generate_moon_craters
261    » max_crater_radius_at
277    » is_point_in_moon_phase
289    » is_crater_fully_in_phase
300    » update_moon_craters
316    » build_moon_sky_glow
324    » build_circle
332    » build_moon_phase
352    » pick_new_moon_phase
370    » _process
382    » handle_debug_time_input
392    » get_darkness_factor
401    » is_night
404    » get_sun_progress
410    » get_moon_progress
423    » is_sun_moon_overlap
426    » get_parallax_anchor_x
432    » arc_position
437    » update_visuals
467    » counter_color
475    » update_moon_true_colors
496    » update_clock_label
```
