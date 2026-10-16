# Audio sources

## Original synthesized effects

These short effects are generated specifically for this project by
`tools/generate_sound_effects.py`, using Python's standard library. These effects are not
downloaded or sampled from another game. Pokemon sprites and other external
visual assets retain their separate provenance.

- Format: mono, 44,100 Hz, signed 16-bit PCM WAV, no loops.
- Rebuild: `python3 tools/generate_sound_effects.py`.
- Verify exact reproducibility, format, peak headroom and fades:
  `python3 tools/generate_sound_effects.py --check`.
- Review montage: `docs/audio/effects-preview.wav`.
- Usage and playback phases: `docs/audio.md`.

Generation uses private seeded noise sources. Runtime playback has no random
pitch changes and does not consume the expedition's RNG.

## Original music

Five original eight-bar PCM WAV loops live in `music/`, with independent motifs,
harmony and rhythm. Rebuild with `python3 tools/generate_music.py` (Python and
FFmpeg for the mobile MP3 preview); verify PCM, file hashes and preview integrity
with `python3 tools/generate_music.py --check`. The tracked Godot import files
enable forward loops and retain uncompressed PCM. See `docs/music.md`.

## Imported Pokémon cries

`cries/` contains #001–386 from the pinned PokéAPI/cries `latest` set, not original
project recordings. Audio copyright belongs to The Pokémon Company according to
the preserved `cries/UPSTREAM_LICENSE`; see `cries/UPSTREAM_README.md` for upstream
sources. `manifest.json` records original and included hashes, the one container
conversion (#025 MP3 → Ogg), decoded PCM hashes, lengths and preview integrity.
Download with `python3 tools/fetch_pokemon_cries.py --download`; verify offline with
`--check`. Runtime uses only bundled files. See `docs/cries.md`.
