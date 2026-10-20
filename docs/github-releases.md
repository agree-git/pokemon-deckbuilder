# v0.28.7 GitHub 릴리스

후속 튜토리얼 입력 제한·이동 카드·한글 검색 교체·기술 가르침/습득순 정렬은 main에만 반영했고 이 고정 버전에는 포함되지 않는다. 새 빌드는 다시 사용자 명시 요청을 따른다.

2026-10-20 사용자 “릴리스” 요청으로 준비했다. **빌드·실제 EXE 검사·ZIP 제작·게시 모두 GitHub에서만** 수행한다. 로컬 빌드/export/ZIP 제작·전달 금지. 수동 트리거 유지.

- 새 태그 `v0.28.7`,고정 게임 `71d914e5ca816e4c439a2b38d63bdfa339c96340`. 검사·도구·[노트](releases/v0.28.7.md)의 자료 SHA는 main workflow 기본값에 고정한다.
- [Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml) → **새 Run workflow → main → 기본값 그대로 Run workflow**. 과거 실행 재실행 금지.
- 현재 연결은 새 workflow dispatch/Release 게시 도구를 제공하지 않는다. 준비·push 뒤 사용자가 새 실행을 시작해야 한다. 준비 완료를 빌드/게시 완료로 보고하지 않는다.
- runner가 공식4.7.2 제작·실제 Windows EXE 검사를 통과한 뒤 ZIP·SHA256SUMS.txt·windows-native-report.json 세 첨부를 draft에서 검증하고 게시한다. 실패하면 게시하지 않는다.
- 원정 재시작 제거11/0·검색21/0 소스 근거를 재사용했다. **Windows 한글 IME는 직접 재현·검증하지 못했으며 Windows native smoke도 IME 실기를 보증하지 않는다.** [입력 지도](workshop-search.md),[재시작 제거](no-run-restart.md).
- v0.28.6 게시 완료는 GitHub GET으로 확인했다. 기존 태그/배포 불변,미리 준비한 소스 lightweight 태그·`--verify-tag`·수동 실행을 유지한다.
- ASSET_SOURCES.md·CHANGELOG.md 복구 금지,사용자 문서·DO·기존 엔딩 양식 유지.

이전 기록은 [고정 지도](https://github.com/agree-git/pokemon-deckbuilder/blob/58affce9ff35679db8093bf65a092e9082c480cc/docs/github-releases.md)에 보관한다.
