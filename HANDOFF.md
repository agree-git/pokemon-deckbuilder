# 현재 작업 인계

## 현재 상태

- main `ca884c3`: 튜토리얼/배포기본값까지반영. 튜토리얼 게임소스 `a000509fbfef57b8ceeb6ff1456909d39f4e5810`: 최초새원정의선택형권유/상시실습버튼과실제전투·포획·야영휴식/강화11단계추가. [튜토리얼지도](docs/tutorial.md)만먼저읽는다. main push/EXE재개는기존승인범위다.
- 별도practice상태만사용하며기존원정/실제저장바이트/RNG/도감/골드는보존한다. 완료/건너뛰기만settings.cfg에저장한다. 완료→스타팅선택은실제출발확정전까지원정을덮지않는다.
- 원정v28/효과19/게시JSON/55물건/137대진·138대표/전국1412항목/배경좌표·경제/성장·경로는그대로다. 새기술버전/추가밸런스변경은없다.

## 실제 검증

- `native_tutorial.gd`최종76/0·21 OS클릭. 권유→호버/실제비용·자동교대/방어/턴종료→별도포획→휴식→다른야영강화→완료/설정재읽기/스타팅선택·재실행·중도종료·건너뛰기,매구간기존저장/도감/RNG불변확인. 최종로그SCRIPT ERROR/ERROR/누수없음.
- 초기드라이버정리/야영상속메서드인자/빠른화면전환의지연울음소리/미부착노드정리를수정했다. 이후전체실습을묶어통과했다. 중간실패를통과로보고하지않는다.
- PNG6개시각확인뒤야영문구잘림만2줄로보완. layout12/0으로11단계텍스트행높이와야영PNG를재확인했다. 전체클릭/919기술/69전투/과거전체창은자동반복하지않았다.
- 자료 `tests/test_export.gd`에배포튜토리얼·야영상속UI/첫카드/원정불변3항목추가. 개인분리증거 `/tmp/pokemon-tutorial-review/`,로그 `/tmp/pokemon-tutorial-native-final.log`와`...-layout.log`;커밋하지않는다.

## 배포 완료/한계

- v0.28.1 EXE/PCK를위게임clean소스/자료 `13b7cf70cfd259f0908eea0c81d8a4d5208640d1`/공식Godot4.7.2로제작했다. Windows PE/6크기아이콘/외부PCK/필수출처·라이선스/플레이안내포함.
- [동일PCK보고서](docs/reports/windows-v0.28.1-linux-pack.json):24배포파일/9,700동일게임항목/시작화면/5,128검사0실패·프로필분리/삭제. 새실습·야영상속화면과원정불변도확인했다. 실제Windows/GPU·오디오확인은아니다.
- ZIP `/workspace/pokemon-deckbuilder/builds/windows-tutorial-a000509/PokemonExpedition-Windows-x86_64-a000509.zip`,294265853바이트, SHA256 `58cf0e0e8aa1b43cd758a8ad22b453571277bf0e226d5dec8c1a698102817f60`. 최종ZIP CRC/경로/해시통과. 원본/로그/긴캐시/ZIP은커밋하지않는다.
- 수동Windows release기본값은v0.28.1/위게임SHA/위자료SHA다. 기존v0.28.0을덮어쓰지않는다. [수동릴리스지도](docs/github-releases.md). API Forbidden/게시도구없음으로CI시작/실제게시실행은이세션에서못한다. 사용자기본값Run workflow한번이남았다.

## 다음 한 단계

요청튜토리얼·main반영·로컬EXE제작은완료했다. ZIP전체압축해제후실행하고시작화면의‘튜토리얼·조작연습’을사용한다. 실제플레이피드백을우선한다. Windows release게시완료/실기확인으로단정하거나전체검사/원정/EXE를자동반복하지않는다.

난도v28/이전EXE근거는 [고정인계](https://github.com/agree-git/pokemon-deckbuilder/blob/9866317e1aaadce73e65805b72c25960d89b2628/HANDOFF.md). 필요할때만읽는다.
