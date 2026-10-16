# 전체 배경 화면 검토

`tools/capture_background_review.gd`는 실제 `TacticalJourneyUI`를 렌더링해 **1920×1080 PNG 65장**과 모음 이미지 네 장을 만든다.

| 분류 | 화면 수 | 범위 |
|---|---:|---|
| 바이옴 | 18 | 모든 타입 |
| 사천왕 | 31 | 현재 후보 전원, 같은 타입 방 공유 포함 |
| 챔피언 | 11 | 현재 후보 전원 |
| 예비 룸 | 5 | 사천왕 노말/전기/풀/페어리, 공용 챔피언 홀 |

현재 연결된 배경 43종과 예비 5종, **아틀라스 셀 48종 전체**를 포함한다. 화면은 1920×1080이며 배경 에셋 자체를 해당 해상도로 다시 만드는 도구는 아니다.

검토용 고정 파티와 난수 시드로 새 전투 장면을 생성한다. 바이옴은 Lv.20, 사천왕 비교 파티는 Lv.95, 챔피언은 Lv.100이다. 사천왕·챔피언 상대 편성은 현재 콘텐츠 정의에서 가져온다. 도입 애니메이션이 끝난 화면을 촬영하고, 촬영 전후 원정 스냅샷이 같은지 검사한다. 원정 완주 기록이 아니며 사용자 원정/도감을 읽거나 저장하지 않는다.

## 재현

Godot 4.7.2와 실제 그래픽 디스플레이를 사용한다. 창은 1920×1080이며 모음 이미지 생성 시 더 큰 렌더 타깃을 사용한다. 출력 폴더는 새 폴더 또는 빈 폴더여야 한다. 아래 경로는 로컬 환경에 맞게 바꾼다.

```bash
XDG_DATA_HOME=/tmp/background-review-data \
XDG_CONFIG_HOME=/tmp/background-review-config \
XDG_CACHE_HOME=/tmp/background-review-cache \
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://tools/capture_background_review.gd \
  -- --output /tmp/pokemon-background-review
python3 tools/package_background_review.py /tmp/pokemon-background-review
```

두 번째 명령은 콘텐츠 ID 전체, PNG 해상도·SHA-256, 배경 셀 전체와 예비 여부를 검증하고 오프라인 `index.html`·설명·인접 ZIP을 만든다. 갤러리에는 분류/이름·타입·지방 검색, 원본 확대와 다운로드가 있다. PNG를 가공하거나 게임 에셋을 바꾸지 않는다. 콘텐츠 후보 수가 바뀌면 도구의 전체 수 검증과 갤러리 안내도 갱신한다.

2026-10-16 Linux/Godot 4.7.2 실제 렌더링 65장, 실패 0개를 확인했다. 모음 이미지 네 장을 시각 검토했다. 산출물은 체크아웃 밖 `/workspace/pokemon-background-review-2026-10-16`과 인접 ZIP에 제공했으며 Git에는 재현 도구만 보관한다. 이 절대 경로의 파일이 다른 환경에도 남아 있다고 가정하지 않는다.
