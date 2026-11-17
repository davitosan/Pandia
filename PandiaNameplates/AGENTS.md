# Pandia Nameplates

Read [../AGENTS.md](../AGENTS.md) first (workspace rules). This file is Nameplates-only.

## Purpose

Class-colored target-of-target names on enemy nameplates (players only; pets / no class stay white); Rogue/Druid combo pips via Blizzard templates.

## Key files

- `PandiaNameplates.toc` — Forever load gate, `PandiaNameplatesDB`, compartment hook
- `PandiaNameplates.lua` — paint loop, options canvas, defaults
- `Locales.lua` → `PandiaNameplatesLocale`

## Forever / API notes

- Nameplates: `C_NamePlate.GetNamePlates()`; only tokens matching `^nameplate`.
- Secret values: guard with `issecretvalue`; do not compare or stringify secret unit/name values for logic — `pcall` + `SetText` for names.
- Combo points: `PlainCP` uses a hidden probe when `GetComboPoints` returns secrets.
- ToT name positions: **no LEFT/RIGHT** (Forever clips past the plate edge). Combo pips may use LEFT/RIGHT.
- Parent overlays to the **nameplate** (not `UIParent`) so they hide with the plate.
- Cast bar: drop overlay level under a visible cast bar; casting APIs / forbidden frames need `pcall`.
- Cross-addon: `MarkShowingOnPlate` nudges LEFT combo pips when `plate.PandiaQuestMark` or a raid-target icon is shown (pairs with Quest Markers).

## Do not

- Parent overlays to `UIParent` or raise strata above unrelated UI.
- Use LEFT/RIGHT for ToT name position.
- Register options synchronously on `ADDON_LOADED`.
