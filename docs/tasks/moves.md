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

정확한 각색은 해당 버전만 조회: [v10](../player-move-cards.md) / [v11](../player-move-tactics.md) / [v12](../player-move-exchange.md) / [v13](../player-move-fields.md) / [v14](../player-move-seals.md). 전체919기술을 원작 그대로 재현한다는 뜻이 아니다. 추가 보완 목록 밖의 기술도 기본 공격/부가효과로 동작할 수 있다.

## 변경이 연결되는 지점

| 변경 | 필요한 파일/계약 |
|---|---|
| 정의/본문/미리보기 | `scripts/tactics/tactical_content.gd`,해당 효과의 `definition/prepare/lines` |
| 소지품 지속 효과 | `TacticalBattle.effective_item()`;영구 `held_item`/무소지 판정은 유지 |
| 피해/행동/교대/턴/입장 | `scripts/tactics/tactical_battle.gd`의 해당 훅,필요 시 `pokemon_stats.gd` |
| 새 원정에만 적용 | `scripts/tactics/campaign_route.gd` + `player_techniques.gd` |
| 저장/복원/검증 | `scripts/persistence/journey_snapshot.gd`,`journey_save.gd`;기존 선택 필드를 필수 필드로 만들지 않음 |
| 연출 중 상태/배지 | `scripts/tactics/battle_frame.gd`,`scripts/ui/tactical_ui.gd`의 해당 함수 |
| 생성/출처 | `tools/import_player_move_seals.py` 등 해당 생성기와 고정CSV 지문;원본 CSV는 커밋하지 않음 |

보존 계약: 미리보기는 상태/UID/RNG를 바꾸지 않는다. 카드 사용 거절은 교대/자원/손패를 바꾸지 않는다. 자동/수동/필수 교대·동시 기절·다음 상대 입장을 구분한다. 승인 파티/마지막 대표,학습 슬롯/카드 UID·강화,기존 원정과 영구 포켓몬 정보를 보존한다. 효과의 원작 차이는 카드 설명과 자료에 명시한다.

## 필요한 검사 선택

- 새 효과는 해당 전용 검사와 실제 저장/복원→같은 입력/결과부터 확인한다. 상호작용을 다루는 기존 테스트도 포함한다.
- 공통 피해·카드 사용·턴·저장·버전 분기를 수정하면 영향을 받는 이전 효과와 원정 회귀를 확대한다. 전체 관련 suite는 반영 전 필요한 시점에 한 번 수행하고,코드 변경/실패/새 우려가 없으면 반복하지 않는다.
- 현재 넓은 회귀 명령: `python3 .dev-materials/tools/check.py --game-dir . --suite player-seals --godot /path/to/godot-4.7.2`.
- 단일 스크립트 직접 실행도 개인 저장과 분리된 XDG/APPDATA 환경을 사용한다. 격리 방법이 불명확하면 `check.py`의 임시 사용자/게임 사본 방식을 따른다.
- 문서/목록만 변경하면 링크·ID·경로·diff만 확인한다. 실제 창/native/X11·EXE/빌드/export/Windows CI는 사용자 지시대로 보류한다.

큰 JSON은 `json.load()`로 필요한 기술ID만 추출한다. 실패 로그는 오류와 앞뒤 호출만 읽는다. 작업 후 최신 상태는 HANDOFF에 짧게 남기고 파일/문맥/검사 계약이 바뀔 때만 이 지도를 갱신한다.
