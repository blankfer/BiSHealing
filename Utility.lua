-- BiSHealing / Utility.lua -- THE UTILITY DECK (18 Nov 2026).
--
-- Arn, 18 Nov 2026: "Utility: it will smartly see what class they are and build the deck that way. Druids: Innervate ...
-- we build out the deck - a druid that provides Innervate will see all classes that need Innervate, mages, healers etc.,
-- 3D face models built out of combat, if he clicks them it casts Innervate on them. Mages will see an Innervate button and
-- a Mana Tide button if they have a shaman in their party. They click the button and the addon asks the druids for an
-- Innervate and it lights up the mage face so they can click on it; shamans: when a mage clicks the Mana Tide button the
-- shaman sees their Mana Tide button light up." Sketches https://claude.ai/artifact/PoSKQvbpSJh8CpcqT6PXb9 - he picked
-- the druid's view as a TOGGLE (faces or boxes) and the mage's two big ask buttons.
--
-- The asking is LibBiSComm's (minor 17, MOD IN: docs/bisin.md in bisdev): lib:BisInSet / BisInMe / BisInReady /
-- BisInAskers / BisInRequests / BisInAsk / BisInClaim / BisInCancel, its "BISIN" callback. This file is the window:
--   GIVE  (a spell I give, targeted - Innervate, Power Infusion): one face per mana user who opted in to ask, a SECURE
--         button pre-aimed at their unit out of a fight (type spell, unit); it lights (alpha - allowed in a fight) while
--         they ask; the click claims their ask first (PreClick) and casts. Faces = 3D portraits (PlayerModel:SetUnit,
--         built out of a fight), boxes = the deck's box shape (2D portrait, name, mana). UT.Mode() / /bish utility faces.
--   TIDE  (I give Mana Tide - untargeted): one secure button, lit gold with who asked.
--   ASK   (I ask - a mana class): one big button per spell somebody in the group gives: "2 ready", "all on cooldown
--         1:40", then "asked - X is answering"; a click asks (a plain message - live in a fight), again takes it back.
-- Secure parts are written out of a fight only (UT.pending -> PLAYER_REGEN_ENABLED). Per character: BiSHealingCharDB
-- .utility (shown), .utilityMode ("faces" | "boxes"), .utilityPos. Nothing ticks while it is hidden.
local _, NS = ...
local UT = {}
NS.UT = UT

local function L() return rawget(_G, "LibBiSComm") end
local function char()
    BiSHealingCharDB = type(BiSHealingCharDB) == "table" and BiSHealingCharDB or {}
    return BiSHealingCharDB
end
local function combat() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function plain(v) if v == nil or (NS.Secret and NS.Secret(v)) then return nil end return v end

UT.COL = { plate = { 0.09, 0.08, 0.165 }, panel = { 0.12, 0.106, 0.21 }, line = { 0.2, 0.17, 0.33 }, accent = { 0.725, 0.5, 1 },
           teal = { 0.31, 0.82, 0.81 }, gold = { 0.9, 0.75, 0.29 }, muted = { 0.6, 0.57, 0.72 }, ink = { 0.93, 0.91, 0.96 },
           mana = { 0.24, 0.48, 1 } }
UT.SPELL = { innervate = "Innervate", pi = "Power Infusion", tide = "Mana Tide Totem" }
UT.WORD = { innervate = "INNERVATE", pi = "POWER INFUSION", tide = "MANA TIDE" }
UT.ICON = { innervate = "Interface\\Icons\\Spell_Nature_Lightning", pi = "Interface\\Icons\\Spell_Holy_PowerInfusion",
            tide = "Interface\\Icons\\Spell_Frost_SummonWaterElemental" }
UT.W, UT.FACE, UT.BOX_H, UT.ASK_H, UT.PAD = 300, 54, 40, 44, 10
UT.REPAINT = 1                                      -- seconds between the asker's "ready / cooldown" words while shown

function UT.Shown() return char().utility == true end
--- THE CLASS FILTER (a giver's own): classes whose faces are left off (/bish utility hide MAGE - again shows them).
function UT.Hidden(class)
    local h = char().utilityHide
    return type(h) == "table" and class ~= nil and h[class] == true
end
function UT.SetHidden(class, hide)
    class = type(class) == "string" and class:upper() or nil
    if not class or class == "" then return nil end
    local c = char()
    c.utilityHide = type(c.utilityHide) == "table" and c.utilityHide or {}
    if hide == nil then hide = not c.utilityHide[class] end
    c.utilityHide[class] = hide and true or nil
    UT.Layout()
    return hide and true or false
end
--- Mana only: a druid in cat or bear form (no mana bar up) dims - Innervate does nothing for them right now.
function UT.OnMana(unit)
    local ok, t = pcall(UnitPowerType, unit)
    t = ok and plain(t) or nil
    return t == nil or t == 0
end
function UT.Mode() return char().utilityMode == "boxes" and "boxes" or "faces" end

local function tex(parent, layer, col, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(col[1], col[2], col[3], a or 1)
    return t
end
local function fs(parent, size, col, font)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont(font or "Fonts\\ARIALN.TTF", size or 12, "")
    f:SetTextColor(col[1], col[2], col[3], 1)
    return f
end
local function edge(f, col)
    local t = {}
    for i = 1, 4 do t[i] = tex(f, "BORDER", col, 1) end
    t[1]:SetPoint("TOPLEFT") t[1]:SetPoint("TOPRIGHT") t[1]:SetHeight(1)
    t[2]:SetPoint("BOTTOMLEFT") t[2]:SetPoint("BOTTOMRIGHT") t[2]:SetHeight(1)
    t[3]:SetPoint("TOPLEFT") t[3]:SetPoint("BOTTOMLEFT") t[3]:SetWidth(1)
    t[4]:SetPoint("TOPRIGHT") t[4]:SetPoint("BOTTOMRIGHT") t[4]:SetWidth(1)
    f.edges = t
    return t
end
local function edgeColor(f, col, a) for _, t in ipairs(f.edges or {}) do t:SetColorTexture(col[1], col[2], col[3], a or 1) end end

--- The group unit a name is (party / raid / me), or nil.
function UT.UnitOf(name)
    local lib = L()
    local full = lib and lib.FullName
    if not (full and name) then return nil end
    if full("player") == name then return "player" end
    local raid = IsInRaid and IsInRaid()
    local n = raid and ((GetNumGroupMembers and GetNumGroupMembers()) or 0) or 4
    for i = 1, n do
        local u = (raid and "raid" or "party") .. i
        local ok, there = pcall(UnitExists, u)
        if ok and plain(there) and full(u) == name then return u end
    end
    return nil
end

--- What I do: { give = { innervate = true, ... }, ask = bool, class }, from the lib (nil when it is not there).
function UT.Me()
    local lib = L()
    if not (lib and lib.BisInMe) then return nil end
    local ok, me = pcall(lib.BisInMe, lib)
    return ok and me or nil
end

------------------------------------------------------------------------------------------------ the window
function UT.Build()
    if UT.frame then return UT.frame end
    local C = UT.COL
    local f = CreateFrame("Frame", "BiSHealingUtility", UIParent)
    f:SetSize(UT.W, 120)
    local p = char().utilityPos
    if type(p) == "table" and p[1] then f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    else f:SetPoint("CENTER", UIParent, "CENTER", 320, -80) end
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not combat() then self:StartMoving() self.moving = true end end)
    local function stop(self)
        if not self.moving then return end
        self.moving = nil
        self:StopMovingOrSizing()
        local ok, pt, _, rp, x, y = pcall(self.GetPoint, self)
        if ok and pt then char().utilityPos = { pt, rp, x, y } end
    end
    f:SetScript("OnDragStop", stop)
    f:SetScript("OnHide", stop)
    f.bg = tex(f, "BACKGROUND", C.plate, 0.96)
    f.bg:SetAllPoints(f)
    edge(f, C.line)
    f.title = fs(f, 12, C.accent, "Fonts\\FRIZQT__.TTF")
    f.title:SetPoint("TOPLEFT", UT.PAD, -8)
    f.title:SetText("BiS> utility")
    f.mode = CreateFrame("Button", nil, f)                -- the faces / boxes toggle (a giver's)
    f.mode:SetSize(54, 16)
    f.mode:SetPoint("TOPRIGHT", -26, -6)
    f.mode.bg = tex(f.mode, "BACKGROUND", C.panel, 1) f.mode.bg:SetAllPoints(f.mode)
    edge(f.mode, C.line)
    f.mode.label = fs(f.mode, 10, C.teal) f.mode.label:SetPoint("CENTER")
    f.mode:SetScript("OnClick", function() UT.SetMode(UT.Mode() == "faces" and "boxes" or "faces") end)
    f.close = CreateFrame("Button", nil, f)
    f.close:SetSize(16, 16)
    f.close:SetPoint("TOPRIGHT", -6, -6)
    f.close.label = fs(f.close, 12, C.muted) f.close.label:SetPoint("CENTER") f.close.label:SetText("x")
    f.close:SetScript("OnClick", function() UT.SetShown(false) end)
    f.head = fs(f, 11, C.muted)                           -- the giver's spell and its readiness
    f.empty = fs(f, 11, C.muted)
    f.empty:SetWidth(UT.W - 2 * UT.PAD)
    f.empty:SetJustifyH("LEFT")
    f.faces, f.asks = {}, {}
    f:SetScript("OnUpdate", function(self, e)
        self.acc = (self.acc or 0) + (tonumber(e) or 0)
        if self.acc >= UT.REPAINT then self.acc = 0 UT.Paint() end
    end)
    f:Hide()
    UT.frame = f
    return f
end

--- One face (or box): a SECURE button pre-aimed at a unit, its picture, name, mana bar, the ASKING word.
function UT.Face(i)
    local f = UT.Build()
    local b = f.faces[i]
    if b then return b end
    local C = UT.COL
    b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    if b.RegisterForClicks then b:RegisterForClicks("AnyDown") end
    b:SetAttribute("type", "spell")
    b.bg = tex(b, "BACKGROUND", C.panel, 1) b.bg:SetAllPoints(b)
    edge(b, C.line)
    local okM, m = pcall(CreateFrame, "PlayerModel", nil, b)      -- the 3D face (faces mode)
    if okM and m then b.model = m end
    b.pic = b:CreateTexture(nil, "ARTWORK")                     -- the 2D portrait (boxes mode)
    b.name = fs(b, 10, C.ink)
    b.mana = CreateFrame("StatusBar", nil, b)
    b.mana:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    b.mana:SetStatusBarColor(C.mana[1], C.mana[2], C.mana[3], 1)
    b.mana.bg = tex(b.mana, "BACKGROUND", { 0, 0, 0 }, 0.8) b.mana.bg:SetAllPoints(b.mana)
    b.ask = fs(b, 9, C.gold)
    b.ask:SetText("ASKING")
    -- the click claims their ask first (the first claim wins everywhere - two druids never both cast), then casts
    b:SetScript("PreClick", function(self)
        local lib = L()
        if self.req and lib and lib.BisInClaim then pcall(lib.BisInClaim, lib, self.req) end
    end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.who or "?", 1, 1, 1)
        GameTooltip:AddLine((self.req and "asking - " or "") .. "click: " .. (UT.SPELL[self.spell] or "?") .. " on them", 0.9, 0.75, 0.29)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f.faces[i] = b
    return b
end

--- One big ask button (a plain button: asking is a message, live in a fight), or the shaman's secure Mana Tide.
function UT.AskButton(i)
    local f = UT.Build()
    local b = f.asks[i]
    if b then return b end
    local C = UT.COL
    b = CreateFrame("Button", nil, f)
    b.bg = tex(b, "BACKGROUND", C.panel, 1) b.bg:SetAllPoints(b)
    edge(b, C.line)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(UT.ASK_H - 10, UT.ASK_H - 10)
    b.icon:SetPoint("LEFT", 5, 0)
    if b.icon.SetTexCoord then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    b.word = fs(b, 13, C.ink, "Fonts\\FRIZQT__.TTF")
    b.word:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, -2)
    b.say = fs(b, 11, C.muted)
    b.say:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, 2)
    b:SetScript("OnClick", function(self) UT.AskClick(self.spell) end)
    f.asks[i] = b
    return b
end
function UT.TideButton()
    local f = UT.Build()
    if f.tide then return f.tide end
    local C = UT.COL
    local b = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    if b.RegisterForClicks then b:RegisterForClicks("AnyDown") end
    b:SetAttribute("type", "spell")
    b:SetAttribute("spell", UT.SPELL.tide)
    b.bg = tex(b, "BACKGROUND", C.panel, 1) b.bg:SetAllPoints(b)
    edge(b, C.line)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(UT.ASK_H - 10, UT.ASK_H - 10)
    b.icon:SetPoint("LEFT", 5, 0)
    b.icon:SetTexture(UT.ICON.tide)
    b.word = fs(b, 13, C.ink, "Fonts\\FRIZQT__.TTF")
    b.word:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, -2)
    b.word:SetText("MANA TIDE")
    b.say = fs(b, 11, C.muted)
    b.say:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, 2)
    b:SetScript("PreClick", function(self)
        local lib = L()
        if self.req and lib and lib.BisInClaim then pcall(lib.BisInClaim, lib, self.req) end
    end)
    f.tide = b
    return b
end

------------------------------------------------------------------------------------------------ laying it out (out of a fight)
--- What the window holds now: the spell I give targeted (with its askers), Mana Tide if I give it, and what I ask.
function UT.Plan()
    local lib, me = L(), UT.Me()
    local plan = { give = nil, askers = {}, tide = false, asks = {} }
    if not (lib and me and me.on) then return plan end
    for _, k in ipairs(lib.BISIN_ORDER or {}) do
        if me.give[k] then
            if k == "tide" then plan.tide = true
            elseif not plan.give then plan.give = k end
        end
    end
    if plan.give then
        local ok, list = pcall(lib.BisInAskers, lib)
        for _, a in ipairs(ok and list or {}) do
            local u = UT.UnitOf(a.name)
            if u and u ~= "player" and not UT.Hidden(a.class) then
                plan.askers[#plan.askers + 1] = { name = a.name, class = a.class, unit = u }
            end
        end
    end
    if me.ask then
        for _, k in ipairs(lib.BISIN_ORDER or {}) do
            if not me.give[k] then
                local ok, ready, soon, givers = pcall(lib.BisInReady, lib, k)
                if ok and type(givers) == "table" and #givers > 0 then plan.asks[#plan.asks + 1] = k end
            end
        end
    end
    return plan
end

function UT.Layout()
    if not UT.Shown() then if UT.frame and not combat() then UT.frame:Hide() end return false end
    if combat() then UT.pending = true return false end
    UT.pending = nil
    local f, C, P = UT.Build(), UT.COL, UT.PAD
    local plan = UT.Plan()
    UT.plan = plan
    local y = -28
    local mode = UT.Mode()
    f.mode:SetShown(plan.give ~= nil)
    f.mode.label:SetText(mode == "faces" and "FACES" or "BOXES")
    -- GIVE: faces or boxes, pre-aimed
    local used = 0
    if plan.give then
        f.head:ClearAllPoints() f.head:SetPoint("TOPLEFT", P, y)
        y = y - 16
        local cols = mode == "faces" and math.max(1, math.floor((UT.W - 2 * P + 6) / (UT.FACE + 12))) or 2
        local w = mode == "faces" and (UT.FACE + 12) or math.floor((UT.W - 2 * P - 6) / 2)
        local h = mode == "faces" and (UT.FACE + 26) or UT.BOX_H
        for i, a in ipairs(plan.askers) do
            used = i
            local b = UT.Face(i)
            b.who, b.unit, b.spell, b.req = a.name, a.unit, plan.give, nil
            b:SetAttribute("unit", a.unit)
            b:SetAttribute("spell", UT.SPELL[plan.give])
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            b:ClearAllPoints()
            b:SetSize(w - 6, h)
            b:SetPoint("TOPLEFT", f, "TOPLEFT", P + col * w, y - row * (h + 6))
            local cc = RAID_CLASS_COLORS and a.class and RAID_CLASS_COLORS[a.class]
            b.name:SetText(a.name:match("^(%S+)") or a.name)
            if cc then b.name:SetTextColor(cc.r, cc.g, cc.b, 1) end
            b.name:ClearAllPoints() b.mana:ClearAllPoints() b.ask:ClearAllPoints()
            if mode == "faces" then
                b.pic:Hide()
                if b.model then
                    b.model:ClearAllPoints()
                    b.model:SetPoint("TOP", b, "TOP", 0, -3)
                    b.model:SetSize(UT.FACE - 4, UT.FACE - 4)
                    pcall(b.model.SetUnit, b.model, a.unit)
                    if b.model.SetPortraitZoom then pcall(b.model.SetPortraitZoom, b.model, 1) end
                    b.model:Show()
                end
                b.mana:SetPoint("TOP", b, "TOP", 0, -(UT.FACE + 1)) b.mana:SetSize(UT.FACE - 6, 4)
                b.name:SetPoint("TOP", b.mana, "BOTTOM", 0, -2)
                b.ask:SetPoint("BOTTOM", b, "TOP", 0, 1)
            else
                if b.model then b.model:Hide() end
                b.pic:ClearAllPoints()
                b.pic:SetPoint("LEFT", 4, 0) b.pic:SetSize(h - 8, h - 8)
                if SetPortraitTexture then pcall(SetPortraitTexture, b.pic, a.unit) end
                b.pic:Show()
                b.name:SetPoint("TOPLEFT", b.pic, "TOPRIGHT", 6, 0)
                b.mana:SetPoint("LEFT", b.pic, "RIGHT", 6, -2) b.mana:SetSize(w - h - 14, 5)
                b.ask:SetPoint("BOTTOMLEFT", b.pic, "BOTTOMRIGHT", 6, 0)
            end
            b:Show()
        end
        local rows = math.ceil(#plan.askers / cols)
        y = y - rows * (h + 6)
        if #plan.askers == 0 then
            f.empty:ClearAllPoints() f.empty:SetPoint("TOPLEFT", P, y)
            f.empty:SetText("Nobody in your group asks yet. Mana users with BiS> in on show here.")
            f.empty:Show()
            y = y - 28
        else
            f.empty:Hide()
        end
    else
        f.head:SetText("")
        f.empty:Hide()
    end
    for i = used + 1, #f.faces do f.faces[i]:Hide() end
    -- TIDE: the shaman's own button
    if plan.tide then
        local b = UT.TideButton()
        b:ClearAllPoints()
        b:SetSize(UT.W - 2 * P, UT.ASK_H)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", P, y)
        b:Show()
        y = y - UT.ASK_H - 6
    elseif f.tide then f.tide:Hide() end
    -- ASK: one big button a spell
    for i, k in ipairs(plan.asks) do
        local b = UT.AskButton(i)
        b.spell = k
        b.icon:SetTexture(UT.ICON[k])
        b.word:SetText(UT.WORD[k])
        b:ClearAllPoints()
        b:SetSize(UT.W - 2 * P, UT.ASK_H)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", P, y)
        b:Show()
        y = y - UT.ASK_H - 6
    end
    for i = #plan.asks + 1, #f.asks do f.asks[i]:Hide() end
    if not plan.give and not plan.tide and #plan.asks == 0 then
        f.empty:ClearAllPoints() f.empty:SetPoint("TOPLEFT", P, y)
        f.empty:SetText((UT.Me() and UT.Me().on) and "Nobody here gives Innervate, Power Infusion or Mana Tide yet." or
            "BiS> in is off - /bish utility on")
        f.empty:Show()
        y = y - 28
    end
    f:SetHeight(-y + 6)
    f:Show()
    UT.Paint()
    return true
end

------------------------------------------------------------------------------------------------ painting (any time)
local function clock(s) s = math.max(0, math.floor(s + 0.5)) return ("%d:%02d"):format(math.floor(s / 60), s % 60) end
--- THE CHAT LOCKDOWN (solved.md: addon messages hold while InChatMessagingLockdown() is true - in a fight): an ask made
--- then waits in LibBiSComm's outbox and leaves when it lifts. The button says so instead of pretending it went out.
--- A hidden answer counts as locked (the lib's own rule).
function UT.Locked()
    if not InChatMessagingLockdown then return false end
    local ok, v = pcall(InChatMessagingLockdown)
    if not ok then return false end
    if NS.Secret and NS.Secret(v) then return true end
    return v == true
end
function UT.Paint()
    local f, plan, lib = UT.frame, UT.plan, L()
    if not (f and f:IsShown() and plan and lib) then return end
    local C = UT.COL
    -- GIVE: who asks lights; my spell's readiness in the head
    if plan.give then
        local okR, reqs = pcall(lib.BisInRequests, lib, plan.give)
        local by = {}
        for _, r in ipairs(okR and reqs or {}) do by[r.owner] = by[r.owner] or r.id end
        local okM, ready, soon = pcall(lib.BisInReady, lib, plan.give)
        f.head:SetText(UT.WORD[plan.give] .. "   " .. ((okM and ready and ready > 0) and "ready" or
            ((okM and soon) and ("ready in " .. clock(soon - ((GetServerTime and GetServerTime()) or 0))) or "")))
        for _, b in ipairs(f.faces) do
            if b:IsShown() then
                b.req = by[b.who]
                b:SetAlpha(b.req and 1 or (UT.OnMana(b.unit) and 0.6 or 0.25))
                edgeColor(b, b.req and C.gold or C.line)
                if b.req then b.ask:Show() else b.ask:Hide() end
                local okP, mx = pcall(UnitPowerMax, b.unit, 0)
                local okV, v = pcall(UnitPower, b.unit, 0)
                if okP and okV then pcall(b.mana.SetMinMaxValues, b.mana, 0, mx) pcall(b.mana.SetValue, b.mana, v) end
            end
        end
    end
    -- TIDE: lit gold with who asked
    if plan.tide and f.tide then
        local okR, reqs = pcall(lib.BisInRequests, lib, "tide")
        local r = okR and reqs and reqs[1]
        f.tide.req = r and r.id or nil
        edgeColor(f.tide, r and C.gold or C.line)
        f.tide.say:SetText(r and ((r.owner:match("^(%S+)") or r.owner) .. " asks - click to drop it") or "nobody asking")
        f.tide.say:SetTextColor((r and C.gold or C.muted)[1], (r and C.gold or C.muted)[2], (r and C.gold or C.muted)[3], 1)
    end
    -- ASK: ready / cooldown, then asked / answering
    for _, b in ipairs(f.asks) do
        if b:IsShown() and b.spell then
            local mine = UT.asked and UT.asked[b.spell]
            local r = mine and lib.BisInRequest and lib:BisInRequest(mine)
            if mine and not r then UT.asked[b.spell] = nil mine = nil end
            local text, lit
            if r then
                lit = true
                text = r.claim and ("asked - " .. ((r.claim.by or "?"):match("^(%S+)") or "?") .. " is answering") or
                    (UT.Locked() and "asked - goes out when the fight ends" or "asked - waiting for an answer")
            else
                local ok, ready, soon, givers = pcall(lib.BisInReady, lib, b.spell)
                if ok and ready and ready > 0 then text = ready == 1 and ((givers[1] or "1"):match("^(%S+)") .. " ready") or (ready .. " ready")
                elseif ok and soon then text = "all on cooldown - " .. clock(soon - ((GetServerTime and GetServerTime()) or 0))
                else text = "nobody ready" end
            end
            b.say:SetText(text)
            local c = lit and C.gold or C.muted
            b.say:SetTextColor(c[1], c[2], c[3], 1)
            edgeColor(b, lit and C.gold or C.line)
        end
    end
end

--- The asker's click: ask; again, take it back.
function UT.AskClick(spell)
    local lib = L()
    if not (lib and lib.BisInAsk) then return nil end
    UT.asked = UT.asked or {}
    local mine = UT.asked[spell]
    if mine and lib:BisInRequest(mine) then
        pcall(lib.BisInCancel, lib, mine, "taken back")
        UT.asked[spell] = nil
        UT.Paint()
        return false
    end
    local ok, id, why = pcall(lib.BisInAsk, lib, spell)
    if ok and id then UT.asked[spell] = id
    elseif NS.Print then NS.Print("BiS> utility: couldn't ask (" .. tostring(ok and why or id) .. ")") end
    UT.Paint()
    return ok and id or nil
end

------------------------------------------------------------------------------------------------ switches
function UT.SetShown(on)
    char().utility = on and true or false
    local lib = L()
    if on and lib and lib.BisInSet then
        local me = UT.Me()
        if not (me and me.on) then pcall(lib.BisInSet, lib, true) end
    end
    if on then UT.Layout() elseif UT.frame then
        if combat() then UT.pending = true else UT.frame:Hide() end
    end
    return UT.Shown()
end
function UT.SetMode(m)
    char().utilityMode = (m == "boxes") and "boxes" or "faces"
    UT.Layout()
    return UT.Mode()
end
--- /bish utility [on|off|faces|boxes]
function UT.Command(arg)
    arg = tostring(arg or ""):lower()
    if arg == "on" then UT.SetShown(true)
    elseif arg == "off" then UT.SetShown(false)
    elseif arg == "faces" or arg == "boxes" then UT.SetMode(arg)
    elseif arg:match("^hide%s+%a+$") then
        local cl = arg:match("^hide%s+(%a+)$"):upper()
        local hid = UT.SetHidden(cl)
        if NS.Print then NS.Print(("utility: %s faces %s"):format(cl, hid and "left off" or "shown")) end
        return
    else UT.SetShown(not UT.Shown()) end
    if NS.Print then NS.Print(("utility: %s, %s"):format(UT.Shown() and "shown" or "hidden", UT.Mode())) end
end

------------------------------------------------------------------------------------------------ events
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        local lib = L()
        if lib and lib.RegisterCallback and not UT.hooked then
            UT.hooked = true
            pcall(lib.RegisterCallback, lib, "BISIN", function(_, what)
                if what == "roster" or what == "cd" then if not combat() then UT.Layout() else UT.pending = true UT.Paint() end
                else UT.Paint() end
            end)
        end
        if UT.Shown() then
            if lib and lib.BisInSet then
                local me = UT.Me()
                if not (me and me.on) then pcall(lib.BisInSet, lib, true) end
            end
            UT.Layout()
        end
        return
    end
    if not UT.Shown() then return end
    if event == "PLAYER_REGEN_ENABLED" then if UT.pending then UT.Layout() end return end
    if event == "GROUP_ROSTER_UPDATE" then if combat() then UT.pending = true else UT.Layout() end end
end)
UT.events = ev
