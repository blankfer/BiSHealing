# The flight deck - the radar's replacement (plan, 15 Nov 2026)

Arn, 15 Nov 2026: "we need a target and target of target outline area ... too much moving mouse around left and right to
click buttons, lets condense them into the bottom ... the radar i like the clean no box ... our party under that, in a
pyramid formation tank always on top". Then: "B, this is to replace radar, this is going to have a radar theme ... it's
going to dynamically grow based on group size seamlessly". Then: public; all tanks on one row; a small interrupt beside
everyone like the cures, shown only when needed; the spells' real icons; Grounding on the bottom row. Then: a support mode
for classes that don't heal, Riptide kept up, and the heal-over-time classes tracking their HoTs.

Mockup (layout B, live size switch, support mode): https://claude.ai/artifact/8pvDjUiXTbhv8WN5azVgLr
Spell research (private, names account folders): `_bisdev/docs/spells/` - interrupts.md, cleanses.md, keepups.md.

## Decided

- **It replaces the radar.** The radar's colours and plate, no boxes round the cells. The engineer view's efficiency: one
  health bar per person in class colour, heals on their way in cyan, the overheal/hover ghost as now.
- **Top to bottom, in the middle column:** the mana / boss fuel bar -> LOS, RANGE, OVER/H under it -> the TANK ROW -> the
  party / raid, five to a row -> the DECK. Left and right rails: information only, nothing to click.
- **The tank row:** EVERY tank on this one row, all the same width, together filling the row left of the TARGET BOX.
  One tank = one long bar. The target box (outlined, labelled "target · its target") holds two cells the size of a
  regular cell: your target (hostile binds on it, its cast, the kick) and its target (your heal binds on it - usually the
  tank being hit).
- **Everyone else:** five to a row, one size, in group order. In a party the first row holds five minus the tanks.
- **It only grows downward.** The width is fixed; rows come and go below. Out of a fight only: in a fight the client
  will not move or show/hide a secure button, so a join/leave mid-fight is laid out when the fight ends (as the radar).
- **Small icons on each cell, the spells' own icons, shown only while needed:**
  - right end: a CURE icon per kind you can remove (the client's dispel marker, as now) and a KICK icon while the enemy
    that person targets is casting (`FG.Casting`, as the PvP cells), casting your class's interrupt at it;
  - left end: YOUR heals over time with the client's countdown swipe (FA.HOTS, as now);
  - the tank cells: a KEEP-UP mark when your one-target keep-up spell is missing (below).
- **The deck (every click in one band, left to right):** SELF (the keep-on-yourself buff by name, with its charges -
  Water Shield, Inner Fire) · RAID KICK (Grounding Totem; Psychic Scream / Howl of Terror / War Stomp for others) ·
  MANA (Mana Tide, potion, Mana Spring, drink) · TOTEMS in use order CALL > BRING > RECALL.
- **Rails (information):** regen %, the five-second rule, role; self-buff charges, totem timers; room kept for 3D totems.
- **Support mode:** a class that doesn't heal (or anyone who picks it) gets the same people, smaller, with only what
  THEIR class can do lit: warlock = the Felhunter's Devour Magic + Spell Lock, mage = Remove Lesser Curse + Counterspell,
  rogue / warrior = the kick. No health reading. Offered on first load to a class that can't heal; never forced.
- **Controller:** the D-pad walks the rows top to bottom (tank row -> target box -> each row -> the deck), left/right
  inside a row; A B X Y are your binds on the lit person, A presses the lit deck button. The same header and route as
  controller healing (PadHeal.lua, #203) - one build.

## Heals over time and keep-ups (Arn: "lets not forget how they can track their hots on the frames")

Drawn by the CLIENT (AuraContainer slots, `HELPFUL|PLAYER` + includeSpellIDs - friendly buffs take a spell-id filter;
solved.md: friendly debuffs and hostile buffs do not). The swipe is the client's; Lua reads nothing in a fight.

| class | on the cells (yours, with countdown) | keep-up mark on the tank when missing |
|---|---|---|
| Shaman | Riptide (408521 / 1239242 / 1239243) | Riptide (12 s cd, ~1 target) |
| Priest | Renew (all ranks; Forever lets several priests' Renews stack - PLAYER filter matters), Power Word: Shield, Prayer of Mending | Prayer of Mending (one per priest); PW:S shows Weakened Soul (6788, plain HARMFUL - anyone's blocks yours) |
| Druid | Rejuvenation, Regrowth, Wild Growth (7 s party burst) | none by default (Rejuvenation fits 4-6 people - missing on others is normal) |
| Paladin | Light's Vigil | Light's Vigil (one per party) |

- **Two spells land under another id:** Prayer of Mending's aura is 401877 / 1240848 / 1240849 (cast 401859 /
  1240826 / 1240827); Light's Vigil's aura is 1310909 / 1311593 / 1311597 (cast 1310911 / 1311590 / 1311595). FA.HotIds
  reads the BOOK (cast ids), so those families must list their AURA ids. Probe 2 in keepups.md confirms.
- **The missing mark = the stabilizer trick:** a mark drawn UNDER, the client's aura icon (opaque) drawn OVER it while the
  spell is up; nothing in Lua decides "missing". On the mark, the spell's cooldown swipe from the client's own duration
  object (`C_Spell.GetSpellCooldownDuration`, as the radar's waits) - bright = missing and ready.
- Only one-target keep-ups get a mark (Riptide, Prayer of Mending, Light's Vigil), and only on the tank row: missing on
  everyone else is normal. A HoT that fits many people never gets a "missing" mark.
- **Riptide first on a heal bind** is built separately (#205): drop Riptide on Chain Heal -> Riptide when ready, aimed.

## What the research found broken in today's code (fix in step 1)

- Warlock: no Spell Lock (a PET spell - `FM.BookIds` reads only the player's book) and no Devour Magic in `FA.CURES`.
- Druid: `FG.KICK.DRUID` lacks Feral Charge (1238122 on Forever; EllesmereUI's 16979 is stale - CONFLICT, probe).
- Protection warrior: Pummel needs Berserker Stance - `/cast [stance:3] Pummel; Shield Bash`.
- Spell Lock should cast its top rank (8 s lockout), not rank 1.
- Psychic Scream is targetless: off the per-person list, onto the deck (the radar's chaff already has it).
- `FA.CURES.MAGE` starts with "Remove Curse" (mages only have Remove Lesser Curse).
- `FM.CLASS_DEFAULTS` puts Cleanse on a paladin's shift-left; below 42 only Purify exists.
- Backups not listed: Repentance, Intimidation, Bash, Concussion Blow, Intimidating Shout, Kidney Shot, Blind.

## Build steps (each its own PR, behind a switch until the last)

1. **Spell tables** from the research (interrupts, cures, keep-ups, aura ids) + the fixes above. Tests from the tables.
2. **The frame** (`FlightDeck.lua`, `NS.FD`): fuel bar, alerts, tank row + target box, rows of five, growth rules, out of
   a fight only; hidden behind `/bish alpha deck`. A `Cost.Count` budget for a 40-man repaint (the radar's is 760).
3. **Cell icons:** cures and kick on the right (shown only when needed), HoTs on the left, the keep-up mark on tanks.
4. **The deck and rails:** self buff, raid kick, mana, totems CALL > BRING > RECALL; rails' information.
5. **Controller route** through PadHeal's header.
6. **Support mode.**
7. **The switch-over:** the radar look becomes the flight deck (`FG.LOOKS` "radar" -> the deck; an existing radar user
   sees the deck on first load), CHANGELOG, the CurseForge page and its glance picture (a big update).

## Ask before building on these (playbook 6c)

- Secret values: target / target-of-target health handed untouched; `targettarget` as a unit attribute on a secure cell
  updates in a fight by itself (the PvP cells prove `<member>target`).
- The target box's kick: `*harmbutton1` on the target cell, as `c.kickFx`.
- Range / LOS words: the alerts row is the black box's boxes moved under the fuel bar.
- Saved settings: per character, like the radar's; an existing radar user's knobs carry over.
- Probes still owed (one-liners in the research files): Feral Charge id, Spell Lock castable by name from the pet book,
  Prayer of Mending / Light's Vigil aura ids, War Stomp id, self-buff charges.
