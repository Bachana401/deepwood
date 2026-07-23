# Deepwood — Codemap

_Navigation index for fast lookup. Regenerate with `bash gen_codemap.sh`. Line numbers drift as code changes — treat as approximate anchors, confirm with a read._

`103` game scripts, ~41351 LOC. Generated 2026-07-23.

## File directory

| script | lines | purpose (first header comment) |
|--------|------:|--------------------------------|
| admin_panel.gd | 289 | One-stop dev/testing console, toggled with P. Every "OP" testing action lives |
| adventurer.gd | 657 | A living adventurer defending Deepwood (GAME_BIBLE 2.4.1). Persistent between |
| adventurer_rescue.gd | 69 | A chained adventurer awaiting rescue in the dungeon (the deep nine of |
| adventurers.gd | 100 | The twelve adventurers (GAME_BIBLE §2.4.1 "The three defenders" + the deep |
| arrival_weather.gd | 59 | THE ARRIVAL STORM (start-scene fix, 2026-07-21). The dev's canon asked for |
| arrow.gd | 182 | (no header comment) |
| assign_ui.gd | 549 | (no header comment) |
| blueprint_pickup.gd | 57 | A BLUEPRINT SATCHEL (GAME_BIBLE 5.2): the plans for one village building, |
| boss.gd | 4017 | Dungeon boss. |
| boss_hud.gd | 190 | WUKONG-STYLE BOSS SPECTACLE (dev ask 2026-07-22). Makes every boss an EVENT: |
| build_menu.gd | 241 | THE BUILDER'S LEDGER (B key; dev request 2026-07-21). |
| build_placer.gd | 325 | THE BUILDER'S HAND (dev 2026-07-22). Raise a building from the B menu with a |
| building.gd | 2238 | (no header comment) |
| building_hitbox.gd | 15 | Buildings are Area2D nodes (for the Press-E proximity), which enemy arrows |
| building_lights.gd | 303 | Breathes life into the painted facades WITHOUT touching the approved art: |
| building_roles.gd | 111 | Role definitions per building (keyed by the building's role_key, e.g. |
| camera_shake.gd | 15 | (no header comment) |
| char_shadow.gd | 44 | Preloaded as a const by its users (const CHAR_SHADOW = preload(...)) rather than |
| chest.gd | 44 | Unique per-instance id, used as the key into GameState.chest_contents so |
| chest_ui.gd | 283 | Terraria pixel-box slots, matching the inventory: slate border + dark fill. |
| currency_pickup.gd | 99 | "1 full in-game day" is defined by the day/night cycle's own day length, |
| day_night_cycle.gd | 501 | (no header comment) |
| death_screen.gd | 41 | The cost of dying, said ON the black screen itself -- the toast version |
| dialogue_box.gd | 137 | A small, reusable conversation box (bottom of screen): speaker name + one line, |
| dock_bridge.gd | 70 | A walkable wooden crossing spanning the Fishing Dock's water: stairs up, a |
| dps_dummy.gd | 89 | The Proving Grounds training dummy: an invincible target that never dies and |
| drag_state.gd | 220 | Coordinates dragging an item stack between slots -- possibly across two |
| dungeon_gate.gd | 106 | The LEAVE gate on the left of every dungeon floor (see dungeon_interior.gd). |
| dungeon_interior.gd | 2628 | Dungeons are a real separate scene the player is teleported into (see |
| dungeon_manager.gd | 18 | Dungeon combat now happens in a fully separate scene (dungeon_interior.gd) |
| dungeon_sign.gd | 50 | (no header comment) |
| dungeon_zone.gd | 24 | (no header comment) |
| enemy.gd | 1409 | Dev call 2026-07-21: sight cut 15% (was 225) -- "I don't want them to non |
| enemy_skins.gd | 196 | Shared skin builder for downloaded/generated character art. Originally for |
| equipment_ui.gd | 417 | Equipment panel, pinned to the RIGHT side of the screen (kept clear of the |
| farm_animal.gd | 221 | A small BLOCKY, pixel-styled farm animal (chicken / pig / cow / sheep) that |
| farm_pen.gd | 73 | A fenced pasture beside the Farm. Draws the fence + a dirt patch and spawns a |
| floating_text.gd | 75 | Shared floating combat text -- a damage number that rises, drifts, and fades |
| food_readout.gd | 99 | Always-visible village food gauge, top-left HUD, tucked just under the mana |
| game_state.gd | 4658 | Deepest dungeon level ever reached in a single run -- a high-score style |
| harvest_director.gd | 309 | THE HARVEST, AT HOME (new finale canon, 2026-07-20). |
| harvest_node.gd | 254 | A harvestable world node: a TREE (chop with the Woodsman's Axe) or a ROCK |
| hazard.gd | 307 | CREATIVE DUNGEON HAZARDS (dev report 2026-07-21: "no creative traps"). Beyond |
| hazard_zone.gd | 61 | A lingering ground hazard dropped by a boss signature ability and then left to |
| homing_bolt.gd | 41 | A slow homing projectile — the Mourncaller's Keening wisps, and reusable for |
| hotbar_ui.gd | 86 | Bottom-of-screen hotbar showing the first 10 inventory slots (keys 1-9, 0). |
| house.gd | 162 | (no header comment) |
| how_to_play.gd | 117 | HOW TO PLAY -- the controls and the laws, one readable page, opened from |
| hud_orb.gd | 48 | MU Online / Diablo style liquid globe for HP or mana (dev ask 2026-07-22). |
| inventory.gd | 1459 | Shared item catalog -- every item type in the game (currency included) is |
| inventory_ui.gd | 338 | Terraria-tight pixel slots (dev ask 2026-07-22): a compact grid of bordered |
| item_tooltip.gd | 94 | A single hover tooltip shared by every item UI (inventory, chest, equipment |
| level_select_ui.gd | 106 | (no header comment) |
| magic_orb.gd | 102 | A slow homing "cursed orb" fired by the Warlock mob (special_mob.gd). It |
| main.gd | 1458 | (no header comment) |
| main_menu.gd | 185 | Whether the fresh-start flow currently in the difficulty picker should wipe |
| material_pickup.gd | 95 | A dropped material on the ground (dev ask 2026-07-22: "materials like in |
| morale_meter.gd | 174 | Village morale, shown in the TAB overlay directly BELOW the mana bar (kept |
| notification_stack.gd | 25 | (no header comment) |
| npc.gd | 1110 | Points back at their entry in GameState.rescued_villagers -- info is |
| objective_banner.gd | 68 | A quiet, always-current objective ticker at the top of the VILLAGE screen, so a |
| pause_menu.gd | 207 | (no header comment) |
| player.gd | 3966 | DEV CALL (2026-07-20): the old dash covered 600*0.15 = 90px -- barely |
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
| siege_enemy.gd | 506 | A besieger: marches east out of the evil lands toward the village wall and |
| siege_manager.gd | 244 | Presents LIVE sieges while the player is in the village. Scheduling and |
| skill_tree.gd | 246 | Each class is ONE tree that actually BRANCHES. A root trunk splits into 3 |
| skill_tree_ui.gd | 464 | Skill tree window (K to toggle) + the always-visible XP bar. Everything is |
| special_mob.gd | 1050 | Special dungeon mobs -- the non-humanoid monsters that spice up NORMAL |
| speech_text.gd | 69 | Floating, window-less speech for characters: plain outlined text hovering |
| standing_torch.gd | 117 | A big free-standing brazier torch the player can PLACE anywhere on the ground |
| story.gd | 183 | Deepwood's scripted story beats, kept in one place (canon: GAME_BIBLE §2/§9, |
| ten_ally.gd | 112 | One of the Ten, fighting beside you at the Harvest (GAME_BIBLE 9.4) -- ten |
| the_ten.gd | 61 | THE TEN (GAME_BIBLE §8) -- the capstone hostages, the truly unbreakable. |
| trap.gd | 82 | (no header comment) |
| trophy_vault.gd | 94 | A Trophy Vault (GAME_BIBLE §8): the gilded cage where Orin keeps one of the |
| tutorial_overlay.gd | 94 | THE INTERACTIVE TUTORIAL CARD (dev 2026-07-22: "show, don't tell"). Instead of a |
| underdark.gd | 1181 | THE UNDERDARK (GAME_BIBLE §4 amendment, dev-decided 2026-07-21). |
| underdark_ambush.gd | 25 | A hidden ambush in a sunken chamber of the deep (underdark.gd _build_pits). |
| underdark_door.gd | 149 | A hidden stone door of the Underdark (GAME_BIBLE §4 amendment). Each one is |
| underdark_rune.gd | 71 | One of three rune stones that unbar a band's vault (underdark.gd). Press E. |
| vault_chest.gd | 134 | A Proving Grounds vault chest. Unlike a normal loot chest it's a bottomless |
| village_life.gd | 348 | Makes Deepwood feel ALIVE, and rewards the player's progress with spectacle. |
| village_log_ui.gd | 122 | THE VILLAGE LOG (GAME_BIBLE 5.9) -- press L. The village's diary: births, |
| villager.gd | 198 | Unique per-instance id so an already-rescued villager doesn't reappear (and |
| villager_quests.gd | 240 | Two things live here: |
| wall.gd | 360 | The village's west rampart -- the line the siege breaks against. It has no |
| wanderer_ui.gd | 93 | THE WANDERER'S POST counter (GAME_BIBLE 5.6a) -- opened with the hands-on |
| watchtower.gd | 144 | THE WATCHTOWER (GAME_BIBLE 7.1) -- foresight, earned. A standalone |
| weapon_projectile.gd | 302 | One configurable projectile powering the special-attack weapons (see |
| wilderness.gd | 209 | THE EAST ROAD (2026-07-21, dev request). |
| wizard.gd | 877 | ORIN, the stranded village mage. Lore: an adventurer like the player who |
| worker_figure.gd | 371 | A villager-at-work figure, spawned by building.gd when villagers are employed |

## Big-file outlines (sections + functions, with line numbers)

Jump anchors for the files too large to grep comfortably. `#` = section header, `»` = function.

### game_state.gd (4658 lines)
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
680    » wall_stationed_count
691    » fighting_adventurers
709    # THE GOLD FAUCETS (GAME_BIBLE 5.6, revised canon 2026-07-17)
729    # Leader bonuses
750    # Master in-game clock
768    » time_of_day
771    » village_darkness
782    » torches_lit
785    # Village siege state (autoload-owned so assaults resolve while the player
812    # Village mage (Orin) downed/respawn state
827    # Construction-material drops (the repair economy)
834    » _has_inventory
837    » roll_construction_drop
849    » grant_construction_bundle
859    » wizard_is_down
864    » wizard_down_progress
870    » mark_wizard_down
873    » clear_wizard_down
899    » building_clear_progress
902    » building_is_cleared
912    » blacksmith_unlocked
917    » building_build_stage
932    » restore_all_buildings
943    » building_level
946    » building_output_multiplier
949    # DELETED BUILDINGS (dev 2026-07-22 building menu: "player can delete these
955    » building_removed
958    » remove_building
977    » restore_building
986    » remove_cottage
1004   » remove_placed_wall
1016   # RAISING BUILDINGS FROM THE MENU (dev 2026-07-22: build from B with a holo)
1027   » build_cost
1040   » can_afford_build
1048   » pay_build
1056   » can_place_building
1086   # THE OPENING TUTORIAL (step-gated, dev polish 2026-07-22)
1101   » tutorial_begin
1113   » tutorial_note
1128   # THE RAMPART (dev ask 2026-07-22: "make WALLS bigger... with gate,
1150   » wall_max_health
1157   » wall_defense_bonus
1160   » wall_trap_dps
1163   » wall_station_capacity
1167   » wall_upgrade_cost
1172   » can_afford_wall_upgrade
1183   » try_upgrade_wall
1221   » _mint_birth_id
1225   # THE VILLAGE LOG (GAME_BIBLE 5.9)
1238   » log_event
1249   # HOUSING (GAME_BIBLE 5.8)
1271   » villager_name
1277   » villager_home_id
1286   » kid_is_housed
1300   » _couple_expecting
1306   » update_cottage_families
1358   » effective_roll_weights
1373   » roll_regular_stat
1389   » _ready
1402   # Audio: a "Master" (Volume) bus and a dedicated "Music" bus routed into it,
1409   » setup_audio
1423   » apply_master_volume
1427   » apply_music_volume
1434   » set_master_volume
1439   » set_music_volume
1444   » save_audio_settings
1450   » _process
1470   » skip_hours
1473   » tick_village_clock
1500   # Siege scheduling + resolution (runs in every scene)
1502   » current_siege_tier
1543   » deep_truly_empty
1546   » feast_ready
1563   » arrival_shield_on
1571   » begin_arrival_shield
1576   » orin_arrived
1581   » village_defense_power
1618   » warrior_count
1627   # DAY/NIGHT SHIFTS (GAME_BIBLE 7.3)
1636   » hour_of_day
1639   » warrior_shift
1642   » on_duty_shift
1646   » warrior_on_duty
1649   » on_duty_warrior_count
1658   » in_shift_change_window
1665   » tick_sieges
1686   » is_black_tide_number
1689   » next_siege_is_black_tide
1694   » tick_black_tide_omen
1704   » trigger_siege
1734   » tick_deep_catches
1753   » resolve_siege_offline
1797   » on_live_siege_ended
1816   » consume_away_report
1823   » is_building_operational
1826   # Food & hunger (Step 1: the hunger loop)
1859   » food_capacity
1863   » has_food
1867   » food_consumption_per_hour
1871   » farm_worker_count
1882   » food_production_per_hour
1891   » dock_worker_count
1901   » food_days_remaining
1908   » village_is_starving
1913   » manual_harvest_food
1920   # THE VILLAGE FOG (dev decision 2026-07-20): distance is ignorance
1929   » has_telepathy
1940   » has_communicator
1944   » try_build_whisperstone
1963   » _cost_text
1969   » village_presence
1977   » village_info_available
1983   » notify
1994   » tick_food
2012   # Villager needs & morale
2018   » is_villager_paired
2034   » villager_needs
2054   » villager_morale
2064   # Village-wide morale (0-100 internally, shown to the player as X/10)
2084   » count_adults
2091   # PERSONAL MORALE (GAME_BIBLE 5.5b)
2105   » personal_morale_target
2156   » get_personal_morale
2161   » tick_personal_morale
2170   » village_morale
2184   » admin_nudge_morale
2188   » village_morale_10
2204   » register_villager_deaths
2230   » register_villagers_added
2236   » all_buildings_operational
2242   » update_morale_meter_unlock
2247   » village_morale_multiplier
2250   # Morale consequences (rewards & punishments)
2262   # THE FADING OF DEEPWOOD (dev ask 2026-07-22): the village dying is a felt,
2277   # CORRUPTION (GAME_BIBLE 10): despair made mechanical, v2
2309   » is_warrior_villager
2314   » tick_rot
2345   » _spread_infection
2370   » on_wall_broken
2375   » get_villager_hp
2378   » village_in_despair
2382   » village_despair_depth
2389   » _despair_rate
2394   » tick_morale_effects
2489   » notify_urgent
2497   » tick_village_peril
2525   » _on_village_emptied
2537   » rescue_pool_open
2553   » is_important_figure
2561   » _trigger_village_lost
2568   » _show_village_lost_screen
2612   » transform_villager_to_demon
2640   » _spawn_demon_at
2657   » morale_defense_multiplier
2662   » morale_birth_multiplier
2667   # High-morale rewards (the carrot)
2671   » morale_high_factor
2676   » morale_speed_bonus
2681   » morale_regen_per_sec
2688   » village_is_celebrating
2697   » tick_village_tribute
2706   » grant_village_tribute
2716   » count_workers
2728   » generate_passive_income
2761   # AUTOSAVE (polish 2026-07-20)
2770   » autosave
2788   # "WHAT NOW?" (polish 2026-07-20)
2794   » next_objective
2832   # ONE-SHOT SFX (polish pass 2026-07-20)
2842   » play_sfx
2865   # BLUEPRINTS (GAME_BIBLE 5.2, dev decision 2026-07-20)
2879   » has_blueprint
2886   » grant_blueprint
2895   # MOVABLE BUILDINGS (GAME_BIBLE 5.2, dev decision 2026-07-20)
2907   # THE MINE (GAME_BIBLE 5.7, decided 2026-07-20 delegated)
2915   » tick_mine_yield
2940   # THE SHRINE (GAME_BIBLE 10, decided 2026-07-20 delegated)
2949   » shrine_unlocked
2952   » shrine_ready
2955   » try_cleanse
2977   # THE WATCHTOWER (GAME_BIBLE 7.1, decided 2026-07-20 delegated)
2991   » watchtower_warning_hours
2995   » siege_clock_visible
3000   » tick_watchtower_warning
3012   # THE WANDERER'S POST (GAME_BIBLE 5.6a)
3032   » grade_rank
3038   » marketplace_merchant_staffed
3041   » tick_wanderers
3054   » _wanderer_dwell_hours
3060   » _wanderer_pool
3072   » _wanderer_price
3085   » _wanderer_arrive
3109   » wanderer_price_now
3118   » buy_from_wanderer
3146   » tick_wages
3178   » count_leader_holders
3185   » get_village_income_multiplier
3188   » get_gestation_speed_multiplier
3192   » get_school_graduation_speed_multiplier
3195   » get_barracks_graduation_speed_multiplier
3200   # LEADERSHIP AUTOMATION
3218   # Barracks armory
3229   » arm_value_of
3233   » armed_warriors
3237   » forgemaster_supplying
3241   » deposit_one_arm
3257   » seated_leaders
3264   » apply_leadership_automation
3300   » auto_staff_villagers
3307   » try_auto_place
3326   » auto_research
3335   » auto_sell_surplus
3350   » auto_heal_villagers
3357   » auto_enroll_children
3372   » auto_repair_one
3390   # VILLAGE SELF-SUFFICIENCY (the time economy, dev vision 2026-07-22)
3402   » chore_domains
3434   » village_self_sufficiency
3451   » tick_self_sufficiency
3463   » find_available_parents
3478   » start_pairing
3494   » update_mating_houses
3515   » update_pregnancies
3527   » produce_child
3559   » remove_npc_avatar
3564   # School / Barracks enrollment
3566   # THE TEN (GAME_BIBLE §8)
3573   # THE HARVEST (GAME_BIBLE 9.3)
3581   # THE SHADOW COURT (GAME_BIBLE 11)
3587   » begin_harvest
3606   » raise_shadow_army
3619   » settle_shadow_court
3623   # NG+ (GAME_BIBLE 11): THE REWOUND HOUR
3639   » rewind_world_keep_player
3661   # THE CHRONICLE (GAME_BIBLE 11): the 100% ledger
3667   » chronicle
3740   » chronicle_check_complete
3751   » new_game_plus
3762   # THE FINALE GATE (GAME_BIBLE 9.1)
3767   » count_ruined_buildings
3775   » count_empty_role_slots
3790   » finale_gate_missing
3804   » finale_gate_open
3807   » ensure_the_ten
3812   » ten_freed
3816   » count_ten_freed
3824   » all_ten_freed
3827   » free_one_of_the_ten
3869   # The Doctor's escalating heal (GAME_BIBLE 5.5a)
3880   » doctor_heal_price
3883   » doctor_alive
3894   » _migrate_starting_civilians
3914   » decay_doctor_price
3924   » enroll_villager
3940   » update_school_enrollments
3955   » graduate_villager
3988   » load_deepest_level
3994   » record_level_reached
4005   » reset_for_new_game
4155   » has_save
4158   » save_game
4262   » load_game
4437   » delete_save
4441   » rescue_villager
4453   # Villager bonds (personal quests)
4458   » quest_event
4480   » find_villager_by_id
4488   » villager_quest_ready
4504   » turn_in_villager_quest
4522   » is_villager_rescued
4528   » assign_villager_to_role
4554   » remove_villager_by_id
4599   » remove_random_villager
4621   » report_death_toll
4645   » remove_one_skill_material
```

### boss.gd (4017 lines)
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
1635   » build_shard_aura
1639   » _make_shard
1664   » build_aura
1732   » process_passives
1775   » blink_short
1783   # procedural creature rigs
1796   » build_rig
1822   # Skinned bosses (PixelLab)
1825   » _build_boss_sprite
1842   » _update_boss_anim
1858   » _on_boss_anim_finished
1873   » _play_boss_ability_anim
1890   » _build_wizard_ground_aura
1929   » _rp
1937   » _rc
1944   » _rl
1954   » _rskull
1963   » rig_gravewarden
1981   » rig_frost
1993   » rig_cinder
2010   » rig_weaver
2028   » rig_stormcaller
2045   » rig_void
2059   » rig_seraph
2071   » rig_leviathan
2091   » rig_eclipse
2115   » rig_wizard
2137   » _wizard_void_face
2144   » _ember_block
2161   » get_display_name
2164   » _physics_process
2264   » process_hover
2274   » arena_width
2281   » effective_speed
2287   » choose_attack
2305   # The Fallen Wizard's active combo brain (level 100 only)
2357   » combo_length_for
2366   » is_wizard_boss
2371   » is_combo_boss
2376   » active_combos
2401   » drive_wizard
2416   » _drive_profile
2478   » combo_step_gap
2485   » combo_recovery_time
2493   » pick_combo_index
2504   » run_combo
2523   » run_ability
2562   » start_attack
2608   » set_cd
2611   » cooldown_mult
2625   » current_player_role
2635   » trigger_counter_mechanic
2651   # abilities
2653   » do_slam
2668   » do_charge
2681   » process_charge
2705   » do_barrage
2721   » do_nova
2735   » do_rain
2760   » do_teleport
2788   » do_summon
2810   » do_pillars
2838   # apex abilities
2842   » do_dive
2848   » process_dive
2874   » do_volley
2887   » do_meteors
2913   » do_vortex
2938   » do_beam
2979   » do_curse
3001   » do_doomring
3026   » allowed_clones
3030   » living_clones
3034   » do_clone
3058   # SIGNATURE ABILITIES (BOSSES.md §6)
3061   » spawn_hazard
3074   » _player_in
3079   » do_grave_grasp
3097   » do_rime_lance
3121   » do_magma_wake
3140   » do_web_snare
3155   » do_thunderstrike
3177   » do_void_rift
3206   » do_dissonant_scream
3232   » do_prayer_pyre
3253   » do_iron_maiden
3272   » do_pounce
3300   » do_splinter_burst
3319   » do_keening
3337   » do_ambush
3363   » do_impale
3387   » do_pincer_lunge
3417   » do_eruption
3441   » do_refraction
3467   » do_riposte_stance
3476   » _do_parry_counter
3485   » do_judgment
3513   » do_tidal_crush
3543   » do_black_sun
3563   » do_unwriting
3583   » _make_wall
3594   » _point_near_ray
3602   » _spawn_beam_line
3615   » _spawn_cone
3631   » _zone_marker
3643   # ability helpers
3645   » spawn_arrow
3656   » deal_player_damage
3668   » knockback_player_away
3676   » shake_camera
3680   » spawn_ring_telegraph
3695   » spawn_shockwave
3712   » spawn_ground_marker
3725   » erupt_pillar
3739   # combat / lifecycle
3741   » check_bump
3752   » flash_telegraph
3764   » apply_petrify
3770   » take_damage
3892   » enrage
3900   » frenzy
3926   » apply_knockback
3929   » flash_hit
3936   » play_sfx
3943   » update_health_bar
3955   » _boss_hud_banner
3962   » die
3985   » play_death_animation
3998   » spawn_death_particles
```

### player.gd (3966 lines)
```
37     # Fall damage
54     # Flight (Aetherwing relic)
75     # Mana
142    # Aiming
156    » get_weapon_stats
159    » has_weapon
287    » _ready
352    » maybe_play_intro
372    » grant_starter_weapons
386    » ensure_test_items
431    » ensure_admin_wand
444    » ensure_flight_relics_for_test
459    » grant_starter_gear
467    # worn-gear visuals (helmet / chest / pants overlays on the body)
471    » build_armor_visuals
498    » update_armor_visuals
511    » _apply_armor_piece
523    » build_weapon_guard
530    # The Shadow Monarch aura (hidden 7-stage passive, see GameState)
543    » build_shadow_aura
618    » update_shadow_aura
688    # THE SHADOW MONARCH'S POWERS
717    » monarch_tick
756    » _apply_true_form
787    » can_raise_shades
790    » raise_shade
816    » _rebalance_shades
828    » shade_defend_share
833    » fire_shadow_nova
856    » apply_fear_aura
872    » enter_long_dark
899    » build_wings_visual
907    » _make_wing
917    » update_wings
932    » _aim_length
943    » setup_body_anim
967    » build_sprite_frames
990    » load_frames_for
1006   » refresh_monarch_skin
1054   » _hooded_art_present
1058   » _ascended_art_present
1065   » load_texture
1087   » opaque_bounds
1108   » load_image_smart
1126   » _add_anim
1140   » _input
1144   » current_anim_state
1173   » feet_anchor_y
1181   » update_body_anim
1249   » spawn_dash_afterimage
1270   » apply_pending_player_state
1288   » play_sfx
1292   # combat/economy effect hooks. get_bonus_total = skill tree + worn gear
1295   » get_max_health
1299   » skill_damage_mult
1338   # Crit
1344   » get_crit_chance
1347   » get_crit_damage
1351   » roll_crit
1357   » show_hit
1367   » spawn_hit_spark
1412   » hit_stop
1418   » _process
1425   » _exit_tree
1431   » _impact_feedback
1436   # Timed buffs (from food). active_buffs[key] = {"v": amount, "until": t}.
1440   # RIFTWEAVING (Mage, mg_p1..p3): the two doors, Z to weave
1452   » has_portal_skill
1457   » portal_open_cost
1462   » portal_drain_per_second
1467   » try_weave_portal
1490   » tick_portals
1502   » close_portals
1518   » try_plant_building
1579   » do_portal_teleport
1589   » add_buff
1594   » use_item
1634   » buff_bonus
1643   » skill_cooldown_mult
1653   # Standing torches (G)
1659   » try_place_torch
1683   # Bar morale
1692   » bar_morale_active
1695   » grant_bar_morale
1708   # boss crowd-control on the PLAYER (set by boss signature abilities)
1723   » on_enemy_killed
1741   » apply_slow
1747   # boss crowd-control API (called by boss.gd signature abilities)
1749   » _cc_dur
1752   » apply_stun
1756   » apply_freeze
1760   » apply_root
1764   » apply_disorient
1768   » apply_poison
1775   » apply_pull
1781   » cc_action_locked
1786   » cc_move_locked
1792   » _poison_tick
1805   » clear_crowd_control
1815   » player_slow_mult
1821   » skill_move_speed_mult
1829   » on_equipment_changed
1836   » update_health_display
1841   # Mana pool
1843   » get_max_mana
1846   » get_mana_regen
1849   » spend_mana
1856   » gain_mana
1863   » build_mana_bar
1896   » update_mana_display
1911   » build_orbs
1939   » update_orbs
1965   » build_player_light
1982   » build_char_shadow
1985   » apply_knockback
2000   » knockback_sign_toward
2006   » _on_spear_tip_hit
2024   » wield_weapon
2055   » select_hotbar_slot
2072   » update_weapon_guard
2083   » get_aim_direction
2089   » update_weapon_visual
2124   » add_currency
2130   » take_damage
2205   » start_invincibility_flash
2216   » stop_invincibility_flash
2222   » die
2280   » drop_currency_on_death
2301   » apply_difficulty_death_penalty
2311   » update_currency_display
2320   » perform_dash
2337   » perform_admin_dash
2358   » _physics_process
2509   # Flight (Aetherwing)
2511   » has_flight
2523   » has_wings
2531   » levitate_mana_rate
2537   » has_fall_immunity
2544   » update_flight
2574   # Fall damage
2577   » handle_fall_landing
2585   » apply_fall_damage
2598   » perform_secondary_attack
2609   » cast_percent_burst
2642   » spawn_ruin_burst
2658   » perform_attack
2815   # Melee combo strings
2827   » combo_length
2849   » combo_finisher_mult
2855   » combo_is_live
2861   » combo_step
2872   » reset_combo
2878   » update_combo_label
2900   # Per-weapon crit character
2904   » weapon_crit_chance_bonus
2910   » weapon_crit_damage_bonus
2921   » spawn_swing_trail
2980   » weapon_grade_rank
2986   » grade_force_mult
2993   » grade_projectile_girth
2995   » grade_projectile_range
2998   » swing_slash_config
3045   » launch_swing_slash
3061   » launch_projectile
3090   » throw_javelin_volley
3109   » cast_wand_projectile
3135   # Relic powers (triggered mechanics on equipped relics; see inventory.gd
3144   » _now
3148   » has_relic_power
3155   » relic_power_value
3162   # Relic power effects (see has_relic_power)
3165   # Sage: the channelled beam (skill tree mg_s4b "Focusing Lens")
3179   » has_beam
3182   » beam_peak_mult
3186   » beam_ramp_mult
3189   » stop_beam
3195   » draw_beam
3213   » channel_beam
3258   » apply_omnivamp
3269   » apply_melee_skills
3310   » reflect_thorns
3324   » spawn_aegis_block
3340   » spawn_phoenix_revive
3358   » spawn_shock_ring
3381   » _unique_impact_point
3391   » on_projectile_hit
3403   » advance_swing_charge
3429   » apply_excellent_effect
3529   # Excellent-weapon hit visuals (all procedural, world-space, self-cleaning)
3538   » spawn_lightning_bolt
3576   » _jagged_points
3592   » spawn_blood_steal
3611   » _circle_points
3619   » spawn_gold_sparks
3645   » spawn_execute_flash
3665   » collapse_singularity
3683   » spawn_singularity_visual
3713   » unleash_ragnarok
3739   » spawn_ragnarok_ring
3756   » spawn_bane_flash
3772   » spawn_chrono_flash
3800   » spawn_echo_ring
3817   » spawn_soul_wisps
3836   » closest_body
3846   » animate_sword
3859   » animate_spear
3874   » animate_bow
3884   » spawn_arrow
3932   » cast_wand
3949   » cast_wand_nuke
```

### dungeon_interior.gd (2628 lines)
```
388    » _ready
422    » setup_exit_button
431    » start_music
453    » music_pitch_for
462    # layout selection
464    » get_layout_slot
467    » is_boss_level
471    » get_layout
477    # REGULAR FLOOR LAYOUTS
499    » get_regular_theme
502    » generate_regular_layout
521    # reachable primitives
523    » _ledge
529    » _stack
542    » _span_with_access
552    # the twelve themes
554    » _theme_terraces
567    » _theme_isles
578    » _theme_pillared_hall
588    » _theme_chasm_bridges
597    » _theme_overwatch
604    » _theme_gauntlet
614    » _theme_twin_towers
620    » _theme_amphitheatre
632    » _theme_roost
644    » _theme_warren
655    » _theme_sunken_court
664    » _theme_cascade
679    » total_boss_levels
686    » get_boss_id
704    » get_boss_counter
710    » build_counter_sequence
724    » get_boss_arena
727    » get_level_width
732    » get_level_ceiling
737    # boss arena platform generators
747    » generate_boss_platforms
781    » add_sky_tier
796    » gen_gravewarden
818    » gen_frost
840    » gen_cinder
864    » gen_weaver
888    » gen_stormcaller
911    » gen_void
931    # the deep (35-90)
942    » gen_hollow_choir
968    » gen_ashen_penitent
995    » gen_gaoler
1021   » gen_sablefang
1047   » gen_effigy
1070   » gen_mourncaller
1096   » gen_unseen
1117   » gen_warden_of_nails
1141   » gen_twin_despair
1163   » gen_cinderking
1191   » gen_glass_saint
1217   » gen_last_man
1240   # apex arena generators
1246   » gen_seraph
1272   » gen_leviathan
1288   » gen_eclipse
1317   » gen_wizard
1335   # level (re)building
1337   » build_level_visuals
1367   » build_floor_surprises
1384   » _dgn_cache
1400   » _dgn_hazard
1405   » build_gates
1420   » on_gate_used
1427   » go_to_level
1433   » build_background
1461   » build_wall_layer
1488   » build_ground_and_walls
1516   » build_wall
1535   » build_platforms
1562   » build_stalactites
1579   » build_cave_life
1627   » _glow_sprite
1637   » _mushroom_cluster
1659   » _crystal_cluster
1673   » _moss_patch
1681   » _ceiling_root
1692   » make_additive_material
1700   » _ensure_ambient
1708   » build_torches
1738   » build_torch
1791   » place_mines
1817   » place_hazards
1843   » place_mine
1848   » place_player_at_entry
1861   » _place_deep_shrine
1884   # combat flow (mirrors the old overworld dungeon_manager.gd)
1888   » _softcapped_mult
1893   » get_level_scaling
1900   » spawn_level_combat
1961   » play_empty_throne
1972   » play_final_victory
2006   » spawn_deep_rescue
2056   # normal-level mob composition
2076   » block_position
2079   » op_pool_for_level
2087   » op_fraction
2094   » spawn_level_mobs
2123   » pick_random_subset
2128   » spawn_kind
2139   » spawn_special_mob
2154   # THE HARVEST (GAME_BIBLE 9.3 / 9.4)
2169   » _physics_process
2209   » _apply_devour_tier
2223   » _spawn_transformed
2255   » spawn_enemy
2292   » assign_enemy_behavior
2304   » spawn_boss
2336   » get_material_for_level
2349   » roll_material_drop
2359   # Gear loot
2401   » roll_gear_drop
2434   » _gear_unowned
2443   » _give_gear
2452   » _on_combatant_died
2493   » play_orin_glimpse
2496   # PROVING GROUNDS (admin test arena)
2501   » build_proving_grounds
2555   » _proving_label
2567   » exit_dungeon
2577   » update_level_label
2604   » _straggler_hint
2625   » show_notification
```

### building.gd (2238 lines)
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
585    # wall torches (auto day/night lighting)
611    » build_torch_layer
672    » position_torches
686    » update_torches
699    » _add_mat
704    » _fire_gradient
710    # villagers at work (visible busy-ness once people are employed here)
736    # attached work-yards
760    » area_world_half
764    » area_offset_x
786    » employed_count
796    » play_door_anim
820    » refresh_workers
893    # attached work-yard props
894    » _a_rect
902    » _a_disc
909    » _a_line
916    # Farm crops (dynamic)
921    » _update_farm_crops
933    » _draw_crop
958    » _spawn_harvest_puff
974    » _spawn_harvest_float
987    » build_work_area
1122   # the Bar's fun music + player morale
1162   » update_bar_music
1178   # upgrades
1180   » can_upgrade
1183   » upgrade_cost
1187   » try_upgrade
1203   » effective_slots
1209   # visuals
1211   » refresh_visual
1235   » build_intact
1288   # shared tiny draw helpers for the named silhouettes
1289   » _disc
1296   » _tri
1299   » _ln
1308   » _lit_col
1311   » _win
1319   » draw_named_building
1345   » _b_government
1365   » _b_school
1382   » _b_farm
1403   » _b_hospital
1421   » _b_barracks
1443   » _b_dock
1466   » _b_lab
1486   » _b_bank
1521   » _b_blacksmith
1552   » _b_tavern
1590   » _b_bar
1643   » market_sections
1646   » _b_market
1673   » _b_builder
1701   » build_half
1715   » build_destroyed
1734   # body / roofs / features
1736   » add_body
1743   » build_roof
1782   » build_feature
1815   » add_pennant
1824   » add_window_grid
1857   » _side_centers
1866   » add_door
1871   » add_cracks
1886   » add_scorch
1901   » add_glow
1916   » add_fire
1951   » build_shine
1962   » flash_body
1969   » spawn_hit_debris
1991   # small draw helpers
1993   » add_poly
1999   » add_rect
2007   » rect_poly
2010   » ruined_body_poly
2020   » circle_poly
2027   # health bar
2029   » build_health_bar
2042   » update_health_bar
2054   # gameplay
2056   » _on_body_entered
2065   » _on_body_exited
2073   » _process
2192   » get_roles
2195   » get_role_holders
2202   » is_role_full
2205   » get_eligible_villagers
2226   » open_assign_ui
2231   » _on_child_produced
```

### enemy.gd (1409 lines)
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
330    » update_body_color
335    » play_sfx
347    » apply_block_archetype
355    » apply_mixed_archetype
378    » build_character
430    » _add_skull
439    » _add_socket
442    » _add_shoulders
449    » _add_poly
455    » _add_dot
463    # Spritesheet-skinned enemies (downloaded art)
467    » _build_sprite_visual
495    » _update_enemy_anim
507    » setup_weapon_visual
523    » get_aim_direction
530    » update_weapon_icon_position
542    » _physics_process
672    » try_jump
684    » count_nearby_enemies
696    » check_bump
715    » _melee_connects
722    » try_attack
742    » finish_attack
746    » try_deal_melee_damage
758    » _telegraph_weapon
763    » animate_sword_attack
777    » animate_spear_attack
792    » animate_bow_attack
805    » _loose_arrow
815    # Behavior archetypes
823    » set_behavior
849    # SUPER-MOB (elite) presence + signature slam
869    » _become_super_mob
892    » _tick_elite_slam
908    » _elite_slam
918    » _spawn_slam_ring
937    » _elite_shockwave
960    » _spawn_shock_burst
982    » process_behavior
1009   » _living_allies
1021   » heal_nearby_allies
1034   » summon_minions
1055   » cast_hex_bolt
1070   » perform_lunge
1083   » spawn_block_spark
1087   » spawn_status_spark
1109   » on_soul_split_wand
1130   » take_damage
1154   » apply_knockback
1162   » flash_hit
1176   » update_health_bar
1182   » die
1256   » _wait_until_unwatched
1267   » play_death_animation
1284   » spawn_death_particles
1324   » spawn_coin_popup
1361   » spawn_material_popup
1386   » respawn
```

### inventory.gd (1459 lines)
```
496    # 
504    # 
797    # TERRARIA-STYLE TOOLTIP (dev ask 2026-07-22)
920    # 
1013   # 
1020   # 
1083   # tiny drawing primitives (children of the icon ColorRect)
1100   # armour silhouettes, one per equipment slot (tinted to the item colour)
1157   # per-item symbols (drawn in the target's 0..w / 0..h local space)
1334   » _init
1344   » get_count
1353   » add_item
1385   » remove_item
1406   » transfer_to
1422   » transfer_slot
1444   » to_save_data
1453   » from_save_data
```

### main.gd (1458 lines)
```
180    » building_names
224    » _ready
295    » _maybe_begin_feast
318    » show_away_report
353    » generate_village
413    » building_def
422    » create_building
439    » spawn_placed_torches
445    » generate_houses
517    » spawn_existing_villager_avatars
554    » arm_arrival_battle
561    » _check_arrival_trigger
594    » _west_wall_x
610    » stage_arrival_battle
649    » trigger_arrival_scene
665    » activate_arrival_combat
672    » _on_arrival_raider_died
700    » _check_arrival_talk
724    » play_arrival_talk
765    » _spawn_reveal_survivors
799    » _autosave_on_arrival
802    » stamp_rewound_arrival
811    » orin_midgame_taunt
824    » warn_wounded_corps
845    » build_escape_ward
867    » _on_escape_attempt
902    » _spawn_gauntlet_wave
915    » _on_gauntlet_raider_died
928    » announce_orin_arrival
944    » spawn_adventurers
959    » is_villager_busy_mating
975    » offscreen_spawn
987    » find_avatar_spawn_position
1003   » _process
1011   » start_music
1019   » apply_save_data
1058   » generate_harvestables
1100   » spawn_harvest_node
1113   » generate_grass
1124   » generate_traps
1132   » generate_platform_traps
1156   » place_trap
1161   » generate_mountains
1263   » _extend_ridges_across_world
1298   » fence_the_camera
1306   » fit_sky_to_world
1317   » build_ground_skin
1369   » _tile_top_padding
1381   » generate_mountain_shape
1405   » generate_clouds
1434   » generate_cloud_shape
1448   » spawn_tuft
```

### underdark.gd (1181 lines)
```
27     # geometry
80     # the cave mouth
112    # doors
120    # streaming mobs
134    » _ready
173    » band_floor_y
178    » _stair_steps
181    » _stair_end_x
185    » _retire_surface_door
207    » _carve_ground_skin
223    » _plan_bands
259    » _build_dark_backdrop
269    » _slab
300    » _build_mouth_and_stair
372    » _climbable_platforms
380    » _build_bands
443    » _plan_shafts
465    » _build_shaft_ladders
491    » _slab_with_hole
500    » _seg_at
506    » _brazier
548    # the cave is alive
562    » _build_cave_life
591    » _cl_glow
601    » _cl_mushrooms
623    » _cl_crystals
636    » _cl_moss
644    » _cl_root
654    # the hidden doors
655    » _place_doors
697    # ore seams
698    » _place_seams
709    # streamed cave mobs (the east road's three rules, underground)
710    » _process
721    » _hold_the_dark_lit
728    » _stream_tick
741    » _band_of
744    » _stream
772    » _sector_center
778    » _prune
788    » _populate
818    » live_count
826    # traps, chests, and the rune vaults
827    » _trap
836    » _stock_chest
861    » _add_chest
871    » _place_chests
890    » _plan_pits
912    » _build_pits
953    » spring_ambush
982    » _build_hidden_lofts
1024   » _build_rune_vaults
1067   » rune_lit
1081   # the arch you walk into
1091   » _build_cave_prompt
1146   » _tick_cave_mouth
```

### npc.gd (1110 lines)
```
28     » _village_span
105    » _ready
179    » build_visual
184    » _body_px
196    » apply_size
259    » _villager_skin
275    » _build_villager_sprite
291    » _update_villager_anim
299    » refresh_size_if_needed
304    » build_hover_panel
328    » build_health_bar
370    » _nearest_threat
383    » _tick_defence
400    » is_fleeing
403    » take_damage
416    » update_health_bar_fill
424    » apply_despair_visual
450    » update_health_bar_display
472    » die
486    » _physics_process
629    » cheer
637    » _apply_cheer
680    » pick_new_state
689    » find_villager_data
695    » _on_body_entered
699    » _on_body_exited
703    » _process
728    » maybe_recount_news
741    » _apply_shadow_form
747    » try_doctor_heal
783    » _play_doctor_sfx
794    » try_bond_interaction
819    # mood talk
829    » tick_mood_talk
840    » say_mood_line
846    » mood_lines
879    » _monarch_reaction_lines
900    » refresh_wander_bounds
912    » get_building_for_role
915    » roll_new_cycle
927    » tick_building_visits
958    » pick_visit_building
976    » enter_building_node
980    » _complete_enter
992    » exit_building
1010   » info_fields
1063   » bond_fields
1076   » show_info
1087   » is_hovering
1090   » update_hover_panel
```

### special_mob.gd (1050 lines)
```
3      # 
18     # 
85     # Elite affixes
131    # Statuses. Special mobs used to have NO apply_status, so every burn/poison/
144    » apply_status
164    » status_slow_mult
167    » tick_statuses
258    » _ready
305    » build_collision
321    » _physics_process
374    # per-kind behaviour
376    » act_flyer
393    » act_bomber
403    » prime_and_explode
416    » explode
429    » act_charger
468    » act_spitter
480    » act_stalker
524    » act_blink_archer
539    » act_hexer
553    » cast_hex_ring
574    » act_runecaster
581    » cast_runes
606    » act_warlock
621    # caster/teleport helpers
623    » face_player
629    » arena_width
635    » teleport_to
643    » blink_to_flank
647    » spawn_teleport_puff
665    » spawn_sigil
677    » erupt_rune
690    # shared combat
692    » deal_contact_damage
696    » fire_projectile
702    » take_damage
729    » apply_knockback
737    » die
750    # visuals
752    » set_flash
759    » clear_flash
766    » add_part
771    » build_visual
791    » _build_mob_sprite
804    » _update_mob_anim
812    » poly
817    » circle_points
827    » build_flyer_visual
846    » build_bomber_visual
863    » build_charger_visual
881    » build_spitter_visual
900    » build_stalker_visual
910    » build_blink_archer_visual
932    » build_hexer_visual
944    » build_runecaster_visual
961    » build_warlock_visual
975    » _robe
979    » build_elite_glow
993    » build_health_bar
1007   » update_health_bar
1011   » play_sfx
1019   » spawn_blast
1032   » spawn_death_particles
```

### wizard.gd (877 lines)
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
298    » apply_meteor_impact
308    » spawn_impact_fx
339    # take hits
343    » take_damage
355    » die
365    # downed / reform
367    » build_fireball
459    » enter_downed_state
491    » _hide_gfx
497    » respawn
541    » _set_fireball_flames
550    » update_ember_growth
561    » spawn_revive_flash
574    » spawn_puff
594    » _additive_material
599    # visuals
601    » build_visual
660    » _build_orin_sprite
675    » _on_orin_anim_finished
679    » build_staff
701    » start_idle_animation
710    » animate_cast
724    » face_toward
731    » build_health_bar
748    » update_health_bar_fill
752    » update_health_bar_display
773    » build_proximity_area
787    » _on_body_entered
791    » _on_body_exited
795    » build_hover_panel
820    » is_hovering
823    » update_hover_panel
828    # geometry util
830    » _circle_points
838    » _ellipse_points
848    » _flame_points
862    » _rock_points
871    » _star_points
```

### adventurer.gd (657 lines)
```
29     » play_sfx
53     # signature ability state (each adventurer runs a DIFFERENT mechanic)
92     » _ready
147    » hero_color
150    » _build_visual
267    » _refresh_prompt
275    » _apply_station_groups
283    » _physics_process
313    » _update_adv_anim
323    » _swing_lunge
340    » _tick_bark
352    » _update_hp_bar
364    » _cycle_station
376    » _station_anchor_x
414    » _village_center_x
430    » _ensure_anchor
437    » _hold_station
466    » _nearest_raider
492    » _attack_damage
506    » _loose_arrow
519    » _second_raider
531    » _fight
605    » take_damage
642    » on_siege_ended
645    » die
656    » apply_knockback
```

### assign_ui.gd (549 lines)
```
6      » _ready
11     » open_for_building
16     » close
20     » esc_is_open
23     » esc_close
26     » refresh
62     » add_market_stall_section
106    » _on_stall_sell
124    » add_relocate_section
142    » add_repair_section
188    » _on_repair
209    » add_upgrade_section
240    » _on_upgrade
258    » add_research_section
312    » _on_build_whisperstone
320    » _on_research
344    » smithy_max_rank
347    » smithy_stock
369    » smithy_price
372    » add_smithy_section
391    » _on_buy_gear
414    » add_armory_section
464    » _on_deposit_arm
477    » add_role_section
522    » _on_assign
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
