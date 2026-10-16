#!/usr/bin/env python3
"""Pin and verify Gen 1–3 cries. Network is used only with --download."""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/audio/cries'
COMMIT = 'b3a9044bb839b5e3152aaa536c7b463a0fcf0140'
BASE = f'https://raw.githubusercontent.com/PokeAPI/cries/{COMMIT}'
PREVIEW = ROOT / 'docs/audio/cries-preview.mp3'
SAMPLE_IDS = [1, 4, 7, 25, 133, 152, 155, 158, 252, 255, 258, 150, 249, 384]

def sha(data):
    return hashlib.sha256(data).hexdigest()

def fetch(url):
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                return response.read()
        except (urllib.error.URLError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(0.5 * (attempt + 1))

def inspect(path):
    data = path.read_bytes()
    assert data.startswith(b'OggS'), f'{path}: not Ogg'
    # Fully decode every file, including the end, rather than trusting headers.
    pcm = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 's16le',
                          '-ar', '22050', '-ac', '1', '-'], check=True, capture_output=True)
    assert not pcm.stderr, f'{path}: {pcm.stderr.decode()}'
    duration = len(pcm.stdout) / 44100
    assert 0.1 < duration < 10 and any(pcm.stdout), f'{path}: invalid/silent cry'
    return {'id': int(path.stem), 'bytes': len(data), 'sha256': sha(data),
            'decoded_pcm_sha256': sha(pcm.stdout), 'duration': round(duration, 6)}

def download_one(species):
    target = DEST / f'{species}.ogg'
    content = fetch(f'{BASE}/cries/pokemon/latest/{species}.ogg')
    source_sha = sha(content)
    converted = not content.startswith(b'OggS')
    if converted:
        # Upstream #025 has an MP3 bitstream despite its .ogg filename.
        # Normalize containers for Godot's Ogg importer; record both hashes.
        result = subprocess.run(['ffmpeg', '-v', 'error', '-i', 'pipe:0', '-c:a', 'libvorbis',
                                 '-q:a', '5', '-f', 'ogg', 'pipe:1'], input=content,
                                check=True, capture_output=True)
        content = result.stdout
    assert content.startswith(b'OggS'), f'Unexpected content for {species}'
    target.write_bytes(content)
    return {'id': species, 'source_sha256': source_sha, 'container_normalized': converted}

def preview():
    with tempfile.TemporaryDirectory(prefix='pokemon-cries-') as temp:
        pcm = bytearray()
        for species in SAMPLE_IDS:
            result = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(DEST / f'{species}.ogg'),
                                     '-f', 's16le', '-ar', '22050', '-ac', '1', '-'],
                                    check=True, capture_output=True)
            pcm.extend(result.stdout)
            pcm.extend(bytes(22050))  # half second between complete, uncut cries
        raw = Path(temp) / 'preview.pcm'
        raw.write_bytes(pcm)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', '22050', '-ac', '1',
                        '-i', str(raw), '-codec:a', 'libmp3lame', '-b:a', '96k', str(PREVIEW)], check=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if not args.download and not args.check:
        parser.error('Choose --download or --check; verification never needs network access.')
    if args.download:
        DEST.mkdir(parents=True, exist_ok=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            sources = list(pool.map(download_one, range(1, 387)))
        for name in ['README.md', 'LICENSE']:
            (DEST / ('UPSTREAM_' + name)).write_bytes(fetch(f'{BASE}/{name}'))
    paths = sorted(DEST.glob('*.ogg'), key=lambda path: int(path.stem))
    assert [int(p.stem) for p in paths] == list(range(1, 387)), 'Expected exactly #001–386'
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        rows = list(pool.map(inspect, paths))
    manifest_path = DEST / 'manifest.json'
    if args.download:
        preview()
        manifest = {'repository': 'https://github.com/PokeAPI/cries', 'commit': COMMIT,
                    'variant': 'latest', 'source_pattern': f'{BASE}/cries/pokemon/latest/{{id}}.ogg',
                    'files': rows, 'sources': sources, 'upstream_readme_sha256': sha((DEST / 'UPSTREAM_README.md').read_bytes()),
                    'upstream_license_sha256': sha((DEST / 'UPSTREAM_LICENSE').read_bytes()),
                    'preview_ids': SAMPLE_IDS, 'preview_sha256': sha(PREVIEW.read_bytes())}
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    else:
        manifest = json.loads(manifest_path.read_text())
        assert manifest['files'] == rows, 'Asset or decoded PCM differs from pinned manifest'
        assert manifest['commit'] == COMMIT and manifest['preview_ids'] == SAMPLE_IDS
        assert manifest['source_pattern'] == f'{BASE}/cries/pokemon/latest/{{id}}.ogg'
        assert [entry['id'] for entry in manifest['sources']] == list(range(1, 387))
        for source, included in zip(manifest['sources'], rows):
            assert len(source['source_sha256']) == 64
            if not source['container_normalized']:
                assert source['source_sha256'] == included['sha256']
        for key, path in [('upstream_readme_sha256', DEST / 'UPSTREAM_README.md'),
                          ('upstream_license_sha256', DEST / 'UPSTREAM_LICENSE'),
                          ('preview_sha256', PREVIEW)]:
            assert manifest[key] == sha(path.read_bytes()), f'Changed {path}'
    print(f'CRIES: {len(rows)} pinned, fully decoded files; {sum(r["bytes"] for r in rows)} bytes; preview verified')

if __name__ == '__main__':
    main()
