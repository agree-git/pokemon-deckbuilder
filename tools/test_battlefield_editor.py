#!/usr/bin/env python3
"""Exercise the standalone editor in Chromium, with mouse, touch and downloads.

Requires the development-only Playwright Python package and a Chromium binary.
The generated HTML itself has no dependencies. No server is required by tests:
set_content loads the complete file in a network-offline, storage-denied page.
"""
import argparse
import base64
import csv
import io
import json
from pathlib import Path
import struct
import tempfile

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]


def run(html, chromium, reference=None):
    checks = 0
    errors = []

    def check(condition, message):
        nonlocal checks
        checks += 1
        if not condition:
            raise AssertionError(message)

    def point(page, x, y):
        box = page.locator('#stage').bounding_box()
        return box['x'] + x * box['width'] / 1920, box['y'] + y * box['height'] / 1080

    def ready(page):
        page.wait_for_function('ready')

    def download(page, selector):
        with page.expect_download() as result:
            page.locator(selector).click()
        return Path(result.value.path()).read_bytes()

    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=chromium, args=['--no-sandbox'])
        context = browser.new_context(viewport={'width': 1440, 'height': 1000}, accept_downloads=True, offline=True)
        page = context.new_page()
        page.on('pageerror', lambda error: errors.append(str(error)))
        requests = []
        page.on('request', lambda request: requests.append(request.url))
        page.set_content(html, wait_until='load')
        ready(page)
        original = json.loads((ROOT / 'data/battlefield_layouts.json').read_text())
        check(page.evaluate('layouts') == original, 'Starts with the exact current game data')
        check(page.locator('#room option').count() == 48, 'Every unique room can be selected')
        check(page.locator('#allySpecies option').count() == 386, 'All 386 species are available')
        assets = page.evaluate('DATA.assets')
        check(len(assets) == 780, 'Eight source atlases and 772 original sprites are embedded')
        for path, url in assets.items():
            check(base64.b64decode(url.split(',', 1)[1]) == (ROOT / path.removeprefix('res://')).read_bytes(), 'Source PNG bytes are unchanged: ' + path)
        page.locator('#stage').scroll_into_view_if_needed()
        box = page.evaluate('visibleSprites.ally.box')
        before = page.evaluate('profile().ally')
        x, y = point(page, box['x'] + box['w'] / 2, box['y'] + box['h'] / 2)
        target_x, target_y = point(page, box['x'] + box['w'] / 2 + 80, box['y'] + box['h'] / 2 + 40)
        page.mouse.move(x, y)
        page.mouse.down()
        page.mouse.move(target_x, target_y, steps=8)
        page.mouse.up()
        check(page.evaluate('profile().ally') == [before[0] + 32, before[1] + 16], 'Mouse drag preserves grab offset and correct source-pixel scale')
        page.locator('#undo').click()
        check(page.evaluate('profile().ally') == before, 'Undo restores the complete prior edit')
        page.locator('#redo').click()
        check(page.evaluate('profile().ally') == [before[0] + 32, before[1] + 16], 'Redo restores the drag')
        page.locator('#stage').focus()
        page.keyboard.press('ArrowRight')
        page.keyboard.press('Shift+ArrowDown')
        check(page.evaluate('profile().ally') == [before[0] + 33, before[1] + 21], 'Keyboard fine tuning uses source pixels')
        page.locator('#reset').click()
        check(page.evaluate('layouts') == original, 'Reset affects only the current background')
        page.locator('#enemy').click()
        page.locator('#sprites').uncheck()
        page.locator('#stage').scroll_into_view_if_needed()
        x, y = point(page, 1450, 72 + 215 * 2.5)
        page.mouse.click(x, y)
        check(page.evaluate('profile().enemy') == [580, 215], 'Click without sprites places the selected contact point')
        edited = page.evaluate('layouts')
        exported = json.loads(download(page, '#save'))
        check(exported == edited, 'JSON download contains all 48 rooms and exactly the edits')
        check(page.evaluate('savedSnapshot===JSON.stringify(layouts)'), 'Exported edits do not trigger an unnecessary close warning')
        check('임시 저장 불가' in page.locator('#status').inner_text() or page.evaluate('!storageAvailable'), 'The editor works when localStorage is denied')
        csv_rows = list(csv.reader(io.StringIO(download(page, '#csv').decode('utf-8-sig'))))
        check(len(csv_rows) == 49 and csv_rows[1][6:8] == ['580', '215'], 'CSV contains all rooms and edited enemy coordinates')
        png = download(page, '#picture')
        check(png[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', png[16:24]) == (1920, 1080), 'Preview PNG download keeps native 1920x1080 resolution')
        page.locator('#next').click()
        ready(page)
        page.locator('#allyX').fill('333.3')
        page.locator('#allyX').press('Tab')
        second = page.evaluate('layouts')
        check(second != edited and second['backgrounds'][page.evaluate('DATA.rooms[0].background')][3]['enemy'] == [580, 215], 'Changing rooms preserves earlier edits')
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / 'layout.json'
            file.write_text(json.dumps(edited))
            page.locator('#load').set_input_files(file)
            page.wait_for_function('document.querySelector("#status").textContent.includes("JSON 좌표를 불러왔습니다")')
            check(page.evaluate('layouts') == edited, 'Downloaded JSON imports into the editor without loss')
            bad = json.loads(json.dumps(edited))
            bad['backgrounds'][next(iter(bad['backgrounds']))][0]['ally'] = [-1, 99]
            file.write_text(json.dumps(bad))
            page.locator('#load').set_input_files(file)
            page.wait_for_function('document.querySelector("#status").textContent.startsWith("불러오기 실패")')
            check(page.evaluate('layouts') == edited, 'Invalid imports leave every existing edit intact')
        page.locator('#view').select_option('game')
        check(page.locator('#allyX').is_disabled(), 'Game framing preview prevents accidental coordinate edits')
        page.locator('#stage').scroll_into_view_if_needed()
        x, y = point(page, 700, 600)
        page.mouse.click(x, y)
        check(page.evaluate('layouts') == edited, 'Preview clicks cannot edit the layout')
        page.locator('#view').select_option('edit')
        for i in range(48):
            page.locator('#room').select_option(str(i))
            ready(page)
            check(page.evaluate('visibleSprites.ally.box.w>0 && visibleSprites.enemy.box.h>0'), f'Room {i + 1} loads its backdrop and both sprites offline')
        check(not requests, 'Opening and editing never requests a network asset')
        if reference:
            # Independent reference is actual Godot viewport capture metadata, not
            # another copy of the editor's projection calculations.
            manifest = json.loads(reference.read_text())
            rooms = page.evaluate('DATA.rooms')
            unique = {}
            for row in manifest['captures']:
                unique.setdefault((row['background'], row['cell']), row)
            page.evaluate('layouts=copy(DATA.layout)')
            page.locator('#view').select_option('game')
            for i, room in enumerate(rooms):
                row = unique[(room['background'], room['cell'])]
                page.locator('#room').select_option(str(i))
                ready(page)
                page.locator('#allySpecies').select_option(str(row['party'][0]))
                page.locator('#enemySpecies').select_option(str(row['opponents'][0]))
                ready(page)
                geometry = page.evaluate('visibleSprites')
                for n, side in enumerate(['ally', 'enemy']):
                    actual = geometry[side]
                    check(max(abs(a-b) for a,b in zip([actual['foot']['x'], actual['foot']['y']], row['screen_feet'][side])) < .001, 'HTML game framing agrees with actual Godot feet within Vector2 float precision')
                    check(actual['zoom'] == row['sprite_scales'][n], 'HTML integer sprite scale agrees with actual Godot')
        context.close()
        mobile = browser.new_context(viewport={'width': 390, 'height': 844}, is_mobile=True, has_touch=True, offline=True, accept_downloads=True)
        page = mobile.new_page()
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.set_content(html, wait_until='load')
        ready(page)
        check(page.evaluate('document.documentElement.scrollWidth<=innerWidth'), 'Mobile controls do not overflow the viewport')
        page.locator('#stage').scroll_into_view_if_needed()
        box = page.evaluate('visibleSprites.ally.box')
        before = page.evaluate('profile().ally')
        x, y = point(page, box['x'] + box['w'] / 2, box['y'] + box['h'] / 2)
        end_x, end_y = point(page, box['x'] + box['w'] / 2 + 100, box['y'] + box['h'] / 2 - 50)
        session = mobile.new_cdp_session(page)
        session.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': [{'x': x, 'y': y}]})
        session.send('Input.dispatchTouchEvent', {'type': 'touchMove', 'touchPoints': [{'x': end_x, 'y': end_y}]})
        session.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []})
        after = page.evaluate('profile().ally')
        check(after == [before[0] + 40, before[1] - 20], 'Mobile touch drag uses the same source coordinates at CSS-scaled size')
        page.locator('#enemy').click()
        page.locator('#sprites').uncheck()
        page.locator('#stage').scroll_into_view_if_needed()
        x, y = point(page, 1425, 72 + 220 * 2.5)
        page.touchscreen.tap(x, y)
        check(page.evaluate('profile().enemy') == [570, 220], 'Mobile tap places the selected enemy contact point')
        mobile_export = json.loads(download(page, '#save'))
        check(mobile_export == page.evaluate('layouts'), 'Mobile JSON export includes both touch edits')
        page.screenshot(path='/tmp/pokemon-background-editor-mobile.png', full_page=True)
        check(not errors, 'No browser script errors: ' + repr(errors))
        browser.close()
    print(f'BATTLEFIELD_EDITOR {checks} checks, 0 failures; Chromium desktop + mobile touch, offline embedded assets')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('html', type=Path)
    parser.add_argument('--chromium', default='/usr/bin/chromium')
    parser.add_argument('--godot-reference', type=Path)
    args = parser.parse_args()
    run(args.html.read_text(), args.chromium, args.godot_reference)


if __name__ == '__main__':
    main()
