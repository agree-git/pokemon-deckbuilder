class_name RemovalPreview
extends RefCounted
## Hypothetical single-instance removal. No live mutation or UID/RNG allocation.
static func describe(j: TacticalJourney, uid: int) -> Dictionary:
    if j.phase != TacticalJourney.REST or j.camp().get("kind","") != "merchant": return {}
    var selected: BattleCardInstance
    for card: BattleCardInstance in j.deck:
        if card.uid == uid: selected = card
    if selected == null: return {}
    var after: Array[BattleCardInstance] = []
    var copies := 0
    for card: BattleCardInstance in j.deck:
        if card.key == selected.key and card.owner_uid == selected.owner_uid and card.upgraded == selected.upgraded: copies += 1
        if card.uid == uid: continue
        var copy := BattleCardInstance.new(card.uid,card.key,card.owner_uid)
        copy.upgraded = card.upgraded
        copy.injury_owner_uid = card.injury_owner_uid
        after.append(copy)
    var view := j.reward_view({"kind":"card","key":selected.key,"owner_uid":selected.owner_uid,"upgraded":selected.upgraded})
    view["uid"] = uid
    return EncounterPreparation.compare(j,after).merged({"uid":uid,"card":view,"copies_before":copies,"copies_after":copies-1,"before":j.deck.size(),"after":after.size(),"price":j.removal_price(),"gold_after":j.gold-j.removal_price(),"reason":j.remove_card_reason(uid),"deck_after":after})
