# v0.28.8 GitHub 릴리스

2026-10-20 사용자 “릴리스” 요청. **빌드·실제EXE 검사·ZIP 제작·게시 전부 GitHub에서만** 수행한다. 로컬빌드/export·ZIP 제작·전달금지,수동트리거유지.

- 고정게임 `28b346fd994592cd1c4b9bdecc0de2932b2293f6`,새태그 `v0.28.8`. 검사도구·[노트](releases/v0.28.8.md)의 자료SHA는 main workflow기본값에고정한다. 기존v0.28.7태그/릴리스불변.
- 포함: [튜토리얼 입력제한·4카드 가로이동](tutorial-route-ui.md),[검색창 교체·기술가르침·습득우선](workshop-search.md). 가격/경제·자동진화/재시작제거·저장불변.
- 재사용근거: 튜토리얼/이동81/0,검색27/0,Fcitx기본외부조합native9/0. **Linux inline음절손실은미해결,Windows 한글IME는미검증.** 소스/크레딧/실제EXE검사버전기대값만v0.28.8로동기화,전체검사반복안함.
- [Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml) → **새 Run workflow → main → 기본값 그대로 Run workflow**. 과거실행재실행금지.
- 현재연결은 새workflow dispatch/Release게시도구가없다. 준비·push를빌드/게시완료로보고하지않는다. 사용자새실행1회가필요하다.
- runner가공식4.7.2제작·실제Windows EXE검사통과뒤ZIP·SHA256SUMS.txt·windows-native-report.json세첨부를draft에서검증후게시. 실패하면게시하지않는다. `tests/test_export.gd`의버전검사도v0.28.8.
- GitHub GET으로v0.28.7게시/Windows release성공실행39356827911확인. 새v0.28.8실행/게시는아직미실행.
- ASSET_SOURCES.md·CHANGELOG.md복구금지,DO·기존엔딩양식유지.

이전[고정지도](https://github.com/agree-git/pokemon-deckbuilder/blob/5a022b3b8cc7a9ab857abf9575b5da49101fdaaf/docs/github-releases.md)에v0.28.7정보보관.
