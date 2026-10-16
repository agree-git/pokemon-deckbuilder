#!/usr/bin/env python3
"""Rebuild original, deterministic PCM effects; no downloaded audio or runtime RNG."""
from pathlib import Path
import argparse
import hashlib
import math
import random
import struct
import wave

RATE = 44100
ROOT = Path(__file__).resolve().parents[1]


def note(freq, duration, amplitude=0.24, end=None, texture="sine", seed=0):
    noise = random.Random(seed)
    result = []
    phase = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        p = t / duration
        hz = freq + ((end if end is not None else freq) - freq) * p
        phase += hz / RATE
        envelope = min(1.0, t / 0.008) * min(1.0, (duration - t) / 0.025)
        envelope *= (1.0 - p) ** 0.4
        tone = math.sin(phase * math.tau)
        if texture == "pixel":
            tone = 0.8 * tone + 0.14 * math.sin(3 * phase * math.tau)
        elif texture == "noise":
            tone = 0.35 * tone + 0.65 * noise.uniform(-1.0, 1.0)
        result.append(tone * amplitude * envelope)
    return result


def phrase(*notes):
    result = []
    for freq, duration in notes:
        result += note(freq, duration, texture="pixel")
    return result


def effects():
    return {
        "ui_click": note(780, 0.045, 0.12, end=560, texture="pixel"),
        "card_play": note(350, 0.10, 0.18, end=800, texture="noise", seed=1),
        "attack": note(170, 0.13, 0.24, end=520, texture="noise", seed=2),
        "hit": note(185, 0.12, 0.40, end=60, texture="noise", seed=3),
        "block": phrase((1000, 0.045), (720, 0.09)),
        "shield": phrase((392, 0.07), (587.33, 0.08), (783.99, 0.13)),
        "heal": phrase((523.25, 0.08), (659.25, 0.08), (783.99, 0.16)),
        "recall": note(960, 0.22, 0.22, end=180, texture="pixel"),
        "release": note(180, 0.23, 0.22, end=1080, texture="pixel"),
        "status": phrase((440, 0.06), (415.3, 0.06), (440, 0.10)),
        "knockout": phrase((293.66, 0.08), (220, 0.09), (146.83, 0.14)),
        "capture": phrase((523.25, 0.09), (659.25, 0.09), (783.99, 0.09), (1046.5, 0.20)),
        "turn": note(330, 0.09, 0.14, end=440, texture="pixel"),
        "victory": phrase((523.25, 0.10), (659.25, 0.10), (783.99, 0.10), (1046.5, 0.25)),
        "defeat": phrase((392, 0.13), (311.13, 0.13), (261.63, 0.22)),
    }


def encode(samples):
    # Short fades and conservative peaks leave headroom when several voices overlap.
    return b"".join(struct.pack("<h", round(max(-0.95, min(0.95, value)) * 32767)) for value in samples)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    dest = ROOT / "assets/audio/effects"
    if not args.check:
        dest.mkdir(parents=True, exist_ok=True)
    hashes = set()
    preview = []
    for name, samples in effects().items():
        preview.extend(samples)
        preview.extend([0.0] * round(0.35 * RATE))
        pcm = encode(samples)
        path = dest / f"{name}.wav"
        if args.check:
            with wave.open(str(path), "rb") as audio:
                assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) == (1, 2, RATE), name
                assert audio.readframes(audio.getnframes()) == pcm, name
            assert any(pcm), name
            assert abs(samples[0]) < 0.001 and abs(samples[-1]) < 0.001, name
            assert max(abs(v) for v in samples) < 0.5, name
        else:
            with wave.open(str(path), "wb") as audio:
                audio.setnchannels(1)
                audio.setsampwidth(2)
                audio.setframerate(RATE)
                audio.writeframes(pcm)
        hashes.add(hashlib.sha256(pcm).hexdigest())
    assert len(hashes) == len(effects()), "Effects must be distinct"
    demo = ROOT / "docs/audio/effects-preview.wav"
    if args.check:
        with wave.open(str(demo), "rb") as audio:
            assert audio.readframes(audio.getnframes()) == encode(preview), "Preview is stale"
    else:
        demo.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(demo), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(RATE)
            audio.writeframes(encode(preview))
    print(f"SOUND ASSETS: {len(hashes)} original effects {'verified' if args.check else 'generated'}")


if __name__ == "__main__":
    main()
