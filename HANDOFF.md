# 현재 작업 인계

- 최신요청: **릴리스**(2026-10-20). v0.28.8로준비·main/자료/고정태그push,빌드는GitHub만. 로컬빌드/export/ZIP제작·전달금지. 수동workflow유지.
- 게임고정SHA `28b346fd994592cd1c4b9bdecc0de2932b2293f6`,버전0.28.8,Credit헤더동기화. 실제EXE검사도구의버전기대값도0.28.8. main workflow기본값은새태그/게임/자료SHA를고정한다. 게임태그와도구핀변경커밋을구분한다.
- 포함: [튜토리얼 입력제한/화살표가로4카드](docs/tutorial-route-ui.md),[검색교체·기술가르침·습득기술우선](docs/workshop-search.md). 소스내용은이전c255a3e+버전/인계뿐,UI추가변경없음.
- 자동진화·원정다시하기제거·가르침100/200고정/TM/야영독립·출발복리×1.1/저장·RNG/승인파티·배경·게시JSON불변. ASSET_SOURCES.md·CHANGELOG.md복구금지,DO·기존엔딩양식유지.

## 검증과 한계

- 기존좁은근거재사용: 공식4.7.2 `test_tutorial_route_ui.gd`81/0,`test_workshop_search.gd`27/0. 버전만변경되어재실행하지않음. 로그 `/tmp/pokemon-tutorial-route/{test,search}.log`.
- 실제X11/Xvfb+Fcitx5기본외부조합native9/0. 전광석화/전기·삭제/재입력/확정·포커스/필터/원정불변,스크린샷확인. `native_workshop_korean_ime.gd`/`native_korean_ime.py`,보고서 `docs/reports/2026-10-20-native-korean-ime.json`.
- **Linux inline은9중6실패/기본TextEdit도음절손실재현,Windows Microsoft한글IME는미검증.** 검색교체를해결완료로단정하지않는다. 새릴리스노트에도명시. 기존v0.28.7에는이번입력창교체없음.
- 이번은버전/노트/고정값정적확인만. 전체919기술·69전투/로컬빌드/export/WindowsCI·새릴리스미실행. GitHub GET으로기존v0.28.7게시및release실행39356827911성공확인.

## 다음 한 단계

- [Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml)에서 **새 Run workflow→main→기본값그대로실행** 필요. 현재새dispatch도구없음;과거run재실행은새SHA를쓰지않으므로금지.
- 새실행후GitHub GET으로상태/실패로그·실제EXE보고서/세첨부확인. 빌드·게시완료를미리말하지않는다. 기존v0.28.7태그71d914e/릴리스는수정·재사용하지않는다.
- 이전상세[고정인계](https://github.com/agree-git/pokemon-deckbuilder/blob/5a022b3b8cc7a9ab857abf9575b5da49101fdaaf/HANDOFF.md)에기능/검사근거보관.
