# Codex development instructions

## Project

- Build a 2D Pokemon roguelite deck-building game.
- Target Godot **4.7.2**, GDScript, and Windows desktop.
- Read `README.md` and `docs/game-design.md` before implementation.
- The design document contains provisional mechanics and tuning values. Identify any inconsistencies before implementing affected rules.

## Scope

- Implement a playable battle with two allied Pokemon first.
- Include a shared deck, energy, draw/discard, card ownership, switching, enemy intent, and win/loss/restart.
- Do not expand to a map, capture, evolution, shops, or extensive content before this battle works.
- Use simple placeholders so art production does not block gameplay.

## Implementation

- Separate battle state and rules from UI nodes and animations.
- Separate immutable content definitions from mutable Pokemon, card, and run instances.
- Prefer small typed GDScript modules and clear names.
- Keep random outcomes seedable when adding randomness.
- Track source assets and required Godot UID sidecar files; exclude `.godot/` and exported builds.
- Avoid unnecessary plugins and external dependencies.

## Validation and communication

- Check the installed Godot version before running engine checks.
- If the specified version is unavailable, report the actual version and validation limits; do not claim compatibility was verified.
- Validate script parsing and project import with Godot when available.
- Add meaningful rule tests for draw/discard, energy consumption, switching, and battle outcome.
- Inspect UI in an actual running game when possible. Headless checks do not prove visual quality.
- Never claim a test or visual inspection occurred without running it.
- Explain progress concisely in Korean and work in small playable increments.
