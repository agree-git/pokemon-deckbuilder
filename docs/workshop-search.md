# 포켓몬 연구 검색·한국어 입력

2026-10-20 사용자: 기술 훈련 검색에 한 글자밖에 입력되지 않으며 **한국어에서만** 발생한다고 확인했다. 이번은 수정·main 반영만,새 빌드 요청 아님.

## 구현

`main/scripts/ui/pokedex_workshop.gd`만 수정한다. `_search_changed`는 query 기록과 process 예약만 한다. `_process`는 LineEdit.has_ime_text()가 참이면 기다리고,조합이 확정되면 실제 search.text를 읽어 결과를 갱신하고 처리를 끈다. IME 조합 신호 안에서 Control 트리를 변경하지 않는다. LineEdit.text를 다시 쓰거나 focus/커서를 강제로 바꾸지 않는다.

목록은 탭/동료/기술 변경 시 populate에서 한 번 만들고 search_terms 메타데이터로 검색한다. `_filter_rows`는 결과 visible/빈 목록 안내/스크롤만 갱신한다. 입력마다 버튼 삭제·새 생성 없음. 빈 안내 Label도 재사용. 이름·번호·타입,진화·폼·훈련·TM 탭 동일 정책. Enter 등으로 마지막 한글 조합이 확정되면 필터를 반영한다.

## 검증과 한계

공식4.7.2 격리headless 소스 `tests/test_workshop_search.gd` **21/0**,깨끗한 종료. 실제 TacticalJourneyUI에서 연구창 열기→확정 Unicode 한글 연속 입력,결과 Control ID·포커스·커서 유지,숫자 물리 키/선택 전체 교체/중간 삽입·삭제/전체 복원/한글 기술명·타입 검색/TM 검색/Esc 닫기/저장·RNG 불변 확인. `/tmp/pokemon-workshop-search/after.log`.

**Windows 한글 IME의 실제 조합 문제는 이 환경에서 직접 재현/검증하지 못했다.** 최초 확정 Unicode만 입력한 headless 기준은 수정 전에도4/0이었다. 따라서 확정 문자 입력 검사를 OS IME 재현 해결 증거로 쓰지 않는다. 대응은 조합 중 시각 갱신 회피와 Control 재사용이다. 중간 검사에서 지연 text_changed보다 일찍 검사한 타이밍·피카츄가 전광석화를 Lv.1에 배우는 fixture 기대값을 고쳤다.

기존 training_economy/native_pokedex/native_workshop_compact의 결과 개수를 visible Panel 기준으로 수정했고 삭제된 진화 액션/훈련 공유 행동 기대값도 정리했으나 해당 넓은 검사는 재실행하지 않았다. 전체 기술/전투/실제 창·Windows IME/EXE/빌드/export/CI·새 릴리스 미실행. 전투·경제·훈련 규칙/저장/게시 JSON 불변.
