# Unreal project workspace

This folder is the Unreal Engine migration workspace for Blackthorn Oath.

- Engine baseline: Unreal Engine 5.8 stable.
- Platform: Android, landscape.
- Status: C++ gameplay source foundation is in the repository; no Unreal Editor import, C++ compile, Android package or device test has been completed.
- Authoritative behavior reference: the existing Godot project on `main`.
- Migration contract and acceptance gates: [../UNREAL_MIGRATION_PLAN.md](../UNREAL_MIGRATION_PLAN.md).

## Implemented source foundation

- Unreal game module and project descriptor.
- Runner character: three lanes, auto-forward movement, jump, slide, attack trace, health, invulnerability and run reset.
- Enemy actor: Hollow Guard, Bloodhound and Executioner tuning, telegraphed wind-up and damage/death callbacks.
- Hazard actor: single-hit trigger damage.
- Relic actor: overlap pickup, rotation and bobbing, connected to the persistent relic bank.
- Run game mode: title/running/paused/game-over states, speed ramp, distance/kills/relic counters and SaveGame persistence.

These are initial C++ systems intended for Blueprint subclasses and final animation/UI assets. They still need compilation, integration and gameplay testing in Unreal Editor.

## Build environment reality

The current coding environment can edit the repository but does not have Unreal Engine 5.8 installed or an activated Epic build environment. The user does not own a PC. A hosted Unreal build service was investigated: WarpBuild lists Windows runners at $0.016–$0.128 per minute, with only a promotional $10 credit offer; it is not a genuinely free ongoing build solution. Its documented Unreal pipeline also requires a prebuilt engine artifact supplied by the project owner. Therefore no cloud build has been started and no APK/AAB is claimed.

Do not ask the user to install a desktop editor as the default next step. Continue source-level migration and investigate legitimate free cloud/build sponsorship routes, while clearly marking editor-only tasks as unverified.

Open the workspace with Unreal Engine 5.8 when a suitable licensed cloud or desktop runner is available. Do not import this project over the original Godot project or delete the source branch.
