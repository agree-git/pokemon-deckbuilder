#!/usr/bin/env python3
"""Compose original eight-bar chiptune loops. Requires Python stdlib and FFmpeg."""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import random
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/audio/music"
RATE = 22050
# Original motifs, harmony and rhythm; no sampled game audio or quoted melodies.
SCORES = {
    "title": (100, [62, 57, 59, 55], [0, 4, 7, 11, 9, 7, 4, 2], "major"),
    "camp": (84, [55, 60, 57, 62], [7, None, 4, 2, 0, None, 4, 7], "major"),
    "battle": (124, [57, 53, 55, 52], [0, 7, 12, 10, 7, 3, 5, 7], "minor"),
    "boss": (138, [50, 46, 48, 45], [12, 7, 8, 7, 3, 5, 7, 10], "minor"),
    "champion": (132, [60, 55, 57, 53], [0, 4, 7, 12, 14, 12, 7, 9], "major"),
}


def compose(key):
    bpm, roots, motif, mode = SCORES[key]
    beat = 60 / bpm
    duration = 32 * beat
    mix = [0.0] * round(duration * RATE)
    noise = random.Random(key)

    def instrument(start, length, midi, gain, kind):
        count = round(length * RATE)
        at = round(start * RATE)
        freq = 440 * 2 ** ((midi - 69) / 12)
        for i in range(min(count, len(mix) - at)):
            t = i / RATE
            p = i / max(1, count - 1)
            envelope = min(1, t / 0.006) * min(1, (length - t) / 0.018)
            if kind == "kick":
                value = math.sin(math.tau * (48 * t + 1.6 * (1 - math.exp(-t * 35)))) * math.exp(-t * 28)
            elif kind == "snare":
                value = noise.uniform(-1, 1) * math.exp(-t * 32)
            elif kind == "hat":
                value = noise.uniform(-1, 1) * math.exp(-t * 95)
            else:
                phase = math.tau * freq * t
                value = math.sin(phase) + (0.16 if kind == "lead" else 0.08) * math.sin(3 * phase)
                envelope *= (1 - p) ** (0.45 if kind == "lead" else 0.7)
            mix[at + i] += value * gain * envelope

    for bar in range(8):
        root = roots[bar % 4]
        chord = [0, 4 if mode == "major" else 3, 7, 12]
        for step in range(8):
            at = (bar * 4 + step / 2) * beat
            pitch = motif[(step + (2 if bar >= 4 else 0)) % 8]
            if pitch is not None:
                instrument(at, beat * 0.46, root + 12 + pitch, 0.095 if key == "camp" else 0.115, "lead")
            instrument(at, beat * 0.42, root + chord[(step + bar) % 4], 0.035, "arp")
            if key != "camp": instrument(at, beat * 0.12, 0, 0.025, "hat")
        for pulse in range(4):
            at = (bar * 4 + pulse) * beat
            instrument(at, beat * 0.75, root - 12 + (7 if pulse == 2 else 0), 0.085, "bass")
            if key in ("battle", "boss", "champion"):
                instrument(at, beat * 0.35, 0, 0.09 if pulse % 2 == 0 else 0.035, "kick" if pulse % 2 == 0 else "snare")
    # Exact silent endpoints keep the repeated waveform from clicking.
    edge = round(RATE * 0.006)
    for i in range(edge):
        mix[i] *= i / edge
        mix[-1 - i] *= i / edge
    assert 0.04 < max(abs(v) for v in mix) < 0.5, key
    pcm = array.array("h", (round(v * 32767) for v in mix))
    if sys.byteorder != "little": pcm.byteswap()
    return pcm.tobytes(), duration


def encode_preview(pcm, path):
    codec = "libmp3lame"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", "pipe:0",
                    "-map_metadata", "-1", "-c:a", codec, "-q:a", "4", "-fflags", "+bitexact", "-flags:a", "+bitexact", str(path)], input=pcm, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    manifest_path = DEST / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if args.check else {}
    preview = bytearray()
    for key in SCORES:
        pcm, duration = compose(key)
        path = DEST / (key + ".wav")
        if not args.check:
            DEST.mkdir(parents=True, exist_ok=True)
            with wave.open(str(path), "wb") as audio:
                audio.setnchannels(1)
                audio.setsampwidth(2)
                audio.setframerate(RATE)
                audio.writeframes(pcm)
        row = {"bpm": SCORES[key][0], "bars": 8, "duration": duration, "pcm_sha256": hashlib.sha256(pcm).hexdigest(), "wav_sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        if args.check:
            assert manifest[key] == row, "Stale score or asset: " + key
            with wave.open(str(path), "rb") as audio:
                assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) == (1, 2, RATE), key
                assert audio.readframes(audio.getnframes()) == pcm, key
            samples = array.array("h", pcm)
            if sys.byteorder != "little": samples.byteswap()
            assert abs(samples[0]) < 100 and abs(samples[-1]) < 100, key
        else: manifest[key] = row
        excerpt = array.array("h", pcm[:6 * RATE * 2])
        if sys.byteorder != "little": excerpt.byteswap()
        fade = round(RATE * 0.025)
        for i in range(fade): excerpt[-1-i] = round(excerpt[-1-i] * i / fade)
        if sys.byteorder != "little": excerpt.byteswap()
        preview.extend(excerpt.tobytes())
        preview.extend(bytes(RATE)) # Half a second of silence between excerpts.
    demo = ROOT / "docs/audio/music-preview.mp3"
    if not args.check:
        encode_preview(bytes(preview), demo)
        manifest["_preview_sha256"] = hashlib.sha256(demo.read_bytes()).hexdigest()
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    else:
        assert hashlib.sha256(demo.read_bytes()).hexdigest() == manifest["_preview_sha256"], "Stale preview"
    print(f"MUSIC: {len(SCORES)} original eight-bar loops {'verified' if args.check else 'generated'}")


if __name__ == "__main__": main()
