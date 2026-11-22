# BLACKTHORN OATH — Development Checkpoint

**Saved:** 2026-11-22  
**Branch:** `main`  
**Repository:** https://github.com/nebiladonay-hash/blackthorn-oath  
**Checkpoint source revision:** `07c091510eec2b3334535b410568f1359b19b113`

## Current direction

The previous builds were rightly rejected by the developer as looking like a primitive 2000s Java mobile game. The current work is a deliberate move toward a dark-fantasy, cinematic 3D runner with a compelling opening, strong world scale, readable gameplay and an atmosphere that can hold player attention. Do not revert to the earlier flat greybox presentation.

## Current implementation

- Reworked `scripts/main.gd` into an 18-second scripted intro:
  - aerial cathedral reveal;
  - camera approach toward the sealed cathedral;
  - gate-opening sequence;
  - Bell Warden silhouette reveal;
  - close knight reveal and title sequence;
  - skip-intro control.
- Added an original 24-second ambient score at `audio/blackthorn_cinematic_ambience.wav` (procedurally composed for this project; looped in-game).
- Built a large gothic cathedral landmark with twin towers, layered facade, pointed arches, rose window, iron gate panels, statues/sentinels, roofline spires and approach steps.
- Added distant ridge and watchtower silhouettes for environmental depth.
- Expanded modular level dressing: stone shader with procedural noise/grain, corridor walls, pillars, buttresses, hanging animated banners, braziers, flame lights, iron chains, statues, broken columns, altars and rubble.
- Added fog, filmic tone mapping, restrained glow and drifting ash particles.
- Retained the current knight/player controller, enemy types, relic system, runner obstacles, HUD and touch controls.
- Added `tests/capture_intro.gd` and a CI visual-review step intended to capture four frames:
  - `01-cathedral-aerial.png`
  - `02-bell-warden-gate-reveal.png`
  - `03-knight-reveal.png`
  - `04-title-and-start-screen.png`

## Verification at checkpoint revision

- Godot 4.4.1 project import: passed.
- Main-scene headless smoke test: passed.
- Xvfb/software-rendered intro capture: passed.
- Visual-review artifact uploaded by Actions. Artifact ID: `14770342672`. Workflow run: https://github.com/nebiladonay-hash/blackthorn-oath/actions/runs/45063399898
- The visual-review ZIP was retrieved into the current working session at `/mnt/data/BLACKTHORN-OATH-visual-review.zip`.
- These checks confirm the scene loads and produces screenshots. They do **not** certify that the result is artistically good or that mobile performance is acceptable.

## Android build status

A new Android APK for the exact checkpoint revision has **not yet been confirmed**. Do not hand the developer an APK from an older revision as if it contains the current cinematic and environment work. Check the Android workflow run for this exact SHA and retrieve its artifact only after it succeeds.

## Next actions when work resumes

1. Retrieve and inspect all four visual-review screenshots. Judge composition, scale, lighting, clipping, readability and whether the Warden reveal is actually legible. Fix what the images demonstrate; do not assume it looks right because the workflow passed.
2. If a screenshot shows camera, shader, geometry or layout problems, correct those before creating another APK.
3. Download Android artifact ID `14770806028` from run #47, inspect the APK archive and signature, and confirm its package/version metadata matches the checkpoint revision. Rebuild only if the artifact is invalid or mismatched.
4. Inspect the actual APK package and signature; provide a verified link only for the build matching the checkpoint revision.
5. Ask the developer to test on the Android phone and share screenshots/video from the real device.
6. After confirming the visual direction, prioritize authored-quality environment assets, rigged/animated character and enemy models, impact animation, sound effects, boss encounter and a compelling first playable minute.

## Constraints and cautions

- Continue in this repository and on its existing `main` branch. Do not restart or replace the project.
- Phone-first Android target; keep the rendering and particle budget suitable for mid-range Android devices.
- Do not misrepresent procedural geometry as realistic authored 3D art.
- Do not equate a successful headless import, screenshot capture or APK export with a polished game.
- Keep debug APKs distinct from a release-signed Play Store build.
- Resume from source revision `07c091510eec2b3334535b410568f1359b19b113`, inspect the current branch before editing, and preserve existing work.
