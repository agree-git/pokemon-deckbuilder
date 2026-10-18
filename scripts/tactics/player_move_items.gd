class_name PlayerMoveItems
extends RefCounted
## v17: temporary item operations and Thousand Arrows. All reads are pure.
const PATH:="res://data/player_move_items_v17.json"
const DEFAULT:Dictionary={"base":{},"spent":{},"embargo":{}}
static var _data:Dictionary={}
static func data() -> Dictionary:
    if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    return _data
static func read(b:TacticalBattle) -> Dictionary:return b.item_context if not b.item_context.is_empty() else DEFAULT
static func write(b:TacticalBattle) -> Dictionary:
    if b.item_context.is_empty():b.item_context=DEFAULT.duplicate(true)
    return b.item_context
static func definition(key:String) -> Dictionary:
    var v:=PlayerMoveTraps.definition(key)
    if v.is_empty():return v
    var overlay:Dictionary=data()["moves"].get(str(v["move_id"]),{})
    if not overlay.is_empty():v=overlay.duplicate(true);v["move_id"]=int(v["move_id"])
    v["player_rules"]=9;v["description"]=TacticalContent.description(v)
    return v
static func suppressed(b:TacticalBattle,p:BattlePokemon) -> bool:return int(read(b)["embargo"].get(p.uid,0))>0
static func remember(b:TacticalBattle,p:BattlePokemon) -> void:
    if not read(b)["base"].has(p.uid):write(b)["base"][p.uid]=b.boss_context.get("removed_items",{}).get(p.uid,p.held_item)
static func restore(b:TacticalBattle) -> void:
    for uid:int in read(b)["base"]:
        var p:=PlayerMoveExchange.member(b,uid)
        if p!=null:p.held_item=read(b)["base"][uid]
static func prepare(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> Dictionary:
    if v.get("category")!="technique":return v
    v["player_rules"]=9
    # Attack copies are expanded by the frozen engine before these live rules.
    if not v.has("item_rule") and int(v["move_id"]) in [614,374]:
        var overlay:Dictionary=data()["moves"][str(v["move_id"])];v["item_rule"]=overlay["item_rule"];v["card_notes"].append_array(overlay["card_notes"])
    if v.get("item_rule","") in ["swap","give","embargo","gas"]:
        var proxy:=v.duplicate(true);proxy["pulse_status"]=true
        v["item_blocked"]=PlayerMoveExchange.blocked(b,v) if PlayerMoveCards.flag(int(v["move_id"]),4) else (BossBattleRules.modern(b) and BossBattleEffectsP3.airborne_miss(b,proxy))
        if v["item_blocked"]:v["card_notes"].append("보호/대타/공중 회피가 소지품 대상 효과를 차단")
    return v
static func reason(b:TacticalBattle,p:BattlePokemon,v:Dictionary) -> String:
    var tag:String=v.get("item_rule","");var target:=b.enemy()
    if v.get("category")=="tool" and suppressed(b,p):return "금제 중에는 도구 카드를 사용할 수 없습니다."
    if tag=="swap" and p.held_item.is_empty() and target.held_item.is_empty():return "교환할 소지품이 없습니다."
    if tag=="give" and (p.held_item.is_empty() or not target.held_item.is_empty()):return "기프트패스는 자신의 소지품과 무소지 상대가 필요합니다."
    if tag=="gas" and target.held_item.is_empty():return "제거할 상대 소지품이 없습니다."
    if tag=="recycle" and (not p.held_item.is_empty() or not read(b)["spent"].has(p.uid)):return "리사이클은 무소지 상태에서 이번 전투의 내던지기 소비물만 복구합니다."
    if tag=="fling" and (p.held_item.is_empty() or suppressed(b,p) or PlayerMoveSeals.read(b)["magic"]>0):return "내던지기는 소지품이 필요하며 금제/매직룸 중에는 사용할 수 없습니다."
    return ""
static func affinity(b:TacticalBattle,attack:String,p:BattlePokemon,base:float,id:int) -> float:
    if attack!="ground" or id!=614:return base
    var types:=PlayerMoveCards.effective_types(b,p)
    if "flying" in types and not PlayerMoveAltitude.forced(b,p):return 1.0
    types.erase("flying")
    if b.boss_context.get("spent_electric",{}).get(p.uid,false):types.erase("electric")
    return TypeMatchup.multiplier("ground",types)
static func raw_damage(b:TacticalBattle,p:BattlePokemon,target:BattlePokemon,v:Dictionary,bonus:int) -> int:
    var n:=PlayerMoveItemMath.arrow_base(b,PlayerMoveFields.room_clone(b,p),PlayerMoveFields.room_clone(b,target),v,bonus)
    return maxi(1,floori(n*PlayerMoveAirFields.factor(b,p,target,v))) if n>0 else 0
static func boss_proxy(b:TacticalBattle,v:Dictionary) -> Dictionary:
    if b.player_moves_version<9 or int(v.get("move_id",0))!=614:return v
    var proxy:=v.duplicate(true);proxy["move_id"]=615 # Same flags; frozen aerial whitelist.
    return proxy
static func boss_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon) -> void:
    # Arrow has no other v9 on-card special; preserve its true ID in copy memory.
    var c:=BossBattleRules.write(b);c["acted"][p.uid]=b.turn;c["card_attacker"]=p.uid
    c["last_moves"][p.uid]={"move":614,"target":b.enemy().uid,"turn":b.turn,"attack":true}
    c["mirror"][b.enemy().uid]={"source":p.uid,"move":614}
    if BossBattleEffectsP3.protected(b,v):b._record("cancel","상대의 방어 · 대상 효과 차단")
static func arrow(a:Dictionary) -> bool:
    return int(a.get("copied_view",{}).get("move_id",a.get("effective_move",a.get("move_id",0))))==614
static func enemy_math(b:TacticalBattle,p:BattlePokemon,source:Dictionary) -> Dictionary:
    if not arrow(source) or source.get("asleep",false) or source.get("failed_move",false) or source.get("player_sealed",false):return source
    var a:=source.duplicate(true);var m:=PlayerMoveFields.enemy_move(a,int(a.get("effective_move",a["move_id"]))).duplicate(true)
    if not m.has("move_power"):return source
    m["move_power"]=int(a.get("base_power",m["move_power"]));m["type"]="ground"
    var actor:=PlayerMoveFields.room_clone(b,b.enemy());var target:=PlayerMoveFields.room_clone(b,p)
    var pressure:=1.0 if a.has("boss_moves_version") else (0.55 if a["kind"]=="barrage" else (1.2 if a["kind"]=="charge" else 1.0))
    var n:=PokemonStats.damage(actor,target,m,b.multiplier("ground",p,614),0,pressure,BattleWeather.kind(b.powers))
    n=maxi(1,floori(n*PlayerMoveAirFields.factor(b,actor,target,m))) if n>0 else 0
    a["immune"]=n==0
    if a.has("per_hit"):a["per_hit"]=n
    a["value"]=n*int(a.get("hits",1))
    return a
static func after_card(b:TacticalBattle,v:Dictionary,p:BattlePokemon,target:BattlePokemon) -> void:
    if v.get("preparing",false) or v.get("failed",false):return
    var tag:String=v.get("item_rule","")
    if tag=="fling":
        remember(b,p);write(b)["spent"][p.uid]=p.held_item;p.held_item=""
    elif tag=="recycle":
        remember(b,p);p.held_item=read(b)["spent"][p.uid];write(b)["spent"].erase(p.uid)
    elif not v.get("item_blocked",false) and not v.get("boss_blocked",false) and not v.get("target_effect_blocked",false):
        match tag:
            "arrows":
                if int(v.get("preview_damage",0))>0:PlayerMoveAltitude.land(b,target,true)
            "swap":
                remember(b,p);remember(b,target);var held:=p.held_item;p.held_item=target.held_item;target.held_item=held
            "give":remember(b,p);remember(b,target);target.held_item=p.held_item;p.held_item=""
            "gas":remember(b,target);target.held_item=""
            "embargo":write(b)["embargo"][target.uid]=5
    if not tag.is_empty():b._record("field",str(v["name"])+" · 착지/소지품 규칙 반영")
static func after_enemy(b:TacticalBattle,p:BattlePokemon,a:Dictionary,had_sub:bool) -> void:
    if arrow(a) and not had_sub and not a.get("immune",false) and not a.get("player_guarded",false) and not a.get("player_airborne",false) and not a.get("player_sealed",false) and not a.get("asleep",false) and not a.get("failed_move",false) and a["kind"]!="prepare":PlayerMoveAltitude.land(b,p,true)
    if b.item_context.is_empty():return
    for uid:int in read(b)["embargo"].keys():
        b.item_context["embargo"][uid]-=1
        if b.item_context["embargo"][uid]<=0:b.item_context["embargo"].erase(uid)
static func on_switch(b:TacticalBattle,old:int) -> void:
    if not b.item_context.is_empty():b.item_context["embargo"].erase(old)
static func valid_context(c:Variant,b:Dictionary) -> bool:
    if not c is Dictionary:return false
    if c.is_empty():return true
    if c.size()!=3:return false
    for key:String in DEFAULT:
        if not c.get(key) is Dictionary:return false
        for uid:Variant in c[key]:
            if not uid is int or uid not in b["party"]+b["enemies"]:return false
            var value:Variant=c[key][uid]
            if key=="embargo":
                if not value is int or value<1 or value>5:return false
            elif not value is String or (not value.is_empty() and not TacticalContent.HELD_ITEMS.has(value)) or (key=="spent" and (value.is_empty() or not c["base"].has(uid))):return false
    return true
static func lines(v:Dictionary) -> Array[String]:
    var rows:=PlayerMoveTraps.lines(v)
    if v.has("item_rule"):rows.push_front({"arrows":"공중/부유 관통 · 명중 후 착지","swap":"양쪽 소지품 교환","give":"무소지 상대에 소지품 전달","recycle":"내던지기 소비물 복구","embargo":"5턴 소지품/도구 정지","gas":"상대 소지품 제거","fling":"소지품 소비 · 위력40"}[v["item_rule"]])
    return rows.slice(0,5)
