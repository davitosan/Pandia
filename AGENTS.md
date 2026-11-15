# WoW Forever AddOns workspace

This folder is `_forever_\Interface\AddOns` (WoW Forever / toc `16001`, product flavor `wowf`).

Git repo: [davitosan/Pandia](https://github.com/davitosan/Pandia) (`origin`), default branch `main`. `.gitignore` tracks only Pandia addons + docs — third-party AddOns stay untracked.

**Progressive disclosure:** this file is workspace-wide. When editing a specific addon, also read that addon's `AGENTS.md`.

| Addon | Agent notes |
|-------|-------------|
| [PandiaNameplates](PandiaNameplates/) | [PandiaNameplates/AGENTS.md](PandiaNameplates/AGENTS.md) |
| [PandiaQuestLinks](PandiaQuestLinks/) | [PandiaQuestLinks/AGENTS.md](PandiaQuestLinks/AGENTS.md) |
| [PandiaQuestMarkers](PandiaQuestMarkers/) | [PandiaQuestMarkers/AGENTS.md](PandiaQuestMarkers/AGENTS.md) |

## Scope

- Prefer editing **our** addons (table above).
- Treat other addons as third-party (`ForeverLootSparkles`, `Auctionator`, `BugSack`, `!BugGrabber`, Wowhead_*): read/debug OK; avoid drive-by refactors. Updates overwrite local edits.
- Do **not** edit Blizzard_* UI unless explicitly asked.
- Do **not** use third-party addon trees (especially `Auctionator`) as a basis to reimplement or copy their code.

## Forever load gate

Prefer toc lines:

```
## Interface: 16001
## AllowLoadGameType: forever
## ExcludeLoadGameType: standard, classic
```

`ExcludeLoadGameType` is required so clients that do not know `forever` do not load the addon anyway. Prefer that over a bare `Interface` line or relying only on a `_Forever.toc` suffix.

Forever uses the Mainline UI family (not Classic Era).

## Git workflow

Every code/doc change ships through a branch and a pull request — never commit straight to `main`.

1. Start from an up-to-date `main` (`git fetch` + `git checkout main` + `git pull`).
2. Create a focused branch (`fix/…`, `feat/…`, `chore/…`).
3. Make the change; keep the PR to one logical unit when practical.
4. Commit on that branch (clear message; UTF-8 sources only).
5. Push the branch and open a PR targeting `main` (`gh pr create`).
6. Do not merge unless the user asks; do not force-push `main`.

Shell tip: if `git` / `gh` are missing from PATH, use `C:\Program Files\Git\cmd` and GitHub CLI paths.

Unrelated local WIP: leave it unstaged or on its own branch — do not fold it into an unrelated PR.

## Encoding (critical)

- Save all `.lua` / `.toc` as **UTF-8 without BOM** (never UTF-16). UTF-16 causes `unexpected symbol near '-'`.

## Shared Forever pitfalls

- Protected calls (`Show`/`Hide`/`SetParent`, `Settings.OpenToCategory` / `OpenSettingsPanel`) fail or taint in combat — use `InCombatLockdown()` and prefer non-Settings UI when opening options.
- Forever inherits modern combat restrictions (secret values, limited combat-log visibility). Do not assume Classic-era addon APIs or unrestricted combat data.
- `UnitGUID(nil)` errors — always guard unit tokens.
- StaticPopup fields are `EditBox` (capital E), not legacy `editBox`.
- Settings categories need numeric IDs (`category:GetID()`), not display-name strings.
- Install path is `_forever_\Interface\AddOns` only — not `_classic_era_`, `_retail_`, or leftover `_classic_beta_`.

## Shared addon patterns

- Locales: `Locales.lua` → `Pandia*Locale`; `enUS` fallback.
- Options: custom canvas via `Settings.RegisterCanvasLayoutCategory` (avoids Settings control taint); register with `C_Timer.After(0, …)` off `ADDON_LOADED`.
- Addon compartment → `Pandia*_OnAddonCompartmentClick` → open category by `GetID()`; block in combat.
- No slash commands in these addons (options UI only).

## Tests

Offline, no WoW client. CI job **tests / toast-logic** runs both:

- `lua tests/toast_logic_test.lua` — toast width, centering, sticky rows, icon reservation
- `lua tests/quest_logic_test.lua` — tooltip work state and hostile vs friendly mark decision
