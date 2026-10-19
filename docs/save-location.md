# 저장 위치와 기존 데이터 이전

사용자가 2026-10-20 **실제 저장 위치도 `%APPDATA%\PokemonExpedition`으로 변경하고 기존 저장을 이전**하도록 선택했다. 버전/저장 스키마/원정 RNG·동결 콘텐츠는 변경하지 않는다. 로컬 빌드/export/ZIP 전달은 금지하며 향후 명시 요청 때 GitHub Actions·Releases에서만 제작한다.

## 최소 파일 지도

- main `project.godot`: custom user dir `PokemonExpedition`, 첫 autoload `SaveLocation`을 Preferences·BattleSession보다 먼저 초기화한다. Windows `%APPDATA%\PokemonExpedition`, Linux `$XDG_DATA_HOME/PokemonExpedition`.
- main `scripts/persistence/save_location.gd`: 이전 기본 폴더의 정상 저장 파일만 복사한다. Windows의 기존 `%APPDATA%\Godot\app_userdata\포켓몬 원정대`, Linux의 `godot/app_userdata/포켓몬 원정대`를 찾는다. 원본을 삭제하거나 변경하지 않는다.
- 원정 `journey.json.head/.bak/본체`는 한 묶음, 도감 `collection.json.bak/본체`는 한 묶음, `settings.cfg`는 독립 묶음이다. 대상에 어느 파일이라도 있으면 그 묶음 전체를 건드리지 않아 다른 원정의 본체/완료 마커/백업이 섞이지 않는다. logs·미완료tmp는 가져오지 않는다.
- 먼저 비공개 staging에 원본을 복사/지문 대조하고 plan을 저장한다. 재개 시 전체 staging과 대상 충돌을 검사한 뒤 완료head→backup→본체 순으로 설치한다. 중단된 단계는 지문이 같은 대상만 재사용하며 다른 파일을 덮어쓰지 않는다. 완료 마커 뒤에는 다시 가져오지 않는다. 오류는 원본을 남기고 안내 후 종료해 불완전한 상태로 플레이하지 않는다.
- 기존 JourneySave/PlayerProfile/Preferences의 user:// 경로와 저장 바이트/형식·호환 지문은 유지한다. 파일 위치만 바뀐다.

## 실제 최소 검증

`tests/test_save_location.gd`: 격리 `/tmp/pokemon-docs-savepath`와 공식4.7.2 headless 소스 실행. **부모24+별도 첫 실행6=30검사/0실패**. 실제 v28 원정/도감/설정 fixture를 저장해 정상 파일·head·backup의 바이트 동일/기존 원본 보존/정확한 원정·RNG 복원/새 진행 덮어쓰기 방지/대상head만 있는 충돌/완료 원정 백업 부활 방지/staging 재개/손상된 staging 거부/신규 설치를 확인했다. 별도 프로세스에서 실제 autoload 순서로 기존 파일을 이전한 후 원정·도감·배속·음량·튜토리얼을 읽는 것도 확인했다.

첫 로드는 검사 함수명 seed가 Godot 전역 함수와 충돌해 검사 전 파싱 실패했다. prepare_fixture로 고친 뒤 위 묶음1회 통과. 게임 오류로 보고하지 않는다. 실제 Windows OS/Windows API 실행·네이티브 화면/EXE/전체 회귀는 실행하지 않았다. 로그 `/tmp/pokemon-docs-savepath/test.log`.

## 문서·배포 연결

사용자 첨부 `Credit.txt`/`README-Windows.txt`/`PLAY_GUIDE.md` 반영. Credit.txt 바이트는 첨부 그대로, 엔딩 JSON은 같은9절이다. 안내 문서는 삭제한 ASSET_SOURCES.md/CHANGELOG.md 참조를 정리하고 승인된 저장 경로와 자동 이전을 설명한다. 원문 에셋/라이선스 파일은 assets/sources·licenses에 유지한다.

자료의 `tools/build_windows.py`는 main의 README-Windows.txt를 그대로 복사하고 내장 안내문을 다시 생성하지 않는다. 제거한 두 문서에 의존하지 않으며 검사 전용 custom user dir를 중복 없이 바꾼다. `verify_export.py`의 격리 제품 경로도 PokemonExpedition에 맞춘다. 이 도구들의 구문/연결만 정적으로 확인했으며 **빌드/export/새 CI/Release는 실행하지 않았다**. 게시된 v0.28.4 태그와 workflow 입력은 동결한다. 다음 릴리스 요청 시 새 버전·정확한 새 게임/자료 SHA·새 태그로 준비한다.
