# 개발 이어가기

게임 코드는 이 `main`이 기준이다. 개발 자료의 첫 문서는 [START_HERE.md](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/START_HERE.md)다.

1. `git status --short`와 최근 커밋을 확인하고 기존 변경을 보존한다.
2. `git fetch origin main development-materials:refs/remotes/origin/development-materials` 후 `git show origin/development-materials:START_HERE.md`를 읽는다.
3. 자료 브랜치의 `HANDOFF.md` → `AGENTS.md` → `docs/rules.md` → 필요한 `docs/development.md` 순서로 확인한다.
4. 진행 중인 게임 checkout을 자료 확인 때문에 다른 브랜치로 전환하지 않는다. 자료 추출 방법은 START_HERE에 있다.

Godot **4.7.2**, 1920×1080 UI. 전국도감1,025종 + 지역/상시폼 포함1,412항목, 최대3마리, 69전투, 통합 카드 덱, 개체값/노력치 없음이 확정 범위다. 최신 사용자 요청이 문서보다 우선한다. 보류한 밸런스/경제 튜닝을 자동 재개하지 않는다.

원정v5 이상은 승인된137대진 파티/마지막 대표를 `data/boss_parties.json`에서 적용한다. v1~v4 원정의 경로·난수·파티 복원용 기존 JSON은 수정하지 않는다.

새 원정v9는 별도 `boss_move_effects_v9.json`/효과버전4로 검토한138대표/실전233기술의 카드 전투 효과를 적용한다. 플레이어919기술의 원작 효과 전체 구현을 뜻하지 않는다. v6/v7/v8 입력·엔진·기존 원정의 현재/미래 전투·난수는 동결한다. 새 `BossBattleRules`는 v8/v9 문맥을 분기하며 고유 상태는 선택 `boss_context`와 `effects_v4`에 저장한다. 후속 확장은 사용 중인 입력·동작을 덮어쓰지 않고 새 버전으로 설계한다.

새 원정v10은 `player_move_cards_v10.json`/`PlayerMoveCards`/`PlayerMoveRules`로 플레이어919기술 중311개의 특징을 보완한다. 원작 수치의 완전 복제보다 기술의 개성을 카드 규칙으로 살리는 것이 사용자 기준이다. 선택 `player_moves_version:2`와 `move_context`에 충전·재충전·보호·대타·봉인 등을 저장한다. v1~v9 플레이어 카드 정의와 보스 전술·승인 파티·경로 RNG는 유지한다. v10 입력도 게시 후 덮어쓰지 않는다. 적용/각색/남은 단순 변환은 자료의 `docs/player-move-cards.md`를 확인한다.

새 원정v11은 별도 `PlayerMoveTactics`/`player_move_tactics_v11.json`과 선택 `technique_context`로32카드를 추가 보완해 누적342기술이다. `PlayerTechniques`가 효과1/2/3을 분기한다. v10 입력·엔진은 그대로 두고 v11도 게시 후 동결한다. 설치는 순차 입장에 적용하며 울부짖기 계열은 승인 파티/마지막 대표를 유지하는 전술 밀어내기로 각색한다. 자세한 범위는 자료의 `docs/player-move-tactics.md`를 따른다.

게임은 main, 문서·현재 검사는 development-materials에 따로 반영한다. 사용자 변경·게임 저장 호환·난수·사용자 배경 좌표·출처 고지를 보존한다. 캐시/개인 저장/빌드/큰 검토 산출물과 중복 게임 사본을 커밋하지 않는다. 다른 영구 원격 브랜치나 worktree를 임의로 만들지 않는다.

작업 종료/중단 시 자료 브랜치의 HANDOFF를 짧게 갱신하고 실제 검증·미완료·다음 단계를 기록한다. 한국어로 간결하게 설명하며 실행하지 않은 검사와 Windows 호환성을 완료로 보고하지 않는다.

사용자가 main 반영을 승인했지만 EXE 생성은 계속 보류했다. 수정·검증·main push는 진행하며 새 빌드/export/Windows CI는 실행하지 않는다. Windows preview는 수동 실행 전용이며 명시적 빌드 재개 요청 전에는 실행하거나 push 자동 빌드를 복원하지 않는다.

사용자 지시: 기술 효과 구현과 소스/모델 검사를 먼저 끝내고, 실제 창 검사는 이후 한꺼번에 진행한다. 구현 도중 기술별 X11/native/UI 실행을 반복하지 않는다. EXE/빌드/export/Windows CI 보류는 별도로 계속 유지한다. 상대의 구속 기술은 수동 교대와 소유 기술 카드의 자동 교대를 모두 제한하고, 현재 동료 기술/도구·구속 해제·시전자 기절·필수 교체를 정상 처리한다.
