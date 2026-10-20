# 원정 다시하기 제거

2026-10-20 사용자 요청: 원정 다시하기 버튼과 기능 제거. 새 빌드/릴리스 요청이 아니다.

- `scripts/ui/tactical_ui.gd`: run_mode에서는 일시정지 메뉴의 다시 시작/승패 결과의 원정 다시하기 버튼을 만들지 않는다. run_restart_requested 신호 제거. 직접 restart 호출도 원정에서는 무변경 반환. 단독 전투의 재연습과 튜토리얼의 restart_lesson은 원정 재시작이 아니므로 유지한다.
- 승패·포획 결과의 계속 진행 버튼은 빈 재시작 자리를 사용한다. result_restart가 없는 원정에서도 대사/포획 결과 배치 시 null 접근을 하지 않는다.
- `scripts/ui/tactical_journey_ui.gd`: 같은 시드/새 시드 재출발 버튼·콜백/신호 연결 제거. 최종 패배·클리어 결과는 중앙 시작 화면 버튼1개,클리어의 엔딩 크레딧 다시 보기는 유지.
- `scripts/tactics/tactical_journey.gd`: 공개 restart API 제거,생성자에서만 `_initialize_run`으로 초기화. 새 원정은 시작 화면의 스타팅 선택→새 객체 생성 경로를 사용한다. 기존 객체를 새 시드로 재사용하지 않는다. 저장 복원도 동일 생성자 경로를 계속 사용한다.
- PLAY_GUIDE 반영. 저장 필드·경로/RNG·데이터 JSON/파티·전투/경제·훈련/버전·workflow·기존 태그는 불변.

## 좁은 확인

공식4.7.2 격리headless 소스 `tests/test_no_run_restart.gd` **11/0**,깨끗한 종료. 정상 새 원정 생성/정확한 기존 저장 복원,원정 메뉴·승패 결과에서 재시작 버튼 부재,신호/같은·새 시드 핸들러 제거,직접 전투 restart 호출의 상태·RNG 무변경,실제 패배 계속 진행→동일run_id 최종 결과/중앙 버튼,최종 저장 복원/클리어의 크레딧 다시 보기 유지 확인. 로그 `/tmp/pokemon-remove-restart/test.log`.

기존 start/machines/rare_capture 검사는 새 객체 생성으로 기대값을 바꿨고 native_ui_spacing/rare_reactions는 삭제된 버튼 참조를 정리했다. 해당 넓은 검사는 재실행하지 않았다. 전체 전투·기술/실제 창·Windows EXE/빌드/export/CI·새 릴리스 미실행.
