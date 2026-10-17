# 필요한 과거 자료만 찾기

현재 상태는 [HANDOFF](../HANDOFF.md)와 [확정 규칙](rules.md)이 기준입니다. 아래는 **정리 직전 고정 커밋** `ce23503f74fe28d79a23813cb0b72b2331c6b421`의 보관 자료입니다. 최신 게임을 실행하는 별도 브랜치가 아니며, 오래된 규칙/범위/임시 경로가 포함될 수 있습니다.

| 필요할 때 | 고정 링크 |
|---|---|
| 희귀103종·효과25종 화면65장/ZIP/CSV | [최종 희귀 검토](https://github.com/agree-git/pokemon-deckbuilder/tree/ce23503f74fe28d79a23813cb0b72b2331c6b421/review/rare-gen9) |
| 사용자 배경 위치·화면·HTML 편집기/ZIP | [배경 자료](https://github.com/agree-git/pokemon-deckbuilder/tree/ce23503f74fe28d79a23813cb0b72b2331c6b421/review/background) |
| 전체 보스 도트 검토/제작자 근거 | [트레이너 자료](https://github.com/agree-git/pokemon-deckbuilder/tree/ce23503f74fe28d79a23813cb0b72b2331c6b421/review/clemont) |
| 과거 모든 갤러리/음원·화면 | [검토 자료 전체](https://github.com/agree-git/pokemon-deckbuilder/tree/ce23503f74fe28d79a23813cb0b72b2331c6b421/review) |
| 세부 기획·규칙·원정/빌드 분석·측정 | [이전 문서](https://github.com/agree-git/pokemon-deckbuilder/tree/ce23503f74fe28d79a23813cb0b72b2331c6b421/docs) |
| 희귀 수집/재현 원본·고정 출처/해시 | [희귀 수집 도구](https://github.com/agree-git/pokemon-deckbuilder/tree/ce23503f74fe28d79a23813cb0b72b2331c6b421/tools/rare-gen9) |
| 도트/소리 생성·배경 편집/촬영·기존 테스트 | [이전 tools](https://github.com/agree-git/pokemon-deckbuilder/tree/ce23503f74fe28d79a23813cb0b72b2331c6b421/tools) · [이전 tests](https://github.com/agree-git/pokemon-deckbuilder/tree/ce23503f74fe28d79a23813cb0b72b2331c6b421/tests) |
| 상세 완료 기록·구저장 검체 | [이전 인계](https://github.com/agree-git/pokemon-deckbuilder/blob/ce23503f74fe28d79a23813cb0b72b2331c6b421/HANDOFF.md) · [저장 fixtures](https://github.com/agree-git/pokemon-deckbuilder/tree/ce23503f74fe28d79a23813cb0b72b2331c6b421/tests/fixtures) |

## 주요 이력

- 시작/스타팅 → 69전투 캠페인·야영지·자동 저장을 연결했다.
- 통합 카드 덱·기술 자동 교대·유물/지닌 물건·상태/날씨·성장/진화를 확장했다.
- 1920×1080 UI·카드 겹침/호버·단계 연출·포켓볼·공격·사용자 보정 배경 위치를 적용했다.
- 전 지방 관장 후보와 보스124대진의 개별 트레이너 도트를 완료했다.
- 일반1~3세대를 유지하면서 희귀만9세대/지역폼까지 확장하고 최종25종의 고유 등장 효과를 연결했다.
- 이번 정리는 이 중복 자료를 현재 파일 목록에서 제거하고, 실행 게임/소수의 이어가기 문서/현재 검사로 역할을 분리했다.

과거 파일은 필요할 때 해당 커밋에서 개별 복원할 수 있습니다. 현재 브랜치에 전부 다시 가져오지 않습니다. Git 이력을 재작성하지 않았으므로 고정 링크는 유지되지만, 이미 받은 전체 clone의 과거 객체 용량은 이 정리로 자동 감소하지 않습니다.
