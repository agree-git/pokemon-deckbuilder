# Pre-removal checkpoints

These three save envelopes were generated with the unmodified game at commit
`2deeb44178bb9180d17d1b7a2f0ef1e18ce986be` using Godot 4.7.2. They retain the
original content fingerprint, fixed IV 31 and Tyrogue EV 32 rules. Do not regenerate
them with the current engine scripts.

- `legacy-camp.json`: Lv.19 Tyrogue prepared for Hitmonchan, one HP; fainted
  Wurmple; Feebas with beauty 180 and seven missing HP; original merchant stock.
- `legacy-battle.json`: the same party after entering battle and manually switching
  to Feebas. Turn-start speed history and spent energy must remain unchanged.
- `legacy-capture.json`: a won battle with an unsettled successful capture.

`tests/test_legacy_stats.gd` reads them through the production save API and verifies
HP, branching, identity, RNG, resources, pending capture and idempotent new saves.
