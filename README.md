# Pandia

Small, lightweight World of Warcraft: Forever addons.

| Addon | What it does |
|-------|----------------|
| **Pandia Chat** | Chat chrome (outline/shadow/fade/layout/sticky) plus compressed chat history |
| **Pandia Nameplates** | Class-colored nameplate ToT names; Rogue/Druid Blizzard combo pips |
| **Pandia Quest Links** | Localized / customizable quest status after chat quest links |
| **Pandia Quest Markers** | Raid-target icons on quest-related nameplates; click-to-mark toast (optional sound) |

## Install

Copy `PandiaChat`, `PandiaNameplates`, `PandiaQuestLinks`, and/or `PandiaQuestMarkers` into:

`World of Warcraft\_forever_\Interface\AddOns\`

Enable them at character select. Forever only (`## Interface: 16001`, `AllowLoadGameType: forever`).

## Options

Esc → **Options** → **AddOns** → Pandia Chat / Nameplates / Quest Links / Quest Markers.

## Testing

Offline logic (no WoW client):

```bash
lua tests/toast_logic_test.lua
lua tests/quest_logic_test.lua
```

`toast_logic_test.lua` covers toast width, centering, sticky rows, and icon reservation. `quest_logic_test.lua` covers tooltip work state and the hostile vs friendly mark decision.

GitHub Actions job **tests / toast-logic** runs both on pull requests and pushes to `main`. To require it before merge: repo **Settings → Branches → Branch protection** on `main`, enable **Require status checks**, and select **tests / toast-logic**.

## License

[GPL-3.0-or-later](LICENSE)
