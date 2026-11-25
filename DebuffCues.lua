--[[
  BiSHealing / Forever :: DebuffCues.lua - WHAT TO DO ABOUT A DEBUFF, ON THE DECK BOX (24 Nov 2026).

  Arn, 24 Nov: "our cues are gonna tell you heal past this, don't heal this target right now, dispel this poison, do not
  dispel this poison". Placement (his pick of three, https://claude.ai/artifact/VokdMsi1w5ohZ3ooB8PFAE): "C across the
  bar, but put the icons next to the name ... I see the tanks name and I can see the armor buff icon and if they have
  mortal strike" - and the bar never says two words: "will it say [Chain Heal] and [Cure]" - no, ONE, the most urgent.

  TWO CONTAINERS PER BOX, both drawn by the client only while a matching aura is on them (nothing here reads one):
    THE ICON ROW  right after the name (DC.PlaceRow: the name's width measured out of a fight, on the box's own frame -
                  never anchored to the name, which made the row secret): one slot per kind at a fixed step (gaps when
                  absent), the auras' own icons. The flow row (AddAuraGroup with `layout`) is gone (24 Nov): on Forever
                  it answered nil yet was made, and a second slot went on top of it.
    THE WORD      across the middle of the bar: one slot per kind, each word on a plate at its own frame level by
                  urgency - the client shows whichever are up, and the highest one's plate covers the rest (and Chain
                  Heal's payoff word, which sits under them all). Order: MIND CONTROL, NO HEAL, NO CURE, CURE, HEAL PAST,
                  -N%.
  MIND CONTROL is no aura: a friend the game says you can attack (UnitCanAttack - a secret answer goes to
  SetAlphaFromBoolean), never on the target / target-of-target boxes or pets.

  WHO SEES WHAT (Arn: "all stuff that our class can do"): CURE and NO CURE only for debuffs of a type YOUR cures remove
  (FA.Cures); the rest for every healer. TANK ARMOR (Ancestral Fortitude / Inspiration from anyone, Arn: "big in raid to
  track that the tanks have that buff even if it's not ours") on EVERY box ("we can display those buffs on everyone i just
  said tanks because that's who i really care about").

  Every kind is its own BiS Cues row, off by default. The data: Debuffs.lua (known) + DebuffBook.lua (learned lines).
  UNVERIFIED LIVE: the spell-id filter on a FRIENDLY debuff in a fight (only NeverSecret ids, solved.md 15 Oct); the flow
  row; the stacking of the word plates.
]]
local ADDON, NS = ...
NS = NS or {}

local DC = {}
NS.DC = DC

-- the words, most urgent first (rank = frame level over the bar; Chain Heal's word is under all of them)
DC.WORDS = {
    { key = "mc",     word = "MIND CONTROL", col = { 1, 0.35, 0.31 }, rank = 7 },
    { key = "noheal", word = "NO HEAL",      col = { 1, 0.35, 0.31 }, rank = 6 },
    { key = "nocure", word = "NO CURE",      col = { 1, 0.76, 0.30 }, rank = 5 },
    { key = "cure",   word = "CURE",         col = { 1, 0.35, 0.31 }, rank = 4 },
    { key = "past",   word = "HEAL PAST",    col = { 1, 1, 1 },       rank = 3 },
    { key = "reduce", word = "-%d%%",        col = { 1, 0.76, 0.30 }, rank = 1 },   -- one per cut, the bigger cut higher
}
-- the icon row's order, left to right
DC.ROW = { "armor", "reduce", "cure", "nocure", "noheal", "past" }
DC.PLATE = { 0.05, 0.06, 0.07, 0.92 }
DC.FONT, DC.SIZE = "Fonts\\ARIALN.TTF", 11
DC.GAP = 2
DC.NOT_MC = { target = true, targettarget = true }

local function secret(v) return NS.Secret and NS.Secret(v) end
local function on(key) local CU = NS.CU return CU and CU.On and CU.On(key) or false end

--- The types this character's cures remove: { Poison = true, ... }.
function DC.MyTypes()
    local out = {}
    local FA = NS.FA
    for _, c in ipairs((FA and FA.Cures and FA.Cures()) or {}) do
        for t in pairs(c.types or {}) do out[t] = true end
    end
    return out
end

--- The spell ids for one kind: { [id] = true } (empty = nothing to watch). `cut` picks one reduce group.
function DC.Ids(kind, cut)
    local out, DD = {}, NS.DD
    local list = DD and DD.LIST or {}
    if kind == "armor" then
        for id in pairs((DD and DD.TANK_BUFFS) or {}) do out[id] = true end
    elseif kind == "past" then
        for id in pairs((NS.HP and NS.HP.All and NS.HP.All()) or {}) do out[id] = true end
    elseif kind == "cure" or kind == "nocure" then
        local mine = DC.MyTypes()
        for id, r in pairs(list) do
            local want
            if kind == "nocure" then want = r.act == "nodispel" else want = r.act ~= "nodispel" end
            if want and r.dtype and mine[r.dtype] then out[id] = true end
        end
    elseif kind == "reduce" then
        for id, r in pairs(list) do if r.act == "reduce" and (cut == nil or r.cut == cut) then out[id] = true end end
    elseif kind == "noheal" then
        for id, r in pairs(list) do if r.act == "noheal" then out[id] = true end end
    end
    return out
end

--- The reduce groups, biggest cut first: { 0.75, 0.5, ... }.
function DC.Cuts()
    local seen, out = {}, {}
    for _, r in pairs((NS.DD and NS.DD.LIST) or {}) do
        if r.act == "reduce" and r.cut and not seen[r.cut] then seen[r.cut] = true out[#out + 1] = r.cut end
    end
    table.sort(out, function(a, b) return a > b end)
    return out
end

--- The kinds switched on (the same on every box - tank armor too, Arn 24 Nov: "we can display those buffs on everyone").
function DC.Kinds()
    local k = {}
    for _, key in ipairs(DC.ROW) do
        if on(key) and next(DC.Ids(key)) then k[#k + 1] = key end
    end
    return k
end

-- ----------------------------------------------------------------- the name's end (anchor for the row)

--- An invisible copy of the name with no width: its right edge is where the name ends (a secret name too).
function DC.Ghost(sp)
    local t = sp.deckTag
    if not (t and t.text) then return nil end
    local g = t.dcGhost
    if not g then
        g = t:CreateFontString(nil, "OVERLAY")
        local okF, font, size, flags = pcall(t.text.GetFont, t.text)
        g:SetFont(okF and font or DC.FONT, okF and size or 10, okF and flags or "OUTLINE")
        local okP, p, rel, rp, x, y = pcall(t.text.GetPoint, t.text, 1)
        if okP and p then g:SetPoint(p, rel, rp, x, y) else g:SetPoint("TOPLEFT", t, "TOPLEFT", 4, -3) end
        g:SetAlpha(0)
        t.dcGhost = g
    end
    local RD = NS.RD
    g:SetText((RD and RD.DeckName and RD.DeckName(sp)) or "")
    return g
end

--- WHERE THE ICON ROW SITS, by numbers we may read (Arn, 24 Nov, `/bish dc`: the row anchored to the name's invisible copy
--- had a SECRET width - a name is secret, so everything hung off it is too - and the client handed it 55 buttons and drew
--- none). Now never anchored to the name: the name's width MEASURED (out of a fight it is plain) and the row put that far
--- along the box's own frame, just after the name; a name we may not measure = the box's top-right corner (left of the
--- G2 tag). Returns "name" / "corner".
function DC.PlaceRow(sp, row)
    if not (row and row.ClearAllPoints) then return nil end
    row:ClearAllPoints()
    local RD, t = NS.RD, sp.deckTag
    local tag = (RD and RD.DECK_TAG) or { x = 4, y = -3 }
    if t and t.text and (not t.text.IsShown or t.text:IsShown()) then
        local okS, sw = pcall(t.text.GetStringWidth, t.text)
        local okB, bw = pcall(t.text.GetWidth, t.text)
        if okS and type(sw) == "number" and not secret(sw) then
            if okB and type(bw) == "number" and not secret(bw) and bw > 0 then sw = math.min(sw, bw) end
            row:SetPoint("TOPLEFT", t, "TOPLEFT", (tag.x or 4) + sw + 3, (tag.y or -3) + 1)
            return "name"
        end
    end
    local corner = (t and t.group and t.group.IsShown and t.group:IsShown() and RD and RD.CORNER_W) or 0
    row:SetPoint("TOPRIGHT", sp.heal, "TOPRIGHT", -2 - corner, -2)
    return "corner"
end

-- ----------------------------------------------------------------- building

local function quiet(button)
    if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
    if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, false) end
    if button.EnableMouse then pcall(button.EnableMouse, button, false) end
end

--- THE AURA'S OWN ICON (24 Nov 2026, Arn's shot: one slot per kind, a button handed over each, and nothing on the box - not
--- even the probe's any-buff slot). The client's button comes BARE: it draws the aura's art only into a texture the addon
--- made and registered with button:SetIcon inside initializeFrame (EllesmereUI's AuraKit notes, learn only: "the engine
--- only ever sets its texture"). So each icon slot gets a dark edge and a texture handed to SetIcon; after the creation
--- window the button is the client's again. Returns true when the client took the texture.
function DC.Dress(button)
    quiet(button)
    local ok = pcall(function()
        local edge = button:CreateTexture(nil, "BACKGROUND")
        edge:SetAllPoints(button)
        edge:SetColorTexture(0, 0, 0, 0.85)
        local tex = button:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button:SetIcon(tex)
        button.dcIcon = tex
    end)
    if not ok then DC.iconRefused = true end
    return ok
end

--- The word on its plate, over the bar, at its rank (made inside the client's button: it comes and goes with the aura).
function DC.Word(parent, sp, text, col, rank)
    local bar = sp.heal
    local w = CreateFrame("Frame", nil, parent)
    w:SetAllPoints(bar)
    local hl = bar.GetFrameLevel and bar:GetFrameLevel()
    if type(hl) == "number" then w:SetFrameLevel(hl + 7 + rank) end
    local bw = bar.GetWidth and bar:GetWidth()
    bw = (type(bw) == "number" and bw > 0) and bw or 80
    local plate = w:CreateTexture(nil, "ARTWORK")
    plate:SetColorTexture(DC.PLATE[1], DC.PLATE[2], DC.PLATE[3], DC.PLATE[4])
    plate:SetSize(math.max(30, math.min(120, bw - 8)), DC.SIZE + 5)        -- one width for every word: the top one covers all
    plate:SetPoint("CENTER", bar, "CENTER", 0, 0)
    local fs = w:CreateFontString(nil, "OVERLAY")
    if fs.SetFont then fs:SetFont(DC.FONT, DC.SIZE, "OUTLINE") end
    fs:SetPoint("CENTER", bar, "CENTER", 0, 0)
    fs:SetTextColor(col[1], col[2], col[3], 1)
    fs:SetText(text)
    w.plate, w.text = plate, fs
    return w
end

--- One box's containers, for its unit and the kinds on now (made again when the kinds change, out of a fight).
--- One aura slot, made once (Reveal.lua's road, 22 Nov 2026): a FRESH key every time (a key the client already knows may be
--- the refusal), AddAuraSlot first; no answer but a button handed over = made; only a slot that handed nothing over tries
--- AddAuraGroup. Never a second slot on top of one the client took. Counts the buttons per kind in `d.handedBy`.
--- Returns the slot (or true) and the road taken: "slot" / "slot, no answer" / "group" / "refused: ...".
function DC.MakeSlot(c, key, filter, opts, d, kind)
    DC.made = (DC.made or 0) + 1
    local count, init = 0, opts.initializeFrame
    opts.initializeFrame = function(b, ...)
        count = count + 1
        if d then
            d.handed = (d.handed or 0) + 1
            d.handedBy = d.handedBy or {}
            d.handedBy[kind or key] = (d.handedBy[kind or key] or 0) + 1
        end
        if init then return init(b, ...) end
    end
    if c.AddAuraSlot then
        local fine, got = pcall(c.AddAuraSlot, c, key .. DC.made, filter, opts)
        if fine and got then return got, "slot" end
        if fine and count > 0 then return true, "slot, no answer" end
        if count > 0 then return nil, "refused: " .. tostring(got) end      -- it handed buttons over and then said no
    end
    if c.AddAuraGroup then
        opts.maxFrameCount = opts.maxFrameCount or 1
        local fine, got = pcall(c.AddAuraGroup, c, key .. "G" .. DC.made, filter, opts)
        if fine and (got or count > 0) then return got or true, "group" end
        return nil, "refused: " .. tostring(got)
    end
    return nil, "no method"
end

function DC.Arm(sp)
    local FA = NS.FA
    if not (FA and FA.Available and FA.Available() and FA.AddSlot and sp.heal and sp.unit) then return false end
    local d = sp.dc
    -- LEAN: nothing switched on = nothing asked (every box repaint passes here)
    local any = false
    for _, key in ipairs(DC.ROW) do if on(key) then any = true break end end
    if not any then
        if d and d.sig ~= "" then
            for _, c in ipairs({ d.row, d.words }) do if c and c.SetEnabled then pcall(c.SetEnabled, c, false) end end
            d.sig = "off"
        end
        return false
    end
    local inFight = InCombatLockdown and InCombatLockdown()
    local kinds = DC.Kinds()
    local sig = table.concat(kinds, ",")
    if d and d.sig == sig then
        if d.unit ~= sp.unit then
            for _, c in ipairs({ d.row, d.words }) do if c then pcall(c.SetUnit, c, sp.unit) end end
            d.unit = sp.unit
            if d.row then d.where = DC.PlaceRow(sp, d.row) end
        end
        for _, c in ipairs({ d.row, d.words }) do if c and c.SetEnabled then pcall(c.SetEnabled, c, true) end end
        return true
    end
    if inFight and d then return true end                -- a fight keeps what it has
    if d then for _, c in ipairs({ d.row, d.words }) do if c and c.SetEnabled then pcall(c.SetEnabled, c, false) end end end
    d = { sig = sig, unit = sp.unit, kinds = kinds }
    sp.dc = d
    if #kinds == 0 then return true end
    local ghost = DC.Ghost(sp)
    local RD = NS.RD
    local px = 14
    if RD and RD.IconPx then
        local okP, v = pcall(RD.IconPx, sp.heal.GetWidth and sp.heal:GetWidth() or 60)
        if okP and type(v) == "number" then px = math.max(10, math.min(18, v - 4)) end
    end
    -- THE ICON ROW
    local okR, row = pcall(CreateFrame, "AuraContainer", nil, sp.deckTag or sp.heal, "CustomAuraContainerTemplate")
    if okR and row then
        -- A ROW WIDE ENOUGH TO HOLD ITS ICONS (Arn, 24 Nov: Ancestral Fortitude up on him, no icon after his name): it was
        -- 1 x 1, and the client lays a flow row out INSIDE the container - an icon wider than the row may get no place at
        -- all. Now as wide as every icon it can hold, an icon tall, and over the box's own layers (Burn.lua's proven road).
        row:SetSize(#kinds * (px + DC.GAP), px)
        local lvl = (sp.deckTag or sp.heal).GetFrameLevel and (sp.deckTag or sp.heal):GetFrameLevel()
        if type(lvl) == "number" and row.SetFrameLevel then row:SetFrameLevel(lvl + 5) end
        d.row = row
        d.where = DC.PlaceRow(sp, row)
        row:SetUnit(sp.unit)
        -- ONE SLOT PER KIND, NEVER TWO ON TOP (24 Nov 2026, Arn's /bish dc after a cast: "flow refused: nil ... buttons handed
        -- 55" and still no Ancestral Fortitude): the flow group answered nothing but WAS made (it handed its buttons over), and
        -- a fixed slot went on top of it under the same key - Revelation's lesson of 22 Nov (Reveal.lua). Now the fixed road
        -- only (DC.MakeSlot: a fresh key, a slot that handed a button over counts as made, no second one on top).
        d.rowSlots, d.roads = {}, {}
        for i, key in ipairs(kinds) do
            local filter = (key == "armor") and "HELPFUL" or "HARMFUL"
            local slot, road = DC.MakeSlot(row, "BiSDC" .. key, filter, {
                candidateFilters = { includeSpellIDs = DC.Ids(key) },
                initializeFrame = FA.Placed(DC.Dress, px, "LEFT", row, (i - 1) * (px + DC.GAP), 0),
            }, d, key)
            d.roads[#d.roads + 1] = key .. " " .. road
            d.rowSlots[key] = slot
            if not slot then DC.refused = true end
        end
        d.how = "fixed"
        if row.SetEnabled then pcall(row.SetEnabled, row, true) end
        if row.UpdateAllAuras then pcall(row.UpdateAllAuras, row) end
        d.row = row
    end
    -- THE WORD
    local okW, words = pcall(CreateFrame, "AuraContainer", nil, sp.deckPlate or sp.heal, "CustomAuraContainerTemplate")
    if okW and words then
        words:SetSize(1, 1)
        words:SetPoint("CENTER", sp.heal, "CENTER", 0, 0)
        words:SetUnit(sp.unit)
        d.wordSlots = {}
        local function slotFor(key, text, col, rank, ids)
            local s = DC.MakeSlot(words, "BiSDCw" .. key, "HARMFUL", {
                candidateFilters = { includeSpellIDs = ids },
                initializeFrame = FA.Placed(function(button)
                    quiet(button)
                    if button.GetRegions then
                        for _, r in ipairs({ button:GetRegions() }) do if r.Hide then pcall(r.Hide, r) end end
                    end
                    pcall(function() button.dcWord = DC.Word(button, sp, text, col, rank) end)
                end, 1, "CENTER", sp.heal, 0, 0),
            }, nil, key)
            d.wordSlots[key] = s
        end
        local want = {}
        for _, k in ipairs(kinds) do want[k] = true end
        for _, w in ipairs(DC.WORDS) do
            if w.key == "reduce" then
                if want.reduce then
                    for i, cut in ipairs(DC.Cuts()) do
                        local ids = DC.Ids("reduce", cut)
                        if next(ids) then
                            slotFor("reduce" .. math.floor(cut * 100), w.word:format(math.floor(cut * 100 + 0.5)), w.col,
                                w.rank + (#DC.Cuts() - i) * 0.1, ids)
                        end
                    end
                end
            elseif w.key ~= "mc" and want[w.key] then
                slotFor(w.key, w.word, w.col, w.rank, DC.Ids(w.key))
            end
        end
        if words.SetEnabled then pcall(words.SetEnabled, words, true) end
        if words.UpdateAllAuras then pcall(words.UpdateAllAuras, words) end
        d.words = words
    end
    return true
end

--- MIND CONTROL: a friend you could attack. The client's own answer drives the word's alpha.
function DC.PaintMC(sp)
    local mcOn = on("mc") and sp.heal and sp.unit and not DC.NOT_MC[sp.unit] and not tostring(sp.unit):find("pet", 1, true)
    local m = sp.dcMC
    if not mcOn then if m then m:SetAlpha(0) end return end
    if not m then
        local mc = DC.WORDS[1]
        m = DC.Word(sp.deckPlate or sp.heal, sp, mc.word, mc.col, mc.rank)
        sp.dcMC = m
    end
    local ok, can = pcall(UnitCanAttack, "player", sp.unit)
    if not ok then m:SetAlpha(0) return end
    if secret(can) then
        if not (m.SetAlphaFromBoolean and pcall(m.SetAlphaFromBoolean, m, can, 1, 0)) then m:SetAlpha(0) end
    else
        m:SetAlpha(can == true and 1 or 0)
    end
end

--- `/bish dc`: what each box built for the cues - for a screenshot when an icon does not show.
function DC.Status()
    local lines = { ("debuff cues: on = %s; refused = %s; icon %s"):format(table.concat(DC.Kinds(), ","), tostring(DC.refused or false),
        DC.iconRefused and "REFUSED" or "taken") }
    for _, sp in ipairs((NS.RD and NS.RD.spokes) or {}) do
        local d = sp.dc
        if sp.unit and d then
            local r = d.row
            local okS, shown = pcall(function() return r and r:IsShown() end)
            local okV, vis = pcall(function() return r and r:IsVisible() end)
            local okW, w = pcall(function() return r and r:GetWidth() end)
            if okW and secret(w) then w = "secret" end
            local okL, lv = pcall(function() return r and r:GetFrameLevel() end)
            local n = 0
            for _ in pairs(d.rowSlots or {}) do n = n + 1 end
            local by = {}
            for _, k in ipairs(d.kinds or {}) do by[#by + 1] = k .. " " .. ((d.handedBy or {})[k] or 0) end
            lines[#lines + 1] = ("  %s: %d slot(s) (%s), row shown %s seen %s w %s lvl %s, handed %s, at %s"):format(
                tostring(sp.unit), n, table.concat(d.roads or {}, "; "), tostring(okS and shown), tostring(okV and vis),
                tostring(okW and (type(w) == "number" and math.floor(w) or w)), tostring(okL and lv), table.concat(by, " "),
                tostring(d.where))
        end
    end
    if #lines == 1 then lines[2] = "  no box has built any yet (tick a cue, then let the deck repaint)" end
    return lines
end

--- `/bish dc any`: THE PROBE (24 Nov 2026) - on your own box, two big buttons the client draws: LEFT = any buff on you (no
--- filter at all), RIGHT = Ancestral Fortitude by its id. Left shows, right does not = the id filter is the trouble; neither
--- shows = a container on the box does not draw. Again = off. Out of a fight only.
function DC.AnyProbe()
    local FA = NS.FA
    if InCombatLockdown and InCombatLockdown() then return { "dc probe: out of a fight only" } end
    if DC.probe then
        if DC.probe.SetEnabled then pcall(DC.probe.SetEnabled, DC.probe, false) end
        pcall(DC.probe.Hide, DC.probe)
        DC.probe = nil
        return { "dc probe: off" }
    end
    local sp
    for _, s in ipairs((NS.RD and NS.RD.spokes) or {}) do if s.unit == "player" and s.heal then sp = s break end end
    if not sp then return { "dc probe: your own box is not on the deck" } end
    if not (FA and FA.Available and FA.Available()) then return { "dc probe: no aura containers on this client" } end
    local okC, c = pcall(CreateFrame, "AuraContainer", nil, sp.deckTag or sp.heal, "CustomAuraContainerTemplate")
    if not (okC and c) then return { "dc probe: container refused: " .. tostring(c) } end
    c:SetSize(52, 24)
    c:SetPoint("LEFT", sp.heal, "LEFT", 2, 0)
    local lvl = (sp.deckTag or sp.heal):GetFrameLevel()
    if type(lvl) == "number" and c.SetFrameLevel then c:SetFrameLevel(lvl + 8) end
    c:SetUnit("player")
    local d = {}
    local _, any = DC.MakeSlot(c, "BiSDCprobeAny", "HELPFUL", {
        initializeFrame = FA.Placed(DC.Dress, 24, "LEFT", c, 0, 0) }, d, "any buff")
    local _, af = DC.MakeSlot(c, "BiSDCprobeAF", "HELPFUL", {
        candidateFilters = { includeSpellIDs = { [16177] = true } },
        initializeFrame = FA.Placed(DC.Dress, 24, "LEFT", c, 28, 0) }, d, "fortitude")
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
    if c.UpdateAllAuras then pcall(c.UpdateAllAuras, c) end
    DC.probe = c
    local h = d.handedBy or {}
    return { ("dc probe: on your box's left - left = any buff (%s, %d handed), right = Fortitude by id (%s, %d handed)")
        :format(tostring(any), h["any buff"] or 0, tostring(af), h["fortitude"] or 0) }
end

--- With every repaint of a deck box.
function DC.Paint(sp, shown)
    if not sp then return end
    if not (shown and sp.unit) then
        local d = sp.dc
        if d then for _, c in ipairs({ d.row, d.words }) do if c and c.SetEnabled then pcall(c.SetEnabled, c, false) end end end
        if sp.dcMC then sp.dcMC:SetAlpha(0) end
        return
    end
    DC.Arm(sp)
    DC.PaintMC(sp)
end

--- The boxes build again at their next repaint (a cue switched, a line learned) - out of a fight.
function DC.Reset()
    if InCombatLockdown and InCombatLockdown() then return false end
    for _, sp in ipairs((NS.RD and NS.RD.spokes) or {}) do
        local d = sp.dc
        if d then
            for _, c in ipairs({ d.row, d.words }) do if c and c.SetEnabled then pcall(c.SetEnabled, c, false) end end
            sp.dc = nil
        end
    end
    return true
end

-- ride on the deck's repaints, and keep the name's copy in step with the name
do
    local EN = NS.EN
    if EN and not EN.__dcWrapped then
        EN.__dcWrapped = true
        local paint = EN.Paint
        if paint then EN.Paint = function(sp, ...) local r = paint(sp, ...) DC.Paint(sp, r) return r end end
    end
    local RD = NS.RD
    if RD and RD.DeckTag and not RD.__dcTag then
        RD.__dcTag = true
        local tag = RD.DeckTag
        RD.DeckTag = function(sp, ...)
            local t = tag(sp, ...)
            if sp and sp.deckTag and sp.deckTag.dcGhost then DC.Ghost(sp) end
            if sp and sp.dc and sp.dc.row then sp.dc.where = DC.PlaceRow(sp, sp.dc.row) end   -- the name changed: re-measure
            return t
        end
    end
end
