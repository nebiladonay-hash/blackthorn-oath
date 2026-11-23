# Blackthorn Oath — Unreal Engine Migration Plan

## Decision and preservation rules

- Target engine: **Unreal Engine 5.8 stable**.
- UE 5.9 is still Preview as of 2026-11-23; do not base production migration on a Preview build.
- Target platform: Android, landscape.
- Rendering target: high-quality mobile rendering on capable Android hardware. Start with Mobile Deferred + Vulkan where supported; validate the actual target devices. Keep a forward-rendering fallback only if a supported device requires it.
- This branch is isolated: `unreal-migration`. The Godot `main` branch and the experimental `unity-migration` branch remain untouched.
- This is a port of the existing Blackthorn Oath game, not a reboot. Preserve its core loop, movement, enemy archetypes, hazard rules, relic economy, run statistics, saved progression, cinematic intro, menu/pause/game-over flow and world identity.
- No engine build, editor import, Android package, or device test has been run yet. Do not describe this scaffold as playable or validated.

## Why UE 5.8

Epic announced UE 5.8 as available on 2026-06-23. UE 5.9 is Preview, not the production baseline. Epic's Android requirements documentation identifies UE 5.7+ as necessary for Google Play target SDK 35 support; UE 5.8 meets that baseline. See:
- https://www.unrealengine.com/news/unreal-engine-5-8-is-now-available
- https://dev.epicgames.com/documentation/unreal-engine/android-development-requirements-for-unreal-engine

Current Android setup documented by Epic for UE 5.8:
- Android Studio Koala 2024.1.2 Patch 1
- Android SDK target 35 (minimum compile SDK 34)
- NDK r27c
- Build-tools 35.0.1
- OpenJDK 21
- Android 8+, 64-bit ARM; supported GPU families and Vulkan 1.1 / OpenGL ES 3.2 are listed in Epic's requirements page.

The versioned toolchain must be rechecked immediately before packaging because Google Play and Epic can revise SDK requirements.

## Existing game behavior — parity contract

The Godot implementation is the authoritative reference until each feature is ported and tested.

### Player
- Three lanes, 2.6 m lane spacing; lane indices 0–2.
- Smooth lateral movement toward the selected lane.
- Auto-forward movement accelerates from 12 m/s toward a capped 18.5 m/s.
- Jump, slide, melee strike.
- Three health points; one-second invulnerability after damage.
- Capsule collision shrinks while sliding.
- Existing player asset: silver knight GLB, with idle/walk/sprint animation clips; sword is part of the imported rigged model.
- Keep the current gameplay-facing direction and camera-relative staging correct.

### Combat and obstacles
- Enemy archetypes: Hollow Guard (2 HP), Bloodhound (1 HP, faster attack cadence), Executioner (3 HP, slower attack cadence).
- Enemy attacks use a readable wind-up before damage.
- Melee strike has a 0.58-second cooldown and a short strike window; hit checks are lane- and distance-limited.
- Hazards are single-hit damage volumes; both ground and overhead variants exist. Ground hazards require jumping; overhead hazards require sliding.
- Player death ends the run. Enemies are removed when defeated and increment the kill count.

### Pickups, run and persistence
- Relics rotate and bob; pickup increments both run relic count and persistent relic bank.
- Run distance, kills, relics and best distance are tracked.
- Best distance and relic bank persist locally.
- Track is generated in 32 m segments; segment spawning recycles old segments.
- First two segments provide a safe relic runway; subsequent segments use deterministic seeded patterns of enemies/hazards and relics.
- Keep spawn fairness: avoid unavoidable combinations, preserve a readable reaction window, and guarantee a viable lane.

### Presentation and flow
- Cinematic intro and skip action.
- Title/menu state, idle camera composition, run start, pause/resume, game-over and run-again.
- Landscape mobile touch: swipe left/right changes lane; swipe up jumps; swipe down slides. On-screen controls also include strike and pause.
- HUD shows distance, kills, vitality, relics/reserve and best run.
- Existing dark-fantasy identity: ruined cloister approach, gothic cathedral, open gatehouse, Bell Warden reveal, ashfall, broken stonework, braziers, banners and crimson accents.
- Existing soundtrack is ambient only. Full action SFX, enemy vocalizations, layered footsteps, weapon impacts, UI cues and adaptive music are not yet implemented and must be authored/added; do not assume they already exist.
- The Bell Warden is currently a cinematic landmark/reveal, not a fully implemented boss encounter. A boss fight is a later feature, not existing parity.

## Unreal architecture

Use a hybrid C++ / Blueprint structure:
- C++ for player movement, lane state, combat windows, health, damage, enemy state, hazard collision, pickup/save data, segment spawning and run-state transitions.
- Blueprint child classes for tuning, visual assembly, enemy presentation and level dressing.
- Animation Blueprints / State Machines for locomotion, jump, slide, attack, hit reaction, death and transitions; use montages for attack and reactions.
- UMG for the HUD, title/menu, pause and game-over. Use Common UI only if its complexity is justified; no dashboard/card layout.
- Sequencer for the intro and Bell Warden reveal, with a skippable transition into gameplay.
- Audio Components / MetaSounds / Sound Cues for layered ambience and responsive gameplay audio. Use pooling for frequently repeated one-shots.
- Data Assets / Data Tables for enemy tuning, spawn patterns, relic values and difficulty progression.
- SaveGame for persistent relic bank and best distance.

## Visual and animation direction

The user authorized broad visual replacement using KayKit packages where suitable. The goal is one coherent stylized art direction, not a mixture of unrelated asset styles.
- Audit exact KayKit package contents, formats, rig compatibility and licence before importing. Prefer CC0 packs where available; preserve a licence/source manifest.
- Use KayKit characters/animation sets as the first candidate for player and enemy replacements. Retarget animation only after validating skeleton hierarchy, bind pose, root motion and weapon attachment points.
- Use a consistent modular environment kit for the ruined cloister, gatehouse and cathedral approach. Keep the Bell Warden silhouette visually distinct and larger than standard enemies.
- Retain the original lore/names, gameplay staging and landmark composition even if meshes/materials are replaced.
- Build the environment from reusable modules and instanced props, not hundreds of unique actors.
- Visual targets: authored material response, strong silhouette readability, controlled fog/volumetrics, baked or carefully limited dynamic lighting where appropriate, deliberate color grading and restrained VFX.
- Avoid generic AI UI patterns: no oversized rounded cards, gradient dashboards, decorative glass panels or unnecessary explanatory copy. The interface should feel like a finished dark-fantasy game.

## High-quality Android rendering policy

- Use the mobile renderer, not the desktop renderer, as the shipping baseline.
- Test Mobile Deferred with Vulkan on capable devices; assess actual GPU/device support before locking the setting.
- Do not assume Lumen, desktop Nanite, Virtual Shadow Maps, desktop post-processing or desktop-only materials are available or affordable on Android.
- Prefer carefully authored lighting, reflection captures, selected dynamic lights, baked lighting where appropriate, material instances, LODs, texture streaming and controlled translucency.
- Profile GPU, CPU, memory, shader compilation and thermal behavior on physical devices. A high visual target still needs stable frame pacing.
- Create quality tiers if the eventual supported Android range requires them; this is a shipping safeguard, not the creative target.

## Migration milestones and acceptance gates

1. **Source audit and project foundation**
   - Preserve this behavior map.
   - Create UE 5.8 project/module, Android configuration, input mapping, save-data model and source control layout.
   - Import one existing GLB to validate scale, forward axis, materials and animation data.
   - Gate: project opens in UE 5.8 and the Android toolchain is recognized.

2. **Playable core vertical slice**
   - Player movement, lane transitions, jump, slide, attack, camera, one enemy, both hazard types, relic pickup, HUD, pause/game-over, touch controls and SaveGame.
   - Gate: complete 60–90 second run with no missing core mechanic; verify collision and animation timing.

3. **Gameplay parity**
   - All three enemy archetypes, deterministic segment generation, fair spawn rules, speed progression, kill/relic/distance counters and persistent data.
   - Gate: repeatable tests for each mechanic and save/load.

4. **Art and animation production**
   - KayKit character/environment selection, rig/retarget validation, final player/enemy rigs, hit/death/attack animations, environment modularization, lighting and VFX.
   - Gate: no placeholder procedural humanoids; coherent asset style; readable animation states.

5. **Audio and game feel**
   - Footsteps/armor, jump/land, slide, weapon whoosh/impact, enemy telegraphs/hits/deaths, hazards, relic, UI, ambience and adaptive music layers.
   - Gate: every meaningful action has intentional audiovisual feedback; no repeated sound spam.

6. **Cinematic, UI and polish**
   - Intro and Warden reveal, menu, HUD, pause, game-over, transitions, haptics and accessibility/readability checks.
   - Gate: polished end-to-end flow with no placeholder UI.

7. **Android QA and release**
   - Build AAB, verify target SDK, arm64, page-size compatibility, permissions, signing, startup, save persistence, thermal behavior, frame pacing and crash logs on physical devices.
   - Gate: reproducible release build and documented device test results.

## Known constraints

- This repository currently contains Godot source, not an Unreal project with imported content.
- The existing external GLBs are downloaded by the Godot asset script and are not committed. Their CC0 claims and sources are documented in `assets/models/README.md`; download and verify them separately for Unreal.
- The current development environment has not been confirmed to have Unreal Editor, Android SDK/NDK, a suitable workstation or an Android device attached. Until those are available, repository work can prepare code/config/docs, but cannot honestly claim an Unreal compile, editor validation or packaged APK/AAB.
- Unreal Editor is resource-intensive. UE 5.8 is the stable baseline; do not jump to UE 5.9 Preview for production.
