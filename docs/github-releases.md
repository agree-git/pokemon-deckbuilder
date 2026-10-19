# 현재 빌드 방침

최신 사용자 지시: **앞으로 빌드는 GitHub Actions·Releases에서만 실행하고, 로컬 빌드/export/ZIP 제작·전달은 하지 않는다.** 문서 수정·저장 경로 이전 작업은 새 버전/Release 요청이 아니다. 현재 빌드를 실행하지 않는다.

2026-10-20 첨부 안내문/크레딧 반영, ASSET_SOURCES.md·CHANGELOG.md 제거, 실제 custom user dir 및 이전 기능을 적용했다. [저장 위치와 도구 연결](save-location.md). 다음 릴리스 명시 요청이 오면 새 버전/게임SHA/자료SHA/태그를 준비하고 수동 Windows workflow로 검증·게시한다. 게시된 v0.28.4 태그/기본 입력을 수정하거나 재게시하지 않는다.

이전 v0.28.4 제작·검증·403 해결·수동 게시 근거는 [고정 릴리스 지도](https://github.com/agree-git/pokemon-deckbuilder/blob/12e0229419f0633afd3b4f8866cc05d5dd09f543/docs/github-releases.md)를 필요할 때만 읽는다. 수동 workflow를 자동 트리거로 바꾸지 않는다. 현재 도구에 새 실행/게시 기능이 없으면 사용자 Run workflow로 시작하고 GET으로 결과를 확인한다.
