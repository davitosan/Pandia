# CurseForge release

Four CurseForge projects (one per addon). Project IDs are already in each `.toc` as `X-Curse-Project-ID`:

| Addon | Project ID | CurseForge |
|-------|------------|------------|
| Pandia Chat | 1813505 | [pandia-chat](https://www.curseforge.com/wow/addons/pandia-chat) |
| Pandia Nameplates | 1813508 | [pandia-nameplates](https://www.curseforge.com/wow/addons/pandia-nameplates) |
| Pandia Quest Links | 1813537 | [pandia-quest-links](https://www.curseforge.com/wow/addons/pandia-quest-links) |
| Pandia Quest Markers | 1813544 | [pandia-quest-markers](https://www.curseforge.com/wow/addons/pandia-quest-markers) |

## Setup (done)

- Project IDs are in each `.toc` as `X-Curse-Project-ID`.
- GitHub repo secret `CF_API_TOKEN` is set.
- `release.yml` uploads to CurseForge on `v*` tags (`-g forever`).

Interface `16001` must match a Forever game version CurseForge knows.

## Releasing

1. Bump `## Version:` and the matching `CHANGELOG.md` on a PR; merge to `main`.
2. Tag from `main` and push:

   ```bash
   git checkout main
   git pull
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. The **release** workflow packages all four addons, uploads each zip to its CurseForge project, and attaches the same zips to the GitHub Release.

## Local dry-run (optional)

With [BigWigs packager](https://github.com/BigWigsMods/packager) available:

```bash
./release.sh -d -g forever -t PandiaChat
./release.sh -d -g forever -t PandiaNameplates
./release.sh -d -g forever -t PandiaQuestLinks
./release.sh -d -g forever -t PandiaQuestMarkers
```

Zips land under `<Addon>/.release/`. Do not commit `.release/`.

## Project avatars

Use the matching JPG under `docs/curseforge/avatars/` as each project’s logo (CurseForge wants JPG/PNG, not the in-game `.tga`):

| Project | File |
|---------|------|
| Pandia Chat | `docs/curseforge/avatars/pandia-chat.jpg` |
| Pandia Nameplates | `docs/curseforge/avatars/pandia-nameplates.jpg` |
| Pandia Quest Links | `docs/curseforge/avatars/pandia-quest-links.jpg` |
| Pandia Quest Markers | `docs/curseforge/avatars/pandia-quest-markers.jpg` |

Author edit → General → logotype / project image → upload that file.

## Screenshots / listing

Upload at least one screenshot per project (options panel and/or in-game effect). Keep the CurseForge summary Forever-only — these addons do not load on retail or classic.
