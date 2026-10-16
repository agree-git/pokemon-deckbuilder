class_name BattleSoundCues
extends RefCounted
## Pure selection of a sound from an already-resolved presentation event.
static func for_event(event: Dictionary) -> String:
    match str(event.get("kind", "")):
        "card": return "card_play"
        "skill":
            var definition := TacticalMoves.definition(TacticalMoves.key_for(int(event.get("move_id", 0))))
            return "attack" if definition.has("damage") else "card_play"
        "enemy_hit": return "attack"
        "enemy_action": return "attack" if event.get("action", "") in ["attack", "charge", "barrage"] else "card_play"
        "damage":
            if int(event.get("amount", 0)) > 0: return "hit"
            return "block" if int(event.get("blocked", 0)) > 0 else ""
        "shield", "heal": return str(event["kind"]) if int(event.get("amount", 0)) > 0 else ""
        "status", "stat", "power", "relic": return "status"
        "knockout": return "knockout"
        "capture": return "capture"
        "turn": return "turn"
    return ""

static func play(node: Node, key: String) -> void:
    if key.is_empty() or not node.is_inside_tree(): return
    var audio := node.get_node_or_null("/root/GameAudio")
    if audio != null: audio.play(key)
