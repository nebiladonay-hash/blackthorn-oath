# BLACKTHORN OATH

A phone-first, 3D dark-fantasy endless runner prototype built with **Godot 4**.

## Current prototype
- Three-lane forward movement with swipe and on-screen controls.
- Jump, slide, and melee attack inputs.
- Procedurally generated stone track segments.
- Three enemy archetypes: Hollow Guard, Bloodhound, and Executioner.
- Jump-over and slide-under obstacle variants.
- Collectible glowing relics, health, distance, kills, and saved best distance.
- Health, distance, kills, and restart UI.
- Android export preset and GitHub Actions workflows.

## Controls
- Swipe left/right: change lane.
- Swipe up/down: jump/slide.
- On-screen buttons: lane movement, jump, attack.
- Keyboard: A/D or left/right arrows, Space/up arrow to jump, S/down arrow to slide, F to attack.

## Build
Open the repository root in Godot 4.4.x. Install matching Godot export templates and Android SDK/JDK before exporting with the **Android** preset. GitHub Actions includes strict headless validation (script parse/runtime errors fail the job) and a cloud Android debug APK export workflow.

## Status
Early greybox prototype. It has not yet passed an engine runtime test or Android device QA. Character art, animation, audio, persistence, progression, monetization, and production optimization remain future work.
