# 현재 작업 인계

- 직전 수정: 기술 훈련 검색창에서 한 글자만 입력되는 문제. 사용자가 **한국어에서만 발생**한다고 확인했다. **최신 요청 “릴리스”로 v0.28.7 준비·수동 GitHub 빌드·게시 승인.** 빌드는 명시 요청 때 GitHub에서만,로컬 build/export/ZIP 금지.
- 게임 `71d914e5ca816e4c439a2b38d63bdfa339c96340`. [검색·한글 조합 지도](docs/workshop-search.md)부터 읽는다.
- PokedexWorkshop의 text_changed는query/예약만,다음 process에서 has_ime_text가 false인 확정 시점에 실제 검색 문자열로 필터한다. 조합 중 기다리며 LineEdit.text·focus·caret를 덮어쓰지 않는다.
- 탭별 항목은populate에서 한 번 생성. 검색은 search_terms에 따라visible만 변경,버튼·빈 안내 Label 삭제/재생성 없음. 이름·번호·타입/진화·폼·훈련·TM에 동일 적용. 명시적인 탭/동료/기술 변경은rebuild 유지.
- 원정 다시하기 제거/자동 진화/훈련100·200골드·행동 독립/TM/야영 출발×1.1 복리 경제/저장·RNG·게시JSON/승인파티/배경좌표 유지. 버전만0.28.7로갱신,이전태그·게시JSON 불변.

## 실제 검사와 한계

- 공식4.7.2 격리headless `tests/test_workshop_search.gd` **21/0**,깨끗한 종료. 실제 원정 UI 연구창에서 확정 한글 입력·포커스/커서·Control ID,숫자 키·전체선택/편집·삭제·복원/검색필터·빈안내/TM/Esc/저장·RNG 불변. `/tmp/pokemon-workshop-search/after.log`.
- **Windows IME 실제 조합은 재현/검증 못했다.** 최초 headless 확정 Unicode 입력은 수정 전에도4/0. 실제 IME 해결을 단정하지 않는다. 조합 중 UI 갱신을 피하고 결과 노드를 유지하는 대응을 반영했다.
- 중간 검사 실패는 지연 text_changed 타이밍과 피카츄 Lv.1 전광석화 fixture 기대값을 정리했다. 기존 training_economy/native_pokedex/native_workshop_compact의 visible 결과·폐기 액션 참조만 갱신,그 넓은 검사들은 재실행하지 않았다.
- 전체919/69전투/실제 창·Windows IME/Windows EXE/빌드/export/CI·새 릴리스 미실행.

## 다음 단계

- v0.28.7 lightweight 태그는 위 게임 SHA. main의 별도 workflow 설정 커밋이 게임·자료 SHA/버전을 기본값으로 지정한다. [릴리스 지도](docs/github-releases.md),[노트](docs/releases/v0.28.7.md).
- 현재 새 dispatch/게시 도구가 없어 준비·push 뒤 사용자가 Windows release에서 main·기본값 그대로 **새 Run workflow**를 눌러야 한다. 아직 새 Windows 실행/게시 미완료. 다음은 실행 GET 상태·실패 로그 확인.
- GET으로 v0.28.6 게시 완료 확인. 해당 태그/배포는 동결. **Windows IME 실제 조합은 여전히 미검증**이며 native 실행 검사와 구분한다.
- 이전 [고정 인계](https://github.com/agree-git/pokemon-deckbuilder/blob/e0bac38a2e688218dd891858fa7ebba933f1a471/HANDOFF.md)에 재시작 제거11/0·기존 작업 근거 보관. ASSET_SOURCES.md·CHANGELOG.md 복구금지,DO·기존 엔딩 양식 유지.
