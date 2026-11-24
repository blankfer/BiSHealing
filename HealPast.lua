--[[
  BiSHealing / Forever :: HealPast.lua - HEAL PAST THE LINE (24 Nov 2026).

  Arn, 24 Nov: a party member carried Grievous Garrote (https://www.wowhead.com/forever/spell=1271761) and nothing showed:
  "this one is special because it say we need to heal them past a certain % ... smartly figure out to display in the
  health bar heal past this line". He picked sketch C of three (https://claude.ai/artifact/VokdMsi1w5ohZ3ooB8PFAE):

    - a white LINE on the deck box's bar at the debuff's % (Grievous Garrote: 90),
    - the GAP between their health and the line washed red (what you still owe),
    - the debuff's own ICON with the game's countdown in the box's top-right,
    - the box's EDGE pulsing amber while they are under the line, quiet once healed past it,
    - (the voice "Heal past, Thrallson" waits: the client hands the button over when the box is built, not when the
      debuff lands, so there is no honest moment to speak yet).

  WHY THE BOX NEVER SHOWED IT: the deck's cure markers ask for HARMFUL|RAID_PLAYER_DISPELLABLE - what YOU can remove.
  A bleed no class removes was never offered.

  NOTHING HERE READS AN AURA OR A HEALTH NUMBER. One AuraContainer per box holds one slot per line (`HP.DEBUFFS` grouped by
  %), filtered by spell id; the CLIENT draws the slot's button only while such a debuff is on them, and everything we draw
  hangs off that button - so it all comes and goes with the debuff. The gap is a red wash anchored to the health fill's
  end inside a clip that stops at the line (past the line it starts outside the clip: nothing). The edge and the line take
  their colour from a step curve the client evaluates on their health (UnitHealthPercent with a curve).

  UNVERIFIED LIVE: whether this client lets a slot filter a FRIENDLY debuff by spell id (solved.md 15 Oct: refused unless
  every id is NeverSecret - the probe /run Arn was given asks exactly that). A refused slot is remembered (`HP.refused`)
  and `/bish past` says so. Off by default, like every cue: BiS Cues' "Heal past the line" row turns it on.
]]
local ADDON, NS = ...
NS = NS or {}

local HP = {}
NS.HP = HP

-- THE DEBUFFS (spell id -> the health share to heal them past). Forever's own ids, read off Wowhead Forever.
HP.DEBUFFS = {
    [1271761] = { pct = 0.90, name = "Grievous Garrote" },      -- 24 Nov: bleed 1:30, 5% healing absorbed, server rule 90
}
HP.COL = {
    line = { 1, 1, 1, 0.95 },                    -- under the line: white
    past = { 0.25, 0.75, 0.37, 0.6 },            -- healed past it: faint green
    gap = { 0.90, 0.24, 0.20, 0.45 },            -- what you still owe
    edge = { 1, 0.72, 0.15, 1 },                 -- the deck's amber: close, look
}
HP.LINE_W, HP.EDGE_W = 3, 2
HP.PULSE = { 1, 0.35, 0.5 }                      -- from, to, seconds (a breath, as the deck's soft pulse)

--- On = the cue's row ticked in BiS Cues (off by default, as every cue).
function HP.On()
    local CU = NS.CU
    return CU and CU.On and CU.On("past") or false
end

--- The lines: { pct = { ids } }, one slot per distinct %.
function HP.Groups()
    local out = {}
    for id, d in pairs(HP.DEBUFFS) do
        local p = tonumber(d.pct)
        if p and p > 0 and p < 1 then
            out[p] = out[p] or {}
            out[p][id] = true
        end
    end
    return out
end

--- A step curve on their health: `below` under `p`, `above` from it (built once per p and kind).
HP.curves = {}
function HP.Curve(p, kind)
    local key = kind .. ":" .. math.floor(p * 1000 + 0.5)
    if HP.curves[key] ~= nil then return HP.curves[key] or nil end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then HP.curves[key] = false return nil end
    local ok, c = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not c or not c.AddPoint then HP.curves[key] = false return nil end
    if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then pcall(c.SetType, c, Enum.LuaCurveType.Step) end
    local below, above
    if kind == "edge" then
        local e = HP.COL.edge
        below, above = { e[1], e[2], e[3], 1 }, { e[1], e[2], e[3], 0 }
    else
        below, above = HP.COL.line, HP.COL.past
    end
    pcall(c.AddPoint, c, 0, CreateColor(below[1], below[2], below[3], below[4]))
    pcall(c.AddPoint, c, p, CreateColor(above[1], above[2], above[3], above[4]))
    HP.curves[key] = c
    return c
end

--- Hand the client's colour for this unit on curve `c` to every texture in `list` (secret r, g, b go straight in).
local function tint(list, unit, c)
    if not (c and UnitHealthPercent and list and #list > 0) then return false end
    local ok, col = pcall(UnitHealthPercent, unit, true, c)
    if not (ok and type(col) == "table") then return false end
    local getter = col.GetRGBA or col.GetRGB
    if not getter then return false end
    local okC, r, g, b, a = pcall(getter, col)
    if not okC then return false end
    for _, t in ipairs(list) do pcall(t.SetVertexColor, t, r, g, b, a or 1) end
    return true
end

--- A box's helper frames: where each line falls (an invisible frame `p` of the box's width), built once.
function HP.Base(sp)
    local EN = NS.EN
    local e = EN and EN.Box and EN.Box(sp)
    if not e then return nil end
    local h = sp.hp
    if h then return h end
    h = { marks = {}, slots = {}, lines = {}, edges = {}, e = e }
    for p in pairs(HP.Groups()) do
        local m = CreateFrame("Frame", nil, e.box)
        m:SetPoint("TOPLEFT", e.box, "TOPLEFT", 0, 0)
        m:SetPoint("BOTTOMLEFT", e.box, "BOTTOMLEFT", 0, 0)
        m:SetWidth(1)
        h.marks[p] = m
        h.lines[p], h.edges[p] = {}, {}
    end
    sp.hp = h
    HP.Size(sp)
    return h
end

--- The marks follow the box's width (the deck resizes boxes).
function HP.Size(sp)
    local h, b = sp and sp.hp, sp and sp.heal
    if not (h and b and b.GetWidth) then return end
    local w = b:GetWidth()
    if type(w) ~= "number" or w <= 2 then return end
    for p, m in pairs(h.marks) do m:SetWidth(math.max(1, (w - 2) * p)) end
    h.w = w - 2
end

--- What the client hands us when such a debuff lands on them: the line, the gap, the edge, the icon (all on its button).
function HP.Init(sp, p)
    return function(button)
        local h = sp.hp
        if not h then return end
        local e = h.e
        local CU = NS.CU
        local look = CU and CU.Look and CU.Look("past") or "icon"
        if look ~= "icon" and button.GetRegions then
            for _, r in ipairs({ button:GetRegions() }) do if r.Hide then pcall(r.Hide, r) end end
        end
        -- nothing to click on the bar (Arn's rule): the client's button only shows
        if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
        if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, false) end
        if button.EnableMouse then pcall(button.EnableMouse, button, false) end
        local mark = h.marks[p]
        local fill = e.bar.GetStatusBarTexture and e.bar:GetStatusBarTexture()
        pcall(function()
            local hold = CreateFrame("Frame", nil, button)
            hold:SetAllPoints(e.box)
            local lvl = e.bar.GetFrameLevel and e.bar:GetFrameLevel()
            if type(lvl) == "number" then hold:SetFrameLevel(lvl + 4) end
            -- the gap: a red wash from their health's end, clipped at the line
            local clip = CreateFrame("Frame", nil, hold)
            clip:SetPoint("TOPLEFT", e.box, "TOPLEFT", 0, 0)
            clip:SetPoint("BOTTOMRIGHT", mark, "BOTTOMRIGHT", 0, 0)
            if clip.SetClipsChildren then clip:SetClipsChildren(true) end
            if fill then
                local gap = clip:CreateTexture(nil, "ARTWORK")
                gap:SetColorTexture(HP.COL.gap[1], HP.COL.gap[2], HP.COL.gap[3], HP.COL.gap[4])
                gap:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
                gap:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
                gap:SetWidth(math.max(40, h.w or 200))
                h.gap = gap
            end
            -- the line
            local l = hold:CreateTexture(nil, "OVERLAY")
            l:SetTexture("Interface\\Buttons\\WHITE8X8")
            l:SetWidth(HP.LINE_W)
            l:SetPoint("TOP", mark, "TOPRIGHT", 0, 0)
            l:SetPoint("BOTTOM", mark, "BOTTOMRIGHT", 0, 0)
            l:SetVertexColor(HP.COL.line[1], HP.COL.line[2], HP.COL.line[3], HP.COL.line[4])
            table.insert(h.lines[p], l)
            -- the edge, pulsing (its colour = amber under the line, see-through past it)
            local pulse = CreateFrame("Frame", nil, hold)
            pulse:SetAllPoints(e.box)
            for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", "h" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
                                    { "TOPLEFT", "BOTTOMLEFT", "v" }, { "TOPRIGHT", "BOTTOMRIGHT", "v" } }) do
                local t = pulse:CreateTexture(nil, "OVERLAY")
                t:SetTexture("Interface\\Buttons\\WHITE8X8")
                t:SetPoint(side[1], pulse, side[1], 0, 0)
                t:SetPoint(side[2], pulse, side[2], 0, 0)
                if side[3] == "h" then t:SetHeight(HP.EDGE_W) else t:SetWidth(HP.EDGE_W) end
                t:SetVertexColor(HP.COL.edge[1], HP.COL.edge[2], HP.COL.edge[3], 0)
                table.insert(h.edges[p], t)
            end
            if pulse.CreateAnimationGroup then
                local g = pulse:CreateAnimationGroup()
                local a = g:CreateAnimation("Alpha")
                a:SetFromAlpha(HP.PULSE[1]) a:SetToAlpha(HP.PULSE[2]) a:SetDuration(HP.PULSE[3])
                g:SetLooping("BOUNCE")
                g:Play()
            end
            if look ~= "icon" then
                local w = hold:CreateFontString(nil, "OVERLAY")
                if w.SetFont then w:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE") end
                w:SetPoint("BOTTOM", l, "TOP", 0, 1)
                w:SetText(tostring(math.floor(p * 100 + 0.5)))
            end
        end)
        HP.Tint(sp)
        -- (NO VOICE HERE: the client makes this button when the box is built, not when the debuff lands - Burn.lua's
        -- Hellfire spoke on every /reload that way. The voice waits for a "shown" signal of its own.)
    end
end

--- The box's container for its unit, made once per box and told who to watch after.
function HP.Arm(sp)
    local FA = NS.FA
    if not (FA and FA.Available and FA.Available() and FA.AddSlot) then return false end
    local h = HP.Base(sp)
    if not h then return false end
    if h.container then
        if h.unit ~= sp.unit then
            pcall(h.container.SetUnit, h.container, sp.unit)
            h.unit = sp.unit
        end
        if h.container.SetEnabled then pcall(h.container.SetEnabled, h.container, true) end
        return true
    end
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, h.e.box, "CustomAuraContainerTemplate")
    if not (ok and c) then return false end
    c:SetSize(1, 1)
    c:SetPoint("CENTER", h.e.box, "CENTER")
    c:SetUnit(sp.unit)
    h.container, h.unit = c, sp.unit
    local px = 16
    if NS.RD and NS.RD.IconPx then
        local okP, v = pcall(NS.RD.IconPx, sp.heal and sp.heal.GetWidth and sp.heal:GetWidth() or 60)
        if okP and type(v) == "number" then px = math.max(12, math.min(22, v)) end
    end
    for p, ids in pairs(HP.Groups()) do
        local slot = FA.AddSlot(c, "BiSHealPast" .. tostring(sp.i or "") .. "_" .. math.floor(p * 100), "HARMFUL", {
            candidateFilters = { includeSpellIDs = ids },
            initializeFrame = FA.Placed(HP.Init(sp, p), px, "TOPRIGHT", h.e.box, -2, -2),
        })
        h.slots[p] = slot
        if not slot then HP.refused = true end
    end
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
    if c.UpdateAllAuras then pcall(c.UpdateAllAuras, c) end
    return true
end

--- The edge and the line by their health (the client's curve).
function HP.Tint(sp)
    local h = sp and sp.hp
    if not (h and sp.unit) then return end
    for p, list in pairs(h.edges) do
        if #list > 0 then tint(list, sp.unit, HP.Curve(p, "edge")) end
    end
    for p, list in pairs(h.lines) do
        if #list > 0 then tint(list, sp.unit, HP.Curve(p, "line")) end
    end
end

--- With every repaint of a deck box: armed while the cue is on, put away when it is off.
function HP.Paint(sp, shown)
    if not sp then return end
    if not (shown and sp.unit and HP.On()) then
        local h = sp.hp
        if h and h.container and h.container.SetEnabled then pcall(h.container.SetEnabled, h.container, false) end
        return
    end
    if HP.Arm(sp) then HP.Tint(sp) end
end

--- `/bish past`: what it watches and whether the client took the filter.
function HP.Status()
    local n = 0
    for _ in pairs(HP.DEBUFFS) do n = n + 1 end
    local boxes = 0
    for _, sp in ipairs((NS.RD and NS.RD.spokes) or {}) do if sp.hp and sp.hp.container then boxes = boxes + 1 end end
    return ("heal past the line: %s, %d debuff%s watched, %d box%s armed%s"):format(HP.On() and "ON" or "off (tick it in BiS Cues)",
        n, n == 1 and "" or "s", boxes, boxes == 1 and "" or "es",
        HP.refused and " - the client REFUSED the spell-id filter (it hides this debuff in a fight)" or "")
end

-- ride on the deck's own repaints (Engineer.lua's box), never a ticker of our own
do
    local EN = NS.EN
    if EN and not EN.__hpWrapped then
        EN.__hpWrapped = true
        local paint, size = EN.Paint, EN.Size
        if paint then EN.Paint = function(sp, ...) local r = paint(sp, ...) HP.Paint(sp, r) return r end end
        if size then EN.Size = function(sp, ...) local r = size(sp, ...) HP.Size(sp) return r end end
    end
end
