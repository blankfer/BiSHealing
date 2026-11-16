--[[
  BiSHealing :: Engineer.lua - THE ENGINEER'S BOXES ARE HEALTH BARS (12 Nov 2026).

  Arn: "engineer view for friendly boxes can we get rid of the icons inside the box and make them actual health bars class
  coded and figure out a over heal los range indicator?"

  The engineer's console (Radar.lua, RD.Console) places the radar's own secure heal pips on a grid. In the console only,
  each pip shows a HEALTH BAR instead of its role glyph:
    * the bar: a plain StatusBar inside the pip (never the secure pip itself), handed UnitHealthMax / UnitHealth untouched
      - the client scales it, the addon never learns either number (the grid's own bargain) - in the grid's class colour
      (FG.CLASS_COLOR), the grid's dead red when dead; the glyph faces hide (RD.PaintHeal still colours them, unseen);
    * RANGE: the grid's own dimming (FG.PaintRange on the box - a plain answer, else the client's ternary on a secret one),
      every radar tick while the console shows (RD.Look), and when a unit crosses the line (UNIT_IN_RANGE_UPDATE);
    * LOS / RANGE on a failed click: the click word (RD.HeardError) in the MIDDLE of the box, as on the grid;
    * INCOMING (Arn, 12 Nov: "engineer still missing the incoming heal mechanic"): heals on their way, as on the grid -
      UnitGetIncomingHeals handed untouched to a bar that starts where their health ends, in the cockpit's incoming cyan,
      on the health events and UNIT_HEAL_PREDICTION (heard only while the console shows);
    * OVERHEAL: while you hover, your hover heal as a paler GHOST right after the incoming - as long as the heal is,
      cut off at the box's edge (the client draws the heal against their max, a secret) - and OVER/H under the box when
      more than half would be wasted (Overheal.lua). Gone while your own cast is in the air (it is incoming then).
  On the radar nothing changes: the bars hide, the glyphs come back, the click word goes back under the pip.
  Cost: health on its events (one unit), range on the radar's half-second tick while the console shows.
]]
local ADDON, NS = ...
NS = NS or {}

local EN = {}
NS.EN = EN

EN.BG = { 0.04, 0.05, 0.06, 0.92 }       -- the empty part of a box
EN.INCOMING = { 0.22, 0.80, 1.00, 0.60 } -- heals on their way: the cockpit grid's own cyan (FG.COCKPIT.incoming)
EN.GHOST = { 0.22, 0.80, 1.00, 0.28 }    -- your hover heal: the same cyan, fainter - "this is what it would add"
-- THE OVERHEAL IN THE BOX (Arn, 12 Nov, with a screenshot of the grid's magenta: "in this grid this is the overheal can we
-- show that and the overheal word on the engineer?"): the grid's own band (Grid.lua, f.overheal) - a bar as wide as the
-- box filling LEFTWARDS from its right edge by the heals on their way, masked to their filled health, so only the part
-- over their health shows: the heal that lands on nobody. A second, fainter one carries on leftwards from it by your
-- hover heal: what YOUR heal would waste on top. Nothing compared; the client does the geometry. A MASK, not a clip:
-- a clip anchored to a secret-sized fill draws nothing (the grid's 8 Oct lesson).
EN.OVER = { 1.00, 0.12, 0.85, 0.95 }      -- the grid's classic overheal magenta (FG.OVERHEAL), the colour Arn showed
EN.OVER_HOVER = { 1.00, 0.12, 0.85, 0.45 }
EN.FALLBACK = { 0.20, 0.70, 0.30 }       -- a class the client will not say
EN.PET = { 0.55, 0.78, 0.35 }            -- a pet's box (the deck, 15 Nov): moss green, with the paw on its name line
EN.TEX = "Interface\\Buttons\\WHITE8X8"

-- ONE PLACE FOR EVERY ALERT (Arn, 12 Nov: "for the engineering since we are cramped for space, we can move all the alerts
-- for all players to the same space in the header?" - "so all stacked in the header LOS RANGE OVERHEAL"): whoever they are
-- about, they show in the console's top strip (RD.CON.pad + head, where only the class and view buttons sit, at the
-- right), in THREE BOXES (Arn: "oh thats right we can have 3 boxes" - "because a hover can show a los and overheal at
-- the same time"): LOS, RANGE, OVER/H, each its own dim empty box (the console's own look), lit by its word. Only one box
-- is under the mouse at a time, so the box you are on is whose it is.
EN.HEAD = { { key = "los", x = 0, w = 34 }, { key = "range", x = 38, w = 58 }, { key = "over", x = 100, w = 62 } }
EN.HEAD_H = 16

-- THE DECK'S BOXES, BIGGER (Arn, 15 Nov: "the los is a bit big if we have to go a little taller we can do that to
-- accommodate make sure they are centered"): the word keeps its size; its box grows round it, the strip taller.
-- FIVE BOXES AT THE DECK'S OWN WIDTH (16 Nov 2026): loss of control and the Riptide bar joined; the three word boxes a
-- little narrower, so all five fit the deck's own width without shrinking (a narrower window still scales them, EN.Heads)
-- THREE LETTERS EACH (Arn, 16 Nov: "some of those boxes are bigger than the actual things it prints LOS RNG OVH maybe we
-- can save space too"): the word boxes sized to their three letters
EN.HEAD_DECK = { { key = "los", x = 0, w = 36 }, { key = "range", x = 40, w = 36 }, { key = "over", x = 80, w = 38 },
                 { key = "cc", x = 122, w = 82 },    -- the fourth box, loss of control (EN.LossPaint)
                 { key = "rip", x = 208, w = 90 } }  -- the Riptide bar (EN.RipPaint)
EN.HEAD_DECK_H = 22
--- The boxes and their height for the surface showing now: the deck's bigger ones, else the console's / radar's.
function EN.Heads()
    local RD = NS.RD
    if RD and RD.Deck and RD.Deck() then
        -- a narrow window (16 Nov 2026, down to Ellesmere's width): the three boxes shrink to fit beside the switches button
        local room = (tonumber(RD.deckInnerW) or 999) - 18
        local full = EN.HEAD_DECK[#EN.HEAD_DECK].x + EN.HEAD_DECK[#EN.HEAD_DECK].w
        if room >= full then return EN.HEAD_DECK, EN.HEAD_DECK_H end
        local k = math.max(0.3, room / full)
        EN.headNarrow = EN.headNarrow or {}
        for i, h in ipairs(EN.HEAD_DECK) do
            local n = EN.headNarrow[i] or {}
            n.key, n.x, n.w = h.key, math.floor(h.x * k), math.floor(h.w * k)
            EN.headNarrow[i] = n
        end
        return EN.headNarrow, EN.HEAD_DECK_H
    end
    return EN.HEAD, EN.HEAD_H
end

local function headSlot(kind)
    local list = EN.Heads()
    for _, h in ipairs(list) do if h.key == kind then return h end end
    return list[1]
end

--- Where the alerts live now: the console's top strip, or on the radar the BLACK BOX's bottom row (Arn, 12 Nov: "find a
--- better place for the overheal los and range bars, the black box has a huge chat bot for the code mayeb we can use that
--- space" - the row the code screen sat in; BlackBox.lua puts the screen up over them only while a code is typed).
--- With no black box rail, the radar square's top-left corner. Answers the frame, the boxes' left edge, their middle's y.
function EN.Where()
    local RD = NS.RD
    if not RD then return UIParent, 8, -11 end
    if RD.Console and RD.Console() then
        local C = RD.CON or {}
        local pad = C.pad or 8
        local head = (RD.Deck and RD.Deck() and RD.DeckHead and RD.DeckHead()) or C.head or 14   -- the deck's strip is taller
        return RD.frame or UIParent, pad, -((pad + head) / 2)
    end
    -- the rail itself, shown or not yet: the radar's layout runs just before the view switch shows it
    local bb = RD.bbRail
    local row = bb and bb.row
    if row then
        local h = row.GetHeight and row:GetHeight()
        return row, 0, -((type(h) == "number" and h > 0 and h or 18) / 2)
    end
    return RD.frame or UIParent, 8, -11
end

--- An alert's spot ("los", "range" or "over"): point, relative frame, relative point, x, y. LOS and RANGE are centred in
--- their box; OVER/H's clipping window starts at its box's left edge (the word hangs 4 px in).
function EN.HeadSpot(kind, sp)
    -- the alert boxes switched off (16 Nov 2026): the word shows on the box it is about
    local RD = NS.RD
    if sp and sp.heal and RD and RD.Deck and RD.Deck() and RD.Sw and not RD.Sw("alerts") then
        if kind == "over" then return "LEFT", sp.heal, "LEFT", 2, 0 end
        return "CENTER", sp.heal, "CENTER", 0, 0
    end
    local f, x0, y = EN.Where()
    local h = headSlot(kind)
    if kind == "over" then return "LEFT", f, "TOPLEFT", x0 + h.x, y end
    return "CENTER", f, "TOPLEFT", x0 + h.x + h.w / 2, y
end

--- The three empty boxes, on the surface showing now: the console's own layer, or the radar's gauge rail (each hides
--- with its surface). Answers that surface's boxes.
function EN.HeadBoxes()
    local RD = NS.RD
    if not RD then return nil end
    local con = RD.Console and RD.Console()
    local bb = RD.bbRail
    local parent = con and RD.conLayer or (not con and (bb or RD.frame)) or nil
    if not parent then return nil end
    local key = con and "heads" or "radarHeads"
    EN[key] = EN[key] or {}
    local set = EN[key]
    local deck = con and RD.Deck and RD.Deck() and RD.Sw
    local function wanted(key)                       -- the switches: LOS / RANGE / OVER together, loss of control its own
        if not deck then return key ~= "cc" and key ~= "rip" end
        if key == "cc" then return RD.Sw("cc") end
        if key == "rip" then return RD.Sw("rip") and RD.RipKnown and RD.RipKnown() end
        return RD.Sw("alerts")
    end
    local f, x0, y = EN.Where()
    local dim = RD.DIM or { 0.22, 1.00, 0.53, 0.4 }
    local list, H = EN.Heads()
    for _, h in ipairs(list) do
        local q = set[h.key]
        if not q then
            q = CreateFrame("Frame", nil, parent)
            q.edges = {}
            for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
                local t = q:CreateTexture(nil, "BORDER")
                t:SetColorTexture(dim[1], dim[2], dim[3], dim[4] or 1)
                if side == "TOP" or side == "BOTTOM" then
                    t:SetPoint(side .. "LEFT", q, side .. "LEFT") t:SetPoint(side .. "RIGHT", q, side .. "RIGHT") t:SetHeight(1)
                else
                    t:SetPoint("TOP" .. side, q, "TOP" .. side) t:SetPoint("BOTTOM" .. side, q, "BOTTOM" .. side) t:SetWidth(1)
                end
                q.edges[#q.edges + 1] = t
            end
            set[h.key] = q
        end
        q:SetSize(h.w, H)
        q:ClearAllPoints()
        q:SetPoint("CENTER", f, "TOPLEFT", x0 + h.x + h.w / 2, y)
        q:SetShown(wanted(h.key))
    end
    for key, q in pairs(set) do                       -- a box this surface does not list (the cc box off the deck)
        local listed = false
        for _, h in ipairs(list) do if h.key == key then listed = true end end
        if not listed then q:Hide() end
    end
    if set.cc and set.cc:IsShown() then EN.LossPaint() end
    if set.rip and set.rip:IsShown() then EN.RipPaint() end
    if not con then
        EN.TintRadarHeads()
        -- the black box's screen may be up (a code being typed): the boxes wait under it
        local NB = NS.BB
        EN.ShowRadarHeads(not (NB and NB.ScreenUp and NB.ScreenUp()))
    end
    return set
end

--- The radar's boxes shown or put away (the black box's screen takes their row while a code is typed).
function EN.ShowRadarHeads(show)
    for _, q in pairs(EN.radarHeads or {}) do if show then q:Show() else q:Hide() end end
end

-- THE RADAR'S BOXES IN THE SHIP'S COLOURS (Arn, 12 Nov, a screenshot of green boxes on the purple radar: "same color theme
-- please"): edged like the readout box beside the tape - the ship's accent - a little dimmer, as empty boxes are. The
-- console keeps its own green (its squares are green). Repainted when the ship changes (RD.ApplyShip).
EN.RADAR_HEAD_A = 0.55

--- The radar's alert boxes edged in the ship's accent.
function EN.TintRadarHeads()
    local RD = NS.RD
    local A = (RD and RD.ship and RD.ship.accent) or (RD and RD.SHIPS and RD.SHIPS[1] and RD.SHIPS[1].accent)
    if not (A and EN.radarHeads) then return false end
    for _, q in pairs(EN.radarHeads) do
        for _, t in ipairs(q.edges or {}) do t:SetColorTexture(A[1], A[2], A[3], EN.RADAR_HEAD_A) end
    end
    return true
end

--- A click word on a pip (RD.HeardError): into its own box - LOS or RANGE - on whichever surface shows.
function EN.PlaceWord(sp, word)
    local RD = NS.RD
    if not (RD and RD.On and RD.On() and sp and sp.los) then return false end
    sp.los:ClearAllPoints()
    sp.los:SetPoint(EN.HeadSpot(word == "RANGE" and "range" or "los", sp))
    return true
end

local function secret(v) return NS.Secret and NS.Secret(v) or false end
local function plain(v) if v == nil or secret(v) then return nil end return v end
local function console()
    local RD = NS.RD
    return RD and RD.On and RD.On() and RD.Console and RD.Console() or false
end
EN.Console = console

--- A pip's box: a plain frame over the pip (inset a pixel, so the console's square edge shows), clipping its own bars.
function EN.Box(sp)
    if sp.en then return sp.en end
    local b = sp.heal
    if not b then return nil end
    local e = {}
    local box = CreateFrame("Frame", nil, b)
    box:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    box:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    box:SetClipsChildren(true)
    if box.SetFrameLevel and b.GetFrameLevel then
        local lvl = b:GetFrameLevel()
        if type(lvl) == "number" then box:SetFrameLevel(lvl + 1) end   -- under the dispel chips (pip + 3)
    end
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(box)
    bg:SetColorTexture(EN.BG[1], EN.BG[2], EN.BG[3], EN.BG[4])
    local bar = CreateFrame("StatusBar", nil, box)
    bar:SetAllPoints(box)
    bar:SetStatusBarTexture(EN.TEX)
    -- heals on their way: as wide as the box, starting where their health ends; the box clips what runs past its edge
    local inc = CreateFrame("StatusBar", nil, box)
    local fill = bar:GetStatusBarTexture()
    inc:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
    inc:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
    inc:SetStatusBarTexture(EN.TEX)
    inc:SetStatusBarColor(EN.INCOMING[1], EN.INCOMING[2], EN.INCOMING[3], EN.INCOMING[4])
    inc:SetMinMaxValues(0, 1)
    inc:SetValue(0)
    -- the ghost: the same, starting where the heals on their way end
    local ghost = CreateFrame("StatusBar", nil, box)
    local incFill = inc:GetStatusBarTexture()
    ghost:SetPoint("TOPLEFT", incFill, "TOPRIGHT", 0, 0)
    ghost:SetPoint("BOTTOMLEFT", incFill, "BOTTOMRIGHT", 0, 0)
    ghost:SetStatusBarTexture(EN.TEX)
    ghost:SetStatusBarColor(EN.GHOST[1], EN.GHOST[2], EN.GHOST[3], EN.GHOST[4])
    ghost:Hide()
    box:Hide()
    -- the overheal: the filled health is a mask's shape; the bands fill leftwards from the box's right edge
    local cur = CreateFrame("Frame", nil, box)
    cur:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    cur:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
    local mask = bar.CreateMaskTexture and bar:CreateMaskTexture() or nil
    if mask then
        mask:SetAllPoints(cur)
        mask:SetTexture(EN.TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "NEAREST")
    end
    local function band(c, anchor, point)
        local o = CreateFrame("StatusBar", nil, bar)
        o:SetPoint("TOPRIGHT", anchor, point, 0, 0)
        o:SetStatusBarTexture(EN.TEX)
        o:SetStatusBarColor(c[1], c[2], c[3], c[4])
        if o.SetReverseFill then o:SetReverseFill(true) end
        o:SetMinMaxValues(0, 1)
        o:SetValue(0)
        if o.SetFrameLevel and bar.GetFrameLevel then
            local lvl = bar:GetFrameLevel()
            if type(lvl) == "number" then o:SetFrameLevel(lvl + 3) end
        end
        local t = o.GetStatusBarTexture and o:GetStatusBarTexture()
        if mask and t and t.AddMaskTexture then t:AddMaskTexture(mask) end
        return o
    end
    local over = band(EN.OVER, box, "TOPRIGHT")
    -- a white tick where the waste begins (the grid's overTick), masked the same way: drawn only when there IS an overheal
    local overFill = over:GetStatusBarTexture()
    local tick = over:CreateTexture(nil, "OVERLAY")
    tick:SetColorTexture(1, 1, 1, 0.95)
    tick:SetWidth(2)
    tick:SetPoint("TOPLEFT", overFill, "TOPLEFT", 0, 0)
    tick:SetPoint("BOTTOMLEFT", overFill, "BOTTOMLEFT", 0, 0)
    if mask and tick.AddMaskTexture then tick:AddMaskTexture(mask) end
    local overHover = band(EN.OVER_HOVER, overFill, "TOPLEFT")
    overHover:Hide()
    e.box, e.bar, e.inc, e.ghost = box, bar, inc, ghost
    e.cur, e.mask, e.over, e.overTick, e.overHover = cur, mask, over, tick, overHover
    sp.en = e
    return e
end

--- A box's width, for the ghost to match (the pip is resized by the console's class).
function EN.Size(sp)
    local e, b = sp.en, sp.heal
    if not (e and b and b.GetWidth) then return end
    local w = b:GetWidth()
    if type(w) == "number" and w > 2 then e.inc:SetWidth(w - 2) e.ghost:SetWidth(w - 2) end
    local h = b.GetHeight and b:GetHeight()
    if type(w) == "number" and w > 2 and type(h) == "number" and h > 2 then
        e.over:SetSize(w - 2, h - 2)
        e.overHover:SetSize(w - 2, h - 2)
    end
end

--[[ ITS TARGET'S CLASS (16 Nov 2026, Arn's screenshot: Ztep in the ITS TARGET box drawn green, the colour for "class
  unknown" - in a fight the game hides the class of a unit seen through somebody's target). The group's own classes are
  plain, so ask the game who it is: UnitIsUnit against each member, tanks first, at most EN.FOLD_MAX. A plain yes takes
  that class; a SECRET answer is folded in channel by channel with EvaluateColorValueFromBoolean (the client picks; read
  off EllesmereUI_Colors, learn only - solved.md 14 Oct). Nothing found: the fallback colour as before. ]]
EN.FOLD_MAX = 10
function EN.FoldUnits()
    local RD, out = NS.RD, {}
    for _, i in ipairs((RD and RD.conOrder) or {}) do
        local u = RD.units and RD.units[i]
        if type(u) == "string" then out[#out + 1] = u end
        if #out >= EN.FOLD_MAX then break end
    end
    return out
end
function EN.FoldClass(unit, c)
    local FG = NS.FG
    local r, g, b = c[1], c[2], c[3]
    if not (UnitIsUnit and UnitClass and FG and FG.CLASS_COLOR) then return r, g, b end
    local curve = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
    -- what the game answered, kept for `/bish alpha radar tot` (one reused table: codes only, words made when asked)
    local seen = EN.foldSeen or {}
    EN.foldSeen = seen
    for k = #seen, 1, -1 do seen[k] = nil end
    for _, u in ipairs(EN.FoldUnits()) do
        local okC, _, tok = pcall(UnitClass, u)
        local cc = okC and FG.CLASS_COLOR[plain(tok) or ""]
        local ok, same
        if cc then ok, same = pcall(UnitIsUnit, unit, u) end
        local code = not cc and "no class" or not ok and "error" or nil
        if ok and secret(same) then
            code = "hidden, curve refused"
            if curve then
                local o1, nr = pcall(curve, same, cc[1], r)
                local o2, ng = pcall(curve, same, cc[2], g)
                local o3, nb = pcall(curve, same, cc[3], b)
                if o1 and o2 and o3 then r, g, b = nr, ng, nb code = "hidden, folded" end
            end
        elseif ok then
            code = (same == true) and "yes" or tostring(same)
        end
        seen[#seen + 1] = u .. "=" .. code
        -- secret first, THEN compare (Arn's BugGrabber, 16 Nov: "attempt to compare local 'same' (a secret boolean")
        if ok and not secret(same) and same == true then return cc[1], cc[2], cc[3] end
    end
    return r, g, b
end

--[[ LOSS OF CONTROL (16 Nov 2026, Arn: "need another los type bar for loss of control either how long im stunned or how long
  im silenced or how long im locked out of magic schools ... im leaning another bar"). The deck's fourth box: while YOU
  are stunned, silenced, feared or locked out of a school, the game's own icon, its own words ("Stunned", "Silenced",
  "Interrupted") and its own countdown - a bar draining across the box and the seconds left - all handed over untouched
  (in a fight they may be secret: nothing is compared or read). A school lockout names the school when the game says it
  plainly. Woken only by LOSS_OF_CONTROL_ADDED / _UPDATE; nothing ticks. ]]
EN.LOSS_COL = { 1.00, 0.45, 0.10, 0.85 }       -- the bar: hot orange, apart from LOS red and the cast bar's red
EN.SCHOOLS = { [1] = "PHYSICAL", [2] = "HOLY", [4] = "FIRE", [8] = "NATURE", [16] = "FROST", [32] = "SHADOW", [64] = "ARCANE" }
function EN.LossBuild(q)
    if q.loss then return q.loss end
    local L = {}
    L.bar = CreateFrame("StatusBar", nil, q)
    L.bar:SetPoint("TOPLEFT", q, "TOPLEFT", 1, -1)
    L.bar:SetPoint("BOTTOMRIGHT", q, "BOTTOMRIGHT", -1, 1)
    L.bar:SetStatusBarTexture(EN.TEX)
    local c = EN.LOSS_COL
    L.bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
    L.bar:SetMinMaxValues(0, 1)
    L.bar:SetValue(0)
    L.icon = L.bar:CreateTexture(nil, "OVERLAY")
    L.icon:SetPoint("LEFT", q, "LEFT", 2, 0)
    L.icon:SetSize(16, 16)
    if L.icon.SetTexCoord then L.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    L.word = L.bar:CreateFontString(nil, "OVERLAY")
    L.word:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    L.word:SetPoint("LEFT", L.icon, "RIGHT", 3, 0)
    L.word:SetPoint("RIGHT", q, "RIGHT", -20, 0)
    L.word:SetJustifyH("LEFT")
    local okCd, cd = pcall(CreateFrame, "Cooldown", nil, L.bar, "CooldownFrameTemplate")
    if okCd and cd then
        cd:SetPoint("TOPRIGHT", q, "TOPRIGHT", -1, -1)
        cd:SetPoint("BOTTOMRIGHT", q, "BOTTOMRIGHT", -1, 1)
        cd:SetWidth(20)
        if cd.SetDrawSwipe then cd:SetDrawSwipe(false) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
        L.cd = cd
    end
    L.bar:Hide()
    q.loss = L
    return L
end
EN.LOSS_EVERY = 0.1
--- While the box is lit without the game's timer: timeRemaining asked again, handed to the bar untouched.
function EN.LossTick(bar, elapsed)
    EN.lossLast = (EN.lossLast or 0) + (tonumber(elapsed) or 0)
    if EN.lossLast < EN.LOSS_EVERY then return end
    EN.lossLast = 0
    local LC = C_LossOfControl
    local ok, data = false, nil
    if LC and LC.GetActiveLossOfControlData then ok, data = pcall(LC.GetActiveLossOfControlData, 1) end
    if not ok or type(data) ~= "table" then bar:SetScript("OnUpdate", nil) bar:Hide() return end
    if data.timeRemaining ~= nil then pcall(bar.SetValue, bar, data.timeRemaining) end
end
local function lossOff(L)
    L.bar:SetScript("OnUpdate", nil)
    L.bar:Hide()
    if L.cd and L.cd.Clear then pcall(L.cd.Clear, L.cd) end
end
--- Paint the box from the game's first active loss of control (yours). Answers true while one shows.
function EN.LossPaint()
    local q = EN.heads and EN.heads.cc
    if not (q and q:IsShown()) then return false end
    local L = EN.LossBuild(q)
    local LC = C_LossOfControl
    local ok, data = false, nil
    if LC and LC.GetActiveLossOfControlData then ok, data = pcall(LC.GetActiveLossOfControlData, 1) end
    EN.lossSeen = ok and (type(data) == "table" and "data" or "none") or "refused"
    if not ok or type(data) ~= "table" then lossOff(L) return false end
    L.bar:Show()
    pcall(L.icon.SetTexture, L.icon, data.iconTexture)
    local word = data.displayText
    local kind, school = data.locType, data.lockoutSchool
    if not secret(kind) and kind == "SCHOOL_INTERRUPT" and not secret(school) and EN.SCHOOLS[school or 0] then
        word = EN.SCHOOLS[school] .. " LOCKED"
    end
    pcall(L.word.SetText, L.word, word)
    local obj
    if LC.GetActiveLossOfControlDuration then
        local okD, o = pcall(LC.GetActiveLossOfControlDuration, 1)
        if okD then obj = o end
    end
    local timed = false
    if obj ~= nil then
        if L.bar.SetTimerDuration and Enum and Enum.StatusBarTimerDirection then
            local interp = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
            timed = pcall(L.bar.SetTimerDuration, L.bar, obj, interp, Enum.StatusBarTimerDirection.RemainingTime)
        end
        if L.cd and L.cd.SetCooldownFromDurationObject then pcall(L.cd.SetCooldownFromDurationObject, L.cd, obj) end
    end
    EN.lossWay = timed and "timer" or nil
    if not timed then
        -- NO TIMER OBJECT (Arn, 16 Nov: "the interrupted does not have a cast bar or timer on how much is left"): the data's
        -- own numbers, handed over untouched (secret or not) - the cooldown counts the seconds from start + duration, and
        -- the bar is fed timeRemaining of duration, asked again a few times a second while the box is lit (EN.LossTick)
        local st, du, tr = data.startTime, data.duration, data.timeRemaining
        local okC = L.cd and L.cd.SetCooldown and st ~= nil and du ~= nil and pcall(L.cd.SetCooldown, L.cd, st, du)
        local okB = du ~= nil and tr ~= nil and pcall(L.bar.SetMinMaxValues, L.bar, 0, du) and pcall(L.bar.SetValue, L.bar, tr)
        if not okB then L.bar:SetMinMaxValues(0, 1) L.bar:SetValue(1) end   -- nothing to count: lit full, the words say it
        EN.lossWay = (okB and "remaining" or "none") .. (okC and "+seconds" or "")
        EN.lossLast = 0
        L.bar:SetScript("OnUpdate", okB and EN.LossTick or nil)
    else
        L.bar:SetScript("OnUpdate", nil)
    end
    return true
end
--- `/bish alpha radar cc`: what the game handed the last time (a fight shows whether its answers are hidden).
function EN.LossStatus()
    local LC = C_LossOfControl
    local okN, n = false, nil
    if LC and LC.GetActiveLossOfControlDataCount then okN, n = pcall(LC.GetActiveLossOfControlDataCount) end
    local nK = not okN and "refused" or n == nil and "nil" or secret(n) and "hidden" or tostring(n)
    local line = string.format("loss of control: api %s, count %s, last look %s, countdown %s, box %s",
        LC and "yes" or "no", nK, tostring(EN.lossSeen or "never"), tostring(EN.lossWay or "none yet"),
        tostring(EN.heads and EN.heads.cc and EN.heads.cc:IsShown() or false))
    if NS.Print then NS.Print(line) end
    return line
end

-- THE RIPTIDE BAR (16 Nov 2026; Radar.lua RD.RipCast keeps the clock). Six segments, one Chain Heal each; the bar drains
-- from the right; the LAST segment (the left end) holds the Riptide icon - dim while there is time for another Chain Heal,
-- lit with a red edge once there is not. Ticks only while a Riptide of yours stands.
EN.RIP_COL = { 0.30, 0.75, 1.00, 0.90 }
EN.RIP_EVERY = 0.1
function EN.RipBuild(q)
    if q.rip then return q.rip end
    local B = {}
    B.bar = CreateFrame("StatusBar", nil, q)
    B.bar:SetPoint("TOPLEFT", q, "TOPLEFT", 1, -1)
    B.bar:SetPoint("BOTTOMRIGHT", q, "BOTTOMRIGHT", -1, 1)
    B.bar:SetStatusBarTexture(EN.TEX)
    local c = EN.RIP_COL
    B.bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
    B.bar:SetMinMaxValues(0, 1)
    B.bar:SetValue(0)
    B.ticks = {}
    local RD = NS.RD
    local segs = (RD and RD.RIP_SEGS) or 6
    for k = 1, segs - 1 do
        local t = q:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(0, 0, 0, 0.8)
        t:SetWidth(1)
        B.ticks[k] = t
    end
    B.icon = q:CreateTexture(nil, "OVERLAY", nil, 2)
    if B.icon.SetTexCoord then B.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, (RD and RD.RIPTIDE) or "Riptide")
        if ok then pcall(B.icon.SetTexture, B.icon, t) end
    end
    B.late = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = q:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetColorTexture(1, 0.2, 0.2, 1)
        B.late[side] = t
    end
    q.rip = B
    return B
end
--- Lay the segments out on the box's size (called with every paint - the box can be narrowed).
local function ripShape(q, B)
    local RD = NS.RD
    local segs = (RD and RD.RIP_SEGS) or 6
    local w, h = q:GetWidth(), q:GetHeight()
    if type(w) ~= "number" or type(h) ~= "number" or w <= 0 then return end
    local sw = (w - 2) / segs
    for k, t in ipairs(B.ticks) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", q, "TOPLEFT", 1 + k * sw, -1)
        t:SetPoint("BOTTOMLEFT", q, "BOTTOMLEFT", 1 + k * sw, 1)
    end
    local is = math.min(sw, h - 2) - 2
    B.icon:SetSize(is, is)
    B.icon:ClearAllPoints()
    B.icon:SetPoint("CENTER", q, "LEFT", 1 + sw / 2, 0)
    local L = B.late
    local x0, x1 = 1, 1 + sw
    L.TOP:ClearAllPoints() L.TOP:SetPoint("TOPLEFT", q, "TOPLEFT", x0, -1) L.TOP:SetSize(sw, 2)
    L.BOTTOM:ClearAllPoints() L.BOTTOM:SetPoint("BOTTOMLEFT", q, "BOTTOMLEFT", x0, 1) L.BOTTOM:SetSize(sw, 2)
    L.LEFT:ClearAllPoints() L.LEFT:SetPoint("TOPLEFT", q, "TOPLEFT", x0, -1) L.LEFT:SetSize(2, h - 2)
    L.RIGHT:ClearAllPoints() L.RIGHT:SetPoint("TOPLEFT", q, "TOPLEFT", x1 - 2, -1) L.RIGHT:SetSize(2, h - 2)
end
local function ripLate(B, on) for _, t in pairs(B.late) do t:SetShown(on) end end
function EN.RipPaint()
    local q = EN.heads and EN.heads.rip
    local RD = NS.RD
    if not (q and q:IsShown() and RD) then return false end
    local B = EN.RipBuild(q)
    ripShape(q, B)
    local l = RD.ripLast
    local now = GetTime()
    local left = l and (l.untilAt - now) or 0
    if left <= 0 then
        B.bar:SetValue(0)
        B.icon:SetAlpha(0.25)
        ripLate(B, false)
        q:SetScript("OnUpdate", nil)
        if RD.RipMarks then RD.RipMarks() end
        return false
    end
    local len = RD.RipLength and RD.RipLength() or 15
    B.bar:SetMinMaxValues(0, len)
    B.bar:SetValue(left)
    local late = left < (len / ((RD.RIP_SEGS) or 6))     -- under one Chain Heal: it would be gone before it lands
    B.icon:SetAlpha(late and 1 or 0.45)
    ripLate(B, late)
    if not q.ripTicking then
        q.ripTicking, q.ripAcc = true, 0
        q:SetScript("OnUpdate", function(self, e)
            self.ripAcc = (self.ripAcc or 0) + (tonumber(e) or 0)
            if self.ripAcc < EN.RIP_EVERY then return end
            self.ripAcc = 0
            if not EN.RipPaint() then self.ripTicking = nil end
        end)
    end
    return true
end

--- `/bish alpha radar box`: the target box's own numbers - how bright each layer is, its bar's colour, what the enemy
--- check last said (Arn, 16 Nov: "the target is right next to me and its dim").
function EN.BoxStatus()
    local function num(v) if v == nil then return "nil" end if secret(v) then return "hidden" end
        return type(v) == "number" and string.format("%.2f", v) or tostring(v) end
    local sp
    for _, s in ipairs((NS.RD and NS.RD.spokes) or {}) do if s.unit == "target" then sp = s end end
    if not sp then
        local line = "target box: none placed"
        if NS.Print then NS.Print(line) end
        return line
    end
    local e = sp.en
    local r, g, b, a
    if e and e.bar and e.bar.GetStatusBarColor then r, g, b, a = e.bar:GetStatusBarColor() end
    local tex = e and e.bar and e.bar.GetStatusBarTexture and e.bar:GetStatusBarTexture()
    local ta = tex and tex.GetAlpha and tex:GetAlpha()
    local line = string.format("target box: box %s (shown %s), pip %s, plate %s, bar %s, fill %s, colour %s %s %s %s, enemy check %s, range %s",
        num(e and e.box:GetAlpha()), tostring(e and e.box:IsShown()), num(sp.heal and sp.heal:GetAlpha()),
        num(sp.deckPlate and sp.deckPlate:GetAlpha()), num(e and e.bar:GetAlpha()), num(ta), num(r), num(g), num(b), num(a),
        tostring(NS.FG and NS.FG.hostileSeen), tostring(NS.FG and NS.FG.rangeSeen))
    if NS.Print then NS.Print(line) end
    return line
end

--- `/bish alpha radar tot`: what the game said the last time ITS TARGET's class had to be looked for.
function EN.FoldStatus()
    local okC, _, tok = pcall(UnitClass, "targettarget")
    local cls = not okC and "error" or tok == nil and "none" or secret(tok) and "hidden" or tostring(tok)
    local curve = (C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean) and "yes" or "no"
    local function kind(ok, v) if not ok then return "error" end if v == nil then return "nil" end
        if secret(v) then return "hidden" end return tostring(v) end
    local okX, ex = pcall(UnitExists, "targettarget")
    local okA, foe = pcall(UnitCanAttack, "player", "targettarget")
    local okN, nm = pcall(GetUnitName, "targettarget", false)
    local nmK = not okN and "error" or nm == nil and "nil" or secret(nm) and "hidden" or "plain"
    cls = cls .. ", exists " .. kind(okX, ex) .. ", enemy " .. kind(okA, foe) .. ", name " .. nmK
    local line = string.format("its target: class now %s, curve %s, last look: %s", cls, curve,
        EN.foldSeen and (#EN.foldSeen > 0 and table.concat(EN.foldSeen, ", ") or "nobody to ask") or "not looked yet")
    if NS.Print then NS.Print(line) end
    return line
end

--- Their health into the bar, untouched, in their class colour. Answers true when painted.
function EN.Paint(sp)
    if not console() or not (sp and sp.unit) then
        if sp and sp.en then sp.en.box:Hide() end
        return false
    end
    local e = EN.Box(sp)
    if not e then return false end
    local unit = sp.unit
    local okM, mx = pcall(UnitHealthMax, unit)
    local okV, v = pcall(UnitHealth, unit)
    if okM and okV then
        pcall(e.bar.SetMinMaxValues, e.bar, 0, mx)
        pcall(e.bar.SetValue, e.bar, v)
    end
    EN.Incoming(sp, okM and mx or nil)
    local FG = NS.FG
    local cls
    if UnitClass then
        local ok, _, token = pcall(UnitClass, unit)
        if ok then cls = plain(token) end
    end
    local c = (FG and FG.CLASS_COLOR and FG.CLASS_COLOR[cls or ""]) or EN.FALLBACK
    if type(unit) == "string" and unit:find("pet", 1, true) then c = EN.PET end     -- a pet: never its owner's class
    if UnitIsDeadOrGhost then
        local okD, dead = pcall(UnitIsDeadOrGhost, unit)
        if okD and plain(dead) == true then c = (FG and FG.DEAD_COLOR) or { 0.35, 0.10, 0.10 } end
    end
    if not cls and unit == "targettarget" then
        local r, g, b = EN.FoldClass(unit, c)              -- the game hid its class: find it among the group
        pcall(e.bar.SetStatusBarColor, e.bar, r, g, b, 1)
        c = { r, g, b }                                    -- and the enemy check's "friendly" colour is that one
    else
        e.bar:SetStatusBarColor(c[1], c[2], c[3], 1)
    end
    -- AN ENEMY IS RED (Arn: "enemies in target and target of target showing up with green health bars"): only the
    -- target box's two units can be a foe; the grid's own road, a secret answer goes through the client's curve
    if (unit == "target" or unit == "targettarget") and FG and FG.PaintHostile then FG.PaintHostile(e, unit, c) end
    e.box:Show()
    return true
end

--- Heals on their way into the box's incoming bar, untouched, on their max (asked here when not handed). True = drawn.
function EN.Incoming(sp, mx)
    local e = sp and sp.en
    if not (e and sp.unit and UnitGetIncomingHeals) then return false end
    if mx == nil then
        local okM, m = pcall(UnitHealthMax, sp.unit)
        if not okM then return false end
        mx = m
    end
    local ok, v = pcall(UnitGetIncomingHeals, sp.unit)
    if not ok then return false end
    if v == nil then v = 0 end
    pcall(e.inc.SetMinMaxValues, e.inc, 0, mx)
    pcall(e.inc.SetValue, e.inc, v)
    -- the overheal is the SAME value on the same scale, filling from the other end (the grid's bargain)
    pcall(e.over.SetMinMaxValues, e.over, 0, mx)
    pcall(e.over.SetValue, e.over, v)
    return true
end

--[[ THE TARGET BOX IS NEVER DIMMED (16 Nov 2026, Arn: "the target enemy health is too dim"). The range asked is your
  HEAL's, and a heal never reaches an enemy - so your target, a mob most of the time, was greyed out as "out of range".
  ITS TARGET (a friend, mostly - the one you heal) keeps the dimming, with the grid's own hostile check (mayBeHostile:
  a plain enemy stays bright). ]]
function EN.PaintRange(sp, unit)
    local FG = NS.FG
    local box = sp and sp.en and sp.en.box
    if not (box and FG and FG.PaintRange) then return nil end
    unit = unit or sp.unit
    if unit == "target" then box:SetAlpha(1) return 1 end
    box.mayBeHostile = (unit == "targettarget") or nil
    local ok, a = pcall(FG.PaintRange, box, unit)
    return ok and a or nil
end

--- Range: the grid's own dimming on each box (the box, never the secure pip). While the console shows.
function EN.Range()
    if not console() then return 0 end
    local FG, n = NS.FG, 0
    if not (FG and FG.PaintRange) then return 0 end
    -- which spell measures range is the same for every box: asked ONCE a tick, the grid's own way (FG.tickRange)
    local mine = FG.tickRange == nil and NS.FM and NS.FM.RangeSpell
    if mine then
        local ok, spell, id = pcall(NS.FM.RangeSpell)
        FG.tickRange = ok and { spell, id } or nil
    end
    for _, sp in ipairs((NS.RD and NS.RD.spokes) or {}) do
        if sp.en and sp.unit and sp.en.box:IsShown() then
            EN.PaintRange(sp)
            n = n + 1
        end
    end
    if mine then FG.tickRange = nil end
    return n
end

--- The ghost: your heal after the heals on their way, as long as the heal is against their max (a secret, the client's sum).
--- nil heal = gone.
function EN.Ghost(sp, heal)
    -- the radar's mini bars take the same heal (MiniBars.lua): one road from Overheal.lua for both views
    if NS.MB and NS.MB.Ghost then NS.MB.Ghost(sp, heal) end
    local e = sp and sp.en
    if not e then return false end
    if not (heal and console() and sp.unit and e.box:IsShown()) then e.ghost:Hide() e.overHover:Hide() return false end
    local okM, mx = pcall(UnitHealthMax, sp.unit)
    if not okM or not pcall(e.ghost.SetMinMaxValues, e.ghost, 0, mx) then e.ghost:Hide() e.overHover:Hide() return false end
    pcall(e.ghost.SetValue, e.ghost, heal)
    e.ghost:Show()
    -- what your heal would waste on top of the heals already coming: the fainter band, on from the first one's end
    pcall(e.overHover.SetMinMaxValues, e.overHover, 0, mx)
    pcall(e.overHover.SetValue, e.overHover, heal)
    e.overHover:Show()
    return true
end

--- Into the console or back to the radar: bars or glyphs, and where the click word sits. Out of a fight (the layouts).
function EN.Layout(con)
    local RD = NS.RD
    for _, sp in ipairs((RD and RD.spokes) or {}) do
        local b = sp.heal
        if b then
            for _, face in ipairs({ b.beat, b.redFace, b.amberFace }) do
                if face then if con then face:Hide() else face:Show() end end
            end
            if sp.los then
                sp.los:ClearAllPoints()
                sp.los:SetPoint(EN.HeadSpot("los", sp))    -- the header's LOS box, the console's or the radar's alert row
            end
            if NS.OV and NS.OV.Anchor and sp.over then NS.OV.Anchor(sp) end
            if con then
                EN.Box(sp)
                EN.Size(sp)
                EN.Paint(sp)
            elseif sp.en then
                sp.en.box:Hide()
                sp.en.ghost:Hide()
                sp.en.overHover:Hide()
            end
        end
    end
    if con then EN.Range() end
    EN.HeadBoxes()                                                      -- the three boxes on the surface showing now
    -- heals on their way: heard only while the console shows (a raid's predictions cost nothing on the radar)
    if EN.events and EN.events.UnregisterEvent then
        if con then pcall(EN.events.RegisterEvent, EN.events, "UNIT_HEAL_PREDICTION")
        else EN.events:UnregisterEvent("UNIT_HEAL_PREDICTION") end
    end
end

--[[ THE FUEL STRIP ON TOP (Arn, 12 Nov: "all engineering can get a barebones mana guage on top from the rader its own
  version" - "with the bingo and mana regen 5 second rule but much smaller"). Not a second gauge: the radar's own tape
  (RD.gauge - your mana, the boss's red past it, BINGO's hot band, the magenta caret, the quarter ticks), moved onto a
  thin plate over the console and shaped to its width (RD.ShapeTape). Barebones: no placard, no scale numbers, no
  readout box riding the fill, no chevron - the regen % small at the right end with the five second rule's dashes under
  it. Every number is still painted by the radar's own functions (RD.PaintFuel); this only moves pieces, out of a fight
  (the view switch). Back on the radar everything goes home (RD.SizeGauge). ]]
EN.GAUGE = { h = 20, pad = 6, right = 44, font = 8 }

--- How far the strip reaches over the console's top (the clamp keeps it on the screen); 0 when it is not there.
function EN.GaugeTop()
    local RD = NS.RD
    if not (EN.rail and EN.rail:IsShown()) then return 0 end
    return EN.GAUGE.h + ((RD and RD.RAIL_GAP) or 2)
end

--- Into the console (true) or back to the radar: the tape moves, its extras hide or come back. Out of a fight.
function EN.Gauge(con)
    local RD = NS.RD
    local g, f = RD and RD.gauge, RD and RD.frame
    if not (g and f) then return false end
    local E, gap = EN.GAUGE, RD.RAIL_GAP or 2
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    if con and RD.Deck and RD.Deck() and RD.Sw and not RD.Sw("fuel") then   -- the fuel strip switched off
        if EN.rail then EN.rail:Hide() end
        g:Hide()
        for _, x in ipairs({ g.regen, g.fsr, g.chev, g.hud, g.readout }) do if x then x:Hide() end end
        return false
    end
    if con then
        if not EN.rail then
            local r = CreateFrame("Frame", nil, f)
            r:SetFrameLevel(math.max(0, f:GetFrameLevel()))
            r.bg = r:CreateTexture(nil, "BACKGROUND")
            r.bg:SetAllPoints(r)
            local P = RD.PLATE or { 0.05, 0.04, 0.09 }
            r.bg:SetColorTexture(P[1], P[2], P[3], 1)
            EN.rail = r
        end
        local r = EN.rail
        r:ClearAllPoints()
        r:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, gap)
        r:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, gap)
        r:SetHeight(E.h)
        r:Show()
        local fw = f:GetWidth()
        local w = (type(fw) == "number" and fw or 200) - E.pad - E.right
        g:ClearAllPoints()
        g:SetPoint("LEFT", r, "LEFT", E.pad, 0)
        RD.ShapeTape(w)
        g:Show()
        if g.hud then g.hud:Hide() end
        if g.readout then g.readout:Hide() end
        if g.chev then g.chev:Hide() end
        if g.regen then
            if g.regen.SetFont then g.regen:SetFont(font, E.font, "") end
            g.regen:ClearAllPoints()
            g.regen:SetPoint("CENTER", r, "RIGHT", -E.right / 2, 3)
            g.regen:Show()
        end
        if g.fsr then g.fsr:Show() end                       -- it hangs under the regen %, wherever that goes
    else
        -- only when coming back from the console: the radar's own sizing is left alone otherwise
        if not (EN.rail and EN.rail:IsShown()) then return false end
        EN.rail:Hide()
        if g.hud then g.hud:Show() end
        if g.readout then g.readout:Show() end
        if g.regen then
            if g.regen.SetFont then g.regen:SetFont(font, 10, "") end
            g.regen:ClearAllPoints()
            g.regen:SetPoint("CENTER", RD.gaugeRail or f, "RIGHT", -math.floor(RD.GAUGE.right / 2) - 4, 4)
        end
        -- the tape home, on the radar's rail, as wide as the radar is now (a raid's square is bigger)
        if RD.FitWide then RD.FitWide() elseif RD.SizeGauge then RD.SizeGauge(RD.SIZE) end
    end
    return true
end

-- the radar's own functions, wrapped (they are called through RD, so the wrap is what runs)
local function wrap()
    local RD = NS.RD
    if not RD or RD.__enWrapped then return end
    RD.__enWrapped = true
    local paint, conLayout, radarLayout, look = RD.PaintHeal, RD.ConsoleLayout, RD.RadarLayout, RD.Look
    if paint then RD.PaintHeal = function(sp, ...) local r = paint(sp, ...) EN.Paint(sp) return r end end
    if conLayout then
        RD.ConsoleLayout = function(...)
            local r = conLayout(...)
            if r then EN.Layout(true) end
            return r
        end
    end
    if radarLayout then
        RD.RadarLayout = function(...)
            local r = radarLayout(...)
            if r then EN.Layout(false) end
            return r
        end
    end
    if look then RD.Look = function(...) local r = look(...) EN.Range() return r end end
    -- a new ship (the group grew or shrank): the radar's alert boxes take its colours
    local ship = RD.ApplyShip
    if ship then RD.ApplyShip = function(...) local r = ship(...) EN.TintRadarHeads() return r end end
    -- the view switch: after it has hidden or shown the radar's pieces, the fuel strip moves (and the clamp follows)
    local apply = RD.ApplyView
    if apply then
        RD.ApplyView = function(...)
            local r = apply(...)
            local con = console()
            EN.Gauge(con)
            if con and RD.ClampRails then RD.ClampRails() end
            return r
        end
    end
end
wrap()

local ev = CreateFrame("Frame")
EN.events = ev
pcall(ev.RegisterEvent, ev, "UNIT_IN_RANGE_UPDATE")
pcall(ev.RegisterEvent, ev, "LOSS_OF_CONTROL_ADDED")      -- yours: the loss of control box (EN.LossPaint)
pcall(ev.RegisterEvent, ev, "LOSS_OF_CONTROL_UPDATE")
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "LOSS_OF_CONTROL_ADDED" or event == "LOSS_OF_CONTROL_UPDATE" then
        if console() then EN.LossPaint() end
        return
    end
    if not console() or secret(unit) then return end
    if event == "UNIT_HEAL_PREDICTION" then
        for _, sp in ipairs((NS.RD and NS.RD.spokes) or {}) do
            if sp.unit == unit and sp.en and sp.en.box:IsShown() then EN.Incoming(sp) end
        end
        return
    end
    if event ~= "UNIT_IN_RANGE_UPDATE" then return end
    local FG = NS.FG
    for _, sp in ipairs((NS.RD and NS.RD.spokes) or {}) do
        if sp.unit == unit and sp.en and FG and FG.PaintRange then EN.PaintRange(sp, unit) end
    end
end)
