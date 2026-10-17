# 개발·실행 방법

## 환경과 실행

Godot **4.7.2**, GDScript, 목표 플랫폼 Windows 데스크톱. 기본 검사는 Python3.10+ 표준 라이브러리만 쓴다. 게임은 main의 `project.godot`을 에디터에서 열어 F5로 실행한다. 시작 씬은 `scenes/main_menu.tscn`이다. 데이터/이미지/소리는 저장소에 포함돼 런타임 다운로드가 없다.

Linux 검사와 Windows 네이티브 검사는 실제 보고서로 구분한다. Windows headless 성공을 실제 GPU/오디오·사람의 긴 플레이 검증으로 설명하지 않는다. 임의의 예전 클라우드 PATH·DISPLAY·설정 파일을 새 환경의 전제 조건으로 삼지 않는다. 설치된 버전과 현재 작업 디렉터리를 직접 확인한다.

## 코드 찾기 (main 기준)

| 바꿀 영역 | 시작 위치 |
|---|---|
| 시작·스타팅·도감 | `scripts/ui/main_menu.gd`, `scripts/battle/battle_session.gd`, `scripts/content/player_profile.gd` |
| 전투 규칙·카드 행동 | `scripts/tactics/tactical_battle.gd`, `tactical_content.gd`, `tactical_moves.gd` |
| 원정·보상·야영·포획 | `scripts/tactics/tactical_journey.gd`, `campaign_route.gd`, `campaign_balance.gd` |
| 능력치·성장·진화 | `scripts/tactics/pokemon_stats.gd`, `tactical_growth.gd`, `evolution_items.gd`, `friendship_evolution.gd`, `special_evolution.gd` |
| 희귀 | `scripts/tactics/rare_encounter.gd`, `scripts/content/rare_encounter_story.gd`, `rare_capture_reaction.gd`, `data/rare_stories.json`, `rare_reactions.json` |
| 포획 후 반응창 | `scripts/ui/rare_reaction_panel.gd`, `tactical_ui.gd`, `tactical_journey_ui.gd` |
| 전투/원정UI | `scripts/ui/tactical_ui.gd`, `tactical_journey_ui.gd` |
| 손패·단계 연출 | `scripts/ui/battle_hand_layout.gd`, `combat_motion.gd`, `ui_motion.gd`, `rare_entrance.gd` |
| 배경·접지·날씨 | `scripts/ui/battle_canvas.gd`, `scripts/content/battlefield_layout.gd`, `scripts/ui/battle_weather_visual.gd` |
| 저장 | `scripts/persistence/journey_snapshot.gd`, `journey_save.gd`, `legacy_stats_snapshot.gd` |
| 콘텐츠 | `data/catalog.json`, `base_stats.json`, `progression.json`, `evolutions.json`, `biomes.json`, `gym_leaders.json`, `league.json` |
| 바이옴 음악·환경음 | `scripts/audio/biome_audio.gd`, `audio_loop_layer.gd`, `game_music.gd`, `game_ambience.gd`, `assets/audio/biomes/manifest.json` |
| 출처·도트·소리 | main `ASSET_SOURCES.md`, `assets/sources/`, `assets/audio/*/manifest.json` |

표에서 폴더를 생략한 같은 행의 파일은 앞 파일과 같은 폴더다. 코드에 실제 파일이 없는 경우 추측해서 새 파일을 만들지 말고 `rg --files scripts`로 확인한다. 런타임 출처 고지는 main에서 유지한다.

## Windows 내보내기

main의 `export_presets.cfg`는 Windows Desktop/x86_64/GL Compatibility/외부PCK/서명 없는 초기 알파 설정이다. Godot4.7.2와 같은 버전의 공식 템플릿을 설치하면 에디터에서도 사용할 수 있다. EXE와 PCK를 같은 폴더에 둔다.

자료의 다음 도구는 Python3.10+ 표준 라이브러리만 쓴다. 네트워크는 준비 단계의 공식 엔진/템플릿/라이선스 다운로드에만 필요하다. 공식 `SHA512-SUMS.txt`에서 고정한 hash로 아카이브를 검사한다. 전체 템플릿 다운로드는 약1.28GB이며 캐시에 재사용한다.

```bash
python3 tools/prepare_godot.py --cache-dir /path/to/cache
python3 tools/build_windows.py --game-dir /path/to/main --godot /path/to/godot \
  --toolchain-dir /path/to/cache --output-dir /path/to/new-output
# Windows의 새 테스트 계정/CI runner에서:
python3 tools/verify_export.py --bundle-dir /path/to/new-output/PokemonExpedition \
  --validation-dir /path/to/new-output/validation --mode windows-native \
  --report /path/to/new-output/windows-native-report.json
```

`--output-dir`은 새 폴더여야 한다. 기존 빌드를 덮어쓰지 않는다. 제작기는 임시 게임 스냅샷에서 import/export하고 원본 checkout을 바꾸지 않는다. 배포 폴더에는 EXE/PCK, 한글 실행 안내, 에셋/폰트/엔진 출처·라이선스, 파일별SHA256·원본 코드/도구 지문을 넣는다. ZIP과 외부SHA256도 만든다. 로그·검증용 실행 파일·캐시는 배포 ZIP이나 Git에 넣지 않는다.

공식4.7.2 배포 템플릿은 외부 `--script`/`--main-pack`을 금지한다. 그 설정을 유지하고, 배포 EXE의 타이틀 시작 검사와 별도 검증 export의 깊은 검사를 나눠 실행한다. 두 PCK의 모든 게임 항목은 실제 payload hash를 비교하며 프로젝트 설정과 UID 캐시만 제외한다. 검증 전용 scene/script는 배포 PCK에 없다. 검증 export는 UUID 사용자 폴더를 사용하고 끝나면 지운다. 실제 사용자 데이터가 있는 Windows 계정에서는 시작 검사를 거부하며, 기존 에디터 로그만 있는 폴더는 로그를 보존한다.

Linux에서는 같은 배포 PCK와 공식 Linux release template을 복사해 다음처럼 검사할 수 있다. 이 결과를 Windows 네이티브 실행으로 설명하지 않는다.

```bash
python3 tools/verify_export.py --bundle-dir /path/to/new-output/PokemonExpedition \
  --validation-dir /path/to/new-output/validation --mode linux-pack \
  --runtime /path/to/cache/templates/linux_release.x86_64 \
  --report /path/to/new-output/linux-pack-report.json
```

`--quit-after`로 타이틀을 강제 종료할 때 Godot4.7.2의 title.wav 정리 진단이 관측되었다. 검사기는 정확히 해당 WAV/PlaybackWAV와 타이틀 리소스만 해당할 때 이를 보고서의 `title_shutdown_diagnostic`과 `title_exit_clean:false`로 남긴다. 다른 시작 오류와 깊은 검사의 오류/누수는 실패다. 보고서에 진단이 있으면 깨끗한 종료로 보고하지 않는다.

main의 [Windows preview workflow](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-preview.yml)는 main 게임과 자료 브랜치의 도구를 별도로 checkout해 공식 Windows 에디터로 빌드하고 Windows release EXE를 headless 실행한다. 성공한 시험 빌드는14일, 진단 로그는7일 보관하며 정식 Release를 자동 게시하지 않는다. 다운로드 아티팩트의 `PokemonExpedition` 폴더를 그대로 사용한다.

## 자동 검사

자료 폴더의 검사기는 **최신 main의 경로를 명시**해서 실행한다.

```bash
python3 tools/check.py --game-dir /path/to/main --suite smoke
python3 tools/check.py --game-dir /path/to/main --suite soundscape
python3 tools/check.py --game-dir /path/to/main --suite reactions
python3 tools/check.py --game-dir /path/to/main --suite campaign
python3 tools/check.py --game-dir /path/to/main --suite rare
# 모두 필요할 때만:
python3 tools/check.py --game-dir /path/to/main --suite all
```

- `smoke`: 시작/해금, 카드 전투, 6능력치/상성, 날씨.
- `reactions`: 희귀103종 반응309문구·전 종 실제 포획/합류/방출/UI·빈자리/교체·구저장/정체 숨김·기존 포획 회귀.
- `soundscape`: 바이옴36음원 Godot 디코딩/루프 경계, 실시간 전환·중단·음량·구설정 호환, 원정/희귀UI·난수 불변.
- `campaign`: 덱/보상/캠페인과 원정 저장/복구.
- `rare`: 103종 데이터/포획/스타팅, 대표20종 정산/합류, 종별이야기/UI, 정체 숨김, 이전 풀/지문 호환, 진화, 울음소리 디코딩.

`--godot /path/to/godot`으로 실행 파일을 지정할 수 있다. 프로세스별 기본 제한은300초이며 `--timeout`으로 바꾼다. 다른 엔진 버전, 오류 로그, 실패한 검사, 완료 요약이 없는 실행은 통과로 처리하지 않는다. 자세한 통과 로그가 필요하면 `--verbose`를 쓴다.

검사기는 게임의 `assets/data/scripts/scenes/project.godot`을 임시 폴더에 복사해 실행한다. 프로젝트 이름과 사용자 데이터 경로를 고유하게 분리하고 끝나면 지운다. 실제 플레이어의 저장/설정을 사용하지 않으며 원본 checkout을 고치지 않는다. 이 임시 사본은 Git에 보관하는 중복 게임 사본이 아니다.

검사에서 구성한 중간 단계 fixture는 정상 플레이로 그 단계까지 이겼다는 뜻이 아니다. 고정 정책의 자동 완주도 사람의 승률/재미 검증이 아니다. 변경 영역의 검사가 통과하면 이유 없이 전체 측정을 반복하지 않는다.

## 바이옴 음원 재생성 (선택)

음원 제작에만 Python의 **numpy·scipy**, `ffmpeg`(libvorbis)가 필요하다. 기본 게임과 Godot 검사기는 이 의존성을 요구하지 않는다.

```bash
python3 tools/generate_biome_audio.py --game-dir /path/to/main --verify
# 원본을 바꿀 때만 재생성:
python3 tools/generate_biome_audio.py --game-dir /path/to/main
```

18개 16마디 곡과18개32초 환경음을 고정 시드로 합성한다. PCM은 루프 경계를 넘어 꼬리/잔향을 겹치고, Ogg importer의 loop를 켠다. 기존 `.import`의 UID를 보존한다. 재생성하면 Ogg 컨테이너 바이트는 달라질 수 있으므로 명세의 PCM/Ogg 지문을 함께 확인한다. `--verify`는 현재 파일의 hash·디코딩·음량/클리핑·길이·루프 경계의 비정상 불연속을 검사한다. 자동 수치 검증은 사람의 청취 평가를 대신하지 않는다.

## 실제 화면·포인터 (선택)

별도의 Linux X11/1920×1080 화면과 `libX11`/`libXtst`가 있어야 한다. 동시에 여러 검사를 실행하지 않는다. 실제 창 검사는 기본 headless runner에 포함되지 않는다.

```bash
RARE_REVIEW_DIR=/path/to/output python3 tools/native_pointer.py \
  --project-dir /path/to/main --script tests/native_presentation.gd
```

설정의 환경음 슬라이더는 같은 조건에서 다음 선택 검사를 실행한다. 테스트용 사용자 데이터 환경변수를 지정하며, `SOUNDSCAPE_REVIEW_DIR`을 지정하면1920×1080 설정 화면을 한 장 저장한다.

```bash
python3 tools/native_pointer.py --project-dir /path/to/main --script tests/native_soundscape.gd
```

희귀 포획 후 반응은 아래 선택 검사로 실제 C키 포획→계속→합류 미리보기/취소/확정 또는 방출→반응창 닫기를 확인한다. 역시 별도 테스트 사용자 프로필이 필요하며, `RARE_REACTION_REVIEW_DIR`을 지정한 경우에만 화면을 저장한다. 중간 원정 fixture로 시작하므로 처음부터 정상 플레이한 결과는 아니다.

```bash
python3 tools/native_pointer.py --project-dir /path/to/main --script tests/native_rare_reactions.gd
```

실제 OS 클릭으로 조사→예약→준비→이동→등장을 확인하고25종 keyframe/공용 희귀 도입을 촬영한다. 이 검사는 직접 지정한 게임/사용자 데이터 폴더를 사용하므로 별도 테스트용 사용자 프로필을 준비한다. Windows/macOS의 실제 포인터 자동화는 아직 제공하지 않는다. 사람의 F5 실행/수동 입력으로도 확인할 수 있다.

## 변경·GitHub 반영

1. 실제 Git 상태와 최신 사용자 요청을 확인한다. 모델 규칙/콘텐츠와 UI/연출을 분리해 작은 변경을 만든다.
2. 기존 저장·UID·난수·배경 좌표와 출처를 보존하고 관련 검사만 실행한다.
3. 게임 변경은 main, 문서/검사 변경은 development-materials에 따로 커밋/push한다. 자료 사본을 main에 통째로 merge하거나 main을 자료 브랜치에 통째로 merge하지 않는다.
4. HANDOFF에는 결과·실제 검증·미완료·다음 단계만 기록한다. 규칙이 바뀌면 rules, 실행 절차가 바뀌면 이 문서를 고친다.
5. push 뒤 `git ls-remote --heads origin`으로 확인한다. 원격은 main/development-materials 두 개만 유지한다. 사용자 요청 없이 force push/이력 삭제/추가 영구 브랜치를 만들지 않는다.

큰 캡처·ZIP·원본 CSV·빌드와 긴 로그를 정기적으로 커밋하지 않는다. 이전 수집/배경 편집/측정 도구가 실제로 필요하면 [과거 자료](history.md)에서 필요한 것만 가져와 현재 경로/범위에 맞춰 검증한다.
