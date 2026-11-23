# BLACKTHORN OATH — Unity port

This directory is the experimental Unity port. The original Godot project remains at the repository root and on the `main` branch.

- Editor baseline: Unity 6000.3.27f2 (Unity 6.3 LTS).
- Planned renderer: Universal Render Pipeline (URP).
- Target: Android phones, including lower-end devices.
- Rendering policy: scalable quality tiers; stable 30 FPS low-tier baseline, with higher frame rates only where measured performance permits.
- Do not add HDRP, expensive full-screen effects or generic gradient/card UI.
- Do not remove gameplay features while porting.

**This is currently a scaffold, not a playable Unity game.** The Unity Editor is not installed in the connected coding environment, so Editor import, Android export and device performance have not yet been tested. See [the migration plan](../UNITY_MIGRATION_PLAN.md) for stages and acceptance criteria.
