# BiS Cues: the build plan (21 Nov 2026)

Arn's picks on the mockups page (https://claude.ai/artifact/SRPu9GtcPkqoErXpt1GtQS), 21 Nov ~15:30:

| Sheet | Pick | What gets built |
|---|---|---|
| 1 Cue card | yes | A card beside the switches panel: LOOK and SOUND pickers, each with a search box, category chips and a list; TRY; BACK TO DEFAULT. The cue ROW: each cue that is on gets a fixed square along the bottom of the health bar, in the order of the cue list. |
| 2 Previews | C | In game: a live copy of a deck box at the top of the card wearing the pick. In the explorer: a sample deck with every cue that is on. |
| 3 Class effects | all | Paladin Light's Vigil -> Holy Shock party burst, priest Prayer of Mending hops + Prayer of Healing pulse, druid Wild Growth bloom. Each a switch, off by default. (The shaman Chain Heal path exists.) |
| 4 Hellfire | A | The 3D fireball, as built. Nothing to do. |
| 5 HTML explorer | yes | A page in the addon folder (offline), export/import string, `/bish import`, `/bish export`. |
| 6 Raid groups | B + switch | A tiny G2 tag on each box, behind its own switch. Plus a sort switch (tanks then groups / by group / by class / by max health, frozen for the fight), a rows/columns switch, and groups as fixed blocks of 5. |
| 7 Overlap | yes | The size tiers and the drop order, a test across widths; the cue order can be re-ordered IN GAME (up/down on the card's order list). |

Every cue: default OFF (its own `cues` table, not the deck's nil-is-on switches). Turned on, it starts as the spell's icon + the voice.

## Who builds what (four branches, merged into `feat/bis-cues`)

- `feat/bis-cues` (Claude, main thread): `Cues.lua` (`NS.CU`) - the registry, the saved settings, the order, the card, the in-game preview, the cue row on deck boxes, `/bish cues`, `/bish import`, `/bish export`.
- `feat/cues-explorer` (helper): `Explorer/BiSCues.html` - the browser explorer, writes and reads the string below.
- `feat/cues-effects` (helper): `Effects.lua` (`NS.FX`) - the three class effects.
- `feat/cues-groups` (helper): the raid-group tag, sort, rows/columns, fixed blocks, and the overlap tiers + their test.

## The saved settings (per character, `db().cues`)

```lua
db().cues = {
  v = 1,
  order = { "hell", "tap", "crit" },        -- the cue row's squares, left to right (keys of CU.LIST)
  on = { hell = true },                     -- nil / false = off (DEFAULT OFF)
  look = { hell = "icon" },                 -- "icon" | "word" | "model:<fileId or displayId>" ; nil = "icon"
  sound = { hell = "voice" },               -- "voice" | "voicename" | "kit:<soundKitId>" | "off" ; nil = "voice"
}
```

## The string (export / import, both sides)

```
BiSCues1:<base64 of gzip of the JSON>     -- the game: C_EncodingUtil.SerializeJSON -> CompressString(.., Enum.CompressionMethod.Gzip) -> EncodeBase64
BiSCues1p:<base64 of the JSON>            -- plain fallback, no compression (always accepted by both sides)
```

The browser uses `CompressionStream("gzip")` / `DecompressionStream("gzip")` and `btoa`/`atob` (standard base64 alphabet, with padding).
Gzip on purpose: it has a header, so neither side can confuse zlib with raw deflate. UNTESTED LIVE: whether this client's
Gzip method exists and matches the browser's; until a probe says yes, the game EXPORTS the plain form and IMPORTS both.

The JSON:

```json
{ "v": 1,
  "order": ["hell", "tap", "crit"],
  "on":    { "hell": true },
  "look":  { "hell": "icon" },
  "sound": { "hell": "voice" },
  "raid":  { "gtag": true, "sort": "tanks", "cols": false } }
```

`raid` is optional (sheet 6's switches). Unknown keys are ignored on import; unknown cue keys are dropped.
`sort` is one of `tanks` | `group` | `class` | `maxhp`.

## The cue list (CU.LIST), first version

| key | name | class | what draws it |
|---|---|---|---|
| hell | Hellfire | warlock in your group | Burn.lua, game draws it |
| tap | Life Tap | warlock in your group | Burn.lua, cast road |
| crit | Revelation | your own proc | Reveal.lua, game draws it |
| rip | Riptide -> Chain Heal | shaman | RD.CueFor (middle word, not a square) |
| oath | Oath of Light -> Holy Light | paladin | middle |
| vigil | Light's Vigil -> Holy Shock | paladin | middle |
| swift | Swiftmend | druid | middle |

The middle cues keep their place (sheet 1, "big cues keep their own place"); the square row is for the small ones.
