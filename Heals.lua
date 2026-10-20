--[[
  BiSHealing :: Heals.lua - MANA FOR MANA, WHICH HEAL? (the probe, step 0)

  Arn, 19 Oct 2026: "i want a window in the option that breaks down the mana efficiency of my healing
  spells taken everything into account break it down phd level. i want you to see all my talents my
  +healing. mana for mana what is the best healing spell i can spam to heal the most at the least
  amount of mana using all ranks and everything".

  The breakdown is only as good as the numbers under it, and Forever is a modern client wearing a 1.x
  game: whether a rank's mana cost already has the talents taken off, whether its tooltip numbers
  include +healing, whether any of it is secret - none of that is known. So first the PROBE:
  `/bish heals` reads, for every rank of every heal this character has, what the client will say -
  cost, cast time, the tooltip's own words - plus +healing, crit, mana, regen and every talent point,
  and puts it in a box to copy out (Forever will not let an addon write the clipboard: select, Ctrl+C).
  The window with the answer is built on what this readout shows.

  Read only. Out of combat or in, it changes nothing; it asks the client a few hundred questions once,
  when typed, and never on a timer.
]]
local ADDON, NS = ...
NS = NS or {}

local FE = {}
NS.FE = FE

-- the heals by class, by NAME (the book decides which ranks this character has - FM.Ranks / BookIds)
FE.HEALS = {
    SHAMAN  = { "Healing Wave", "Lesser Healing Wave", "Chain Heal" },
    PRIEST  = { "Lesser Heal", "Heal", "Greater Heal", "Flash Heal", "Renew", "Prayer of Healing", "Holy Nova" },
    DRUID   = { "Healing Touch", "Regrowth", "Rejuvenation", "Tranquility" },
    PALADIN = { "Holy Light", "Flash of Light", "Holy Shock" },
}
-- the spell schools GetSpellCritChance numbers: 2 holy, 4 nature
FE.SCHOOL = { SHAMAN = 4, DRUID = 4, PRIEST = 2, PALADIN = 2 }

local function plain(v)
    if NS.Plain then return NS.Plain(v) end
    return v
end
local function show(v)
    local p = plain(v)
    if p == nil and v ~= nil then return "secret" end
    if p == nil then return "-" end
    return tostring(p)
end
local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

--- One rank: id, cost, cast time, level learned, and the tooltip's own words.
function FE.Rank(id)
    local r = { id = id }
    local S = C_Spell
    local costs = S and ask(S.GetSpellPowerCost, id)
    if type(costs) == "table" then
        for _, c in ipairs(costs) do
            local t = plain(c.type)
            if t == 0 or plain(c.name) == "MANA" or #costs == 1 then r.cost = c.cost break end
        end
    end
    local info = S and ask(S.GetSpellInfo, id)
    if type(info) == "table" then r.cast, r.name = info.castTime, info.name end
    r.learned = S and ask(S.GetSpellLevelLearned, id)
    r.sub = S and ask(S.GetSpellSubtext, id)
    r.desc = S and ask(S.GetSpellDescription, id)
    return r
end

--- One talent: its name, points spent, and its most.
function FE.Talent(tab, i)
    if type(GetTalentInfo) ~= "function" then return nil end
    local ok, name, _, _, _, rank, max = pcall(GetTalentInfo, tab, i)
    if not ok then return nil end
    return name, rank, max
end

--- The readout, as lines of text.
function FE.Probe()
    local out = {}
    local function line(fmt, ...) out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end
    local _, class = ask(UnitClass, "player")
    class = plain(class)
    local level = ask(UnitLevel, "player")
    line("BiS Healing heals probe - %s level %s, %s", show(class), show(level),
         date and date("%Y-%m-%d %H:%M") or "")
    line("+healing %s   crit %s%%   mana %s   regen (not casting / casting) %s / %s per s",
         show(ask(GetSpellBonusHealing)), show(ask(GetSpellCritChance, FE.SCHOOL[class or ""] or 2)),
         show(ask(UnitPowerMax, "player", 0)), show((ask(GetManaRegen))), show(select(2, ask(GetManaRegen))))
    local stats = {}
    for i, nm in ipairs({ "Str", "Agi", "Sta", "Int", "Spi" }) do
        stats[#stats + 1] = nm .. " " .. show(select(2, ask(UnitStat, "player", i)))
    end
    line("%s", table.concat(stats, "   "))
    local FM = NS.FM
    for _, name in ipairs(FE.HEALS[class or ""] or {}) do
        local ids = FM and FM.BookIds and FM.BookIds(name) or {}
        local ranks = FM and FM.Ranks and FM.Ranks(name) or {}
        line("")
        line("== %s: %d rank%s", name, #ids, #ids == 1 and "" or "s")
        for i, id in ipairs(ids) do
            local r = FE.Rank(id)
            line("%s [%s] id %s  cost %s  cast %s ms  learned %s", tostring(ranks[i] and ranks[i].rank or r.sub or "?"),
                 show(r.sub), tostring(id), show(r.cost), show(r.cast), show(r.learned))
            line("   %s", show(r.desc))
        end
    end
    line("")
    line("== talents (points spent)")
    local tabs = ask(GetNumTalentTabs) or 0
    for t = 1, plain(tabs) or 0 do
        local tabName = ask(GetTalentTabInfo, t)
        local n = ask(GetNumTalents, t) or 0
        local spent = {}
        for i = 1, plain(n) or 0 do
            -- GetTalentInfo answers name, icon, tier, column, rank, max (and more)
            local tn, rank, max = FE.Talent(t, i)
            if plain(rank) and plain(rank) > 0 then
                spent[#spent + 1] = ("%s %s/%s"):format(show(tn), show(rank), show(max))
            end
        end
        line("%s: %s", show(type(tabName) == "table" and tabName.name or tabName),
             #spent > 0 and table.concat(spent, ", ") or "-")
    end
    return out
end

--------------------------------------------------------------------
-- the copy box
--------------------------------------------------------------------
-- 1.43:1, the family's window shape (standing order, 14 Oct)
FE.W, FE.H = 572, 400

function FE.Box()
    if FE.box then return FE.box end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(FE.W, FE.H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 10, -8)
    f.title:SetText("BiS> heals probe - Ctrl+A, Ctrl+C, paste it to Claude")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -30)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(FE.W - 50)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(edit)
    f.edit = edit
    FE.box = f
    return f
end

--- `/bish heals`: the readout, selected, ready to copy.
function FE.Show()
    local f = FE.Box()
    local text = table.concat(FE.Probe(), "\n")
    f.edit:SetText(text)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
    return text
end
