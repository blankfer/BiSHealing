-- BiSHealing / Onboard.lua -- THE FIRST-START CARD (18 Nov 2026).
--
-- Arn, 18 Nov 2026: "a new pop up for new installs. BiS>healing/onboard. Quick steps, I'm here to: [heal] : [utility].
-- Heal: [classic] [deck]. Utility: it will smartly see what class they are and build the deck that way." Sketches
-- https://claude.ai/artifact/PoSKQvbpSJh8CpcqT6PXb9 - he picked A, TWO BIG CARDS: "utility always defaults to deck,
-- healing strongly suggested deck", and the suggestions: new installs only plus /bish onboard; per character; healing
-- druids, shamans and priests get the utility window too ("utility" alone is for everyone else).
--
--   HEAL     -> CLASSIC or DECK (DECK pre-picked, marked SUGGESTED). DECK = the radar look with every switch on - the
--               black box excepted, it is always clicked on by hand (Arn, 18 Nov: "even when someone selects the deck
--               options show everything it should not turn on that black box"; Radar.lua RD.SW_MANUAL).
--   UTILITY  -> the utility window (Utility.lua) built for your class; the healing frames put away.
--   SKIP     -> nothing changes; /bish onboard brings the card back.
-- Shown once per character, only on a NEW install (NS.fresh, decided by NS.Forever10), never in a fight. The pick is
-- kept in BiSHealingCharDB.onboard = { role, look, at }.
local _, NS = ...
local OB = {}
NS.OB = OB

local function char()
    BiSHealingCharDB = type(BiSHealingCharDB) == "table" and BiSHealingCharDB or {}
    return BiSHealingCharDB
end
local function combat() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function say(...) if NS.Print then NS.Print(...) end end

OB.W, OB.H = 430, 300                           -- the family's 1.43 : 1 (window-ratio standard)
OB.COL = { plate = { 0.09, 0.08, 0.165 }, panel = { 0.12, 0.106, 0.21 }, line = { 0.2, 0.17, 0.33 }, accent = { 0.725, 0.5, 1 },
           teal = { 0.31, 0.82, 0.81 }, gold = { 0.9, 0.75, 0.29 }, muted = { 0.6, 0.57, 0.72 }, ink = { 0.93, 0.91, 0.96 },
           heal = { 0.44, 0.89, 0.6 } }
OB.HEALERS = { DRUID = true, SHAMAN = true, PRIEST = true }      -- a healer whose class also gives: the utility window too

--- What the UTILITY card says your class gets.
OB.CLASS_LINE = {
    DRUID   = "You give Innervate: a face for everyone who asks, one click casts it on them.",
    PRIEST  = "You give Power Infusion: a face for everyone who asks, one click casts it.",
    SHAMAN  = "You answer Mana Tide: your button lights up gold when someone in your party asks.",
    MAGE    = "You ask: an Innervate button, and Mana Tide when a shaman is in your party.",
    WARLOCK = "You ask: an Innervate button, and Mana Tide when a shaman is in your party.",
    HUNTER  = "You ask: an Innervate button, and Mana Tide when a shaman is in your party.",
    PALADIN = "You ask: an Innervate button, and Mana Tide when a shaman is in your party.",
}
OB.NONE_LINE = "Your class has nothing to give or ask here - HEAL suits you better."

function OB.Class()
    local ok, _, cl = pcall(UnitClass, "player")
    if ok and type(cl) == "string" and not (NS.Secret and NS.Secret(cl)) then return cl end
    return nil
end
function OB.ClassLine(cl) return OB.CLASS_LINE[cl or OB.Class() or ""] or OB.NONE_LINE end
function OB.Done() return type(char().onboard) == "table" end

------------------------------------------------------------------------------------------------ the picks
--- Apply a pick: role "heal" (look "deck" | "classic") or "utility", or "skip". Out of a fight only (the looks lay out
--- secure frames). Answers true when applied, or nil and why.
function OB.Pick(role, look)
    if combat() then return nil, "in a fight" end
    local cl = OB.Class()
    if role == "heal" then
        look = (look == "classic") and "classic" or "deck"
        local RD = NS.RD
        if look == "deck" then
            if NS.DO and NS.DO.look then NS.DO.look("radar") end
            if RD and RD.SwPreset then RD.SwPreset("full") end          -- every switch on; the black box keeps its own
        else
            if NS.DO and NS.DO.look then NS.DO.look("classic") end
        end
        local d = NS.DB and NS.DB()
        if d and d.shown == false and NS.DO.show then NS.DO.show(true) end
        if OB.HEALERS[cl or ""] and NS.UT then NS.UT.SetShown(true) end
    elseif role == "utility" then
        if NS.UT then NS.UT.SetShown(true) end
        local d = NS.DB and NS.DB()
        if d and d.shown ~= false and NS.DO.show then NS.DO.show(false) end   -- the healing frames away: not a healer
        look = nil
    elseif role == "skip" then
        look = nil
    else
        return nil, "no such pick"
    end
    char().onboard = { role = role, look = look, at = (time and time()) or 0 }
    if OB.frame then OB.frame:Hide() end
    if role == "heal" then say(("set up to heal - %s look%s. /bish onboard to choose again"):format(look,
        (OB.HEALERS[cl or ""]) and ", and the utility window" or ""))
    elseif role == "utility" then say("set up for utility - /bish utility shows or hides it, /bish onboard to choose again")
    else say("skipped - /bish onboard brings the card back") end
    return true
end

------------------------------------------------------------------------------------------------ the card
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
end
local function edgeColor(f, col) for _, t in ipairs(f.edges or {}) do t:SetColorTexture(col[1], col[2], col[3], 1) end end
--- A plain button that glows on hover (the family's rows-glow rule).
local function button(parent, w, h, word, size)
    local C = OB.COL
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.bg = tex(b, "BACKGROUND", C.panel, 1) b.bg:SetAllPoints(b)
    b.wash = tex(b, "ARTWORK", C.accent, 0.12) b.wash:SetAllPoints(b) b.wash:Hide()
    edge(b, C.line)
    b.word = fs(b, size or 13, C.ink, "Fonts\\FRIZQT__.TTF")
    b.word:SetText(word or "")
    b:SetScript("OnEnter", function(self) self.wash:Show() end)
    b:SetScript("OnLeave", function(self) self.wash:Hide() end)
    return b
end

function OB.Build()
    if OB.frame then return OB.frame end
    local C = OB.COL
    local f = CreateFrame("Frame", "BiSHealingOnboard", UIParent)
    f:SetSize(OB.W, OB.H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetScript("OnHide", function(self) self:StopMovingOrSizing() end)
    f.bg = tex(f, "BACKGROUND", C.plate, 0.97) f.bg:SetAllPoints(f)
    edge(f, C.line)
    f.title = fs(f, 13, C.accent, "Fonts\\FRIZQT__.TTF")
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetText("BiS> healing/onboard")
    f.close = button(f, 18, 18, "x", 11)
    f.close:SetPoint("TOPRIGHT", -8, -8)
    f.close.word:SetPoint("CENTER")
    f.close:SetScript("OnClick", function() OB.Pick("skip") end)
    f.ask = fs(f, 12, C.muted, "Fonts\\FRIZQT__.TTF")
    f.ask:SetPoint("TOPLEFT", 14, -38)
    f.ask:SetText("I'M HERE TO:")
    -- the two big cards
    local cw, ch = math.floor((OB.W - 28 - 12) / 2), 112
    f.cards = {}
    for i, spec in ipairs({ { role = "heal", word = "HEAL", glyph = "+", col = C.heal,
                              small = "Click-cast frames for the whole group" },
                            { role = "utility", word = "UTILITY", glyph = "<>", col = C.accent,
                              small = "Innervate, Mana Tide - give or ask" } }) do
        local b = button(f, cw, ch, "", 16)
        b:SetPoint("TOPLEFT", 14 + (i - 1) * (cw + 12), -58)
        b.role = spec.role
        b.glyph = fs(b, 22, spec.col, "Fonts\\FRIZQT__.TTF")
        b.glyph:SetPoint("TOP", 0, -14)
        b.glyph:SetText(spec.glyph)
        b.word:SetPoint("TOP", b.glyph, "BOTTOM", 0, -8)
        b.word:SetText(spec.word)
        b.small = fs(b, 11, C.muted)
        b.small:SetPoint("TOP", b.word, "BOTTOM", 0, -6)
        b.small:SetWidth(cw - 20)
        b.small:SetText(spec.small)
        b:SetScript("OnClick", function(self) OB.Choose(self.role) end)
        f.cards[spec.role] = b
    end
    -- under HEAL: CLASSIC / DECK (DECK suggested); under UTILITY: what your class gets + GO
    local y = -58 - ch - 14
    f.classic = button(f, 120, 30, "CLASSIC", 13)
    f.classic:SetPoint("TOPLEFT", 14, y)
    f.classic.word:SetPoint("CENTER")
    f.classic:SetScript("OnClick", function() OB.Pick("heal", "classic") end)
    f.deck = button(f, 120, 30, "DECK", 13)
    f.deck:SetPoint("LEFT", f.classic, "RIGHT", 10, 0)
    f.deck.word:SetPoint("CENTER")
    f.deck:SetScript("OnClick", function() OB.Pick("heal", "deck") end)
    f.suggest = fs(f, 10, C.gold, "Fonts\\FRIZQT__.TTF")
    f.suggest:SetPoint("LEFT", f.deck, "RIGHT", 10, 0)
    f.suggest:SetText("SUGGESTED")
    f.line = fs(f, 12, C.ink)
    f.line:SetPoint("TOPLEFT", 14, y)
    f.line:SetWidth(OB.W - 28 - 90)
    f.line:SetJustifyH("LEFT")
    f.go = button(f, 80, 30, "GO", 13)
    f.go:SetPoint("TOPRIGHT", -14, y)
    f.go.word:SetPoint("CENTER")
    f.go:SetScript("OnClick", function() OB.Pick("utility") end)
    f.note = fs(f, 10, C.muted)
    f.note:SetPoint("TOPLEFT", 14, y - 40)
    f.note:SetWidth(OB.W - 28)
    f.note:SetJustifyH("LEFT")
    f.skip = button(f, 70, 24, "SKIP", 11)
    f.skip:SetPoint("BOTTOMRIGHT", -14, 12)
    f.skip.word:SetPoint("CENTER")
    f.skip:SetScript("OnClick", function() OB.Pick("skip") end)
    f.foot = fs(f, 10, C.muted)
    f.foot:SetPoint("BOTTOMLEFT", 14, 18)
    f.foot:SetText("/bish onboard opens this again")
    f:Hide()
    OB.frame = f
    return f
end

--- One of the two big cards picked: its row under the cards comes up, the card edged teal.
function OB.Choose(role)
    local f = OB.Build()
    local C = OB.COL
    OB.role = role
    for r, b in pairs(f.cards) do edgeColor(b, r == role and C.teal or C.line) end
    local heal, util = role == "heal", role == "utility"
    local function vis(x, on) if on then x:Show() else x:Hide() end end
    vis(f.classic, heal) vis(f.deck, heal) vis(f.suggest, heal)
    if heal then edgeColor(f.deck, C.gold) f.deck.word:SetTextColor(C.gold[1], C.gold[2], C.gold[3], 1) end
    vis(f.line, util) vis(f.go, util)
    local cl = OB.Class()
    if util then
        f.line:SetText(OB.ClassLine(cl))
        if OB.CLASS_LINE[cl or ""] then f.go:Show() else f.go:Hide() end
    end
    if heal then
        f.note:SetText(OB.HEALERS[cl or ""] and "Your class gives mana too: the utility window comes with it." or
            "DECK shows everything at once; the switches beside it turn any part off.")
    elseif util then
        f.note:SetText("The healing frames are put away. /bish show brings them back.")
    else
        f.note:SetText("")
    end
    return role
end

--- Open the card (out of a fight only - it lays out frames when a pick is made).
function OB.Open()
    if combat() then say("onboard: after this fight") OB.wantOpen = true return false end
    local f = OB.Build()
    OB.Choose(nil)
    f:Show()
    return true
end

--- At login: a new install that has not picked yet sees the card. Waits for NS.Forever10 to decide new or returning.
function OB.Maybe()
    if OB.Done() or OB.offered then return false end
    if NS.pending10 then return false end
    if not NS.fresh then return false end
    OB.offered = true
    return OB.Open()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "UPDATE_MACROS", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if OB.wantOpen then OB.wantOpen = nil OB.Open() end
        return
    end
    pcall(OB.Maybe)
end)
OB.events = ev
