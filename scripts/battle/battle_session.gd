extends Node
## Keeps expedition state alive while opening the separate art lab.
var run := RunState.new(2026)
var tactics := TacticalBattle.new(2026)
var return_scene := "res://scenes/tactical_battle.tscn"
var battle: BattleState:
    get:
        return run.battle
