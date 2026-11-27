--[[ BiSHealing / Trinkets.lua (NS.TR) - THE TRINKET PRIORITY LIST (26 Nov 2026).

  Arn, 26 Nov: "need a priority list for each slot kind of like always try and put star its a 30 sec cooldown when you equip a
  triket so a 2 min trinket it we can equit at 1:30 if thats on coold down we put on trinket on prio 2 etc".

  Each trinket slot (13 top, 14 bottom) has its own list, best first. OUT OF A FIGHT ONLY (the game never lets trinkets change in
  one), the slot wears the FIRST trinket on its list that is ready or will be within TR.EQUIP_WAIT: putting a trinket on starts a
  30 second wait on it (the game's rule, UNVERIFIED on Forever - measured by the chip's own countdown the first time), so one
  with 30 s or less left loses nothing by going on now. So a 2 minute trinket used at 0:00 goes back on at 1:30, and while it
  waits the next one on the list that is ready takes its place. A trinket already worn in the other slot is skipped; one you do
  not carry is skipped; nothing qualifies = the slot keeps what it wears.

  When it looks: a fight ending, gear or bags changing, a cooldown starting (coalesced: TR.SOON), and a timer for the moment the
  next better trinket comes within 30 s. Nothing is listened to while both lists are empty (Lean and mean); in a fight every
  event stops at the first test.

  The list lives in the BiS>Deck window's TRINKETS tab (Cues.lua's card, TR.Page): every trinket you carry or wear, a tick = on
  this slot's list, the arrows = its place. Right-click a trinket on the deck opens it; /bish trinkets too (`why`, `now`).
  Saved per character: db().radar.trinketPrio = { [13] = { itemID, ... }, [14] = { ... } }.

  THE EQUIP: C_Item.EquipItemByName(itemID, slot) (the bare global is gone on Forever - the fence). UNVERIFIED that the client
  lets an addon do it: the first try says (TR.why), and a swap that does not take within TR.REFUSED_FOR is reported, not
  retried in a loop. ]]
local _, NS = ...
local TR = {}
NS.TR = TR

TR.SLOTS = { 13, 14 }
TR.EQUIP_WAIT = 30                -- seconds the game makes a trinket wait after it goes on
TR.SOON = 0.3                     -- a burst of events = one look this long after the first
TR.REFUSED_FOR = 3                -- an equip that has not taken by then: refused
TR.ROWS = 9                       -- rows a column shows
TR.why = "nothing looked at yet"

local function fight() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function plain(v) if v == nil or (NS.Secret and NS.Secret(v)) then return nil end return v end
local function now() return (GetTime and GetTime()) or 0 end
local function db()
    local d = NS.DB()
    d.radar = type(d.radar) == "table" and d.radar or {}
    local p = d.radar.trinketPrio
    if type(p) ~= "table" then p = {} d.radar.trinketPrio = p end
    for _, s in ipairs(TR.SLOTS) do if type(p[s]) ~= "table" then p[s] = {} end end
    return p
end

-- ----------------------------------------------------------------- what you carry

--- Is this item a trinket? (GetItemInfoInstant's equip place; nil when the client cannot say yet)
function TR.IsTrinket(id)
    local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(id) ~= "number" or not info then return nil end
    local ok, _, _, _, loc = pcall(info, id)
    loc = ok and plain(loc) or nil
    if loc == nil then return nil end
    return loc == "INVTYPE_TRINKET"
end
function TR.Icon(id)
    local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not info then return nil end
    local ok, _, _, _, _, icon = pcall(info, id)
    return ok and plain(icon) or nil
end
function TR.Name(id)
    local nameOf = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
    if not nameOf then return nil end
    local ok, nm = pcall(nameOf, id)
    nm = ok and plain(nm) or nil
    return type(nm) == "string" and nm or nil
end
--- The item worn in a slot, or nil.
function TR.Worn(slot)
    if not GetInventoryItemID then return nil end
    local ok, id = pcall(GetInventoryItemID, "player", slot)
    id = ok and plain(id) or nil
    return type(id) == "number" and id or nil
end
--- Where an item is: "worn", slot | "bag", bag, slot | nil (not carried).
function TR.Where(id)
    for _, s in ipairs(TR.SLOTS) do if TR.Worn(s) == id then return "worn", s end end
    local C = C_Container
    local nslots = C and C.GetContainerNumSlots
    local itemAt = C and C.GetContainerItemID
    if not (nslots and itemAt) then return nil end
    for bag = 0, 4 do
        local okN, n = pcall(nslots, bag)
        n = okN and plain(n) or 0
        for slot = 1, (type(n) == "number" and n or 0) do
            local okI, it = pcall(itemAt, bag, slot)
            if okI and plain(it) == id then return "bag", bag, slot end
        end
    end
    return nil
end
--- Every trinket you carry or wear, once each: { id, ... }.
function TR.Owned()
    local out, seen = {}, {}
    local function add(id)
        if type(id) == "number" and not seen[id] and TR.IsTrinket(id) then seen[id] = true out[#out + 1] = id end
    end
    for _, s in ipairs(TR.SLOTS) do add(TR.Worn(s)) end
    local C = C_Container
    local nslots = C and C.GetContainerNumSlots
    local itemAt = C and C.GetContainerItemID
    if nslots and itemAt then
        for bag = 0, 4 do
            local okN, n = pcall(nslots, bag)
            n = okN and plain(n) or 0
            for slot = 1, (type(n) == "number" and n or 0) do
                local okI, it = pcall(itemAt, bag, slot)
                if okI then add(plain(it)) end
            end
        end
    end
    return out
end
--- Seconds until it is ready (0 = ready), from where it is; nil when the client will not say.
function TR.Left(id, kind, a, b)
    local start, dur
    if kind == "worn" and GetInventoryItemCooldown then
        local ok, s, d = pcall(GetInventoryItemCooldown, "player", a)
        if ok then start, dur = s, d end
    elseif kind == "bag" and C_Container and C_Container.GetContainerItemCooldown then
        local ok, s, d = pcall(C_Container.GetContainerItemCooldown, a, b)
        if ok then start, dur = s, d end
    end
    start, dur = plain(start), plain(dur)
    if type(start) ~= "number" or type(dur) ~= "number" then return nil end
    if start <= 0 or dur <= 1.5 then return 0 end                         -- (a global cooldown is not a wait)
    return math.max(0, start + dur - now())
end

-- ----------------------------------------------------------------- the list

function TR.List(slot) return db()[slot] or {} end
function TR.InList(slot, id)
    for i, x in ipairs(TR.List(slot)) do if x == id then return i end end
    return nil
end
--- Tick or untick a trinket on a slot's list (a new one goes last).
function TR.SetIn(slot, id, on)
    local list = db()[slot]
    if not list or type(id) ~= "number" then return false end
    local at = TR.InList(slot, id)
    if on and not at then list[#list + 1] = id
    elseif not on and at then table.remove(list, at) end
    TR.Changed()
    return on and true or false
end
--- Move one place up (-1) or down (+1).
function TR.Move(slot, id, dir)
    local list = db()[slot]
    local at = list and TR.InList(slot, id)
    if not at then return false end
    local to = at + dir
    if to < 1 or to > #list then return false end
    list[at], list[to] = list[to], list[at]
    TR.Changed()
    return true
end
function TR.Any()
    for _, s in ipairs(TR.SLOTS) do if #TR.List(s) > 0 then return true end end
    return false
end

-- ----------------------------------------------------------------- the choice

--- The trinket this slot should wear now: the first on its list that is carried, not worn in the other slot, and ready or
--- within TR.EQUIP_WAIT. Answers id, seconds left, why (nil = keep what it wears).
--- A HAND PICK HOLDS (26 Nov 2026, the Shift pop-out): a trinket you put on (or queued) by hand stays on - the list leaves
--- that slot alone - until you USE it (its wait goes past TR.EQUIP_WAIT), then the list takes over again.
function TR.Held(slot)
    local h = TR.hold[slot]
    if not h then return nil end
    if TR.queue[slot] == h then return h end                              -- (still queued for after the fight)
    if TR.Worn(slot) == h then
        local left = TR.Left(h, "worn", slot)
        if left and left > TR.EQUIP_WAIT + 1 then TR.hold[slot] = nil return nil end   -- used: the list again
        return h
    end
    local l = TR.last
    if l and l.slot == slot and l.id == h and now() - l.at < TR.REFUSED_FOR then return h end   -- (the game still at it)
    TR.hold[slot] = nil                                                   -- taken off some other way: let go
    return nil
end
TR.hold, TR.queue = {}, {}

function TR.Choose(slot)
    if TR.Held(slot) then return nil end
    local other = slot == 13 and 14 or 13
    local otherWorn = TR.Worn(other)
    for i, id in ipairs(TR.List(slot)) do
        if id ~= otherWorn then
            local kind, a, b = TR.Where(id)
            if kind then
                local left = TR.Left(id, kind, a, b)
                if left and left <= TR.EQUIP_WAIT + 0.05 then return id, left, i end
            end
        end
    end
    return nil
end
--- When a better trinket than the one worn comes within the wait: seconds from now, or nil.
function TR.NextLook()
    local soonest
    for _, slot in ipairs(TR.SLOTS) do
        local worn = TR.Worn(slot)
        local otherWorn = TR.Worn(slot == 13 and 14 or 13)
        for _, id in ipairs(TR.List(slot)) do
            if id == worn then break end                                    -- (only the ones above it)
            if id ~= otherWorn then
                local kind, a, b = TR.Where(id)
                local left = kind and TR.Left(id, kind, a, b)
                if left and left > TR.EQUIP_WAIT then
                    local t = left - TR.EQUIP_WAIT
                    if not soonest or t < soonest then soonest = t end
                end
            end
        end
    end
    return soonest
end

--- Look now: out of a fight, put on each slot's choice (one swap a look; the gear change looks again).
function TR.Check(why)
    TR.soon = nil
    if not TR.Any() then TR.why = "no trinket on either list" return false end
    if fight() then TR.why = "in a fight: after it" TR.afterFight = true return false end
    if UnitIsDeadOrGhost then
        local ok, dead = pcall(UnitIsDeadOrGhost, "player")
        if ok and plain(dead) then TR.why = "dead: not now" return false end
    end
    -- (never under a cast: a swap would not wait for it)
    local casting = false
    for _, f in ipairs({ UnitCastingInfo, UnitChannelInfo }) do
        if f then
            local ok, name = pcall(f, "player")
            if ok and name ~= nil then casting = true end
        end
    end
    if casting then TR.why = "casting: in a moment" TR.Soon(1) return false end
    local t = now()
    for _, slot in ipairs(TR.SLOTS) do
        local pick, left, place = TR.Choose(slot)
        local worn = TR.Worn(slot)
        if pick and pick ~= worn then
            local last = TR.last
            if last and last.slot == slot and last.id == pick and t - last.at < TR.REFUSED_FOR then
                TR.why = "waiting for the game to put on " .. (TR.Name(pick) or pick)
                return false
            end
            if last and last.slot == slot and last.id == pick and last.refused then
                TR.why = "the game refused " .. (TR.Name(pick) or pick) .. " - put it on by hand once"
                return false
            end
            local ok = TR.Equip(slot, pick)
            if ok then
                TR.why = ("slot %d: %s on (no. %d on its list, %s) - %s"):format(slot, TR.Name(pick) or pick, place,
                    left > 0 and ("%d s left"):format(math.ceil(left)) or "ready", why or "a look")
            end
            return ok
        end
    end
    TR.why = "both slots wear their best (" .. (why or "a look") .. ")"
    TR.Timer()
    return false
end
--- Put a trinket on a slot now (out of a fight): the client's equip, remembered in TR.last; one that has not taken by
--- TR.REFUSED_FOR is marked refused (said once, never retried in a loop).
function TR.Equip(slot, id)
    if fight() then return false end
    local eq = C_Item and C_Item.EquipItemByName
    if not eq then TR.why = "this client has no way to put a trinket on" return false end
    local ok, err = pcall(eq, id, slot)
    TR.last = { slot = slot, id = id, at = now(), from = TR.Worn(slot) }
    if not ok then TR.why = "the game refused: " .. tostring(err) return false end
    TR.why = ("slot %d: %s on"):format(slot, TR.Name(id) or id)
    if C_Timer and C_Timer.After then
        C_Timer.After(TR.REFUSED_FOR, function()
            local l = TR.last
            if l and l.id == id and l.slot == slot and TR.Worn(slot) ~= id then
                l.refused = true
                TR.why = "the game did not put on " .. (TR.Name(id) or id) .. " - put it on by hand once"
            end
        end)
    end
    return true
end
--- A look in `s` seconds (one waiting at a time: the sooner wins).
function TR.Soon(s)
    if not (C_Timer and C_Timer.After) then return end
    local at = now() + (s or TR.SOON)
    if TR.soon and TR.soon <= at then return end
    TR.soon = at
    C_Timer.After(s or TR.SOON, function() if TR.soon and TR.soon <= now() + 0.01 then TR.Check("a cooldown") end end)
end
--- The timer for the next better trinket's moment.
function TR.Timer()
    local t = TR.NextLook()
    if not t or not (C_Timer and C_Timer.After) then return nil end
    TR.token = (TR.token or 0) + 1
    local token = TR.token
    C_Timer.After(t + 0.2, function() if token == TR.token then TR.Check("one came within 30 s") end end)
    return t
end

-- ----------------------------------------------------------------- events

TR.EVENTS = { "PLAYER_REGEN_ENABLED", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN",
              "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" }
TR.frame = CreateFrame("Frame")
TR.frame:SetScript("OnEvent", function(_, event)
    if fight() then TR.afterFight = true return end                       -- (one test in a fight, nothing else)
    if event == "PLAYER_REGEN_ENABLED" then
        TR.afterFight = nil
        TR.RunQueue()                                                     -- (a pick made in the fight goes on first)
        if TR.Any() then TR.Soon(0.5) end
        return
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        local l = TR.last
        if l and TR.Worn(l.slot) == l.id then l.refused = nil end
        if TR.page and TR.page:IsShown() then TR.Paint() end
    end
    TR.Soon()
end)
--- Listen only while a list holds something.
function TR.Listen()
    local any = TR.Any() or next(TR.queue) ~= nil                         -- (a queued pick needs the fight's end too)
    if any == TR.listening then return any end
    TR.listening = any
    for _, ev in ipairs(TR.EVENTS) do
        if any then pcall(TR.frame.RegisterEvent, TR.frame, ev) else pcall(TR.frame.UnregisterEvent, TR.frame, ev) end
    end
    return any
end
function TR.Changed()
    TR.last = nil
    TR.Listen()
    if TR.page and TR.page:IsShown() then TR.Paint() end
    if TR.Any() then TR.Soon() end
end
TR.boot = CreateFrame("Frame")
TR.boot:RegisterEvent("PLAYER_LOGIN")
TR.boot:SetScript("OnEvent", function() TR.Listen() end)

--- /bish trinkets why: each slot's list and what it wears.
function TR.Report()
    local out = { "trinkets: " .. (TR.why or "-") }
    for _, slot in ipairs(TR.SLOTS) do
        local names = {}
        for i, id in ipairs(TR.List(slot)) do names[#names + 1] = i .. ". " .. (TR.Name(id) or ("item " .. id)) end
        local worn = TR.Worn(slot)
        out[#out + 1] = ("  slot %d wears %s; list: %s"):format(slot, worn and (TR.Name(worn) or worn) or "nothing",
            #names > 0 and table.concat(names, ", ") or "empty")
    end
    return out
end

-- ----------------------------------------------------------------- the Shift pop-out

--[[ SHIFT + HOVER A TRINKET (26 Nov 2026, Arn: "hold shift on the [trinket] so i can switch on the fly out of combat? maybe it
  que if i do in combat?"). The totem boxes' hand: Shift over a deck trinket = the trinkets in your bags drop down under it
  (up only at the screen's foot). Let go of Shift on one, or click it: out of a fight it goes on now; IN A FIGHT it is
  QUEUED (the game never changes trinkets in one) - its icon rides the chip's corner - and goes on the moment the fight
  ends. A hand pick holds against the priority list until you use it (TR.Held).
  NOTHING SECURE: the column and its icons are plain frames on UIParent (they show, take clicks and anchor in a fight); the
  chip itself is untouched - its own click still uses the worn trinket. ]]
TR.FLY = { gap = 2, off = 0.3, margin = 6, max = 10 }

--- The trinkets you could put on this slot: carried in the bags, not worn in either slot.
function TR.FlyList(slot)
    local out = {}
    for _, id in ipairs(TR.Owned()) do
        if id ~= TR.Worn(13) and id ~= TR.Worn(14) then out[#out + 1] = id end
        if #out >= TR.FLY.max then break end
    end
    return out
end

function TR.FlyButton(col, i)
    local b = CreateFrame("Button", nil, col)
    if b.RegisterForClicks then b:RegisterForClicks("AnyUp") end
    b.edge = b:CreateTexture(nil, "BACKGROUND")
    b.edge:SetAllPoints(b)
    local P = (NS.RD and NS.RD.TRINK_BOX_COL) or { 1, 0.45, 0.92 }
    b.edge:SetColorTexture(P[1], P[2], P[3], 1)
    b.pic = b:CreateTexture(nil, "ARTWORK")
    b.pic:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.pic:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    if b.pic.SetTexCoord then b.pic:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")                        -- (it pops on hover, like every clickable thing)
    b.hl:SetAllPoints(b)
    b.hl:SetColorTexture(1, 1, 1, 0.25)
    b:SetScript("OnEnter", function(self)
        TR.flyHover = self
        if not (GameTooltip and self.id) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")                 -- (to the side: never over the column)
        if not (GameTooltip.SetHyperlink and pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. self.id)) then
            GameTooltip:AddLine(TR.Name(self.id) or "a trinket")
        end
        GameTooltip:AddLine(fight() and "Click or let go of Shift: it goes on when this fight ends."
            or "Click or let go of Shift: put it on now.", 0.6, 0.85, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        if TR.flyHover == self then TR.flyHover = nil end
        if GameTooltip then GameTooltip:Hide() end
    end)
    b:SetScript("OnClick", function(self) if self.id and col.slot then TR.Pick(col.slot, self.id, "a click") end end)
    return b
end

--- Open the column under a chip (in a fight too: plain frames).
function TR.OpenFly(chip)
    local slot = chip and chip.slot
    if not slot then return false end
    local list = TR.FlyList(slot)
    if #list == 0 then TR.flyWhy = "no other trinket in your bags" return false end
    local col = TR.col
    if not col then
        col = CreateFrame("Frame", "BiSHealingTrinketFly", UIParent)
        col:SetFrameStrata("DIALOG")
        col.bg = col:CreateTexture(nil, "BACKGROUND")
        col.bg:SetAllPoints(col)
        col.bg:SetColorTexture(0, 0, 0, 0.85)
        col.b = {}
        col:Hide()
        TR.col = col
    end
    local size = math.max(16, math.floor(((chip.GetHeight and chip:GetHeight()) or 22) + 0.5))
    local gap = TR.FLY.gap
    col.slot, col.chip = slot, chip
    col:SetSize(size + 2 * gap, #list * (size + gap) + gap)
    if col.SetScale and chip.GetEffectiveScale and UIParent.GetEffectiveScale then
        local cs, us = chip:GetEffectiveScale(), UIParent:GetEffectiveScale()
        if type(cs) == "number" and type(us) == "number" and us > 0 then col:SetScale(cs / us) end
    end
    local RD = NS.RD
    local down = not (RD and RD.FlyDir) or RD.FlyDir(chip, col:GetHeight()) == "down"   -- (down first, as the totems)
    col:ClearAllPoints()
    if down then col:SetPoint("TOPLEFT", chip, "BOTTOMLEFT", 0, 0) else col:SetPoint("BOTTOMLEFT", chip, "TOPLEFT", 0, 0) end
    for i, id in ipairs(list) do
        local b = col.b[i] or TR.FlyButton(col, i)
        col.b[i] = b
        b.id = id
        b:SetSize(size, size)
        b:ClearAllPoints()
        local y = gap + (i - 1) * (size + gap)                          -- (the first nearest the chip)
        if down then b:SetPoint("TOP", col, "TOP", 0, -y) else b:SetPoint("BOTTOM", col, "BOTTOM", 0, y) end
        local icon = TR.Icon(id)
        if icon then b.pic:SetTexture(icon) end
        b.pic:SetAlpha(TR.queue[slot] == id and 0.5 or 1)              -- (the one already queued: dimmed)
        b:Show()
    end
    for i = #list + 1, #col.b do col.b[i]:Hide() end
    col.count = #list
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(chip) then GameTooltip:Hide() end
    local RD = NS.RD
    if RD and RD.CloseFly and RD.flyFrom then RD.CloseFly("a trinket opened") end   -- (one pop-out at a time)
    TR.flyFrom, TR.flyOffAt = chip, nil
    col:Show()
    TR.flyWatch:Show()
    TR.flyWhy = "opened: " .. #list .. " to pick"
    return true
end
function TR.CloseFly(why)
    TR.flyFrom, TR.flyHover, TR.flyOffAt = nil, nil, nil
    if TR.flyWatch then TR.flyWatch:Hide() end
    if TR.col then TR.col:Hide() end
    if why then TR.flyWhy = why end
end

--- A pick: out of a fight on now, in one queued for its end. Held against the list either way.
function TR.Pick(slot, id, why)
    TR.CloseFly("picked " .. (TR.Name(id) or id))
    TR.hold[slot] = id
    if fight() then
        TR.queue[slot] = id
        TR.why = ("slot %d: %s queued for the fight's end (%s)"):format(slot, TR.Name(id) or id, why or "a pick")
        TR.Listen()
        TR.PaintQueue()
        return "queued"
    end
    TR.queue[slot] = nil
    TR.PaintQueue()
    return TR.Equip(slot, id) and "on" or false
end
--- The fight over: what was queued goes on.
function TR.RunQueue()
    if fight() then return 0 end
    local n = 0
    for _, slot in ipairs(TR.SLOTS) do
        local id = TR.queue[slot]
        if id then
            TR.queue[slot] = nil
            if TR.Worn(slot) ~= id and TR.Equip(slot, id) then n = n + 1 end
        end
    end
    TR.PaintQueue()
    TR.Listen()
    return n
end
--- The queued trinket's icon in its chip's corner (the pink box's top right).
function TR.PaintQueue()
    local RD = NS.RD
    for _, key in ipairs({ "trink1", "trink2" }) do
        local b = RD and RD[key]
        if b and b.pink then
            local id = b.slot and TR.queue[b.slot]
            if id and not b.queued then
                b.queued = b.pink:CreateTexture(nil, "OVERLAY")
                b.queued:SetSize(12, 12)
                b.queued:SetPoint("TOPRIGHT", b.pink, "TOPRIGHT", -1, -1)
                if b.queued.SetTexCoord then b.queued:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
            end
            if b.queued then
                if id then
                    local icon = TR.Icon(id)
                    if icon then b.queued:SetTexture(icon) end
                    b.queued:Show()
                else
                    b.queued:Hide()
                end
            end
        end
    end
end

--- Is the mouse on it (a little round it: the gap between chip and column counts)?
local function over(fr)
    if not (fr and fr.IsMouseOver) then return false end
    local m = TR.FLY.margin
    local fine, yes = pcall(fr.IsMouseOver, fr, m, -m, -m, m)
    return fine and yes and true or false
end
TR.flyWatch = CreateFrame("Frame")
TR.flyWatch:Hide()
TR.flyWatch:SetScript("OnUpdate", function()
    if not TR.flyFrom then TR.flyWatch:Hide() return end
    -- ONE POP-OUT AT A TIME (Arn, 26 Nov: "if i put my mouse right in the gap both open"): a totem column showing (in a
    -- fight the game's snippets open those) and the mouse off this trinket = this one goes
    local RD = NS.RD
    local onChip = TR.flyOver == TR.flyFrom or over(TR.flyFrom.pink) or over(TR.flyFrom)
    if not onChip and not over(TR.col) and RD and RD.flyCols then
        for _, c in pairs(RD.flyCols) do if c:IsShown() then TR.CloseFly("a totem column opened") return end end
    end
    -- THE WHOLE CHIP COUNTS (Arn, 26 Nov: "on the icon holding shift it stays open on the words it blinks"): the click
    -- spot covers the word (its hit rect), so does this - the mouse still inside it (no OnLeave yet), or on its pink box
    if onChip or over(TR.col) then TR.flyOffAt = nil return end
    TR.flyOffAt = TR.flyOffAt or now()
    if now() - TR.flyOffAt >= TR.FLY.off then TR.CloseFly("the mouse left") end
end)
-- Shift: heard only while the mouse is on a chip or the column is open
TR.flyKeys = CreateFrame("Frame")
TR.flyKeys:SetScript("OnEvent", function(_, _, key, down)
    if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
    if down == 1 then
        if not TR.flyFrom and TR.flyOver then TR.OpenFly(TR.flyOver) end
    elseif TR.flyFrom and TR.flyHover and TR.flyHover.id and TR.col and TR.col.slot then
        TR.Pick(TR.col.slot, TR.flyHover.id, "Shift let go")
    end
end)
local function keys(on)
    if on then pcall(TR.flyKeys.RegisterEvent, TR.flyKeys, "MODIFIER_STATE_CHANGED")
    else pcall(TR.flyKeys.UnregisterEvent, TR.flyKeys, "MODIFIER_STATE_CHANGED") end
end
--- A deck chip learns the hand (Radar.lua RD.TrinketChip calls this once per chip).
function TR.HookChip(b)
    if not b or b.trHooked then return end
    b.trHooked = true
    b:HookScript("OnEnter", function(self)
        TR.flyOver = self
        keys(true)
        if IsShiftKeyDown and IsShiftKeyDown() and not TR.flyFrom then TR.OpenFly(self) end
    end)
    b:HookScript("OnLeave", function(self)
        if TR.flyOver == self then TR.flyOver = nil end
        if not TR.flyFrom then keys(false) end
    end)
end
local closeFly = TR.CloseFly
function TR.CloseFly(why)
    closeFly(why)
    if not TR.flyOver then keys(false) end
end

-- ----------------------------------------------------------------- the TRINKETS tab

--- The rows of one column: the list first (in order), then the other trinkets you carry, dim.
function TR.Rows(slot)
    local rows, seen = {}, {}
    for i, id in ipairs(TR.List(slot)) do rows[#rows + 1] = { id = id, place = i } seen[id] = true end
    for _, id in ipairs(TR.Owned()) do if not seen[id] then rows[#rows + 1] = { id = id } end end
    return rows
end

function TR.Page(card)
    if TR.page then return TR.page end
    local K = NS.CU and NS.CU.Kit
    if not K then return nil end
    local INK, DIM, ACC, GOLD, GOOD = K.tones()
    local p = CreateFrame("Frame", nil, card)
    p:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -24)
    p:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
    p.cols = {}
    for c, slot in ipairs(TR.SLOTS) do
        local x = 10 + (c - 1) * 222
        local head = K.text(p, 9, GOLD)
        head:SetPoint("TOPLEFT", p, "TOPLEFT", x, -6)
        head:SetText(slot == 13 and "TOP TRINKET SLOT - BEST FIRST" or "BOTTOM TRINKET SLOT - BEST FIRST")
        local col = { slot = slot, rows = {} }
        for i = 1, TR.ROWS do
            local row = CreateFrame("Button", nil, p)
            row:SetSize(212, 20)
            row:SetPoint("TOPLEFT", p, "TOPLEFT", x - 4, -20 - (i - 1) * 21)
            K.hoverRow(row)
            row.tick = CreateFrame("Button", nil, row)
            row.tick:SetSize(11, 11)
            row.tick:SetPoint("LEFT", row, "LEFT", 5, 0)
            row.tick.edges = K.edges(row.tick, DIM)
            row.tick.fill = row.tick:CreateTexture(nil, "ARTWORK")
            row.tick.fill:SetPoint("TOPLEFT", row.tick, "TOPLEFT", 2, -2)
            row.tick.fill:SetPoint("BOTTOMRIGHT", row.tick, "BOTTOMRIGHT", -2, 2)
            row.tick.fill:SetColorTexture(GOOD[1], GOOD[2], GOOD[3], 1)
            row.tick:SetScript("OnClick", function() if row.id then TR.SetIn(slot, row.id, not TR.InList(slot, row.id)) end end)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(16, 16)
            row.icon:SetPoint("LEFT", row.tick, "RIGHT", 5, 0)
            if row.icon.SetTexCoord then row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
            row.text = K.text(row, 10, INK)
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
            row.text:SetWidth(130)
            row.text:SetJustifyH("LEFT")
            if row.text.SetWordWrap then row.text:SetWordWrap(false) end
            row.up = K.button(row, 14, 14, "^", function() if row.id then TR.Move(slot, row.id, -1) end end)
            row.up:SetPoint("RIGHT", row, "RIGHT", -18, 0)
            row.down = K.button(row, 14, 14, "v", function() if row.id then TR.Move(slot, row.id, 1) end end)
            row.down:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            row:SetScript("OnClick", function() if row.id then TR.SetIn(slot, row.id, not TR.InList(slot, row.id)) end end)
            row:HookScript("OnEnter", function(self)
                if not (self.id and GameTooltip) then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if not (GameTooltip.SetHyperlink and pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. self.id)) then
                    GameTooltip:AddLine(TR.Name(self.id) or "a trinket")
                end
                GameTooltip:AddLine("Tick: on this slot's list.  Arrows: its place - the deck wears the first one that is ready "
                    .. "or 30 s from ready, out of a fight.", 0.6, 0.85, 1, true)
                GameTooltip:Show()
            end)
            row:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            row:Hide()
            col.rows[i] = row
        end
        p.cols[c] = col
    end
    p.help = K.text(p, 9, DIM)
    p.help:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 10, 46)
    p.help:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -10, 46)
    p.help:SetJustifyH("LEFT")
    p.help:SetText("Out of a fight, each slot wears the first ticked trinket that is ready or 30 s from ready - putting one on "
        .. "starts a 30 s wait, so nothing is lost. Nothing changes in a fight.")
    p.status = K.text(p, 9, ACC)
    p.status:SetPoint("TOPLEFT", p.help, "BOTTOMLEFT", 0, -3)
    p.status:SetPoint("TOPRIGHT", p.help, "BOTTOMRIGHT", 0, -3)
    p.status:SetJustifyH("LEFT")
    p:SetScript("OnShow", function() TR.Paint() end)
    p.tones = { INK = INK, DIM = DIM }
    TR.page = p
    return p
end

function TR.Paint()
    local p = TR.page
    if not p then return 0 end
    local n = 0
    for _, col in ipairs(p.cols) do
        local rows = TR.Rows(col.slot)
        local worn = TR.Worn(col.slot)
        for i, row in ipairs(col.rows) do
            local r = rows[i]
            if r then
                row.id = r.id
                local name = TR.Name(r.id) or ("item " .. r.id)
                local mark = (r.id == worn) and "  (worn)" or ""
                row.text:SetText(r.place and (r.place .. ". " .. name .. mark) or (name .. mark))
                local c = r.place and p.tones.INK or p.tones.DIM
                row.text:SetTextColor(c[1], c[2], c[3], 1)
                if r.place then row.tick.fill:Show() row.up:Show() row.down:Show()
                else row.tick.fill:Hide() row.up:Hide() row.down:Hide() end
                local icon = TR.Icon(r.id)
                if icon then row.icon:SetTexture(icon) row.icon:Show() else row.icon:Hide() end
                row:Show()
                n = n + 1
            else
                row.id = nil
                row:Hide()
            end
        end
    end
    p.status:SetText(n == 0 and "You carry no trinkets." or ("Last look: " .. (TR.why or "-")))
    return n
end
