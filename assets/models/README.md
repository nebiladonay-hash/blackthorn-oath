# External 3D assets

The CI and Android build workflows download these models with `scripts/download_assets.sh`.

| File | Use | Format / scale | License |
|---|---|---|---|
| `generic-gothic-cathedral.glb` | Distant cathedral landmark | GLB, approx. 17 MB | CC0 1.0 |
| `silver-knight.glb` | Main player character | GLB, 1.85 m, idle/walk/sprint | CC0 1.0 |
| `t1-sentinel.glb` | Bell Warden boss character | GLB, sword and shield, idle/walk | CC0 1.0 |

## Sources

- **Generic gothic cathedral** — Innerscene Free Parts Library: https://www.innerscene.com/tools/library/3d-parts/generic-gothic-cathedral-89717f0f
- **Silver Knight** — AutoSprite free 3D models: https://www.autosprite.io/free-3d-models/silver-knight
- **T1 Sentinel** — AutoSprite free 3D models: https://www.autosprite.io/free-3d-models/t1-sentinel

AutoSprite states that its models are CC0, free for commercial use, and need no attribution. The knight is a 7.7 MB rigged GLB with idle, walk and sprint animations. The sentinel is a 23.2 MB sword-and-shield GLB with idle and walk animations.

The cathedral is the static distant landmark. The silver knight is the playable character. The T1 Sentinel is the oversized Warden reveal. Road collisions and the surrounding gatehouse remain authored in the Godot project.

Local builds must run `bash scripts/download_assets.sh` before opening the project. The exact downloaded GLBs are not committed to Git because the CI downloader keeps the repository smaller; the download source and licence are recorded here.
