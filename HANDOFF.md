# 현재 작업 인계

## 현재 상태

- 튜토리얼 게임소스 `a000509fbfef57b8ceeb6ff1456909d39f4e5810`: 최초새원정의선택형권유/상시실습버튼과실제전투·포획·야영휴식/강화11단계추가. [튜토리얼지도](docs/tutorial.md)만먼저읽는다. main push/EXE재개는기존승인범위다.
- 별도practice상태만사용하며기존원정/실제저장바이트/RNG/도감/골드는보존한다. 완료/건너뛰기만settings.cfg에저장한다. 완료→스타팅선택은실제출발확정전까지원정을덮지않는다.
- 원정v28/효과19/게시JSON/55물건/137대진·138대표/전국1412항목/배경좌표·경제/성장·경로는그대로다. 새기술버전/추가밸런스변경은없다.

## 실제 검증

- `native_tutorial.gd`최종76/0·21 OS클릭. 권유→호버/실제비용·자동교대/방어/턴종료→별도포획→휴식→다른야영강화→완료/설정재읽기/스타팅선택·재실행·중도종료·건너뛰기,매구간기존저장/도감/RNG불변확인. 최종로그SCRIPT ERROR/ERROR/누수없음.
- 초기드라이버정리/야영상속메서드인자/빠른화면전환의지연울음소리/미부착노드정리를수정했다. 이후전체실습을묶어통과했다. 중간실패를통과로보고하지않는다.
- PNG6개시각확인뒤야영문구잘림만2줄로보완. layout12/0으로11단계텍스트행높이와야영PNG를재확인했다. 전체클릭/919기술/69전투/과거전체창은자동반복하지않았다.
- 자료 `tests/test_export.gd`에배포튜토리얼·야영상속UI/첫카드/원정불변3항목추가. 개인분리증거 `/tmp/pokemon-tutorial-review/`,로그 `/tmp/pokemon-tutorial-native-final.log`와`...-layout.log`;커밋하지않는다.

## 다음 한 단계

- 튜토리얼포함v0.28.1 EXE를격리제작/동일PCK검사하고새ZIP/SHA를전달한다. 수동Release의기본게임SHA는위소스,버전v0.28.1/자료SHA도갱신한다. 기존v0.28.0을덮어쓰지않는다.
- GitHub API Forbidden/Release게시도구없음은이전과같아직접게시/CI시작은불가다. [수동릴리스지도](docs/github-releases.md). 사용자에게Windows release→기본값Run workflow만안내하고게시완료/Windows실기완료로단정하지않는다.
- 난도v28/기존EXE의근거는 [고정인계](https://github.com/agree-git/pokemon-deckbuilder/blob/9866317e1aaadce73e65805b72c25960d89b2628/HANDOFF.md),상세는 [난도지도](docs/campaign-challenge.md). 새피드백에필요할때만읽는다.
