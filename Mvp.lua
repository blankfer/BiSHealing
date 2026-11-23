--[[ BiSHealing :: Mvp.lua (NS.MV) - OUR MVP ON THEIR BOX, in a battleground (22 Nov 2026).

  Arn, 22 Nov, in Warsong Gulch: "i was just wondering if in the healing frame we can show our mvp" - "kind of like how we mark
  who is hellfire" - "yeah api to bis healing and bis tools will have its own pvp/bg app". BiS Tools' battleground tool reads the
  scoreboard and knows our side's best healer and best killer; it hands them over by BiSToolsAPI.BGMarks() (version 8). Here: a
  gold MVP square on that person's box, in the cue row under the callsign (after Hellfire's and Life Tap's squares, the way the
  squares line up). The word is on it: MVP.

  The switch: "Our MVP on their box" in a PVP group of the deck's switches (RD.SW "pvpmvp"), OFF until ticked. Nothing runs
  outside a battleground, with the switch off or without BiS Tools: one look every MV.EVERY s only then, a table walk of the
  boxes. Plain frames only (on the box's plate): shown and hidden in a fight too.
]]
local _, NS = ...
local MV = {}
NS.MV = MV
local RD = NS.RD

MV.EVERY = 3
MV.PX = 22
MV.COL = { 1.00, 0.83, 0.30, 1 }
MV.WHAT = { healer = "our best healer", killer = "our best killer" }

local function plain(v) if v == nil or (NS.Secret and NS.Secret(v)) then return nil end return v end
local function inBG()
    local ok, inside, kind = pcall(IsInInstance)
    return ok and plain(inside) == true and (plain(kind) == "pvp" or plain(kind) == "arena")
end
function MV.On() return RD and RD.Sw and RD.Sw("pvpmvp") and RD.On and RD.On() or false end

-- THE SWITCH, in a PVP group at the end of the deck's switches (off until ticked: nil reads off)
if RD and RD.SW then
    RD.SW[#RD.SW + 1] = { key = "pvpmvp", group = "PVP", name = "Our MVP on their box", off = true, layout = true,
        tip = "In a battleground: a gold MVP square on the box of our side's best healer and best killer. BiS Tools' battleground tool reads the scoreboard." }
    if RD.SW_OFF then RD.SW_OFF.pvpmvp = true end
    -- (like the raid layout's switches: the presets and RESET leave it alone - a battleground thing, ticked on purpose)
end

--- Who is our MVP now: { ["FIRSTNAME"] = "healer"|"killer" } (the deck's boxes say first names, in capitals).
function MV.Names()
    local api = _G.BiSToolsAPI
    if not (api and type(api.BGMarks) == "function") then return nil end
    local ok, m = pcall(api.BGMarks)
    if not ok or type(m) ~= "table" or not m.inBG then return nil end
    local out = {}
    for _, x in ipairs(m.mvps or {}) do
        if type(x) == "table" and type(x.name) == "string" then
            local first = x.name:match("^(%S+)") or x.name
            out[first:gsub("%-.*$", ""):upper()] = x.what or "mvp"
        end
    end
    return out
end

--- The square on one box: shown with `what` ("healer"/"killer"), hidden with nil.
function MV.Tag(sp, what)
    local t = sp.mvpTag
    if not what or (RD.BoxHas and not RD.BoxHas(sp, "extras")) then
        if t then t:Hide() end
        return nil
    end
    local plate = sp.deckPlate or (RD.DeckPlate and RD.DeckPlate(sp))
    if not plate then return nil end
    if not t then
        t = CreateFrame("Frame", nil, plate)
        t:SetSize(MV.PX, MV.PX)
        local bg = t:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(t)
        bg:SetColorTexture(0.04, 0.04, 0.06, 0.9)
        local c = MV.COL
        for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
                             { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
            local x = t:CreateTexture(nil, "BORDER")
            x:SetColorTexture(c[1], c[2], c[3], 1)
            x:SetPoint(e[1], t, e[1], 0, 0)
            x:SetPoint(e[2], t, e[2], 0, 0)
            if e[3] > 0 then x:SetWidth(e[3]) else x:SetHeight(e[4]) end
        end
        t.text = t:CreateFontString(nil, "OVERLAY")
        t.text:SetFont("Fonts\\ARIALN.TTF", 8, "OUTLINE")
        t.text:SetPoint("CENTER", t, "CENTER", 0, 0)
        t.text:SetTextColor(c[1], c[2], c[3], 1)
        t.text:SetText("MVP")
        sp.mvpTag = t
    end
    -- its place: the next square of the cue row (after the square cues that are on)
    local x, y = 3, -14
    local CU = NS.CU
    if CU and CU.SQUARE then
        local n = 0
        for _, k in ipairs(CU.Order and CU.Order() or {}) do
            local q = CU.BY and CU.BY[k]
            if q and q.kind == "square" and CU.On(k) then n = n + 1 end
        end
        x, y = CU.SQUARE.x + n * (MV.PX + CU.SQUARE.gap), CU.SQUARE.y
    end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", plate, "TOPLEFT", x, y)
    local lvl = sp.heal and sp.heal.GetFrameLevel and sp.heal:GetFrameLevel()
    if type(lvl) == "number" then t:SetFrameLevel(lvl + 7) end
    t.what = what
    t:Show()
    return t
end

--- One look: every box, its square or none.
function MV.Look()
    local names = MV.On() and inBG() and MV.Names() or nil
    local shown = 0
    for _, sp in pairs(RD.spokes or {}) do
        local what
        if names and sp.unit then
            local n = RD.BoxName and RD.BoxName(sp.unit)
            if type(n) == "string" and not (NS.Secret and NS.Secret(n)) then what = names[n] end
        end
        if MV.Tag(sp, what) then shown = shown + 1 end
    end
    MV.shown = shown
    return shown
end

--- The watch: a ticker only in a battleground with the switch on; off otherwise (and every square put away).
function MV.Arm()
    local want = MV.On() and inBG()
    if want and not MV.ticker and C_Timer and C_Timer.NewTicker then
        MV.ticker = C_Timer.NewTicker(MV.EVERY, MV.Look)
    elseif not want and MV.ticker then
        MV.ticker:Cancel()
        MV.ticker = nil
    end
    MV.Look()
    return MV.ticker ~= nil
end

MV.events = CreateFrame("Frame")
MV.events:RegisterEvent("PLAYER_ENTERING_WORLD")
MV.events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
MV.events:SetScript("OnEvent", function() MV.Arm() end)
-- a switch flipped (RD.SetSw / a preset / RESET go through RD.SwApply): on or off now
if RD and RD.SwApply then
    local swApply = RD.SwApply
    function RD.SwApply(...)
        local r = swApply(...)
        pcall(MV.Arm)
        return r
    end
end
