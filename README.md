# Pokemon Deckbuilder

포켓몬의 포획·육성과 카드 전투를 연결하는 2D 로그라이트 덱빌딩 게임.

## 개발 기준

- 목표 엔진: **Godot 4.7.2** (GDScript, Compatibility 렌더러).
- 언어: GDScript
- 첫 실행 대상: Windows PC
- 게임 기획: [docs/game-design.md](docs/game-design.md)
- 전투 설계와 확장 방향: [슬더스라이크 전투·원정 설계](docs/deckbuilder-direction.md) — 통합 카드 덱·자동 교대·유물·선택 보상의 구현과 추가 설계 제안.
- Codex 작업 기준: [AGENTS.md](AGENTS.md)
- 새 대화에서 이어갈 때: [현재 작업 인계](HANDOFF.md) → [전체 진행 현황](docs/progress.md)

## 현재 상태

현재는 시작부터 엔딩까지 플레이 가능한 초기 알파다. [출발 덱·Lv.5 능력치 미리보기](docs/starter-loadout.md)로 편성을 확인하고, [스타팅·빌드 난도 측정](docs/balance-measurements.md)으로 파티별 진행을 비교한다. [희귀 조우](docs/capture-unlocks.md)는 준전설·환상·초전설 21종의 단서 조사와 원정당 한 번의 포획 도전을 지원하며 초전설을 가장 어렵게 획득하도록 구분한다. [특수 진화 준비](docs/special-evolution.md)까지 연결해 1~3세대 사이의 진화 경로 184개를 지원한다. [친밀도·시간대 진화](docs/friendship.md) 9개 경로를 경험치 성장과 연결했고 야영지에서 이브이의 낮·밤 분기를 준비한다. [돌·통신 진화](docs/evolution-items.md)는 상인 재료 13종과 가방의 진화 미리보기로 33개 경로를 지원한다. [보스 전술](docs/boss-tactics.md)은 관장·사천왕·챔피언 124개 후보 편성에 방벽·회복·상태·연타 등 아홉 가지 유형을 조합하며 행동을 미리 공개한다. [원정 기록](docs/run-records.md)에서 전투별 피해·카드 사용·유물 발동·골드 지출과 덱 선택을 확인할 수 있다. [야영지 상인](docs/merchant.md)에서 조합 카드·파티 기술 사본을 구매하고 보급품·카드 제거에 골드를 나눠 쓴다. [카드·유물 조합](docs/build-synergies.md)으로 기술 교대·에이스·소모전·보호막 전환을 연결하며 공용 카드 23종·일반 유물 10종·핵심 유물 5종·지닌 물건 6종을 사용한다. [핵심 유물](docs/core-relics.md)은 관장전에서 셋 중 하나를 골라 효과와 대가로 원정 운영을 바꾼다. [전체 진행 현황과 다음 작업](docs/progress.md), [적 전술과 대응](docs/enemy-tactics.md)을 참고한다.

기본 실행은 **시작 화면 → 스타팅 최대 3마리 선택 → 원정**이다. 처음에는 이상해씨·파이리·꼬부기를 선택할 수 있고, 포획하면 해당 계열의 가장 미진화한 종을 영구 스타팅으로 해금한다. 선택 순서대로 파티를 구성하며 첫 번째 멤버가 먼저 출전한다. 기술·도구·트레이너 공유 덱과 자동 교대·유물로 **서로 다른 무작위 바이옴 8곳의 배지 8개, 무작위 사천왕 4명, 챔피언 1명**을 이기면 챔피언이 된다. 각 지역은 야생 5회·일반 트레이너 1회·엘리트 트레이너 1회·관장 1회이며, 전투 사이마다 야영지를 거친다. 전체 137개 장소·69전투다. [시작과 포획 도감](docs/start-flow.md), [정식 원정 경로](docs/full-campaign.md)를 참고한다.

기존 5개 장소 햇살숲·9개 장소 원정과 단일 전술 시험은 **개발용 비교·회귀 검사 씬**으로 보관한다. 일반 플레이 메뉴와 F3/F4 전환에서 제거했다. 개발자가 에디터에서 직접 열거나 검사 스크립트로 실행할 수 있으며, 일반 사용자는 시작 화면에서 하나의 원정 흐름만 플레이한다.

- **포켓몬 콘텐츠는 1~3세대 원종 #001~386**, 관동·성도·호연까지 사용한다. 체육관 관장·사천왕·챔피언 인물은 전 지방에서 등장할 수 있다. 4세대 이후 종·지역폼·메가진화는 이후에 추가한다.
- 386종의 앞·뒤 도트 스프라이트 **772장**, 한글 이름·세대·현대 복합타입·진화 전 종·전설/환상 구분을 로컬 카탈로그에 포함한다. 개발용 아트 랩에서 모두 선택할 수 있다.
- 18개 타입 바이옴의 출현 후보와 **전 지방 관장 82팀·83명, 각 6마리 파티**를 준비했다. 새 원정마다 타입별 후보를 추첨하며 기존 원정의 대진은 보존한다. [타입별 후보](docs/gyms.md), [전체 인물·편성](docs/gym-candidates.md)을 참고한다. 아트 랩은 기존 18개 기준 편성을 보여준다.
- 전설·환상 21종은 일반 출현과 관장 파티에서 제외했다. 포획 도감은 `user://collection.json`에 저장하며 게임을 종료해도 스타팅 해금이 유지된다. 준전설·환상·초전설의 단서 조사와 등급별 희귀 포획을 지원한다. [포획·해금 규칙](docs/capture-unlocks.md)을 참고한다.
- 각 바이옴의 야생 전투에서는 몬스터볼 1개·에너지 1로 체력 25% 이하의 적을 포획한다. 전투 종료 후 [합류 미리보기](docs/recruitment.md)에서 추가/제거 카드와 반환 장비·덱 장수를 확인하고 합류·교체·방출을 결정하며, 방출하거나 이후 패배해도 스타팅 해금은 유지한다. 트레이너·관장·리그 포켓몬은 포획하지 못하며 야영지의 떠돌이 상인이나 발견 이벤트에서 몬스터볼을 보충한다.
- 승리·포획 정산 시 살아 있는 파티원은 정상 경험치, 기절한 파티원은 **30%**를 얻는다. 원작의 종별 성장 곡선에 스테이지·전투 종류 배율을 적용한 경험치를 누적한다. 조건 레벨에서 자동 진화하고, 에메랄드 레벨별 기술표로 기술을 배우며 네 개가 차면 교체 또는 포기한다. 기절 없이 진행하면 마지막 사천왕전 정산에서 Lv.100에 도달한다. 챔피언은 전원 Lv.100이다. 야영지는 휴식과 무작위 상인·이벤트·아이템 발견, 가방·장비를 이용하는 거점이다. [성장 규칙](docs/growth.md)을 참고한다.
- 1세대 기술 165종을 재사용 가능한 공격·방어·회복·상태 연출에 연결했다. 원작의 개별 기술 애니메이션을 복제한 것은 아니며, 실제 피해·명중·상태 확률을 적용하지 않는 연출 프리뷰다.
- 화면·UI 기준은 **1920×1080**이며, 전체 화면을 저해상도로 렌더링하지 않는다. 도트 스타일은 그래픽에만 적용한다. 포켓몬 스프라이트는 최근접 필터와 정수 배율로 표시하고, 글자·카드·HUD는 화면 해상도에서 그린다.

- 개체값·노력치 없이 3세대 종족값·레벨만으로 여섯 능력치를 계산하고 물리/특수·자속·복합타입 상성을 적용한다. 턴 시작 출전 아군이 더 빠르면 에너지 4, 아니면 3이다. [능력치와 스피드 에너지](docs/pokemon-stats.md)를 참고한다. 이번 개체값·노력치 제거 이전의 v3 원정도 능력치를 변환해 이어할 수 있다.

지도·야영지의 [다음 전투 준비](docs/encounter-preparation.md)에서 실제 상대별로 현재 덱의 통하는 공격·타격 무효·지속/조건부 카드를 확인한다. 기절한 동료의 카드는 제외하며 회복 후 다시 조회할 수 있다.

## 전투 화면

모바일에서 보는 [수정 후 배경 갤러리·ZIP·좌표 CSV](https://github.com/agree-git/pokemon-deckbuilder/tree/background-review-2026-10-16)는 별도 검토 브랜치에 보관한다. 전투 65장·접지 가이드 48장과 원본 다운로드를 제공한다.

[전투 연출·카드 목록·야영지 가방](docs/battle-presentation.md): 포켓볼 회수·등장, 양쪽 공격·피격 동작과 이벤트 순서에 맞춘 수치 변화, 큰 보호막 표시를 적용한다. 처음 출발에도 이동 화면을 표시하며 가방은 아이템을 누른 뒤 파티 팝업에서 대상을 선택한다. 전리품 탭은 제거했다.

- 에너지는 하단 왼쪽 끝, 바로 오른쪽에는 `남은 카드`·`버린 카드` 수를 위아래로 표시한다. 더미 확인과 카드 이동 연출도 이 위치를 따른다.
- 내 파티는 화면 왼쪽, 상대 파티는 오른쪽의 작은 초상·체력 목록으로 표시한다. 출전·기절 상태를 표시하며 상대 6마리도 전투와 손패를 가리지 않게 배치한다.
- 상단 바는 불투명 배경을 화면 끝까지 채워 얇은 틈이 생기지 않게 했다.
- 기술·도구·트레이너 카드를 하단 손패 한 곳에 모았다. 기술에는 소유 포켓몬의 초상·이름과 자동 교대 표시가 나온다. 고정 기술 패널과 브레이크 게이지는 제거했다. 중앙에는 포켓몬·체력바·적 행동 예고를 표시한다.
- 타입은 검토·승인한 웹 SVG 기호 18종을 색상별 원형 배지로 표시한다. 원본·해시와 재현 방법은 [에셋 출처](ASSET_SOURCES.md#ui-아이콘)에 기록했다.
- 손패 6~10장은 자연스럽게 겹치며, 호버하면 위로 올라가 확대되고 양옆이 벌어진다. [트레이너 도입·발밑 연출](docs/battle-presentation.md)과 [사천왕·챔피언 실내 배경](docs/league-stages.md)을 적용했다.
- [카드 결과 미리보기](docs/action-preview.md): 손패를 가리키면 자동 교대 후 HP·보호막·에너지·다음 공격과 야생 포획 가능 여부를 표시하며, HP 바에는 변할 구간을 표시한다. 행동을 실행하거나 난수를 소비하지 않는다.
- [배경별 접지 좌표](docs/battlefield-layout.md)로 48개 배경의 발판/바닥과 포켓몬 발끝·HP·보호막·연출을 맞춘다. [전체 화면 촬영 도구](docs/background-review.md)로 일반 화면과 접지점 가이드·좌표 CSV를 검토할 수 있다.
- 기술은 초록, 도구는 금색, 트레이너는 푸른 프레임으로 구분하며 비용·초상 또는 도트 아이콘·효과를 표시한다. 카드가 뽑히면 순서대로 등장하고, 호버하면 떠오르며, 사용하면 버린 더미로 이동한다. 소진 카드는 사용 후 사라진다.
- 버튼 반응, 교체 페이드, 체력바 보간, 에너지·턴·유물 발동 강조와 메뉴·도움말·결과창의 열기/닫기 애니메이션을 적용했다. 자세한 효과는 툴팁에서 확인한다.
- 상단 **? / F1**은 도움말, **… / Esc**는 메뉴다. 획득한 파티 유물 확인·원정 재시작·시작 화면 이동을 제공한다. 아트 랩과 비교용 원정은 일반 메뉴에 노출하지 않는다.
- 원정 덱 조회·강화·제거 목록은 [전체·공용·동료별 필터](docs/deck-browser.md)를 제공한다. 강화와 제거는 묶음에서 한 장을 선택해 비교·확정한다.
- 덱·더미·출발 덱·합류/기술 비교·전투 준비 목록에서 같은 소유자·강화·내용의 사본은 겹친 카드와 `×N`으로 묶어 표시한다. 전체 장수는 실제 카드 수다.
- 뽑을 더미와 버린 더미 아이콘을 누르면 카드 구성을 확인할 수 있다. 소진 더미는 메뉴에서 확인한다. 더미 확인으로 드로우 순서를 공개하거나 변경하지 않는다.

## 개발용 기존 원정 전투 UI

- 상단: 파티 체력, 원정 진행도, 몬스터볼 수, 현재 지역, 전투 번호, 화면 전환.
- 중앙: 아군·적 스프라이트, 체력바, 적의 다음 행동 예고.
- 하단: 공유 에너지, 뽑을 더미, 부채꼴 손패 5장, 버린 더미와 턴 종료.
- 아군 교체 슬롯으로 전용 카드의 사용 가능 표시가 바뀐다. 카드 호버 시 위로 올라오고, 선택 시 해당 기술 연출을 재생한다.
- 적을 쓰러뜨리면 살아 있는 파티원의 전용 기술 3개 중 1장을 선택하거나 넘긴다. 보상 카드는 해당 포켓몬에게 귀속되며 다음 전투부터 덱에 들어간다. 보상 화면을 다시 열어도 후보가 바뀌지 않는다.
- 포획은 적 체력 25% 이하일 때 에너지 1과 몬스터볼 1개를 소비한다. 시작 볼은 2개이며 파티는 최대 3마리다. 가득 차면 기존 멤버 또는 새 포켓몬을 내보낸다. 합류 시 전용 카드 2장을 추가하고, 기존 멤버를 내보내면 전용 카드와 연결된 부상을 제거한다.
- 지도에서 다음 장소의 적·타입·HP·포획 가능 여부를 보고 경로를 선택한다. 휴식은 회복·부활, 카드 한 장 강화, 경험치 4의 스타팅 첫 진화 중 하나를 선택한다.
- 체력·에너지·손패·더미·행동 예고는 실제 전투 상태를 표시한다. 연출 중 중복 입력을 막고, 기절하면 살아 있는 아군을 선택할 때까지 진행을 멈춘다. 종료 후 결과 화면에서 재시작할 수 있다.
- 전투 규칙은 Node에 의존하지 않는 `BattleState`에, 불변 카드·적 정의는 `BattleContent`에 분리했다. 화면은 데이터 조회와 행동 요청·연출만 담당한다.
- 현재 전투는 4타입과 소수 카드로 검증한다. 386종 전체의 플레이어용 기술·특성·포획과 기술 165종의 게임 규칙을 모두 구현한 것은 아니다. [전투 규칙과 덱 구성](docs/battle-rules.md)을 참고한다.

## 실행과 검증

Godot 4.7.2로 `project.godot`을 열고 F5로 시작 화면을 실행한다. `새 원정`에서 스타팅을 1~3마리 선택하고 `원정 시작`을 누른다. **1/2/3** 교체, **Q/W/E/R** 손패 왼쪽 1~4장, **Enter** 턴 종료, **C** 포획이다. Lv.5까지의 원작 기술로 시작한다. 기술은 네 개까지이며 새 기술 습득 시 카드 얼굴과 교체할 덱 사본 수를 확인하고 교체하거나 배우지 않을 수 있다. [교체 전후 비교](docs/learning-comparison.md)에서는 실제 사본·강화와 다음 상대별 공격/약점/조건부 카드 수 변화를 확인한다. 옛 기술의 사본을 모두 제거했어도 새 기술을 배우면 기본 카드 한 장이 덱에 들어간다. 야영지에서는 준비를 마친 뒤 출발 버튼을 누른다. 장소 사이에 짧은 이동 애니메이션이 재생되며 이동 중에는 입력을 차단한다. 전투 회복은 손패의 도구 카드로 하고 가방의 회복 아이템은 야영지에서 사용한다. 야영지는 휴식 또는 카드 강화 중 하나를 선택하며, 강화는 카드 선택 → [현재/강화 후 카드 비교](docs/camp-upgrade-preview.md) → 확정 순서로 진행한다. 취소하거나 Esc로 목록에 돌아가면 행동을 소비하지 않는다. 상인에게 진열된 카드·기술 사본을 구매하거나 [카드 제거 확인](docs/camp-removal-preview.md)에서 겹친 카드 한 장을 선택해 골드·덱·다음 상대 상성 변화를 보고 제거할 수 있다. 장비·유물 탭에서 지닌 물건을 장착한다. 메뉴에서 원정 재시작·시작 화면 복귀를 선택한다. 행동 후 자동 저장하며 게임을 종료하고 다시 실행해도 시작 화면의 `이어하기`로 돌아갈 수 있다. 손패·에너지·난수·기술 선택·야영지 재고까지 복원한다. 상단 저장 버튼에서 상태 확인과 재시도를 할 수 있다. [저장과 복구](docs/persistence.md)를 참고한다. 기본 실행은 별도 최대화 게임 창이며 1920×1080 기준 UI와 16:9 비율을 유지한다. 실행 중 네트워크와 API 키는 필요 없다.

```bash
# 이 클라우드 환경에서는 기본 Godot 4.6.3 대신 지정 엔진을 활성화한다.
source /workspace/.cloud-setup/pokemon-deckbuilder/env.sh
cd /workspace/pokemon-deckbuilder
godot --version
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_journey_save.gd
godot --headless --path . --script res://tests/test_save_files.gd
python3 tools/test_save_process.py
godot --headless --path . --script res://tests/test_camps.gd
godot --headless --path . --script res://tests/test_encounter_preparation.gd
godot --headless --path . --script res://tests/test_encounter_preparation_ui.gd
godot --headless --path . --script res://tests/test_camp_ui.gd
godot --headless --path . --script res://tests/test_campaign.gd
godot --headless --path . --script res://tests/test_campaign_ui.gd
godot --headless --path . --script res://tests/test_card_stacks.gd
godot --headless --path . --script res://tests/test_deck_filters_ui.gd
godot --headless --path . --script res://tests/test_removal_preview.gd
godot --headless --path . --script res://tests/test_removal_preview_ui.gd
godot --headless --path . --script res://tests/test_learning_comparison.gd
godot --headless --path . --script res://tests/test_learning_comparison_ui.gd
godot --headless --path . --script res://tests/test_learning_deck.gd
godot --headless --path . --script res://tests/test_learning_deck_ui.gd
python3 tools/test_learning_deck_process.py
godot --headless --path . --script res://tests/test_growth.gd
godot --headless --path . --script res://tests/test_growth_ui.gd
godot --headless --path . --script res://tests/test_evolution_items.gd
godot --headless --path . --script res://tests/test_evolution_items_ui.gd
python3 tools/test_evolution_process.py
godot --headless --path . --script res://tests/test_friendship.gd
godot --headless --path . --script res://tests/test_friendship_ui.gd
python3 tools/test_evolution_process.py --friendship
godot --headless --path . --script res://tests/test_special_evolution.gd
godot --headless --path . --script res://tests/test_special_evolution_ui.gd
python3 tools/test_evolution_process.py --special
godot --headless --path . --script res://tests/test_recruitment.gd
godot --headless --path . --script res://tests/test_recruitment_ui.gd
python3 tools/test_recruitment_process.py
godot --headless --path . --script res://tests/test_start_flow.gd
godot --headless --path . --script res://tests/test_start_ui.gd
godot --headless --path . --script res://tests/test_presentation.gd
godot --headless --path . --script res://tests/test_run_statistics.gd
godot --headless --path . --script res://tests/test_run_report_ui.gd
godot --headless --path . --script res://tests/test_merchant_cards.gd
godot --headless --path . --script res://tests/test_merchant_ui.gd
godot --headless --path . --script res://tests/test_build_synergies.gd
godot --headless --path . --script res://tests/test_build_synergies_ui.gd
godot --headless --path . --script res://tests/test_enemy_tactics.gd
godot --headless --path . --script res://tests/test_enemy_tactics_ui.gd
godot --headless --path . --script res://tests/test_boss_tactics.gd
godot --headless --path . --script res://tests/test_boss_tactics_ui.gd
godot --headless --path . --script res://tests/test_pokemon_stats.gd
godot --headless --path . --script res://tests/test_core_relics.gd
godot --headless --path . --script res://tests/test_core_relics_ui.gd
python3 tools/test_core_relics_process.py
godot --headless --path . --script res://tests/test_deck_combat.gd
godot --headless --path . --script res://tests/test_deck_run.gd
godot --headless --path . --script res://tests/test_deck_ui.gd
godot --headless --path . --script res://tests/test_tooltips.gd
godot --headless --path . --script res://tests/test_journey.gd
godot --headless --path . --script res://tests/test_journey_ui.gd
godot --headless --path . --script res://tests/test_battle.gd
godot --headless --path . --script res://tests/test_visuals.gd
godot --headless --path . --script res://tests/test_pointer.gd
godot --headless --path . --script res://tests/test_capture.gd
godot --headless --path . --script res://tests/test_rewards.gd
godot --headless --path . --script res://tests/test_expedition.gd
godot --path .
```

개발용 `scenes/battle_preview.tscn`에서는 카드를 눌러 사용하고, 왼쪽 아군 슬롯으로 교체한다. `Enter`는 턴 종료, `R`은 같은 시드로 원정 전체 재시작, `Shift+R`은 새 시드로 재시작, `F11`은 전체화면, `F2`는 아트 랩 전환이다. 상단 `전투 기록`에서 피해·상태·기절 기록을 확인할 수 있다. 승리하면 보상 카드를 클릭하거나 `보상 넘기기`를 누른 뒤 `원정 지도로`를 누른다. 포획·승리 후에도 파티 체력·기절·덱·몬스터볼·경험치를 유지한다. 지도·휴식·결과 화면에서 `덱 확인`으로 전체 덱을 볼 수 있다. 아트 랩을 오가도 현재 원정은 메모리에 유지되지만 앱을 종료하면 저장되지 않는다.

개발용 `scenes/art_lab.tscn`을 에디터에서 열면 바이옴·포켓몬·기술을 선택할 수 있다. `Space` 재생, `←/→` 바이옴 이동, `Esc` 연출 초기화다. 연출 샘플은 실제 전투나 포획 도감을 변경하지 않는다.

`test_start_flow.gd`는 최대 3마리 편성, 포획·합류, 미진화 해금, 도감 저장·백업 복구를 검사한다. `test_start_ui.gd`와 `python3 tools/test_native_pointer.py --probe native_start_probe`는 시작·선택·포획·도감·이어하기·관장 완주·새 스타팅 사용을 실제 입력 경로로 검사한다.

`test_journey.gd`는 30개 시드·시작 유물 전체의 짧은 원정와 체력·덱 유지, 스테이지 성장·자동 진화·정산 중복 방지를 검사한다. `test_journey_ui.gd`는 보상·지도·휴식·6마리 관장전·배지·재도전을 포인터로 연결하고 세 창 크기의 덱 모달 차단을 검사한다. `python3 tools/test_native_pointer.py --probe native_journey_probe`는 실제 OS 마우스로 새 원정 한 판을 완주하며 1920×1080 화면을 캡처한다.

`test_deck_combat.gd`는 자동 교대·소유권·자원·소진·보존·유물·지속 작전·지닌 물건과 386종 초기 덱을 검사한다. `test_deck_run.gd`는 혼합 보상·장비·강화·제거·저장과 실제 69전투 진행을 연결한다. `test_deck_ui.gd`와 `python3 tools/test_native_pointer.py --probe native_deck_probe`는 세 창 비율의 카드 위·중앙·아래 클릭, 모달 차단, 보상·이동·강화·장비 화면을 검사한다. 기존 전술 검사 진입점도 새 검사로 연결한다.

`test_battle.gd`는 카드 보존, 잘못된 행동의 무변경, 에너지·교체 비용, 드로우·재섞기, 상성·보호막·상태, 기절·승패·재시작과 30개 시드의 완결 전투를 검사한다. `test_visuals.gd`는 가져온 에셋과 실제 UI 조작을 통한 승리·패배·강제 교체·재시작·화면 재진입을 검사한다. `test_pointer.gd`는 버튼 신호를 직접 호출하지 않고 창 좌표의 마우스 이벤트를 보내 4개 창 크기에서 버튼의 위·중앙·아래, 호버 카드의 겹침, 결과창의 클릭 영역을 검사한다. `test_capture.gd`는 포획 조건·자원·중복 방지·합류·교체·부상 제거·다음 전투와 실제 입력 경로를 검사한다. `test_rewards.gd`는 시드 재현, 배울 수 있는 후보·소유권, 선택·넘기기·중복 방지, 다음 전투와 방출 연동, 화면 재진입과 창 크기별 실제 입력 경로를 검사한다. `test_expedition.gd`는 회복·부활·강화·진화·특성·경험치·경로 제한과 54개의 전체 원정을 검사하고 실제 포인터 이벤트로 한 판을 완주한다. Linux X11에서는 `LIBGL_ALWAYS_SOFTWARE=1 python3 tools/test_native_pointer.py`로 OS 포인터를 움직여 3개 창 크기에서 추가 검증할 수 있다. `--probe native_expedition_probe`를 붙이면 OS 마우스 입력만으로 원정 한 판 전체를 검사한다. 그래픽 렌더러로 검사할 때는 `--headless`를 빼면 된다.

`test_tooltips.gd`는 버튼 아래에 툴팁 창과 일반 Node가 있어도 활성·비활성 표시를 갱신하는지 검사한다. `python3 tools/test_native_pointer.py --probe native_tooltip_probe`는 실제 OS 포인터로 기술 툴팁을 띄운 상태의 갱신과 행동을 검사한다.

`test_journey_save.gd`와 `test_save_files.gd`는 상태·난수·강제 교체·중복 보상과 손상 복구를 검사한다. `python3 tools/test_save_process.py --native`는 별도 Godot 프로세스 다섯 개에서 실제 OS 포인터로 전투·야영지 이어하기와 백업 복구를 확인한다.

현재 검증은 Linux의 Godot 4.7.2 헤드리스와 실제 Compatibility 렌더러에서 수행했다. Windows 실행과 내보내기는 아직 검증하지 않았다.

원본 스프라이트·데이터·폰트를 다시 내려받으려면 `python3 tools/import_pokemon_assets.py`, 출현표·관장 편성과 해당 문서 재생성은 `python3 tools/build_biomes.py`, 성장 곡선·레벨별 기술표는 `python3 tools/build_progression.py`, 현대 타입 상성은 `python3 tools/build_type_chart.py`, 3세대 종족값은 `python3 tools/build_stats.py`를 실행한다. Python 3 표준 라이브러리만 사용하고 고정 업스트림 커밋·파일별 SHA-256을 검증한다. 기존 `import_kanto_assets.py` 명령도 같은 386종 임포터로 연결한다. 출처·라이선스는 [ASSET_SOURCES.md](ASSET_SOURCES.md)에 기록했다.

## 정식 원정과 이후 구현

정식 진행은 **무작위 바이옴 8곳 → 각 타입 관장 6마리 → 배지 8개 → 전 지방 무작위 사천왕 4명 → 무작위 챔피언 → 챔피언 등극**이다. [경로·대진·난이도·현재 제한](docs/full-campaign.md)을 참고한다. 현대 18개 타입의 약점·저항·무효와 복합타입을 적용한다. 경로·대진은 시드로 재현한다.

`test_campaign.gd`는 100개 시드 경로와 30개 시드의 실제 보상·장비 선택과 승리/전멸 결과, 고정 시드 3개의 69전투 완주, 챔피언 직전 Lv.100, 리그 진입 제한과 중복 정산을 검사한다. `test_camps.gd`는 386종의 경험치 예산·기절 30%와 야영지 이벤트의 중복 지급 방지·상인 재고를 검사한다. `test_camp_ui.gd`와 `python3 tools/test_native_pointer.py --probe native_camp_probe`는 이동 연출·입력 차단과 모든 야영지 만남을 검사한다. `test_campaign_ui.gd`와 `python3 tools/test_native_pointer.py --probe native_campaign_probe`는 마우스·1/2/3·Q/W/E/R·Enter로 전체 원정과 엔딩을 검사한다. 기존 시작·포획 UI 검사는 개발용 짧은 경로로 보존한다.

종별 경험치 곡선·스테이지 배율·자동 진화·원작 레벨별 기술 교체와 야영지 상점·가방·장비를 연결했다. 원정 자동 저장과 종료 후 이어하기·백업 복구를 구현했다. 통합 카드 덱·공용 카드 23종·일반 유물 10종·핵심 유물 5종·지닌 물건 6종·혼합 보상·강화·제거를 연결했다. 3세대 종족값·물리/특수 피해·자속·턴 시작 스피드 에너지까지 연결했다. 네 가지 일반 적 역할과 인물별 보스 전술을 연결했다. 카드 세 장·할인·보급품·제거를 제공하는 상점을 연결했다. 돌·통신 진화 33경로를 상인·가방·저장과 연결했다. 친밀도·시간대 진화 9경로를 연결했다. 진화 대상 선택·개체 분기·아름다움·껍질몬 추가 합류까지 연결했다. 준전설·환상·초전설의 조건부 희귀 포획을 연결했다. 다음은 희귀 스타팅과 빌드별 난도 조정이다. 현재 자동 검사는 기본 스타팅 세 마리로 수행하며 모든 파티 조합의 난이도를 보장하지 않는다.

## 데이터와 구조

`scripts/battle/`에 콘텐츠 정의·포켓몬/카드 인스턴스·전투 상태·원정 상태·세션을 두고, `scripts/ui/`와 `scripts/vfx/`에 화면과 연출을 둔다. 시드 기본값은 2026이며 재시작하면 덱 순서가 동일하게 재현된다.

## 저장소 관리

소스, 씬, 기획 문서, 필요한 원본 에셋을 추적한다. Godot 캐시와 빌드 결과는 커밋하지 않는다. 실행과 테스트가 가능한 환경에서 Godot 버전을 확인하고 결과를 기록한다.
