--[[
  BiSHealing / Forever :: DebuffBook.lua - THE DEBUFF BOOK: learning debuffs on the fly (24 Nov 2026).

  Arn, 24 Nov: "build the infrastructure into the best healing in a way if for some reason the helpers didn't pick up a
  [debuff], it can learn on the fly of oh, I just saw a new [debuff] and try and work out what it can probe".

  WHEN IT LOOKS (never in a fight - auras are secret there and the walk throws):
    - a group member gains a harmful aura while out of a fight (UNIT_AURA, registered only out of one), and
    - once as a fight ends (PLAYER_REGEN_ENABLED): whatever the fight left on people is still there to read.
  The index walk can refuse even out of a fight under instance restrictions (Between.lua's note) - then it learns
  nothing there and says so (`DK.refused`), never "nothing seen".

  WHAT IT WRITES DOWN, per spell id, in the save (`debuffBook`): its name, dispel type, how many times and where it was
  seen, the first words of its tooltip, whether the client will let a box filter it by id in a fight
  (C_Secrets.GetSpellAuraSecrecy - only a NeverSecret one can be shown by id there), and a GUESS at what a healer does
  about it, read off the words (`DK.Guess`):
    past      "healed above 90%" / "until healed to full"  -> HEAL PAST, the line at that % (joins HealPast.lua's lines)
    nodispel  "when dispelled ..." / "if removed ..."        -> DON'T DISPEL
    reduce    "healing received reduced"                      -> heals land weaker
    absorb    "absorbs the next N healing"                    -> heals vanish into it
    dispel    a dispel type and none of the above             -> DISPEL (who can is the client's answer, as the cure marks)
    watch     nothing to say yet
  A guess is a guess: `/bish debuffs` lists the book, newest first, and every row says "learned". A helper-made or a
  person-confirmed row (`HP.DEBUFFS`, later the curated list) always wins over a learned one.
]]
local ADDON, NS = ...
NS = NS or {}

local DK = {}
NS.DK = DK

DK.MAX = 300                     -- rows kept (the oldest seen goes first)
DK.DESC = 200                    -- tooltip letters kept
DK.RETRY = 3                     -- times a missing tooltip is asked for again (the client loads spell text late)

local function plain(v) if NS.Plain then return NS.Plain(v) end return v end
local function field(a, k)
    local ok, v = pcall(function() return a[k] end)
    if not ok then return nil end
    return plain(v)
end

function DK.Book()
    local d = NS.DB and NS.DB() or {}
    if type(d.debuffBook) ~= "table" then d.debuffBook = {} end
    return d.debuffBook
end

--- Read the words: an action and, for a line, its share. `words` is the tooltip (any case).
DK.PAST = {
    "healed above (%d+)%%", "healed to above (%d+)%%", "health is above (%d+)%%", "above (%d+)%% health",
    "healed to (%d+)%%", "below (%d+)%% health", "health falls below (%d+)%%", "heal[%a]* the target above (%d+)%%",
}
function DK.Guess(words, dtype)
    local w = type(words) == "string" and words:lower() or ""
    for _, pat in ipairs(DK.PAST) do
        local n = tonumber(w:match(pat))
        if n and n > 0 and n < 100 then return "past", n / 100 end
    end
    if w:find("healed to full", 1, true) or w:find("until fully healed", 1, true) then return "past", 0.99 end
    if w:find("when dispelled") or w:find("if dispelled") or w:find("when removed") or w:find("if removed")
       or w:find("upon dispel") or w:find("dispelling") then return "nodispel" end
    if w:find("healing received") and (w:find("reduc") or w:find("decreas")) then return "reduce" end
    if w:find("healing taken") and (w:find("reduc") or w:find("decreas")) then return "reduce" end
    if w:find("absorbs? the next %d+ ?h?e?a?l?i?n?g?") or w:find("healing absorb") or w:find("absorbs? %d+ healing") then return "absorb" end
    if type(dtype) == "string" and dtype ~= "" and dtype ~= "none" then return "dispel" end
    return "watch"
end

--- Can a box filter it by id in a fight? true / false / nil (the client will not say).
function DK.Shown(id)
    local get = C_Secrets and C_Secrets.GetSpellAuraSecrecy
    if not get then return nil end
    local ok, v = pcall(get, id)
    if not ok or v == nil or (NS.Secret and NS.Secret(v)) then return nil end
    local E = Enum and (Enum.SpellAuraSecrecy or Enum.SecrecyLevel or Enum.SpellSecrecy)
    local never = E and E.NeverSecret
    if never == nil then return nil end
    return v == never
end

--- The tooltip's words, or nil while the client has not loaded them.
local function words(id)
    if not (C_Spell and C_Spell.GetSpellDescription) then return nil end
    local ok, d = pcall(C_Spell.GetSpellDescription, id)
    d = ok and plain(d) or nil
    if type(d) ~= "string" or d == "" then return nil end
    return d
end

local function where()
    local z = GetRealZoneText and plain(GetRealZoneText())
    if type(z) == "string" and z ~= "" then return z end
    z = GetZoneText and plain(GetZoneText())
    return type(z) == "string" and z or "?"
end

--- One aura seen on someone: write it down (or count it again). Returns the row, and true when it is new.
function DK.Learn(a)
    local id = field(a, "spellId")
    if type(id) ~= "number" then return nil end
    local book = DK.Book()
    local row = book[id]
    local now = (GetServerTime and plain(GetServerTime())) or 0
    local fresh = row == nil
    if fresh then
        row = { name = field(a, "name"), dtype = field(a, "dispelName"), n = 0, first = now, where = where(),
                boss = field(a, "isBossAura") == true or nil, tries = 0 }
        book[id] = row
        DK.Trim(book)
    end
    row.n, row.last = (row.n or 0) + 1, now
    if not row.desc and (row.tries or 0) < DK.RETRY then
        row.tries = (row.tries or 0) + 1
        local d = words(id)
        if d then row.desc = d:sub(1, DK.DESC) end
    end
    if row.shown == nil then row.shown = DK.Shown(id) end
    local act, pct = DK.Guess(row.desc, row.dtype)
    if act ~= row.act or pct ~= row.pct then
        row.act, row.pct = act, pct
        if act == "past" and NS.HP and NS.HP.Reset then NS.HP.Reset() end      -- a new line: the boxes build it next time
    end
    if fresh then DK.news = (DK.news or 0) + 1 end
    return row, fresh
end

--- Keep the book to DK.MAX rows: the longest unseen go.
function DK.Trim(book)
    local ids = {}
    for id in pairs(book) do ids[#ids + 1] = id end
    if #ids <= DK.MAX then return end
    table.sort(ids, function(x, y) return (book[x].last or book[x].first or 0) < (book[y].last or book[y].first or 0) end)
    for i = 1, #ids - DK.MAX do book[ids[i]] = nil end
end

--- The group, as tokens.
function DK.Units()
    local out = { "player" }
    local n = GetNumGroupMembers and plain(GetNumGroupMembers()) or 0
    if type(n) ~= "number" then n = 0 end
    if IsInRaid and plain(IsInRaid()) then
        for i = 1, n do out[#out + 1] = "raid" .. i end
    else
        for i = 1, 4 do out[#out + 1] = "party" .. i end           -- (the sweep keeps only those that exist)
    end
    return out
end

--- Walk one unit's harmful auras (out of a fight). false = the client refused.
function DK.Walk(unit)
    if NS.Blind and NS.Blind() then return false end
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get then return false end
    for i = 1, 40 do
        local ok, a = pcall(get, unit, i, "HARMFUL")
        if not ok then DK.refused = true return false end
        if not a then break end
        DK.Learn(a)
    end
    return true
end

--- The fight is over: read what it left on everyone.
function DK.Sweep()
    local any = false
    for _, u in ipairs(DK.Units()) do
        local okE, there = pcall(UnitExists, u)
        if okE and plain(there) == true and DK.Walk(u) then any = true end
    end
    return any
end

--- The book's rows for a person to read, newest first: { id, row }.
function DK.Rows()
    local out = {}
    for id, row in pairs(DK.Book()) do out[#out + 1] = { id = id, row = row } end
    table.sort(out, function(x, y) return (x.row.first or 0) > (y.row.first or 0) end)
    return out
end

--- The learned lines for HealPast.lua: { [id] = { pct, name, learned = true } } (only ids a box may filter, or unknown).
function DK.Past()
    local out = {}
    for id, row in pairs(DK.Book()) do
        if row.act == "past" and type(row.pct) == "number" and row.shown ~= false then
            out[id] = { pct = row.pct, name = row.name, learned = true }
        end
    end
    return out
end

DK.WORD = { past = "HEAL PAST", nodispel = "DON'T DISPEL", reduce = "HEALS WEAKER", absorb = "HEALS ABSORBED",
            dispel = "DISPEL", watch = "-" }
--- `/bish debuffs`: the newest rows, one line each.
function DK.Report(max)
    local rows = DK.Rows()
    local lines = { ("debuff book: %d learned%s"):format(#rows, DK.refused and " (the client refused a look here - raids can)" or "") }
    for i = 1, math.min(#rows, max or 10) do
        local r = rows[i].row
        local act = DK.WORD[r.act or "watch"] or "-"
        if r.act == "past" and r.pct then act = act .. " " .. math.floor(r.pct * 100 + 0.5) .. "%" end
        if NS.DD and NS.DD.LIST[rows[i].id] then act = act .. " (known)" end
        lines[#lines + 1] = ("%d %s [%s] %s x%d, %s%s"):format(rows[i].id, tostring(r.name or "?"), tostring(r.dtype or "-"),
            act, r.n or 1, tostring(r.where or "?"),
            r.shown == true and " - shows in a fight" or (r.shown == false and " - HIDDEN in a fight" or ""))
    end
    return lines
end

-- listening: UNIT_AURA only out of a fight, the sweep as one ends
DK.events = CreateFrame("Frame")
function DK.Listen(on)
    if on then DK.events:RegisterEvent("UNIT_AURA") else DK.events:UnregisterEvent("UNIT_AURA") end
    DK.listening = on and true or false
end
DK.events:RegisterEvent("PLAYER_LOGIN")
DK.events:RegisterEvent("PLAYER_REGEN_ENABLED")
DK.events:RegisterEvent("PLAYER_REGEN_DISABLED")
DK.events:SetScript("OnEvent", function(_, event, unit, info)
    if event == "UNIT_AURA" then
        if NS.Blind and NS.Blind() then return end
        if type(info) ~= "table" or (NS.Secret and NS.Secret(info)) then return end
        local added = info.addedAuras
        if type(added) ~= "table" then return end
        for _, a in ipairs(added) do
            if field(a, "isHarmful") == true then DK.Learn(a) end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        DK.Listen(false)
    elseif event == "PLAYER_REGEN_ENABLED" then
        DK.Listen(true)
        DK.Sweep()
    elseif event == "PLAYER_LOGIN" then
        DK.Listen(not (InCombatLockdown and InCombatLockdown()))
    end
end)
