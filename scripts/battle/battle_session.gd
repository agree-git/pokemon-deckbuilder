extends Node
const MAX_STARTERS := 3
## Keeps the active expedition alive across menus; the collection persists separately.
var run := RunState.new(2026)
var tactics := TacticalBattle.new(2026)
var journey := TacticalJourney.new(2026)
var profile := PlayerProfile.new()
var has_journey := false
var open_starter_selection := false
var return_scene := "res://scenes/tactical_battle.tscn"
var battle: BattleState:
    get:
        return run.battle

func start_journey(starters: Array[int],run_seed: int) -> String:
    var catalog := VisualCatalog.new()
    var allowed := profile.unlocked_starters(catalog)
    var seen: Array[int] = []
    if starters.is_empty() or starters.size() > MAX_STARTERS: return "스타팅을 1~%d마리 선택하세요." % MAX_STARTERS
    for id: int in starters:
        if id not in allowed or id in seen: return "해금된 포켓몬을 중복 없이 선택하세요."
        seen.append(id)
    journey = TacticalJourney.new(run_seed,"seed_relay",starters)
    has_journey = true
    return ""
