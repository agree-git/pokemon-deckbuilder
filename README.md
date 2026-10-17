# 포켓몬 원정대 · 개발 자료

최신 게임은 [main](https://github.com/agree-git/pokemon-deckbuilder/tree/main)에 있습니다. 이 브랜치에는 **이어가기 문서와 현재 사용하는 검증 도구만** 둡니다. 게임 사본·화면 모음·ZIP·원본 자료를 중복 보관하지 않습니다.

**처음에는 [START_HERE.md](START_HERE.md)를 읽으세요.**

| 문서 | 용도 |
|---|---|
| [START_HERE.md](START_HERE.md) | 읽는 순서, 새 환경 준비, 브랜치를 바꾸지 않고 자료 가져오기 |
| [HANDOFF.md](HANDOFF.md) | 현재 구현, 마지막 작업, 남은 일 |
| [AGENTS.md](AGENTS.md) | 개발 에이전트의 작업 지침 |
| [확정 규칙](docs/rules.md) | 원정·카드 전투·성장·희귀·표시·저장 |
| [개발 방법](docs/development.md) | 코드 위치, 실행·검사·변경 반영 방법 |
| [검증 현황](docs/validation.md) | 실제 확인한 범위와 미검증 항목 |
| [과거 자료](docs/history.md) | 이전 갤러리·ZIP·CSV·상세 문서·수집 도구의 고정 링크 |

검사: `python3 tools/check.py --game-dir /path/to/main --suite smoke`

파일 정리는 일반 커밋으로 수행했습니다. 과거 자료는 Git 이력에 남고 고정 링크로 열 수 있습니다. 따라서 현재 파일 목록은 작아지지만 전체 Git 이력을 포함한 기존 clone의 용량이 즉시 줄어드는 것은 아닙니다.
