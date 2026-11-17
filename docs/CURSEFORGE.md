# CurseForge release

Four separate CurseForge projects (one per addon) so players can install only what they want.

## One-time author setup

1. On [CurseForge authors](https://authors.curseforge.com/), create a project for each addon:
   - **Pandia Chat**
   - **Pandia Nameplates**
   - **Pandia Quest Links**
   - **Pandia Quest Markers**
2. For each project:
   - Game: **World of Warcraft**
   - License: **GNU General Public License v3.0** (matches repo `LICENSE`)
   - Category that fits (Chat, Unit Frames / Nameplates, Quests, etc.)
   - Short description from the addon’s `## Notes:` line; longer overview from `README.md`
3. Copy each project’s numeric **Project ID** (About Project side box).
4. Add to that addon’s `.toc` (next to `## Version:`):

   ```toc
   ## X-Curse-Project-ID: 123456
   ```

5. Create a CurseForge **API token** and store it as the GitHub repo secret `CF_API_TOKEN`.
6. In `.github/workflows/release.yml`, remove `-d` from the packager `args` so tagged builds upload to CurseForge as well as GitHub.

Game flavor for uploads is **Forever** (`-g forever` in the workflow). Interface `16001` must match a Forever game version CurseForge knows.

## Releasing

1. Bump `## Version:` and the matching `CHANGELOG.md` on a PR; merge to `main`.
2. Tag from `main` and push:

   ```bash
   git checkout main
   git pull
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. The **release** workflow packages all four addons and attaches zips to the GitHub Release.
4. Until CF auto-upload is enabled (step 6 above), download each zip from the GitHub Release and upload it on the project’s Files tab. Tag the file for the current Forever game version.

## Local dry-run (optional)

With [BigWigs packager](https://github.com/BigWigsMods/packager) available:

```bash
./release.sh -d -g forever -t PandiaChat
./release.sh -d -g forever -t PandiaNameplates
./release.sh -d -g forever -t PandiaQuestLinks
./release.sh -d -g forever -t PandiaQuestMarkers
```

Zips land under `<Addon>/.release/`. Do not commit `.release/`.

## Screenshots / listing

Upload at least one screenshot per project (options panel and/or in-game effect). Keep the CurseForge summary Forever-only — these addons do not load on retail or classic.
