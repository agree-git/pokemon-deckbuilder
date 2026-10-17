class_name PlayerProfile
extends RefCounted
## Permanent collection only; run HP, XP and decks never enter this file.
const DEFAULT_STARTERS := [1,4,7]
const SAVE_PATH := "user://collection.json"
var captured_ids: Array[int] = []
var path: String
var last_error := ""

func _init(save_path: String = SAVE_PATH) -> void:
    path = save_path
    if not path.is_empty() and FileAccess.file_exists(path):
        if not _load(path) and not _load(path+".bak"):
            last_error = "포획 도감을 불러오지 못했습니다."
func _load(source: String) -> bool:
    if not FileAccess.file_exists(source): return false
    var parser := JSON.new()
    if parser.parse(FileAccess.get_file_as_string(source)) != OK: return false
    var data: Variant = parser.data
    if not data is Dictionary or data.get("version") != 1 or not data.get("captured_ids") is Array: return false
    var valid: Array[int] = []
    for value: Variant in data["captured_ids"]:
        if not (value is float or value is int) or not is_finite(float(value)): return false
        var id := int(value)
        if float(id) != float(value) or not VisualCatalog.supports(id): return false
        if id not in valid: valid.append(id)
    valid.sort()
    captured_ids.assign(valid)
    return true
func unlocked_starters(catalog: VisualCatalog) -> Array[int]:
    var result: Array[int] = []
    result.assign(DEFAULT_STARTERS)
    for id: int in captured_ids:
        var basic := catalog.starter_species_id(id)
        if basic > 0 and basic not in result: result.append(basic)
    result.sort()
    return result
func record_capture(id: int,catalog: VisualCatalog) -> String:
    if catalog.species(id).is_empty(): return "포획 도감에 기록할 수 없는 포켓몬입니다."
    if id not in captured_ids:
        captured_ids.append(id)
        captured_ids.sort()
    return save()
func save() -> String:
    var target := ProjectSettings.globalize_path(path)
    var error := DirAccess.make_dir_recursive_absolute(target.get_base_dir())
    if error != OK: return "포획 도감 저장 폴더를 만들 수 없습니다."
    var file := FileAccess.open(target+".tmp",FileAccess.WRITE)
    if file == null: return "포획 도감을 저장할 수 없습니다."
    file.store_string(JSON.stringify({"version":1,"captured_ids":captured_ids}))
    file.flush()
    var write_error := file.get_error()
    file.close()
    if write_error != OK: return "포획 도감을 저장할 수 없습니다."
    if FileAccess.file_exists(target):
        # Only back up a valid previous file, preserving recovery from corruption.
        var previous := PlayerProfile.new("")
        if previous._load(target):
            error = DirAccess.copy_absolute(target,target+".bak")
            if error != OK: return "이전 포획 도감을 보관할 수 없습니다."
    error = DirAccess.rename_absolute(target+".tmp",target)
    last_error = "" if error == OK else "포획 도감을 저장할 수 없습니다."
    return last_error
