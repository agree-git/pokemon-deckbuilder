class_name BossTactics
extends RefCounted
## Trainer orders share readable mechanics, with authored roles for every roster.
const STYLES := {
    "tempo":{"name":"연타형","cycle":["block","barrage","attack","charge"],"description":"방어 뒤 연타합니다. 예고된 총 피해만큼 보호막을 준비하세요."},
    "bulwark":{"name":"철벽형","cycle":["fortify","attack","charge","block"],"description":"방어를 높입니다. 특수 기술·지속 피해로 우회할 수 있습니다.","stat":"defense"},
    "precision":{"name":"특방형","cycle":["fortify","charge","attack","block"],"description":"특방을 높입니다. 물리 기술·지속 피해로 우회할 수 있습니다.","stat":"special_defense"},
    "sustain":{"name":"회복형","cycle":["block","recover","charge","attack"],"description":"방어 다음에 회복합니다. 회복 전에 집중 공격하거나 그동안 작전을 준비하세요."},
    "scorch":{"name":"화상형","cycle":["status","block","attack","charge"],"description":"화상은 지속 피해와 물리 위력 감소를 줍니다. 치료하거나 특수 기술을 활용하세요.","status":"burn","move_id":52},
    "venom":{"name":"독형","cycle":["status","attack","block","charge"],"description":"독은 대기 중에도 피해를 줍니다. 치료 카드나 빠른 처치로 피해를 줄이세요.","status":"poison","move_id":92},
    "roots":{"name":"씨앗형","cycle":["status","block","charge","attack"],"description":"씨앗은 살아 있는 시전자에게 HP를 돌려줍니다. 치료하거나 시전자를 먼저 쓰러뜨리세요.","status":"seed","move_id":73},
    "focus":{"name":"집중형","cycle":["boost","attack","barrage","block"],"description":"위력을 높인 뒤 공격과 연타를 잇습니다. 강화 턴을 활용하고 장기전을 경계하세요."},
    "assault":{"name":"돌파형","cycle":["block","charge","barrage","attack"],"description":"방어 뒤 강공격과 연타를 잇습니다. 받을 동료와 방어 카드를 남겨두세요."},
}
# role:id avoids conflating Koga/Lance's gym, Elite and champion appearances.
const TRAINERS := {
    "gym:whitney":{"name":"꼭두","plan":"끈질긴 승부","styles":["sustain","tempo","bulwark","assault","sustain","focus"]},
    "gym:blaine":{"name":"강연","plan":"작열 공세","styles":["scorch","assault","tempo","focus","scorch","bulwark"]},
    "gym:misty":{"name":"이슬","plan":"흐름 전환","styles":["sustain","tempo","precision","sustain","focus","sustain"]},
    "gym:erika":{"name":"민화","plan":"씨앗 정원","styles":["roots","sustain","venom","roots","precision","focus"]},
    "gym:lt_surge":{"name":"마티스","plan":"전격 속공","styles":["tempo","precision","focus","tempo","assault","focus"]},
    "gym:pryce":{"name":"류옹","plan":"빙벽 전술","styles":["precision","sustain","bulwark","precision","tempo","focus"]},
    "gym:brawly":{"name":"철구","plan":"격투 연무","styles":["focus","tempo","assault","bulwark","tempo","assault"]},
    "gym:koga":{"name":"독수","plan":"독안개 포위","styles":["venom","precision","tempo","venom","bulwark","focus"]},
    "gym:giovanni":{"name":"비주기","plan":"대지 장벽","styles":["bulwark","assault","focus","bulwark","tempo","assault"]},
    "gym:winona":{"name":"은송","plan":"공중 난무","styles":["tempo","precision","tempo","assault","sustain","focus"]},
    "gym:sabrina":{"name":"초련","plan":"정신 장벽","styles":["precision","focus","sustain","precision","tempo","focus"]},
    "gym:bugsy":{"name":"호일","plan":"벌레 연계","styles":["venom","tempo","precision","tempo","assault","focus"]},
    "gym:roxanne":{"name":"원규","plan":"암석 요새","styles":["bulwark","assault","precision","bulwark","focus","assault"]},
    "gym:morty":{"name":"유빈","plan":"환영 포위","styles":["venom","precision","focus","tempo","venom","focus"]},
    "gym:clair":{"name":"이향","plan":"용의 압박","styles":["bulwark","focus","assault","tempo","precision","assault"]},
    "gym:piers":{"name":"두송","plan":"반격의 리듬","styles":["tempo","focus","venom","assault","precision","tempo"]},
    "gym:jasmine":{"name":"규리","plan":"강철 성벽","styles":["bulwark","precision","bulwark","assault","focus","precision"]},
    "gym:valerie":{"name":"마슈","plan":"요정의 장막","styles":["precision","sustain","focus","tempo","sustain","precision"]},
    "elite:lorelei":{"name":"칸나","plan":"빙해의 지구전","styles":["precision","bulwark","focus","sustain","assault"]},
    "elite:bruno":{"name":"시바","plan":"단련의 연격","styles":["focus","bulwark","assault","tempo","focus"]},
    "elite:agatha":{"name":"국화","plan":"독의 환영","styles":["venom","precision","focus","sustain","venom"]},
    "elite:lance":{"name":"목호","plan":"용의 진군","styles":["focus","assault","precision","tempo","assault"]},
    "elite:will":{"name":"일목","plan":"초능력 포진","styles":["precision","roots","focus","tempo","precision"]},
    "elite:koga":{"name":"독수","plan":"인법 독진","styles":["venom","bulwark","tempo","venom","precision"]},
    "elite:karen":{"name":"카렌","plan":"어둠의 유도","styles":["precision","venom","focus","tempo","assault"]},
    "elite:sidney":{"name":"혁진","plan":"공격의 박자","styles":["tempo","assault","venom","focus","tempo"]},
    "elite:phoebe":{"name":"회연","plan":"영혼의 소모전","styles":["venom","precision","sustain","focus","venom"]},
    "elite:glacia":{"name":"미혜","plan":"냉기의 장벽","styles":["precision","bulwark","sustain","assault","precision"]},
    "elite:drake":{"name":"권수","plan":"노련한 용격","styles":["bulwark","focus","tempo","assault","focus"]},
    "elite:aaron":{"name":"충호","plan":"군집 연계","styles":["venom","tempo","bulwark","focus","assault"]},
    "elite:bertha":{"name":"들국화","plan":"지층의 요새","styles":["bulwark","sustain","assault","precision","bulwark"]},
    "elite:flint":{"name":"대엽","plan":"맹화 연격","styles":["scorch","tempo","assault","focus","scorch"]},
    "elite:lucian":{"name":"오엽","plan":"계산된 장벽","styles":["precision","focus","bulwark","sustain","precision"]},
    "elite:shauntal":{"name":"망초","plan":"환영의 서사","styles":["venom","focus","precision","sustain","assault"]},
    "elite:grimsley":{"name":"블래리","plan":"승부의 연격","styles":["tempo","venom","assault","precision","focus"]},
    "elite:caitlin":{"name":"카틀레야","plan":"고요한 집중","styles":["sustain","precision","focus","bulwark","precision"]},
    "elite:marshal":{"name":"연무","plan":"수련의 돌파","styles":["focus","tempo","bulwark","assault","tempo"]},
    "elite:malva":{"name":"파키라","plan":"불꽃 포위","styles":["scorch","precision","assault","scorch","focus"]},
    "elite:siebold":{"name":"즈미","plan":"유수의 호흡","styles":["sustain","tempo","precision","assault","sustain"]},
    "elite:wikstrom":{"name":"간피","plan":"기사의 방진","styles":["bulwark","precision","assault","focus","bulwark"]},
    "elite:drasna":{"name":"드라세나","plan":"용의 조율","styles":["precision","sustain","focus","tempo","assault"]},
    "elite:hala":{"name":"할라","plan":"호쾌한 연무","styles":["bulwark","focus","tempo","assault","focus"]},
    "elite:olivia":{"name":"라이치","plan":"암석의 반격","styles":["bulwark","assault","precision","tempo","focus"]},
    "elite:acerola":{"name":"아세로라","plan":"장난스런 독무","styles":["venom","sustain","tempo","precision","focus"]},
    "elite:kahili":{"name":"카일리","plan":"공중 정밀전","styles":["tempo","precision","assault","focus","precision"]},
    "elite:rika":{"name":"칠리","plan":"대지의 호흡","styles":["bulwark","sustain","venom","assault","focus"]},
    "elite:poppy":{"name":"뽀삐","plan":"단단한 진격","styles":["bulwark","precision","tempo","assault","bulwark"]},
    "elite:larry":{"name":"청목","plan":"실전의 완급","styles":["sustain","tempo","precision","assault","focus"]},
    "elite:hassel":{"name":"팔자크","plan":"용의 격정","styles":["focus","assault","tempo","precision","assault"]},
    "champion:blue":{"name":"그린","plan":"상성의 포진","styles":["tempo","scorch","precision","roots","bulwark","assault"]},
    "champion:lance":{"name":"목호","plan":"용왕의 공세","styles":["scorch","tempo","bulwark","assault","precision","focus"]},
    "champion:steven":{"name":"성호","plan":"강철의 완성","styles":["bulwark","assault","precision","sustain","tempo","focus"]},
    "champion:wallace":{"name":"윤진","plan":"물결의 순환","styles":["venom","precision","tempo","roots","bulwark","sustain"]},
    "champion:cynthia":{"name":"난천","plan":"빈틈없는 포진","styles":["venom","sustain","precision","bulwark","focus","sustain"]},
    "champion:alder":{"name":"노간주","plan":"노련한 연계","styles":["scorch","roots","tempo","assault","bulwark","focus"]},
    "champion:iris":{"name":"아이리스","plan":"용의 격류","styles":["focus","precision","bulwark","assault","sustain","assault"]},
    "champion:diantha":{"name":"카르네","plan":"화려한 장막","styles":["scorch","precision","sustain","tempo","focus","precision"]},
    "champion:leon":{"name":"단델","plan":"왕자의 압박","styles":["scorch","assault","venom","sustain","bulwark","focus"]},
    "champion:geeta":{"name":"테사","plan":"치밀한 포석","styles":["roots","precision","venom","bulwark","assault","focus"]},
    "champion:nemona":{"name":"네모","plan":"승부의 열기","styles":["tempo","precision","assault","venom","bulwark","focus"]},
}
static var _trainers: Dictionary = {}
static func trainers() -> Dictionary:
    if _trainers.is_empty():
        _trainers = TRAINERS.duplicate(true)
        _trainers.merge(BossExpansion.data()["tactics"],true)
        for leader: Dictionary in GymLeaders.all():
            _trainers["gym:"+leader["leader_id"]] = {"name":leader["leader"],"plan":leader["plan"],"styles":leader["styles"].duplicate()}
    return _trainers
static func build(boss: String, slot: int, species: int, level: int, types: Array,modern := false) -> Dictionary:
    var commands := trainers()
    if not commands.has(boss): return {}
    var style: String = commands[boss]["styles"][slot]
    var selected := EnemyTactics.moves(species,level,types,modern)
    var pattern: Array = []
    for kind: String in STYLES[style]["cycle"]:
        var action := {"kind":kind,"value":6,"move_id":115}
        match kind:
            "attack","charge","barrage":
                var id: int = selected["heavy"] if kind == "charge" else (selected["coverage"] if kind == "barrage" else selected["normal"])
                action.merge({"value":40,"move_id":id,"type":TacticalMoves.definition(TacticalMoves.key_for(id))["type"]},true)
                if kind == "barrage": action["hits"] = 2
            "fortify": action["stat"] = STYLES[style]["stat"]
            "recover": action["move_id"] = 105
            "boost": action.merge({"value":2,"move_id":74},true)
            "status": action.merge({"value":2,"move_id":STYLES[style]["move_id"],"status":STYLES[style]["status"]},true)
        pattern.append(action)
    return {"boss":boss,"boss_style":style,"intents":pattern}
static func title(style: String) -> String:
    return str(STYLES.get(style,{"name":"기본형"})["name"])
static func heading(definition: Dictionary) -> String:
    var trainer: Dictionary = trainers().get(definition.get("boss",""),{})
    return "%s · %s" % [trainer["name"],trainer["plan"]] if not trainer.is_empty() else ""
static func valid(definition: Dictionary) -> bool:
    if not definition.get("boss") is String or not trainers().has(definition["boss"]): return false
    if not definition.get("boss_style") is String or definition["boss_style"] not in trainers()[definition["boss"]]["styles"]: return false
    return STYLES.has(definition["boss_style"])
