class_name RecruitmentPreview
extends RefCounted
## Pure roster/deck consequence preview; never allocates live UIDs or learns moves.
static func keys_for(caught: BattlePokemon) -> Array[String]:
    var result: Array[String] = []
    result.assign(TacticalContent.skills_for(caught))
    if result.size() == 1: result.append(result[0])
    return result
static func describe(j: TacticalJourney, index: int) -> Dictionary:
    if j.phase != TacticalJourney.CAPTURE or j.pending_captures.is_empty(): return {}
    if index < 0 or index >= (3 if j.party.size() == 3 else 1): return {}
    var caught := j.pending_captures[0]
    var outgoing: BattlePokemon = j.party[index] if j.party.size() == 3 else null
    var removed: Array[Dictionary] = []
    for card: BattleCardInstance in j.deck:
        if outgoing != null and (card.owner_uid == outgoing.uid or card.injury_owner_uid == outgoing.uid):
            removed.append(j.reward_view({"kind":"card","key":card.key,"owner_uid":card.owner_uid,"upgraded":card.upgraded}))
    var added: Array[Dictionary] = []
    for key: String in keys_for(caught):
        var view := TacticalContent.definition(BattleCardInstance.new(0,key,caught.uid))
        view["species_id"] = caught.species_id
        view["owner_name"] = caught.display_name
        added.append(view)
    return {"incoming":caught,"outgoing":outgoing,"added":added,"removed":removed,"before":j.deck.size(),"after":j.deck.size()-removed.size()+added.size(),"returned_item":outgoing.held_item if outgoing != null else ""}
