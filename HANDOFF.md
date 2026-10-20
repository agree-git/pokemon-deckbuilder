# 현재 작업 인계

- 최신 요청: “한글 검색 확인 못해?” 실제검증요청. 이전요청: 튜토리얼 안내 버튼 외 입력 차단,지역 내4×2격자를 화살표 연결 가로 카드4개 viewport로 변경. 추가로 이전 패치에도 한글 입력이 안 됨·기술 가르침 명칭·이미 습득한 기술 최상단 요청. 수정·main 반영만,새 빌드/Release 요청 아님. GitHub 빌드만·로컬 export/ZIP 금지.
- 게임 `c255a3e172ff987ef08fff2a1d15422dc49ea397`. [튜토리얼·이동 카드](docs/tutorial-route-ui.md),[입력·정렬](docs/workshop-search.md) 중 해당 파일부터 읽는다.
- TutorialInputGate는 현재 허용 Control만 포인터 hole. TutorialUI는 단계별 카드/다음/턴종료/포획/휴식/강화열기→카드선택→확정만 허용,다른 메뉴·취소와 단축키 차단. Tab도허용버튼만,연습나가기·Esc/F11 유지. 기존 행동권한 검사도 유지.
- JourneyStageStrip은260×280카드/50간격/1190×312viewport. 같은지역 전투8개·리그5개 원순서/화살표·완료/현재·전술 tooltip·희귀 정체 숨김 유지. 좌우4개 이동·스크롤/현재 구간 자동표시,실제경로·배지요약·이동액션불변.
- 검색은 LineEdit→단일행 TextEdit, native get_line_with_ime으로 확정/조합 중 음절 모두 읽는다. 이전 조합 종료 대기는 폐기. native 텍스트·커서를 조합 중 덮어쓰지 않고 결과는기존노드visible만 변경. Enter는조합확정/줄바꿈차단,붙여넣기확정줄바꿈평탄화.
- 기술 가르침 명칭은탭/액션/오류/이후기록·가이드에반영. 현재습득기술우선·그안ID순,이미습득비활성,새가르침후에도위로정렬. 내부 train_move/moves 키는유지. 가격100/200·야영행동독립/TM/복리경제/자동진화/재시작제거/저장·RNG/승인파티·배경·게시JSON불변.

## 실제 검증과 한계

- 공식4.7.2 격리headless `test_tutorial_route_ui.gd` **81/0**,깨끗한종료. Viewport GUI 마우스·키로금지입력/전체안내흐름완료·실제원정/저장바이트/도감·RNG보존,8지역+리그의4카드·단일행·화살표·좌우끝·현재구간·경로불변. `/tmp/pokemon-tutorial-route/test.log`.
- `test_workshop_search.gd` **27/0**,깨끗한종료. 새TextEdit 확정한글/숫자/커서·포커스/필터·Enter·붙여넣기·노드유지·Esc,기술가르침명칭/기존·신규습득우선정렬·가격/야영행동불변. `/tmp/pokemon-tutorial-route/search.log`.
- 실제X11/Xvfb+Fcitx5 Hangul기본외부조합 **9/0**,OS자판으로전광석화/전기·삭제/재입력/확정·포커스/필터/원정불변확인,스크린샷확인. inline은9중6실패,IBus/기본TextEdit도음절손실재현. `docs/workshop-search.md`의추가절과native검사2개·OS드라이버참조. 게임코드추가변경없음.
- **Windows 한글 IME 실기는 여전히 재현·검증 못함.** 이전 LineEdit 대기는 사용자 확인상 실패해교체했다. 확정Unicode 이벤트통과를실제IME해결로단정하지않는다. 초기검사만동적배열타입/없는TextEdit속성정리후위범위검사했다.
- 이번실제창·OS클릭/픽셀확인은검색창에만수행. Windows/전체919기술·69전투/빌드/export/CI·새릴리스미실행. 기존전체회귀는반복하지않았다.

## 다음 단계

- Windows검증은추가환경필요. Linux기본입력기통과를전체해결로오해하지않는다. inline실패는기본TextEdit에서도재현되어앱추측수정대신엔진/OS확정경로추가분석필요. 현재실행버전사용자질문대기(main교체는구v7태그미포함). 새릴리스요청때새버전·태그·게임/자료SHA로GitHub수동준비한다.
- 기존v0.28.7태그=71d914e5ca816e4c439a2b38d63bdfa339c96340/기본입력은동결,이번수정미포함. 과거실행재실행금지. 새dispatch도구없으면사용자새Run workflow필요.
- 이전 [고정 인계](https://github.com/agree-git/pokemon-deckbuilder/blob/61f2d5503f46cbe1170a415eb1eb4ba110788d42/HANDOFF.md)에v0.28.7 준비·재시작제거·기존검색근거보관. ASSET_SOURCES.md·CHANGELOG.md 복구금지,DO·기존엔딩양식유지.
