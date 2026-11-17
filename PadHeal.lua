--[[
  BiSHealing :: PadHeal.lua (NS.PH) - HEALING WITH A CONTROLLER, option A: step through the party.

  Arn, 15 Nov 2026 (picked A of three sketches, https://claude.ai/artifact/8ymA6qnqpLa82V7Yat5R9q - "A now, C later"):
  his cousin plays on a controller. The game's own pad cursor never draws on Forever (the game stays in keyboard/mouse
  style; Test-Pad, 15 Nov), so a pad player cannot hover a cell. Instead ONE person is lit by a magenta bracket:
    D-pad up / down       the next / previous person (empty slots skipped)
    D-pad left / right    a whole group back / on (5 places)
    A  B  X  Y            your left / right / middle / thumb (Button4) bind on whoever is lit - the SAME binds the bind
                          window sets, because the press IS a click on that cell (macros, hostile binds, res, Clique all
                          ride along). With a modifier held (the game's pad emulates shift on LT) the shift bind goes.
  The bracket stays where it is, so A A A keeps healing the same person.

  IN A FIGHT: picking who is lit runs in the game's secure snippets (PH.NAV, on SecureHandlerClickTemplate buttons the
  D-pad is bound to), which may rebind A/B/X/Y to the newly lit cell mid-fight (SetBindingClick on the header). The list of
  cells (frame refs "cell1".."cellN") is written out of a fight only (PH.Arm, from FM.ApplyWheel = every layout and every
  bind change, and after a fight / a roster change). The bracket is a plain frame moved from the header's
  OnAttributeChanged (insecure code may anchor a plain frame to a protected one).

  The sticks are never ours (Test-Pad: the character walks while a frame holds them). Off by default: `padHeal`, the
  options row "heal with a controller", /bish pad on|off.
  Untested live: the snippet's UnitExists, SetBindingClick with a frame handle, LT as shift on a bound pad key.
]]
local ADDON, NS = ...

local PH = {}
NS.PH = PH

PH.NAVKEYS = { { key = "PADDUP", step = -1 }, { key = "PADDDOWN", step = 1 },
               { key = "PADDLEFT", step = -5 }, { key = "PADDRIGHT", step = 5 } }
PH.FACE = { { "PAD1", "LeftButton" }, { "PAD2", "RightButton" }, { "PAD3", "MiddleButton" }, { "PAD4", "Button4" } }
PH.MODS = { "", "SHIFT-", "CTRL-", "ALT-" }
PH.COL = { 1.0, 0.31, 0.72 }                  -- the cockpit's magenta (chosen)
PH.ARM, PH.THICK, PH.OUT = 12, 3, 4             -- the bracket's corner length, thickness, how far outside the cell

local function db() return NS.DB and NS.DB() or {} end

function PH.On() return db().padHeal == true end

--- A frame reference the secure snippet can read (GetFrameRef): the census lists the global SecureHandlerSetFrameRef,
--- not the frame method.
function PH.SetRef(f, label, ref)
    if SecureHandlerSetFrameRef then SecureHandlerSetFrameRef(f, label, ref) return true end
    return false
end

-- the snippet a D-pad press runs (restricted Lua, the game's secure environment): step `step` places, skip a slot with
-- nobody in it, wrap round, and hand A/B/X/Y to the lit cell
PH.NAV = [[
    local H = self:GetFrameRef("header")
    local n = H:GetAttribute("n") or 0
    if n == 0 then return end
    local step = self:GetAttribute("step") or 1
    local dir = step > 0 and 1 or -1
    local sel = H:GetAttribute("sel") or 0
    local i
    if sel == 0 then i = dir > 0 and 1 or n else i = sel + step end
    local found = 0
    for t = 1, n do
        i = ((i - 1) % n) + 1
        local c = H:GetFrameRef("cell" .. i)
        local u = c and c:GetAttribute("unit")
        if u and UnitExists(u) then found = i break end
        i = i + dir
    end
    if found == 0 then return end
    H:SetAttribute("sel", found)
    local c = H:GetFrameRef("cell" .. found)
    local nk = H:GetAttribute("nk") or 0
    for k = 1, nk do
        H:SetBindingClick(true, H:GetAttribute("key" .. k), c, H:GetAttribute("btn" .. k))
    end
]]

--- The cells a press can light, in order: the radar's heal pips while the radar is the look, else the grid's cells.
function PH.List()
    local list = {}
    local RD, FG = NS.RD, NS.FG
    if RD and RD.On and RD.On() and RD.spokes then
        for i = 1, #RD.spokes do
            local sp = RD.spokes[i]
            if sp and sp.heal and sp.heal.GetName and sp.heal:GetName() then list[#list + 1] = sp.heal end
        end
    elseif FG and FG.frames then
        for i = 1, #FG.frames do
            local f = FG.frames[i]
            if f and f.GetName and f:GetName() and f:GetAttribute("unit") then list[#list + 1] = f end
        end
    end
    return list
end

local function build()
    if PH.header then return PH.header end
    local H = CreateFrame("Frame", "BiSHealingPadHeader", UIParent, "SecureHandlerBaseTemplate")
    PH.header = H
    PH.nav = {}
    for i, k in ipairs(PH.NAVKEYS) do
        local b = CreateFrame("Button", "BiSHealingPadNav" .. i, UIParent, "SecureHandlerClickTemplate")
        b:SetAttribute("step", k.step)
        PH.SetRef(b, "header", H)
        b:SetAttribute("_onclick", PH.NAV)
        if b.RegisterForClicks then b:RegisterForClicks("AnyDown") end
        PH.nav[i] = b
    end
    -- the bracket: four L corners round the lit cell, a plain frame
    local g = CreateFrame("Frame", nil, UIParent)
    g:SetFrameStrata("HIGH")
    g:Hide()
    g.bits = {}
    local function bit() local t = g:CreateTexture(nil, "OVERLAY") t:SetColorTexture(PH.COL[1], PH.COL[2], PH.COL[3], 1) g.bits[#g.bits + 1] = t return t end
    for _, c in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
        local h, v = bit(), bit()
        h:SetSize(PH.ARM, PH.THICK) h:SetPoint(c[1], g, c[1], 0, 0)
        v:SetSize(PH.THICK, PH.ARM) v:SetPoint(c[1], g, c[1], 0, 0)
    end
    PH.glow = g
    H:HookScript("OnAttributeChanged", function(_, name) if name == "sel" then PH.Paint() end end)
    return H
end

--- Move the bracket onto whoever is lit (or hide it).
function PH.Paint()
    local g, H = PH.glow, PH.header
    if not (g and H) then return false end
    local i = tonumber(H:GetAttribute("sel")) or 0
    local c = PH.cells and PH.cells[i]
    if not (PH.On() and c) then g:Hide() return false end
    g:ClearAllPoints()
    g:SetPoint("TOPLEFT", c, "TOPLEFT", -PH.OUT, PH.OUT)
    g:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", PH.OUT, -PH.OUT)
    g:Show()
    return true
end

--- Write the list and the keys (out of a fight only; queued otherwise).
function PH.Arm()
    if InCombatLockdown and InCombatLockdown() then PH.pending = true return false end
    PH.pending = nil
    if not PH.On() then
        if PH.header then
            if ClearOverrideBindings then ClearOverrideBindings(PH.header) end
            PH.header:SetAttribute("n", 0)
            PH.header:SetAttribute("sel", 0)
            PH.cells = {}
            PH.Paint()
        end
        return false
    end
    local H = build()
    if ClearOverrideBindings then ClearOverrideBindings(H) end
    local wasCell = PH.cells and PH.cells[tonumber(H:GetAttribute("sel")) or 0]
    local list = PH.List()
    PH.cells = list
    local sel = 0
    for i, c in ipairs(list) do
        PH.SetRef(H, "cell" .. i, c)
        if c == wasCell then sel = i end
    end
    H:SetAttribute("n", #list)
    local nk = 0
    for _, m in ipairs(PH.MODS) do
        for _, fb in ipairs(PH.FACE) do
            nk = nk + 1
            H:SetAttribute("key" .. nk, m .. fb[1])
            H:SetAttribute("btn" .. nk, fb[2])
        end
    end
    H:SetAttribute("nk", nk)
    for i, k in ipairs(PH.NAVKEYS) do
        for _, m in ipairs(PH.MODS) do
            SetOverrideBindingClick(H, true, m .. k.key, PH.nav[i]:GetName(), "LeftButton")
        end
    end
    -- whoever was lit stays lit (a new layout keeps the bracket on the same cell when it is still there)
    if sel > 0 then
        for k = 1, nk do SetOverrideBindingClick(H, true, H:GetAttribute("key" .. k), list[sel]:GetName(), H:GetAttribute("btn" .. k)) end
    end
    H:SetAttribute("sel", sel)
    PH.Paint()
    return true, #list
end

-- after a fight (a queued arm), and when the group changes (out of a fight)
local ev = CreateFrame("Frame")
PH.events = ev
pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
pcall(ev.RegisterEvent, ev, "GROUP_ROSTER_UPDATE")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if PH.pending then PH.Arm() end
    elseif PH.On() then
        PH.Arm()
    end
end)
