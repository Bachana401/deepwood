# Deepwood — The Boss Ladder

> **Status: DESIGN, not built.** Nothing here is implemented yet. This exists so
> the dev can veto before a single generation is spent. Build order at the end.

---

## 1. The problem, measured

Boss floors are every 5th level, so the 100-floor dungeon has **22 boss fights**.
There are **10 unique bosses**. `dungeon_interior.gd get_boss_id()` does this:

```gdscript
var n = int(level / 5)
return CYCLING_BOSSES[max(0, n - 1) % CYCLING_BOSSES.size()]
```

That `%` wraps a **6-boss** roster across the 18 non-finale boss floors, so **each
cycling boss is fought three times** — Gravewarden on 5, again on 35, again on 65,
identical moveset, bigger numbers. Only 95/98/99/100 (Seraph, Leviathan, Eclipse,
Wizard) are unique. **12 of 22 fights are reruns.**

Two deeper problems the repeat is hiding:

- **Only 3 of 10 bosses have combo AI at all** (`BOSS_COMBOS`: seraph, leviathan,
  eclipse). The other seven pick single abilities off a 3-item list.
- **The whole roster shares one vocabulary of ~13 verbs** (`slam`, `charge`,
  `summon`, `nova`, `teleport`, `rain`, `barrage`, `pillars`, `beam`, `volley`,
  `meteors`, `vortex`, `dive`). Even the *unique* bosses are recombinations. And
  difficulty scales by multiplying HP/damage — i.e. exactly the "it one-shots you"
  difficulty the dev rejected.

**So this is not "add 12 bosses." The vocabulary has to exist first.**

---

## 2. The mechanics vocabulary (the actual work)

Difficulty should come from *the boss refusing to be fought carelessly*, never
from raw numbers. Everything below is **reactive** — it responds to what the
player does. Each is a `passive` on a boss (the `passives` array already exists;
`blink_on_hit` and `crumbling_aura` are the only two so far).

**The dev's examples, built for real:**

| id | what it does | how the player beats it |
|---|---|---|
| `sidestep` | % chance to blink 1 body-width out of an incoming **melee** swing, leaving an afterimage | bait it, or use reach/projectiles |
| `riposte` | attacking it **during its tell window** (the wind-up frames) = it counters, hard | read the tell; strike in the recovery, not the wind-up |
| `phase` | goes **intangible** for ~2s — attacks pass clean through (Obito) | stop swinging, reposition, punish the exit frame |
| `skyfall` | anti-air: punishes the player for being **airborne** (now that the Monarch levitates from 1/7) | fight it on the ground; levitation is not a free win |

**More of the same family:**

| id | what it does | how the player beats it |
|---|---|---|
| `mirror` | reflects **projectiles** back at the caster | close to melee; stop spamming bow/wand |
| `rhythm_punish` | every **Nth consecutive** hit is countered — punishes mashing | vary the rhythm, drop a beat |
| `stagger_armour` | immune to chip damage; only **heavy/charged** hits break the guard | commit to slow hits under pressure |
| `soulbind` | heals from your hits until you break its **rune adds** | kill the adds first, then burst |
| `tether` | chains the player; damage ramps while the chain holds | break **line of sight**, or run the chain out |
| `false_twin` | splits into copies; only **one** is real, the fakes hit back | find the tell (the real one casts a shadow) |
| `afterimage_trap` | marks the ground where you **stood** 2s ago; it detonates | keep moving; never stand still |
| `covenant` | two bodies, **one** HP pool — one healing the other | kill both inside a window; split your damage |
| `dread_ward` | takes damage only from **behind / above** | it must be flanked, not out-DPS'd |
| `famine` | drains your **mana/stamina** on contact, not HP | disengage windows matter; resource discipline |

**None of these raise damage.** They gate *how* you're allowed to fight. A player
with good gear still wins — but only by reading the fight.

### Escalation rule
Depth = **more simultaneous mechanics**, not bigger numbers.

- **Floors 5–30** — 1 mechanic each. Teaching floors.
- **Floors 35–60** — 2 stacked.
- **Floors 65–90** — 3 stacked, and they interact (e.g. `phase` + `afterimage_trap`
  = it's untouchable *and* you can't stand still).
- **Floors 95–100** — 4+, plus phase changes.

HP/damage curves stay on the existing L100 soft-cap (see `deepwood_endgame_balance`).

---

## 3. The 22-boss ladder

Theme is Deepwood: **despair, soulless humans turned, burning devils, the Monarch
of Despair**. Applied where it helps; ignored where a mechanic is better served
otherwise (dev's call: *"mechanics are the most important"*).

### Existing — keep, but give each ONE mechanic + real combos
| Fl | Boss | New mechanic | Note |
|---|---|---|---|
| 5 | The Gravewarden | — | teaching fight: pure pattern |
| 10 | Frost Monarch | `stagger_armour` | teaches committing to heavy hits |
| 15 | Cinder Colossus | `riposte` | teaches reading a tell |
| 20 | The Weaver | `soulbind` | teaches kill-the-adds |
| 25 | Stormcaller | `skyfall` | teaches the ground is safer |
| 30 | Void Sovereign | `sidestep` | teaches baiting |

### NEW — the twelve that replace the reruns
| Fl | Boss | Mechanics | Identity |
|---|---|---|---|
| 35 | **The Hollow Choir** | `false_twin` + `soulbind` | villagers fused into one chorus of soulless mouths; the fakes sing, the real one doesn't |
| 40 | **The Ashen Penitent** | `riposte` + `famine` | a burning devil locked mid-prayer; strike during the prayer and it answers |
| 45 | **The Gaoler** | `tether` + `stagger_armour` | warden of the soul-pits; chains you to the floor you stand on |
| 50 | **Sablefang** | `sidestep` + `rhythm_punish` | a beast that has learned your habits; it dodges what you repeat |
| 55 | **The Effigy** | `stagger_armour` + `afterimage_trap` | a burning wicker giant; it sows fire where you *were* |
| 60 | **Mourncaller** | `soulbind` + `mirror` | a widow of the Harvest; grief reflects |
| 65 | **The Unseen** | `phase` + `afterimage_trap` | intangible; you cannot hit it *and* cannot stand still |
| 70 | **Warden of Nails** | `skyfall` + `dread_ward` + `riposte` | anti-air, must be flanked, punishes the wind-up |
| 75 | **The Twin Despair** | `covenant` + `sidestep` + `phase` | two bodies one soul, each healing the other |
| 80 | **The Cinderking** | `afterimage_trap` + `mirror` + `famine` | devil-lord of the burning deep |
| 85 | **The Glass Saint** | `mirror` + `dread_ward` + `rhythm_punish` | reflects everything; must be flanked in melee, without a rhythm |
| 90 | **The Last Man** | `rhythm_punish` + `phase` + `covenant` | the final soulless human; fights *exactly like the player does* |

### Finale — keep, deepen
| Fl | Boss | Add |
|---|---|---|
| 95 | Seraph | + `dread_ward` |
| 98 | Leviathan | + `skyfall`, + `tether` |
| 99 | Eclipse | + `phase`, + `false_twin` |
| 100 | The Fallen Wizard | + `covenant` (with his clones), + `riposte` |

**Every floor now has a distinct fight.** `CYCLING_BOSSES` and its `%` are deleted.

---

## 4. Build order

1. **Mechanics first, no art.** Implement the 14 passives + per-boss combo tables,
   and prove each with a headless test (a `sidestep` boss must measurably dodge; a
   `riposte` boss must punish a tell-window hit and *not* a recovery hit). The
   ladder is playable with existing sprites at this point — the fights are real
   before a single pixel is drawn.
2. **Retire the modulo.** `get_boss_id` reads a flat 22-entry table.
3. **Art, 12 bosses.** ~10–25 generations each → **~150–300** of the remaining
   ~1,312. Per boss: `create_character` (v3) + idle/walk/attack/hurt/death, and
   `levitate` for the flyers.
4. **Per-frame QC on every clip.** Contact-sheet every animation
   (`tool_sheet.gd`); reject shape-shifting, drifting identity, and tools/limbs
   popping in and out — the failure modes already caught on the hooded hero
   (template anims wiped the hood), the trade clips (empty-handed lead-in frames)
   and the dash (superman pose). **`mode="v3"` only** — template animations
   regenerate from the description and destroy a design.

## 5. Dev decisions — LOCKED (2026-07-17)

**`phase` is OBITO-STYLE.** It goes intangible ~2s **and can still attack you
while intangible** — it phases reactively the instant your blade lands, then hits
you out of the ghost. You can never trade with it; you have to bait the phase out
first. It gets a **visible tell** (translucent/ghosted) so the fight is hard
because you misread it, not because it's unfair. That means `phase` DOES need an
art/shader pass, not just a flag.

**Every boss gets its own arena, built against it.** *"Get extremely creative."*
`BOSS_ARENAS` is keyed by boss id. The arena is part of the fight, not
decoration — `skyfall` is meaningless in an open room and lethal under a low
ceiling with pillars; `tether` wants sight-blockers to break; `dread_ward` wants
flankable geometry. Design each arena WITH its boss's mechanics, not after.

### ✅ BUILT — 22/22, and how they're kept honest

All 22 arenas exist (`gen_<boss>` in `dungeon_interior.gd`), each designed
against its boss's stack using the mechanics' real numbers: `TETHER_RANGE` 420,
`FAMINE_RADIUS` 120, `SKYFALL_RADIUS` 320, `MIRROR_RADIUS` 90, `TRAP_PERIOD`
2.2s. `test_arena_node.gd` (54 checks) asserts each room carries the geometry
its boss needs — the Gaoler's cover sits inside the leash, the Warden's ceiling
is the lowest in the game and no perch in it escapes skyfall, Twin Despair's
room is exactly symmetric, Sablefang's has no repeating gap to fall into a
rhythm on, the Hollow Choir's central floor is bare so shadows are readable.

**Two traps this ladder has now fallen into twice.**

1. **The silent fallback.** `generate_boss_platforms` used to end in
   `_: return gen_gravewarden(w, h)`, so 12 of 22 bosses fought in the *same
   tomb*. It was the `CYCLING_BOSSES` modulo again, one layer down, and
   invisible from inside the game because the room rendered fine. There is no
   fallback now: an unknown id is a `push_error`, and the suite asserts no two
   layouts are identical.
2. **Walls that read as cover.** This is a side-scroller: you cannot walk
   *around* a pillar. The player's measured single-jump rise is **~92px**
   (`test_jump_node.gd`), so the first draft's 300-tall pillars were walls
   between the player and the exit gate — five uncompletable floors that looked
   perfectly normal. Floor-rooted cover is capped at `VAULT_HEIGHT` (88) by
   construction, and the suite fails on any solid taller than the measured jump.

**New primitive: cover** (`{"solid": true}`). Every platform in the game used to
be a one-way drop-through ledge, which quietly made half of this document
undeliverable. Cover is solid from all sides and sits on `COVER_LAYER` (bit 5)
*in addition* to ground — its own bit because a raycast ignores `one_way`, so
sighting against layer 1 would let ordinary scenery break the tether. `tether`
now snaps on broken line of sight, which is the counter-play this doc always
claimed it had.

**Floor 100's ascended Monarch: candidate #4** — the crowned king, heavy cloak
sweeping behind, regal. Preserved as PixelLab object
`5901ec07-d4af-4af6-b48d-954545da58b7`. **His eyes burn — fiery, lit, on fire.**
He keeps the hood and the void face, so the ascension reads as the same man
risen rather than a new character; the fire in the hood is the only thing
looking back.
