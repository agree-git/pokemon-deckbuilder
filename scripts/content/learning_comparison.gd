class_name LearningComparison
extends RefCounted
## Hypothetical card copies only. No live mutation, UID allocation, learning or RNG.
static func describe(j: TacticalJourney, slot: int) -> Dictionary:
    var change := j.learning_preview(slot)
    if change.is_empty(): return {}
    var pokemon: BattlePokemon = change["pokemon"]
    var incoming: String = j.pending_learning[0]["key"]
    var after: Array[BattleCardInstance] = []
    var before_views: Array[Dictionary] = []
    var after_views: Array[Dictionary] = []
    for card: BattleCardInstance in j.deck:
        var replaced: bool = card.owner_uid == pokemon.uid and card.key == change["previous"]
        var copy := BattleCardInstance.new(card.uid,incoming if replaced else card.key,card.owner_uid)
        copy.upgraded = card.upgraded
        copy.injury_owner_uid = card.injury_owner_uid
        after.append(copy)
        if replaced:
            before_views.append(_view(j,card))
            after_views.append(_view(j,copy))
    if change["copies"] == 0:
        var copy := BattleCardInstance.new(0,incoming,pokemon.uid)
        after.append(copy)
        after_views.append(_view(j,copy))
    return EncounterPreparation.compare(j,after).merged({"change":change,"before_cards":before_views,"after_cards":after_views,"deck_after":after})
static func _view(j: TacticalJourney, card: BattleCardInstance) -> Dictionary:
    return j.reward_view({"kind":"card","key":card.key,"owner_uid":card.owner_uid,"upgraded":card.upgraded})
