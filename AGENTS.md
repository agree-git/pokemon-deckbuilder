# 개발 이어가기

게임 코드는 이 `main`이 기준이다. 개발 자료의 첫 문서는 [START_HERE.md](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/START_HERE.md)다.

1. `git status --short`와 최근 커밋을 확인하고 기존 변경을 보존한다.
2. `git fetch origin main development-materials:refs/remotes/origin/development-materials` 후 `git show origin/development-materials:START_HERE.md`를 읽는다.
3. 자료 브랜치의 `HANDOFF.md` → `AGENTS.md` → `docs/rules.md` → 필요한 `docs/development.md` 순서로 확인한다.
4. 진행 중인 게임 checkout을 자료 확인 때문에 다른 브랜치로 전환하지 않는다. 자료 추출 방법은 START_HERE에 있다.

Godot **4.7.2**, 1920×1080 UI. 전국도감1,025종 + 지역/상시폼 포함1,412항목, 최대3마리, 69전투, 통합 카드 덱, 개체값/노력치 없음이 확정 범위다. 최신 사용자 요청이 문서보다 우선한다. 보류한 밸런스/경제 튜닝을 자동 재개하지 않는다.

원정v5 이상은 승인된137대진 파티/마지막 대표를 `data/boss_parties.json`에서 적용한다. v1~v4 원정의 경로·난수·파티 복원용 기존 JSON은 수정하지 않는다.

새 원정v7는 별도 `boss_move_effects_v7.json`/효과버전2의41대표를 적용한다. v6의19대표 동결 파일/효과버전1과 v1~v5의 미래 전투를 보존한다. 아직97대표가 이전 전술이며 잠꼬대 엔진 지원을 꼭두 적용 완료로 보고하지 않는다. 후속 확장도 사용 중인 v6/v7 입력을 덮어쓰지 않고 새 원정/효과 버전으로 설계한다.

게임은 main, 문서·현재 검사는 development-materials에 따로 반영한다. 사용자 변경·게임 저장 호환·난수·사용자 배경 좌표·출처 고지를 보존한다. 캐시/개인 저장/빌드/큰 검토 산출물과 중복 게임 사본을 커밋하지 않는다. 다른 영구 원격 브랜치나 worktree를 임의로 만들지 않는다.

작업 종료/중단 시 자료 브랜치의 HANDOFF를 짧게 갱신하고 실제 검증·미완료·다음 단계를 기록한다. 한국어로 간결하게 설명하며 실행하지 않은 검사와 Windows 호환성을 완료로 보고하지 않는다.

사용자가 main 반영을 승인했지만 EXE 생성은 계속 보류했다. 수정·검증·main push는 진행하며 새 빌드/export/Windows CI는 실행하지 않는다. Windows preview는 수동 실행 전용이며 명시적 빌드 재개 요청 전에는 실행하거나 push 자동 빌드를 복원하지 않는다.
