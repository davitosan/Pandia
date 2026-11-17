# CurseForge release

Four CurseForge projects (one per addon). Project IDs are already in each `.toc` as `X-Curse-Project-ID`:

| Addon | Project ID | CurseForge |
|-------|------------|------------|
| Pandia Chat | 1813505 | [pandia-chat](https://www.curseforge.com/wow/addons/pandia-chat) |
| Pandia Nameplates | 1813508 | [pandia-nameplates](https://www.curseforge.com/wow/addons/pandia-nameplates) |
| Pandia Quest Links | 1813537 | [pandia-quest-links](https://www.curseforge.com/wow/addons/pandia-quest-links) |
| Pandia Quest Markers | 1813544 | [pandia-quest-markers](https://www.curseforge.com/wow/addons/pandia-quest-markers) |

## Remaining setup

1. Create a CurseForge **API token** and store it as the GitHub repo secret `CF_API_TOKEN`.
2. In `.github/workflows/release.yml`, remove `-d` from the packager `args` so tagged builds upload to CurseForge as well as GitHub.

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
