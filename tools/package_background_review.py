#!/usr/bin/env python3
"""Verify the complete rendered review, then build an offline gallery and ZIP."""
import argparse
from collections import Counter
import csv
import hashlib
import html
import json
import math
from pathlib import Path
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
GROUPS = {'biomes': '바이옴', 'elite': '사천왕', 'champions': '챔피언', 'reserve': '예비 룸'}


def verify(folder):
    manifest = json.loads((folder/'manifest.json').read_text())
    layout_bytes = (ROOT/'data/battlefield_layouts.json').read_bytes()
    if manifest.get('floor_layout_sha256', hashlib.sha256(layout_bytes).hexdigest()) != hashlib.sha256(layout_bytes).hexdigest():
        raise ValueError('Capture used a different floor coordinate file')
    rows = manifest['captures']
    league = json.loads((ROOT/'data/league.json').read_text())
    biomes = json.loads((ROOT/'data/biomes.json').read_text())
    backdrops = json.loads((ROOT/'data/battle_backdrops.json').read_text())
    expected = {(b['background'], b['cell']) for b in biomes}
    expected.update((b['background'], b['cell']) for b in backdrops['elite'].values())
    expected.update((b['background'], b['cell']) for b in backdrops['champions'].values())
    expected.add((backdrops['fallback_champion']['background'], backdrops['fallback_champion']['cell']))
    if manifest['failures'] or len(rows) != 65 or {(r['background'], r['cell']) for r in rows} != expected:
        raise ValueError('Missing or failed background captures')
    actual = {group: {r['key'] for r in rows if r['category'] == group} for group in GROUPS}
    if (actual['biomes'] != {b['type'] for b in biomes}
            or actual['elite'] != {t['id'] for t in league['elite']}
            or actual['champions'] != {t['id'] for t in league['champions']}
            or len(actual['reserve']) != 5
            or len({r['file'] for r in rows}) != 65):
        raise ValueError('Missing or duplicate biome/trainer/champion identities')
    for row in rows:
        path = folder/row['file']
        if not path.resolve().is_relative_to(folder.resolve()):
            raise ValueError('Screenshot must stay inside the gallery')
        payload = path.read_bytes()
        if (payload[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', payload[16:24]) != (1920, 1080)
                or hashlib.sha256(payload).hexdigest() != row['sha256'] or row['resolution'] != [1920, 1080]):
            raise ValueError(f'Invalid or changed 1920x1080 screenshot: {path}')
        if row['active'] != (row['category'] != 'reserve'):
            raise ValueError('Reserved room must not be presented as active content')
        if row.get('floor_guide'):
            guide = folder/row['floor_guide']
            if not guide.resolve().is_relative_to(folder.resolve()):
                raise ValueError('Guide must stay inside the gallery')
            payload = guide.read_bytes()
            if (payload[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', payload[16:24]) != (1920,1080)
                    or hashlib.sha256(payload).hexdigest() != row['guide_sha256']):
                raise ValueError(f'Invalid floor guide: {guide}')
            layouts = json.loads((ROOT/'data/battlefield_layouts.json').read_text())
            profile = layouts['backgrounds'][row['background']][int(row['cell'])]
            if row['floor_layout'] != profile:
                raise ValueError('Capture does not match current floor calibration')
            origin_y = math.floor(layouts['ally_screen_y'] - profile['ally'][1]*2.5)
            for side in ('ally', 'enemy'):
                expected_point = [profile[side][0]*2.5, origin_y+profile[side][1]*2.5]
                if any(abs(a-b) > .01 for a,b in zip(row['screen_feet'][side],expected_point)):
                    raise ValueError('Sprite feet and artwork projection differ')
    for group in GROUPS:
        if not (folder/'sheets'/f'{group}.png').is_file():
            raise ValueError(f'Missing contact sheet: {group}')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    folder = args.directory.resolve()
    manifest = verify(folder)
    (folder/'battlefield_layouts.json').write_bytes((ROOT/'data/battlefield_layouts.json').read_bytes())
    rows = manifest['captures']
    counts = Counter(row['category'] for row in rows)
    names = {t['key']: t['name'] for t in json.loads((ROOT/'data/catalog.json').read_text())['types']}
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    cards = []
    for index, row in enumerate(rows):
        caption = html.escape(row['title'])
        tags = html.escape(' · '.join(filter(None, (GROUPS[row['category']], row['region'], names[row['type']], '' if row['active'] else '예비'))))
        search = html.escape((' '.join(str(row[k]) for k in ('title', 'type', 'region', 'key')) + ' ' + names[row['type']]).lower())
        cards.append(f'<article data-group="{row["category"]}" data-search="{search}">'
                     f'<a href="{row["file"]}" data-index="{index}"><img src="{row["file"]}" loading="lazy" width="480" height="270" alt="{caption}"></a>'
                     f'<h2>{caption}</h2><p>{tags}</p></article>')
    options = ''.join(f'<option value="{key}">{name} {counts[key]}장</option>' for key, name in GROUPS.items())
    sheets = ' · '.join(f'<a href="sheets/{key}.png">{name} 모음</a>' for key, name in GROUPS.items())
    page = '''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>포켓몬 전투 배경 전체 검토</title><style>
*{box-sizing:border-box}body{margin:0;background:#0b171d;color:#e8ede7;font-family:system-ui,sans-serif}header{padding:24px;max-width:1500px;margin:auto}h1{font-size:28px}p{line-height:1.6;color:#acc0c4}a{color:#e9ce89}nav{position:sticky;top:0;z-index:1;display:flex;gap:12px;padding:14px 24px;background:#10252dee}select,input,button{font:inherit;background:#213b43;border:1px solid #69858a;color:#fff;padding:10px;border-radius:7px}input{flex:1;min-width:120px}#grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,400px),1fr));gap:20px;max-width:1500px;margin:auto;padding:24px}article{border:1px solid #304d55;border-radius:10px;overflow:hidden;background:#12272e}article img{width:100%;height:auto;display:block}h2{font-size:18px;margin:14px 16px 6px}article p{margin:0 16px 16px}article[hidden]{display:none}dialog{background:#0b171d;color:white;border:1px solid #69858a;border-radius:10px;padding:12px;width:min(96vw,1800px);max-width:96vw}dialog::backdrop{background:#000d}dialog img{display:block;width:100%;height:auto;max-height:80vh;object-fit:contain}dialog footer{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin-top:12px}#caption{flex:1}small{color:#9bafaf}
</style><header><h1>포켓몬 전투 배경 전체 검토 · 65장</h1>
<p>바이옴 18곳 · 사천왕 후보 31명 · 챔피언 후보 11명 · 예비 룸 5개. 같은 룸을 공유하는 사천왕도 모두 촬영했습니다.<br>
모든 원본은 Godot 실제 전투 UI의 1920×1080 스크린샷입니다. 고정 파티를 사용하는 검토용 장면이며 원정 플레이 기록은 아닙니다. 현재 연결된 배경 43종과 예비 5종을 모두 포함합니다.</p>
<p>이미지를 누르면 원본을 크게 볼 수 있습니다. ← → 이동, Esc 닫기. 인터넷 연결 없이 사용할 수 있습니다.</p><p>__SHEETS__ __COORDINATES__</p>
<small>화면/UI 1920×1080 · 배경은 작은 도트 원본을 확대해 표시합니다. 예비 룸은 현재 실제 상대에 배정되지 않습니다.</small></header>
<nav><select id="group"><option value="all">전체 65장</option>__OPTIONS__</select><input id="search" placeholder="이름 · 지방 · 타입 검색" aria-label="화면 검색">__GUIDE_TOGGLE__<span id="count"></span></nav>
<main id="grid">__CARDS__</main><dialog id="viewer"><img id="full" alt=""><footer><button id="prev">← 이전</button><span id="caption"></span><a id="download" download>원본 PNG 저장</a><button id="next">다음 →</button><button id="close">닫기</button></footer></dialog>
<script>
const rows=__ROWS__, articles=[...document.querySelectorAll('article')], group=document.querySelector('#group'), search=document.querySelector('#search'), viewer=document.querySelector('#viewer'), guides=document.querySelector('#guides');let current=0;
function source(r){return guides?.checked&&r.floor_guide?r.floor_guide:r.file;}
function filter(){let total=0;for(const a of articles){a.hidden=!((group.value==='all'||a.dataset.group===group.value)&&a.dataset.search.includes(search.value.toLowerCase()));if(!a.hidden)total++;}document.querySelector('#count').textContent=total+'장';}
function show(i){current=i;const r=rows[i];document.querySelector('#full').src=source(r);document.querySelector('#full').alt=r.title;document.querySelector('#caption').textContent=(i+1)+'/65 · '+r.title;document.querySelector('#download').href=source(r);if(!viewer.open)viewer.showModal();}
if(guides)guides.onchange=()=>{articles.forEach((a,i)=>a.querySelector('img').src=source(rows[i]));if(viewer.open)show(current);};
function step(d){const visible=articles.flatMap((a,i)=>a.hidden?[]:[i]);if(!visible.length)return;const at=visible.indexOf(current);show(visible[(at+d+visible.length)%visible.length]);}
for(const a of document.querySelectorAll('[data-index]'))a.addEventListener('click',e=>{e.preventDefault();show(Number(a.dataset.index));});group.onchange=filter;search.oninput=filter;document.querySelector('#prev').onclick=()=>step(-1);document.querySelector('#next').onclick=()=>step(1);document.querySelector('#close').onclick=()=>viewer.close();document.addEventListener('keydown',e=>{if(viewer.open&&e.key==='ArrowLeft')step(-1);if(viewer.open&&e.key==='ArrowRight')step(1);});filter();
</script></html>'''
    guide_toggle = '<label><input type="checkbox" id="guides">접지 좌표 보기</label>' if all(r.get('floor_guide') for r in rows) else ''
    coordinates = ''
    if guide_toggle:
        coordinates = ' · <a href="floor_coordinates.csv">접지점 좌표 CSV</a> · <a href="battlefield_layouts.json" download>적용 좌표 JSON</a>'
        with (folder/'floor_coordinates.csv').open('w', encoding='utf-8-sig', newline='') as output:
            writer = csv.writer(output)
            writer.writerow(['이름','배경','셀','아군 원본 X','아군 원본 Y','상대 원본 X','상대 원본 Y','아군 화면 X','아군 화면 Y','상대 화면 X','상대 화면 Y','바닥 구분'])
            seen = set()
            for row in rows:
                key = (row['background'],row['cell'])
                if key in seen: continue
                seen.add(key)
                profile = row['floor_layout']
                writer.writerow([row['title'],*key,*profile['ally'],*profile['enemy'],*row['screen_feet']['ally'],*row['screen_feet']['enemy'],profile['surface']])
    page = page.replace('__COORDINATES__', coordinates).replace('__GUIDE_TOGGLE__', guide_toggle).replace('__SHEETS__', sheets).replace('__OPTIONS__', options).replace('__CARDS__', '\n'.join(cards)).replace('__ROWS__', json.dumps(rows, ensure_ascii=False).replace('<', '\\u003c'))
    (folder/'index.html').write_text(page)
    (folder/'README.txt').write_text(f'전체 전투 배경 검토\n\nindex.html을 브라우저로 열면 검색/분류/확대/원본 저장을 사용할 수 있습니다.\n'
        f'실제 1920x1080 렌더링 65장: 바이옴 18, 사천왕 후보 31, 챔피언 후보 11, 예비 5.\n'
        f'배경 48종 전체(현재 연결 43종 + 예비 5종), 모음 이미지 4장.\n'
        f'고정 파티의 검토용 전투 장면이며 플레이 완주 기록은 아닙니다. 사용자 저장을 읽거나 변경하지 않습니다.\n'
        f'엔진: {manifest["engine"]}\n촬영 시 체크아웃: {revision}\n\n'
        f'screens/: UI 원본 PNG, sheets/: 모음 PNG, manifest.json: 이름/타입/지방/배경 매핑/원본 해시.\n')
    if guide_toggle:
        with (folder/'README.txt').open('a') as output:
            output.write('guides/: 캐릭터와 HUD를 숨긴 접지점 검토 화면 48장. 갤러리의 접지 좌표 보기로 전환합니다.\nfloor_coordinates.csv: 배경 48종의 셀 내부 좌표와 1920x1080 투영 좌표. 발판/바닥을 수동 지정한 값이며 자동 인식 결과가 아닙니다.\nbattlefield_layouts.json: 실제 적용한 전체 좌표 원본.\n')
    archive = folder.with_suffix('.zip')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as target:
        for path in sorted(folder.rglob('*')):
            if path.is_file(): target.write(path, Path(folder.name)/path.relative_to(folder))
    print(f'Verified 65 PNGs, all {len(set((r["background"],r["cell"]) for r in rows))} background cells, four contact sheets.')
    print(f'Gallery: {folder / "index.html"}')
    print(f'ZIP: {archive} ({archive.stat().st_size:,} bytes)')


if __name__ == '__main__':
    main()
