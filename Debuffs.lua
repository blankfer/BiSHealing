--[[
  BiSHealing / Forever :: Debuffs.lua - THE KNOWN DEBUFFS (24 Nov 2026): what a healer does about each, as data.

  Arn, 24 Nov: "our cues are gonna tell you heal past this, don't heal this target right now, dispel this poison, do not
  dispel this poison". This is the list a helper read off Wowhead Forever's tooltip API, dungeon guides and a sweep of the
  new spell ids (1,240,000-1,339,999) - curated rows, which always win over what the debuff book learns on the fly
  (DebuffBook.lua). Each row: `act` (what to do), and for it `pct` (heal past this share) / `cut` (healing received
  taken off) / `dtype` (the client's dispel type) / `why` (a few words for a tip) / `where` (source, when known).

    past      heal them above `pct` (HealPast.lua draws the line)
    nodispel  DON'T dispel it blindly (removing it does something bad)
    dispel    take it off, soon (the dungeon guides say "dispel ASAP")
    reduce    heals land weaker (`cut`)
    noheal    direct heals do nothing
    watch     dangerous, nothing to remove - heal through it / move

  UNVERIFIED: sources marked "?" were inferred, not read. A Forever-new id is 124xxxx-133xxxx. The talents' armor procs
  (Ancestral Fortitude 16177, Inspiration 14893) are single ids on Forever - kept in DD.TANK_BUFFS.
]]
local ADDON, NS = ...
NS = NS or {}

local DD = {}
NS.DD = DD

DD.LIST = {
    -- HEAL PAST THE LINE
    [1271761] = { act = "past", pct = 0.90, name = "Grievous Garrote", where = "Katerina the Cleaner, Alcaz Prison", why = "bleed until healed above 90%" },
    [1288524] = { act = "past", pct = 0.90, name = "Spinning Glaive", where = "Sonya Darkhallow, Barrow Deeps?", why = "until above 90% health" },

    -- DON'T DISPEL BLINDLY
    [1271351] = { act = "nodispel", dtype = "Magic", name = "Lunar Mark", where = "Anara Chillwind, Hyjal", why = "removing it spawns a Collapsing Star" },
    [1271352] = { act = "nodispel", dtype = "Magic", name = "Umbral Mark", where = "Anara Chillwind, Hyjal", why = "removing it spawns an Umbral Void that pulls players in" },

    -- NO DIRECT HEALS
    [28350] = { act = "noheal", dtype = "Curse", name = "Veil of Darkness", why = "immune to direct healing, 7 s" },

    -- HEALS WEAKER
    [1269603] = { act = "reduce", cut = 0.50, name = "Dire Laceration", where = "The Wild King, Hyjal", why = "-50% healing + bleed" },
    [1283348] = { act = "reduce", cut = 0.30, name = "Horrifying Presence", why = "-30% healing, within 15 yd" },
    [1291932] = { act = "reduce", cut = 0.50, dtype = "Poison", name = "Necrotic Poison", why = "-50% healing - cure it" },
    [1289126] = { act = "reduce", cut = 0.15, name = "Emerald Weakness", why = "-15% healing" },
    [1289941] = { act = "reduce", cut = 0.75, name = "Cyclonic Winds", why = "stunned, -75% healing" },
    [1289914] = { act = "reduce", cut = 0.75, name = "Cyclone", why = "stunned, -75% healing" },
    [1289916] = { act = "reduce", cut = 0.75, name = "Cyclone", why = "stunned, -75% healing" },
    [1283414] = { act = "reduce", cut = 0.50, name = "Mortal Strike", why = "-50% healing" },
    [1294310] = { act = "reduce", cut = 0.50, name = "Mortal Strike", why = "-50% healing" },
    [1328019] = { act = "reduce", cut = 0.50, name = "Mortal Strike", why = "-50% healing, 15 s" },
    [16856] = { act = "reduce", cut = 0.50, name = "Mortal Strike", where = "Alcaz Prison, Krol'dok Stronghold", why = "-50% healing" },
    [15708] = { act = "reduce", cut = 0.50, name = "Mortal Strike", why = "-50% healing" },
    [13737] = { act = "reduce", cut = 0.50, name = "Mortal Strike", why = "-50% healing" },
    [17547] = { act = "reduce", cut = 0.50, name = "Mortal Strike", why = "-50% healing" },
    [19643] = { act = "reduce", cut = 0.50, name = "Mortal Strike", why = "-50% healing" },
    [24573] = { act = "reduce", cut = 0.50, name = "Mortal Strike", why = "-50% healing" },
    [22859] = { act = "reduce", cut = 0.50, name = "Mortal Cleave", where = "Dire Maul North", why = "-50% healing" },
    [7068] = { act = "reduce", cut = 0.75, dtype = "Curse", name = "Veil of Shadow", why = "-75% healing - decurse" },
    [17820] = { act = "reduce", cut = 0.75, dtype = "Curse", name = "Veil of Shadow", where = "Lord Alexei Barov, Scholomance", why = "-75% healing - decurse" },
    [22687] = { act = "reduce", cut = 0.75, dtype = "Curse", name = "Veil of Shadow", why = "-75% healing - decurse" },
    [23224] = { act = "reduce", cut = 0.75, dtype = "Curse", name = "Veil of Shadow", why = "-75% healing - decurse" },
    [24674] = { act = "reduce", cut = 0.75, dtype = "Curse", name = "Veil of Shadow", why = "-75% healing - decurse" },
    [28440] = { act = "reduce", cut = 0.75, dtype = "Curse", name = "Veil of Shadow", why = "-75% healing - decurse" },
    [13583] = { act = "reduce", cut = 0.50, dtype = "Curse", name = "Curse of the Deadwood", why = "-50% healing - decurse" },
    [19716] = { act = "reduce", cut = 0.75, dtype = "Curse", name = "Gehennas' Curse", why = "-75% healing - decurse" },
    [23169] = { act = "reduce", cut = 0.50, dtype = "Poison", name = "Brood Affliction: Green", why = "-50% healing - cure it" },

    -- DISPEL SOON (the dungeon guides say so)
    [1323656] = { act = "dispel", dtype = "Poison", name = "Poisoned Shot", where = "Blackmaw Headhunter, Blackmaw Hold", why = "dispel ASAP" },
    [1302767] = { act = "dispel", dtype = "Disease", name = "Dark Plague", where = "Festering Swarmer, Blackmaw Hold", why = "1.5 min disease" },
    [1302497] = { act = "dispel", dtype = "Disease", name = "Corpse Explosion", where = "Bloated Grizzly, Blackmaw Hold", why = "dispel ASAP" },
    [1287756] = { act = "dispel", dtype = "Magic", name = "Fiery Talons", where = "Tor'Rel, Shaper's Terrace", why = "stacks - dispel at once" },
    [1310365] = { act = "dispel", dtype = "Poison", name = "Poison Bolt Volley", where = "Venomridge, Shaper's Terrace", why = "party-wide - cleanse" },
    [1291301] = { act = "dispel", dtype = "Poison", name = "Poison", where = "Nanaya, Shaper's Terrace", why = "poison" },
    [1283313] = { act = "dispel", dtype = "Poison", name = "Poison Bolt Volley", where = "Min'loth, Drowned City", why = "party-wide - cleanse" },
    [1282519] = { act = "dispel", dtype = "Magic", name = "Rotted Strike", where = "Zul'Alai, Drowned City", why = "the tank first" },
    [3583] = { act = "dispel", dtype = "Poison", name = "Deadly Poison", where = "Katerina the Cleaner, Alcaz Prison", why = "on the tank - dispel" },
    [1304473] = { act = "dispel", dtype = "Curse", name = "Curse of Thorns", where = "City of Dalaran", why = "decurse" },
    [1240869] = { act = "dispel", dtype = "Magic", name = "Manamorph", where = "Arcanic Enigma, City of Dalaran", why = "8 s control" },
    [1303598] = { act = "dispel", dtype = "Magic", name = "Mass Polymorph", where = "Shade of the Archmage, City of Dalaran", why = "8 s control" },
    [1240738] = { act = "dispel", dtype = "Magic", name = "Drain Vitality", where = "Mana Devourer, City of Dalaran", why = "drain" },
    [1293228] = { act = "dispel", dtype = "Magic", name = "Combust", where = "Magmatus, Hall of Thanes", why = "burn" },
    [3358] = { act = "dispel", dtype = "Poison", name = "Leech Poison", where = "Ruins of Lordaeron", why = "off the tank" },
    [1266011] = { act = "dispel", dtype = "Magic", name = "Life Drain", where = "The Abandoned, Ruins of Lordaeron", why = "16 s drain" },
    [3427] = { act = "dispel", dtype = "Disease", name = "Infected Wound", where = "Thicket Hunter, Excavation Site", why = "dispel quickly" },
    [11639] = { act = "dispel", dtype = "Magic", name = "Shadow Word: Pain", where = "Legashi Summoner, Blackmaw Hold", why = "dot" },
    [14032] = { act = "dispel", dtype = "Magic", name = "Shadow Word: Pain", where = "Defias Truthfinder, Alcaz Prison", why = "dot" },
    [17620] = { act = "dispel", dtype = "Magic", name = "Drain Life", where = "The Questioner, Alcaz Prison", why = "big drain" },
    [1270650] = { act = "dispel", dtype = "Magic", name = "Lunar Fire", where = "Hyjal?", why = "hits players within 20 yd when it ends" },
    [1270651] = { act = "dispel", dtype = "Magic", name = "Umbral Fire", where = "Hyjal?", why = "hits players within 20 yd when it ends" },
    [1293928] = { act = "dispel", dtype = "Magic", name = "Mistrot", where = "Old Gloomlurker, Hyjal?", why = "1 min shadow" },
    [1288559] = { act = "dispel", dtype = "Poison", name = "Bloom", why = "30 s poison" },

    -- DANGEROUS, NOTHING TO REMOVE
    [1246362] = { act = "watch", name = "Nightmare Detonation", where = "Varrox Bleakhoof, Blackmaw Hold", why = "10 s then blows up - move away" },
    [1287886] = { act = "watch", name = "Puncture", where = "Shaper's Terrace", why = "stacks on the tank" },
    [1310512] = { act = "watch", name = "Conflagration", where = "Cinder, Shaper's Terrace", why = "burns the tank and allies near" },
    [1271604] = { act = "watch", name = "Searing Scales", where = "Zarla Ober, Alcaz Prison", why = "everyone burns 18 s" },
    [1280011] = { act = "watch", name = "Rending Whirl", where = "Krol'dok Stronghold", why = "area bleed" },
    [1306816] = { act = "watch", name = "Bigger Rock to the Face", why = "bleed 20 s" },
    [1294269] = { act = "watch", dtype = "Magic", name = "Burning Blade", why = "players within 8 yd burn when it ends - think before dispelling" },
    [1263284] = { act = "watch", dtype = "Magic", name = "Siphoned Mana", why = "stacks, blows up at 3" },
    [1270498] = { act = "watch", name = "Malady", where = "Kathris the Haunted, Hyjal", why = "raid-wide 5 s" },
}

-- THE ARMOR PROCS A TANK WANTS, whoever's crit gave them (Arn, 24 Nov: "big in raid to track that the tanks have that buff
-- even if it's not ours"). Forever keeps one aura id each (rank 2 and 3's are "not found").
DD.TANK_BUFFS = {
    [16177] = { name = "Ancestral Fortitude", class = "SHAMAN" },
    [14893] = { name = "Inspiration", class = "PRIEST" },
}

--- The rows that do `act`: { [id] = row }.
function DD.Of(act)
    local out = {}
    for id, r in pairs(DD.LIST) do if r.act == act then out[id] = r end end
    return out
end
