# v0.28.6 GitHub 릴리스

2026-10-20 사용자 “릴리스” 요청으로 준비했다. **빌드·실제 EXE 검사·ZIP 제작·배포는 GitHub에서만** 진행한다. 로컬 build/export/ZIP 제작·전달 금지. 수동 트리거 유지.

- 새 태그 `v0.28.6`,고정 게임 SHA `81c600b8afe2be7cba294d1b7086e38d29e2e434`. 자료 SHA는 main workflow 기본값에 고정한다.
- 같은 자료 커밋의 검사·도구·[릴리스 노트](releases/v0.28.6.md)를 사용한다. [현재 진화·훈련·경제](camp-progression.md).
- [Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml) → **새 Run workflow → main → 기본값 그대로 Run workflow**. 과거 실행을 재실행하지 않는다.
- 현재 연결에는 새 workflow dispatch/Release 게시 도구가 없다. 모든 준비·push 후 사용자 클릭이 필요하며 준비 완료를 게시 완료로 보고하지 않는다.
- GitHub Windows runner가 공식4.7.2 제작·실제 EXE 검사를 통과한 뒤 ZIP·SHA256SUMS.txt·windows-native-report.json 세 첨부를 draft에서 검증하고 게시한다. 실패하면 게시하지 않는다.
- 기존 태그/릴리스 불변,소스 lightweight 태그를 미리 준비하고 `--verify-tag`를 유지한다. 수동 workflow를 자동 실행으로 바꾸지 않는다.
- ASSET_SOURCES.md·CHANGELOG.md 복구 금지. 사용자 문서·DO·기존 엔딩 형식과 저장 위치 이전 유지.

직전 배포 기록은 [고정 지도](https://github.com/agree-git/pokemon-deckbuilder/blob/47ff5f5d2f1e14b16347de0cd651e16b211d13dd/docs/github-releases.md)에 보관한다.
