--[[
  BiSHealing :: Radar.lua - THE RADAR, the secret alpha's first feature (8 Nov 2026).

  Arn: "total complete rewite of the healing concept ... im only clicking on stuff that lights up lets lean into it and
  make a radar that hides everything and only lights up when it needs to be clicked" ... "square and no names on
  anything completly dark i want everything to hide when not needed" ... "we hide stuff like how we hide the interrupt
  button, no casting we turn completly invisible but still in the same place" ... "Build it".
  Mockup (v3): https://claude.ai/artifact/6FVpu5JR4yCyyaHT1VfftP

  Behind the secret alpha only: `NS.AlphaOn("radar")`. On, it takes the grid's place (FG.Hidden, the saved `shown`
  untouched); off, the grid comes back. Out of combat both ways; asked in a fight, it waits for the fight's end.

  A SQUARE SCOPE, ONE SPOKE A TEAMMATE (you and your party, or your own raid group - five; raid sectors are v2).
  From the centre out, on each spoke:
    HEAL pip   a secure button on that unit: a plain left-click casts THE RADAR HEAL (your class's single-target
               heal at its top trained rank minus 2 - RD.Heal; `/bish alpha radar heal <spell>` changes it); every
               other click is your own binds (FM.ApplyTo). Its face is a role glyph (tank / heal / damage) the CLIENT
               colours from their health through a curve (RD.Curve): hidden at RD.GREEN and up, green below it, amber
               where your heal would fill it (1 - heal / max health, learned out of a fight; else RD.AMBER), red
               under RD.RED with a client-run pulse. Nothing is read.
    CURE pip   per cure your class has (Auras.lua's list): the client draws a small diamond only while that unit has
               something you can cure (an AuraContainer slot, HARMFUL|RAID_PLAYER_DISPELLABLE), a secure box under it
               casts the cure. No words.
    BOGEY      their target (yours on your own spoke): a red triangle only while it casts (FG.Casting, `type()` only);
               a click is your interrupt, on an enemy only (the client's own harm switch, as the PvP cells).
  THE FUEL GAUGE across the top, sideways (buildGauge; 9 Nov): your mana racing the boss's health on one tape, the red you are behind
  by, a magenta caret on the boss, a hot pulsing BINGO band when the boss is 30% ahead, a cyan chevron while you are
  generating (out of the five second rule). THE MANA COLUMN beside it, icons only, top to bottom: the STABILIZER (your
  keep-up self buff - Water Shield - red while it is NOT on you: the client's own icon arriving covers the red), MANA
  TIDE, the best MANA POTION, the best DRINK (each lit by its own curve once you miss what it restores - learned out of a
  fight; the drink out of a fight only), RATIONS (out of a fight, Well Fed missing and a well-fed food in your bags).
  A FAILED CLICK says why under the pip, in the grid's red letters: LOS or RANGE (UI_ERROR_MESSAGE, RD.HeardError) -
  only when you click, never standing (9 Nov 2026). Everything lit pulses (RD.Pulse) and carries the GCD sweep.

  OUT OF A FIGHT everything is drawn dim, so the hand learns the places. IN A FIGHT the scope and every empty slot go
  to alpha 0 - in the same place and still clickable, like the PvP interrupt - and only what needs a click shows.
  Secure attributes are written out of combat only; a roster change mid-fight waits for its end.
  WHAT IT COSTS: no OnUpdate. Health and mana repaint on their events, one unit at a time. While shown, a ticker every
  RD.TICK asks each bogey "casting?" and each spoke's range (Cost budget in the suite); it stops when hidden.
]]
local ADDON, NS = ...
NS = NS or {}

local RD = {}
NS.RD = RD

RD.KEY = "radar"
RD.SIZE = 300                 -- the square, before its scale
RD.FADE_PX = 380              -- the dark disc's art at party size: solid to r 148 (past the outer ring), gone by r 190
RD.SPOKES = 5                 -- a party's spokes; a raid has 40 fixed slots (RD.Geometry)
RD.SYS_PX = 22                 -- a system pip (Arn, 8 Nov: five in the mana column - 26 reached a raid cure ring)
RD.RINGS = { 40, 80, 120, 142 }
RD.RING_SEG = 40
RD.GREEN, RD.AMBER, RD.RED = 0.90, 0.80, 0.35    -- below: green / amber (when the heal size is unknown) / red
RD.FUEL_LOW = 0.30
-- THE FUEL GAUGE (8 Nov 2026, Arn: "a quasi mana/heal efficiency gauge ... my mana to track the boss health bar ... the
-- delta indicates we are keeping pace or bingo fuel"). SIDEWAYS ALONG THE TOP since 9 Nov (Arn: "mana gauge ... put it on
-- top side ways that way only one rail per side"): `w` = the tape's thickness, `left` / `right` = the room kept at its
-- ends (the ship's placard, then the ramjet), `base` = the tape's bottom above the rail's bottom (the scale hangs under
-- it), `flag` = how far the BINGO window reaches past the tape.
RD.GAUGE = { w = 7, left = 56, right = 64, base = 19, flag = 5 }
-- THE RAILS, OUTSIDE THE SQUARE (Arn, 8 Nov: "pop out the rail to the left of the radar square and the gauge too in its own
-- rail"; 9 Nov: the gauge on top, one rail a side): solid strips in RD.PLATE's dark - the fuel GAUGE's rail across the top
-- (over the tool rail and the square), the TOOL rail on the left (stabilizer, Mana Tide, potion, drink, rations), the
-- DEFENCE rail on the right. Children of the radar, so they move and hide with it; solid, so the stabilizer's cover (the
-- same dark) melts into its rail.
RD.RAIL_GAP = 3                                    -- between the rails, and between the tool rail and the square
RD.TOOL_RAIL_W = 22 + 8                            -- a system pip and a margin
RD.GAUGE_RAIL_H = 44                               -- the readout box, the tape, the scale's ticks and numbers under it
-- THE SHIPS (9 Nov 2026, Arn: "lean to the ryan gosling in the spirit of star wars imperial purple and white accents like
-- a fighter and the more the group gets we change the color to finally ending in star destroyer theam"). The radar's
-- chrome takes the look of a bigger ship as the group grows: night-drive neon on a small fighter, cooling through a
-- gunship and a cruiser to a capital ship's grey hull with white lines. OUR OWN looks and names - the feeling is
-- borrowed, never a film's ship shapes, emblem, names or lettering. Only the chrome changes: the hull (RD.PLATE - the
-- disc, the rails, the stabilizer's cover), the scope's lines, its corner brackets, the centre mark, the fuel tape and its
-- scale. WARNINGS KEEP THEIR COLOURS in every ship (the health pips, the boss's red, BINGO, LOS / RANGE, amber, cyan), so
-- a warning reads the same everywhere. Picked by the group's size in RD.Arm - out of a fight only, never mid-fight.
--   upTo     the biggest group this ship flies with
--   plate    the hull: the disc, the rails, the covers          line     the scope's rings, cross and ticks; the scale
--   bracket  the corner brackets (`be` long, `bw` thick)        accent   the centre mark, the readout, the ship's name
--   fuel     your mana on the tape                              track    the tape's empty groove
RD.SHIPS = {
    { key = "fighter", name = "PARTY", upTo = 5,
      plate = { 0.035, 0.015, 0.060 }, line = { 0.82, 0.38, 1.00 }, bracket = { 0.97, 0.93, 1.00 }, be = 18, bw = 2,
      accent = { 1.00, 0.45, 0.92 }, fuel = { 0.88, 0.56, 1.00, 0.95 }, track = { 0.10, 0.04, 0.16, 0.9 } },
    { key = "gunship", name = "RAID 10", upTo = 10,
      plate = { 0.035, 0.025, 0.070 }, line = { 0.64, 0.52, 1.00 }, bracket = { 1.00, 1.00, 1.00 }, be = 22, bw = 2,
      accent = { 0.82, 0.64, 1.00 }, fuel = { 0.80, 0.72, 1.00, 0.95 }, track = { 0.08, 0.06, 0.17, 0.9 } },
    { key = "cruiser", name = "RAID 20", upTo = 20,
      plate = { 0.045, 0.045, 0.060 }, line = { 0.60, 0.64, 0.75 }, bracket = { 1.00, 1.00, 1.00 }, be = 28, bw = 2,
      accent = { 0.70, 0.44, 1.00 }, fuel = { 0.88, 0.90, 0.97, 0.95 }, track = { 0.10, 0.10, 0.14, 0.9 } },
    { key = "capital", name = "RAID 40", upTo = 40,
      plate = { 0.060, 0.062, 0.072 }, line = { 0.84, 0.86, 0.91 }, bracket = { 1.00, 1.00, 1.00 }, be = 34, bw = 3,
      accent = { 0.64, 0.40, 0.96 }, fuel = { 0.96, 0.96, 0.99, 0.95 }, track = { 0.13, 0.13, 0.16, 0.9 } },
}
RD.SCOPE_DIM = 0.55                                -- the rings, cross and ticks: the ship's line at this strength
-- THE HUD TAPE (Arn, 8 Nov, a fighter HUD's speed tape: "the picture is an idea of how the guage should look not just a
-- line"): a spine with a tick every 10%, longer ticks and numbers at 0/25/50/75/100, and a BOXED READOUT riding at the top
-- of your fuel with your mana % in it - the client writes the number (SetFormattedText, UnitPowerPercent ScaleTo100; a
-- secret is handed on, never read) - pointing into the tape. The race (red above green, BINGO) stays, in the slim tape.
RD.HUD = { minor = 3, major = 6, label = 9, boxW = 24, boxH = 13 }
-- THE MANA COLUMN (Arn, 8 Nov: "put the mana tools close to the fuel tape and the water shield ... its essential for a
-- pilot to always click that button when it lights"): right beside the tape, top to bottom the stabilizer, Mana Tide,
-- the potion, the drink. Its x from the radar's left edge; clear of every pip, party and raid (the suite measures it).
RD.COLUMN_X = 12
RD.BINGO = 0.30                                    -- the boss this far ahead of your mana (of the tape) = BINGO
RD.MANA_COL = { 0.22, 1.00, 0.53, 0.95 }           -- your fuel: the scope's phosphor
RD.BOSS_COL = { 1.00, 0.23, 0.30, 0.85 }           -- the boss's health: the red your fuel has to cover
RD.HOT = { 1.00, 0.08, 0.58, 1 }                   -- BINGO: a hot magenta-red, pulsing
RD.CARET = { 1.00, 0.24, 0.92, 1 }                 -- the boss's level: the cockpit's magenta
-- THE REGEN TOOLS (Arn, 8 Nov: "light up the mana regen buttons, mana potions, mana tide"): always in their places down
-- the right edge, each lit by its own curve (RD.ToolCurve) once you are missing what it restores
RD.TIDE = "Mana Tide Totem"
RD.POTION = "Restore Mana"                         -- the use-spell of every mana potion (the drink's is "Drink")
RD.TOOL_GUESS = 0.50                               -- the amount unknown: light at half mana, and say it is a guess
-- THE RESERVE TANK (8 Nov 2026, Arn: "add mana spring to the rail and we light it up when everything else is on cooldown
-- as a scraping the barrel option. reserve reserve tank for a pilot"): Mana Spring, lit only once Mana Tide and the
-- potion are spent (cooling, or not here) and - in a fight, or with no drink - your mana is down to what it gives back.
-- What is spent is OUR OWN CLOCK of OUR OWN casts (UNIT_SPELLCAST_SUCCEEDED for you - plain), seeded out of a fight from
-- the client's cooldowns; nothing secret is read. A water totem of yours already down (the Spring, or Mana Tide for its
-- 12 s) keeps it dark: a second one would only replace it.
RD.FSR = { n = 5, w = 6, h = 3, gap = 2, spent = 0.2 }   -- the five second rule's segments (RD.PaintFSR)
RD.SPRING = "Mana Spring Totem"
RD.COOLS = { tide = 300, potion = 120, kick = 6, chaff = 15 }  -- seconds, when the client gives no cooldown to seed from
RD.cdLen = {}                                      -- kind -> a cooldown's length, learned from the client's plain answer
-- THE RIGHT RAIL: DEFENCE (9 Nov 2026, Arn: "an interrupt needs to target the specific unit, if it's on cool down, our
-- grounding totem lights up on the right rail it needs no target it just needs to know the flare missed - deploy chaff,
-- last resort catch all"). The FLARE is the interrupt on each bogey: it needs the caster, so it lives on the caster's
-- spoke. CHAFF is a TARGETLESS answer on its own rail right of the square, lit only while (a) an enemy on the radar is
-- casting, (b) the flare is spent - our own clock of your interrupt (a shaman's shocks share one cooldown, so any shock
-- spends it), or no interrupt at all - and (c) the chaff itself is ready. Plain booleans from our clock and from
-- FG.Casting (`type()` only); nothing secret is read. Only targetless spells belong here.
RD.CHAFF = { SHAMAN = "Grounding Totem", PRIEST = "Psychic Scream", WARLOCK = "Howl of Terror" }
RD.KICK_SHARED = { ["Earth Shock"] = { "Flame Shock", "Frost Shock" } }   -- casts that spend the same cooldown
RD.CHAFF_COL = { 1.00, 0.70, 0.25 }                -- amber: answer this now (a missile on its way)
-- THE PILOT'S KNOBS (Arn, 9 Nov: "these are our knobs can be turned on and off, some fights we need a specific totem all
-- the time so we can't afford for it to be lighting up ... we can turn off from the rail without having to go into the
-- setting"): a small switch on each rail tool's corner, a PLAIN button (never part of the secure cast button), so a click
-- works in a fight - it only changes what we light, and alpha is allowed in combat. Saved in `radar.off[kind]`.
RD.KNOB_PX = 9
RD.KNOB_ON = { 0.22, 1.00, 0.53, 0.35 }            -- lit when it needs you: a faint phosphor dot
RD.KNOB_OFF = { 1.00, 0.23, 0.30, 1 }              -- switched off: red, plain to see
RD.WATER = { tide = 12, spring = 300 }             -- how long each water totem stands
RD.readyAt = {}                                    -- kind -> GetTime() when it is ready again
RD.coolStart = {}                                  -- kind -> GetTime() its cooldown started (the cooling disc's start)
RD.waterUntil = 0
RD.TOOL_GAP = 3
RD.TICK = 0.5
RD.FOOD_EVERY = 10            -- ticks: the food is asked again every 5 s out of a fight
RD.WHITE = "Interface\\Buttons\\WHITE8X8"
RD.PHOS = { 0.22, 1.00, 0.53 }                   -- the scope's green
RD.DIM = { 0.11, 0.36, 0.22, 0.9 }               -- an empty slot out of a fight
RD.COL = { green = { 0.22, 1.00, 0.53, 1 }, amber = { 1.00, 0.70, 0.25, 1 }, red = { 1.00, 0.23, 0.30, 1 },
           cyan = { 0.25, 0.96, 1.00, 1 }, bogey = { 1.00, 0.23, 0.30, 1 } }
RD.CROSS = { 1.00, 0.24, 0.92 }                    -- your target's crosshair: the cockpit's magenta (FG.COCKPIT.target)
RD.CROSS_PAD = 12                                  -- px round a pip
-- TARGET OF TARGET (Arn, 8 Nov: "target of target?"): who your target is on - the same reticle in amber, a size bigger,
-- so it frames the magenta one when you target a friend's attacker and never hides under it
RD.TOT = { 1.00, 0.70, 0.25 }
RD.CROSSHAIRS = false                              -- Arn, 8 Nov: "no crosshairs" - taken off (the code stays)
RD.TOT_PAD = 22
RD.CONTACT = { 0.22, 1.00, 0.53, 0.75 }            -- their target, quiet: a phosphor triangle (red once it casts)
RD.CONTACT_SHOWN = false                           -- Arn, 8 Nov: a bogey shows only while it casts
RD.PLATE = { 0.02, 0.06, 0.04 }                    -- the stabilizer's backing plate, and the cover's colour over it
RD.SHIELD_OK = { 0.18, 0.62, 0.36 }                -- the cover while your shield is up: its icon, greyed, a dim phosphor
                                                   -- green (Arn, 8 Nov: "no water shield icon" - the first dark one read as nothing)
RD.SHIELD_LAST = { 255, 120, 0 }                   -- the last charge: an orange wash (r, g, b 0-255, a texture escape's)
RD.CURE_COL = { Poison = { 0.49, 1.00, 0.35, 1 }, Disease = { 0.88, 0.69, 0.29, 1 }, Magic = { 0.30, 0.64, 1.00, 1 },
                Curse = { 0.77, 0.35, 1.00, 1 } }
-- your class's single-target heal, the first one trained wins (Arn: "we always use our biggest heal minus 2 ranks")
RD.HEALS = { SHAMAN = { "Healing Wave" }, PRIEST = { "Greater Heal", "Heal", "Lesser Heal" }, DRUID = { "Healing Touch" },
             PALADIN = { "Holy Light" } }
RD.HEALER_CLASS = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }

local function combat() return (InCombatLockdown and InCombatLockdown()) and true or false end
-- NIL FOR A SECRET, ALWAYS (8 Nov 2026, Arn's BugSack: "attempt to compare local 'mx' (a secret number value)"). This
-- was `NS.Plain and NS.Plain(v) or v`: NS.Plain answers nil for a secret, and `nil or v` handed the secret straight back.
local function plain(v)
    if NS.Plain then return NS.Plain(v) end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
local function db()
    local d = NS.DB()
    d.radar = type(d.radar) == "table" and d.radar or {}
    return d.radar
end

--- Is the radar on now (the alpha, and this feature)?
-- THE DASHBOARD LOOK (11 Nov 2026, Arn: "we are ready to take this alpha and add it to the look of bis healing, cockpit
-- classic and dashboard"; named "radar" the same night - "dashboard" is what the BiS> pages are called): the radar is a
-- public look now - `look = "radar"` (NS.DO.look, the options' look row).
-- THE LOOK ALONE DECIDES (11 Nov 2026, Arn: "in the options when i toggel between class cockpit and dash it does
-- nothing" - the old alpha switch kept the radar up whatever the look, and the grid behind it hidden). Whoever had the
-- alpha radar on is moved to the dashboard ONCE (RD.DashStamp), so nobody loses the radar they had; from then on the
-- look is the only switch. The black box rail along the bottom shows for everyone (Arn: "bottom rail is not hidden
-- everyone sees it"); its codes need the key addon either way. The brains need the private key addon; the test
-- camera is its own alpha feature.
function RD.On()
    local FG = NS.FG
    return (FG and FG.Look and FG.Look() == "radar") or false
end
--- Once: the alpha radar on = the radar look (written down, `dash1` on the account). Answers true when it moved one.
function RD.DashStamp()
    local d = NS.DB()
    if d.dash1 or not (NS.AlphaOn and NS.AlphaOn(RD.KEY)) then return false end
    d.dash1 = true
    if d.look == "radar" or d.look == "dashboard" then return false end
    d.look = "radar"
    return true
end
--- The black box rail, while it is part of the instrument (the extras, out of the engineer's view).
function RD.BBRail()
    local b = RD.bbRail
    return (b and b:IsShown()) and b or nil
end
--- Is it standing in for the grid now? (What the grid asks: FG.Hidden.)
function RD.Active() return RD.shownFor == true end

-- ------------------------------------------------------------------ the heal

local function classFile()
    local ok, _, c = pcall(UnitClass, "player")
    return ok and plain(c) or nil
end

--- "healing wave" -> "Healing Wave" (a typed name is lowercased on its way here).
local function titled(s)
    return (tostring(s or ""):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b:lower() end))
end

--- The radar's heal: { name, rank (nil for a spell without ranks), cast = "Name(Rank n)" } or nil.
--- The saved pick first (db.heal), else the class's list; the top trained rank minus 2 (rank 1 at the least).
function RD.Heal()
    local FM = NS.FM
    if not (FM and FM.Ranks) then return nil end
    local names = {}
    local pick = db().heal
    if type(pick) == "string" and pick ~= "" then names[1] = pick end
    for _, n in ipairs(RD.HEALS[classFile() or ""] or {}) do names[#names + 1] = n end
    for _, n in ipairs(names) do
        local ranks = FM.Ranks(n)
        if #ranks > 0 then
            local r = ranks[math.max(1, #ranks - 2)]
            return { name = n, rank = r and r.rank or nil, cast = FM.Cast(n, r and r.rank), ranks = #ranks }
        end
    end
    return nil
end

--- How much the radar heal heals, from the client's own words out of a fight ("for 300 to 350"): the middle, or nil.
function RD.HealAmount(h)
    h = h or RD.heal
    if not h or combat() then return RD.healAmount end
    local get = C_Spell and C_Spell.GetSpellDescription
    if not get then return nil end
    local ok, text = pcall(get, h.cast or h.name)
    text = ok and plain(text) or nil
    if type(text) ~= "string" then return nil end
    local a, b = text:match("(%d[%d,]*)%s+to%s+(%d[%d,]*)")
    a, b = tonumber(a and a:gsub(",", "")), tonumber(b and b:gsub(",", ""))
    if a and b then RD.healAmount = (a + b) / 2 return RD.healAmount end
    return nil
end

-- ------------------------------------------------------------------ the curves (the client decides)

RD.curves = {}
--- The heal pip's colour by health fraction: red under RD.RED, amber under `amber`, green under RD.GREEN, gone above.
function RD.Curve(amber)
    amber = math.max(RD.RED + 0.02, math.min(amber or RD.AMBER, RD.GREEN - 0.01))
    local key = math.floor(amber * 100 + 0.5)
    if RD.curves[key] then return RD.curves[key] end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, c = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not c or not c.AddPoint then return nil end
    if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then pcall(c.SetType, c, Enum.LuaCurveType.Linear) end
    local R, A, G = RD.COL.red, RD.COL.amber, RD.COL.green
    local function at(x, col, a) pcall(c.AddPoint, c, x, CreateColor(col[1], col[2], col[3], a or col[4])) end
    at(0.00, R) at(RD.RED, R)
    -- amber: the colour, see-through - the pulsing amber layer (RD.AmberCurve) is what shows there, so green holds still
    at(RD.RED + 0.0001, A, 0) at(amber, A, 0)
    at(amber + 0.0001, G) at(RD.GREEN, G)
    at(RD.GREEN + 0.0001, G, 0) at(1.00, G, 0)
    RD.curves[key] = c
    return c
end

--- THE BOX'S EDGE BY HEALTH (15 Nov 2026, Arn: "need the outline of the boxes to turn colors amber when they are low red
--- very low"): the deck's plate edge - red at and under RD.RED, amber up to `amber` (where your heal stops being wasted,
--- the pip's own amber), the dim edge above. A step curve the CLIENT evaluates on their health (UnitHealthPercent with a
--- curve): nothing here reads a number, so it holds in a fight.
RD.outlineCurves = {}
function RD.OutlineCurve(amber)
    amber = math.max(RD.RED + 0.02, math.min(amber or RD.AMBER, RD.GREEN - 0.01))
    local key = math.floor(amber * 100 + 0.5)
    if RD.outlineCurves[key] then return RD.outlineCurves[key] end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, c = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not c or not c.AddPoint then return nil end
    if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then pcall(c.SetType, c, Enum.LuaCurveType.Linear) end
    local R, A, D = RD.COL.red, RD.COL.amber, RD.DIM
    local function at(x, col) pcall(c.AddPoint, c, x, CreateColor(col[1], col[2], col[3], col[4] or 1)) end
    at(0.00, R) at(RD.RED, R)
    at(RD.RED + 0.0001, A) at(amber, A)
    at(amber + 0.0001, D) at(1.00, D)
    RD.outlineCurves[key] = c
    return c
end

--- The amber layer: solid amber between RD.RED and `amber`, nothing elsewhere (the client pulses that layer gently).
RD.amberCurves = {}
function RD.AmberCurve(amber)
    amber = math.max(RD.RED + 0.02, math.min(amber or RD.AMBER, RD.GREEN - 0.01))
    local key = math.floor(amber * 100 + 0.5)
    if RD.amberCurves[key] then return RD.amberCurves[key] end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, c = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not c or not c.AddPoint then return nil end
    if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then pcall(c.SetType, c, Enum.LuaCurveType.Linear) end
    local A = RD.COL.amber
    local function at(x, a) pcall(c.AddPoint, c, x, CreateColor(A[1], A[2], A[3], a)) end
    at(0.00, 0) at(RD.RED, 0)
    at(RD.RED + 0.0001, 1) at(amber, 1)
    at(amber + 0.0001, 0) at(1.00, 0)
    RD.amberCurves[key] = c
    return c
end

--- The red pulse layer: solid under RD.RED, nothing above (the client runs the pulse on it).
function RD.RedCurve()
    if RD.redCurve then return RD.redCurve end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, c = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not c or not c.AddPoint then return nil end
    if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then pcall(c.SetType, c, Enum.LuaCurveType.Linear) end
    local R = RD.COL.red
    pcall(c.AddPoint, c, 0.00, CreateColor(R[1], R[2], R[3], 0.6))
    pcall(c.AddPoint, c, RD.RED, CreateColor(R[1], R[2], R[3], 0.6))
    pcall(c.AddPoint, c, RD.RED + 0.0001, CreateColor(R[1], R[2], R[3], 0))
    pcall(c.AddPoint, c, 1.00, CreateColor(R[1], R[2], R[3], 0))
    RD.redCurve = c
    return c
end

--- A REGEN TOOL'S CURVE (8 Nov 2026, Arn: "we change the color of our bar because the game tells us then at when it
--- tells us a certain shade we light up the button" - the heal pips' amber trick): cyan at and below `at` (your mana
--- fraction), nothing above. `at` = 1 - what the tool restores / your full mana, learned out of a fight - so the tool
--- lights the moment you are missing at least what it gives back. The client evaluates it on your mana; Lua never does.
RD.toolCurves = {}
function RD.ToolCurve(at)
    at = math.max(0.02, math.min(tonumber(at) or RD.TOOL_GUESS, 0.98))
    local key = math.floor(at * 100 + 0.5)
    if RD.toolCurves[key] then return RD.toolCurves[key], key / 100 end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, c = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not c or not c.AddPoint then return nil end
    if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then pcall(c.SetType, c, Enum.LuaCurveType.Linear) end
    local C, x = RD.COL.cyan, key / 100
    pcall(c.AddPoint, c, 0.00, CreateColor(C[1], C[2], C[3], 1))
    pcall(c.AddPoint, c, x, CreateColor(C[1], C[2], C[3], 1))
    pcall(c.AddPoint, c, x + 0.0001, CreateColor(C[1], C[2], C[3], 0))
    pcall(c.AddPoint, c, 1.00, CreateColor(C[1], C[2], C[3], 0))
    RD.toolCurves[key] = c
    return c, x
end

--- The old fuel curve (lit below RD.FUEL_LOW): a tool curve at that point.
function RD.FuelCurve() return (RD.ToolCurve(RD.FUEL_LOW)) end

--- A colour the client worked out, onto textures. false when the client handed none back.
local function paint(texs, col)
    if type(col) ~= "table" or not col.GetRGBA then return false end
    local any = false
    for _, t in ipairs(texs) do
        if pcall(function() t:SetVertexColor(col:GetRGBA()) end) then any = true end
    end
    return any                     -- true only if the colour LANDED somewhere (Arn's white blade: it never had)
end

--- Paint one box's edge from its person's health (the deck only). Dead or gone: the dim edge.
function RD.PaintOutline(sp)
    local p = sp and sp.deckPlate
    if not (p and p.edges and p:IsShown()) then return false end
    local D = RD.DIM
    local hold = p.edgeHold
    local function dim()
        for _, e in ipairs(p.edges) do e:SetVertexColor(D[1], D[2], D[3], D[4]) end
        if hold then hold:SetAlpha(1) end
        return false
    end
    if not (sp.unit and RD.Deck()) then return dim() end
    if not RD.Sw("edges") then return dim() end              -- the warning edges switch
    -- NO WARNING EDGE ON AN ENEMY (16 Nov 2026, Arn: "the enemy bar gets a health out line which makes me think i need to
    -- heal it"): your target box never warns (a mob, most of the time); its target warns unless it is an enemy - a plain
    -- answer decides, a secret one goes to the client (each edge's alpha from the boolean: enemy = no warning colour)
    if sp.unit == "target" then return dim() end
    local foe
    if sp.unit == "targettarget" and UnitCanAttack then
        local okH, h = pcall(UnitCanAttack, "player", sp.unit)
        if okH then foe = h end
        if foe ~= nil and not (NS.Secret and NS.Secret(foe)) and foe == true then return dim() end
    end
    local okE, there = pcall(UnitExists, sp.unit)
    if okE and plain(there) == false then return dim() end
    local okD, dead = pcall(UnitIsDeadOrGhost, sp.unit)
    if okD and plain(dead) == true then return dim() end
    local curve = RD.OutlineCurve(sp.amber)
    local ok, col = false, nil
    if curve and UnitHealthPercent then ok, col = pcall(UnitHealthPercent, sp.unit, true, curve) end
    if not (ok and paint(p.edges, col)) then return dim() end
    -- a hidden "is it an enemy": the client shows the warning edge only for a friend
    local hidden = foe ~= nil and NS.Secret and NS.Secret(foe)
    if hold then
        if not (hidden and hold.SetAlphaFromBoolean and pcall(hold.SetAlphaFromBoolean, hold, foe, 0, 1)) then hold:SetAlpha(1) end
    end
    return true
end

-- ------------------------------------------------------------------ drawing helpers

local function line(parent, layer, x1, y1, x2, y2, col, w)
    local l = parent:CreateLine(nil, layer or "ARTWORK")
    l:SetTexture(RD.WHITE)
    l:SetThickness(w or 1)
    l:SetStartPoint("CENTER", parent, x1, y1)
    l:SetEndPoint("CENTER", parent, x2, y2)
    l:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
    return l
end

local function tex(parent, layer, col)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(RD.WHITE)
    t:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
    return t
end

--- THE POP UNDER THE MOUSE (8 Nov 2026, Arn: "need to also make the icons pop a little so i know im hovering over the
--- right icon" - the family rule, rows pop on hover). A bright white RING snaps round whatever clickable thing the mouse
--- is on - a heal pip, a cure pip, a bogey, a corner system - even an invisible one, so you see what a click would do.
--- A ring, not a box (Arn: no boxes). Its own plain frame on the button, only its ALPHA ever changes (in a fight too);
--- remade only when the pip's size changes. Hooked, never Set: a secure button keeps its own scripts.
--- SWITCHED OFF (8 Nov 2026, Arn: "it kills the immersion when i am moving the mouse over empty spaces and it shows where
--- something will light up ... might make them want to click that place"): built, never shown. RD.HALO_ON brings it back.
RD.HALO_ON = false
RD.HALO_PAD, RD.HALO_SEG = 6, 18
RD.HALO_COL = { 1, 1, 1, 0.95 }
function RD.Halo(owner, px)
    local h = owner.halo
    if h and h.px == px then return h end
    if not h then
        h = CreateFrame("Frame", nil, owner)
        h:SetPoint("CENTER", owner, "CENTER", 0, 0)
        h:SetSize(1, 1)
        h:SetFrameLevel(owner:GetFrameLevel() + 30)
        h:SetAlpha(0)
        owner.halo = h
        owner:HookScript("OnEnter", function() if RD.HALO_ON then h:SetAlpha(1) end end)
        owner:HookScript("OnLeave", function() h:SetAlpha(0) end)
    end
    for _, t in ipairs(h.ring or {}) do t:Hide() end
    h.ring = {}
    local r = px / 2 + RD.HALO_PAD
    local seg = 2 * math.pi * r / RD.HALO_SEG + 1
    for k = 0, RD.HALO_SEG - 1 do
        local a = (k + 0.5) * 2 * math.pi / RD.HALO_SEG
        local t = h:CreateTexture(nil, "OVERLAY")
        t:SetTexture(RD.WHITE)
        t:SetVertexColor(RD.HALO_COL[1], RD.HALO_COL[2], RD.HALO_COL[3], RD.HALO_COL[4])
        t:SetSize(seg, 2)
        t:SetPoint("CENTER", h, "CENTER", math.sin(a) * r, math.cos(a) * r)
        if t.SetRotation then t:SetRotation(-a) end
        h.ring[#h.ring + 1] = t
    end
    h.px = px
    return h
end

--[[ WHERE EVERY SLOT SITS (the geometry). A slot = { b = bearing (radians, 0 up, clockwise), rh / rc / rb = the heal,
  cure and bogey radii (rb nil: no bogey), ph / pc / pb = their sizes, own = your group }.
  PARTY / SOLO (v1): five spokes, 72 degrees apart, the first straight up.
  RAID (Arn, 8 Nov: "raid sectors next"): 8 groups x 5 = 40 FIXED slots, so each person's pip has its place by their
  group and their place in it. Your own group is the top sector, nearer the centre and bigger (the shortest moves);
  the other seven go round clockwise in group order on the outer ring. Bogeys in a raid: your own group only (40
  cast checks twice a second is a second grid's cost for a picture nobody can watch) - the cures are on everyone. ]]
RD.PARTY = { size = 300, rim = 146, rh = 58, rc = 92, rb = 124, ph = 26, pc = 14, pb = 22 }
-- YOU ARE THE MIDDLE (Arn, 8 Nov: "if we want to heal ourselves we are in the middle and stuff build out from us"): your
-- heal pip sits on the centre, your cure just above it, your target's bogey straight up; everyone else builds out from
-- you - a party's four on the diagonals, a raid's on their sectors (your own slot there moves to the centre).
RD.SELF = { b = 0, rh = 0, rc = 30, rb = 124, ph = 28, pc = 14, pb = 22 }
RD.GLYPH = 1.5                -- no box round a pip any more: its role glyph is drawn this much bigger to read alone
-- THE PETS (9 Nov 2026, Arn: "lets add pets small too to rader"): a small paw pip beside its owner, lit like a person (the
-- pet's health through the same curve), a left-click the radar heal. The CLIENT shows and hides it as the pet comes and
-- goes (RegisterUnitWatch), so a pet called mid-fight appears. A party: each pet `turn` clockwise of its owner on the
-- owner's ring; your own just below you (`selfB`, `selfR`). A raid: your own group's pets only, `inward` nearer the centre
-- on their owner's bearing (35 more would crowd the scope and cost a second grid). `px` / `raidPx` their sizes.
RD.PET = { px = 14, raidPx = 10, turn = math.rad(26), selfB = math.pi, selfR = 30, inward = 20 }
RD.PET_UNIT = { player = "pet" }                       -- the owner's token -> the pet's (party/raid by pattern, RD.PetOf)
RD.RAID = { size = 440, rim = 212, span = math.rad(72), gap = math.rad(6),
            own = { rh = 100, rc = 126, rb = 150, ph = 22, pc = 12, pb = 18 },
            other = { rh = 172, rc = 196, ph = 16, pc = 10 } }
function RD.Geometry(raid, ownGroup)
    local out = {}
    if not raid then
        local P, S = RD.PARTY, RD.SELF
        -- slot 1 is you (RD.Roster puts "player" first): the centre
        out[1] = { b = S.b, rh = S.rh, rc = S.rc, rb = S.rb, ph = S.ph, pc = S.pc, pb = S.pb, own = true, self = true,
                   group = 1, pos = 1 }
        for i = 2, RD.SPOKES do
            out[i] = { b = math.pi / 4 + (i - 2) * math.pi / 2, rh = P.rh, rc = P.rc, rb = P.rb, ph = P.ph, pc = P.pc,
                       pb = P.pb, own = true, group = 1, pos = i }
        end
        return out, P.size, P.rim
    end
    local R = RD.RAID
    ownGroup = ownGroup or 1
    local rest = 2 * math.pi - R.span - 2 * R.gap
    local k = 0
    for g = 1, 8 do
        for p = 1, 5 do
            local s
            if g == ownGroup then
                local o = R.own
                s = { b = -R.span / 2 + (p - 0.5) * R.span / 5, rh = o.rh, rc = o.rc, rb = o.rb, ph = o.ph, pc = o.pc, pb = o.pb, own = true }
            else
                local o = R.other
                local order = (g - ownGroup) % 8             -- 1..7: clockwise from your own group
                local idx = (order - 1) * 5 + p              -- 1..35
                s = { b = R.span / 2 + R.gap + (idx - 0.5) * rest / 35, rh = o.rh, rc = o.rc, ph = o.ph, pc = o.pc, own = false }
            end
            s.group, s.pos = g, p
            k = k + 1
            out[k] = s
        end
    end
    return out, R.size, R.rim
end

--- A point on a slot's bearing, `r` out from the middle.
function RD.Point(s, r) return math.sin(s.b) * r, math.cos(s.b) * r end

--- A square edge of four strips on a frame, tinted `col`; answers the list.
local function edge(f, col, w)
    local out = {}
    for _, s in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local t = tex(f, "BORDER", col)
        t:SetPoint(s[1]) t:SetPoint(s[2])
        if s[3] then t:SetHeight(w or 2) else t:SetWidth(w or 2) end
        out[#out + 1] = t
    end
    return out
end

--- The role glyph, our own shapes: "tank" a diamond outline, "heal" a cross, "damage" a blade.
--- PLAIN TEXTURES ONLY, turned with SetRotation (8 Nov 2026, Arn's screenshot: a WHITE blade that never went away). The
--- blade and the diamond were Lines, and the client's curve colour never landed on them - the pip kept its starting
--- white. BiS> now proves the road that works: a texture's SetVertexColor(col:GetRGBA()). Every piece starts INVISIBLE
--- (alpha 0), so a colour that does not land shows nothing rather than a stale white sign.
local function glyph(f, role, px)
    local out = {}
    local c = { 1, 1, 1, 0 }
    local function bar(w, h, x, y, rot)
        local t = tex(f, "OVERLAY", c)
        t:SetSize(w, h)
        t:SetPoint("CENTER", f, "CENTER", x or 0, y or 0)
        if rot and t.SetRotation then t:SetRotation(rot) end
        out[#out + 1] = t
        return t
    end
    if role == "heal" then
        bar(px * 0.22, px * 0.62)
        bar(px * 0.62, px * 0.22)
    elseif role == "tank" then
        -- a diamond: four bars on its edges, each turned 45 degrees
        local s, q = px * 0.30, math.pi / 4
        local len = s * math.sqrt(2)
        bar(len, 2, s / 2, s / 2, -q)
        bar(len, 2, s / 2, -s / 2, q)
        bar(len, 2, -s / 2, -s / 2, -q)
        bar(len, 2, -s / 2, s / 2, q)
    else
        -- a blade: a long bar on the diagonal, a short crossguard across it near the hilt
        local s = px * 0.28
        bar(s * 2 * math.sqrt(2), 3, 0, 0, math.pi / 4)
        bar(s * 0.9, 3, -s * 0.45, -s * 0.45, -math.pi / 4)
    end
    return out
end

-- ------------------------------------------------------------------ the frame

local function endDrag(f)
    if not (f and f.dragging) then return end
    f.dragging = nil
    pcall(f.StopMovingOrSizing, f)
    local ok, p, _, rp, x, y = pcall(f.GetPoint, f)
    p, rp, x, y = plain(p), plain(rp), plain(x), plain(y)
    if ok and type(p) == "string" and type(x) == "number" and type(y) == "number" then
        db().pos = { p, type(rp) == "string" and rp or p, x, y }
    end
end
RD.EndDrag = endDrag

function RD.Place()
    local f = RD.frame
    if not f or combat() then return end
    local pos, d = db().pos, db()
    f:ClearAllPoints()
    if type(pos) == "table" and type(pos[1]) == "string" then
        f:SetPoint(pos[1], UIParent, pos[2] or pos[1], tonumber(pos[3]) or 0, tonumber(pos[4]) or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", -260, -40)
    end
    f:SetScale(math.max(0.5, math.min(2, tonumber(d.scale) or 1)))
end

--- The scope is drawn at the party size and scaled up for a raid (RD.Arm), so its rings sit where the slots do.
local function buildScope(f)
    local s = CreateFrame("Frame", nil, f)
    s:SetSize(RD.PARTY.size, RD.PARTY.size)
    s:SetPoint("CENTER", f, "CENTER", 0, 0)
    RD.scope = s
    local g = { RD.PHOS[1] * 0.45, RD.PHOS[2] * 0.45, RD.PHOS[3] * 0.45, 0.85 }
    -- A DARK DISC WITH A SOFT EDGE (Arn, 9 Nov: "we dont use the corners of the radar what about if we give it a dark
    -- background instead of see through so things pop more like the rail. and we apply the edge fade instead on the edges
    -- like the screen shot" - a map that fades into the world). The see-through square is gone: the rail's own plate,
    -- solid out past the outer ring, fading to nothing (Art\scopefade.tga), the corners left clear. On the radar's OWN
    -- lowest layer, not the scope's: the fade reaches past the square, and the rails beside it must draw over it.
    -- Sized with the scope (RD.Arm), so a raid's bigger scope gets a bigger disc.
    local fade = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    fade:SetTexture(RD.ART .. "scopefade")
    fade:SetVertexColor(RD.PLATE[1], RD.PLATE[2], RD.PLATE[3], 1)
    fade:SetSize(RD.FADE_PX, RD.FADE_PX)
    fade:SetPoint("CENTER", s, "CENTER", 0, 0)
    RD.fade = fade
    -- every line kept, so a ship can repaint them (RD.ApplyShip): the rings, cross and ticks; the brackets; the centre
    RD.scopeLines, RD.brackets = {}, {}
    local function keep(l) RD.scopeLines[#RD.scopeLines + 1] = l return l end
    RD.innerRings = {}                               -- the party's inner rings (not the rim): a fleet draws its own instead
    for ri, r in ipairs(RD.RINGS) do
        for k = 1, RD.RING_SEG do
            local a0, a1 = (k - 1) * 2 * math.pi / RD.RING_SEG, k * 2 * math.pi / RD.RING_SEG
            local l = keep(line(s, "BORDER", math.sin(a0) * r, math.cos(a0) * r, math.sin(a1) * r, math.cos(a1) * r, g, 1))
            if ri < #RD.RINGS then RD.innerRings[#RD.innerRings + 1] = l end
        end
    end
    local h = RD.SIZE / 2 - 6
    keep(line(s, "BORDER", -h, 0, h, 0, g, 1))
    keep(line(s, "BORDER", 0, -h, 0, h, g, 1))
    for k = 0, 35 do
        local a = k * math.pi / 18
        local r2 = (k % 3 == 0) and 134 or 138
        keep(line(s, "BORDER", math.sin(a) * 142, math.cos(a) * 142, math.sin(a) * r2, math.cos(a) * r2, g, 1))
    end
    -- the square's corner brackets: two arms a corner, `sx`/`sy` kept so a ship can lengthen them (RD.ShapeBrackets)
    local b, e = RD.SIZE / 2 - 4, 22
    local bc = { RD.PHOS[1] * 0.6, RD.PHOS[2] * 0.6, RD.PHOS[3] * 0.6, 1 }
    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            local a1 = line(s, "BORDER", sx * b, sy * b, sx * (b - e), sy * b, bc, 2)
            local a2 = line(s, "BORDER", sx * b, sy * b, sx * b, sy * (b - e), bc, 2)
            a1.sx, a1.sy, a1.across = sx, sy, true
            a2.sx, a2.sy, a2.across = sx, sy, false
            RD.brackets[#RD.brackets + 1] = a1
            RD.brackets[#RD.brackets + 1] = a2
        end
    end
    -- you, in the middle: your role icon alone. The chevron that drew over it is gone (Arn, 10 Nov, on a DPS: "get rid
    -- of the chevron, and keep the role icon" - as a healer the healing icon hid it). The icon itself: RD.PaintMe
    RD.meLines, RD.meRole = {}, nil
    -- the dim places of every slot live on their own layer, unscaled, and go with the scope (RD.PaintQuiet)
    local dims = CreateFrame("Frame", nil, f)
    dims:SetAllPoints(f)
    RD.dims = dims
    return s
end

--- YOU, IN THE MIDDLE, ALWAYS (Arn, 10 Nov, after the chevron went: "my icon is gone"). Your heal pip lights only below
--- 90%, so at full health the middle was empty. Your role's sign now stays on the scope in the ship's accent, dimmed
--- (RD.ME_ALPHA); your heal pip lights over it, and it goes dark with the scope in a fight (RD.PaintQuiet). Rebuilt only
--- when your role changes.
--- HIDDEN AGAIN the same night (Arn: "you can hide my center icon and only light up when it needs to light up for a
--- heal, now i just want to click it because its on there"): alpha 0 - the middle is your heal pip alone, lit only when
--- you need one. The sign stays built, so one number brings it back.
RD.ME_ALPHA = 0
function RD.PaintMe()
    local s = RD.scope
    if not s then return end
    local role = RD.Role("player")
    if RD.meRole ~= role then
        for _, t in ipairs(RD.meLines or {}) do t:Hide() end
        RD.meLines = glyph(s, role, RD.SELF.ph * RD.GLYPH)
        RD.meRole = role
    end
    local A = (RD.ship and RD.ship.accent) or RD.PHOS
    for _, t in ipairs(RD.meLines) do t:SetVertexColor(A[1], A[2], A[3], RD.ME_ALPHA) end
end

--- One spoke's pieces: the heal pip (secure), its cure pips (client markers + secure boxes), its bogey, its alert
--- arcs and its dim places. Made once (a pool of 40 at most) and PLACED by RD.PlaceSpoke, out of a fight.
local function buildSpoke(f, i)
    local sp = { i = i }
    -- HEAL: a secure unit button; its face is ours
    local b = CreateFrame("Button", "BiSHealingRadarHeal" .. i, f, "SecureUnitButtonTemplate")
    if b.RegisterForClicks then b:RegisterForClicks("AnyDown") end
    -- EVERY LIT PIP PULSES (Arn, 8 Nov: "make the heal pips pulse too"): the face sits in a wrapper with a gentle pulse
    -- (green: hurt, can wait); amber's own layer a touch stronger; red's own layer hard. The pulse multiplies the
    -- curve's colour, so a pip the curve hides stays hidden.
    b.beat = CreateFrame("Frame", nil, b)
    b.beat:SetAllPoints(b)
    sp.beat = RD.Pulse(b.beat, RD.PULSE_SOFT)
    b.face = CreateFrame("Frame", nil, b.beat)
    b.face:SetAllPoints(b)
    -- NO BOX (Arn, 8 Nov: "the box outlines are not needed"): the pip is its role glyph alone, in the game's colour.
    -- Red has its own glyph on its own layer, coloured by the red curve, on its own hard pulse.
    b.redFace = CreateFrame("Frame", nil, b)
    b.redFace:SetAllPoints(b)
    sp.pulse = RD.Pulse(b.redFace, RD.PULSE_HARD)            -- a size pulse: the red curve alone decides it is seen
    -- AMBER PULSES A TOUCH STRONGER (Arn, 8 Nov: whack-a-mole - "it lights up and pulses a little"): its own glyph layer,
    -- lit only between the red and amber points by its own curve (RD.AmberCurve), on its own pulse. The main face goes
    -- see-through over amber, so only the amber layer's beat shows there.
    b.amberFace = CreateFrame("Frame", nil, b)
    b.amberFace:SetAllPoints(b)
    sp.amberPulse = RD.Pulse(b.amberFace, RD.PULSE_MID)
    -- the GCD's sweep, its swipe dark only while the pip is lit (RD.SwipeCurve on their health, RD.PaintHeal)
    sp.cd = RD.Sweep(b.face)
    b:HookScript("OnEnter", function()
        RD.over = sp
        if NS.OV then NS.OV.Enter(sp) end
        if sp.raidGroup then RD.GroupWash(sp, true) end          -- a raid deck: its group mates lit (sheet 6)
    end)
    b:HookScript("OnLeave", function()
        if sp.raidGroup then RD.GroupWash(sp, false) end
        if RD.over == sp then RD.over = nil end
        if NS.OV then NS.OV.Leave(sp) end
    end)
    -- THE OVER WORD (Overheal.lua, 12 Nov 2026): the click is measured here, before the cast starts
    b:HookScript("PostClick", function(_, button)
        RD.lastClick, RD.lastClickAt = sp, GetTime()            -- the Riptide tracker: whose box the cast went to
        if NS.OV then NS.OV.Click(sp, button) end
    end)
    sp.heal = b
    -- BOGEY: their target, a red triangle only while it casts; a click is your interrupt (enemies only)
    local k = CreateFrame("Button", "BiSHealingRadarBogey" .. i, f, "SecureActionButtonTemplate")
    if k.RegisterForClicks then k:RegisterForClicks("AnyDown") end
    -- AN INCOMING MISSILE PULSES HARD (Arn, 8 Nov: "make the bogeys pulse red when they show up"): the red heal pip's
    -- pulse, on a wrapper round the face - the face is alpha 0 unless a cast is on, so the pulse shows only then
    k.beat = CreateFrame("Frame", nil, k)
    k.beat:SetAllPoints(k)
    k.pulse = RD.Pulse(k.beat, RD.PULSE_HARD)
    k.face = CreateFrame("Frame", nil, k.beat)
    k.face:SetAllPoints(k)
    k.face:SetAlpha(0)
    -- YOUR INTERRUPT'S COOLDOWN (Arn, 8 Nov: "cooldown sweep on interrupt icon"): the grid's own sweep (FG.PvPCooldown's
    -- road) - the client runs it from the duration object it hands us for our own spell, no number read. On the face, so
    -- it is seen only while the bogey is (a cast to answer); RD.KickCooldown feeds it.
    local okCd, cd = pcall(CreateFrame, "Cooldown", nil, k.face, "CooldownFrameTemplate")
    if okCd and cd then
        cd:SetAllPoints(k.face)
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        k.cd = cd
    end
    sp.bogey = k
    -- THE CLICK'S WORD, LIKE THE GRID (Arn, 9 Nov: "flash LOS under the teammate im clicking like bis healing" ... "range
    -- for out of range ... only when i click them"): LOS or RANGE in the grid's red and thick outline (FG.Flash), just
    -- UNDER the pip, fading by itself in FG.FLASH_FOR (RD.HeardError). The red rim dashes for range are gone. A plain
    -- frame on the radar anchored to the pip, built here out of a fight; in one only its text, alpha and fade change.
    local los = CreateFrame("Frame", nil, f)
    los:SetPoint("TOP", b, "BOTTOM", 0, -1)
    los:SetSize(40, 16)
    if los.SetFrameLevel and b.GetFrameLevel then
        local lvl = b:GetFrameLevel()
        if type(lvl) == "number" then los:SetFrameLevel(lvl + 25) end
    end
    los.word = los:CreateFontString(nil, "OVERLAY")
    if los.word.SetFont then los.word:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "THICKOUTLINE") end
    los.word:SetPoint("CENTER", los, "CENTER", 0, 0)
    los.word:SetText("")                  -- empty until a click fails: no words stand on the scope
    local red = (NS.FG and NS.FG.FLASH_RED) or { 1.00, 0.25, 0.30 }
    los.word:SetTextColor(red[1], red[2], red[3], 1)
    los:SetAlpha(0)
    -- the dim places, out of a fight
    sp.dims = {}
    for d = 1, 3 do
        local fr = CreateFrame("Frame", nil, RD.dims)
        edge(fr, RD.DIM, 1)
        sp.dims[d] = fr
    end
    if los.CreateAnimationGroup then
        local ok, g = pcall(los.CreateAnimationGroup, los)
        if ok and g then
            local a = g:CreateAnimation("Alpha")
            a:SetFromAlpha(1) a:SetToAlpha(0) a:SetDuration((NS.FG and NS.FG.FLASH_FOR) or 1.2)
            if g.SetToFinalAlpha then g:SetToFinalAlpha(true) end
            sp.losFade = g
        end
    end
    sp.los = los
    sp.cures = {}
    -- THE PET: a small secure pip of its own, the client's unit watch showing it only while the pet is there
    local p = CreateFrame("Button", "BiSHealingRadarPet" .. i, f, "SecureUnitButtonTemplate")
    if p.RegisterForClicks then p:RegisterForClicks("AnyDown") end
    p.beat = CreateFrame("Frame", nil, p)
    p.beat:SetAllPoints(p)
    p.pulse = RD.Pulse(p.beat, RD.PULSE_SOFT)
    p.face = CreateFrame("Frame", nil, p.beat)
    p.face:SetAllPoints(p)
    p:Hide()
    sp.pet = p
    -- CROSSHAIRS ON YOUR TARGET (Arn, 8 Nov: "need a target pip indicated by crosshairs like on our regular frames"): the
    -- grid's own reticle (FG.Crosshair), magenta like the cockpit's target, round the heal pip when that person is your
    -- target and round the bogey when THEIR target is yours. Plain frames on the radar (not on the secure pips), so only
    -- their alpha ever changes - in a fight too.
    sp.cross = CreateFrame("Frame", nil, f)
    sp.bogeyCross = CreateFrame("Frame", nil, f)
    sp.totCross = CreateFrame("Frame", nil, f)
    for _, c in ipairs({ sp.cross, sp.bogeyCross, sp.totCross }) do
        if NS.FG and NS.FG.Crosshair then NS.FG.Crosshair(c, c == sp.totCross and RD.TOT or RD.CROSS) end
        c:SetFrameLevel(f:GetFrameLevel() + 20)
        c:SetAlpha(0)
    end
    return sp
end

--- Put a spoke where its slot is: sizes, places, the bogey's triangle, the arcs, the dim places. Out of a fight only
--- (the heal pip and the bogey are secure). A slot with no bogey (a raid's other groups) leaves it off.
function RD.PlaceSpoke(sp, s, rim)
    local f = RD.frame
    sp.slot = s
    local b = sp.heal
    b:SetSize(s.ph, s.ph)
    b:ClearAllPoints()
    b:SetPoint("CENTER", f, "CENTER", RD.Point(s, s.rh))
    RD.Halo(b, s.ph)
    if sp.glyphPx ~= s.ph then
        for _, t in ipairs(sp.glyph or {}) do t:Hide() end
        sp.glyph, sp.role, sp.glyphPx = nil, nil, s.ph
    end
    local k = sp.bogey
    if s.rb then
        k:SetSize(s.pb, s.pb)
        RD.Halo(k, s.pb)
        k:ClearAllPoints()
        k:SetPoint("CENTER", f, "CENTER", RD.Point(s, s.rb))
        if not k.lines or k.linesPx ~= s.pb then
            for _, l in ipairs(k.lines or {}) do l:Hide() end
            local h = s.pb * 0.42
            local rc = RD.COL.bogey
            local hid = { rc[1], rc[2], rc[3], 0 }               -- born see-through: only a cast makes it solid
            k.lines = { line(k.face, "OVERLAY", 0, h, h, -h * 0.8, hid, 2), line(k.face, "OVERLAY", h, -h * 0.8, -h, -h * 0.8, hid, 2),
                        line(k.face, "OVERLAY", -h, -h * 0.8, 0, h, hid, 2) }
            k.linesPx = s.pb
        end
    end
    -- the crosshairs sit on the pips they frame
    sp.cross:SetSize(s.ph + RD.CROSS_PAD, s.ph + RD.CROSS_PAD)
    sp.cross:ClearAllPoints()
    sp.cross:SetPoint("CENTER", f, "CENTER", RD.Point(s, s.rh))
    sp.totCross:SetSize(s.ph + RD.TOT_PAD, s.ph + RD.TOT_PAD)
    sp.totCross:ClearAllPoints()
    sp.totCross:SetPoint("CENTER", f, "CENTER", RD.Point(s, s.rh))
    if s.rb then
        sp.bogeyCross:SetSize(s.pb + RD.CROSS_PAD, s.pb + RD.CROSS_PAD)
        sp.bogeyCross:ClearAllPoints()
        sp.bogeyCross:SetPoint("CENTER", f, "CENTER", RD.Point(s, s.rb))
    end
    local spots = { { s.rh, s.ph }, { s.rc, s.pc }, { s.rb, s.pb } }
    for d, fr in ipairs(sp.dims) do
        local r, px = spots[d][1], spots[d][2]
        if r then
            fr:SetSize(px, px)
            fr:ClearAllPoints()
            fr:SetPoint("CENTER", f, "CENTER", RD.Point(s, r))
            fr:Show()
        else
            fr:Hide()
        end
    end
end

--- Spoke i, made the first time it is needed (a party needs 5, a raid 40).
function RD.Spoke(i)
    RD.spokes[i] = RD.spokes[i] or buildSpoke(RD.frame, i)
    return RD.spokes[i]
end

--[[ WHACK-A-MOLE (8 Nov 2026, Arn: "something lights up we click, it lights up and pulses a little it grabs more of our
  attention"). EVERYTHING THAT LIGHTS ALSO PULSES: a client AnimationGroup, alpha BOUNCE, looping, playing always - no
  OnUpdate, nothing read. It runs on a WRAPPER frame whose alpha we never set (`beat`), with the lit face inside it, so
  the pulse only ever multiplies what the game's curve or boolean decided: an invisible pip stays invisible.
  Gentle (RD.PULSE_SOFT) for a tool, a cure, amber; hard (RD.PULSE_HARD) for red and for a bogey - an incoming missile. ]]
-- A PULSE OF SIZE, NOT OF ALPHA (8 Nov 2026, Arn's screenshots: an amber cross at the centre at 98% health, "center
-- cross still pulsing", and bogeys showing with nothing casting). In the client an ALPHA animation on a frame drove that
-- frame's alpha itself - what we hid by alpha under it came back. A SCALE bounce never touches whether a thing is seen:
-- an invisible pip grows invisibly, a lit one breathes. { grow to, seconds }.
RD.SIZE_PULSE = false                              -- the size pulse is OFF: it blew a pip up to the whole screen
RD.PULSE_SOFT = { 1.08, 0.5 }                      -- grow to, seconds
RD.PULSE_MID = { 1.13, 0.45 }                      -- amber: a touch stronger than soft
RD.PULSE_HARD = { 1.20, 0.35 }
function RD.Pulse(frame, kind)
    if not (frame and frame.CreateAnimationGroup) then return nil end
    local p = kind or RD.PULSE_SOFT
    local ok, g = pcall(frame.CreateAnimationGroup, frame)
    if not (ok and g) then return nil end
    local a = g:CreateAnimation("Scale")
    if a.SetScaleFrom and a.SetScaleTo then
        a:SetScaleFrom(1, 1)
        a:SetScaleTo(p[1], p[1])
    elseif a.SetScale then
        a:SetScale(p[1], p[1])
    end
    if a.SetOrigin then pcall(a.SetOrigin, a, "CENTER", 0, 0) end
    a:SetDuration(p[2])
    g:SetLooping("BOUNCE")
    -- OFF (8 Nov 2026, Arn's screenshot: in a fight his own green heal pip filled the whole screen - the client's SCALE
    -- bounce grew it without bound). Built, never played, until a probe says how this client runs a Scale animation.
    if RD.SIZE_PULSE then g:Play() end
    return g
end

--- The ALPHA pulse, kept only where what is seen is decided by SHAPE, not by alpha: the BINGO band (a clipped window)
--- and the stabilizer's last-charge wash (the client's own text). Never under anything hidden by alpha.
RD.FADE_SOFT, RD.FADE_HARD = { 0.55, 0.5 }, { 0.35, 0.35 }
function RD.PulseAlpha(frame, kind)
    if not (frame and frame.CreateAnimationGroup) then return nil end
    local p = kind or RD.FADE_SOFT
    local ok, g = pcall(frame.CreateAnimationGroup, frame)
    if not (ok and g) then return nil end
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(1) a:SetToAlpha(p[1]) a:SetDuration(p[2])
    g:SetLooping("BOUNCE")
    g:Play()
    return g
end

--[[ THE GLOBAL COOLDOWN'S SWEEP ON EVERYTHING LIT (8 Nov 2026, Arn: "would be kinda cool to also put the global cooldown
  sweep on everything that lit"). The bogey's own kind of sweep (no bling, no numbers) on each clickable face, all fed
  ONE duration object per SPELL_UPDATE_COOLDOWN (RD.Sweeps): the GCD's (spell 61304), or the radar heal's own cooldown
  when the client will not answer for it. Mana Tide and the potion show their own cooldown instead. A face that is lit
  by its COLOUR (a heal pip, a tool) has its swipe coloured by a curve too (RD.SwipeCurve), so it is dark only while the
  face is lit and see-through otherwise; a face lit by its alpha (rations, a cure marker) needs nothing more. ]]
RD.GCD = 61304
RD.SWIPE = { 0, 0, 0, 0.6 }
RD.sweeps = {}                                     -- every GCD sweep, fed in one loop
function RD.Sweep(parent, own)
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, parent, "CooldownFrameTemplate")
    if not (ok and cd) then return nil end
    cd:SetAllPoints(parent)
    if cd.SetDrawBling then cd:SetDrawBling(false) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    -- NO EDGE (Arn, 8 Nov: "cool down sweep show up when pips are not there" - the bright edge line is not coloured by
    -- the pip's curve, so it ran over unlit and empty spots). Only the swipe, which the curve makes see-through there.
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if not own then RD.sweeps[#RD.sweeps + 1] = cd end
    return cd
end

--[[ COOLING, SEEN WHEN DARK (8 Nov 2026, Arn, after using Mana Tide: "we should put it there but with a cooldown sweep
  right now i think its ready to go again"). Mana Tide and the potion carry their own cooldown on the BUTTON, not on the
  face - so it shows while the face is dark - as a dim cyan disc (Art\disc.tga) the client eats away as it comes ready:
  there = still cooling, gone = ready. Under the face (a lower level), so a lit sign draws over it. A Cooldown frame
  only draws while it runs, so nothing of ours decides "cooling" - the client's own object, secret or not. ]]
RD.WAIT_SWIPE = { 0.30, 0.90, 1.00, 0.35 }
function RD.WaitSweep(b)
    local cd = RD.Sweep(b, true)
    if not cd then return nil end
    cd.wait = true
    if cd.SetFrameLevel then cd:SetFrameLevel(b:GetFrameLevel()) end    -- under the face's wrapper (b + 1)
    if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, RD.ART .. "disc") end
    local W = RD.WAIT_SWIPE
    if cd.SetSwipeColor then pcall(cd.SetSwipeColor, cd, W[1], W[2], W[3], W[4]) end
    return cd
end

--- A sweep back in the loop (its marker switched on again); never twice.
function RD.Resweep(cd)
    if not cd then return false end
    for _, x in ipairs(RD.sweeps) do if x == cd then return false end end
    RD.sweeps[#RD.sweeps + 1] = cd
    return true
end

--- A sweep whose marker was thrown away (a cure re-placed): out of the list, so the loop stays the size of what is seen.
function RD.Unsweep(cd)
    if not cd then return false end
    for i = #RD.sweeps, 1, -1 do if RD.sweeps[i] == cd then table.remove(RD.sweeps, i) return true end end
    return false
end

--- The swipe's shade by a fraction (health or mana): dark at and below `at`, nothing above.
RD.swipeCurves = {}
function RD.SwipeCurve(at)
    local key = math.floor((tonumber(at) or 1) * 100 + 0.5)
    if RD.swipeCurves[key] then return RD.swipeCurves[key] end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, c = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not c or not c.AddPoint then return nil end
    if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then pcall(c.SetType, c, Enum.LuaCurveType.Linear) end
    local S, x = RD.SWIPE, key / 100
    pcall(c.AddPoint, c, 0.00, CreateColor(S[1], S[2], S[3], S[4]))
    pcall(c.AddPoint, c, x, CreateColor(S[1], S[2], S[3], S[4]))
    pcall(c.AddPoint, c, x + 0.0001, CreateColor(S[1], S[2], S[3], 0))
    pcall(c.AddPoint, c, 1.00, CreateColor(S[1], S[2], S[3], 0))
    RD.swipeCurves[key] = c
    return c
end

--- A sweep's swipe in the colour the client worked out; no colour back = no swipe (never a dark disc on nothing).
local function swipeTo(cd, col)
    if not cd then return false end
    if type(col) == "table" and col.GetRGBA and cd.SetSwipeColor
       and pcall(function() cd:SetSwipeColor(col:GetRGBA()) end) then return true end
    if cd.SetSwipeColor then pcall(cd.SetSwipeColor, cd, 0, 0, 0, 0) end
    return false
end

--- A system pip in the column: a secure button (for its click) with our own face, inside its pulse wrapper.
local function buildSystem(f, name, point, x, y, rel)
    local b = CreateFrame("Button", "BiSHealingRadar" .. name, f, "SecureActionButtonTemplate")
    b:SetSize(RD.SYS_PX, RD.SYS_PX)
    b:SetPoint(point, rel or f, point, x, y)
    b.home = { point, rel or f, point, x, y }       -- where the radar keeps it (the console moves it: RD.RadarLayout)
    b.rail = rel
    if b.RegisterForClicks then b:RegisterForClicks("AnyDown") end
    b.beat = CreateFrame("Frame", nil, b)
    b.beat:SetAllPoints(b)
    b.face = CreateFrame("Frame", nil, b.beat)
    b.face:SetAllPoints(b)
    b.ring = {}
    local r = RD.SYS_PX / 2 - 1
    for k = 1, 16 do
        local a0, a1 = (k - 1) * math.pi / 8, k * math.pi / 8
        b.ring[k] = line(b.face, "ARTWORK", math.sin(a0) * r, math.cos(a0) * r, math.sin(a1) * r, math.cos(a1) * r, RD.COL.cyan, 2)
    end
    b.icon = b.face:CreateTexture(nil, "OVERLAY")
    b.icon:SetPoint("CENTER") b.icon:SetSize(RD.SYS_PX - 10, RD.SYS_PX - 10)
    RD.Halo(b, RD.SYS_PX)
    -- what it is, under the mouse only (no words on the scope): b.tip = { title, line }
    b:HookScript("OnEnter", function(self)
        local tip = self.tip
        if not (tip and GameTooltip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(tip[1])
        if tip[2] then GameTooltip:AddLine(tip[2], 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end

--[[ THE FUEL GAUGE (8 Nov 2026). Arn: "I want to end the boss fight at 0% mana ... if its at 50% I should be at 50% mana
  ... if its at 70% and im at 20% thats a warning". THE GPU COMPARES, LUA NEVER DOES. Bottom to top, all on the same tape:
    boss      a StatusBar of the boss's health (boss1, else a hostile target), red, 0..max handed untouched
    mana      your mana over it, the same size and place, green: where you are behind, red shows above your fuel
    ticks     25 / 50 / 75, phosphor
    caret     a magenta mark on the boss bar's FILL TOP (the heal-absorb anchoring), drawn over the mana
    BINGO     a ruler: your mana again, in a frame lifted 30% of the tape and clipped to it (never seen). A window
              whose FLOOR is anchored to that ruler's fill top - so it starts at mana + 30% - clips a copy of the boss
              bar in a pulsing hot magenta and a hot flag under the caret. Boss more than 30% ahead of you: the hot
              band shows from mana + 30% up to the boss, the flag with it. Not that far behind: the window is above the
              boss's fill, and nothing shows. Exact to the pixel: two fill edges and a fixed offset, no number read.
  The boss layer's alpha says whether there is a boss at all (a secret "hostile?" goes to SetAlphaFromBoolean).
  SIDEWAYS SINCE 9 NOV (Arn: "put it on top side ways that way only one rail per side"): the tape runs left to right
  along the top rail, so "above" in the words here is "to the right of" on the screen - the caret on the boss fill's
  RIGHT end, the ruler lifted 30% to the right, the BINGO window's floor its LEFT edge. ]]
local function fuelBar(parent, col, lvl)
    local s = CreateFrame("StatusBar", nil, parent)
    s:SetStatusBarTexture(RD.WHITE)
    s:SetStatusBarColor(col[1], col[2], col[3], col[4] or 1)
    if s.SetOrientation then s:SetOrientation("HORIZONTAL") end        -- fills from the left
    s:SetMinMaxValues(0, 1)
    s:SetValue(0)
    s:SetFrameLevel(lvl)
    return s
end

local function buildGauge(f)
    local G = RD.GAUGE
    local g = CreateFrame("Frame", nil, f)
    RD.gauge = g
    g:SetFrameLevel(f:GetFrameLevel() + 2)
    local L = g:GetFrameLevel()
    g.track = g:CreateTexture(nil, "BACKGROUND")
    g.track:SetAllPoints(g)
    g.track:SetColorTexture(0.02, 0.09, 0.05, 0.9)
    -- the boss layer: everything that is the boss's, so one alpha says "is there one"
    g.bossLayer = CreateFrame("Frame", nil, g)
    g.bossLayer:SetAllPoints(g)
    g.bossLayer:SetFrameLevel(L + 1)
    g.bossLayer:SetAlpha(0)
    g.boss = fuelBar(g.bossLayer, RD.BOSS_COL, L + 1)
    g.boss:SetAllPoints(g)
    g.mana = fuelBar(g, RD.MANA_COL, L + 2)
    g.mana:SetAllPoints(g)
    g.tickFrame = CreateFrame("Frame", nil, g)
    g.tickFrame:SetAllPoints(g)
    g.tickFrame:SetFrameLevel(L + 3)
    RD.BuildHUD(g, L)
    g.ticks = {}
    for q = 1, 3 do g.ticks[q] = line(g.tickFrame, "OVERLAY", 0, 0, 1, 0, RD.PHOS, 1) end
    -- the boss's level, over your mana
    g.caretFrame = CreateFrame("Frame", nil, g.bossLayer)
    g.caretFrame:SetAllPoints(g)
    g.caretFrame:SetFrameLevel(L + 4)
    g.caret = tex(g.caretFrame, "OVERLAY", RD.CARET)
    g.caret:SetSize(3, G.w + 3)
    g.caret:SetPoint("BOTTOM", g.boss:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    -- BINGO: the lifted ruler (clipped to the tape, its colour see-through - it is only an edge)
    g.rulerClip = CreateFrame("Frame", nil, g)
    g.rulerClip:SetAllPoints(g)
    g.rulerClip:SetClipsChildren(true)
    g.rulerClip:SetFrameLevel(L + 1)
    g.lift = CreateFrame("Frame", nil, g.rulerClip)
    g.ruler = fuelBar(g.lift, { 0, 0, 0, 0 }, L + 1)
    g.ruler:SetAllPoints(g.lift)
    -- the window: floor on the ruler's fill end, roof past the tape's end (mana + 30% can reach 130%), tall enough for
    -- the flag
    g.hotClip = CreateFrame("Frame", nil, g.bossLayer)
    g.hotClip:SetClipsChildren(true)
    g.hotClip:SetFrameLevel(L + 5)
    g.hotClip:SetPoint("BOTTOMLEFT", g.ruler:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    g.hot = fuelBar(g.hotClip, RD.HOT, L + 5)
    g.hot:SetAllPoints(g)
    g.flagFrame = CreateFrame("Frame", nil, g.hotClip)
    g.flagFrame:SetAllPoints(g)
    g.flagFrame:SetFrameLevel(L + 6)
    -- the BINGO flag: a hot bar just behind the magenta caret, as tall - shown only inside the window
    g.flag = tex(g.flagFrame, "OVERLAY", RD.HOT)
    g.flag:SetSize(3, G.w + 3)
    g.flag:SetPoint("BOTTOMRIGHT", g.boss:GetStatusBarTexture(), "BOTTOMRIGHT", -3, 0)
    -- BINGO pulses hard, always playing: it is seen only while the window holds some of the boss's fill
    g.pulse = RD.PulseAlpha(g.hotClip, RD.FADE_HARD)
    -- REGEN, "generating fuel": a cyan inflow chevron at the foot (RD.PaintRegen)
    g.chev = CreateFrame("Frame", nil, f)
    g.chev:SetSize(12, 10)
    g.chev:SetAlpha(0)
    local C = RD.COL.cyan
    g.chevLines = { line(g.chev, "OVERLAY", -5, -1, 0, 4, C, 2), line(g.chev, "OVERLAY", 0, 4, 5, -1, C, 2),
                    line(g.chev, "OVERLAY", -5, -5, 0, 0, C, 2), line(g.chev, "OVERLAY", 0, 0, 5, -5, C, 2) }
    -- the REGEN READOUT at the gauge's foot (Arn, 8 Nov: "bottom of the gauge we should put our mana regen % - 100% out
    -- of combat, in combat reads our talents like the bis healing header"): Regen.lua's own words. CENTRED in the room
    -- kept at the tape's right end (Arn: "more centered in the empty space"), the chevron on its right.
    g.regen = f:CreateFontString(nil, "OVERLAY")
    g.regen:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
    g.regen:SetTextColor(C[1], C[2], C[3])
    g.regen:SetPoint("CENTER", RD.gaugeRail or f, "RIGHT", -math.floor(G.right / 2) - 4, 4)   -- the pair centred
    g.regen:SetText("100%")
    g.chev:SetPoint("LEFT", g.regen, "RIGHT", 3, 0)
    -- THE FIVE SECOND RULE, COUNTED DOWN (Arn, 8 Nov: "somewhere on there the 5 second casting rule for 100% mana regen
    -- ... so they know if i wait a little bit i can get full mana regen"): five segments under the readout, one per
    -- second left, draining as you hold your casts; all gone = 100% again. Shown in a fight, inside the rule only.
    g.fsr = CreateFrame("Frame", nil, f)
    g.fsr:SetSize(RD.FSR.n * RD.FSR.w + (RD.FSR.n - 1) * RD.FSR.gap, RD.FSR.h)
    g.fsr:SetPoint("TOP", g.regen, "BOTTOM", 0, -2)
    g.fsr:SetAlpha(0)
    g.fsrSegs = {}
    for k = 1, RD.FSR.n do
        local t = tex(g.fsr, "OVERLAY", C)
        t:SetSize(RD.FSR.w, RD.FSR.h)
        t:SetPoint("LEFT", g.fsr, "LEFT", (k - 1) * (RD.FSR.w + RD.FSR.gap), 0)
        g.fsrSegs[k] = t
    end
    -- what it is, under the mouse only; the radar's own drag goes on through it. THE WHOLE RAIL answers (Arn, 8 Nov: "the
    -- tool tip is inconsistent only certain parts of the gauge light it up" - only the 7px tape did): the tape, the
    -- scale, the readout and the ramjet at the foot all show the same card, anchored to the rail
    local function tipOn(w)
        w:EnableMouse(true)
        w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart", function() local s = f:GetScript("OnDragStart") if s then s(f) end end)
        w:SetScript("OnDragStop", function() endDrag(f) end)
        w:SetScript("OnEnter", function()
            if not GameTooltip then return end
            GameTooltip:SetOwner(RD.gaugeRail or g, "ANCHOR_RIGHT")
            GameTooltip:AddLine("MANA")      -- plain words, never the old flight words (Arn, 15 Nov: "call it what it is now")
            for _, l in ipairs(RD.FuelTip()) do GameTooltip:AddLine(l, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        w:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    tipOn(g)
    if RD.gaugeRail then tipOn(RD.gaugeRail) end
    -- THE PLACARD at the tape's left end, a pilot's seat plate: your ROLE (Arn, 9 Nov: "lets add our role here Healer,
    -- DPS, Tank" - RD.PaintRole), the ship you are flying (RD.ApplyShip), then the word FUEL (Arn: "lets not do rpm" - a
    -- bar across the top reads as an engine gauge without it). The rail's only words; the scope has none.
    local P = RD.gaugeRail or f
    local function word(text)
        local fs = P:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "")
        fs:SetText(text)
        return fs
    end
    -- each line at its own fixed spot, so an empty role (the game said none) leaves the ship and FUEL where they are
    g.role = word("")
    g.role:SetPoint("TOPLEFT", P, "TOPLEFT", 6, -5)
    g.role:SetTextColor(1, 1, 1)
    g.ship = word(RD.SHIPS[1].name)
    g.ship:SetPoint("TOPLEFT", P, "TOPLEFT", 6, -17)
    g.fuelWord = word("MANA")
    g.fuelWord:SetPoint("TOPLEFT", P, "TOPLEFT", 6, -29)
    RD.SizeGauge(RD.SIZE)
    return g
end

--- The rails, outside the square: the tool rail on its left and the defence rail on its right, the radar's full height;
--- the gauge's rail across the top of both the tool rail and the square. Their own frames under the radar's level so the
--- tape and the tools draw over them; the radar's clamp grows to keep them on the screen.
local function rail(f, w)
    local r = CreateFrame("Frame", nil, f)
    if w then r:SetWidth(w) end
    r:SetFrameLevel(math.max(0, f:GetFrameLevel()))
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints(r)
    r.bg:SetTexture(RD.WHITE)
    r.bg:SetVertexColor(RD.PLATE[1], RD.PLATE[2], RD.PLATE[3], 1)
    return r
end
function RD.BuildRails(f)
    if RD.toolRail then return RD.toolRail, RD.gaugeRail end
    local gap = RD.RAIL_GAP
    local t = rail(f, RD.TOOL_RAIL_W)
    t:SetPoint("TOPRIGHT", f, "TOPLEFT", -gap, 0)
    t:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", -gap, 0)
    -- THE GAUGE'S RAIL ON TOP (Arn, 9 Nov: "put it on top side ways that way only one rail per side"): from the tool
    -- rail's left edge to the square's right edge; its width follows the square (RD.SizeGauge)
    local g = rail(f)
    g:SetHeight(RD.GAUGE_RAIL_H)
    g:SetPoint("BOTTOMLEFT", t, "TOPLEFT", 0, gap)
    g:SetWidth(RD.SIZE + RD.TOOL_RAIL_W + gap)
    -- THE DEFENCE RAIL on the right (CHAFF): shown only when it holds something (RD.ArmTools, out of a fight)
    local d = rail(f, RD.TOOL_RAIL_W)
    d:SetPoint("TOPLEFT", f, "TOPRIGHT", gap, 0)
    d:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", gap, 0)
    d:Show()                         -- always (Arn, 10 Nov: "always show the full square rail")
    RD.toolRail, RD.gaugeRail, RD.defRail = t, g, d
    -- THE BLACK BOX'S RAIL along the bottom (BlackBox.lua, 10 Nov: "Build the bottom raid with the squawk box thing")
    if NS.BB and NS.BB.Build then RD.bbRail = NS.BB.Build(f, t, rail) end
    RD.BuildHull(f)
    RD.BuildGrip(f)
    RD.ClampRails()
    return t, g
end

--[[ THE CORNER GRIP (11 Nov 2026, Arn: "instead of having a command to set the scale for the radar can we the corner drag
  to resize for radar and engineer"). A small plain button on the hull's bottom-right corner - the whole instrument's,
  radar or engineer's view alike (the hull is both). Drag = the scale (RD.SCALE_MIN..MAX), the top-left corner held
  where it is; right-click = back to 100%. The radar is a secure frame, so OUT OF A FIGHT ONLY: nothing at all in one,
  and a drag ends at PLAYER_REGEN_DISABLED (endDrag) and on hide. Saved as the scale and a TOPLEFT position. ]]
RD.SCALE_MIN, RD.SCALE_MAX, RD.GRIP_PX = 0.5, 2, 14

--- The scale a drag gives: the cursor's distance from the held top-left corner, against where the drag began (screen
--- pixels, both axes added so a diagonal pull reads naturally). Clamped. Plain numbers only.
function RD.GripScale(startScale, left, top, sx, sy, cx, cy)
    local was = (sx - left) + (top - sy)
    if type(was) ~= "number" or was <= 1 then return startScale end
    local now = (cx - left) + (top - cy)
    local s = startScale * now / was
    return math.max(RD.SCALE_MIN, math.min(RD.SCALE_MAX, s))
end

-- THE STOPS (Arn, 15 Nov: "fake stops every 25% and if you keep dragging itll pass it"): within RD.SNAP_BAND of a quarter
-- (50%, 75%, 100% ... 200%) the scale sits on it; drag on past the band and it moves again
RD.SNAP_STEP, RD.SNAP_BAND = 0.25, 0.04
function RD.SnapScale(s)
    if type(s) ~= "number" then return s end
    local q = math.floor(s / RD.SNAP_STEP + 0.5) * RD.SNAP_STEP
    if math.abs(s - q) <= RD.SNAP_BAND then return q end
    return s
end

--- THE LIVE READOUT (Arn: "would be nice if it updated live so i can see what % im at"): while the grip drags, the scale
--- ("75%") or the width ("300 px") beside it - the tooltip goes when the mouse leaves the grip, this stays. nil hides it.
function RD.GripReadout(text)
    local g = RD.grip
    if not g then return nil end
    if not g.pct then
        g.pct = g:CreateFontString(nil, "OVERLAY")
        g.pct:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        g.pct:SetPoint("BOTTOMRIGHT", g, "TOPLEFT", -2, 2)
        local P = RD.PHOS
        g.pct:SetTextColor(P[1], P[2], P[3], 1)
    end
    g.pct:SetText(text or "")
    if text then g.pct:Show() else g.pct:Hide() end
    return text
end

--- Scale the radar to `s` with its top-left corner staying at (left, top) in screen pixels.
function RD.ScaleAt(f, s, left, top)
    if combat() then return false end
    f:SetScale(s)
    local k = f:GetEffectiveScale()
    if type(k) ~= "number" or k <= 0 then return false end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / k, top / k)
    return true
end

--- THE OPTIONS' SIZE ROW, while the radar look shows (11 Nov 2026, Arn: "people might try to reize from here" ... "we
--- can make it so only the scale work on the rader and nothing else"): the radar's own scale, the same one the corner
--- grip sets, the top-left corner held. Out of a fight only (a secure frame). Answers the scale it has.
function RD.Scale() return math.max(RD.SCALE_MIN, math.min(RD.SCALE_MAX, tonumber(db().scale) or 1)) end
function RD.SetScale(v)
    local f = RD.frame
    local s = math.floor(math.max(RD.SCALE_MIN, math.min(RD.SCALE_MAX, tonumber(v) or 1)) * 100 + 0.5) / 100
    if combat() then return RD.Scale() end
    db().scale = s
    if f then
        local k, l, t = f:GetEffectiveScale(), f.GetLeft and f:GetLeft(), f.GetTop and f:GetTop()
        if type(k) == "number" and type(l) == "number" and type(t) == "number" then
            RD.ScaleAt(f, s, l * k, t * k)
            local ok, p, _, rp, x, y = pcall(f.GetPoint, f)
            p, rp, x, y = plain(p), plain(rp), plain(x), plain(y)
            if ok and type(p) == "string" and type(x) == "number" and type(y) == "number" then
                db().pos = { p, type(rp) == "string" and rp or p, x, y }
            end
        else
            f:SetScale(s)
        end
    end
    return s
end

--[[ SHIFT + DRAG = THE WIDTH (15 Nov 2026, Arn: "they could just resize on how many fit in the window by making the window
  bigger"; mockup https://claude.ai/artifact/NzLCgjinETPrUVic2Xawxc). The top-left corner held; the cursor's sideways move
  (in the frame's own pixels) is the new width of the boxes' area, never under the totem row's floor. The deck is laid out
  again as it changes, at most every RD.WIDTH_EVERY seconds (secure buttons move: out of a fight only - a pull ends it). ]]
RD.WIDTH_EVERY = 0.12
function RD.WidthFor(startInner, sx, cx, k)
    if type(k) ~= "number" or k <= 0 then return startInner end
    return math.max(RD.FloorInner(), startInner + (cx - sx) / k)
end
function RD.StartWidthDrag(g, f, k, l, t, sx)
    local fw = f:GetWidth()
    if type(fw) ~= "number" then return false end
    g.sizing = { width = true, start = RD.DeckWidth() or (fw - 2 * RD.CON.pad), sx = sx, k = k, last = 0 }
    RD.ScaleAt(f, f:GetScale(), l * k, t * k)               -- held by the top-left from here on
    local ok, p, _, rp, x, y = pcall(f.GetPoint, f)          -- and saved so: a reload keeps the corner where it was
    p, rp, x, y = plain(p), plain(rp), plain(x), plain(y)
    if ok and type(p) == "string" and type(x) == "number" and type(y) == "number" then
        db().pos = { p, type(rp) == "string" and rp or p, x, y }
    end
    g:SetScript("OnUpdate", function(self, elapsed)
        local z = self.sizing
        if not z or combat() then RD.EndGrip() return end
        z.last = z.last + (tonumber(elapsed) or 0)
        if z.last < RD.WIDTH_EVERY then return end
        z.last = 0
        local cx = GetCursorPosition()
        local w = math.floor(RD.WidthFor(z.start, z.sx, cx, z.k) + 0.5)
        if w ~= z.applied then
            z.applied = w
            RD.SetDeckWidth(w)
            RD.Arm()
            RD.GripReadout(w + 2 * RD.CON.pad .. " px")         -- the window's width, live
        end
    end)
    return true
end

--- The window back to 100%, its top-left corner held, the spot saved. Out of a fight.
function RD.ScaleHome()
    local f = RD.frame
    if not f or combat() then return false end
    local k, l, t = f:GetEffectiveScale(), f:GetLeft(), f:GetTop()
    if type(k) == "number" and type(l) == "number" and type(t) == "number" then
        RD.ScaleAt(f, 1, l * k, t * k)
    end
    db().scale = 1
    local ok, p, _, rp, x, y = pcall(f.GetPoint, f)
    p, rp, x, y = plain(p), plain(rp), plain(x), plain(y)
    if ok and type(p) == "string" and type(x) == "number" and type(y) == "number" then
        db().pos = { p, type(rp) == "string" and rp or p, x, y }
    end
    return true
end

--- RESET (16 Nov 2026, Arn: "there should be a reset button where in full it resets to everything on and the size i had
--- it ... i think it was 100%"): every switch on (FULL), the window's own width, the boxes at 100%, the window at 100%.
function RD.SwReset()
    if combat() or RD.inFight then return nil end
    RD.SetDeckWidth(nil)
    RD.SetBoxHeight(nil)
    RD.ScaleHome()
    -- the raid layout back to its own too (21 Nov 2026): no group tags, groups as rows, tanks then groups
    local d = db()
    if type(d.sw) == "table" then d.sw.gtag, d.sw.cols = nil, nil end
    d.deckSort = nil
    return RD.SwPreset("full")
end

--- The grip's drag over: the scale and the corner saved.
function RD.EndGrip()
    local g, f = RD.grip, RD.frame
    if not (g and g.sizing) then return false end
    local widthDrag = g.sizing.width
    g.sizing = nil
    g:SetScript("OnUpdate", nil)
    RD.GripReadout(nil)                                     -- the live % / px goes with the drag
    if widthDrag then return true end                       -- the width is already saved, the corner held
    if f then
        db().scale = f:GetScale()
        local ok, p, _, rp, x, y = pcall(f.GetPoint, f)
        p, rp, x, y = plain(p), plain(rp), plain(x), plain(y)
        if ok and type(p) == "string" and type(x) == "number" and type(y) == "number" then
            db().pos = { p, type(rp) == "string" and rp or p, x, y }
        end
    end
    return true
end

function RD.BuildGrip(f)
    if RD.grip then return RD.grip end
    local g = CreateFrame("Button", nil, f)
    g:SetSize(RD.GRIP_PX, RD.GRIP_PX)
    g:SetPoint("TOPLEFT", RD.hull or f, "BOTTOMRIGHT", -RD.GRIP_PX + 4, RD.GRIP_PX - 4)   -- on the corner, over the soft edge
    g:SetFrameLevel((f:GetFrameLevel() or 0) + 30)
    if g.RegisterForClicks then g:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    -- three short strokes across the corner, the classic sizing mark, in the scope's green (brighter under the mouse)
    local P = RD.PHOS
    g.lines = {}
    for k = 1, 3 do
        local o = 2 + (k - 1) * 4
        g.lines[k] = line(g, "OVERLAY", RD.GRIP_PX / 2 - o, -RD.GRIP_PX / 2 + 1, RD.GRIP_PX / 2 - 1, -RD.GRIP_PX / 2 + o,
                          { P[1], P[2], P[3], 0.45 }, 1.5)
    end
    local function glow(a) for _, l in ipairs(g.lines) do l:SetVertexColor(P[1], P[2], P[3], a) end end
    g:SetScript("OnEnter", function(self)
        glow(1)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("RESIZE  " .. math.floor(f:GetScale() * 100 + 0.5) .. "%")
        GameTooltip:AddLine("Drag to make it bigger or smaller.  Double-click or right-click: back to 100%.  Out of a fight.", 1, 1, 1, true)
        if RD.Deck() then
            GameTooltip:AddLine("Shift + drag: wider or narrower - the boxes keep their size, more or fewer fit in a row.  "
                                .. "Shift + right-click: its own width again.", 0.6, 0.9, 1, true)
        end
        GameTooltip:Show()
    end)
    g:SetScript("OnLeave", function() glow(0.45) if GameTooltip then GameTooltip:Hide() end end)
    g:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or combat() then return end
        local k = f:GetEffectiveScale()
        local l, t = f:GetLeft(), f:GetTop()
        if not (type(k) == "number" and type(l) == "number" and type(t) == "number") then return end
        local sx, sy = GetCursorPosition()
        if RD.Deck() and IsShiftKeyDown and IsShiftKeyDown() then return RD.StartWidthDrag(self, f, k, l, t, sx) end
        self.sizing = { scale = f:GetScale(), left = l * k, top = t * k, sx = sx, sy = sy }
        RD.ScaleAt(f, self.sizing.scale, self.sizing.left, self.sizing.top)   -- held by the top-left from here on
        self:SetScript("OnUpdate", function()
            local z = self.sizing
            if not z or combat() then RD.EndGrip() return end
            local cx, cy = GetCursorPosition()
            local s = RD.SnapScale(RD.GripScale(z.scale, z.left, z.top, z.sx, z.sy, cx, cy))
            RD.ScaleAt(f, s, z.left, z.top)
            RD.GripReadout(math.floor(s * 100 + 0.5) .. "%")
        end)
        RD.GripReadout(math.floor(f:GetScale() * 100 + 0.5) .. "%")
    end)
    g:SetScript("OnMouseUp", function() RD.EndGrip() end)
    g:SetScript("OnHide", function() RD.EndGrip() end)
    -- DOUBLE-CLICK = THE DEFAULT SIZE (22 Nov 2026, Arn: "we steal from bis tools for the bis healing double clicking bottom right
    -- resize corner puts bis healing in defaut size 100%" - the phone's corner does it): 100% and the view's own width
    g:SetScript("OnDoubleClick", function(_, button)
        if button ~= "LeftButton" or combat() then return end
        RD.EndGrip()
        if RD.Deck() and RD.DeckWidth() then RD.SetDeckWidth(nil) RD.Arm() end
        RD.ScaleHome()
    end)
    g:SetScript("OnClick", function(_, button)
        if button ~= "RightButton" or combat() then return end
        if RD.Deck() and IsShiftKeyDown and IsShiftKeyDown() then RD.SetDeckWidth(nil) RD.Arm() return end
        RD.ScaleHome()
    end)
    RD.grip = g
    return g
end

--[[ ONE HULL, SOFT EDGES (10 Nov 2026, Arn: "complete the rails so there are no gaps and alpha the edges"). Behind every
  rail and the square, on the radar's own lowest layer: ONE solid plate from the gauge rail's top-left corner to the
  bottom rail's bottom-right (the right rail's column too while it shows, RD.FitHull), so the gaps between the rails
  and the corners over and under the right rail are filled. Around it RD.EDGE_N thin rings of the same plate, each
  fainter (RD.EdgeAlpha), RD.EDGE_PX apart: the instrument fades into the world instead of ending on a hard line.
  The ship's plate colour repaints all of it (RD.PaintHull, from RD.ApplyShip). ]]
RD.EDGE_N, RD.EDGE_PX = 6, 2
function RD.EdgeAlpha(k) return 0.9 * (1 - k / (RD.EDGE_N + 1)) ^ 1.6 end
function RD.BuildHull(f)
    if RD.hull then return RD.hull end
    local function plateTex()
        local t = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        t:SetTexture(RD.WHITE)
        return t
    end
    RD.hull = plateTex()
    RD.edges = {}
    for k = 1, RD.EDGE_N do
        local ring = { a = RD.EdgeAlpha(k), k = k }
        for _, side in ipairs({ "top", "bottom", "left", "right" }) do ring[side] = plateTex() end
        RD.edges[k] = ring
    end
    -- A FRAME over the plate, for other addons to dock against (BiSHealingAPI v2 RadarEdge). 12 Nov 2026, Arn's BugSack:
    -- "Cannot anchor protected frames to regions" - the BiS Tools box holds secure buttons, and the client refuses to pin
    -- such a frame to a texture. A plain frame with the plate's corners is allowed.
    -- Pinned to the SAME FRAMES as the plate, never to the plate: the client checks the whole chain (12 Nov, second
    -- BugSack - a frame SetAllPoints'd to the texture was refused the same way). Placed by RD.FitHull.
    RD.edgeFrame = CreateFrame("Frame", nil, f)
    RD.FitHull()
    RD.PaintHull()
    return RD.hull
end

--[[ THE ENGINEER'S CONSOLE (10 Nov 2026). Arn's cousin found the radar too big; Arn: "lets say we are an engineer on the
  death star, we open the radar console and it shows us the behind the scene. we just show empty squares top row party.
  next row dispels, next row interrupts, next row pets, next row everything else water water shield exp food all left
  and right rails bare bones empty squares all they do is the smart light up. 10 20 40 we dont just make bigger we just
  reimaging to acoomodate a bigger raid".
  THE SAME BUTTONS, PLACED ON A GRID. Nothing new lights anything: every pip, cure box, bogey, pet and tool is the very
  secure button the radar uses, with its own curve or boolean; the console only moves them (RD.ConsoleLayout, out of a
  fight, inside RD.Arm) and draws an empty square where each one lives (RD.conSquares, dim, always there - the
  behind-the-scenes look). The scope, the dark disc, the rails, the fuel tape and the black box step aside.
      row 1   party: the heal pips, you first
      row 2   dispels: each person's cure boxes, under them
      row 3   interrupts: the kick on each person's target (their bogey)
      row 4   pets
      row 5   everything else: stabilizer, Mana Tide, potion, Mana Spring, drink, rations, chaff, res
  THE VIEW BUTTON (Arn: "button ... on right rail"): at the right rail's foot on the radar, at the console's top-right
  corner in the console; one click switches, out of a fight (`radar.view` on the account). A party only for now: in a
  raid the radar stays (the 10 / 20 / 40 console is its own design, to come). ]]
-- a unit that is never a friend: an empty place and the radar's background name it, so the mouseover is nobody there
-- (an arena enemy, which does not exist outside an arena - and inside one the wheel's [nohelp] stops it all the same)
RD.EMPTY_UNIT = "arena5"
-- FROM THE CENTRE OUT (Arn, 11 Nov): place in a group of five -> its column, the first (you, in a party) in the middle
RD.CENTER_OUT = { 3, 2, 4, 1, 5 }
RD.CON = { pad = 8, colW = 39, ph = 18, sq = 26, cure = 12, pb = 18, pet = 18, gap = 6, toolGap = 2,
           head = 14 }                         -- a strip on top for the class and view buttons (Arn, 11 Nov: "clean it up")

--[[ THE CONSOLE'S SHIPS (11 Nov 2026, Arn: "start to reimagine the next step up in groups we are upgrading ships to the next
  class ending a spirit of star destroyer. let me click them even if i am not in that size party or raid, only go bigger
  5-10%" ... "build from the center out" ... "dont ahve to keep them in the same groups the companion is going to tell us
  who the best targets to keep in the center top 5 with me in the center, they can be in any group as long as they are
  the best target according to the brains, outer edges people that arent really taking any damage").
  Not a bigger copy: each class packs twice the crew into a hull only a little bigger, laid out IN RINGS - an odd grid,
  every place sorted by its distance from the middle (RD.ConsoleCells), the n nearest kept, so the hull fills from the
  centre out. WHO GOES WHERE IS A RANK, NOT A GROUP (RD.ConsoleOrder): you in the very middle, the top five round you,
  the quiet ones on the edge. The rank comes from THE BRAINS - the companion's reading of the combat log, written as
  `BiSBrains = { order = { "Name Surname", ... } }` into the private key addon on Arn's PC and read at a reload; until
  then you, the tanks, the healers, then everyone else. Interrupts and pets: the top five's, in a row each under the
  crew. Dispels: chips in each person's top corners. The tools row is the same in every ship; colours from RD.SHIPS.
      FIGHTER   5   one row: you in the middle, then dispels / interrupts / pets / tools rows (the first console)
      GUNSHIP  10   5 x 3 grid, the 10 nearest the middle
      CRUISER  20   7 x 3 grid, the 20 nearest
      CAPITAL  40   9 x 5 grid, the 40 nearest - the star destroyer
  The view button steps radar -> fighter -> gunship -> cruiser -> capital -> radar, in any group (a preview: the empty
  places are empty squares, on the edge); a group too big for a class skips it. ]]
RD.CON_TIERS = {
    { n = 5,  ship = 1, name = "PARTY" },
    -- TIDY (Arn, 11 Nov, three screenshots: "lets clean it up at least"): a full rectangle, one square size a class,
    -- the rank from the centre out within it; the bands told by brightness, not size
    { n = 10, ship = 2, name = "RAID 10", cols = 5, rows = 2, sq = 26, ph = 17, colW = 41, rowGap = 6, chip = 9, kick = 22, pet = 18 },
    { n = 20, ship = 3, name = "RAID 20", cols = 5, rows = 4, sq = 24, ph = 16, colW = 44, rowGap = 5, chip = 8, kick = 22, pet = 18 },
    { n = 40, ship = 4, name = "RAID 40", cols = 8, rows = 5, sq = 22, ph = 14, colW = 30, rowGap = 5, chip = 8, kick = 22, pet = 18 },
}

--[[ THE RADAR'S SHIPS (11 Nov 2026, Arn: "i want you to reimage the radar screen, for 10 20 40 we already have the 5 version
  very nice" - the console above is the engineer's view of the same classes). The fighter keeps the party radar. A bigger
  class is a FLEET round you, by rank (RD.ConsoleOrder - you, then the brains' order), drawn in rings:
      you      the star destroyer, in the middle (your cure above you, your target's bogey straight up at the rim)
      core     the next four on the inner ring, on the diagonals, full size, with cures and interrupts (bogeys at the
               rim, on the diagonals - the outer rings leave the diagonals clear for them)
      escorts  the middle ring, smaller, a cure beside each, no bogey
      screen   the outer ring, the smallest ("the ones that will have to be sacrificed to protect the carriers")
  The scope only grows 7-8% a class (300 / 320 / 345 / 370 - the old one-size raid radar was 440). Pets: the core's. ]]
RD.FLEET = {
    [10] = { size = 320, core = { rh = 56, rc = 86, rb = 140, ph = 24, pc = 13, pb = 20 },
             rings = { { n = 5, rh = 114, ph = 20, pc = 10, off = 36 } } },     -- due north left free for the main tank
    [20] = { size = 345, core = { rh = 56, rc = 84, rb = 158, ph = 24, pc = 13, pb = 20 },
             rings = { { n = 7, rh = 106, ph = 18, pc = 9, off = 360 / 14 }, { n = 8, rh = 142, ph = 15, pc = 8, off = 22.5 } } },
    [40] = { size = 370, core = { rh = 56, rc = 82, rb = 172, ph = 22, pc = 12, pb = 18 },
             rings = { { n = 11, rh = 104, ph = 17, pc = 9, off = 360 / 22 }, { n = 24, rh = 146, ph = 13, pc = 7, off = 7.5 } } },
}

--- Every place of a fleet, in rank order: you, the core four, then each ring from the top clockwise.
function RD.FleetPlaces(T)
    local F = RD.FLEET[T.n]
    if not F then return nil end
    local C, S = F.core, RD.SELF
    local P = { { b = 0, rh = 0, rc = S.rc, rb = C.rb, ph = C.ph + 4, pc = C.pc, pb = C.pb, own = true, self = true, band = "you" } }
    for j = 1, 4 do
        P[#P + 1] = { b = math.pi / 4 + (j - 1) * math.pi / 2, rh = C.rh, rc = C.rc, rb = C.rb, ph = C.ph, pc = C.pc,
                      pb = C.pb, own = true, band = "core" }
    end
    for r, R in ipairs(F.rings) do
        for j = 1, R.n do
            P[#P + 1] = { b = math.rad(R.off) + (j - 1) * 2 * math.pi / R.n, rh = R.rh, rc = R.rh + R.ph / 2 + R.pc / 2 + 3,
                          ph = R.ph, pc = R.pc, own = false, band = (r == #F.rings and #F.rings > 1) and "screen" or "escort" }
        end
    end
    return P
end

--- The fleet's slots for these units: slot i (unit i) gets the place of its rank. Answers slots, the scope's size, rim.
function RD.FleetGeometry(T, order)
    local P = RD.FleetPlaces(T)
    local F = RD.FLEET[T.n]
    local slots = {}
    for k, i in ipairs(order) do
        local p = P[k]
        if p then
            local s = {}
            for key, v in pairs(p) do s[key] = v end
            s.group, s.pos, s.rank = math.ceil(i / 5), (i - 1) % 5 + 1, k
            slots[i] = s
        end
    end
    return slots, F.size, F.size / 2 - 4
end

--[[ THE FLEET MADE VISIBLE (11 Nov 2026, Arn: "yes do both", to: faint seats out of a fight, and rings where the ships sit).
  RINGS: a class bigger than the fighter hides the party's inner rings and draws its own - the core's ring and each of
  its rings, at the radius its ships sit on (RD.DrawRings), in the ship's line like the rest of the scope; the rim, cross
  and ticks stay. They stay in a fight, like the scope. SEATS: every place a faint dot out of a fight (RD.PaintSeats),
  so the fleet's shape shows on a quiet radar; gone in a fight (RD.PaintQuiet), gone in the engineer's view. ]]
RD.SEAT_ALPHA = 0.45
function RD.DrawRings(T)
    local f = RD.frame
    if not f then return end
    local F = T and RD.FLEET[T.n]
    local fleet = F and not RD.Console()
    for _, l in ipairs(RD.innerRings or {}) do if fleet then l:Hide() else l:Show() end end
    RD.ringFrame = RD.ringFrame or CreateFrame("Frame", nil, f)
    local rf = RD.ringFrame
    rf:SetAllPoints(f)
    rf:SetFrameLevel(math.max(0, f:GetFrameLevel()))
    RD.fleetLines = RD.fleetLines or {}
    for _, l in ipairs(RD.fleetLines) do l:Hide() end
    if not fleet then rf:Hide() return end
    rf:Show()
    local radii = { F.core.rh }
    for _, R in ipairs(F.rings) do radii[#radii + 1] = R.rh end
    local L, k = (RD.ship and RD.ship.line) or RD.PHOS, RD.SCOPE_DIM
    local col = { L[1] * k, L[2] * k, L[3] * k, 0.85 }
    local n = 0
    for _, r in ipairs(radii) do
        for j = 1, RD.RING_SEG do
            n = n + 1
            local a0, a1 = (j - 1) * 2 * math.pi / RD.RING_SEG, j * 2 * math.pi / RD.RING_SEG
            local l = RD.fleetLines[n]
            if not l then
                l = line(rf, "BORDER", 0, 0, 0, 0, col, 1)
                RD.fleetLines[n] = l
            end
            l:SetStartPoint("CENTER", rf, math.sin(a0) * r, math.cos(a0) * r)
            l:SetEndPoint("CENTER", rf, math.sin(a1) * r, math.cos(a1) * r)
            l:SetVertexColor(col[1], col[2], col[3], col[4])
            l:Show()
        end
    end
    RD.fleetRadii = radii
end

--- A faint dot at every place, out of a fight: the fleet's shape on a quiet radar.
function RD.PaintSeats(slots)
    local f = RD.frame
    if not f then return end
    RD.seatFrame = RD.seatFrame or CreateFrame("Frame", nil, f)
    local sf = RD.seatFrame
    sf:SetAllPoints(f)
    sf:SetFrameLevel(math.max(0, f:GetFrameLevel()))
    RD.seats = RD.seats or {}
    local L = (RD.ship and RD.ship.line) or RD.PHOS
    local n = 0
    if not RD.Console() then
        for _, s in ipairs(slots or {}) do
            n = n + 1
            local t = RD.seats[n]
            if not t then
                t = sf:CreateTexture(nil, "BORDER")
                t:SetTexture(RD.ART .. "disc")
                RD.seats[n] = t
            end
            local px = math.max(4, math.floor((s.ph or 20) * 0.3 + 0.5))
            t:SetSize(px, px)
            t:ClearAllPoints()
            t:SetPoint("CENTER", f, "CENTER", RD.Point(s, s.rh))
            t:SetVertexColor(L[1], L[2], L[3], RD.SEAT_ALPHA)
            t:Show()
        end
    end
    for j = n + 1, #RD.seats do RD.seats[j]:Hide() end
    -- THE TANK'S SEAT (Arn, 11 Nov: "the faint dots should reflect that" - the tank always straight above you): with no
    -- tank in the group, a faint dot of its own due north on the inner ring, where one will sit. A main tank there has
    -- its own dot, so this one steps aside.
    local inner
    for _, s in ipairs(slots or {}) do
        if not s.self and (s.rh or 0) > 0 and (not inner or s.rh < inner.rh) then inner = s end
    end
    local ts = RD.tankSeat
    if not ts then
        ts = sf:CreateTexture(nil, "BORDER")
        ts:SetTexture(RD.ART .. "disc")
        RD.tankSeat = ts
    end
    if inner and not RD.mainTank and not RD.Console() then
        local px = math.max(4, math.floor((inner.ph or 20) * 0.3 + 0.5))
        ts:SetSize(px, px)
        ts:ClearAllPoints()
        ts:SetPoint("CENTER", f, "CENTER", 0, inner.rh)
        ts:SetVertexColor(L[1], L[2], L[3], RD.SEAT_ALPHA)
        ts:Show()
    else
        ts:Hide()
    end
    sf:SetAlpha((RD.inFight or combat()) and 0 or 1)
end

--- The console is in use (any group: a class that holds everyone is picked, RD.ConsoleTier). THE FLIGHT DECK is a console
--- too (15 Nov 2026, Arn: "this is going to replace radar and engineer is going to be this new deck but barebones"): the
--- engineer's boxes - health bars, kick squares, cure chips, the fuel strip, the tools and totems - laid out as the deck.
function RD.Deck() return (NS.FG and NS.FG.DeckOn and NS.FG.DeckOn()) == true end
function RD.Console() return db().view == "console" or RD.Deck() end
--- The view button picked the engineer's view (the deck is the radar look's own view otherwise).
function RD.EngineerView() return db().view == "console" end
--- The retired radar disc, reachable only by the suite (`RD.FORCE_DISC`, never set in the game), so its code stays tested
--- until it is deleted.
RD.FORCE_DISC = false
function RD.DiscView() return RD.FORCE_DISC == true end
--- The engineer's view: the deck, condensed (RD.DECK_SMALL) - narrower, taller boxes, short totem timers.
function RD.Compact() return RD.EngineerView() and RD.Deck() end
--- The deck's sizes for the view on screen.
function RD.DeckM() return RD.Compact() and RD.DECK_SMALL or RD.DECK end

--[[ THE SWITCHES (16 Nov 2026, Arn: "maybe we just do toggles with everything off its the quasi engineer look and deck would
  be with everything on names flavor etc" - "that unifies them, no more deck and engineer, just deck now"; sketch
  https://claude.ai/artifact/NyfWTe1b5MEJRmF1qFcGE7, Arn: "works amazing"). One window; each part of it a switch, saved per
  character (db().sw[key] = true / false; nil = on, so nobody's deck changes until they switch something). The health
  boxes always stay. A switch that adds or takes away click buttons is laid out by RD.Arm, out of a fight only - in one it
  waits for the fight's end (RD.pending), like every other secure change. ]]
RD.SW = {
    { key = "names",  group = "LOOK",      name = "Names",                    tip = "The name on each box." },
    { key = "edges",  group = "LOOK",      name = "Warning edges",            tip = "A box's edge turns amber when low, red when very low." },
    { key = "pets",   group = "LOOK",      name = "Pets",                     tip = "Hunter and warlock pets get a small box with a paw." },
    { key = "attn",   group = "LOOK",      name = "Attention outlines",       tip = "A red box on an icon you need to click now (food, a buff, a mana tool), amber when it is getting close." },
    { key = "head",   group = "LOOK",      name = "Name header",              tip = "The name and the buff / debuff icons in a dark strip at the top of each box, off the health bar (a short raid box keeps its whole height for the bar)." },
    { key = "bb",     group = "LOOK",      name = "Black box",                tip = "The red light and the keypad under the window." },
    -- RAID GROUPS (21 Nov 2026, BiS Cues sheet 6, Arn picked B + its own switch). OFF until switched on (`off`, see RD.Sw),
    -- and left alone by the presets and RESET's "everything on" - they change where boxes stand, not what a box shows.
    -- The sort switch (one setting that cycles) has its own row under these (RD.SORTS).
    { key = "gtag",   group = "LAYOUT",    name = "Group tags",               off = true, layout = true,
      tip = "In a raid: a small G2 in the corner of each box - that person's raid group. The first thing to go when the boxes get small." },
    { key = "cols",   group = "LAYOUT",    name = "Groups as columns",        off = true, layout = true,
      tip = "In a raid: each group stands top to bottom, the groups side by side. Off: each group is a row. The window's width decides how many groups fit side by side." },
    { key = "target", group = "THE FIGHT", name = "Target + its target",      tip = "Your target and who it is hitting, in the top row." },
    { key = "kicks",  group = "THE FIGHT", name = "Kick buttons",             tip = "Your interrupt on a box when their target casts." },
    { key = "cures",  group = "THE FIGHT", name = "Cure chips",               tip = "A chip when they carry something you can remove." },
    { key = "cast",   group = "THE FIGHT", name = "Mini cast bars",           tip = "A red line under whoever a caster targets; grey when you cannot kick it." },
    { key = "alerts", group = "THE FIGHT", name = "LOS / RANGE / OVER boxes", tip = "Three boxes on top for a failed heal or a big overheal. Off: the word shows on the box itself." },
    { key = "cc",     group = "THE FIGHT", name = "Loss of control box",      tip = "A fourth box on top: how long you are stunned, silenced, feared or locked out of a school, counting down." },
    { key = "fuel",   group = "MANA",      name = "Mana vs boss",             tip = "Above the window: your mana against the boss's health - the boss's red past your mana means you run dry first; the hot band = drink soon at this pace; the small % at the end is your regen." },
    { key = "tools",  group = "MANA",      name = "Tools row",                tip = "Mana Tide, potion, Mana Spring, drink, rations, Grounding." },
    { key = "mana",   group = "MANA",      name = "Party mana",               tip = "In the Mana vs boss strip: a bar per mana user in your group, shown once they drop under half - and Mana Tide lights up when all of them have." },
    { key = "totems", group = "SHAMAN",    name = "Totem buttons",            tip = "CALL, BRING, RECALL." },
    { key = "timers", group = "SHAMAN",    name = "Totem timers",             tip = "Air, water, earth, fire. Click one to drop it again." },
    { key = "bounce", group = "SHAMAN",    name = "Chain Heal path",          tip = "After your Chain Heal, a bolt across the boxes it landed on: gold for 3, amber for 2, a red flash for 1. A star on each crit." },
    { key = "bsound", group = "SHAMAN",    name = "Chain Heal sounds",        tip = "A fanfare when all 3 bounces crit, a buzzer when it healed only one (mana wasted)." },
    { key = "rip",    group = "SHAMAN",    name = "Riptide + synergy bar",    tip = "A Riptide mark on whoever has yours, and the synergy bar on top: how many of YOUR Chain Heals (your cast time and lag) still land before it runs out; the Riptide icon lights when the next one would be too late." },
    { key = "oath",   group = "PALADIN",   name = "Oath of Light cue",        tip = "Holy Light in the middle of the box of whoever carries your Oath of Light: your heals land harder there." },
    { key = "vigil",  group = "PALADIN",   name = "Light's Vigil + synergy",  tip = "Holy Shock in the middle of the box of whoever carries your Light's Vigil (that Holy Shock skips its cooldown and splashes their party), and the synergy bar on top counting its 30 s down." },
    { key = "swift",  group = "DRUID",     name = "Swiftmend + synergy",      tip = "Swiftmend in the middle of the box of whoever carries your Rejuvenation or Regrowth while it is ready, and the synergy bar on top: your newest one's time left." },
    -- 20 Nov 2026 (Arn: "remember all these are toggles"): the warlock's Hellfire and Life Tap (Burn.lua), Revelation (Reveal.lua)
    { key = "hell",   group = "YOUR GROUP", name = "Hellfire box",            tip = "A warlock's box catches fire while he channels Hellfire (it burns him every second). The game draws it, even in a fight." },
    { key = "hellvoice", group = "YOUR GROUP", name = "Hellfire voice",       tip = "Your PC's voice says \"Hellfire\" when a warlock's box catches fire. At most once every 12 s a warlock." },
    { key = "tap",    group = "YOUR GROUP", name = "Life Tap tag",            tip = "TAP in amber under a warlock's name for 3 s after he trades health for mana. Only when the game shows his cast (often not in a fight)." },
    { key = "crit",   group = "EXTRAS",    name = "Revelation CRIT",          tip = "The Revelation weapon enchant's proc: a gold CRIT on the synergy bar while your next spell will crit. The game draws it, even in a fight." },
}
RD.SW_PRESETS = {
    full = { names = true, head = true, edges = true, pets = true, attn = true, target = true, kicks = true, cures = true, cast = true, alerts = true, cc = true,
             fuel = true, tools = true, totems = true, timers = true, bb = true, rip = true, mana = true, bounce = true, bsound = true,
             oath = true, vigil = true, swift = true, hell = true, hellvoice = true, tap = true, crit = true },
    bare = {},
    lean = { names = true, head = true, target = true, kicks = true, cures = true, totems = true, timers = true },   -- the engineer's fans
}
RD.SW_ORDER = { "bare", "lean", "full" }
RD.SW_WORD = { bare = "BARE", lean = "LEAN", full = "FULL" }
-- THE SWITCHES THAT START OFF (21 Nov 2026): every other switch reads nil as ON (nobody's deck changed when the switches
-- came, 16 Nov). The raid-group tag and groups-as-columns are new parts of the layout nobody asked for yet, so nil must
-- read as OFF for them - a player who touches nothing keeps today's deck.
RD.SW_OFF = {}
for _, s in ipairs(RD.SW) do if s.off then RD.SW_OFF[s.key] = true end end
function RD.Sw(key)
    local t = db().sw
    if type(t) ~= "table" or t[key] == nil then return not RD.SW_OFF[key] end
    return t[key] == true
end
--- The icon row under each box's bar: while kicks or cures are on.
function RD.SwIcons() return RD.Sw("kicks") or RD.Sw("cures") end
--- Which preset the switches match now; nil = your own mix.
function RD.SwPresetNow()
    for _, name in ipairs(RD.SW_ORDER) do
        local p, same = RD.SW_PRESETS[name], true
        for _, s in ipairs(RD.SW) do if not s.layout and (p[s.key] == true) ~= RD.Sw(s.key) then same = false end end
        if same then return name end
    end
    return nil
end
--- Lay the window out again for the switches: now, or after the fight. Answers "now" or "after".
function RD.SwApply()
    if RD.PaintSwitches then RD.PaintSwitches() end
    if combat() or RD.inFight then RD.pending = true return "after" end
    if RD.Active() then RD.Arm() end
    if RD.PaintSwitches then RD.PaintSwitches() end
    return "now"
end
function RD.SetSw(key, on)
    local known
    for _, s in ipairs(RD.SW) do if s.key == key then known = true end end
    if not known then return nil end
    local d = db()
    d.sw = type(d.sw) == "table" and d.sw or {}
    d.sw[key] = on and true or false
    return RD.SwApply()
end
function RD.SwPreset(name)
    local p = RD.SW_PRESETS[name]
    if not p then return nil end
    local t, old = {}, db().sw
    for _, s in ipairs(RD.SW) do
        if s.layout then t[s.key] = type(old) == "table" and old[s.key] or nil   -- the layout keeps what it was
        else t[s.key] = p[s.key] == true end
    end
    db().sw = t
    return RD.SwApply()
end

--[[ THE SORT (21 Nov 2026, BiS Cues sheet 6: "one switch"): who stands where. Decided in RD.Arm - out of a fight only - and
  so FROZEN for the whole fight: a death never reshuffles a box. Saved per character as db().deckSort (nil = "tanks").
    tanks  the tanks lifted into the top row, then everyone by raid group (today's deck, the default)
    group  nobody lifted, everyone by raid group
    class  by class (the order of RD.CLASS_ORDER), then group; in a raid the groups scatter (the G2 tag still says)
    maxhp  the biggest max health first, read plain out of a fight; who cannot be read goes after, by group ]]
RD.SORTS = { "tanks", "group", "class", "maxhp" }
RD.SORT_WORD = { tanks = "Tanks, then groups", group = "By group", class = "By class", maxhp = "By max health" }
RD.CLASS_ORDER = { WARRIOR = 1, PALADIN = 2, DRUID = 3, SHAMAN = 4, PRIEST = 5, ROGUE = 6, HUNTER = 7, MAGE = 8, WARLOCK = 9 }
function RD.DeckSort()
    local v = db().deckSort
    return RD.SORT_WORD[v] and v or "tanks"
end
function RD.SetDeckSort(v)
    if not RD.SORT_WORD[v] then return nil end
    db().deckSort = (v ~= "tanks") and v or nil
    return RD.SwApply()
end
--- The sort row's click: the next sort, round and round.
function RD.NextSort()
    local cur, nxt = RD.DeckSort(), RD.SORTS[1]
    for k, v in ipairs(RD.SORTS) do if v == cur then nxt = RD.SORTS[k % #RD.SORTS + 1] end end
    return RD.SetDeckSort(nxt), nxt
end
--- Sheet 6's three settings as one table (the BiS Cues string's `raid` part): { gtag, sort, cols }.
function RD.RaidSettings()
    return { gtag = RD.Sw("gtag"), sort = RD.DeckSort(), cols = RD.Sw("cols") }
end
--- ...and back. Unknown keys and values are ignored. Laid out now, or after the fight ("now" / "after").
function RD.SetRaidSettings(t)
    if type(t) ~= "table" then return nil end
    local d = db()
    d.sw = type(d.sw) == "table" and d.sw or {}
    if type(t.gtag) == "boolean" then d.sw.gtag = t.gtag end
    if type(t.cols) == "boolean" then d.sw.cols = t.cols end
    if RD.SORT_WORD[t.sort] then d.deckSort = (t.sort ~= "tanks") and t.sort or nil end
    return RD.SwApply()
end
--- Once per character: whoever used the engineer's view starts LEAN; the view itself is retired (one window now).
function RD.SwStamp()
    local d = db()
    if d.swStamp then return false end
    d.swStamp = 1
    if d.view == "console" and d.sw == nil then
        local t = {}
        for _, s in ipairs(RD.SW) do t[s.key] = RD.SW_PRESETS.lean[s.key] == true end
        d.sw = t
    end
    d.view = nil
    return true
end
--- A box's sizes with the icon row taken out while kicks and cures are both off (the lean look: the bar is the box).
--- BOX HEIGHT (16 Nov 2026, Arn: "maybe we also put the sliders there for width and height"): the bar's part of every box
--- taller or shorter, RD.BOX_H_MIN .. RD.BOX_H_MAX %, saved per character (db().boxH; nil = 100). The icon row keeps its size.
RD.BOX_H_MIN, RD.BOX_H_MAX, RD.BOX_H_STEP = 50, 200, 5
function RD.BoxHeight()
    local v = tonumber(db().boxH)
    if not v then return 100 end
    return math.max(RD.BOX_H_MIN, math.min(RD.BOX_H_MAX, math.floor(v + 0.5)))
end
function RD.SetBoxHeight(v)
    v = tonumber(v)
    db().boxH = (v and v ~= 100) and math.max(RD.BOX_H_MIN, math.min(RD.BOX_H_MAX, math.floor(v + 0.5))) or nil
end
function RD.DeckSized(M)
    local icons, hk = RD.SwIcons(), RD.BoxHeight()
    if icons and hk == 100 then return M end
    RD.deckSized = RD.deckSized or {}
    local key = tostring(M) .. (icons and "i" or "n") .. hk
    local L = RD.deckSized[key]
    if not L then
        L = {}
        for k, v in pairs(M) do L[k] = v end
        local ic = icons and M.icons or 0
        local function bar(h) return math.max(12, math.floor((h - M.icons) * hk / 100 + 0.5)) + ic end
        L.row, L.tank, L.icons = bar(M.row), bar(M.tank), ic
        RD.deckSized[key] = L
    end
    return L
end
--- The strip on top: the alert boxes' height, or just room for the switches button.
RD.DECK_HEAD_BARE = 16
function RD.DeckHead()
    local syn = NS.EN and NS.EN.SynergyKnown and NS.EN.SynergyKnown()
    return (RD.Sw("alerts") or RD.Sw("cc") or syn) and RD.DECK_HEAD or RD.DECK_HEAD_BARE
end

--- The window's width at which the totem row fits on ONE line: CALL / BRING / RECALL in the middle, two timers each side.
function RD.TotemWideW()
    local C = RD.CON
    return 2 * (C.pad + 4 + 2 * RD.TIMER_MIN + C.toolGap) + 3 * RD.SYS_PX + 2 * C.toolGap
end
--- The narrowest the boxes' area may be (16 Nov 2026, Arn: "the side by side view i gave you with ellesmere was about the
--- size he likes ... we gotta be able to go down to that size even if it means we stack the totem timers"): Ellesmere's
--- party frames, about 130 px; under RD.TotemWideW the totems stack, the tools wrap, the top row splits.
RD.NARROW_INNER = 118
function RD.FloorInner() return RD.NARROW_INNER end
--- The width the player dragged this view to (Shift + the corner grip), never under the floor; nil = the view's own.
function RD.DeckWidth()
    local t = db().deckW
    local w = type(t) == "table" and tonumber(t[RD.Compact() and "eng" or "deck"]) or nil
    if not w then return nil end
    return math.max(RD.FloorInner(), math.floor(w + 0.5))
end
function RD.SetDeckWidth(w)
    local d = db()
    d.deckW = type(d.deckW) == "table" and d.deckW or {}
    d.deckW[RD.Compact() and "eng" or "deck"] = w and math.max(RD.FloorInner(), math.floor(w + 0.5)) or nil
end

--- The console's class: the one chosen, or the smallest that holds everyone in `units` (a raid's slot is its group and
--- place, so the highest slot says how many must fit). Answers the class and its number.
function RD.ConsoleTier(units)
    local hi = 0
    for i in pairs(units or RD.units or {}) do if type(i) == "number" and i > hi then hi = i end end
    local need = #RD.CON_TIERS
    for k, t in ipairs(RD.CON_TIERS) do if hi <= t.n then need = k break end end
    -- THE GROUP DECIDES (Arn, 15 Nov: "5 man 10 man 20man 40 man rules to apply automatically ... we can get rid of the
    -- button"): a picked size counts only behind the retired disc's suite door
    local picked = RD.FORCE_DISC and tonumber(db().tier) or 1
    local k = math.min(#RD.CON_TIERS, math.max(picked, need))
    return RD.CON_TIERS[k], k
end

--[[ THE FLEET'S ORDERS (11 Nov 2026). Arn: "think of youself of a rear admiral of the imperial navy you communications are
  up and you know where to place your navy, now they take out your communicatiion ship and you have to figure out how to
  order you ships, you will still have your tanks close to screen you, and you most capable figters around while keeping
  you medical frigates close, the other layers are small agile ships that can handle their own ... once you communication
  figate come online you can use the data to order them around".
  WITH THE COMMUNICATIONS FRIGATE (the companion's brains, `BiSBrains`, private on Arn's PC: _bisdev/companion/
  brains.py): its order - who takes the damage, the spikes, the close calls - matched by the player's GUID (what the log
  names them by), else by "Name Surname". WITHOUT IT, or for anyone it does not know: by logic (RD.LogicBand) -
      tank     close, screening you                    1
      melee    the interceptors, with the tanks         2   (Arn: "melee dps classes near by too because they are
               clumped up for aoe heals, they are the inteceptors of the tanks" - warriors, rogues, paladins)
      ranged   the agile ships that handle their own    3   (everyone else: they stand back)
      heal     the medical frigates, furthest out       4   (Arn: "melee closer healers further away, in a battle
               medical figates stay far away enough to not take font damage, and come in only when needed or the data
               supports it" - the brains bring a healer in when the log says they are taking it)
  You are always the middle. Empty places last (the edge). ]]
RD.MELEE = { WARRIOR = true, ROGUE = true, PALADIN = true }
RD.BAND_ORDER = { tank = 1, melee = 2, ranged = 3, heal = 4 }

--- "Holy-Haven-PvP-US" (the log's) -> "Holy Haven" (GetUnitName's on Forever): the forename and surname.
function RD.BrainsName(s)
    if type(s) ~= "string" then return nil end
    local a, b = s:match("^([^%-]+)%-([^%-]+)")
    if a then return a .. " " .. b end
    return s
end

--- THE BRAINS' RANK: key -> place (1 = watch first), keyed by GUID and by "Name Surname". nil without the brains.
function RD.BrainsRank()
    local b = _G.BiSBrains
    if type(b) ~= "table" or type(b.order) ~= "table" then return nil end
    local out, names = {}, type(b.names) == "table" and b.names or {}
    for k, key in ipairs(b.order) do
        if type(key) == "string" then
            if not out[key] then out[key] = k end
            local nm = RD.BrainsName(names[key] or (not key:find("^Player%-") and key) or nil)
            if nm and not out[nm] then out[nm] = k end
        end
    end
    return next(out) and out or nil
end

--- The band a unit flies in without the brains: tank, heal, melee or ranged.
function RD.LogicBand(u)
    local role = RD.Role(u)
    if role == "tank" or role == "heal" then return role end
    local ok, _, class = pcall(UnitClass, u)
    class = ok and plain(class) or nil
    return (class and RD.MELEE[class]) and "melee" or "ranged"
end

--- This unit's place in the brains, by GUID first, then by name; nil when the brains do not know them.
local function brainsOf(brains, u)
    local okG, guid = pcall(UnitGUID, u)
    guid = okG and plain(guid) or nil
    if type(guid) == "string" and brains[guid] then return brains[guid] end
    local okN, name = pcall(GetUnitName, u, false)
    name = okN and plain(name) or nil
    return type(name) == "string" and brains[name] or nil
end

--- Who goes where: the slot numbers (into `units` and RD.spokes) in rank order - you first, then the brains' order, then
--- anyone it does not know by logic (tank, heal, melee, ranged), the empty slots last (the edge). Out of a fight.
function RD.ConsoleOrder(units, n)
    local present, empty, rank = {}, {}, {}
    local brains = RD.BrainsRank()
    for i = 1, n do
        local u = units and units[i]
        if u then present[#present + 1] = i else empty[#empty + 1] = i end
    end
    for _, i in ipairs(present) do
        local u = units[i]
        local okMe, me = false, nil
        if u == "player" then okMe, me = true, true
        elseif UnitIsUnit then okMe, me = pcall(UnitIsUnit, u, "player") end   -- a raid names you "raidN"
        if okMe and plain(me) == true then
            rank[i] = 0
        else
            local b = brains and brainsOf(brains, u)
            local logic = (RD.BAND_ORDER[RD.LogicBand(u)] or 4) * 100 + i
            rank[i] = b and b or (1000 + logic)
        end
    end
    table.sort(present, function(a, b) return rank[a] < rank[b] end)
    for _, i in ipairs(empty) do present[#present + 1] = i end
    return present
end

--[[ TANKS NORTH (11 Nov 2026, Arn - a standing rule: "only things I want to be consistent is keep tank north of us, can be
  spread but in the top half of the quadrant"). On the radar, every class: a tank whose place is not in the top half
  (north of you: cos(bearing) > 0) trades places with the nearest top-half place that holds no tank - an empty one, or
  the closest to the middle. The rank still decides everyone else; only the tanks are pinned north. ]]
local function north(s) return s and not s.self and (s.rh or 0) > 0 and math.cos(s.b or 0) > 0.01 end

--[[ NOBODY NAMED THE TANK (11 Nov 2026, Arn: "the tank is not north of me"). On Forever a group made by hand has no
  roles: the game names no tank, so the rule above had nobody to move. When neither the game, BiS> now's tank nor a main
  tank assignment names one, ONE is guessed from the classes that can tank: the one the brains say takes the most, else
  a warrior, then a paladin, then a druid (the first in the group). You are never the guess. Answers the slot or nil. ]]
RD.TANK_GUESS = { WARRIOR = 1, PALADIN = 2, DRUID = 3 }
function RD.GuessTank(slots, units)
    local brains = RD.BrainsRank()
    local best, bestKey
    for i in pairs(slots) do
        local u = units[i]
        if u and u ~= "player" then
            local okMe, me = false, nil
            if UnitIsUnit then okMe, me = pcall(UnitIsUnit, u, "player") end
            local ok, _, class = pcall(UnitClass, u)
            class = ok and plain(class) or nil
            local c = class and RD.TANK_GUESS[class]
            if c and not (okMe and plain(me) == true) then
                local b = brains and brainsOf(brains, u) or 999
                local key = b * 100 + c * 10                -- the brains first, then the class
                if not bestKey or key < bestKey or (key == bestKey and i < best) then best, bestKey = i, key end
            end
        end
    end
    return best
end

function RD.TanksNorth(slots, units)
    if type(slots) ~= "table" or type(units) ~= "table" then return 0 end
    local isTank = {}
    for i in pairs(slots) do
        local u = units[i]
        if u and u ~= "player" then
            local okMe, me = false, nil
            if UnitIsUnit then okMe, me = pcall(UnitIsUnit, u, "player") end
            if not (okMe and plain(me) == true) and RD.LogicBand(u) == "tank" then isTank[i] = true end
        end
    end
    RD.tankGuessed = nil
    if not next(isTank) then
        local g = RD.GuessTank(slots, units)
        if g then isTank[g], RD.tankGuessed = true, g end
    end
    local moved = 0
    for i, s in pairs(slots) do
        if isTank[i] and not north(s) then
            local best
            for j, t in pairs(slots) do
                if not isTank[j] and north(t) then
                    -- the nearest to the middle; then an empty place over someone's; then the lowest rank
                    local key = { t.rh, units[j] and 1 or 0, t.rank or j }
                    if not best or key[1] < best[2][1] or (key[1] == best[2][1] and (key[2] < best[2][2]
                       or (key[2] == best[2][2] and key[3] < best[2][3]))) then
                        best = { j, key }
                    end
                end
            end
            if best then
                local j = best[1]
                slots[i], slots[j] = slots[j], slots[i]
                moved = moved + 1
            end
        end
    end
    -- THE MAIN TANK DIRECTLY ON TOP (Arn, 11 Nov: "Main tank taking the most damage always directly on top of us"): the
    -- first tank in the fleet's order - the brains' (who takes the most) when online, else the game's main tank / BiS> now's
    -- tank / the first tank - sits due north on its own ring. Your own target's bogey (which sat due north at the rim)
    -- steps to your left with your cure, so the two never sit on each other.
    local order = RD.ConsoleOrder(units, #slots)
    local mt
    for _, i in ipairs(order) do if isTank[i] then mt = i break end end
    RD.mainTank = mt
    if mt and slots[mt] then
        local s = {}
        for k, v in pairs(slots[mt]) do s[k] = v end
        s.b = 0
        slots[mt] = s
        for i, t in pairs(slots) do
            if t.self then
                local me = {}
                for k, v in pairs(t) do me[k] = v end
                me.b, me.rc, me.rb = RD.SELF_ASIDE.b, RD.SELF_ASIDE.rc, RD.SELF_ASIDE.rb
                slots[i] = me
            end
        end
    end
    return moved
end
RD.SELF_ASIDE = { b = -math.pi / 2, rc = 26, rb = 50 }    -- your cure and your target's bogey, to your left

--- `/bish alpha radar brains`: what the fleet is ordered by now.
function RD.BrainsSay(P)
    local b = _G.BiSBrains
    if type(b) == "table" and type(b.order) == "table" and #b.order > 0 then
        local names = {}
        for k = 1, math.min(8, #b.order) do
            local key = b.order[k]
            names[#names + 1] = RD.BrainsName((type(b.names) == "table" and b.names[key]) or key) or "?"
        end
        local age = (time and type(b.at) == "number") and math.floor((time() - b.at) / 60) or nil
        P("radar brains: |cff5dff9bonline|r - %d fight%s read%s.  Most watched: %s", tonumber(b.fights) or 0,
          b.fights == 1 and "" or "s", age and (", " .. age .. " min ago") or "", table.concat(names, ", "))
    else
        P("radar brains: |cffffb340offline|r - ordering by logic: you, tanks, melee, ranged, then the healers out of the front line")
    end
end

--- Every slot of a class: the fighter's own (RD.ConsoleSlot), else small ones. `top` = the slots that carry an interrupt
--- and a pet (the top five of the rank).
function RD.ConsoleSlots(T, top, rankOf)
    local out = {}
    top, rankOf = top or {}, rankOf or {}
    for i = 1, T.n do
        if T.n == 5 then
            out[i] = RD.ConsoleSlot(i)
        else
            local mine = top[i] == true
            local z = 1                              -- one size a class (the bands are told by brightness)
            out[i] = { b = 0, rh = 0, rc = 0, rb = mine and 0 or nil, ph = math.floor(T.ph * z + 0.5), pc = math.max(2, T.chip - 4),
                       pb = T.kick * 0.8, own = mine, group = math.ceil(i / 5), pos = (i - 1) % 5 + 1, console = true,
                       scale = z }
        end
    end
    return out
end

--- THE FLEET'S SHAPE (Arn, 11 Nov: "we are the star destroyer, our best ships are around us ... like how herds keep the
--- vulnerable in the middle, out in the outer edges are the screen ships smaller ships that dont take much damage"):
--- the size of the k-th in rank - the core five full size, the escorts a little smaller, the outer screen the smallest.
RD.SHIP_SIZES = { core = 1, escort = 0.85, screen = 0.72 }
function RD.ShipScale(k, n)
    if k <= 5 then return RD.SHIP_SIZES.core end
    if k <= math.ceil(n * 2 / 3) then return RD.SHIP_SIZES.escort end
    return RD.SHIP_SIZES.screen
end

--- The slot a spoke gets in the fighter: drawn small (its glyph fits its square), placed by RD.ConsoleLayout.
function RD.ConsoleSlot(i)
    local C = RD.CON
    return { b = 0, rh = 0, rc = 0, rb = 0, ph = C.ph, pc = C.cure, pb = C.pb, own = true, group = 1, pos = i,
             self = (i == 1) or nil, console = true }
end

--- The fighter's grid: column centres, row centres, the size. Every place is (x, -y) from the radar frame's top-left.
function RD.ConsoleGrid()
    local C = RD.CON
    local W = C.pad * 2 + C.colW * RD.SPOKES
    local y1 = C.pad + C.head + C.sq / 2
    local y2 = y1 + C.sq / 2 + C.gap + (C.cure + 4) / 2
    local y3 = y2 + (C.cure + 4) / 2 + C.gap + C.sq / 2
    local y4 = y3 + C.sq / 2 + C.gap + C.sq / 2
    local y5 = y4 + C.sq / 2 + C.gap + RD.SYS_PX / 2
    local H = y5 + RD.SYS_PX / 2 + C.pad
    local cols = {}
    for i = 1, RD.SPOKES do cols[i] = C.pad + C.colW * (i - 0.5) end
    return { W = W, H = H, cols = cols, rows = { y1, y2, y3, y4, y5 } }
end

--- A bigger class's places: an odd grid, sorted nearest the middle first (in pixels), the n nearest kept. Answers the
--- places {x, y}, the crew block's size.
function RD.ConsoleCells(T, x0)
    local C = RD.CON
    local pitch = T.sq + T.rowGap
    local midC, midR = (T.cols + 1) / 2, (T.rows + 1) / 2
    local cells = {}
    for r = 1, T.rows do
        for c = 1, T.cols do
            local dx, dy = (c - midC) * T.colW, (r - midR) * pitch
            cells[#cells + 1] = { x = x0 + T.colW * (c - 0.5), y = C.pad + C.head + T.sq / 2 + (r - 1) * pitch, d = dx * dx + dy * dy,
                                  r = r, c = c }
        end
    end
    table.sort(cells, function(a, b)
        if a.d ~= b.d then return a.d < b.d end
        if a.r ~= b.r then return a.r < b.r end
        return a.c < b.c
    end)
    local out = {}
    for k = 1, T.n do out[k] = cells[k] end
    return out, T.cols * T.colW, T.rows * T.sq + (T.rows - 1) * T.rowGap
end

-- an empty square: four thin edges in the dim phosphor, on the console's own layer
local function square(key, px, col)
    RD.conSquares = RD.conSquares or {}
    local q = RD.conSquares[key]
    if not q then
        q = CreateFrame("Frame", nil, RD.conLayer)
        q.edges = edge(q, RD.DIM, 1)
        RD.conSquares[key] = q
    end
    col = col or RD.DIM
    if q.col ~= col then
        for _, e in ipairs(q.edges) do e:SetVertexColor(col[1], col[2], col[3], col[4] or 1) end
        q.col = col
    end
    q:SetSize(px, px)
    q:Show()
    return q
end

-- THE BANDS BY BRIGHTNESS: the core five bright, the escorts the usual dim, the outer screen fainter
RD.BAND_COL = { core = { 0.22, 1.00, 0.53, 0.75 }, escort = RD.DIM, screen = { 0.11, 0.36, 0.22, 0.5 } }
local function bandCol(k, n)
    if k <= 5 then return RD.BAND_COL.core end
    if k <= math.ceil(n * 2 / 3) then return RD.BAND_COL.escort end
    return RD.BAND_COL.screen
end

local function at(fr, x, y)
    fr:ClearAllPoints()
    fr:SetPoint("CENTER", RD.frame, "TOPLEFT", x, -y)
end

-- the tools row: every tool from both rails, centred across `W`, at `y`
local CON_TOOLS = function() return { RD.shield, RD.tide, RD.potion, RD.reserve, RD.fuel, RD.rations, RD.chaff, RD.res } end
-- THE DECK'S TOOLS: NO SQUARE ROUND EACH, ONE BLUE BOX ROUND THE MANA (Arn, 15 Nov: "im not liking the blue outline, lets
-- just go with dim and very bright when needed if we are going to outline we outline the box mana stuff blue"): the
-- icons alone, dim or bright; Mana Tide, the potion, Mana Spring and the drink inside one blue outline.
RD.MANA_BOX_COL = { 0.30, 0.62, 1.00, 0.9 }
local function toolsRow(W, y, deck)
    local tools = CON_TOOLS()
    local n, gap = #tools, RD.CON.toolGap
    local w = n * RD.SYS_PX + (n - 1) * gap
    local x0 = (W - w) / 2 + RD.SYS_PX / 2
    local xs = {}
    for k, b in ipairs(tools) do
        local x = x0 + (k - 1) * (RD.SYS_PX + gap)
        xs[b] = x
        if not deck then at(square("tool" .. k, RD.SYS_PX), x, y) end
        at(b, x, y)
    end
    local mb = RD.manaBox
    if deck and xs[RD.tide] and xs[RD.fuel] then
        if not mb then
            mb = CreateFrame("Frame", nil, RD.conLayer)
            mb.edges = edge(mb, RD.MANA_BOX_COL, 1.5)
            RD.manaBox = mb
        end
        local l, r = xs[RD.tide] - RD.SYS_PX / 2 - 2, xs[RD.fuel] + RD.SYS_PX / 2 + 2
        mb:SetSize(r - l, RD.SYS_PX + 4)
        mb:ClearAllPoints()
        mb:SetPoint("CENTER", RD.frame, "TOPLEFT", (l + r) / 2, -y)
        mb:Show()
    elseif mb then
        mb:Hide()
    end
end

--- THE DECK'S TOOLS, WRAPPED (16 Nov 2026): as many to a line as fit across the window, centred, line under line; the blue
--- box round the mana four only while they share a line. `top` = the first line's top. Answers the height taken, with
--- the gap under it.
-- Mana Tide in the MIDDLE of the mana four (Arn, 16 Nov: "move it to the middle of the mana i confused it for my call totems a
-- couple times cause they were both far left")
RD.TOOL_KEYS = { "shield", "potion", "tide", "reserve", "fuel", "rations", "chaff", "res" }
RD.MANA_KEYS = { tide = true, potion = true, reserve = true, fuel = true }   -- the four inside the blue box
function RD.DeckTools(W, top)
    local C, gap, S = RD.CON, RD.CON.toolGap, RD.SYS_PX
    local per = math.max(1, math.floor((W - 2 * C.pad + gap) / (S + gap)))
    -- every tool, in its order - NOT only the shown ones (Arn, 16 Nov: "all the buttons for food are gone" after a /reload:
    -- at the first layout the game has not shown them yet, so a "shown only" list placed none); a narrow window (Arn's
    -- shot: "the mana thing did not center"): the mana four on a line of their own, centred in their box, the rest under
    local all, mana, rest = {}, {}, {}
    for _, k in ipairs(RD.TOOL_KEYS) do
        local b = RD[k]
        if b then
            all[#all + 1] = b
            if RD.MANA_KEYS[k] then mana[#mana + 1] = b else rest[#rest + 1] = b end
        end
    end
    local lines = {}
    local function wrap(list)
        local i = 1
        while i <= #list do
            local l = {}
            for k = i, math.min(#list, i + per - 1) do l[#l + 1] = list[k] end
            lines[#lines + 1] = l
            i = i + per
        end
    end
    if per >= #all then lines[1] = all else wrap(mana) wrap(rest) end
    local xs, ys = {}, {}
    for l, line in ipairs(lines) do
        local cnt = #line
        local x0 = (W - (cnt * S + (cnt - 1) * gap)) / 2 + S / 2
        local cy = top + (l - 1) * (S + C.gap) + S / 2
        for k, b in ipairs(line) do
            xs[b], ys[b] = x0 + (k - 1) * (S + gap), cy
            at(b, xs[b], cy)
            if b.swHidden then b.swHidden = nil b:Show() end   -- the tools switch back on: the ones it hid
        end
    end
    local nLines = math.max(1, #lines)
    local mb = RD.manaBox
    if not mb then
        mb = CreateFrame("Frame", nil, RD.conLayer)
        mb.edges = edge(mb, RD.MANA_BOX_COL, 1.5)
        RD.manaBox = mb
    end
    local first, last                                  -- the box runs from the mana four's first button to its last
    for _, k in ipairs(RD.TOOL_KEYS) do
        if RD.MANA_KEYS[k] and RD[k] then first = first or RD[k] last = RD[k] end
    end
    if first and xs[first] and xs[last] and ys[first] == ys[last] then
        local l, r = xs[first] - S / 2 - 2, xs[last] + S / 2 + 2
        mb:SetSize(r - l, S + 4)
        mb:ClearAllPoints()
        mb:SetPoint("CENTER", RD.frame, "TOPLEFT", (l + r) / 2, -ys[first])
        mb:Show()
    else
        mb:Hide()
    end
    return nLines * (S + C.gap)
end
--- The tools row switched off: every tool button out of sight (RD.ArmTools shows them again at the next layout).
function RD.HideTools()
    for _, b in ipairs(CON_TOOLS()) do
        if b and b:IsShown() then b.swHidden = true b:Hide() end   -- remembered: only these come back (Arn: the empty blue box)
    end
    if RD.manaBox then RD.manaBox:Hide() end
end

--[[ ATTENTION OUTLINES (16 Nov 2026, Arn: "I'm missing clicking on icons that are only lit 100% for example food ... I
  miss it because I think it's still some time left. How about at 10% of whatever makes it light up is left it gets a red
  box outline ... if it is ever 100% bright red outline, cascade after that half 50% amber"). A box round a deck icon:
  RED = needed now (lit full, a buff missing or under RD.ATTN_RED_LEFT of its time, mana under the tool's own point), AMBER
  = getting close (a buff under half its time, mana under twice the tool's point). A cooling tool gets none: red always
  means "click me now". Its own switch (attn); the deck only. ]]
RD.ATTN_RED = { 1.00, 0.15, 0.15, 1 }
RD.ATTN_AMBER = { 1.00, 0.70, 0.15, 1 }
RD.ATTN_RED_LEFT = 0.10
RD.ATTN_AMBER_LEFT = 0.50
RD.attnCurves = {}
function RD.AttnOn() return RD.Deck and RD.Deck() and RD.Sw and RD.Sw("attn") end
function RD.Attn(b)
    if not b then return nil end
    if b.attn then return b.attn end
    local f = CreateFrame("Frame", nil, b)
    f:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
    f:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
    if f.SetFrameLevel and b.GetFrameLevel then
        local lvl = b:GetFrameLevel()
        if type(lvl) == "number" then f:SetFrameLevel(lvl + 8) end
    end
    f.edges = edge(f, RD.ATTN_RED, 2)
    f:Hide()
    b.attn = f
    return f
end
--- A plain colour ("red", "amber") or nil (no outline).
function RD.AttnSet(b, which)
    if not b then return false end
    if not (which and RD.AttnOn()) then
        if b.attn then b.attn:Hide() end
        return false
    end
    local f = RD.Attn(b)
    local c = (which == "amber") and RD.ATTN_AMBER or RD.ATTN_RED
    for _, e in ipairs(f.edges) do e:SetVertexColor(c[1], c[2], c[3], c[4]) end
    f:Show()
    return true
end
--- A buff's time left (a fraction, nil = missing) as an outline: red under 10% or missing, amber under half.
function RD.AttnLeft(left)
    if left == nil or left <= RD.ATTN_RED_LEFT then return "red" end
    if left <= RD.ATTN_AMBER_LEFT then return "amber" end
    return nil
end
--- A mana tool's outline as a curve on your mana: red under its own point, amber under twice it, nothing above.
function RD.AttnCurve(at)
    at = math.max(0.02, math.min(tonumber(at) or RD.TOOL_GUESS, 0.95))
    local key = math.floor(at * 100 + 0.5)
    if RD.attnCurves[key] then return RD.attnCurves[key] end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, c = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not c or not c.AddPoint then return nil end
    if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then pcall(c.SetType, c, Enum.LuaCurveType.Linear) end
    local Rd, A, x = RD.ATTN_RED, RD.ATTN_AMBER, key / 100
    local amb = math.min(x * 2, 0.95)
    pcall(c.AddPoint, c, 0.00, CreateColor(Rd[1], Rd[2], Rd[3], 1))
    pcall(c.AddPoint, c, x, CreateColor(Rd[1], Rd[2], Rd[3], 1))
    if amb > x + 0.01 then
        pcall(c.AddPoint, c, x + 0.0001, CreateColor(A[1], A[2], A[3], 1))
        pcall(c.AddPoint, c, amb, CreateColor(A[1], A[2], A[3], 1))
    end
    pcall(c.AddPoint, c, amb + 0.0001, CreateColor(A[1], A[2], A[3], 0))
    pcall(c.AddPoint, c, 1.00, CreateColor(A[1], A[2], A[3], 0))
    RD.attnCurves[key] = c
    return c
end

--- A deck button's light: very bright when needed, dim otherwise (Arn: "dim and very bright when needed") - while it wears
--- a real icon in the deck; anywhere else, as before: shown or not.
--- DIMMER AND GREY WHILE IT WAITS (15 Nov 2026, Arn: "grounding totem dimmed too like the food until needed then bright"):
--- at 30% a bright purple icon still read as lit. A waiting icon is RD.ICON_FADED (20%) and greyed; lit, full colour.
function RD.LitAlpha(b, lit)
    if b and b.food and b.food.SetDesaturated then pcall(b.food.SetDesaturated, b.food, not lit) end
    if b and b ~= RD.rations then RD.AttnSet(b, lit and "red" or nil) end   -- lit full: the red box (the food has its own)
    if lit then return 1 end
    if RD.Deck and RD.Deck() and b and b.iconTex then return RD.ICON_FADED end
    return 0
end

-- THE TOTEMS' LINE under the tools (11 Nov): only the ones you know (RD.ArmTotems), centred; answers the height it took
local function totemRow(W, y)
    local list = {}
    for _, b in ipairs(RD.TOTEMS or {}) do if b.macro then list[#list + 1] = b end end
    for k = 1, 3 do if RD.conSquares and RD.conSquares["totem" .. k] then RD.conSquares["totem" .. k]:Hide() end end
    if #list == 0 then return 0 end
    local gap = RD.CON.toolGap
    local y6 = y + RD.SYS_PX + RD.CON.gap
    local x0 = (W - (#list * RD.SYS_PX + (#list - 1) * gap)) / 2 + RD.SYS_PX / 2
    for k, b in ipairs(list) do
        local x = x0 + (k - 1) * (RD.SYS_PX + gap)
        at(square("totem" .. k, RD.SYS_PX), x, y6)
        at(b, x, y6)
    end
    return RD.SYS_PX + RD.CON.gap
end

-- a spoke's crosshairs and dims, in the console: on its pip, the dims away
local function settle(sp)
    for _, fr in ipairs(sp.dims or {}) do fr:Hide() end
    for _, cr in ipairs({ sp.cross, sp.totCross, sp.bogeyCross }) do
        if cr then cr:ClearAllPoints() cr:SetPoint("CENTER", sp.heal, "CENTER") end
    end
end

--- A bigger class (gunship, cruiser, capital): the crew in rings by rank, each person's dispels as chips in their top
--- corners; the top five's interrupts and pets in a row each under them, the middle first; the tools row.
function RD.ConsoleLayoutWide(T, order)
    local f, C = RD.frame, RD.CON
    local blockW = T.cols * T.colW
    local W = math.max(C.pad * 2 + blockW, C.pad * 2 + 8 * RD.SYS_PX + 7 * C.toolGap)
    local cells, _, blockH = RD.ConsoleCells(T, (W - blockW) / 2)
    local yk = C.pad + C.head + blockH + C.gap + T.kick / 2
    local yp = yk + T.kick / 2 + C.gap + T.pet / 2
    local yt = yp + T.pet / 2 + C.gap + RD.SYS_PX / 2
    local H = yt + RD.SYS_PX / 2 + C.pad
    f:SetSize(W, H)
    local kw = T.colW                                -- under the crew's own columns
    local function topX(j) return W / 2 + (RD.CENTER_OUT[j] - 3) * kw end
    for j = 1, 5 do
        at(square("kick" .. j, T.kick), topX(j), yk)
        at(square("pet" .. j, T.pet), topX(j), yp)
    end
    local placed = {}
    for k, i in ipairs(order) do
        local cell = cells[k]
        if not cell then break end
        local sq = T.sq
        at(square("heal" .. k, sq, bandCol(k, T.n)), cell.x, cell.y)
        local sp = RD.spokes[i]
        if sp then
            placed[i] = cell
            cell.sq = sq
            sp.heal:SetSize(sq, sq)
            at(sp.heal, cell.x, cell.y)
            settle(sp)
            -- the dispels: chips in the person's top corners, over the heal square (they take their own click)
            local lvl = sp.heal:GetFrameLevel()
            for n, c in ipairs(sp.cures or {}) do
                local side = (n % 2 == 1) and -1 or 1
                c.box:SetSize(T.chip, T.chip)
                at(c.box, cell.x + side * (sq / 2 - T.chip / 2), cell.y - (sq / 2 - T.chip / 2))
                c.box:SetFrameLevel(lvl + 3)
                if c.holder then c.holder:SetFrameLevel(lvl + 4) end
                if c.container then c.container:ClearAllPoints() c.container:SetPoint("CENTER", c.box, "CENTER") end
            end
            if k <= 5 then
                if sp.bogey then sp.bogey:SetSize(T.kick, T.kick) at(sp.bogey, topX(k), yk) end
                if sp.pet then sp.pet:SetSize(T.pet, T.pet) at(sp.pet, topX(k), yp) end
            end
        end
    end
    toolsRow(W, yt)
    H = H + totemRow(W, yt)
    f:SetSize(W, H)
    return { W = W, H = H, tier = T, cells = cells, placed = placed, rows = { kick = yk, pet = yp, tools = yt } }
end

--[[ THE FLIGHT DECK (15 Nov 2026, dev/FLIGHTDECK.md, Arn's layout B; "its own contained box" like the radar and the
  engineer's view). The engineer's own boxes - each a secure pip with its health bar (Engineer.lua), its kick square (the
  bogey: their target casting) and its cure chips - placed by the deck's arithmetic (FG.DeckPlace): the tank row and the
  outlined target box on top, then rows of five, then the tools row and the totems under them, the black box under all.
  The kick and the cures hang inside each box's right end, over the bar (their own clicks). Empty places are hidden: the
  deck grows down instead. Out of a fight only, like every layout here. ]]
-- TALLER, THE ICONS UNDER THE BAR (Arn, 15 Nov: "lets go taller and put the kick dispells under"): a box is the name's
-- line on top, the health bar the whole width, and a row of icons under it (`icons` tall) - the kick at its left, the cures
-- at its right. The tank row taller still, so the target box's two cells are not squished under its label.
-- NARROW AND TALL (Arn, 15 Nov: "also taller 9:16 just a number throwing out there i hate moving mouse lef and right"):
-- five to a row still, each box thinner and taller - the deck about 320 wide instead of 450; a full raid comes out near
-- 9:16, a party (two rows) stays wider than tall.
-- boxTop = boxIn: the target box's label sits ABOVE the box (Arn, 15 Nov: "there is plenty of space to write target of
-- target up there so the boxes can be the same size of the tank"), so its two cells stand the tank row's full height
-- ONE ICON SIZE (Arn, 15 Nov: "the interrupt section under the frames lets make it the same size icons as everything
-- else keep things uniform" - he picked wider boxes): the kick and the cures at the tool buttons' own 22 px, so a box is 74
-- wide (kick + two cures) and a little taller for the bar's room; the deck about 400 wide.
RD.DECK = { cell = 74, row = 58, tank = 70, gap = 3, boxIn = 2, boxTop = 2, chip = 22, kick = 22, icons = 24 }
-- THE ENGINEER'S VIEW (Arn, 15 Nov: his cousin "already thought it took too much space" - "we dont go wider we can go
-- taller ... as little empty space as possible"): the same deck, narrower and taller boxes, 2 px apart
RD.DECK_SMALL = { cell = 58, row = 56, tank = 62, gap = 2, boxIn = 2, boxTop = 2, chip = 20, kick = 20, icons = 22,
                  -- the 9:16 engineer (FG.EngPlace): one narrow width; a party's rows, then a raid's short ones
                  w = 218, top = 66, row2 = 70, pet2 = 44, rtank = 46, rhead = 13, rtgt = 40, row5 = 34, pet5 = 28, short = 10,
                  pw = 100, rw = 39 }                -- the box widths a wider drag keeps (party, raid)
-- THE FLOOR (Arn, 15 Nov: "the minimum is that bottom row ... the four totems and the call recall"): the totem row -
-- CALL / BRING / RECALL in the middle, two timers each side at least RD.TIMER_MIN wide (an icon and "5m") - is the
-- narrowest the window goes; the mockup showed the timers overlapping below it
RD.TIMER_MIN = 34
RD.DECK_BOX_COL = { 0.62, 0.66, 0.74, 0.85 }       -- the target pair's header + line: quiet grey (the cyan clashed, Arn 15 Nov)
RD.DECK_LINE_UP = 2                                 -- the line's gap above the two boxes
RD.DECK_LABEL_H = 12                                -- the band the header and its line take above a top-row pair
RD.DECK_HEADER = false                              -- the header is gone: the boxes' own names say it (RD.BoxName)
RD.BOX_WORD = { target = "TARGET", targettarget = "ITS TARGET" }   -- the name line while nobody is there

--- A target-pair box's name line: the real name (a hidden one handed over untouched), else what the box is for.
function RD.BoxName(unit)
    local cs = RD.Callsign(unit)
    if NS.Secret and NS.Secret(cs) then return cs end
    if (cs == nil or cs == "") and RD.BOX_WORD[unit] then return RD.BOX_WORD[unit] end
    return cs
end
RD.DECK_HEAD = 26                                   -- the deck's alert strip (LOS / RANGE / OVER/H boxes 22 tall)
RD.DECK_TAG = { font = "Fonts\\ARIALN.TTF", size = 9, col = { 0.86, 1.00, 0.90, 1 }, x = 4, y = -4 }   -- the callsign on each box

--- A box's plate: the whole box - its two sides and the middle - drawn dark with a thin edge, under the pip and the icons.
function RD.DeckPlate(sp)
    local p = sp.deckPlate
    if not p then
        p = CreateFrame("Frame", nil, RD.conLayer)
        p.bg = p:CreateTexture(nil, "BACKGROUND")
        p.bg:SetAllPoints(p)
        p.bg:SetColorTexture(0, 0, 0, 0.35)
        p.edgeHold = CreateFrame("Frame", nil, p)        -- the edges on their own frame: a hidden "enemy?" sets its alpha
        p.edgeHold:SetAllPoints(p)
        p.edges = edge(p.edgeHold, RD.DIM, 1.5)
        -- THE GROUP MATES' WASH (21 Nov 2026, sheet 6: "hovering a box lights up its group mates"): a faint wash over the
        -- whole box on its own plain frame (over the bar; RD.DeckLayout sets its level), shown only from enter / leave
        p.mateHold = CreateFrame("Frame", nil, p)
        p.mateHold:SetAllPoints(p)
        p.mate = p.mateHold:CreateTexture(nil, "OVERLAY")
        p.mate:SetAllPoints(p.mateHold)
        local mc = RD.MATE_WASH
        p.mate:SetColorTexture(mc[1], mc[2], mc[3], mc[4])
        p.mate:Hide()
        sp.deckPlate = p
    end
    return p
end

--[[ THE SIZE TIERS (21 Nov 2026, BiS Cues sheet 7, Arn: "dragging the window narrower never piles icons"; and the same
  evening: "the bar cant have clickable things on frame or people will miss click and the bar must always go to the end of
  the box no empty space" - so there is NO side column: the bar is always the box's whole width, the kick and the cures
  only ever in the row under it). As a box gets narrower, parts drop in this order:
    1 extra tags (MANA TIDE, TAP)   2 the pet's paw and the group tag   3 the name, cut to 4 letters
    4 the second cure               5 the first cure                    6 the name
  NEVER dropped: the health bar's click area (the whole box above the icon row) and the kick's spot.
    FULL       RD.TIER_FULL+ wide     the kick + 2 cures, the full name, tags, extras
    ONE CURE   the kick + 1 cure fit  the name cut to RD.NAME_CUT letters
    KICK       narrower               the kick alone, the cut name
    FLOOR      under RD.NAME_MIN      the bar + the kick; never narrower than FG.BOX_MIN_W (fewer boxes a row instead)
  `ic` = the deck's one icon size (RD.IconPx). Answers the room table, kept on the spoke as sp.room. ]]
RD.TIER_FULL = 74
RD.NAME_MIN = 34
RD.NAME_CUT = 4
RD.NAME_LINE = 13                                   -- the name's line: RD.DECK_TAG.y down, 9 pt
RD.EXTRA_NEED = 27                                  -- a bar this tall holds the line under the name (TAP, MANA TIDE)
RD.ICON_MIN, RD.ICON_MAX = 16, 22
RD.CORNER_W = 20                                    -- the group tag's (or the paw's) corner, taken off the name's width
-- (22 Nov 2026, Arn in a battleground: "group tags are so small" - 8 pt grey read as a dash: now 12 pt in gold)
RD.GTAG = { size = 12, col = { 1.00, 0.83, 0.30, 1 } }
RD.MATE_WASH = { 1, 1, 1, 0.10 }
--- One icon size for the whole deck: scaled with the smallest box (`minW`), never under 16 or over 22 px.
function RD.IconPx(minW)
    if type(minW) ~= "number" then return RD.ICON_MAX end
    return math.max(RD.ICON_MIN, math.min(RD.ICON_MAX, math.floor((minW - 6) / 2)))
end
function RD.BoxRoom(w, ph, ic)
    ic = ic or RD.ICON_MAX
    local tier
    if w >= RD.TIER_FULL then tier = "full"
    elseif 2 * ic + 6 <= w then tier = "one"            -- kick + cure + their gaps and margins
    elseif w >= RD.NAME_MIN then tier = "kick"
    else tier = "floor" end
    local full = tier == "full"
    local name = full and "full" or (tier ~= "floor" and "cut") or false
    if (ph or 0) < RD.NAME_LINE then name = false end
    return { tier = tier, cures = full and 2 or (tier == "one" and 1) or 0, name = name, tags = full,
             extras = full and (ph or 0) >= RD.EXTRA_NEED }
end
--- Has this box room for `what` (extras / tags / name / cures)? A box the deck never laid out: yes.
function RD.BoxHas(sp, what)
    local r = sp and sp.room
    if not r then return true end
    return r[what] and true or false
end
--- Hovering a box in a raid lights its group mates (the other boxes of its raid group); the wash goes on leave.
function RD.GroupWash(sp, on)
    local g = sp and sp.raidGroup
    local mates = g and RD.deckMates and RD.deckMates[g]
    if not mates then return false end
    for _, m in ipairs(mates) do
        local p = m.deckPlate
        if m ~= sp and p and p.mate then p.mate:SetShown(on and p:IsShown() and true or false) end
    end
    return true
end

--- THE CALLSIGN (Arn: "puts names on the boxes like a flight rader tracker"): the first name in capitals across the TOP
--- of the whole box (Arn, 15 Nov: "run the name across the whole box" - in the middle alone it was "CHA..."); the box's
--- icons sit under that line, so the name never covers them. Plain only - a hidden name shows nothing, never a guess.
RD.DECK_NAME_BAND = 9                              -- the top line the name owns
--- A HIDDEN NAME IS STILL SHOWN (Arn, 15 Nov, the target box empty of names: "names here too"): in a dungeon the game hides
--- an enemy's name - a secret - and a secret may not be cut or put in capitals, but a font string takes it untouched, so it
--- is handed over as it is (the game writes it whole). Only a plain name becomes the first-word capitals callsign.
function RD.Callsign(unit)
    if type(unit) ~= "string" then return "" end
    local ok, n = pcall(GetUnitName, unit, false)
    if not ok or n == nil then return "" end
    if NS.Secret and NS.Secret(n) then return n end
    if type(n) ~= "string" or n == "" then return "" end
    return ((n:match("^(%S+)")) or n):upper()
end
--- The name a box shows: the callsign, cut to RD.NAME_CUT letters while its tier says so (a plain name only - a hidden one
--- may not be cut, it is handed whole and the label's width cuts it); "" while the tier has no room for a name.
function RD.DeckName(sp)
    local n = RD.BoxName(sp.unit)
    local room = sp.room
    if room and room.name == false then return "" end
    if room and room.name == "cut" and type(n) == "string" and not (NS.Secret and NS.Secret(n)) then n = n:sub(1, RD.NAME_CUT) end
    return n
end
--- `room` (RD.BoxRoom) cuts or drops the name; `group` = the raid group for the G2 tag (nil: none); `paw` = a pet's paw
--- takes the top-right corner. The name never runs under the corner: its width stops RD.CORNER_W short.
function RD.DeckTag(sp, w, room, group, paw)
    local t = sp.deckTag
    local plate = RD.DeckPlate(sp)
    if not t then
        t = CreateFrame("Frame", nil, plate)          -- on the plate: the whole box, not the middle alone (takes no click)
        t:SetAllPoints(plate)
        t.text = t:CreateFontString(nil, "OVERLAY")
        t.text:SetFont(RD.DECK_TAG.font, RD.DECK_TAG.size, "OUTLINE")
        t.text:SetPoint("TOPLEFT", t, "TOPLEFT", RD.DECK_TAG.x, RD.DECK_TAG.y)   -- clear of the edge (Arn's shot, 16 Nov)
        t.text:SetJustifyH("LEFT")
        local c = RD.DECK_TAG.col
        t.text:SetTextColor(c[1], c[2], c[3], c[4])
        sp.deckTag = t
    end
    t:SetFrameLevel(sp.heal:GetFrameLevel() + 5)            -- over the bar and the icons (they sit below its line)
    local corner = (group or paw) and RD.CORNER_W or 0
    if w then t.text:SetWidth(math.max(8, w - 6 - corner)) end
    t.text:SetText(RD.DeckName(sp))
    -- THE GROUP TAG (21 Nov 2026, sheet 6 B): "G2" in the box's top-right corner, its own switch (RD.Sw("gtag")), a raid only
    if group and not t.group then
        t.group = t:CreateFontString(nil, "OVERLAY")
        t.group:SetFont(RD.DECK_TAG.font, RD.GTAG.size, "OUTLINE")
        t.group:SetPoint("TOPRIGHT", t, "TOPRIGHT", -2, RD.DECK_TAG.y)
        t.group:SetJustifyH("RIGHT")
        t.group:SetWidth(RD.CORNER_W - 1)
        local c = RD.GTAG.col
        t.group:SetTextColor(c[1], c[2], c[3], c[4])
    end
    if t.group then
        t.group:SetText(group and ("G" .. group) or "")
        t.group:SetShown(group ~= nil)
    end
    local names = RD.Sw("names")
    t.text:SetShown(names)
    t:SetShown(names or group ~= nil)                       -- the names switch (the group tag has its own)
    return t
end

--- THE KICK, AS ITS SPELL (15 Nov 2026, Arn: "the red interrupt button use the actual spell icon with red outline or red
--- slight pulse"): in the deck the kick button's face carries your interrupt's own icon (FG.KickIcon - Earth Shock for a
--- shaman) inside a thin red rim, in place of the drawn red triangle. The face shows only while their target casts, and
--- the button's red pulse is the radar's own (k.beat), so nothing new runs.
function RD.DeckKick(sp)
    local k = sp and sp.bogey
    if not (k and k.face) then return false end
    if not k.deckIcon then
        k.deckIcon = k.face:CreateTexture(nil, "OVERLAY", nil, 5)
        k.deckIcon:SetPoint("TOPLEFT", k, "TOPLEFT", 1, -1)
        k.deckIcon:SetPoint("BOTTOMRIGHT", k, "BOTTOMRIGHT", -1, 1)
        if k.deckIcon.SetTexCoord then k.deckIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        k.deckRim = edge(k.face, RD.COL.bogey, 1.5)
    end
    k.deckIcon:SetTexture((NS.FG and NS.FG.KickIcon and NS.FG.KickIcon()) or nil)
    k.deckIcon:Show()
    for _, t in ipairs(k.deckRim) do t:Show() end
    for _, l in ipairs(k.lines or {}) do l:Hide() end    -- the drawn triangle steps aside
    return true
end

--- Out of the deck: every box's plate and callsign away (the radar and the engineer's view draw neither); the kick back
--- to its drawn triangle.
function RD.DeckClear()
    for _, t in ipairs(RD.timers or {}) do t:Hide() end   -- the totem timers are the deck's alone
    if RD.manaBox then RD.manaBox:Hide() end              -- and the mana group's outline
    RD.deckMates = nil                                    -- (the deck lays them out again; nobody's group mates lit)
    for _, sp in ipairs(RD.spokes or {}) do
        sp.room, sp.raidGroup = nil, nil
        if sp.deckPlate then sp.deckPlate:Hide() if sp.deckPlate.mate then sp.deckPlate.mate:Hide() end end
        if sp.deckTag then sp.deckTag.text:SetText("") sp.deckTag:Hide() end
        local k = sp.bogey
        if k and k.deckIcon then
            k.deckIcon:Hide()
            for _, t in ipairs(k.deckRim or {}) do t:Hide() end
            for _, l in ipairs(k.lines or {}) do l:Show() end
        end
    end
end

--- The deck's order: the tanks first (the radar's own answer, RD.LogicBand; nobody named = one guessed, RD.GuessTank),
--- then everyone else in place order (a raid's place is its group and spot), the empty places last. Answers the order
--- and how many of it are tanks.
--- THE SORT AND THE BLOCKS (21 Nov 2026, BiS Cues sheet 6): `sort` (RD.DeckSort() by default) - only "tanks" lifts anyone.
--- In a raid (`raid`, RD.raid by default) a third answer: the BLOCKS, each { group = g, spots = { place, ... } } - a group
--- sort gives one block per raid group that has anyone left in it (a lifted tank leaves his spot empty: the block keeps
--- five spots, so the rows never shift); class and max health give blocks of five in their order (group = nil). The same
--- group always gives the same order: every tie falls back to the place.
function RD.DeckOrder(units, n, sort, raid)
    sort = RD.SORT_WORD[sort] and sort or RD.DeckSort()
    if raid == nil then raid = RD.raid end
    local tanks, rest, empty, present = {}, {}, {}, {}
    for i = 1, n do if units[i] then present[i] = true end end
    for i = 1, n do
        local u = units[i]
        if not u then
            empty[#empty + 1] = i
        elseif sort ~= "tanks" then
            rest[#rest + 1] = i
        else
            local okMe, me = false, nil
            if u == "player" then okMe, me = true, true elseif UnitIsUnit then okMe, me = pcall(UnitIsUnit, u, "player") end
            if not (okMe and plain(me) == true) and RD.LogicBand(u) == "tank" then tanks[#tanks + 1] = i
            else rest[#rest + 1] = i end
        end
    end
    if sort == "class" or sort == "maxhp" then
        local key = {}
        for _, i in ipairs(rest) do
            local u, k = units[i], nil
            if sort == "class" then
                local ok, _, c = pcall(UnitClass, u)
                c = ok and plain(c) or nil
                k = -(RD.CLASS_ORDER[c] or 99)
            else
                local ok, mx = pcall(UnitHealthMax, u)
                mx = ok and plain(mx) or nil
                k = (type(mx) == "number" and mx > 0) and mx or -1     -- unreadable: after everyone read, by place
            end
            key[i] = k
        end
        table.sort(rest, function(a, b) if key[a] ~= key[b] then return key[a] > key[b] end return a < b end)
    end
    if sort == "tanks" and #tanks == 0 then
        -- NOBODY NAMED: THE MOST HEALTH (Arn, 15 Nov: "as a fallback can we do it so if there is no tank in the group the one
        -- with the most health goes up there") - the biggest max health, read plain out of a fight, never you; only when no
        -- health can be read, the class guess (RD.GuessTank)
        local g = RD.MostHealth(rest, units) or RD.GuessTank(present, units)
        -- ALONE: YOU (Arn, 15 Nov, solo with an empty tank row: "no party we go up there")
        if not g and #rest == 1 then g = rest[1] end
        if g then
            tanks[1] = g
            for k, i in ipairs(rest) do if i == g then table.remove(rest, k) break end end
        end
    end
    local order = {}
    for _, i in ipairs(tanks) do order[#order + 1] = i end
    for _, i in ipairs(rest) do order[#order + 1] = i end
    for _, i in ipairs(empty) do order[#order + 1] = i end
    local blocks
    if raid then
        blocks = {}
        if sort == "tanks" or sort == "group" then
            local byGroup = {}
            for _, i in ipairs(rest) do
                local g = math.ceil(i / 5)
                if not byGroup[g] then
                    byGroup[g] = { group = g, spots = {} }
                    blocks[#blocks + 1] = byGroup[g]
                end
                local sp = byGroup[g].spots
                sp[#sp + 1] = i
            end
            table.sort(blocks, function(a, b) return a.group < b.group end)
        else
            for k, i in ipairs(rest) do
                local b = math.ceil(k / 5)
                blocks[b] = blocks[b] or { spots = {} }
                local sp = blocks[b].spots
                sp[#sp + 1] = i
            end
        end
    end
    return order, #tanks, blocks
end

--- The target box's two boxes repainted (a target change: the client re-points "target" / "targettarget" by itself; the
--- colours are ours to redo). Nothing when the deck is off.
function RD.PaintDeckBox()
    if not RD.Deck() then return false end
    for _, sp in ipairs(RD.spokes or {}) do
        if sp.unit and sp.slot and sp.slot.box then
            RD.PaintHeal(sp)
            if sp.deckTag then sp.deckTag.text:SetText(RD.DeckName(sp)) end    -- the new target's callsign, or the box's word
        end
    end
    return true
end

--- Of these places, the one whose person has the most max health (plain; never you), or nil when none can be read.
function RD.MostHealth(places, units)
    local best, bestHp
    for _, i in ipairs(places or {}) do
        local u = units[i]
        if u and u ~= "player" then
            local okMe, me = false, nil
            if UnitIsUnit then okMe, me = pcall(UnitIsUnit, u, "player") end
            local ok, mx = pcall(UnitHealthMax, u)
            mx = ok and plain(mx) or nil
            if not (okMe and plain(me) == true) and type(mx) == "number" and mx > 0 and (not bestHp or mx > bestHp) then
                best, bestHp = i, mx
            end
        end
    end
    return best
end

--- The deck's places: no pet; then the target box's two (no kick of their own). THE KICK ON EVERYONE (Arn: "a small
--- interrupt button next to everyone like their cure and dispell buttons only show up when needed"). Measured in a 40: one
--- look is 344 calls with all 40 kicks, 274 with five - the engineer's range on 40 boxes is most of it (its view pays that
--- today); a kick is about two calls.
function RD.DeckSlots(T, nPets)
    local M, out = RD.DeckM(), {}
    for i = 1, T.n + 2 + (nPets or 0) do
        local crew = i <= T.n
        out[i] = { b = 0, rh = 0, rc = 0, rb = crew and 0 or nil, ph = M.row - 8, pc = M.chip, pb = M.kick, own = false,
                   nopet = true, console = true, group = math.ceil(i / 5), pos = (i - 1) % 5 + 1, deck = true,
                   box = (not crew and i <= T.n + 2) or nil, petBox = (i > T.n + 2) or nil }
        if i > T.n + 2 then out[i].rb = nil end              -- a pet box: no kick of its own
        if not RD.Sw("kicks") then out[i].rb = nil end       -- kicks switched off: no kick button anywhere
    end
    return out
end

--[[ PETS ARE PEOPLE TOO (Arn, 15 Nov: "hunter pets should be counted as party members but never go in the top tank spot,
  and indicated by that paw icon"). Out of a fight, the pets that are out: yours and your party's (in a raid, your own
  group's), each its own box after the people - never in the tank row (the tank row only ever takes the crew) - with a paw
  on its name line. A pet called or sent away re-lays the deck (UNIT_PET; in a fight it waits for the fight's end). ]]
function RD.DeckPets(units, n)
    local out = {}
    for i = 1, n do
        local u = units[i]
        local mine = (not RD.raid) or math.ceil(i / 5) == (RD.ownGroup or 1)
        local pet = u and mine and RD.PetOf(u)
        if pet then
            local ok, there = pcall(UnitExists, pet)
            if ok and plain(there) == true then out[#out + 1] = pet end
        end
    end
    return out
end

-- the paw: the game's own paw print (Track Beasts' icon, asked by its spell id; its file path if the client will not say)
RD.PAW_SPELL = 1494
function RD.DeckPaw(sp, on)
    local plate = sp and sp.deckPlate
    if not plate then return false end
    local p = sp.deckPaw
    if not on then if p then p:Hide() end return false end
    if not p then
        p = plate:CreateTexture(nil, "OVERLAY", nil, 6)
        local tex
        if C_Spell and C_Spell.GetSpellTexture then
            local ok, t = pcall(C_Spell.GetSpellTexture, RD.PAW_SPELL)
            if ok then tex = t end
        end
        p:SetTexture(tex or "Interface\\Icons\\Ability_Tracking")
        if p.SetTexCoord then p:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        p:SetSize(RD.DECK_NAME_BAND + 2, RD.DECK_NAME_BAND + 2)
        p:SetPoint("TOPRIGHT", plate, "TOPRIGHT", -2, -1)
        sp.deckPaw = p
    end
    p:Show()
    return true
end

--- The units the deck's places hold: the crew's own (a copy - RD.units stays the group), then "target" and "targettarget".
function RD.DeckUnits(units, n, pets)
    local out = {}
    for i = 1, n do out[i] = units[i] end
    out[n + 1], out[n + 2] = "target", "targettarget"
    for k, p in ipairs(pets or {}) do out[n + 2 + k] = p end
    return out
end

function RD.DeckLayout(T, order)
    local f, C, M = RD.frame, RD.CON, RD.DeckSized(RD.DeckM())
    local SW = RD.Sw
    local nT = math.min(RD.deckTanks or 0, T.n)
    local crew = {}
    for k = nT + 1, T.n do
        local i = order[k]
        if i and RD.units and RD.units[i] then crew[#crew + 1] = i end
    end
    local firstPet = #crew + 1
    for k = 1, RD.deckPets or 0 do crew[#crew + 1] = T.n + 2 + k end     -- the pets: after the people, never a tank
    local place
    local dw = RD.DeckWidth()
    local noTankRow = (RD.deckSorted or "tanks") ~= "tanks"          -- a sort that lifts nobody: no tank row
    -- A RAID AS FIXED BLOCKS (21 Nov 2026, sheet 6): each raid group five spots, an empty spot where someone is missing
    -- (lifted to the tank row, or never there); the pets a block of their own after the people
    local blocks
    if RD.raid and not RD.Compact() and RD.deckBlocks then
        blocks = {}
        for _, b in ipairs(RD.deckBlocks) do blocks[#blocks + 1] = { group = b.group, spots = b.spots } end
        for k = 1, RD.deckPets or 0 do
            local last = blocks[#blocks]
            if not (last and last.pet and #last.spots < 5) then last = { pet = true, spots = {} } blocks[#blocks + 1] = last end
            last.spots[#last.spots + 1] = T.n + 2 + k
        end
    end
    if RD.Compact() then
        place = NS.FG.EngPlace(nT, firstPet - 1, #crew - firstPet + 1, not RD.raid, M, dw or math.max(M.w, RD.FloorInner()))
    elseif blocks then
        local counts = {}
        for b = 1, #blocks do counts[b] = 5 end
        place = NS.FG.DeckBlocks(nT, counts, M, dw, not SW("target"), SW("cols"), noTankRow)
    else
        place = NS.FG.DeckPlace(nT, #crew, not RD.raid, M, dw, not SW("target"), noTankRow)
    end
    -- ONE ICON SIZE (sheet 7): scaled with the smallest box the deck places, held to RD.ICON_MIN .. RD.ICON_MAX
    local minW
    local function seen(r) if r and r.w and (not minW or r.w < minW) then minW = r.w end end
    for k = 1, nT do seen(place.tanks[k]) end
    if blocks then
        for b, blk in ipairs(blocks) do for s = 1, #blk.spots do seen(place.blocks[b] and place.blocks[b].spots[s]) end end
    else
        for r = 1, #crew do seen(place.rest[r]) end
    end
    seen(place.target) seen(place.tot)
    local ic = RD.IconPx(minW)
    RD.deckIcon = ic
    RD.deckMates = {}
    local W = C.pad * 2 + place.w                    -- the tools wrap and the totems stack to fit (RD.DeckTools / DeckTotemRow)
    RD.deckInnerW = place.w
    -- under the deck's taller alert strip; when the target pair sits in the top row, a band for its header line too (Arn,
    -- 15 Nov, a screenshot: "TARGET - ITS TARGET" was drawn over the alert boxes)
    local band = (RD.DECK_HEADER and place.target and place.target.y == 0) and RD.DECK_LABEL_H or 0
    local x0, y0 = (W - place.w) / 2, C.pad + RD.DeckHead() + band
    local placed = {}
    -- THE ICONS UNDER THE BAR (15 Nov 2026). The kick and the cures are secure buttons that keep their click while unseen
    -- (a secure button's mouse may not change in a fight) - laid over the bar they ate the heal (Arn: "the middle part of
    -- the healing frame cast the cure disease"). First they went to the box's sides; then (Arn: "lets go taller and put the
    -- kick dispells under") into a ROW UNDER THE BAR: the heal pip - your binds, the name, the bar - takes the box's whole
    -- width above, the icon row the bottom `icons` px, the kick at its left, the cures at its right. Nothing overlaps.
    -- THE SIZE TIERS (21 Nov 2026, sheet 7 - RD.BoxRoom): what a box this wide has room for. The bar always runs the box's
    -- whole width (Arn: "the bar must always go to the end of the box no empty space") and nothing clickable ever sits on
    -- or beside it ("people will miss click"): the kick and the cures live only in the row UNDER the bar.
    local function put(i, r, kick, group, pet)
        local sp = RD.spokes[i]
        if not (sp and r) then return end
        local cy, left, right = y0 + r.y + r.h / 2, x0 + r.x, x0 + r.x + r.w
        local plate = RD.DeckPlate(sp)
        plate:SetSize(r.w, r.h)
        at(plate, left + r.w / 2, cy)
        plate:Show()
        placed[i] = r
        -- A SHORT BOX (the engineer's raid rows): the bar takes the box's whole height, the icons a thin column at its
        -- right end - kick at the foot, cures above it - never over the bar (a secure icon keeps its click unseen)
        local is = r.short and (M.short or 10) or nil
        local ih = is and 0 or M.icons
        local ph = is and (r.h - 2) or (r.h - ih - 1)            -- the pip: the bar's height
        local pw = is and (r.w - 3 - is) or (r.w - 2)            -- and its width
        local ks = is or math.min(M.kick, ih - 2, ic)
        local cs = is or math.min(M.chip, ih - 2, ic)
        local room = (not is) and RD.BoxRoom(r.w, ph, ic) or nil
        sp.room, sp.raidGroup = room, (RD.raid and group) or nil
        if sp.raidGroup then
            RD.deckMates[group] = RD.deckMates[group] or {}
            table.insert(RD.deckMates[group], sp)
        end
        if plate.mate then plate.mate:Hide() end                  -- (a wash left lit by a hover before this layout)
        if plate.mateHold then plate.mateHold:SetFrameLevel(sp.heal:GetFrameLevel() + 6) end
        if room and not room.extras and sp.tideTag then sp.tideTag:Hide() end   -- no room for MANA TIDE: it goes first
        RD.TideTagWidth(sp)
        local icy = y0 + r.y + r.h - ih / 2                       -- the icon row's middle, at the box's foot
        sp.heal:SetSize(pw, ph)
        at(sp.heal, left + 1 + pw / 2, y0 + r.y + 1 + ph / 2)
        sp.heal:Show()
        settle(sp)
        local lvl = sp.heal:GetFrameLevel()
        local colX = right - 1 - (is or 0) / 2                    -- a short box's icon column
        local footY = y0 + r.y + r.h - 1 - (is or 0) / 2
        kick = kick and SW("kicks")
        if sp.bogey and not SW("kicks") then sp.bogey:Hide() end     -- switched off: disarmed in RD.DeckSlots, out of sight
        if kick and sp.bogey then
            sp.bogey:SetSize(ks, ks)
            if is then at(sp.bogey, colX, footY) else at(sp.bogey, left + 2 + ks / 2, icy) end
            sp.bogey:SetFrameLevel(lvl + 3)
            RD.DeckKick(sp)                                   -- your interrupt's own icon, red-rimmed
        end
        RD.MakeCastStrip(sp)                                  -- the mini cast bar, made here, out of a fight
        RD.PlaceCastStrip(sp, ih > 0 and { left + 1, y0 + r.y + r.h - ih, right - 1, y0 + r.y + r.h - 1 } or nil)
        local x = right - 2
        local cyCol = footY - ((kick and is) and (is + 1) or 0)  -- a short box: the cures stack above the kick
        for n, c in ipairs(sp.cures or {}) do
            -- off by the switch, or no room in this box's icon row (the second cure goes first, then the first: RD.BoxRoom)
            if not SW("cures") or (room and n > room.cures) then
                if c.box:IsShown() then c.swHidden = true c.box:Hide() end
                if c.container and c.container.Hide then c.container:Hide() end
            elseif c.swHidden then
                c.swHidden = nil
                c.box:Show()
                if c.container and c.container.Show then c.container:Show() end
            end
            c.box:SetSize(cs, cs)
            if is then
                at(c.box, colX, cyCol)
                cyCol = cyCol - is - 1
            else
                at(c.box, x - cs / 2, icy)
                x = x - cs - 2
            end
            c.box:SetFrameLevel(lvl + 3)
            if c.holder then c.holder:SetFrameLevel(lvl + 4) end
            if c.container then c.container:ClearAllPoints() c.container:SetPoint("CENTER", c.box, "CENTER") end
        end
        -- the name across the whole box; the corner (the group tag, or a pet's paw) only where the tier keeps it
        local gtag = room and room.tags and sp.raidGroup and SW("gtag") and not pet
        RD.DeckTag(sp, r.w, room, gtag and sp.raidGroup or nil, pet and (not room or room.tags))
    end
    local function groupOf(i) return (RD.raid and i and i <= T.n) and math.ceil(i / 5) or nil end
    for k = 1, nT do put(order[k], place.tanks[k], true, groupOf(order[k])) end
    if blocks then
        for b, blk in ipairs(blocks) do
            local pb = place.blocks[b]
            for s, i in ipairs(blk.spots) do
                put(i, pb and pb.spots[s], not blk.pet, (not blk.pet) and groupOf(i) or nil, blk.pet)
                local sp = RD.spokes[i]
                RD.DeckPaw(sp, blk.pet and RD.BoxHas(sp, "tags"))
            end
        end
    else
        for r, i in ipairs(crew) do
            put(i, place.rest[r], r < firstPet, nil, r >= firstPet)
            local sp = RD.spokes[i]
            RD.DeckPaw(sp, r >= firstPet and RD.BoxHas(sp, "tags"))
        end
    end
    for k = 1, nT do RD.DeckPaw(RD.spokes[order[k]], false) end
    for i = T.n + 1, T.n + 2 do if RD.spokes[i] then RD.DeckPaw(RD.spokes[i], false) end end
    -- the empty places: out of sight (the deck grows down instead of keeping holes)
    for k = 1, T.n do
        local i = order[k]
        local sp = i and RD.spokes[i]
        if sp and not placed[i] then
            sp.heal:Hide()
            if sp.bogey then sp.bogey:Hide() end
            if sp.deckPlate then sp.deckPlate:Hide() end
        end
    end
    -- the target pair: no outline (Arn, 15 Nov: "the colors clash too much ... maybe just the header text with a line above
    -- them"), a thin line over the two boxes with their job written on it, in the deck's quiet grey
    local box = RD.deckBox
    if not box then
        box = CreateFrame("Frame", nil, RD.conLayer)
        local c = RD.DECK_BOX_COL
        box.line = box:CreateTexture(nil, "OVERLAY")
        box.line:SetColorTexture(c[1], c[2], c[3], c[4])
        box.line:SetHeight(1)
        box.line:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 0, RD.DECK_LINE_UP)
        box.line:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, RD.DECK_LINE_UP)
        box.label = box:CreateFontString(nil, "OVERLAY")
        box.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 7, "")
        box.label:SetPoint("BOTTOMLEFT", box.line, "TOPLEFT", 1, 2)   -- over the line, in the strip above the top row
        box.label:SetTextColor(c[1], c[2], c[3], 1)
        box.label:SetText("TARGET · ITS TARGET")
        RD.deckBox = box
    end
    -- NO HEADER ANY MORE (Arn, 15 Nov night: "instead of the bar up top that says target and its target we just pretend
    -- thats the name and put it in that place"): the two boxes' own name lines say TARGET / ITS TARGET while nobody is
    -- there (RD.BoxName); the line and its words stay built, hidden
    box.line:Hide()
    box.label:Hide()
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + place.box.x, -(y0 + place.box.y))
    box:SetSize(place.box.w, place.box.h)
    box:Show()
    if place.target then
        put(T.n + 1, place.target, false)
        put(T.n + 2, place.tot, false)
    else                                              -- the target pair switched off: out of sight, nothing to click
        for i = T.n + 1, T.n + 2 do
            local sp = RD.spokes[i]
            if sp then
                sp.heal:Hide()
                if sp.deckPlate then sp.deckPlate:Hide() end
                if sp.deckTag then sp.deckTag:Hide() end
                if sp.castStrip then sp.castStrip:SetAlpha(0) end
            end
        end
    end
    -- the deck of buttons under the crew: the tools (wrapped to fit), then the totems and their timers (stacked to fit)
    local y = y0 + place.h + C.gap
    if SW("tools") then y = y + RD.DeckTools(W, y) else RD.HideTools() end
    y = y + RD.DeckTotemRow(W, y)
    local H = y - C.gap + C.pad
    f:SetSize(W, H)
    return { W = W, H = H, tier = T, placed = placed, place = place, deck = true, rows = { tools = yt } }
end

--[[ THE TOTEMS' TIMERS (15 Nov 2026, Arn: "we have a lot of room on the totem class utility row, can we add 4 boxes can be
  long to acommodate 5:00 timer for the totems, with a icon of what totem it is in this order grey air blue water brown
  earth and red fire"). On the deck's totem row: CALL, BRING, RECALL at its left, then four long boxes to its right edge,
  air / water / earth / fire, each edged in its element's colour, the standing totem's icon at its left and the GAME'S own
  countdown beside it (a Cooldown fed GetTotemDuration's object - the client counts and writes the number, in a fight too;
  out of a fight the plain start/length). The icon from GetTotemInfo, handed to the texture untouched (secret or not).
  Shown for anyone who has totems (the totem buttons armed, RD.ArmTotems); repainted on PLAYER_TOTEM_UPDATE. ]]
RD.TOTEM_TIMERS = {                                -- the game's totem slots: 1 fire, 2 earth, 3 water, 4 air
    { slot = 4, col = { 0.72, 0.74, 0.80, 1 } },   -- air: grey
    { slot = 3, col = { 0.25, 0.55, 1.00, 1 } },   -- water: blue
    { slot = 2, col = { 0.62, 0.42, 0.22, 1 } },   -- earth: brown
    { slot = 1, col = { 1.00, 0.32, 0.26, 1 } },   -- fire: red
}
--[[ A CLICK DROPS IT AGAIN (Arn, 15 Nov: "will it remember what [totem icon timer] and i click it will it be able to drop
  it, we drop the totem first out of combat and make a macro in it"). Each box is a secure button: out of a fight the
  standing totem's NAME is plain, so it is remembered for its slot (db().totemSlots, kept across a reload) and the box's
  click becomes `/cast <that totem>` - which then works in a fight too. Under the live icon, the remembered totem's icon,
  dim: an empty slot still shows what a click drops. A totem swapped in mid-fight is learned when the fight ends (the
  names are secret in one). ]]
RD.TIMER_DIM = 0.45
RD.TIMER_FULL = 600                                 -- seconds under which the timer shows minutes:seconds (a totem lasts 300)
RD.TIMER_SHORT = 60                                 -- the engineer's view: "5m", then plain seconds (Arn: "just 5m or 00")
function RD.TotemTimer(k)
    RD.timers = RD.timers or {}
    local t = RD.timers[k]
    if t then return t end
    local spec = RD.TOTEM_TIMERS[k]
    t = CreateFrame("Button", nil, RD.conLayer, "SecureActionButtonTemplate")
    if t.RegisterForClicks then t:RegisterForClicks("AnyDown") end
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints(t)
    t.bg:SetColorTexture(0, 0, 0, 0.4)
    t.edges = edge(t, spec.col, 1.5)
    t.base = t:CreateTexture(nil, "BORDER")                 -- the remembered totem, dim
    t.base:SetPoint("TOPLEFT", t, "TOPLEFT", 2, -2)
    t.base:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 2, 2)
    if t.base.SetTexCoord then t.base:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    t.base:SetAlpha(RD.TIMER_DIM)
    t.icon = t:CreateTexture(nil, "ARTWORK")                -- the standing totem, the game's own icon
    t.icon:SetPoint("TOPLEFT", t, "TOPLEFT", 2, -2)
    t.icon:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 2, 2)
    if t.icon.SetTexCoord then t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    t:SetScript("OnEnter", function(self)
        if not self.totem and not combat() then RD.LearnTimers() end   -- not learned yet: try now (out of a fight)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.totem and self.totem:upper() or "TOTEM TIMER")
        GameTooltip:AddLine(self.totem and "Click: drop it again." or "Drop a totem out of a fight: this box remembers it.",
            1, 1, 1, true)
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    local okCd, cd = pcall(CreateFrame, "Cooldown", nil, t, "CooldownFrameTemplate")
    if okCd and cd then
        cd:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 2, 0)
        cd:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -2, 2)
        if cd.SetDrawSwipe then cd:SetDrawSwipe(false) end          -- the number only: a long box takes no round swipe
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
        -- THE FULL TIME, 4:59 (Arn, 15 Nov: "can we do a full timer 0:00"): the client writes "4m" above its abbreviation
        -- threshold; raised past a totem's 5 minutes, it writes minutes and seconds the whole way (still the client's
        -- number, so it holds in a fight). Not every client has the setting: then it stays "4m".
        if cd.SetCountdownAbbrevThreshold then pcall(cd.SetCountdownAbbrevThreshold, cd, RD.TIMER_FULL) end
        t.cd = cd
    end
    t.slot = spec.slot
    RD.timers[k] = t
    return t
end

--- A standing totem's name is its CREATURE's, rank and all ("Mana Spring Totem II"); the spell has no numeral. Off it comes,
--- and /cast picks your highest rank (16 Nov 2026, Arn: "water and earth totem still not drop when click" - his water and
--- earth were rank 2, air and fire rank 1).
function RD.TotemSpell(name)
    if type(name) ~= "string" then return nil end
    local bare = name:gsub("%s+[IVX]+$", "")
    return bare ~= "" and bare or nil
end

--- Out of a fight: learn the standing totem's name for each slot (kept), and arm each box's click with its remembered one.
function RD.LearnTimers()
    if combat() or RD.inFight then return false end
    local d = db()
    d.totemSlots = type(d.totemSlots) == "table" and d.totemSlots or {}
    d.totemSetAt = nil                                            -- (an old save's clock times: never read again)
    for _, t in ipairs(RD.timers or {}) do
        local okI, _, name, start = pcall(GetTotemInfo, t.slot)
        name = okI and plain(name) or nil
        start = okI and plain(start) or nil
        -- (a totem standing from before a pick sent in by SetTotems - BiS Tools' combo - does not undo the pick)
        -- (RD.setAt is this session's only: GetTime counts from the PC's start, so a time kept in the save blocked the box
        -- forever after a restart - 20 Nov 2026, Arn: "earth totem always drops earth bind totem, yesterday it was working")
        local older = RD.setAt[t.slot] and type(start) == "number" and start < RD.setAt[t.slot]
        if type(name) == "string" and name ~= "" and not older then d.totemSlots[t.slot] = RD.TotemSpell(name) end
        local want = RD.TotemSpell(d.totemSlots[t.slot])          -- a name kept before this fix loses its numeral too
        t.totem = want
        t:SetAttribute("type1", want and "macro" or nil)
        t:SetAttribute("macrotext1", want and ("/cast " .. want) or nil)
        local tex
        if want and C_Spell and C_Spell.GetSpellTexture then
            local ok, x = pcall(C_Spell.GetSpellTexture, want)
            if ok then tex = x end
        end
        pcall(t.base.SetTexture, t.base, tex)
    end
    return true
end

--[[ A TOTEM SET SENT IN (18 Nov 2026, Arn: "can we API-send the totems to BiS Healing's totem click areas - it's having me
  test a new totem setup, I click something and it changes the totems on my BiS Healing deck - out of combat of course"):
  `set` = { [slot] = "Spell Name" } (1 fire, 2 earth, 3 water, 4 air; a slot left out is left alone, false clears it). The
  boxes drop the new ones from the next click; a totem already standing from before does not undo it (RD.setAt, this
  session's GetTime - never saved - compared with the standing one's start). Out of a fight only (secure writes). Answers true, or nil and why. ]]
RD.SLOT_OF = { fire = 1, earth = 2, water = 3, air = 4 }
RD.setAt = {}                                                     -- [slot] = GetTime of a set sent in, this session only
function RD.SetTotems(set)
    if combat() or RD.inFight then return nil, "in a fight" end
    if type(set) ~= "table" then return nil, "no totems" end
    local d = db()
    d.totemSlots = type(d.totemSlots) == "table" and d.totemSlots or {}
    local now = GetTime and GetTime() or 0
    local n = 0
    for k, v in pairs(set) do
        local slot = RD.SLOT_OF[k] or tonumber(k)
        if slot and slot >= 1 and slot <= 4 then
            if v == false then d.totemSlots[slot] = nil
            elseif type(v) == "string" and v ~= "" then d.totemSlots[slot] = RD.TotemSpell(v) end
            RD.setAt[slot] = now
            n = n + 1
        end
    end
    if n == 0 then return nil, "no totems" end
    RD.LearnTimers()
    return true
end

--- One timer box from its slot: the icon untouched, the game's own countdown (or nothing for an empty slot).
function RD.PaintTimer(t)
    if not (t and t:IsShown()) then return false end
    local okI, _, _, start, dur, icon = pcall(GetTotemInfo, t.slot)
    pcall(t.icon.SetTexture, t.icon, okI and icon or nil)
    local cd = t.cd
    if not cd then return okI end
    local obj
    if GetTotemDuration then
        local ok, o = pcall(GetTotemDuration, t.slot)
        if ok then obj = o end
    end
    if obj and cd.SetCooldownFromDurationObject and pcall(cd.SetCooldownFromDurationObject, cd, obj) then return true end
    local st, d = nil, nil
    if okI then
        st = plain(start)
        d = plain(dur)
    end
    if type(st) == "number" and type(d) == "number" and d > 0 and cd.SetCooldown then
        cd:SetCooldown(st, d)
    elseif cd.Clear then
        cd:Clear()
    end
    return true
end
function RD.PaintTimers()
    for _, t in ipairs(RD.timers or {}) do RD.PaintTimer(t) end
end

--[[ WHERE THE NUMBER GOES (16 Nov 2026, Arn's screenshots: "3m" drawn over the totem's icon in a narrow window). The
  client centres its countdown in the Cooldown frame and writes it at its own size, so a strip narrower than the number
  spills over the icon. With room (RD.TIMER_ROOM) the number stays beside the icon; without, it sits ON the icon, small
  and outlined, the way an action button shows its cooldown. ]]
RD.TIMER_ROOM = 22                                  -- px beside the icon a "4:59" / "3m" needs
RD.TIMER_FONT = 10                                  -- the number's size when it sits on the icon
function RD.TimerSpot(t, tw)
    local cd = t and t.cd
    if not cd then return nil end
    local room = (tonumber(tw) or 0) - (RD.SYS_PX - 4) - 6
    local on = room < RD.TIMER_ROOM
    cd:ClearAllPoints()
    if on then
        cd:SetPoint("TOPLEFT", t.icon, "TOPLEFT", 0, 0)
        cd:SetPoint("BOTTOMRIGHT", t.icon, "BOTTOMRIGHT", 0, 0)
    else
        cd:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 2, 0)
        cd:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -2, 2)
    end
    -- the client's own number: a smaller font on the icon, its own beside it
    if cd.GetRegions then
        for _, reg in ipairs({ cd:GetRegions() }) do
            if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" and reg.SetFont then
                if not t.numFont and reg.GetFont then t.numFont = { reg:GetFont() } end
                local f = t.numFont or {}
                if on then
                    pcall(reg.SetFont, reg, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", RD.TIMER_FONT, "OUTLINE")
                elseif f[1] then
                    pcall(reg.SetFont, reg, f[1], f[2], f[3])
                end
            end
        end
    end
    t.numOnIcon = on
    return on
end

--- The deck's totem row: the totem buttons you know at its left, then the four timers to its right edge. Answers the height
--- it took (0 = no totems: nothing shown).
function RD.DeckTotemRow(W, top)
    local list = {}
    for _, b in ipairs(RD.TOTEMS or {}) do if b.macro then list[#list + 1] = b end end
    for k = 1, 3 do if RD.conSquares and RD.conSquares["totem" .. k] then RD.conSquares["totem" .. k]:Hide() end end
    for k = 1, #RD.TOTEM_TIMERS do if RD.timers and RD.timers[k] then RD.timers[k]:Hide() end end
    if #list == 0 then return 0 end
    local wantB, wantT = RD.Sw("totems"), RD.Sw("timers")
    if not wantB then for _, b in ipairs(list) do b:Hide() end end
    if not (wantB or wantT) then return 0 end
    -- STACKED (16 Nov 2026, Arn: "even if it means we stack the totem timers / call move recall / air water / earth fire"):
    -- narrower than the one-line row, or with one of the two switched off - the buttons on a line, then two timers a line
    if not (wantB and wantT) or W < RD.TotemWideW() then return RD.DeckTotemStack(W, top, list, wantB, wantT) end
    local y = top - RD.SYS_PX - RD.CON.gap + RD.SYS_PX / 2   -- the one-line row's own reckoning: `y` = the row above's middle
    -- SPLIT DOWN THE MIDDLE (Arn, 15 Nov: "totem bar can we split totem down the middle and put the call recall and bring
    -- in the center"): air and water on the left, CALL / BRING / RECALL in the middle, earth and fire on the right - each
    -- pair of timers stretched over its half. No square round the buttons (the deck's icons are dim or bright alone).
    local C, gap = RD.CON, RD.CON.toolGap
    local y6 = y + RD.SYS_PX + C.gap
    local bw = #list * RD.SYS_PX + (#list - 1) * gap
    local bl = (W - bw) / 2                              -- the buttons' left edge, centred
    for k, b in ipairs(list) do
        at(b, bl + RD.SYS_PX / 2 + (k - 1) * (RD.SYS_PX + gap), y6)
    end
    local sideGap = 4
    local leftW = bl - sideGap - C.pad                  -- each half's room for its two timers
    local tw = math.floor((leftW - gap) / 2)
    local starts = { C.pad, C.pad + tw + gap, bl + bw + sideGap, bl + bw + sideGap + tw + gap }   -- air, water | earth, fire
    for k = 1, #RD.TOTEM_TIMERS do
        local t = RD.TotemTimer(k)
        t:SetSize(tw, RD.SYS_PX)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", RD.frame, "TOPLEFT", starts[k], -(y6 - RD.SYS_PX / 2))
        t.icon:SetWidth(RD.SYS_PX - 4)
        t.base:SetWidth(RD.SYS_PX - 4)
        RD.TimerSpot(t, tw)
        -- the engineer's view: "5m", then seconds (Arn: "no 0:00 timer just 5m or 00"); the deck: 4:59 the whole way
        local cd = t.cd
        if cd and cd.SetCountdownAbbrevThreshold then
            pcall(cd.SetCountdownAbbrevThreshold, cd, RD.Compact() and RD.TIMER_SHORT or RD.TIMER_FULL)
        end
        t:Show()
    end
    RD.LearnTimers()                                   -- each box's remembered totem, and its click
    RD.PaintTimers()
    return RD.SYS_PX + C.gap
end

--- The totems stacked: CALL / BRING / RECALL centred on a line (if on), then air + water, then earth + fire (if on), each
--- pair across the whole width. Answers the height taken, with the gap under it.
function RD.DeckTotemStack(W, top, list, wantB, wantT)
    local C, gap, S = RD.CON, RD.CON.toolGap, RD.SYS_PX
    local y = top
    if wantB then
        local bw = #list * S + (#list - 1) * gap
        local bl = (W - bw) / 2
        for k, b in ipairs(list) do at(b, bl + S / 2 + (k - 1) * (S + gap), y + S / 2) end
        y = y + S + C.gap
    end
    if wantT then
        local inner = W - 2 * C.pad
        local tw = math.floor((inner - gap) / 2)
        for k = 1, #RD.TOTEM_TIMERS do
            local t = RD.TotemTimer(k)
            local line, col = math.ceil(k / 2), (k - 1) % 2       -- air, water | earth, fire
            local w = (col == 0) and tw or (inner - tw - gap)
            t:SetSize(w, S)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", RD.frame, "TOPLEFT", C.pad + col * (tw + gap), -(y + (line - 1) * (S + C.gap)))
            t.icon:SetWidth(S - 4)
            t.base:SetWidth(S - 4)
            RD.TimerSpot(t, w)
            if t.cd and t.cd.SetCountdownAbbrevThreshold then
                pcall(t.cd.SetCountdownAbbrevThreshold, t.cd, (w < 60) and RD.TIMER_SHORT or RD.TIMER_FULL)
            end
            t:Show()
        end
        y = y + 2 * (S + C.gap)
        RD.LearnTimers()
        RD.PaintTimers()
    end
    return y - top
end

--- Put everything on the grid. Out of a fight only (RD.Arm calls it). Answers the grid.
function RD.ConsoleLayout()
    local f = RD.frame
    if not f or combat() then return nil end
    local C, G = RD.CON, RD.ConsoleGrid()
    if not RD.conLayer then
        RD.conLayer = CreateFrame("Frame", nil, f)
        RD.conLayer:SetAllPoints(f)
        RD.conLayer:SetFrameLevel(math.max(0, f:GetFrameLevel()))
    end
    RD.conLayer:Show()
    for _, q in pairs(RD.conSquares or {}) do q:Hide() end
    if RD.deckBox then RD.deckBox:Hide() end
    RD.DeckClear()                                   -- the deck puts back the ones it places
    local T = RD.ConsoleTier()
    local order = RD.conOrder or {}
    if RD.Deck() then
        RD.conGrid = RD.DeckLayout(T, order)
        return RD.conGrid
    end
    if T.n > 5 then
        RD.conGrid = RD.ConsoleLayoutWide(T, order)
        return RD.conGrid
    end
    f:SetSize(G.W, G.H)
    -- THE FIGHTER: one row, the first in rank (you) in the middle, the rest outward (Arn: "from the center out")
    for k = 1, RD.SPOKES do
        local i = order[k] or k
        local x = G.cols[RD.CENTER_OUT[k]]
        local sp = RD.spokes[i]
        at(square("heal" .. k, C.sq, RD.BAND_COL.core), x, G.rows[1])   -- the fighter: all five are the core
        at(square("kick" .. k, C.sq), x, G.rows[3])
        at(square("pet" .. k, C.sq), x, G.rows[4])
        if sp then
            sp.heal:SetSize(C.sq, C.sq)
            at(sp.heal, x, G.rows[1])
            if sp.bogey then sp.bogey:SetSize(C.sq, C.sq) at(sp.bogey, x, G.rows[3]) end
            settle(sp)
            -- the cures side by side under the person
            local n = #(sp.cures or {})
            for j, c in ipairs(sp.cures or {}) do
                local off = (j - (n + 1) / 2) * (C.cure + 6)
                at(square("cure" .. k .. "-" .. j, C.cure + 4), x + off, G.rows[2])
                if not c.cure then RD.conSquares["cure" .. k .. "-" .. j]:Hide() end
                at(c.box, x + off, G.rows[2])
                if c.container then c.container:ClearAllPoints() c.container:SetPoint("CENTER", c.box, "CENTER") end
            end
            if sp.pet then sp.pet:SetSize(C.pet, C.pet) at(sp.pet, x, G.rows[4]) end
        end
    end
    -- row 5: every tool from both rails, centred
    toolsRow(G.W, G.rows[5])
    local extra = totemRow(G.W, G.rows[5])
    if extra > 0 then
        G.H = G.H + extra
        f:SetSize(G.W, G.H)
    end
    G.tier = T
    RD.conGrid = G
    return G
end

--- The radar's own places back: the tools to their rails (where RD.Build put them), the console's squares away.
function RD.RadarLayout()
    if combat() then return false end
    for _, b in ipairs({ RD.shield, RD.tide, RD.potion, RD.reserve, RD.fuel, RD.rations, RD.chaff, RD.res,
                         RD.call, RD.tcall, RD.recall }) do
        local h = b and b.home
        if h then b:ClearAllPoints() b:SetPoint(h[1], h[2], h[3], h[4], h[5]) end
    end
    if RD.conLayer then RD.conLayer:Hide() end
    if RD.deckBox then RD.deckBox:Hide() end          -- the deck's target box goes with the console's layer
    RD.DeckClear()
    return true
end

--- What steps aside in the console (the scope, the disc, the rails, the tape, the black box) comes back on the radar.
function RD.ApplyView()
    local con = RD.Console()
    local function vis(fr, on) if fr then if on then fr:Show() else fr:Hide() end end end
    vis(RD.scope, not con)
    vis(RD.fade, not con)
    vis(RD.dims, not con)
    vis(RD.toolRail, not con)
    vis(RD.gaugeRail, not con)
    vis(RD.defRail, not con)
    vis(RD.bbRail, not con or (RD.Deck() and RD.Sw("bb")))   -- the deck keeps the black box (Arn: "dont forget my black box"), unless switched off
    vis(RD.gauge, not con)
    -- the tape's pieces that hang on the radar frame itself: the regen readout, its chevron, the ramjet
    local g = RD.gauge
    if g then vis(g.regen, not con) vis(g.chev, not con) vis(g.fsr, not con) end
    RD.PlaceViewButton()
    RD.ClampRails()
end

--- The two buttons: the CLASS (5 / 10 / 20 / 40) over the VIEW (radar / engineer) at the right rail's foot on the radar;
--- side by side in the console's top-right corner.
function RD.PlaceViewButton()
    local b, c, f = RD.viewBtn, RD.classBtn, RD.frame
    if not (b and f) then return end
    b:ClearAllPoints()
    if c then c:ClearAllPoints() end
    if RD.Console() then
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
        b:SetSize(12, 12)
        if c then c:SetPoint("TOPRIGHT", b, "TOPLEFT", -3, 0) c:SetSize(12, 12) end
    else
        b:SetPoint("BOTTOM", RD.defRail or f, "BOTTOM", 0, 8)
        b:SetSize(RD.SYS_PX, RD.SYS_PX)
        if c then c:SetPoint("BOTTOM", b, "TOP", 0, 4) c:SetSize(RD.SYS_PX, RD.SYS_PX) end
    end
    if c then c:SetShown(not RD.Deck()) end                -- the deck and the engineer size themselves: no size button
    RD.PaintViewButton()
    RD.PlaceTopGrip()
end

--[[ THE TOP GRIP (17 Nov 2026, Arn: "make bis healing easier to drag and move from the header"). The deck has no title bar - its
  top strip holds the alert boxes, which take no mouse, so a drag there fell through to the window only in the gaps the
  boxes and the pad left. Now the whole strip (the pad above it included) is one grab band over them, up to the switches
  button in the corner: it washes on hover with a bar on the left (every row that does something pops), says so in a
  tooltip, and drags the window like the background does - out of a fight only, ended before one (endDrag). ]]
RD.GRIP_RIGHT = 34                                  -- (left free at the right: the switches button)
function RD.BuildTopGrip(f)
    if RD.topGrip or not f then return RD.topGrip end
    local g = CreateFrame("Frame", nil, f)
    g:SetFrameLevel(f:GetFrameLevel() + 12)           -- (over the strip, under the switches button at +14)
    g:EnableMouse(true)
    g:RegisterForDrag("LeftButton")
    local c = RD.PHOS
    g.wash = g:CreateTexture(nil, "HIGHLIGHT")
    g.wash:SetAllPoints(g)
    g.wash:SetTexture(RD.WHITE)
    g.wash:SetVertexColor(c[1], c[2], c[3], 0.10)
    g.bar = g:CreateTexture(nil, "HIGHLIGHT")
    g.bar:SetPoint("TOPLEFT") g.bar:SetPoint("BOTTOMLEFT")
    g.bar:SetWidth(2)
    g.bar:SetTexture(RD.WHITE)
    g.bar:SetVertexColor(c[1], c[2], c[3], 0.9)
    g:SetScript("OnDragStart", function() local st = f:GetScript("OnDragStart") if st then st(f) end end)
    g:SetScript("OnDragStop", function() endDrag(f) end)
    g:SetScript("OnHide", function() endDrag(f) end)
    g:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("BiS> Healing")
        if combat() then GameTooltip:AddLine("Not while the fight is on.", 0.94, 0.55, 0.69)
        else GameTooltip:AddLine("Drag to move the window.", 0.86, 0.84, 0.92) end
        GameTooltip:Show()
    end)
    g:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    RD.topGrip = g
    return g
end
--- The grip over the deck's top strip (the console's views); away on the radar.
function RD.PlaceTopGrip()
    local g, f = RD.topGrip, RD.frame
    if not (g and f) then return end
    if not (RD.Console and RD.Console()) then g:Hide() return end
    local C = RD.CON or {}
    local head = (RD.Deck() and RD.DeckHead and RD.DeckHead()) or C.head or 14
    -- UP OVER THE MANA STRIP TOO (17 Nov, Arn: "i thought it was higher" - only the mana bar itself dragged up there):
    -- the band starts at the window's very top, the strip above the console (EN.GaugeTop) included; the mana tape keeps
    -- its tooltip, lifted over the band
    local up = (NS.EN and NS.EN.GaugeTop and NS.EN.GaugeTop()) or 0
    g:ClearAllPoints()
    g:SetPoint("TOPLEFT", f, "TOPLEFT", 0, up)
    g:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RD.GRIP_RIGHT, up)
    g:SetHeight((C.pad or 8) + head + up)
    local tape = RD.gauge
    if tape and tape.GetFrameLevel and tape:GetFrameLevel() <= g:GetFrameLevel() then
        pcall(tape.SetFrameLevel, tape, g:GetFrameLevel() + 1)
    end
    g:Show()
end

function RD.PaintViewButton()
    local b = RD.viewBtn
    if not b then return end
    -- since 15 Nov the two sides are the DECK and the engineer's view (the radar disc retired): a drawn sign of where the
    -- click goes - four small squares (the engineer's view), a ring (back to the deck)
    local con = RD.EngineerView() == true
    for _, t in ipairs(b.grid) do t:SetAlpha(con and 0 or 1) end
    for _, l in ipairs(b.ring) do l:SetAlpha(con and 1 or 0) end
    b.tip = con and { "ENGINEER VIEW", "Click: back to the deck.  Out of a fight." }
            or { "DECK", "Click: the engineer's view - the same buttons on a plain grid.  Out of a fight." }
    if RD.Deck() and not con then                     -- one window since 16 Nov: the button opens its switches
        b.tip = { "SWITCHES", "Click: what this window shows - names, kicks, cures, totems, the black box..." }
    end
    local c = RD.classBtn
    if c then
        local T, k = RD.ConsoleTier()
        for j, t in ipairs(c.dots) do t:SetAlpha(j <= k and 1 or 0.18) end
        local nk = k % #RD.CON_TIERS + 1
        local nT = RD.CON_TIERS[nk]
        c.tip = { T.name, "Click: " .. nT.name .. " - the next group size, in any group (a preview; a size too small "
                  .. "for your group is skipped).  Out of a fight." }
    end
end

--- One click on the view button: radar <-> the engineer's view, the class kept. Refused in a fight (the radar holds
--- secure buttons). Answers "radar" or "console".
function RD.ToggleView()
    if combat() or RD.inFight then return nil end
    local d = db()
    d.view = (d.view ~= "console") and "console" or nil
    RD.Arm()
    return d.view and "console" or "radar"
end

--- One click on the class button: the next class - fighter, gunship, cruiser, capital, round again (Arn: "let me click
--- them even if i am not in that size party or raid"); a class too small for the group is skipped. Answers its name.
function RD.NextClass()
    if combat() or RD.inFight then return nil end
    local _, k = RD.ConsoleTier()
    db().tier = k % #RD.CON_TIERS + 1
    RD.Arm()
    return RD.ConsoleTier().name
end

-- a small square button with the hover pop, a drawn sign and a tooltip
local function smallButton(f, onClick)
    local b = CreateFrame("Button", nil, f)
    b:SetFrameLevel(f:GetFrameLevel() + 14)
    local c = RD.PHOS
    b.edges = edge(b, { c[1] * 0.6, c[2] * 0.6, c[3] * 0.6, 1 }, 1)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.hl:SetTexture(RD.WHITE)
    b.hl:SetVertexColor(c[1], c[2], c[3], 0.22)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        local tip = self.tip
        if not (tip and GameTooltip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(tip[1])
        GameTooltip:AddLine(tip[2], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return b
end

--- The class button: four dots in a row, as many lit as the class (1 fighter .. 4 capital).
function RD.BuildClassButton(f)
    if RD.classBtn or not f then return RD.classBtn end
    local b = smallButton(f, function() RD.NextClass() end)
    local c = RD.PHOS
    b.dots = {}
    for j = 1, 4 do
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetTexture(RD.WHITE)
        t:SetVertexColor(c[1], c[2], c[3], 1)
        t:SetSize(2, 2)
        t:SetPoint("CENTER", b, "CENTER", (j - 2.5) * 3, 0)
        b.dots[j] = t
    end
    RD.classBtn = b
    return b
end

function RD.BuildViewButton(f)
    if RD.viewBtn or not f then return RD.viewBtn end
    local b = CreateFrame("Button", nil, f)
    b:SetFrameLevel(f:GetFrameLevel() + 14)
    local c = RD.PHOS
    b.edges = edge(b, { c[1] * 0.6, c[2] * 0.6, c[3] * 0.6, 1 }, 1)
    b.grid = {}
    for _, o in ipairs({ { -3, 3 }, { 3, 3 }, { -3, -3 }, { 3, -3 } }) do
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetTexture(RD.WHITE)
        t:SetVertexColor(c[1], c[2], c[3], 1)
        t:SetSize(4, 4)
        t:SetPoint("CENTER", b, "CENTER", o[1], o[2])
        b.grid[#b.grid + 1] = t
    end
    b.ring = {}
    for k = 1, 12 do
        local a0, a1 = (k - 1) * math.pi / 6, k * math.pi / 6
        b.ring[k] = line(b, "OVERLAY", math.sin(a0) * 4, math.cos(a0) * 4, math.sin(a1) * 4, math.cos(a1) * 4, c, 1)
    end
    -- it pops on hover (every clickable thing does)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.hl:SetTexture(RD.WHITE)
    b.hl:SetVertexColor(c[1], c[2], c[3], 0.22)
    b:SetScript("OnClick", function(self)
        if RD.Deck() and not RD.EngineerView() then RD.ToggleSwitches() return end
        RD.ToggleView()
        -- the tooltip says where the NEXT click goes: written again at once (Arn's screenshot, 15 Nov: still "DECK - click:
        -- the engineer's view" while the engineer's view showed)
        local onEnter = self.GetScript and self:GetScript("OnEnter")
        if onEnter and GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then onEnter(self) end
    end)
    b:SetScript("OnEnter", function(self)
        local tip = self.tip
        if not (tip and GameTooltip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(tip[1])
        GameTooltip:AddLine(tip[2], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    RD.viewBtn = b
    RD.PlaceViewButton()
    return b
end

--[[ THE SWITCHES PANEL (16 Nov 2026). Beside the window, from its switches button: BARE / LEAN / FULL on top, then a row
  per switch in its group. Every row glows on hover (wash + left bar, the family rule) and is scaled up for a small window.
  A click switches it; in a fight it is saved and laid out when the fight ends (the row says so). Esc closes it. ]]
RD.SW_ROW_H = 18
RD.SW_W = 210
local function swWash(row, on)
    if row.wash then row.wash:SetShown(on) end
    if row.bar then row.bar:SetShown(on) end
end
--- ONLY WHAT YOUR CLASS CAN ACT ON (Arn, 21 Nov 2026, BiS>Cues: "we wont see ones that arent our class that we cant act on
--- like oath and light vigil"): a switch in a class's group (SHAMAN / PALADIN / DRUID / PRIEST), or carrying `class`,
--- shows on that class's panel only. Class unknown: shown. `/bish cues all` (NS.CU.showAll) shows all, for testing.
local SW_CLASS_GROUP = { SHAMAN = true, PALADIN = true, DRUID = true, PRIEST = true }
function RD.SwForMe(s)
    local cls = s.class or (SW_CLASS_GROUP[s.group] and s.group) or nil
    if not cls then return true end
    local CU = NS.CU
    if CU and CU.showAll then return true end
    local mine = CU and CU.MyClass and CU.MyClass()
    return mine == nil or mine == cls
end
--- A switch row in the DECK list: yours (RD.SwForMe) and not a cue - a cue lives on the CUES / DEBUFFS tabs only (Arn,
--- 24 Nov, sketch B: "One window, three tabs"; the seven rows that were both a switch and a cue). Cues.lua sets RD.SwOwned.
function RD.SwInList(s)
    return RD.SwForMe(s) and not (RD.SwOwned and RD.SwOwned(s.key))
end

--- THE DECK TAB'S COLUMNS (24 Nov 2026): the panel lives inside BiS Cues' window now (Cues.lua, CU.Host), so its rows flow
--- into columns `colW` wide from the top of the panel down to `bottom` (a negative y): the presets and the two sliders top
--- the first column, then the heads and rows in their order (a head never ends a column), RESET last. Answers the number
--- of columns used and whether it all fit in `maxCols`.
function RD.FlowSwitches(p, colW, bottom, maxCols)
    if not (p and p.flow) then return 0, false end
    colW = colW or RD.SW_W
    local gap = 8
    local pw = math.floor((colW - 16 - 8) / 3)
    for k, name in ipairs(RD.SW_ORDER) do
        local b = p.presets and p.presets[name]
        if b then b:ClearAllPoints() b:SetSize(pw, 18) b:SetPoint("TOPLEFT", p, "TOPLEFT", 8 + (k - 1) * (pw + 4), -4) end
    end
    local sy = -28
    for _, key in ipairs({ "width", "height" }) do
        local sl = p.sliders and p.sliders[key]
        if sl then sl:ClearAllPoints() sl:SetPoint("TOPLEFT", p, "TOPLEFT", 64, sy - 4) sy = sy - 18 end
    end
    local col, x, y = 1, 0, sy - 4
    local items = {}
    for _, it in ipairs(p.flow) do items[#items + 1] = it end
    if p.reset then items[#items + 1] = { el = p.reset, h = 24, reset = true } end
    for i, it in ipairs(items) do
        local need = it.h + ((it.head and items[i + 1]) and items[i + 1].h or 0)   -- a head takes its first row along
        if y - need < bottom and y < -8 then
            col = col + 1
            x, y = (col - 1) * (colW + gap), -4
        end
        it.el:ClearAllPoints()
        if it.head then it.el:SetPoint("TOPLEFT", p, "TOPLEFT", x + 8, y - 3)
        elseif it.reset then it.el:SetSize(colW - 16, 18) it.el:SetPoint("TOPLEFT", p, "TOPLEFT", x + 8, y - 6)
        else it.el:SetSize(colW - 8, RD.SW_ROW_H) it.el:SetPoint("TOPLEFT", p, "TOPLEFT", x + 4, y) end
        y = y - it.h
    end
    return col, col <= (maxCols or col)
end

function RD.BuildSwitches()
    if RD.swPanel then return RD.swPanel end
    local c = RD.PHOS
    local p = CreateFrame("Frame", "BiSHealingSwitches", UIParent)
    p:SetFrameStrata("DIALOG")
    p:SetScale(1.2)
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p.bg = p:CreateTexture(nil, "BACKGROUND")
    p.bg:SetAllPoints(p)
    local P = RD.PLATE or { 0.05, 0.04, 0.09 }
    p.bg:SetColorTexture(P[1], P[2], P[3], 0.97)
    p.edges = edge(p, { c[1] * 0.6, c[2] * 0.6, c[3] * 0.6, 1 }, 1)
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    p.title = p:CreateFontString(nil, "OVERLAY")
    p.title:SetFont(font, 11, "")
    p.title:SetTextColor(c[1], c[2], c[3], 1)
    p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -7)
    p.title:SetText("SWITCHES")
    p.note = p:CreateFontString(nil, "OVERLAY")
    p.note:SetFont(font, 9, "")
    p.note:SetTextColor(1, 0.75, 0.3, 1)
    p.note:SetPoint("LEFT", p.title, "RIGHT", 8, 0)
    local close = CreateFrame("Button", nil, p)
    close:SetSize(14, 14)
    close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -4)
    close.x = close:CreateFontString(nil, "OVERLAY")
    close.x:SetFont(font, 11, "")
    close.x:SetPoint("CENTER")
    close.x:SetText("x")
    close.hl = close:CreateTexture(nil, "HIGHLIGHT")
    close.hl:SetAllPoints(close)
    close.hl:SetColorTexture(c[1], c[2], c[3], 0.22)
    close:SetScript("OnClick", function() p:Hide() end)
    p.closeB = close
    -- the three presets
    p.presets = {}
    local pw = math.floor((RD.SW_W - 16 - 8) / 3)
    for k, name in ipairs(RD.SW_ORDER) do
        local b = CreateFrame("Button", nil, p)
        b:SetSize(pw, 18)
        b:SetPoint("TOPLEFT", p, "TOPLEFT", 8 + (k - 1) * (pw + 4), -24)
        b.edges = edge(b, { c[1] * 0.5, c[2] * 0.5, c[3] * 0.5, 1 }, 1)
        b.text = b:CreateFontString(nil, "OVERLAY")
        b.text:SetFont(font, 10, "")
        b.text:SetPoint("CENTER")
        b.text:SetText(RD.SW_WORD[name])
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints(b)
        b.hl:SetColorTexture(c[1], c[2], c[3], 0.25)
        b.preset = name
        b:SetScript("OnClick", function() RD.SwPreset(name) end)
        p.presets[name] = b
    end
    -- THE SLIDERS: the width (the same as Shift + drag on the corner) and the boxes' height. Laid out again at most every
    -- RD.WIDTH_EVERY seconds while dragging, and once more when let go. Right-click one: back to its own.
    p.sliders = {}
    local function slider(key, label, y, lo, hi, step, get, set, unit)
        local s = CreateFrame("Slider", nil, p)
        s:SetOrientation("HORIZONTAL")
        s:SetSize(RD.SW_W - 16 - 56 - 44, 12)
        s:SetPoint("TOPLEFT", p, "TOPLEFT", 64, y - 4)
        s:SetMinMaxValues(lo, hi)
        s:SetValueStep(step)
        if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
        s:EnableMouse(true)
        s.track = s:CreateTexture(nil, "BACKGROUND")
        s.track:SetPoint("LEFT") s.track:SetPoint("RIGHT") s.track:SetHeight(3)
        s.track:SetColorTexture(c[1] * 0.4, c[2] * 0.4, c[3] * 0.4, 1)
        local th = s:CreateTexture(nil, "OVERLAY")
        th:SetColorTexture(1, 0.31, 0.66, 1)
        th:SetSize(6, 12)
        s:SetThumbTexture(th)
        s.label = s:CreateFontString(nil, "OVERLAY")
        s.label:SetFont(font, 9, "")
        s.label:SetTextColor(0.85, 0.85, 0.9, 1)
        s.label:SetPoint("RIGHT", s, "LEFT", -6, 0)
        s.label:SetText(label)
        s.value = s:CreateFontString(nil, "OVERLAY")
        s.value:SetFont(font, 9, "")
        s.value:SetTextColor(c[1], c[2], c[3], 1)
        s.value:SetPoint("LEFT", s, "RIGHT", 6, 0)
        s.get, s.set, s.unit, s.last = get, set, unit, 0
        local function apply(self, now)
            if combat() or RD.inFight then return end
            if not now and (GetTime() - self.last) < RD.WIDTH_EVERY then self.dirty = true return end
            self.last, self.dirty = GetTime(), nil
            if RD.Active() then RD.Arm() end
        end
        s:SetScript("OnValueChanged", function(self, v, user)
            if self.painting then return end
            v = math.floor((tonumber(v) or 0) / step + 0.5) * step
            self.value:SetText(v .. self.unit)
            if user == false then return end
            self.set(v)
            apply(self, false)
        end)
        s:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then self.set(nil) RD.PaintSwitches() end
            apply(self, true)
            RD.PaintSwitches()
        end)
        s:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label)
            GameTooltip:AddLine("Drag to change it.  Right-click: back to its own.  Out of a fight.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        s:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        p.sliders[key] = s
        return s
    end
    slider("width", "WIDTH", -48, RD.FloorInner(), 800, 2,
        function() return RD.DeckWidth() or tonumber(RD.deckInnerW) or 382 end,
        function(v) RD.SetDeckWidth(v) end, " px")
    slider("height", "BOX HEIGHT", -66, RD.BOX_H_MIN, RD.BOX_H_MAX, RD.BOX_H_STEP,
        function() return RD.BoxHeight() end,
        function(v) RD.SetBoxHeight(v) end, "%")
    -- a row per switch, under its group's word
    p.rows = {}
    local y, group = -88, nil
    local list = {}
    for _, s in ipairs(RD.SW) do if RD.SwInList(s) then list[#list + 1] = s end end
    p.flow = {}                                                -- heads, rows and the sort row in order (RD.FlowSwitches)
    for _, s in ipairs(list) do
        if s.group ~= group then
            group = s.group
            local h = p:CreateFontString(nil, "OVERLAY")
            h:SetFont(font, 8, "")
            h:SetTextColor(1, 0.7, 0.28, 1)
            h:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y - 3)
            h:SetText(group)
            p.flow[#p.flow + 1] = { el = h, h = 14, head = true }
            y = y - 14
        end
        local row = CreateFrame("Button", nil, p)
        row:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
        row:SetSize(RD.SW_W - 8, RD.SW_ROW_H)
        row.wash = row:CreateTexture(nil, "BACKGROUND")
        row.wash:SetAllPoints(row)
        row.wash:SetColorTexture(c[1], c[2], c[3], 0.14)
        row.wash:Hide()
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetPoint("TOPLEFT", row, "TOPLEFT")
        row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
        row.bar:SetWidth(2)
        row.bar:SetColorTexture(1, 0.31, 0.66, 1)
        row.bar:Hide()
        row.box = CreateFrame("Frame", nil, row)
        row.box:SetSize(11, 11)
        row.box:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.box.edges = edge(row.box, { c[1] * 0.7, c[2] * 0.7, c[3] * 0.7, 1 }, 1)
        row.box.fill = row.box:CreateTexture(nil, "ARTWORK")
        row.box.fill:SetPoint("TOPLEFT", row.box, "TOPLEFT", 2, -2)
        row.box.fill:SetPoint("BOTTOMRIGHT", row.box, "BOTTOMRIGHT", -2, 2)
        row.box.fill:SetColorTexture(c[1], c[2], c[3], 1)
        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetFont(font, 10, "")
        row.text:SetPoint("LEFT", row.box, "RIGHT", 7, 0)
        row.text:SetText(s.name)
        row.key = s.key
        row:SetScript("OnClick", function() RD.SetSw(s.key, not RD.Sw(s.key)) end)
        row:SetScript("OnEnter", function(self)
            swWash(self, true)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(s.name:upper())
                GameTooltip:AddLine(s.tip, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self) swWash(self, false) if GameTooltip then GameTooltip:Hide() end end)
        p.rows[#p.rows + 1] = row
        p.flow[#p.flow + 1] = { el = row, h = RD.SW_ROW_H }
        y = y - RD.SW_ROW_H
        if s.key == "cols" then
            y = RD.BuildSortRow(p, y, font)                            -- the sort: one row that cycles (sheet 6)
            p.flow[#p.flow + 1] = { el = p.sortRow, h = RD.SW_ROW_H }
        end
    end
    local reset = CreateFrame("Button", nil, p)
    reset:SetSize(RD.SW_W - 16, 18)
    reset:SetPoint("TOPLEFT", p, "TOPLEFT", 8, y - 6)
    reset.edges = edge(reset, { 1, 0.7, 0.28, 0.6 }, 1)
    reset.text = reset:CreateFontString(nil, "OVERLAY")
    reset.text:SetFont(font, 10, "")
    reset.text:SetTextColor(1, 0.75, 0.3, 1)
    reset.text:SetPoint("CENTER")
    reset.text:SetText("RESET")
    reset.hl = reset:CreateTexture(nil, "HIGHLIGHT")
    reset.hl:SetAllPoints(reset)
    reset.hl:SetColorTexture(1, 0.7, 0.28, 0.22)
    reset:SetScript("OnClick", function() RD.SwReset() end)
    reset:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("RESET")
        GameTooltip:AddLine("Everything on, the window's own width, boxes and window at 100%.  The raid layout back to its own: no group tags, groups as rows, tanks then groups.  Out of a fight.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    p.reset = reset
    y = y - 6 - 18
    p:SetSize(RD.SW_W, -y + 8)
    p:Hide()
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "BiSHealingSwitches") end   -- Esc closes it
    RD.swPanel = p
    return p
end
--- THE SORT ROW (21 Nov 2026, BiS Cues sheet 6): one row, a click moves to the next sort (RD.NextSort); its words say the
--- sort now. Kept as p.sortRow, apart from p.rows (those are the on/off switches). Answers the next row's y.
function RD.BuildSortRow(p, y, font)
    local c = RD.PHOS
    local row = CreateFrame("Button", nil, p)
    row:SetPoint("TOPLEFT", p, "TOPLEFT", 4, y)
    row:SetSize(RD.SW_W - 8, RD.SW_ROW_H)
    row.wash = row:CreateTexture(nil, "BACKGROUND")
    row.wash:SetAllPoints(row)
    row.wash:SetColorTexture(c[1], c[2], c[3], 0.14)
    row.wash:Hide()
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT")
    row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
    row.bar:SetWidth(2)
    row.bar:SetColorTexture(1, 0.31, 0.66, 1)
    row.bar:Hide()
    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetFont(font, 10, "")
    row.text:SetPoint("LEFT", row, "LEFT", 24, 0)
    row.text:SetTextColor(1, 1, 1, 1)
    row:SetScript("OnClick", function() RD.NextSort() end)
    row:SetScript("OnEnter", function(self)
        swWash(self, true)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("SORT")
            GameTooltip:AddLine("Click for the next order: tanks, then groups / by group / by class / by max health.  "
                .. "Picked out of a fight and kept for the whole fight, so a death never moves a box.", 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self) swWash(self, false) if GameTooltip then GameTooltip:Hide() end end)
    p.sortRow = row
    return y - RD.SW_ROW_H
end
--- The panel's ticks, the matching preset lit, and the fight note.
function RD.PaintSwitches()
    local p = RD.swPanel
    if not p then return false end
    local c = RD.PHOS
    if p.sortRow then p.sortRow.text:SetText("Sort: " .. RD.SORT_WORD[RD.DeckSort()]) end
    for _, row in ipairs(p.rows) do
        local on = RD.Sw(row.key)
        row.box.fill:SetShown(on)
        row.text:SetTextColor(on and 1 or 0.55, on and 1 or 0.55, on and 1 or 0.6, 1)
    end
    local now = RD.SwPresetNow()
    for name, b in pairs(p.presets) do
        local lit = name == now
        b.text:SetTextColor(lit and c[1] or 0.8, lit and c[2] or 0.8, lit and c[3] or 0.85, 1)
        for _, e in ipairs(b.edges) do e:SetVertexColor(c[1], c[2], c[3], lit and 1 or 0.35) end
    end
    p.note:SetText((combat() or RD.inFight) and "after this fight" or "")
    for _, s in pairs(p.sliders or {}) do
        local v = s.get()
        s.painting = true
        s:SetValue(v)
        s.painting = nil
        s.value:SetText(math.floor(v + 0.5) .. s.unit)
    end
    return true
end
--- The switches button: open the panel beside the window, or close it.
function RD.ToggleSwitches()
    local p = RD.BuildSwitches()
    if p:IsShown() then p:Hide() return false end
    p:ClearAllPoints()
    local f = RD.frame
    if f then p:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, 0) else p:SetPoint("CENTER") end
    RD.PaintSwitches()
    p:Show()
    return true
end

--- Where the hull reaches: the top-left of the gauge rail, the bottom-right of the bottom rail (or of the tool rail
--- without one), out over the right rail's column while it shows. The rings follow it.
--- How much wider the top and bottom rails run while the right rail shows (its column and the gap before it).
function RD.RightW()
    return (RD.defRail and RD.defRail:IsShown()) and (RD.RAIL_GAP + RD.TOOL_RAIL_W) or 0
end

--- THE SQUARE CLOSED (Arn, 10 Nov: "recenter all the stuff since we got extra space"): the gauge rail and the black
--- box's rail run over the right rail's column while it shows, and what they hold re-centres in the new width (the
--- tape between its placard and its ramjet, the black box's keypad at the right end). Out of it, back to the square.
function RD.FitWide()
    local f = RD.frame
    if not f then return end
    local w = f.GetWidth and f:GetWidth()
    -- the console: the tape lives on the engineer's own small strip (Engineer.lua, EN.Gauge), shaped there
    if RD.Console and RD.Console() and NS.EN and NS.EN.Gauge then NS.EN.Gauge(true)
    elseif RD.gauge and type(w) == "number" and w > 0 then RD.SizeGauge(w) end
    local b = RD.bbRail
    if b and RD.Deck and RD.Deck() then
        -- THE FLIGHT DECK: the black box hangs straight under the deck, as wide as it (Arn's screenshot, 15 Nov: it sat on
        -- the radar's old left rail, off to the side, under BiS Tools' box)
        local gap = RD.RAIL_GAP
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -gap)
        b:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -gap)
    elseif b and RD.toolRail then
        local gap = RD.RAIL_GAP
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", RD.toolRail, "BOTTOMLEFT", 0, -gap)
        b:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", RD.RightW(), -gap)
    end
end

function RD.FitHull()
    local h, f = RD.hull, RD.frame
    if not (h and f) then return end
    if RD.Console and RD.Console() then             -- the console: the hull is its own small square
        -- the flight deck's hull holds its black box too (one contained box), and other addons dock below it
        local bottom = (RD.Deck and RD.Deck() and RD.BBRail()) or f
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        h:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", 0, 0)
        RD.FitEdgeFrame(f, bottom)
        RD.FitEdges(h)
        return
    end
    local top = RD.gaugeRail or f
    -- the bottom rail spans the whole width already (RD.FitWide); without one, the square's corner or the right rail's
    local corner = RD.BBRail() or ((RD.defRail and RD.defRail:IsShown()) and RD.defRail) or f
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", top, "TOPLEFT", 0, 0)
    h:SetPoint("BOTTOMRIGHT", corner, "BOTTOMRIGHT", 0, 0)
    RD.FitEdgeFrame(top, corner)
    RD.FitEdges(h)
end

--- The dock frame (BiSHealingAPI RadarEdge) on the plate's two corners - pinned to the rails / the radar, which are
--- FRAMES: a box holding secure buttons may be pinned to it only if no texture is anywhere in the chain.
function RD.FitEdgeFrame(top, corner)
    local e = RD.edgeFrame
    if not e then return end
    e:ClearAllPoints()
    e:SetPoint("TOPLEFT", top, "TOPLEFT", 0, 0)
    e:SetPoint("BOTTOMRIGHT", corner, "BOTTOMRIGHT", 0, 0)
end

--- The soft rings round the hull, wherever it is.
function RD.FitEdges(h)
    local p = RD.EDGE_PX
    for k, ring in ipairs(RD.edges or {}) do
        local o, i = k * p, (k - 1) * p                 -- the ring's outer and inner distance from the hull
        ring.top:ClearAllPoints()
        ring.top:SetPoint("TOPLEFT", h, "TOPLEFT", -o, o)
        ring.top:SetPoint("BOTTOMRIGHT", h, "TOPRIGHT", o, i)
        ring.bottom:ClearAllPoints()
        ring.bottom:SetPoint("TOPLEFT", h, "BOTTOMLEFT", -o, -i)
        ring.bottom:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", o, -o)
        ring.left:ClearAllPoints()
        ring.left:SetPoint("TOPLEFT", h, "TOPLEFT", -o, i)
        ring.left:SetPoint("BOTTOMRIGHT", h, "BOTTOMLEFT", -i, -i)
        ring.right:ClearAllPoints()
        ring.right:SetPoint("TOPLEFT", h, "TOPRIGHT", i, i)
        ring.right:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", o, -i)
    end
end

function RD.PaintHull()
    local P = RD.PLATE
    if RD.hull then RD.hull:SetVertexColor(P[1], P[2], P[3], 1) end
    for _, ring in ipairs(RD.edges or {}) do
        for _, side in ipairs({ "top", "bottom", "left", "right" }) do ring[side]:SetVertexColor(P[1], P[2], P[3], ring.a) end
    end
end

--- The radar's clamp: the tool rail, the gauge's rail and the black box's always, the right one while it shows.
function RD.ClampRails()
    RD.FitWide()                                     -- the top and bottom rails run over the right rail while it shows
    RD.FitHull()                                     -- and the hull follows them
    local f = RD.frame
    if not (f and f.SetClampRectInsets) then return end
    if RD.Console and RD.Console() then
        -- the engineer's small fuel strip on top (Engineer.lua) stays on the screen too
        local top = NS.EN and NS.EN.GaugeTop and NS.EN.GaugeTop() or 0
        pcall(f.SetClampRectInsets, f, 0, 0, top, 0)
        return
    end
    local gap = RD.RAIL_GAP
    local right = (RD.defRail and RD.defRail:IsShown()) and (RD.TOOL_RAIL_W + gap) or 0
    local bottom = (RD.BBRail() and NS.BB) and -(NS.BB.RAIL_H + gap) or 0
    pcall(f.SetClampRectInsets, f, -(RD.TOOL_RAIL_W + gap), right, RD.GAUGE_RAIL_H + gap, bottom)
end

--- The HUD scale UNDER the tape: the spine, the ticks hanging from it, the numbers under them, and the readout box
--- riding your fuel's end above the tape, pointing down into it.
function RD.BuildHUD(g, L)
    local H = RD.HUD
    local hud = CreateFrame("Frame", nil, g)
    hud:SetPoint("TOPLEFT", g, "BOTTOMLEFT", 0, -1)
    hud:SetPoint("TOPRIGHT", g, "BOTTOMRIGHT", 0, -1)
    hud:SetHeight(RD.GAUGE.base - 2)
    hud:SetFrameLevel(L + 3)
    g.hud = hud
    hud.spine = tex(hud, "ARTWORK", RD.PHOS)
    hud.spine:SetPoint("TOPLEFT", hud, "TOPLEFT", 0, 0)
    hud.spine:SetPoint("TOPRIGHT", hud, "TOPRIGHT", 0, 0)
    hud.spine:SetHeight(1)
    hud.ticks, hud.labels = {}, {}
    for k = 0, 10 do
        local t = tex(hud, "ARTWORK", RD.PHOS)
        t:SetSize(1, (k % 5 == 0 or k == 10) and H.major or H.minor)
        hud.ticks[k] = t
    end
    for q = 0, 4 do
        local fs = hud:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, H.label, "")
        fs:SetTextColor(RD.PHOS[1], RD.PHOS[2], RD.PHOS[3])
        fs:SetJustifyH("CENTER")
        fs:SetText(tostring(q * 25))
        hud.labels[q] = fs
    end
    -- the readout: a box riding the mana fill's end above the tape, the number inside, a pointer down into the tape
    local box = CreateFrame("Frame", nil, g)
    box:SetSize(H.boxW, H.boxH)
    box:SetPoint("BOTTOM", g.mana:GetStatusBarTexture(), "TOPRIGHT", 0, 3)
    box:SetFrameLevel(L + 6)
    box.fill = tex(box, "BACKGROUND", { RD.PLATE[1], RD.PLATE[2], RD.PLATE[3], 1 })
    box.fill:SetAllPoints(box)
    box.edges = {}
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local t = tex(box, "BORDER", RD.PHOS)
        t:SetPoint(e[1]) t:SetPoint(e[2])
        if e[3] then t:SetHeight(1) else t:SetWidth(1) end
        box.edges[#box.edges + 1] = t
    end
    box.tip1 = line(box, "OVERLAY", -3, -H.boxH / 2, 0, -H.boxH / 2 - 3, RD.PHOS, 1)
    box.tip2 = line(box, "OVERLAY", 3, -H.boxH / 2, 0, -H.boxH / 2 - 3, RD.PHOS, 1)
    box.num = box:CreateFontString(nil, "OVERLAY")
    box.num:SetFont(STANDARD_TEXT_FONT, 10, "")
    box.num:SetTextColor(RD.PHOS[1], RD.PHOS[2], RD.PHOS[3])
    box.num:SetPoint("CENTER", box, "CENTER", 0, 0)
    g.readout = box
    return hud
end

--- The HUD scale's places for a tape `w` long: a tick every 10%, numbers every 25%.
function RD.SizeHUD(w)
    local g = RD.gauge
    local hud = g and g.hud
    if not hud then return end
    for k, t in pairs(hud.ticks) do
        t:ClearAllPoints()
        t:SetPoint("TOP", hud, "TOPLEFT", k / 10 * w, 0)
    end
    for q, fs in pairs(hud.labels) do
        fs:ClearAllPoints()
        fs:SetPoint("TOP", hud, "TOPLEFT", q / 4 * w, -(RD.HUD.major + 1))
    end
end

--- The tape's size for a square `size` across: the rail's width (the tool rail + the square), the tape's length between
--- the placard and the ramjet, the ticks, the 30% lift and the window's roof. Answers the tape's length.
function RD.SizeGauge(size)
    local g, G = RD.gauge, RD.GAUGE
    if not g then return nil end
    -- the whole width once the panel closes into a square (Arn, 10 Nov: "once its closed like a square rail recenter all
    -- the stuff since we got extra space"): over the right rail's column too while it shows
    local railW = size + RD.TOOL_RAIL_W + RD.RAIL_GAP + RD.RightW()
    if RD.gaugeRail then RD.gaugeRail:SetWidth(railW) end
    local w = railW - G.left - G.right
    g:ClearAllPoints()
    g:SetPoint("BOTTOMLEFT", RD.gaugeRail or RD.frame, "BOTTOMLEFT", G.left, G.base)
    return RD.ShapeTape(w)
end

--- The tape `w` long wherever it was just anchored: its size, the scale, the ticks, the 30% lift and BINGO's window.
--- The radar's rail (RD.SizeGauge) and the engineer's small strip on top (Engineer.lua, EN.Gauge) both shape it here.
function RD.ShapeTape(w)
    local g, G = RD.gauge, RD.GAUGE
    if not g then return nil end
    g:SetSize(w, G.w)
    RD.SizeHUD(w)
    for q, l in ipairs(g.ticks) do
        local x = (q / 4 - 0.5) * w
        l:SetStartPoint("CENTER", g.tickFrame, x, -G.w / 2 - 2)
        l:SetEndPoint("CENTER", g.tickFrame, x, G.w / 2 + 2)
    end
    g.lift:ClearAllPoints()
    g.lift:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", RD.BINGO * w, 0)
    g.lift:SetSize(w, G.w)
    g.hotClip:SetPoint("TOPRIGHT", g, "TOPRIGHT", RD.BINGO * w + 2, G.flag)
    g.len = w
    return w
end

-- ------------------------------------------------------------------ the ships

--- The ship for a group of `n` (you count): the first whose `upTo` holds it; the biggest past 40.
function RD.ShipFor(n)
    n = tonumber(n) or 1
    for _, s in ipairs(RD.SHIPS) do
        if n <= s.upTo then return s end
    end
    return RD.SHIPS[#RD.SHIPS]
end

--- The corner brackets for a ship: `be` long, `bw` thick, from the square's corners.
function RD.ShapeBrackets(ship)
    local b = RD.SIZE / 2 - 4
    local e = ship.be or 22
    local c = ship.bracket
    for _, l in ipairs(RD.brackets or {}) do
        local sx, sy = l.sx, l.sy
        l:SetStartPoint("CENTER", RD.scope, sx * b, sy * b)
        if l.across then l:SetEndPoint("CENTER", RD.scope, sx * (b - e), sy * b)
        else l:SetEndPoint("CENTER", RD.scope, sx * b, sy * (b - e)) end
        l:SetThickness(ship.bw or 2)
        l:SetVertexColor(c[1], c[2], c[3], 1)
    end
end

--- FLY THIS SHIP: repaint the radar's chrome in its colours. Out of a fight (RD.Arm); colours only, nothing secure.
--- RD.PLATE is the hull and is changed IN PLACE, so everything made later from it (a stabilizer cover the client builds
--- at the next aura) comes out in the same dark. Answers the ship.
function RD.ApplyShip(ship)
    ship = ship or RD.SHIPS[1]
    RD.ship = ship
    local P = ship.plate
    RD.PLATE[1], RD.PLATE[2], RD.PLATE[3] = P[1], P[2], P[3]
    local function plate(t) if t then t:SetVertexColor(P[1], P[2], P[3], 1) end end
    plate(RD.fade)
    for _, r in ipairs({ RD.toolRail, RD.gaugeRail, RD.defRail, RD.bbRail }) do plate(r and r.bg) end
    RD.PaintHull()                                   -- the hull and its soft edge, in the same plate
    local sh = RD.shield
    if sh then
        plate(sh.plate)
        -- (the cover stands in the game's own aura button: forbidden to us once made - BugGrabber, 20 and 21 Nov - and the
        -- throw stopped RD.Arm halfway; a cover made later takes the new dark from RD.PLATE)
        for _, t in ipairs(sh.cover or {}) do pcall(plate, t) end
    end
    -- (the last-charge stencil is the buff's own icon now, never painted the plate's dark)
    -- the scope: rings, cross and ticks at the ship's line, dimmed; the brackets; you in the middle in its accent
    local L, k = ship.line, RD.SCOPE_DIM
    for _, l in ipairs(RD.scopeLines or {}) do l:SetVertexColor(L[1] * k, L[2] * k, L[3] * k, 0.85) end
    RD.ShapeBrackets(ship)
    local A = ship.accent
    RD.PaintMe()
    -- the fuel tape: your mana and the ruler in the ship's fuel colour, the groove, the scale, the readout, the placard
    local g = RD.gauge
    if g then
        local F = ship.fuel
        g.mana:SetStatusBarColor(F[1], F[2], F[3], F[4] or 1)
        g.track:SetColorTexture(ship.track[1], ship.track[2], ship.track[3], ship.track[4] or 1)
        for _, l in ipairs(g.ticks) do l:SetVertexColor(L[1], L[2], L[3], 1) end
        local hud = g.hud
        if hud then
            hud.spine:SetVertexColor(L[1], L[2], L[3], 1)
            for _, t in pairs(hud.ticks) do t:SetVertexColor(L[1], L[2], L[3], 1) end
            for _, fs in pairs(hud.labels) do fs:SetTextColor(L[1], L[2], L[3]) end
        end
        local box = g.readout
        if box then
            plate(box.fill)
            for _, t in ipairs(box.edges or {}) do t:SetVertexColor(A[1], A[2], A[3], 1) end
            box.tip1:SetVertexColor(A[1], A[2], A[3], 1)
            box.tip2:SetVertexColor(A[1], A[2], A[3], 1)
            box.num:SetTextColor(1, 1, 1)
        end
        if g.ship then
            g.ship:SetText(ship.name)
            g.ship:SetTextColor(A[1], A[2], A[3])
        end
        if g.fuelWord then g.fuelWord:SetTextColor(L[1], L[2], L[3]) end
    end
    RD.PaintRole()
    RD.PaintKnobs()                                  -- the knobs' "on" dot is the ship's line too
    return ship
end

--- A regen tool's face: a ring and its sign, PLAIN TEXTURES ONLY (the client's curve colour lands on a texture, never
--- on a Line - Arn's white blade), every piece born invisible so a colour that does not land shows nothing.
local function toolFace(b, kind)
    for _, l in ipairs(b.ring or {}) do l:Hide() end
    b.icon:Hide()
    local out, face = {}, b.face
    local s = 1                                                -- the signs are drawn for a 26px pip, then scaled
    local function bar(w, h, x, y, rot)
        local t = face:CreateTexture(nil, "OVERLAY")
        t:SetTexture(RD.WHITE)
        t:SetVertexColor(1, 1, 1, 0)
        t:SetSize(math.max(1, w * s), math.max(1, h * s))
        t:SetPoint("CENTER", face, "CENTER", x * s, y * s)
        if rot and t.SetRotation then t:SetRotation(rot) end
        out[#out + 1] = t
    end
    local r, n = RD.SYS_PX / 2 - 1, 16
    for k = 0, n - 1 do
        local a = (k + 0.5) * 2 * math.pi / n
        bar(2 * math.pi * r / n + 1, 2, math.sin(a) * r, math.cos(a) * r, -a)
    end
    s = RD.SYS_PX / 26
    if kind == "tide" then                                     -- a totem: the pole, its arms, a wave at its foot
        bar(4, 14, 0, 0) bar(12, 2, 0, 3) bar(10, 2, 0, -6)
    elseif kind == "potion" then                               -- a flask: the neck and the body
        bar(3, 5, 0, 5) bar(6, 2, 0, 3) bar(10, 8, 0, -3)
    elseif kind == "reserve" then                              -- a reserve can: the body, its handle, the spout
        bar(10, 10, -1, -2) bar(6, 2, -2, 5) bar(2, 6, 5, 4, -0.6)
    elseif kind == "chaff" then                                -- the ground sign: a stem into three shrinking bars
        bar(2, 8, 0, 4) bar(12, 2, 0, -1) bar(8, 2, 0, -4) bar(4, 2, 0, -7)
    else                                                       -- a drop
        bar(2, 9, -2.2, 2, -0.45) bar(2, 9, 2.2, 2, 0.45) bar(8, 5, 0, -3.5)
    end
    b.pieces = out
    return out
end

--- Is this tool switched off by its knob?
function RD.KnobOff(kind)
    local off = db().off
    return type(off) == "table" and kind ~= nil and off[kind] == true or false
end

--- Switch a tool's knob (true = off). Works in a fight: it only repaints what we light.
function RD.SetKnob(kind, isOff)
    local d = db()
    d.off = type(d.off) == "table" and d.off or {}
    d.off[kind] = isOff and true or nil
    RD.PaintKnobs()
    if RD.Active() then RD.PaintQuiet() RD.PaintChaff() end
    return RD.KnobOff(kind)
end

--- The knob on a tool's top-left corner: a plain button on the tool's rail, over the pip. A click flips it.
function RD.Knob(b)
    local k = CreateFrame("Button", nil, b.rail or RD.frame)
    k:SetSize(RD.KNOB_PX, RD.KNOB_PX)
    k:SetPoint("CENTER", b, "TOPLEFT", 1, -1)
    k:SetFrameLevel((b:GetFrameLevel() or 0) + 6)
    if k.RegisterForClicks then k:RegisterForClicks("LeftButtonUp") end
    k.dot = k:CreateTexture(nil, "OVERLAY")
    k.dot:SetAllPoints(k)
    k.dot:SetTexture(RD.ART .. "disc")
    k.owner = b
    k:SetScript("OnClick", function(self)
        local kind = self.owner.kind
        RD.SetKnob(kind, not RD.KnobOff(kind))
        if GameTooltip and GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end)
    k:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local tool = self.owner
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine((tool.tip and tool.tip[1] or "TOOL") .. (RD.KnobOff(tool.kind) and "  -  OFF" or "  -  ON"))
        GameTooltip:AddLine(RD.KnobOff(tool.kind) and "Switched off: it never lights.  Click to switch it back on."
                            or "Lights when it needs you.  Click to switch it off (works in a fight).", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    k:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b.knob = k
    return k
end

--- Every knob: shown on an armed tool only; red when off (a warning, every ship), a faint dot in the ship's line when on
--- (Arn's 9 Nov screenshot: the old phosphor green sat wrong on the purple fighter). Plain frames: any time, fight or not.
function RD.KnobOnColour()
    local L = RD.ship and RD.ship.line
    if not L then return RD.KNOB_ON end
    return { L[1], L[2], L[3], RD.KNOB_ON[4] }
end
function RD.PaintKnobs()
    local on = RD.KnobOnColour()
    for _, b in ipairs(RD.knobbed or {}) do
        local k = b.knob
        if k then
            if b.macro then
                local c = RD.KnobOff(b.kind) and RD.KNOB_OFF or on
                k.dot:SetVertexColor(c[1], c[2], c[3], c[4])
                k:Show()
            else
                k:Hide()
            end
        end
    end
end

function RD.Build()
    if RD.frame then return RD.frame end
    local f = CreateFrame("Frame", "BiSHealingRadar", UIParent)
    RD.frame = f
    f:SetSize(RD.SIZE, RD.SIZE)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    -- the radar's own background is nobody too (RD.EMPTY_UNIT): the wheel over a gap heals no one
    f:SetAttribute("unit", RD.EMPTY_UNIT)
    f:RegisterForDrag("LeftButton")
    -- dragged by the scope, out of a fight only; the drag ENDS before a fight takes the mouse (BiS Tools' lesson, 8 Nov)
    f:SetScript("OnDragStart", function(self)
        if combat() then return end
        self:StartMoving()
        self.dragging = true
    end)
    f:SetScript("OnDragStop", endDrag)
    f:SetScript("OnHide", endDrag)
    buildScope(f)
    RD.spokes = {}                      -- made as the roster needs them (RD.Spoke)
    -- THE MANA COLUMN on its own rail outside the square (RD.toolRail): the STABILIZER on top (only the button moved - its client
    -- cover is anchored to the button, so it follows), then the regen tools: Mana Tide, the best mana potion, the best
    -- drink (the old FUEL pip, its name kept). Each always in its place, invisible until its own curve lights it.
    RD.BuildRails(f)
    local step, X, rail = RD.SYS_PX + RD.TOOL_GAP, (RD.TOOL_RAIL_W - RD.SYS_PX) / 2, RD.toolRail
    RD.shield = buildSystem(f, "Shield", "TOPLEFT", X, -8, rail)
    RD.tide = buildSystem(f, "Tide", "TOPLEFT", X, -8 - step, rail)
    RD.potion = buildSystem(f, "Potion", "TOPLEFT", X, -8 - 2 * step, rail)
    -- the RESERVE TANK after the fight tools it stands behind (Mana Spring, RD.ReserveOpen)
    RD.reserve = buildSystem(f, "Reserve", "TOPLEFT", X, -8 - 3 * step, rail)
    RD.fuel = buildSystem(f, "Fuel", "TOPLEFT", X, -8 - 4 * step, rail)
    -- RATIONS, last in the column (Arn, 8 Nov: "move the rations next to the drink too")
    RD.rations = buildSystem(f, "Rations", "TOPLEFT", X, -8 - 5 * step, rail)
    RD.COLUMN = { RD.shield, RD.tide, RD.potion, RD.reserve, RD.fuel, RD.rations }
    RD.tide.kind, RD.potion.kind, RD.reserve.kind, RD.fuel.kind = "tide", "potion", "reserve", "drink"
    RD.fuel.restOnly = true                          -- a drink is out of a fight only
    RD.reserve.gate = function(fight) return RD.ReserveOpen(fight) end
    -- SPENT = DARK (11 Nov 2026, Arn after a dungeon: "mana tide was on cooldown but it showed i can click it"): Mana Tide
    -- and the potion light only while OUR clock says they are ready; while cooling, the dim disc alone shows (the face
    -- dark, as the disc was always meant to be seen)
    RD.tide.gate = function() return RD.ToolReady("tide") end
    RD.potion.gate = function() return RD.ToolReady("potion") end
    RD.TOOLS = { RD.tide, RD.potion, RD.reserve, RD.fuel }
    for _, b in ipairs(RD.TOOLS) do toolFace(b, b.kind) b.face:SetAlpha(0) end
    RD.fuel.drop = RD.fuel.pieces
    -- every lit thing pulses (gently here; the stabilizer keeps its own breath on its red), and carries a sweep: the
    -- GCD's, or for Mana Tide and the potion their own cooldown (RD.Sweeps)
    for _, b in ipairs({ RD.tide, RD.potion, RD.reserve, RD.fuel, RD.rations }) do b.pulse = RD.Pulse(b.beat, RD.PULSE_SOFT) end
    for _, b in ipairs(RD.COLUMN) do
        if b == RD.tide or b == RD.potion then b.cd = RD.WaitSweep(b) else b.cd = RD.Sweep(b.face) end
    end
    -- THE DEFENCE RAIL (right of the square): CHAFF, the targetless catch-all (RD.ChaffLit)
    RD.chaff = buildSystem(f, "Chaff", "TOPLEFT", X, -8, RD.defRail)
    RD.chaff.kind = "chaff"
    toolFace(RD.chaff, "chaff")
    RD.chaff.face:SetAlpha(0)
    RD.chaff.pulse = RD.Pulse(RD.chaff.beat, RD.PULSE_MID)
    RD.chaff.cd = RD.Sweep(RD.chaff.face)
    RD.DEFENCE = { RD.chaff }
    -- THE RES under the chaff, out of a fight only (RD.ArmRes)
    RD.res = buildSystem(f, "Res", "TOPLEFT", X, -8 - step, RD.defRail)
    RD.BuildRes(RD.res)
    -- THE TOTEMS under the res (RD.ArmTotems): CALL, BRING, RECALL - shown only for someone who knows them
    for k, name in ipairs({ "call", "tcall", "recall" }) do
        local b = buildSystem(f, "Totem" .. k, "TOPLEFT", X, -8 - (k + 1) * step, RD.defRail)
        b.kind = name
        b.face:SetAlpha(0)
        b:EnableMouse(false)
        b:Hide()
        local G = RD.COL.cyan
        for _, l in ipairs(b.ring or {}) do l:SetVertexColor(G[1], G[2], G[3], 1) end
        b.pulse = RD.Pulse(b.beat, RD.PULSE_SOFT)
        -- THE DISCS (11 Nov 2026, Arn: "recall has the same cool down as bring but recall has no cooldown"): BRING carries
        -- its OWN 30 s cooldown (our clock, RD.PaintWaits, like Mana Tide); CALL the totems' time left - dark while they
        -- stand, its disc runs down to the moment it lights (RD.ShowLife); RECALL has no cooldown and carries none
        if name == "tcall" then b.cd = RD.WaitSweep(b) else b.cd = RD.Sweep(b.face) end
        if name == "call" then b.life = RD.WaitSweep(b) end
        RD[name] = b
    end
    RD.TOTEMS = { RD.call, RD.tcall, RD.recall }
    -- THE VIEW BUTTON: radar <-> the engineer's console (RD.ToggleView)
    RD.BuildClassButton(f)
    RD.BuildViewButton(f)
    RD.BuildTopGrip(f)
    -- a knob on each tool that lights by itself (the stabilizer and the rations stay: always wanted)
    RD.knobbed = { RD.tide, RD.potion, RD.reserve, RD.fuel, RD.chaff, RD.call, RD.tcall, RD.recall }
    for _, b in ipairs(RD.knobbed) do RD.Knob(b) end
    buildGauge(f)
    RD.ApplyShip(RD.SHIPS[1])                        -- a fighter until the roster says otherwise (RD.Arm)
    -- (the rail drawn inside the scope is gone: the rails stand outside the square now - RD.BuildRails)
    -- rations: a fork
    RD.rations.fork = { line(RD.rations.face, "OVERLAY", -4, 7, -4, -7, RD.COL.cyan, 2), line(RD.rations.face, "OVERLAY", 4, 7, 4, -7, RD.COL.cyan, 2),
                        line(RD.rations.face, "OVERLAY", -4, 0, 4, 0, RD.COL.cyan, 2) }
    -- (the missile tape along the bottom is gone - Arn, 8 Nov: "the guage does the same thing")
    f:Hide()
    RD.Place()
    return f
end

-- ------------------------------------------------------------------ who is on the radar

--- Who sits in which slot: { [slot] = unit } plus raid (true/false) and your own group. A party: you first, then
--- party1-4 (slots 1-5). A raid: slot (group - 1) * 5 + place in the group, places in roster order - FIXED by group.
function RD.Roster()
    local out = {}
    local okR, raid = pcall(IsInRaid)
    if okR and plain(raid) == true then
        local okN, n = pcall(GetNumGroupMembers)
        n = okN and plain(n) or 0
        local filled, mine = {}, nil
        for i = 1, (type(n) == "number" and math.min(n, 40) or 0) do
            local okI, _, _, group = pcall(GetRaidRosterInfo, i)
            group = okI and tonumber(plain(group)) or nil
            if group and group >= 1 and group <= 8 then
                filled[group] = (filled[group] or 0) + 1
                if filled[group] <= 5 then out[(group - 1) * 5 + filled[group]] = "raid" .. i end
                local okU, isMe = pcall(UnitIsUnit, "raid" .. i, "player")
                if okU and plain(isMe) == true then mine = group end
            end
        end
        return out, true, mine or 1
    end
    out[1] = "player"
    for i = 1, RD.SPOKES - 1 do
        local okE, e = pcall(UnitExists, "party" .. i)
        if okE and plain(e) == true then out[i + 1] = "party" .. i end
    end
    return out, false, 1
end

--- tank, heal or damage. Out of a fight (the only time a role is not a secret). THE GAME'S ROLE FIRST (8 Nov 2026, Arn:
--- "tank shows up as a sword instead of a shield" - his Ellesmere frames showed Legaian's shield from it):
--- UnitGroupRolesAssigned TANK / HEALER / DAMAGER; then BiS> now's tank or a raid main tank; then a healing class.
RD.ROLE_WORD = { TANK = "tank", HEALER = "heal", DAMAGER = "damage" }
function RD.Role(unit)
    if UnitGroupRolesAssigned then
        local okR, r = pcall(UnitGroupRolesAssigned, unit)
        r = okR and plain(r) or nil
        if type(r) == "string" and RD.ROLE_WORD[r] then return RD.ROLE_WORD[r] end
    end
    -- BiS> now's tank (right-click its button with them targeted): matched as BiS> now matches it - the realm left off
    -- either side (it keeps "Name Surname-Realm" for /target; the plain name has none)
    local okN, name = pcall(GetUnitName, unit, false)
    name = okN and plain(name) or nil
    if type(name) == "string" and NS.FN and NS.FN.IsTank and NS.FN.IsTank(name) then return "tank" end
    if GetPartyAssignment then
        local ok, mt = pcall(GetPartyAssignment, "MAINTANK", unit)
        if ok and plain(mt) == true then return "tank" end
    end
    local ok, _, c = pcall(UnitClass, unit)
    c = ok and plain(c) or nil
    if c and RD.HEALER_CLASS[c] then return "heal" end
    return "damage"
end

--- YOUR ROLE ON THE PLACARD (Arn, 9 Nov: "lets add our role here Healer, DPS, Tank" ... "we take the role from what the
--- games tell us, the frames already tell us"): ONLY the game's own answer, the one its party and raid frames show - the
--- group role set for you (UnitGroupRolesAssigned), else a raid's main tank assignment (GetPartyAssignment). No guess
--- from the class, no tank mark of ours: the game says nothing, the line stays empty. A font string - fine in a fight;
--- asked in RD.Arm (a role set fires PLAYER_ROLES_ASSIGNED, which re-arms). Answers the word ("" for none).
RD.ROLE_PLACARD = { TANK = "TANK", HEALER = "HEALER", DAMAGER = "DPS" }
function RD.GameRole()
    if UnitGroupRolesAssigned then
        local okR, r = pcall(UnitGroupRolesAssigned, "player")
        r = okR and plain(r) or nil
        if type(r) == "string" and RD.ROLE_PLACARD[r] then return RD.ROLE_PLACARD[r] end
    end
    if GetPartyAssignment then
        local ok, mt = pcall(GetPartyAssignment, "MAINTANK", "player")
        if ok and plain(mt) == true then return "TANK" end
    end
    return ""
end
function RD.PaintRole()
    local g = RD.gauge
    local w = RD.GameRole()
    if g and g.role then g.role:SetText(w) end
    return w
end

-- ------------------------------------------------------------------ arming (out of a fight only)

local function armHeal(sp, unit)
    local b = sp.heal
    b:SetAttribute("unit", unit)
    RD.BindsOn(b)                                                     -- your binds are every click, the left one too
    b.unit = unit
    -- the face: the role glyph, rebuilt only when the role changed
    local role = RD.Role(unit)
    if sp.role ~= role then
        for _, t in ipairs(sp.glyph or {}) do t:Hide() end
        for _, t in ipairs(sp.redGlyph or {}) do t:Hide() end
        for _, t in ipairs(sp.amberGlyph or {}) do t:Hide() end
        local px = ((sp.slot and sp.slot.ph) or RD.PARTY.ph) * RD.GLYPH
        sp.glyph = glyph(b.face, role, px)
        sp.redGlyph = glyph(b.redFace, role, px)
        sp.amberGlyph = glyph(b.amberFace, role, px)
        sp.role = role
    end
    sp.paintTex = {}
    for _, t in ipairs(sp.glyph) do sp.paintTex[#sp.paintTex + 1] = t end
    -- where amber starts: your heal against their max health, both plain out of a fight
    local amount = RD.HealAmount()
    local okM, mx = pcall(UnitHealthMax, unit)
    mx = okM and plain(mx) or nil
    sp.amber = (amount and type(mx) == "number" and mx > 0) and (1 - amount / mx) or RD.AMBER
end

--- The pet's token for an owner's: player -> pet, party3 -> partypet3, raid12 -> raidpet12; nil for anything else.
function RD.PetOf(unit)
    if type(unit) ~= "string" then return nil end
    if RD.PET_UNIT[unit] then return RD.PET_UNIT[unit] end
    local kind, n = unit:match("^(%a+)(%d+)$")
    if kind == "party" or kind == "raid" then return kind .. "pet" .. n end
    return nil
end

--- Where a slot's pet sits, and how big: a party's beside its owner (turned clockwise), yours below you, a raid's own
--- group nearer the middle on its owner's bearing. nil = no pet here (a raid's other groups).
function RD.PetSpot(s)
    if not s or s.nopet then return nil end                -- the deck's places carry no pet (yet)
    local P = RD.PET
    if s.self then
        return math.sin(P.selfB) * P.selfR, math.cos(P.selfB) * P.selfR, RD.raid and P.raidPx or P.px
    end
    if RD.raid then
        if not s.own then return nil end
        local r = s.rh - P.inward
        return math.sin(s.b) * r, math.cos(s.b) * r, P.raidPx
    end
    local b = s.b + P.turn
    return math.sin(b) * s.rh, math.cos(b) * s.rh, P.px
end

--- A paw, our own shape: a pad and four toes, plain textures born invisible (the curve's colour lands on textures).
local function paw(face, px)
    local out = {}
    local function dot(w, h, x, y)
        local t = face:CreateTexture(nil, "OVERLAY")
        t:SetTexture(RD.ART .. "disc")
        t:SetVertexColor(1, 1, 1, 0)
        t:SetSize(w, h)
        t:SetPoint("CENTER", face, "CENTER", x, y)
        out[#out + 1] = t
    end
    local u = px / 14
    dot(7 * u, 6 * u, 0, -2.5 * u)                                   -- the pad
    dot(3 * u, 3 * u, -4.5 * u, 1.5 * u) dot(3 * u, 3.5 * u, -1.6 * u, 4 * u)
    dot(3 * u, 3.5 * u, 1.6 * u, 4 * u) dot(3 * u, 3 * u, 4.5 * u, 1.5 * u)
    return out
end

--- Put a spoke's pet where its slot says, on its owner's pet token, the client watching it. Out of a fight only.
--- No owner, or no place for a pet (a raid's other groups): off the watch and hidden.
--[[ YOUR BINDS ARE THE CLICKS (10 Nov 2026, Arn: "did we set a heal to left click? if we did get rid of it and lets
  whatever binds set as the heal"). The radar's own left-click heal is gone: a pip or a pet carries exactly what the
  bind window says, the left button too (an empty left button targets, like on the grid). RD.heal stays only for where
  amber starts (RD.HealAmount).
  NEVER A HEAL ON YOU BY ACCIDENT (same night: "when someone dies it leaves a red sword ... anytime i clicked it it
  healed me"): a plain "spell" click on someone a heal cannot land on (dead, a ghost) is handed by the client to its
  self-cast - you. So a pip is GUARDED (`b.__guard`, Mouse.lua's FM.ApplyTo): each bound spell is the macro
  `/cast [@mouseover,help,nodead] <spell>`, and on the dead or hostile it casts nothing. The client checks it at the
  click, mid-fight too. Out of a fight a dead pip still resurrects (FM.ResNow), and hostile binds still work on enemies. ]]
function RD.BindsOn(b)
    b.__guard = true
    if NS.FM and NS.FM.ApplyTo then pcall(NS.FM.ApplyTo, b) end
    -- no click of the radar's own: a plain "type1" would win over your bind's "*type1"
    b:SetAttribute("type1", nil)
    b:SetAttribute("macrotext1", nil)
    b:SetAttribute("spell1", nil)
end

--- Your binds changed (FM.Apply): every pip and pet in use takes them. Out of a fight only (secure writes).
function RD.ApplyBinds()
    if combat() then return 0 end
    if RD.BounceMap then RD.BounceMap() end           -- out of a fight: which party/raid tokens name which box
    local n = 0
    for _, sp in ipairs(RD.spokes or {}) do
        if sp.unit and sp.heal then RD.BindsOn(sp.heal) n = n + 1 end
        if sp.petUnit and sp.pet then RD.BindsOn(sp.pet) n = n + 1 end
    end
    return n
end

--- A DEAD PERSON'S PIP GOES DARK (same night): 0% health read red, but there is nothing a heal can do. In a fight the
--- answer may be a secret: it goes to the client (SetAlphaFromBoolean), never into an `if`. True when we KNOW they are.
--- `...` = more faces that go dark with it (a pip's red and amber copies sit on their own layers, 11 Nov - Arn: "left
--- group still icons remain": the amber sword stayed after the face went dark).
function RD.DeadDark(face, unit, ...)
    if not (UnitIsDeadOrGhost and face and unit) then return false end
    local ok, dead = pcall(UnitIsDeadOrGhost, unit)
    if not ok then return false end
    local faces = { face, ... }
    if NS.Secret and NS.Secret(dead) then
        for _, f in ipairs(faces) do
            if f.SetAlphaFromBoolean then pcall(f.SetAlphaFromBoolean, f, dead, 0, 1) end
        end
        return false
    end
    if dead == true then for _, f in ipairs(faces) do f:SetAlpha(0) end return true end
    return false
end

--- A pip's three faces at once: the face, its red copy, its amber copy (siblings, each with its own alpha).
function RD.HealFaces(b, a)
    if not b then return end
    if b.face then b.face:SetAlpha(a) end
    if b.redFace then b.redFace:SetAlpha(a) end
    if b.amberFace then b.amberFace:SetAlpha(a) end
end

local function armPet(sp, unit, s)
    local p = sp.pet
    if not p then return nil end
    local x, y, px = RD.PetSpot(s)
    local pu = unit and x and RD.PetOf(unit) or nil
    if not pu then
        if UnregisterUnitWatch then pcall(UnregisterUnitWatch, p) end
        p:SetAttribute("unit", nil)
        p:SetAttribute("type1", nil)
        p:Hide()
        -- the size goes with the paw (15 Nov 2026): kept, a pet coming back at the same size found no paw and was never drawn
        for _, t in ipairs(sp.petTex or {}) do t:Hide() end
        sp.petUnit, sp.petTex, sp.petPx = nil, nil, nil
        return nil
    end
    p:SetSize(px, px)
    p:ClearAllPoints()
    p:SetPoint("CENTER", RD.frame, "CENTER", x, y)
    p:SetAttribute("unit", pu)
    RD.BindsOn(p)                                                     -- your binds, like on its owner
    p.unit = pu
    if sp.petPx ~= px then
        for _, t in ipairs(sp.petTex or {}) do t:Hide() end
        sp.petTex, sp.petPx = paw(p.face, px), px
    end
    sp.petUnit = pu
    if RegisterUnitWatch then pcall(RegisterUnitWatch, p) end         -- the client shows it while the pet is there
    return pu
end

--- A pet's pip, coloured by the client from the pet's health through the radar's curve (hidden when healthy).
function RD.PaintPet(sp)
    local p = sp and sp.pet
    if not (p and sp.petUnit and sp.petTex) then return false end
    local okE, there = pcall(UnitExists, sp.petUnit)
    if okE and plain(there) == false then p.face:SetAlpha(0) return false end
    p.face:SetAlpha(1)
    if RD.DeadDark(p.face, sp.petUnit) then return false end
    local curve = RD.Curve(RD.AMBER)
    local ok, col = false, nil
    if curve and UnitHealthPercent then ok, col = pcall(UnitHealthPercent, sp.petUnit, true, curve) end  -- an `and` keeps one return
    local drew = ok and paint(sp.petTex, col)
    if not drew then p.face:SetAlpha(0) end                      -- no colour back: nothing, never a stale sign
    return drew
end

local function armBogey(sp, unit)
    local k = sp.bogey
    local tok = unit == "player" and "target" or (unit .. "target")
    local cast = NS.FG and NS.FG.KickCast and NS.FG.KickCast() or nil
    k:SetAttribute("*harmbutton1", cast and "kick" or nil)
    k:SetAttribute("*type-kick", cast and "spell" or nil)
    k:SetAttribute("*spell-kick", cast)
    k:SetAttribute("unit", tok)
    -- a right-click targets their target (any time: your crosshairs go on it); a left-click on an enemy is the kick
    k:SetAttribute("type2", "target")
    k:EnableMouse(true)
    sp.tok, sp.kick = tok, cast
end

--- The cure pips of a spoke: one client marker + one secure box per cure your class has.
local function armCures(sp, unit)
    local FA = NS.FA
    local s = sp.slot
    local cures = (unit and s and FA and FA.Cures and FA.Available and FA.Available()) and FA.Cures() or {}
    -- a box beyond what this spoke needs now: off (its marker stops drawing, its click does nothing)
    for n, c in ipairs(sp.cures) do
        if not cures[n] then
            if c.container and c.container.SetEnabled then pcall(c.container.SetEnabled, c.container, false) end
            RD.Unsweep(c.sweep)                -- a marker switched off is fed no sweep (kept, for when it comes back)
            c.box:SetAttribute("spell", nil)
            c.box:EnableMouse(false)
        end
    end
    local f = RD.frame
    for n, cure in ipairs(cures) do
        local px = s.pc
        local off = (n - (#cures + 1) / 2) * (px + 6)
        local cx, cy = RD.Point(s, s.rc)
        cx, cy = cx + math.cos(s.b) * off, cy - math.sin(s.b) * off
        local c = sp.cures[n]
        if not c then
            c = {}
            c.box = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
            if c.box.RegisterForClicks then c.box:RegisterForClicks("AnyDown") end
            -- the client's marker lives in a plain holder that pulses gently (whack-a-mole): the marker itself is
            -- never animated, and it draws only while there is something to cure, so the pulse shows only then
            c.holder = CreateFrame("Frame", nil, f)
            c.holder:SetAllPoints(f)
            c.pulse = RD.Pulse(c.holder, RD.PULSE_SOFT)
            sp.cures[n] = c
        end
        c.box:SetSize(px + 4, px + 4)
        RD.Halo(c.box, px + 4)
        c.box:ClearAllPoints()
        c.box:SetPoint("CENTER", f, "CENTER", cx, cy)
        c.box:SetAttribute("type", "spell")
        c.box:SetAttribute("spell", cure.name)
        c.box:SetAttribute("unit", unit)
        c.box:EnableMouse(true)
        c.cure = cure.name
        RD.DriveCure(c, unit)
        -- the client's marker: a diamond in the cure's colour, only while there is something to cure. Built once per
        -- place and cure; a new unit in the same place is only told who to watch.
        local key = cure.name .. ":" .. math.floor(cx + 0.5) .. ":" .. math.floor(cy + 0.5) .. ":" .. px
        if c.key == key and c.container then
            pcall(c.container.SetUnit, c.container, unit)
            if c.container.SetEnabled then pcall(c.container.SetEnabled, c.container, true) end
            RD.Resweep(c.sweep)
        else
            if c.container and c.container.SetEnabled then pcall(c.container.SetEnabled, c.container, false) end
            c.container, c.key = nil, nil
            RD.Unsweep(c.sweep)                -- the old marker's sweep is fed no more
            c.sweep = nil
            local ok, container = pcall(CreateFrame, "AuraContainer", nil, c.holder or f, "CustomAuraContainerTemplate")
            if ok and container then
                container:SetSize(1, 1)
                -- ON ITS BOX, and the marker on the container (11 Nov 2026, Arn: "when my cousin tries to click this on the
                -- engineer view to dispel the poison it does not dispel"): the marker was placed at the radar spot on the
                -- frame itself, so in the engineer's view the box moved to its square and the diamond stayed behind, over
                -- nothing clickable. Now wherever the box goes - radar, console, a bigger class - the diamond goes too.
                container:SetPoint("CENTER", c.box, "CENTER")
                container:SetUnit(unit)
                local first
                for t in pairs(cure.types or {}) do first = first or t end
                local col = RD.CURE_COL[first or ""] or RD.COL.green
                c.container, c.key = container, key
                c.slot = FA.AddSlot(container, "BiSRadarCure" .. sp.i .. "_" .. n, "HARMFUL|RAID_PLAYER_DISPELLABLE", {
                    candidateFilters = { includeDispelTypes = cure.types },
                    initializeFrame = FA.Placed(function(button)
                        if button.GetRegions then
                            for _, r in ipairs({ button:GetRegions() }) do if r.Hide then pcall(r.Hide, r) end end
                        end
                        for _, k in ipairs({ "Icon", "icon", "Border", "border", "Count", "count", "Cooldown" }) do
                            local part = button[k]
                            if type(part) == "table" and part.Hide then pcall(part.Hide, part) end
                        end
                        -- THE CURE'S OWN ICON, IN ITS DEBUFF'S COLOUR (15 Nov 2026, Arn: "when it lights up it lights up with
                        -- its icon the same size as the other stuff but with its color - poison green, disease brownish,
                        -- magic blue"): the cure spell's icon filling the marker, a rim in the debuff type's colour - drawn
                        -- by the client only while such a debuff is on them (it was a small diamond in that colour)
                        local tex
                        if C_Spell and C_Spell.GetSpellTexture then
                            local okT, t = pcall(C_Spell.GetSpellTexture, cure.name)
                            if okT then tex = t end
                        end
                        local d = button:CreateTexture(nil, "OVERLAY")
                        d:SetPoint("CENTER") d:SetSize(px - 2, px - 2)
                        if tex then
                            d:SetTexture(tex)
                            if d.SetTexCoord then d:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
                        else
                            d:SetTexture(RD.WHITE)                    -- no icon from the client: the old coloured diamond
                            d:SetSize(px * 0.72, px * 0.72)
                            d:SetVertexColor(col[1], col[2], col[3], col[4])
                            if d.SetRotation then d:SetRotation(math.pi / 4) end
                        end
                        local rim = CreateFrame("Frame", nil, button)
                        rim:SetSize(px, px)
                        rim:SetPoint("CENTER")
                        edge(rim, col, 1.5)
                        if button.EnableMouse then pcall(button.EnableMouse, button, false) end
                        if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
                        -- the GCD sweep on the marker: drawn only while the client draws the marker
                        if not button.bisSweep then button.bisSweep = RD.Sweep(button) c.sweep = button.bisSweep end
                    end, px, "CENTER", container, 0, 0),
                })
            end
        end
    end
end

--- THE TARGET BOX'S CURES (15 Nov 2026, Arn's screenshot + probe: a green diamond in the box with no target at all). The
--- client's marker does not redraw when "target" / "targettarget" changes to someone else or to nobody, so the last
--- target's poison stayed up. The grid's answer (Auras.lua FA.DRIVE): the CLIENT shows the cure button - and here the
--- marker's holder too - only while that token is someone you can help, a state driver that works in a fight. Any other
--- unit: the driver comes off and both show as before.
function RD.DriveCure(c, unit)
    local cond = NS.FA and NS.FA.DRIVE and NS.FA.DRIVE[unit or ""] or nil
    if c.driven == cond then return end
    for _, fr in ipairs({ c.box, c.holder }) do
        if fr then
            if cond and RegisterStateDriver then
                RegisterStateDriver(fr, "visibility", cond)
            elseif c.driven and UnregisterStateDriver then
                UnregisterStateDriver(fr, "visibility")
                fr:Show()
            end
        end
    end
    c.driven = cond
end

--- Your watched self buff (Water Shield): the red lights while it is NOT on you. The client's own icon arriving (its
--- aura button shown) hides the red - so the pip is dark exactly while the buff is up, and nothing is read.
--- The shield the refuel pip watches. NOT the buff reminder's switch (Arn, 8 Nov: "i dont have water shield where is the
--- button on my radar" - his reminder was off, `selfBuffs.none`, so FS.Target answered nothing and the pip never armed):
--- the names the player chose for the reminder if there are any, else the class's own (FS.CLASS: Water Shield for a
--- shaman); the first one this character has trained.
function RD.ShieldTarget()
    local FS = NS.FS
    if not FS then return nil end
    local d = NS.DB()
    local own = type(d.selfBuffs) == "table" and d.selfBuffs or nil
    local list = (own and #own > 0) and own or nil
    if not list then
        local okC, _, class = pcall(UnitClass, "player")
        list = (FS.CLASS and FS.CLASS[(okC and plain(class)) or ""]) or {}
    end
    for _, name in ipairs(list) do
        if FS.Knows and FS.Knows(name) and FS.SpellIds then
            local ids = FS.SpellIds(name)
            if #ids > 0 then return name, ids end
        end
    end
    return nil
end

--- THE LAST CHARGE, AS A COLOUR THE CLIENT CHOOSES (the reminder's road, FS.Wash): the client writes the charge count into
--- a font string through a formatter we hand it; 1 is written as an orange SQUARE, anything else as nothing. Never read.
--- THE SYMBOL IS A STENCIL (9 Nov 2026, Arn's screenshot: "look at the stabaliuzer graphics squished"). The gyro used to
--- be the escape itself (Art\gyro.tga), and came out a flat bar a quarter of its height: a texture escape is sized by
--- the text line it sits in, not by the pixels it asks for (the reminder learned that on 12 Oct - FS.Wash). A square
--- does not mind being any size, so the client paints a square RD.WASH_OVER times the pip, cut to the pip by a clip, and
--- over it lies Art\gyrohole.tga in the plate's dark with the symbol CUT OUT: the orange shows through the symbol only.
--- With no orange under it the stencil is plate on plate - nothing to see.
RD.ART = "Interface\\AddOns\\" .. (ADDON or "BiSHealing") .. "\\Art\\"
RD.WASH_OVER = 3
RD.SHIELD_RING = 3                                  -- the last charge's orange outline, px round the icon
RD.SHIELD_UP_DIM = 0.4                              -- the buff's icon while it is up: quiet
function RD.WashText(px, rgb)
    return ("|TInterface\\Buttons\\WHITE8X8:%d:%d:0:0:8:8:0:8:0:8:%d:%d:%d|t"):format(px, px, rgb[1], rgb[2], rgb[3])
end
function RD.ShieldWash(button)
    local make = C_StringUtil and C_StringUtil.CreateNumericRuleFormatter
    if not (make and button and button.SetApplicationCount) then return false end
    local px = RD.SYS_PX * RD.WASH_OVER
    if not RD.washFmt then
        local ok, f = pcall(make)
        if not ok or not f or not f.SetBreakpoints then return false end
        local points = { { threshold = 0, format = "" }, { threshold = 1, format = RD.WashText(px, RD.SHIELD_LAST) },
                         { threshold = 2, format = "" } }
        if not pcall(f.SetBreakpoints, f, points) then return false end
        RD.washFmt = f
    end
    local clip = CreateFrame("Frame", nil, button)
    clip:SetAllPoints(button)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    -- THE LAST CHARGE ASKS FOR A CLICK, SO IT PULSES (Arn, 8 Nov: "make the stabilizer pulse too"): gently, on this clip
    -- only - the orange the client writes into it beats, the green cover beside it holds still
    RD.washPulse = RD.PulseAlpha(clip, RD.FADE_SOFT)
    RD.washClip = clip
    local fs = clip:CreateFontString(nil, "OVERLAY")
    if fs.SetFont then fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", RD.SYS_PX, "") end
    fs:SetPoint("CENTER", clip, "CENTER", 0, 0)
    -- the stencil, over the orange (and still: only the orange under it beats)
    local hole = CreateFrame("Frame", nil, button)
    hole:SetAllPoints(button)
    if hole.SetFrameLevel and clip.GetFrameLevel then
        local lvl = clip:GetFrameLevel()
        if type(lvl) == "number" then hole:SetFrameLevel(lvl + 2) end
    end
    -- THE STENCIL IS THE ICON NOW (15 Nov 2026): the buff's own icon, dim, inset a few pixels - so while it is up the button
    -- is that icon, quiet on the dark cover (nothing asking for a click); on the last charge the orange square under it
    -- shows only in the ring round it - an orange outline. (It was the symbol cut out of the plate: an orange symbol.)
    local inset = RD.SHIELD_RING
    -- A SOLID BACK UNDER THE ICON (16 Nov 2026, Arn: "the amber outline still covers the whole icon when it's one charge
    -- left ... can we change the amber to an outline so it does not block the water shield icon"): the icon is dim, so the
    -- orange square showed through it; on the plate's own dark the orange is left only in the ring round it - an outline
    local back = hole:CreateTexture(nil, "BACKGROUND")
    back:SetPoint("TOPLEFT", hole, "TOPLEFT", inset, -inset)
    back:SetPoint("BOTTOMRIGHT", hole, "BOTTOMRIGHT", -inset, inset)
    local P = RD.PLATE or { 0.05, 0.04, 0.09 }
    back:SetColorTexture(P[1], P[2], P[3], 1)
    RD.washBack = back
    local t = hole:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", hole, "TOPLEFT", inset, -inset)
    t:SetPoint("BOTTOMRIGHT", hole, "BOTTOMRIGHT", -inset, inset)
    if t.SetTexCoord then t:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    local sb = RD.shield
    t:SetTexture((sb and sb.shieldTex) or nil)
    t:SetVertexColor(1, 1, 1, RD.SHIELD_UP_DIM)
    RD.washHole = t
    return pcall(button.SetApplicationCount, button, fs, { formatter = RD.washFmt })
end

--[[ THE STABILIZER (8 Nov 2026, Arn: "i dont want a shield icon i want an icon that a jet pilot would see in combat and
  know i need to press this button to fly effectively maybe call it stabilizer ... cause priest would see a inner fire").
  One cockpit symbol for every class's keep-up buff (Water Shield, Inner Fire, Omen of Clarity, Blessing of Wisdom): an
  ATTITUDE INDICATOR - a ring, the horizon across it, the little aircraft's wings and nose. Plain textures only (the
  colour lands on them), every piece turned with SetRotation. Drawn TWICE, identically: red on the pip (under), and a
  dim green copy on the client's own aura button over it - piece for piece on the same spot, so the green hides the red
  exactly while the buff is up, and the red shows the moment the client stops drawing. ]]
RD.GYRO_SEG = 16
function RD.Gyro(parent, px, col, layer)
    local out = {}
    local function bar(w, h, x, y, rot)
        local t = parent:CreateTexture(nil, layer or "OVERLAY")
        t:SetTexture(RD.WHITE)
        t:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
        t:SetSize(w, h)
        t:SetPoint("CENTER", parent, "CENTER", x, y)
        if rot and t.SetRotation then t:SetRotation(rot) end
        out[#out + 1] = t
        return t
    end
    local r = px * 0.44
    local seg = 2 * math.pi * r / RD.GYRO_SEG + 1
    for k = 0, RD.GYRO_SEG - 1 do                              -- the ring
        local a = (k + 0.5) * 2 * math.pi / RD.GYRO_SEG
        bar(seg, 2, math.sin(a) * r, math.cos(a) * r, -a)
    end
    bar(px * 0.80, 1, 0, 0)                                    -- the horizon
    bar(px * 0.24, 2, -px * 0.17, -px * 0.08)                  -- the wings, either side of the nose
    bar(px * 0.24, 2, px * 0.17, -px * 0.08)
    bar(2, px * 0.10, 0, -px * 0.03)                           -- the nose
    return out
end

local function armShield()
    local b = RD.shield
    local name, ids = RD.ShieldTarget()
    b:SetAttribute("*type1", name and "macro" or nil)
    b:SetAttribute("*macrotext1", name and ("/cast " .. name) or nil)
    b:EnableMouse(name and true or false)
    b.shieldName = name
    if not name or b.shieldFor == name then return end
    b.shieldFor = name
    -- the red under it: the STABILIZER symbol (RD.Gyro), breathing - not the spell's picture (Arn: a cockpit symbol, the
    -- same for every class)
    b.icon:Hide()
    for _, l in ipairs(b.ring or {}) do l:Hide() end        -- the gyro has its own ring
    -- THE BUFF'S OWN ICON (15 Nov 2026, Arn: "the red water shield use the icon the classes use that use charges, water
    -- shield priest inner fire"): under the client's cover, the spell's icon in a red rim - shown, breathing, exactly
    -- while the buff is gone (the cover hides it whole while it is up). The drawn stabilizer symbol is retired.
    if not b.shieldIcon then
        b.shieldIcon = b.face:CreateTexture(nil, "ARTWORK")
        b.shieldIcon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
        b.shieldIcon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
        if b.shieldIcon.SetTexCoord then b.shieldIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        b.shieldRim = edge(b.face, RD.COL.red, 1.5)
    end
    b.shieldTex = nil
    if C_Spell and C_Spell.GetSpellTexture then
        local okT, tx = pcall(C_Spell.GetSpellTexture, name)
        if okT and tx ~= nil and not (NS.Secret and NS.Secret(tx)) then b.shieldTex = tx end
    end
    b.shieldIcon:SetTexture(b.shieldTex)
    for _, t in ipairs(b.gyroRed or {}) do t:Hide() end      -- a copy built before: the old symbol stays away
    -- the plate: the dark the cover is painted in, so a covered pip looks like the plate alone
    if not b.plate then
        b.plate = b:CreateTexture(nil, "BACKGROUND")
        b.plate:SetAllPoints(b)
        b.plate:SetTexture(RD.WHITE)
        b.plate:SetVertexColor(RD.PLATE[1], RD.PLATE[2], RD.PLATE[3], 1)
    end
    b.tip = { name:upper(), "Click to cast it.  Dim green: on you.  Orange: the last charge.  Red: gone." }
    b.face:SetAlpha(1)
    if not b.breath and b.face.CreateAnimationGroup then
        local okA, g = pcall(b.face.CreateAnimationGroup, b.face)
        if okA and g then
            local fade = g:CreateAnimation("Alpha")
            -- moderate, as the column's (Arn, 8 Nov: "nothing crazy"): the soft pulse's depth, a breath's pace
            fade:SetFromAlpha(1) fade:SetToAlpha(RD.FADE_SOFT[1]) fade:SetDuration(0.6)
            g:SetLooping("BOUNCE")
            g:Play()
            b.breath = g
        end
    end
    local FA = NS.FA
    if not (FA and FA.Available and FA.Available() and FA.AddSlot and ids and #ids > 0) then return end
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, b, "CustomAuraContainerTemplate")
    if not (ok and container) then return end
    container:SetSize(1, 1)
    container:SetPoint("CENTER", b)
    if container.SetFrameLevel then container:SetFrameLevel(b:GetFrameLevel() + 10) end   -- over the red
    container:SetUnit("player")
    local want = {}
    for _, id in ipairs(ids) do want[id] = true end
    b.container = container
    b.slot = FA.AddSlot(container, "BiSRadarShield", "HELPFUL", {
        candidateFilters = { includeSpellIDs = want },
        -- THE REMINDER'S OWN ROAD, WHICH WORKS IN A FIGHT (8 Nov 2026, Arn: "watershield reminder used to work in
        -- combat"; SelfBuff.lua's badge, 12 Oct). Nothing of ours decides "missing": the red pip is ALWAYS drawn under
        -- this button, and while the buff is up the CLIENT draws the button over it - our cover, the shield's own icon
        -- greyed into the scope's dark - so the red is hidden. Gone: the client stops drawing it, the red shows. The
        -- old hooks (OnShow/OnHide flipping the red's alpha) missed changes and are gone. The charges are the client's
        -- too: the last one washes the cover orange (RD.ShieldWash), any more write nothing.
        initializeFrame = FA.Placed(function(button)
            if button.GetRegions then for _, r in ipairs({ button:GetRegions() }) do if r.Hide then pcall(r.Hide, r) end end end
            b.handed = true
            pcall(function()
                -- NOTHING TO CLICK WHILE IT IS UP (Arn, 8 Nov: "this stabilizer is 3/3 it needs to go away or ill keep
                -- trying to click it"): the cover is a plain square in the PLATE's own dark (RD.PLATE, drawn under the
                -- pip by armShield), so with the buff up you see only the dark plate - no symbol. It still hides the red
                -- whole. The last charge washes it orange; gone, the client stops drawing it and the red shows.
                local t = button:CreateTexture(nil, "OVERLAY")
                t:SetAllPoints(button)
                t:SetTexture(RD.WHITE)
                t:SetVertexColor(RD.PLATE[1], RD.PLATE[2], RD.PLATE[3], 1)
                b.cover = { t }
            end)
            pcall(RD.ShieldWash, button)
            if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
            if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, false) end
            if button.EnableMouse then pcall(button.EnableMouse, button, false) end
        end, RD.SYS_PX, "CENTER", b, 0, 0),
    })
    -- switched on and asked to look now, as the reminder's badge is: a shield already on you is not news to a container
    -- that only listens for changes. No slot placed: the red would never be covered - so no pip at all.
    if not b.slot then b.face:SetAlpha(0) b.shieldName = nil return end
    if container.SetEnabled then pcall(container.SetEnabled, container, true) end
    if container.UpdateAllAuras then pcall(container.UpdateAllAuras, container) end
end

-- MAGE WATER FIRST (Arn, 12 Nov: "can you proioritize mage water first on the drink button too"): conjured water is free
-- and goes away anyway, so the drink button reaches for it before anything bought, whatever level each needs. Known by
-- its item id (the classic conjured waters, Conjured Water to Conjured Crystal Water), else a name starting "Conjured ".
RD.CONJURED = { [5350] = true, [2288] = true, [2136] = true, [3772] = true, [8077] = true, [8078] = true, [8079] = true }

--- True when an item is conjured (a mage made it).
function RD.IsConjured(id, name)
    if RD.CONJURED[id] then return true end
    return type(name) == "string" and name:find("^Conjured ") ~= nil
end

--- The best item in your bags whose use is `spellName` ("Drink" / "Food"; `needWords` in its use text), by the level it
--- needs - out of a fight only. A drink: conjured (mage) water first, then by level. Answers an item id or nil.
function RD.BestItem(spellName, needWords)
    if combat() then return nil end
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    local num = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    local idOf = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not (getSpell and num and idOf) then return nil end
    local okL, lvl = pcall(UnitLevel, "player")
    lvl = okL and plain(lvl) or 60
    local best, bestLvl
    for bag = 0, 4 do
        local okN, n = pcall(num, bag)
        for slot = 1, (okN and type(n) == "number" and n or 0) do
            local okI, id = pcall(idOf, bag, slot)
            id = okI and plain(id) or nil
            if type(id) == "number" then
                local okS, sname, sid = pcall(getSpell, id)
                sname = okS and plain(sname) or nil
                if sname == spellName then
                    local fits = true
                    if needWords then
                        local getDesc = C_Spell and C_Spell.GetSpellDescription
                        local okD, text = false, nil
                        if getDesc and sid then okD, text = pcall(getDesc, sid) end
                        text = okD and plain(text) or nil
                        fits = type(text) == "string" and text:lower():find(needWords, 1, true) ~= nil
                    end
                    local need, iname = 0, nil
                    if fits and info then
                        local okF, n1, _, _, _, minLvl = pcall(info, id)
                        need = okF and tonumber(plain(minLvl)) or 0
                        iname = okF and plain(n1) or nil
                    end
                    -- the rank: the level it needs, and a mage's water above everything bought
                    local rank = need
                    if spellName == "Drink" and RD.IsConjured(id, iname) then rank = need + 1000 end
                    if fits and need <= (lvl or 60) and (not bestLvl or rank > bestLvl) then best, bestLvl = id, rank end
                end
            end
        end
    end
    return best
end

local function armUse(b, id)
    b:SetAttribute("*type1", id and "macro" or nil)
    b:SetAttribute("*macrotext1", id and ("/use item:" .. id) or nil)
    b:EnableMouse(id and true or false)
    b.item = id
    if b == RD.rations then RD.FoodIcon(id) end
end

--- THE FOOD'S OWN ICON on the rations button (15 Nov 2026, Arn: "put the food icon on the H or Fork" - "not always fish just
--- the food we are eating" - "pre 60 its exp at 60 its the buff food"). Whatever RD.FoodWanted picked - BiS Tools' XP food
--- while you level, else the food that gives Well Fed - shows its icon on the button's face, where the drawn fork was; no
--- icon from the client keeps the fork. The face's alpha (food wanted, out of a fight) still decides whether it shows.
--- THE DRINK AND THE POTION TOO (Arn: "same with the drink put the actual drink i am about to drink"): RD.ItemIcon on any
--- item button - the item it would use, its icon over the drawn sign (the fork, or a tool's pieces), which steps aside.
--- REAL ICONS ON EVERY BUTTON (Arn, 15 Nov: "yes use the real icons on all of them"). One helper: a texture the size of the
--- button on its face (so the face's alpha - lit or not - still decides whether it shows), and the drawn sign steps aside:
--- the tool's pieces, the rations' fork, the small icon and ring a totem or the res wore. nil = the drawn sign back.
function RD.RealIcon(b, tex)
    if not (b and b.face) then return false end
    if tex ~= nil and NS.Secret and NS.Secret(tex) then tex = nil end
    if not b.food then
        b.food = b.face:CreateTexture(nil, "OVERLAY")
        b.food:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
        b.food:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
        if b.food.SetTexCoord then b.food:SetTexCoord(0.08, 0.92, 0.08, 0.92) end   -- the icon's own border trimmed
    end
    if tex then b.food:SetTexture(tex) b.food:Show() else b.food:Hide() end
    for _, l in ipairs(b.fork or b.pieces or {}) do if tex then l:Hide() else l:Show() end end
    -- no ring round a real icon (Arn: "im not liking the blue outline") - the rations' cyan ring was left round its food;
    -- a totem's or the res's ring and small icon come back only when it has no icon
    for _, l in ipairs(b.ring or {}) do if tex then l:Hide() elseif b.ringIcon then l:Show() end end
    if b.icon and tex then b.icon:Hide() elseif b.icon and b.ringIcon then b.icon:Show() end
    b.iconTex = tex
    return tex ~= nil
end
function RD.ItemIcon(b, id)
    local iconOf = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    local tex
    if id and iconOf then
        local ok, t = pcall(iconOf, id)
        if ok then tex = t end
    end
    return RD.RealIcon(b, tex)
end
function RD.SpellIcon(b, spell)
    local tex
    if spell and C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, spell)
        if ok then tex = t end
    end
    return RD.RealIcon(b, tex)
end
function RD.FoodIcon(id) return RD.ItemIcon(RD.rations, id) end

--- An item tool's icon, lit by the client like its pieces were: full where the tool's own curve says it helps (below
--- `at` on your mana), faded above - white, so the icon keeps its own colours.
RD.ICON_FADED = 0.2                                  -- a waiting icon: clearly dim (Arn, 15 Nov)
RD.iconCurves = {}
--- A RAMP, NOT A SWITCH (15 Nov 2026, Arn: "mana potion starts getting less dim the closer we get to zero mana 100% bright
--- at 10% mana" - "mana tide full brightness at 25% mana" - "if water restores 800 mana over 24 seconds when i am out of
--- combat it should light up to 100% when i am at 1600 mana needed"): dim above the tool's own point `at` (where it starts
--- to help), brightening linearly as your mana falls, full at `full` and below. The client evaluates it.
RD.FULL_AT = { potion = 0.10, tide = 0.25, reserve = 0.15 }
--- Where a tool is full bright: its fixed point, or - the drink - missing TWICE what one drink restores.
function RD.FullFor(b)
    if not b then return nil end
    if b.kind == "drink" and type(b.at) == "number" then return math.max(0.02, 2 * b.at - 1) end
    return RD.FULL_AT[b.kind or ""]
end
function RD.IconCurve(at, full)
    at = math.max(0.02, math.min(tonumber(at) or RD.TOOL_GUESS, 0.98))
    full = tonumber(full)
    local key = math.floor(at * 100 + 0.5) .. ":" .. (full and math.floor(full * 100 + 0.5) or "-")
    if RD.iconCurves[key] then return RD.iconCurves[key] end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, c = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not c or not c.AddPoint then return nil end
    if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then pcall(c.SetType, c, Enum.LuaCurveType.Linear) end
    local x, F = math.floor(at * 100 + 0.5) / 100, RD.ICON_FADED
    if full and full < x then
        pcall(c.AddPoint, c, 0.00, CreateColor(1, 1, 1, 1))
        pcall(c.AddPoint, c, full, CreateColor(1, 1, 1, 1))     -- full and below: bright
        pcall(c.AddPoint, c, x, CreateColor(1, 1, 1, F))        -- the ramp, from where it starts to help
        pcall(c.AddPoint, c, 1.00, CreateColor(1, 1, 1, F))
    else
        pcall(c.AddPoint, c, 0.00, CreateColor(1, 1, 1, 1))
        pcall(c.AddPoint, c, x, CreateColor(1, 1, 1, 1))
        pcall(c.AddPoint, c, x + 0.0001, CreateColor(1, 1, 1, F))
        pcall(c.AddPoint, c, 1.00, CreateColor(1, 1, 1, F))
    end
    RD.iconCurves[key] = c
    return c
end

--[[ THE DIM IS THE TIME LEFT (15 Nov 2026, Arn: "all these should be totally dimmed out like the food, and then 100%
  bright when the buff is gone, actually lets cascade it, when its 50% left 50% dim, 20% left 80% undimmed" - "lets use
  the dimness as its duration for the food buff and such"). A buff button's brightness = 1 - the buff's time left (as a
  share of its whole), never below RD.BUFF_DIM_FLOOR: fresh = all but gone, half left = half bright, gone = full. Read
  OUT OF A FIGHT (a buff's time is plain then) - Well Fed, and the charge shield over its cover; in a fight they keep
  where they were (the shield still turns red the moment it is gone, the client's own). ]]
RD.BUFF_DIM_FLOOR = 0.05
function RD.BuffLeft(name)
    if combat() or RD.inFight or type(name) ~= "string" then return nil end
    local find = AuraUtil and AuraUtil.FindAuraByName
    if not find then return nil end
    local ok, n, _, _, _, dur, exp = pcall(find, name, "player", "HELPFUL")
    if not ok then return nil end
    -- HIDDEN IS NOT GONE (Arn, 16 Nov: "red outline on watershield i have 3 charges"): right after a fight the game can
    -- still hide aura names (the totem-name row in solved.md); a secret answer = unknown, never "missing"
    if NS.Secret and NS.Secret(n) then return nil end
    if n == nil then return 0 end                                -- gone
    dur, exp = plain(dur), plain(exp)
    if type(dur) ~= "number" or dur <= 0 or type(exp) ~= "number" then return 1 end   -- no timer: as fresh
    local now = (GetTime and GetTime()) or 0
    return math.max(0, math.min(1, (exp - now) / dur))
end
function RD.CascadeAlpha(left)
    if left == nil then return nil end
    return math.max(RD.BUFF_DIM_FLOOR, 1 - left)
end

--- The food the button shows: the food you want now, else - Well Fed still on you - the food that would renew it (its
--- icon fading with the buff's time). The second answer: wanted now (full bright).
function RD.FoodShown()
    local want = RD.FoodWanted()
    if want then return want, true end
    if RD.WellFed() == true then return RD.BestItem("Food", "well fed"), false end
    return nil, false
end

--- Out of a fight, every few seconds: the food's and the shield's fade from their buffs' time left.
function RD.PaintBuffDims()
    if combat() or RD.inFight then return false end
    local r = RD.rations
    if r and r.face then
        local a = 0
        local left
        if r.item then
            left = 0
            if not r.wanted then left = RD.BuffLeft("Well Fed") or 0 end
            a = RD.CascadeAlpha(left) or 1
        end
        r.face:SetAlpha(a)
        RD.AttnSet(r, r.item and RD.AttnLeft(left) or nil)     -- red under 10% of Well Fed (or none), amber under half
        if r.food and r.food.SetDesaturated then pcall(r.food.SetDesaturated, r.food, false) end
    end
    local sh = RD.shield
    if RD.washHole and sh and sh.shieldName then
        local left = RD.BuffLeft(sh.shieldName)
        if left and left > 0 then RD.washHole:SetVertexColor(1, 1, 1, RD.CascadeAlpha(left)) end
    end
    -- your shield: the red box when it is missing (or nearly out of time); its LAST CHARGE has its own amber ring (the
    -- client's square, RD.ShieldWash), so no time-based amber here on top of it
    if sh and sh.shieldName then
        -- nil = the game will not say (a fight hides buff times), NOT missing: no box then (Arn, 16 Nov: "red outline on
        -- watershield i have 3 charges"); 0 = gone, out of a fight, where the reminder matters (before the pull)
        local sl = RD.BuffLeft(sh.shieldName)
        RD.AttnSet(sh, (sl ~= nil and sl <= RD.ATTN_RED_LEFT) and "red" or nil)
    end
    return true
end

--- HOW MUCH MANA A TOOL GIVES BACK, from its own words (out of a fight, plain): "Restores 1350 to 2250 mana" -> the
--- middle; "Restores 4200 mana over 30 sec" -> 4200; "restores 170 mana every 3 seconds ... for 12 sec" -> 170 x 4.
--- nil when the words say no number.
function RD.RestoreAmount(text)
    if type(text) ~= "string" then return nil end
    local function num(s) return tonumber((tostring(s or ""):gsub(",", ""))) end
    -- a number may carry a decimal ("Restores 835.2 mana"): read whole, never as its last digit
    local N = "(%d[%d,]*%.?%d*)"
    local a, b = text:match(N .. "%s+to%s+" .. N .. "%s+mana")
    local n = (num(a) and num(b)) and (num(a) + num(b)) / 2 or num(text:match(N .. "%s+mana"))
    if not n then return nil end
    local every = num(text:match("every%s+(%d+)%s+sec"))
    local dur = num(text:match("for%s+(%d+)%s+sec"))
    local mins = num(text:match("for%s+(%d+)%s+min"))              -- Mana Spring: "for 5 min ... every 2 seconds"
    if not dur and mins then dur = mins * 60 end
    if every and dur and every > 0 and dur >= every then n = n * math.floor(dur / every) end
    return n
end

local function describe(spell)
    local get = C_Spell and C_Spell.GetSpellDescription
    if not (get and spell) then return nil end
    local ok, text = pcall(get, spell)
    text = ok and plain(text) or nil
    return type(text) == "string" and text or nil
end

--- An item's use, in words: its use-spell's description.
local function itemWords(id)
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if not (getSpell and id) then return nil end
    local ok, _, sid = pcall(getSpell, id)
    sid = ok and plain(sid) or nil
    return sid and describe(sid) or nil
end

--- Learn where a tool lights: `at` = restores / your full mana (both plain out of a fight), else RD.TOOL_GUESS and
--- `guess` = true. Kept on the button; its curve is RD.ToolCurve(b.at).
--- KEEP YOU OFF EMPTY, NOT TOP YOU UP (Arn, 8 Nov: "run these backwards we dont want to light them as soon as they will
--- bring us back to 100% we want to use them when they will keep us from reaching 0%"): a tool lights once your mana is
--- down to what it gives back - Mana Tide's 352 of 1,400 lights at 25%, not at 75%.
function RD.LearnTool(b, words)
    local amount = RD.RestoreAmount(words)
    local okM, mx = pcall(UnitPowerMax, "player", 0)
    mx = okM and plain(mx) or nil
    b.amount = amount
    if amount and type(mx) == "number" and mx > 0 then
        b.at, b.guess = math.max(0.02, math.min(amount / mx, 0.98)), false
    else
        b.at, b.guess = RD.TOOL_GUESS, true
    end
    b.at = math.floor(b.at * 100 + 0.5) / 100                     -- the curve's own point (RD.ToolCurve rounds to 1%)
    return b.at, amount
end

local function toolTip(b, title, what)
    local where = b.guess and ("its amount unknown - lights below %d%% mana (a guess)"):format(b.at * 100 + 0.5)
                  or ("restores ~%d mana - lights below %d%% mana, when it keeps you off empty"):format(b.amount, b.at * 100 + 0.5)
    b.tip = { title, what .. ".  " .. where .. "." .. (b.restOnly and "  Out of a fight only." or "") }
end

--[[ THE MANA TIDE PING (16 Nov 2026, Arn: "every time i drop it" - "a ping can be a ping and we use that, not on the way
  assist attack or warning" - assist "will make the tanks think i need help"). The button's own click drops the totem
  and then pings at your feet, the game's plain ping, so the whole group (BiS or not) sees where it stands. A click while
  it is down pings again: "stand close". An addon may not ping by itself (C_Ping.SendMacroPing is forbidden, measured
  14 Nov); a /ping inside a secure button's macro is the player's own click. ]]
--- AND THE SECOND CLICK PINGS THE TOTEM ITSELF (Arn, 16 Nov: "clicking once to drop and clicking the same place but now
--- its a small target frame of the totem so it pings where its at" - he had pinged it on Ellesmere's target frame with
--- the totem targeted: "Mana Tide Totem II"). One macro, both clicks: /target finds the standing totem (the first click's
--- totem does not exist yet, so the ping falls to you, at the same spot), pings it, and goes back to your target - only
--- when it really got the totem (a friendly that is not in your group); left on it with no target before, it clears.
--- Every line is a secure slash command run by your own click, so it works in a fight.
--- One spec per button that behaves like Mana Tide: the real one, and the Grounding Totem stand-in for testing (Arn, 16 Nov:
--- "its a 5 min cool down so i dont want to sit there waiting lets do grounding totem"). `life` = how long the totem
--- stands (the tag's seconds), `len` = its cooldown (the chat line), `key` = its slot in RD.readyAt (our clock).
local function val(v) if type(v) == "function" then return v() end return v end
RD.TIDE_SPEC = { spell = RD.TIDE, key = "tide", word = "MANA TIDE",
                 life = function() return RD.WATER.tide end,
                 len = function() return (RD.cdLen and RD.cdLen.tide) or RD.COOLS.tide end }
RD.TEST_SPEC = { spell = "Grounding Totem", key = "groundTest", word = "GROUNDING", life = 45, len = 15 }

--- NO PING ON THE FIRST CLICK (Arn, 16 Nov: "dont need to ping first click"): only a standing totem, targeted, is pinged.
--- THE PING FIRST, THE DROP LAST (Arn, 16 Nov night: "when i click mana tide do not ping ... second click pings it only"):
--- on the drop's click no totem stands yet, so /target finds none and nothing is pinged; on the next click the totem is
--- there - targeted, pinged, back to your own target - and the /cast at the end fails quietly while it cools.
function RD.TideMacroFor(spell)
    return "/target " .. spell .. "\n/ping [@target,help,noparty,noraid]"
        .. "\n/targetlasttarget [help,noparty,noraid]\n/cleartarget [help,noparty,noraid]\n/cast " .. spell
end
function RD.TideMacro() return RD.TideMacroFor(RD.TIDE) end

--[[ MANA TIDE FOR BIS USERS (16 Nov 2026, Arn: "yes for bis users too"). Your cast sends TIDE over the shared BiS channel;
  every BiS Healing deck in the group shows "MANA TIDE" and the totem's seconds on YOUR box (yours too, at once). The
  channel holds messages through the game's chat lockdown, so in a fight it can land a little late. ]]
RD.TIDE_COL = { 0.35, 0.85, 1.00, 1 }
function RD.TideSay(spec)
    spec = spec or RD.TIDE_SPEC
    local life = val(spec.life)
    RD.TideHeard(UnitName and plain((UnitName("player"))) or nil, life, true, spec.word)
    local lib = _G.LibBiSComm
    if lib and lib.Send then pcall(lib.Send, lib, "BiSHealing", "TIDE", life, spec.word) end
end
--- Does this deck box's unit carry this name? (whole "Name Surname" or the first name; a realm is cut off)
function RD.BoxIsNamed(unit, who)
    if type(unit) ~= "string" or type(who) ~= "string" then return false end
    who = who:gsub("%-.*$", "")
    local okW, whole = pcall(GetUnitName, unit, false)
    whole = okW and plain(whole) or nil
    if whole and whole == who then return true end
    local okF, first = pcall(UnitName, unit)
    first = okF and plain(first) or nil
    return first ~= nil and (first == who or first == who:match("^(%S+)"))
end
--- A Mana Tide heard (or yours): the tag on that person's box for `secs`, saying `word` (MANA TIDE unless told).
function RD.TideHeard(who, secs, mine, word)
    secs = math.max(1, math.min(tonumber(secs) or RD.WATER.tide, 60))
    word = (type(word) == "string" and word ~= "" and #word <= 12) and word:upper() or "MANA TIDE"
    for _, i in ipairs(RD.conOrder or {}) do
        local sp = RD.spokes and RD.spokes[i]
        local u = sp and sp.unit
        if u and ((mine and u == "player") or RD.BoxIsNamed(u, who)) and sp.deckPlate and sp.deckPlate:IsShown() then
            RD.TideTag(sp, secs, word)
            return sp
        end
    end
    return nil
end
--- The tag's line stays inside its box (it was a fixed 80 px, wider than a 74 px box - sheet 7's test found it).
function RD.TideTagWidth(sp)
    local t, p = sp and sp.tideTag, sp and sp.deckPlate
    if not (t and p) then return false end
    local w = p:GetWidth()
    t:SetSize(math.max(8, ((type(w) == "number" and w > 0) and w or 80) - RD.DECK_TAG.x - 2), 11)
    return true
end
function RD.TideTag(sp, secs, word)
    local t = sp.tideTag
    if not RD.BoxHas(sp, "extras") then                      -- a box too small: the extra tags go first (sheet 7)
        if t then t:Hide() end
        return nil
    end
    if not t then
        t = CreateFrame("Frame", nil, sp.deckPlate)
        -- UNDER THE NAME (Arn's shot, 16 Nov: on a narrow box "CHAINHEAL GROUNDING 34" ran together - "we can just move
        -- it under the name"): the line below the callsign, from the same left edge
        t:SetPoint("TOPLEFT", sp.deckPlate, "TOPLEFT", RD.DECK_TAG.x, RD.DECK_TAG.y - RD.DECK_TAG.size - 3)
        t:SetSize(80, 11)
        t.text = t:CreateFontString(nil, "OVERLAY")
        t.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        t.text:SetPoint("LEFT", t, "LEFT", 0, 0)
        t.text:SetJustifyH("LEFT")
        local c = RD.TIDE_COL
        t.text:SetTextColor(c[1], c[2], c[3], c[4])
        t:SetScript("OnUpdate", function(self, e)
            self.acc = (self.acc or 0) + (tonumber(e) or 0)
            if self.acc < 0.25 then return end
            self.acc = 0
            local left = math.ceil((self.untilAt or 0) - GetTime())
            if left <= 0 then self:Hide() return end
            if left ~= self.shown then self.shown = left self.text:SetText(self.word .. " " .. left) end
        end)
        sp.tideTag = t
    end
    RD.TideTagWidth(sp)
    local lvl = sp.heal and sp.heal.GetFrameLevel and sp.heal:GetFrameLevel()
    if type(lvl) == "number" then t:SetFrameLevel(lvl + 7) end      -- over the bar and the name line
    t.word = word or "MANA TIDE"
    t.untilAt, t.shown, t.acc = GetTime() + secs, math.ceil(secs), 0
    t.text:SetText(t.word .. " " .. math.ceil(secs))
    t:Show()
    return t
end
--[[ MANA TIDE IN THE PARTY'S CHAT (16 Nov 2026, Arn: "i want the cool down to put it in the chat when i click it" - the
  action bar's own ping writes "[Mana Tide Totem (Rank 2)] is ready!", which only the game can send). Our own line, as
  cooldown addons do: when it goes down, its link and "down - ready again in 5:00"; a click while it is cooling, the time
  left. Party or raid only (alone: nothing), one line per RD.TIDE_CHAT_GAP seconds. The time is OUR clock of your cast
  (RD.readyAt[key]), never the client's cooldown object. ]]
RD.TIDE_CHAT_GAP = 3
local function mmss(s)
    s = math.max(0, math.floor(s + 0.5))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end
function RD.TideLink(spec)
    spec = spec or RD.TIDE_SPEC
    local link
    if C_Spell and C_Spell.GetSpellLink then
        local ok, l = pcall(C_Spell.GetSpellLink, spec.spell)
        if ok then link = plain(l) end
    end
    return type(link) == "string" and link or ("[" .. spec.spell .. "]")
end
function RD.TideChatLine(cooling, spec)
    spec = spec or RD.TIDE_SPEC
    local now = GetTime()
    if cooling then
        local left = (RD.readyAt[spec.key] or 0) - now
        if left <= 0 then return nil end
        return RD.TideLink(spec) .. " - " .. mmss(left) .. " cooldown"
    end
    return RD.TideLink(spec) .. " down - ready again in " .. mmss(val(spec.len))
end
-- NOTHING IN CHAT (Arn, 16 Nov night: "when i click mana tide do not ping or say anything in chat, second click pings it
-- only, nothing in chat"): the party's chat line is off; the BiS users' tag (addon messages, never chat) stays
RD.TIDE_CHAT = false
function RD.TideChat(cooling, spec)
    if not RD.TIDE_CHAT then return nil end
    local now = GetTime()
    if RD.tideChatAt and now - RD.tideChatAt < RD.TIDE_CHAT_GAP then return nil end
    local chan = (IsInRaid and IsInRaid()) and "RAID" or ((IsInGroup and IsInGroup()) and "PARTY" or nil)
    if not chan then return nil end
    local line = RD.TideChatLine(cooling, spec)
    if not line then return nil end
    RD.tideChatAt = now
    local ok, err = pcall(SendChatMessage, line, chan)
    RD.tideChatErr = (not ok) and tostring(err) or nil
    return ok and line or nil
end
--- A click on the button while it is cooling: the time left in chat (the drop itself is said on the cast).
function RD.TideClicked(spec)
    spec = spec or RD.TIDE_SPEC
    local left = (RD.readyAt[spec.key] or 0) - GetTime()
    if left > 1 then return RD.TideChat(true, spec) end
    return nil
end

--[[ THE TEST BUTTON (16 Nov 2026): a small button left of the deck, Grounding Totem in Mana Tide's shoes - the same macro
  (drop + ping, the next click pings the standing totem), the same chat lines, the same tag for BiS users, with a 15 s
  cooldown instead of 5 min. `/bish alpha radar tidetest` shows or hides it (out of a fight); never saved. ]]
function RD.BuildTideTest()
    if RD.tideTest then return RD.tideTest end
    local f = RD.frame
    if not f or combat() then return nil end
    local spec = RD.TEST_SPEC
    local b = CreateFrame("Button", "BiSHealingTideTest", f, "SecureActionButtonTemplate")
    if b.RegisterForClicks then b:RegisterForClicks("AnyDown") end
    b:SetSize(RD.SYS_PX + 6, RD.SYS_PX + 6)
    b:SetPoint("TOPRIGHT", f, "TOPLEFT", -6, 0)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(0, 0, 0, 0.6)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    if b.icon.SetTexCoord then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, spec.spell)
        if ok then pcall(b.icon.SetTexture, b.icon, t) end
    end
    b.edges = edge(b, { 1, 0.7, 0.28, 1 }, 1.5)
    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
    b.label:SetTextColor(1, 0.75, 0.3, 1)
    b.label:SetText("TEST")
    local okCd, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
    if okCd and cd then cd:SetAllPoints(b.icon) b.cd = cd end
    b:SetAttribute("*type1", "macro")
    b:SetAttribute("*macrotext1", RD.TideMacroFor(spec.spell))
    b:HookScript("PostClick", function() RD.TideClicked(RD.TEST_SPEC) end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("TEST: " .. spec.spell:upper())
        GameTooltip:AddLine("Works like the Mana Tide button: click drops it and pings; click again while it stands pings the totem. "
            .. "Chat line and the BiS tag too. /bish alpha radar tidetest hides it.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:Hide()
    RD.tideTest = b
    return b
end
function RD.ToggleTideTest()
    if combat() or RD.inFight then (NS.Print or print)("test button: out of a fight only") return nil end
    local b = RD.BuildTideTest()
    if not b then return nil end
    b:SetShown(not b:IsShown())
    return b:IsShown()
end
--- Our cast of the test spell while the test button shows: its clock, its sweep, the tag and the chat line.
function RD.TideTestCast(name, now)
    local b, spec = RD.tideTest, RD.TEST_SPEC
    if not (b and b:IsShown() and name == spec.spell) then return false end
    local len = val(spec.len)
    RD.readyAt[spec.key] = now + len
    if b.cd and b.cd.SetCooldown then pcall(b.cd.SetCooldown, b.cd, now, len) end
    RD.TideSay(spec)
    RD.TideChat(false, spec)
    return true
end

--[[ THE RIPTIDE TRACKER (16 Nov 2026, Arn: "for sham healer rip tide is crucial need a riptide marker on who i riptided and
  on top in los row a riptide duration, the riptide icon will serve as not enough time left to cast another chain heal
  mark ... the bar size should be 6 icons long and when its the last icon that means if i cast a chain the buff will be
  gone by the time it lands"). OUR clock, never the aura (auras go secret in a fight): your Riptide cast (OnCast) starts
  it, on the box you clicked (RD.lastClick within RD.RIP_CLICK s), else the one under the mouse (a wheel turn), else the
  name the game said you aimed at (UNIT_SPELLCAST_SENT, when plain). It lasts RD.RIP_LEN (read off the spell's own words
  out of a fight, else 15 s). The bar: RD.RIP_SEGS segments of one Chain Heal each; it drains, and the last segment holds
  the Riptide icon, lit once the time left is under one Chain Heal (EN.RipPaint). ]]
RD.RIPTIDE = "Riptide"
RD.RIP_LEN = 15
RD.RIP_SEGS = 6
RD.RIP_CLICK = 1.5
RD.rips = {}                                         -- person (RD.RipKey) -> until (GetTime), at most a couple at once
--- WHO, NOT WHICH BOX (17 Nov 2026, Arn's shot: "rip tide is not propagating to the other frames" - he stood in three boxes
--- at once, the tank's and the TARGET / ITS TARGET pair, and only the clicked box was marked): a Riptide belongs to the
--- PERSON - their GUID while the client says it plainly, else the box's own unit token.
function RD.RipKey(unit)
    if not unit then return nil end
    local g
    if UnitGUID then
        local ok, v = pcall(UnitGUID, unit)
        if ok then g = plain(v) end
    end
    if type(g) == "string" and g ~= "" then return g end
    return unit
end
function RD.RipKnown()
    local FM = NS.FM
    return (FM and FM.Ranks and #FM.Ranks(RD.RIPTIDE) > 0) and true or false
end
--- Riptide's length, off its own words out of a fight ("... over 15 sec"); kept.
function RD.RipLength()
    if RD.ripLenRead then return RD.RIP_LEN end
    if combat() then return RD.RIP_LEN end
    if C_Spell and C_Spell.GetSpellDescription then
        local ok, d = pcall(C_Spell.GetSpellDescription, RD.RIPTIDE)
        d = ok and plain(d) or nil
        local n = type(d) == "string" and tonumber(d:match("over ([%d%.]+) sec")) or nil
        if n and n > 3 and n < 60 then RD.RIP_LEN = n RD.ripLenRead = true end
    end
    return RD.RIP_LEN
end
--- The game's word on whom your last spell went to (UNIT_SPELLCAST_SENT), when it is plain.
function RD.RipSent(target)
    if type(target) == "string" and not (NS.Secret and NS.Secret(target)) and target ~= "" then
        RD.sentTarget, RD.sentAt = target, GetTime()
    end
end
--- Whose box a spell of yours just went to: the box you clicked (within RD.RIP_CLICK s), else the one under the mouse,
--- else the box of the name the game said you aimed at. Shared by the Riptide tracker and the heal cues.
function RD.CastTarget(now)
    now = now or GetTime()
    local sp
    if RD.lastClick and RD.lastClickAt and now - RD.lastClickAt <= RD.RIP_CLICK then sp = RD.lastClick end
    sp = sp or RD.over
    if not (sp and sp.unit) and RD.sentTarget and RD.sentAt and now - RD.sentAt <= RD.RIP_CLICK then
        for _, i in ipairs(RD.conOrder or {}) do
            local s = RD.spokes and RD.spokes[i]
            if s and s.unit and RD.BoxIsNamed(s.unit, RD.sentTarget) then sp = s break end
        end
    end
    return sp
end
--- Your Riptide went out: whose box, and its clock.
function RD.RipCast(now)
    now = now or GetTime()
    local sp = RD.CastTarget(now)
    local unit = sp and sp.unit
    if not unit then return nil end
    local key = RD.RipKey(unit)
    RD.rips[key] = now + RD.RipLength()
    RD.ripLast = { unit = unit, key = key, at = now, untilAt = RD.rips[key] }
    RD.RipMarks()
    if NS.EN and NS.EN.RipPaint then NS.EN.RipPaint() end
    return unit
end
--[[ THE HEAL CUE (17 Nov 2026, Arn: "let place it in the middle with a white border so it does not get lost. only for stuff
  that you need to heal the person ... I need to heal this person with chain heal, so I can see it at a glance"): the
  middle of a box is kept for ONE thing - a sign that says heal THIS person now, with this. The Riptide mark is the first
  (a Riptide standing = Chain Heal starts here); the icon in the box's middle, edged white, over the health bar. ]]
RD.CUE = { px = 20, edge = 1, col = { 1, 1, 1, 1 } }
-- THE CUE IS A WORD, NOT AN ICON (20 Nov 2026, Arn: "the riptide buff is nice but maybe people will think if i click here
-- ill riptide" - "maybe we write [Chain Heal] in a color that works on all class colors"): the spell to cast now, in white
-- with a black outline on a dark box sized to it - white on black reads on every class colour the bar can be.
RD.CUE_WORD = { font = "Fonts\\ARIALN.TTF", size = 10, padX = 3, padY = 1, back = { 0, 0, 0, 0.7 }, rip = "Chain Heal" }
function RD.CueMark(sp)
    if sp.cue then return sp.cue end
    -- ITS OWN FRAME OVER THE BAR (Arn's shot, 16 Nov: "no mark on sushii" - a texture on the plate drew UNDER the health
    -- bar, which lives in the pip; the callsign's road: a child frame lifted over the pip, RD.DeckTag)
    local hold = CreateFrame("Frame", nil, sp.deckPlate)
    hold:SetAllPoints(sp.deckPlate)
    local hl = sp.heal and sp.heal.GetFrameLevel and sp.heal:GetFrameLevel()
    if type(hl) == "number" and hold.SetFrameLevel then hold:SetFrameLevel(hl + 6) end
    local C = RD.CUE
    local b = hold:CreateTexture(nil, "OVERLAY", nil, 5)
    b:SetColorTexture(C.col[1], C.col[2], C.col[3], C.col[4])
    local m = hold:CreateTexture(nil, "OVERLAY", nil, 6)
    if m.SetTexCoord then m:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    -- IN THE MIDDLE OF THE HEALTH BAR, not of the whole box (17 Nov, Arn's second shot: the icon row under the bar pulled
    -- it low) - the bar is the pip, sp.heal; since the name header (24 Nov, Arn's shot: "Chain Heal" rode up under the
    -- strip) the health bar under the header, the deck box's own bar (Engineer.lua's e.bar)
    local EN = NS.EN
    local e = sp.en or (EN and EN.Box and sp.heal and EN.Box(sp))
    local bar = (e and e.bar) or sp.heal or sp.deckPlate
    local h = bar.GetHeight and bar:GetHeight()
    local px = math.min(C.px, math.max(10, (type(h) == "number" and h > 0 and h or C.px + 6) - 6))
    m:SetSize(px, px)
    m:SetPoint("CENTER", bar, "CENTER", 0, 0)
    b:SetSize(px + 2 * C.edge, px + 2 * C.edge)
    b:SetPoint("CENTER", m, "CENTER", 0, 0)
    b:Hide() m:Hide()                                           -- (the icon kept for a later look; the word is the cue)
    local W = RD.CUE_WORD
    local back = hold:CreateTexture(nil, "OVERLAY", nil, 5)
    back:SetColorTexture(W.back[1], W.back[2], W.back[3], W.back[4])
    local word = hold:CreateFontString(nil, "OVERLAY", nil)
    word:SetFont(W.font, W.size, "OUTLINE")
    word:SetTextColor(1, 1, 1, 1)
    word:SetPoint("CENTER", bar, "CENTER", 0, 0)
    back:SetPoint("TOPLEFT", word, "TOPLEFT", -W.padX, W.padY)
    back:SetPoint("BOTTOMRIGHT", word, "BOTTOMRIGHT", W.padX, -W.padY)
    back:Hide() word:Hide()
    sp.cue = { hold = hold, edge = b, icon = m, word = word, back = back, bar = bar }
    sp.ripHold = hold
    return sp.cue
end
RD.CUE_FACE = 22
--- THE WORD FITS THE BAR (24 Nov 2026, Arn, a party's thin bars: "maybe make the font smaller" - the 10-point word with
--- its dark box stood taller than the bar and ate into the name header): the font is the bar's height less the box's
--- edges, never above `max`, never below 7. Measured each time it shows (the box height slider changes the bar).
function RD.WordSize(bar, max, pad)
    max = max or RD.CUE_WORD.size
    local okH, h = pcall(function() return bar and bar.GetHeight and bar:GetHeight() end)
    if not (okH and type(h) == "number" and h > 0) then return max end
    return math.max(7, math.min(max, math.floor(h - 2 * (pad or RD.CUE_WORD.padY) - 2)))
end
function RD.CueShow(sp, on)
    local q = sp.cue
    if not q then return end
    -- BiS Cues (21 Nov 2026): the cue card's LOOK - "icon" shows the spell's icon in the middle, else the word
    local icon = on and q.ck and q.tex and NS.CU and NS.CU.Look(q.ck) == "icon"
    local model = on and q.ck and NS.CU and NS.CU.ModelOf(q.ck) or nil        -- (a model: its own dark square, CU.Face)
    if model and not q.face then
        q.face = NS.CU.Face(q.hold, q.ck, RD.CUE_FACE)
        q.face.sq:SetPoint("CENTER", q.icon, "CENTER", 0, 0)
    end
    if q.face then
        if q.ck then q.face.key = q.ck end
        NS.CU.FaceShow(q.face, model ~= nil)
    end
    if on and not icon and not model then
        local W = RD.CUE_WORD
        local size = RD.WordSize(q.bar, W.size, W.padY)
        if q.size ~= size then
            q.size = size
            pcall(q.word.SetFont, q.word, W.font, size, "OUTLINE")
            local pad = (size < W.size) and 0 or W.padY                 -- (a thin bar: the box hugs the word)
            q.back:ClearAllPoints()
            q.back:SetPoint("TOPLEFT", q.word, "TOPLEFT", -W.padX, pad)
            q.back:SetPoint("BOTTOMRIGHT", q.word, "BOTTOMRIGHT", W.padX, -pad)
        end
        q.word:Show() q.back:Show()
    else q.word:Hide() q.back:Hide() end
    if icon then q.icon:Show() q.edge:Show() else q.icon:Hide() q.edge:Hide() end
end

RD.cueTold = {}                                    -- "rip:<person>" whose mark is up: its sound is not said again
--- The marks on the boxes: the Riptide icon in the middle (the heal cue) on EVERY box of whoever has one of yours standing.
function RD.RipMarks()
    local now = GetTime()
    -- EACH MARK ENDS WITH ITS OWN RIPTIDE (Arn's cousin, 16 Nov: "riptide one person and then another person but the icon
    -- stayed on two people, the second rip tide extended the timer for the first one"): the marks were cleared only at a
    -- cast or when the NEWEST one ran out; RD.ripNext = the soonest end, and the bar's ticker calls this when it comes
    -- THE MARK GOES WHEN A CHAIN HEAL STARTED NOW COULD NOT LAND IN TIME (21 Nov 2026, Arn: "if the buff only has one
    -- second left and the cast is 2.5 seconds, I won't benefit from that buff ... if my spell takes two seconds, we remove
    -- it at" two seconds + the lag): shown while (its end - your Chain Heal's cast time with haste - your lag) is ahead
    local lead = RD.CueLead(RD.CUE_WORD.rip)
    local nextAt
    for u, t in pairs(RD.rips) do
        if t <= now then RD.rips[u] = nil
        else
            local at = (t - lead > now) and (t - lead) or t        -- (the next change: the mark going, else the Riptide)
            if not nextAt or at < nextAt then nextAt = at end
        end
    end
    RD.ripNext = nextAt
    local cueNext = RD.CuePrune(now)
    local deck = RD.Deck()
    local on = deck and RD.Sw("rip")
    local told, still = RD.cueTold, {}
    for _, sp in ipairs(RD.spokes or {}) do
        local shown = sp.unit and sp.deckPlate and sp.deckPlate:IsShown()
        local key = shown and RD.RipKey(sp.unit) or nil
        local has = on and key and RD.rips[key] and RD.rips[key] - lead > now
        local tex, word, ck
        if key and RD.CueDead(sp.unit) then key, has = nil, nil end   -- (dead: nothing to heal there - the mark waits)
        if has then tex, word, ck = RD.SpellTex(RD.RIPTIDE), RD.CUE_WORD.rip, "rip" elseif deck and key then tex, word, ck = RD.CueFor(key, now) end
        if tex or word then
            local q = RD.CueMark(sp)
            q.ck = ck
            if q.tex ~= tex then q.tex = tex pcall(q.icon.SetTexture, q.icon, tex) end
            if q.text ~= word then q.text = word q.word:SetText(word or "") end
            if has then sp.ripMark = q.word end
            -- the card's sound, once when the mark comes on somebody (off unless picked; one person, however many boxes)
            local id = ck and key and (ck .. ":" .. key) or nil
            if id then
                if not told[id] and not still[id] and NS.CU and not NS.CU.Quiet() then NS.CU.Say(ck, sp.unit) end
                still[id] = true
            end
        end
        if sp.cue then RD.CueShow(sp, (tex or word) ~= nil) end
    end
    RD.cueTold = still
    RD.CueArm(cueNext)
end

--[[ THE CLASS HEAL CUES (17 Nov 2026, Arn: "build all three" - after the Riptide cue: "the pallies ... need to heal a certain
  person when it has a buff", "druid have something with their swiftmend"). Researched for Forever (wowhead/forever,
  method.gg, guides - numbers from the beta, the in-game tooltip wins): OATH OF LIGHT (a Forever Holy talent, a 5 min buff on
  one ally: your Holy Light / Flash of Light / Holy Shock land harder on them) -> Holy Light on their box; LIGHT'S VIGIL (a
  30 s mark: your next Holy Shock on them skips its cooldown and splashes their party; that Holy Shock ends it) -> Holy
  Shock; SWIFTMEND (needs your Rejuvenation or Regrowth on them; on Forever it reportedly keeps the HoT; 15 s cooldown) ->
  Swiftmend on whoever carries one of yours while it is ready. OUR OWN CLOCK of your casts, never their auras (secret in a
  fight), the Riptide tracker's road (RD.CastTarget). The higher `prio` wins a box's middle. ]]
RD.CUE_DEFS = {
    { key = "oath", cast = "Oath of Light", len = 300, one = true, show = "Holy Light", sw = "oath", prio = 1 },
    { key = "vigil", cast = "Light's Vigil", len = 30, one = true, show = "Holy Shock", sw = "vigil", prio = 2, ends = "Holy Shock", bar = "vigil" },
    { key = "rejuv", cast = "Rejuvenation", len = 12, show = "Swiftmend", sw = "swift", prio = 1, gate = "swift", bar = "hot" },
    { key = "regrowth", cast = "Regrowth", len = 21, show = "Swiftmend", sw = "swift", prio = 1, gate = "swift", bar = "hot" },
}
RD.SWIFTMEND, RD.SWIFT_CD = "Swiftmend", 15
--[[ WHAT A PALADIN OR A DRUID RUNS INTO (17 Nov 2026, Arn: "I dont play the other classes so think of all the possible
  scenarios they might run into"), and what the cues do:
  - the person DIES: their box shows no cue (RD.CueDead, plain answers only); the clock keeps running, so a quick rez
    still has it.
  - the buff is DISPELLED, clicked off, or runs out early; a /RELOAD or a new login wipes our clock: out of a fight,
    when the numbers are plain again, RD.CueSeed reads the truth off every box - your own Riptide / Oath of Light /
    Light's Vigil / Rejuvenation / Regrowth on them, its real end - and puts the clock right (a mark nobody wears goes).
    In a fight our clock is all there is (their auras are secret).
  - HOLY SHOCK ON AN ENEMY (it is a damage spell too): never spends the Vigil - when the game named the target and it is
    not the box's person, the cast is not theirs (RD.CueCast).
  - Swiftmend's cooldown: off the book (GetSpellBaseCooldown), else 15 s.
  - Swiftmend EATING the HoT (Classic did; Forever reportedly does not): the cue stays on after a Swiftmend; if it did eat
    it, the next out-of-fight read (RD.CueSeed) takes the mark away.
  - two paladins, two druids: each addon tracks its OWN casts only (the aura reads ask for yours: "HELPFUL|PLAYER"). ]]
function RD.CueDead(unit)
    if not unit then return false end
    if UnitIsConnected then                             -- (offline: nobody there to heal either - 17 Nov, the status words)
        local okC, c = pcall(UnitIsConnected, unit)
        if okC and plain(c) == false then return true end
    end
    if not UnitIsDeadOrGhost then return false end
    local ok, d = pcall(UnitIsDeadOrGhost, unit)
    return ok and plain(d) == true
end
--- Swiftmend's cooldown off the book, else RD.SWIFT_CD; read once, out of a fight.
function RD.SwiftCd()
    if RD.swiftCdRead then return RD.swiftCdRead end
    if combat() then return RD.SWIFT_CD end
    local id
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, RD.SWIFTMEND)
        id = ok and type(info) == "table" and plain(info.spellID) or nil
    end
    if id and GetSpellBaseCooldown then
        local ok, ms = pcall(GetSpellBaseCooldown, id)
        ms = ok and plain(ms) or nil
        if type(ms) == "number" and ms >= 3000 and ms <= 120000 then RD.swiftCdRead = ms / 1000 return RD.swiftCdRead end
    end
    return RD.SWIFT_CD
end
--- OUT OF A FIGHT: the truth off every box - your own opener auras on them, their real end. Answers how many it read.
function RD.CueSeed()
    if combat() or (NS.Blind and NS.Blind()) then return 0 end
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if not get then return 0 end
    local now = GetTime()
    local names = { [RD.RIPTIDE] = "rip" }
    for _, d in ipairs(RD.CUE_DEFS) do names[d.cast] = d end
    local FM = NS.FM
    local seen, read = {}, 0
    for _, sp in ipairs(RD.spokes or {}) do
        local u = sp.unit
        local key = u and RD.RipKey(u)
        if key and not seen[key] then
            seen[key] = true
            for spell, d in pairs(names) do
                if FM and FM.Ranks and #FM.Ranks(spell) > 0 then
                    local ok, a = pcall(get, u, spell, "HELPFUL|PLAYER")
                    if ok and not (NS.Secret and NS.Secret(a)) then
                        read = read + 1
                        local exp = type(a) == "table" and plain(a.expirationTime) or nil
                        local m = (d == "rip") and RD.rips or (function() RD.cueMarks[d.key] = RD.cueMarks[d.key] or {} return RD.cueMarks[d.key] end)()
                        if type(exp) == "number" and exp > now then
                            m[key] = exp
                            if d ~= "rip" and d.bar then
                                local l = RD.cueLast[d.bar]
                                if not l or l.key == key or exp > (l.untilAt or 0) then
                                    local dur = plain(a.duration)
                                    RD.cueLast[d.bar] = { key = key, at = now, len = (type(dur) == "number" and dur > 0) and dur or RD.SpellSecs(d.cast, d.len), untilAt = exp }
                                end
                            end
                        elseif a == nil then
                            m[key] = nil                       -- nobody wears it (dispelled, clicked off, ran out)
                            if d ~= "rip" and d.bar and RD.cueLast[d.bar] and RD.cueLast[d.bar].key == key then RD.cueLast[d.bar] = nil end
                            if d == "rip" and RD.ripLast and RD.ripLast.key == key then RD.ripLast = nil end
                        end
                    end
                end
            end
        end
    end
    RD.RipMarks()
    if NS.EN and NS.EN.RipPaint then NS.EN.RipPaint() end
    return read
end
RD.cueMarks = {}                                     -- cue key -> person (RD.RipKey) -> until
RD.cueLast = {}                                      -- the synergy bar's newest: "vigil" / "hot" -> { key, at, len, untilAt }
RD.cueSecs, RD.cueTex = {}, {}
--- A spell's icon (asked once).
function RD.SpellTex(name)
    if RD.cueTex[name] == nil and C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, name)
        RD.cueTex[name] = (ok and plain(t)) or false
    end
    return RD.cueTex[name] or nil
end
--- How long a spell's effect lasts, off its own words out of a fight ("... over 12 sec", "... for 5 min"); kept.
function RD.SpellSecs(name, default)
    local v = RD.cueSecs[name]
    if v then return v end
    if combat() or not (C_Spell and C_Spell.GetSpellDescription) then return default end
    local ok, d = pcall(C_Spell.GetSpellDescription, name)
    d = ok and plain(d) or nil
    local n
    if type(d) == "string" then
        local sec = d:match("(%d+%.?%d*) sec")
        local min = d:match("(%d+%.?%d*) min")
        n = (sec and tonumber(sec)) or (min and tonumber(min) and tonumber(min) * 60) or nil
    end
    RD.cueSecs[name] = (n and n >= 3 and n <= 900) and n or default
    return RD.cueSecs[name]
end
--- Swiftmend learned and ready by our clock.
function RD.SwiftReady(now)
    local FM = NS.FM
    if not (FM and FM.Ranks and #FM.Ranks(RD.SWIFTMEND) > 0) then return false end
    return (now or GetTime()) >= (RD.swiftAt or 0)
end
--- The game named a different target than the box's person (a Holy Shock on an enemy, a keybind on your target): true.
function RD.CueElsewhere(sp, now)
    local who = RD.sentTarget
    if not (who and RD.sentAt and now - RD.sentAt <= RD.RIP_CLICK and sp and sp.unit) then return false end
    return not RD.BoxIsNamed(sp.unit, who)
end
--- A spell of yours went out: start, move or end a cue. Answers true when a cue changed.
function RD.CueCast(name, now)
    if not name then return false end
    now = now or GetTime()
    local hit = false
    if name == RD.SWIFTMEND then RD.swiftAt = now + RD.SwiftCd() hit = true end
    for _, d in ipairs(RD.CUE_DEFS) do
        if d.cast == name or d.ends == name then
            local sp = RD.CastTarget(now)
            local key = sp and sp.unit and RD.RipKey(sp.unit)
            local m = RD.cueMarks[d.key] or {}
            RD.cueMarks[d.key] = m
            if d.cast == name and key then
                if d.one then for k in pairs(m) do m[k] = nil end end
                local len = RD.SpellSecs(d.cast, d.len)
                m[key] = now + len
                if d.bar then RD.cueLast[d.bar] = { key = key, at = now, len = len, untilAt = m[key] } end   -- the synergy bar's
                hit = true
            elseif d.ends == name and key and m[key] and not RD.CueElsewhere(sp, now) then
                m[key] = nil
                local l = d.bar and RD.cueLast[d.bar]
                if l and l.key == key then RD.cueLast[d.bar] = nil end
                hit = true
            end
        end
    end
    if hit then RD.RipMarks() end
    return hit
end
--- The ended ones gone; answers the soonest time anything changes (an end, Swiftmend coming ready), or nil.
function RD.CuePrune(now)
    local nextAt
    for _, d in ipairs(RD.CUE_DEFS) do
        local m = RD.cueMarks[d.key]
        local lead = m and next(m) and RD.CueLead(d.show) or 0
        for k, t in pairs(m or {}) do
            if t <= now then m[k] = nil
            else
                local at = (t - lead > now) and (t - lead) or t
                if not nextAt or at < nextAt then nextAt = at end
            end
        end
    end
    if RD.swiftAt and RD.swiftAt > now and (not nextAt or RD.swiftAt < nextAt) then nextAt = RD.swiftAt end
    return nextAt
end
--- How long before a mark ends its cue must go: the payoff's cast time over your haste (an instant: 0) plus your lag -
--- a cast started later lands after the buff is gone (Arn, 21 Nov). Plain numbers only; the book's own cast time.
function RD.CueLead(spell)
    local FM, EN = NS.FM, NS.EN
    local ct = (FM and FM.SeqCastTime and spell and FM.SeqCastTime(spell)) or 2.5
    if spell ~= "Chain Heal" and FM and FM.CAST_GUESS and ct == FM.CAST_GUESS then ct = 0 end   -- (an instant)
    local haste = (FM and FM.Haste and FM.Haste()) or 0
    return ct / (1 + haste / 100) + ((EN and EN.Lag and EN.Lag()) or 0)
end
--- The icon a person's box should show for a class cue (the highest prio standing), or nil.
function RD.CueFor(key, now)
    local best
    for _, d in ipairs(RD.CUE_DEFS) do
        local m = RD.cueMarks[d.key]
        local t = m and m[key]
        if t and t - RD.CueLead(d.show) > now and RD.Sw(d.sw) and (d.gate ~= "swift" or RD.SwiftReady(now)) and (not best or d.prio > best.prio) then
            best = d
        end
    end
    return best and RD.SpellTex(best.show) or nil, best and best.show or nil, best and best.sw or nil
end
--- One timer for the next change (never one per cue): the marks repainted then.
function RD.CueArm(at)
    if not at or RD.cueArmed == at or not (C_Timer and C_Timer.After) then return end
    RD.cueArmed = at
    local wait = math.max(0.05, at - GetTime() + 0.05)
    C_Timer.After(wait, function()
        if RD.cueArmed ~= at then return end
        RD.cueArmed = nil
        RD.RipMarks()
    end)
end

--[[ THE CHAIN HEAL BOUNCE PROBE (16 Nov 2026, Arn: "after I cast chain heal see a chain heal line on the three targets it
  bounced to? A 3 bounce is a gold line, 3 bounce and 3 crits get a celebration, 1 bounce a buzzer"). Before drawing
  anything: does the game tell an addon who was healed? UNIT_COMBAT (unit, "HEAL", "CRITICAL"/"", amount, school) is
  what unit frames show heal numbers from. Armed by hand (`/bish alpha radar bounce on`, it fires for every hit on every
  unit, so never left on), it records - as KINDS only (plain / hidden / nil), nothing compared - each event within
  RD.BOUNCE_WINDOW s of your last Chain Heal, and `/bish alpha radar bounce` prints the last ones. ]]
RD.BOUNCE_WINDOW = 1.5
RD.BOUNCE_BEFORE = 0.5
RD.bounceLog = {}
RD.bounceRing = {}
--- Your Chain Heal went out: a fresh log, opened with whatever landed in the half second before (marked "before").
function RD.BounceStart(now)
    RD.bounceLog = {}
    for _, e in ipairs(RD.bounceRing) do
        if now - e.t <= RD.BOUNCE_BEFORE then
            RD.bounceLog[#RD.bounceLog + 1] = string.format("-%.2fs before %s", now - e.t, e.d)
        end
    end
    RD.bounceRing = {}
end
local function kindOf(v)
    if v == nil then return "nil" end
    if NS.Secret and NS.Secret(v) then return "hidden" end
    return tostring(v)
end
function RD.BounceArm(on)
    local f = RD.bounceFrame
    if on and not f then
        f = CreateFrame("Frame")
        f:SetScript("OnEvent", function(_, _, unit, action, flag, amount)
            local now = GetTime()
            local d = string.format("%s %s %s amount=%s", kindOf(unit), kindOf(action), kindOf(flag),
                (amount == nil and "nil") or ((NS.Secret and NS.Secret(amount)) and "hidden" or "plain"))
            -- THE LAST HALF SECOND BEFORE (Arn's first run, 16 Nov: two heals at +0.00, the first target missing - its
            -- heal can arrive in the same frame BEFORE our cast event, so the cast keeps what came just before it)
            local ring = RD.bounceRing
            if #ring >= 12 then table.remove(ring, 1) end
            ring[#ring + 1] = { t = now, d = d }
            local at = RD.chainAt
            if not at or now < at or now - at > RD.BOUNCE_WINDOW then return end
            local log = RD.bounceLog
            if #log >= 24 then table.remove(log, 1) end
            log[#log + 1] = string.format("+%.2fs %s", now - at, d)
        end)
        RD.bounceFrame = f
    end
    if not f then return false end
    if on then pcall(f.RegisterEvent, f, "UNIT_COMBAT") else f:UnregisterAllEvents() end
    RD.bounceOn = on and true or false
    return RD.bounceOn
end
function RD.BounceStatus()
    local P = NS.Print or print
    P("chain heal bounces: probe %s, last Chain Heal %s ago, %d events:", RD.bounceOn and "ON" or "off",
        RD.chainAt and string.format("%.1fs", GetTime() - RD.chainAt) or "never", #RD.bounceLog)
    for _, l in ipairs(RD.bounceLog) do P("  %s", l) end
    return #RD.bounceLog
end

--[[ THE CHAIN HEAL PATH (16 Nov 2026, Arn picked B, the lightning, off https://claude.ai/artifact/X85oCkn5UgGfgauC6iPfEH; "you
  pick sounds"). The probe measured it live: UNIT_COMBAT names each bounce (unit, "HEAL", "CRITICAL"/"") PLAINLY, only the
  amount is hidden; every bounce lands in ONE frame, the first one often just BEFORE our cast event; the same person also
  comes as target / targettarget / softfriend / nameplateN, and other heals mix in a little before or after. So:
  LEAN: UNIT_COMBAT is registered only from your Chain Heal's UNIT_SPELLCAST_SENT (instant ones too) and lets ITSELF go on
    the first event after the landing (never from a timer); while it listens, anything but a group token's HEAL costs one
    check. Each group HEAL goes into a short ring.
  JUDGE: at the landing (UNIT_SPELLCAST_SUCCEEDED, RD.OnCast) a C_Timer a moment later takes the heals within
    RD.BOUNCE_SAME of it, group tokens only (player / partyN / raidN), one per box (RD.BounceSpoke; aliases mapped out of a
    fight, RD.BounceMap), the box you clicked first, then in the order the game told us.
  DRAW (RD.BounceDraw): a jagged bolt box to box on its own layer over the deck - gold 3, amber 2 - a star on each crit,
    sparkling when all 3 crit; one box: a red flashing outline. Fades over RD.BOUNCE_HOLD.
  SOUNDS (own switch, SFX): all 3 crit = the quest-complete fanfare; one box = the quest-failed buzz. Nothing for 2 or 3. ]]
RD.BOUNCE_SAME = 0.06
RD.BOUNCE_HOLD = 1.5
RD.BOUNCE_COL = { [3] = { 1.00, 0.83, 0.30 }, [2] = { 1.00, 0.65, 0.15 }, [1] = { 1.00, 0.30, 0.30 } }
RD.BOUNCE_FANFARE = (SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE) or 878
RD.BOUNCE_BUZZ = (SOUNDKIT and SOUNDKIT.IG_QUEST_FAILED) or 847
RD.BOUNCE_SEGS = 6
RD.bnc = { ring = {} }
RD.bounceAlias = {}
function RD.BounceOn() return RD.Deck() and RD.Sw("bounce") end
local function groupToken(u)
    if type(u) ~= "string" or (NS.Secret and NS.Secret(u)) then return false end
    return u == "player" or u:find("^party%d$") ~= nil or u:find("^raid%d+$") ~= nil
end
RD.BounceGroupToken = groupToken
--- Out of a fight: "player" and party1-4 point at whichever box holds them (a raid's boxes hold raidN).
function RD.BounceMap()
    local m = {}
    if UnitIsUnit then
        for _, sp in ipairs(RD.spokes or {}) do
            local u = sp.unit
            if u then
                for _, a in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
                    if a ~= u then
                        local ok, same = pcall(UnitIsUnit, a, u)
                        if ok and not (NS.Secret and NS.Secret(same)) and same == true then m[a] = sp end
                    end
                end
            end
        end
    end
    RD.bounceAlias = m
    return m
end
--- The box a group token names, or nil.
function RD.BounceSpoke(u)
    for _, sp in ipairs(RD.spokes or {}) do
        if sp.unit == u and sp.deckPlate and sp.deckPlate:IsShown() then return sp end
    end
    local sp = RD.bounceAlias[u]
    if sp and sp.deckPlate and sp.deckPlate:IsShown() then return sp end
    return nil
end
local bounceEv = CreateFrame("Frame")
RD.bounceEv = bounceEv
bounceEv:SetScript("OnEvent", function(self, _, unit, action, flag)
    local b, now = RD.bnc, GetTime()
    if (b.landedAt and now - b.landedAt > 0.25) or (not b.landedAt and now - (b.armedAt or 0) > 6) then
        self:UnregisterAllEvents()                    -- done (or the cast never landed): let go, on an event
        b.listening = false
        return
    end
    if (NS.Secret and NS.Secret(action)) or action ~= "HEAL" or not groupToken(unit) then return end
    local ring = b.ring
    if #ring >= 16 then table.remove(ring, 1) end
    ring[#ring + 1] = { t = now, u = unit, crit = not (NS.Secret and NS.Secret(flag)) and flag == "CRITICAL" }
end)
--- UNIT_SPELLCAST_SENT: a Chain Heal is on its way - listen from now.
function RD.BounceSent(spellID)
    if not RD.BounceOn() or (NS.Secret and NS.Secret(spellID)) or type(spellID) ~= "number" then return false end
    local ok, name = false, nil
    if C_Spell and C_Spell.GetSpellName then ok, name = pcall(C_Spell.GetSpellName, spellID) end
    if not ok or (NS.Secret and NS.Secret(name)) or name ~= "Chain Heal" then return false end
    local b = RD.bnc
    b.armedAt, b.landedAt, b.ring = GetTime(), nil, {}
    if not b.listening then
        pcall(bounceEv.RegisterEvent, bounceEv, "UNIT_COMBAT")
        b.listening = true
    end
    return true
end
--- Your Chain Heal landed (UNIT_SPELLCAST_SUCCEEDED): judge it a moment later, when every bounce is in.
function RD.BounceLanded(now)
    local b = RD.bnc
    if not (b.armedAt and RD.BounceOn()) then return false end
    b.landedAt = now or GetTime()
    if C_Timer and C_Timer.After then C_Timer.After(RD.BOUNCE_SAME, RD.BounceJudge) else RD.BounceJudge() end
    return true
end
--- The boxes it landed on, in order (the one you clicked first), and the crits. Draws; answers the count.
function RD.BounceJudge()
    local b = RD.bnc
    local at = b.landedAt
    if not at then return 0 end
    local path, crit, seen = {}, {}, {}
    local function add(sp, c)
        if not sp then return end
        if not seen[sp] then seen[sp] = true path[#path + 1] = sp end
        if c then crit[sp] = true end
    end
    local hits = {}
    for _, e in ipairs(b.ring) do
        if math.abs(e.t - at) <= RD.BOUNCE_SAME then hits[#hits + 1] = { sp = RD.BounceSpoke(e.u), crit = e.crit } end
    end
    local first = RD.lastClick and RD.lastClickAt and at - RD.lastClickAt <= 4 and RD.lastClick or nil
    for _, h in ipairs(hits) do if h.sp == first then add(first, h.crit) end end
    for _, h in ipairs(hits) do add(h.sp, h.crit) end
    b.armedAt = nil
    while #path > 3 do table.remove(path) end
    local crits = 0
    for _, sp in ipairs(path) do if crit[sp] then crits = crits + 1 end end
    b.last = { n = #path, crits = crits, at = at }
    if #path > 0 then                                 -- a fight feature's first deploy: a slip never breaks your casts
        local okD, err = pcall(RD.BounceDraw, path, crit)
        if not okD then RD.bounceErr = err end
    end
    return #path
end
-- the layer, its lines, stars and the red outline: built on first use, kept
local function bounceLayer()
    local fx = RD.bounceFx
    if fx then return fx end
    fx = CreateFrame("Frame", nil, RD.conLayer or RD.frame or UIParent)
    fx:SetAllPoints(RD.conLayer or RD.frame or UIParent)
    if fx.SetFrameLevel and fx.GetParent and fx:GetParent().GetFrameLevel then
        local lvl = fx:GetParent():GetFrameLevel()
        if type(lvl) == "number" then fx:SetFrameLevel(lvl + 40) end
    end
    fx.lines, fx.dots, fx.stars = {}, {}, {}
    fx.red = CreateFrame("Frame", nil, fx)
    fx.red.edges = edge(fx.red, { 1, 0.3, 0.3, 1 }, 3)
    fx.red:Hide()
    fx:Hide()
    RD.bounceFx = fx
    return fx
end
local function bounceLine(fx, i)
    local l = fx.lines[i]
    if not l then
        l = fx:CreateLine(nil, "OVERLAY")
        if l.SetTexture then l:SetTexture("Interface\\Buttons\\WHITE8X8") end
        fx.lines[i] = l
    end
    return l
end
local function bounceStar(fx, i)
    local s = fx.stars[i]
    if not s then
        s = fx:CreateTexture(nil, "OVERLAY", nil, 7)
        s:SetTexture("Interface\\Cooldown\\star4")
        if s.SetBlendMode then s:SetBlendMode("ADD") end
        s:SetVertexColor(1, 0.85, 0.35, 1)
        fx.stars[i] = s
    end
    return s
end
--- A box's middle, on the layer's own coordinates (from its bottom-left).
local function middleOf(fx, sp)
    local p = sp.deckPlate
    if not (p and p.GetCenter) then return nil end
    local cx, cy = p:GetCenter()                      -- not `p and p:GetCenter()`: `and` keeps only the first answer
    local ox, oy = fx:GetLeft(), fx:GetBottom()
    if type(cx) ~= "number" or type(cy) ~= "number" or type(ox) ~= "number" or type(oy) ~= "number" then return nil end
    return cx - ox, cy - oy
end
function RD.BounceDraw(path, crit)
    local fx = bounceLayer()
    local n = #path
    local col = RD.BOUNCE_COL[math.min(n, 3)]
    for _, l in ipairs(fx.lines) do l:Hide() end
    for _, s in ipairs(fx.stars) do s:Hide() end
    fx.red:Hide()
    local li = 0
    if n >= 2 then
        for i = 1, n - 1 do
            local x1, y1 = middleOf(fx, path[i])
            local x2, y2 = middleOf(fx, path[i + 1])
            if x1 and x2 then
                local dx, dy = x2 - x1, y2 - y1
                local len = math.max(1, math.sqrt(dx * dx + dy * dy))
                local px, py = x1, y1
                for s = 1, RD.BOUNCE_SEGS do
                    local f = s / RD.BOUNCE_SEGS
                    local qx, qy = x1 + dx * f, y1 + dy * f
                    if s < RD.BOUNCE_SEGS then           -- the jag: alternately off the straight line, a little random
                        local off = ((s % 2 == 1) and 1 or -1) * (4 + math.random() * 5)
                        qx, qy = qx - dy / len * off, qy + dx / len * off
                    end
                    for layer = 1, 2 do                  -- a wide soft glow, then a thin bright core
                        li = li + 1
                        local l = bounceLine(fx, li)
                        l:SetStartPoint("BOTTOMLEFT", fx, px, py)
                        l:SetEndPoint("BOTTOMLEFT", fx, qx, qy)
                        if layer == 1 then
                            l:SetThickness(6) l:SetVertexColor(col[1], col[2], col[3], 0.35)
                        else
                            l:SetThickness(1.6) l:SetVertexColor(1, 0.98, 0.88, 1)
                        end
                        l:Show()
                    end
                    px, py = qx, qy
                end
            end
        end
    else
        local p = path[1].deckPlate
        fx.red:ClearAllPoints()
        fx.red:SetPoint("TOPLEFT", p, "TOPLEFT", -2, 2)
        fx.red:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 2, -2)
        fx.red:Show()
    end
    local si, crits = 0, 0
    for _, sp in ipairs(path) do
        if crit[sp] then
            crits = crits + 1
            si = si + 1
            local s = bounceStar(fx, si)
            s:ClearAllPoints()
            s:SetPoint("CENTER", sp.deckPlate, "TOPRIGHT", -26, -9)
            s:SetSize(18, 18)
            s:Show()
        end
    end
    local party = n >= 3 and crits >= 3
    if RD.Sw("bsound") and PlaySound then
        if party then pcall(PlaySound, RD.BOUNCE_FANFARE, "SFX")
        elseif n == 1 then pcall(PlaySound, RD.BOUNCE_BUZZ, "SFX") end
    end
    fx.age, fx.party, fx.single, fx.nStars = 0, party, n == 1, si
    fx:SetAlpha(0)
    fx:Show()
    fx:SetScript("OnUpdate", function(self, e)
        self.age = self.age + (tonumber(e) or 0)
        local a, t = self.age, RD.BOUNCE_HOLD
        if a >= t then self:Hide() self:SetScript("OnUpdate", nil) return end
        local alpha = (a < 0.08 and a / 0.08) or (a < 0.5 and 1) or (1 - (a - 0.5) / (t - 0.5))
        if self.single and a < 0.6 and math.floor(a * 8) % 2 == 1 then alpha = alpha * 0.25 end   -- the red blinks
        self:SetAlpha(alpha)
        if self.party and a < 0.7 then                 -- all three crit: the stars swell and spin
            for i = 1, self.nStars do
                local s = self.stars[i]
                s:SetSize(18 + a * 30, 18 + a * 30)
                if s.SetRotation then s:SetRotation(a * 4) end
            end
        end
    end)
    return n
end
function RD.BounceStatus2()
    local P = NS.Print or print
    local l = RD.bnc.last
    P("chain heal path: %s, sounds %s, listening %s, last: %s%s", RD.BounceOn() and "on" or "off", RD.Sw("bsound") and "on" or "off",
        tostring(RD.bnc.listening == true), l and string.format("%d boxes, %d crits", l.n, l.crits) or "none yet",
        RD.bounceErr and (" - draw error: " .. tostring(RD.bounceErr)) or "")
    return l and l.n or 0
end

function RD.TideHook()
    local lib = _G.LibBiSComm
    if RD.tideHooked or not (lib and lib.RegisterHandler) then return false end
    lib:RegisterHandler("BiSHealing", "TIDE", function(sender, secs, word) RD.TideHeard(sender, secs, false, word) end)
    RD.tideHooked = true
    if RD.tide and RD.tide.HookScript and not RD.tide.tideChatHooked then
        RD.tide:HookScript("PostClick", function() RD.TideClicked() end)
        RD.tide.tideChatHooked = true
    end
    return true
end

--- Arm one tool: its click (a macro written out of a fight) and its light point. `macro` nil = this tool is not here.
local function armTool(b, macro, words, title, what)
    b:SetAttribute("*type1", macro and "macro" or nil)
    b:SetAttribute("*macrotext1", macro)
    b:EnableMouse(macro and true or false)
    b.macro = macro
    if not macro then b.tip = nil return end
    RD.LearnTool(b, words)
    toolTip(b, title, what)
end

--- THE REGEN TOOLS, out of a fight (Arn: "they are always there and we use ingame calculations out of fight"): Mana Tide
--- if you know it, the best mana potion, the best drink - each learns its amount and gets its click.
function RD.ArmTools()
    if combat() or not RD.tide then return false end
    local FM = NS.FM
    local tide = FM and FM.Ranks and #FM.Ranks(RD.TIDE) > 0
    armTool(RD.tide, tide and RD.TideMacro() or nil, tide and describe(RD.TIDE), "MANA TIDE", RD.TIDE)
    if RD.tide.HookScript and not RD.tide.tideChatHooked then           -- a click while cooling: the time left in chat
        RD.tide:HookScript("PostClick", function() RD.TideClicked() end)
        RD.tide.tideChatHooked = true
    end
    local potion = RD.BestItem(RD.POTION)
    RD.potion.item = potion
    armTool(RD.potion, potion and ("/use item:" .. potion) or nil, itemWords(potion), "MANA POTION",
            "the best mana potion in your bags")
    local drink = RD.BestItem("Drink")
    RD.fuel.item = drink
    armTool(RD.fuel, drink and ("/use item:" .. drink) or nil, itemWords(drink), "DRINK", "the best drink in your bags")
    RD.ItemIcon(RD.potion, potion)                   -- the potion and the drink you would use, their own icons
    RD.ItemIcon(RD.fuel, drink)
    RD.SpellIcon(RD.tide, tide and RD.TIDE or nil)   -- Mana Tide and Mana Spring, their spells' own icons
    RD.SpellIcon(RD.reserve, spring and RD.SPRING or nil)
    local spring = FM and FM.Ranks and #FM.Ranks(RD.SPRING) > 0
    armTool(RD.reserve, spring and ("/cast " .. RD.SPRING) or nil, spring and describe(RD.SPRING), "MANA SPRING",
            RD.SPRING .. " - the last resort: lights only when Mana Tide and your potion are spent (or not here)")
    -- the potion's use-spell, so our own clock knows it when you drink one in a fight
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    RD.potion.spellId = nil
    if potion and getSpell then
        local okS, _, sid = pcall(getSpell, potion)
        RD.potion.spellId = okS and plain(sid) or nil
    end
    RD.ArmChaff()
    RD.ArmTotems()
    RD.SeedCooldowns()
    RD.PaintKnobs()
    return true
end

--- Your chaff: RD.CHAFF[class] if trained, and never the same spell as your interrupt (a priest whose only interrupt is
--- Psychic Scream has no second answer). nil = none.
function RD.ChaffSpell()
    local okC, _, class = pcall(UnitClass, "player")
    class = okC and plain(class) or nil
    local name = RD.CHAFF[class or ""]
    local FM, FG = NS.FM, NS.FG
    if not (name and FM and FM.Ranks and #FM.Ranks(name) > 0) then return nil end
    if FG and FG.KickSpell and FG.KickSpell() == name then return nil end
    return name
end

--- Arm the chaff (its click, written out of a fight) and show the defence rail only when it holds it.
function RD.ArmChaff()
    local b = RD.chaff
    if combat() or not b then return false end
    local spell = RD.ChaffSpell()
    local macro = spell and ("/cast " .. spell) or nil
    b:SetAttribute("*type1", macro and "macro" or nil)
    b:SetAttribute("*macrotext1", macro)
    b:EnableMouse(macro and true or false)
    b.macro, b.spell = macro, spell
    b.tip = spell and { spell:upper(), "The catch-all: lights when an enemy casts and your interrupt is cooling.  "
                        .. "No target needed." } or nil
    RD.SpellIcon(b, spell)                            -- Grounding Totem's own icon
    if RD.defRail then
        -- ALWAYS SHOWN (Arn, 10 Nov: "lets always show the full square rail even if there is nothing there"): the
        -- panel is a closed square whether the chaff or the res is in it or not. ON THE RADAR ONLY (11 Nov, the
        -- cousin's engineer view had a right rail): this also runs on its own (max mana changes, a fight ends), after
        -- RD.ApplyView hid it, so it asks the view itself
        if RD.Console and RD.Console() then RD.defRail:Hide() else RD.defRail:Show() end
        RD.ClampRails()
    end
    return spell
end

--[[ THE TOTEMS (11 Nov 2026, Arn, with the four spells' tooltips: "need these in the radar engineering utility bar, some
  how its always cast them all then you bring them too you and recall to get mana back"). Three buttons under the res on
  the right rail (the engineer's view: their own line under the tools), one per step of that loop:
    CALL     left = Call of the Elements, right = Call of the Ancestors (whichever you know on both when only one):
             lit OUT OF A FIGHT while none of your totems stand (Arn, 11 Nov: "can be turned on before the fight i am
             not pressing that during combat i have to heal")
    BRING    Totemic Call (relocates them to you, 30 s): IN A FIGHT only, while they stand and it is ready
             (Arn, 11 Nov: "does not nevessarly have to be when i move i can just be lit up during combat")
    OUT OF A FIGHT, BRING OR RECALL (Arn, 11 Nov: "if i just dropped them its cheaper to bring them and if they are about
    to run out a recall them to get mana back"): after a fight they stood through (RD.totemsFought), with more than
    RD.TOTEM_LOW seconds left BRING lights (once - a bring out of a fight puts it out till the next fight, and never
    straight after a CALL before the pull); with RD.TOTEM_LOW or less left RECALL lights (fought or not - mana back
    before they run out). A recall = none stand = CALL lights again. What is left: the plain totem timers out of a
    fight (the earliest end among totems that last RD.TOTEM_SHORT+ s - a short fire totem does not decide), else our
    clock from the Call
  WHAT STANDS IS OUR OWN CLOCK: the totem slots go secret in a fight (solved.md), so a Call / any "... Totem" of yours
  starts RD.totemsUntil (RD.TOTEM_LIFE, Mana Tide its 12 s), a Recall ends it; out of a fight the slots are read plainly
  (FB.TotemSlot, PLAYER_TOTEM_UPDATE) and correct it. ]]
RD.CALLS = { "Call of the Elements", "Call of the Ancestors" }
RD.TCALL, RD.RECALL = "Totemic Call", "Totemic Recall"
RD.TOTEM_LIFE = 300                                 -- seconds a totem stands (Arn, 11 Nov: "totems last 5 min"; Mana Tide: RD.WATER.tide)
RD.COOLS.tcall = 30
RD.totemsUntil = 0
RD.totemsFought = false                             -- the totems standing now stood through a fight (BRING's gate after it)
RD.totemsBrought = false                            -- brought along out of a fight since the last one (BRING out till the next)
RD.TOTEM_LOW = 30                                   -- seconds left: at or under = RECALL, over = BRING (out of a fight)
RD.TOTEM_SHORT = 60                                 -- a totem lasting less (a fire totem) does not decide when they run out
--[[ IN A FIGHT (11 Nov 2026, Arn: "do the totem timers in combat"; the road ForeverAuras 1.3.9 walks, learnt not copied):
  the slots go secret, but PLAYER_TOTEM_UPDATE still names the SLOT. One within RD.TOTEM_CAST_WINDOW of a totem cast of
  yours (before or after it) = that slot went down; any other = that slot's totem died or ran out. Every slot known
  empty = none stand (RD.totemsUntil 0: BRING goes dark mid-fight). THE TIMER: `GetTotemDuration(slot)` hands the
  client's own duration object for the deciding slot (RD.lifeSlot - the earliest-ending long-lived one, picked out of
  a fight; earth until then) - handed untouched to a cooling disc on CALL (SetCooldownFromDurationObject) - dark while they stand,
  so the time left is the game's, fight or not. Lua never reads it. ]]
RD.TOTEM_CAST_WINDOW = 0.5
RD.EARTH_SLOT = 2
RD.slotUp, RD.slotSeen = {}, {}                     -- slot -> down (true) / empty (false) / unknown (nil); slot -> when an update named it
RD.lastTotemCast = 0

local function knows(spell) local FM = NS.FM return FM and FM.Ranks and #FM.Ranks(spell) > 0 or false end

--- Do your totems stand, by our clock?
function RD.TotemsUp(now) return RD.totemsUntil > (now or (GetTime and GetTime()) or 0) end

--- Your cast, from RD.OnCast: the totem clock. Answers "call" / "tcall" / "recall" for the three buttons' spells.
function RD.TotemCast(name, now)
    if type(name) ~= "string" then return nil end
    for _, c in ipairs(RD.CALLS) do
        if name == c then
            RD.totemsUntil = now + RD.TOTEM_LIFE
            RD.totemsFought = (RD.inFight or combat()) and true or false
            RD.totemsBrought = false
            RD.lastTotemCast = now
            for slot = 1, 4 do RD.slotUp[slot] = true end    -- up to four: out of a fight the read says which
            RD.ShowLife()
            return "call"
        end
    end
    if name == RD.TCALL then
        RD.readyAt.tcall, RD.coolStart.tcall = now + RD.COOLS.tcall, now
        RD.lastTotemCast = now                           -- a relocation re-names its slots: not a death
        if not (RD.inFight or combat()) then RD.totemsBrought = true end
        return "tcall"
    end
    if name == RD.RECALL then
        RD.totemsUntil, RD.totemsFought, RD.lastTotemCast = 0, false, 0
        for slot = 1, 4 do RD.slotUp[slot] = false end
        RD.ShowLife()
        return "recall"
    end
    if name:find("Totem$") then
        local life = (name == RD.TIDE) and RD.WATER.tide or RD.TOTEM_LIFE
        RD.totemsUntil = math.max(RD.totemsUntil, now + life)
        if RD.inFight or combat() then RD.totemsFought = true end
        RD.lastTotemCast = now
        -- the update may have come just before the cast: the slot it named is this totem's
        for slot, at in pairs(RD.slotSeen) do
            if now - at <= RD.TOTEM_CAST_WINDOW then RD.slotUp[slot] = true end
        end
        RD.ShowLife()
    end
    return nil
end

--- Out of a fight the slots read plainly: none down = none stand; one down that our clock missed = they stand.
function RD.ReadTotems()
    local FB = NS.FB
    if combat() or RD.inFight or not (FB and FB.TotemSlot) then return nil end
    if NS.Blind and NS.Blind() then return nil end
    local any, known, ends, endSlot = false, true, nil, nil
    for slot = 1, 4 do
        local have = FB.TotemSlot(slot)
        RD.slotUp[slot] = have
        if have == nil then known = false
        elseif have then
            any = true
            -- its timer, plain out of a fight: the earliest end among the long-lived ones is when they run out
            local ok, _, _, start, dur = pcall(GetTotemInfo, slot)
            if ok then
                start = plain(start)
                dur = plain(dur)
            else
                start, dur = nil, nil
            end
            if type(start) == "number" and type(dur) == "number" and dur >= RD.TOTEM_SHORT
               and start + dur < (ends or math.huge) then
                ends, endSlot = start + dur, slot
            end
        end
    end
    local now = (GetTime and GetTime()) or 0
    if any and ends then RD.totemsUntil = ends
    elseif any and not RD.TotemsUp(now) then RD.totemsUntil = now + RD.TOTEM_LIFE
    elseif known and not any then RD.totemsUntil, RD.totemsFought = 0, false end
    RD.lifeSlot = endSlot or RD.lifeSlot
    RD.ShowLife()
    return any
end

--- PLAYER_TOTEM_UPDATE in a fight (the slots secret, the slot number plain): down if a totem cast of yours is within
--- the window, else that totem is gone. Every slot known empty = none stand. Answers whether anything changed.
function RD.TotemSlotChanged(slot, now)
    slot = plain(slot)
    if type(slot) ~= "number" or slot < 1 or slot > 4 then return false end
    now = now or (GetTime and GetTime()) or 0
    RD.slotSeen[slot] = now
    if slot == RD.AIR_SLOT then                      -- Grounding: down right after your cast of it, gone on any other change
        RD.groundUp = RD.groundCastAt ~= nil and (now - RD.groundCastAt) <= RD.TOTEM_CAST_WINDOW
    end
    local down = (now - RD.lastTotemCast) <= RD.TOTEM_CAST_WINDOW
    RD.slotUp[slot] = down
    if down then
        if not RD.TotemsUp(now) then RD.totemsUntil = now + RD.TOTEM_LIFE end
    else
        local any = false
        for s = 1, 4 do if RD.slotUp[s] ~= false then any = true end end
        if not any then RD.totemsUntil = 0 end
        if slot == RD.lifeSlot then RD.lifeSlot = nil end
    end
    RD.ShowLife()
    return true
end

--- THE TIME LEFT, the game's own: the deciding slot's duration object (GetTotemDuration) on CALL's (dark meanwhile) cooling
--- disc, handed untouched; out of a fight the plain start/length do the same. Nothing standing: cleared.
function RD.ShowLife()
    local discs = {}
    for _, b in ipairs({ RD.call }) do if b and b.life and b.macro then discs[#discs + 1] = b.life end end
    if #discs == 0 then return false end
    local slot = RD.lifeSlot
    if not slot then
        for _, s in ipairs({ RD.EARTH_SLOT, 1, 3, 4 }) do if RD.slotUp[s] then slot = s break end end
    end
    local obj, start, dur = nil, nil, nil
    if slot and RD.TotemsUp() and RD.slotUp[slot] ~= false then
        if GetTotemDuration then
            local ok, o = pcall(GetTotemDuration, slot)
            if ok then obj = o end
        end
        if not obj and not (combat() or RD.inFight) then
            local ok, _, _, st, d = pcall(GetTotemInfo, slot)
            if ok then
                start = plain(st)
                dur = plain(d)
            end
        end
    end
    local shown = false
    for _, cd in ipairs(discs) do
        if obj and cd.SetCooldownFromDurationObject and pcall(cd.SetCooldownFromDurationObject, cd, obj) then
            shown = true
        elseif type(start) == "number" and type(dur) == "number" and dur > 0 and pcall(cd.SetCooldown, cd, start, dur) then
            shown = true
        elseif cd.Clear then
            pcall(cd.Clear, cd)
        end
    end
    return shown
end

--- Arm the three (their clicks, out of a fight). Unknown spells: the button hides.
function RD.ArmTotems()
    if combat() then return false end
    local function arm(b, spell1, spell2, tip)
        if not b then return end
        local m1 = spell1 and ("/cast " .. spell1) or nil
        local m2 = spell2 and ("/cast " .. spell2) or m1
        b:SetAttribute("*type1", m1 and "macro" or nil)
        b:SetAttribute("*macrotext1", m1)
        b:SetAttribute("*type2", m2 and "macro" or nil)
        b:SetAttribute("*macrotext2", m2)
        b.macro, b.spell = m1, spell1
        b.ringIcon = true
        RD.SpellIcon(b, spell1)                       -- the totem spell's own icon, the button's full size
        b:EnableMouse(m1 and true or false)
        if m1 then b:Show() else b:Hide() end
        b.tip = m1 and tip or nil
    end
    local e = knows(RD.CALLS[1]) and RD.CALLS[1] or nil
    local a = knows(RD.CALLS[2]) and RD.CALLS[2] or nil
    arm(RD.call, e or a, a or e, { "CALL", (e or a or "") .. (e and a and ("  -  right-click: " .. a) or "")
        .. ".  Lights before the pull while none of your totems are down." })
    arm(RD.tcall, knows(RD.TCALL) and RD.TCALL or nil, nil,
        { "BRING", RD.TCALL .. " - your totems to you.  Lights in a fight while they stand and it is ready; after one, "
          .. "while they still have plenty of time left (cheaper than calling again)." })
    arm(RD.recall, knows(RD.RECALL) and RD.RECALL or nil, nil,
        { "RECALL", RD.RECALL .. " - 25% of their mana back.  Lights out of a fight when they are about to run out." })
    RD.ReadTotems()
    return true
end

--- The three lights. Plain booleans from our clock; a knob switches each off.
function RD.TotemLights(fight, now)
    now = now or (GetTime and GetTime()) or 0
    local up = RD.TotemsUp(now)
    local function on(b) return b and b.macro and not RD.KnobOff(b.kind) end
    local low = up and (RD.totemsUntil - now) <= RD.TOTEM_LOW
    local bringAfter = not fight and up and not low and RD.totemsFought and not RD.totemsBrought
    return on(RD.call) and not fight and not up or false,
           on(RD.tcall) and (fight and up or bringAfter) and RD.ToolReady("tcall", now) or false,
           on(RD.recall) and not fight and low or false
end
function RD.PaintTotems(fight)
    if fight == nil then fight = RD.inFight or combat() end
    local c, t, r = RD.TotemLights(fight)
    if RD.call then RD.call.face:SetAlpha(RD.LitAlpha(RD.call, c)) end
    if RD.tcall then RD.tcall.face:SetAlpha(RD.LitAlpha(RD.tcall, t)) end
    if RD.recall then RD.recall.face:SetAlpha(RD.LitAlpha(RD.recall, r)) end
    RD.totemsWas = (c and 1 or 0) + (t and 2 or 0) + (r and 4 or 0)
    return c, t, r
end

--- The ticker's watch: BRING lights on a clock (its cooldown), the totems run out on one. Repaint on a change.
function RD.WatchTotems()
    if not (RD.call or RD.tcall or RD.recall) then return false end
    local c, t, r = RD.TotemLights(RD.inFight or combat())
    if (c and 1 or 0) + (t and 2 or 0) + (r and 4 or 0) == RD.totemsWas then return false end
    RD.PaintTotems()
    return true
end

--[[ THE RES (10 Nov 2026, Arn: "Out of combat right rail let's put the resurrection module where it chooses the best
  person to res always lights up when someone is dead if they are out of range it'll say so or los it'll say so").
  On the defence rail under the chaff. OUT OF A FIGHT ONLY - a res is - and dark in one.
    who     BiS> now's own pick (FN.ResTarget): healers first, then Arn's class order, released or not (Arn: "people
            that have released should not be skipped"); never someone offline, someone a res is already coming to,
            or a corpse another BiS healer claimed (RezComm)
    click   `/cast [@<unit>,help] <res>`: that friend only - a res is never anything on you (you are alive), and no
            [dead] in it, so a ghost who released is res'd too
    lit     whenever someone can be brought back; the name is in the tooltip (no words on the scope)
    RANGE   asked of the client for that one person while it is lit (one question a tick, out of a fight)
    LOS     only the cast can tell: a res that fails on line of sight with the mouse on the pip says so, for a while
  Asked again only when something changed (RD.resDirty: health, the roster, a res coming, a fight's end) and every
  RD.RES_EVERY ticks while someone lies there (a claim from another healer runs out on a clock). Nobody dead, no work. ]]
RD.RES_EVERY = 4                                   -- ticks (2 s) between re-picks while someone is dead
RD.RES_LOS = 4                                     -- seconds the LOS word stays after a failed res
function RD.BuildRes(b)
    b.kind = "res"
    b.face:SetAlpha(0)
    b:EnableMouse(false)
    local G = RD.COL.green
    for _, l in ipairs(b.ring or {}) do l:SetVertexColor(G[1], G[2], G[3], 1) end
    b.pulse = RD.Pulse(b.beat, RD.PULSE_SOFT)
    -- the word under it: RANGE or LOS, in the grid's flash red
    local w = b:CreateFontString(nil, "OVERLAY")
    w:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "THICKOUTLINE")
    w:SetPoint("TOP", b, "BOTTOM", 0, -1)
    local R = (NS.FG and NS.FG.FLASH_RED) or RD.COL.red
    w:SetTextColor(R[1], R[2], R[3], 1)
    w:SetText("")
    b.word = w
    b:HookScript("OnEnter", function() RD.overRes = true end)
    b:HookScript("OnLeave", function() RD.overRes = nil end)
    RD.resDirty = true
end

--- Aim the res at the best corpse, or put it out. Out of a fight only (secure writes). Answers the unit, or nil.
function RD.ArmRes()
    local b = RD.res
    if not b or combat() or RD.inFight then return nil end
    local res = NS.FM and NS.FM.ResSpell and NS.FM.ResSpell() or nil
    local unit = res and NS.FN and NS.FN.ResTarget and NS.FN.ResTarget() or nil
    if res ~= b.spell then
        b.spell = res
        b.ringIcon = true
        RD.SpellIcon(b, res)                          -- your res spell's own icon, the button's full size
    end
    local macro = unit and ("/cast [@" .. unit .. ",help] " .. res) or nil
    if macro ~= b.macro then
        b:SetAttribute("*type1", macro and "macro" or nil)
        b:SetAttribute("*macrotext1", macro)
        b.macro = macro
    end
    if unit ~= b.unit then b.losUntil = nil end
    b.unit = unit
    b:EnableMouse(unit and true or false)
    b.face:SetAlpha(RD.LitAlpha(b, unit and true or false))
    local okN, name = pcall(GetUnitName, unit or "none", false)
    name = (unit and okN and plain(name)) or nil
    b.tip = unit and { "RES" .. (type(name) == "string" and (": " .. name) or ""),
                       res .. " - who to bring back first: healers, then by class.  Out of a fight only." } or nil
    RD.PaintResWord()
    return unit
end

--- The word under the res: LOS for a while after a failed res, else RANGE when the client says they are too far.
function RD.PaintResWord()
    local b = RD.res
    if not (b and b.word) then return nil end
    local word = ""
    local now = (GetTime and GetTime()) or 0
    if b.unit then
        if b.losUntil and now < b.losUntil then
            word = "LOS"
        elseif b.spell and C_Spell and C_Spell.IsSpellInRange then
            local ok, inRange = pcall(C_Spell.IsSpellInRange, b.spell, b.unit)
            if ok and plain(inRange) == false then word = "RANGE" end
        end
    end
    if b.word.__res ~= word then b.word:SetText(word) b.word.__res = word end
    return word ~= "" and word or nil
end

--- A fight: the res goes dark and stops answering clicks (before the lockdown starts: PLAYER_REGEN_DISABLED).
function RD.ResOff()
    local b = RD.res
    if not b then return end
    b.face:SetAlpha(0)
    if b.word then b.word:SetText("") b.word.__res = "" end
    if not combat() then
        b:SetAttribute("*type1", nil)
        b:SetAttribute("*macrotext1", nil)
        b:EnableMouse(false)
        b.macro, b.unit = nil, nil
    end
    RD.resDirty = true                               -- asked again when the fight ends
end

--- What is still cooling, from the client while it will say (out of a fight): seeds our own clock, so a Mana Tide used
--- before a /reload still counts as spent. Plain numbers only; anything else leaves the clock as it was.
function RD.SeedCooldowns()
    if combat() then return false end
    local now = (GetTime and GetTime()) or 0
    local getCd = C_Spell and C_Spell.GetSpellCooldown
    if RD.tide and RD.tide.macro and getCd then
        local ok, info = pcall(getCd, RD.TIDE)
        local s, d = nil, nil
        if ok and type(info) == "table" then
            s = plain(info.startTime)
            d = plain(info.duration)
        end
        if type(s) == "number" and type(d) == "number" and d > 2 then RD.readyAt.tide, RD.coolStart.tide = s + d, s end
    end
    local itemCd = C_Container and C_Container.GetItemCooldown
    if RD.potion and RD.potion.item and itemCd then
        local ok, s, d = pcall(itemCd, RD.potion.item)
        if ok then
            s = plain(s)
            d = plain(d)
        else
            s, d = nil, nil
        end
        if type(s) == "number" and type(d) == "number" and d > 2 then RD.readyAt.potion, RD.coolStart.potion = s + d, s end
    end
    -- the flare and the chaff: their clocks seeded, and their real length learned (talents can shorten them)
    local FG = NS.FG
    local named = { kick = FG and FG.KickSpell and FG.KickSpell() or nil, chaff = RD.chaff and RD.chaff.spell or nil }
    for kind, name in pairs(named) do
        if name and getCd then
            local ok, info = pcall(getCd, name)
            local s, d = nil, nil
            if ok and type(info) == "table" then
                s = plain(info.startTime)
                d = plain(info.duration)
            end
            if type(s) == "number" and type(d) == "number" and d > 2 then
                RD.readyAt[kind], RD.coolStart[kind], RD.cdLen[kind] = s + d, s, d
            end
        end
    end
    return true
end

--- Is the flare (your interrupt) spent? No interrupt at all counts as spent: the chaff is all you have.
function RD.FlareSpent(now)
    local FG = NS.FG
    if not (FG and FG.KickSpell and FG.KickSpell()) then return true end
    return (RD.readyAt.kick or 0) > (now or (GetTime and GetTime()) or 0)
end

--- THE CHAFF'S LIGHT: armed, knob on, in a fight, something casting, the flare spent and the chaff ready. Plain booleans.
function RD.ChaffLit(fight, casting)
    local b = RD.chaff
    if not (b and b.macro) or RD.KnobOff("chaff") then return false end
    if not (fight and casting) then return false end
    local now = (GetTime and GetTime()) or 0
    if (RD.readyAt.chaff or 0) > now then return false end
    return RD.FlareSpent(now)
end

--- Paint the chaff from the last look (RD.anyCast, set by RD.Look): its sign in amber and its face seen, or dark.
function RD.PaintChaff(casting)
    local b = RD.chaff
    if not b then return false end
    if casting == nil then casting = RD.anyCast end
    local up = RD.GroundUp() and not RD.KnobOff("chaff")      -- its knob switches this light off too
    local lit = up or RD.ChaffLit(RD.inFight or combat(), casting)
    local c = RD.CHAFF_COL
    for _, t in ipairs(b.pieces or {}) do t:SetVertexColor(c[1], c[2], c[3], lit and 1 or 0) end
    b.face:SetAlpha(RD.LitAlpha(b, lit))
    RD.GroundSweep(b, up)
    return lit
end

--[[ GROUNDING STANDING (15 Nov 2026, Arn: "when i drop grounding it does not show full bright with its duration sweep not
  sure about the cooldown sweep"). While your Grounding Totem stands its button is lit, full colour, and the GAME's own
  timer for the air slot (GetTotemDuration) runs a sweep across it; gone (it ate a spell, or ran out - the air slot's
  change says so, in a fight too), it is dim with its cooldown (our own clock, from your cast) as the sweep, then waits
  for the next enemy cast as before. ]]
RD.AIR_SLOT, RD.GROUND_LIFE = 4, 45
function RD.GroundUp(now)
    now = now or (GetTime and GetTime()) or 0
    return RD.groundUp == true and RD.groundCastAt ~= nil and (now - RD.groundCastAt) < RD.GROUND_LIFE
end
function RD.GroundSweep(b, up)
    if not (b and b.face) then return false end
    if not b.groundCd then
        local ok, cd = pcall(CreateFrame, "Cooldown", nil, b.face, "CooldownFrameTemplate")
        if not (ok and cd) then return false end
        cd:SetAllPoints(b)
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        b.groundCd = cd
    end
    local cd, now = b.groundCd, (GetTime and GetTime()) or 0
    if up then
        local obj
        if GetTotemDuration then
            local ok, o = pcall(GetTotemDuration, RD.AIR_SLOT)
            if ok then obj = o end
        end
        if obj and cd.SetCooldownFromDurationObject and pcall(cd.SetCooldownFromDurationObject, cd, obj) then return "up" end
        if cd.SetCooldown then cd:SetCooldown(RD.groundCastAt, RD.GROUND_LIFE) end
        return "up"
    end
    local ready, start = RD.readyAt.chaff or 0, RD.coolStart.chaff
    if ready > now and start and cd.SetCooldown then
        cd:SetCooldown(start, ready - start)
        return "cooling"
    end
    if cd.Clear then cd:Clear() end
    return false
end

--- THE COOLING DISCS, FROM OUR OWN CLOCK (8 Nov 2026, Arn: "this mana tide sweep shows up whenever i click anything"):
--- the client's Mana Tide cooldown carries the global cooldown too, and in a fight its object is secret - we cannot tell
--- "on the GCD" from "spent". So the disc never takes it: it runs from the cast we saw (or the client's plain answer out
--- of a fight, longer than a GCD), plain numbers handed to SetCooldown; ready = cleared.
function RD.PaintWaits(now)
    now = now or (GetTime and GetTime()) or 0
    local n = 0
    for kind, b in pairs({ tide = RD.tide, potion = RD.potion, tcall = RD.tcall }) do
        local cd = b and b.cd
        if cd and cd.wait then
            local s, r = RD.coolStart[kind], RD.readyAt[kind]
            if b.macro and type(s) == "number" and type(r) == "number" and r > now then
                if pcall(cd.SetCooldown, cd, s, r - s) then n = n + 1 end
            elseif cd.Clear then
                pcall(cd.Clear, cd)
            end
        end
    end
    return n
end

--- Is a tool ready by our own clock (plain numbers)? Mana Tide's and the potion's gate: spent = dark.
function RD.ToolReady(kind, now)
    return (RD.readyAt[kind] or 0) <= (now or (GetTime and GetTime()) or 0)
end

--- The ticker's watch: Mana Tide and the potion come off cooldown on a clock, not an event - repainted only when one
--- turns ready (or spent). Two plain comparisons a tick.
function RD.WatchReady()
    local readyNow = (RD.ToolReady("tide") and 1 or 0) + (RD.ToolReady("potion") and 2 or 0)
    if readyNow == RD.toolsReadyWas then return false end
    RD.toolsReadyWas = readyNow
    RD.PaintQuiet()
    return true
end

--- Is a tool spent right now? Not here at all counts as spent (nothing to reach for); else our clock.
local function spent(b, kind, now)
    if not (b and b.macro) then return true end
    return (RD.readyAt[kind] or 0) > now
end

--- THE RESERVE TANK'S GATE: armed, no water totem of yours standing, Mana Tide and the potion both spent, and - out of a
--- fight - no drink to reach for instead. Plain booleans from our own clock; the mana level is the curve's (PaintTools).
function RD.ReserveOpen(fight)
    local b = RD.reserve
    if not (b and b.macro) then return false end
    local now = (GetTime and GetTime()) or 0
    if RD.waterUntil > now then return false end
    if not (spent(RD.tide, "tide", now) and spent(RD.potion, "potion", now)) then return false end
    if not fight and RD.fuel and RD.fuel.macro then return false end
    return true
end

--- One of YOUR casts (UNIT_SPELLCAST_SUCCEEDED, you only): Mana Tide, Mana Spring or a mana potion starts our clock.
--- The spell's name is asked of the client for your own cast; a secret or no answer = not one of ours.
function RD.OnCast(unit, spellID)
    if (NS.IsPlayer and NS.IsPlayer(unit)) ~= true then return false end
    spellID = plain(spellID)
    if type(spellID) ~= "number" then return false end
    local now = (GetTime and GetTime()) or 0
    if RD.potion and RD.potion.spellId and spellID == RD.potion.spellId then
        RD.readyAt.potion, RD.coolStart.potion = now + RD.COOLS.potion, now
        RD.PaintWaits(now)
        return "potion"
    end
    local getName = C_Spell and C_Spell.GetSpellName
    local ok, name = false, nil
    if getName then ok, name = pcall(getName, spellID) end
    name = ok and plain(name) or nil
    RD.TideTestCast(name, now)                       -- the Grounding test button (Mana Tide's stand-in), when it shows
    local sh = RD.shield                             -- your shield back on: its red box goes, mid-fight too
    if name and sh and sh.shieldName == name then RD.AttnSet(sh, nil) end
    if name == RD.RIPTIDE then RD.RipCast(now) end   -- the Riptide tracker: whose box, and its clock
    RD.CueCast(name, now)                            -- the class heal cues (Oath of Light, Light's Vigil, Swiftmend)
    if name == "Chain Heal" then                      -- the bounce probe's clock, and the bounce path
        RD.chainAt = now
        if RD.bounceOn then RD.BounceStart(now) end
        RD.BounceLanded(now)
    end
    local totem = RD.TotemCast(name, now)            -- the totem clock (CALL / BRING / RECALL)
    if totem then RD.PaintTotems() RD.PaintWaits(now) return totem end
    if name == RD.TIDE then
        RD.readyAt.tide, RD.coolStart.tide = now + RD.COOLS.tide, now
        RD.PaintWaits(now)
        RD.waterUntil = now + RD.WATER.tide
        RD.TideSay()                                 -- BiS Healing users: MANA TIDE on your box in their deck
        RD.TideChat(false)                           -- and the party's chat: down, ready again in 5:00
        return "tide"
    elseif name == RD.SPRING then
        RD.waterUntil = now + RD.WATER.spring
        return "spring"
    end
    -- the flare: your interrupt, or a spell that spends the same cooldown (a shaman's shocks share one)
    local FG = NS.FG
    local kick = FG and FG.KickSpell and FG.KickSpell() or nil
    local shares = name and kick and (name == kick)
    if not shares and name and kick then
        for _, other in ipairs(RD.KICK_SHARED[kick] or {}) do if other == name then shares = true end end
    end
    if shares then
        RD.readyAt.kick, RD.coolStart.kick = now + (RD.cdLen.kick or RD.COOLS.kick), now
        return "kick"
    end
    if name and RD.chaff and name == RD.chaff.spell then
        RD.readyAt.chaff, RD.coolStart.chaff = now + (RD.cdLen.chaff or RD.COOLS.chaff), now
        RD.groundCastAt, RD.groundUp = now, true        -- down from now (the air slot's change follows)
        RD.PaintChaff()
        return "chaff"
    end
    return false
end

--- The food the rations pip offers now, out of a fight. BiS TOOLS FIRST (Arn, 8 Nov: "bis tool still shows the eat food
--- icon in the toolbox but its not in the radar need it there too"): BiSToolsAPI.FoodNow (v7) is the tools box's own
--- rule and its own food, so both light together. Without BiS Tools: Well Fed missing and a well-fed food in the bags.
function RD.FoodWanted()
    if combat() then return nil end
    local A = _G.BiSToolsAPI
    if type(A) == "table" and A.major == 1 and type(A.FoodNow) == "function" then
        local ok, item, why = pcall(A.FoodNow)
        if ok and type(item) == "number" then return item end
        if ok and why ~= "not ready" and why ~= "xp tool off" then return nil end   -- the box says no: so do we
    end
    local fed = RD.WellFed()
    return (fed == false) and RD.BestItem("Food", "well fed") or nil
end

--- Is Well Fed on you? Out of a fight only (an aura read); nil when it cannot say.
function RD.WellFed()
    if combat() then return nil end
    local find = AuraUtil and AuraUtil.FindAuraByName
    if not find then return nil end
    local ok, name = pcall(find, "Well Fed", "player", "HELPFUL")
    if not ok then return nil end
    return plain(name) ~= nil
end

--- Everything secure, written once per change - OUT OF A FIGHT ONLY (asked in one, it waits: RD.pending).
function RD.Arm()
    if combat() then RD.pending = true return false end
    RD.pending = nil
    RD.Build()
    RD.heal = RD.Heal()
    RD.HealAmount(RD.heal)
    local units, raid, mine = RD.Roster()
    RD.units, RD.raid, RD.ownGroup = units, raid, mine
    local slots, size, rim = RD.Geometry(raid, mine)
    -- in a raid your own slot (wherever your group put you) moves to the centre; its sector keeps the gap
    if raid then
        for i, s in ipairs(slots) do
            local u = units[i]
            if u then
                local okU, me = pcall(UnitIsUnit, u, "player")
                if okU and plain(me) == true then
                    local S, own = RD.SELF, RD.RAID.own
                    slots[i] = { b = S.b, rh = S.rh, rc = S.rc, rb = S.rb, ph = own.ph + 4, pc = own.pc, pb = own.pb,
                                 own = true, self = true, group = s.group, pos = s.pos }
                end
            end
        end
    end
    -- THE RADAR'S SHIPS (11 Nov): a class bigger than the fighter is its own drawing - rings by rank round you
    -- (RD.FleetGeometry); the class is chosen (the class button) or the smallest that holds everyone
    local T = RD.ConsoleTier(units)
    if not RD.Console() and T.n > 5 then
        local order = RD.ConsoleOrder(units, T.n)
        RD.conOrder = order
        slots, size, rim = RD.FleetGeometry(T, order)
    end
    if not RD.Console() then RD.TanksNorth(slots, units) end   -- the tanks in the top half, always
    RD.slots, RD.rim = slots, rim
    -- the square grows for a raid; the scope's drawing scales with it, so its rings sit where the slots do
    RD.frame:SetSize(size, size)
    RD.scope:SetScale(size / RD.PARTY.size)
    if RD.fade then RD.fade:SetSize(RD.FADE_PX * size / RD.PARTY.size, RD.FADE_PX * size / RD.PARTY.size) end
    RD.SizeGauge(size)                 -- the fuel tape runs the rail over the tool rail and the square
    -- THE SHIP for this many (Arn, 9 Nov: "the more the group gets we change the color"): out of a fight only, here
    local n = 0
    for i = 1, #slots do if units[i] then n = n + 1 end end
    RD.ApplyShip(RD.SHIPS[T.ship] or RD.ShipFor(math.max(1, n)))   -- the class's colours (a preview shows its own)
    local con = RD.Console()                         -- the engineer's console: small slots, placed on its grid after
    if con then
        -- its class (fighter .. capital): chosen, or the smallest that holds everyone; the radar's ship colours with it
        local T = RD.ConsoleTier(units)
        -- who goes where: a rank (you, then the brains' order), the top five carrying interrupts and pets
        local order = RD.ConsoleOrder(units, T.n)
        local top, rankOf = {}, {}
        for k = 1, math.min(5, #order) do top[order[k]] = true end
        for k, i in ipairs(order) do rankOf[i] = k end
        RD.conOrder = order
        slots = RD.ConsoleSlots(T, top, rankOf)
        -- THE FLIGHT DECK: the tanks first, then everyone in group order; every place carries a kick; and two more places,
        -- after the crew, for the target box - your target and its target (the radar's own units list is left alone)
        if RD.Deck() then
            -- (the sort is read HERE, out of a fight only: frozen for the fight - RD.DeckSort)
            RD.deckSorted = RD.DeckSort()
            order, RD.deckTanks, RD.deckBlocks = RD.DeckOrder(units, T.n, RD.deckSorted, raid)
            RD.conOrder = order
            local pets = RD.Sw("pets") and RD.DeckPets(units, T.n) or {}
            RD.deckPets = #pets
            slots = RD.DeckSlots(T, #pets)
            units = RD.DeckUnits(units, T.n, pets)
        end
        RD.slots = slots
        RD.ApplyShip(RD.SHIPS[T.ship] or RD.ShipFor(T.n))
    end
    for i, s in ipairs(slots) do
        local sp = RD.Spoke(i)
        local unit = units[i]
        sp.unit = unit
        if sp.cd then
            sp.cd.active = unit and true or false
            if not unit and sp.cd.Clear then pcall(sp.cd.Clear, sp.cd) end
        end
        RD.PlaceSpoke(sp, s, rim)
        sp.heal:Show()
        if unit then
            sp.heal:EnableMouse(true)
            armHeal(sp, unit)
            if s.rb then armBogey(sp, unit) else sp.bogey:SetAttribute("unit", nil) sp.bogey:EnableMouse(false) sp.kick = nil end
        else
            -- AN EMPTY PLACE IS NOBODY (Arn, 10 Nov: the wheel over an empty console square "heal me"): it takes the
            -- mouse and names a unit that never exists, so the game's mouseover becomes nobody and the wheel's guard
            -- ([@mouseover,noexists]) casts nothing - before, the mouseover stayed whoever you hovered last (you)
            sp.heal:SetAttribute("unit", RD.EMPTY_UNIT)
            sp.heal:SetAttribute("type1", nil)
            sp.heal:EnableMouse(true)
            sp.bogey:SetAttribute("unit", nil)
            sp.bogey:EnableMouse(false)
            sp.kick, sp.paintTex = nil, nil
        end
        armCures(sp, (not (RD.Deck() and not RD.Sw("cures"))) and unit or nil)   -- cures switched off: none armed
        armPet(sp, unit, s)
        if s.rb then sp.bogey:Show() else sp.bogey:Hide() end
    end
    -- spokes beyond this layout (a raid became a party): off, out of the way
    for i = #slots + 1, #RD.spokes do
        local sp = RD.spokes[i]
        sp.unit, sp.kick, sp.paintTex = nil, nil, nil
        sp.heal:SetAttribute("unit", nil) sp.heal:SetAttribute("type1", nil) sp.heal:EnableMouse(false) sp.heal:Hide()
        sp.bogey:SetAttribute("unit", nil) sp.bogey:EnableMouse(false) sp.bogey:Hide()
        armCures(sp, nil)
        armPet(sp, nil, nil)
        for _, fr in ipairs(sp.dims) do fr:Hide() end
        sp.los:SetAlpha(0)
        -- the deck's own parts of a place no longer used (a pet sent away): its box, name, paw and cast bar
        if sp.deckPlate then sp.deckPlate:Hide() end
        if sp.deckTag then sp.deckTag:Hide() end
        if sp.deckPaw then sp.deckPaw:Hide() end
        if sp.castStrip then sp.castStrip:SetAlpha(0) end
    end
    armShield()
    RD.ArmTools()
    local foodItem, foodWanted = RD.FoodShown()
    armUse(RD.rations, foodItem)
    RD.rations.wanted = foodWanted
    RD.PickFuel()
    RD.PaintMe()                                     -- your role's sign in the middle (a role change lands here)
    if con then RD.ConsoleLayout() else RD.RadarLayout() end
    RD.DrawRings(T)                                  -- the class's own rings (a fleet), or the party's
    RD.PaintSeats(slots)                             -- a faint dot at every place, out of a fight
    RD.ApplyView()                                   -- what steps aside in the console, and the view button
    RD.Paint()
    if RD.Deck() then RD.CueSeed() end               -- (out of a fight here: a login, a /reload, a new group - the cues read the truth)
    return true
end

-- ------------------------------------------------------------------ painting (any time: colours and alpha only)

--- One spoke's heal pip, coloured by the client from their health.
function RD.PaintHeal(sp)
    RD.PaintOutline(sp)                              -- the deck's box edge: amber low, red very low (the client picks)
    -- STOOD UP (17 Nov 2026, Arn's cousin, res'd: his box still said DEAD and every click on himself tried to res him): out of
    -- a fight each paint asks whether the box's clicks still match their death (FM.ResCheck writes only on a change), and
    -- a box that showed someone dead is looked at again every tick until they are up (RD.StandUpWatch) - the health event
    -- can come while the game still calls them dead, and nothing else would come after it
    -- (no question of its own: the death RD.DeadDark asks below decides - the 40-man repaint budget)
    if not (sp and sp.unit and sp.paintTex) then
        if sp and sp.heal then RD.HealFaces(sp.heal, 0) end
        return false
    end
    -- somebody who left (a slot whose re-layout waits for the fight's end): nothing at their spot, not a stale sign -
    -- the red and amber copies too (11 Nov, Arn: "left group still icons remain", an amber sword after they left)
    local okE, there = pcall(UnitExists, sp.unit)
    if okE and plain(there) == false then RD.HealFaces(sp.heal, 0) return false end
    RD.HealFaces(sp.heal, 1)
    -- dead: nothing to heal, nothing lit - all three faces
    local dead = RD.DeadDark(sp.heal.face, sp.unit, sp.heal.redFace, sp.heal.amberFace)
    if dead then sp.deadSeen = true end
    if (dead and not sp.heal.__res or not dead and sp.heal.__res) and NS.FM and NS.FM.ResCheck and not (RD.inFight or combat()) then
        NS.FM.ResCheck(sp.heal)                      -- (the clicks and the death disagree: FM.ResCheck sets them right)
    end
    if dead then return false end
    local curve = RD.Curve(sp.amber)
    if not (curve and UnitHealthPercent) then
        -- no curves on this client: the pip stays at its spot, plainly green, rather than lie about urgency
        for _, t in ipairs(sp.paintTex) do t:SetVertexColor(RD.COL.green[1], RD.COL.green[2], RD.COL.green[3], 0.6) end
        return false
    end
    local ok, col = pcall(UnitHealthPercent, sp.unit, true, curve)
    local drew = ok and paint(sp.paintTex, col)
    if not drew then RD.HealFaces(sp.heal, 0) end              -- no colour back: nothing, never a stale sign
    local red = RD.RedCurve()
    if red then
        local okR, rc = pcall(UnitHealthPercent, sp.unit, true, red)
        if okR and sp.redGlyph then paint(sp.redGlyph, rc) end
        if RD.SIZE_PULSE and sp.pulse and not (sp.pulse.IsPlaying and sp.pulse:IsPlaying()) then sp.pulse:Play() end
    end
    local amber = RD.AmberCurve(sp.amber)
    if amber and sp.amberGlyph then
        local okA, ac = pcall(UnitHealthPercent, sp.unit, true, amber)
        if okA then paint(sp.amberGlyph, ac) end
    end
    -- the GCD sweep's swipe: dark while the pip is lit (below RD.GREEN), see-through when it is not
    local sw = sp.cd and RD.SwipeCurve(RD.GREEN)
    if sw then
        local okS, scol = pcall(UnitHealthPercent, sp.unit, true, sw)
        swipeTo(sp.cd, okS and scol or nil)
    end
    return drew
end

--- In a fight the scope, the empty slots and the idle bogeys are see-through; out of one they are drawn dim.
function RD.PaintQuiet()
    -- a fight: the lockdown, or the moment PLAYER_REGEN_DISABLED says one starts (the lockdown begins just after it)
    local fight = RD.inFight or combat()
    -- THE SCOPE STAYS IN A FIGHT (Arn, 8 Nov: "i like this green outline in combat too"): rings, cross and corners are
    -- the instrument; only the pips come and go
    if RD.scope then RD.scope:SetAlpha(1) end
    -- the dim slot outlines are never drawn (Arn, 8 Nov: "the box outlines are not needed"); the scope alone says where
    if RD.dims then RD.dims:SetAlpha(0) end
    -- the faint seats instead (Arn, 11 Nov): out of a fight only
    if RD.seatFrame then RD.seatFrame:SetAlpha(fight and 0 or 1) end
    if RD.rations then
        local r = RD.rations
        if fight or not r.item then
            r.face:SetAlpha(RD.LitAlpha(r, false) * (r.item and 1 or 0))   -- no food: nothing; in a fight: dim (no eating)
            RD.AttnSet(r, nil)
        else
            RD.PaintBuffDims()                                                -- out of a fight: the buff's time left
        end
    end
    RD.PaintTools(fight)
    RD.PaintTotems(fight)
end

--- THE REGEN TOOLS' LIGHTS: each tool's own curve on your mana (lit once you miss what it restores), the client's
--- colour landing on its pieces and its sweep's swipe. Nothing compared. A tool that is not here, or a drink in a fight,
--- is dark; no colour back from the client = dark, never a stale sign.
function RD.PaintTools(fight)
    if not RD.TOOLS then return end
    for _, b in ipairs(RD.TOOLS) do
        local drew = false
        if b.macro and not (b.restOnly and fight) and not (b.gate and not b.gate(fight)) and not RD.KnobOff(b.kind)
           and UnitPowerPercent then
            local c = RD.ToolCurve(b.at)
            if c then
                local ok, col = pcall(UnitPowerPercent, "player", 0, true, c)
                drew = ok and paint(b.pieces, col) or false
            end
            -- an item tool showing its own icon (the drink, the potion): lit full / faded by its own white curve
            if drew and b.iconTex and b.food then
                local ic = RD.IconCurve(b.at, RD.FullFor(b))
                local okI, icol = false, nil
                if ic then okI, icol = pcall(UnitPowerPercent, "player", 0, true, ic) end
                if not (okI and paint({ b.food }, icol)) then b.food:SetVertexColor(1, 1, 1, RD.ICON_FADED) end
            end
            local sw = b.cd and not b.cd.wait and RD.SwipeCurve(b.at)   -- a cooling disc keeps its own colour
            if drew and sw then
                local okS, scol = pcall(UnitPowerPercent, "player", 0, true, sw)
                swipeTo(b.cd, okS and scol or nil)
            end
        end
        -- the outline: red under its own point, amber under twice it (the client's curve); none while it cools
        local ac = drew and RD.AttnOn() and not (b.cd and b.cd.wait) and RD.AttnCurve(b.at)
        if ac then
            local f = RD.Attn(b)
            local okA, acol = pcall(UnitPowerPercent, "player", 0, true, ac)
            if okA and paint(f.edges, acol) then f:Show() else f:Hide() end
        elseif b.attn then
            b.attn:Hide()
        end
        b.face:SetAlpha(drew and 1 or 0)
    end
end

--- Bogeys and range arcs: the ticker's work while shown.
--- Is `unit` your target? Onto `frame`'s alpha: plain yes/no, or a SECRET answer handed to the client
--- (SetAlphaFromBoolean, the grid's own road - FG.PaintTarget), so it still works inside an instance. Never tested by us.
local function crossOn(frame, unit, whose)
    if not (frame and unit and UnitIsUnit) then if frame then frame:SetAlpha(0) end return false end
    local ok, same = pcall(UnitIsUnit, unit, whose or "target")
    if not ok or same == nil then frame:SetAlpha(0) return false end
    if NS.Secret and NS.Secret(same) then
        if not pcall(function() frame:SetAlphaFromBoolean(same, 1, 0) end) then frame:SetAlpha(0) end
        return "secret"
    end
    frame:SetAlpha((same == true or same == 1) and 1 or 0)
    return same == true or same == 1
end

--- The crosshairs: on the pip of whoever is your target, and on the bogey of whoever's target is yours. Asked when your
--- target changes (and after a layout), never on the ticker - a 40-man raid is 40 pips.
function RD.PaintCross()
    if not RD.CROSSHAIRS then
        -- OFF (Arn, 8 Nov, after trying them: "no crosshairs" - "take them off"); kept behind RD.CROSSHAIRS
        for _, sp in ipairs(RD.spokes or {}) do
            for _, c in ipairs({ sp.cross, sp.bogeyCross, sp.totCross }) do if c then c:SetAlpha(0) end end
        end
        return false
    end
    for _, sp in ipairs(RD.spokes or {}) do
        crossOn(sp.cross, sp.unit)
        crossOn(sp.totCross, sp.unit, "targettarget")       -- who your target is on
        crossOn(sp.bogeyCross, (sp.unit and sp.slot and sp.slot.rb) and sp.tok or nil)
    end
end

--- THEIR TARGET, WHERE THE INTERRUPT LIVES (Arn, 8 Nov: "a pip for their target where the interrupt button would live"):
--- a quiet phosphor triangle while they have a HOSTILE target, red the moment it casts (a click = your interrupt; a
--- right-click targets it, so your crosshairs go on it). Hostile is the client's answer (UnitCanAttack); a secret one
--- goes through its own curve into the alpha. Nothing to show: invisible.
--- A bogey seen or not, set ON ITS LINES (their colour's alpha) as well as its face (8 Nov 2026, Arn's screenshot, out of a
--- fight: four red triangles and a green one, nothing casting - the face's frame alpha alone did not hide them in the
--- client, while the heal pips, hidden by their colour's alpha, did). The sweep follows.
local function bogeyAlpha(k, a, col)
    col = col or RD.COL.bogey
    for _, l in ipairs(k.lines or {}) do l:SetVertexColor(col[1], col[2], col[3], a) end
    k.face:SetAlpha(a)
    if k.cd and k.cd.SetAlpha then k.cd:SetAlpha(a) end
end
RD.BogeyAlpha = bogeyAlpha

-- THE MINI CAST BAR (Arn 15 Nov, a target frame's "Whirlwind 7.9": "can we show that as a mini mini cast bar along the
-- bottom of the party member that is targeting him?"). In the deck only: a thin bar along the bottom of the box of whoever
-- targets the caster, lit with the kick. The client runs it: the cast's own duration object handed untouched to
-- SetTimerDuration (a channel drains, a cast fills), nothing read. Grey when the cast cannot be interrupted (the shield's
-- flag through the client's ternary when secret), red otherwise.
RD.CAST_STRIP_H = 3
RD.CAST_COL = { 0.85, 0.15, 0.15 }       -- red: an enemy cast (Arn: "make the progress bar red to indicate a enemy cast")
RD.CAST_SHIELDED = { 0.55, 0.57, 0.62 }

--- Built OUT OF A FIGHT, from the deck's layout (Arn 15 Nov, "interrups dont show up now": built at the first cast, in a
--- fight, it took the whole look down with it). A child of the secure pip, so it is made only while that is allowed.
function RD.MakeCastStrip(sp)
    local pip = sp and sp.heal
    if not pip then return nil end
    local b = sp.castStrip
    if not b then
        if combat() then return nil end
        b = CreateFrame("StatusBar", nil, pip)
        b:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        b:SetPoint("BOTTOMLEFT", pip, "BOTTOMLEFT", 1, 1)
        b:SetPoint("BOTTOMRIGHT", pip, "BOTTOMRIGHT", -1, 1)
        b:SetHeight(RD.CAST_STRIP_H)
        local lvl = pip.GetFrameLevel and pip:GetFrameLevel()
        if type(lvl) == "number" then b:SetFrameLevel(lvl + 4) end
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints(b)
        b.bg:SetColorTexture(0, 0, 0, 0.7)
        b:SetAlpha(0)
        sp.castStrip = b
    end
    return b
end

--[[ THE CAST BAR FILLS THE ICON ROW (16 Nov 2026, Arn's screenshot: "enemy cast bar gets a little lost how about we use the
  whole bottom interrupt cure bar for it"). Where a box has the kick / cure row under its bar, the cast bar is that whole
  row, under the kick and the cures (which stay on top and clickable); without the row (kicks and cures switched off, a
  raid's short boxes) it stays the thin line under the health bar. `row` = left, top, right, bottom in the window's own
  pixels from its top-left; nil = the thin line. Out of a fight (RD.DeckLayout). ]]
function RD.PlaceCastStrip(sp, row)
    local b = sp and sp.castStrip
    if not b then return false end
    b:ClearAllPoints()
    if row and RD.frame then
        b:SetPoint("TOPLEFT", RD.frame, "TOPLEFT", row[1], -row[2])
        b:SetPoint("BOTTOMRIGHT", RD.frame, "TOPLEFT", row[3], -row[4])
        sp.castRow = true
    else
        b:SetPoint("BOTTOMLEFT", sp.heal, "BOTTOMLEFT", 1, 1)
        b:SetPoint("BOTTOMRIGHT", sp.heal, "BOTTOMRIGHT", -1, 1)
        b:SetHeight(RD.CAST_STRIP_H)
        sp.castRow = false
    end
    return sp.castRow
end
function RD.CastStrip(sp, lit)
    if not RD.Sw("cast") then
        if sp and sp.castStrip then sp.castStrip:SetAlpha(0) end
        return false
    end
    local b = sp and sp.castStrip
    if not b then return false end
    if not lit or not RD.Deck() then b:SetAlpha(0) return false end
    -- the thin line: over the box's health bar, whatever was built over the pip since; the icon row: UNDER the kick and the
    -- cures (pip + 3), so they stay on top and take the click (a plain frame: allowed in a fight)
    local pl = sp.heal and sp.heal.GetFrameLevel and sp.heal:GetFrameLevel()
    if type(pl) == "number" then b:SetFrameLevel(pl + (sp.castRow and 2 or 8)) end
    if not b.SetTimerDuration or not Enum or not Enum.StatusBarTimerDirection then return false end
    local tok = sp.tok
    local dir, dur = Enum.StatusBarTimerDirection.RemainingTime, nil
    if UnitChannelDuration then
        local ok, d = pcall(UnitChannelDuration, tok)
        if ok and type(d) ~= "nil" then dur = d end
    end
    if dur == nil and UnitCastingDuration then
        local ok, d = pcall(UnitCastingDuration, tok)
        if ok and type(d) ~= "nil" then dur, dir = d, Enum.StatusBarTimerDirection.ElapsedTime end
    end
    if dur == nil then b:SetAlpha(0) return false end
    local interp = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
    if not pcall(b.SetTimerDuration, b, dur, interp, dir) then b:SetAlpha(0) return false end
    local A, G = RD.CAST_COL, RD.CAST_SHIELDED
    -- never `x and flag or false`: in a fight the flag is a secret boolean and `and`/`or` test it (live 15 Nov, Radar:5087)
    local ni = false
    if NS.KG then ni = NS.KG.Protected(tok) end
    if NS.Secret and NS.Secret(ni) then
        local tern = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
        local drew = false
        if tern then
            local o1, r = pcall(tern, ni, G[1], A[1])
            local o2, g = pcall(tern, ni, G[2], A[2])
            local o3, bl = pcall(tern, ni, G[3], A[3])
            drew = o1 and o2 and o3 and pcall(b.SetStatusBarColor, b, r, g, bl)
        end
        if not drew then b:SetStatusBarColor(A[1], A[2], A[3]) end
    else
        local c = (ni == true) and G or A
        b:SetStatusBarColor(c[1], c[2], c[3])
    end
    b:SetAlpha(1)
    return true
end

--- `/bish alpha deck strip`: what the mini cast bars are doing (Arn 15 Nov: the kick lit on a box, no bar under it).
--- One line: how many are made, how many showing, the client's timer bar there or not, the last failure. Answers the line.
function RD.StripStatus(rest)
    if rest ~= "strip" then return nil end
    local made, shown, timer = 0, 0, nil
    for _, sp in ipairs(RD.spokes or {}) do
        local b = sp.castStrip
        if b then
            made = made + 1
            if b:GetAlpha() > 0 then shown = shown + 1 end
            if timer == nil then timer = b.SetTimerDuration and true or false end
        end
    end
    local enumOK = (Enum and Enum.StatusBarTimerDirection and Enum.StatusBarInterpolation) and true or false
    local line = string.format("cast bars: %d made, %d showing, timer bar %s, enums %s, last failure: %s", made, shown,
        tostring(timer), tostring(enumOK), tostring(RD.stripErr or "none"))
    if NS.Print then NS.Print(line) end
    return line
end

local function paintContact(sp, lit)
    local k = sp.bogey
    local col = lit and RD.COL.bogey or RD.CONTACT
    if lit then
        bogeyAlpha(k, 1, col)
        -- a cast you cannot interrupt wears a shield (Guard.lua, Arn 12 Nov)
        if NS.KG then pcall(NS.KG.Paint, k.face, sp.tok, k.GetWidth and k:GetWidth()) end
        -- the kick is lit FIRST; nothing the mini cast bar does can put it out (a failure is kept for /bish alpha)
        local okS, err = pcall(RD.CastStrip, sp, true)
        if not okS then RD.stripErr = err end
        return true
    end
    if sp.castStrip then pcall(RD.CastStrip, sp, false) end
    bogeyAlpha(k, 0, col)
    -- ONLY WHEN IT CASTS (Arn, 8 Nov, four green triangles over a party on one mob: "why is it showing interrupt buttons
    -- when its not casting" - picked "only when casting"). The quiet green contact below is kept, switched off by
    -- RD.CONTACT_SHOWN, should it ever be wanted back.
    if not RD.CONTACT_SHOWN then k.face:SetAlpha(0) return false end
    local okE, there = pcall(UnitExists, sp.tok)
    there = okE and there
    if NS.Secret and NS.Secret(there) then there = true end           -- let the hostile answer decide
    if not there then k.face:SetAlpha(0) return false end
    local okH, hostile = pcall(UnitCanAttack, "player", sp.tok)
    if not okH then k.face:SetAlpha(0) return false end
    if NS.Secret and NS.Secret(hostile) then
        local tern = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
        local made, a = false, 0
        if tern then made, a = pcall(tern, hostile, RD.CONTACT[4], 0) end
        if not (made and pcall(k.face.SetAlpha, k.face, a)) then k.face:SetAlpha(0) end
        return "secret"
    end
    k.face:SetAlpha(hostile == true and RD.CONTACT[4] or 0)
    return hostile == true
end

--- The boxes that last showed someone dead: up again now? Then painted again (the word, the colour, the clicks).
function RD.StandUpWatch()
    for _, sp in ipairs(RD.spokes or {}) do
        if sp.deadSeen then
            local up = true
            if sp.unit and UnitIsDeadOrGhost then
                local okD, dead = pcall(UnitIsDeadOrGhost, sp.unit)
                up = okD and plain(dead) == false
            end
            if up then sp.deadSeen = nil RD.PaintHeal(sp) end
        end
    end
end
function RD.Look()
    local FG = NS.FG
    RD.StandUpWatch()
    local anyCast = false
    -- asked only while the chaff could light (armed, knob on, in a fight): lean when it cannot
    local wantChaff = RD.chaff and RD.chaff.macro and (RD.inFight or combat()) and not RD.KnobOff("chaff") or false
    for _, sp in ipairs(RD.spokes or {}) do
        if sp.unit and sp.tok and sp.slot and sp.slot.rb then
            -- red only when you have an interrupt to answer it with; the quiet pip shows either way
            -- nobody there is never casting (a duration question about an empty token is not trusted to say nil)
            local okE, there = pcall(UnitExists, sp.tok)
            there = okE and there
            if NS.Secret and NS.Secret(there) then there = true end
            local casting = false
            if there and (sp.kick or wantChaff) and FG and FG.Casting then casting = FG.Casting(sp.tok) end
            -- the chaff answers any hostile cast on the radar, interrupt or not (Arn: "it needs no target")
            if casting and wantChaff and not anyCast and UnitCanAttack then
                local okH, hostile = pcall(UnitCanAttack, "player", sp.tok)
                if okH and (hostile == true or (NS.Secret and NS.Secret(hostile))) then anyCast = true end
            end
            local lit = casting and sp.kick and true or false
            -- ENEMIES ONLY (Arn, 10 Nov: "when im healing myself and targeting myself it shows the interuppt?"): your own
            -- bogey is YOUR target - you, casting your own heal, lit it. A plain "not hostile" puts it out; a secret answer
            -- keeps it (the kick itself only ever fires on an enemy: *harmbutton1)
            if lit and UnitCanAttack then
                local okH, hostile = pcall(UnitCanAttack, "player", sp.tok)
                if okH and not (NS.Secret and NS.Secret(hostile)) and hostile ~= true then lit = false end
            end
            paintContact(sp, lit)
        else
            bogeyAlpha(sp.bogey, 0)
        end
    end
    RD.anyCast = anyCast
    RD.PaintChaff(anyCast)
end

-- THE CLICK'S WORD (Arn, 9 Nov: "LOS for line of sight, range for out of range, red letter under the teammate ... only
-- when i click them ... like the bis grid in normal view"). No standing range mark any more (the red rim dashes asked
-- the client about every spoke on every look): a heal that FAILS on the pip under the mouse flashes why, under it.
local clickWords
RD.SHORT_WORD = { RANGE = "RNG" }    -- the words as shown: three letters each, the boxes sized to them
function RD.ClickWords()
    if clickWords then return clickWords end
    clickWords = {}
    local los = NS.FG and NS.FG.FailWords and NS.FG.FailWords() or { ["Target not in line of sight"] = "LOS" }
    for k, v in pairs(los) do clickWords[k] = v end
    -- the client's own out-of-range strings (any language), with the English as a net
    for _, s in ipairs({ "Out of range.", "Out of range", _G.SPELL_FAILED_OUT_OF_RANGE, _G.ERR_OUT_OF_RANGE,
                         _G.ERR_SPELL_OUT_OF_RANGE }) do
        if type(s) == "string" and s ~= "" and not (NS.Secret and NS.Secret(s)) then clickWords[s] = "RANGE" end
    end
    return clickWords
end

--- A failed click: the word under the pip under the mouse, fading by itself. The grid's switch (`flash`) turns it off
--- here too. Answers the word, or nil.
function RD.HeardError(msg)
    local d = NS.DB()
    if d.flash == false then return nil end
    if type(msg) ~= "string" or (NS.Secret and NS.Secret(msg)) then return nil end
    local word = RD.ClickWords()[msg]
    -- the res under the mouse (RD.ArmRes): LOS stays a while; RANGE it already says by itself
    if word and RD.overRes and RD.res and RD.res.unit then
        if word == "LOS" then RD.res.losUntil = ((GetTime and GetTime()) or 0) + RD.RES_LOS end
        RD.PaintResWord()
        return word
    end
    local sp = RD.over
    if not (word and sp and sp.los and sp.unit) then return nil end
    sp.los.word:SetText(RD.SHORT_WORD[word] or word)     -- RNG on screen, RANGE inside (Arn, 16 Nov: "LOS RNG OVH")
    if NS.EN and NS.EN.PlaceWord then NS.EN.PlaceWord(sp, word) end   -- the console: into its own header box
    sp.los:SetAlpha(1)
    if sp.losFade then sp.losFade:Stop() sp.losFade:Play() end
    RD.lastLos = sp.i
    return word
end

-- ------------------------------------------------------------------ the fuel gauge (handed untouched, never read)

--- nil, asked without testing a secret (a secret refuses even `== nil`): a secret is never nil.
local function isNil(v)
    if NS.Secret and NS.Secret(v) then return false end
    return v == nil
end

--- Hand a unit's pair of numbers to bars, untouched: 0..max, then the value. false when the client refused.
local function handTo(bars, getMax, getNow, unit, kind)
    local okM, mx = pcall(getMax, unit, kind)
    local okV, v = pcall(getNow, unit, kind)
    if not (okM and okV) then return false end
    for _, s in ipairs(bars) do
        pcall(s.SetMinMaxValues, s, 0, mx)
        pcall(s.SetValue, s, v)
    end
    return true
end

--- Your fuel: your mana on the tape and on the BINGO ruler, as the client gives it.
function RD.PaintMana()
    local g = RD.gauge
    if not (g and UnitPower and UnitPowerMax) then return false end
    -- the readout's number: the client writes your mana % into it (a secret is handed on, never read)
    local num = g.readout and g.readout.num
    if num and UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100 then
        if not pcall(function() num:SetFormattedText("%d", UnitPowerPercent("player", 0, true, CurveConstants.ScaleTo100)) end) then
            num:SetText("")
        end
    end
    return handTo({ g.mana, g.ruler }, UnitPowerMax, UnitPower, "player", 0)
end

--- WHOSE HEALTH THE TAPE RACES: the boss (boss1) while the client has one, else your target, hostile or not decided by
--- the client (a secret "hostile?" stays the client's: RD.fuelHostile goes to SetAlphaFromBoolean). nil: nothing to race.
--- Asked when the target or the encounter changes, never per health tick.
function RD.PickFuel()
    RD.fuelUnit, RD.fuelHostile = nil, nil
    local okB, b = pcall(UnitExists, "boss1")
    if okB and plain(b) == true then RD.fuelUnit, RD.fuelHostile = "boss1", true return "boss1" end
    local okT, t = pcall(UnitExists, "target")
    if not okT then return nil end
    if not (NS.Secret and NS.Secret(t)) and t ~= true then return nil end
    local okH, h = pcall(UnitCanAttack, "player", "target")
    if not okH or isNil(h) then return nil end
    RD.fuelUnit, RD.fuelHostile = "target", h
    return "target"
end

--- The boss's side of the tape: its health handed to the red bar and the hot copy; the boss layer's alpha says whether
--- there is one. Out of a fight with no boss: nothing, the tape is calm (Arn's brief).
function RD.PaintBoss()
    local g = RD.gauge
    if not g then return nil end
    local unit, h = RD.fuelUnit, RD.fuelHostile
    local show = unit and (unit == "boss1" or RD.inFight or combat())
    if not show then g.bossLayer:SetAlpha(0) return nil end
    handTo({ g.boss, g.hot }, UnitHealthMax, UnitHealth, unit)
    if NS.Secret and NS.Secret(h) then
        if not pcall(function() g.bossLayer:SetAlphaFromBoolean(h, 1, 0) end) then g.bossLayer:SetAlpha(0) end
        return "secret"
    end
    g.bossLayer:SetAlpha(h == true and 1 or 0)
    return h == true
end

--- GENERATING FUEL: the cyan chevron at the tape's foot, in a fight only. Lit while you are out of the five second rule
--- (Regen.lua's own clock - your own casts, plain); inside it, dimmed to the share you keep while casting (the pair
--- Regen.lua remembered out of a fight; nothing asked now). Out of a fight: nothing.
function RD.PaintRegen()
    local g, FR = RD.gauge, NS.FR
    if not g then return nil end
    local fight = RD.inFight or combat()
    -- the readout: 100% out of a fight; in one, the header's own number (your while-casting share inside the five
    -- seconds, 100% once they are up, "?" when the client never said)
    -- THE RAMJET (Arn, 8 Nov: "a fighter pilot able to lay off the thruster for 5 seconds and his ram jet kicks in to
    -- regen his fuel"): the clock is read ONCE - the dashes count it down, the chevron lights when it is out
    local left = (fight and FR and FR.Left) and FR.Left() or 0
    if g.regen then g.regen:SetText((left > 0 and FR.Text) and FR.Text(true) or "100%") end
    RD.PaintFSR(left)
    if not fight or not (FR and FR.Left) then g.chev:SetAlpha(0) return 0 end
    local a = 1
    if left > 0 then
        local k = FR.known
        a = (k and type(k.base) == "number" and k.base > 0 and type(k.casting) == "number") and (k.casting / k.base) or 0
        a = math.max(0, math.min(a, 1))
    end
    g.chev:SetAlpha(a)
    return a
end

--- The five segments: one lit per second the rule still holds (a part-second counts), spent ones dim; nothing left =
--- hidden. `left` = Regen.lua's own clock (plain - your own casts). Answers how many are lit.
function RD.PaintFSR(left)
    local g = RD.gauge
    if not (g and g.fsr) then return nil end
    if type(left) ~= "number" or left <= 0 then g.fsr:SetAlpha(0) return 0 end
    local lit = math.min(RD.FSR.n, math.ceil(left))
    for k, t in ipairs(g.fsrSegs) do t:SetAlpha(k <= lit and 1 or RD.FSR.spent) end
    g.fsr:SetAlpha(1)
    return lit
end

function RD.PaintFuel()
    RD.PaintMana()
    RD.PaintBoss()
    RD.PaintRegen()
end

--- What the tape says, in words, under the mouse only.
function RD.FuelTip()
    local FR = NS.FR
    local who = RD.fuelUnit == "boss1" and "the boss" or (RD.fuelUnit == "target" and "your target, when it is hostile")
                or "nothing - no boss, no hostile target"
    -- plain words (Arn, 15 Nov: "remove references to airplane stuff like fuel chaff call it what it is now")
    return {
        "The bright bar: your mana, filling left to right.  Red past it: how far the boss's health is ahead of your mana.  Magenta mark: the boss.",
        ("Pulsing band: the boss is more than %d%% ahead of your mana - drink, potion, Mana Tide."):format(RD.BINGO * 100),
        "At the right end: your mana regen now (100% out of a fight).  The five dashes: seconds left of the five-second rule - hold your casts till they are gone and your full regen comes back.  The cyan arrow: regen running (dim: only your while-casting share).",
        "Compared with: " .. who .. ".  " .. ((FR and FR.Text) and FR.Text() or ""),
    }
end

--- THE SWEEPS, BATCHED (SPELL_UPDATE_COOLDOWN, a layout): ONE duration object for the GCD - spell 61304, else the radar
--- heal's own cooldown, which carries it - handed untouched to every GCD sweep in one loop; Mana Tide its own spell's
--- object; the potion its item cooldown (plain start + duration, handed on as given). Answers how many were fed.
function RD.Sweeps()
    local get = C_Spell and C_Spell.GetSpellCooldownDuration
    if not get then return 0 end
    local ok, gcd = pcall(get, RD.GCD)
    if not ok or isNil(gcd) then
        local h = RD.heal and (RD.heal.cast or RD.heal.name)
        ok, gcd = false, nil
        if h then ok, gcd = pcall(get, h) end
    end
    local n = 0
    if ok and not isNil(gcd) then
        for _, cd in ipairs(RD.sweeps) do
            -- a slot with nobody in it (cd.active false, set by RD.Arm) runs no sweep at all
            if cd.active ~= false and pcall(cd.SetCooldownFromDurationObject, cd, gcd) then n = n + 1 end
        end
    end
    -- Mana Tide and the potion: their cooling discs run on our own clock (RD.PaintWaits) - never the client's object,
    -- which carries the GCD; out of a fight the client's plain answer re-seeds the clock first
    RD.SeedCooldowns()
    return n + RD.PaintWaits()
end

--- The interrupt's sweep on every bogey (SPELL_UPDATE_COOLDOWN, a layout): your own spell's duration object, handed
--- untouched to each sweep. false when you have no interrupt or the client will not say.
function RD.KickCooldown()
    local FG = NS.FG
    local name = FG and FG.KickSpell and FG.KickSpell()
    local get = C_Spell and C_Spell.GetSpellCooldownDuration
    if not (name and get) then return false end
    local ok, dur = pcall(get, name)
    if not ok then return false end
    for _, sp in ipairs(RD.spokes or {}) do
        local cd = sp.bogey and sp.bogey.cd
        if cd and cd.SetCooldownFromDurationObject then pcall(cd.SetCooldownFromDurationObject, cd, dur) end
    end
    return true
end

--- THE SHIELD, ASKED DIRECTLY (8 Nov 2026, Arn: "water shield missing again" - the pip lit only when the client's aura
--- container took its button away, and when that hook was missed it never lit). The buff reminder's own question,
--- FS.Present (by spell id, the client's readable answer): on you = dark, gone = lit. When the client will not say
--- (nil, inside the lockdown) the container's hooks decide, as before.
function RD.PaintShield()
    local b = RD.shield
    if not b then return nil end
    if not b.shieldName then
        if b.breath and b.breath.Stop then b.breath:Stop() end
        b.face:SetAlpha(0)
        return nil
    end
    if b.breath and b.breath.IsPlaying and not b.breath:IsPlaying() then b.breath:Play() end
    -- the red is ALWAYS under the client's cover (armShield): it never decides anything itself, so nothing here can
    -- leave it dark while the shield is gone - the fight-proof part. The question is only kept for the suite and for
    -- /bish alpha radar, never to hide the red.
    b.face:SetAlpha(1)
    local FS = NS.FS
    if not (FS and FS.Present) then return nil end
    local ok, present = pcall(FS.Present, b.shieldName)
    if not ok then return nil end
    return present
end

function RD.Paint()
    if not RD.frame then return end
    for _, sp in ipairs(RD.spokes or {}) do RD.PaintHeal(sp) RD.PaintPet(sp) end
    RD.PaintShield()
    RD.PaintQuiet()
    RD.PaintFuel()
    RD.PaintCross()
    RD.KickCooldown()
    RD.Sweeps()
    RD.Look()
end

-- ------------------------------------------------------------------ on and off

local function startTicker()
    if RD.ticker or not (C_Timer and C_Timer.NewTicker) then return end
    local n = 0
    RD.ticker = C_Timer.NewTicker(RD.TICK, function()
        if not RD.Active() then return end
        RD.Look()
        RD.PaintRegen()                     -- the five second rule runs out on a clock, not an event
        -- the reserve tank opens on a clock too (a cooldown running out): repainted only when its gate turns
        if RD.reserve and RD.reserve.macro then
            local open = RD.ReserveOpen(RD.inFight or combat())
            if open ~= RD.reserveWas then RD.reserveWas = open RD.PaintQuiet() end
        end
        RD.WatchReady()
        RD.WatchTotems()
        -- the food goes due on BiS Tools' own clock (Well Fed running low): asked again every RD.FOOD_EVERY ticks, out
        -- of a fight - one API question, and a re-arm only when the answer changed
        -- the res, out of a fight: re-picked when something changed, or every RD.RES_EVERY ticks while someone lies
        -- there; the word (RANGE / LOS) checked every tick while it is lit. Nobody dead and nothing changed: no work.
        if RD.res and not (RD.inFight or combat()) then
            RD.resTicks = (RD.resTicks or 0) + 1
            if RD.resDirty or (RD.res.unit and RD.resTicks >= RD.RES_EVERY) then
                RD.resDirty, RD.resTicks = nil, 0
                RD.ArmRes()
            elseif RD.res.unit then
                RD.PaintResWord()
            end
        end
        n = n + 1
        if n >= RD.FOOD_EVERY and not combat() and RD.rations then
            n = 0
            local want, wanted = RD.FoodShown()
            RD.rations.wanted = wanted
            if want ~= RD.rations.item then armUse(RD.rations, want) RD.PaintQuiet() end
            RD.PaintShield()                -- and the shield, in case an aura change went unheard
            RD.PaintBuffDims()              -- the food's and the shield's fade: their buffs' time left
        end
    end)
end
local function stopTicker()
    if RD.ticker then RD.ticker:Cancel() RD.ticker = nil end
end

--- Bring the radar in or out to match the switch. Out of a fight only; asked in one, it waits.
function RD.Apply()
    RD.DashStamp()                                   -- the old alpha switch, once, into the look
    RD.SwStamp()                                     -- the engineer's view, once, into the switches
    local want = RD.On()
    if combat() then
        if want ~= RD.Active() then RD.pending = true end
        return false
    end
    if want then
        RD.Build()
        RD.shownFor = true
        RD.Place()
        RD.frame:Show()
        RD.Arm()
        startTicker()
    else
        RD.shownFor = nil
        if RD.frame then RD.frame:Hide() end
        stopTicker()
    end
    -- the grid gives way, or comes back (FG.Hidden asks RD.Active; the saved `shown` is never touched)
    if NS.FG and NS.FG.Layout and NS.FG.anchor then pcall(NS.FG.Layout) end
    return true
end

--- The hidden settings: `/bish alpha radar heal <spell>` | `scale <50-200>` | `center`.
function RD.Command(rest)
    local word, arg = tostring(rest or ""):match("^%s*(%S+)%s*(.-)%s*$")
    word = word and word:lower() or ""
    local P = NS.Print or print
    if word == "strip" then return RD.StripStatus("strip") end
    if word == "tot" and NS.EN and NS.EN.FoldStatus then return NS.EN.FoldStatus() end
    if word == "box" and NS.EN and NS.EN.BoxStatus then return NS.EN.BoxStatus() end
    if word == "cc" and NS.EN and NS.EN.LossStatus then return NS.EN.LossStatus() end
    if word == "mana" and NS.EN and NS.EN.ManaStatus then return NS.EN.ManaStatus() end
    if word == "bounce" then
        if arg == "on" or arg == "off" then
            local on = RD.BounceArm(arg == "on")
            P("chain heal bounce probe: %s - cast Chain Heal on a hurt group, then /bish alpha radar bounce", on and "ON" or "off")
            return on
        end
        RD.BounceStatus2()                            -- the path's own line first
        return RD.BounceStatus()
    end
    if word == "rip" then
        local l = RD.ripLast
        local line = string.format("riptide: known %s, length %ss, last on %s, %s left", tostring(RD.RipKnown()), tostring(RD.RipLength()),
            tostring(l and l.unit or "nobody yet"), l and string.format("%.1f", math.max(0, l.untilAt - GetTime())) or "-")
        P(line)
        if NS.FM and NS.FM.SeqInfo then P(NS.FM.SeqInfo()) end   -- what the Riptide + heal bind's list is built from
        return line
    end
    if word == "over" and NS.OV and NS.OV.Status then return NS.OV.Status() end
    if word == "tidetest" then
        local on = RD.ToggleTideTest()
        P("test button (Grounding Totem as Mana Tide): %s", on == nil and "not now" or (on and "shown, left of the deck" or "hidden"))
        return on
    end
    if word == "sw" then
        local k, v = arg:lower():match("^(%S*)%s*(%S*)$")
        if k == "" then return RD.ToggleSwitches() end
        local done = RD.SW_PRESETS[k] and RD.SwPreset(k) or RD.SetSw(k, v ~= "off")
        P("switches: %s %s", k, tostring(done or "unknown - names, edges, pets, target, kicks, cures, cast, alerts, fuel, tools, totems, timers, bb"))
        return done
    end
    if word == "heal" then
        if arg == "" or arg:lower() == "default" then
            db().heal = nil
        else
            db().heal = titled(arg)
        end
        local was = RD.heal
        RD.Arm()
        local h = RD.heal
        P("radar heal: %s%s", h and h.cast or "none trained",
          (db().heal and not (h and h.name == db().heal)) and ("  (|cfff08cb0" .. db().heal .. "|r is not in your spellbook)") or "")
        return h, was
    elseif word == "scale" then
        local n = tonumber(arg)
        if n then db().scale = math.max(50, math.min(200, n)) / 100 end
        RD.Place()
        P("radar scale: %d%%", math.floor((db().scale or 1) * 100 + 0.5))
    elseif word == "center" or word == "centre" then
        db().pos = nil
        RD.Place()
        P("radar: back in its place")
    elseif word == "brains" then
        RD.BrainsSay(P)
    elseif word == "knob" then
        -- `knob <tide|potion|reserve|drink|chaff> on|off` - the same switch as the knob on the rail
        local kind, state = arg:lower():match("^(%a+)%s*(%a*)$")
        local names = { "tide", "potion", "reserve", "drink", "chaff", "call", "tcall", "recall" }
        local known = {}
        for _, k in ipairs(names) do known[k] = true end
        if kind and known[kind] and (state == "on" or state == "off") then
            RD.SetKnob(kind, state == "off")
        end
        local list = {}
        for _, k in ipairs(names) do
            list[#list + 1] = k .. (RD.KnobOff(k) and " |cffff3a4doff|r" or " on")
        end
        P("radar knobs: %s.  |cff968ead/bish alpha radar knob <name> on|off|r", table.concat(list, ", "))
    else
        local h = RD.heal or RD.Heal()
        P("radar: heal %s.  |cff968ead/bish alpha radar heal <spell> | center|r  (resize: drag its corner)", h and h.cast or "none")
        -- THE FUEL GAUGE AND THE MANA COLUMN, SAID PLAINLY: what the tape races, and where each tool lights
        local function tool(b, name)
            if not (b and b.macro) then return name .. " none" end
            return ("%s %s%%%s"):format(name, math.floor((b.at or 0) * 100 + 0.5), b.guess and " (guess)" or "")
        end
        P("mana bar: compared with %s.  lights at: %s, %s, %s", RD.fuelUnit or "nothing", tool(RD.tide, "tide"),
          tool(RD.potion, "potion"), tool(RD.fuel, "drink"))
        -- THE SHIELD PIP, SAID PLAINLY (Arn, 8 Nov: "no water shield icon"): what it watches, whether the client took the
        -- marker, and what it last handed over - so the next screenshot says which part is missing
        local b, FA = RD.shield, NS.FA
        local present = b and b.shieldName and NS.FS and NS.FS.Present and select(2, pcall(NS.FS.Present, b.shieldName))
        P("radar shield: %s - markers %s, slot %s, button %s, cover %s, on you now: %s%s",
          b and b.shieldName or "none trained (or not your class)",
          (FA and FA.Available and FA.Available()) and "yes" or ("no (" .. tostring(FA and FA.refused) .. ")"),
          (b and b.slot) and "placed" or "none", (b and b.handed) and "handed over" or "not yet",
          (b and b.cover) and "on" or "none",
          present == true and "yes" or (present == false and "no" or "the client will not say"),
          (FA and FA.initRefused) and ("  |cfff08cb0refused: " .. tostring(FA.initRefused) .. "|r") or "")
    end
end

-- ------------------------------------------------------------------ events

local ev = CreateFrame("Frame")
RD.events = ev
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE",
                     "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_AURA", "SPELLS_CHANGED",
                     "BAG_UPDATE_DELAYED", "UI_ERROR_MESSAGE", "PLAYER_TARGET_CHANGED", "UNIT_TARGET",
                     "PLAYER_ROLES_ASSIGNED", "SPELL_UPDATE_COOLDOWN", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "UNIT_MAXPOWER",
                     "PLAYER_LEVEL_UP", "UNIT_PET", "INCOMING_RESURRECT_CHANGED", "UNIT_CONNECTION",
                     "PLAYER_TOTEM_UPDATE", "PLAYER_ENTERING_WORLD", "ADDON_RESTRICTION_STATE_CHANGED",
                     "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
    pcall(ev.RegisterEvent, ev, e)
end
-- your own casts only (the reserve tank's clock): the client filters to you, so a raid's casts never reach us
if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SUCCEEDED", "player") end
-- whom your spell went to (the Riptide tracker's last way to tell, when no deck box was clicked): yours only
local sentEv = CreateFrame("Frame")
if sentEv.RegisterUnitEvent then pcall(sentEv.RegisterUnitEvent, sentEv, "UNIT_SPELLCAST_SENT", "player") end
sentEv:SetScript("OnEvent", function(_, _, _, target, _, spellID)
    RD.RipSent(target)
    RD.BounceSent(spellID)                            -- a Chain Heal on its way: the bounce path starts listening
end)
ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
    if event == "PLAYER_LOGIN" then RD.TideHook() RD.Apply() return end
    -- THE LOADING WINDOW (11 Nov 2026): a /reload in a fight lets secure frames be armed while the loading events are
    -- handed out, the lockdown back right after - armed NOW, never left for a later tick (Grid.lua, FG.Start)
    if event == "PLAYER_ENTERING_WORLD" then
        if RD.Active() and not combat() then RD.Arm() end
        return
    end
    -- THE NAMES COME BACK A LITTLE AFTER THE FIGHT (16 Nov 2026, Arn: "when i click the water or earth totem its not
    -- dropping them again"): at PLAYER_REGEN_ENABLED the totems' names can still be hidden (solved.md 14 Oct, "data stays
    -- partly secret after combat ends") - the lift is this event; the boxes learn then
    if event == "ADDON_RESTRICTION_STATE_CHANGED" then
        if not combat() then RD.LearnTimers() end
        return
    end
    if event == "PLAYER_TOTEM_UPDATE" then                      -- the deck's four timers: the game's own countdowns
        RD.LearnTimers()                                         -- out of a fight: the totem dropped, remembered for its box
        RD.PaintTimers()
    end
    if event == "PLAYER_TOTEM_UPDATE" and (RD.inFight or combat()) then
        if RD.TotemSlotChanged(a1) and RD.Active() then RD.PaintTotems() end   -- a fight: the slot number only
        RD.PaintChaff()                                          -- Grounding: still standing, or gone
        return
    end
    if event == "PLAYER_TOTEM_UPDATE" then
        if RD.ReadTotems() ~= nil and RD.Active() then RD.PaintTotems() end   -- out of a fight only (plain slots)
        -- out of a fight the air slot's own name says whether your Grounding stands, and since when
        local okG, _, gname, gstart = pcall(GetTotemInfo, RD.AIR_SLOT)
        if okG then gname, gstart = plain(gname), plain(gstart) else gname, gstart = nil, nil end
        RD.groundUp = (RD.chaff and RD.chaff.spell and gname == RD.chaff.spell) and true or false
        if RD.groundUp and type(gstart) == "number" and gstart > 0 then RD.groundCastAt = gstart end
        RD.PaintChaff()
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local kind = RD.OnCast(a1, a3)
        if kind and RD.Active() then RD.PaintQuiet() end
        if kind and NS.CamShot then NS.CamShot(kind) end   -- the test camera (TestCam.lua), when armed
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        -- a fight: the drag ends first (before the lockdown takes the mouse), then everything goes quiet
        if RD.frame then endDrag(RD.frame) end
        RD.EndGrip()                       -- and a resize by the corner grip, the same way
        RD.ResOff()                        -- a res is out of a fight only: dark, and no click left armed
        RD.inFight = true                  -- the lockdown starts just after this event: the paints ask this too
        if RD.TotemsUp() then RD.totemsFought = true end   -- the totems standing go through this fight (BRING after)
        RD.totemsBrought = false
        if RD.Active() then RD.PaintQuiet() RD.PickFuel() RD.PaintFuel() end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        RD.inFight = nil
        RD.resDirty = true                 -- who died in it: the res asks at the next tick
        if RD.pending then RD.Apply() if RD.Active() then RD.Arm() end
        elseif RD.Active() then
            RD.ArmTools()                  -- the numbers are plain again: each tool re-learns where it lights
            RD.PaintQuiet() RD.PaintShield() RD.PickFuel() RD.PaintFuel()
        end
        RD.LearnTimers()                   -- a totem swapped in the fight: its box learns it now
        RD.CueSeed()                       -- the heal cues: the truth off every box, now it is plain again
        return
    end
    if not RD.Active() then return end
    if event == "GROUP_ROSTER_UPDATE" or event == "SPELLS_CHANGED" or event == "BAG_UPDATE_DELAYED"
       or event == "PLAYER_ROLES_ASSIGNED" or event == "PLAYER_LEVEL_UP" then   -- a role set: the pip's sign follows
        -- in a fight it only marks RD.pending; then a repaint, so whoever LEFT goes dark now, not at the fight's end
        -- (11 Nov, Arn: "left group still icons remain ... during combat")
        if not RD.Arm() then RD.Paint() end
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then   -- you stood up (a res taken, back at your body)
        for _, sp in ipairs(RD.spokes) do RD.PaintHeal(sp) end
        RD.resDirty = true
    elseif event == "INCOMING_RESURRECT_CHANGED" or event == "UNIT_CONNECTION" then
        if not (RD.inFight or combat()) then RD.resDirty = true end
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if NS.Secret and NS.Secret(a1) then return end
        -- a death or a res between pulls (not every regen tick): the res asks again only for the dead, or for the one it
        -- is aimed at (they stood up)
        if RD.res and not (RD.inFight or combat()) and a1 ~= nil then
            if a1 == RD.res.unit then RD.resDirty = true
            elseif UnitIsDeadOrGhost then
                local okD, dead = pcall(UnitIsDeadOrGhost, a1)
                if okD and plain(dead) == true then RD.resDirty = true end
            end
        end
        for _, sp in ipairs(RD.spokes) do
            if sp.unit == a1 then RD.PaintHeal(sp) elseif sp.petUnit == a1 then RD.PaintPet(sp) end
        end
        if a1 ~= nil and a1 == RD.fuelUnit then RD.PaintBoss() end
    elseif event == "UNIT_PET" then
        -- an owner called or sent away a pet: the client's watch shows or hides the pip; we repaint its colour
        if NS.Secret and NS.Secret(a1) then return end
        for _, sp in ipairs(RD.spokes) do if sp.unit == a1 then RD.PaintPet(sp) end end
        -- the deck: a pet is a box of its own - called or sent away, the deck is laid out again (after the fight, in one)
        if RD.Deck() then if combat() then RD.pending = true else RD.Arm() end end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
        if a1 == "player" then
            -- a bigger or smaller pool between pulls (gear, a buff): the tools re-learn where they light
            if event == "UNIT_MAXPOWER" and not combat() then RD.ArmTools() end
            RD.PaintMana() RD.PaintQuiet()
        end
    elseif event == "UNIT_AURA" then
        if a1 == "player" then RD.PaintShield() end
        if a1 == "player" and not combat() then
            local want, wanted = RD.FoodShown()
            RD.rations.wanted = wanted
            if want ~= RD.rations.item then armUse(RD.rations, want) RD.PaintQuiet() end
            RD.PaintBuffDims()
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        RD.KickCooldown()
        RD.Sweeps()
    elseif event == "UNIT_TARGET" then
        if a1 == "target" then RD.PaintCross() RD.PaintDeckBox() RD.RipMarks() end   -- your target picked someone else: the amber mark moves, the cues follow
    elseif event == "PLAYER_TARGET_CHANGED" then
        RD.PaintCross()
        RD.PaintDeckBox()                                -- the deck's target box: who is in it now
        RD.RipMarks()                                    -- (17 Nov, Arn: "if I target later they dont show up" - the cues follow who is in the box)
        RD.Look()
        RD.PickFuel() RD.PaintBoss()
    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        RD.PickFuel() RD.PaintBoss()       -- a boss came (or went): the tape races it
    elseif event == "UI_ERROR_MESSAGE" then
        -- a heal that failed on line of sight or range: the word under the pip under the mouse
        RD.HeardError(a2)
    end
end)

NS.AlphaFeature{ key = RD.KEY, name = "the radar's words",
                 desc = "the radar's hidden words (heal, center, knob) - the radar itself is a look now (look: radar)",
                 apply = function() RD.Apply() end, cmd = function(rest) return RD.Command(rest) end }
