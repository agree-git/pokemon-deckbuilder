#!/usr/bin/env python3
"""Reproduce the reviewed 32px type badges from pinned, hash-locked web SVGs.

Uses Python's standard library. Cached sources support offline builds; gameplay
uses local assets only. Original glyphs, CSS and README remain unmodified.
"""
import argparse
import hashlib
import json
import re
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "assets/sources/type_icons.json"
REVISION = "5781623f147f1bf850f426cfe1874ba56a9b75ee"
BASE = f"https://raw.githubusercontent.com/duiker101/pokemon-type-svg-icons/{REVISION}/"
SVG = "http://www.w3.org/2000/svg"


def digest(payload):
    return hashlib.sha256(payload).hexdigest()


def source(relative, record, offline):
    path = ROOT / relative
    if path.exists():
        payload = path.read_bytes()
        if digest(payload) == record["sha256"]:
            return payload
    if offline:
        raise ValueError(f"Missing or changed locked source: {relative}")
    if not record["url"].startswith(BASE):
        raise ValueError(f"Source must use the pinned revision: {relative}")
    with urllib.request.urlopen(record["url"], timeout=30) as response:
        payload = response.read()
    if digest(payload) != record["sha256"]:
        raise ValueError(f"Source checksum mismatch: {relative}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    return payload


def badge(payload, color):
    original = ET.fromstring(payload)
    if original.tag != f"{{{SVG}}}svg" or original.get("viewBox") != "0 0 512 512":
        raise ValueError("Expected a 512px source SVG")
    ET.register_namespace("", SVG)
    result = ET.Element(f"{{{SVG}}}svg", {"width": "32", "height": "32", "viewBox": "0 0 32 32"})
    ET.SubElement(result, f"{{{SVG}}}circle", {"cx": "16", "cy": "16", "r": "16", "fill": color})
    glyph = ET.SubElement(result, f"{{{SVG}}}g", {"transform": "translate(6.4 6.4) scale(0.0375)"})
    for child in original:
        glyph.append(child)
    return (ET.tostring(result, encoding="unicode") + "\n").encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline", action="store_true", help="Require cached hash-matching sources")
    parser.add_argument("--check", action="store_true", help="Verify sources, generated files and lock without writing or downloading")
    args = parser.parse_args()
    lock = json.loads(LOCK.read_text())
    if lock["revision"] != REVISION:
        raise ValueError("Unexpected type icon revision")
    sources = {path: source(path, record, args.offline or args.check) for path, record in lock["sources"].items()}
    css = sources["assets/sources/type-icons/style.css.txt"].decode()
    generated = {}
    files = {}
    for key in lock["types"]:
        source_path = f"assets/sources/type-icons/{key}.svg.txt"
        color = re.search(r"\." + key + r"\s*\{\s*background:\s*(#[0-9A-Fa-f]{6})", css)
        if color is None:
            raise ValueError(f"Missing upstream type color: {key}")
        payload = badge(sources[source_path], color[1])
        target = f"assets/ui/icons/{key}.svg"
        files[target] = payload
        generated[target] = {"source": source_path, "color": color[1], "size": [32, 32], "sha256": digest(payload)}
    if args.check:
        for path, payload in files.items():
            if not (ROOT / path).exists() or (ROOT / path).read_bytes() != payload:
                raise ValueError(f"Generated badge differs: {path}")
        if lock["generated"] != generated:
            raise ValueError("Generated badge manifest differs")
        print(f"Verified {len(sources)} pinned sources and {len(files)} reviewed type badges (offline).")
    else:
        for path, payload in files.items():
            (ROOT / path).write_bytes(payload)
        lock["generated"] = generated
        LOCK.write_text(json.dumps(lock, indent=2) + "\n")
        print(f"Built {len(files)} reviewed 32px type badges.")


if __name__ == "__main__":
    main()
