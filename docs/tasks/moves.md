# 기술 작업: 필요한 파일부터

현재/다음 작업과 최신 검증 수치는 [HANDOFF](../../HANDOFF.md) 한 곳에서 확인한다. 모든 기술 문서나 이전 엔진을 먼저 읽지 않는다.

## 진입점과 동결 범위

- 우선 `scripts/tactics/player_techniques.gd`의 버전 분기와 수정할 효과 모듈만 읽는다. 공통 전투 훅이 필요하면 `tactical_battle.gd`의 해당 함수로 넓힌다.
- 게시된 아래 입력/전용 엔진은 동결이다. 후속 구현은 새 파일/원정 버전/효과 분기로 추가하고 이전 원정의 현재·미래 전투와 RNG를 보존한다.

| 원정/효과 | 전용 엔진 (`scripts/tactics/`) | 데이터 (`data/`) | 선택 문맥 |
|---|---|---|---|
| v10/2 | `player_move_cards.gd`,`player_move_rules.gd` | `player_move_cards_v10.json` | `move_context` |
| v11/3 | `player_move_tactics.gd` | `player_move_tactics_v11.json` | `technique_context` |
| v12/4 | `player_move_exchange.gd` | `player_move_exchange_v12.json` | `exchange_context` |
| v13/5 | `player_move_fields.gd` | `player_move_fields_v13.json` | `field_context`,`turn_speed_inverted` |
| v14/6 | `player_move_seals.gd` | `player_move_seals_v14.json` | `seal_context` |
| v15/7 | `player_move_altitude.gd`,`player_move_air_fields.gd` | `player_move_altitude_v15.json` | `altitude_context` |
| v16/8 | `player_move_traps.gd` | `player_move_traps_v16.json` | `trap_context` |
| v17/9 | `player_move_items.gd`,`player_move_item_math.gd` | `player_move_items_v17.json` | `item_context` |
| v18/10 | `player_move_assist.gd`,`player_move_assist_math.gd` | `player_move_assist_v18.json` | `assist_context` |
| v19/11 | `player_move_fate.gd` | `player_move_fate_v19.json` | `fate_context` |
| v20/12 | `player_move_reactions.gd`,`player_move_reaction_math.gd` | `player_move_reactions_v20.json` | `reaction_context` |
| v21/13 | `held_items.gd`,`held_item_math.gd` | `held_items_v21.json` | `held_context` |

정확한 각색은 해당 버전만 조회: [v10](../player-move-cards.md) / [v11](../player-move-tactics.md) / [v12](../player-move-exchange.md) / [v13](../player-move-fields.md) / [v14](../player-move-seals.md) / [v15](../player-move-altitude.md) / [v16](../player-move-traps.md) / [v17](../player-move-items.md) / [v18](../player-move-assist.md) / [v19](../player-move-fate.md) / [v20](../player-move-reactions.md) / [v21 물건](../held-items.md). 전체919기술을 원작 그대로 재현한다는 뜻이 아니다. 추가 보완 목록 밖의 기술도 기본 공격/부가효과로 동작할 수 있다.

## 변경이 연결되는 지점

| 변경 | 필요한 파일/계약 |
|---|---|
| 정의/본문/미리보기 | `scripts/tactics/tactical_content.gd`,해당 효과의 `definition/prepare/lines` |
| 접지/부유 | `PlayerMoveAltitude.grounded/affinity`;필드의 접지 의존 함수는 `PlayerMoveAirFields` (동결 소스에서 파생) |
| 식별/조준·동료 보조 | `PlayerMoveAssist.affinity/prepare/after_card`;조준한 보스 훅은 동결 소스에서 파생한 `PlayerMoveAssistMath`. 실제 타입/보호/대타·기술ID 유지 |
| 수면/기절·치유 인계 | `PlayerMoveFate.tick/after_enemy/on_knockout/on_switch`;수면 감소 전 악몽·날씨 후 카운트·입장 피해 뒤 회복. 기절 동시 판정/기존 강제 교대 보존 |
| 이번 턴 타입/분진 반응 | `PlayerMoveReactions.card_type/enemy_preview/explode`;타입은 조건부/종별/필드 결정 뒤 계산. `BossEffects`의v4 미리보기와 공중 필드/주술/애로 계산은 SHA 고정 파생기 |
| 소지품 지속 효과 | `TacticalBattle.effective_item()`;v17 변경은 `item_context.base`로 복구. v21은 [물건 계약](../held-items.md)의 원 소유권/영구 소비를 마지막에 적용 |
| 피해/행동/교대/턴/입장 | `scripts/tactics/tactical_battle.gd`의 해당 훅,필요 시 `pokemon_stats.gd` |
| 새 원정에만 적용 | `scripts/tactics/campaign_route.gd` + `player_techniques.gd` |
| 저장/복원/검증 | `scripts/persistence/journey_snapshot.gd`,`journey_save.gd`;기존 선택 필드를 필수 필드로 만들지 않음 |
| 연출 중 상태/배지 | `scripts/tactics/battle_frame.gd`,`scripts/ui/tactical_ui.gd`의 해당 함수 |
| 생성/출처 | `tools/import_player_move_reactions.py`,`tools/derive_player_reaction_math.py` 등 해당 생성기와 고정CSV 지문;원본 CSV는 커밋하지 않음 |

보존 계약: 미리보기는 상태/UID/RNG를 바꾸지 않는다. 카드 사용 거절은 교대/자원/손패를 바꾸지 않는다. 자동/수동/필수 교대·동시 기절·다음 상대 입장을 구분한다. 승인 파티/마지막 대표,학습 슬롯/카드 UID·강화,기존 원정과 영구 포켓몬 정보를 보존한다. 효과의 원작 차이는 카드 설명과 자료에 명시한다.

## 필요한 검사 선택

- **최신 사용자 지시: 검사 횟수 최소화.** 변경 효과·실제 저장·직접 관련된 이전 동작을 작은 핵심 검사에 묶어 기본1회 실행한다. 전체919기술/전체 suite를 매번 돌리지 않는다.
- 최신 기술 묶음 명령(지닌 물건 작업은 `--suite held-items`): `python3 .dev-materials/tools/check.py --game-dir . --suite player-reactions --godot /path/to/godot-4.7.2` (타입 변환/분진·저장·관련 이전 동작 한 스크립트).
- 실패/구체적 미확인 위험에만 관련 검사를 추가한다. 과거 넓은 회귀는 `--suite player-altitude` 등이며 자동 필수 절차가 아니다. 통과 뒤 이유 없이 반복하지 않는다. 후속 효과도 해당 변경의 최소 묶음을 새로 선택한다.
- 단일 스크립트 직접 실행도 개인 저장과 분리된 XDG/APPDATA 환경을 사용한다. 격리 방법이 불명확하면 `check.py`의 임시 사용자/게임 사본 방식을 따른다.
- 문서/목록만 변경하면 링크·ID·경로·diff만 확인한다. 실제 창/native/X11·EXE/빌드/export/Windows CI는 사용자 지시대로 보류한다.

큰 JSON은 `json.load()`로 필요한 기술ID만 추출한다. 실패 로그는 오류와 앞뒤 호출만 읽는다. 작업 후 최신 상태는 HANDOFF에 짧게 남기고 파일/문맥/검사 계약이 바뀔 때만 이 지도를 갱신한다.
