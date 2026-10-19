# 포켓몬 원정대

포켓몬 최대 세 마리로 덱을 구성하고 여덟 바이옴의 배지를 모아 사천왕과 챔피언에게 도전하는 팬게임입니다.

최신 버전의 실행·조작·저장은 **[플레이 안내](PLAY_GUIDE.md)**, 최근 수정은 [변경사항](CHANGELOG.md)을 참고하세요.

## Windows 다운로드 · GitHub Releases

실행 파일은 **[Releases](https://github.com/agree-git/pokemon-deckbuilder/releases)**에서 버전별 변경사항과 함께 관리합니다. Assets의 `PokemonExpedition-Windows-x86_64-….zip`을 받아 전체를 압축 해제하고 `PokemonExpedition.exe`를 실행하세요. 옆의 `.pck`를 함께 두며 **Godot 설치는 필요 없습니다**. GitHub의 자동 생성 Source code ZIP은 게임 실행 파일이 아닙니다.

v0.28.0 릴리스 게시 작업을 준비했습니다. 아직 실행하지 않았다면 저장소 관리자가 **[Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml) → Run workflow**를 기본값으로 한 번 실행하면 됩니다. 공식 Godot4.7.2로 Windows 빌드·실제 EXE headless 실행 검사를 통과한 뒤 ZIP·`SHA256SUMS.txt`·`windows-native-report.json`을 시험 릴리스에 게시합니다. main push/태그 push로 자동 실행하지 않습니다. [배포 안내](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/github-releases.md).

저장·설정은 `%APPDATA%\Godot\app_userdata\포켓몬 원정대`에 보관합니다. 새 빌드는 별도 폴더에 풀어도 기존 저장을 이어서 읽습니다. 실물 PC의 화면·소리·긴 수동 플레이 검증은 별도입니다. `linux-pack-report.json`은 동일 PCK의 Linux 검사이며 Windows 실기 검사가 아닙니다.

기존 **[Windows preview](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-preview.yml)**도 수동 실행으로 유지하며,임시 아티팩트의 보관 기간은14일입니다.

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


새 원정 **v28은 도전 난도**입니다. 상대 트레이너의 각 포켓몬은 개시 보호막으로 첫 공격을 버티며, 직접 공격은 후반으로 갈수록 강해집니다. 야영 휴식은 전원 최대 HP의40%→35%→30%를 회복합니다. 상성·교대·보호막과 야영지 강화·회복약·장비를 준비하세요. 첫 지역 야생의 공격 배율은 기존과 같고 개시 보호막도 없습니다. 기존 v27 이하 저장은 이전 난도를 유지합니다. [조정 근거](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/campaign-challenge.md).

## 저장소

`main`에는 사용하는 게임 코드·씬·데이터·에셋과 필수 출처/라이선스가 있습니다. Windows 내보내기 설정과 수동 실행 전용 시험 빌드 절차를 포함합니다. 상세 검증 범위와 한계는 [검증 현황](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/validation.md)에 기록합니다.

개발을 이어갈 때는 **[START_HERE.md](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/START_HERE.md)**부터 읽으세요. 이어서 [현재 상태](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/HANDOFF.md)와 [작업별 파일 지도](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/TASK_INDEX.md)에서 필요한 항목만 확인합니다.

`development-materials`는 문서·현재 검사만 둡니다. 과거 갤러리·ZIP·CSV·수집 도구는 [보관 링크](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/history.md)로 열 수 있습니다. 최신 게임 코드는 이 `main`이 기준입니다.

에셋의 권리와 출처는 [ASSET_SOURCES.md](ASSET_SOURCES.md)를 확인하세요.

야영지의 **포켓몬 연구**에서 진화 분기·상시 폼·기술 훈련을 준비할 수 있습니다. 기술은 해당 포켓몬의 습득 경로와 레벨을 따르며 기존 카드 전투 규칙으로 사용합니다. 장소·통신·특수 조작 진화는 화면에 표시한 야영 행동으로 준비합니다. 지역폼은 별도 계통을 포획·진화하고, 합체 폼은 두 포켓몬의 포획 기록이 필요합니다. 기존 원정은 이전 경로를 복원하며 새 원정부터 전 세대 조우를 사용합니다.

v27에서 **전체919개 기술 설정을 분류**하고,남은 설정39종과 공통 회복·연계 규칙을 일괄 보완했습니다. 충전·웅크리기·작아지기·무게 변화,보호 해제,상대 행동에 따른 사용 조건,동료 회복과 주요 상태 치료를 연결했습니다. 설명·각색 고지까지92종을 정리했습니다. [적용 범위와 전체 분류](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/player-move-completion.md).

변신·복사·부활·지연 공격·설치/구속·필드/룸·타입/능력 교환·소지품 조작과 실제 HP 기준 흡수/반동을 카드 전투로 구현합니다. 원작의 PP/특성/명중률 추첨·전투 전용 폼처럼 이 게임에 없는 시스템은 설명에 각색 범위를 명시합니다. 모든919개 원작 효과의 완전 복제를 뜻하지 않습니다.

보스는 v9의 검토한 대표138마리/실전233기술 효과를 그대로 사용합니다. 기존 원정 저장과 미래 전투는 시작 당시 규칙을 유지합니다. [보스 적용 현황](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/boss-move-effects.md). 기술 구현 뒤 대표 실제 창 검사와 단일 시드 69전투 진행 확인을 마쳤습니다.

새 원정 v21부터 지닌 물건 보상은 **원작 물건55종**을 사용합니다. 구애 시리즈·생명의구슬·먹다남은음식·기합의띠·타입 강화 도구·나무열매 등의 효과와 실제 아이콘을 적용했습니다. 야영지에서 동료당 하나를 장착하며,소모품은 사용 후 사라져 다시 획득해야 합니다. 리사이클로 복구하면 소모도 취소합니다. 이전 원정은 기존6종과 전투 규칙을 유지합니다. [전체 목록과 각색 범위](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/held-items.md).
