# Pandia Chat

Read [../AGENTS.md](../AGENTS.md) first (workspace rules). This file is Chat-only.

## Purpose

Persist chat FontString / ScrollingMessageFrame / ChatFrame settings that have **no** Esc → Options control and **no** chat-tab right-click control. Optionally save chat history across sessions.

## Skip (stock already covers)

- Font size
- Chat background color / opacity
- Channel colors, class colors, timestamps, and other Esc chat options

## Include

| Area | APIs / knobs |
|------|----------------|
| Font | `SetFont` flags (`OUTLINE` / thin / thick), `SetShadowOffset`, `SetShadowColor`, optional face path, `ChatFontNormal` |
| Fade | `SetFading`, `SetTimeVisible`, `SetFadeDuration` |
| Layout | `SetClampedToScreen` + `SetClampRectInsets(0,0,0,0)` when edge snap is on; `SetInsertMode` |
| History (live) | `SetMaxLines` only when override enabled **and** the value changed (clears the window) |
| History (saved) | Hook `AddMessage`, line-capped ring buffer, LibDeflate compress + `EncodeForPrint` into SV; skip Combat Log |
| Guild gap-fill | `C_Club` guild stream (`RequestMoreMessagesBefore` / `GetMessagesInRange`) for offline gaps |
| Sticky | `ChatTypeInfo[type].sticky` for say/party/raid/instance/guild/officer/whisper/channel |
| Side buttons | Show/Hide `ChatFrameNButtonFrame` and `ChatFrameMenuButton` |

## Key files

- `PandiaChat.toc` — Forever load gate, `PandiaChatDB`, `PandiaChatHistoryDB` (per-character), libs, compartment
- `Libs/LibStub`, `Libs/LibDeflate` — vendored; compress history blobs
- `PandiaChatHistory.lua` — capture, flush/restore, guild backfill
- `PandiaChat.lua` — `ApplyAll`, options canvas
- `Locales.lua` → `PandiaChatLocale`

## Vendored libs

- `Libs/LibDeflate` — **LibDeflate 1.0.2-release**, zlib License (compatible with GPL-3.0-or-later). Keep `LICENSE.txt`. Upstream: https://github.com/SafeteeWoW/LibDeflate. Do not edit for feature work; upgrade by replacing the upstream file and re-checking the license notice.
- `Libs/LibStub` — public domain **LibStub minor 2** (Kaelten et al.). Hand-copied standard stub (upstream fetch failed when vendoring); not a byte-identical git pin. Same API LibDeflate expects. Optional: LibDeflate also runs if LibStub is absent. Prefer replacing with an official `LibStub.lua` when convenient; do not invent API changes.

## Saved history rules

- Default store: `PandiaChatHistoryDB` (per character). Option `historyShared` uses `PandiaChatDB.sharedHistory` instead.
- Never hook / save the combat-log frame.
- In-memory ring buffer while playing; compress on `PLAYER_LOGOUT` (and when trimming/clearing).
- Do **not** write raw deflate bytes into SavedVariables — always `EncodeForPrint`.
- Restore via original `AddMessage` with a restoring flag so hooks do not double-save.
- Guild backfill is guild-only; no Blizzard API for say/party/whisper/zone history.

## Apply rules (live UI)

- Preserve each window’s current font **size** from `GetFont()`; never own size permanently.
- Re-apply on login, `UPDATE_CHAT_WINDOWS`, after `FCF_SetChatWindowFontSize`, and on options edits.
- On load with max-lines already enabled, seed `lastAppliedMaxLines` so login does not clear history.
- Turning clamp-to-edge **off** leaves Blizzard insets alone (do not invent old values).

## Options

- Parent canvas + `Settings.RegisterCanvasLayoutSubcategory` pages: **Display** (font/fade/layout/side buttons), **History** (live max-lines + saved), **Sticky** (two-column type toggles). Parent holds blurb + Reset.
- Register with `C_Timer.After(0, …)` off `ADDON_LOADED`
- Outline / font face / insert mode: `WowStyle1DropdownTemplate` (cycle-button fallback)
- Shadow X/Y: sliders ±5 px; shadow alpha on the color picker only
- Controls use `GameTooltip` tips from `L.TIP_*`
- Compartment → `PandiaChat_OnAddonCompartmentClick` → open **Display** by `GetID()`; block in combat
- No slash commands

## Do not

- Replace Blizzard chat frames or message filters
- Open settings in combat
- Duplicate stock font-size or background opacity UI
- Save Combat Log
- Age-prune history (line cap only)
