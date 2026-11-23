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
-- A BUFF ID PER CLASS (21 Nov 2026, the enchant research off wowhead/forever - each page lists the spells it works on):
-- shaman 1323418, priest 1323377, druid 1323400, paladin 1323419, mage 1248808, warlock 1323392, hunter 1323410, all
-- 15 s, +100% crit; 1248806 is the enchant's hidden passive. The game draws whichever of them is on you.
RV.CLASS_IDS = { 1323418, 1323377, 1323400, 1323419, 1248808, 1323392, 1323410 }
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
RV.fight = fight

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
        fs:SetPoint("CENTER", q, "CENTER", 0, 0)        -- (only when the game's badge could not be built)
        fs:SetTextColor(RV.COL[1], RV.COL[2], RV.COL[3], 1)
        fs:SetText(RV.WORD)
        fs:Hide()
        B.crit = fs
    end
    return B.crit
end

--[[ THE GAME DRAWS IT (20 Nov 2026, Arn: "can we just tell hey blizzard you see this buff in my bar can you put it in
  this place"). Your probe said ShouldSpellAuraBeSecret(1323418) = true: in a fight the game will not TELL us Revelation
  is up - but it will DRAW it: an AuraContainer on you with one slot filtered to the buff's id, its icon and countdown
  swipe put in the middle of the synergy bar (the road the classic look's HoT icons and SelfBuff's Water Shield badge
  take). Nothing of ours decides; the client shows it while the buff is there. Built out of a fight, once the bar is. ]]
RV.ICON_IDS = {}
for _, id in ipairs(RV.CLASS_IDS) do RV.ICON_IDS[id] = true end
--[[ OUR OWN BADGE IN THE GAME'S BUTTON (20 Nov 2026, Arn: "instead of the buff can we tell it to draw something else
  like [Revelation] in our theme"): the client hands us its aura button inside initializeFrame (the creation window -
  the one place it may be sized and placed); its own icon / border / count / swipe are hidden (the dispel pip's road)
  and the deck's tag look goes in: a dark box sized to its word, a gold edge, CRIT in gold. The client still shows and
  hides the button with the buff - nothing of ours decides. ]]
RV.BADGE = { w = 36, h = 15, size = 10, bg = { 0.04, 0.04, 0.06, 0.95 } }
function RV.Badge(button)
    if not button then return end
    local B, host = RV.BADGE, RV.host
    local placed = pcall(function()
        button:SetSize(B.w, B.h)
        button:ClearAllPoints()
        button:SetPoint("CENTER", host, "CENTER", 0, 0)
    end)
    if not placed then RV.iconSeen = "button refused" return end
    pcall(function()
        if button.GetRegions then
            for _, r in ipairs({ button:GetRegions() }) do if r.SetTexture and r.Hide then r:Hide() end end
        end
        for _, k in ipairs({ "Icon", "icon", "Border", "border", "Count", "count", "Cooldown" }) do
            local part = button[k]
            if type(part) == "table" and part.Hide then part:Hide() end
        end
        if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(button)
        bg:SetColorTexture(B.bg[1], B.bg[2], B.bg[3], B.bg[4])
        local c = RV.COL
        button.bisTag = { bg }                               -- (the tag: put away when the card's look is an icon or a model)
        for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
                             { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
            local t = button:CreateTexture(nil, "BORDER")
            t:SetColorTexture(c[1], c[2], c[3], 1)
            t:SetPoint(e[1], button, e[1], 0, 0)
            t:SetPoint(e[2], button, e[2], 0, 0)
            if e[3] > 0 then t:SetWidth(e[3]) else t:SetHeight(e[4]) end
            button.bisTag[#button.bisTag + 1] = t
        end
        local fs = button:CreateFontString(nil, "OVERLAY")
        fs:SetFont("Fonts\\ARIALN.TTF", B.size, "OUTLINE")
        fs:SetPoint("CENTER", button, "CENTER", 0, 0)
        fs:SetTextColor(c[1], c[2], c[3], 1)
        fs:SetText(RV.WORD)
        button.bisCrit = fs
        button.bisTag[#button.bisTag + 1] = fs
        -- the cue card's look and sound (Arn, 21 Nov: "no talking on revelation crit"): the client shows the button when
        -- the buff is there - that is the moment to speak, and nothing else in a fight may say so
        if NS.CU and NS.CU.Face then
            button.bisFace = NS.CU.Face(button, "crit", RV.FACE_PX)
            button.bisFace.sq:SetPoint("CENTER", button, "CENTER", 0, 0)
        end
        if button.HookScript then pcall(button.HookScript, button, "OnShow", RV.Speak) end
    end)
    RV.badges = (RV.badges or 0) + 1
    RV.buttons[#RV.buttons + 1] = button
    local faced = NS.CU and NS.CU.FaceShow(button.bisFace, true) or false     -- (this one only: the others may be forbidden)
    if faced then for _, part in ipairs(button.bisTag or {}) do NS.CU.Touch(part, "Hide") end end
end
RV.FACE_PX = 20
RV.buttons = {}
--- The cue card's sound for Revelation, once per CU.EVERY (the button's showing, the combat text, or the read aura).
function RV.Speak()
    local CU = NS.CU
    if not CU or CU.Quiet() then return false end
    return CU.Say("crit", "player")
end
--- Dress every badge in the card's look: the CRIT tag, the spell's icon, or a turning model.
--- (The game's button may refuse us by now - CU.Touch - so a changed look also makes a fresh container, out of a fight:
--- its new button is dressed in its creation window.)
function RV.Relook(fresh)
    local CU = NS.CU
    for _, b in ipairs(RV.buttons) do
        local faced = CU and CU.FaceShow(b.bisFace, true) or false
        if CU then for _, part in ipairs(b.bisTag or {}) do CU.Touch(part, faced and "Hide" or "Show") end end
    end
    local look = CU and CU.Look("crit") or nil
    if fresh and RV.container and RV.look ~= look and not fight() then
        local old = RV.container
        if old.SetEnabled then pcall(old.SetEnabled, old, false) end
        if old.Hide then pcall(old.Hide, old) end
        RV.container, RV.buttons = nil, {}
        RV.Icon()
    end
    if not fight() then RV.look = look end
    if RV.PaintGhost then RV.PaintGhost(not (NS.RD and NS.RD.Sw) or NS.RD.Sw("crit")) end
end
function RV.Icon()
    if RV.container then return RV.container end
    local EN, FA = NS.EN, NS.FA
    local q = EN and EN.heads and EN.heads.rip
    if not (q and FA and FA.Available and FA.Available() and FA.AddSlot) then return nil end
    if fight() then return nil end
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, q, "CustomAuraContainerTemplate")
    if not ok or not c then RV.iconSeen = "refused" return nil end
    c:SetAllPoints(q)
    local lvl = q.GetFrameLevel and q:GetFrameLevel()
    if type(lvl) == "number" and c.SetFrameLevel then c:SetFrameLevel(lvl + 4) end
    c:SetUnit("player")
    RV.host = q
    local slot = FA.AddSlot(c, "BiSHealRevelation", "HELPFUL", {
        candidateFilters = { includeSpellIDs = RV.ICON_IDS },
        initializeFrame = RV.Badge,
    })
    if not slot then RV.iconSeen = "no slot" return nil end
    if c.SetEnabled then c:SetEnabled(true) end
    RV.container, RV.iconSeen = c, "built"
    RV.look = NS.CU and NS.CU.Look and NS.CU.Look("crit") or nil
    RV.Refresh()
    return c
end

--- Ask the game's container to look again now, out of a fight (Arn, 21 Nov: "the crit words are just on the whole time"):
--- it listens for changes and may have missed the buff going (Radar.lua's shield pip learned the same, 8 Nov).
function RV.Refresh()
    local c = RV.container
    if c and c.UpdateAllAuras and not fight() then pcall(c.UpdateAllAuras, c) end
end
--[[ ITS PLACE, ALWAYS (22 Nov 2026, Arn: "the crit always show even without revelation"): a dim CRIT tag of our own in
  the middle of the synergy bar while the cue is on - the place where the lit one comes. It sits UNDER the game's button
  (a lower frame level), so when the client shows Revelation its gold badge covers it; nothing of ours decides that.
  Plain textures on a plain frame: shown and hidden in a fight too. An icon or model look gets the spell's icon, greyed. ]]
RV.GHOST_A = 0.35
function RV.Ghost()
    local EN = NS.EN
    local q = EN and EN.heads and EN.heads.rip
    if not q then return nil end
    if q.bisGhost then return q.bisGhost end
    local B, c = RV.BADGE, RV.COL
    local g = CreateFrame("Frame", nil, q)
    g:SetSize(B.w, B.h)
    g:SetPoint("CENTER", q, "CENTER", 0, 0)
    local lvl = q.GetFrameLevel and q:GetFrameLevel()
    if type(lvl) == "number" and g.SetFrameLevel then g:SetFrameLevel(lvl + 3) end   -- (over the bar, under the game's +4)
    g.tag = {}
    local bg = g:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(g)
    bg:SetColorTexture(B.bg[1], B.bg[2], B.bg[3], B.bg[4])
    g.tag[1] = bg
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
                         { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
        local t = g:CreateTexture(nil, "BORDER")
        t:SetColorTexture(c[1], c[2], c[3], RV.GHOST_A)
        t:SetPoint(e[1], g, e[1], 0, 0)
        t:SetPoint(e[2], g, e[2], 0, 0)
        if e[3] > 0 then t:SetWidth(e[3]) else t:SetHeight(e[4]) end
        g.tag[#g.tag + 1] = t
    end
    local fs = g:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\ARIALN.TTF", B.size, "OUTLINE")
    fs:SetPoint("CENTER", g, "CENTER", 0, 0)
    fs:SetTextColor(c[1], c[2], c[3], RV.GHOST_A)
    fs:SetText(RV.WORD)
    g.word = fs
    g.tag[#g.tag + 1] = fs
    local ic = g:CreateTexture(nil, "ARTWORK")
    ic:SetSize(RV.FACE_PX, RV.FACE_PX)
    ic:SetPoint("CENTER", g, "CENTER", 0, 0)
    if ic.SetTexCoord then ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, RV.CLASS_IDS[1])
        if ok and tex then pcall(ic.SetTexture, ic, tex) end
    end
    if ic.SetDesaturated then ic:SetDesaturated(true) end
    ic:SetAlpha(RV.GHOST_A)
    ic:Hide()
    g.icon = ic
    q.bisGhost = g
    return g
end
--- Show or hide its place: the cue on = always there; its look follows the card (the word = the tag, else the icon).
function RV.PaintGhost(on)
    local g = on and RV.Ghost() or (NS.EN and NS.EN.heads and NS.EN.heads.rip and NS.EN.heads.rip.bisGhost)
    if not g then return false end
    if not on then if g.bisState ~= "off" then g:Hide() g.bisState = "off" end return false end
    local look = NS.CU and NS.CU.Look and NS.CU.Look("crit") or "word"
    local word = look == nil or look == "word"
    local state = word and "word" or "icon"
    if g.bisState == state then return true end                  -- (only a change touches it: the pull's paints stay cheap)
    for _, part in ipairs(g.tag) do if word then part:Show() else part:Hide() end end
    if word then g.icon:Hide() else g.icon:Show() end
    g:Show()
    g.bisState = state
    return true
end

--- Paint it: shown while Revelation is on you.
function RV.Paint()
    local on = not (NS.RD and NS.RD.Sw) or NS.RD.Sw("crit")   -- (the deck's switch, RD.SW "crit")
    if on then RV.Icon() end
    RV.PaintGhost(on)
    local c = RV.container
    if c and c.bisOn ~= on and not fight() and c.SetEnabled then pcall(c.SetEnabled, c, on) c.bisOn = on end
    if not on then
        local fs0 = NS.EN and NS.EN.heads and NS.EN.heads.rip and NS.EN.heads.rip.rip and NS.EN.heads.rip.rip.crit
        if fs0 then fs0:Hide() end
        return false
    end
    local up = RV.Up()
    if up and not RV.up then RV.Speak() end
    RV.up = up
    local fs = (up or (NS.EN and NS.EN.heads and NS.EN.heads.rip and NS.EN.heads.rip.rip and NS.EN.heads.rip.rip.crit)) and RV.Word()
    if not fs then return up end
    if up and not RV.container then fs:Show() else fs:Hide() end   -- (the game's badge, when built, is the CRIT)
    local g = NS.EN.heads.rip.bisGhost
    if g then local hide = up and not RV.container if g.bisHid ~= hide then g.bisHid = hide g:SetAlpha(hide and 0 or 1) end end   -- (our own lit word there: no dim one under it)
    return up
end

RV.events = CreateFrame("Frame")
if RV.events.RegisterUnitEvent then RV.events:RegisterUnitEvent("UNIT_AURA", "player")
else RV.events:RegisterEvent("UNIT_AURA") end
RV.events:RegisterEvent("PLAYER_ENTERING_WORLD")
RV.events:RegisterEvent("PLAYER_REGEN_ENABLED")
RV.events:RegisterEvent("COMBAT_TEXT_UPDATE")
RV.events:SetScript("OnEvent", function(_, event, unit)
    if event == "COMBAT_TEXT_UPDATE" then
        if RV.Text(unit) then RV.Paint() end
        return
    end
    if event == "UNIT_AURA" and unit ~= "player" then return end
    RV.Paint()
    if event ~= "UNIT_AURA" then RV.Refresh() end
end)

--- `/bish reveal`: is it on you, which id is the buff, what the last read said.
function RV.Status()
    local d = db()
    local pas = {}
    for id in pairs(d.passive) do pas[#pas + 1] = tostring(id) end
    local line = string.format("reveal: up %s | icon %s | the buff's id %s | passive %s | last read: %s | combat text: %s", tostring(RV.Up()),
        tostring(RV.iconSeen or "not built"),
        tostring(d.buff or "not seen yet"), #pas > 0 and table.concat(pas, ", ") or "none", RV.seen or "nothing yet",
        RV.seenText or "nothing heard")
    if NS.Print then NS.Print(line) end
    return line
end
