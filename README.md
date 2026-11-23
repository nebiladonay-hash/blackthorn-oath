# BLACKTHORN OATH

A landscape, Android-first dark-fantasy action runner built with Godot 4.4.1.

## Prototype 0.4.1 — The Last Cathedral

This milestone corrects the environmental and cinematic issues found in the previous visual-review screenshots.

- Imports a full-scale 17 MB Gothic cathedral landmark (CC0) as the distant world anchor, downloaded reproducibly by `scripts/download_assets.sh`.
- Rebuilt the foreground as a separate open gatehouse; the solid wall that previously blocked the doorway and hid the Warden has been removed.
- The Bell Warden now stands in the clear portal opening as the gate leaves swing outward, with a restored large silhouette and crown horns.
- Replaced repeated cone silhouettes with a continuous generated mountain ridge mesh and surrounding ground plane.
- Replaced solid tunnel walls with spaced ruined cloister arcades, transverse Gothic ribs and open side views.
- Increased ambient moonlight and neutral stone brightness while reducing heavy fog; the scene should remain dark-fantasy but the architecture must be readable.
- Re-staged the cinematic camera: wide cathedral approach, clear gate/Warden reveal, front-facing hero portrait, then rear gameplay title shot.
- Re-centered the main menu and aligned its title, story copy and controls.
- Retained the original ambient score, ash particles, banners, braziers, player controller, enemies, hazards, relics, HUD and run persistence.

## Controls

- Swipe left/right: change lane.
- Swipe up: jump.
- Swipe down: slide.
- On-screen buttons: move, jump, slide, strike and pause.
- Keyboard (desktop testing): A/D or left/right arrows, Space/up arrow, S/down arrow, F.

## External asset

The distant landmark uses the **Generic gothic cathedral** model from the Innerscene Free Parts Library. It is released under CC0 1.0 / public domain; the original part page lists a 17 MB GLB. Local builds can fetch it with:

```bash
bash scripts/download_assets.sh
```

Source: https://www.innerscene.com/tools/library/3d-parts/generic-gothic-cathedral-89717f0f

The asset is used as a static skyline landmark; the foreground gatehouse, Warden, gameplay road and collisions remain authored in this project.

## Build and validation

Open the repository in Godot 4.4.1 with matching export templates. GitHub Actions downloads the CC0 cathedral model before Godot import, runs strict script import and main-scene smoke checks, captures four cinematic screenshots, and produces an ARM64 Android debug APK.

## Honest status

Prototype 0.4.1 is an environment and cinematic vertical-slice upgrade, not a finished commercial game. The cathedral uses an external static mesh; the road dressing, gatehouse and Warden still need hand-authored high-quality materials and further art direction. The player model still needs a production rig, polished animations, hit reactions and sound effects. Real-device visual/performance QA remains mandatory before the next release milestone. Headless validation and screenshot capture do not equal mobile gameplay QA.
