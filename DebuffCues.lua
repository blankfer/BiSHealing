--[[
  BiSHealing / Forever :: DebuffCues.lua - WHAT TO DO ABOUT A DEBUFF, ON THE DECK BOX (24 Nov 2026).

  Arn, 24 Nov: "our cues are gonna tell you heal past this, don't heal this target right now, dispel this poison, do not
  dispel this poison". Placement (his pick of three, https://claude.ai/artifact/VokdMsi1w5ohZ3ooB8PFAE): "C across the
  bar, but put the icons next to the name ... I see the tanks name and I can see the armor buff icon and if they have
  mortal strike" - and the bar never says two words: "will it say [Chain Heal] and [Cure]" - no, ONE, the most urgent.

  TWO CONTAINERS PER BOX, both drawn by the client only while a matching aura is on them (nothing here reads one):
    THE ICON ROW  right after the name (anchored to an invisible copy of the name with no width, so it starts where the
                  name ENDS even when the name is a secret): one aura GROUP per kind in a flow row the client packs left
                  to right (SetFlowLayout*, AddAuraGroup with `layout` - read off ForeverAuras, GPL, learn only), the
                  debuffs' own icons. A client without groups: one slot per kind at a fixed step (gaps when absent).
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

-- ----------------------------------------------------------------- building

local function quiet(button)
    if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
    if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, false) end
    if button.EnableMouse then pcall(button.EnableMouse, button, false) end
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
        row:SetSize(1, 1)
        if ghost then row:SetPoint("LEFT", ghost, "RIGHT", 3, 0) else row:SetPoint("TOPLEFT", sp.heal, "TOPLEFT", 4, -3) end
        row:SetUnit(sp.unit)
        local flow = row.SetFlowLayoutAxis and AnchorUtil and AnchorUtil.FlowLayoutAxis and row.AddAuraGroup
        if flow then
            pcall(row.SetFlowLayoutAxis, row, AnchorUtil.FlowLayoutAxis.Horizontal)
            pcall(row.SetFlowLayoutAnchorPoint, row, "LEFT")
            if row.SetFlowLayoutGrowthDirection and AnchorUtil.FlowDirection then
                pcall(row.SetFlowLayoutGrowthDirection, row, AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
            end
        end
        d.rowSlots = {}
        for i, key in ipairs(kinds) do
            local filter = (key == "armor") and "HELPFUL" or "HARMFUL"
            local init = function(button) quiet(button) end
            local slot
            if flow then
                local okG, g = pcall(row.AddAuraGroup, row, "BiSDC" .. key, filter, {
                    maxFrameCount = 3, candidateFilters = { includeSpellIDs = DC.Ids(key) },
                    layout = { elementWidth = px, elementHeight = px, elementSpacing = DC.GAP, lineSpacing = DC.GAP, layoutIndex = i },
                    initializeFrame = init,
                })
                slot = okG and g or nil
            end
            if not slot then
                slot = FA.AddSlot(row, "BiSDC" .. key, filter, {
                    candidateFilters = { includeSpellIDs = DC.Ids(key) },
                    initializeFrame = FA.Placed(init, px, "LEFT", row, (i - 1) * (px + DC.GAP), 0),
                })
            end
            d.rowSlots[key] = slot
            if not slot then DC.refused = true end
        end
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
            local s = FA.AddSlot(words, "BiSDCw" .. key, "HARMFUL", {
                candidateFilters = { includeSpellIDs = ids },
                initializeFrame = FA.Placed(function(button)
                    quiet(button)
                    if button.GetRegions then
                        for _, r in ipairs({ button:GetRegions() }) do if r.Hide then pcall(r.Hide, r) end end
                    end
                    pcall(function() button.dcWord = DC.Word(button, sp, text, col, rank) end)
                end, 1, "CENTER", sp.heal, 0, 0),
            })
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
            return t
        end
    end
end
