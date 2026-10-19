extends SceneTree
const L = preload("res://scripts/persistence/save_location.gd")
const OUT := "/tmp/pokemon-docs-savepath"
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1;push_error(message)
func put(path: String,text: String) -> void:
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var file := FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()
func hashes(folder: String) -> Dictionary:
    var result := {}
    for group: Array in L.GROUPS:
        for name: String in group:
            if FileAccess.file_exists(folder.path_join(name)): result[name]=FileAccess.get_sha256(folder.path_join(name))
    return result
func prepare_fixture(folder: String) -> TacticalJourney:
    var j := TacticalJourney.new(71726,"field_kit",[1,4,7],true)
    var store := JourneySave.new(folder.path_join("journey.json"))
    check(store.save(j).is_empty() and store.save(j).is_empty(),"Create real save/head/backup fixture")
    var profile := PlayerProfile.new(folder.path_join("collection.json"))
    profile.captured_ids.assign([1,4,7,25])
    check(profile.save().is_empty() and profile.save().is_empty(),"Create collection/main backup fixture")
    var cfg := ConfigFile.new()
    cfg.set_value("presentation","battle_speed",2.0)
    cfg.set_value("audio","music",.22)
    cfg.set_value("tutorial","status","completed")
    check(cfg.save(folder.path_join("settings.cfg"))==OK,"Create preferences fixture")
    return j
func run() -> void:
    if not OS.get_user_data_dir().begins_with(OUT): quit(2);return
    check(OS.get_user_data_dir()==OS.get_data_dir().path_join("PokemonExpedition"),"Custom directory resolves without Godot/app_userdata")
    if "--verify" in OS.get_cmdline_user_args():
        var session := root.get_node("BattleSession")
        var expected: Dictionary=FileAccess.open(OUT+"/expected.bin",FileAccess.READ).get_var()
        check(root.get_node("SaveLocation").last_error.is_empty(),"Bootstrap migration completes")
        check(session.has_journey and JourneySnapshot.encode(session.journey)==expected,"First process load restores exact expedition/RNG")
        check(session.profile.captured_ids==[1,4,7,25],"Collection migrated before profile loads")
        check(root.get_node("Preferences").battle_speed==2.0 and is_equal_approx(root.get_node("Preferences").music_volume,.22),"Preferences migrated before loading")
        check(root.get_node("Preferences").tutorial_status=="completed","Tutorial preference preserved")
        print("SAVE_LOCATION_CHILD ",checks," checks / ",failures," failures")
        quit(0 if failures==0 else 1);return
    var source := OUT+"/source"
    var destination := OUT+"/destination"
    var j := prepare_fixture(source)
    var original := hashes(source)
    check(L.migrate(source,destination).is_empty(),"Migrate full real save set")
    check(hashes(destination)==original and hashes(source)==original,"Exact bytes copied; legacy original retained")
    check(JourneySnapshot.encode(JourneySave.new(destination+"/journey.json").load_journey())==JourneySnapshot.encode(j),"Migrated save/RNG restore exactly")
    j.gold += 42
    check(JourneySave.new(destination+"/journey.json").save(j).is_empty(),"New destination progress saves")
    var progressed := hashes(destination)
    check(L.migrate(source,destination).is_empty() and hashes(destination)==progressed,"Completed import never overwrites newer progress")
    var conflict := OUT+"/conflict"
    put(conflict+"/journey.json.head","existing new run")
    check(L.migrate(source,conflict).is_empty(),"Existing destination group is respected")
    check(not FileAccess.file_exists(conflict+"/journey.json") and not FileAccess.file_exists(conflict+"/journey.json.bak"),"A new head is never mixed with an old run/backup")
    check(FileAccess.get_file_as_string(conflict+"/journey.json.head")=="existing new run" and FileAccess.file_exists(conflict+"/collection.json"),"Existing data retained while missing independent collection imports")
    var terminal := OUT+"/terminal"
    j.phase=TacticalJourney.CLEARED
    check(JourneySave.new(terminal+"/journey.json").save(j).is_empty(),"Create terminal marker")
    DirAccess.copy_absolute(source+"/journey.json.bak",terminal+"/journey.json.bak")
    put(terminal+"/journey.json","corrupt main")
    check(L.migrate(terminal,OUT+"/terminal-copy").is_empty(),"Terminal main/head/backup migrate together")
    check(JourneySave.new(OUT+"/terminal-copy/journey.json").load_journey()==null,"Finished run never revives from copied backup")
    var interrupted := OUT+"/interrupted"
    var stage := interrupted.path_join(L.STAGE)
    var plan := {}
    for name: String in ["journey.json.head","journey.json","settings.cfg"]:
        DirAccess.make_dir_recursive_absolute(stage)
        DirAccess.copy_absolute(source.path_join(name),stage.path_join(name))
        plan[name]=FileAccess.get_sha256(stage.path_join(name))
    put(stage+"/plan.json",JSON.stringify(plan))
    DirAccess.copy_absolute(stage+"/journey.json.head",interrupted+"/journey.json.head")
    check(L.migrate(OUT+"/absent",interrupted).is_empty(),"Interrupted import resumes from staged transaction")
    check(JourneySave.new(interrupted+"/journey.json").load_journey()!=null,"Resumed save is usable")
    var corrupt := OUT+"/corrupt"
    put(corrupt.path_join(L.STAGE)+"/settings.cfg","bad staged data")
    put(corrupt.path_join(L.STAGE)+"/plan.json",JSON.stringify({"settings.cfg":"wrong hash"}))
    check(not L.migrate(source,corrupt).is_empty() and not FileAccess.file_exists(corrupt+"/settings.cfg"),"Damaged stage is rejected before installing data")
    var absent := OUT+"/empty"
    check(L.migrate(OUT+"/absent",absent).is_empty() and hashes(absent).is_empty(),"Fresh installation handles missing legacy data")
    var legacy := L.legacy_directory()
    var integration := prepare_fixture(legacy)
    var legacy_before := hashes(legacy)
    FileAccess.open(OUT+"/expected.bin",FileAccess.WRITE).store_var(JourneySnapshot.encode(integration))
    DirAccess.remove_absolute(OS.get_user_data_dir().path_join(L.DONE))
    var output: Array = []
    var exit_code := OS.execute(OS.get_executable_path(),["--headless","--audio-driver","Dummy","--path",ProjectSettings.globalize_path("res://"),"--script","res://.dev-materials/tests/test_save_location.gd","--","--verify"],output,true)
    for line: String in output: print(line)
    check(exit_code==0,"Separate first-launch process loads migrated data in autoload order")
    check(hashes(legacy)==legacy_before,"First-launch migration preserves all legacy originals")
    print("SAVE_LOCATION ",checks," checks / ",failures," failures")
    quit(0 if failures==0 else 1)
