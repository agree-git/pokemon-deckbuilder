#!/usr/bin/env python3
"""Build generation 1–3 biome pools and authored gym rosters from the catalog.

Keeps the existing 18 backgrounds and authored Kanto encounter tiers. New tiers
are provisional: babies/starters/final evolutions rare, middle stages uncommon,
other basic species common. Legendary/mythical species are event-only.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GYMS = {
    "normal": ("whitney", "꼭두", [40, 53, 115, 128, 241, 289]),
    "fire": ("blaine", "강연", [38, 59, 78, 126, 219, 324]),
    "water": ("misty", "이슬", [55, 62, 121, 184, 230, 350]),
    "grass": ("erika", "민화", [182, 189, 315, 114, 45, 71]),
    "electric": ("lt_surge", "마티스", [26, 82, 101, 125, 181, 310]),
    "ice": ("pryce", "류옹", [87, 91, 124, 221, 362, 365]),
    "fighting": ("brawly", "철구", [57, 62, 68, 214, 286, 297]),
    "poison": ("koga", "독수", [31, 34, 89, 110, 169, 336]),
    "ground": ("giovanni", "비주기", [28, 51, 105, 112, 232, 330]),
    "flying": ("winona", "은송", [18, 85, 164, 227, 277, 334]),
    "psychic": ("sabrina", "초련", [65, 97, 122, 196, 282, 326]),
    "bug": ("bugsy", "호일", [12, 15, 127, 205, 212, 214]),
    "rock": ("roxanne", "원규", [76, 141, 142, 248, 306, 348]),
    "ghost": ("morty", "유빈", [94, 200, 292, 302, 354, 356]),
    "dragon": ("clair", "이향", [148, 149, 230, 330, 334, 373]),
    "dark": ("piers", "두송", [197, 198, 215, 229, 248, 359]),
    "steel": ("jasmine", "규리", [82, 205, 208, 212, 227, 376]),
    "fairy": ("valerie", "마슈", [36, 40, 122, 184, 210, 303]),
}
STARTERS = {152, 155, 158, 252, 255, 258}
WEIGHTS = {"common": 8, "uncommon": 3, "rare": 1}


def main():
    catalog = json.loads((ROOT / "data/catalog.json").read_text(encoding="utf-8"))
    pokemon = {p["id"]: p for p in catalog["pokemon"]}
    assert set(pokemon) == set(range(1, 387)), "Import all 386 species first"
    type_names = {t["key"]: t["name"] for t in catalog["types"]}
    biomes = json.loads((ROOT / "data/biomes.json").read_text(encoding="utf-8"))
    parents = {p["evolves_from"] for p in pokemon.values()}
    gyms = []
    biome_rows = []
    gym_rows = []
    placed = set()
    for biome in biomes:
        key = biome["type"]
        old_tiers = {e["pokemon_id"]: e["tier"] for e in biome["encounters"] if e["pokemon_id"] <= 151}
        biome["encounter_mode"] = "type"
        biome["encounter_note"] = "1~3세대 원종 · 현대 타입 기준 · 전설/환상은 별도 이벤트 후보"
        biome["encounters"] = []
        biome["landmarks"] = []
        for sid, species in pokemon.items():
            if key not in species["types"]:
                continue
            placed.add(sid)
            if species["is_legendary"] or species["is_mythical"]:
                biome["landmarks"].append({"pokemon_id": sid, "note": "별도 이벤트 후보 · 일반 출현 제외"})
                continue
            tier = old_tiers.get(sid) if key != "dark" else None
            if tier is None:
                if species["is_baby"] or sid in STARTERS or (species["evolves_from"] and sid not in parents):
                    tier = "rare"
                elif species["evolves_from"]:
                    tier = "uncommon"
                else:
                    tier = "common"
            biome["encounters"].append({"pokemon_id": sid, "tier": tier, "weight": WEIGHTS[tier]})
        biome["encounters"].sort(key=lambda e: (list(WEIGHTS).index(e["tier"]), e["pokemon_id"]))
        leader_id, leader, party = GYMS[key]
        assert len(party) == len(set(party)) == 6
        for sid in party:
            assert key in pokemon[sid]["types"], (key, sid)
            assert not pokemon[sid]["is_legendary"] and not pokemon[sid]["is_mythical"]
        pool = [e["pokemon_id"] for e in biome["encounters"]]
        assert len(pool) >= 6 and set(party) <= set(pool)
        gyms.append({"type": key, "biome_id": biome["id"], "leader_id": leader_id,
                     "leader": leader, "name": type_names[key] + " 체육관", "party": party})
        columns = [type_names[key], biome["name"]]
        for tier in WEIGHTS:
            columns.append(" · ".join(pokemon[e["pokemon_id"]]["name"] for e in biome["encounters"] if e["tier"] == tier) or "—")
        columns.append(" · ".join(pokemon[e["pokemon_id"]]["name"] for e in biome["landmarks"]) or "—")
        biome_rows.append("| " + " | ".join(columns) + " |")
        gym_rows.append("| %s | %s | %s | %d종 |" % (type_names[key], leader, " · ".join(pokemon[sid]["name"] for sid in party), len(pool)))
    assert placed == set(pokemon)
    for path, data in [("data/biomes.json", biomes), ("data/gyms.json", gyms)]:
        (ROOT / path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "docs/biomes.md").write_text(
        "# 1~3세대 바이옴과 등장 포켓몬\n\n"
        "포켓몬 범위는 관동·성도·호연 원종 386종(#001~386)이다. 현대 타입과 복합타입을 인정하며 지역폼·메가진화는 제외한다. "
        "악타입을 포함한 18개 바이옴 모두 실제 해당 타입의 포켓몬으로 채운다. 전설·환상 21종은 일반 풀과 관장 파티에서 제외하고 별도 이벤트 후보로 분리한다.\n\n"
        "아래 출현 콘텐츠는 [정식 원정](full-campaign.md)의 무작위 8개 바이옴 순회에서 사용한다. "
        "개발용 `scenes/art_lab.tscn`에서 각 바이옴의 출현 후보와 관장 6마리 편성을 확인할 수 있다. "
        "자주/가끔/희귀의 종별 상대 가중치는 8:3:1이며 등급 전체 확률을 뜻하지 않는다.\n\n"
        "| 타입 | 바이옴 | 자주 | 가끔 | 희귀 | 별도 이벤트 후보 |\n|---|---|---|---|---|---|\n"
        + "\n".join(biome_rows) + "\n\n"
        "기존 관동 출현 등급은 유지하고, 새 종은 기본형 자주·중간 진화 가끔·최종 진화/아기/신규 스타팅 희귀로 분류한 초안이다. "
        "특정 원작의 서식지와 출현율을 재현하지 않는다. 진화 전후는 서로 다른 종으로 취급한다.\n\n"
        "배경은 기존 3개 PNG 아틀라스의 18개 영역을 유지한다. [에셋 출처](../ASSET_SOURCES.md), "
        "[출현 데이터](../data/biomes.json), [타입별 관장 파티](gyms.md)를 참고한다. "
        "`python3 tools/build_biomes.py`로 카탈로그에서 출현표와 관장 편성을 재생성한다.\n", encoding="utf-8")
    (ROOT / "docs/gyms.md").write_text(
        "# 타입별 관장 6마리 편성\n\n"
        "1~3세대 원종과 현대 타입을 사용한다. 모든 파티는 해당 타입을 가진 서로 다른 6종이며 전설·환상·지역폼·메가진화는 없다. "
        "진화 전후는 서로 다른 종이다. 인물의 출신 지방은 제한하지 않으며 편성은 이 게임용 초안으로, 특정 원작 버전의 파티 재현이 아니다.\n\n"
        "| 타입 | 관장 | 파티 | 일반 출현 후보 |\n|---|---|---|---|\n"
        + "\n".join(gym_rows) + "\n\n"
        "[data/gyms.json](../data/gyms.json)의 편성은 아트 랩에서 바이옴 선택 후 ‘관장 파티’로 확인한다. "
        "[정식 원정](full-campaign.md)에서 무작위 8개 바이옴의 관장전·배지와 사천왕·챔피언을 연결한다. "
        "고스트는 일반 후보 10종, 드래곤은 전설을 제외한 10종이 있어 각각 중복 없는 여섯 마리를 구성할 수 있다.\n", encoding="utf-8")
    print(f"Built {len(biomes)} typed biome pools, {len(gyms)} distinct six-species gym rosters; {len(placed)} species placed.")


if __name__ == "__main__":
    main()
