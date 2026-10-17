class_name TrainerCardArt
extends Control
## Original pixel vignettes, drawn on an 84x48 grid at exactly 2x.
@export var card_key := "analysis"
const COLORS := {"analysis":Color("aebedd"),"guard":Color("8ec9dc"),"focus":Color("a2cdb7"),"rally":Color("e7c47c"),"counter":Color("df9e87"),"injury":Color("b9a0af")}
const ICONS := {"weather_rain":"weather_rain","weather_snow":"weather_snow","weather_sun":"weather_sun","weather_sand":"weather_sand","analysis":"analysis","guard":"shield","focus":"draw","rally":"boost","counter":"counter","injury":"injury","redraw":"discard","hold":"draw","retrieve":"discard","relay_plan":"switch","ace_plan":"boost","tool_plan":"draw","status_cash":"fire","potion_card":"heal","boost_card":"boost","smoke_card":"counter","ether_card":"energy","antidote_card":"heal","relay_cover":"switch","ace_order":"boost","status_plan":"poison","shield_strike":"attack","toxic_flask":"poison","shield_cell":"shield","relay_retrieve":"switch","ace_finisher":"attack","status_pulse":"poison","shield_double":"shield",
"relay_formation":"shield","relay_accelerate":"energy","relay_command":"boost","relay_cycle_plan":"draw",
"ace_retrieve":"discard","ace_precision":"attack","ace_reserve":"energy","ace_breathing":"shield",
"status_catalyst":"poison","status_ampoule":"burn","status_analysis":"analysis","status_absorption":"heal",
"shield_lock":"shield","shield_inspect":"analysis","shield_regroup":"draw","shield_fortress":"shield",
"supply_recycle":"exhaust","supply_pack":"heal","supply_dynamo":"energy","supply_assembly":"boost",
"cycle_filter":"discard","cycle_preserve":"draw","cycle_opportunity":"discard","cycle_engine":"energy"}
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _draw() -> void:
    draw_set_transform(Vector2.ZERO,0,Vector2(2,2))
    var concept := str(TacticalContent.CARDS.get(card_key,{}).get("concept",""))
    var accent: Color = COLORS.get(card_key,Color("aebedd"))
    if not concept.is_empty(): accent = Color({"relay":"8dcdb0","ace":"e1a583","status":"bd92cc","shield":"8ec9dc","supply":"e5c280","cycle":"b2bce4"}[concept])
    if TacticalContent.CARDS.get(card_key,{}).get("category","") == "tool": accent = Color("e5c280")
    draw_rect(Rect2(0,0,84,48),accent.darkened(0.82))
    for i in 7:
        draw_rect(Rect2(i*14-6,0,5,48),Color(accent,0.055))
    draw_rect(Rect2(0,37,84,11),accent.darkened(0.72))
    draw_rect(Rect2(0,37,84,1),Color(accent,0.3))
    # Small props give each instruction its own scene, beyond the shared symbol.
    match card_key:
        "analysis":
            draw_rect(Rect2(9,25,29,17),Color("c8bd9d"))
            draw_rect(Rect2(12,28,18,2),Color("758580"))
            draw_rect(Rect2(12,33,23,2),Color("758580"))
            draw_rect(Rect2(19,23,2,18),Color("758580"))
        "guard":
            for i in 4:
                draw_rect(Rect2(8+i*17,31-(i%2)*4,10,12),accent.darkened(0.48))
                draw_rect(Rect2(8+i*17,31-(i%2)*4,10,2),accent.darkened(0.15))
        "focus":
            for i in 3:
                draw_rect(Rect2(9+i*4,25-i*4,25,14),accent.darkened(0.15+i*0.1))
                draw_rect(Rect2(13+i*4,29-i*4,15,1),accent.darkened(0.55))
        "rally":
            draw_rect(Rect2(15,6,2,35),Color("bdc2a4"))
            draw_colored_polygon(PackedVector2Array([Vector2(17,7),Vector2(35,10),Vector2(30,16),Vector2(17,15)]),accent)
            for i in 3: draw_rect(Rect2(54+i*7,35-i*7,4,8+i*7),accent.darkened(0.3))
        "counter":
            draw_rect(Rect2(9,27,25,14),accent.darkened(0.4))
            draw_rect(Rect2(14,22,15,5),accent.darkened(0.1))
            for i in 3: draw_rect(Rect2(60+i*5,8+i*6,9,2),accent.darkened(0.3))
        "relay_retrieve":
            for i in 3:
                draw_rect(Rect2(8+i*5,25-i*4,18,14),accent.darkened(0.25+i*0.1))
            draw_rect(Rect2(60,17,14,3),accent)
            draw_rect(Rect2(65,12,3,14),accent)
        "ace_finisher":
            for i in 3: draw_rect(Rect2(8+i*7,34-i*8,4,8+i*8),Color("e3ae79"))
            draw_rect(Rect2(63,10,10,3),accent)
            draw_rect(Rect2(67,6,3,11),accent)
        "status_pulse":
            for i in 3:
                draw_rect(Rect2(7+i*23,32,16,9),Color("aa80b6"))
                draw_rect(Rect2(12+i*23,26,6,6),Color("d6b6d9"))
        "shield_double":
            for i in 5: draw_rect(Rect2(6+i*15,33-(i%2)*4,12,12),accent.darkened(0.3))
            draw_rect(Rect2(15,12,10,3),accent)
            draw_rect(Rect2(18,9,3,9),accent)
        "injury":
            draw_rect(Rect2(9,22,30,20),accent.darkened(0.2))
            draw_rect(Rect2(17,16,14,7),accent.darkened(0.48))
            draw_rect(Rect2(21,26,5,12),Color("e6d4c2"))
            draw_rect(Rect2(17,30,13,4),Color("e6d4c2"))
    if not concept.is_empty():
        var pattern: int = BuildConceptContent.GROUPS[concept].find(card_key)+1
        for i in 3:
            draw_rect(Rect2(7+i*5,30-i*5,18,10),accent.darkened(0.22+i*0.12))
            draw_rect(Rect2(62+i*4,13+pattern+i*5,7,2),accent.darkened(0.15))
    var icon_at := Vector2(37,6) if card_key in ["analysis","focus","injury"] else Vector2(29,4)
    draw_texture_rect(CombatWidgets.texture(ICONS.get(card_key,BuildConceptContent.ICONS.get(concept,"heal" if card_key.ends_with("_card") else "boost"))),Rect2(icon_at,Vector2(28,28)),false)
    for at: Vector2 in [Vector2(8,10),Vector2(69,24),Vector2(62,8)]:
        draw_rect(Rect2(at,Vector2(2,2)),Color(accent,0.6))
    draw_set_transform(Vector2.ZERO)
