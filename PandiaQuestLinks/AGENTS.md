# Pandia Quest Links

Read [../AGENTS.md](../AGENTS.md) first (workspace rules). This file is Quest Links-only.

## Purpose

Append colored, configurable status text after `|Hquest:…|h` chat links (failed / ready / on quest / completed / none).

## Key files

- `PandiaQuestLinks.toc` — Forever load gate, `PandiaQuestLinksDB`, compartment hook
- `PandiaQuestLinks.lua` — chat filter, options canvas, color picker
- `Locales.lua` → `PandiaQuestLinksLocale`

## Forever / API notes

- Filter via `ChatFrameUtil.AddMessageEventFilter`; return `false, newMsg, …` to rewrite.
- Quest state: `C_QuestLog.IsOnQuest`, `IsFailed`, `IsComplete`, `IsQuestFlaggedCompleted`.
- Link parse must preserve the hyperlink and any trailing `|r` — only append after the link.
- Color UI: `ColorPickerFrame:SetupColorPickerAndShow` with legacy fallback; hex = 6 digits.
- Options rows use `EditBox` (capital E). Default: `none` state is disabled on fresh installs.

## Do not

- Replace or break the quest hyperlink itself.
- Open settings in combat (compartment guard).
- Enable `none` by default in `Defaults()`.
