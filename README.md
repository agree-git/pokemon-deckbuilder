# 개발·검토 자료

현재 게임 파일은 [main](https://github.com/agree-git/pokemon-deckbuilder/tree/main)에 있다. 이 브랜치는 개발 문서·테스트·도구·자료 조사·검토 갤러리와 정리 전 프로젝트 사본을 보관한다. 실행 게임과 구분해 자료를 찾는 용도다.

| 자료 | 위치 |
|---|---|
| 다른 채팅에서 개발 이어가기 | [AGENTS.md](AGENTS.md) → [HANDOFF.md](HANDOFF.md) |
| 개발 진행/기획 | [진행 현황](docs/progress.md) · [게임 기획](docs/game-design.md) |
| 저장소 정리·main 실행 검증 | [결과·화면·로그](review/repository-cleanup/README.md) |
| 모든 검토 갤러리·ZIP·CSV | [검토 자료 모음](review/README.md) |
| 전체 보스 도트 적용 완료 | [시트론 화면·전체 CSV·ZIP](review/clemont/README.md) · [출처와 검증](docs/clemont-sprite.md) |
| 직전 후대 트레이너 도트 확장 | [추가 34대진 화면 39장·CSV·ZIP](review/trainer-sprite-expansion/README.md) · [출처와 검증](docs/trainer-sprite-expansion.md) |
| 이전 칼로스·알로라 도트 | [14인물 화면·CSV·ZIP](review/trainer-fan-sprites/README.md) |
| 트레이너 도트 출처 조사 | [업로드 XLSX 조사](docs/trainer-resource-research.md) · [후대 후보](docs/trainer-sprite-links.md) |
| 테스트와 개발 도구 | [tests](tests) · [tools](tools) |
| 이전 프로젝트 사용법 | [PROJECT_README.md](PROJECT_README.md) |
| 삭제 대상 브랜치의 원본 commit·파일 지문 | [보존 목록](docs/branch-archive.json) |

기존 검토 브랜치의 commit은 이 브랜치의 부모 이력으로도 보존한다. 갤러리를 옮긴 경로와 원본 commit 링크를 보존 목록에서 확인할 수 있다. 큰 산출물은 이후에도 이 브랜치에 두고 `main`에 다시 추가하지 않는다.

실제 게임 개선은 최신 `main`을 기준으로 진행한다. 이 브랜치의 프로젝트 코드는 정리 전 검증/개발 자료이므로 최신 게임 코드라고 가정하지 않는다. 옛 테스트/실험실은 옛 코드에 의존할 수 있다. 검증 자료를 가져올 때 대상 `main`의 실제 코드·파일 구조를 먼저 확인한다.

저장소 정리의 최종 검증과 브랜치 상태는 [작업 인계](HANDOFF.md)에 기록한다.
