--[[ BiSHealing :: Effects.lua (NS.FX) - THE CLASS EFFECTS on the deck (BiS Cues sheet 3, Arn 21 Nov 2026: "all").

  The shaman has his Chain Heal path (Radar.lua, RD.BounceDraw). These are the other three healers' pictures, drawn
  across the deck's boxes on our own layer, each a switch on the deck's panel (group CLASS EFFECTS), OFF until picked:
  - PALADIN, "Light's Vigil burst" (fxvigil): your Holy Shock lands on someone who carries your Light's Vigil (Radar.lua's
    own clock of it, RD.cueMarks.vigil, read at the cast's SENT - RD.CueCast takes the mark away at the landing) and
    the heals the game names in that moment = their party: gold dashed rays from their box to every other box it
    healed, a gold ring swelling round each. ~1.2 s.
  - PRIEST, "Prayer of Mending hops" (fxmend): each heal of your Prayer of Mending, a white arc from the last box it
    healed to the new one, the heals it has left as a small number when its own words say how many (else no number).
    "Prayer of Healing pulse" (fxpoh): a white ring on every box your Prayer of Healing healed.
  - DRUID, "Wild Growth bloom" (fxwild): a soft green glow on every box your Wild Growth reached, fading over its 7 s.

  HOW IT KNOWS WHO WAS HEALED - the Chain Heal path's road (RD.BounceSent / RD.BounceJudge, measured live 16 Nov): the
  game names every heal's target plainly in UNIT_COMBAT (unit, "HEAL", "CRITICAL"/"", amount hidden) even in a fight,
  while auras and the combat text's names are hidden. So: your own UNIT_SPELLCAST_SENT names the spell (by NAME, from
  the client's spell info - the ids below are UNVERIFIED on Forever and never compared) and opens a short listen on
  UNIT_COMBAT; UNIT_SPELLCAST_SUCCEEDED is the landing; a C_Timer a moment later takes the group tokens' heals in that
  moment (player / partyN / raidN only - the same person also comes as target / nameplateN; RD.BounceSpoke maps a
  token to its box, aliases included).
  - Holy Shock + Vigil: the heals within FX.VIGIL_WIN s of the landing (the splash may trail the first heal a little).
  - Prayer of Healing: the heals in the landing's own frame (FX.SAME), like the Chain Heal path.
  - Wild Growth (a 3 s cast on Forever, a HoT on the target's party): the target's box glows at the landing; its first
    tick lands on everyone at once a second later, so at FX.WILD_LOOK s the biggest same-frame bunch of heals (the one
    holding the target's box, if any) joins the bloom.
  - Prayer of Mending: no spell name comes with a heal, and its heals come whenever the carrier is hit. Its mark: a
    HEAL and a WOUND (or a second HEAL - one Forever guide says a direct heal sets it off too; CONFLICT, both taken) on
    the SAME person in the SAME frame. The first must be on the box you cast it on; each next one on any OTHER box than
    the last (it jumps on). Up to FX.mend.left heals, alive FX.MEND_LIFE s after each. A coincidence (a HoT ticking as a
    hit lands) can draw a false hop: a white arc is all it costs.

  LEAN: nothing is registered while all four switches are off. While one is on, only your own SENT / SUCCEEDED
  (RegisterUnitEvent, player). UNIT_COMBAT only from a matching cast's SENT until its judging is done, or while a Prayer
  of Mending is alive; it lets itself go on the first event after. A stranger's event while it listens costs two
  client calls. The OnUpdate runs only while something is fading, and every texture is pooled and built on first use.
  Nothing here touches a secure frame: our layer is a plain frame over the deck, its pieces are anchored TO the boxes.

  DEFAULT OFF: RD.Sw reads nil as ON (so nobody's deck changed when the panel came in). Three roads were open; this file
  takes two at once, so the panel and the effects can never disagree: FX.Stamp writes `false` for the four keys ONCE
  per character (stamp `fxStamp`, after RD.SwStamp, which needs `sw == nil` to move an engineer user to LEAN), so the
  panel draws them off; and FX.Sw itself reads nil as OFF, so even an unstamped save never draws. FULL (and RESET,
  which is FULL) turns them on - FULL means everything. The switches are added to RD.SW from here, after the DRUID group,
  so Radar.lua needs no edit. ]]
local _, NS = ...
NS = NS or {}
local FX = {}
NS.FX = FX
local RD = NS.RD

-- the spells, by NAME (the client's own spell info answers the name for your cast's id). Classic / TBC ids for the
-- record only, all UNVERIFIED on Forever, none compared: Holy Shock 20473, Prayer of Mending 33076, Prayer of Healing
-- 596, Wild Growth 48438 (a Wrath id; Forever's is its own). Light's Vigil is a Forever spell - Radar.lua tracks it.
FX.SPELLS = { ["Holy Shock"] = "vigil", ["Prayer of Mending"] = "mend", ["Prayer of Healing"] = "poh", ["Wild Growth"] = "wild" }
FX.NAME = {}
for name, kind in pairs(FX.SPELLS) do FX.NAME[kind] = name end
FX.KEY = { vigil = "fxvigil", mend = "fxmend", poh = "fxpoh", wild = "fxwild" }
FX.KEYS = { "fxvigil", "fxmend", "fxpoh", "fxwild" }
FX.SWITCHES = {
    { key = "fxvigil", group = "CLASS EFFECTS", name = "Light's Vigil burst",     tip = "Paladin. When your Holy Shock lands on someone carrying your Light's Vigil, gold rays from their box to every box it also healed, and a gold ring on each." },
    { key = "fxmend",  group = "CLASS EFFECTS", name = "Prayer of Mending hops",  tip = "Priest. Each time your Prayer of Mending heals someone and jumps on, a white arc from the last box it healed to the new one, with the heals it has left when the game says." },
    { key = "fxpoh",   group = "CLASS EFFECTS", name = "Prayer of Healing pulse", tip = "Priest. A white ring on every box your Prayer of Healing healed." },
    { key = "fxwild",  group = "CLASS EFFECTS", name = "Wild Growth bloom",       tip = "Druid. A soft green glow on every box your Wild Growth reached, fading over its 7 seconds." },
}

FX.SAME = 0.06            -- one frame (the Chain Heal path's RD.BOUNCE_SAME)
FX.BEFORE = 0.1           -- a heal can land just BEFORE our cast event (Arn's bounce probe, 16 Nov)
FX.VIGIL_WIN = 0.3        -- the Vigil's party splash: within this of the landing
FX.WILD_LOOK = 1.3        -- Wild Growth's first tick (about 1 s in) is looked for until then
FX.WILD_LEN = 7           -- its length when its own words cannot be read (UNVERIFIED: guides say 7 s)
FX.MEND_LIFE = 30         -- Prayer of Mending lasts this long after each jump (UNVERIFIED: its words are read when plain)
FX.ARMED_FOR = 6          -- a cast that never lands: let go after this
FX.HOLD = { vigil = 1.2, mend = 1.2, poh = 0.9 }
FX.GOLD = { 1.00, 0.82, 0.25 }
FX.WHITE = { 1.00, 1.00, 1.00 }
FX.GREEN = { 0.40, 1.00, 0.50 }
FX.GLOW_A = 0.32          -- the bloom's brightest
FX.DASH, FX.GAP, FX.MAX_DASH = 6, 4, 30
FX.ARC_SEGS = 10
FX.FONT = "Fonts\\ARIALN.TTF"

FX.ring = {}              -- recent group-token heals and hits: { t, u, a }
FX.live = {}              -- what is fading: { t0, hold, objs, step }
FX.pend = nil             -- the cast being judged: { kind, sp, armedAt, landedAt }
FX.mend = nil             -- a Prayer of Mending alive: { first, prev, left, lastAt, hops, lastU }

local function plain(v)
    if NS.Plain then return NS.Plain(v) end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
local function combat() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function db()
    local d = NS.DB()
    d.radar = type(d.radar) == "table" and d.radar or {}
    return d.radar
end
local function groupToken(u)
    if RD and RD.BounceGroupToken then return RD.BounceGroupToken(u) end
    return false
end

-- THE SWITCHES on the deck's panel, after the DRUID group (FULL turns them on with everything else)
if RD and RD.SW then
    local at = #RD.SW + 1
    for i, s in ipairs(RD.SW) do if s.group == "DRUID" then at = i + 1 end end
    for j, s in ipairs(FX.SWITCHES) do table.insert(RD.SW, at + j - 1, s) end
    if RD.SW_PRESETS and RD.SW_PRESETS.full then
        for _, s in ipairs(FX.SWITCHES) do RD.SW_PRESETS.full[s.key] = true end
    end
end

--- A class effect's switch: ON only when written true (nil = off - see the header).
function FX.Sw(key)
    local t = db().sw
    return type(t) == "table" and t[key] == true
end
function FX.AnyOn()
    for _, k in ipairs(FX.KEYS) do if FX.Sw(k) then return true end end
    return false
end
function FX.On() return (RD and RD.Deck and RD.Deck()) == true and FX.AnyOn() end

--- Once per character: the four switches written off, so the panel shows them off. Answers true when it wrote.
function FX.Stamp()
    if not NS.DB then return false end
    local d = db()
    if d.fxStamp then return false end
    if RD and RD.SwStamp then RD.SwStamp() end       -- first: it reads `sw == nil`
    d.sw = type(d.sw) == "table" and d.sw or {}
    for _, k in ipairs(FX.KEYS) do if d.sw[k] == nil then d.sw[k] = false end end
    d.fxStamp = 1
    return true
end

-- the events: your own casts (only while a switch is on), and UNIT_COMBAT (only while a cast is judged / a PoM lives)
FX.castEv = CreateFrame("Frame")
FX.combatEv = CreateFrame("Frame")
FX.loginEv = CreateFrame("Frame")

--- Listen to your own casts while any class effect is on; nothing at all while none is. Answers whether it listens.
function FX.Arm()
    local on = FX.AnyOn()
    local f = FX.castEv
    if on and not FX.armed then
        if f.RegisterUnitEvent then
            pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SENT", "player")
            pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SUCCEEDED", "player")
        end
        FX.armed = true
    elseif not on and FX.armed then
        f:UnregisterEvent("UNIT_SPELLCAST_SENT")
        f:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        FX.armed = false
        FX.pend, FX.mend = nil, nil
        FX.Listen(false)
    end
    return FX.armed == true
end
--- UNIT_COMBAT on or off.
function FX.Listen(on)
    local f = FX.combatEv
    if on and not FX.listening then
        pcall(f.RegisterEvent, f, "UNIT_COMBAT")
        FX.listening = true
    elseif not on and FX.listening then
        f:UnregisterEvent("UNIT_COMBAT")
        FX.listening = false
        FX.ring = {}
    end
end
--- Is anything still waiting for heals?
function FX.Wanted(now)
    local p = FX.pend
    if p then
        if p.landedAt then
            if now - p.landedAt <= (p.keep or 0) then return true end
        elseif now - p.armedAt <= FX.ARMED_FOR then return true end
    end
    local m = FX.mend
    if m and now - m.lastAt <= m.life and (m.left == nil or m.left > 0) then return true end
    return false
end

local function spellName(spellID)
    spellID = plain(spellID)
    if type(spellID) ~= "number" then return nil end
    local get = C_Spell and C_Spell.GetSpellName
    if not get then return nil end
    local ok, name = pcall(get, spellID)
    return ok and plain(name) or nil
end

--- Did your Light's Vigil sit on this box's person (by Radar.lua's own clock), and was the cast aimed at them?
function FX.VigilOn(sp, now)
    if not (sp and sp.unit and RD and RD.RipKey) then return false end
    local m = RD.cueMarks and RD.cueMarks.vigil
    local t = m and m[RD.RipKey(sp.unit)]
    if type(t) ~= "number" or t <= now then return false end
    if RD.CueElsewhere and RD.CueElsewhere(sp, now) then return false end   -- a Holy Shock on an enemy
    return true
end

--- UNIT_SPELLCAST_SENT (you): one of the four spells on its way, its switch on - listen from now. Answers the kind.
function FX.Sent(target, spellID)
    if not FX.On() then return false end
    local kind = FX.SPELLS[spellName(spellID) or ""]
    if not kind or not FX.Sw(FX.KEY[kind]) then return false end
    local now = GetTime()
    if RD.RipSent then RD.RipSent(target) end        -- (whom the game says you aimed at, for RD.CastTarget)
    local sp = RD.CastTarget and RD.CastTarget(now) or nil
    if kind == "vigil" and not FX.VigilOn(sp, now) then return false end
    FX.pend = { kind = kind, sp = sp, armedAt = now }
    FX.ring = {}
    FX.Listen(true)
    return kind
end

--- UNIT_SPELLCAST_SUCCEEDED (you): the landing. Answers the kind it judges.
function FX.Landed(spellID)
    local p = FX.pend
    if not p or p.landedAt then return false end
    if spellName(spellID) ~= FX.NAME[p.kind] then return false end
    local now = GetTime()
    p.landedAt = now
    if p.kind == "mend" then
        FX.pend = nil
        FX.MendStart(p.sp, now)
        return "mend"
    end
    local wait = (p.kind == "vigil" and FX.VIGIL_WIN) or (p.kind == "wild" and FX.WILD_LOOK) or FX.SAME
    p.keep = wait + 0.25
    if p.kind == "wild" and p.sp then pcall(FX.Bloom, p, { p.sp }) end   -- it always reaches its target: glow now
    if C_Timer and C_Timer.After then C_Timer.After(wait, function() FX.Judge(p) end) else FX.Judge(p) end
    return p.kind
end

--- The boxes healed between two moments, each once, in the order the game named them.
local function boxesBetween(from, to, onlyHeal)
    local out, seen = {}, {}
    for _, e in ipairs(FX.ring) do
        if e.t >= from and e.t <= to and (e.a == "HEAL" or not onlyHeal) then
            local sp = RD.BounceSpoke(e.u)
            if sp and not seen[sp] then seen[sp] = true out[#out + 1] = sp end
        end
    end
    return out
end

--- A moment later: whom it healed. Draws (never breaks your casts: pcall). Answers the boxes' count.
function FX.Judge(p)
    if not p or FX.pend ~= p or not p.landedAt then return 0 end
    FX.pend = nil
    local at, n = p.landedAt, 0
    if p.kind == "vigil" then
        local healed = boxesBetween(at - FX.BEFORE, at + FX.VIGIL_WIN, true)
        local others = {}
        for _, sp in ipairs(healed) do if sp ~= p.sp then others[#others + 1] = sp end end
        local from = p.sp or healed[1]
        if from and from == healed[1] and not p.sp then table.remove(others, 1) end
        if from and #others >= 1 then
            n = #others + 1
            local ok, err = pcall(FX.DrawVigil, from, others)
            if not ok then FX.err = err end
        end
    elseif p.kind == "poh" then
        local healed = boxesBetween(at - FX.SAME, at + FX.SAME, true)
        n = #healed
        if n > 0 then
            local ok, err = pcall(FX.DrawRings, healed, FX.WHITE, FX.HOLD.poh)
            if not ok then FX.err = err end
        end
    elseif p.kind == "wild" then
        local best = FX.WildBunch(at, p.sp)
        n = #best
        if n > 0 then
            local ok, err = pcall(FX.Bloom, p, best)
            if not ok then FX.err = err end
        end
    end
    FX.last = { kind = p.kind, n = n, at = at }
    return n
end

--- Wild Growth's first tick: the heals bunched in one frame after the landing - the biggest bunch holding the target's
--- box, else the biggest of two or more.
function FX.WildBunch(at, target)
    local bunches, cur = {}, nil
    for _, e in ipairs(FX.ring) do
        if e.a == "HEAL" and e.t >= at - FX.SAME and e.t <= at + FX.WILD_LOOK then
            if not cur or e.t - cur.t > FX.SAME then
                cur = { t = e.t, boxes = {}, seen = {} }
                bunches[#bunches + 1] = cur
            end
            local sp = RD.BounceSpoke(e.u)
            if sp and not cur.seen[sp] then cur.seen[sp] = true cur.boxes[#cur.boxes + 1] = sp end
        end
    end
    local best, bestT
    for _, b in ipairs(bunches) do
        local hasT = target and b.seen[target] or false
        if hasT and (not bestT or #b.boxes > #bestT.boxes) then bestT = b end
        if #b.boxes >= 2 and (not best or #b.boxes > #best.boxes) then best = b end
    end
    local pick = bestT or best
    return pick and pick.boxes or {}
end

--- Prayer of Mending landed on a box: its life starts. The heals it has left, off its own words out of a fight.
FX.mendWords = nil
function FX.MendWords()
    if FX.mendWords then return FX.mendWords end
    local w = { charges = nil, life = FX.MEND_LIFE }
    if combat() or not (C_Spell and C_Spell.GetSpellDescription) then return w end
    local ok, d = pcall(C_Spell.GetSpellDescription, FX.NAME.mend)
    d = ok and plain(d) or nil
    if type(d) == "string" and d ~= "" then
        local n = tonumber(d:match("up to (%d+) times") or d:match("(%d+) times") or d:match("(%d+) charges") or "")
        if n and n >= 1 and n <= 10 then w.charges = n end
        local life = tonumber(d:match("lasts (%d+) sec") or "")
        if life and life >= 5 and life <= 120 then w.life = life end
        FX.mendWords = w                                 -- read once
    end
    return w
end
function FX.MendStart(sp, now)
    local w = FX.MendWords()
    FX.mend = { first = sp, prev = nil, left = w.charges, life = w.life, lastAt = now, hops = 0 }
    FX.Listen(true)
    for _, e in ipairs(FX.ring) do                       -- a hit in the landing's own frame
        if math.abs(e.t - now) <= FX.SAME then FX.MendCheck(e.u, now) end
    end
    return FX.mend
end
--- A group token was hit or healed: was that your Prayer of Mending going off (a HEAL with a WOUND or a second HEAL on
--- the same person in the same frame)? Draws the hop. Answers the box.
function FX.MendCheck(u, now)
    local m = FX.mend
    if not m or (m.lastU == u and m.lastAt == now) then return nil end
    local heals, hits = 0, 0
    for _, e in ipairs(FX.ring) do
        if e.u == u and math.abs(e.t - now) <= FX.SAME then
            if e.a == "HEAL" then heals = heals + 1 else hits = hits + 1 end
        end
    end
    if heals < 1 or (hits < 1 and heals < 2) then return nil end
    local sp = RD.BounceSpoke(u)
    if not sp then return nil end
    if m.hops == 0 and m.first and sp ~= m.first then return nil end   -- the first heal is on the box you cast it on
    if m.hops > 0 and sp == m.prev then return nil end                  -- it jumped away from there
    m.hops = m.hops + 1
    if m.left then m.left = m.left - 1 end
    local ok, err = pcall(FX.DrawMend, m.prev, sp, m.left)
    if not ok then FX.err = err end
    m.prev, m.lastAt, m.lastU = sp, now, u
    FX.last = { kind = "mend", n = m.hops, at = now, left = m.left }
    if m.left and m.left <= 0 then FX.mend = nil end
    return sp
end

--- UNIT_COMBAT: a group token's heal or hit goes into the ring. A stranger costs two client calls.
function FX.Heard(unit, action)
    local now = GetTime()
    if not FX.Wanted(now) then FX.Listen(false) FX.pend = nil FX.mend = nil return end
    if not groupToken(unit) then return end
    if (NS.Secret and NS.Secret(action)) or (action ~= "HEAL" and action ~= "WOUND") then return end
    local ring = FX.ring
    if #ring >= 24 then table.remove(ring, 1) end
    ring[#ring + 1] = { t = now, u = unit, a = action }
    if FX.mend then FX.MendCheck(unit, now) end
end

FX.castEv:SetScript("OnEvent", function(_, event, _, a2, a3, a4)
    if event == "UNIT_SPELLCAST_SENT" then FX.Sent(a2, a4)          -- (unit, target, castGUID, spellID)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then FX.Landed(a3) end   -- (unit, castGUID, spellID)
end)
FX.combatEv:SetScript("OnEvent", function(_, _, unit, action) FX.Heard(unit, action) end)
pcall(FX.loginEv.RegisterEvent, FX.loginEv, "PLAYER_LOGIN")
FX.loginEv:SetScript("OnEvent", function() FX.Stamp() FX.Arm() end)
-- a switch flipped (RD.SetSw / RD.SwPreset / RESET all go through RD.SwApply): listen, or stop
if RD and RD.SwApply then
    local swApply = RD.SwApply
    function RD.SwApply(...)
        local r = swApply(...)
        FX.Arm()
        return r
    end
end

--[[ THE DRAWING: one plain layer over the deck (the Chain Heal path's road), pools of lines, rings (four edges round a
  box), glows and numbers, built on first use and kept. One OnUpdate while anything fades; gone when nothing does. ]]
function FX.Layer()
    local L = FX.layer
    if L then return L end
    local parent = (RD and (RD.conLayer or RD.frame)) or UIParent
    L = CreateFrame("Frame", nil, parent)
    L:SetAllPoints(parent)
    local lvl = parent.GetFrameLevel and parent:GetFrameLevel()
    if type(lvl) == "number" then L:SetFrameLevel(lvl + 42) end
    L.pool = { line = { free = {}, made = 0 }, ring = { free = {}, made = 0 }, glow = { free = {}, made = 0 }, label = { free = {}, made = 0 } }
    L:Hide()
    FX.layer = L
    return L
end
local MAKE = {
    line = function(L)
        local l = L:CreateLine(nil, "OVERLAY")
        if l.SetTexture then l:SetTexture("Interface\\Buttons\\WHITE8X8") end
        return l
    end,
    ring = function(L)
        local r = CreateFrame("Frame", nil, L)
        r.edges = {}
        for _, s in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                             { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
            local t = r:CreateTexture(nil, "OVERLAY")
            t:SetPoint(s[1]) t:SetPoint(s[2])
            if s[3] then t:SetHeight(2) else t:SetWidth(2) end
            r.edges[#r.edges + 1] = t
        end
        return r
    end,
    glow = function(L)
        local g = L:CreateTexture(nil, "ARTWORK")
        g:SetTexture("Interface\\Buttons\\WHITE8X8")
        if g.SetBlendMode then g:SetBlendMode("ADD") end
        return g
    end,
    label = function(L)
        local fs = L:CreateFontString(nil, "OVERLAY")
        fs:SetFont(FX.FONT, 11, "OUTLINE")
        fs:SetTextColor(1, 1, 1, 1)
        return fs
    end,
}
local function take(item, kind)
    local L = FX.Layer()
    local p = L.pool[kind]
    local o = table.remove(p.free)
    if not o then o = MAKE[kind](L) p.made = p.made + 1 end
    o:Show()
    item.objs[#item.objs + 1] = { kind, o }
    return o
end
local function release(item)
    local L = FX.layer
    for _, ko in ipairs(item.objs) do
        ko[2]:Hide()
        local p = L.pool[ko[1]].free
        p[#p + 1] = ko[2]
    end
    item.objs = {}
end
local function tick(self)
    local now = GetTime()
    local live = FX.live
    for i = #live, 1, -1 do
        local it = live[i]
        local age = now - it.t0
        local ok = age < it.hold and pcall(it.step, it, age)
        if not ok then release(it) table.remove(live, i) end
    end
    if #live == 0 then self:SetScript("OnUpdate", nil) self:Hide() end
end
FX.Tick = function() if FX.layer then tick(FX.layer) end end
local function start(item)
    local L = FX.Layer()
    FX.live[#FX.live + 1] = item
    pcall(item.step, item, GetTime() - item.t0)
    L:Show()
    L:SetScript("OnUpdate", tick)
    return item
end
local function newItem(hold, step, t0) return { t0 = t0 or GetTime(), hold = hold, objs = {}, step = step } end
--- Fade in fast, hold, fade out over the last 60%.
local function env(age, hold)
    if age < 0.08 then return age / 0.08 end
    local h = hold * 0.4
    if age < h then return 1 end
    return math.max(0, 1 - (age - h) / (hold - h))
end
--- A box's middle on the layer's own coordinates (from its bottom-left), or nil while the client has not placed it.
local function middleOf(L, sp)
    local p = sp and sp.deckPlate
    if not (p and p.GetCenter) then return nil end
    local cx, cy = p:GetCenter()
    local ox, oy = L:GetLeft(), L:GetBottom()
    if type(cx) ~= "number" or type(cy) ~= "number" or type(ox) ~= "number" or type(oy) ~= "number" then return nil end
    return cx - ox, cy - oy
end
local function line(item, L, x1, y1, x2, y2, col, thick)
    local l = take(item, "line")
    l:SetStartPoint("BOTTOMLEFT", L, x1, y1)
    l:SetEndPoint("BOTTOMLEFT", L, x2, y2)
    l:SetThickness(thick)
    l:SetVertexColor(col[1], col[2], col[3], 1)
    return l
end
local function ring(item, sp, col)
    local r = take(item, "ring")
    for _, t in ipairs(r.edges) do t:SetColorTexture(col[1], col[2], col[3], 1) end
    r.box = sp.deckPlate
    return r
end
local function placeRing(r, grow)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", r.box, "TOPLEFT", -grow, grow)
    r:SetPoint("BOTTOMRIGHT", r.box, "BOTTOMRIGHT", grow, -grow)
end
local function stepLinesRings(it, age)
    local a = env(age, it.hold)
    local grow = 1 + math.min(age, 0.6) / 0.6 * 10
    for _, ko in ipairs(it.objs) do
        local o = ko[2]
        if ko[1] == "ring" then placeRing(o, grow) o:SetAlpha(a * (1 - math.min(age, 0.6) / 0.6 * 0.5))
        else o:SetAlpha(a) end
    end
end

--- Holy Shock through Light's Vigil: gold dashed rays from the target's box to each other box it healed + a gold ring on each.
function FX.DrawVigil(from, others)
    local L = FX.Layer()
    local it = newItem(FX.HOLD.vigil, stepLinesRings)
    local x1, y1 = middleOf(L, from)
    for _, sp in ipairs(others) do
        local x2, y2 = middleOf(L, sp)
        if x1 and x2 then
            local dx, dy = x2 - x1, y2 - y1
            local len = math.sqrt(dx * dx + dy * dy)
            local step = FX.DASH + FX.GAP
            local n = math.min(FX.MAX_DASH, math.max(1, math.floor(len / step)))
            for i = 0, n - 1 do
                local f1 = i * step / math.max(len, 1)
                local f2 = math.min(1, (i * step + FX.DASH) / math.max(len, 1))
                line(it, L, x1 + dx * f1, y1 + dy * f1, x1 + dx * f2, y1 + dy * f2, FX.GOLD, 2)
            end
        end
    end
    ring(it, from, FX.GOLD)
    for _, sp in ipairs(others) do ring(it, sp, FX.GOLD) end
    FX.lastDraw = { kind = "vigil", item = it }
    return start(it)
end
--- A ring swelling round each box (Prayer of Healing: white).
function FX.DrawRings(boxes, col, hold)
    local it = newItem(hold, stepLinesRings)
    for _, sp in ipairs(boxes) do ring(it, sp, col) end
    FX.lastDraw = { kind = "rings", item = it }
    return start(it)
end
--- One Prayer of Mending heal: a white arc from the last box it healed (none for its first) + a ring, and the heals left.
function FX.DrawMend(prev, sp, left)
    local L = FX.Layer()
    local it = newItem(FX.HOLD.mend, stepLinesRings)
    local x1, y1 = middleOf(L, prev)
    local x2, y2 = middleOf(L, sp)
    if prev and x1 and x2 then
        local dx, dy = x2 - x1, y2 - y1
        local len = math.max(1, math.sqrt(dx * dx + dy * dy))
        local bow = math.max(18, len * 0.3)              -- the arc bows to the left of its way
        local cx, cy = (x1 + x2) / 2 - dy / len * bow, (y1 + y2) / 2 + dx / len * bow
        local px, py = x1, y1
        for s = 1, FX.ARC_SEGS do
            local t = s / FX.ARC_SEGS
            local u = 1 - t
            local qx = u * u * x1 + 2 * u * t * cx + t * t * x2
            local qy = u * u * y1 + 2 * u * t * cy + t * t * y2
            line(it, L, px, py, qx, qy, FX.WHITE, 2)
            px, py = qx, qy
        end
    end
    ring(it, sp, FX.WHITE)
    if left then
        local fs = take(it, "label")
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOMRIGHT", sp.deckPlate, "TOPRIGHT", -2, 2)
        fs:SetText(tostring(left))
    end
    FX.lastDraw = { kind = "mend", item = it }
    return start(it)
end
--- Wild Growth: a soft green glow on each box, fading over its length from the landing (boxes may join later).
local function stepBloom(it, age)
    local a = (age < 0.15 and age / 0.15 or 1) * FX.GLOW_A * math.max(0, 1 - age / it.hold)
    for _, ko in ipairs(it.objs) do ko[2]:SetAlpha(a) end
end
function FX.Bloom(p, boxes)
    local it = p.item
    if not it then
        local len = (RD and RD.SpellSecs and RD.SpellSecs(FX.NAME.wild, FX.WILD_LEN)) or FX.WILD_LEN
        it = newItem(len, stepBloom, p.landedAt)
        it.seen = {}
        p.item = it
        start(it)
    end
    for _, sp in ipairs(boxes) do
        if sp.deckPlate and not it.seen[sp] then
            it.seen[sp] = true
            local g = take(it, "glow")
            g:SetVertexColor(FX.GREEN[1], FX.GREEN[2], FX.GREEN[3], 1)
            g:ClearAllPoints()
            g:SetAllPoints(sp.deckPlate)
        end
    end
    pcall(it.step, it, GetTime() - it.t0)
    FX.lastDraw = { kind = "wild", item = it }
    return it
end
