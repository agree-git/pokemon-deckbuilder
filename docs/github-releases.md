# v0.28.5 GitHub 릴리스

2026-10-20 사용자 “릴리스” 요청으로 준비했다. **빌드·실행 검사·ZIP 제작·배포는 GitHub Actions·Releases에서만** 수행한다. 로컬 export/빌드·ZIP 전달 금지. 수동 트리거는 유지한다.

- 게임 고정 SHA: `2560d2da269074e4444b4644ab69cad40dd6cf75` / 새 lightweight 태그 `v0.28.5`.
- 자료 SHA는 main의 `.github/workflows/windows-release.yml` 기본값에 고정한다. 검사·도구·[릴리스 노트](releases/v0.28.5.md)를 같은 자료 커밋에서 읽는다.
- [Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml) → **Run workflow → main → 기본값 그대로 Run workflow**. 과거 실행을 재실행하지 않는다.
- 현재 연결은 새 workflow dispatch/Release 게시 도구를 제공하지 않는다. 준비와 push 후 사용자가 새 수동 실행을 시작해야 한다. 준비 완료를 게시 완료로 보고하지 않는다.
- 공식 Godot4.7.2 Windows 제작·실제 EXE 검사 통과 후 draft에 ZIP·SHA256SUMS.txt·windows-native-report.json 세 첨부를 검증하고 게시한다. 실패하면 draft를 게시하지 않는다.
- 기존 태그·릴리스를 이동/덮어쓰지 않는다. 미리 준비한 정확한 소스 태그와 `--verify-tag`로 과거 workflow 수정 SHA의 권한 문제를 피한다.

이번 변경은 [저장 이전](save-location.md), [연출](presentation-polish.md), [제공된 크레딧](ending-credits.md)을 포함한다. ASSET_SOURCES.md·CHANGELOG.md는 복구하지 않는다. 제작 도구가 사용자 README-Windows.txt를 그대로 복사하고 검사용 프로필을 별도로 쓰도록 반영했다.

이전 배포·403 근거는 [고정 지도](https://github.com/agree-git/pokemon-deckbuilder/blob/12e0229419f0633afd3b4f8866cc05d5dd09f543/docs/github-releases.md)에 보관한다.
