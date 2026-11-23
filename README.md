# BLACKTHORN OATH

A landscape, Android-first dark-fantasy action runner built with Godot 4.4.1.

## Prototype 0.4.4 — Hero Facing and Boss Identity

This milestone corrects the environmental and cinematic issues found in the previous visual-review screenshots.

- Imports a full-scale 17 MB Gothic cathedral landmark (CC0) as the distant world anchor, downloaded reproducibly by `scripts/download_assets.sh`.
- Rebuilt the foreground as a separate open gatehouse; the solid wall that previously blocked the doorway and hid the Warden has been removed.
- The Bell Warden is now a rigged sword-and-shield sentinel model with an idle animation, shown through the opening gate.
- The player uses a rigged silver knight model with idle, walk and sprint animation clips, plus a separate sword strike overlay.
- Replaced repeated cone silhouettes with a continuous generated mountain ridge mesh and surrounding ground plane.
- Replaced solid tunnel walls with spaced ruined cloister pillars, rare broken lintels and open side views.
- Rebuilt the title screen as a two-column layout so the story card no longer hides the playable knight.
- Added a cool front key light and warm rim light to show the silver plate and purple cape.
- Corrected the knight's forward axis separately for the front-facing intro, title-menu portrait and -Z runner gameplay.
- Changed the title camera to look down the cathedral approach from behind the hero while showing his face.
- Darkened the Bell Warden's imported armor and added crown spikes and emissive eyes.
- Fitted the Bell Warden to a known world height and brought the camera close enough to read its silhouette.
- Moved portal lighting to the camera-facing side of the Warden.
- Tinted the imported cathedral's PBR materials while preserving their texture maps, and increased its landmark scale.
- Added a procedural ash-rock ground shader, dead-tree silhouettes and terrain boulders.
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

Prototype 0.4.4 is an environment and cinematic vertical-slice upgrade, not a finished commercial game. The cathedral uses an external static mesh; the road dressing, gatehouse and Warden still need hand-authored high-quality materials and further art direction. The player model still needs a production rig, polished animations, hit reactions and sound effects. Real-device visual/performance QA remains mandatory before the next release milestone. Headless validation and screenshot capture do not equal mobile gameplay QA.


## Free asset licenses
- **Knight and cathedral models:** see the source notes in `scripts/download_assets.sh`; the included model providers' license terms are recorded there.
- **RPG sound effects:** OpenGameArt, *RPG Sound Pack* by artisticdude, CC0: https://opengameart.org/content/rpg-sound-pack
- **Animation source under evaluation:** Quaternius, *Universal Animation Library 2*, CC0: https://quaternius.com/packs/universalanimationlibrary2.html

- **Footsteps and supplementary impacts:** OpenGameArt, *100 CC0 SFX #2*, CC0: https://opengameart.org/content/100-cc0-sfx-2
