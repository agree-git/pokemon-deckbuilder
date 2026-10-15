#!/usr/bin/env python3
"""Fetch pinned PokéAPI sources; create the offline generation 1–3 catalog.

Uses only Python's standard library. Existing files with matching hashes are
reused. Pokémon game art retains its original owners' rights; see ASSET_SOURCES.
"""

import concurrent.futures
import csv
import hashlib
import io
import json
import struct
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPRITES_REV = "0dc105d5b12416932f29b594078282ab4be045f5"
DATA_REV = "81d20919845b6a445969b9265aab5cec6b04cece"
FONTS_REV = "e9678a5385322c63730122ba464765baad83cfd8"
RAW = "https://raw.githubusercontent.com"
MANIFEST = ROOT / "assets/sources/manifest.json"
previous = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
records = previous.copy()
SPECIES_LIMIT = 386


def fetch(url: str, relative: str) -> bytes:
    path = ROOT / relative
    old = previous.get(relative, {})
    if path.exists():
        payload = path.read_bytes()
        if old.get("url") == url and old.get("sha256") == hashlib.sha256(payload).hexdigest():
            records[relative] = old
            return payload
        if relative not in previous:
            raise RuntimeError(f"Refusing to overwrite unrecorded file: {path}")
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                payload = response.read()
            break
        except (OSError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(attempt + 1)
    if relative.endswith(".png"):
        if payload[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", payload[16:24]) != (96, 96):
            raise ValueError(f"Expected 96x96 PNG: {url}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    records[relative] = {"url": url, "sha256": hashlib.sha256(payload).hexdigest()}
    return payload


def table(name):
    payload = fetch(f"{RAW}/PokeAPI/pokeapi/{DATA_REV}/data/v2/csv/{name}.csv", f"assets/sources/csv/{name}.csv")
    return list(csv.DictReader(io.StringIO(payload.decode("utf-8-sig"))))


def localized(rows, key):
    return {int(row[key]): row["name"] for row in rows if row["local_language_id"] == "3"}


def number(row, key, default=0):
    return int(row.get(key) or default)


def presentation(move, meta, stats):
    """Presentation only: these profiles never apply damage/status game rules."""
    mid = int(move["id"])
    target = "self" if number(move, "target_id") in (4, 7, 13) else "opponent"
    ailment = {1: "paralysis", 2: "sleep", 3: "freeze", 4: "burn", 5: "poison", 6: "confusion", 8: "bind", 18: "seed"}.get(number(meta, "meta_ailment_id"), "")
    if mid in (54, 114):
        return {"primary": "mist", "target": "field", "secondary": ""}
    if mid in (100, 18, 46):
        return {"primary": "evade", "target": target, "secondary": ""}
    if mid in (102, 118, 119, 144, 160):
        return {"primary": "transform", "target": "self", "secondary": ""}
    if mid == 50:
        return {"primary": "seal", "target": "opponent", "secondary": ""}
    if mid == 150:
        return {"primary": "splash", "target": "self", "secondary": ""}
    if mid in (113, 115, 112, 110, 111, 151, 164):
        return {"primary": "shield", "target": "self", "secondary": ""}
    if number(meta, "healing") > 0 or mid in (105, 135, 156):
        return {"primary": "heal", "target": "self", "secondary": "sleep" if mid == 156 else ""}
    if number(meta, "drain") > 0:
        return {"primary": "drain", "target": "opponent", "secondary": ""}
    if number(move, "damage_class_id") == 1:
        if ailment:
            primary = ailment
        elif stats:
            primary = "stat_up" if stats[0]["change"] > 0 else "stat_down"
        elif mid in (14, 74, 96, 97, 104, 106, 107, 116, 133, 159):
            primary = "stat_up"
        else:
            primary = "utility"
        return {"primary": primary, "target": target, "secondary": ""}
    primary = "projectile" if number(move, "damage_class_id") == 3 else "impact"
    if mid in (2, 10, 15, 154, 163):
        primary = "slash"
    if mid in (120, 153):
        primary = "explosion"
    if mid in (19, 76, 91, 130, 143):
        primary = "charge"
    return {"primary": primary, "target": target, "secondary": ailment}


def main():
    names = localized(table("pokemon_species_names"), "pokemon_species_id")
    move_names = localized(table("move_names"), "move_id")
    type_names = localized(table("type_names"), "type_id")
    types = {int(row["id"]): {"key": row["identifier"], "name": type_names[int(row["id"])]}
             for row in table("types") if int(row["id"]) <= 18}
    pokemon_types = table("pokemon_types")
    pokemon = []
    for species in table("pokemon_species"):
        sid = int(species["id"])
        if 1 <= sid <= SPECIES_LIMIT:
            pokemon.append({"id": sid, "key": species["identifier"], "name": names[sid],
                            "generation": int(species["generation_id"]),
                            "region": {1: "kanto", 2: "johto", 3: "hoenn"}[int(species["generation_id"])],
                            "evolves_from": number(species, "evolves_from_species_id"),
                            "is_baby": species["is_baby"] == "1",
                            "is_legendary": species["is_legendary"] == "1",
                            "is_mythical": species["is_mythical"] == "1",
                            "types": [types[int(row["type_id"])]["key"] for row in sorted(pokemon_types, key=lambda r: int(r["slot"])) if int(row["pokemon_id"]) == sid],
                            "front": f"res://assets/pokemon/front/{sid:03}.png",
                            "back": f"res://assets/pokemon/back/{sid:03}.png"})
    meta = {int(row["move_id"]): row for row in table("move_meta")}
    stat_rows = table("move_meta_stat_changes")
    moves = []
    for move in table("moves"):
        mid = int(move["id"])
        if int(move["generation_id"]) != 1:
            continue
        changes = [{"stat_id": int(row["stat_id"]), "change": int(row["change"])} for row in stat_rows if int(row["move_id"]) == mid]
        detail = meta.get(mid, {})
        moves.append({"id": mid, "key": move["identifier"], "name": move_names[mid],
                      "type": types[int(move["type_id"])]["key"],
                      "category": {1: "status", 2: "physical", 3: "special"}[int(move["damage_class_id"])],
                      "power": number(move, "power"), "accuracy": number(move, "accuracy"),
                      "stat_changes": changes, "ailment_chance": number(detail, "ailment_chance"),
                      "vfx": presentation(move, detail, changes)})
    assert len(pokemon) == SPECIES_LIMIT and len(moves) == 165
    # Only unconditional level evolutions are playable for now. Keep all
    # conditional rows in the pinned CSV, rather than treating stones/friendship
    # or gender/stat/location requirements as plain level evolutions.
    parents = {p["id"]: p["evolves_from"] for p in pokemon}
    evolutions = []
    for row in table("pokemon_evolution"):
        target = int(row["evolved_species_id"])
        if target not in parents or not parents[target]:
            continue
        ordinary = all(value in ("", "0") if key in ("needs_overworld_rain", "turn_upside_down", "needs_multiplayer", "near_special_rock") else value == ""
                       for key, value in row.items()
                       if key not in ("id", "evolved_species_id", "evolution_trigger_id", "minimum_level", "version_group_id", "is_default"))
        if row["is_default"] == "1" and row["evolution_trigger_id"] == "1" and row["minimum_level"] and ordinary:
            rule = {"from": parents[target], "to": target, "level": int(row["minimum_level"])}
            if rule not in evolutions:
                evolutions.append(rule)
    assert {"from": 1, "to": 2, "level": 16} in evolutions
    (ROOT / "data/evolutions.json").write_text(json.dumps(sorted(evolutions, key=lambda e: (e["from"], e["to"])), indent=2) + "\n", encoding="utf-8")
    jobs = [(f"{RAW}/PokeAPI/sprites/{SPRITES_REV}/sprites/pokemon/{'' if side == 'front' else 'back/'}{sid}.png",
             f"assets/pokemon/{side}/{sid:03}.png") for sid in range(1, SPECIES_LIMIT + 1) for side in ("front", "back")]
    jobs += [(f"{RAW}/PokeAPI/sprites/{SPRITES_REV}/LICENCE.txt", "assets/sources/POKEAPI_SPRITES_LICENSE.txt"),
             (f"{RAW}/PokeAPI/pokeapi/{DATA_REV}/LICENSE.md", "assets/sources/POKEAPI_DATA_LICENSE.txt"),
             (f"{RAW}/google/fonts/{FONTS_REV}/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf", "assets/fonts/NotoSansKR.ttf"),
             (f"{RAW}/google/fonts/{FONTS_REV}/ofl/notosanskr/OFL.txt", "assets/fonts/OFL.txt")]
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(lambda job: fetch(*job), jobs))
    out = ROOT / "data/catalog.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"regions": ["kanto", "johto", "hoenn"], "max_generation": 3,
                               "pokemon": sorted(pokemon, key=lambda p: p["id"]),
                               "types": list(types.values()), "moves": moves}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Imported {len(pokemon)} generation 1-3 species / {len(jobs) - 4} sprites / {len(moves)} move VFX profiles.")


if __name__ == "__main__":
    try:
        main()
    finally:
        # Preserve verified source downloads even when validation fails early.
        MANIFEST.write_text(json.dumps(dict(sorted(records.items())), indent=2) + "\n", encoding="utf-8")
