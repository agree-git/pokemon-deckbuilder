# 현재 작업 인계

- 최신 요청: 기술 훈련 검색창에서 한 글자만 입력되는 문제. 사용자가 **한국어에서만 발생**한다고 확인했다. 수정·main 반영만,새 빌드/Release 요청 아님. 빌드는 명시 요청 때 GitHub에서만,로컬 build/export/ZIP 금지.
- 게임 `92d671e70e9ed67cb89b4220a28ebee731048597`. [검색·한글 조합 지도](docs/workshop-search.md)부터 읽는다.
- PokedexWorkshop의 text_changed는query/예약만,다음 process에서 has_ime_text가 false인 확정 시점에 실제 검색 문자열로 필터한다. 조합 중 기다리며 LineEdit.text·focus·caret를 덮어쓰지 않는다.
- 탭별 항목은populate에서 한 번 생성. 검색은 search_terms에 따라visible만 변경,버튼·빈 안내 Label 삭제/재생성 없음. 이름·번호·타입/진화·폼·훈련·TM에 동일 적용. 명시적인 탭/동료/기술 변경은rebuild 유지.
- 원정 다시하기 제거/자동 진화/훈련100·200골드·행동 독립/TM/야영 출발×1.1 복리 경제/저장·RNG·게시JSON/승인파티/배경좌표 유지. 버전/태그/workflow 불변.

## 실제 검사와 한계

- 공식4.7.2 격리headless `tests/test_workshop_search.gd` **21/0**,깨끗한 종료. 실제 원정 UI 연구창에서 확정 한글 입력·포커스/커서·Control ID,숫자 키·전체선택/편집·삭제·복원/검색필터·빈안내/TM/Esc/저장·RNG 불변. `/tmp/pokemon-workshop-search/after.log`.
- **Windows IME 실제 조합은 재현/검증 못했다.** 최초 headless 확정 Unicode 입력은 수정 전에도4/0. 실제 IME 해결을 단정하지 않는다. 조합 중 UI 갱신을 피하고 결과 노드를 유지하는 대응을 반영했다.
- 중간 검사 실패는 지연 text_changed 타이밍과 피카츄 Lv.1 전광석화 fixture 기대값을 정리했다. 기존 training_economy/native_pokedex/native_workshop_compact의 visible 결과·폐기 액션 참조만 갱신,그 넓은 검사들은 재실행하지 않았다.
- 전체919/69전투/실제 창·Windows IME/Windows EXE/빌드/export/CI·새 릴리스 미실행.

## 다음 단계

- 사용자 수정사항 대기. 실제 Windows IME에서 증상이 계속되면 조합 상태/확정·포커스 변화를 그 환경에서 확인해야 한다. 현재 소스에 새 버전/빌드는 포함하지 않았다.
- 준비됐던 v0.28.6 태그=81c600b8afe2be7cba294d1b7086e38d29e2e434는 그대로이며 이번/원정 재시작 제거 수정은 미포함. 다음 릴리스 요청 때 새 버전·태그·게임/자료 SHA를 준비한다.
- 이전 [고정 인계](https://github.com/agree-git/pokemon-deckbuilder/blob/e0bac38a2e688218dd891858fa7ebba933f1a471/HANDOFF.md)에 재시작 제거11/0·기존 작업 근거 보관. ASSET_SOURCES.md·CHANGELOG.md 복구금지,DO·기존 엔딩 양식 유지.
