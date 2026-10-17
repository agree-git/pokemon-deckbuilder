# Codex development instructions

## Repository layout after cleanup

- User request: keep only the runnable game, essential credits/licenses and a short usage README on `main`. Keep development material on `development-materials`; do not create additional persistent remote branches.
- This branch retains the pre-cleanup project for reference. Implement runtime changes against current `main`, and keep documents, tests, tooling and review artifacts here. Main no longer contains legacy battle preview/art lab; older tests may require their archived code.
- Read the latest `main` README and this branch HANDOFF before continuing. Preserve both remote branches; never reintroduce the deleted review branch names in new links.


## Project

- Build a 2D Pokemon roguelite deck-building game.
- Target Godot **4.7.2**, GDScript, and Windows desktop.
- Read `README.md` and `docs/game-design.md` before implementation.
- The design document contains provisional mechanics and tuning values. Identify any inconsistencies before implementing affected rules.

## Continue work across chats

- At the start of every new or resumed task, read `HANDOFF.md`, then `docs/progress.md`. Check `git status --short` and recent commits before choosing work; never assume a previous chat's uncommitted changes are absent.
- Treat `HANDOFF.md` as the current project handoff, not a transcript. Follow the latest user request first, then the confirmed rules and next steps recorded there. Read the linked rule documents before changing affected systems.
- Update `HANDOFF.md` whenever a meaningful milestone completes, work is interrupted, or the turn ends. Record completed work, unfinished files/steps, actual validation outcomes, blockers and the concrete next task. Keep pending work distinct from completed work.
- Keep `docs/progress.md` for the broader implementation/validation history. Avoid copying that entire history into the handoff; remove stale pending items as they complete.
- Never store credentials, private environment identifiers, user saves or secrets in the handoff. Keep cloud-specific setup commands clearly distinguished from general project instructions.

## Scope

- The original first-battle milestone is complete. The current game starts at the main menu and supports the full 69-battle campaign, camps, capture, evolution, shops and autosave. Do not treat these implemented systems as future work.
- Preserve the confirmed scope: Generation 1-3 ordinary originals plus Generation 1-9 rare species/regional birds (see docs/rare-gen9.md), up to three starters, eight biome badges followed by the league, and the unified technique/tool/trainer deck. Consult `HANDOFF.md` and current rule documents for details.
- Continue in small playable increments. Prioritize the user's requested work and the recorded remaining work; do not silently add ordinary Generation 4+ species, restore break/fixed-skill combat, or replace the native 1920x1080 UI with a low-resolution viewport.

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
- The user reviews on mobile: publish requested review galleries, ZIPs and CSVs to GitHub and provide HTTPS links, not only workspace paths. Keep large review artifacts on a separate review branch. The consolidated `review/background/` directory on `development-materials` contains the aligned background review.
