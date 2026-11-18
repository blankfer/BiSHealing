--[[
  BiSHealing :: Rhythm.lua - THE TARGET RHYTHM TEST, a secret alpha feature (19 Nov 2026).

  Arn, 18 Nov: "we just tell the mages when you need an Innervate, just spam this button and what the druid is gonna see
  is my mage is continuously targeting me and un-targeting me ... that means they are ready for an Innervate." And 19 Nov:
  "build the test tool for the target rhythm".

  WHY. Addon messages HOLD in a fight (the chat lockdown): an ask typed mid-fight leaves the mage's PC only when the fight
  ends. Changing your target is not a message - every client in the group is told about it as part of the game itself
  (UNIT_TARGET, "partyN changed target"). If that event still arrives in a fight, a mage can SAY something with it: three
  target changes inside two seconds = "I need mana now". This file is the experiment that finds out. It proves nothing
  by being written; only two players in a fight can answer it.

  TWO HALVES, both in one small window (`/bish alpha rhythm open`):
    ASK   (the mage)  one SECURE button. Each press flips the target: hostile or none -> `/target <their unit>`, friendly
                      -> `/targetlasttarget` (back to the boss). The choice is made by a secure snippet (a header's
                      WrapScript on the button's OnClick, the wheel-bind road in Mouse.lua) that sets the button's
                      macrotext just before the click runs it - legal in a fight. `SecureCmdOptionParse("[@target,help]")`
                      decides; where the snippet cannot see that call, it simply alternates. Aimed out of a fight only
                      (`/bish alpha rhythm to <name>`; by itself it picks the first druid, alone it aims at you, so one
                      player can test both halves on a training dummy). A key can press it too (`rhythm bind <KEY>`).
    HEAR  (the druid) while the window is open: UNIT_TARGET for you and every party/raid member. Per person, the times of
                      their last target changes; THREE inside TWO seconds = RHYTHM: their row flashes, a sound, one line.
                      Each row also has a lamp ON ME = "their target is me" - UnitIsUnit(theirTarget, "player"), which is
                      SECRET in a fight (solved.md, 14 Nov), so it is handed to SetAlphaFromBoolean, never tested. Even if
                      the event never comes, a lamp blinking on and off IS the rhythm, read by the druid's eye.

  WHAT IT WRITES (the account save, `rhythm.log`, read by Claude after a /reload or logout): one entry per BURST (changes
  with no gap over two seconds): who, in a fight or not, how many, over how long, the shortest and longest gap, whether
  the event's unit came plain, and what "their target is me" answered (plain yes/no or secret). The asker writes its own
  bursts too: clicks, and how many times its own target really changed. Comparing the two answers the open questions:
  does UNIT_TARGET for a party member arrive in a fight, how late, and does a fast run merge into fewer events.

  COST. Closed = nothing registered and nothing ticks. Open = UNIT_TARGET + a lamp repaint every RH.POLL (0.1 s) for at
  most RH.ROWS people. Nothing secret goes into arithmetic, a comparison, an `if` or a table key.
]]
local ADDON, NS = ...

local RH = {}
NS.RH = RH

RH.KEY = "rhythm"
RH.WINDOW = 2            -- seconds: the changes counted together, and the silence that ends a burst
RH.NEED = 3              -- changes inside WINDOW = a rhythm
RH.QUIET = 3             -- seconds before the same person can fire a rhythm again
RH.POLL = 0.1            -- the lamps' repaint while open
RH.FLASH = 1.5           -- seconds a RHYTHM word fades over
RH.KEEP = 80             -- bursts remembered (the oldest go first)
RH.ROWS = 5              -- people shown (you + 4)
RH.SOUND = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959
RH.W, RH.H = 344, 240    -- 1.43 : 1, the family's window shape
RH.PAD = 10

-- The snippet: runs in the client's restricted world, before the button's own click, in or out of a fight.
RH.SNIPPET = [[
    local back
    if SecureCmdOptionParse then
        back = SecureCmdOptionParse("[@target,help] back; go") == "back"
    else
        local n = (self:GetAttribute("bis-n") or 0) + 1
        self:SetAttribute("bis-n", n)
        back = (n % 2 == 0)
    end
    if back then
        self:SetAttribute("macrotext", "/targetlasttarget")
    else
        self:SetAttribute("macrotext", "/target " .. (self:GetAttribute("bis-who") or "player"))
    end
]]

local Print = NS.Print
local function now() return (GetTime and GetTime()) or 0 end
local function wall() return (time and time()) or 0 end
local function combat() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function secret(v) return v ~= nil and NS.Secret and NS.Secret(v) and true or false end
local function plain(v) if v == nil or secret(v) then return nil end return v end

local function db()
    local d = NS.DB()
    d.rhythm = type(d.rhythm) == "table" and d.rhythm or {}
    local r = d.rhythm
    r.log = type(r.log) == "table" and r.log or {}
    return r
end
RH.DB = db

------------------------------------------------------------------------------------------------ who is who

--- The group units, you first: player, party1-4 / raid1-40 (the raid's own entry for you skipped).
function RH.Units()
    local out = { "player" }
    local raid = IsInRaid and IsInRaid()
    local n = raid and ((GetNumGroupMembers and GetNumGroupMembers()) or 0) or 4
    for i = 1, n do
        local u = (raid and "raid" or "party") .. i
        local ok, there = pcall(UnitExists, u)
        local okMe, me = pcall(UnitIsUnit, u, "player")
        if ok and plain(there) and not (okMe and plain(me)) then out[#out + 1] = u end
    end
    return out
end

local WATCH = { player = true }
for i = 1, 4 do WATCH["party" .. i] = true end
for i = 1, 40 do WATCH["raid" .. i] = true end
RH.WATCH = WATCH

--- A name to show: the whole name where the lib gives it, else the client's; a secret or missing one = nil.
function RH.NameOf(unit)
    local lib = rawget(_G, "LibBiSComm")
    if lib and lib.FullName then
        local ok, n = pcall(lib.FullName, unit)
        n = ok and plain(n) or nil
        if type(n) == "string" and n ~= "" then return n end
    end
    local ok, n = pcall(UnitName, unit)
    n = ok and plain(n) or nil
    return type(n) == "string" and n ~= "" and n or nil
end

local function classOf(unit)
    local ok, _, c = pcall(UnitClass, unit)
    return ok and plain(c) or nil
end

--- The unit a typed word means: party1 / raid7 as typed, "me", or the first member whose name starts with it.
function RH.Find(word)
    word = type(word) == "string" and word:match("^%s*(.-)%s*$"):lower() or ""
    if word == "" then return nil end
    if word == "me" or word == "player" then return "player" end
    if word:match("^party%d$") or word:match("^raid%d%d?$") then return word end
    for _, u in ipairs(RH.Units()) do
        local n = RH.NameOf(u)
        if n and n:lower():sub(1, #word) == word then return u end
    end
    return nil
end

--- Who the button asks when nobody was named: the first druid in the group, else the first member, else you.
function RH.Pick()
    local units = RH.Units()
    for i = 2, #units do if classOf(units[i]) == "DRUID" then return units[i] end end
    return units[2] or "player"
end

------------------------------------------------------------------------------------------------ the window

local C = { plate = { 0.09, 0.08, 0.165 }, panel = { 0.12, 0.106, 0.21 }, line = { 0.2, 0.17, 0.33 },
            accent = { 0.725, 0.5, 1 }, teal = { 0.31, 0.82, 0.81 }, gold = { 0.9, 0.75, 0.29 },
            muted = { 0.6, 0.57, 0.72 }, ink = { 0.93, 0.91, 0.96 }, red = { 1, 0.3, 0.3 } }
RH.COL = C

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
    return t
end

--- One HEAR row: name, the ON ME lamp, the count, the RHYTHM word.
local function row(f, i)
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(150, 24)
    r:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RH.PAD, -46 - (i - 1) * 28)
    r.bg = tex(r, "BACKGROUND", C.panel, 1) r.bg:SetAllPoints(r)
    edge(r, C.line)
    r.name = fs(r, 11, C.ink)
    r.name:SetPoint("LEFT", 6, 0)
    r.name:SetWidth(70)
    r.name:SetJustifyH("LEFT")
    r.lamp = CreateFrame("Frame", nil, r)                  -- ON ME: their target is me (alpha from the client)
    r.lamp:SetSize(34, 14)
    r.lamp:SetPoint("LEFT", 78, 0)
    r.lamp.bg = tex(r.lamp, "ARTWORK", C.teal, 1) r.lamp.bg:SetAllPoints(r.lamp)
    r.lamp.word = fs(r.lamp, 9, C.plate) r.lamp.word:SetPoint("CENTER") r.lamp.word:SetText("ON ME")
    r.lamp:SetAlpha(0.12)
    r.count = fs(r, 11, C.muted)
    r.count:SetPoint("RIGHT", -6, 0)
    r.hot = CreateFrame("Frame", nil, r)                   -- RHYTHM, over the row, fading
    r.hot:SetAllPoints(r)
    r.hot.bg = tex(r.hot, "ARTWORK", C.plate, 0.85) r.hot.bg:SetAllPoints(r.hot)
    r.hot.word = fs(r.hot, 13, C.gold, "Fonts\\FRIZQT__.TTF")
    r.hot.word:SetPoint("CENTER")
    r.hot.word:SetText("RHYTHM")
    r.hot:SetAlpha(0)
    r:Hide()
    return r
end

function RH.Build()
    if RH.frame then return RH.frame end
    local f = CreateFrame("Frame", "BiSHealingRhythmWindow", UIParent)
    f:SetSize(RH.W, RH.H)
    local p = db().pos
    if type(p) == "table" and p[1] then f:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    else f:SetPoint("CENTER", UIParent, "CENTER", 0, 160) end
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    -- it holds a secure button: never dragged in a fight (solved.md, 6 Oct)
    f:SetScript("OnDragStart", function(self) if not combat() then self:StartMoving() self.moving = true end end)
    local function stop(self)
        if not self.moving then return end
        self.moving = nil
        self:StopMovingOrSizing()
        local ok, pt, _, rp, x, y = pcall(self.GetPoint, self)
        if ok and pt then db().pos = { pt, rp, x, y } end
    end
    f:SetScript("OnDragStop", stop)
    f:SetScript("OnHide", stop)
    f.bg = tex(f, "BACKGROUND", C.plate, 0.96) f.bg:SetAllPoints(f)
    edge(f, C.line)
    f.title = fs(f, 12, C.accent, "Fonts\\FRIZQT__.TTF")
    f.title:SetPoint("TOPLEFT", RH.PAD, -8)
    f.title:SetText("BiS> healing/rhythm")
    f.tag = fs(f, 9, C.muted)
    f.tag:SetPoint("LEFT", f.title, "RIGHT", 8, 0)
    f.tag:SetText("TEST")
    f.close = CreateFrame("Button", nil, f)
    f.close:SetSize(16, 16)
    f.close:SetPoint("TOPRIGHT", -6, -6)
    f.close.label = fs(f.close, 12, C.muted) f.close.label:SetPoint("CENTER") f.close.label:SetText("x")
    f.close:SetScript("OnClick", function() RH.Close() end)

    -- ASK: the one secure button (hidden header wraps its click)
    f.askHead = fs(f, 10, C.muted)
    f.askHead:SetPoint("TOPLEFT", RH.PAD, -30)
    f.askHead:SetText("ASK - spam this")
    local b = CreateFrame("Button", "BiSHealingRhythm", f, "SecureActionButtonTemplate")
    if b.RegisterForClicks then b:RegisterForClicks("AnyDown") end
    b:SetSize(160, 84)
    b:SetPoint("TOPLEFT", RH.PAD, -46)
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/target player")
    b:SetAttribute("bis-who", "player")
    b.bg = tex(b, "BACKGROUND", C.panel, 1) b.bg:SetAllPoints(b)
    edge(b, C.gold)
    b.word = fs(b, 18, C.gold, "Fonts\\FRIZQT__.TTF")
    b.word:SetPoint("CENTER", 0, 8)
    b.word:SetText("SPAM")
    b.to = fs(b, 10, C.ink)
    b.to:SetPoint("BOTTOM", 0, 10)
    b.hl = tex(b, "HIGHLIGHT", C.gold, 0.12) b.hl:SetAllPoints(b)
    b:SetScript("PreClick", function() RH.Clicked() end)   -- insecure: counts the press, touches nothing secure
    f.ask = b
    if CreateFrame then
        local ok, h = pcall(CreateFrame, "Frame", "BiSHealingRhythmHeader", UIParent, "SecureHandlerBaseTemplate")
        RH.header = ok and h or nil
    end
    local H = RH.header
    RH.wrapped = false
    if H and H.WrapScript then RH.wrapped = pcall(H.WrapScript, H, b, "OnClick", RH.SNIPPET) and true or false end
    f.sent = fs(f, 10, C.muted)
    f.sent:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -6)
    f.sent:SetWidth(160)
    f.sent:SetJustifyH("LEFT")
    f.key = fs(f, 9, C.muted)
    f.key:SetPoint("TOPLEFT", f.sent, "BOTTOMLEFT", 0, -3)
    f.key:SetWidth(160)
    f.key:SetJustifyH("LEFT")

    -- HEAR: a row per person
    f.hearHead = fs(f, 10, C.muted)
    f.hearHead:SetPoint("TOPRIGHT", -RH.PAD, -30)
    f.hearHead:SetWidth(150)
    f.hearHead:SetJustifyH("LEFT")
    f.hearHead:SetText("HEAR - target changes")
    f.rows = {}
    for i = 1, RH.ROWS do f.rows[i] = row(f, i) end

    f.last = fs(f, 10, C.ink)                              -- the newest burst, in words
    f.last:SetPoint("BOTTOMLEFT", RH.PAD, 22)
    f.last:SetWidth(RH.W - 2 * RH.PAD)
    f.last:SetJustifyH("LEFT")
    f.foot = fs(f, 9, C.muted)
    f.foot:SetPoint("BOTTOMLEFT", RH.PAD, 8)
    f.foot:SetText("/bish alpha rhythm to <name> · bind <key> · report")
    f:SetScript("OnUpdate", function(_, e) RH.Tick(tonumber(e) or 0) end)
    f:Hide()
    RH.frame = f
    return f
end

------------------------------------------------------------------------------------------------ ask

--- Aim the button (out of a fight only). nil/"" = pick by itself. Returns the unit, or nil (refused / nobody).
function RH.SetTo(word)
    if combat() then RH.pendingTo = word or true Print("rhythm: aimed when the fight ends") return nil end
    local f = RH.Build()
    local unit
    if word and word ~= "" then
        unit = RH.Find(word)
        if not unit then Print("rhythm: nobody in the group called %s", tostring(word)) return nil end
        db().to = word
    else
        local saved = db().to
        unit = saved and RH.Find(saved) or RH.Pick()
    end
    f.ask:SetAttribute("bis-who", unit)
    f.ask:SetAttribute("macrotext", "/target " .. unit)
    f.ask:SetAttribute("bis-n", 0)
    RH.to = unit
    f.ask.to:SetText("asks " .. (unit == "player" and "you (a test alone)" or (RH.NameOf(unit) or unit)))
    return unit
end

--- A press (PreClick, insecure): the burst's clicks.
function RH.Clicked()
    local t, s = now(), RH.send
    if not s or t - s.last > RH.WINDOW then
        if s then RH.CloseSend() end
        s = { first = t, last = t, n = 0, changes = 0, fight = combat(), to = RH.to }
        RH.send = s
    end
    s.n, s.last = s.n + 1, t
    if combat() then s.fight = true end
    RH.PaintSend()
end

--- My own target really changed (PLAYER_TARGET_CHANGED) - the proof the button did what it was pressed for.
function RH.MyTarget()
    local s = RH.send
    if s and now() - s.last <= RH.WINDOW then s.changes = s.changes + 1 RH.PaintSend() end
end

function RH.CloseSend()
    local s = RH.send
    if not s then return nil end
    RH.send = nil
    local e = { k = "sent", to = s.to and (RH.NameOf(s.to) or s.to) or "?", at = wall(), fight = s.fight, n = s.n,
                changes = s.changes, span = math.floor((s.last - s.first) * 100 + 0.5) / 100 }
    RH.Keep(e)
    return e
end

function RH.PaintSend()
    local f = RH.frame
    if not f then return end
    local s = RH.send
    if s then f.sent:SetText(("pressed %d · target changed %d"):format(s.n, s.changes))
    else f.sent:SetText("press it 3+ times in 2 s") end
    local k = db().bind
    f.key:SetText((k and ("key: " .. k) or "no key - rhythm bind <KEY>") .. (RH.wrapped and "" or "  |cffff5050(no snippet!)|r"))
end

------------------------------------------------------------------------------------------------ hear

RH.seen = {}      -- unit -> { stamps = {t...}, burst = {...}, quietUntil, hotAt }
RH.stat = { events = 0, secretUnit = 0, other = 0 }

--- What "their target is me" answers, as data: the value (secret or plain) and its kind.
function RH.IsMe(unit)
    local tu = unit == "player" and "target" or (unit .. "target")
    local ok, v = pcall(UnitIsUnit, tu, "player")
    if not ok then return nil, "error" end
    if secret(v) then return v, "secret" end
    return v and true or false, v and "yes" or "no"
end

function RH.Heard(unit)
    RH.stat.events = RH.stat.events + 1
    if secret(unit) then RH.stat.secretUnit = RH.stat.secretUnit + 1 return false end
    if type(unit) ~= "string" or not WATCH[unit] then RH.stat.other = RH.stat.other + 1 return false end
    local t = now()
    local s = RH.seen[unit]
    if not s then s = { stamps = {} } RH.seen[unit] = s end
    local b = s.burst
    if b and t - b.last > RH.WINDOW then RH.CloseBurst(unit) b = nil end
    if not b then
        b = { first = t, last = t, n = 0, fight = combat(), isMe = {}, gmin = nil, gmax = 0, name = RH.NameOf(unit) }
        s.burst = b
    else
        local g = math.floor((t - b.last) * 1000 + 0.5)
        b.gmin = (b.gmin == nil or g < b.gmin) and g or b.gmin
        b.gmax = g > b.gmax and g or b.gmax
    end
    b.n, b.last = b.n + 1, t
    if combat() then b.fight = true end
    local v, kind = RH.IsMe(unit)
    b.isMe[kind] = (b.isMe[kind] or 0) + 1
    -- the rhythm: NEED changes inside WINDOW
    local st = s.stamps
    st[#st + 1] = t
    while st[1] and t - st[1] > RH.WINDOW do table.remove(st, 1) end
    s.lastAt = t
    if #st >= RH.NEED and t >= (s.quietUntil or 0) then RH.Rhythm(unit) end
    -- a raid member not in the rows yet takes the stalest place (rows are plain frames: fine in a fight)
    local inRows = false
    for _, u in ipairs(RH.rowUnits or {}) do if u == unit then inRows = true break end end
    if not inRows then RH.rowUnits = nil end
    RH.PaintRows()
    return true
end

--- THREE in TWO seconds from one person: their row flashes, a sound, one line.
function RH.Rhythm(unit)
    local s = RH.seen[unit]
    s.quietUntil, s.hotAt = now() + RH.QUIET, now()
    if s.burst then s.burst.rhythm = true end
    RH.rhythms = (RH.rhythms or 0) + 1
    if db().sound ~= false and PlaySound then pcall(PlaySound, RH.SOUND, "Master") end
    Print("|cffe6c04aRHYTHM|r from %s%s", RH.NameOf(unit) or unit, combat() and " - in a fight" or "")
    return true
end

function RH.CloseBurst(unit)
    local s = RH.seen[unit]
    local b = s and s.burst
    if not b then return nil end
    s.burst = nil
    local e = { k = "heard", who = b.name or unit, unit = unit, at = wall(), fight = b.fight, n = b.n,
                span = math.floor((b.last - b.first) * 100 + 0.5) / 100, gmin = b.gmin, gmax = b.n > 1 and b.gmax or nil,
                isMe = b.isMe, rhythm = b.rhythm, secretUnits = RH.stat.secretUnit }
    RH.Keep(e)
    return e
end

function RH.Keep(e)
    local log = db().log
    log[#log + 1] = e
    while #log > RH.KEEP do table.remove(log, 1) end
    RH.lastEntry = e
    RH.PaintLast()
    return e
end

--- One entry in words.
function RH.Words(e)
    if type(e) ~= "table" then return "" end
    local fight = e.fight and "in a fight" or "out of a fight"
    if e.k == "sent" then
        return ("sent: %d presses to %s in %.2f s, target changed %d - %s"):format(e.n or 0, tostring(e.to), e.span or 0,
            e.changes or 0, fight)
    end
    local me = {}
    for _, k in ipairs({ "yes", "no", "secret", "error" }) do
        if e.isMe and e.isMe[k] then me[#me + 1] = k .. " " .. e.isMe[k] end
    end
    return ("heard: %s changed target %d times in %.2f s%s%s - %s, on me: %s"):format(tostring(e.who), e.n or 0, e.span or 0,
        e.gmin and (", gaps " .. e.gmin .. "-" .. (e.gmax or e.gmin) .. " ms") or "", e.rhythm and ", RHYTHM" or "", fight,
        #me > 0 and table.concat(me, ", ") or "-")
end

function RH.PaintLast()
    local f = RH.frame
    if f then f.last:SetText(RH.lastEntry and RH.Words(RH.lastEntry) or "nothing heard yet") end
end

--- The people in the rows: in a party everyone; in a raid you + whoever changed target last.
function RH.RowUnits()
    local units = RH.Units()
    if #units <= RH.ROWS then return units end
    local rest = {}
    for i = 2, #units do rest[#rest + 1] = units[i] end
    table.sort(rest, function(a, b)
        local sa, sb = RH.seen[a], RH.seen[b]
        return ((sa and sa.lastAt) or 0) > ((sb and sb.lastAt) or 0)
    end)
    local out = { "player" }
    for i = 1, RH.ROWS - 1 do out[#out + 1] = rest[i] end
    return out
end

function RH.PaintRows()
    local f = RH.frame
    if not (f and f:IsShown()) then return end
    RH.rowUnits = RH.rowUnits or RH.RowUnits()
    local t = now()
    for i, r in ipairs(f.rows) do
        local u = RH.rowUnits[i]
        if u then
            local s = RH.seen[u]
            local n = 0
            if s then for _, at in ipairs(s.stamps) do if t - at <= RH.WINDOW then n = n + 1 end end end
            r.name:SetText(u == "player" and "you" or (RH.NameOf(u) or u))
            r.count:SetText(n > 0 and tostring(n) or "")
            r.unit = u
            r:Show()
        else
            r.unit = nil
            r:Hide()
        end
    end
end

--- The lamps (their target is me, the client's answer) and the fading words. Only while the window is open.
function RH.PaintLamps(t)
    local f = RH.frame
    if not f then return end
    t = t or now()
    for _, r in ipairs(f.rows) do
        local u = r.unit
        if u then
            local v, kind = RH.IsMe(u)
            if kind == "secret" then r.lamp:SetAlphaFromBoolean(v, 1, 0.12)
            else r.lamp:SetAlpha(v and 1 or 0.12) end
            local s = RH.seen[u]
            local hot = s and s.hotAt and (t - s.hotAt) or nil
            r.hot:SetAlpha((hot and hot < RH.FLASH) and (1 - hot / RH.FLASH) or 0)
        end
    end
end

function RH.Tick(e)
    RH.acc = (RH.acc or 0) + e
    if RH.acc < RH.POLL then return end
    RH.acc = 0
    local t = now()
    for u, s in pairs(RH.seen) do
        if s.burst and t - s.burst.last > RH.WINDOW then RH.CloseBurst(u) RH.PaintRows() end
    end
    if RH.send and t - RH.send.last > RH.WINDOW then RH.CloseSend() RH.PaintSend() end
    RH.PaintLamps(t)
end

------------------------------------------------------------------------------------------------ open / close

local ev = CreateFrame("Frame")
RH.events = ev

function RH.Listen(on)
    for _, e in ipairs({ "UNIT_TARGET", "PLAYER_TARGET_CHANGED" }) do
        if on then pcall(ev.RegisterEvent, ev, e) else pcall(ev.UnregisterEvent, ev, e) end
    end
end

function RH.Bind(key)
    local f = RH.Build()
    if combat() then Print("rhythm: keys are set out of a fight") return nil end
    if ClearOverrideBindings then pcall(ClearOverrideBindings, f) end
    if key == nil then key = db().bind end
    if type(key) ~= "string" or key == "" or key:lower() == "none" then db().bind = nil RH.PaintSend() return false end
    key = key:upper()
    db().bind = key
    if f:IsShown() and SetOverrideBindingClick then pcall(SetOverrideBindingClick, f, true, key, "BiSHealingRhythm", "LeftButton") end
    RH.PaintSend()
    return key
end

function RH.Open()
    if not (NS.AlphaOn and NS.AlphaOn(RH.KEY)) then Print("rhythm: the alpha is off - /bish alpha on") return false end
    if combat() then RH.pendingOpen = true Print("rhythm: opens when the fight ends") return false end
    local f = RH.Build()
    f:Show()
    RH.Listen(true)
    RH.SetTo(nil)
    RH.rowUnits = nil
    RH.Bind(nil)
    RH.PaintSend()
    RH.PaintRows()
    RH.PaintLast()
    return true
end

function RH.Close()
    if combat() then RH.pendingClose = true Print("rhythm: closes when the fight ends") return false end
    local f = RH.frame
    for u in pairs(RH.seen) do RH.CloseBurst(u) end
    RH.CloseSend()
    RH.Listen(false)
    if f then
        if ClearOverrideBindings then pcall(ClearOverrideBindings, f) end
        f:Hide()
    end
    return true
end

function RH.Report(n)
    local log = db().log
    n = n or 8
    if #log == 0 then Print("rhythm: nothing written yet") return 0 end
    Print("rhythm: the last %d of %d (all in the save after /reload)", math.min(n, #log), #log)
    for i = math.max(1, #log - n + 1), #log do Print("  %s", RH.Words(log[i])) end
    return #log
end

function RH.Command(rest)
    rest = tostring(rest or ""):match("^%s*(.-)%s*$")
    local word, arg = rest:match("^(%S+)%s*(.-)$")
    word = (word or ""):lower()
    if word == "open" or word == "" then return RH.Open()
    elseif word == "close" or word == "stop" then return RH.Close()
    elseif word == "to" then return RH.SetTo(arg ~= "" and arg or nil) ~= nil
    elseif word == "bind" then return RH.Bind(arg ~= "" and arg or "none")
    elseif word == "report" then return RH.Report(tonumber(arg)) > 0
    elseif word == "clear" then db().log = {} RH.lastEntry = nil RH.PaintLast() Print("rhythm: the log is empty") return true
    elseif word == "sound" then db().sound = (arg:lower() ~= "off") Print("rhythm: sound %s", db().sound and "on" or "off") return db().sound
    end
    Print("rhythm: /bish alpha rhythm open | close | to <name> | bind <key>|none | report | clear | sound on|off")
    return false
end

for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_TARGET" then RH.Heard(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then RH.MyTarget()
    elseif event == "GROUP_ROSTER_UPDATE" then
        RH.rowUnits = nil
        if RH.frame and RH.frame:IsShown() then
            if combat() then RH.pendingTo = true else RH.SetTo(nil) end
            RH.PaintRows()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if RH.pendingClose then RH.pendingClose = nil RH.Close()
        elseif RH.pendingOpen then RH.pendingOpen = nil RH.Open() end
        if RH.pendingTo then
            local w = RH.pendingTo
            RH.pendingTo = nil
            if RH.frame and RH.frame:IsShown() then RH.SetTo(type(w) == "string" and w or nil) end
        end
    end
end)

NS.AlphaFeature{ key = RH.KEY, name = "the target rhythm test",
                 desc = "can a mage ask for mana mid-fight by flipping targets? /bish alpha rhythm open (both players)",
                 apply = function() if not NS.AlphaOn(RH.KEY) and RH.frame and RH.frame:IsShown() then RH.Close() end end,
                 cmd = function(rest) return RH.Command(rest) end }
