#!/usr/bin/env python3
"""Build original Emerald level-up learnsets and species growth curves offline.

The large all-version move table is filtered before checking it into the repo;
both the upstream SHA-256 and the derived subset SHA-256 are recorded.
"""
import csv
import hashlib
import io
import json
import tempfile
import urllib.request
import import_pokemon_assets as assets


def emerald_moves():
    relative = "assets/sources/csv/pokemon_moves_emerald.csv"
    path = assets.ROOT / relative
    url = f"{assets.RAW}/PokeAPI/pokeapi/{assets.DATA_REV}/data/v2/csv/pokemon_moves.csv"
    old = assets.previous.get(relative, {})
    if path.exists() and old.get("selection") == "Emerald 1..385; Deoxys Ruby-Sapphire base form; level-up" and old.get("url") == url and hashlib.sha256(path.read_bytes()).hexdigest() == old.get("sha256"):
        assets.records[relative] = old
        return list(csv.DictReader(path.open(encoding="utf-8")))
    if path.exists() and relative not in assets.previous:
        raise RuntimeError(f"Refusing to overwrite unrecorded file: {path}")
    digest = hashlib.sha256()
    with tempfile.TemporaryFile(mode="w+b") as raw:
        with urllib.request.urlopen(url, timeout=60) as response:
            for chunk in iter(lambda: response.read(1024*1024), b""):
                digest.update(chunk)
                raw.write(chunk)
        raw.seek(0)
        reader = csv.DictReader(io.TextIOWrapper(raw, encoding="utf-8-sig"))
        fields = reader.fieldnames
        rows = [r for r in reader if r["pokemon_move_method_id"] == "1" and ((1 <= int(r["pokemon_id"]) <= 385 and r["version_group_id"] == "6") or (r["pokemon_id"] == "386" and r["version_group_id"] == "5"))]
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=fields, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    payload = output.getvalue().encode()
    path.write_bytes(payload)
    assets.records[relative] = {"url": url, "sha256": hashlib.sha256(payload).hexdigest(),
        "source_sha256": digest.hexdigest(), "selection": "Emerald 1..385; Deoxys Ruby-Sapphire base form; level-up"}
    return rows


def main():
    groups = assets.table("version_groups")
    assert any(row["id"] == "6" and row["identifier"] == "emerald" for row in groups)
    species = {int(r["id"]): r for r in assets.table("pokemon_species") if int(r["id"]) <= 386}
    pokemon = {int(r["id"]): r for r in assets.table("pokemon") if int(r["id"]) <= 386}
    curves = {str(i): [0]*101 for i in range(1, 7)}
    for r in assets.table("experience"):
        curves[r["growth_rate_id"]][int(r["level"])] = int(r["experience"])
    entries = {str(i): {"growth_rate": int(s["growth_rate_id"]), "base_experience": int(pokemon[i]["base_experience"]), "learnset": []} for i, s in species.items()}
    for row in sorted(emerald_moves(), key=lambda r: (int(r["level"]), int(r["order"] or 0), int(r["move_id"]))):
        entry = {"level": int(row["level"]), "move": int(row["move_id"])}
        if entry not in entries[row["pokemon_id"]]["learnset"]:
            entries[row["pokemon_id"]]["learnset"].append(entry)
    names = assets.localized(assets.table("move_names"), "move_id")
    types = {int(r["id"]): r["identifier"] for r in assets.table("types")}
    meta = {int(r["move_id"]): r for r in assets.table("move_meta")}
    stats = assets.table("move_meta_stat_changes")
    moves = {}
    for move in assets.table("moves"):
        mid = int(move["id"])
        if mid > 354 or int(move["generation_id"]) > 3: continue
        changes = [{"stat_id": int(s["stat_id"]), "change": int(s["change"])} for s in stats if int(s["move_id"]) == mid]
        detail = meta.get(mid, {})
        moves[str(mid)] = {"id": mid, "name": names[mid], "type": types[int(move["type_id"])],
            "power": assets.number(move, "power"), "category": int(move["damage_class_id"]),
            "target": assets.number(move, "target_id"), "stats": changes,
            "ailment": assets.number(detail, "meta_ailment_id"), "healing": assets.number(detail, "healing"),
            "drain": assets.number(detail, "drain"), "vfx": assets.presentation(move, detail, changes)}
    assert all(e["learnset"] for e in entries.values())
    assert len(moves) == 354
    content = {"version": "emerald", "curves": curves, "species": entries, "moves": moves}
    (assets.ROOT / "data/progression.json").write_text(json.dumps(content, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(f"Built Emerald learnsets for {len(entries)} species, {len(moves)} moves and 6 growth curves.")


if __name__ == "__main__":
    try:
        main()
    finally:
        assets.MANIFEST.write_text(json.dumps(dict(sorted(assets.records.items())), indent=2)+"\n", encoding="utf-8")
