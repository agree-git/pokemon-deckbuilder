# 현재 게임 화면·실제 입력 검사

v27/플레이어 효과19에서 기술 설정 일괄 정리 뒤 대표 상황을 실제1920×1080 X11 창과 XTest 마우스/키보드로 확인했다. 전체919기술·전체69전 플레이,Windows 실행/EXE 제작을 뜻하지 않는다. 세부 결과는 [검증 기록](validation.md#v27-기술-구현-뒤-실제-창-일괄-검사)만 필요할 때 읽는다.

그 뒤의 단일 시드 전체69전투 진행과 종료/새 원정 확인은 [최종 원정 확인](final-review.md)에 따로 기록한다. 아래 대표 검사를 그때 전부 반복한 것은 아니다.

## 수정 진입점

- `scripts/content/battle_card_preview.gd`: 현재 효과 버전·15개 문맥·룸 지급 방향과 포켓몬 폼/변신 능력치를 깊게 복사한 독립 전투/RNG로 예측. 새 문맥/임시 포켓몬 정보가 추가되면 이 복제 지도도 갱신한다. 동료 HP 변화는 별도 목록으로 전달한다.
- `scripts/ui/battle_action_preview.gd`: 부상 동료 회복 결과를 대상 이름과 함께 표시,늘어난 행은 아래쪽 경계를 유지해 위로 확장한다.
- `scripts/ui/card_effect_text.gd`: 동결 효과 엔진을 변경하지 않고v19의 동료 회복/충전·웅크림·무게/입장·예고 공격 등 핵심 규칙을 앞면에 표시. 자기/상대 능력 단계도 구체적으로 표시한다.
- `scripts/tactics/tactical_content.gd`: v19에서만 기습/속이기의 낡은 상충 설명2개를 생략한다. 이전 효과 설명은 보존한다.
- `scripts/ui/trainer_action_card.gd`: 비용은 정수로,변신/동적 타입 변경은 기존 카드 인스턴스의 초상/타입 아이콘에 즉시 반영한다.
- `scripts/ui/tactical_ui.gd`: 기존4열 상태 배지의 텍스트 영역을 넓혀3글자 상태 이름을 보존한다.

## 필요한 경우에만 재현

Godot4.7.2와1920×1080 X11 디스플레이를 활성화한다. 개인 저장과 격리된 XDG 경로가 필수이며 스크립트가 실제 `user://` 경로를 검사한다. 엔진은 export 없이 프로젝트 소스로 실행한다. 다음 명령은 예시이며 환경의 엔진 경로와 DISPLAY를 사용한다.

```sh
export PATH=/path/to/godot-4.7.2/bin:$PATH
export DISPLAY=:99
review_root=$(mktemp -d /tmp/pokemon-native-review-XXXXXX)
export XDG_DATA_HOME="$review_root/data" XDG_CONFIG_HOME="$review_root/config" XDG_CACHE_HOME="$review_root/cache"
export COMPLETION_REVIEW_DIR="$review_root/review"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$COMPLETION_REVIEW_DIR"
LIBGL_ALWAYS_SOFTWARE=1 timeout 240 python3 .dev-materials/tools/native_pointer.py --project-dir . --script .dev-materials/tests/native_completion_review.gd
COMPLETION_REVIEW_PHASE=resume LIBGL_ALWAYS_SOFTWARE=1 timeout 100 python3 .dev-materials/tools/native_pointer.py --project-dir . --script .dev-materials/tests/native_completion_review.gd
```

기본 실행은 제목/이어하기→대표 기술·호버/구속→야영 TM·장비·휴식·소비→관장/사천왕/챔피언→기절/교대/승리/보상/다음 야영을 묶는다. `resume`은 **새 엔진 프로세스**의 정확한 복원/실제 다음 Enter·분리 복제/15개 카드 텍스트·배지 폭·AudioServer 저역통과 DSP를 확인한다. 준비 상태/레벨/기술 소유/기절 직전 HP와 적 HP 일부는 fixture이며 전체 원정을 자연 플레이한 검사는 아니다.

오류 범위만 재확인하는 `remaining`(기술/메뉴/소비),`flow`(기절 이후 흐름),`art`(직전 flow 저장의 부상 보존+실제 변신 카드 갱신)도 제공한다. 현재 작업에서는 각각 필요한 범위만 사용했으며 수정 후 전체 기본 실행을 다시 돌리지 않았다. 실행 종료 코드와 `SCRIPT ERROR`/`ERROR`·실패 수를 함께 확인하고,시각 검사를 보고할 때는 생성된 PNG를 직접 본다. Dummy 오디오 드라이버의 실제 믹서 샘플/DSP 측정은 사람의 청취나 Windows 오디오 검증과 구분한다.
