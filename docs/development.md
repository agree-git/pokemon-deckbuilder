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
| 야영 기술머신 | `scripts/tactics/technical_machines.gd`, `scripts/ui/pokedex_workshop.gd`, `data/technical_machines.json` |
| 능력치·성장·진화 | `scripts/tactics/pokemon_stats.gd`, `tactical_growth.gd`, `evolution_items.gd`, `friendship_evolution.gd`, `special_evolution.gd` |
| 희귀 | `scripts/tactics/rare_encounter.gd`, `scripts/content/rare_encounter_story.gd`, `rare_capture_reaction.gd`, `data/rare_stories.json`, `rare_reactions.json` |
| 포획 후 반응창 | `scripts/ui/rare_reaction_panel.gd`, `tactical_ui.gd`, `tactical_journey_ui.gd` |
| 전투/원정UI | `scripts/ui/tactical_ui.gd`, `tactical_journey_ui.gd` |
| 손패·단계 연출 | `scripts/ui/battle_hand_layout.gd`, `combat_motion.gd`, `ui_motion.gd`, `rare_entrance.gd` |
| 배경·접지·날씨 | `scripts/ui/battle_canvas.gd`, `scripts/content/battlefield_layout.gd`, `scripts/ui/battle_weather_visual.gd` |
| 저장 | `scripts/persistence/journey_snapshot.gd`, `journey_save.gd`, `legacy_stats_snapshot.gd` |
| 콘텐츠 | `data/catalog.json`, `base_stats.json`, `progression.json`, `evolutions.json`, `biomes.json`, `gym_leaders.json`, `league.json` |
| 지역 음악·환경음 | `scripts/audio/region_music.gd`, `biome_audio.gd`, `audio_loop_layer.gd`, `game_music.gd`, `game_ambience.gd`, `assets/audio/region_music/manifest.json` |
| 출처·도트·소리 | main `ASSET_SOURCES.md`, `assets/sources/`, `assets/audio/*/manifest.json` |

표에서 폴더를 생략한 같은 행의 파일은 앞 파일과 같은 폴더다. 코드에 실제 파일이 없는 경우 추측해서 새 파일을 만들지 말고 `rg --files scripts`로 확인한다. 런타임 출처 고지는 main에서 유지한다.

## Windows 내보내기

main의 `export_presets.cfg`는 Windows Desktop/x86_64/GL Compatibility/외부PCK/서명 없는 초기 알파 설정이다. Godot4.7.2와 같은 버전의 공식 템플릿을 설치하면 에디터에서도 사용할 수 있다. EXE와 PCK를 같은 폴더에 둔다.

`assets/branding`의 자체 제작 카드·나침반·포획 볼 문양을 시작 로고(1920×1080 PNG), 창 아이콘(512 PNG), Windows EXE 아이콘(16/32/48/64/128/256 ICO)에 공통 적용한다. `application/modify_resources=true`로 Godot4.7.2 내장 PE 편집기가 아이콘을 삽입하며 외부 rcedit은 필요 없다. 제작/실행 검사기는 PE 아이콘 그룹의 여섯 크기와 참조된 실제 payload를 원본 ICO와 비교한다. 원본 ICO/시작 PNG hash도 빌드 명세에 남긴다. 깊은 export 검사에서는 packed 설정과 raw 시작 PNG·창 아이콘 읽기를 확인한다.

에셋을 다시 그릴 때만 선택 의존성 Pillow가 필요하다. `python3 tools/generate_branding.py --game-dir /path/to/main`으로 재생성한다. 실행/내보내기/검사에는 Pillow가 필요 없다. 기존 바이옴/포켓몬 그림을 편집하지 않고 코드로 도형과 지형을 그리며 포함된 Noto Sans KR로 글자를 렌더링한다. 시작 로고에 강제 대기 시간을 추가하지 않는다.

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
- `soundscape`: 기존 바이옴36음원과 사용자 제공35곡의 Godot 디코딩/루프, 지역 캐시·직전곡 제외·독립 난수·실시간 전환, 메뉴/중첩 설정의 저역 통과 필터·제거 복구·음량 보존, 원정/희귀UI·저장/RNG 불변.
- `campaign`: 덱/보상/캠페인과 원정 저장/복구.
- `rare`: 103종 데이터/포획/스타팅, 대표20종 정산/합류, 종별이야기/UI, 정체 숨김, 이전 풀/지문 호환, 진화, 울음소리 디코딩.

`--godot /path/to/godot`으로 실행 파일을 지정할 수 있다. 프로세스별 기본 제한은300초이며 `--timeout`으로 바꾼다. 다른 엔진 버전, 오류 로그, 실패한 검사, 완료 요약이 없는 실행은 통과로 처리하지 않는다. 자세한 통과 로그가 필요하면 `--verbose`를 쓴다.

검사기는 게임의 `assets/data/scripts/scenes/project.godot`을 임시 폴더에 복사해 실행한다. 프로젝트 이름과 사용자 데이터 경로를 고유하게 분리하고 끝나면 지운다. 실제 플레이어의 저장/설정을 사용하지 않으며 원본 checkout을 고치지 않는다. 이 임시 사본은 Git에 보관하는 중복 게임 사본이 아니다.

검사에서 구성한 중간 단계 fixture는 정상 플레이로 그 단계까지 이겼다는 뜻이 아니다. 고정 정책의 자동 완주도 사람의 승률/재미 검증이 아니다. 변경 영역의 검사가 통과하면 이유 없이 전체 측정을 반복하지 않는다.

## 바이옴 음원 재생성 (선택)

사용자가 제공한 지역 BGM35곡은 `assets/audio/region_music/manifest.json`에 ZIP/MP3/Ogg 지문과 전체 길이를 기록했다. `tools/import_region_music.py --archive /path/bgm_1.zip --archive /path/bgm_2.zip --archive /path/bgm_3.zip --archive /path/bgm_4.zip --catalog docs/bgm-candidates.json --output-dir /path/to/new-output`으로 재생성한다. 이 선택 도구만 ffmpeg/ffprobe가 필요하며 네트워크 다운로드를 하지 않는다. 후보 파일명은 악센트/구두점 차이를 정규화해 대조하고35곡 누락·중복·예상 밖 엔트리를 거부한다. 파일 경로를 ZIP 밖으로 추출하거나 첨부 문서를 실행하지 않는다. 음량은 두 단계 loudnorm(-18LUFS/true peak -2dB), Vorbis q5·48kHz·스테레오로 정리하며 전체 길이를 보존하고 메타데이터를 제거한다. 각 Ogg의 Godot import는 `loop=true`로 보관한다. 원본 ZIP/MP3는 사용자 첨부 자료로만 두고 Git에 중복 보관하지 않는다.

`RegionMusic.context()`와 GameMusic의 임시 캐시는 원정run_id별 지역 선곡을 유지한다. 같은 앱 실행 중 원정 복원/타이틀 재진입에도 같은 지역 곡을 쓰지만 앱 재시작 후에는 다시 고른다. 관장/사천왕/챔피언만 기존 전용곡이며 해당 원곡 ZIP을 추후 받으면 별도 작업으로 연결한다.

메뉴 음향은 `Preferences.watch_pause_menu()`가 메뉴의 실제 표시/제거를 추적하고 Music/Ambience만 필터링한다. 중첩 메뉴가 하나라도 남으면 먹먹함을 유지하며, 마지막 메뉴가 닫히면 완전히 우회한다. `native_region_music.gd`는 실제 X11 Esc/설정 클릭/지역 이동과 엔진 믹서의 자체 생성500Hz+6kHz 신호 캡처로 저역 통과 동작을 확인한다. 기존 `native_pointer.py`와 별도 사용자 프로필·Dummy 오디오·Godot4.7.2를 사용한다. 물리 스피커/헤드폰 청취 검사는 아니다.

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

보스 확장은 `boss_expansion.json`과 `BossExpansion`으로 분리했다. CampaignRoute v3만 합치며 v1/v2의 원본 gym/league JSON, RNG 호출과 서명을 그대로 유지한다. `test_boss_routes.gd`는 변경 전 기록한6개 서명·저장 복원·600개 새 경로의8/4/1구조·신규13대진 도달·역할 간 동일 인물 출현을 검사한다. `test_boss_music.gd`는137대진의 음악/개별 도트/대사3단계/방/전술·파티를 대조하고36곡 전체 디코딩·루프·독립 RNG·전투 중 선곡 고정을 확인한다.

`tools/import_boss_music.py --game-dir /path/game --archive /path/bgm1.zip ... --archive /path/bgm8.zip`은 사용자 첨부39MP3를 읽어36녹음으로 중복 제거한다. 지역 importer와 같은 변환을 사용하며137역할 매핑·별칭·파일명 미포함3인의 지역 공용곡 근거를 기록한다. Godot import에서 `loop=true`를 지정한다. `tools/boss_roster.py --game-dir /path/game --output-dir docs`로 목록을 갱신한다. `native_boss_music.gd`는 신규13대진의 실제 전투 씬·도트 입장·대사·전용곡·배경을 촬영하며 입장 연출이 끝난 뒤 실제 Esc로 보스곡 필터를 확인한다. 촬영 PNG는 로컬 검토용이며 커밋하지 않는다.

Headless 씬 검사는 종료 전에 GameAudio/GameMusic/GameCries뿐 아니라 GameAmbience도 즉시 정지한다. 지역 음악 도입 뒤 희귀 이야기 검사에서 이 정리가 누락돼 행위3609개는 통과했지만 종료 시 Ogg 자원 진단이 발생했다. test_rare_stories의 정리 대상에 환경음을 추가했으며 진단을 필터링해 통과 처리하지 않는다.

## 전국도감 확장 재현

`tools/pokedex/fetch_sources.py --game-dir /path/game --cache-dir /path/outside-game-cache`로 실행 데이터에 기록한26개 CSV의 SHA256을 대조하고 고정 PokéAPI 이미지/울음소리 저장소를 선택 sparse checkout한다. 게임 밖 캐시만 허용하며 원격/작업 내용이 다른 캐시를 덮어쓰지 않는다. `build_content.py`가 입력을 스트리밍해1,412항목·919기술·644진화분기와 최신 정규 레벨업 습득표, 기술 훈련 경로를 생성하고 메가/전투 전용 폼을 명시적으로 제외한다. 형식상 상시로 잘못 표시된 무한다이맥스와 이동 자세도 제외한다. 폼 ID는 Pokemon ID와 충돌하지 않게 별도 영역을 쓰며 데이터에 원본 Pokemon/Form ID를 함께 둔다.

`tools/pokedex/import_assets.py --game-dir /path/game --cache-dir /path/cache`가 실제 앞뒤 PNG/울음소리/진화 재료를 설치하고 출처 지문을 갱신한다. 이 도구만 Pillow·ffmpeg/ffprobe를 필요로 한다. 기존 파일을 보존하며 원본 CSV/asset checkout/검토 PNG는 Git에 넣지 않는다. 새 울음소리 전체의 Vorbis/PCM/길이를 검사하고, 게임 검사는1,412개체의 앞뒤 투명 경계·울음소리 실제 디코딩·Lv.5 습득표/성장·전국번호/조우/희귀 문턱을 대조한다.

`test_national_progression.gd`는 역사적v3서명·정확한 저장 roundtrip,9세대 진화·지역폼/합체 보호·기술 소유자별 교체·진화 준비/아이템·높은 폼ID의 포획UID·재료 재고 정수 직렬화를 검사한다. `native_pokedex.gd`는 실제 X11 포인터/키로 전투→연구→폼 준비→검색/훈련→도감 화면을 촬영한다. 스크린샷은 로컬 검토용이다. 빌드/export는 사용자가 보류했으므로 실행하지 않는다.

기술머신 데이터는 `python3 tools/pokedex/build_machines.py --game-dir /path/to/main --cache-dir /path/to/source-cache`로 재생성한다. 기존 고정 CSV의 SHA256을 검사하며 자료/원본 CSV는 게임에 넣지 않는다. `--suite camp`는 기술머신·성장·덱/야영·저장·경로 회귀를 실행한다. `tests/native_machines.gd`는 `tools/native_pointer.py`로 실제 X11 클릭을 사용하며 `TM_REVIEW_DIR`에 로컬 검토 PNG만 저장한다.

원작 기반 파티 컨펌 자료는 `docs/boss-party-review.json`이 기준이고 `python3 tools/boss_party_review.py --game-dir /path/to/main`으로 Markdown을 재생성/검증한다. `--workbook /path/outside-repo/review.xlsx`는 선택 openpyxl로 검토용 엑셀을 만든다. 게임 파일에 쓰지 않으며 `review_pending_not_applied`는 사용자 승인 전까지 유지한다. 실제 현재 역할/BGM 목록은 `boss-roster.*`와 구분한다.

승인 파티는 `scripts/content/boss_parties.gd`와 `data/boss_parties.json`, 경로 적용은 `campaign_route.gd`의v5분기다. `python3 tools/import_boss_parties.py --game-dir /path/to/main`은 승인/applied 상태 검토안만 가져오고 역사적 파티 JSON은 건드리지 않는다. `boss_roster.py`는 현재 승인 파티/대표를 BGM 목록에도 표시한다. 새 파티 검사는 `test_boss_parties.gd`, 주변 회귀는 `--suite boss-party-regression`이며 native는 `tests/native_boss_parties.gd` + `BOSS_PARTY_REVIEW_DIR`/실제 X11 입력 도구를 쓴다. EXE 보류 중에는 export/Windows workflow를 실행하지 않는다.

## 대표 기술·전술 명세

[전술 목록](boss-ace-tactics.md)은 계획1번의 결과이며 게임에는 미적용이다. 원작 참조와 제안을 각각 `boss-ace-references.json`/`boss-ace-tactics.json`에서 관리한다. `boss_ace_review.py`는 검증/문서 생성만 하며 게임 파일을 쓰지 않는다. 선택 의존성openpyxl은 엑셀 출력에만 필요하다.

```bash
python3 .dev-materials/tools/boss_ace_review.py --game-dir .
# 고정 출처 CSV가 있는 경우 실제 습득 증거도 재검증:
python3 .dev-materials/tools/boss_ace_review.py --game-dir . --csv-dir /path/to/pinned-csv \
  --workbook .dev-materials/docs/boss-ace-tactics.xlsx
```

현재 런타임 전술과 제안 기술의 플레이어 카드 정의를 비교하는 읽기 전용 Godot 도구도 있다. 실제 사용자 저장과 분리한 XDG/APPDATA 경로에서 실행한다. 출력 경로와 JSON 경로는 사용 환경에 맞춰 지정한다. 게임의 기존 전술만 읽는 감사이며 제안 전술 실행 검사가 아니다.

```bash
BOSS_ACE_AUDIT_OUTPUT=/tmp/boss-ace-current.json \
BOSS_ACE_SPEC_PATH=/absolute/path/to/.dev-materials/docs/boss-ace-tactics.json \
godot --headless --path . --script .dev-materials/tools/audit_boss_aces.gd
```

후속 효과 구현은 새 전술 버전을 먼저 설계한다. 기존v1~v5 저장을 읽고 다음 전투를 만들 때도 이전 전술을 유지해야 한다. 단순히 `BossTactics.build`를 덮어쓰거나 현행 지문을 바꾸는 것만으로 호환이 해결되지 않는다. 원작 상태/능력/부가효과가 플레이어 카드에 존재해도 적 공격 경로에 연결되어 있는지 별도로 검증한다.

## 보스 기술 효과 P0 구현

현재 [P0 적용 현황](boss-move-effects.md)은 새 원정v6의19대표/46기술이다. main의 `scripts/tactics/boss_move_effects.gd`가 기술별 예고/효과를 처리하고 `data/boss_move_effects_v6.json`이 동결 입력이다. `BossTactics.build`의 마지막 인자가 새 효과 선택이며 기존 기본값은false다. `CampaignRoute`가 v6의 실제 마지막 대표에만 선택하므로 일목의 첫 네이티오와 v1~v5의 미래 전투는 바뀌지 않는다. `JourneySnapshot`은 정확한 정수 기술/패턴/원정 버전을 검사한다.

```bash
python3 .dev-materials/tools/check.py --game-dir . --suite boss-effects --godot /path/to/godot-4.7.2
# 기존 v5 전137파티 검사는 source route_version=5로 명시:
godot --headless --path . --script .dev-materials/tests/test_boss_parties.gd
```

`tools/import_boss_move_effects.py --game-dir /path/to/main`은 고정 명세+원본 메타에서 v6 데이터를 결정적으로 생성한다. 이 v6 입력은 이미 사용한 저장의 미래 재생성을 위해 동결한다. 기존 P0를 수정하거나 P1/P2를 확장할 때 새 버전과 별도 입력을 만들고 호환을 설계한다. 전체 목표 JSON은 당시의 기준 자료로 유지하며,리뷰 Markdown/엑셀에는 실제 부분 적용 현황을 함께 표시한다.

실제 창 검사는 `native_boss_move_effects.gd`와 `native_pointer.py`로 카틀레야·이슬·은송의 명상/수면/날개쉬기를 확인한다. `BOSS_EFFECT_REVIEW_DIR`과 격리 프로필을 지정한다. 무작위 손패에 특정 소유 카드가 있다고 가정하지 않고,수면 카드 검사 시 실제 소유 카드를 더미에서 손패로 옮긴 fixture를 사용한다. 해당 촬영/검사는 전체 전투를 사람이 공략한 검사가 아니다.

## 대표 기술 효과 P1 구현

현재는 새 원정v7의41대표/실전95기술과 별도 잠꼬대 엔진 fixture다. `BossEffects`가 기존 v6 `BossMoveEffects`와 새 v7 `BossMoveEffectsP1`을 분기한다. 생성기 `tools/import_boss_move_effects_p1.py --game-dir /path/to/main`은 기존 v6 파일을 읽기만 하고 별도 `boss_move_effects_v7.json`을 생성한다. 이 파일도 저장 후속 재생성용 동결 입력이며 후속 확장은 새 버전이 필요하다. 원정 전술 선택은 `BossTactics.build`의 추가 `effects_version` 인자(기존 기본값1)로 분리했다.

```bash
python3 .dev-materials/tools/check.py --game-dir . --suite boss-effects-p1 --godot /path/to/godot-4.7.2
# 격리 프로필·X11 환경에서 실제 창 검사:
BOSS_P1_REVIEW_DIR=/tmp/boss-p1-review python3 .dev-materials/tools/native_pointer.py \
  --project-dir . --script .dev-materials/tests/native_boss_move_effects_p1.gd
```

전용 `test_boss_move_effects_p1.gd`는 모든41대표, 충전/날씨/재충전, 연타/보호막/기절, 반동/흡수/동시기절, 잠자기/잠꼬대 fixture, 잠긴 연속기의 중간 저장/복원과 v6 후속 정의 지문을 검사한다. `/tmp/boss-effects-v6-snapshot.bin`이 있는 개발 환경에서는 실제 수정 전 캡처도 추가 검증하며,없어도 기본 회귀는 가능하다. P0 검사는 명시적 v6,기존 파티 검사는 명시적 v5로 고정했다. 새 기본 경로 회귀는 v7이다. 실제 창 검사는6대진/10 OS Enter키이며 파티/앞 적 기절/대표 HP·행동 위치는 fixture다. EXE/export/Windows workflow는 계속 보류한다.

P1 후속 회귀에서 공용 `support/tactical_policy.gd`는 새 `move` 공격 예고와 수면 취소를 읽도록 보강했다. `test_save.gd`의69전투는 모든 보상을 건너뛰는 대신 이미 사용 중인 `CampaignPolicy.reward`로 실제 보상을 고른다. 기존 무보상 봇은 독수 구간7승 뒤 패배했으며 저장 형식 오류는 아니었다. 이 변경은 검사 플레이어에만 적용하고 게임 수치/경제/성장/난수는 바꾸지 않는다. 새 v7의69전투 저장 회귀와 혼합 보상/상점 원정을 따로 검증한다. `test_boss_effects_parity.gd`는 v6의19대표를 두 엔진에서 직접 실행해 예고/실제 HP·상태·단계·보호막이 같은지 비교한다.
