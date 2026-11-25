--[[ BiSHealing :: Cues.lua (NS.CU) - BiS CUES: one card for every cue.

  Arn, 21 Nov 2026 ("BiS Cues" - his name), picks off the mockups page (https://claude.ai/artifact/SRPu9GtcPkqoErXpt1GtQS):
  1 the cue card yes, 2 previews C, 4 Hellfire A (the 3D fireball), 5 the explorer + its string yes, 7 "can re order in game".
  The plan and the string's format: dev/CUES.md (the browser explorer, Explorer/BiSCues.html, reads and writes the same).

  - CU.LIST: every cue. A SQUARE cue (Hellfire, Life Tap) sits in the cue row under a box's name, one fixed square each,
    left to right in the cue order (CU.SquareXY) - a square stays put while its cue is quiet, so nothing jumps mid-fight.
    A MIDDLE cue (Riptide -> "Chain Heal", Oath, Vigil, Swiftmend) keeps its place in the middle of the bar; a BAR cue
    (Revelation's CRIT) keeps its place on the synergy bar.
  - Saved per character in db().radar.cues = { v, order, on, look, sound } (dev/CUES.md). A cue is OFF by default for a new
    player; whoever had the deck before keeps what the deck's own switches said (CU.Stamp, once).
  - The deck's switches for these cues (RD.Sw "hell", "tap", "crit", "rip", "oath", "vigil", "swift", and "hellvoice") read
    and write HERE (CU.Wrap) - one truth, so the switches panel and the card can never disagree.
  - LOOK: "icon" | "word" | "model:<file id>" (CU.LOOKS, only models proven to draw). VOICE: "off" | "spell" | "name"; SOUND:
    "kit:<id>" | "off" (CU.SOUNDS; game sound kits play on Forever, 23 Oct). CU.Say plays a cue's sound, at most once every
    CU.EVERY s for the same cue on the same box.
  - THE CARD (CU.Card): beside the switches panel - the order list (tick = on, up / down arrows move its square), the
    chosen cue's preview box (a drawn deck box wearing the pick), the LOOK and SOUND pickers (search, category chips, a
    list the wheel scrolls), TRY, BACK TO DEFAULT, EXPORT / IMPORT. Order and look changes are laid out out of a fight.
  - THE STRING: CU.Export() / CU.Import(s) - "BiSCues1p:" + base64(JSON) (plain, ours, no client call), and "BiSCues1:"
    (gzip) read through C_EncodingUtil when the client has it. UNTESTED LIVE: the client's gzip against the browser's -
    until a probe says they match, we EXPORT the plain form. `/bish cues`, `/bish export`, `/bish import`. ]]
local _, NS = ...
NS = NS or {}
local CU = {}
NS.CU = CU

CU.EVERY = 12                                       -- the same cue on the same box speaks at most this often
CU.LIST = {
    { key = "hell",  name = "Hellfire",    cat = "YOUR GROUP", kind = "square", spell = 1949,  word = "FIRE",
      look = "model:198692", sound = "off", voice = "name", say = "Hellfire",
      tip = "A warlock in your group burning himself with Hellfire. The game draws it, even in a fight." },
    { key = "tap",   name = "Life Tap",    cat = "YOUR GROUP", kind = "square", spell = 1454,  word = "TAP",
      look = "word", sound = "off", say = "Life Tap",
      tip = "A warlock trading health for mana. Only when the game shows his cast (often not in a fight)." },
    { key = "crit",  name = "Revelation",  cat = "YOUR PROCS", kind = "bar",    spell = 1323418, word = "CRIT",
      look = "word", sound = "off", say = "Crit",
      tip = "The Revelation weapon enchant: your next spell will crit. On the synergy bar." },
    { key = "rip",   name = "Riptide",     cat = "SHAMAN",     kind = "middle", spell = "Riptide", word = "Chain Heal",
      look = "word", sound = "off", say = "Chain Heal",
      tip = "Whoever carries your Riptide: your Chain Heal lands harder there." },
    { key = "oath",  name = "Oath of Light", cat = "PALADIN",  kind = "middle", spell = "Holy Light", word = "Holy Light",
      look = "word", sound = "off", say = "Holy Light",
      tip = "Whoever carries your Oath of Light: your heals land harder there." },
    { key = "vigil", name = "Light's Vigil", cat = "PALADIN",  kind = "middle", spell = "Holy Shock", word = "Holy Shock",
      look = "word", sound = "off", say = "Holy Shock",
      tip = "Whoever carries your Light's Vigil: that Holy Shock skips its cooldown and heals their party." },
    { key = "swift", name = "Swiftmend",   cat = "DRUID",      kind = "middle", spell = "Swiftmend", word = "Swiftmend",
      look = "word", sound = "off", say = "Swiftmend",
      tip = "Whoever carries your Rejuvenation or Regrowth while Swiftmend is ready." },
    -- HEAL PAST THE LINE (HealPast.lua, 24 Nov 2026 - Arn picked sketch C): every healer's, so no class
    { key = "past",  name = "Heal past the line", cat = "DEBUFFS", kind = "line", spell = 1271761, word = "90%",
      look = "icon", sound = "off", say = "Heal past",
      tip = "A debuff that wants them healed above a line (Grievous Garrote: 90%). The line on their bar, the gap you owe in red, the debuff's icon, the edge pulsing until they are past it." },
    -- WHAT TO DO ABOUT A DEBUFF (DebuffCues.lua, 24 Nov 2026 - Arn's pick: one word across the bar, icons after the name)
    { key = "cure",   name = "Cure it",        cat = "DEBUFFS", kind = "line", word = "CURE", look = "word", sound = "off", say = "Cure",
      needCure = true, tip = "A debuff the guides say to dispel now, of a type YOUR cures remove: CURE across their bar." },
    { key = "nocure", name = "Don't cure it",  cat = "DEBUFFS", kind = "line", word = "NO CURE", look = "word", sound = "off", say = "Don't cure",
      needCure = true, tip = "A debuff that does something bad when removed (Hyjal's Lunar / Umbral Mark): NO CURE across their bar." },
    { key = "reduce", name = "Heals weaker",   cat = "DEBUFFS", kind = "line", word = "-50%", look = "word", sound = "off", say = "Heals weaker",
      tip = "Mortal Strike and friends: how much healing they lose (-50%) across their bar, the icon after their name." },
    { key = "noheal", name = "No heals land",  cat = "DEBUFFS", kind = "line", word = "NO HEAL", look = "word", sound = "off", say = "No heal",
      tip = "Direct heals do nothing on them right now (Veil of Darkness): NO HEAL across their bar." },
    { key = "mc",     name = "Mind controlled", cat = "DEBUFFS", kind = "line", word = "MIND CONTROL", look = "word", sound = "off", say = "Mind control",
      tip = "A friend the game now lets you attack: MIND CONTROL across their bar. Not on the target boxes or pets." },
    { key = "armor",  name = "Tank armor",     cat = "DEBUFFS", kind = "line", spell = 16177, word = "AF", look = "icon", sound = "off", say = "Armor",
      tip = "Ancestral Fortitude / Inspiration, whoever's crit gave it: the icon after the name - on everyone (the tanks are who it is for)." },
}
CU.BY = {}
local CLASS_CAT = { SHAMAN = true, PALADIN = true, DRUID = true, PRIEST = true }
for i, c in ipairs(CU.LIST) do
    c.i = i
    CU.BY[c.key] = c
    if CLASS_CAT[c.cat] then c.class = c.cat end      -- (a class's own cue: only that class can act on it)
end

-- ONLY WHAT YOU CAN ACT ON (Arn, 21 Nov: "smartly when its the real one we wont see ones that arent our class that we
-- cant act on like oath and light vigil"): the card lists a class cue to that class only. The browser explorer shows
-- them all (anyone may set up anyone's); `/bish cues all` shows them all here too until the next reload, for testing
-- (not the secret alpha: Arn tests with it on, and would never see the class filter work).
function CU.MyClass()
    if not UnitClass then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    if not ok or token == nil or (NS.Secret and NS.Secret(token)) then return nil end
    return token
end
function CU.ForMe(key)
    local q = CU.BY[key]
    if not q then return false end
    if CU.showAll then return true end
    -- a cure cue only for someone with a cure (Arn: "all stuff that our class can do")
    if q.needCure and NS.FA and NS.FA.Cures and #NS.FA.Cures() == 0 then return false end
    if not q.class then return true end
    local mine = CU.MyClass()
    return mine == nil or mine == q.class                 -- (class unknown: show it rather than hide it)
end
--- The cues the card lists, in row order.
function CU.Shown()
    local out = {}
    for _, k in ipairs(CU.Order()) do if CU.ForMe(k) then out[#out + 1] = k end end
    return out
end
-- the looks: only what is known to draw (the model census proves each one first)
CU.LOOKS = {
    { id = "icon", name = "Spell icon", cat = "Icon" },
    { id = "word", name = "Payoff word", cat = "Icon" },
    { id = "model:198692", name = "Fireball", cat = "Fire" },
}
-- SOUND AND VOICE ARE TWO PICKS (Arn, 21 Nov: "yes make sound and voice separate" - one pick meant Lightning crack took the
-- name's place)
CU.VOICES = {
    { id = "off", name = "OFF" },
    { id = "spell", name = "SPELL" },
    { id = "name", name = "SPELL + NAME" },
}
CU.SOUNDS = {
    { id = "kit:8959", name = "Raid warning", cat = "Bells" },
    { id = "kit:8960", name = "Ready check", cat = "Bells" },
    { id = "kit:3090", name = "Thunder", cat = "Storm" },
    { id = "kit:1506", name = "Lightning crack", cat = "Storm" },
    { id = "kit:6161", name = "Devilsaur roar", cat = "Creatures" },
    { id = "off", name = "Off", cat = "Off" },
}
CU.SQUARE = { x = 3, y = -14, gap = 2, px = 22 }    -- the cue row under the callsign (RD.DECK_TAG y -4, size 9)
CU.MODEL_CAM = 1.6                                  -- a model's camera distance in a square (BN.FLAME.cam)
CU.VOICE = { rate = 0, volume = 100 }

local function fight() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function plain(v) if v == nil or (NS.Secret and NS.Secret(v)) then return nil end return v end
local function say(msg) if NS.Print then NS.Print(msg) end end

--- What an old single pick (the voice or a game sound, one or the other) means as two: sound, voice.
function CU.Split(sd)
    if sd == "voicename" then return nil, "name" end
    if sd == "voice" then return nil, "spell" end
    if type(sd) == "string" then return sd, "off" end
    return nil, nil
end

--- The saved table (per character, beside the deck's own settings).
function CU.DB()
    local d = NS.DB and NS.DB() or {}
    d.radar = type(d.radar) == "table" and d.radar or {}
    local r = d.radar
    if type(r.cues) ~= "table" then r.cues = { v = 1 } end
    local c = r.cues
    c.on = type(c.on) == "table" and c.on or {}
    c.look = type(c.look) == "table" and c.look or {}
    c.sound = type(c.sound) == "table" and c.sound or {}
    c.order = type(c.order) == "table" and c.order or {}
    if type(c.voice) ~= "table" then                         -- (a save from before the split, once)
        c.voice = {}
        for k, sd in pairs(c.sound) do
            local a, b = CU.Split(sd)
            c.sound[k], c.voice[k] = a, b                     -- (only existing keys written: pairs allows it)
        end
    end
    return c
end

--- Once per character: whoever had the deck before keeps what its switches said (nil there was "on"); a new player starts
--- with every cue off. The old Hellfire voice switch becomes Hellfire's sound.
function CU.Stamp()
    local d = NS.DB and NS.DB() or {}
    local r = type(d.radar) == "table" and d.radar or nil
    if r and type(r.cues) == "table" and r.cues.stamp then return false end
    local had = r and (r.swStamp ~= nil or type(r.sw) == "table")
    local sw = r and type(r.sw) == "table" and r.sw or {}
    local c = CU.DB()
    c.stamp = 1
    if had then
        for _, q in ipairs(CU.LIST) do
            if c.on[q.key] == nil then c.on[q.key] = sw[q.key] ~= false end
        end
        if sw.hellvoice == false or r.burnVoice == false then c.voice.hell = "off" end
    end
    return true
end

--- The cue order: the saved one, cleaned (unknown keys dropped, missing ones added at the end in CU.LIST's order).
function CU.Order()
    local c, out, seen = CU.DB(), {}, {}
    for _, k in ipairs(c.order) do
        if CU.BY[k] and not seen[k] then out[#out + 1] = k seen[k] = true end
    end
    for _, q in ipairs(CU.LIST) do if not seen[q.key] then out[#out + 1] = q.key end end
    return out
end
function CU.On(key) return CU.DB().on[key] == true end
function CU.Look(key)
    local q = CU.BY[key]
    local v = CU.DB().look[key]
    return type(v) == "string" and v or (q and q.look) or "icon"
end
function CU.Sound(key)
    local q = CU.BY[key]
    local v = CU.DB().sound[key]
    return type(v) == "string" and v or (q and q.sound) or "off"
end
function CU.Voice(key)
    local q = CU.BY[key]
    local v = CU.DB().voice[key]
    return type(v) == "string" and v or (q and q.voice) or "off"
end
function CU.Word(key) local q = CU.BY[key] return q and q.word or "" end
function CU.ModelOf(key)
    local id = CU.Look(key):match("^model:(%d+)$")
    return id and tonumber(id) or nil
end

--- A MODEL THAT HIDES IS A MODEL TO LOAD AGAIN (Arn, 21 Nov: "the fireball appeared for a second but disappeared after i
--- switched" - it was loaded once and only shown again after). Every showing loads it afresh, and the camera goes back
--- once per load (a load puts the camera at its own place: at 22 px, inside the fireball = nothing). Both the card's
--- sample and the game's Hellfire badge wear their model through here.
CU.modelLoads = 0
--- WHAT STANDS IN THE GAME'S OWN AURA BUTTON IS FORBIDDEN TO US LATER (Arn's BugGrabber, 21 Nov 21:31: "Cues.lua:201: calling
--- 'Hide' on bad self (Attempt to access forbidden object ...)", a model of ours in the Hellfire button; the button may only
--- be touched inside initializeFrame). Every touch that may be late goes through here: a refusal is an answer (false),
--- never a throw - the lookup is inside too, on such an object even reading a method may refuse.
function CU.Touch(obj, method, ...)
    return (pcall(function(...)
        local fn = obj[method]
        if fn then fn(obj, ...) end
    end, ...))
end
local function modelCam(m)
    if m.bisCamSet then return end
    m.bisCamSet = true
    CU.Touch(m, "SetCamDistanceScale", CU.MODEL_CAM)
end
local function modelLoad(m)
    if not m.bisWant or m.bisUp == m.bisWant then return end
    m.bisUp, m.bisCamSet = m.bisWant, nil
    CU.modelLoads = CU.modelLoads + 1
    CU.Touch(m, "ClearModel")
    CU.Touch(m, "SetModel", m.bisWant)
    modelCam(m)
end
--- Set a model frame up once (its own scripts only: no script of it is anyone else's).
function CU.ModelReady(m)
    if m.bisReady then return end
    m.bisReady = true
    pcall(m.SetScript, m, "OnHide", function(self) self.bisUp = nil end)
    pcall(m.SetScript, m, "OnShow", function(self) self.bisUp = nil modelLoad(self) end)
    pcall(m.SetScript, m, "OnModelLoaded", function(self)      -- (a late load: its camera came with it)
        self.bisCamSet = nil
        modelCam(self)
    end)
end
--- Wear this file's model, or none.
function CU.Wear(m, file)
    if not m then return end
    CU.ModelReady(m)
    m.bisWant = file
    if file then CU.Touch(m, "Show") modelLoad(m) else CU.Touch(m, "Hide") m.bisUp = nil end
end

--- A CUE'S FACE: the picked icon or turning model on a dark square, for any cue that has a word of its own (Arn, 21 Nov:
--- "no talking on revelation crit" - and his Life Tap icon and the rest did nothing either: only Hellfire obeyed the card).
function CU.Face(parent, key, px)
    local f = { key = key, px = px }
    local sq = CreateFrame("Frame", nil, parent)
    sq:SetSize(px, px)
    if sq.SetFrameLevel and parent.GetFrameLevel then
        local lvl = parent:GetFrameLevel()
        if type(lvl) == "number" then sq:SetFrameLevel(lvl + 5) end
    end
    local bg = sq:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(sq)
    bg:SetColorTexture(0, 0, 0, 0.75)
    local icon = sq:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(sq)
    if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    icon:Hide()
    sq:Hide()
    f.sq, f.icon = sq, icon
    return f
end
--- Show (or put away) a face as its cue's look says. Answers true when the face stands for the cue - its word stays out.
function CU.FaceShow(f, on)
    if not f then return false end
    local look = on and CU.Look(f.key) or nil
    if f.shown == look and f.wore == f.key then return f.faced end
    f.shown, f.wore = look, f.key
    local model = look and CU.ModelOf(f.key) or nil
    local icon = look == "icon"
    f.faced = (model ~= nil) or icon
    if icon then
        local q = CU.BY[f.key]
        local get = C_Spell and C_Spell.GetSpellTexture
        local ok, tex = false, nil
        if get and q then ok, tex = pcall(get, q.spell) end
        if ok and plain(tex) then CU.Touch(f.icon, "SetTexture", tex) end
        CU.Touch(f.icon, "Show")
    else CU.Touch(f.icon, "Hide") end
    CU.Touch(f.sq, f.faced and "Show" or "Hide")
    if model and not f.model then
        local okM, m = pcall(CreateFrame, "PlayerModel", nil, f.sq)
        if okM and m then
            m:SetAllPoints(f.sq)
            m.yaw = 0
            m:SetScript("OnUpdate", function(self, el)
                self.yaw = (self.yaw + (tonumber(el) or 0) * 1.5) % 6.2832
                pcall(self.SetFacing, self, self.yaw)
            end)
            f.model = m
        end
    end
    if f.model then CU.Wear(f.model, model) end
    return f.faced
end

--- Change a cue: on/off, look, sound. Each answers "now" or "after" (this fight).
function CU.SetOn(key, on)
    if not CU.BY[key] then return nil end
    CU.DB().on[key] = on and true or false
    return CU.Apply()
end
local function known(list, id)
    if type(id) ~= "string" then return false end
    for _, o in ipairs(list) do if o.id == id then return true end end
    return id:match("^kit:%d+$") ~= nil or id:match("^model:%d+$") ~= nil
end
function CU.SetLook(key, id)
    if not CU.BY[key] or not known(CU.LOOKS, id) then return nil end
    CU.DB().look[key] = id
    return CU.Apply()
end
function CU.SetSound(key, id)
    if not CU.BY[key] or not known(CU.SOUNDS, id) then return nil end
    CU.DB().sound[key] = id
    return CU.Apply()
end
function CU.SetVoice(key, id)
    if not CU.BY[key] or not known(CU.VOICES, id) then return nil end
    CU.DB().voice[key] = id
    return CU.Apply()
end
function CU.Default(key)
    local c = CU.DB()
    c.look[key], c.sound[key], c.voice[key] = nil, nil, nil
    return CU.Apply()
end
--- Move a cue one place up (-1) or down (+1) among the cues the card lists: its square moves with it (a cue another
--- class owns is stepped over, so an arrow never seems to do nothing).
function CU.Move(key, by)
    local o = CU.Order()
    local at
    for i, k in ipairs(o) do if k == key then at = i end end
    if not at or (by ~= 1 and by ~= -1) then return nil end
    local to = at + by
    while o[to] and not CU.ForMe(o[to]) do to = to + by end
    if to < 1 or to > #o or not o[to] then return nil end
    o[at], o[to] = o[to], o[at]
    CU.DB().order = o
    return CU.Apply()
end

--- Where a square cue's square goes on a box: its place among the square cues, in the cue order (on or off - a square
--- keeps its place, so turning another cue on never moves it mid-fight). Answers x, y from the box's TOPLEFT.
function CU.SquareXY(key, px)
    local S = CU.SQUARE
    px = px or S.px
    local n = 0
    for _, k in ipairs(CU.Order()) do
        local q = CU.BY[k]
        if q.kind == "square" and CU.On(k) then n = n + 1 end
        if k == key then
            if not CU.On(k) then n = n + 1 end
            break
        end
    end
    n = math.max(1, n)
    return S.x + (n - 1) * (px + S.gap), S.y
end

--- Lay the cues out again: now, or when the fight ends. The deck's own painters do the drawing.
function CU.Apply()
    if CU.card and CU.card:IsShown() then CU.Paint() end
    local RD, BN = NS.RD, NS.BN
    if RD and RD.PaintSwitches then RD.PaintSwitches() end
    if fight() then CU.pending = true return "after" end
    CU.pending = nil
    if BN and BN.Relayout then BN.Relayout() end
    if NS.RV and NS.RV.Relook then NS.RV.Relook(true) end
    if RD and RD.RipMarks and RD.spokes then pcall(RD.RipMarks) end
    if RD and RD.SwApply then RD.SwApply() end
    return "now"
end

--- A cue heard: its game sound and its voice, each on its own pick. `force` (TRY) skips the once-every-12-s rule.
CU.spoke = {}
--- A moment after a loading screen nothing speaks (the client re-makes its buttons: BN.quietUntil).
function CU.Quiet()
    local u = NS.BN and NS.BN.quietUntil
    return type(u) == "number" and GetTime and GetTime() < u or false
end
function CU.Say(key, unit, force)
    local q = CU.BY[key]
    if not q or (not force and not CU.On(key)) then return false end
    local s, v = CU.Sound(key), CU.Voice(key)
    if s == "off" and v == "off" then return false end
    local t = GetTime and GetTime() or 0
    local k = key .. ":" .. tostring(unit or "")
    if not force and CU.spoke[k] and t - CU.spoke[k] < CU.EVERY then return false end
    CU.spoke[k] = t
    local played = CU.Play(s)
    local spoke = CU.Speak(q, v, unit)
    return played or spoke
end
--- One sound of the list, played (nothing is picked).
function CU.Play(s)
    local kit = type(s) == "string" and s:match("^kit:(%d+)$")
    if not (kit and PlaySound) then return false end
    return (pcall(PlaySound, tonumber(kit), "SFX"))
end
--- The voice, as picked: "spell" or "name" (the spell and who).
function CU.Speak(q, v, unit)
    if v == "off" or not (C_VoiceChat and C_VoiceChat.SpeakText) then return false end
    local words = q.say
    if v == "name" then words = CU.Named(q.say, unit) end
    CU.said = (CU.said or 0) + 1
    return (pcall(C_VoiceChat.SpeakText, 0, words, CU.VOICE.rate, CU.VOICE.volume))
end
--- "Hellfire, Tin": the first name in normal case (an all-caps name is spelled out letter by letter by the voice).
function CU.Named(words, unit)
    local name
    if type(unit) == "string" and GetUnitName then
        local ok, n = pcall(GetUnitName, unit, false)
        n = ok and plain(n) or nil
        if type(n) == "string" then name = (n:match("^(%S+)") or n):lower():gsub("^%l", string.upper) end
    elseif type(unit) == "string" and unit ~= "" and not unit:match("^%l+%d*$") then
        name = unit                                       -- (the card's TRY hands a plain name)
    end
    if type(name) == "string" and name ~= "" then return words .. ", " .. name end
    return words
end

-- THE DECK'S SWITCHES read and write here (one truth). Wrapped once Radar.lua is in.
function CU.Wrap()
    local RD = NS.RD
    if not RD or CU.wrapped then return false end
    CU.wrapped = true
    local sw, setSw, preset = RD.Sw, RD.SetSw, RD.SwPreset
    RD.Sw = function(key)
        if CU.BY[key] then return CU.On(key) end
        if key == "hellvoice" then return CU.On("hell") and CU.Voice("hell") ~= "off" end
        return sw(key)
    end
    RD.SetSw = function(key, on)
        if CU.BY[key] then CU.DB().on[key] = on and true or false return RD.SwApply() end
        if key == "hellvoice" then
            CU.DB().voice.hell = on and (CU.BY.hell.voice) or "off"
            return RD.SwApply()
        end
        return setSw(key, on)
    end
    RD.SwPreset = function(name)
        local p = RD.SW_PRESETS and RD.SW_PRESETS[name]
        if p then
            local c = CU.DB()
            for _, q in ipairs(CU.LIST) do c.on[q.key] = p[q.key] == true end
            if p.hell and not p.hellvoice then c.voice.hell = "off" elseif p.hellvoice then c.voice.hell = nil end
        end
        return preset(name)
    end
    -- the engineer's old view starts LEAN (RD.SwStamp writes the switches table itself): the cues follow it
    local stamp = RD.SwStamp
    if stamp then
        RD.SwStamp = function(...)
            local did = stamp(...)
            local r = NS.DB and NS.DB().radar
            if did and r and type(r.sw) == "table" then
                local c = CU.DB()
                for _, q in ipairs(CU.LIST) do c.on[q.key] = r.sw[q.key] == true end
            end
            return did
        end
    end
    return true
end

-- ===================================================================================================================
-- THE STRING (dev/CUES.md): JSON of our own (a handful of types), base64 of our own; gzip only through the client.
-- ===================================================================================================================
local function jsonStr(s)
    return '"' .. s:gsub('[%c"\\]', function(ch)
        local m = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
        return m[ch] or string.format("\\u%04x", ch:byte())
    end) .. '"'
end
function CU.JSON(v)
    local t = type(v)
    if t == "string" then return jsonStr(v)
    elseif t == "number" then return tostring(v)
    elseif t == "boolean" then return v and "true" or "false"
    elseif t == "table" then
        if #v > 0 or next(v) == nil and v.__array then
            local out = {}
            for _, x in ipairs(v) do out[#out + 1] = CU.JSON(x) end
            return "[" .. table.concat(out, ",") .. "]"
        end
        local keys = {}
        for k in pairs(v) do if type(k) == "string" and k ~= "__array" then keys[#keys + 1] = k end end
        table.sort(keys)
        local out = {}
        for _, k in ipairs(keys) do out[#out + 1] = jsonStr(k) .. ":" .. CU.JSON(v[k]) end
        return "{" .. table.concat(out, ",") .. "}"
    end
    return "null"
end
--- Read JSON back (objects, arrays, strings, numbers, true/false/null). Answers the value, or nil + why.
function CU.FromJSON(s)
    local i = 1
    local function ws() i = s:find("[^ \t\r\n]", i) or (#s + 1) end
    local val
    local function str()
        local out = {}
        i = i + 1
        while i <= #s do
            local ch = s:sub(i, i)
            if ch == '"' then i = i + 1 return table.concat(out) end
            if ch == "\\" then
                local e = s:sub(i + 1, i + 1)
                local m = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
                if e == "u" then
                    local code = tonumber(s:sub(i + 2, i + 5), 16) or 63
                    out[#out + 1] = code < 128 and string.char(code) or "?"
                    i = i + 6
                elseif m[e] then out[#out + 1] = m[e] i = i + 2
                else error("bad escape") end
            else out[#out + 1] = ch i = i + 1 end
        end
        error("unfinished text")
    end
    val = function()
        ws()
        local ch = s:sub(i, i)
        if ch == "{" then
            local o = {}
            i = i + 1 ws()
            if s:sub(i, i) == "}" then i = i + 1 return o end
            while true do
                ws()
                if s:sub(i, i) ~= '"' then error("a name was expected") end
                local k = str()
                ws()
                if s:sub(i, i) ~= ":" then error("':' was expected") end
                i = i + 1
                o[k] = val()
                ws()
                local c = s:sub(i, i)
                i = i + 1
                if c == "}" then return o end
                if c ~= "," then error("',' was expected") end
            end
        elseif ch == "[" then
            local a = {}
            i = i + 1 ws()
            if s:sub(i, i) == "]" then i = i + 1 return a end
            while true do
                a[#a + 1] = val()
                ws()
                local c = s:sub(i, i)
                i = i + 1
                if c == "]" then return a end
                if c ~= "," then error("',' was expected") end
            end
        elseif ch == '"' then return str()
        elseif s:sub(i, i + 3) == "true" then i = i + 4 return true
        elseif s:sub(i, i + 4) == "false" then i = i + 5 return false
        elseif s:sub(i, i + 3) == "null" then i = i + 4 return nil
        else
            local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
            if num and num ~= "" then i = i + #num return tonumber(num) end
            error("unexpected '" .. ch .. "'")
        end
    end
    local ok, v = pcall(val)
    if not ok then return nil, tostring(v):gsub("^.-:%d+: ", "") end
    return v
end
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function CU.B64(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local d1, d2 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64
        local d3, d4 = math.floor(n / 64) % 64, n % 64
        out[#out + 1] = B64:sub(d1 + 1, d1 + 1) .. B64:sub(d2 + 1, d2 + 1)
            .. (b and B64:sub(d3 + 1, d3 + 1) or "=") .. (c and B64:sub(d4 + 1, d4 + 1) or "=")
    end
    return table.concat(out)
end
function CU.UnB64(s)
    s = s:gsub("[^%w%+/=]", "")
    local rev = {}
    for i = 1, 64 do rev[B64:sub(i, i)] = i - 1 end
    local out = {}
    for i = 1, #s, 4 do
        local q = s:sub(i, i + 3)
        local n, pad = 0, 0
        for j = 1, 4 do
            local ch = q:sub(j, j)
            if ch == "=" or ch == "" then pad = pad + 1 n = n * 64
            else
                local v = rev[ch]
                if not v then return nil end
                n = n * 64 + v
            end
        end
        local a, b, c = math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256
        out[#out + 1] = string.char(a)
        if pad < 2 then out[#out + 1] = string.char(b) end
        if pad < 1 then out[#out + 1] = string.char(c) end
    end
    return table.concat(out)
end

--- The settings as the string's table (dev/CUES.md).
function CU.Table()
    local c, t = CU.DB(), { v = 1, order = CU.Order(), on = {}, look = {}, sound = {}, voice = {} }
    for _, q in ipairs(CU.LIST) do
        if CU.On(q.key) then t.on[q.key] = true end
        if c.look[q.key] then t.look[q.key] = c.look[q.key] end
        if c.sound[q.key] then t.sound[q.key] = c.sound[q.key] end
        if c.voice[q.key] then t.voice[q.key] = c.voice[q.key] end
    end
    local RD = NS.RD
    if RD and RD.RaidSettings then t.raid = RD.RaidSettings() end   -- (sheet 6's switches, when they are in)
    return t
end
--- The export string: the plain form until a probe proves the client's gzip matches the browser's.
function CU.Export()
    return "BiSCues1p:" .. CU.B64(CU.JSON(CU.Table()))
end
--- Read a string (either form) into a table, or nil + why. Nothing is saved here.
function CU.Decode(s)
    if type(s) ~= "string" then return nil, "nothing pasted" end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    local json
    local plainBody = s:match("^BiSCues1p:(.+)$")
    local zipBody = s:match("^BiSCues1:(.+)$")
    if plainBody then
        json = CU.UnB64(plainBody)
    elseif zipBody then
        local E = C_EncodingUtil
        if not (E and E.DecodeBase64 and E.DecompressString) then return nil, "this game cannot unzip it - export the plain form in the explorer" end
        local okD, raw = pcall(E.DecodeBase64, zipBody)
        local method = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Gzip
        local okZ, out = false, nil
        if okD and raw then okZ, out = pcall(E.DecompressString, raw, method) end
        if not okZ or type(out) ~= "string" then return nil, "could not unzip it - export the plain form in the explorer" end
        json = out
    else
        return nil, "not a BiS Cues string (it starts with BiSCues1)"
    end
    if not json then return nil, "the letters are broken - copy it again" end
    local t, why = CU.FromJSON(json)
    if type(t) ~= "table" then return nil, "could not read it: " .. tostring(why) end
    if t.v ~= 1 then return nil, "made by a newer BiS Healing - update first" end
    return t
end
--- Paste a string: answers how many cues it set, or nil + why.
function CU.Import(s)
    local t, why = CU.Decode(s)
    if not t then return nil, why end
    local c = CU.DB()
    local order = {}
    if type(t.order) == "table" then for _, k in ipairs(t.order) do if CU.BY[k] then order[#order + 1] = k end end end
    c.order = order
    local n = 0
    for _, q in ipairs(CU.LIST) do
        local k = q.key
        c.on[k] = type(t.on) == "table" and t.on[k] == true or false
        local lk = type(t.look) == "table" and t.look[k]
        c.look[k] = known(CU.LOOKS, lk) and lk or nil
        local sd = type(t.sound) == "table" and t.sound[k]
        local vo
        if type(t.voice) == "table" then vo = t.voice[k] else sd, vo = CU.Split(sd) end    -- (a string from before the split)
        c.sound[k] = known(CU.SOUNDS, sd) and sd or nil
        c.voice[k] = known(CU.VOICES, vo) and vo or nil
        n = n + 1
    end
    local RD = NS.RD
    if type(t.raid) == "table" and RD and RD.SetRaidSettings then pcall(RD.SetRaidSettings, t.raid) end
    CU.Apply()
    return n
end

-- ===================================================================================================================
-- THE CARD
-- ===================================================================================================================
CU.CARD_W, CU.CARD_H = 460, 322                      -- (1.43:1, the family's window shape)
CU.ROWS = 6                                          -- picker rows shown; the wheel scrolls
CU.sel = "hell"
local FONT = "Fonts\\ARIALN.TTF"
-- THE FAMILY'S COLOURS, never our own (Arn, 21 Nov: "our ui strays sometimes need a way to unify it like bis>cues has this
-- blue tint to it"; "bis healing black background wokrs becuause we can hide boxes"): the deck's black under everything
-- (RD.PLATE, as the switches panel beside it) and BiSTheme's tokens over it, asked when the card is built - the theme may
-- load after us. A switched-off part leaves no hole on black.
local FALL = { ink = { 0.93, 0.91, 0.96 }, dim = { 0.56, 0.53, 0.65 }, accent = { 0.73, 0.50, 1.00 }, gold = { 0.90, 0.75, 0.29 },
    good = { 0.31, 0.82, 0.81 }, line2 = { 0.23, 0.20, 0.38 }, sunken = { 0.13, 0.11, 0.24 } }
local INK, DIM, ACC, GOLD, GOOD, LINE, SUNK, BLACK = FALL.ink, FALL.dim, FALL.accent, FALL.gold, FALL.good, FALL.line2, FALL.sunken, { 0.02, 0.02, 0.03 }
function CU.Tones()
    local T = _G.BiSTheme
    local function tone(name)
        if T and T.rgb then
            local ok, r, g, b = pcall(T.rgb, name)
            if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then return { r, g, b } end
        end
        return FALL[name]
    end
    INK, DIM, ACC, GOLD = tone("ink"), tone("dim"), tone("accent"), tone("gold")
    GOOD, LINE, SUNK = tone("good"), tone("line2"), tone("sunken")
    local P = NS.RD and NS.RD.PLATE
    if type(P) == "table" and type(P[1]) == "number" then BLACK = { P[1], P[2], P[3] } end
end

local function text(parent, size, col, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(FONT, size, "")
    fs:SetTextColor(col[1], col[2], col[3], 1)
    return fs
end
local function edges(f, col)
    local out = {}
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 },
                         { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(col[1], col[2], col[3], col[4] or 1)
        t:SetPoint(e[1], f, e[1], 0, 0)
        t:SetPoint(e[2], f, e[2], 0, 0)
        if e[3] > 0 then t:SetWidth(e[3]) else t:SetHeight(e[4]) end
        out[#out + 1] = t
    end
    return out
end
-- a row that POPS on hover (the family rule: a wash and a left bar)
local function hoverRow(row)
    row.wash = row:CreateTexture(nil, "BACKGROUND")
    row.wash:SetAllPoints(row)
    row.wash:SetColorTexture(ACC[1], ACC[2], ACC[3], 0.14)
    row.wash:Hide()
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT")
    row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
    row.bar:SetWidth(2)
    row.bar:SetColorTexture(ACC[1], ACC[2], ACC[3], 1)
    row.bar:Hide()
    row:HookScript("OnEnter", function(self) self.wash:Show() self.bar:Show() end)
    row:HookScript("OnLeave", function(self) if not self.sel then self.wash:Hide() self.bar:Hide() end end)
end
local function button(parent, w, h, label, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.edges = edges(b, { ACC[1] * 0.5, ACC[2] * 0.5, ACC[3] * 0.5, 1 })
    b.text = text(b, 10, INK)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.hl:SetColorTexture(ACC[1], ACC[2], ACC[3], 0.22)
    b:SetScript("OnClick", onClick)
    return b
end

--- One picker: a search box, category chips, a list. `kind` = "look" | "sound".
local function picker(card, kind, x, y, w)
    local list = kind == "look" and CU.LOOKS or CU.SOUNDS
    local P = { kind = kind, list = list, cat = "All", top = 0 }
    P.head = text(card, 10, ACC)
    P.head:SetPoint("TOPLEFT", card, "TOPLEFT", x, y)
    P.head:SetText(kind == "look" and "LOOK" or "SOUND")
    P.pick = text(card, 10, INK)
    P.pick:SetPoint("TOPRIGHT", card, "TOPLEFT", x + w, y)
    local q = CreateFrame("EditBox", nil, card)
    q:SetSize(w, 16)
    q:SetPoint("TOPLEFT", card, "TOPLEFT", x, y - 14)
    q:SetAutoFocus(false)
    q:SetFont(FONT, 10, "")
    q:SetTextColor(INK[1], INK[2], INK[3], 1)
    q:SetTextInsets(4, 4, 0, 0)
    q.bg = q:CreateTexture(nil, "BACKGROUND")
    q.bg:SetAllPoints(q)
    q.bg:SetColorTexture(SUNK[1], SUNK[2], SUNK[3], 1)
    q.edges = edges(q, LINE)
    q.hint = text(q, 9, DIM)
    q.hint:SetPoint("LEFT", q, "LEFT", 5, 0)
    q.hint:SetText(kind == "look" and "search looks..." or "search sounds...")
    q:SetScript("OnTextChanged", function(self) P.top = 0 self.hint:SetShown(self:GetText() == "") CU.PaintPicker(P) end)
    q:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    q:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    P.q = q
    -- the chips: All + each category, in the list's order
    local cats = { "All" }
    for _, o in ipairs(list) do
        local seen = false
        for _, c in ipairs(cats) do if c == o.cat then seen = true end end
        if not seen then cats[#cats + 1] = o.cat end
    end
    P.chips = {}
    -- (chips that would run past the picker's edge wrap to a second line - Arn's shot: "Crea..." off the card)
    local cx, cy = x, y - 33
    P.extra = 0
    for _, c in ipairs(cats) do
        local b = CreateFrame("Button", nil, card)
        local wd = 8 + #c * 5
        if cx > x and cx + wd > x + w then cx, cy, P.extra = x, cy - 15, P.extra + 15 end
        b:SetSize(wd, 13)
        b:SetPoint("TOPLEFT", card, "TOPLEFT", cx, cy)
        b.edges = edges(b, LINE)
        b.text = text(b, 9, DIM)
        b.text:SetPoint("CENTER")
        b.text:SetText(c)
        b.cat = c
        b:SetScript("OnClick", function() P.cat = c P.top = 0 CU.PaintPicker(P) end)
        P.chips[#P.chips + 1] = b
        cx = cx + wd + 3
    end
    -- the list
    P.rows = {}
    for i = 1, CU.ROWS do
        local row = CreateFrame("Button", nil, card)
        row:SetSize(w, 15)
        row:SetPoint("TOPLEFT", card, "TOPLEFT", x, y - 50 - P.extra - (i - 1) * 15)
        hoverRow(row)
        row.text = text(row, 10, INK)
        row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
        -- TRY ONLY PLAYS (Arn, 21 Nov: "it no say name and spell for hellfire" - TRY was a word on the row, so hearing
        -- Lightning crack picked it, and it took the voice's place): its own button; the rest of the row picks
        row.try = button(row, 26, 13, "TRY", function()
            local q = CU.BY[CU.sel]
            if row.id and q then CU.Play(row.id) end
        end)
        row.try:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row:SetScript("OnClick", function(self)
            if not self.id then return end
            if kind == "look" then CU.SetLook(CU.sel, self.id) else CU.SetSound(CU.sel, self.id) CU.Play(self.id) end
        end)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta) P.top = math.max(0, P.top - (delta or 0)) CU.PaintPicker(P) end)
        P.rows[i] = row
    end
    return P
end

--- The list a picker shows now: its search and its chip.
function CU.Filtered(P)
    local qtext = (P.q and P.q:GetText() or ""):lower()
    local out = {}
    for _, o in ipairs(P.list) do
        if (P.cat == "All" or o.cat == P.cat)
            and (qtext == "" or o.name:lower():find(qtext, 1, true) or o.cat:lower():find(qtext, 1, true)) then
            out[#out + 1] = o
        end
    end
    return out
end
function CU.PaintPicker(P)
    local cur = P.kind == "look" and CU.Look(CU.sel) or CU.Sound(CU.sel)
    local items = CU.Filtered(P)
    P.top = math.max(0, math.min(P.top, #items - CU.ROWS))
    local curName = cur
    for _, o in ipairs(P.list) do if o.id == cur then curName = o.name end end
    P.pick:SetText(curName)
    for i, row in ipairs(P.rows) do
        local o = items[P.top + i]
        row.id = o and o.id or nil
        row.sel = o and o.id == cur or false
        if o then
            row.text:SetText(o.name)
            row.text:SetTextColor(row.sel and ACC[1] or INK[1], row.sel and ACC[2] or INK[2], row.sel and ACC[3] or INK[3], 1)
            row:Show()
            row.wash:SetShown(row.sel) row.bar:SetShown(row.sel)
            row.try:SetShown(P.kind == "sound" and o.id ~= "off")
        else
            row:Hide()
        end
    end
    for _, b in ipairs(P.chips) do
        local on = b.cat == P.cat
        b.text:SetTextColor(on and ACC[1] or DIM[1], on and ACC[2] or DIM[2], on and ACC[3] or DIM[3], 1)
    end
end

--- The preview: a drawn deck box wearing the chosen cue's pick (the real model turning, the word, or the icon).
local function buildPreview(card, x, y)
    local pv = CreateFrame("Frame", nil, card)
    pv:SetSize(150, 44)
    pv:SetPoint("TOPLEFT", card, "TOPLEFT", x, y)
    pv.bg = pv:CreateTexture(nil, "BACKGROUND")
    pv.bg:SetAllPoints(pv)
    pv.bg:SetColorTexture(BLACK[1], BLACK[2], BLACK[3], 1)
    pv.edges = edges(pv, LINE)
    -- the bar runs edge to edge, always (Arn, 21 Nov: "the bar must always go to the end of the box no empty space")
    pv.bar = pv:CreateTexture(nil, "BORDER")
    pv.bar:SetPoint("TOPLEFT", pv, "TOPLEFT", 1, -1)
    pv.bar:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", -1, 1)
    pv.bar:SetColorTexture(0.58, 0.51, 0.79, 1)          -- a warlock's purple
    pv.name = text(pv, 9, { 0.86, 1.00, 0.90 })
    pv.name:SetPoint("TOPLEFT", pv, "TOPLEFT", 4, -4)
    pv.name:SetText("TIN")
    pv.sq = CreateFrame("Frame", nil, pv)
    pv.sq:SetSize(CU.SQUARE.px, CU.SQUARE.px)
    pv.sqBg = pv.sq:CreateTexture(nil, "BACKGROUND")    -- (a dark square under a model: the fire reads on it)
    pv.sqBg:SetAllPoints(pv.sq)
    pv.sqBg:SetColorTexture(0, 0, 0, 0.75)
    pv.icon = pv.sq:CreateTexture(nil, "ARTWORK")
    pv.icon:SetAllPoints(pv.sq)
    if pv.icon.SetTexCoord then pv.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    local okM, m = pcall(CreateFrame, "PlayerModel", nil, pv.sq)
    if okM and m then
        m:SetAllPoints(pv.sq)
        m.yaw = 0
        m:SetScript("OnUpdate", function(self, el)
            self.yaw = (self.yaw + (tonumber(el) or 0) * 1.5) % 6.2832
            pcall(self.SetFacing, self, self.yaw)
        end)
        pv.model = m
    end
    pv.back = pv:CreateTexture(nil, "ARTWORK")
    pv.back:SetColorTexture(0, 0, 0, 0.7)
    pv.word = text(pv, 10, INK)
    pv.back:SetPoint("TOPLEFT", pv.word, "TOPLEFT", -3, 1)
    pv.back:SetPoint("BOTTOMRIGHT", pv.word, "BOTTOMRIGHT", 3, -1)
    -- the flash TRY plays
    pv.flash = CreateFrame("Frame", nil, pv)
    pv.flash:SetAllPoints(pv)
    pv.flash.edges = edges(pv.flash, { 1, 0.95, 0.7, 1 })
    pv.flash:Hide()
    return pv
end
function CU.PaintPreview()
    local pv = CU.card and CU.card.preview
    if not pv then return end
    local key = CU.sel
    local q = CU.BY[key]
    local look = CU.Look(key)
    local tex
    if q then
        local get = C_Spell and C_Spell.GetSpellTexture
        if get then local ok, t = pcall(get, q.spell) if ok then tex = plain(t) end end
    end
    pv.sq:ClearAllPoints()
    pv.word:ClearAllPoints()
    if q and q.kind == "square" then
        local sx, sy = CU.SquareXY(key)
        pv.sq:SetPoint("TOPLEFT", pv, "TOPLEFT", sx, sy)
        pv.word:SetPoint("CENTER", pv.sq, "CENTER", 0, 0)
    else
        pv.sq:SetPoint("CENTER", pv.bar, "CENTER", 0, 0)
        pv.word:SetPoint("CENTER", pv.bar, "CENTER", 0, 0)
    end
    local model = CU.ModelOf(key)
    CU.Wear(pv.model, model)
    -- no spell of its own = the question mark, never the last cue's icon (Arn, 24 Nov: "tank armor shows hellfire spell?")
    pcall(pv.icon.SetTexture, pv.icon, tex or 134400)
    if look == "icon" then pv.icon:Show() else pv.icon:Hide() end   -- (a model stands on its own dark square)
    if model or look == "icon" then pv.sq:Show() pv.sqBg:Show() else pv.sq:Hide() end
    if look == "word" then
        pv.word:SetText(CU.Word(key)) pv.word:Show() pv.back:Show()
    else
        pv.word:Hide() pv.back:Hide()
    end
    pv:SetAlpha(CU.On(key) and 1 or 0.45)
end

--- The order list on the left: tick = on, the name selects, up / down move its square.
local function buildOrder(card)
    card.order = {}
    for i = 1, #CU.LIST do
        local row = CreateFrame("Button", nil, card)
        row:SetSize(150, 18)
        row:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -42 - (i - 1) * 18)
        hoverRow(row)
        row.tick = CreateFrame("Button", nil, row)
        row.tick:SetSize(11, 11)
        row.tick:SetPoint("LEFT", row, "LEFT", 5, 0)
        row.tick.edges = edges(row.tick, DIM)
        row.tick.fill = row.tick:CreateTexture(nil, "ARTWORK")
        row.tick.fill:SetPoint("TOPLEFT", row.tick, "TOPLEFT", 2, -2)
        row.tick.fill:SetPoint("BOTTOMRIGHT", row.tick, "BOTTOMRIGHT", -2, 2)
        row.tick.fill:SetColorTexture(GOOD[1], GOOD[2], GOOD[3], 1)
        row.tick:SetScript("OnClick", function() if row.key then CU.SetOn(row.key, not CU.On(row.key)) end end)
        row.text = text(row, 10, INK)
        row.text:SetPoint("LEFT", row.tick, "RIGHT", 6, 0)
        row.up = button(row, 14, 14, "^", function() if row.key then CU.Move(row.key, -1) end end)
        row.up:SetPoint("RIGHT", row, "RIGHT", -18, 0)
        row.down = button(row, 14, 14, "v", function() if row.key then CU.Move(row.key, 1) end end)
        row.down:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row:SetScript("OnClick", function() if row.key then CU.sel = row.key CU.Paint() end end)
        row:HookScript("OnEnter", function(self)
            local q = self.key and CU.BY[self.key]
            if q and GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:AddLine(q.name:upper())
                GameTooltip:AddLine(q.tip, 1, 1, 1, true)
                GameTooltip:AddLine("Tick: on or off.  Arrows: move its place in the row.", 0.6, 0.85, 1, true)
                GameTooltip:Show()
            end
        end)
        row:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        card.order[i] = row
    end
end

function CU.Card()
    if CU.card then return CU.card end
    CU.Tones()
    local c = CreateFrame("Frame", "BiSHealingCues", UIParent)
    c:SetSize(CU.CARD_W, CU.CARD_H)
    c:SetFrameStrata("DIALOG")
    c:SetScale(1.2)
    c:SetClampedToScreen(true)
    c:EnableMouse(true)
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints(c)
    c.bg:SetColorTexture(BLACK[1], BLACK[2], BLACK[3], 0.97)
    c.edges = edges(c, { ACC[1] * 0.6, ACC[2] * 0.6, ACC[3] * 0.6, 1 })
    c.title = text(c, 12, ACC)
    c.title:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -7)
    c.title:SetText("BiS>Deck")
    c.note = text(c, 9, GOLD)
    c.note:SetPoint("LEFT", c.title, "RIGHT", 8, 0)
    c.close = button(c, 14, 14, "x", function() c:Hide() end)
    c.close:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -4)
    -- THE ONE WINDOW (Arn, 24 Nov, sketch B: "One window, three tabs"): the cue card's own parts live on a page that the
    -- CUES and DEBUFFS tabs show; the DECK tab shows the switches panel in its place (CU.Host). Anchored to the page = to
    -- the card (the page covers it).
    local pg = CreateFrame("Frame", nil, c)
    pg:SetAllPoints(c)
    c.page = pg
    c.orderHead = text(pg, 9, GOLD)
    c.orderHead:SetPoint("TOPLEFT", pg, "TOPLEFT", 10, -28)
    c.orderHead:SetText("THE CUES, IN ROW ORDER")
    buildOrder(pg)
    c.order = pg.order
    -- the chosen cue
    c.name = text(pg, 12, INK)
    c.name:SetPoint("TOPLEFT", pg, "TOPLEFT", 168, -26)
    c.preview = buildPreview(pg, 168, -42)
    c.try = button(pg, 56, 18, "TRY", function() CU.Try() end)
    c.try:SetPoint("TOPLEFT", pg, "TOPLEFT", 326, -42)
    c.def = button(pg, 90, 18, "BACK TO DEFAULT", function() CU.Default(CU.sel) end)
    c.def:SetPoint("TOPLEFT", pg, "TOPLEFT", 326, -64)
    -- the voice: its own pick, over the two lists
    c.voiceHead = text(pg, 10, ACC)
    c.voiceHead:SetPoint("TOPLEFT", pg, "TOPLEFT", 168, -95)
    c.voiceHead:SetText("VOICE")
    c.voices = {}
    local vx = 208
    for i, o in ipairs(CU.VOICES) do
        local w = 14 + #o.name * 6
        local b = button(pg, w, 17, o.name, function()
            CU.SetVoice(CU.sel, o.id)
            local q = CU.BY[CU.sel]
            if q then CU.Speak(q, o.id, "Tin") end
        end)
        b:SetPoint("TOPLEFT", pg, "TOPLEFT", vx, -91)
        b.id = o.id
        c.voices[i] = b
        vx = vx + w + 5
    end
    c.look = picker(pg, "look", 168, -116, 138)
    c.sound = picker(pg, "sound", 314, -116, 138)
    -- the string
    c.export = button(pg, 74, 18, "EXPORT", function() CU.ShowString("export") end)
    c.export:SetPoint("BOTTOMLEFT", pg, "BOTTOMLEFT", 8, 8)
    c.import = button(pg, 74, 18, "IMPORT", function() CU.ShowString("import") end)
    c.import:SetPoint("LEFT", c.export, "RIGHT", 6, 0)
    c.hint = text(pg, 9, DIM)
    c.hint:SetPoint("LEFT", c.import, "RIGHT", 8, 0)
    c.hint:SetText("Set it up in the browser: Explorer\\BiSCues.html in the addon's folder.")
    -- THE FAINT CODE (Arn, 21 Nov: "a faint code on the page so when i ss you can see back end info version number ect
    -- setting turn on"): what a screenshot needs to tell Claude - the build, the chosen cue, the order, what is on
    c.code = text(c, 8, DIM)
    c.code:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 8, 30)
    c.code:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -8, 30)
    c.code:SetJustifyH("LEFT")
    c.code:SetAlpha(0.45)
    -- DRAGGED WHERE YOU WANT IT, and it opens there again (Arn, 24 Nov: "I gotta keep dragging to the left"); nothing
    -- secure on it, and the drag still ends at the pull and when it closes (the family rule)
    c:SetMovable(true)
    c:RegisterForDrag("LeftButton")
    c:SetScript("OnDragStart", function(self) self:StartMoving() self.moving = true end)
    c:SetScript("OnDragStop", function() CU.EndDrag() end)
    c:SetScript("OnHide", function()
        CU.EndDrag()
        local p = NS.RD and NS.RD.swPanel
        if p and p.hosted then p:Hide() end                    -- (the DECK tab goes with its window)
    end)
    CU.BuildTabs(c)
    c:Hide()
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "BiSHealingCues") end
    CU.card = c
    return c
end

function CU.Paint()
    local c = CU.card
    if not c then return false end
    CU.PaintTabs()
    if c.code then c.code:SetText(CU.Code()) end
    if CU.tab == "deck" then
        c.note:SetText(fight() and "after this fight" or "")
        return true
    end
    local shown = CU.TabShown()
    local inTab = false
    for _, k in ipairs(shown) do if k == CU.sel then inTab = true end end
    if not CU.BY[CU.sel] or not CU.ForMe(CU.sel) or not inTab then CU.sel = shown[1] or CU.LIST[1].key end
    for i, row in ipairs(c.order) do if i > #shown then row.key = nil row:Hide() else row:Show() end end
    for i, k in ipairs(shown) do
        local row = c.order[i]
        local q = CU.BY[k]
        row.key = k
        row.sel = k == CU.sel
        local on = CU.On(k)
        row.text:SetText(q.name)
        row.text:SetTextColor(on and INK[1] or DIM[1], on and INK[2] or DIM[2], on and INK[3] or DIM[3], 1)
        if on then row.tick.fill:Show() else row.tick.fill:Hide() end
        row.wash:SetShown(row.sel) row.bar:SetShown(row.sel)
    end
    local q = CU.BY[CU.sel]
    c.name:SetText(q.name .. "  |cff8d94b1" .. q.cat:lower() .. "|r")
    c.note:SetText((fight() and "after this fight") or (CU.On(CU.sel) and "" or "this cue is off"))
    CU.PaintPicker(c.look)
    CU.PaintPicker(c.sound)
    for _, b in ipairs(c.voices) do
        local on = b.id == CU.Voice(CU.sel)
        b.text:SetTextColor(on and ACC[1] or DIM[1], on and ACC[2] or DIM[2], on and ACC[3] or DIM[3], 1)
        for _, e in ipairs(b.edges) do e:SetColorTexture(ACC[1] * (on and 1 or 0.3), ACC[2] * (on and 1 or 0.3), ACC[3] * (on and 1 or 0.3), 1) end
    end
    CU.PaintPreview()
    if c.code then c.code:SetText(CU.Code()) end
    return true
end

--- The faint code: build | chosen cue: on, look, sound, square | order (first letters, capital = on) | Hellfire's game
--- buttons | fight | class effects. Short codes on purpose - it is for Claude reading a screenshot, not for reading.
local VOICE_CODE = { name = "vn", spell = "v", off = "x" }
function CU.Code()
    local key = CU.sel
    local look = CU.Look(key)
    local lk = look == "icon" and "i" or look == "word" and "w" or ("m" .. (look:match("%d+") or "?"))
    local sd = CU.Sound(key)
    sd = (sd == "off" and "" or ("k" .. (sd:match("%d+") or "?") .. "+")) .. (VOICE_CODE[CU.Voice(key)] or "?")
    local q = CU.BY[key]
    local sq = q and q.kind == "square" and ("@" .. CU.SquareXY(key)) or (q and q.kind or "")
    local ord = {}
    for _, k in ipairs(CU.Order()) do
        local l = k:sub(1, 2)
        ord[#ord + 1] = CU.On(k) and l:upper() or l
    end
    local BN, FX, RD = NS.BN, NS.FX, NS.RD
    local burn = BN and (tostring(BN.drawSeen or "-") .. "/" .. tostring(#(BN.badges or {}))) or "-"
    local fx = ""
    if FX and FX.Sw then
        for _, k in ipairs({ "fxvigil", "fxmend", "fxpoh", "fxwild" }) do fx = fx .. (FX.Sw(k) and "1" or "0") end
    end
    local look2 = RD and RD.Deck and (pcall(RD.Deck) and RD.Deck()) and "deck" or (NS.FG and NS.FG.Look and NS.FG.Look()) or "?"
    local pm = CU.card and CU.card.preview and CU.card.preview.model
    local mdl = not pm and "none" or (tostring(pm.bisUp or "-") .. (pm:IsShown() and "s" or "h") .. (pm.bisCamSet and "c" or "") .. CU.modelLoads)
    return string.format("%s | %s %s %s %s %s | %s | burn %s | %s | fx %s | %s | mdl %s",
        NS.Mark and NS.Mark() or tostring(NS.VERSION), key, CU.On(key) and "on" or "off", lk, sd, sq,
        table.concat(ord, " "), burn, fight() and "FIGHT" or "calm", fx, tostring(look2), mdl)
end

--- TRY: the chosen cue's sound now, and the preview box flashes.
function CU.Try()
    local pv = CU.card and CU.card.preview
    if pv then
        pv.flash:Show()
        if C_Timer and C_Timer.After then C_Timer.After(1.5, function() pv.flash:Hide() end) end
    end
    return CU.Say(CU.sel, "Tin", true)
end

--- The drag's end: let go, and keep the spot (by the screen) for the next opening.
function CU.EndDrag()
    local c = CU.card
    if not (c and c.moving) then return end
    c.moving = nil
    c:StopMovingOrSizing()
    local pt, _, rel, x, y = c:GetPoint(1)
    if type(pt) == "string" and type(x) == "number" and type(y) == "number" then
        local r = CU.DB() and (NS.DB().radar)
        if r then r.deckWinPos = { pt, rel or pt, x, y } end
    end
end

-- ----------------------------------------------------------------- the one window's tabs

--[[ ONE WINDOW, THREE TABS (Arn, 24 Nov 2026, sketch B https://claude.ai/artifact/673B7uUYYd1rmWqHZMitvh: "One window, three
  tabs ... for the switches and cues"). DECK = the switches panel, hosted here (CU.Host) in columns (RD.FlowSwitches);
  CUES = every cue but the debuffs; DEBUFFS = the debuff cues. The seven rows that were a switch AND a cue live on the
  cue tabs only (RD.SwOwned). The switches button opens it on DECK, /bish cues on CUES; it opens where you last dragged
  it, else against the deck's right edge (where the switches opened), else the middle. ]]
CU.TABS = { { id = "deck", name = "DECK" }, { id = "cues", name = "CUES" }, { id = "debuffs", name = "DEBUFFS" } }
CU.tab = "cues"

--- The cues on the open tab, in row order (your class only, as CU.Shown).
function CU.TabShown(tab)
    tab = tab or CU.tab
    local out = {}
    for _, k in ipairs(CU.Shown()) do
        local deb = CU.BY[k].cat == "DEBUFFS"
        if (tab == "debuffs") == deb then out[#out + 1] = k end
    end
    return out
end

function CU.BuildTabs(c)
    c.tabs = {}
    local x = 84
    for i, t in ipairs(CU.TABS) do
        local w = 18 + #t.name * 6
        local b = button(c, w, 16, t.name, function() CU.SetTab(t.id) end)
        b:SetPoint("TOPLEFT", c, "TOPLEFT", x, -4)
        b.id = t.id
        c.tabs[i] = b
        x = x + w + 4
    end
end

function CU.PaintTabs()
    local c = CU.card
    for _, b in ipairs((c and c.tabs) or {}) do
        local on = b.id == CU.tab
        b.text:SetTextColor(on and ACC[1] or DIM[1], on and ACC[2] or DIM[2], on and ACC[3] or DIM[3], 1)
        for _, e in ipairs(b.edges or {}) do e:SetColorTexture(ACC[1] * (on and 1 or 0.3), ACC[2] * (on and 1 or 0.3), ACC[3] * (on and 1 or 0.3), 1) end
    end
end

--- The switches panel moves into the window, once: its own frame, title, close and Esc go (the window has them).
function CU.Host(p)
    local c = CU.Card()
    if not p or p.hosted then return p end
    p.hosted = true
    p:SetParent(c)
    if p.SetScale then p:SetScale(1) end                       -- (the window carries the 1.2)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -24)
    p:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
    for _, r in ipairs({ p.bg, p.title, p.closeB, p.note }) do if r and r.Hide then r:Hide() end end
    for _, e in ipairs(p.edges or {}) do if e.Hide then e:Hide() end end
    if p.EnableMouse then p:EnableMouse(false) end            -- (a drag on its empty space moves the window)
    if type(UISpecialFrames) == "table" then
        for i = #UISpecialFrames, 1, -1 do if UISpecialFrames[i] == "BiSHealingSwitches" then table.remove(UISpecialFrames, i) end end
    end
    return p
end

--- The window's size for the DECK tab: the family's 1.43:1, grown until the switches fit its columns.
function CU.FitDeck(c, p)
    local RD = NS.RD
    local colW = RD.SW_W or 210
    for H = CU.CARD_H, 900, 14 do
        local W = math.max(CU.CARD_W, math.ceil(H * 1.43))
        local maxCols = math.floor((W - 8) / (colW + 8))
        local _, fits = RD.FlowSwitches(p, colW, -(H - 24 - 18), maxCols)
        if fits then c:SetSize(W, H) return W, H end
    end
    c:SetSize(CU.CARD_W, CU.CARD_H)
    return CU.CARD_W, CU.CARD_H
end

function CU.SetTab(id)
    local c = CU.Card()
    local RD = NS.RD
    CU.tab = id
    if id == "deck" and RD and RD.BuildSwitches then
        local p = CU.Host(RD.BuildSwitches())
        c.page:Hide()
        p:Show()
        CU.FitDeck(c, p)
        if RD.PaintSwitches then RD.PaintSwitches() end
        c.code:ClearAllPoints()
        c.code:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 8, 5)
        c.code:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -8, 5)
    else
        if RD and RD.swPanel and RD.swPanel.hosted then RD.swPanel:Hide() end
        c:SetSize(CU.CARD_W, CU.CARD_H)
        c.page:Show()
        c.code:ClearAllPoints()
        c.code:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 8, 30)
        c.code:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -8, 30)
    end
    CU.Paint()
    return id
end

--- Where it opens: your last drag; else against the deck's right edge, tops level; else the middle.
function CU.Place(c)
    c:ClearAllPoints()
    local pos = (NS.DB().radar or {}).deckWinPos
    if type(pos) == "table" and type(pos[1]) == "string" and type(pos[3]) == "number" then
        c:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3], pos[4] or 0)
        return "drag"
    end
    local f = NS.RD and NS.RD.frame
    if f and f.IsShown and f:IsShown() then
        c:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, 0)
        return "deck"
    end
    c:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    return "middle"
end

--- Close the window and its DECK tab with it.
function CU.Close()
    local c = CU.card
    if c then c:Hide() end
    local p = NS.RD and NS.RD.swPanel
    if p and p.hosted then p:Hide() end
    return false
end

--- Open on a tab; that tab already open = close the window (the switches button and /bish cues stay toggles).
function CU.Open(tab)
    local c = CU.Card()
    tab = tab or CU.tab
    if c:IsShown() and CU.tab == tab then return CU.Close() end
    if not c:IsShown() then CU.Place(c) c:Show() end
    CU.SetTab(tab)
    return true
end

--- /bish cues: open on the cue tab (or DEBUFFS, if that was last), or close.
function CU.Toggle()
    local c = CU.Card()
    if c:IsShown() then return CU.Close() end
    return CU.Open(CU.tab == "debuffs" and "debuffs" or "cues")
end

--- The string's window: EXPORT shows it ready to copy, IMPORT takes a paste.
function CU.ShowString(mode)
    local w = CU.strWin
    if not w then
        w = CreateFrame("Frame", "BiSHealingCuesString", UIParent)
        w:SetSize(360, 140)
        w:SetFrameStrata("FULLSCREEN_DIALOG")
        w:SetClampedToScreen(true)
        w:EnableMouse(true)
        w.bg = w:CreateTexture(nil, "BACKGROUND")
        w.bg:SetAllPoints(w)
        w.bg:SetColorTexture(BLACK[1], BLACK[2], BLACK[3], 0.98)
        w.edges = edges(w, { ACC[1] * 0.6, ACC[2] * 0.6, ACC[3] * 0.6, 1 })
        w.title = text(w, 11, ACC)
        w.title:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -7)
        w.close = button(w, 14, 14, "x", function() w:Hide() end)
        w.close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -4, -4)
        local e = CreateFrame("EditBox", nil, w)
        e:SetMultiLine(true)
        e:SetAutoFocus(false)
        e:SetFont(FONT, 10, "")
        e:SetTextColor(INK[1], INK[2], INK[3], 1)
        e:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -26)
        e:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -8, 32)
        e:SetScript("OnEscapePressed", function(self) self:ClearFocus() w:Hide() end)
        e.bg = e:CreateTexture(nil, "BACKGROUND")
        e.bg:SetAllPoints(e)
        e.bg:SetColorTexture(SUNK[1], SUNK[2], SUNK[3], 1)
        w.edit = e
        w.go = button(w, 80, 18, "IMPORT", function()
            local n, why = CU.Import(w.edit:GetText())
            w.status:SetText(n and ("Done: " .. n .. " cues set.") or ("Not imported: " .. tostring(why)))
        end)
        w.go:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -8, 8)
        w.status = text(w, 9, { 1, 0.75, 0.3 })
        w.status:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 8, 12)
        w:Hide()
        if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "BiSHealingCuesString") end
        CU.strWin = w
    end
    w:ClearAllPoints()
    w:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    w.mode = mode
    if mode == "export" then
        w.title:SetText("EXPORT - copy this (Ctrl+C) and keep or share it")
        w.edit:SetText(CU.Export())
        w.edit:SetFocus()
        if w.edit.HighlightText then w.edit:HighlightText() end
        w.go:Hide()
        w.status:SetText("Paste it into the explorer page, or a friend's /bish import.")
    else
        w.title:SetText("IMPORT - paste a BiS Cues string (Ctrl+V)")
        w.edit:SetText("")
        w.edit:SetFocus()
        w.go:Show()
        w.status:SetText("")
    end
    w:Show()
    return w
end

-- THE SWITCHES BUTTON OPENS THE ONE WINDOW ON ITS DECK TAB (24 Nov 2026, sketch B); a cue row leaves the switch list
function CU.HookPanel()
    local RD = NS.RD
    if not RD or CU.panelHooked or not RD.ToggleSwitches then return false end
    CU.panelHooked = true
    RD.SwOwned = function(key) return key == "hellvoice" or CU.BY[key] ~= nil end
    RD.ToggleSwitches = function() return CU.Open("deck") end
    return true
end

-- the fight's end lays out what waited
CU.events = CreateFrame("Frame")
CU.events:RegisterEvent("PLAYER_LOGIN")
CU.events:RegisterEvent("PLAYER_REGEN_ENABLED")
CU.events:RegisterEvent("PLAYER_REGEN_DISABLED")
CU.events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then CU.Stamp()
    elseif event == "PLAYER_REGEN_DISABLED" then CU.EndDrag()                 -- (a drag ends at the pull)
    elseif event == "PLAYER_REGEN_ENABLED" and CU.pending then CU.Apply() end
end)
CU.Wrap()
CU.HookPanel()

-- the slash words (Core.lua hands them here)
function CU.Slash(rest)
    rest = rest or ""
    local cmd, arg = rest:match("^(%S*)%s*(.-)$")
    if cmd == "export" then
        local s = CU.Export()
        CU.ShowString("export")
        return s
    elseif cmd == "import" then
        if arg ~= "" then
            local n, why = CU.Import(arg)
            say(n and ("BiS>Cues: imported, " .. n .. " cues set.") or ("BiS>Cues: not imported - " .. tostring(why)))
            return n
        end
        CU.ShowString("import")
        return true
    elseif cmd == "all" then
        CU.showAll = not CU.showAll
        say(CU.showAll and "BiS>Cues: showing every class's cues (until you reload)." or "BiS>Cues: only your class's cues.")
        if CU.card and CU.card:IsShown() then CU.Paint() else CU.Toggle() end
        return CU.showAll
    end
    return CU.Toggle()
end
