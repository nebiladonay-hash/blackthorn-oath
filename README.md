# BLACKTHORN OATH

A landscape, Android-first dark-fantasy action runner built with Godot 4.4.1.

## Prototype 0.3.0 — The Cathedral Prologue

This milestone is focused on world scale, atmosphere and a more compelling opening:

- An 18-second scripted cinematic opening: aerial cathedral reveal, approach to the sealed gate, knight reveal, and hero-follow shot.
- Original 24-second ambient score, composed specifically for the game and looped in the opening and run.
- Monumental gothic cathedral facade with twin towers, pointed arches, rose window, stained-glass panes, iron doors, sentinels, roofline spires and broad approach steps.
- Layered distant ridges and watchtowers to establish depth beyond the road.
- Procedural PBR-style stone shader with noise, grain and weathering variation.
- Modular fortress walls, buttresses, cornices, hanging animated banners, braziers, torch lighting, iron chains, broken columns, altars and rubble.
- Continuous ash particles, fog, filmic tone mapping and restrained glow.
- A short safe introduction before the first enemy patterns appear.
- The previous knight, sword, enemy archetypes, relics, mobile controls, HUD, pause and run-summary systems remain.

## Controls

- Swipe left/right: change lane.
- Swipe up: jump.
- Swipe down: slide.
- On-screen buttons: move, jump, slide, strike and pause.
- Keyboard (desktop testing): A/D or left/right arrows, Space/up arrow, S/down arrow, F.

## Asset and audio notes

The ambient score in `audio/blackthorn_cinematic_ambience.wav` is an original procedural composition created for BLACKTHORN OATH. The environment geometry and materials in this milestone are generated within Godot; no external marketplace asset is required to build the scene.

## Build and validation

Open the repository in Godot 4.4.1 with matching export templates. Android export uses the repository's Android preset and the cloud build workflow. GitHub Actions performs Godot project import, checks for script parse/runtime errors, runs a main-scene smoke test, and builds an ARM64 debug APK.

## Honest status

Prototype 0.3.0 is a more atmospheric, cinematic vertical slice, not a finished commercial game. The environment is still procedural rather than a photogrammetry-based or artist-authored asset set. The character and enemies still need high-quality rigged models, hand-authored animation, hit reactions and polish. It still needs physical-device visual/performance QA, a real boss encounter, additional level chapters, settings, accessibility, release signing, privacy and store preparation. A successful CI check confirms Godot can import and launch the scene; it does not replace testing on an Android phone.
