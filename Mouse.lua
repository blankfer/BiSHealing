--[[
  BiSHealing / Forever :: Forever/Mouse.lua - bind spells to the mouse you actually hold.

  Healium gives you a row of buttons beside each name and you drag spells onto them. This does the
  same job the other way round: a picture of a MOUSE, and you drop a spell on the button you intend
  to press. Left click, right click, middle, the two thumb buttons, wheel up and wheel down - times
  no modifier, shift, ctrl and alt. Twenty-eight slots, each one a place your hand already knows.

  TWO MECHANISMS, because the client has two.

    buttons 1-5   a secure attribute on every grid cell: `*type1`/`*spell1`, `shift-type1`, ...
                  The click lands on the cell under the cursor, and Blizzard's own secure code
                  does the casting. An addon may not cast; it may only say what a click means.

    the wheel     NOT a click a button can take. It is a BINDING, so it goes through a hidden
                  secure action button holding `/cast [@mouseover] <spell>` and
                  SetOverrideBindingClick("MOUSEWHEELUP", ...). Hover a cell, turn the wheel, and
                  the macro's [@mouseover] picks the unit. The TBC pyramid has done it this way
                  since September; the API is on Forever too (measured).

  EVERY BIND IS SET OUT OF COMBAT. Secure attributes and override bindings are both refused once
  the lockdown is on, so changes made mid-fight are queued and applied when it lifts - the same
  rule the grid's layout already follows.
]]
local ADDON, NS = ...
NS = NS or {}

local FM = {}
NS.FM = FM

-- Where each slot sits on the drawing, and what the client calls it.
--   attr   the secure attribute suffix for a click (nil = the wheel, which is a binding)
--   bind   the binding name for the wheel
-- Laid out like the thing in your hand: the two big buttons across the top, the wheel between
-- them, the middle click UNDER the wheel (because that is what pressing it is), and the two thumb
-- buttons down the left flank.
FM.SLOTS = {
    { key = "left",      label = "Left click",  attr = 1, x = -34, y =  52 },
    { key = "right",     label = "Right click", attr = 2, x =  34, y =  52 },
    { key = "wheelup",   label = "Wheel up",    bind = "MOUSEWHEELUP",   x = 0, y =  66 },
    { key = "wheeldown", label = "Wheel down",  bind = "MOUSEWHEELDOWN", x = 0, y =  40 },
    { key = "middle",    label = "Wheel click", attr = 3, x =   0, y =  10 },
    { key = "button4",   label = "Thumb 1",     attr = 4, x = -46, y = -22 },
    { key = "button5",   label = "Thumb 2",     attr = 5, x = -46, y = -46 },
}

FM.MODS = { { key = "", label = "no modifier" }, { key = "shift-", label = "shift" },
            { key = "ctrl-", label = "ctrl" }, { key = "alt-", label = "alt" } }

--- The binds live in SavedVariables when there are any. Before the DB exists - this file loads
--- before BiSHealing.lua, and a harness has no SavedVariables at all - they live in one table
--- here. Without that fallback every call made a FRESH table, so a bind was written to one and
--- read from another: set it, apply it, get nothing, with no error anywhere. The suite caught it.
-- What a fresh install already knows. The mouse owns EVERY click meaning: the grid used to set
-- these itself, and then applying an empty bind list wiped them - a grid with no click-casting at
-- all, silently. One owner, seeded once.
--
-- ONE LIST PER CLASS, and it is the only class-shaped thing in the addon. Everything else asks
-- the client what this character can do; a fresh install cannot, because "what would you like on
-- the left button" has no answer until you have dragged one. So each healer gets the two or three
-- spells they would have dragged first, and anyone else gets nothing rather than a guess.
--
-- These are courtesies, not opinions. Drag over them and they are gone.
FM.CLASS_DEFAULTS = {
    SHAMAN  = { left = "Healing Wave",    right = "Lesser Healing Wave", ["shift-left"] = "Chain Heal" },
    PRIEST  = { left = "Greater Heal",    right = "Flash Heal",          ["shift-left"] = "Renew" },
    -- a list = the first one trained (15 Nov 2026: a paladin under 42 has Purify, not Cleanse - the research for the flight deck)
    PALADIN = { left = "Holy Light",      right = "Flash of Light",      ["shift-left"] = { "Cleanse", "Purify" } },
    DRUID   = { left = "Healing Touch",   right = "Regrowth",            ["shift-left"] = "Rejuvenation" },
}

--- What this character starts with - AND ONLY WHAT THEY HAVE ACTUALLY TRAINED.
---
--- Arn, 19 Sep, at level something on a fresh shaman: "it setts it back to chain heals which i
--- dont have yet". A default is a courtesy; a default for a spell you cannot cast is a button
--- that does nothing and a line of red text when you press it. The spellbook is asked, and
--- anything not in it is left out.
---
--- `booked` comes back false when the book answered nothing at all - a real possibility at login,
--- before the client has filled it in - and the caller uses that to try again later rather than
--- writing an empty mouse down as "seeded".
function FM.Defaults()
    local class
    if UnitClass then
        local ok, _, token = pcall(UnitClass, "player")
        if ok then class = token end
    end
    local list = FM.CLASS_DEFAULTS[class or ""] or {}
    local out, booked = {}, false
    for slot, want in pairs(list) do
        local spell, ranks = want, {}
        for _, name in ipairs(type(want) == "table" and want or { want }) do
            spell, ranks = name, FM.Ranks(name)
            if #ranks > 0 then break end
        end
        if #ranks > 0 then
            -- WITH THE RANK ON IT, the highest trained. A bare name casts your biggest rank
            -- anyway, so this changes nothing about what the button does - but it puts a number
            -- in the corner of the slot, and that number is the button you click to walk down to
            -- a cheaper rank. Seeded bare, the slot has nothing to click and the one feature this
            -- addon is FOR is invisible until you drag something yourself. (19 Sep 2026: Arn's
            -- first working login showed "Healing Wave" with no rank. Healium shipped the same
            -- decision the same day - "menu selections now track the highest learned rank;
            -- drag-and-drop can assign a specific lower rank" - which is a good sign it is right.)
            out[slot] = FM.Cast(spell, ranks[#ranks].rank)
            booked = true
        end
    end
    return out, booked
end

-- kept as a name because the suite and the options window both ask what a fresh install believes
FM.DEFAULTS = setmetatable({}, { __index = function(_, k) return FM.Defaults()[k] end })

local memory = { binds = {} }
local function db()
    local d = (NS.DB and NS.DB()) or _G.BiSHealingDB
    if type(d) ~= "table" then
        if not memory.seeded then
            for k, v in pairs(FM.Defaults()) do memory.binds[k] = v end
            memory.seeded = true
        end
        return memory
    end
    -- The binds live at the top of the table now. They used to sit under `d.forever`, from the
    -- days when this was the Forever half of another addon; Core.lua's migration carries them.
    d.binds = type(d.binds) == "table" and d.binds or {}
    if next(memory.binds) and not next(d.binds) then
        d.binds = memory.binds                -- carry anything bound before the DB arrived
    end
    -- SEEDED ONCE, AND ONLY INTO AN EMPTY MOUSE.
    --
    -- It used to fill any slot that happened to be nil, which meant clearing a bind and reloading
    -- brought it back - the addon quietly overruling a deliberate act. "the binds are not surving
    -- a reload it setts it back to chain heals": the saved variables were fine all along (the
    -- file on disk had his ranks in it), this was the seeding writing over the gaps.
    --
    -- So: only when there is nothing bound at all, and only spells the spellbook confirms. If the
    -- book answered nothing - which can happen at login, before the client has filled it in - the
    -- flag is NOT set, and the next call tries again rather than writing an empty mouse down as
    -- done forever.
    -- THE MACRO FIRST, then the defaults. On a client that hands back no saved variables the
    -- class default is not a courtesy, it is a bully: it lands on left click at every single
    -- login, and a player who wants the spell on their wheel has to drag it back every time.
    -- Arn, twice in ten minutes - "it did it to left click i put it back on mousewheel", then
    -- "reloaded and it put it back on left click". Asking Keep first means a remembered bind
    -- makes the mouse non-empty, and seeding never runs at all.
    if not FM.asked and not next(d.binds) then
        if NS.FK and NS.FK.Ready and NS.FK.Ready() then
            local kept, settings = nil, nil
            if NS.FK.Load then kept, settings = NS.FK.Load() end
            -- ASKED ONLY ONCE THE LIST IS IN. Before it arrives "no macro" is not an answer, and
            -- taking it for one seeded the class defaults - which the next save then wrote over
            -- the real macro (Arn's, 22 Sep: a grid position and no binds). So until Keep says
            -- the list is in, this asks again, and seeds nothing.
            FM.asked = NS.FK.read and true or false
            if type(kept) == "table" then for k, v in pairs(kept) do d.binds[k] = v end end
            -- AND THE SIZE, which rides in the same macro because it would not survive a restart
            -- anywhere else on this client. Applied WITHOUT saving: writing back to the macro in
            -- the middle of reading it would store a half-restored mouse.
            if type(settings) == "table" and settings.scale then
                d.scale = settings.scale
                if NS.FG and NS.FG.SetScale then NS.FG.SetScale(settings.scale, true) end
            end
            -- the number and the colour ride the same way; the next paint picks them up
            if type(settings) == "table" then
                if settings.text then d.text = settings.text end
                if settings.color then d.color = settings.color end
                -- and where the grid was, and whether it was hidden: Arn, 21 Sep, "when i log on
                -- it puts the frames back in the center". Pinned by the centre, as it was saved.
                if type(settings.pos) == "table" then
                    d.gridPos = { point = "CENTER", rel = "CENTER", x = settings.pos.x, y = settings.pos.y }
                    if NS.FG and NS.FG.RestorePos and not (InCombatLockdown and InCombatLockdown()) then
                        NS.FG.RestorePos()
                    end
                end
                -- heals over time switched off: forget the containers' fingerprint and lay out again
                -- (after the one in progress), so every cell is rebuilt without them
                if settings.hots == false then
                    d.hots = false
                    if NS.FA then NS.FA.sig = nil end
                    if NS.FG and NS.FG.Layout then NS.FG.Layout() end
                end
                -- the gold ring's cell and the out-of-range dim (7 Oct); the next paint shows both
                if settings.ring then d.ring = settings.ring end
                if settings.dim then d.dim = settings.dim end
                if settings.hover ~= nil then d.hover = settings.hover end
                if settings.trinketTabs ~= nil then d.trinketTabs = settings.trinketTabs or nil end
                -- the three a player asked for on 23 Sep, all of them the layout's business
                if settings.layout then d.layout = settings.layout end
                if settings.target == true then
                    d.target = true
                    if settings.targetAt then d.targetAt = settings.targetAt end
                    if settings.targetPos then d.targetPos = settings.targetPos end
                    d.tot = settings.tot == true      -- the cell beside it, from the same row
                end
                -- and your own cell, which is a row of its own: it has nothing to do with the
                -- target block and a player may want one without the other
                -- BiS> NOW, which never came back at all until 5 Oct 2026. The block, the side it
                -- sits on, where it was dragged, and the order its buttons are in - including which
                -- had been EARNED, because a button's id only appears in that list once something
                -- happened to earn it. Without this the whole feature started again every login.
                if settings.now == true then
                    d.now = true
                    if settings.nowAt then d.nowAt = settings.nowAt end
                    if settings.nowPos then d.nowPos = settings.nowPos end
                    if settings.nowOrder and NS.FN and NS.FN.Decode then
                        NS.FN.Decode(settings.nowOrder)
                    end
                end
                -- the buff buttons (4 Nov 2026): on, and which buffs; "I=1" with nothing after = the defaults
                if settings.buffs == true then
                    d.buffs = true
                    if settings.buffFams and settings.buffFams ~= "" and NS.FU then
                        d.buffFam = NS.FU.DecodeFams(settings.buffFams)
                    end
                end
                -- the pets, which never used to come back at all
                if settings.pets then
                    d.pets = settings.pets
                    if settings.petAt then d.petAt = settings.petAt end
                    if settings.petPos then d.petPos = settings.petPos end
                end
                if settings.mana == true then
                    d.mana = true
                    if settings.manaAt then d.manaAt = settings.manaAt end
                    if settings.manaPos then d.manaPos = settings.manaPos end
                end
                -- (a "me" row, Y/Z, from before 8 Nov is read and ignored: the "me" cell is retired)
                if settings.markers then
                    d.markers = settings.markers
                    if NS.FA then NS.FA.sig = nil end
                end
                if settings.layout or settings.target or settings.markers then
                    if NS.FG and NS.FG.Layout then NS.FG.Layout() end
                end
                -- clicks handed to Clique: the relayout clears ours and registers every cell
                if settings.clique == true then
                    d.clique = true
                    if NS.FG and NS.FG.Layout then NS.FG.Layout() end
                end
                -- THE BUFF-DROP SOUND, both halves. `quiet` is only set when the macro carries an
                -- N row at all, so a player who never touched it is left alone - and the sounds
                -- are registered again right here rather than waited for, because one that only
                -- arms itself at the next SPELLS_CHANGED is one that misses the first pull.
                if settings.quiet ~= nil then
                    d.buffQuiet = settings.quiet and true or false
                    d.buffSound = settings.sound
                    if NS.FS and NS.FS.Sounds then NS.FS.Sounds() end
                end
                -- the buff watched on the GROUP, by name. Only set when the macro carries a U row,
                -- so a player who never chose one keeps the default of watching nothing.
                if type(settings.groupBuff) == "string" and settings.groupBuff ~= "" then
                    d.groupBuff = settings.groupBuff
                end
                if settings.hidden then
                    d.shown = false
                    if NS.FG and NS.FG.Layout then NS.FG.Layout() end   -- refuses in combat; the
                end                                                      -- grid's own retry obeys
            end
            -- CARRIED OVER FROM THE SHARED MACRO, once: the binds came from the old General one,
            -- so they are written into this character's own now, and the old one is left alone
            -- for the player to delete - it is theirs, and it may hold another character's mouse.
            if NS.FK.adopted then
                NS.FK.adopted = nil
                local wrote = NS.FK.Save and NS.FK.Save(d.binds)
                if NS.Print then
                    NS.Print(wrote and "your binds now live in this character's own BiSHealing macro."
                        .. " The old one in General Macros is no longer used - delete it whenever you like."
                        or "your binds were read from the shared BiSHealing macro in General Macros;"
                        .. " they move to this character's own at the next change out of combat.")
                end
            end
        end
    end
    -- a save that came before the list was in, now it is
    if NS.FK and NS.FK.pending and NS.FK.read and FM.asked then NS.FK.Save(d.binds) end
    -- SEEDED ONLY AFTER THE MACRO WAS ASKED: defaults written in before then were the empty mouse
    -- that got saved over a real one
    if FM.asked and not d.bindsSeeded and not next(d.binds) then
        local defaults, booked = FM.Defaults()
        for k, v in pairs(defaults) do d.binds[k] = v end
        if booked then d.bindsSeeded = true end
    end
    return d
end

--- The rank of a spell id, as the client words it: "Rank 4". Asked for separately from the name
--- because THE NAME PATH NEVER CARRIES IT. Arn, 19 Sep, after the rank went in: "the rank is
--- still not showing in the mouse keybind thing". GetCursorInfo hands back (spellBookIndex,
--- "spell", spellID); the code asked the LAST number first, which is the id, and the id answers
--- a name and nothing else. C_Spell.GetSpellSubtext is the one call on this client that answers
--- the rank for an id, and it was never asked.
function FM.RankOf(id)
    if type(id) ~= "number" then return nil end
    if C_Spell and C_Spell.GetSpellSubtext then
        local ok, sub = pcall(C_Spell.GetSpellSubtext, id)
        if ok and type(sub) == "string" and sub ~= "" then return sub end
    end
    if GetSpellSubtext then
        local ok, sub = pcall(GetSpellSubtext, id)
        if ok and type(sub) == "string" and sub ~= "" then return sub end
    end
    return nil
end

--- A name and a rank for one number, from whichever call this client answers.
function FM.NameOf(n)
    local name, rank
    if C_SpellBook and C_SpellBook.GetSpellBookItemName then
        local ok, nm, sub = pcall(C_SpellBook.GetSpellBookItemName, n)
        if ok and type(nm) == "string" and nm ~= "" then name, rank = nm, sub end
    end
    if not name and GetSpellInfo then              -- classic: name, rank, icon, ...
        local ok, nm, sub = pcall(GetSpellInfo, n)
        if ok and type(nm) == "string" and nm ~= "" then name, rank = nm, sub end
    end
    if not name and C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, n)
        if ok and info then
            if type(info) == "table" then name, rank = info.name, info.subtext or info.rank
            elseif type(info) == "string" then name = info end
        end
    end
    if name and (type(rank) ~= "string" or rank == "") then rank = FM.RankOf(n) end
    if type(rank) ~= "string" or rank == "" then rank = nil end
    return name, rank
end

--- What the cursor is holding: a cast string, plus the name and rank behind it. Nil for anything
--- that is not a spell.
function FM.CursorSpell()
    if not GetCursorInfo then return nil end
    local kind, a, b, c = GetCursorInfo()
    if kind == "macro" then return FM.CursorMacro(a) end
    if kind ~= "spell" then return nil end

    -- The clients disagree about what comes back, and Forever disagrees with both: it hands
    -- (kind, spellBookIndex, "spell", spellID) and its C_SpellBook.GetSpellBookItemName takes ONE
    -- argument, not two - "bad argument #1 (not a numerical value)" when handed the old pair.
    local numbers = {}
    for _, v in ipairs({ a, b, c }) do
        if type(v) == "number" then numbers[#numbers + 1] = v end
    end

    -- PREFER THE ANSWER WITH A RANK. The old loop returned the first number that gave a name,
    -- which is the spell id, which never gives a rank - so every drop bound a bare name and every
    -- slot looked the same whatever you dropped on it. Now each number is asked, and a name with
    -- a rank wins over a name without one; the plain name is the fallback, not the answer.
    local plain
    for i = #numbers, 1, -1 do
        local name, rank = FM.NameOf(numbers[i])
        if name and name ~= "" then
            FM.lastDrop = { numbers = numbers, name = name, rank = rank, from = numbers[i] }
            if rank then return FM.Cast(name, rank), name, rank end
            plain = plain or name
        end
    end
    if plain then return FM.Cast(plain), plain, nil end
    return nil
end

-- MACROS ON A BIND (Arn, 8 Nov 2026: "can drag macros also on the binds"). A macro off the macro window rides
-- the cursor as ("macro", index); the bind keeps its NAME ("macro:<name>"), because an index moves when the
-- player adds or deletes one, and the name is what the client's secure `macro` attribute takes. The macro picks
-- its own target - write [@mouseover] in it to aim at the cell. A name the save macro cannot carry (its own
-- separators ; # = : or brackets) is refused rather than mangled.
FM.MACRO = "macro:"
function FM.CursorMacro(index)
    if not GetMacroInfo then return nil end
    local ok, name = pcall(GetMacroInfo, index)
    if not ok or type(name) ~= "string" or name == "" or (NS.Secret and NS.Secret(name)) then return nil end
    if name:find("[;#=:%(%)]") then return nil end
    return FM.MACRO .. name, name, nil
end

--- The macro's name when this bind is a macro, else nil.
function FM.MacroOf(cast)
    if type(cast) ~= "string" then return nil end
    return cast:match("^macro:(.+)$")
end

-- HOSTILE BINDS (Arn, 8 Nov 2026: "can drag harmful spells and if a cell is a hostile target use the hostile binds
-- on them"). A second mouse, kept beside the first under keys "harm:" .. modifier .. slot - so the save macro, the
-- API copy and every bind call carry it with nothing new to learn: FM.Get(FM.HARM .. "shift-", "left").
FM.HARM = "harm:"

--- What goes into the secure attribute. "Healing Wave(Rank 3)" is what the client understands,
--- and what a macro would say; a bare name means max rank, which is a different spell in practice.
function FM.Cast(name, rank)
    if not name or name == "" then return nil end
    if type(rank) == "string" and rank:match("%d") then return name .. "(" .. rank .. ")" end
    return name
end

--- A PING AS A BIND (1 Oct 2026, Arn's design: "they would have the buttons on the mouse bind
--- window and its just drag and drop to the buttons").
---
--- `C_Ping.SendMacroPing` is forbidden to addon code - measured with `/bish ping`, which came back
--- with no Lua error at all and an ADDON_ACTION_FORBIDDEN naming us. But a secure button may hold
--- a MACRO, and a macro is Blizzard's code running Blizzard's own `/ping`, which this client has
--- (`SlashCmdList.PING`). So the one road that is open is the one the wheel already drives on:
--- `FM.ApplyWheel` has been putting `/target [@mouseover]` on hidden secure buttons for a fortnight.
---
--- Stored like a spell so every existing road still works - the macro that keeps your binds, the
--- trimmer, Set/Get/Clear - but MARKED, so nothing mistakes one for something castable. A bind is
--- "!ping:assist"; a spell can never collide with that, because no spell name begins with "!".
FM.PING_MARK = "!ping:"
--- `subject` is the name in the client's own `Enum.PingSubjectType`, which is how the art is found:
--- `C_Ping.GetTextureKitForType` turns the type into a kit word ("Assist", "OnMyWay") and the atlas
--- is `Ping_Chat_<kit>`. Measured 1 Oct 2026 by listing every atlas with "ping" in its name
--- (`C_Texture.GetAtlasElements`), after five guessed suffixes all missed.
FM.PINGS = {
    { key = "assist",  word = "Assist",    subject = "Assist"  },
    { key = "attack",  word = "Attack",    subject = "Attack"  },
    { key = "warning", word = "Warning",   subject = "Warning" },
    { key = "onmyway", word = "On My Way", subject = "OnMyWay" },
}

--- The client's own icon for a ping, or nil - and nil is a real answer, not a failure. Not every
--- subject type even has a kit (ActionNotReady has none), and two of them share one, so anything
--- built on this has to cope with a missing icon rather than assume one per type.
---
--- `Ping_Chat_*` is the small one, meant for a line of chat: the right size for a 16-pixel chip
--- and a 30-pixel slot. The big world art is `Ping_GroundMarker_Pin_*`.
function FM.PingAtlas(key)
    local p
    for _, e in ipairs(FM.PINGS) do if e.key == key then p = e break end end
    if not p then return nil end
    local subject = Enum and Enum.PingSubjectType and Enum.PingSubjectType[p.subject]
    local kitOf = C_Ping and C_Ping.GetTextureKitForType
    if subject == nil or type(kitOf) ~= "function" then return nil end
    local got, kit = pcall(kitOf, subject)
    if not got or type(kit) ~= "string" or kit == "" then return nil end
    local atlas = "Ping_Chat_" .. kit
    local exists = C_Texture and C_Texture.GetAtlasExists
    if type(exists) == "function" then
        local okE, yes = pcall(exists, atlas)
        if not okE or not yes then return nil end
    end
    return atlas
end

--- The ping a bind means, or nil when it is an ordinary spell.
function FM.PingOf(cast)
    if type(cast) ~= "string" then return nil end
    local key = cast:match("^" .. FM.PING_MARK .. "(%w+)$")
    if not key then return nil end
    for _, p in ipairs(FM.PINGS) do if p.key == key then return key end end
    return nil
end

--- What to store for a ping, and what to call it on screen.
function FM.PingBind(key) return FM.PING_MARK .. tostring(key) end

function FM.PingWord(key)
    for _, p in ipairs(FM.PINGS) do if p.key == key then return p.word end end
    return tostring(key)
end

--- A SPELL THAT GOES OFF FIRST (8 Oct 2026). Arn: "finally got nature's swiftness ... when i press
--- down a button it pops it before my big heal". Each of these makes the NEXT heal better and is
--- off the global cooldown, so one press can cast it and then the heal - the classic two-line
--- macro. Dropped onto a slot that already holds a heal, it rides IN FRONT of that heal:
--- "Nature's Swiftness+Healing Wave(Rank 10)". Stored as one string, so the macro that keeps the
--- binds, Set/Get/Clear and the trimmer all carry it untouched. On cooldown, the first line fails
--- quietly and the heal still goes out.
FM.BOOSTERS = { ["Nature's Swiftness"] = true, ["Inner Focus"] = true, ["Divine Favor"] = true, ["Riptide"] = true }
FM.BOOST_MARK = "+"

--- A SPELL THAT GOES FIRST WHEN IT IS READY, AIMED (15 Nov 2026). Arn: "if i drop it on top of chain heal bind will it be
--- smart to cast rip tide if its cooldown is up and then go back to casting chain heal". Riptide (Forever: a shaman
--- talent, 408521, 12 s cooldown, a 15 s heal over time, and Chain Heal 25% stronger on that target) rides in front of a
--- heal like Nature's Swiftness, with two differences: it needs a TARGET - so its line is aimed like the heal, at the
--- living friend under the mouse - and it is ON the global cooldown, so a press that casts it casts it alone (the heal's
--- line meets the global cooldown and does nothing). Every press while it cools, its line fails quietly and the heal
--- goes out. One button: Riptide every 12 s on whoever you are healing, Chain Heal in between - and the Chain Heal that
--- follows lands on the Riptide target, which is the one it is stronger on.
FM.AIMED = { ["Riptide"] = true }

--- THE HEALS, READY TO DRAG (8 Oct 2026). Arn: "look at how fojjicore made a little box that tells
--- you these spells are not max rank, and you can drag and drop them on your bar ... show all the
--- healing spells max rank dragable to the binds". FojjiCore's rows call C_Spell.PickupSpell(id)
--- with the rank it wants, which puts that spell on the cursor; a bind slot already reads a spell
--- off the cursor WITH its rank. So the palette is a row of this character's healing spells, each
--- picked up at its highest trained rank. Per class, in the order a healer reaches for them; only
--- what the spellbook has trained is shown. (No "not max rank" warning on the binds: a healer
--- downranks on purpose, and the rank button is how.)
FM.PALETTE = {
    SHAMAN  = { "Healing Wave", "Lesser Healing Wave", "Chain Heal", "Riptide", "Nature's Swiftness",
                "Cure Poison", "Cure Disease", "Ancestral Spirit" },
    PRIEST  = { "Flash Heal", "Greater Heal", "Heal", "Lesser Heal", "Renew", "Prayer of Healing",
                "Power Word: Shield", "Inner Focus", "Dispel Magic", "Abolish Disease", "Resurrection" },
    DRUID   = { "Healing Touch", "Regrowth", "Rejuvenation", "Swiftmend", "Nature's Swiftness",
                "Remove Curse", "Abolish Poison", "Rebirth" },
    PALADIN = { "Holy Light", "Flash of Light", "Holy Shock", "Divine Favor", "Cleanse",
                "Lay on Hands", "Blessing of Protection", "Redemption" },
}
FM.PALETTE_MAX = 11                 -- what fits across the bind window
-- THE HOSTILE SIDE'S PALETTE (Arn, 8 Nov 2026: "put the hostile spells at the bottom of the window like how we put
-- healing spells so they can drag and not have to open spellbook"): each healer's everyday damage and control
-- spells, shown only once trained, at the top rank - the same way as the heals above.
FM.HARM_PALETTE = {
    SHAMAN  = { "Lightning Bolt", "Chain Lightning", "Earth Shock", "Flame Shock", "Frost Shock", "Purge" },
    PRIEST  = { "Smite", "Holy Fire", "Mind Blast", "Shadow Word: Pain", "Mana Burn", "Psychic Scream",
                "Dispel Magic" },
    DRUID   = { "Wrath", "Moonfire", "Starfire", "Insect Swarm", "Entangling Roots", "Hibernate",
                "Faerie Fire" },
    PALADIN = { "Hammer of Justice", "Exorcism", "Hammer of Wrath", "Holy Shock", "Turn Undead" },
}

--- A CLICK ON THE DEAD RESES (Arn, 17 Oct 2026: "when someone is dead and out of combat if we click
--- the cell does it default to res?" - it did not; the heal on the button was cast and the client
--- said "target is dead"). Every heal click carries one more line, first: `/cast [@mouseover,dead,
--- nocombat] <your res>`. The CLIENT decides at the click - dead and out of combat, the res; anything
--- else, the line does nothing and the heal goes out as it always did. Nothing is read, nothing
--- changes in a fight, and `nocombat` keeps a druid's Rebirth from going on a misclick mid-pull.
--- By name, from the book: a character who has not trained it gets no line. `/bish res off` stops it.
-- each class's res, the first one trained wins. DRUIDS GOT REVIVE ON FOREVER (Arn, 20 Oct 2026: "I think druids got
-- a resurrection spell"): an out-of-combat res at level 12 beside Classic's Rebirth (Icy Veins' and
-- ForeverChanges' WoW Forever druid pages) - asked for by name, so it is used once the spellbook has it.
-- NEVER REBIRTH (Arn, 20 Oct: "Let's not do rebirth unless they bind it on their mouse ... that super long
-- cooldown is usually only reserved for in combat battle rez"): the addon never spends it by itself - a druid
-- without Revive gets no res click at all; Rebirth bound on a button by hand is that button's, as ever.
FM.RES = { SHAMAN = { "Ancestral Spirit" }, PRIEST = { "Resurrection" }, PALADIN = { "Redemption" },
           DRUID = { "Revive" } }

function FM.ResSpell()
    local d = NS.DB and NS.DB()
    if type(d) == "table" and d.resClick == false then return nil end
    local class = UnitClass and NS.Plain(select(2, UnitClass("player"))) or nil
    for _, name in ipairs(FM.RES[class or ""] or {}) do
        if #FM.BookIds(name) > 0 then return name end
    end
    return nil
end

--- The line that goes first in a heal click, or "" when there is no res to cast.
function FM.ResLine(cast)
    local res = FM.ResSpell()
    if not res or not cast or FM.Split(cast) == res then return "" end
    return "/cast [@mouseover,dead,nocombat] " .. res .. "\n"
end

--- This character's palette: { name, id (the highest trained rank's), rank } in class order. `list` is
--- FM.PALETTE (the heals, the default) or FM.HARM_PALETTE (the hostile side).
function FM.Palette(list)
    local class = UnitClass and select(2, UnitClass("player"))
    local out = {}
    for _, name in ipairs((list or FM.PALETTE)[class or ""] or {}) do
        local ranks = FM.Ranks(name)
        local top = ranks[#ranks]
        if top and top.spell then
            out[#out + 1] = { name = name, id = top.spell, rank = top.rank }
            if #out >= FM.PALETTE_MAX then break end
        end
    end
    return out
end

--- The bind window's tip about boosters, or nil: said only while one is trained and no bind, on
--- any modifier, has one in front of it yet. Short enough for the header line.
FM.BOOST_SHORT = { ["Nature's Swiftness"] = "NS", ["Inner Focus"] = "Inner Focus",
                   ["Divine Favor"] = "Divine Favor", ["Riptide"] = "Riptide" }
function FM.BoostTip(palette)
    local trained
    for _, s in ipairs(palette or FM.Palette()) do
        if FM.BOOSTERS[s.name] then trained = s.name break end
    end
    if not trained then return nil end
    for _, cast in pairs(db().binds or {}) do
        if FM.Boost(cast) then return nil end
    end
    return "drop " .. (FM.BOOST_SHORT[trained] or trained) .. " on a heal: it goes first"
end

--- Put a spell on the cursor, the way FojjiCore's rows do. Out of combat only, like every bind.
function FM.PickUp(id)
    if not id or (InCombatLockdown and InCombatLockdown()) then return false end
    local pick = (C_Spell and C_Spell.PickupSpell) or PickupSpell
    if not pick then return false end
    return (pcall(pick, id))
end

--- The booster riding in front of a bind, and the bind without it. (nil, cast) when there is none.
--- TRINKETS FIRST (10 Oct 2026). Arn: "another thing that the old bis healing had was popping
--- trinkets before big heals". The old addon put `/use 13` and `/use 14` in front of its shift
--- binds; on-use trinkets are off the global cooldown, so the heal still goes out on the same
--- press, and a trinket with nothing to use - or on cooldown - is simply skipped. Stored by SLOT,
--- never by item: swap a trinket and the bind keeps working. A bind's front is now a CHAIN, in a
--- fixed order: trinket slots, then a booster spell, then the heal -
--- "!use:13+Nature's Swiftness+Healing Wave(Rank 10)".
FM.TRINKET_MARK = "!use:"
FM.TRINKET_SLOTS = { 13, 14 }

local function trinketSlot(part)
    local n = type(part) == "string" and tonumber(part:match("^!use:(%d+)$"))
    return (n == 13 or n == 14) and n or nil
end

--- What goes first, and the heal: { 13, 14 } (trinket slots), "Nature's Swiftness" (or nil), heal.
function FM.Front(cast)
    local slots, boost, rest = {}, nil, cast
    if type(cast) ~= "string" then return slots, nil, cast end
    while true do
        local head, tail = rest:match("^(.-)%+(.+)$")
        if not head then break end
        local s = trinketSlot(head)
        if s then slots[#slots + 1] = s
        elseif FM.BOOSTERS[head] then boost = head
        else break end
        rest = tail
    end
    return slots, boost, rest
end

--- A bind from its parts: trinket slots (sorted, once each), then the booster, then the heal.
function FM.Compose(slots, boost, heal)
    if not heal then return nil end
    local parts, seen = {}, {}
    local sorted = {}
    for _, s in ipairs(slots or {}) do if not seen[s] then seen[s] = true sorted[#sorted + 1] = s end end
    table.sort(sorted)
    for _, s in ipairs(sorted) do parts[#parts + 1] = FM.TRINKET_MARK .. s end
    if boost then parts[#parts + 1] = boost end
    parts[#parts + 1] = heal
    return table.concat(parts, FM.BOOST_MARK)
end

--- The booster spell riding in front of a bind, and the heal with nothing in front of it.
function FM.Boost(cast)
    if type(cast) ~= "string" then return nil, cast end
    local _, boost, heal = FM.Front(cast)
    return boost, heal
end

--- A booster in front of a bind - its trinkets kept - or the bind as it was with no booster.
function FM.WithBoost(boost, cast)
    if not boost or not cast then return cast end
    local slots, _, heal = FM.Front(cast)
    return FM.Compose(slots, boost, heal)
end

--- The trinket slot of an item on the cursor - an EQUIPPED trinket (13 or 14), or nil. The item is
--- matched to the slot wearing it, because it is the slot that gets stored, not the item.
function FM.CursorTrinket()
    if not (GetCursorInfo and GetInventoryItemID) then return nil end
    local kind, id = GetCursorInfo()
    if kind ~= "item" or type(id) ~= "number" then return nil end
    for _, s in ipairs(FM.TRINKET_SLOTS) do
        local ok, worn = pcall(GetInventoryItemID, "player", s)
        if ok and worn == id then return s end
    end
    return nil
end

--- TRINKETS PER MODIFIER TAB (10 Oct 2026). Arn: "each tab no modifier shift alt cntrl has a check
--- make when this modifier is held down pop trinket 1 - 2 can check either or both maybe even
--- different for each modifier". `d.trinketTabs[mod]` = { [13] = true, [14] = true }; nil = none.
function FM.TabTrinkets(mod)
    local t = db().trinketTabs
    local on = type(t) == "table" and t[mod or ""] or nil
    local out = {}
    for _, s in ipairs(FM.TRINKET_SLOTS) do if type(on) == "table" and on[s] then out[#out + 1] = s end end
    return out
end

--- Tick or untick one trinket on one tab. Returns the new state.
function FM.SetTabTrinket(mod, slot, on)
    if slot ~= 13 and slot ~= 14 then return nil end
    local d = db()
    d.trinketTabs = type(d.trinketTabs) == "table" and d.trinketTabs or {}
    local t = d.trinketTabs[mod or ""] or {}
    t[slot] = on and true or nil
    d.trinketTabs[mod or ""] = next(t) and t or nil
    if not next(d.trinketTabs) then d.trinketTabs = nil end
    -- written to the macro like any bind (keep() lives below; its two lines, inlined)
    FM.touched = true
    if NS.FK and NS.FK.Save then NS.FK.Save(d.binds) end
    if NS.Announce then NS.Announce("BiSHealing_BindsChanged") end
    return on and true or false
end

--- The lines a bind casts BEFORE its heal: its own trinket slots, plus the ones ticked on its
--- modifier's tab, then its booster.
--[[ RIPTIDE AS A CAST SEQUENCE (16 Nov 2026). Arn: "when i put riptide and chain heal on the same left click it gets stuck
  trying to cast riptide" - and his test of the plain two lines: "Nothing casts, with a red 'Spell is not ready yet'". On
  Forever a /cast of a spell that is cooling STOPS the macro, so the heal's line never runs. A cast sequence only moves on
  when a spell really casts, so it goes Riptide, then enough heals to cover Riptide's cooldown, then Riptide again - ready
  by then (Arn's test, five Chain Heals: "it works, riptide comes back after 5 chain heals"). FM.SeqCount: the heals that
  fill Riptide's 12 s less its own global cooldown, from the heal's own cast time (Chain Heal 2.5 s -> 5). reset=15: a
  15 s pause starts it over at Riptide. ]]
FM.RIPTIDE_CD = 12
FM.SEQ_RESET = 15
--[[ COUNTED FROM YOUR CAST TIME, READ OFF THE BOOK (16 Nov 2026). Arn: "make a way for it to read the spell book and see
  what the cast time is cause people like trolls have a racial for 10% faster cast ... haste items". Only a cast that
  FINISHES moves the list on - Arn measured it: "i stopped casting 12 times and it never riptide, i casted 8 to completion
  and then it riptide" (a GCD-counted 8 was an evening's wrong guess: it only made Riptide come back late). So: Riptide,
  its global cooldown, then enough FINISHED heals to outlast the rest of its cooldown, plus one (Arn: "add one more"):
  ceil((cooldown - GCD) / cast time) + 1 - a 2.5 s Chain Heal 6, a 2 s one 7. The cast time is the book's
  (C_Spell.GetSpellInfo), divided by your spell haste (UnitSpellHaste - gear, racials; if the book already counts it,
  the list is one heal longer: the safe side), never under the GCD; Riptide's cooldown is the spell's own
  (GetSpellBaseCooldown). Read when the macro is written, out of a fight, and written again when they change
  (FM.SeqWatch). What still sticks the list: a Riptide cast OUTSIDE it (another bind) - its Riptide step then comes round
  while Riptide cools. ]]
FM.GCD_BASE = 1.5
FM.GCD_FLOOR = 1.0
FM.SEQ_MAX = 14
--- Your spell haste in %, plain, or 0 (unknown counts as none).
function FM.Haste()
    if not UnitSpellHaste then return 0 end
    local ok, h = pcall(UnitSpellHaste, "player")
    if not ok or (NS.Secret and NS.Secret(h)) or type(h) ~= "number" or h ~= h then return 0 end
    return math.max(0, math.min(h, 400))
end
--- The global cooldown your casts start, in seconds.
function FM.SeqGcd()
    return math.max(FM.GCD_FLOOR, FM.GCD_BASE / (1 + FM.Haste() / 100))
end
--- Riptide's own cooldown off the spell book, else 12 s.
function FM.RiptideCooldown()
    local id
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, "Riptide")
        id = ok and type(info) == "table" and info.spellID or nil
    end
    if id and not (NS.Secret and NS.Secret(id)) and GetSpellBaseCooldown then
        local ok, ms = pcall(GetSpellBaseCooldown, id)
        if ok and not (NS.Secret and NS.Secret(ms)) and type(ms) == "number" and ms >= 3000 and ms <= 60000 then return ms / 1000 end
    end
    return FM.RIPTIDE_CD
end
FM.SEQ_EXTRA = 1           -- one heal more than the cooldown needs (Arn, 16 Nov: "add one more chain heal")
FM.CAST_GUESS = 2.5        -- the book did not answer
--- The heal's cast time off the book, in seconds (rank stripped), else FM.CAST_GUESS.
function FM.SeqCastTime(heal)
    local name = type(heal) == "string" and (heal:match("^(.-)%(") or heal) or nil
    if name and C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        local ct = ok and type(info) == "table" and info.castTime or nil
        if ct ~= nil and not (NS.Secret and NS.Secret(ct)) and type(ct) == "number" and ct > 0 then return ct / 1000 end
    end
    return FM.CAST_GUESS
end
--- How many heals follow Riptide: enough FINISHED casts (only those move the list) to outlast its cooldown, plus one.
function FM.SeqCount(heal)
    local cd, gcd = FM.RiptideCooldown(), FM.SeqGcd()
    local step = math.max(gcd, FM.SeqCastTime(heal or "Chain Heal") / (1 + FM.Haste() / 100))
    local n = math.ceil((cd - gcd) / step - 0.001) + FM.SEQ_EXTRA
    return math.max(3, math.min(FM.SEQ_MAX, n))
end
--- One line for the readout: what the list is built from.
function FM.SeqInfo(heal)
    heal = heal or "Chain Heal"
    return string.format("riptide list: %d heals after Riptide (cast %.2fs from the book, haste %.0f%%, GCD %.2fs, Riptide cooldown %gs, reset %ds)",
        FM.SeqCount(heal), FM.SeqCastTime(heal), FM.Haste(), FM.SeqGcd(), FM.RiptideCooldown(), FM.SeqReset())
end
--- The list's reset: longer than Riptide's cooldown, so a pause never lands it on a cooling Riptide.
function FM.SeqReset()
    return math.max(FM.SEQ_RESET, math.ceil(FM.RiptideCooldown()) + 1)
end
FM.GUARD = "/stopmacro [@mouseover,noexists][@mouseover,nohelp][@mouseover,dead]\n"
--- A bind's whole heal text after `pre` (a res line, the wheel's front): the guard, then FM.HealLines - except a Riptide
--- sequence with nothing in front of it, which carries the guard in its own conditions ([@mouseover,help,nodead]) and so
--- has 70 more letters for heals (eight ranked Chain Heals do not fit beside the guard line).
function FM.GuardedHeal(pre, spell, mod, heal)
    pre = pre or ""
    local _, boost = FM.Front(spell)
    if boost and FM.AIMED[boost] and FM.FirstLines(spell, mod, true) == "" then
        return pre .. FM.HealLines(spell, mod, heal, FM.MACRO_MAX - #pre, true)
    end
    local lead = pre .. FM.GUARD
    return lead .. FM.HealLines(spell, mod, heal, FM.MACRO_MAX - #lead)
end
--- The lines that cast a bind's heal, after the guard: what goes first, then the heal - or, with an aimed booster
--- (Riptide), the trinkets and then ONE cast sequence. `room` = characters left in the macro (a sequence shortens to fit).
--- `guarded`: no guard line before it, so the sequence asks for a living friend itself.
function FM.HealLines(spell, mod, heal, room, guarded)
    local _, boost = FM.Front(spell)
    if boost and FM.AIMED[boost] then
        local front = FM.FirstLines(spell, mod, true)
        local cond = guarded and "[@mouseover,help,nodead]" or "[@mouseover]"
        local head = front .. "/castsequence " .. cond .. " reset=" .. FM.SeqReset() .. " " .. boost
        local n, text = FM.SeqCount(heal), nil
        while true do
            local parts = { head }
            for _ = 1, n do parts[#parts + 1] = heal end
            text = table.concat(parts, ", ")
            if n <= 3 or not room or #text <= room then break end
            n = n - 1
        end
        return text
    end
    return FM.FirstLines(spell, mod) .. "/cast [@mouseover] " .. heal
end
FM.MACRO_MAX = 255

--[[ A TRINKET ONCE A FIGHT, NEVER WHILE IT COOLS (24 Nov 2026). Arn: "the trinket on the bind ... gets stuck on item not
  ready". MEASURED that night, all on Forever:
   - `/use 14` (Enamored Water Spirit, cooling) + `/cast [@player] Chain Heal` = "Item is not ready yet", NO Chain Heal: a
     cooling trinket STOPS the macro, as a cooling /cast does. (A `/use 13` on a trinket that was not cooling let the next
     line run, which is why the first probe misled.)
   - A hidden secure button (type item) pressed with `/click`: does nothing until useOnKeyDown is false; then it fires -
     and a cooling trinket inside it STOPS the outer macro all the same. Dead end.
   - `/castsequence reset=combat 14, null` + the cast: the first press drops the totem; the sequence then rests on
     `null` (it never casts, so it never moves on) and every press heals - until the fight ends and it starts over.
  Trinkets after the heal: Arn, "nope dont want trinkets after a heal". So a bind carries its trinket as that sequence,
  written only while the trinket is READY and has a Use: (FM.TrinketReady); out of a fight the binds are written again
  the moment one starts cooling or comes back (FM.TrinketWatch) - a bind never meets a cooling trinket. Its text changes
  each time it comes back (FM.trinkVar), so a sequence left on `null` by a use outside a fight never carries over. The
  deck's trinket button uses the same text (RD.ArmTrinkets), so a use there counts for the binds. A trinket that comes
  back mid-fight waits for the next fight. ]]
FM.trinkVar = FM.trinkVar or { [13] = 0, [14] = 0 }
--- Is the trinket in `slot` ready to use: worn, a Use:, not cooling (asked plainly; out of a fight the answers are).
function FM.TrinketReady(slot)
    if not (GetInventoryItemID and GetInventoryItemCooldown) then return false end
    local okI, id = pcall(GetInventoryItemID, "player", slot)
    if not okI or type(id) ~= "number" or (NS.Secret and NS.Secret(id)) then return false end
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if getSpell then
        local okS, use = pcall(getSpell, id)
        if not okS or type(use) ~= "string" or (NS.Secret and NS.Secret(use)) or use == "" then return false end
    end
    local okC, start, dur = pcall(GetInventoryItemCooldown, "player", slot)
    if not okC then return false end
    if (NS.Secret and (NS.Secret(start) or NS.Secret(dur))) or type(start) ~= "number" or type(dur) ~= "number" then return false end
    if start <= 0 or dur <= 1.5 then return true end                       -- (the global cooldown is not "cooling")
    local now = (GetTime and GetTime()) or 0
    return start + dur <= now
end
--- The line that uses `slot` once a fight - the same text for every bind and the deck's button.
function FM.TrinketSeq(slot)
    -- [combat]: never out of a fight (Arn, 24 Nov: "it did it when i was out of combat when i was healing")
    return "/castsequence [combat] reset=combat " .. slot .. ", null" .. string.rep(", null", (FM.trinkVar[slot] or 0) % 4)
end
--- The bind's line for one trinket slot, or nil while it cannot be used (cooling, passive, none).
function FM.UseLine(slot)
    if FM.TrinketReady(slot) then return FM.TrinketSeq(slot) end
    return nil
end
--- Out of a fight: a trinket starts cooling or comes back -> every bind and the deck written again. Seconds until the
--- next one comes back are timed (the client does not always say).
function FM.TrinketSig()
    return (FM.TrinketReady(13) and "1" or "0") .. (FM.TrinketReady(14) and "1" or "0")
end
function FM.TrinketCheck()
    if InCombatLockdown and InCombatLockdown() then return false end
    local sig = FM.TrinketSig()
    if sig == FM.trinkSig then return false end
    local was = FM.trinkSig or "00"
    for i, slot in ipairs({ 13, 14 }) do
        if sig:sub(i, i) == "1" and was:sub(i, i) ~= "1" then FM.trinkVar[slot] = (FM.trinkVar[slot] or 0) + 1 end
    end
    FM.trinkSig = sig
    FM.Apply()
    if NS.RD and NS.RD.ArmTrinkets then NS.RD.ArmTrinkets() end
    FM.TrinketTimer()
    return true
end
function FM.TrinketTimer()
    if not (C_Timer and C_Timer.After and GetInventoryItemCooldown and GetTime) then return end
    local soonest
    for _, slot in ipairs({ 13, 14 }) do
        local ok, start, dur = pcall(GetInventoryItemCooldown, "player", slot)
        if ok and type(start) == "number" and type(dur) == "number" and not (NS.Secret and (NS.Secret(start) or NS.Secret(dur)))
           and start > 0 and dur > 1.5 then
            local left = start + dur - GetTime()
            if left > 0 and (not soonest or left < soonest) then soonest = left end
        end
    end
    if not soonest then return end
    FM.trinkToken = (FM.trinkToken or 0) + 1
    local token = FM.trinkToken
    C_Timer.After(soonest + 0.2, function() if token == FM.trinkToken then FM.TrinketCheck() end end)
end
FM.TRINKET_EVENTS = { "PLAYER_REGEN_ENABLED", "SPELL_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD" }
--- Listen only while some bind carries a trinket (Lean and mean): asked after every write of the binds.
function FM.TrinketWatch()
    local any = false
    local d = db()
    for _, cast in pairs(d.binds or {}) do
        if type(cast) == "string" and #FM.Front(cast) > 0 then any = true break end
    end
    if not any and type(d.trinketTabs) == "table" and next(d.trinketTabs) then any = true end
    if not CreateFrame then return any end
    if any and not FM.trinkWatch then
        FM.trinkWatch = CreateFrame("Frame")
        FM.trinkWatch:SetScript("OnEvent", function() FM.TrinketCheck() end)
    end
    if FM.trinkWatch then
        for _, ev in ipairs(FM.TRINKET_EVENTS) do
            if any then pcall(FM.trinkWatch.RegisterEvent, FM.trinkWatch, ev) else pcall(FM.trinkWatch.UnregisterEvent, FM.trinkWatch, ev) end
        end
    end
    if any and not FM.trinkSig then FM.trinkSig = FM.TrinketSig() FM.TrinketTimer() end
    return any
end

function FM.FirstLines(cast, mod, noAimed)
    if type(cast) ~= "string" or FM.PingOf(cast) then return "" end
    local slots, boost = FM.Front(cast)
    for _, s in ipairs(FM.TabTrinkets(mod)) do slots[#slots + 1] = s end
    local seen, lines = {}, {}
    table.sort(slots)
    for _, s in ipairs(slots) do
        if not seen[s] then seen[s] = true lines[#lines + 1] = FM.UseLine(s) end   -- (nil while it cannot be used: no line)
    end
    if boost and not (noAimed and FM.AIMED[boost]) then
        -- an aimed one (Riptide) goes on the living friend under the mouse, never on you by the client's self-cast
        lines[#lines + 1] = "/cast " .. (FM.AIMED[boost] and "[@mouseover,help,nodead] " or "") .. boost
    end
    return #lines > 0 and (table.concat(lines, "\n") .. "\n") or ""
end

--- Split a stored bind back into its parts, for showing it. Whatever goes first is not part of
--- the name: the name is the heal's, so its icon, its ranks and its range are the heal's.
function FM.Split(cast)
    if type(cast) ~= "string" then return nil, nil end
    local _, _, plain = FM.Front(cast)
    cast = plain
    local name, rank = cast:match("^(.-)%((.-)%)$")
    if name then return name, rank end
    return cast, nil
end

--- The spell the grid asks about when it wants to know who is reachable: whatever is on the left
--- button, without its rank - a rank has no bearing on range, and "Healing Wave(Rank 3)" is a
--- cast string, not a spell name the range call would recognise.
---
--- This is why the grid holds no spell names at all now. The range that matters is the range of
--- the thing your click would actually cast, which is a different spell for every class and a
--- different spell again when you drag something new onto the mouse.
--- AND ITS SPELL ID, because a NAME is not what this call wants. EllesmereUI passes ids
--- (`C_Spell.IsSpellInRange(361469, unit)`) and their notes say why it matters: a spell the call
--- cannot answer for "stranded Evoker frames at full alpha" - which is exactly what Arn reported
--- on 30 Sep, a raid with nobody dimmed.
---
--- Second return: ANY id this character has for the spell. Not the bound rank's - every rank of a
--- heal has the same range, so matching it was a branch with nothing behind it (a mutation that
--- removed it changed no answer, which is the test telling you the code is pretending). nil when
--- the book has not answered yet, and then the name is all there is to try.
function FM.RangeSpell()
    -- LEFT AND RIGHT FIRST, then ANYTHING BOUND. Arn, 30 Sep, with /bish range answering "range is
    -- measured with nothing": his heals live on the wheel and the thumb buttons, and nothing at
    -- all is on left or right click. This looked at those two and gave up - so the dimming has
    -- never once run for him, on any character, since the day it was written.
    --
    -- Any heal he has bound answers the range question about as well as any other: they are all
    -- 40 yards, and "can I reach them with what I cast" is the question either way. Left and right
    -- stay first because that is what the hand reaches for.
    -- A PING IS NOT A SPELL AND HAS NO RANGE (1 Oct 2026). Without this, binding a ping to left
    -- click would hand "!ping:assist" to the range call, which answers "don't know" for a spell it
    -- cannot find - read as "in range", so the whole raid stays bright. That is exactly the bug
    -- 0.7.2 and 0.7.5 were spent on, and it would have come back through a new door.
    local function spellAt(mod, key)
        local c = FM.Get(mod, key)
        if c and (FM.PingOf(c) or FM.MacroOf(c)) then return nil end   -- a macro has no range to ask
        return c
    end
    -- THE LONGEST REACH OF EVERY HEAL YOU KNOW (7 Oct 2026). Arn: "now that we know more about
    -- the client can we check all the healing spells and use that range the biggest one". Every
    -- spell bound (left and right first, then the rest), then the class's own heals, each asked
    -- for its maximum range; the longest wins, and a tie keeps the earlier - the one the hand
    -- reaches for. A spell the client calls NOT helpful is skipped: a damage spell on a bind has
    -- a range too, and it answers nil about a friend, which is "no answer" for the whole raid.
    local order, seen = {}, {}
    local function add(cast)
        if not cast then return end
        local name = FM.Split(cast)
        if name and not seen[name] then seen[name] = true order[#order + 1] = name end
    end
    add(spellAt("", "left")) add(spellAt("", "right"))
    for _, slot in ipairs(FM.SLOTS) do
        for _, m in ipairs(FM.MODS) do add(spellAt(m.key, slot.key)) end
    end
    -- select(2, ...), not `local _, class = UnitClass and UnitClass(...)`: `x and f()` keeps only
    -- f's FIRST return, so that line left `class` nil and no class heal was ever asked (7 Oct -
    -- the truncated-returns landmine, which the suite caught and bislint did not)
    local class = UnitClass and select(2, UnitClass("player"))
    -- in a FIXED order: `pairs` has none, and between two equal heals the winner would be chance
    local defaults = FM.CLASS_DEFAULTS[class or ""] or {}
    for _, k in ipairs({ "left", "right", "shift-left" }) do add(defaults[k]) end

    local best, bestID, bestRange
    for _, name in ipairs(order) do
        local id
        for _, r in ipairs(FM.Ranks(name) or {}) do if r.spell then id = r.spell break end end
        if id then
            local helpful = FM.Helpful(id)
            if helpful ~= false then
                local reach = FM.MaxRange(id) or 0
                if not bestRange or reach > bestRange then best, bestID, bestRange = name, id, reach end
            end
        end
    end
    -- the reach rides along third, so /bish range can show its working
    if best then return best, bestID, bestRange end
    -- the book has not answered yet (login): the first bound spell by name is all there is to try
    return order[1]
end

--- Is this spell one you cast on a friend? true / false, or nil when the client will not say.
function FM.Helpful(id)
    local f = C_Spell and C_Spell.IsSpellHelpful
    if not f then return nil end
    local ok, v = pcall(f, id)
    if not ok or (NS.Secret and NS.Secret(v)) then return nil end
    if v == true or v == 1 then return true end
    if v == false or v == 0 then return false end
    return nil
end

--- A spell's maximum range in yards, or nil. C_Spell.GetSpellInfo answers a TABLE (`maxRange`);
--- the old global answered it as the 6th return - both shapes, as RezComm learned on 17 Sep.
function FM.MaxRange(id)
    local get = (C_Spell and C_Spell.GetSpellInfo) or GetSpellInfo
    if not get then return nil end
    local ok, a, _, _, _, _, six = pcall(get, id)
    if not ok then return nil end
    local r = (type(a) == "table") and a.maxRange or six
    if NS.Secret and NS.Secret(r) then return nil end
    return type(r) == "number" and r or nil
end

--- EVERY RANK OF A SPELL THIS CHARACTER KNOWS, oldest first, out of the spellbook.
---
--- Arn, 19 Sep: "did not let me do different rank on modifier and shift modifier". Dropping a
--- lower rank assumes the spellbook is showing you one to drag, and that is a setting - on a
--- book showing max ranks only there is nothing to drag and no way to say what you meant.
---
--- So the window stops depending on the drag for this: bind the spell once, then click the rank.
--- The list comes from the book itself, so it is exactly what this character has trained.
---
--- THE BOOK IS READ ONCE AND KEPT (8 Oct 2026). This used to walk all 500 slots on every call,
--- and it is called a great deal: the grid asks FM.RangeSpell for every cell on every tick, which
--- asks here about every spell on the mouse; BiS> now asks FB.Knows on every tick as well. Arn's
--- own mouse in a 25-man came to 126 walks a tick - 630,000 questions a second about a book that
--- had not changed since login. His addon list said so before anything else did: "Current CPU
--- 6%" with the addon off or the cells hidden, "63%" with them shown.
---
--- So one walk fills `book.names` for every spell at once, and it is thrown away when:
---   * the client says the book changed (SPELLS_CHANGED, PLAYER_ENTERING_WORLD - FM.BookChanged)
---   * it is FM.BOOK_TTL seconds old, in case there is a way to learn a spell that fires neither
---   * it came back EMPTY, which is never kept: at login the client has not filled the book in
---     yet, and an empty answer remembered is a mouse with no defaults for the whole session
local book = {}
-- 60, not 5 (8 Oct 2026). Arn's /bish range: "read 70 times since login" - the 5 s net was the
-- only thing still reading it. Learning a spell fires SPELLS_CHANGED, which re-reads at once; the
-- net is for a way nobody has seen, and "at level 60 you stop learning spells anyways".
FM.BOOK_TTL = 60
FM.bookReads = 0          -- how many times the book has been walked; /bish range prints it

--- The real spell id behind a book slot, or nil. The same read SelfBuff.lua has always done.
function book.idAt(i, bank)
    if not (C_SpellBook and C_SpellBook.GetSpellBookItemInfo) then return nil end
    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, bank)
    local id = ok and type(info) == "table" and NS.Plain(info.spellID) or nil
    return type(id) == "number" and id or nil
end

-- `index` IS A BOOK SLOT AND `spell` IS A SPELL ID, and they are not the same number (1 Oct
-- 2026). This field was called `id` and held the slot, which read like a spell id to everything
-- that touched it - so three callers asked the client about the wrong thing entirely, and the
-- only reason it was ever noticed is that `/bish byid` printed the number: Arn's Water Shield
-- came back as "id 35", which is a row in his spellbook.
--
-- The one that had been wrong longest is the range check (0.7.2), which has been asking
-- IsSpellInRange about slot numbers ever since and quietly working off its name fallback - a
-- bug hidden by its own safety net. A field named for what it is cannot be misread that way.
function book.add(into, nm, rank, index, spell)
    -- a secret string refuses to be a table key, and a name we may not read is not one we can
    -- be asked about by name either
    if type(nm) ~= "string" or nm == "" or NS.Secret(nm) then return false end
    local e = into[nm]
    if not e then
        e = { ranks = {}, seen = {}, ids = {} }
        into[nm] = e
    end
    -- every id under the name, rank or no rank: a buff is a different id at every rank
    if type(spell) == "number" then e.ids[#e.ids + 1] = spell end
    local key = tostring(rank or "")
    if e.seen[key] then return true end
    e.seen[key] = true
    e.ranks[#e.ranks + 1] = { rank = (type(rank) == "string" and rank ~= "") and rank or nil,
                              index = index, spell = spell }
    return true
end

--- Walk the modern book once, every slot, into a table keyed by spell name.
function book.readModern()
    local names, n = {}, 0
    -- THE MODERN BOOK TAKES TWO ARGUMENTS: the slot, and which bank it is in. Measured in game
    -- on 1.60.1.69913, 19 Sep 2026, after this function had been answering "no ranks" forever:
    --
    --   C_SpellBook.GetSpellBookItemName(1)     -> error: bad argument #1 (not a numerical value)
    --   C_SpellBook.GetSpellBookItemName(1, 0)  -> "Attack"
    --
    -- Called with one argument it errors on EVERY slot. The pcall caught that and the loop just
    -- kept going, so the list came back empty and stayed empty - and three separate things
    -- quietly did nothing: the class defaults were never seeded (a blank mouse at every login),
    -- the rank button had nothing to walk through, and the binder showed no ranks. Arn reported
    -- all three as separate complaints over two days. One missing argument.
    --
    -- It swallowed its own cause, which is the lesson: a pcall around a call whose SIGNATURE you
    -- are guessing turns "I am calling this wrong" into "the client has nothing", and those two
    -- look identical from here. The suite could not catch it either, because the mock answered
    -- the one-argument call - it refuses it now.
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    if C_SpellBook and C_SpellBook.GetSpellBookItemName then
        -- cost: once per SPELLS_CHANGED / PLAYER_ENTERING_WORLD, or every FM.BOOK_TTL s - kept between
        for i = 1, 500 do
            local got, nm, sub = pcall(C_SpellBook.GetSpellBookItemName, i, bank)
            if got and type(nm) == "string" and nm ~= "" then
                if book.add(names, nm, sub, i, book.idAt(i, bank)) then n = n + 1 end
            end
        end
    end
    return names, n
end

--- The old book: (index, bookType), and a count per tab. Only ever asked about a name the modern
--- book did not have, which is what the walk-per-call did too.
function book.readOld()
    local names, n = {}, 0
    if GetSpellBookItemName and GetNumSpellTabs then
        -- cost: only when the modern book came back empty, and kept with it (book.get)
        for i = 1, 500 do
            local got, nm, sub = pcall(GetSpellBookItemName, i, "spell")
            if got and type(nm) == "string" and nm ~= "" then
                if book.add(names, nm, sub, i, nil) then n = n + 1 end
            end
        end
    end
    return names, n
end

--- The book as last read, or read now. Second return: the old book's table, filled only when a
--- caller needs it (pass true).
function book.get(wantOld)
    local now = GetTime and GetTime()
    local fresh = book.names and now and book.at and (now - book.at) >= 0 and (now - book.at) < FM.BOOK_TTL
    if not fresh then
        local names, n = book.readModern()
        local old, m = nil, 0
        if n == 0 then old, m = book.readOld() end      -- a client with only the old book
        FM.bookReads = FM.bookReads + 1
        if (n + m) > 0 and now then
            book.names, book.old, book.at = names, old, now
        elseif book.names and now then
            -- IT ONLY GOT OLD, AND NOW THE CLIENT ANSWERS NOTHING. Nobody said the book changed
            -- (FM.BookChanged empties book.names, and then this branch is not reached) - the kept
            -- one just reached its age, and the re-read came back empty. A character does not
            -- unlearn every spell in silence; a client that has gone quiet mid-fight is the
            -- likelier story, and this addon keeps what it last knew when that happens. Asked
            -- again in another FM.BOOK_TTL, not on every call: that would be the old cost back
            -- at exactly the moment the client is busiest.
            book.at = now
        else
            -- empty with nothing kept, or no clock to age it by: never kept
            book.names, book.old, book.at = nil, nil, nil
            return names, old
        end
    end
    if wantOld and not book.old then book.old = (book.readOld()) end
    return book.names, book.old
end

--- The client said the book changed, or something that knows it did is telling us. Cheap: the
--- next question walks it again, and a hundred of these in a row cost one walk.
function FM.BookChanged()
    book.names, book.at, book.old = nil, nil, nil
end

do
    local okF, f = pcall(CreateFrame, "Frame")
    if okF and f then
        for _, e in ipairs({ "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }) do
            pcall(f.RegisterEvent, f, e)        -- an event this client does not know must not abort the file
        end
        f:SetScript("OnEvent", function() FM.BookChanged() end)
        FM.bookEvents = f
    end
end

--- A fresh list every time, never the kept one: a caller that sorted or trimmed it in place
--- would be rewriting the memory every other caller reads.
function FM.Ranks(name)
    if not name or name == "" then return {} end
    local names = book.get()
    local e = names and names[name]
    if not e and GetSpellBookItemName and GetNumSpellTabs then
        local _, old = book.get(true)
        e = old and old[name]
    end
    local out = {}
    if e then for i, r in ipairs(e.ranks) do out[i] = r end end
    return out
end

--- Every spell id this character has under a name, one per rank, from the same single read.
--- SelfBuff's FS.SpellIds and the HoT markers' FA.HotIds each walked the book for this themselves.
---
--- YOUR PET'S SPELLS TOO (15 Nov 2026, the spell research for the flight deck): a warlock's Spell Lock and Devour Magic
--- are the Felhunter's, never in the player's book - so the kick and the cure box never found them. A pet spell has no
--- name to look up by, so FM.PET_SPELLS holds its Forever ids (CONFIRMED from two saved spell caches) and the client is
--- asked, rank by rank, whether your pet knows it (`IsSpellKnown(id, true)`). Cast by its name, a pet spell goes out at
--- its highest rank - the one Spell Lock should use (8 s lockout, not 6).
FM.PET_SPELLS = {
    ["Spell Lock"] = { 19244, 19647 },
    ["Devour Magic"] = { 19505, 19731, 19734, 19736 },
}
function FM.BookIds(name)
    local out = {}
    if not name or name == "" then return out end
    local names = book.get()
    local e = names and names[name]
    if e then for i, id in ipairs(e.ids) do out[i] = id end end
    if #out == 0 and FM.PET_SPELLS[name] and IsSpellKnown then
        for _, id in ipairs(FM.PET_SPELLS[name]) do
            local ok, has = pcall(IsSpellKnown, id, true)
            if ok and NS.Plain(has) == true then out[#out + 1] = id end
        end
    end
    return out
end

--- Put the next rank of whatever is in this slot into this slot. Wraps, so clicking it enough
--- times comes back to where it started - which is what makes it safe to click without reading.
function FM.CycleRank(mod, slotKey)
    local cast = FM.Get(mod, slotKey)
    if not cast then return nil end
    local name, rank = FM.Split(cast)
    local ranks = FM.Ranks(name)
    if #ranks < 2 then return cast end            -- one rank, or a spell that has none
    local at = 1
    for i, r in ipairs(ranks) do
        if r.rank == rank then at = i break end
    end
    local nextRank = ranks[(at % #ranks) + 1]
    -- the booster in front stays in front: stepping the heal's rank must not drop Nature's Swiftness
    -- whatever goes first (trinkets, the booster) stays in front: stepping the heal's rank keeps it
    local slots, boost = FM.Front(cast)
    local new = FM.Compose(slots, boost, FM.Cast(name, nextRank and nextRank.rank))
    FM.Set(mod, slotKey, new)
    return new
end

--- Remember a bind. Returns the spell, or nil and why not.
--- Written to the macro as well as the table, because the table does not survive this client.
--- A refusal is not an error here: in combat the client will not make a macro, and the next
--- change out of combat writes the whole mouse anyway - there is no half-saved state to repair.
local function keep(d)
    FM.touched = true              -- a deliberate act, never to be thrown away by us
    -- AND NOT ONLY FOR THIS SESSION (26 Nov 2026): `bindsSeeded` says "this mouse is our guess", and
    -- it stayed true for good after the first login's class defaults, whatever the player bound
    -- since. The next session's FM.Reconsider then took their ranks for our guess (see there).
    d.bindsSeeded = nil
    if NS.FK and NS.FK.Save then
        -- SAID, NOT SILENT (14 Oct 2026, Arn's cousin: a Nature's Swiftness bind "not saving").
        -- A full macro sheds its LAST binds, and they were gone at the next load with no word.
        local done, dropped = NS.FK.Save(d.binds)
        if done and type(dropped) == "number" and dropped > 0 and NS.Print then
            NS.Print("|cfff08cb0%d bind(s) did not fit in the save macro|r and will be gone after a reload"
                .. " - /bish keep shows which", dropped)
        end
    end
    if NS.Announce then NS.Announce("BiSHealing_BindsChanged") end   -- API.lua, for other addons
end

--- The macro list is not always populated the moment we first ask. If it filled in late, what
--- is on the mouse now is OUR guess - the class defaults - and the player's real binds are
--- sitting in a macro we have already stopped asking about. Worse, the next spell they drag
--- would write the guess over them.
---
--- So: when the client says the macros changed, throw away a mouse that only we put there and
--- ask again. Never a mouse the player has touched - FM.touched is the difference between our
--- guess and their act, and their act wins every time.
---
--- THE RANKS LOST AT A SPEC SWITCH (26 Nov 2026, Arn: "not remembering the ranks is when he is switching
--- specs"). FM.touched lasts one session; `bindsSeeded` lasted forever. A player who started on the class
--- defaults and then dragged their own ranks still carried the flag, so in any later session where they had
--- not touched the mouse yet, UPDATE_MACROS (every login, and - very likely - a spec switch, which reloads the
--- macro list) wiped their binds and read the macro again. If the macro was not there at that moment, the
--- class defaults - the TOP rank of each - came back in their place, and their next drag saved that over
--- the macro for good. Now a seeded flag is believed only while the mouse still IS the defaults; a mouse
--- that differs is theirs and the flag goes. With the book not in, nobody can tell: nothing is touched.
function FM.OnlyDefaults(binds)
    local defaults, booked = FM.Defaults()
    if not booked then return nil end
    for k, v in pairs(binds or {}) do if defaults[k] ~= v then return false end end
    return true
end
function FM.Reconsider()
    if NS.FK and NS.FK.MacrosArrived then NS.FK.MacrosArrived() end   -- the event means the list is in
    local d = db()
    if FM.touched then return false end
    if d.bindsSeeded then
        local ours = FM.OnlyDefaults(d.binds)
        if ours == nil then return false end                           -- the book is not in: next event
        if ours == false then d.bindsSeeded = nil return false end     -- theirs since: never ours to wipe
    end
    if d.bindsSeeded then
        for k in pairs(d.binds) do d.binds[k] = nil end
    elseif next(d.binds) then
        return false                   -- binds that came from the macro are not a guess to throw away
    end
    d.bindsSeeded, FM.asked = nil, false
    db()                           -- asks the macro first, seeds again only if it is empty
    return true
end

function FM.Set(mod, slotKey, spell)
    if type(spell) ~= "string" or spell == "" then return nil, "not a spell" end
    local d = db()
    d.binds[(mod or "") .. slotKey] = spell
    keep(d)
    return spell
end

function FM.Get(mod, slotKey)
    return db().binds[(mod or "") .. slotKey]
end

function FM.Clear(mod, slotKey)
    local d = db()
    d.binds[(mod or "") .. slotKey] = nil
    keep(d)
end

--- Write every click bind onto one cell. OUT OF COMBAT ONLY: SetAttribute on a secure frame is
--- refused inside the lockdown, so this answers false there and the caller tries again later.
---
--- AN EMPTY BUTTON TARGETS. Arn, 22 Sep 2026, from a player's request: "if a key is not bound to
--- anything on the mouse that defaults to target". A click with nothing on it used to do nothing
--- at all; now it selects the person, the way Blizzard's own frames do - through the client's
--- built-in "target" action, which is secure and so works in a fight too. The wheel is not a
--- click on the cell (FM.ApplyWheel) and is untouched: an empty wheel still zooms the camera.
---
--- LET CLIQUE HAVE THEM. Arn, 22 Sep: "im a clique user and it uses all of theirs". Two addons
--- writing what a click means onto the same frame is a race - whichever wrote last wins, and that
--- changes with every layout. So it is ONE OWNER, by the player's switch (d.clique):
---   on   our click attributes are cleared, the wheel is let go, and the cell is registered in
---        ClickCastFrames - the shared list Clique (and Clicked, oUF, Healium) use. Clique then
---        owns every click, key and wheel turn on the grid.
---   off  the cell is unregistered and our binds go back on. With `= nil`, not `= false`: Clique
---        (v5.1, core.lua CaptureGlobalRegistry) takes nil and false alike as "unregister" once it
---        has loaded, but a frame already in the list when it loads is registered WHATEVER its
---        value - a `false` left behind before Clique arrived would register the cell anyway.
--- Registration is the documented `ClickCastFrames[frame] = true`; the table is made only when no
--- click-cast addon has made it yet, never written over (see the Blizzard-global test).
function FM.CliqueOn()
    local d = NS.DB and NS.DB()
    return type(d) == "table" and d.clique == true
end

local function cliqueRegister(cell, on)
    if on then
        if not ClickCastFrames then ClickCastFrames = {} end
        ClickCastFrames[cell] = true
        cell.__clique = true
    elseif cell.__clique then
        if ClickCastFrames then ClickCastFrames[cell] = nil end
        cell.__clique = nil
    end
end

--- One button's hostile half on a cell (FM.HARM). The client's own secure click code does the switching: on a unit
--- it may attack, `<mod>harmbutton<n>` renames the button to "harm<n>", and every attribute is then read with the
--- suffix "-harm<n>" - so an enemy under the click casts the hostile bind and a friend the heal, with nothing of
--- ours running at the click (and so nothing refused in combat). No hostile bind: nothing renamed, the heal's own.
local function harmTo(cell, prefix, attr, modKey, slotKey)
    local hb = "harm" .. attr
    local harm = FM.Get(FM.HARM .. modKey, slotKey)
    local kind, spell, text, macro
    if harm then
        local ping = FM.PingOf(harm)
        if ping then
            kind, text = "macro", "/ping [@mouseover] " .. ping
        elseif FM.MacroOf(harm) then
            kind, macro = "macro", FM.MacroOf(harm)
        elseif FM.FirstLines(harm, FM.HARM .. modKey) ~= "" then
            -- a booster or a trinket in front: one macro, guarded the hostile way round
            local _, nuke = FM.Boost(harm)
            kind = "macro"
            text = "/stopmacro [@mouseover,noexists][@mouseover,noharm][@mouseover,dead]\n"
                .. FM.FirstLines(harm, FM.HARM .. modKey) .. "/cast [@mouseover] " .. nuke
        else
            kind, spell = "spell", harm
        end
    end
    cell:SetAttribute(prefix .. "harmbutton" .. attr, harm and hb or nil)
    cell:SetAttribute(prefix .. "type-" .. hb, kind)
    cell:SetAttribute(prefix .. "spell-" .. hb, spell)
    cell:SetAttribute(prefix .. "macrotext-" .. hb, text)
    cell:SetAttribute(prefix .. "macro-" .. hb, macro)
    return harm and 1 or 0
end

--- Everything of ours off one cell: the heal half, the macro names and the hostile half.
local function clearOurs(cell, keepType)
    for _, slot in ipairs(FM.SLOTS) do
        if slot.attr then
            for _, m in ipairs(FM.MODS) do
                local prefix = m.key == "" and "*" or m.key
                if not keepType then
                    cell:SetAttribute(prefix .. "type" .. slot.attr, nil)
                    cell:SetAttribute(prefix .. "spell" .. slot.attr, nil)
                end
                cell:SetAttribute(prefix .. "macrotext" .. slot.attr, nil)
                cell:SetAttribute(prefix .. "macro" .. slot.attr, nil)
                cell:SetAttribute(prefix .. "harmbutton" .. slot.attr, nil)
                local hb = "-harm" .. slot.attr
                for _, a in ipairs({ "type", "spell", "macrotext", "macro" }) do cell:SetAttribute(prefix .. a .. hb, nil) end
            end
        end
    end
end

function FM.ApplyTo(cell)
    if InCombatLockdown and InCombatLockdown() then return false end
    if not cell or not cell.SetAttribute then return false end
    FM.WheelArm(cell)                             -- the wheel works over this frame (WHERE THE WHEEL WORKS)
    -- DEAD, OUT OF COMBAT: EVERY CLICK RESURRECTS (FM.ResNow) - whatever is bound, and on an empty
    -- button too; the binds come back when they stand up or a fight starts
    local res = not FM.CliqueOn() and FM.ResNow(cell)
    cell.__res = res and true or nil
    if res then
        clearOurs(cell, true)
        for _, slot in ipairs(FM.SLOTS) do
            if slot.attr then
                for _, m in ipairs(FM.MODS) do
                    local prefix = m.key == "" and "*" or m.key
                    cell:SetAttribute(prefix .. "type" .. slot.attr, "spell")
                    cell:SetAttribute(prefix .. "spell" .. slot.attr, res)
                end
            end
        end
        cliqueRegister(cell, false)
        return true, 0
    end
    if FM.CliqueOn() then
        -- clear everything of ours first, so nothing of ours is left for Clique to fight
        clearOurs(cell)
        cliqueRegister(cell, true)
        return true, 0
    end
    cliqueRegister(cell, false)
    local n = 0
    for _, slot in ipairs(FM.SLOTS) do
        if slot.attr then
            for _, m in ipairs(FM.MODS) do
                local spell = FM.Get(m.key, slot.key)
                local prefix = m.key == "" and "*" or m.key
                -- EMPTY 3-5 TARGET BY MACRO. Measured on the beta (22 Sep): the thumbs and the
                -- wheel click reach the cell - a bound spell casts - but an empty one set to type
                -- "target" does nothing; the SecureUnitButton path honours "target" for buttons 1
                -- and 2 only. So 1-2 keep the built-in action, and 3-5 get a secure macro that does
                -- the same thing through the one unit the cursor is on.
                local kind, text, cast, macro = nil, nil, spell, nil
                local ping = FM.PingOf(spell)
                if FM.MacroOf(spell) then
                    -- a macro: the client runs it by name; it aims itself (write [@mouseover] in it)
                    kind, cast, macro = "macro", nil, FM.MacroOf(spell)
                elseif ping then
                    -- `[@mouseover]` IS THE WHOLE THING (measured 1 Oct 2026). Without it the ping
                    -- fires at wherever the cursor is in the WORLD, so clicking a person's cell
                    -- pings the floor at your feet - which Arn saw, and which is worse than no
                    -- button at all. The same condition the wheel binds have used all along:
                    -- "/target [@mouseover]". Arn confirmed by hand before a line of this changed.
                    kind, text, cast = "macro", "/ping [@mouseover] " .. ping, nil
                elseif spell and FM.FirstLines(spell, m.key) ~= "" then
                    -- WHAT GOES FIRST, THEN THE HEAL, in one press: trinkets, the booster, the
                    -- heal - a macro, aimed like the ping at the cell under the cursor (a click on
                    -- a cell makes it the mouseover). The wheel's guard too, so no cooldown is ever
                    -- spent on a dead or hostile cell.
                    local _, heal = FM.Boost(spell)
                    kind, cast = "macro", nil
                    text = FM.GuardedHeal(FM.ResLine(spell), spell, m.key, heal)
                elseif spell and FM.ResLine(spell) ~= "" then
                    -- a heal with a res in front of it: one macro, the client picks at the click
                    kind, cast = "macro", nil
                    text = FM.ResLine(spell) .. "/cast [@mouseover] " .. spell
                elseif spell and cell.__guard then
                    -- THE GUARD (the radar's pips, 10 Nov 2026 - Arn: a dead man's red sword "healed me"): the
                    -- client hands a plain spell on someone it cannot land on to its self-cast, so here a bound spell
                    -- is a macro that casts only on the living and friendly, and otherwise casts nothing
                    kind, cast = "macro", nil
                    text = "/cast [@mouseover,help,nodead] " .. spell
                elseif spell then kind = "spell"
                elseif slot.attr <= 2 then kind = "target"
                else kind, text = "macro", "/target [@mouseover]" end
                cell:SetAttribute(prefix .. "type" .. slot.attr, kind)
                cell:SetAttribute(prefix .. "spell" .. slot.attr, cast or nil)
                cell:SetAttribute(prefix .. "macrotext" .. slot.attr, text)
                cell:SetAttribute(prefix .. "macro" .. slot.attr, macro)
                if spell then n = n + 1 end
                n = n + harmTo(cell, prefix, slot.attr, m.key, slot.key)
            end
        end
    end
    return true, n
end

--- The wheel, which no button can take as a click: one hidden secure action button per direction
--- and modifier, holding a macro that aims at whatever the cursor is over.
local wheelButtons = {}

--[[ WHERE THE WHEEL WORKS (14 Nov 2026, Arn's cousin: "when he mouse wheels down it casts on his mouseover target and
  it's not even in our frame - when he disables the addon mouse wheel down zooms out again"). The wheel binds were
  BINDINGS over the whole screen (8 Nov: Arn wanted them on the Ellesmere frames too), so a wheel turn over a friend in
  the world cast on him, and the camera never zoomed. Now `wheelWhere`:
    "frames" (the default) - bound only while the mouse is over one of OUR frames (grid cells, PvP cells, radar pips and
      pets): each is wrapped by a secure handler whose OnEnter sets the wheel's bindings on that frame and OnLeave / OnHide
      clears them (FM.WheelArm, Clique's road - it runs in a fight too); everywhere else the wheel zooms the camera.
    "everywhere" - the old way, over any unit frame of any addon (and the camera loses the wheel). `/bish wheel`.
  15 Nov 2026 (Arn: "it used to carry the bishealing bind ... can we still make it work when its on a party frame"):
    "frames" (still the default) now means OUR frames AND every unit frame - the shared ClickCastFrames list (EllesmereUI,
      VuhDo, oUF frames put theirs there) and the game's own unit frames (FM.WHEEL_BLIZZARD) - the same hover road, so
      the wheel heals over any party frame and zooms the camera over the world. (FM.WheelOthers)
    "ours" - BiS Healing's frames only (what 1.5.1 did). ]]
function FM.WheelWhere()
    local d = db()
    local w = d and d.wheelWhere
    return (w == "everywhere" or w == "ours") and w or "frames"
end

FM.WHEEL_ENTER = [[
    local n = self:GetAttribute("bis-wn") or 0
    for i = 1, n do
        local k, b = self:GetAttribute("bis-wk" .. i), self:GetAttribute("bis-wb" .. i)
        if k and b then self:SetBindingClick(true, k, b) end
    end
]]
FM.WHEEL_LEAVE = [[ self:ClearBindings() ]]
FM.wheelMap, FM.wheelCells = {}, {}

--- One of our frames takes the wheel while the mouse is over it: wrapped once (out of a fight), then handed this map.
--- `foreign` = another addon's (or the game's) unit frame: armed only while the setting is "frames".
function FM.WheelArm(cell, foreign)
    if not cell or (InCombatLockdown and InCombatLockdown()) or not cell.SetAttribute then return false end
    if not FM.wheelHeader and CreateFrame then
        local ok, h = pcall(CreateFrame, "Frame", "BiSHealingWheelHeader", UIParent, "SecureHandlerBaseTemplate")
        FM.wheelHeader = ok and h or false
    end
    local H = FM.wheelHeader
    if H and H.WrapScript and not FM.wheelCells[cell] then
        local ok = pcall(H.WrapScript, H, cell, "OnEnter", FM.WHEEL_ENTER)
        if ok then
            pcall(H.WrapScript, H, cell, "OnLeave", FM.WHEEL_LEAVE)
            pcall(H.WrapScript, H, cell, "OnHide", FM.WHEEL_LEAVE)
            FM.wheelCells[cell] = true
        end
    end
    local where = FM.WheelWhere()
    local on = (where == "frames" or (where == "ours" and not foreign)) and not FM.CliqueOn()
    local map = on and FM.wheelMap or {}
    local was = tonumber(cell:GetAttribute("bis-wn")) or 0
    for i, e in ipairs(map) do
        cell:SetAttribute("bis-wk" .. i, e.key)
        cell:SetAttribute("bis-wb" .. i, e.button)
    end
    for i = #map + 1, was do cell:SetAttribute("bis-wk" .. i, nil) cell:SetAttribute("bis-wb" .. i, nil) end
    cell:SetAttribute("bis-wn", #map)
    return true
end

--- THE OTHER UNIT FRAMES (15 Nov 2026): every frame in the shared ClickCastFrames list, and the game's own unit frames,
--- take the wheel on hover too (setting "frames"). Out of a fight only; frames already wrapped are only re-handed the
--- map when `all`. A frame another addon took back out of ClickCastFrames (EllesmereUI does, when its own click-casting
--- is on) is handed an empty map. The game's frames are skipped while its gamepad UI is on (solved.md: no hooks on
--- Blizzard frames then).
FM.WHEEL_BLIZZARD = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame" }
for i = 1, 4 do FM.WHEEL_BLIZZARD[#FM.WHEEL_BLIZZARD + 1] = "PartyMemberFrame" .. i end
for i = 1, 5 do FM.WHEEL_BLIZZARD[#FM.WHEEL_BLIZZARD + 1] = "CompactPartyFrameMember" .. i end
for i = 1, 40 do FM.WHEEL_BLIZZARD[#FM.WHEEL_BLIZZARD + 1] = "CompactRaidFrame" .. i end
FM.wheelForeign = {}
FM.WHEEL_LATER = 1                                  -- s after a roster change: the second look for late-made frames

-- (BiS Memories' ns.Gamepad: C_GamePad.IsEnabled is on both censuses; C_InputInterfaceStyle on neither)
local function gamepadUI()
    local G = _G.C_GamePad
    if not (G and G.IsEnabled) then return false end
    local ok, on = pcall(G.IsEnabled)
    return ok and on == true
end

local function armable(f)
    if type(f) ~= "table" or not f.SetAttribute or not f.GetAttribute then return false end
    if f.IsForbidden then
        local ok, no = pcall(f.IsForbidden, f)
        if not ok or no then return false end
    end
    return true
end

function FM.WheelOthers(all)
    if InCombatLockdown and InCombatLockdown() then return 0 end
    local want = {}
    local function consider(f)
        if armable(f) and not (FM.wheelCells[f] and not FM.wheelForeign[f]) then want[f] = true end
    end
    if type(ClickCastFrames) == "table" then
        for f, v in pairs(ClickCastFrames) do if v then consider(f) end end
    end
    -- CLIQUE HOLDS THE LIST (15 Nov 2026, Arn's probe over an Ellesmere party frame: "ERFPartyHeaderUnitButton1 nil nil").
    -- With Clique loaded - even unused - ClickCastFrames is an EMPTY stand-in whose writes go to Clique (Clique 5.1
    -- core.lua CaptureGlobalRegistry): pairs() finds nothing and a read answers nil, so every frame EllesmereUI (or VuhDo,
    -- oUF) handed over was invisible here. Clique keeps them on its public addon table: `ccframes` (frame -> true) and
    -- `hccframes` (name -> button, frames that came through a secure header). Read only, never written.
    local C = rawget(_G, "Clique")
    if type(C) == "table" then
        if type(C.ccframes) == "table" then for f, v in pairs(C.ccframes) do if v then consider(f) end end end
        if type(C.hccframes) == "table" then for _, f in pairs(C.hccframes) do consider(f) end end
    end
    if not gamepadUI() then
        for _, name in ipairs(FM.WHEEL_BLIZZARD) do consider(_G[name]) end
    end
    local n = 0
    for f in pairs(want) do
        if all or not FM.wheelForeign[f] then
            FM.wheelForeign[f] = true
            if FM.WheelArm(f, true) then n = n + 1 end
        end
    end
    for f in pairs(FM.wheelForeign) do                  -- taken back out: nothing of ours stays on it
        if not want[f] then
            FM.wheelForeign[f] = nil
            local was = tonumber(f:GetAttribute("bis-wn")) or 0
            for i = 1, was do f:SetAttribute("bis-wk" .. i, nil) f:SetAttribute("bis-wb" .. i, nil) end
            if was > 0 then f:SetAttribute("bis-wn", 0) end
        end
    end
    return n
end

function FM.ApplyWheel(owner)
    if InCombatLockdown and InCombatLockdown() then return false end
    owner = owner or (NS.FG and NS.FG.anchor) or UIParent
    if ClearOverrideBindings then pcall(ClearOverrideBindings, owner) end
    FM.wheelMap = {}
    if NS.PH and NS.PH.Arm then NS.PH.Arm() end     -- the pad's list of cells, written with every layout (PadHeal.lua)
    if FM.CliqueOn() then                          -- Clique owns the wheel too: let it go
        for cell in pairs(FM.wheelCells) do FM.WheelArm(cell, FM.wheelForeign[cell]) end
        return true, 0
    end
    local everywhere = FM.WheelWhere() == "everywhere"
    local n = 0
    for _, slot in ipairs(FM.SLOTS) do
        if slot.bind then
            for _, m in ipairs(FM.MODS) do
                local heal = FM.Get(m.key, slot.key)
                local harm = FM.Get(FM.HARM .. m.key, slot.key)
                local spell = heal or harm
                local name = "BiSHealWheel" .. m.key:gsub("%-", "") .. slot.key
                local b = wheelButtons[name]
                if spell and not b then
                    b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
                    b:RegisterForClicks("AnyDown")
                    wheelButtons[name] = b
                end
                if b then
                    -- A PING ON THE WHEEL (1 Oct 2026). Arn: "the ping system we build does not
                    -- work with mouse wheel up or down". It could not: the wheel is not a click,
                    -- so it never goes through ApplyTo where ping binds are turned into /ping -
                    -- it comes here instead, and arrived as `/cast !ping:assist`, which casts
                    -- nothing. The wheel is where his heals live, so it is where a ping belongs.
                    --
                    -- The guard is narrower than the cast one: a ping may go at anything you can
                    -- see, friend or enemy, so only "nothing under the cursor" stops it. `nohelp`
                    -- would make Attack pings impossible on the one bind that matters most.
                    --
                    -- THE WHEEL HAS NO UNIT TO SWITCH ON (8 Nov 2026, hostile binds), so its one macro asks: a
                    -- hostile SPELL goes first, for an enemy under the cursor, and stops there; anything else falls
                    -- through to the heal side. A macro cannot ride inside another macro: a macro on the wheel runs
                    -- alone - the heal side's when it has one (it aims itself), else the hostile side's.
                    local nuke = harm and not FM.PingOf(harm) and not FM.MacroOf(harm) and select(2, FM.Boost(harm)) or nil
                    local cast = heal or (not nuke and harm) or nil      -- what the macro does after the hostile line
                    local front = nuke and ("/cast [@mouseover,harm,nodead] " .. nuke .. (cast and "\n/stopmacro [@mouseover,harm]\n" or "")) or ""
                    local ping = FM.PingOf(cast)
                    local text, macro
                    if FM.MacroOf(cast) then
                        macro = FM.MacroOf(cast)
                    elseif not cast then
                        text = front ~= "" and front or nil
                    elseif ping then
                        text = front .. "/stopmacro [@mouseover,noexists]\n/ping [@mouseover] " .. ping
                    else
                        spell = cast
                        -- [@mouseover] is what makes a wheel turn land on the cell under the
                        -- cursor; the stopmacro keeps it quiet when the cursor is over nothing
                        -- healable. A booster rides between the two: after the guard, so Nature's
                        -- Swiftness is never spent on a wheel turn over nobody.
                        local _, healCast = FM.Boost(spell)
                        text = FM.GuardedHeal(front, spell, m.key, healCast)
                    end
                    b:SetAttribute("type", (text or macro) and "macro" or nil)
                    b:SetAttribute("macrotext", text)
                    b:SetAttribute("macro", macro)
                end
                spell = heal or harm
                if spell then
                    local key = (m.key == "" and "" or m.key:upper():gsub("%-", "-")) .. slot.bind
                    if everywhere then
                        if SetOverrideBindingClick then pcall(SetOverrideBindingClick, owner, true, key, name, "LeftButton") end
                    else
                        FM.wheelMap[#FM.wheelMap + 1] = { key = key, button = name }
                    end
                    n = n + 1
                end
            end
        end
    end
    -- every frame we have wrapped takes the new map (our new frames take it in FM.ApplyTo); the other unit frames too
    for cell in pairs(FM.wheelCells) do FM.WheelArm(cell, FM.wheelForeign[cell]) end
    FM.WheelOthers(true)
    return true, n
end

--- CLICK A DEAD FRIEND, RES THEM (Arn, 20 Oct 2026, from his cousin: "when he clicked the frame of someone that
--- had died, it did not res that person ... if out of combat, you click someone that's dead, it'll cast res no
--- matter what is binded"). The res used to ride only in front of a bound heal (FM.ResLine), so an empty
--- button - which targets - or a ping never carried it. Now, out of combat, a dead player's cell is ALL res:
--- every button, every modifier, your class's own (FM.RES; the options' res switch still turns it off).
--- The res spell for this cell now, or nil: a player, dead (or a ghost), you out of combat and not about to
--- be (FM.fighting: PLAYER_REGEN_DISABLED comes a moment before the lockdown, the last chance to put the binds
--- back).
function FM.ResNow(cell)
    if FM.fighting or (InCombatLockdown and InCombatLockdown()) then return nil end
    -- a PvP team-target cell (Grid.lua): its token is whoever a teammate has targeted, an enemy as often as not and
    -- someone else a second later - the all-res, written once out of combat, has no place on it
    if cell and cell.__pvp then return nil end
    local unit = cell and (cell.unit or (cell.GetAttribute and cell:GetAttribute("unit")))
    if type(unit) ~= "string" or (NS.Secret and NS.Secret(unit)) then return nil end
    local okP, player = pcall(UnitIsPlayer, unit)
    if not (okP and NS.Plain(player) == true) then return nil end
    local okD, dead = pcall(UnitIsDeadOrGhost, unit)
    if not (okD and NS.Plain(dead) == true) then return nil end
    return FM.ResSpell()
end

--- Each paint asks (Grid.lua FG.Paint): has this cell's "all res" changed? Only then are its clicks rewritten.
function FM.ResCheck(cell)
    if not cell or (InCombatLockdown and InCombatLockdown()) or FM.CliqueOn() then return false end
    local want = FM.ResNow(cell) and true or nil
    if want == cell.__res then return false end
    return FM.ApplyTo(cell)
end

-- the fight's edges: binds back on every all-res cell the moment it starts; the cells look again when it ends
FM.resEvents = CreateFrame("Frame")
FM.resEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
FM.resEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(FM.resEvents.RegisterEvent, FM.resEvents, "GROUP_ROSTER_UPDATE")   -- (new unit frames take the wheel's hover)
FM.resEvents:SetScript("OnEvent", function(_, event)
    if event == "GROUP_ROSTER_UPDATE" then
        FM.WheelOthers()                                -- another addon's new frames take the wheel (out of a fight)
        -- and once more a moment later: a group header makes its new button AFTER this event reaches us, and nothing else
        -- would look again until the next fight ended. One look per burst of roster changes (the flag), no event touched.
        if not FM.wheelLater and C_Timer and C_Timer.After then
            FM.wheelLater = true
            C_Timer.After(FM.WHEEL_LATER, function() FM.wheelLater = nil FM.WheelOthers() end)
        end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then FM.WheelOthers() end
    if event == "PLAYER_REGEN_DISABLED" then
        FM.fighting = true
        for _, cell in ipairs(FM.ResCells()) do
            if cell.__res then FM.ApplyTo(cell) end
        end
    else
        FM.fighting = nil
        for _, cell in ipairs(FM.ResCells()) do FM.ResCheck(cell) end
    end
end)
--- Every frame whose clicks can turn into a res: the grid's cells AND the deck's boxes and pets (17 Nov 2026, Arn's cousin:
--- "when he died and was res'd his frames still said dead, and anytime he tried to cast on himself it tried to res him" -
--- the deck's boxes took the all-res while he lay dead, and only the grid's cells were ever given their binds back).
function FM.ResCells()
    local out = {}
    for _, cell in ipairs((NS.FG and NS.FG.frames) or {}) do out[#out + 1] = cell end
    for _, sp in ipairs((NS.RD and NS.RD.spokes) or {}) do
        if sp.heal then out[#out + 1] = sp.heal end
        if sp.pet then out[#out + 1] = sp.pet end
    end
    return out
end

--- THE SEQUENCE WATCH: haste from new gear or a racial, or a new Riptide rank, changes how many heals follow Riptide; the
--- macros are written again (FM.Apply queues it in a fight) only when that number or the reset really moved.
function FM.SeqSig()
    return FM.SeqCount("Chain Heal") .. "/" .. FM.SeqReset()
end
do
    local okW, w = pcall(CreateFrame, "Frame")
    if okW and w then
        pcall(w.RegisterEvent, w, "PLAYER_EQUIPMENT_CHANGED")
        pcall(w.RegisterEvent, w, "SPELLS_CHANGED")
        if w.RegisterUnitEvent then pcall(w.RegisterUnitEvent, w, "UNIT_SPELL_HASTE", "player") end
        w:SetScript("OnEvent", function()
            local sig = FM.SeqSig()
            if FM.seqSig == nil then FM.seqSig = sig return end    -- the first answer: the macros were written with it
            if sig == FM.seqSig then return end
            FM.seqSig = sig
            if FM.Apply then FM.Apply() end
        end)
        FM.seqWatch = w
    end
end

--- Push every bind onto every cell and the wheel. Queued when the fight is on.
function FM.Apply()
    FM.seqSig = FM.SeqSig and FM.SeqSig() or nil
    if InCombatLockdown and InCombatLockdown() then
        FM.pending = true
        return false
    end
    FM.pending = false
    local cells = 0
    for _, cell in ipairs((NS.FG and NS.FG.frames) or {}) do
        if FM.ApplyTo(cell) then cells = cells + 1 end
    end
    -- PvP mode's team-target cells (Grid.lua): the same binds, the hostile half doing the work there
    for _, cell in ipairs((NS.FG and NS.FG.pvpCells) or {}) do
        if FM.ApplyTo(cell) then cells = cells + 1 end
    end
    -- the radar's pips and pets (Radar.lua): your binds are their clicks too
    if NS.RD and NS.RD.ApplyBinds then cells = cells + (NS.RD.ApplyBinds() or 0) end
    FM.ApplyWheel()
    FM.TrinketWatch()                                -- a trinket on a bind: written again when it cools / comes back
    return true, cells
end
