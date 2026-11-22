# BLACKTHORN OATH

A landscape, Android-first dark-fantasy action runner prototype made with Godot 4.4.1.

## Prototype 0.2.0

This build replaces the earlier greybox presentation with a more deliberate first-playable scene:

- Title screen with an **ENTER THE RUINS** start action.
- Third-person follow camera and an armored knight built from layered 3D meshes.
- Sword held at the right hand, swing animation, and alternating run-cycle limbs.
- Ruined stone gate, lane seams, torch embers, pillars, and rubble.
- Three enemy silhouettes: Hollow Guard, Bloodhound, and Executioner.
- Three-lane running, swipe controls, jump, crouch-slide, and melee attack.
- Ground spike traps, overhead barriers, and collectible relics.
- Health, distance, kill count, pause/resume, end-of-run summary, best-distance and relic persistence.

## Controls

- Swipe left/right: change lane.
- Swipe up: jump.
- Swipe down: slide.
- On-screen buttons: lane movement, jump, slide, attack, pause.
- Keyboard (desktop testing): A/D or left/right arrows, Space/up arrow, S/down arrow, F.

## Build and test

Open this repository in Godot 4.4.1 or the matching release. Install the matching export templates and Android SDK/JDK, then use the **Android** export preset.

GitHub Actions runs strict headless import/runtime checks and produces an ARM64 debug APK. The debug signing key is cached across CI runs so subsequent development builds can update the prior development install. The first build signed by this new key may require uninstalling an earlier APK once.

## Honest status

This is a more complete greybox vertical slice, not a finished commercial game. The knight, enemies, gate and environment are procedural mesh models rather than authored high-detail art assets. It still needs physical-device playtesting, balancing, improved animations, audio, varied level set pieces, a real boss encounter, settings/accessibility, release signing, privacy and store preparation. A successful headless check confirms the project runs in Godot; it does not replace visual QA on an Android phone.
