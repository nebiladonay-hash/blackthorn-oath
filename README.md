# BLACKTHORN OATH

## Production engine decision — Godot

Godot 4.x is the authoritative production engine for Blackthorn Oath. Continue development from this existing project on `main`; do not port gameplay to Unreal or Unity and do not replace the current project structure. The experimental Unreal migration branch is not part of the production game.

The existing Godot implementation, scenes, scripts, downloaded asset manifest, cinematic, combat loop, procedural track and Android workflow are the source of truth. All new gameplay work must preserve those systems and improve them incrementally. Use the existing Godot CI workflow for import, headless checks, screenshots and Android builds; never claim a successful build without a completed workflow run.


A landscape, Android-first dark-fantasy action runner built with Godot 4.4.1.

## Prototype 0.5.0 — Gameplay Foundation Fix

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

Prototype 0.5.0 is an environment and cinematic vertical-slice upgrade, not a finished commercial game. The cathedral uses an external static mesh; the road dressing, gatehouse and Warden still need hand-authored high-quality materials and further art direction. The player model still needs a production rig, polished animations, hit reactions and sound effects. Real-device visual/performance QA remains mandatory before the next release milestone. Headless validation and screenshot capture do not equal mobile gameplay QA.


## Free asset licenses
- **Knight and cathedral models:** see the source notes in `scripts/download_assets.sh`; the included model providers' license terms are recorded there.
- **RPG sound effects:** OpenGameArt, *RPG Sound Pack* by artisticdude, CC0: https://opengameart.org/content/rpg-sound-pack
- **Animation source under evaluation:** Quaternius, *Universal Animation Library 2*, CC0: https://quaternius.com/packs/universalanimationlibrary2.html

- **Footsteps and supplementary impacts:** OpenGameArt, *100 CC0 SFX #2*, CC0: https://opengameart.org/content/100-cc0-sfx-2


## 0.5.0 Gameplay Foundation
- Corrected the imported Mixamo sprint clip mapping (`sprint`, not `sprint_loop`) and synchronized its playback rate to runner speed.
- Reused the Warden's `sword_attack` and `sword_block` clips on the Silver Knight; both GLBs share identical Mixamo skeleton track paths.
- Replaced non-physical lane X teleports with physics-based horizontal velocity and added physical enemy hitboxes.
- Replaced placeholder enemies with the rigged T1 Sentinel and idle, attack, hit and death animation states.
- Added runtime spatial SFX playback from two CC0 OpenGameArt sound packs.
- Replaced the launcher emblem with a dark-fantasy cathedral/ember sigil.
- Added automated runner, collision, lane, combat and visual screenshot checks.


## 0.5.1 UI and audio art pass
- The boot splash is a game-specific cathedral scene, not the previous badge. It is rendered from `assets/ui/blackthorn_splash.svg` to the PNG format required by Godot 4.4.
- The square application icon is full-bleed cathedral key art with an eclipse and blackthorn silhouette.
- Cinzel is bundled from Google Fonts under SIL Open Font License 1.1; the full OFL is included in `assets/fonts/OFL-Cinzel.txt`.
- The in-game touch controls are icon-only beveled rune medallions. Lane movement uses the existing swipe controls, so redundant left/right screen buttons are removed.
- CC0 audio sources: Kenney Impact Sounds via 3DValley for stone footsteps and steel impacts; artisticdude's CC0 Swishes Sound Pack on OpenGameArt for blade movement. Relic collection no longer triggers random high-pitched pickup dings.


## 0.5.1 — Premium UI, title art and curated audio
- Replaced the badge-like launcher mark with full-bleed gothic cathedral key art.
- Replaced the default boot presentation with a custom cinematic cathedral splash, compiled to PNG during the CI asset setup because Godot's boot splash setting expects a raster image.
- Rebuilt the in-game interface as a restrained raised-rune control system: icon-only touch medallions for jump, slide, strike, pause and flask; swipe gestures remain the lane controls. The HUD is now a compact top status rail rather than a large block of text.
- Added Cinzel display typography under the SIL Open Font License 1.1; license file is bundled.
- Removed loose filename-based random SFX classification and random pickup chimes. Audio now uses individually downloaded and header-validated CC0 sounds: concrete footsteps, heavy steel impacts, named blade OGGs and creature roars/grunts. Relic collection is intentionally silent; there is no arcade coin ding.
- SFX source licenses: 3DValley's CC0 library, including Kenney Impact Sounds and OpenGameArt rubberduck blade/creature sounds.
