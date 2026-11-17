# Pandia Chat

Read [../AGENTS.md](../AGENTS.md) first (workspace rules). This file is Chat-only.

## Purpose

Persist chat FontString / ScrollingMessageFrame / ChatFrame settings that have **no** Esc → Options control and **no** chat-tab right-click control.

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
| History | `SetMaxLines` only when override enabled **and** the value changed (clears the window) |
| Sticky | `ChatTypeInfo[type].sticky` for say/party/raid/instance/guild/officer/whisper/channel |
| Chrome | Show/Hide `ChatFrameNButtonFrame` and `ChatFrameMenuButton` |

## Key files

- `PandiaChat.toc` — Forever load gate, `PandiaChatDB`, compartment hook
- `PandiaChat.lua` — `ApplyAll`, options canvas (scrollable sections)
- `Locales.lua` → `PandiaChatLocale`

## Apply rules

- Preserve each window’s current font **size** from `GetFont()`; never own size permanently.
- Re-apply on login, `UPDATE_CHAT_WINDOWS`, after `FCF_SetChatWindowFontSize`, and on options edits.
- On load with max-lines already enabled, seed `lastAppliedMaxLines` so login does not clear history.
- Turning clamp-to-edge **off** leaves Blizzard insets alone (do not invent old values).

## Options

- Canvas via `Settings.RegisterCanvasLayoutCategory`; register with `C_Timer.After(0, …)` off `ADDON_LOADED`
- Outline / font face / insert mode: `WowStyle1DropdownTemplate` (cycle-button fallback)
- Shadow X/Y: sliders ±5 px; shadow alpha on the color picker only
- Controls use `GameTooltip` tips from `L.TIP_*`
- Compartment → `PandiaChat_OnAddonCompartmentClick` → open by `GetID()`; block in combat
- No slash commands

## Do not

- Replace Blizzard chat frames or message filters
- Open settings in combat
- Duplicate stock font-size or background opacity UI
