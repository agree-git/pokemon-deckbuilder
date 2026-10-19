# 현재 작업 인계

## 현재 상태

- 사용자 요청으로 v0.28.2 제작·Windows CI·게시 승인. 이후 버전은 재요청받는다. [릴리스 지도](docs/github-releases.md)부터 읽는다.
- 게임 소스 `84d06746db6387d8de1e4b4ee81b3f29f5e46e30`, 자료 `4989eb4412d55d33d86f497ff41b137e973677d2`. main의 후속 변경은 수동 릴리스 설정만이다. [릴리스 노트](docs/releases/v0.28.2.md).
- 튜토리얼/전종 애니메이션/야영·연구UI/음악플레이어/전투동작/상태VFX/상대 진화 단계 포함. 상태 원인 문구 추가 금지. 원정v28/효과19/저장·승인파티·RNG·배경좌표·게시JSON 보존.

## 실제 검증

- 로컬 공식4.7.2 제작 및 linux-pack29파일/15,184동일항목/시작화면/5,140검사/0실패. [로컬 보고서](docs/reports/windows-v0.28.2-linux-pack.json),[산출물·provenance 정정](docs/reports/windows-v0.28.2-artifact.json). 자료 raw SHA push 후에는 fetch로 tracking ref를 갱신한다.
- 사용자 실행 [39253172946](https://github.com/agree-git/pokemon-deckbuilder/actions/runs/39253172946): **Windows 빌드·실제 Windows EXE 검사 5,140개/0실패**. 29배포파일/15,184동일PCK항목/시작화면/프로필정리 통과. 실물 GPU/오디오/장시간 플레이는 미검사. [CI 관측 기록](docs/reports/windows-v0.28.2-ci.json).
- 빌드 아티팩트 `12187096428`에 게임ZIP/체크섬/Windows보고서 보관(14일). Windows ZIP SHA256 `5c01c4b701a5280a18768c27d596155c48e5d524e4bc77a3dc8e796e4250fb4c`. 로컬 ZIP SHA와 구분한다.

## 게시 실패와 수정

- release 생성만403 `Resource not accessible by integration`. 이미 Contents:write였음. 과거 workflow 변경 커밋에 ref가 없어 추가 workflow 권한이 필요한 GitHub 제약과 일치한다. 공식 근거는 릴리스 지도에 있다.
- 정확한 게임 SHA에 lightweight 태그v0.28.2를 정상 Git 경로로 준비한다. main workflow는 기존 태그 SHA 일치/기존 release 없음 확인 → `gh release create --verify-tag` 사용. 태그 이동/덮어쓰기/자동 실행 없음. 기존 게임 소스와 자료 입력은 유지한다.
- 이번 수정은 YAML/게시 계약 정적 확인만 수행. 게임 재빌드/동일 기능 검사를 로컬에서 반복하지 않는다. 수정한 배포 경로의 Windows CI 실제 실행·게시 성공은 아직 미확인이다.

## 다음 한 단계

사용자가 [Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml)에서 main/기본값으로 **새 Run workflow**를 실행한다. 예전 실행의 Re-run은 예전 태그 거부 로직이므로 쓰지 않는다. 환경의 gh API는 Forbidden/커넥터에 dispatch·게시 도구 없음. 실행 회신 뒤 GET으로 결과와 릴리스3첨부를 확인한다. 실패 시 재빌드보다 오류 직전 로그만 먼저 읽는다.
