# 최종 원정 진행 확인

원정 v27/플레이어 효과19에서 **단일 시드2026·이상해씨/파이리/꼬부기**로 시작해 69승·배지8개·사천왕4명·챔피언 카르네 완료까지 확인했다. 공개 카드/교대/야영/보상/습득 행동만 사용한 자동 정책이며 체력·에너지·경험치·승리를 강제 변경하지 않았다. 난도에 대한 수동 플레이 평가나 모든 대진/기술/폼 전수 검사는 아니다.

## 수행 결과

| 범위 | 결과 |
|---|---|
| `test_final_campaign.gd` | 437검사/실패0 · 1,439행동 · 215턴 · 68야영 · 기술 습득29처리 · 상인 카드3구매 |
| `native_final_campaign.gd` 기본 | 16검사/실패0 · 실제4클릭/1키+휠 · 클리어69승/배지·사천왕 표시,69개 기록/스크롤/3탭,시작 화면 |
| 별도 새 프로세스 `FINAL_CAMPAIGN_PHASE=new` | 12검사/실패0 · 실제5클릭 · 완료 원정 재개 차단→3스타팅 선택→새원정/새run ID→정확한 저장 |
| 수정 범위 `FINAL_CAMPAIGN_PHASE=cap` | 3검사/실패0 · 실제69승 상태에서Lv.100 안내/3개 패널,성장/XP/저장/RNG 불변,PNG |

최종 스냅샷/통계69개와 모든 진행 단계,지역·보스 경계의 실제 파일 저장/정확한 복원을 확인했다. 종료 후에는 미완료 백업으로 되살아나지 않고 정산을 다시 해도 보상이 중복되지 않는다. 끝의 골드5180은 초기100+수입5540−지출460과 일치한다. 전체 진행에서 막히는 오류나 검사 실패는 없었다.

실제 창에서 최대 레벨 동료에게 ‘다음 레벨을 향해’가 표시되는 것을 발견해 `scripts/ui/tactical_journey_ui.gd::_growth_summary`의 문구만 고쳤다. 기존 실행으로 얻은 최종 상태로 해당 표시만3검사/실패0 재확인했고,전체69전을 반복하지 않았다. 전투/성장 수치·저장/버전·승인 콘텐츠는 변경하지 않았다. [일반 플레이 안내](https://github.com/agree-git/pokemon-deckbuilder/blob/main/PLAY_GUIDE.md)와 [변경사항](https://github.com/agree-git/pokemon-deckbuilder/blob/main/CHANGELOG.md)은 main에 있다.

## 다시 필요할 때만 실행

Godot4.7.2를 PATH에 넣고 개인 데이터와 분리한 XDG 디렉터리를 사용한다. 새 checkout은 Godot 편집기에서 `project.godot`을 한 번 열어 리소스를 가져온 뒤 실행한다. headless 원정은 창 없이 실제 공개 행동을 실행하고,종료 화면은 앞서 저장한 실제 결과를 X11 창에서 복원한다. XTest를 사용하는 창 검사는 동시에 실행하지 않는다.

```sh
review_root=$(mktemp -d /tmp/pokemon-final-review-XXXXXX)
export XDG_DATA_HOME="$review_root/data" XDG_CONFIG_HOME="$review_root/config" XDG_CACHE_HOME="$review_root/cache"
export FINAL_CAMPAIGN_DIR="$review_root/review"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$FINAL_CAMPAIGN_DIR"
timeout 240 godot --headless --path . --script .dev-materials/tests/test_final_campaign.gd
# 1920×1080 DISPLAY를 활성화한 뒤:
LIBGL_ALWAYS_SOFTWARE=1 timeout 100 python3 .dev-materials/tools/native_pointer.py --project-dir . --script .dev-materials/tests/native_final_campaign.gd
FINAL_CAMPAIGN_PHASE=new LIBGL_ALWAYS_SOFTWARE=1 timeout 100 python3 .dev-materials/tools/native_pointer.py --project-dir . --script .dev-materials/tests/native_final_campaign.gd
```

출력 종료 코드와 SCRIPT ERROR/ERROR 및 실패 수를 함께 본다. 전체가 통과했다면 반복하지 않는다. 별도 `cap`은 이번에 발견한 성장 안내만 검사하며 일반 전체 검사에 추가로 반복할 필요가 없다. 향후 실제 진행 실패를 재현할 때만 `FINAL_CAMPAIGN_RESUME=/path/to/captured-state.bin`으로 실제 `last-battle.bin`/`boss-<step>.bin`에서 이어 진행할 수 있다. 새로운 출발부터 검사한 결과와 재개한 결과를 구분해 기록한다.

현재 실제 산출물은 `/tmp/pokemon-final-20261019/`의 로그·report.json·실제 스냅샷·6PNG이며 커밋하지 않는다. 클리어/기록/새 원정/수정 후 최대 레벨 화면을 직접 보았다. 수정 전 대표 카드·오디오·저장 화면 검사는 [이전 범위](native-review.md)에 보존한다.

**EXE/빌드/export/Windows CI는 명시 재개 전 보류.** 이번 확인은 Linux Godot4.7.2 소스 실행이며 Windows 배포/청취 검증은 아니다. 기본 원정은 포획/희귀 조우/모든 TM·물건·원작919효과 조합을 전부 사용한 검사가 아니며 그 대표 검사는 이전 기록과 구분한다.
