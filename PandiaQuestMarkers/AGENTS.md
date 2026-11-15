# Pandia Quest Markers

Read [../AGENTS.md](../AGENTS.md) first (workspace rules). This file is Quest Markers-only.

## Purpose

Raid-target-style icons on quest-related nameplates; optional detect sound; click-to-mark toast that sets marks via secure `raidtarget` **set** (addons cannot call `SetRaidTarget` on Forever).

## Key files

- `PandiaQuestMarkers.toc` — load `Locales.lua`, then `ToastLogic.lua`, then `QuestLogic.lua`, then `PandiaQuestMarkers.lua`
- `ToastLogic.lua` — pure layout, sticky, and icon-reservation helpers (`PandiaQuestMarkersToastLogic`); no WoW API; covered by `../tests/toast_logic_test.lua`
- `QuestLogic.lua` — pure tooltip work state + hostile/friendly mark decision (`PandiaQuestMarkersQuestLogic`); covered by `../tests/quest_logic_test.lua`
- `PandiaQuestMarkers.lua` — marking, tooltips, toast UI, options
- `Locales.lua` → `PandiaQuestMarkersLocale`

## Quest / tooltip logic

- Related: `C_QuestLog.UnitIsRelatedToActiveQuest`.
- Hostiles: mark only when tooltip shows **incomplete** work (`C_TooltipInfo.GetUnit` + quest line types).
- Secret/missing tooltip → `uncertain`: **hold** existing marks and sound-only detects; do not `ForgetGUID` (that re-arms detect sound).
- Context off (Solo / Group / Raid / PvP checkbox, or the current instance does not match): hide plate icons and the toast. Turning the context back on scans again.
- World objects: `TooltipDataProcessor` post-call, plus `GetWorldCursor` on mouseover and the 0.4s scan. Do not poll the cursor from `OnUpdate`. Wrap handlers in `pcall`.
- No `COMBAT_LOG_EVENT_UNFILTERED` — free icons via dead unit / nameplate removed.

## Toast / combat

- Secure host: `SecureActionButtonTemplate`; mark helper uses `type=raidtarget`, `action=set` (not toggle).
- Pre-sized visual shells; host is **not** parented/anchored in a way that protects shell `SetSize` at create time — but secure buttons are `SetPoint`'d to the shell, so shell `Show`/`Hide` is combat-protected.
- In combat: do not `Show`/`Hide`/`SetAttribute`/`SetPoint` toast chrome; use row **alpha**; apply visibility/layout on `PLAYER_REGEN_ENABLED`.
- Macro: `/target Name` + `/click` mark button; never `/run SetRaidTarget*`.
- One proposed icon per visible name in a pass (`AssignToastIcons` / `ToastLogic.ReservePeek`). Two names must not both display the first free icon before either is stored in `marks`.

## Options

- Row labels take the width of the widest localized string (`GetStringWidth` + padding). Controls sit to the right of that. Do not freeze the label column at 140px.

## Sound

- At most **one** detect ping per GUID (`sounded`); survives icon eviction.
- Evict with `ReleaseIconOnly` (do not full `ForgetGUID`).
- Object detect keeps a short per-name cooldown (loot tooltip flicker).

## Cross-addon

- Overlay `plate.PandiaQuestMark`; Nameplates may nudge combo pips when it is shown.

## Do not

- Call `SetRaidTarget` / `/tm` toggle semantics for auto-mark.
- Register combat-log listeners for deaths.
- Clear marks on `uncertain` tooltip flicker.
- Create/move/show toast frames under `InCombatLockdown()`.
- Put layout or icon-reservation math only in the main file when it belongs in `ToastLogic.lua` (keep `lua tests/toast_logic_test.lua` green).
- Put tooltip work-state or hostile/friendly mark decisions only in the main file when they belong in `QuestLogic.lua` (keep `lua tests/quest_logic_test.lua` green).
- Poll `GetWorldCursor` every frame.
