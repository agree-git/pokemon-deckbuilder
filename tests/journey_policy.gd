class_name JourneyPolicy
extends RefCounted
static func action(b: TacticalBattle) -> Array:
    return TacticalPolicy.action(b)
