# 작업별 최소 파일 지도

모든 행을 읽을 필요는 없다. 아래 코드 경로는 게임 `main`,문서/검사는 `development-materials` 기준이다. 먼저 해당 엔트리만 읽고 필요한 호출자로 넓힌다.

| 요청 | 먼저 읽을 안내 | 코드 엔트리 | 검증 출발점 |
|---|---|---|---|
| 플레이어 기술 구현/남은 기술 | [기술 작업](docs/tasks/moves.md) | `scripts/tactics/player_techniques.gd` + 최신 효과 모듈 | 해당 효과/저장 검사 |
| 관장·사천왕·챔피언 기술 | [보스 효과](docs/boss-move-effects.md)의 해당 기술 | `scripts/tactics/boss_battle_rules.gd` + 해당 버전 엔진 | `tests/test_boss_move_effects_p3.gd` |
| 트레이너 명단/파티/대표 | [승인 파티](docs/boss-party-review.md),명단이면 [roster](docs/boss-roster.md) | `scripts/content/boss_parties.gd`,`data/boss_parties.json` | `tests/test_boss_parties.gd` |
| 저장 위치 변경/기존 파일 이전 | [저장 위치 지도](docs/save-location.md) | `scripts/persistence/save_location.gd`,`project.godot`; 배포는 자료 `build_windows.py`,`verify_export.py` | `tests/test_save_location.gd` 한 묶음; 빌드 금지 |
| 저장/불러오기/호환 | [기술 작업의 저장 지도](docs/tasks/moves.md) 또는 `rules`의 저장 절 | `scripts/persistence/journey_save.gd`,`journey_snapshot.gd` | `tests/test_save.gd` + 관련 효과 저장 |
| 아이템 이미지 크기/일반 트레이너/포획 모션 | [연출 지도](docs/presentation-polish.md) | `_item_sprite`,`trainer_sprites.gd`,`capture_motion.gd`,`tactical_ui.gd::_present` | `tests/native_presentation_polish.gd`; 포획만 `POLISH_CAPTURE_ONLY=1` |
| 포켓몬 이미지/움직이는 스프라이트 | [포켓몬 애니메이션](docs/pokemon-animation.md) | `scripts/content/pokemon_animation.gd`,`scripts/ui/pokemon_animation_player.gd`,`battle_canvas.gd`,`combat_widgets.gd` | `tools/pokemon_animations.py`;`tests/native_pokemon_animation.gd` |
| 기술 사용 동작/돌진·몸통·자세 복귀 | [기술 사용 모션](docs/combat-motion.md) | `scripts/ui/combat_motion.gd`,`battle_canvas.gd`,`tactical_ui.gd::_play_event` | `tests/native_combat_motion.gd`;종료 문제만 `native_combat_motion_flow.gd` |
| 독·마비·화상 등 상태이상 이펙트 | [효과 전용 지도](docs/status-vfx.md);원인 문구 추가 금지 | `scripts/ui/status_feedback.gd`,`tactical_ui.gd::_play_event`;내부 tick 키만 `tactical_battle.gd` | `tests/native_status_feedback.gd` 한 묶음 |
| 상대 레벨/진화 단계 | [상대 진화 단계](docs/enemy-evolution.md) | `scripts/tactics/enemy_evolution.gd`,`campaign_route.gd`,`tactical_journey.gd` | `tests/test_enemy_evolution.gd`;새 버전/EXE 보류 |
| 원정 다시하기 제거/시작·결과 화면 | [원정 다시하기 제거](docs/no-run-restart.md) | `tactical_ui.gd`,`tactical_journey_ui.gd`,`tactical_journey.gd::_initialize_run` | `tests/test_no_run_restart.gd` 11/0; 새 빌드 보류 |
| 자동 진화/훈련 전체 목록·야영 출발 경제 | [자동 진화·훈련](docs/camp-progression.md) | `national_evolution.gd`,`special_evolution.gd`,`camp_move_training.gd`,`tactical_journey.gd`,`pokedex_workshop.gd` | `tests/test_training_economy.gd` 217/0; 진화는 이전67/0 근거; 새 빌드 보류 |
| 도감/진화/습득 | [전국도감](docs/pokedex-expansion.md)의 해당 절 | `scripts/content/pokedex_expansion.gd`,`scripts/ui/pokedex_workshop.gd` | `tests/test_national_progression.gd` |
| 지닌 물건/소모/장착 | [원작 지닌 물건](docs/held-items.md)의 계약/해당 효과 | `scripts/tactics/held_items.gd`,`held_item_math.gd`;보상/장착이면 `tactical_journey.gd` | `tools/check.py --suite held-items` |
| 기술머신/야영 | `rules`의 야영 기술머신/야영지 절 | `scripts/tactics/technical_machines.gd`,`tactical_journey.gd` | `tests/test_machines.gd` |
| BGM/환경음/Esc 음악 플레이어 | [플레이어·최소 검사](docs/music-player.md),음원 자체를 바꾸면 해당 manifest | `scripts/audio/game_music.gd`,`scripts/ui/music_player_panel.gd`;환경음은 `game_ambience.gd` | `tests/native_music_player.gd` 관련 범위;전체 soundscape는 필요한 경우만 |
| 튜토리얼/첫 플레이 | [튜토리얼 지도](docs/tutorial.md) | `scripts/ui/tutorial_ui.gd`,`scripts/content/tutorial_lesson.gd`;권유는 `main_menu.gd` | `tests/native_tutorial.gd`;문구만수정하면layout만 |
| UI 간격/공간 활용/설정·메뉴 배치 | [UI 간격 지도](docs/ui-spacing.md);연구의 긴 버튼은 [연구 화면 지도](docs/workshop-layout.md) | 연구는 `scripts/ui/pokedex_workshop.gd`;그 외 해당 UI 파일 | 연구는 `tests/native_workshop_compact.gd` 한 묶음;전체 UI 검사는 필요할 때만.새 버전/EXE 보류 |
| 야영지 버튼/글자 겹침 | [야영지 UI](docs/camp-layout.md) | `scripts/ui/tactical_journey_ui.gd`,`pokedex_workshop.gd`,`combat_widgets.gd` | `tests/native_camp_layout.gd`;새 버전/EXE 보류 |
| 카드/화면/배치·실제 입력 검사 | [현재 화면 검사](docs/native-review.md),필요 시 `rules` 표시·조작 절 | `scripts/ui/tactical_ui.gd`,`trainer_action_card.gd`,`card_effect_text.gd`,`scripts/content/battle_card_preview.gd` 중 관련 파일 | 해당 문제만 native 대표 재검사;전체 자동 반복 금지 |
| 엔딩 크레딧/제작자 표시 | [엔딩 지도](docs/ending-credits.md) | `scripts/ui/ending_credits.gd`,`tactical_journey_ui.gd::_open_credits`,`main_menu.gd::_open_credits` | `tests/native_ending_credits.gd` 한 묶음 |
| 최종 원정/마무리·실행 안내 | [최종 원정 확인](docs/final-review.md) | `scripts/tactics/tactical_journey.gd`,`scripts/ui/tactical_journey_ui.gd`;main의 `PLAY_GUIDE.md`,`CHANGELOG.md` | 단일 `test_final_campaign.gd`;종료/새 원정은 `native_final_campaign.gd` |
| GitHub Releases 게시 | [수동 릴리스](docs/github-releases.md) | `.github/workflows/windows-release.yml`;자료의 `docs/releases/<tag>.md` | Windows runner 실제EXE 검사 후 게시;실행 전 게시완료로 보고하지 않는다 |
| 난도/밸런스·EXE 제작 | [도전 난도/배포](docs/campaign-challenge.md) | `scripts/tactics/campaign_challenge.gd`,`data/campaign_challenge_v28.json` | `tests/test_challenge_contracts.gd`;실제 변경에 필요한 작은 시드/창만 검사 |
| 설치/실행 환경 | [환경 준비](docs/setup.md) | `project.godot` | 필요 시 `tools/check.py --suite smoke` |
| 문서/읽기 비용 개선 | [START_HERE](START_HERE.md) | 이 파일 + 해당 문서 | 링크/경로/변경 범위 확인;게임 검사 없음 |

`rules`=[확정 규칙](docs/rules.md),`development`=[개발 안내](docs/development.md). 해당 절 제목을 먼저 검색한다. 과거 결과/실패 근거가 필요할 때만 [검증 기록](docs/validation.md)이나 [과거 자료](docs/history.md)를 조회한다.
