--[[ BiSHealing :: Reveal.lua (NS.RV) - REVELATION on the synergy bar.

  Arn, 20 Nov 2026: "revelation tracker like buffs" - "no the buff revelation" - and from the sketch
  (https://claude.ai/artifact/E4HZeBae4m9j41rcwbooZN) "B, on the synergy bar". Revelation is Forever's weapon enchant
  (Enchant Weapon - Revelation): a spell that fails to crit can trigger it, and the next spell gets +100% crit - your
  next heal crits. While it is on you, a gold CRIT sits in the middle of the synergy bar (EN.heads.rip).

  YOUR OWN aura, asked by id (GetPlayerAuraBySpellID - the call that has never missed; SelfBuff.lua's road). The name has
  RV.IDS spell ids in ForeverAuras' name list and which one is the buff is UNVERIFIED (the BiS? probe of 20 Nov asks the
  descriptions): an aura with duration 0 is the enchant's own passive, never the buff - learned out of a fight into
  db().reveal.passive, so a hidden duration later cannot fool us; the first one seen with a real duration is kept
  (db().reveal.buff) and from then on is the only one asked. Listens to UNIT_AURA for you only. ]]
local _, NS = ...
NS = NS or {}
local RV = {}
NS.RV = RV

-- THE BUFF IS 1323418 (Arn's tooltip, 20 Nov: "Revelation, Spell ID: 1323418 - Critical Strike chance of your next
-- non-periodic spell increased by 100%", seconds remaining) - asked first; the rest stay as a fallback. In a fight even
-- your own aura answers nil (his BiS? probe with it up: all eight nil), so the combat text below is the road there.
RV.IDS = { 1323418, 1248806, 1248808, 1323377, 1323392, 1323400, 1323410, 1323419 }
RV.WORD = "CRIT"
RV.COL = { 1.00, 0.83, 0.30 }

local function plain(v) if v == nil or (NS.Secret and NS.Secret(v)) then return nil end return v end
local function db()
    local d = NS.DB and NS.DB() or {}
    d.radar = type(d.radar) == "table" and d.radar or {}
    local r = d.radar
    r.reveal = type(r.reveal) == "table" and r.reveal or {}
    r.reveal.passive = type(r.reveal.passive) == "table" and r.reveal.passive or {}
    return r.reveal
end
local function fight() return (InCombatLockdown and InCombatLockdown()) and true or false end

--[[ THE SECOND ROAD (20 Nov 2026, Arn's live test: "no crit mid fight" - `/bish reveal` said the aura read never answered,
  yet the game's own floating text said "<Revelation fades>"): the game announces your auras to its combat text through
  COMBAT_TEXT_UPDATE ("SPELL_AURA_START" / "SPELL_AURA_END", the name from GetCurrentCombatTextEventInfo). A PLAIN name
  equal to Revelation's lights it / puts it out; a hidden name is never compared. ]]
RV.textUp = false
function RV.Name()
    local get = C_Spell and C_Spell.GetSpellName
    if get then
        local ok, n = pcall(get, RV.IDS[1])
        n = ok and plain(n) or nil
        if type(n) == "string" and n ~= "" then return n end
    end
    return "Revelation"
end
function RV.Text(kind)
    kind = plain(kind)
    if kind ~= "SPELL_AURA_START" and kind ~= "SPELL_AURA_END" then return false end
    local info = GetCurrentCombatTextEventInfo
    if not info then RV.seenText = "no combat text api" return false end
    local ok, name = pcall(info)
    local n = ok and plain(name) or nil
    RV.seenText = kind .. " " .. (n and tostring(n) or (ok and "hidden name" or "refused"))
    if n ~= RV.Name() then return false end
    RV.textUp = kind == "SPELL_AURA_START"
    return true
end

--- Is Revelation on you right now (true / false)?
function RV.Up()
    if RV.textUp then return true end
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not get then return false end
    local d = db()
    local ids = d.buff and { d.buff } or RV.IDS
    for _, id in ipairs(ids) do
        if not d.passive[id] then
            local ok, a = pcall(get, id)
            -- a HIDDEN answer about the buff we already know: a missing aura answers nil, so something hidden is there
            -- (UNVERIFIED in a fight - `/bish reveal` says what it last read)
            if ok and a ~= nil and NS.Secret and NS.Secret(a) then
                RV.seen = d.buff == id and "hidden: taken as up" or "hidden: not known yet"
                if d.buff == id then return true end
            elseif ok and a ~= nil then
                RV.seen = "read " .. id
                local dur = plain(a.duration)
                if dur == 0 then
                    if not fight() then d.passive[id] = true end     -- the enchant's own passive: never again
                else
                    if type(dur) == "number" and dur > 0 and not d.buff then d.buff = id end
                    return true
                end
            end
        end
    end
    return false
end

--- The CRIT word on the synergy bar, made on first need.
function RV.Word()
    local EN = NS.EN
    local q = EN and EN.heads and EN.heads.rip
    if not (q and EN.RipBuild) then return nil end
    local B = EN.RipBuild(q)
    if not B.crit then
        local fs = B.over:CreateFontString(nil, "OVERLAY")
        fs:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
        fs:SetPoint("CENTER", q, "CENTER", 0, 0)
        fs:SetTextColor(RV.COL[1], RV.COL[2], RV.COL[3], 1)
        fs:SetText(RV.WORD)
        fs:Hide()
        B.crit = fs
    end
    return B.crit
end

--- Paint it: shown while Revelation is on you.
function RV.Paint()
    local up = RV.Up()
    RV.up = up
    local fs = (up or (NS.EN and NS.EN.heads and NS.EN.heads.rip and NS.EN.heads.rip.rip and NS.EN.heads.rip.rip.crit)) and RV.Word()
    if not fs then return up end
    if up then fs:Show() else fs:Hide() end
    return up
end

RV.events = CreateFrame("Frame")
if RV.events.RegisterUnitEvent then RV.events:RegisterUnitEvent("UNIT_AURA", "player")
else RV.events:RegisterEvent("UNIT_AURA") end
RV.events:RegisterEvent("PLAYER_ENTERING_WORLD")
RV.events:RegisterEvent("COMBAT_TEXT_UPDATE")
RV.events:SetScript("OnEvent", function(_, event, unit)
    if event == "COMBAT_TEXT_UPDATE" then
        if RV.Text(unit) then RV.Paint() end
        return
    end
    if event == "UNIT_AURA" and unit ~= "player" then return end
    RV.Paint()
end)

--- `/bish reveal`: is it on you, which id is the buff, what the last read said.
function RV.Status()
    local d = db()
    local pas = {}
    for id in pairs(d.passive) do pas[#pas + 1] = tostring(id) end
    local line = string.format("reveal: up %s | the buff's id %s | passive %s | last read: %s | combat text: %s", tostring(RV.Up()),
        tostring(d.buff or "not seen yet"), #pas > 0 and table.concat(pas, ", ") or "none", RV.seen or "nothing yet",
        RV.seenText or "nothing heard")
    if NS.Print then NS.Print(line) end
    return line
end
