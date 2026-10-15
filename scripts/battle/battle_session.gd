extends Node
## Keeps expedition state alive while opening the separate art lab.
var run := RunState.new(2026)
var battle: BattleState:
    get:
        return run.battle
