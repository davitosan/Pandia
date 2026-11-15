# Pandia

Small, lightweight World of Warcraft: Forever addons.

| Addon | What it does |
|-------|----------------|
| **Pandia Nameplates** | Class-colored nameplate ToT names; Rogue/Druid Blizzard combo pips |
| **Pandia Quest Links** | Localized / customizable quest status after chat quest links |
| **Pandia Quest Markers** | Raid-target icons on quest-related nameplates; click-to-mark toast (optional sound) |

## Install

Copy `PandiaNameplates`, `PandiaQuestLinks`, and/or `PandiaQuestMarkers` into:

`World of Warcraft\_forever_\Interface\AddOns\`

Enable them at character select. Forever only (`## Interface: 16001`, `AllowLoadGameType: forever`).

## Options

Esc → **Options** → **AddOns** → Pandia Nameplates / Quest Links / Quest Markers.

## Testing

Offline toast layout/sticky logic (no WoW client):

```bash
lua tests/toast_logic_test.lua
```

GitHub Actions runs the same command on pull requests and pushes to `main`. To require it before merge: repo **Settings → Branches → Branch protection** on `main`, enable **Require status checks**, and select **tests / toast-logic**.

## License

[GPL-3.0-or-later](LICENSE)
