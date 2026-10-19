# 현재 작업 인계

- 최신 요청: **“릴리스”**, v0.28.5 준비·GitHub 수동 빌드·게시 승인. 로컬 빌드/export/ZIP 제작·전달 금지. 수동 workflow를 자동으로 바꾸지 않는다.
- 고정 게임 소스 `2560d2da269074e4444b4644ab69cad40dd6cf75` / 태그 `v0.28.5`. main의 별도 workflow 설정 커밋에서 이 게임 SHA와 자료 SHA를 기본값으로 지정한다.
- 새 dispatch/게시 도구가 현재 연결에 없다. [Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml)에서 main·기본값 그대로 **새 Run workflow**를 사용자가 시작해야 한다. 과거 job 재실행 금지. 실행/게시 완료로 보고하지 않는다.
- Windows runner가 공식4.7.2 제작→실제 EXE 검사→3첨부 draft 검증→게시를 수행한다. 다음 단계는 새 실행의 GET 상태·실패 로그 확인이다. [릴리스 지도](docs/github-releases.md), [노트](docs/releases/v0.28.5.md).

## 포함한 수정

- 첨부 Credit.txt/README-Windows.txt/PLAY_GUIDE.md 반영. Credit.txt는 버전만0.28.5로 갱신했고 내용9절/DO와 기존 명예의 전당·스크롤 양식을 유지했다. 문서 뷰어 금지.
- ASSET_SOURCES.md·CHANGELOG.md 삭제와 도구/활성 링크 정리. 원래 assets/sources·licenses 고지는 보존. 배포 README는 사용자 파일 그대로 복사.
- 저장 위치 **%APPDATA%\PokemonExpedition** + 첫 autoload SaveLocation의 비파괴 기존 저장 이전. 묶음 충돌 방지/중단 재개/완료 marker. [파일 지도](docs/save-location.md).
- 아이템 expand_mode 순서 수정, 원작 HGSS 일반 트레이너12종(일반·베테랑만 표시용 해시), 몬스터볼 투척·명중·수납·착지·3흔들림과 연출 후 성공 안내. [파일 지도](docs/presentation-polish.md).
- 원정28/효과19/저장 형식·RNG·승인 보스 파티·배경좌표/포획 비용·판정 유지. 상태 원인 문구 추가 금지.

## 검증

- 이전 소스 검사: 저장30/0, 연출176/0, 마지막 포획 수정27/0(깨끗한 종료), 5장 직접 확인. 자료 docs/reports/2026-10-20-save-and-presentation.json.
- 이번 릴리스 준비는 버전·고정 SHA/태그·수동 YAML·패키징 연결 정적 확인만 한다. 이미 통과한 소스 검사를 반복하지 않는다.
- 로컬 전체import/빌드/export/ZIP/Windows EXE 검사, 새 GitHub 실행·게시 미실행. 실제 Windows 결과는 향후 해당 workflow와 첨부 report 기준이다.

이전 작업 기록은 [고정 인계](https://github.com/agree-git/pokemon-deckbuilder/blob/bd3fed3ef3a86967cc563541228f1ee539253c6e/HANDOFF.md)에 보관한다.
