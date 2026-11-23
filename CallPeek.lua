--[[ BiSHealing / CallPeek.lua (NS.CP) - EVERY CALL AND ITS TOTEMS, under the deck's CALL button (22 Nov 2026).

  Arn, 22 Nov: "on the bis healing if i hold shift while hovering over the call icon can you show me the 3 call buttons with what
  totems it has set up?"

  Shift held over CALL: a small panel under it, one row a Call you know - its icon, its name, the four totems standing in its places
  (fire, earth, water, air). Out of a fight a row is a button: a click drops that Call. It goes when the mouse leaves both, and when
  Shift goes up over CALL itself.

  IT NEVER TOUCHES THE HEALING: the panel is a plain frame on UIParent, placed by numbers; what can be clicked are secure buttons on a
  root of their own (also by numbers - a secure button hung on our frames would protect them), which the client itself hides in a
  fight. In a fight the panel only shows, and takes no mouse.
  WHAT STANDS IN A CALL is the game's totem bar: GetActionInfo on (GetMultiCastBarIndex() - 1) * 12 + (Call - 1) * 4 + place (read
  right on Arn's client, 22 Nov, by BiS Tools' Totems app). Read out of a fight and kept; in one an answer may be hidden. ]]
local _, NS = ...
local RD = NS.RD
if not RD then return end
local CP = {}
NS.CP = CP

CP.CALLS = { "Call of the Elements", "Call of the Ancestors", "Call of the Spirits" }
CP.PLACES = { "Fire", "Earth", "Water", "Air" }
CP.ROW, CP.ICON, CP.W, CP.PAD, CP.NAME_W = 30, 26, 204, 5, 62
CP.FONT = "Fonts\\ARIALN.TTF"
CP.LOOK = 0.1                                              -- seconds between two looks at the mouse while it is shown

for i, s in ipairs(RD.SW) do
    if s.key == "timers" then
        table.insert(RD.SW, i + 1, { key = "callpeek", group = "SHAMAN", name = "Calls on Shift",
            tip = "Hold Shift over CALL: every Call you know and the four totems set in it. Out of a fight a click drops one." })
        break
    end
end
if RD.SW_PRESETS and RD.SW_PRESETS.full then RD.SW_PRESETS.full.callpeek = true end

local function plain(v) if NS.Plain then return NS.Plain(v) end return v end
local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return plain(a), plain(b) end
end
local function combat() return InCombatLockdown and InCombatLockdown() and true or false end
local function knows(spell) local FM = NS.FM return FM and FM.Ranks and #FM.Ranks(spell) > 0 or false end
local function icon(spell) return spell and C_Spell and ask(C_Spell.GetSpellTexture, spell) or nil end
local function colour(name)
    local T = _G.BiSTheme
    if T and T.rgb then return T.rgb(name) end
    return 1, 1, 1
end
--- A totem's name as it is said: no rank, no "Totem".
local function short(name)
    return (tostring(name):gsub("%s*%(Rank %d+%)", ""):gsub("%s+Rank %d+$", ""):gsub("%s+[IVX]+$", ""):gsub(" Totem$", ""))
end

--- The spell that stands in a Call's place: its id, or nil.
function CP.Get(call, place)
    local bar = ask(GetMultiCastBarIndex)
    local kind, id = ask(GetActionInfo, ((type(bar) == "number" and bar > 0 and bar or 12) - 1) * 12 + (call - 1) * 4 + place)
    return kind == "spell" and type(id) == "number" and id > 0 and id or nil
end
--- The Calls you know: { { call, name, totems = { [place] = { id, name, icon } } }, ... }. In a fight what was read before it.
CP.kept = {}
function CP.Sets()
    local out = {}
    for i, name in ipairs(CP.CALLS) do
        if knows(name) then
            local set = { call = i, name = name, icon = icon(name), totems = {} }
            for place = 1, 4 do
                local id = CP.Get(i, place)
                local n = id and C_Spell and ask(C_Spell.GetSpellName, id)
                if id then set.totems[place] = { id = id, name = type(n) == "string" and short(n) or CP.PLACES[place], icon = icon(id) } end
            end
            if combat() and next(set.totems) == nil and CP.kept[i] then set.totems = CP.kept[i].totems end
            if not combat() then CP.kept[i] = set end
            out[#out + 1] = set
        end
    end
    return out
end

-- THE PANEL (plain) ---------------------------------------------------------------------------------------------------------

function CP.Build()
    if CP.frame then return CP.frame end
    local f = CreateFrame("Frame", "BiSHealingCallPeek", UIParent)
    CP.frame = f
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(false)
    f:Hide()
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    local r, g, b = colour("sunken")
    bg:SetColorTexture(r * 0.5, g * 0.5, b * 0.5, 0.96)
    local top = f:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT") top:SetPoint("TOPRIGHT") top:SetHeight(1)
    top:SetColorTexture(colour("accent"))
    f.rows = {}
    for i = 1, #CP.CALLS do
        local row = { tot = {} }
        local y = -CP.PAD - (i - 1) * (CP.ROW + 2)
        row.pic = f:CreateTexture(nil, "ARTWORK")
        row.pic:SetSize(CP.ICON, CP.ICON)
        row.pic:SetPoint("TOPLEFT", f, "TOPLEFT", CP.PAD, y - 2)
        row.pic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = f:CreateFontString(nil, "ARTWORK")
        row.name:SetFont(CP.FONT, 12, "")
        row.name:SetJustifyH("LEFT")
        row.name:SetPoint("LEFT", row.pic, "RIGHT", 6, 0)
        row.name:SetWidth(CP.NAME_W)
        for place = 1, 4 do
            local t = f:CreateTexture(nil, "ARTWORK")
            t:SetSize(CP.ICON, CP.ICON)
            t:SetPoint("TOPLEFT", f, "TOPLEFT", CP.PAD + CP.ICON + 6 + CP.NAME_W + (place - 1) * (CP.ICON + 2), y - 2)
            t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.tot[place] = t
        end
        f.rows[i] = row
    end
    f.code = f:CreateFontString(nil, "ARTWORK")
    f.code:SetFont(CP.FONT, 8, "")
    f.code:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 2)
    f.code:SetAlpha(0.45)
    f:SetScript("OnUpdate", function(self, dt)
        self.t = (self.t or 0) + (dt or 0)
        if self.t < CP.LOOK then return end
        self.t = 0
        if not CP.Over() then CP.Hide() end
    end)
    return f
end

-- THE BUTTONS (secure, on a root of their own) ------------------------------------------------------------------------------

function CP.Root()
    if CP.root then return CP.root end
    if combat() or CP.noRoot or type(RegisterStateDriver) ~= "function" then return nil end
    local ok, r = pcall(CreateFrame, "Frame", "BiSHealingCallPeekRoot", UIParent, "SecureHandlerStateTemplate")
    if not (ok and r) then CP.noRoot = true return nil end
    r:SetSize(1, 1)
    r:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    r:SetFrameStrata("DIALOG")
    RegisterStateDriver(r, "visibility", "[combat] hide; show")
    CP.root, CP.btn = r, {}
    for i = 1, #CP.CALLS do
        local b = CreateFrame("Button", "BiSHealingCallPeek" .. i, r, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetFrameLevel(20)
        b.wash = b:CreateTexture(nil, "HIGHLIGHT")
        b.wash:SetAllPoints(b)
        local cr, cg, cb = colour("accent")
        b.wash:SetColorTexture(cr, cg, cb, 0.22)
        b.bar = b:CreateTexture(nil, "HIGHLIGHT")
        b.bar:SetPoint("TOPLEFT") b.bar:SetPoint("BOTTOMLEFT") b.bar:SetWidth(2)
        b.bar:SetColorTexture(cr, cg, cb, 1)
        b:SetScript("OnEnter", function(self)
            if not (GameTooltip and self.tip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.tip[1])
            GameTooltip:AddLine(self.tip[2], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        b:Hide()
        CP.btn[i] = b
    end
    return r
end
--- The clicks, put over the rows (out of a fight only; n = how many rows are shown, 0 = all away).
function CP.Arm(sets)
    if combat() then CP.late = true return false end
    CP.late = nil
    if not (#sets > 0 and CP.Root()) then
        for _, b in ipairs(CP.btn or {}) do b:Hide() end
        return false
    end
    local f = CP.frame
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local left, top = f:GetLeft(), f:GetTop()
    for i, b in ipairs(CP.btn) do
        local s = sets[i]
        if s and type(left) == "number" and type(top) == "number" then
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (left + 2) * k, (top - CP.PAD - (i - 1) * (CP.ROW + 2)) * k)
            b:SetSize((CP.W - 4) * k, CP.ROW * k)
            b:SetAttribute("*type1", "macro")
            b:SetAttribute("*macrotext1", "/cast " .. s.name)
            local words = {}
            for place = 1, 4 do words[place] = CP.PLACES[place] .. ": " .. (s.totems[place] and s.totems[place].name or "nothing") end
            b.tip = { s.name, table.concat(words, "\n") .. "\nClick: drops them" }
            b:Show()
        else
            b:Hide()
        end
    end
    return true
end

-- SHOWN AND GONE ------------------------------------------------------------------------------------------------------------

function CP.On()
    return not RD.Sw or RD.Sw("callpeek") ~= false
end
local function over(f) return f and f:IsVisible() and f.IsMouseOver and ask(f.IsMouseOver, f) == true or false end
--- Is the mouse where it should be: on CALL with Shift down, or on the panel (out of a fight: there it can be clicked)?
function CP.Over()
    if over(RD.call) and ask(IsShiftKeyDown) then return true end
    return not combat() and over(CP.frame)
end
function CP.Show()
    if not (CP.On() and RD.call and RD.call:IsVisible() and over(RD.call) and ask(IsShiftKeyDown)) then return false end
    local sets = CP.Sets()
    if #sets == 0 then return false end
    local f = CP.Build()
    local k = RD.call:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local left, bottom = RD.call:GetLeft(), RD.call:GetBottom()
    if not (type(left) == "number" and type(bottom) == "number") then return false end
    f:SetScale(k)
    f:SetSize(CP.W, 2 * CP.PAD + #sets * (CP.ROW + 2) + 8)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + (RD.call:GetWidth() or 0) / 2 - CP.W / 2, bottom + 1)
    for i, row in ipairs(f.rows) do
        local s = sets[i]
        row.pic:SetShown(s ~= nil)
        row.name:SetShown(s ~= nil)
        for place = 1, 4 do row.tot[place]:SetShown(s ~= nil) end
        if s then
            row.pic:SetTexture(s.icon or 134400)
            row.name:SetText((s.name:gsub("^Call of the ", "")))
            row.name:SetTextColor(colour("ink"))
            for place = 1, 4 do
                local t = s.totems[place]
                row.tot[place]:SetTexture(t and t.icon or RD.WHITE)
                if t then row.tot[place]:SetVertexColor(1, 1, 1, 1) else local r, g, b = colour("line2") row.tot[place]:SetVertexColor(r, g, b, 0.5) end
            end
        end
    end
    f.code:SetText((NS.VERSION or "?") .. " calls " .. #sets .. (combat() and " f" or ""))
    f:EnableMouse(not combat())
    f.t = 0
    f:Show()
    if GameTooltip then GameTooltip:Hide() end
    CP.Arm(sets)
    return true
end
function CP.Hide()
    if CP.frame then CP.frame:Hide() end
    CP.Arm({})
end

--- CALL's own words, and the mouse on it: once, when there is a CALL.
function CP.Attach()
    local b = RD.call
    if not b then return false end
    if b.tip and CP.On() and not b.tip[2]:find("Shift", 1, true) then b.tip[2] = b.tip[2] .. "  Hold Shift: all your Calls and their totems." end
    if CP.hooked then return true end
    CP.hooked = true
    b:HookScript("OnEnter", function() pcall(CP.Show) end)
    return true
end
local arm = RD.ArmTotems
function RD.ArmTotems(...)
    local a = arm(...)
    pcall(CP.Attach)
    return a
end

local ev = CreateFrame("Frame")
CP.events = ev
for _, e in ipairs({ "MODIFIER_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e, key, down)
    if e == "MODIFIER_STATE_CHANGED" then
        if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
        local shown = CP.frame and CP.frame:IsShown()
        if down == 1 and not shown then pcall(CP.Show)
        elseif down == 0 and shown and not CP.Over() then pcall(CP.Hide) end
    elseif e == "PLAYER_REGEN_DISABLED" then
        if CP.frame and CP.frame:IsShown() then CP.Hide() end
    elseif CP.late then
        CP.Arm({})
    end
end)
