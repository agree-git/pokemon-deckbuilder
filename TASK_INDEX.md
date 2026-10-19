# 작업별 최소 파일 지도

모든 행을 읽을 필요는 없다. 아래 코드 경로는 게임 `main`,문서/검사는 `development-materials` 기준이다. 먼저 해당 엔트리만 읽고 필요한 호출자로 넓힌다.

| 요청 | 먼저 읽을 안내 | 코드 엔트리 | 검증 출발점 |
|---|---|---|---|
| 플레이어 기술 구현/남은 기술 | [기술 작업](docs/tasks/moves.md) | `scripts/tactics/player_techniques.gd` + 최신 효과 모듈 | 해당 효과/저장 검사 |
| 관장·사천왕·챔피언 기술 | [보스 효과](docs/boss-move-effects.md)의 해당 기술 | `scripts/tactics/boss_battle_rules.gd` + 해당 버전 엔진 | `tests/test_boss_move_effects_p3.gd` |
| 트레이너 명단/파티/대표 | [승인 파티](docs/boss-party-review.md),명단이면 [roster](docs/boss-roster.md) | `scripts/content/boss_parties.gd`,`data/boss_parties.json` | `tests/test_boss_parties.gd` |
| 저장/불러오기/호환 | [기술 작업의 저장 지도](docs/tasks/moves.md) 또는 `rules`의 저장 절 | `scripts/persistence/journey_save.gd`,`journey_snapshot.gd` | `tests/test_save.gd` + 관련 효과 저장 |
| 도감/진화/습득 | [전국도감](docs/pokedex-expansion.md)의 해당 절 | `scripts/content/pokedex_expansion.gd`,`scripts/ui/pokedex_workshop.gd` | `tests/test_national_progression.gd` |
| 지닌 물건/소모/장착 | [원작 지닌 물건](docs/held-items.md)의 계약/해당 효과 | `scripts/tactics/held_items.gd`,`held_item_math.gd`;보상/장착이면 `tactical_journey.gd` | `tools/check.py --suite held-items` |
| 기술머신/야영 | `rules`의 야영 기술머신/야영지 절 | `scripts/tactics/technical_machines.gd`,`tactical_journey.gd` | `tests/test_machines.gd` |
| BGM/환경음/일시정지 소리 | `development`의 바이옴 음원 절,사용자 제공곡이면 해당 manifest | `scripts/audio/region_music.gd`,`boss_music.gd`,`game_ambience.gd`,`game_audio.gd` 중 관련 파일 | `tools/check.py --suite soundscape` |
| 튜토리얼/첫 플레이 | [튜토리얼 지도](docs/tutorial.md) | `scripts/ui/tutorial_ui.gd`,`scripts/content/tutorial_lesson.gd`;권유는 `main_menu.gd` | `tests/native_tutorial.gd`;문구만수정하면layout만 |
| 카드/화면/배치·실제 입력 검사 | [현재 화면 검사](docs/native-review.md),필요 시 `rules` 표시·조작 절 | `scripts/ui/tactical_ui.gd`,`trainer_action_card.gd`,`card_effect_text.gd`,`scripts/content/battle_card_preview.gd` 중 관련 파일 | 해당 문제만 native 대표 재검사;전체 자동 반복 금지 |
| 최종 원정/마무리·실행 안내 | [최종 원정 확인](docs/final-review.md) | `scripts/tactics/tactical_journey.gd`,`scripts/ui/tactical_journey_ui.gd`;main의 `PLAY_GUIDE.md`,`CHANGELOG.md` | 단일 `test_final_campaign.gd`;종료/새 원정은 `native_final_campaign.gd` |
| GitHub Releases 게시 | [수동 릴리스](docs/github-releases.md) | `.github/workflows/windows-release.yml`;자료의 `docs/releases/<tag>.md` | Windows runner 실제EXE 검사 후 게시;실행 전 게시완료로 보고하지 않는다 |
| 난도/밸런스·EXE 제작 | [도전 난도/배포](docs/campaign-challenge.md) | `scripts/tactics/campaign_challenge.gd`,`data/campaign_challenge_v28.json` | `tests/test_challenge_contracts.gd`;실제 변경에 필요한 작은 시드/창만 검사 |
| 설치/실행 환경 | [환경 준비](docs/setup.md) | `project.godot` | 필요 시 `tools/check.py --suite smoke` |
| 문서/읽기 비용 개선 | [START_HERE](START_HERE.md) | 이 파일 + 해당 문서 | 링크/경로/변경 범위 확인;게임 검사 없음 |

`rules`=[확정 규칙](docs/rules.md),`development`=[개발 안내](docs/development.md). 해당 절 제목을 먼저 검색한다. 과거 결과/실패 근거가 필요할 때만 [검증 기록](docs/validation.md)이나 [과거 자료](docs/history.md)를 조회한다.
