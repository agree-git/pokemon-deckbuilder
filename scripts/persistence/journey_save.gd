class_name JourneySave
extends RefCounted
## Atomic checkpoints + last valid backup. The small head prevents old-run resurrection.
const VERSION := 1
const SAVE_PATH := "user://journey.json"
const MAX_FILE_BYTES := 4*1024*1024
const RULESET := "campaign-69-player-fields-v13"
const COMPATIBLE_CONTENT := ["e96129c17840469e6ef32ed0996be6e535a7cad0f9fd0eb186259c893ac9ac5a","efe331c4f45f549b9bba7dc032ae577acca0fff3eebdc0c154cf403e01069d52","7dfcdedd7bc0ccd814d896a7a0dc71e3ebbaf79a127c08a94d37713a1d1c106f","f823671d51317f3d0352a807005558ef2c9e4accc868fdc17b91c25d619e2d43","36fe00197a9e4de42cae2a20b6dffe564f7478250f8659812a68790fc76bae08","5de9a69473977ace2c89e2ba54e0951ca8c436ce9a47d611ac61b636f7acbf30","6c3446b61b27f5743982dd04b96f2882dd5a994615edf785ae87160c2ea3da4e","8105ad5dafd74ab91cfd49421042e0281a9e15e0297f99563ea392faa3fc606e","f1cf5bc91b4f53123011c7a2ec0049862d425f11127d63782b19971ab44411a5","7ce6e0d58dab102bb60728714b36d36cc417cedeb0ed92811261c6339ad15b89","cb812fd10b00f224a7c50255448f2d5643ed440af7daa4429d41ae26bfc6e952","1f49586798419ec8b34b5e1698a3d7b470905520caed012674308eec391001c2"]
const CONTENT := ["res://data/base_stats.json","res://data/catalog.json","res://data/biomes.json","res://data/gyms.json","res://data/league.json","res://data/progression.json","res://data/evolutions.json","res://data/type_chart.json",PokedexExpansion.PATH,TechnicalMachines.PATH,BossParties.PATH,BossMoveEffects.PATH,BossMoveEffectsP1.PATH,BossMoveEffectsP2.PATH,BossMoveEffectsP3.PATH,PlayerMoveCards.PATH,PlayerMoveTactics.PATH,PlayerMoveExchange.PATH,PlayerMoveFields.PATH]
static var _fingerprint := ""
var path: String
var last_error := ""
var recovered := false
func _init(save_path := SAVE_PATH) -> void:
    path = save_path
static func fingerprint() -> String:
    if _fingerprint.is_empty():
        var hash := HashingContext.new()
        hash.start(HashingContext.HASH_SHA256)
        hash.update(RULESET.to_utf8_buffer())
        for source: String in CONTENT:
            hash.update(source.to_utf8_buffer())
            hash.update(FileAccess.get_file_as_bytes(source))
        _fingerprint = hash.finish().hex_encode()
    return _fingerprint
static func compatible_content(value: Variant) -> bool:
    return value is String and (value == fingerprint() or value in COMPATIBLE_CONTENT)
static func _json(source: String) -> Variant:
    if not FileAccess.file_exists(source): return null
    var file := FileAccess.open(source,FileAccess.READ)
    if file == null or file.get_length() > MAX_FILE_BYTES: return null
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK: return null
    return parser.data
func _read(source: String, validate_state := true) -> Dictionary:
    var envelope: Variant = _json(source)
    if not envelope is Dictionary or envelope.get("version") != VERSION or not compatible_content(envelope.get("content")): return {}
    if not envelope.get("payload") is String or not envelope.get("sha256") is String: return {}
    var bytes := Marshalls.base64_to_raw(envelope["payload"])
    if bytes.size() < 4 or bytes.size() > MAX_FILE_BYTES or bytes.hex_encode().sha256_text() != envelope["sha256"]: return {}
    # Godot's non-object decoder preserves 64-bit RNG/seed values and integer keys.
    var decoded: Variant = bytes_to_var(bytes)
    if not decoded is Dictionary or not decoded.get("run") is Dictionary: return {}
    if validate_state and not JourneySnapshot.validate(decoded): return {}
    return decoded
static func _atomic(target: String, text: String) -> String:
    var absolute := ProjectSettings.globalize_path(target)
    if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return "원정 저장 폴더를 만들 수 없습니다."
    var file := FileAccess.open(absolute+".tmp",FileAccess.WRITE)
    if file == null: return "원정을 저장할 수 없습니다."
    file.store_string(text)
    file.flush()
    var result := file.get_error()
    file.close()
    if result != OK: return "원정 저장을 완료하지 못했습니다."
    if DirAccess.rename_absolute(absolute+".tmp",absolute) != OK: return "원정 저장 파일을 교체할 수 없습니다."
    return ""
func save(j: TacticalJourney) -> String:
    if path.is_empty() or not j.full_campaign: return ""
    var terminal := j.phase in [TacticalJourney.CLEARED,TacticalJourney.FAILED] or j.battle.phase == TacticalBattle.LOST
    var head := {"version":VERSION,"run_id":j.run_id,"finished":terminal}
    # Commit the terminal marker first, so a backup cannot revive a finished run.
    if terminal:
        last_error = _atomic(path+".head",JSON.stringify(head))
        if not last_error.is_empty(): return last_error
    var previous := _read(path,false)
    if not previous.is_empty() and previous["run"].get("run_id") == j.run_id:
        last_error = _atomic(path+".bak",FileAccess.get_file_as_string(path))
        if not last_error.is_empty(): return last_error
    var bytes := var_to_bytes(JourneySnapshot.encode(j))
    var envelope := {"version":VERSION,"content":fingerprint(),"payload":Marshalls.raw_to_base64(bytes),"sha256":bytes.hex_encode().sha256_text()}
    last_error = _atomic(path,JSON.stringify(envelope))
    if not last_error.is_empty(): return last_error
    if not terminal: last_error = _atomic(path+".head",JSON.stringify(head))
    return last_error
func load_journey() -> TacticalJourney:
    last_error = ""
    recovered = false
    if path.is_empty(): return null
    var head: Variant = _json(path+".head")
    if not head is Dictionary or head.get("version") != VERSION or not head.get("run_id") is String or not head.get("finished") is bool: head = null
    var data := _read(path)
    if data.is_empty():
        data = _read(path+".bak")
        # A backup belongs only to the last committed run, never an older attempt.
        if data.is_empty() or not head is Dictionary or data["run"]["run_id"] != head.get("run_id"):
            if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"):
                var previous: Variant = _json(path)
                var incompatible: bool = previous is Dictionary and not compatible_content(previous.get("content",""))
                last_error = "전투 규칙이 바뀌어 이전 원정은 이어할 수 없습니다. 새 원정을 시작하세요. 포획 도감과 스타팅 해금은 유지됩니다." if incompatible else "원정 저장을 불러오지 못했습니다. 파일이 손상되었거나 게임 버전이 다릅니다."
            return null
        recovered = true
    if head is Dictionary and data["run"]["run_id"] == head.get("run_id") and head.get("finished",false): return null
    if data["run"]["phase"] in [TacticalJourney.CLEARED,TacticalJourney.FAILED] or data["battle"]["phase"] == TacticalBattle.LOST: return null
    var result := JourneySnapshot.restore(data)
    if recovered: last_error = "저장 파일을 읽지 못해 이전 자동 저장에서 복구했습니다."
    return result
