# Pandia

Small, lightweight World of Warcraft: Forever addons.

| Addon | What it does | CurseForge |
|-------|----------------|------------|
| **Pandia Chat** | Chat chrome (outline/shadow/fade/layout/sticky) plus compressed chat history | [pandia-chat](https://www.curseforge.com/wow/addons/pandia-chat) |
| **Pandia Nameplates** | Class-colored nameplate ToT names; Rogue/Druid Blizzard combo pips | [pandia-nameplates](https://www.curseforge.com/wow/addons/pandia-nameplates) |
| **Pandia Quest Links** | Localized / customizable quest status after chat quest links | [pandia-quest-links](https://www.curseforge.com/wow/addons/pandia-quest-links) |
| **Pandia Quest Markers** | Raid-target icons on quest-related nameplates; click-to-mark toast (optional sound) | [pandia-quest-markers](https://www.curseforge.com/wow/addons/pandia-quest-markers) |

## Install

**CurseForge / WowUp:** install each Pandia addon you want (Forever client). Links are in the table above.

**Manual:** copy `PandiaChat`, `PandiaNameplates`, `PandiaQuestLinks`, and/or `PandiaQuestMarkers` into:

`World of Warcraft\_forever_\Interface\AddOns\`

Enable them at character select. Forever only (`## Interface: 16001`, `AllowLoadGameType: forever`).

Author release checklist: [docs/CURSEFORGE.md](docs/CURSEFORGE.md).

## Options

Esc → **Options** → **AddOns** → Pandia Chat / Nameplates / Quest Links / Quest Markers.

Each addon can also open options from its minimap button or the Blizzard Addon Compartment (both optional in that addon's options).

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
