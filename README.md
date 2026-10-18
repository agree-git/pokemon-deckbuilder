# 포켓몬 원정대

포켓몬 최대 세 마리로 덱을 구성하고 여덟 바이옴의 배지를 모아 사천왕과 챔피언에게 도전하는 팬게임입니다.

## Windows 시험 빌드

현재 EXE 생성은 보류 중이며 main 반영으로 자동 빌드되지 않습니다. Windows preview는 수동 실행 전용입니다.

[Windows preview](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-preview.yml)의 성공한 실행에서 `PokemonExpedition-Windows-x86_64-…` 아티팩트를 받습니다(GitHub 로그인 필요, 보관14일). 압축을 풀고 `PokemonExpedition` 폴더의 `PokemonExpedition.exe`를 실행합니다. Godot 설치는 필요하지 않으며 옆의 `.pck` 파일을 함께 둡니다.

저장·설정은 `%APPDATA%\Godot\app_userdata\포켓몬 원정대`에 보관합니다. 새 빌드는 별도 폴더에 풀어도 기존 저장을 이어서 읽습니다. 초기 알파의 자동 검사 빌드이며 실제 PC의 화면·소리·긴 플레이 검증은 별도입니다. 빌드의 검증 결과는 함께 제공하는 `windows-native-report.json`에 있습니다.

## Godot에서 실행

1. **Godot 4.7.2**에서 `project.godot`을 엽니다.
2. F5로 시작 화면을 실행합니다. 시작 씬은 `scenes/main_menu.tscn`입니다.
3. 스타팅을 최대 세 마리 선택해 새 원정을 시작하거나 저장된 원정을 이어갑니다.

전국도감 1,025종과 지역폼·상시폼을 합친 1,412개 항목을 지원합니다. 앞·뒤 스프라이트와 울음소리, 종족값·성장·기술·진화를 포함하며 메가진화·거다이맥스 같은 전투 전용 폼은 제외합니다. 희귀 조우는 발견 전까지 물음표로 표시하며 HP 10% 이하에서 포획할 수 있습니다.

원정 v5 이상의 관장·사천왕·챔피언 137대진은 승인된 원작 기반 파티를 사용하며 대표 포켓몬이 마지막에 출전합니다. 풍·란은 솔록·루나톤 두 자리를 고정합니다. 기존 v1~v4 저장은 이전 파티와 경로를 유지합니다. 원작 외 정원 보충과 대표 최종진화 예외는 [적용 목록](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/boss-party-review.md)에 구분합니다.

지역에 들어갈 때 제공된 포켓몬 BGM 35곡 중 한 곡을 무작위로 고릅니다. 같은 지역의 일반 전투·야영·이동은 같은 곡을 이어 재생하고, 새 지역에서는 직전 곡과 다른 곡으로 1.2초간 페이드 전환합니다. 관장·사천왕·챔피언은 제공된 전용 전투곡 36개를 역할별로 사용합니다. 새 원정의 후보는 관장86·사천왕36·챔피언15이며 레드도 챔피언으로 등장합니다. 같은 인물의 관장/사천왕/챔피언은 별개 대진입니다. 18개 바이옴의 환경음은 설정에서 별도로 조절할 수 있습니다.

전투 메뉴·설정을 열면 음악과 환경음이 먹먹하게 들리고, 닫으면 원래 소리로 돌아옵니다. 효과음·울음소리와 저장된 음량 설정은 별도로 유지됩니다.

야영지의 **기술머신** 메뉴에서 상인의 무작위 기술머신을 구매하거나 발견한 기술머신을 주울 수 있습니다. 동료와 교체할 기술을 선택해 사용하며, 1개를 소모하고 야영 행동은 사용하지 않습니다.

화면은 1920×1080, 그래픽은 도트 스타일입니다. 원정은 69전투·68야영지로 구성되며 저장/설정은 Godot 사용자 데이터 폴더에 보관됩니다.

| 조작 | 기능 |
|---|---|
| 마우스 | 카드·메뉴 선택 |
| 1 / 2 / 3 | 파티 교대 |
| Q / W / E / R | 손패 첫 네 장 |
| Enter / C | 턴 종료 / 포획 |
| Esc / F1 / F11 | 메뉴 / 도움말 / 전체 화면 |

## 저장소

`main`에는 사용하는 게임 코드·씬·데이터·에셋과 필수 출처/라이선스가 있습니다. Windows 내보내기 설정과 자동 시험 빌드 절차를 포함합니다. 상세 검증 범위와 한계는 [검증 현황](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/validation.md)에 기록합니다.

개발을 이어갈 때는 **[START_HERE.md](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/START_HERE.md)**부터 읽으세요. 이어서 [현재 상태](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/HANDOFF.md) → [작업 지침](AGENTS.md) → [확정 규칙](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/rules.md) → [개발·검사 방법](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/development.md) 순서로 확인합니다.

`development-materials`는 문서·현재 검사만 둡니다. 과거 갤러리·ZIP·CSV·수집 도구는 [보관 링크](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/history.md)로 열 수 있습니다. 최신 게임 코드는 이 `main`이 기준입니다.

에셋의 권리와 출처는 [ASSET_SOURCES.md](ASSET_SOURCES.md)를 확인하세요.

야영지의 **포켓몬 연구**에서 진화 분기·상시 폼·기술 훈련을 준비할 수 있습니다. 기술은 해당 포켓몬의 습득 경로와 레벨을 따르며 기존 카드 전투 규칙으로 사용합니다. 장소·통신·특수 조작 진화는 화면에 표시한 야영 행동으로 준비합니다. 지역폼은 별도 계통을 포획·진화하고, 합체 폼은 두 포켓몬의 포획 기록이 필요합니다. 기존 원정은 이전 경로를 복원하며 새 원정부터 전 세대 조우를 사용합니다.

새 원정 v11은 플레이어 기술919개 중 **342개 기술의 특징**을 보완했습니다. v10의311개에 설치·구속·행동 제한·교대 인계 등을 추가했습니다. 연타는 개별 타격, 흡수·반동은 실제 HP 피해, 솔라빔은 충전, 파괴광선은 재충전으로 처리합니다. 방어·대타·반격·조건부 위력·잠꼬대·소원·비축하기와 기술 봉인도 카드 설명과 실제 전투에 연결했습니다. 원작을 그대로 복제하기보다 카드 전투에서 특징이 드러나도록 각색했으며, 모든919기술의 원작 고유 효과를 완성한 것은 아닙니다. [추가 기술과 각색 규칙](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/player-move-tactics.md)을 확인하세요.

보스는 v9의 검토한 대표138마리/실전233기술 효과를 그대로 사용합니다. 기존 v1~v10 원정 저장과 미래 전투는 이전 규칙을 유지합니다. [보스 적용 현황](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/boss-move-effects.md). 사용자 요청으로 실제 창 검사는 기술 구현 뒤 일괄 진행하며 EXE 생성은 계속 보류합니다.
