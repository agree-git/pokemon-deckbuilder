extends Node
## Runs before preferences/profile/session load. The legacy directory stays intact.
const USER_DIR := "PokemonExpedition"
const STAGE := ".legacy-save-import"
const DONE := ".legacy-save-migrated"
const GROUPS := [
    ["journey.json.head","journey.json.bak","journey.json"],
    ["collection.json.bak","collection.json"],
    ["settings.cfg"]
]
var last_error := ""

func _init() -> void:
    # The export validation harness deliberately uses a separate custom directory.
    if ProjectSettings.get_setting("application/config/custom_user_dir_name","") != USER_DIR: return
    last_error = migrate(legacy_directory(),OS.get_user_data_dir())
    if not last_error.is_empty():
        if DisplayServer.get_name() != "headless": OS.alert(last_error,"저장 이전 안내")
        (Engine.get_main_loop() as SceneTree).quit(1)

static func legacy_directory() -> String:
    var engine_folder := "godot" if OS.get_name() in ["Linux","FreeBSD","NetBSD","OpenBSD"] else "Godot"
    return OS.get_data_dir().path_join(engine_folder+"/app_userdata/포켓몬 원정대")

static func migrate(source: String,destination: String) -> String:
    if source.simplify_path() == destination.simplify_path(): return ""
    if FileAccess.file_exists(destination.path_join(DONE)): return ""
    var error := "기존 저장을 새 폴더로 이전하지 못했습니다. 원본은 그대로 남아 있습니다. 폴더 권한과 여유 공간을 확인한 뒤 다시 실행하세요."
    if DirAccess.make_dir_recursive_absolute(destination) != OK: return error
    var stage := destination.path_join(STAGE)
    var journal := stage.path_join("plan.json")
    var plan: Dictionary = {}
    if FileAccess.file_exists(journal):
        var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(journal))
        if not loaded is Dictionary: return error
        plan = loaded
    else:
        if DirAccess.make_dir_recursive_absolute(stage) != OK: return error
        for group: Array in GROUPS:
            # A run and its head/backup are indivisible; never mix old and new runs.
            if group.any(func(name: String): return FileAccess.file_exists(destination.path_join(name))): continue
            for name: String in group:
                var original := source.path_join(name)
                if not FileAccess.file_exists(original): continue
                var copy := stage.path_join(name)
                if DirAccess.copy_absolute(original,copy) != OK: return error
                var hash := FileAccess.get_sha256(copy)
                if hash.is_empty() or hash != FileAccess.get_sha256(original): return error
                plan[name] = hash
        var file := FileAccess.open(journal+".tmp",FileAccess.WRITE)
        if file == null: return error
        file.store_string(JSON.stringify(plan));file.flush()
        var written := file.get_error()
        file.close()
        if written != OK or DirAccess.rename_absolute(journal+".tmp",journal) != OK: return error
    var allowed: Array = []
    for group: Array in GROUPS: allowed.append_array(group)
    if not plan.keys().all(func(name: Variant): return name is String and name in allowed): return error
    # Check the whole staged transaction before installing any file.
    for name: String in plan:
        if not plan[name] is String or not FileAccess.file_exists(stage.path_join(name)): return error
        if FileAccess.get_sha256(stage.path_join(name)) != plan[name]: return error
        var target := destination.path_join(name)
        if FileAccess.file_exists(target) and FileAccess.get_sha256(target) != plan[name]: return error
    for group: Array in GROUPS:
        for name: String in group:
            if not plan.has(name): continue
            var target := destination.path_join(name)
            if FileAccess.file_exists(target): continue # Identical file from an interrupted import.
            if DirAccess.copy_absolute(stage.path_join(name),target+".migrate.tmp") != OK: return error
            if FileAccess.get_sha256(target+".migrate.tmp") != plan[name]: return error
            if DirAccess.rename_absolute(target+".migrate.tmp",target) != OK: return error
    var completed := FileAccess.open(destination.path_join(DONE)+".tmp",FileAccess.WRITE)
    if completed == null: return error
    completed.store_string("1\n");completed.flush()
    var written := completed.get_error()
    completed.close()
    if written != OK or DirAccess.rename_absolute(destination.path_join(DONE)+".tmp",destination.path_join(DONE)) != OK: return error
    for name: String in plan: DirAccess.remove_absolute(stage.path_join(name))
    DirAccess.remove_absolute(journal)
    DirAccess.remove_absolute(stage)
    return ""
