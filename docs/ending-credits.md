# 엔딩 크레딧

최신 사용자 지시: 제작자는 **DO**. YOUNG의 Another Red Credit.txt를 참고하되 **처음 만든 명예의 전당·스크롤 화면 양식은 유지하고, 역할별 제작자·기여자 내용만 보완**한다. 문서형 상세 창/버튼이나 Name/Version/Website 양식을 게임 화면에 추가하지 않는다.

## 최소 파일 지도

- main `scripts/ui/ending_credits.gd`: 고정 명예의 전당/실제 동료·성적과 오른쪽 자동 스크롤. 부모 화면의 기존 음악을 이어 쓴다.
- main `assets/sources/expedition_credits.json`: 24개 역할/기여자 절. DO/원작/데이터/개별 스프라이트 작가/음악/엔진/글꼴/구성 참고/감사. 실제 사용하는 자료만 기재한다.
- main `Credit.txt`: 같은 역할별 목록과 TRAINER_FAN/EBDX/PokéRogue 원문 고지3개를 수정 없이 보존한다. 외부 텍스트 파일이며 게임 안에 문서 뷰어는 없다. 전체 권리/개별 파일 출처는 ASSET_SOURCES.md와 기존 고지를 유지한다.
- `tactical_journey_ui.gd::_open_credits`: 전체 원정 CLEARED 화면에서 run_id별1회 자동 열기, 결과의 다시 보기. 짧은 원정/패배 제외. 표시 여부는 화면 메모리만 사용하고 저장하지 않는다.
- `main_menu.gd::_open_credits`: 시작 화면 재생. 원정 없이도 열고 닫는다.

Space/버튼 정지·재생, ↑↓/휠 스크롤, Esc/Enter/버튼 결과 복귀. 끝의 감사 문구에서 멈추고 다시 재생 가능. 전체 화면 모달이 하위 클릭/키를 막는다. Esc는 크레딧만 닫고 일시정지 메뉴를 열지 않는다. 다시 보기 버튼은 왼쪽 x96,y886,w340,h62로 성장 패널(y832~972)과 겹치지 않는다.

## 실제 검사

공식Godot4.7.2/1920×1080/Dummy audio, 개인 데이터와 분리한 XDG. 이전 공개 행동의 실제69전 클리어 v27 스냅샷 `/tmp/pokemon-final-20261019/review/final.bin`을 복원했다. 전체69전/919기술을 재실행하지 않았다.

- 최초 크레딧28/0, 위치 수정만7/0. 시험 태그v0.28.3은 미게시 상태로 보존한다.
- 사용자가 보낸 파일을 문서 창 요청으로 잘못 해석해 만든 상세 뷰어는 최신 지시로 제거했다. 그때의72/0은 최종 UI 근거로 쓰지 않는다.
- 최종 역할별 이름/기존 양식 복구 **80검사/0실패, 실제7클릭·4키**. DO/개별 작가/문서 버튼과 메타데이터 양식 없음/기존 버튼 좌표/모든 롤 문구 폭/3동료·69승·통계/하위 재시작 클릭 차단/정지·수동스크롤·끝·재생·건너뛰기/결과·시작 다시보기/짧은원정·패배 제외/정확한 원정·RNG·저장 바이트 불변을 함께 확인했다.
- `/tmp/pokemon-ending-credits/native-cinematic-final.log`와 최종 `01-ending.png`,`02-thank-you.png`,`03-title-credits.png`. 성장 패널 수정은 `04-result-layout.png`.
- 현재 루트 Credit.txt의24절/3원문과 JSON의 일치도 정적으로 확인한다. 배포 도구 `tools/build_windows.py`는 Credit.txt를 source hash/격리snapshot/PCK/외부폴더에 넣고, `tests/test_export.gd`는 packed DO/JSON/원문파일/마지막 정지를 확인한다.

## 필요한 경우만 재실행

`native_pointer.py`는 PATH의 godot을 사용한다. 공식4.7.2를 먼저 PATH에 놓고 격리XDG/1920×1080 DISPLAY를 준비한 다음 `tests/native_ending_credits.gd` 묶음만 실행한다. 레이아웃만 확인할 때 `ENDING_GEOMETRY_ONLY=1`로 작은 위치 검사를 실행한다. 최초 시도는 기본PATH의4.6.3/검사 스크립트 타입 추론 오류로 로드 실패했고, 타입/PATH 수정 뒤4.7.2의 최종 결과만 사용한다.
