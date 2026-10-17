extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(message)
func run() -> void:
    var save := JourneySave.new("user://rare-legacy-envelope.json")
    for seed_value in [0,14,16,24,2026,9999]:
        var j := TacticalJourney.new(seed_value,"field_kit",[1,4,7],true)
        j.rare_hunt = {"target":RareEncounter.target(seed_value,1),"clues":[],"battle_step":-1,"captured":false}
        var checkpoint := JourneySnapshot.encode(j)
        check(save.save(j).is_empty(),"Write checkpoint")
        var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save.path))
        envelope["content"] = JourneySave.COMPATIBLE_CONTENT[0]
        check(JourneySave._atomic(save.path,JSON.stringify(envelope)).is_empty(),"Write historical envelope")
        var restored := save.load_journey()
        check(restored != null and JourneySnapshot.encode(restored) == checkpoint,"Historical fingerprint + seed pool preserved")
        check(save.save(restored).is_empty(),"Save legacy run with current fingerprint")
        envelope = JSON.parse_string(FileAccess.get_file_as_string(save.path))
        check(envelope["content"] == JourneySave.fingerprint(),"Envelope upgraded, target unchanged")
        for version: Variant in [0,3,2.0,"2",null]:
            var bad := checkpoint.duplicate(true)
            bad["run"]["rare_hunt"]["pool_version"] = version
            check(not JourneySnapshot.validate(bad),"Reject unsupported hunt pool version")
        var bad := checkpoint.duplicate(true)
        bad["run"]["rare_hunt"]["extra"] = true
        check(not JourneySnapshot.validate(bad),"Reject unrelated hunt fields")
        envelope["content"] = "arbitrary incompatible content"
        JourneySave._atomic(save.path,JSON.stringify(envelope))
        # Delete only this test's backup to exercise an unsupported content hash.
        DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path+".bak"))
        check(save.load_journey() == null,"Unknown content fingerprint remains rejected")
    for id: int in [1001,1002,1007,1024,10169,10170,10171]:
        var j := TacticalJourney.new(2026,"field_kit",[id],true)
        check(save.save(j).is_empty(),"Write rare starter "+str(id))
        var loaded := save.load_journey()
        check(loaded != null and JourneySnapshot.encode(loaded) == JourneySnapshot.encode(j),"Disk roundtrip rare starter "+str(id))
        var bad := JourneySnapshot.encode(j)
        bad["run"]["starter_ids"] = [387]
        check(not JourneySnapshot.validate(bad),"Added rare scope does not accept unrelated ordinary species")
    print("RARE_COMPATIBILITY ",checks," checks / ",failures," failures")
    await process_frame
    quit(0 if failures == 0 else 1)
