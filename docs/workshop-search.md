# 기술 가르침 검색·한글 입력 교체

2026-10-20 사용자가 이전 패치 뒤에도 한국어 입력이 안 된다고 확인했다. 명칭을 **기술 가르침**으로 바꾸고 이미 습득한 기술을 맨 위로 표시하도록 추가 요청했다. 이번은 수정·main 반영만,새 빌드 요청 아님.

## 현재 구현

- `scripts/ui/search_text_input.gd`: LineEdit 대신 TextEdit 기반 단일행 검색. `get_line_with_ime(0)`으로 확정 문자와 현재 조합 음절을 함께 읽고 query_changed를 알린다. 조합 종료까지 기다리던 이전 경로를 제거했다. 조합 중 native 텍스트/포커스/커서를 덮어쓰지 않는다.
- Enter는 native apply_ime으로 명시 확정하고 줄바꿈을 막는다. Ctrl+V/Shift+Insert와 컨텍스트 붙여넣기의 확정된 줄바꿈만 공백 처리한다. TextEdit 자체 편집·선택·Undo/한글 조합은 native 구현을 쓴다.
- `pokedex_workshop.gd`: 입력 알림에서는 query/다음 프레임 예약만,그다음에 최신 조합 포함 query로 visible 결과를 갱신한다. 기존 검색 결과 Control/빈 안내 재사용 유지. 이름·번호·타입/진화·폼·가르침·TM 공통. search.text를 매 입력에 다시 쓰지 않는다.
- 가르침 목록은 learned_skills에 있는 기술 우선,각 묶음 안에서는 기존ID순. 습득 완료 비활성 버튼으로 표시하고 가르침 뒤 rebuild에서도 새 습득 기술이 위에 온다. 합법 목록·가격100/200·야영 행동 독립·TM 소모 방식 불변.
- tab/액션/성공·부족 골드 안내·향후 원정 기록의 사용자 명칭을 기술 가르침으로 바꾸고 PLAY_GUIDE 동기화. 내부 train_move/모드moves/파일 이름은 호환을 위해 유지한다.

## 실제 검사와 중요한 한계

공식4.7.2 격리headless `tests/test_workshop_search.gd` **27/0**,깨끗한 종료. 실제 원정 UI 연구창에서 확정 한글 연속입력/포커스·caret·결과 Control ID,번호키·전체선택/삽입·삭제·복원,기술명·타입/TM검색·Enter 단일행·붙여넣기 평탄화·Esc,표시 명칭·기존 습득기술/새로 가르친 기술 최상단,기존 가격·야영 행동과 검색 중 실제 원정/RNG 불변. `/tmp/pokemon-tutorial-route/search.log`.

## 실제 한글 자판 검사 — 2026-10-20 추가

사용자의 “한글 검색 확인 못해?” 요청으로 Xvfb1920×1080·실제 Korean XIM을 root 권한 없이 /tmp에 준비했다. 공식4.7.2 소스를 실행하고 xdotool의 실제 X11 키/마우스 이벤트로 두벌식 `wjsrhkdtjrghk`→전광석화,`wjsrl`→전기를 입력했다. 완성 한글 붙여넣기/InputEvent 주입이 아니다. 게임 코드는 이번 검사에서 변경하지 않았다.

- **Fcitx5 Hangul 기본 외부 조합(UseOnTheSpot=False): 9/0 통과.** 여러 음절 유지,조합 중 확정된 접두어 검색,Enter 전체 확정/줄바꿈 없음,Ctrl+A·삭제/재입력·조합 Backspace,타입 결과/포커스/결과노드ID/원정·RNG 불변. 스크린샷에서 전기 입력과 전기 타입 결과 확인. 외부 조합의 마지막 음절은 입력기가 확정한 뒤 검색에 반영되며,실시간 inline 조합 통과를 의미하지 않는다.
- **Fcitx5 inline(UseOnTheSpot=True): 9검사 중6실패.** 전→ㄱ으로 넘어갈 때 확정 전이 TextEdit.text에 들어오지 않고 마지막 조합 음절만 남는다. IBus Hangul inline도 동일 계열 실패(첫 문자 XIM 활성화 시점 영향 포함). 실패를해결/통과로표시하지않는다.
- 검색/필터 없는 기본 TextEdit(`native_textedit_korean_baseline.gd`)에서도 inline 음절 손실 재현. 이 Linux 증상은 게임 필터만의 문제로볼수없다. 공식 Godot4.7.2 `platform/linuxbsd/x11/display_server_x11.cpp::_handle_key_event`는 ime_in_progress 동안 키이벤트를반환하며 XIM callback은다음preedit상태를바꾼다. 원인 후보이지만 엔진패치 실험은안했으므로 확정 원인으로 단정하지않는다.
- **Windows Microsoft 한글 IME는 여전히 미검증.** 이 환경에는 Windows 데스크톱 실행도구가없다. Linux XIM 실패/성공을 Windows 결과로 일반화하지 않는다. 최신 검색 입력창교체 c255a3e는 main에만있고 기존v0.28.7태그에는없다.

### 재현 파일과 실행

`tests/native_workshop_korean_ime.gd`는 실제 검색창,`tests/native_textedit_korean_baseline.gd`는 기본 TextEdit 비교용이다. `tools/native_korean_ime.py`는 OS키/마우스만 전달한다. Godot4.7.2·Xvfb·Fcitx5+Hangul·xdotool을 준비하고 XMODIFIERS=@im=fcitx인 독립D-Bus세션에서 Fcitx를 띄운다. 검사당하나의입력기만사용한다. Fcitx xim.conf의 UseOnTheSpot와 아래모드를일치시킨다. 실제 사용자 저장 경로가 아닌 /tmp/pokemon-native-ime/하위 XDG_DATA_HOME을필수로사용한다.

```bash
export XDG_DATA_HOME=/tmp/pokemon-native-ime/data
export POKEMON_IME_MODE=external  # inline일 때는 현재 재현 실패를 기대
export POKEMON_IME_OUTPUT=/tmp/pokemon-native-ime
python3 .dev-materials/tools/native_korean_ime.py \
  --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --project-dir . --script .dev-materials/tests/native_workshop_korean_ime.gd \
  --activate-fcitx
```

검사기반 준비 실패(입력기 미연결/영문만입력)는 실제한글검사결과에포함하지않는다. 원본로그 `/tmp/pokemon-native-ime/workshop-fcitx-{external,inline}.log`,IBus `/tmp/pokemon-native-ime/test.log`,기본TextEdit `/tmp/pokemon-native-ime/minimal.log`;스크린샷 `/tmp/pokemon-native-ime/korean-search.png`. 환경 패키지/긴로그/개인데이터는커밋하지않는다. 상세요약은 `docs/reports/2026-10-20-native-korean-ime.json`.

전체919기술·69전투/Windows/빌드/export/CI·새릴리스는미실행. 사용자의 새빌드요청이없어 릴리스동결유지. Windows한글조합해결을완료로선언하지않는다.
