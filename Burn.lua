--[[ BiSHealing :: Burn.lua (NS.BN) - A WARLOCK HURTING HIMSELF, on his deck box.

  Arn, 20 Nov 2026: "research hellfire i need some sort of indicator when a warlock is doing it" ... "and life tap";
  from the sketch (https://claude.ai/artifact/E4HZeBae4m9j41rcwbooZN) he picked "tag for single cast, 2 for channel":
  - HELLFIRE (a 15 s channel that burns the warlock every second) = THE BURNING BAR: his health bar orange, an orange
    edge round the box, and a pulsing band laid back from the end of his health over what the rest of the channel will
    burn (the client sizes it: max = his max health, handed untouched; value = our own sum, ticks left x one tick).
  - LIFE TAP (instant: health for mana) = THE TAP TAG: "TAP" in amber under his name for BN.TAP_FOR s.

  HOW IT KNOWS, two roads, whichever the client answers (the BiS? probe of 20 Nov asks which):
  - the Hellfire aura by spell id (NS.AnyAuraById - the one aura question that survives the restrictions; a secret or
    hidden answer is "could not tell" and changes nothing);
  - the cast itself: UNIT_SPELLCAST_CHANNEL_START / _STOP and _SUCCEEDED carry the spell id - used only when it is
    PLAIN (a secret id is never compared).
  Only warlocks are looked at (the group's classes are plain), nothing is asked while none is in the group, and the
  half-second repaint runs only while one burns. `/bish burn` says what it last saw.

  The ranks are the classic ids (UNVERIFIED on Forever until the probe names them); a tick's damage comes from the
  spell's own words ("causing 83 Fire damage to himself"), else BN.TICK. ]]
local _, NS = ...
NS = NS or {}
local BN = {}
NS.BN = BN

BN.HELLFIRE = { 1949, 11683, 11684 }                       -- ranks 1-3
BN.TICK = { [1949] = 83, [11683] = 139, [11684] = 208 }   -- one second's burn when the words cannot be read
BN.LENGTH = 15                                             -- seconds of channel
BN.LIFETAP = { [1454] = true, [1455] = true, [1456] = true, [11687] = true, [11688] = true, [11689] = true }
BN.TAP_FOR = 3                                             -- seconds the TAP tag stays
BN.FIRE = { 1.00, 0.42, 0.10 }                             -- the burning bar
BN.BAND = { 1.00, 0.55, 0.15, 0.85 }                       -- what the rest of the channel will burn
BN.AMBER = { 1.00, 0.69, 0.13 }                            -- the TAP tag (he chose it: it waits behind the tank)
BN.EVERY = 0.5                                             -- the repaint while one burns

BN.on = {}                                                 -- unit -> { id, t0 }: Hellfire seen on him
BN.tap = {}                                                -- unit -> GetTime() the TAP tag goes
BN.seen = { aura = "never asked", cast = "never heard" }

local function now() return GetTime and GetTime() or 0 end
local function plain(v) if v == nil or (NS.Secret and NS.Secret(v)) then return nil end return v end
local HELL = {}
for _, id in ipairs(BN.HELLFIRE) do HELL[id] = true end

--- A group token we watch (you, your party, your raid) - never target / nameplates.
function BN.Mine(unit)
    if type(unit) ~= "string" then return false end
    return unit == "player" or unit:match("^party%d$") ~= nil or unit:match("^raid%d+$") ~= nil
end

--- Is this a warlock (a plain answer only)?
function BN.Warlock(unit)
    if not (UnitClass and BN.Mine(unit)) then return false end
    local ok, _, token = pcall(UnitClass, unit)
    return ok and plain(token) == "WARLOCK"
end

--- One second's burn for this rank: the spell's own words first, else the table.
BN.tickCache = {}
function BN.Tick(id)
    if BN.tickCache[id] then return BN.tickCache[id] end
    local n
    local get = C_Spell and C_Spell.GetSpellDescription
    if get then
        local ok, text = pcall(get, id)
        text = ok and plain(text) or nil
        if type(text) == "string" then n = tonumber(text:match("(%d+)%s+[Ff]ire damage")) end
    end
    n = n or BN.TICK[id] or BN.TICK[BN.HELLFIRE[1]]
    BN.tickCache[id] = n
    return n
end

--- What the rest of his channel will burn (a plain number, ours), or nil when he is not burning.
function BN.Left(unit, t)
    local st = BN.on[unit]
    if not st then return nil end
    local ticks = math.max(0, math.ceil(BN.LENGTH - ((t or now()) - st.t0)))
    return ticks * BN.Tick(st.id)
end

local function start(unit, id)
    local st = BN.on[unit]
    if st and st.id == id then return false end
    BN.on[unit] = { id = id, t0 = now() }
    return true
end
local function stop(unit)
    if not BN.on[unit] then return false end
    BN.on[unit] = nil
    return true
end

--- The aura road: which Hellfire rank is on him (true / false / nil = could not tell).
function BN.Look(unit)
    if not BN.Warlock(unit) then return stop(unit) end
    if not NS.AuraById then BN.seen.aura = "no api" return false end
    local answered = true
    for _, id in ipairs(BN.HELLFIRE) do
        local a, why = NS.AuraById(unit, id)
        if a then BN.seen.aura = "read: rank " .. id return start(unit, id) end
        if why ~= "none" then answered = false BN.seen.aura = why or "unknown" end
    end
    if answered then BN.seen.aura = "read: none" return stop(unit) end
    return false                                           -- (hidden: the cast road may still answer)
end

--- The cast road: a plain spell id only.
function BN.Cast(event, unit, id)
    if not BN.Warlock(unit) then return false end
    local sid = plain(id)
    if sid == nil then BN.seen.cast = "hidden id" return false end
    BN.seen.cast = event .. " " .. tostring(sid)
    if HELL[sid] then
        if event == "UNIT_SPELLCAST_CHANNEL_START" then return start(unit, sid) end
        if event == "UNIT_SPELLCAST_CHANNEL_STOP" then return stop(unit) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and BN.LIFETAP[sid] then
        BN.tap[unit] = now() + BN.TAP_FOR
        if NS.CU then NS.CU.Say("tap", unit) end            -- (BiS Cues: Life Tap's sound, off unless picked)
        return true
    end
    return false
end

-- PAINTING ---------------------------------------------------------------------------------------------------------

--- The pieces on one deck box, made on first need: the band, the orange edge, the TAP tag.
function BN.Parts(e)
    if e.burn then return e.burn end
    local B = {}
    local band = CreateFrame("StatusBar", nil, e.bar)
    band:SetPoint("TOPRIGHT", e.bar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)   -- back from the end of his health
    band:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    band:SetStatusBarColor(BN.BAND[1], BN.BAND[2], BN.BAND[3], BN.BAND[4])
    if band.SetReverseFill then band:SetReverseFill(true) end
    band:SetMinMaxValues(0, 1)
    band:SetValue(0)
    if band.SetFrameLevel and e.bar.GetFrameLevel then
        local lvl = e.bar:GetFrameLevel()
        if type(lvl) == "number" then band:SetFrameLevel(lvl + 2) end
    end
    local t = band:GetStatusBarTexture()
    if e.mask and t and t.AddMaskTexture then t:AddMaskTexture(e.mask) end      -- only over the health he has
    if band.CreateAnimationGroup then
        local ag = band:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(1) a:SetToAlpha(0.35) a:SetDuration(0.45)
        ag:SetLooping("BOUNCE")
        B.pulse = ag
    end
    band:Hide()
    B.edges = {}
    for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1.5 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1.5 },
                           { "TOPLEFT", "BOTTOMLEFT", 1.5, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1.5, 0 } }) do
        local x = e.box:CreateTexture(nil, "OVERLAY", nil, 6)
        x:SetColorTexture(BN.FIRE[1], BN.FIRE[2], BN.FIRE[3], 1)
        x:SetPoint(pts[1], e.box, pts[1], 0, 0)
        x:SetPoint(pts[2], e.box, pts[2], 0, 0)
        if pts[3] > 0 then x:SetWidth(pts[3]) else x:SetHeight(pts[4]) end
        x:Hide()
        B.edges[i] = x
    end
    local tag = e.box:CreateFontString(nil, "OVERLAY")
    tag:SetFont("Fonts\\ARIALN.TTF", 9, "OUTLINE")
    BN.PlaceTag(tag, e.box)                                  -- under the callsign, in Life Tap's square of the cue row
    tag:SetTextColor(BN.AMBER[1], BN.AMBER[2], BN.AMBER[3], 1)
    tag:SetText("TAP")
    tag:Hide()
    B.band, B.tag = band, tag
    if NS.CU and NS.CU.Face then                              -- the card's look for Life Tap: the icon or a model in its square
        B.tapFace = NS.CU.Face(e.box, "tap", BN.FLAME.px)
        BN.PlaceFace(B.tapFace, e.box)
    end
    e.burn = B
    return B
end

--- Paint one deck box's burn and tap (after EN.Paint has painted it; `mx` = his max health, untouched).
function BN.Paint(sp, mx)
    local e = sp and sp.en
    if not (e and sp.unit) then return false end
    local unit, t = sp.unit, now()
    local left = BN.Sw("hell") and BN.Left(unit, t) or nil
    local tapOn = BN.Sw("tap") and BN.tap[unit] and BN.tap[unit] > t or false
    -- a box too small for the line under the name: the extra tags go first (Radar.lua RD.BoxRoom, BiS Cues sheet 7)
    if tapOn and NS.RD and NS.RD.BoxHas and not NS.RD.BoxHas(sp, "extras") then tapOn = false end
    if not left and not tapOn and not e.burn then return false end   -- (nothing made for a box that never burned)
    local B = BN.Parts(e)
    if left then
        e.bar:SetStatusBarColor(BN.FIRE[1], BN.FIRE[2], BN.FIRE[3], 1)
        local w, h
        if sp.heal then w = sp.heal:GetWidth() h = sp.heal:GetHeight() end
        if type(w) == "number" and type(h) == "number" and w > 2 and h > 2 then B.band:SetSize(w - 2, h - 2) end
        if mx ~= nil then pcall(B.band.SetMinMaxValues, B.band, 0, mx) end
        B.band:SetValue(left)
        if not B.band:IsShown() then B.band:Show() if B.pulse then B.pulse:Play() end end
    elseif B.band:IsShown() then
        B.band:Hide()
        if B.pulse then B.pulse:Stop() end
    end
    for _, x in ipairs(B.edges) do x:SetShown(left ~= nil) end
    local faced = NS.CU and NS.CU.FaceShow(B.tapFace, tapOn) or false
    if tapOn and not faced then B.tag:Show() else B.tag:Hide() end
    if not tapOn then BN.tap[unit] = nil end
    return left ~= nil or tapOn
end

--- Repaint the deck boxes showing this unit.
function BN.Repaint(unit)
    local RD, EN = NS.RD, NS.EN
    if not (RD and EN and EN.Paint) then return end
    for _, sp in ipairs(RD.spokes or {}) do
        if sp.unit == unit and sp.en then EN.Paint(sp) end
    end
end

--- The half-second beat, only while somebody burns or a tag shows.
function BN.Busy()
    return next(BN.on) ~= nil or next(BN.tap) ~= nil
end
function BN.Beat()
    if BN.ticker or not BN.Busy() then return end
    if not (C_Timer and C_Timer.NewTicker) then return end
    BN.ticker = C_Timer.NewTicker(BN.EVERY, function()
        local t = now()
        for unit, st in pairs(BN.on) do
            if t - st.t0 > BN.LENGTH + 1 then BN.on[unit] = nil end   -- (a missed stop: the channel cannot outlast this)
            BN.Repaint(unit)
        end
        for unit in pairs(BN.tap) do BN.Repaint(unit) end
        if not BN.Busy() and BN.ticker then BN.ticker:Cancel() BN.ticker = nil end
    end)
end

-- EVENTS -----------------------------------------------------------------------------------------------------------

BN.events = CreateFrame("Frame")
function BN.Any()
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    if BN.Warlock("player") then return true end
    local raid = IsInRaid and IsInRaid()
    for i = 1, (raid and n or math.max(0, n - 1)) do
        if BN.Warlock((raid and "raid" or "party") .. i) then return true end
    end
    return false
end
--- Listen only while a warlock is with you.
function BN.Arm()
    local f = BN.events
    local want = BN.Any()
    if want == BN.armed then return want end
    BN.armed = want
    for _, ev in ipairs({ "UNIT_AURA", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SUCCEEDED" }) do
        if want then f:RegisterEvent(ev) else f:UnregisterEvent(ev) end
    end
    if not want then BN.on, BN.tap = {}, {} end
    return want
end
BN.events:RegisterEvent("GROUP_ROSTER_UPDATE")
BN.events:RegisterEvent("PLAYER_ENTERING_WORLD")
BN.events:SetScript("OnEvent", function(_, event, unit, guid, id)
    if event == "PLAYER_ENTERING_WORLD" then BN.quietUntil = (GetTime and GetTime() or 0) + 5 end
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        BN.on, BN.tap = {}, {}                             -- (tokens move when the group changes)
        BN.Arm()
        return
    end
    if not BN.Mine(unit) then return end
    local changed
    if event == "UNIT_AURA" then changed = BN.Look(unit) else changed = BN.Cast(event, unit, id) end
    if changed then BN.Repaint(unit) BN.Beat() end
end)

--[[ THE GAME DRAWS IT (20 Nov 2026, Arn: "was not able to see warlock hf" - the road Revelation proved in Zul'Farrak the
  same night: in a fight the game hides a buff from us but still DRAWS it). Each deck box of a warlock gets an
  AuraContainer on his unit with one slot per filter, filtered to Hellfire's ids; the client hands us the button while he
  wears it, and we dress it as THE BURNING BOX: sized over his whole box, an orange wash (his bar burns orange), an orange
  edge, and HELLFIRE in its corner. Nothing of ours decides; the client shows it while the buff is there. Built and
  pointed at his unit out of a fight only. ]]
BN.DRAW_IDS = {}
for _, id in ipairs(BN.HELLFIRE) do BN.DRAW_IDS[id] = true end
BN.FLAME = { px = 22, x = 3, y = -14, model = 198692, cam = 1.6, spin = 1.5 }   -- the fire square under his callsign
-- THE VOICE (the games' road: the PC's own voice, C_VoiceChat.SpeakText - heard on Forever 17 Nov): "Hellfire" when the
-- game shows his burning box, at most once every `every` s a box; db().radar.burnVoice = false keeps it quiet.
BN.VOICE = { text = "Hellfire", every = 12, rate = 0, volume = 100 }
BN.spoke = {}
--- A switch on the deck's panel (RD.SW; nil = on).
function BN.Sw(key) local RD = NS.RD return not (RD and RD.Sw) or RD.Sw(key) end
BN.quietUntil = 0                                          -- (a /reload re-makes the buttons: no voice for a moment after it)
--- The voice's words: "Hellfire, Tin" - his callsign when the game says it plainly, else just the spell (Arn, 21 Nov: "how
--- fire, which warlock, I would have to look through all of them to find it").
function BN.Words(unit)
    local name
    if type(unit) == "string" and GetUnitName then
        local ok, n = pcall(GetUnitName, unit, false)
        n = ok and plain(n) or nil
        -- his first name, in normal case ("TIN" would be spelled out letter by letter by the voice)
        if type(n) == "string" then name = (n:match("^(%S+)") or n):lower():gsub("^%l", string.upper) end
    end
    if type(name) == "string" and name ~= "" then return BN.VOICE.text .. ", " .. name end
    return BN.VOICE.text
end
function BN.Speak(key, unit)
    local t = GetTime and GetTime() or 0
    -- BiS Cues (21 Nov 2026): Hellfire's sound is the cue card's pick - the voice with his name (as before), the voice,
    -- a game sound, or off
    if NS.CU then
        if t < BN.quietUntil then return false end
        return NS.CU.Say("hell", unit)
    end
    local d = NS.DB and NS.DB().radar
    if (d and d.burnVoice == false) or not BN.Sw("hellvoice") or not BN.Sw("hell") then return false end
    if t < BN.quietUntil then return false end
    if key and BN.spoke[key] and t - BN.spoke[key] < BN.VOICE.every then return false end
    if key then BN.spoke[key] = t end
    if not (C_VoiceChat and C_VoiceChat.SpeakText) then return false end
    local ok = pcall(C_VoiceChat.SpeakText, 0, BN.Words(unit), BN.VOICE.rate, BN.VOICE.volume)
    BN.said = (BN.said or 0) + 1
    return ok
end
local function fightNow() return (InCombatLockdown and InCombatLockdown()) and true or false end

--- Dress the client's button as the burning box over `box` (inside initializeFrame - the one place it may be placed).
function BN.BadgeOn(button, box, pip, sp)
    if not (button and box) then return end
    local F = BN.FLAME
    -- (21 Nov 2026, Arn: "can we just add a 3d model of fire under their name with 15s numbers?" - the burning border is
    -- gone: a small square under his callsign, the Hellfire icon under a turning 3D fireball, the client's own countdown)
    -- (BiS Cues: its square in the cue row, in the cue order - CU.SquareXY)
    local x, y = F.x, F.y
    if NS.CU then x, y = NS.CU.SquareXY("hell", F.px) end
    local placed = pcall(function()
        button:SetSize(F.px, F.px)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
    end)
    if not placed then BN.drawSeen = "button refused" return end
    BN.badges[#BN.badges + 1] = { button = button, box = box }
    pcall(function()
        if button.GetRegions then
            for _, r in ipairs({ button:GetRegions() }) do if r.SetTexture and r.Hide then r:Hide() end end
        end
        for _, k in ipairs({ "Icon", "icon", "Border", "border", "Count", "count", "Cooldown" }) do
            local part = button[k]
            if type(part) == "table" and part.Hide then part:Hide() end
        end
        if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
        if button.EnableMouse then button:EnableMouse(false) end   -- (his box's clicks stay his box's)
        -- under a model: a dark square (the fire reads on it); for the "icon" look: Hellfire's own icon
        local dark = button:CreateTexture(nil, "BACKGROUND", nil, -1)
        dark:SetAllPoints(button)
        dark:SetColorTexture(0, 0, 0, 0.75)
        button.bisDark = dark
        local icon = button:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints(button)
        if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        local get = C_Spell and C_Spell.GetSpellTexture
        if get then
            local ok, tex = pcall(get, BN.HELLFIRE[1])
            if ok and tex then pcall(icon.SetTexture, icon, tex) end
        end
        button.bisIcon = icon
        -- the 3D fire: the model census's small fireball (mh_fireball_high_01), turning
        local okM, m = pcall(CreateFrame, "PlayerModel", nil, button)
        if okM and m then
            m:SetAllPoints(button)
            if NS.CU then NS.CU.ModelReady(m)                 -- (BN.Relook dresses it: loaded at every showing)
            else
                pcall(m.SetModel, m, F.model)
                if m.SetCamDistanceScale then pcall(m.SetCamDistanceScale, m, F.cam) end
            end
            if m.SetScript then
                m.bisYaw = 0
                m:SetScript("OnUpdate", function(self, el)
                    self.bisYaw = (self.bisYaw + (tonumber(el) or 0) * F.spin) % 6.2832
                    pcall(self.SetFacing, self, self.bisYaw)
                end)
            end
            button.bisModel = m
        end
        -- the seconds left, written by the client (the aura's duration is secret to us; its cooldown is not ours to read)
        if type(button.SetDurationCooldown) == "function" then
            local ok, cd = pcall(CreateFrame, "Cooldown", nil, button, "CooldownFrameTemplate")
            if ok and cd then
                cd:SetAllPoints(button)
                if cd.SetDrawSwipe then cd:SetDrawSwipe(false) end
                if cd.SetDrawEdge then cd:SetDrawEdge(false) end
                if cd.SetDrawBling then cd:SetDrawBling(false) end
                if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
                if cd.SetFrameLevel and button.GetFrameLevel then
                    local lvl = button:GetFrameLevel()
                    if type(lvl) == "number" then cd:SetFrameLevel(lvl + 3) end
                end
                pcall(button.SetDurationCooldown, button, cd)
                button.bisCount = cd
            end
        end
        -- the cue card's LOOK as the word: FIRE in white on a dark square (made now, shown by BN.Relook)
        local w = button:CreateFontString(nil, "OVERLAY")
        w:SetFont("Fonts\\ARIALN.TTF", 9, "OUTLINE")
        w:SetPoint("CENTER", button, "CENTER", 0, 0)
        w:SetText(NS.CU and NS.CU.Word("hell") or "FIRE")
        button.bisWord = w
        -- the voice when the game SHOWS the button (Arn: "everytime i reload it says hellfire" - the client makes the
        -- button ahead of time, at the reload; made is not shown)
        if button.HookScript then pcall(button.HookScript, button, "OnShow", function() BN.Speak(box, sp and sp.unit) end) end
    end)
    BN.Relook(button)
    BN.drawn = (BN.drawn or 0) + 1
end

--- BiS Cues: the badges made so far (each the client's button, kept to re-place and re-dress out of a fight).
BN.badges = {}
--- Dress one badge (or all) in the cue card's look: the turning model, the spell's icon, or the word.
function BN.Relook(button)
    local CU = NS.CU
    local look = CU and CU.Look("hell") or "model"
    local model = CU and CU.ModelOf("hell") or (not CU and BN.FLAME.model) or nil
    local list = button and { { button = button } } or BN.badges
    for _, b in ipairs(list) do
        local btn = b.button
        if btn.bisModel then
            if CU then CU.Wear(btn.bisModel, model)
            elseif model then pcall(btn.bisModel.SetModel, btn.bisModel, model) end
        end
        -- (the game's button may be forbidden to us by now: CU.Touch takes the refusal)
        local function set(part, on) if part and CU then CU.Touch(part, on and "Show" or "Hide") end end
        -- the spell's icon only for the "icon" look (Arn, 21 Nov: "the hellfire spell icon comes out when i choose fireball
        -- too" - it sat under the fireball as a fallback); a model stands on its own dark square
        set(btn.bisIcon, look == "icon")
        set(btn.bisDark, model and look ~= "icon")
        set(btn.bisWord, look == "word")
    end
    return #list
end
--- Out of a fight: every badge to its square in the cue order, and the TAP tags with them. Answers how many moved.
function BN.Relayout()
    if fightNow() then return 0 end
    local n = 0
    local F = BN.FLAME
    local x, y = F.x, F.y
    if NS.CU then x, y = NS.CU.SquareXY("hell", F.px) end
    for _, b in ipairs(BN.badges) do
        if pcall(function() b.button:ClearAllPoints() b.button:SetPoint("TOPLEFT", b.box, "TOPLEFT", x, y) end) then n = n + 1 end
    end
    BN.Relook()
    -- a new look or place: fresh containers, dressed in their own creation window (the old buttons may refuse both)
    local sig = (NS.CU and NS.CU.Look("hell") or "") .. ":" .. x .. ":" .. y
    if BN.sig and BN.sig ~= sig then BN.Rebuild() end
    BN.sig = sig
    for _, sp in ipairs((NS.RD and NS.RD.spokes) or {}) do
        local B = sp.en and sp.en.burn
        if B and B.tag then
            BN.PlaceTag(B.tag, sp.en.box)
            if B.tapFace then BN.PlaceFace(B.tapFace, sp.en.box) end
        end
    end
    return n
end
--- Every game-drawn Hellfire made again, out of a fight.
function BN.Rebuild()
    if fightNow() then return 0 end
    local n = 0
    for _, sp in ipairs((NS.RD and NS.RD.spokes) or {}) do
        local c = sp.burnC
        if c then
            if c.SetEnabled then pcall(c.SetEnabled, c, false) end
            if c.Hide then pcall(c.Hide, c) end
            sp.burnC, sp.burnUnit = nil, nil
            n = n + 1
        end
    end
    if n == 0 then return 0 end
    BN.badges = {}
    for _, sp in ipairs((NS.RD and NS.RD.spokes) or {}) do if sp.unit and sp.en then BN.Container(sp) end end
    return n
end
function BN.PlaceFace(face, box)
    local x, y = NS.CU.SquareXY("tap", BN.FLAME.px)
    face.sq:ClearAllPoints()
    face.sq:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
end
--- The TAP tag in Life Tap's square of the cue row.
function BN.PlaceTag(tag, box)
    local x, y = 4, -15
    if NS.CU then x, y = NS.CU.SquareXY("tap", BN.FLAME.px) x, y = x + 1, y - 1 end
    tag:ClearAllPoints()
    tag:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
end

--- The flash: the client's second button over his whole box, a bright edge that fades out in `flashT` s each time it shows.
BN.FLASH = { px = 3, col = { 1, 0.95, 0.7, 1 }, flashT = 3 }
function BN.FlashOn(button, box, pip)
    if not (button and box) then return end
    local placed = pcall(function()
        local w, h = box:GetWidth(), box:GetHeight()
        if not (type(w) == "number" and w > 2) and pip then w, h = pip:GetWidth() - 2, pip:GetHeight() - 2 end
        button:SetSize(type(w) == "number" and w > 2 and w or 60, type(h) == "number" and h > 2 and h or 40)
        button:ClearAllPoints()
        button:SetPoint("CENTER", box, "CENTER", 0, 0)
    end)
    if not placed then return end
    pcall(function()
        if button.GetRegions then
            for _, r in ipairs({ button:GetRegions() }) do if r.SetTexture and r.Hide then r:Hide() end end
        end
        for _, k in ipairs({ "Icon", "icon", "Border", "border", "Count", "count", "Cooldown" }) do
            local part = button[k]
            if type(part) == "table" and part.Hide then part:Hide() end
        end
        if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
        if button.EnableMouse then button:EnableMouse(false) end
        local Fl = BN.FLASH
        local hold = CreateFrame("Frame", nil, button)
        hold:SetAllPoints(button)
        for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, Fl.px }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, Fl.px },
                             { "TOPLEFT", "BOTTOMLEFT", Fl.px, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", Fl.px, 0 } }) do
            local t = hold:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(Fl.col[1], Fl.col[2], Fl.col[3], Fl.col[4])
            t:SetPoint(e[1], hold, e[1], 0, 0)
            t:SetPoint(e[2], hold, e[2], 0, 0)
            if e[3] > 0 then t:SetWidth(e[3]) else t:SetHeight(e[4]) end
        end
        if hold.CreateAnimationGroup then
            local ag = hold:CreateAnimationGroup()
            local a = ag:CreateAnimation("Alpha")
            a:SetFromAlpha(1) a:SetToAlpha(0) a:SetDuration(Fl.flashT)
            if ag.SetToFinalAlpha then ag:SetToFinalAlpha(true) end
            button.bisFlash = ag
            if button.HookScript then pcall(button.HookScript, button, "OnShow", function() ag:Stop() ag:Play() end) end
            ag:Play()
        end
    end)
end

--- His box's container: made on first need, pointed at his unit, off when the box is somebody else (out of a fight).
function BN.Container(sp)
    local FA, e = NS.FA, sp and sp.en
    if not (e and e.box and FA and FA.Available and FA.Available() and FA.AddSlot) or fightNow() then return nil end
    local warlock = BN.Warlock(sp.unit) and BN.Sw("hell")
    local c = sp.burnC
    if not c then
        if not warlock then return nil end
        local ok, made = pcall(CreateFrame, "AuraContainer", nil, e.box, "CustomAuraContainerTemplate")
        if not ok or not made then BN.drawSeen = "refused" return nil end
        c = made
        c:SetAllPoints(e.box)
        local lvl = e.box.GetFrameLevel and e.box:GetFrameLevel()
        if type(lvl) == "number" and c.SetFrameLevel then c:SetFrameLevel(lvl + 5) end
        local box, pip = e.box, sp.heal
        local init = function(button) BN.BadgeOn(button, box, pip, sp) end
        local flash = function(button) BN.FlashOn(button, box, pip) end
        -- HELPFUL ONLY (21 Nov 2026, Arn: "he was not hellfiring in those pictures" - a HARMFUL slot beside it lit his box
        -- in Zul'Farrak with no Hellfire up: the debuff side seems to show ANY debuff, filter or not; Hellfire is his own
        -- channel - a buff on him)
        local a = FA.AddSlot(c, "BiSHealHellfireBuff", "HELPFUL", { candidateFilters = { includeSpellIDs = BN.DRAW_IDS }, initializeFrame = init })
        -- a second button for the same buff: his whole box flashes as it starts (Arn: "his box jumps out")
        FA.AddSlot(c, "BiSHealHellfireFlash", "HELPFUL", { candidateFilters = { includeSpellIDs = BN.DRAW_IDS }, initializeFrame = flash })
        if not a then BN.drawSeen = "no slot" return nil end
        sp.burnC = c
        BN.drawSeen = "built"
    end
    if sp.burnUnit ~= sp.unit or c.bisOn ~= warlock then
        sp.burnUnit = sp.unit
        if warlock then pcall(c.SetUnit, c, sp.unit) end
        if c.SetEnabled then pcall(c.SetEnabled, c, warlock) end
        c.bisOn = warlock
    end
    return c
end

-- EN.Paint paints the box; the burn goes on top of it.
local EN = NS.EN
if EN and EN.Paint then
    local paint = EN.Paint
    EN.Paint = function(sp, ...)
        local done = paint(sp, ...)
        -- the game-drawn burning box: only while a warlock is with you, and only re-pointed when the box changed hands
        if done and BN.armed and sp and sp.unit and (not sp.burnC or sp.burnUnit ~= sp.unit or sp.burnC.bisOn ~= BN.Sw("hell"))
            and not fightNow() then BN.Container(sp) end
        if done and sp and sp.unit and (BN.on[sp.unit] or BN.tap[sp.unit] or (sp.en and sp.en.burn)) then
            local okM, mx = pcall(UnitHealthMax, sp.unit)
            BN.Paint(sp, okM and mx or nil)
        end
        return done
    end
end

--- `/bish burn`: what it last saw, for the probe round.
function BN.Status()
    local who = {}
    for unit, st in pairs(BN.on) do who[#who + 1] = unit .. " rank " .. st.id end
    local line = string.format("burn: listening %s | Hellfire on: %s | aura road: %s | cast road: %s | game draws it: %s (%d drawn)",
        tostring(BN.armed and true or false), #who > 0 and table.concat(who, ", ") or "nobody", BN.seen.aura, BN.seen.cast,
        tostring(BN.drawSeen or "not built"), BN.drawn or 0)
    if NS.Print then NS.Print(line) end
    return line
end
