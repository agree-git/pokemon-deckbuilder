extends Node
signal save_status_changed
const MAX_STARTERS := 3
## Owns the auto-saved campaign and the separately persistent collection.
var journey := TacticalJourney.new(2026)
var profile := PlayerProfile.new()
var save_store := JourneySave.new()
var save_notice := ""
var _tracked_journey: TacticalJourney
var has_journey := false
var open_starter_selection := false

func start_journey(starters: Array[int],run_seed: int, full_campaign := true) -> String:
    var catalog := VisualCatalog.new()
    var allowed := profile.unlocked_starters(catalog)
    var seen: Array[int] = []
    if starters.is_empty() or starters.size() > MAX_STARTERS: return "스타팅을 1~%d마리 선택하세요." % MAX_STARTERS
    for id: int in starters:
        if id not in allowed or id in seen: return "해금된 포켓몬을 중복 없이 선택하세요."
        seen.append(id)
    adopt_journey(TacticalJourney.new(run_seed,"field_kit",starters,full_campaign))
    return ""

func _ready() -> void:
    var restored := save_store.load_journey()
    save_notice = save_store.last_error
    if restored != null:
        adopt_journey(restored,false)
        var profile_error := _sync_captures()
        if not profile_error.is_empty(): save_notice = profile_error
func adopt_journey(next: TacticalJourney, save_now := true) -> void:
    if _tracked_journey != null and _tracked_journey.changed.is_connected(_on_journey_changed): _tracked_journey.changed.disconnect(_on_journey_changed)
    journey = next
    has_journey = true
    _tracked_journey = journey
    journey.changed.connect(_on_journey_changed)
    if save_now: checkpoint()
func tracks(candidate: TacticalJourney) -> bool:
    return candidate == _tracked_journey and candidate == journey and candidate.full_campaign
func _on_journey_changed() -> void:
    checkpoint()
func _sync_captures() -> String:
    if not profile.last_error.is_empty():
        profile.last_error = profile.save()
        if not profile.last_error.is_empty(): return profile.last_error
    var missing: Array = journey.captured_ids.filter(func(id: int): return id not in profile.captured_ids)
    if missing.is_empty(): return ""
    var catalog := VisualCatalog.new()
    for id: int in missing:
        if id not in profile.captured_ids:
            var error := profile.record_capture(id,catalog)
            if not error.is_empty():
                profile.last_error = error
                return error
    return ""
func checkpoint() -> String:
    if not has_journey or not tracks(journey): return ""
    var profile_error := _sync_captures()
    save_notice = save_store.save(journey)
    if save_notice.is_empty(): save_notice = profile_error
    save_status_changed.emit()
    return save_notice
