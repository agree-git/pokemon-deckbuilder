extends SceneTree
const TRAINING = preload("res://scripts/tactics/camp_move_training.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1;push_error(message)
func fixture(ids: Array[int] = [133,4,7]) -> TacticalJourney:
    var j := TacticalJourney.new(712,"field_kit",ids,true)
    j.step=1;j.phase=TacticalJourney.MAP
    check(j.enter_next().is_empty(),"Enter a real campaign camp")
    j.gold=300
    return j
func member(id: int,level: int,uid := 37) -> BattlePokemon:
    var p := BattlePokemon.new(TacticalContent.member_definition(id,VisualCatalog.new()),uid)
    p.level=level;TacticalGrowth.initialize(p,true)
    return p
func roundtrip(j: TacticalJourney) -> void:
    var encoded := JourneySnapshot.encode(j)
    var valid := JourneySnapshot.validate(encoded)
    check(valid,"Campaign save including original statistics shape validates")
    if valid: check(JourneySnapshot.encode(JourneySnapshot.restore(encoded))==encoded,"Exact save/RNG roundtrip")
func run() -> void:
    if not OS.get_user_data_dir().begins_with("/tmp/pokemon-camp-auto/"): quit(2);return
    var j := fixture()
    var p := j.party[0]
    var denied: Dictionary
    # Evolution conditions resolve automatically on actual growth, not at camp.
    var sprigatito:=member(906,15)
    TacticalGrowth.award(sprigatito,TacticalGrowth.experience_floor(16,906)-sprigatito.experience)
    check(sprigatito.species_id==907,"Ordinary level evolution still happens automatically at its level")
    var ape:=member(57,40)
    ape.learned_skills.assign(["move_889"])
    check(NationalEvolution.level_target(ape,"day")==979,"External-world evolution has no camp preparation gate")
    TacticalGrowth.award(ape,TacticalGrowth.experience_floor(41,57)-ape.experience)
    check(ape.species_id==979,"Primeape evolves automatically when level-up and required move are present")
    var tyrogue:=member(236,19)
    tyrogue.evolution_choice=106
    TacticalGrowth.award(tyrogue,TacticalGrowth.experience_floor(20,236)-tyrogue.experience)
    check(tyrogue.species_id==237,"Tyrogue automatically uses equal attack/defense, ignoring obsolete manual choice")
    var wurmple:=member(265,6)
    var personality:=SpecialEvolution.personality(wurmple)
    TacticalGrowth.award(wurmple,TacticalGrowth.experience_floor(7,265)-wurmple.experience)
    check(wurmple.species_id==(266 if ((personality>>16)%10)<5 else 268),"Wurmple keeps its existing individual branch")
    var eevee:=member(133,5)
    eevee.friendship=255;eevee.learned_skills.assign(["move_33"]);eevee.evolution_prepared=700
    check(NationalEvolution.level_target(eevee,"day")==196 and NationalEvolution.level_target(eevee,"night")==197,"Old branch flag cannot block automatic day/night friendship evolution")
    eevee.learned_skills.append("move_608")
    check(NationalEvolution.level_target(eevee,"day")==700,"Fairy move automatically prioritizes Sylveon")
    var branches:=[]
    for id in 25:
        var toxel:=member(848,30,id+1)
        var branch:=NationalEvolution.level_target(toxel,"day")
        check(branch in [849,10184] and NationalEvolution.level_target(toxel,"day")==branch,"Toxel's individual branch is automatic and stable")
        if branch not in branches:branches.append(branch)
    check(branches.size()==2,"Both Toxtricity branches remain reachable without selection")
    var rare_seen := []
    for id in 300:
        var dunsparce:=member(206,40,id+1)
        dunsparce.learned_skills.assign(["move_887"])
        var branch:=NationalEvolution.level_target(dunsparce,"day")
        if branch not in rare_seen:rare_seen.append(branch)
    check(rare_seen.size()==2 and 982 in rare_seen and 10255 in rare_seen,"Both common and rare individual branches remain reachable")
    var item:=fixture([133])
    item.inventory["ice_stone"]=1
    check(item.use_item("ice_stone",0).is_empty() and item.party[0].species_id==471 and item.inventory["ice_stone"]==0,"Stone evolution still consumes a material without preparing a branch")
    roundtrip(item)
    denied=JourneySnapshot.encode(j)
    check(not j.prepare_evolution(p.uid,700).is_empty() and not j.choose_evolution(p.uid,106).is_empty() and JourneySnapshot.encode(j)==denied,"Retired selection APIs cannot spend camp actions or mutate saves")
    var ui:=PokedexWorkshop.new();ui.journey=j;root.add_child(ui)
    check(ui.rows.find_children("WorkshopAction","Button",true,false).is_empty() and not ui.rows.find_children("AutomaticEvolution","Label",true,false).is_empty(),"Evolution guide has no branch-selection buttons")
    ui.free()
    print("CAMP_PROGRESSION ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
