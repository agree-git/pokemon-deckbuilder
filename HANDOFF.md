# 현재 작업 인계

- 최신 요청: **원정 다시하기 버튼과 기능 제거**. 수정·main 반영만,새 버전/빌드/Release 요청 아님. 빌드는 명시 요청 때 GitHub에서만,로컬 build/export/ZIP 금지.
- 게임 `364b19a1d418e88651d11823b3de54359bd6dbbb`. [원정 재시작 제거 지도](docs/no-run-restart.md)부터 읽는다.
- 원정 pause 메뉴/전투 승패·포획 결과의 재시작 버튼 및 run_restart_requested 신호 제거. 원정에서 직접 TacticalUI.restart 호출도 무변경. 단독 전투 재연습/튜토리얼 자체 연습 재개는 유지.
- 최종 결과의 같은 시드·새 시드 재출발 버튼/핸들러 제거,중앙 시작 화면 버튼1개로 정리. 클리어의 엔딩 크레딧 다시 보기 유지. 새 원정은 시작 화면의 스타팅 선택에서 시작한다.
- TacticalJourney의 공개 restart API 제거,생성자 전용 `_initialize_run`으로 초기화. 기존 객체 재시작 없음. 새 객체 생성·저장 복원 경로 유지. UI 결과 배치의 null 참조 정리.
- 저장 형식·내용/경로·전투 RNG/승인 파티/배경좌표/게시 JSON/진화·훈련·경제·게임 버전 불변. PLAY_GUIDE 동기화.

## 실제 검사

- 공식4.7.2 격리headless `tests/test_no_run_restart.gd` **11/0**,깨끗한 종료. 생성자·정확한 저장 복원,메뉴/승패 결과 버튼·신호 부재,직접 restart 무변경,실제 패배 계속 진행·run_id 유지,최종 제목 버튼/저장 복원/크레딧 재생 버튼 확인. `/tmp/pokemon-remove-restart/test.log`.
- 기존 start/machines/rare_capture 검사의 재시작을 새 객체 생성으로 대체하고 native_ui_spacing/rare_reactions의 삭제 버튼 참조를 정리했다. 해당 검사들은 재실행하지 않았다.
- 전체919/69전투/실제 창·Windows EXE/빌드/export/CI·새 릴리스 미실행.

## 배포·다음 단계

- 기존 준비된 v0.28.6 태그=81c600b8afe2be7cba294d1b7086e38d29e2e434,workflow 입력/태그는 이동하지 않았다. 이번 수정은 그 버전에 포함되지 않는다. 새 빌드는 다시 명시 요청을 따른다.
- 다음은 사용자 수정사항 대기. 다음 릴리스는 새 버전/게임·자료 SHA/새 태그로 GitHub 수동 준비. 새 dispatch 도구가 없으면 사용자 새 Run workflow 필요.
- 직전 [고정 인계](https://github.com/agree-git/pokemon-deckbuilder/blob/c3deb7ea461e62ff68837c118ce2bfc87795d8a6/HANDOFF.md)에 진화/훈련·복리 경제/217검사·v0.28.6 준비 근거 보관. ASSET_SOURCES.md·CHANGELOG.md 복구금지,DO·기존 엔딩 양식 유지.
