# GitHub Releases 수동 배포

사용자는 2026-10-19 새 릴리스 빌드를 요청했다. **이번 v0.28.2 빌드와 수동 Windows CI/배포 준비는 승인됐다.** 이후 새 버전은 다시 요청받는다. 전체 UI/기술/원정 검사를 반복하지 않고 공식 제작/패키지 검사만 수행했다.

## 준비된 버전

- 태그 `v0.28.2`, 게임 `84d06746db6387d8de1e4b4ee81b3f29f5e46e30`. main의추가커밋은수동릴리스기본값만갱신하고게임내용은바꾸지않는다.
- [릴리스 변경사항](releases/v0.28.2.md):튜토리얼/전종2D애니메이션/야영겹침·UI간격·연구긴버튼/음악플레이어/전투동작/상태효과/상대진화단계의누적변경.
- main `.github/workflows/windows-release.yml`의기본값은v0.28.2/위게임SHA/해당자료커밋의40자리SHA다. 자료 SHA는이워크플로파일의`materials_revision.default`를확인한다. 외부파일을추측해서사용하지않는다.

## 실제 로컬 빌드

- 공식4.7.2에디터·템플릿의SHA512검증→격리import→Windows x86_64 EXE/PCK→별도검사용export를완료했다. Windows게임아이콘6크기와PE/PCK,PE버전0.28.2도확인했다.
- 로컬ZIP `PokemonExpedition-Windows-x86_64-84d0674.zip` (326,788,599바이트), SHA256 `552a54d0e21ee9b34beecc527a0cf92d879b3ad54d968495e58e92abf3f8f225`. 출력 `builds/windows-v0.28.2-84d0674`. [검사보고서](reports/windows-v0.28.2-linux-pack.json),[로컬산출물정보](reports/windows-v0.28.2-artifact.json).
- **linux-pack:29배포파일·15,184동일게임항목·실제시작화면·5,140실행검사/0실패**. 새애니메이션2,824뷰의import존재/대표8뷰디코딩,새플레이어·상태효과·전투애니메이션,기존카탈로그/울음소리/음원/승인파티/저장/설정을확인했다. 격리프로필제거/깨끗한종료확인. ZIP전체CRC와필수파일/최종SHA도통과했다.
- 로컬빌드도구/검사는자료 `2e33c07ba5fbc1570fec50bb689e5a6f612e60bc`의실제5파일SHA와일치한다. raw SHA push 후로컬원격추적참조가갱신되지않아최초build-info의자료SHA가기존참조를가리켰다. 실제5파일의Git blobSHA256을대조한뒤build-info만정정하고ZIP/체크섬을다시생성했다. 검증한EXE/PCK는불변이다. **다음로컬빌드는자료push뒤반드시fetch하고도구스냅샷/참조SHA를일치시킨다.**
- 이환경에서실행한것은공식Linux release template에연결한동일PCK다. **Windows EXE의실제OS실행/실물GPU·오디오/새장시간플레이검사를수행한것으로보고하지않는다.**

## GitHub 게시의 남은 한 단계

[Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml)에서main을선택하고 **Run workflow→Run workflow**를누른다. 입력값은그대로사용한다. 워크플로는Windows공식제작→실제Windows EXE headless검사→검사통과한초안과3첨부→첨부이름/크기확인→공개한다. 기존태그를덮어쓰지않는다. 자동push/태그트리거는추가하지않았다.

이세션의 `gh api`는Forbidden이며사용가능한커넥터에는릴리스게시/수동실행도구가없다. GET조회는가능하고마지막으로공개된v0.28.0을확인했다. **v0.28.2 workflow실행/태그/게시를완료했다고보고하지않는다.** 토큰을추출하거나접근제한을우회하지않는다.

GitHub가만드는ZIP은같은게임이어도호스트/타임스탬프/도구커밋으로로컬ZIP과해시가다를수있다. 게시된ZIP은게시된`SHA256SUMS.txt`를사용한다. 로컬파일을그대로재게시했다고하지않는다. 실행용ZIP은Source code자동ZIP과구분한다.
