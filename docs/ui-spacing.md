# UI 버튼 간격·공간 구성

사용자는 버튼들이 너무 붙어 있어 좁아 보이고 공간을 잘 쓰지 못한다고 요청했다. main `8384c2f`에서 기능 묶음/여백/폭을 함께 정리했다. **새 버전·EXE·export·Windows CI·Release는 재요청까지 보류한다.** 1920×1080,게임 규칙/게시 입력/저장/원정 RNG/배경 좌표/기술 효과/포켓몬 애니메이션은 유지한다.

## 최소 파일 지도

- `scripts/ui/combat_widgets.gd`: `CONTROL_GAP=24`, `row_rect(area,index,count)`는 지정 영역 안의 같은 폭 버튼과24px 간격을 계산한다. 스타일박스에 패딩만 더해 실제 좌표/히트 영역이 겹치는 방식은 쓰지 않는다.
- `tactical_journey_ui.gd`:야영5탭24px. 희귀조우/진화준비와 시간 스위치의 영역을 나눈다. 휴식·강화를1190×400 패널 안에 넣고 출발/다음전투준비는 하단 양끝에 둔다. 유물 열24px/행16px/48px높이,상점 보급품/장비 선택 행24px. 상점카드의 실제 폭을 유지하며 가로 간격을 늘린다.
- `pokedex_workshop.gd`:1600×952 창과40px안쪽여백. 동료/탭24px간격,검색은 전체 폭으로 독립된 줄,기술4슬롯은 별도 줄로폭314px. 결과 행148px/사이24px/본문과행동버튼32px,목록은 제한된 ScrollContainer에 둔다. 기존 검색·Esc·슬롯·기술머신 동작은 그대로다.
- `settings_panel.gd`:1280×880 두 열. 왼쪽화면/연출속도/피격흔들림,오른쪽음량5종/음소거/미리듣기. 설정값·저장·오디오 로직은 유지한다.
- `main_menu.gd`:큰 주행동과 가로2열 보조메뉴,도감 타일24px간격. `journey_deck_panel.gd`:1040×888 창,5필터24px,카드4열/가로40px/세로24px. `starter_loadout_panel.gd`:동료/필터24px,카드가로48px/세로24px.
- `encounter_preparation_panel.gd`:상대 타일은 수에 맞는 제한 폭/최대6개를24px간격으로 배치한다. 카드뷰312px와가로스크롤을위한16px이상 높이를 확보하고 안내/닫기와 분리한다.
- `tactical_ui.gd`:헤더/뽑기·버리기24px,파티 행20px. 전투 메뉴는 유물/일반기능/화면이동·재시작으로 구분하고버튼24px간격. `battle_canvas.gd`의로스터 회피높이도 새 실제패널높이(아군288/상대최대522)에맞췄다. 발/배경원본좌표는 바꾸지 않는다.

## 확인한 범위

`tests/native_ui_spacing.gd`:Godot4.7.2,실제X11 1920×1080/XTest,**1묶음49검사/0실패·18 OS클릭**. 초기 실패·소스 재수정·검사 반복은 없었다. 최종 SCRIPT ERROR/ERROR/누수없음. 기존 llvmpipe VSync 안내만1개다.

- 시작화면/설정/스타팅타일·출발덱/야영/연구/원정덱/장비/상점/전투준비/전투메뉴의 실제위치·간격·히트영역·경계를 확인했다. 설정의 효과음 미리듣기,검색초점Esc,덱 공용필터와팝업전환도 실제 OS 입력으로 확인했다.
- 많은유물31개·지닌물건55개·상인카드/TM은 UI fixture다. 원정의자연획득 상태라는뜻이아니다. 스크롤컨테이너의클리핑/간격/카드·스크롤바높이를 확인했으며 이번묶음에서 휠 탐색/실제구매·아이템소비·기술훈련은 반복하지 않았다. 그 동작은 이번에 바꾸지 않았다.
- 실제 새 원정의 전체snapshot/UID·RNG/저장바이트와복원동일,별도의 실제 챔피언 저장6마리로스터·손패상단과분리/전체snapshot동일도 확인했다. 개인저장/도감에fixture를채택하지않았다.
- PNG7장 생성,시작/설정/야영휴식/연구/덱/전투메뉴6장 직접 시각 확인. 파일은 `/tmp/pokemon-ui-spacing/01-title.png`~`07-battle-menu.png`,로그 `/tmp/pokemon-ui-spacing-native.log`. 커밋하지 않는다.
- 전체919기술/69전투/전종애니메이션/기존전체창/빌드·패키지검사를 반복하지 않았다. 원정v28/효과19/전체정적·동적에셋과 fingerprint 유지.

재현은 기존 `env.sh`/`enable-display.sh`를 source하고 격리된XDG3경로를지정한뒤 `python .dev-materials/tools/native_pointer.py --project-dir . --script .dev-materials/tests/native_ui_spacing.gd`다. 다른환경에서는 재사용한 실제챔피언증거 `/tmp/pokemon-challenge-review/results/seed-2026-false-boss-136.bin`을먼저준비한다. 같은디스플레이의native드라이버는하나만실행한다.
