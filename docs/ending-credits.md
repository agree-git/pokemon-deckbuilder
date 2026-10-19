# 엔딩 크레딧

사용자 요청으로 제작자는 **DO**로 표기한다. v0.28.4 전시용 UI이며 저장·전투·콘텐츠 버전을 올리지 않는다.

## 파일과 동작

- 게임 `scripts/ui/ending_credits.gd`: 고정 명예의 전당/실제 동료3마리·성적, 독립 자동 스크롤과 제작·에셋 출처. 애니메이션 스프라이트 재사용. 별도 음악 변경 없이 결과 화면의 기존 title 테마를 유지한다.
- `tactical_journey_ui.gd`: 전체 원정 CLEARED에 도달한 화면에서 run_id별1회 자동 열기, 결과의 다시 보기 버튼. 짧은 원정/패배는 자동 열지 않는다. 표시 여부는 화면 메모리만 사용하고 저장하지 않는다.
- `main_menu.gd`: 시작 화면의 크레딧 버튼. 원정 없이도 열고 닫는다.
- Space/버튼 일시정지·재생, 화살표/휠 스크롤, Esc/Enter/버튼 복귀. 마지막 감사 문구에서 멈추고 처음부터 재생 가능. 전체 화면 모달이 하위 클릭·키를 차단한다. 크레딧을 닫는 Esc는 일시정지 메뉴를 열지 않는다.
- 기존 ASSET_SOURCES.md/원문 고지는 배포에 유지하며 화면에는 요약 출처와 전체 고지 위치를 표시한다.

## 최소 검사

`tests/native_ending_credits.gd`: **28검사/0실패, 실제7클릭·4키**, Godot4.7.2/1920×1080/Dummy audio. 기존 공개 행동으로 실제69전 클리어한 v27 스냅샷을 복원해 자동 열기·3동료/통계·DO·하위 재출발 클릭 차단·정지·수동스크롤·재생·감사 문구의 화면 내부 배치·끝/다시 재생·건너뛰기·결과 다시보기·시작 크레딧·짧은 원정/패배 제외·원정/RNG/저장 바이트 불변을 함께 확인했다. 전체69전을 재실행한 결과는 아니다.

최초 시도는 PATH가 기본Godot4.6.3을 선택하고 검사 스크립트의 타입 추론 오류로 검사 전 로드 실패했다. 문자열 타입을 명시하고 공식4.7.2 PATH로 수정해 위 묶음1회 통과했다. 게임 동작 오류를 발견한 것으로 보고하지 않는다.

현재 로컬 근거는 `/tmp/pokemon-ending-credits/native.log`, `01-ending.png`, `02-thank-you.png`, `03-title-credits.png`. 3PNG를 직접 보았다. 재검사 시 개인 데이터와 분리한 XDG를 사용하고 native_pointer가 PATH의 godot을 쓰는 점을 확인한다. 실제 전체 클리어 스냅샷은 `/tmp/pokemon-final-20261019/review/final.bin`; 없으면 완료 fixture라고 구분해서 만들고 실제69전으로 주장하지 않는다.

별도 배포 검사 `tests/test_export.gd`는 버전0.28.4/DO/스크롤 노드/마지막 정지의 packed 리소스 로드를 추가 확인한다. UI만 수정할 때 이 전체 배포 검사를 자동 반복하지 않는다.

결과 성장 패널(y832~972)과 다시 보기 버튼의 겹침을 발견해 버튼을 왼쪽 메뉴(x96,y886,w340,h62)로 옮겼다. 이전 시험 태그v0.28.3은 미게시 상태로 보존하고 수정 최종판을v0.28.4로 배포한다. v0.28.3의 진행 중 로컬 import 빌드는 중단했으며 그 빌드 검사를 통과했다고 보고하지 않는다. 최종 태그는 패키지 확인 뒤 준비한다.

최종 배치 범위 `ENDING_GEOMETRY_ONLY=1`: **7검사/0실패**, 실제 완료 스냅샷의 성장 패널3개/시작 화면 버튼과 비중첩 확인 및 `04-result-layout.png` 확인. 전체28검사는 반복하지 않았다.

## 첨부 Credit.txt 형식 반영

사용자가 YOUNG의 Pokémon: Another Red Credit.txt를 제공해 같은 구성으로 요청했다. 우리 게임의 실제 자료만 Name/Version/Website/Credits/License별로 정리했다. 구성 참고에 YOUNG를 명시하고, 사용하지 않은 DBK·RPG Maker 플러그인이나 다른 게임의 테스트 인물을 이 게임 제작진으로 복사하지 않았다.

원본 목록은 main `assets/sources/expedition_credits.json`의18개 절이다. 첫 제작자는 DO다. main `Credit.txt`에는 동일 절과 기존 TRAINER_FAN/EBDX/PokéRogue 원문 고지를 수정 없이 합쳐1,347줄로 보관한다. 고지를 포함한 다른 엔진 이름은 재사용 이미지의 원문 출처이며 게임 실행은 Godot임을 구분한다. `ending_credits.gd`가 JSON을 읽고 자동롤에 자료별 출처를 표시하며, ‘상세 크레딧’은 전체 Credit.txt를 읽는 RichTextLabel 뷰어다. 상세 창 중 자동롤 정지/휠스크롤/Esc 우선 닫기를 지원한다.

`tools/build_windows.py`가 Credit.txt를 source hash에 넣고 격리 snapshot/PCK/외부 배포 폴더에 복사한다. `tests/test_export.gd`가 packed Credit.txt의 DO와 실제 로드를 확인한다. 18절·원문3파일의 원문 일치도 정적으로 확인했다.

상세 뷰어 추가 후 관련 묶음 **72검사/0실패, 실제8클릭·5키**, 공식4.7.2. 전체 원문 표시·휠·자동롤 보류·Esc 우선 닫기·모든 롤 문구 폭·기존 원정/RNG/저장 바이트 불변 포함. 로그 `/tmp/pokemon-ending-credits/native-detailed.log`, `05-full-credit.png` 확인. 새 기능 추가에 따른 관련 묶음 실행이며 전체 UI/919기술/69전투는 반복하지 않았다.
