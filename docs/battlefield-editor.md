# 배경 위치를 직접 수정하는 HTML

[HTML 파일 다운로드 · 약 28MB](https://github.com/agree-git/pokemon-deckbuilder/raw/refs/heads/background-review-2026-10-16/pokemon-background-editor.html?download=1) · [ZIP 다운로드](https://github.com/agree-git/pokemon-deckbuilder/raw/refs/heads/background-review-2026-10-16/pokemon-background-editor.zip) · [미리보기](https://github.com/agree-git/pokemon-deckbuilder/blob/background-review-2026-10-16/editor-preview.png)

사용자가 배경을 보며 직접 위치를 옮기기 위해 요청한 **독립 HTML 파일**이다. ZIP에도 같은 HTML이 들어 있다. 다운로드한 HTML을 JavaScript를 지원하는 브라우저로 열면 된다. GitHub 파일 보기 화면 자체에서 실행되는 사이트는 아니다.

## 사용

1. 위에서 배경을 선택한다. 바이옴 18개·사천왕 타입 룸 18개·챔피언/공용 룸 12개, 총 48개 고유 배경이다. 같은 타입 룸을 공유하는 사천왕 이름은 함께 표시한다.
2. 포켓몬을 드래그한다. 또는 ‘내 포켓몬 선택’/‘상대 포켓몬 선택’을 누르고 배경의 발판 중심을 누른다. ‘포켓몬’을 끄면 발판과 접지점만 보며 맞출 수 있다. 마우스와 터치를 지원한다.
3. 숫자로 미세 조정하거나 화면에 초점을 둔 채 방향키로 1px, Shift+방향키로 5px 이동한다. 숫자는 1920px 화면 좌표가 아닌 **768px 폭의 배경 셀 내부 좌표**다. 포켓몬 종류는 386종 앞/뒤를 모두 선택할 수 있으며 크기 확인용이다.
4. **게임 구도 미리보기**로 바꿔 카메라·정수 배율·접지·UI 영역을 확인한다. 실제 게임과 같은 아군 기준 높이 565px를 사용하므로 배경이 함께 이동한다. 실수로 좌표를 바꾸지 않도록 이 모드에서는 편집을 막는다. ‘배경 보며 수정’으로 돌아가면 배경을 고정해 전체를 보며 다시 수정한다.
5. **수정 좌표 JSON 저장**을 누른다. 모든 배경의 현재 좌표가 `battlefield_layouts.json` 하나에 들어 있다. 다른 배경을 선택해도 이전 수정은 남는다. JSON을 다시 불러와 이어서 수정할 수 있다. 되돌리기·다시 하기·현재 배경 초기화·전체 좌표 CSV·1920×1080 미리보기 PNG도 제공한다.
6. 내려받은 JSON을 전달하면 그 좌표를 게임에 적용할 수 있다. 직접 적용하려면 게임을 종료하고 프로젝트의 `data/battlefield_layouts.json`을 교체한 뒤 다시 실행한다. 실행 중에는 정적 캐시가 있으므로 종료 후 다시 실행해야 한다.

브라우저가 허용하면 임시 자동 저장을 사용한다. 허용하지 않아도 편집/다운로드는 가능하며 상태줄에 표시한다. 중요한 수정은 JSON으로 저장한다. 모바일 파일 미리보기 앱에서 실행되지 않으면 내려받은 HTML을 브라우저로 연다. 실제 iOS/Safari는 검증하지 않았다.

## 범위와 재현

현재 좌표를 초기값으로 담는다. 이 도구 제공 자체가 위치 수정 완료나 검수 승인을 의미하지 않는다. 게임 좌표·PNG·원정·저장·전투 규칙은 바꾸지 않았다. 사천왕 룸은 같은 타입 후보 전체가 공유한다.

배경 8개 아틀라스와 386종 앞·뒤 772개 PNG를 원본 그대로 base64로 포함한다. 외부 CDN·요청·서버가 필요 없다. UI는 겹침 확인용 단순 가이드이며 실제 게임 UI를 브라우저에서 실행하는 것은 아니다. 스프라이트는 게임과 같은 불투명 영역 하단 중앙을 접지점에 맞춘다. 종별 실제 발/꼬리/비행 자세의 차이는 별도 규칙을 추가하지 않았다.

```bash
python3 tools/build_battlefield_editor.py /tmp/pokemon-background-editor.html
python3 tools/test_battlefield_editor.py /tmp/pokemon-background-editor.html
```

생성은 Python 표준 라이브러리만 사용한다. 개발용 브라우저 검사는 Playwright Python과 Chromium이 필요하다. 선택적으로 `--chromium <실행파일>`을 지정한다. `--godot-reference <실제 촬영 manifest.json>`을 주면 48종 전체의 화면 접지점·스프라이트 배율을 실제 Godot 촬영 메타데이터와 비교한다.

큰 생성 HTML/ZIP/미리보기는 `background-review-2026-10-16` 검토 브랜치에, 작은 재현 소스·검사는 `main`에 보관한다. 브라우저 편집 화면은 게임 스크린샷 갤러리와 구분한다. 기존 갤러리·ZIP·CSV는 사용자 지적 이전의 촬영본이며 이번 HTML 제작으로 재촬영하거나 덮어쓰지 않았다.
