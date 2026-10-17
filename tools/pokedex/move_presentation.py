def number(row, key):
    return int(row.get(key) or 0)

def presentation(move, meta, stats):
    """Presentation only: these profiles never apply damage/status game rules."""
    mid = int(move["id"])
    target = "self" if number(move, "target_id") in (4, 7, 13) else "opponent"
    ailment = {1: "paralysis", 2: "sleep", 3: "freeze", 4: "burn", 5: "poison", 6: "confusion", 8: "bind", 18: "seed"}.get(number(meta, "meta_ailment_id"), "")
    if mid in (54, 114):
        return {"primary": "mist", "target": "field", "secondary": ""}
    if mid in (100, 18, 46):
        return {"primary": "evade", "target": target, "secondary": ""}
    if mid in (102, 118, 119, 144, 160):
        return {"primary": "transform", "target": "self", "secondary": ""}
    if mid == 50:
        return {"primary": "seal", "target": "opponent", "secondary": ""}
    if mid == 150:
        return {"primary": "splash", "target": "self", "secondary": ""}
    if mid in (113, 115, 112, 110, 111, 151, 164):
        return {"primary": "shield", "target": "self", "secondary": ""}
    if number(meta, "healing") > 0 or mid in (105, 135, 156):
        return {"primary": "heal", "target": "self", "secondary": "sleep" if mid == 156 else ""}
    if number(meta, "drain") > 0:
        return {"primary": "drain", "target": "opponent", "secondary": ""}
    if number(move, "damage_class_id") == 1:
        if ailment:
            primary = ailment
        elif stats:
            primary = "stat_up" if stats[0]["change"] > 0 else "stat_down"
        elif mid in (14, 74, 96, 97, 104, 106, 107, 116, 133, 159):
            primary = "stat_up"
        else:
            primary = "utility"
        return {"primary": primary, "target": target, "secondary": ""}
    primary = "projectile" if number(move, "damage_class_id") == 3 else "impact"
    if mid in (2, 10, 15, 154, 163):
        primary = "slash"
    if mid in (120, 153):
        primary = "explosion"
    if mid in (19, 76, 91, 130, 143):
        primary = "charge"
    return {"primary": primary, "target": target, "secondary": ailment}
