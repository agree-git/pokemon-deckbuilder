# 기술 가르침 검색·한글 입력 교체

2026-10-20 사용자가 이전 패치 뒤에도 한국어 입력이 안 된다고 확인했다. 명칭을 **기술 가르침**으로 바꾸고 이미 습득한 기술을 맨 위로 표시하도록 추가 요청했다. 이번은 수정·main 반영만,새 빌드 요청 아님.

## 현재 구현

- `scripts/ui/search_text_input.gd`: LineEdit 대신 TextEdit 기반 단일행 검색. `get_line_with_ime(0)`으로 확정 문자와 현재 조합 음절을 함께 읽고 query_changed를 알린다. 조합 종료까지 기다리던 이전 경로를 제거했다. 조합 중 native 텍스트/포커스/커서를 덮어쓰지 않는다.
- Enter는 native apply_ime으로 명시 확정하고 줄바꿈을 막는다. Ctrl+V/Shift+Insert와 컨텍스트 붙여넣기의 확정된 줄바꿈만 공백 처리한다. TextEdit 자체 편집·선택·Undo/한글 조합은 native 구현을 쓴다.
- `pokedex_workshop.gd`: 입력 알림에서는 query/다음 프레임 예약만,그다음에 최신 조합 포함 query로 visible 결과를 갱신한다. 기존 검색 결과 Control/빈 안내 재사용 유지. 이름·번호·타입/진화·폼·가르침·TM 공통. search.text를 매 입력에 다시 쓰지 않는다.
- 가르침 목록은 learned_skills에 있는 기술 우선,각 묶음 안에서는 기존ID순. 습득 완료 비활성 버튼으로 표시하고 가르침 뒤 rebuild에서도 새 습득 기술이 위에 온다. 합법 목록·가격100/200·야영 행동 독립·TM 소모 방식 불변.
- tab/액션/성공·부족 골드 안내·향후 원정 기록의 사용자 명칭을 기술 가르침으로 바꾸고 PLAY_GUIDE 동기화. 내부 train_move/모드moves/파일 이름은 호환을 위해 유지한다.

## 실제 검사와 중요한 한계

공식4.7.2 격리headless `tests/test_workshop_search.gd` **27/0**,깨끗한 종료. 실제 원정 UI 연구창에서 확정 한글 연속입력/포커스·caret·결과 Control ID,번호키·전체선택/삽입·삭제·복원,기술명·타입/TM검색·Enter 단일행·붙여넣기 평탄화·Esc,표시 명칭·기존 습득기술/새로 가르친 기술 최상단,기존 가격·야영 행동과 검색 중 실제 원정/RNG 불변. `/tmp/pokemon-tutorial-route/search.log`.

**Windows 한글 IME 실기 문제는 이 환경에서 재현/검증하지 못했다.** 확정 Unicode 이벤트 통과를 실제 조합 해결 증거로 쓰지 않는다. 이전 LineEdit+has_ime_text 대기 패치는 사용자 확인상 해결되지 않았고 이번에 교체했다. 필요하면 실제 Windows에서 native 조합/확정·포커스 상태를 확인해야 한다.

초기 TextEdit 준비에서 존재하지 않는 scroll_horizontal_enabled 속성을 제거한 뒤 검사했다. 이전 UI 레이아웃/native 검사·전체 경제·전투/실제 창·Windows IME/EXE/빌드/export/CI·새 릴리스는 반복하지 않았다.
