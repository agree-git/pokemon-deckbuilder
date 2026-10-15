class_name CampaignBalance
extends RefCounted
## Fixed stage rewards, normalized to each original growth curve. No level catch-up.
const REGIONS := 8
const BATTLES_PER_REGION := 8
const REGIONAL_BATTLES := REGIONS*BATTLES_PER_REGION
const ELITE_COUNT := 4
const CHAMPION_INDEX := REGIONAL_BATTLES+ELITE_COUNT
const TOTAL_BATTLES := CHAMPION_INDEX+1
const GYM_LEVELS := [18,29,40,50,60,70,80,91]
const ELITE_LEVELS := [94,96,98,100]
const REGIONAL_KINDS := ["wild","wild","wild","wild","wild","trainer","veteran","gym"]
static func kind_at(index: int) -> String:
    if index >= CHAMPION_INDEX: return "champion"
    if index >= REGIONAL_BATTLES: return "elite"
    return REGIONAL_KINDS[index%BATTLES_PER_REGION]
static func enemy_level(index: int) -> int:
    if index >= CHAMPION_INDEX: return 100
    if index >= REGIONAL_BATTLES: return ELITE_LEVELS[index-REGIONAL_BATTLES]
    var chapter := floori(index/float(BATTLES_PER_REGION))
    var start := 6 if chapter == 0 else int(GYM_LEVELS[chapter-1])+1
    return roundi(lerpf(start,GYM_LEVELS[chapter],(index%BATTLES_PER_REGION)/7.0))
static func weight(index: int) -> int:
    var role: int = {"wild":4,"trainer":5,"veteran":6,"gym":8,"elite":9,"champion":10}[kind_at(index)]
    return (index+4)*(index+4)*role
static var _cumulative: Array[int] = []
static func cumulative() -> Array[int]:
    if _cumulative.is_empty():
        _cumulative.append(0)
        for i in CHAMPION_INDEX: _cumulative.append(_cumulative.back()+weight(i))
    return _cumulative
static func experience_reward(index: int, species_id := 1) -> float:
    var sums := cumulative()
    var budget := TacticalGrowth.experience_floor(100,species_id)-TacticalGrowth.experience_floor(5,species_id)
    var denominator := float(sums.back())
    # Difference of rounded cumulative awards preserves the exact Lv.100 budget.
    var before := roundi(budget*10.0*sums[mini(index,CHAMPION_INDEX)]/denominator)
    var after := roundi(budget*10.0*(sums[index+1] if index < CHAMPION_INDEX else sums.back()+weight(index))/denominator)
    return (after-before)/10.0
