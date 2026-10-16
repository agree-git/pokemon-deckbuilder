extends SceneTree
const Diagnostics = preload("res://tools/campaign_battle_diagnostics.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    var j := TacticalJourney.new(0,"field_kit",[129,349,298],true)
    var before := JourneySnapshot.encode(j)
    var entry := Diagnostics.begin(j)
    check(JourneySnapshot.encode(j) == before,"Beginning diagnostics cannot edit state, card identities, resources or RNG")
    check(entry["fallback_cards"] == 5 and entry["direct_cards"] == 5,"Splash-only starters retain exact Struggle copy counts")
    check(entry["coverage"][0]["attack"]+entry["coverage"][0]["immune"] == entry["direct_cards"],"Coverage includes actual live attack copies")
    var guard := 0
    while j.battle.phase not in [TacticalBattle.WON,TacticalBattle.LOST] and guard < 1000:
        guard += 1
        check(CampaignPolicy.apply(j,CampaignPolicy.action(j)).is_empty(),"Diagnostic fixture progresses with legal actions")
    before = JourneySnapshot.encode(j)
    var result := Diagnostics.finish(j,entry)
    check(JourneySnapshot.encode(j) == before,"Finishing diagnostics cannot settle XP, rewards, state or RNG")
    check(result["outcome"] == "won" and result["turns"] == j.battle.turn,"Capture actual battle outcome and turns")
    check(result["counts"] == j.battle.statistics["counts"] and result["cards"] == j.battle.statistics["cards"],"Diagnostics preserve real counters and card use")
    var before_level: int = result["party_before"][0]["level"]
    check(j.settle().is_empty(),"Real settlement follows the diagnostic snapshot")
    check(result["party_after"][0]["level"] == before_level and j.party[0].level > before_level,"End snapshots precede growth and cannot alias live Pokemon")
    j.party[0].hp = 0
    entry = Diagnostics.begin(j)
    var living_attacks := 0
    for card: BattleCardInstance in j.deck:
        if card.owner_uid != 0 and j.battle.member(card.owner_uid).alive() and TacticalContent.definition(card).has("damage"): living_attacks += 1
    check(entry["direct_cards"] == living_attacks,"Fainted owners cannot inflate available attack counts")
    print("CAMPAIGN_DIAGNOSTICS ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
