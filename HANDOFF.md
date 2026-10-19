# 현재 작업 인계

## 현재 상태

- main `1f97aed`: 포켓몬 연구의 긴 버튼/화면 폭 축소. [연구 화면 지도](docs/workshop-layout.md)부터 읽는다. 앞선 [Esc 음악 플레이어](docs/music-player.md), [UI 간격](docs/ui-spacing.md), 전종 애니메이션/야영 겹침/상대 진화 레벨 수정도 포함한다.
- 최신 요청은 연구 화면의 버튼이 좌우로 너무 길어 보기 불편하니 고치는 것이다. `pokedex_workshop.gd` 한 파일의 배치와 짧은 행동 문구만 수정했다.
- 창1280×920 두 열. 동료232×88 스프라이트/이름/레벨의 세로 카드, 탭144~160px, 교체 기술176px, 검색528px, 목록 실행184px. 주요 버튼 간격24px, 설명과 행동 버튼을 분리했다.
- 연구 대상·탭·검색·슬롯 선택/Esc 닫기 callback, 연구 비용/조건/획득·소모는 유지한다. 게임 규칙/게시 JSON/승인 파티/UID·RNG/배경 좌표/에셋은 바꾸지 않았다.
- **새 버전·EXE·빌드/export·Windows CI·Release는 사용자가 다시 요청할 때만 진행한다.** 태그/버전/워크플로 기본값 변경 없음.

## 실제 검증

- Godot4.7.2 실제 X11 1920×1080/Dummy `native_workshop_compact.gd` **한 묶음36검사/0실패·8 OS클릭**. 첫 실행 통과로 재실행하지 않았다.
- 동료/탭/검색·삭제/검색 초점 Esc를 실제 입력했다. 버튼 폭·간격·경계·설명 분리, 진화/기술 훈련/보유TM 목록을 확인했다. 원정·야영 fixture 전체 snapshot/UID·RNG/실제 저장 바이트 불변.
- PNG3장 모두 시각 확인. 증거 `/tmp/pokemon-workshop-compact/`, 로그 `/tmp/pokemon-workshop-compact-native.log` SCRIPT ERROR/ERROR/누수 없음. 기존 소프트웨어 VSync 안내만 있다. 보유TM2개는 검사 fixture이며 실제 저장에 반영하지 않았다.
- 기존 `native_ui_spacing.gd`의 기술 버튼 폭 조건도176px로 보정했다. 이 전체 UI 묶음, 전체919기술/69전투/전종 애니메이션/빌드·패키지는 반복하지 않았다. 연구 행동 실행·구매·소모 검사는 레이아웃 변경에 필요하지 않아 반복하지 않았다.

## 다음 한 단계

사용자의 새 화면 피드백을 우선한다. 배포 재요청 전 기존v0.28.1/태그/워크플로 기본값을 유지한다. 요청 시 누적 수정의 소스·자료 SHA/새 태그를 한 번에 갱신하고 공식 import/패키지를 검증한다.

이전 근거는 [고정 이전 인계](https://github.com/agree-git/pokemon-deckbuilder/blob/b3257756f41c0034c1a40002540e8972f06e36fd/HANDOFF.md)를 필요할 때만 읽는다.
