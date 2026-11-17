# Pandia Chat

Read [../AGENTS.md](../AGENTS.md) first (workspace rules). This file is Chat-only.

## Purpose

Persist chat text outline and drop shadow. The stock client can do this via FontString APIs but does not expose or save the settings.

## Key files

- `PandiaChat.toc` — Forever load gate, `PandiaChatDB`, compartment hook
- `PandiaChat.lua` — apply fonts, options canvas
- `Locales.lua` → `PandiaChatLocale`

## Font APIs

- Per window: `ChatFrameN:GetFont()` → `SetFont(font, size, flags)` with `""` / `THINOUTLINE` / `OUTLINE` / `THICKOUTLINE`
- Shadow: `SetShadowOffset(x, y)`, `SetShadowColor(r, g, b, a)`
- Edit box: same treatment on `ChatFontNormal` when enabled
- Re-apply on login, `UPDATE_CHAT_WINDOWS`, and after `FCF_SetChatWindowFontSize` (size changes wipe flags)

## Options

- Canvas via `Settings.RegisterCanvasLayoutCategory`; register with `C_Timer.After(0, …)` off `ADDON_LOADED`
- Outline: `WowStyle1DropdownTemplate` (cycle-button fallback)
- Shadow X/Y: sliders clamped to ±5 px
- Shadow alpha lives on the color picker only (no separate alpha field)
- Compartment → `PandiaChat_OnAddonCompartmentClick` → open by `GetID()`; block in combat
- No slash commands

## Do not

- Replace Blizzard chat frames or message filters
- Open settings in combat
- Own font size permanently — preserve the window’s current size from `GetFont`
