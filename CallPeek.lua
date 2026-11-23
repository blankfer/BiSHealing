--[[ BiSHealing / CallPeek.lua (NS.CP) - EVERY CALL AND ITS TOTEMS, under the deck's CALL button (22 Nov 2026).

  Arn, 22 Nov: "on the bis healing if i hold shift while hovering over the call icon can you show me the 3 call buttons with what
  totems it has set up?"

  Shift held over CALL: a small panel under it, one row a Call you know - its icon, its name, the four totems standing in its places
  (fire, earth, water, air), read each time it opens. Out of a fight a press on a row CHOOSES it: CALL drops that one from then on
  (left-click; right-click = the one it took the place of), its own icon on the button, kept. It goes when the mouse leaves both, and
  when Shift goes up over CALL itself. BiS Tools' BiS>totems can choose it too (BiSHealingAPI.SetCall, version 4).

  IT NEVER TOUCHES THE HEALING: the panel and its rows are plain frames on UIParent, placed by numbers; nothing in it is secure. The
  only secure button is CALL itself, whose click is written where it always was (RD.ArmTotems), out of a fight. In a fight the panel
  only shows, and takes no mouse.
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
            tip = "Hold Shift over CALL: every Call you know and the four totems set in it. Out of a fight a click chooses the one CALL drops." })
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

-- THE ROWS AS BUTTONS (plain: a press chooses, CALL itself casts) -----------------------------------------------------------

function CP.Button(i)
    local f = CP.frame
    local b = f.rows[i].btn
    if b then return b end
    b = CreateFrame("Button", nil, f)
    f.rows[i].btn = b
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -CP.PAD - (i - 1) * (CP.ROW + 2))
    b:SetSize(CP.W - 4, CP.ROW)
    b:RegisterForClicks("LeftButtonUp")
    local r, g, bl = colour("accent")
    b.wash = b:CreateTexture(nil, "HIGHLIGHT")
    b.wash:SetAllPoints(b)
    b.wash:SetColorTexture(r, g, bl, 0.22)
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetPoint("TOPLEFT") b.bar:SetPoint("BOTTOMLEFT") b.bar:SetWidth(2)
    b:SetScript("OnEnter", function(self)
        if not (GameTooltip and self.tip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.tip[1])
        GameTooltip:AddLine(self.tip[2], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnClick", function(self)
        if combat() or not self.call then return end
        CP.Choose(self.call)
        CP.Show(true)
    end)
    return b
end

-- WHICH CALL THE BUTTON DROPS (Arn, 22 Nov: "when i select one that call button now uses that one not elements as default") ----

local function saved()
    local d = NS.DB and NS.DB()
    if type(d) ~= "table" then return nil end
    d.radar = type(d.radar) == "table" and d.radar or {}
    return d.radar
end
--- The chosen Call's name, if you (still) know it.
function CP.Chosen()
    local r = saved()
    local c = r and r.callNow
    for _, name in ipairs(CP.CALLS) do if name == c and knows(name) then return name end end
    return nil
end
--- Choose one (nil = the old way: Elements, right-click Ancestors). Out of a fight only: a click's spell cannot change in one.
function CP.Choose(name)
    local r = saved()
    if not r or combat() then return nil, "in a fight" end
    local known = name == nil
    for _, n in ipairs(CP.CALLS) do known = known or (n == name and knows(n)) end
    if not known then return nil, "not known" end
    r.callNow = name
    RD.ArmTotems()
    if RD.PaintTotems then RD.PaintTotems() end
    return true
end
--- CALL with the chosen one: left = it, right = the one it took the place of. (After RD.ArmTotems; out of a fight.)
function CP.Dress()
    local b, c = RD.call, CP.Chosen()
    if combat() or not (b and c and b.macro) then return false end
    local first = knows(RD.CALLS[1]) and RD.CALLS[1] or nil
    local second = knows(RD.CALLS[2]) and RD.CALLS[2] or nil
    local other = c ~= first and first or second or c
    b:SetAttribute("*macrotext1", "/cast " .. c)
    b:SetAttribute("*macrotext2", "/cast " .. other)
    b.macro, b.spell = "/cast " .. c, c
    RD.SpellIcon(b, c)
    b.tip = { "CALL", c .. (other ~= c and ("  -  right-click: " .. other) or "") .. ".  Lights before the pull while none of your totems are down." }
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
function CP.Show(stay)
    if not (CP.On() and RD.call and RD.call:IsVisible()) then return false end
    if not stay and not (over(RD.call) and ask(IsShiftKeyDown)) then return false end
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
    local now = CP.Chosen() or (RD.call.spell)
    for i = 1, #f.rows do
        local set = sets[i]
        local b = CP.Button(i)
        b.call = set and set.name or nil
        if set then
            local is = set.name == now
            local words = {}
            for place = 1, 4 do words[place] = CP.PLACES[place] .. ": " .. (set.totems[place] and set.totems[place].name or "nothing") end
            b.tip = { set.name, table.concat(words, "\n") .. (is and "\nCALL drops this one" or "\nClick: CALL drops this one from now on") }
            local r, g, bl = colour("gold")
            b.bar:SetColorTexture(r, g, bl, is and 1 or 0)
            f.rows[i].name:SetTextColor(colour(is and "gold" or "ink"))
        end
        b:SetShown(set ~= nil)
        b:EnableMouse(set ~= nil and not combat())
    end
    return true
end
function CP.Hide() if CP.frame then CP.frame:Hide() end end

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
    pcall(CP.Dress)
    pcall(CP.Attach)
    return a
end
-- (a third Call counts as a Call for the totem clock too)
if not RD.CALLS[3] then RD.CALLS[3] = CP.CALLS[3] end

local ev = CreateFrame("Frame")
CP.events = ev
for _, e in ipairs({ "MODIFIER_STATE_CHANGED", "PLAYER_REGEN_DISABLED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e, key, down)
    if e == "MODIFIER_STATE_CHANGED" then
        if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
        local shown = CP.frame and CP.frame:IsShown()
        if down == 1 and not shown then pcall(CP.Show)
        elseif down == 0 and shown and not CP.Over() then pcall(CP.Hide) end
    elseif CP.frame and CP.frame:IsShown() then
        CP.Hide()
    end
end)
