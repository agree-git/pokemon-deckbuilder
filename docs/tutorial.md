# 첫 플레이 실습 튜토리얼

시작 화면의 재실행 버튼과 최초새원정의 선택형권유를 추가했다. 11안내단계에서 실제카드/버튼으로 예고→비용/호버→자동교대→보호막→턴종료→별도포획→야영휴식→다른야영강화를 연습한다. 마지막에 가방/장비/TM/연구와 목표/단축키를 안내한다. 사용자가 건너뛰거나 나갈 수 있고 기존 이어하기는 바뀌지 않는다.

## 최소 수정 지도

- `scenes/tutorial.tscn`,`scripts/ui/tutorial_ui.gd`: 연습별상태/화면전환,현재목표 테두리·안내,완료화면. 캠프 안내는2줄로 유지하고 모든문구의실제행높이를 검사한다.
- `scripts/content/tutorial_lesson.gd`: 실제v28원정/효과19의 엔진을 사용하는 버려지는fixture. 고정손패·연습상대·포획용HP·야영부상/건강상태만 준비한다. 난도/성장 입력을 변경하지 않는다.
- `scripts/ui/tutorial_battle_view.gd`,`tutorial_camp_view.gd`: 일반 UI를 상속해 안내한 행동만 허용한다. 기본엔진/기존원정에 제한을 추가하지 않는다. 재시작은연습만재시작한다. 빠른화면전환의 지연입장콜백은트리밖에서울음소리를재생하지않도록막는다.
- `scripts/ui/main_menu.gd`: 첫새원정의 선택형권유/건너뛰기/상시연습버튼. 기존이어하기가우선유지된다.
- `scripts/preferences.gd`: 설정 `[tutorial] status`의new/skipped/completed만저장. 예전설정/잘못된값은new. 원정지문/routev28/효과19/게시JSON/기존저장·파티·경험치·경제·배경좌표는변경없다.

연습은 `BattleSession.adopt_journey`/profile기록을 호출하지 않고 `session.tracks(practice)==false`다. 연습저장은없다. 완료시스타팅선택은 `open_starter_selection`만지정하며출발확정전까지기존원정을유지한다. 연습단계를영구저장하지않으며재실행은처음부터다.

## 실제 검증

- 격리XDG `/tmp/pokemon-tutorial-review/`,Godot4.7.2/X11/1920×1080/실제XTest입력으로 `tests/native_tutorial.gd`최종 **76/0·21 OS클릭**,로그SCRIPT ERROR/ERROR/리소스누수없음. 기존자동저장원정을별도로만든뒤전체스냅샷/RNG와실제저장바이트/도감이연습전체·완료·스타팅이동·재실행/나가기·건너뛰기에도동일함을확인했다. 완료/건너뛰기는실제설정재읽기도통과했다.
- 초기에검사인자형/겹친GUI드라이버를정리했고,야영상속메서드의인자형과지연연출·초기미부착노드누수를수정했다. 남은캠프부분확인뒤최종전체튜토리얼을한번묶어서통과시켰다. 이전실패/중간46개결과를최종성공으로세지않는다.
- PNG6개시각검사에서야영안내의마지막줄잘림을발견해2줄로줄였다. 그뒤 `TUTORIAL_REVIEW_PHASE=layout` **12/0**,11단계의실제line_count×line_height가표시높이안에드는지확인하고야영PNG를갱신했다. 전체클릭은반복하지않았다.
- `TUTORIAL_REVIEW_PHASE=camp`는야영이후만재현하는실패범위확인용이다. 기본실행은처음권유부터끝까지진행한다. 한디스플레이에는드라이버한개만실행하고에러로중단한과거프로세스를정확한script인자로종료한뒤재시도한다.
- `tests/test_export.gd`에는배포튜토리얼/야영하위UI구성·실제첫카드사용가능·원정불변의작은3검사를추가했다. 최종배포결과는인계를본다. 전체919/69전투/과거전체창검사는반복하지않는다.

`source env.sh`,`source enable-display.sh`후격리XDG와함께 `python3 .dev-materials/tools/native_pointer.py --project-dir . --script .dev-materials/tests/native_tutorial.gd`로재현한다. PNG/개인저장/긴로그/캐시/EXE는커밋하지않는다. 발표노트는 `docs/releases/v0.28.1.md`다.
