# 포켓몬 원정대

포켓몬 최대 세 마리로 덱을 구성하고 여덟 바이옴의 배지를 모아 사천왕과 챔피언에게 도전하는 팬게임입니다.

## Windows 시험 빌드

[Windows preview](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-preview.yml)의 성공한 실행에서 `PokemonExpedition-Windows-x86_64-…` 아티팩트를 받습니다(GitHub 로그인 필요, 보관14일). 압축을 풀고 `PokemonExpedition` 폴더의 `PokemonExpedition.exe`를 실행합니다. Godot 설치는 필요하지 않으며 옆의 `.pck` 파일을 함께 둡니다.

저장·설정은 `%APPDATA%\Godot\app_userdata\포켓몬 원정대`에 보관합니다. 새 빌드는 별도 폴더에 풀어도 기존 저장을 이어서 읽습니다. 초기 알파의 자동 검사 빌드이며 실제 PC의 화면·소리·긴 플레이 검증은 별도입니다. 빌드의 검증 결과는 함께 제공하는 `windows-native-report.json`에 있습니다.

## Godot에서 실행

1. **Godot 4.7.2**에서 `project.godot`을 엽니다.
2. F5로 시작 화면을 실행합니다. 시작 씬은 `scenes/main_menu.tscn`입니다.
3. 스타팅을 최대 세 마리 선택해 새 원정을 시작하거나 저장된 원정을 이어갑니다.

일반 포켓몬은 1~3세대, 희귀 포켓몬은 1~9세대와 가라르 전설의 새를 지원합니다. 희귀 조우는 발견 전까지 물음표로 표시하며 HP 10% 이하에서 포획할 수 있습니다.

18개 바이옴마다 전용 탐험·야영 음악과 환경음이 있으며, 설정에서 환경음 음량을 별도로 조절할 수 있습니다.

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
