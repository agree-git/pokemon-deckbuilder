# Original synthesized effects

These short effects are generated specifically for this project by
`tools/generate_sound_effects.py`, using Python's standard library. No audio is
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
