# 개발 이어가기

게임 코드는 이 `main`이 기준이다. 개발 자료의 첫 문서는 [START_HERE.md](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/START_HERE.md)다.

1. `git status --short`와 최근 커밋을 확인하고 기존 변경을 보존한다.
2. `git fetch origin main development-materials:refs/remotes/origin/development-materials` 후 `git show origin/development-materials:START_HERE.md`를 읽는다.
3. 자료 브랜치의 `HANDOFF.md` → `AGENTS.md` → `docs/rules.md` → 필요한 `docs/development.md` 순서로 확인한다.
4. 진행 중인 게임 checkout을 자료 확인 때문에 다른 브랜치로 전환하지 않는다. 자료 추출 방법은 START_HERE에 있다.

Godot **4.7.2**, 1920×1080 UI. 전국도감1,025종 + 지역/상시폼 포함1,412항목, 최대3마리, 69전투, 통합 카드 덱, 개체값/노력치 없음이 확정 범위다. 최신 사용자 요청이 문서보다 우선한다. 보류한 밸런스/경제 튜닝을 자동 재개하지 않는다.

게임은 main, 문서·현재 검사는 development-materials에 따로 반영한다. 사용자 변경·게임 저장 호환·난수·사용자 배경 좌표·출처 고지를 보존한다. 캐시/개인 저장/빌드/큰 검토 산출물과 중복 게임 사본을 커밋하지 않는다. 다른 영구 원격 브랜치나 worktree를 임의로 만들지 않는다.

작업 종료/중단 시 자료 브랜치의 HANDOFF를 짧게 갱신하고 실제 검증·미완료·다음 단계를 기록한다. 한국어로 간결하게 설명하며 실행하지 않은 검사와 Windows 호환성을 완료로 보고하지 않는다.

사용자가 빌드 보류를 지시했다. 수정·검증·로컬 커밋은 진행하되 새 빌드/export/Windows CI를 실행하지 않고, 자동 빌드를 유발하는 main push도 보류한다. 명시적 재개 요청 전까지 유지한다.
