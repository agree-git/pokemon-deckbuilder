# GitHub Releases 수동 배포

사용자는 2026-10-19 새 릴리스 빌드를 요청했다. **이번 v0.28.2 빌드와 수동 Windows CI/배포 준비는 승인됐다.** 이후 새 버전은 다시 요청받는다. 전체 UI/기술/원정 검사를 반복하지 않고 공식 제작/패키지 검사만 수행했다.

## 준비된 버전

- 태그 `v0.28.2`, 게임 `84d06746db6387d8de1e4b4ee81b3f29f5e46e30`. main의추가커밋은수동릴리스설정만갱신하고게임내용은바꾸지않는다.
- [릴리스 변경사항](releases/v0.28.2.md):튜토리얼/전종2D애니메이션/야영겹침·UI간격·연구긴버튼/음악플레이어/전투동작/상태효과/상대진화단계의누적변경.
- main `.github/workflows/windows-release.yml`의기본값은v0.28.2/위게임SHA/해당자료커밋의40자리SHA다. 자료 SHA는이워크플로파일의`materials_revision.default`를확인한다. 외부파일을추측해서사용하지않는다.

## 실제 로컬 빌드

- 공식4.7.2에디터·템플릿의SHA512검증→격리import→Windows x86_64 EXE/PCK→별도검사용export를완료했다. Windows게임아이콘6크기와PE/PCK,PE버전0.28.2도확인했다.
- 로컬ZIP `PokemonExpedition-Windows-x86_64-84d0674.zip` (326,788,599바이트), SHA256 `552a54d0e21ee9b34beecc527a0cf92d879b3ad54d968495e58e92abf3f8f225`. 출력 `builds/windows-v0.28.2-84d0674`. [검사보고서](reports/windows-v0.28.2-linux-pack.json),[로컬산출물정보](reports/windows-v0.28.2-artifact.json).
- **linux-pack:29배포파일·15,184동일게임항목·실제시작화면·5,140실행검사/0실패**. 새애니메이션2,824뷰의import존재/대표8뷰디코딩,새플레이어·상태효과·전투애니메이션,기존카탈로그/울음소리/음원/승인파티/저장/설정을확인했다. 격리프로필제거/깨끗한종료확인. ZIP전체CRC와필수파일/최종SHA도통과했다.
- 로컬빌드도구/검사는자료 `2e33c07ba5fbc1570fec50bb689e5a6f612e60bc`의실제5파일SHA와일치한다. raw SHA push 후로컬원격추적참조가갱신되지않아최초build-info의자료SHA가기존참조를가리켰다. 실제5파일의Git blobSHA256을대조한뒤build-info만정정하고ZIP/체크섬을다시생성했다. 검증한EXE/PCK는불변이다. **다음로컬빌드는자료push뒤반드시fetch하고도구스냅샷/참조SHA를일치시킨다.**
- 이환경에서실행한것은공식Linux release template에연결한동일PCK다. **Windows EXE의실제OS실행/실물GPU·오디오/새장시간플레이검사를수행한것으로보고하지않는다.**

## Windows CI 통과·게시 오류 수정

사용자가 실행한 [run 39253172946](https://github.com/agree-git/pokemon-deckbuilder/actions/runs/39253172946)에서 Windows 제작과 **실제 Windows EXE 검사 5,140개/0실패**가 통과했다. 배포29파일/동일PCK15,184항목/시작화면/격리프로필정리도 통과했다. 실물 GPU·오디오·장시간 플레이는 별개다.

릴리스 생성만 `HTTP 403: Resource not accessible by integration`으로 실패했다. 로그의 `GITHUB_TOKEN`에는 이미 `Contents: write`가 있다. GitHub는 workflow를 변경한 과거 SHA에 branch/tag ref가 없을 때 release 생성에 추가 workflow 권한을 요구한다. [공식 안내](https://github.blog/changelog/2023-11-02-github-actions-enforcing-workflow-scope-when-creating-a-release/). 게임 SHA는 현재 main의 HEAD가 아니었고 태그도 없었다.

수정: 정상 Git 쓰기 경로로 정확한 게임 SHA에 lightweight 태그 `v0.28.2`를 먼저 준비한다. 수동 workflow는 시작 때 태그 SHA와 입력 게임 SHA의 일치를 확인하고 이미 존재하는 release는 거부한다. `gh release create --verify-tag`로 준비된 태그만 사용하며 태그 생성/이동이나 기존 릴리스 덮어쓰기를 수행하지 않는다. 미래 버전도 승인받은 게임 SHA에 새 태그를 먼저 준비한다. 토큰 추가/권한 확대는 필요 없다.

## 게시의 남은 한 단계

[Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml)에서 **main → Run workflow → 기본값 그대로 Run workflow**를 새로 실행한다. **실패한 예전 실행의 Re-run jobs는 사용하지 않는다.** 예전 YAML은 기존 태그를 거부하므로 수정된 main의 새 실행이 필요하다. 버전은 그대로 v0.28.2다.

수동 workflow는 공식 Windows 제작→실제 Windows EXE 검사→초안/3첨부→첨부 이름·크기 확인→게시 순서다. 자동 push/태그 트리거는 추가하지 않았다. 게시 성공은 실행 결과와 release의 실제3첨부를 GET으로 확인한 후 보고한다.

현재 환경의 `gh api`는 Forbidden이며 커넥터에는 새 workflow dispatch/릴리스 게시 도구가 없다. Git 쓰기와 GET 조회는 가능하다. 사용자에게 토큰을 요청하거나 접근 제한을 우회하지 않는다.

당장 게임이 필요하면 [통과한 기존 실행의 다운로드](https://github.com/agree-git/pokemon-deckbuilder/actions/runs/39253172946/artifacts/12187096428)를 사용할 수 있다(14일 보관). 바깥 artifact ZIP을 풀면 게임 ZIP·체크섬·Windows 검사보고서가 있다. 이 Windows 게임 ZIP의 SHA256은 `5c01c4b701a5280a18768c27d596155c48e5d524e4bc77a3dc8e796e4250fb4c`다. 이는 위의 로컬 Linux-host 빌드 ZIP 해시와 다르다.

GitHub가 만드는 ZIP은 같은 게임이어도 호스트/타임스탬프/도구커밋으로 해시가 달라질 수 있다. 항상 함께 첨부된 `SHA256SUMS.txt`를 사용한다. 실행용 ZIP은 Source code 자동 ZIP과 구분한다.
