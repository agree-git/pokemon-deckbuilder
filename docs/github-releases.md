# GitHub Releases 수동 배포

## 최신 요청과 소스

사용자는 엔딩 크레딧과 새 릴리스를 요청했다. 제작자는 **DO**, 최신 지시는 **처음의 명예의 전당·스크롤 화면 양식을 유지하고, YOUNG의 첨부 크레딧처럼 역할별 기여자 내용만 보완**하는 것이다. 문서형 상세 창은 제거했다. [크레딧 지도](ending-credits.md),[v0.28.4 노트](releases/v0.28.4.md).

- 버전 `v0.28.4`, 게임 `83b32740e9988c3fbda39b20cc29b01f4fd1d614`.
- 빌드 도구/검사 자료 `8e3a7a38b2df13a7a0c66591599a14aae1edf83c`.
- 원정v28/효과19/기존 저장·승인 콘텐츠는 유지한다. 시험 태그v0.28.3은 미게시로 보존한다. 사용자 보완 지시가 들어온 중간 빌드는 중단했고 최종 산출물로 사용하지 않는다.
- 실제 창 검사80/0·7클릭·4키. 배치 수정만7/0은 별도 근거다. 자료 원문3개와24절/DO/외부 Credit.txt 일치를 확인했다. 전체919기술/69전투는 반복하지 않았다.

## 제작과 게시 순서

공식4.7.2 에디터·템플릿 SHA512 확인 → 격리 Windows EXE/PCK/별도검사용 export → PE/아이콘/동일PCK/패키지 검사 → 정확한 게임 SHA에 새 lightweight 태그 준비 → main 수동 workflow의 태그/게임/자료 기본값 갱신 순서다. 기존 태그를 이동하거나 기존 릴리스를 덮어쓰지 않는다.

빌드는 `builds/windows-v0.28.4-83b3274`에 만든다. Linux-host 패키지 실행 검사는 실제 Windows OS 실행과 구분한다. **완료:31배포파일/15,188동일게임항목/실제시작화면/5,143실행검사/0실패**,격리프로필정리. [패키지 보고서](reports/windows-v0.28.4-linux-pack.json),[산출물·Git blob지문·ZIP CRC/크레딧 일치](reports/windows-v0.28.4-artifact.json). ZIP326,828,107바이트, SHA256 `9308beb17217312db14ab4b28e4d4a2783fdf199b149d224b3cd532e0c43d3d6`다. GitHub ZIP은 타임스탬프/OS/도구 커밋이 달라 로컬 해시와 다를 수 있으며 첨부된 SHA256SUMS.txt를 사용한다.

## GitHub 실행

[Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml)에서 **main → Run workflow → 최신 기본값 그대로 Run workflow**를 실행한다. 수정 전 실행의 Re-run jobs는 이전 YAML/입력을 사용하므로 새 버전 실행으로 쓰지 않는다. 워크플로는 실제 Windows 제작/Windows EXE 검사 후 초안과 ZIP·체크섬·Windows 보고서3첨부를 만들고 이름·크기를 확인해 게시한다. 수동 workflow만 사용하며 자동 push/태그 트리거를 추가하지 않는다.

현재 환경은 Git 쓰기와 커넥터 GET 조회가 가능하지만 `gh api`는 Forbidden이고 새 workflow dispatch/Release 게시 도구가 없다. 사용자가 새 실행을 시작한 뒤 GET으로 실행 결과와 공개된3첨부를 확인한다. 실행하지 못한 Windows CI/게시를 완료라고 보고하지 않는다. 토큰을 추출하거나 권한 제한을 우회하지 않는다.

## 과거403의 해결 근거

v0.28.2 [실패 실행](https://github.com/agree-git/pokemon-deckbuilder/actions/runs/39253172946)은 Windows 검사5,140/0 뒤 release 생성만403이었다. Contents:write는 이미 부여돼 있었으며 workflow를 수정한 과거 SHA에 ref가 없는 경우의 [GitHub workflow 권한 제약](https://github.blog/changelog/2023-11-02-github-actions-enforcing-workflow-scope-when-creating-a-release/)과 일치했다.

정상 Git 경로로 소스 태그를 미리 준비하고 workflow는 SHA 일치/기존 release 없음 확인 후 `gh release create --verify-tag`만 수행하도록 수정했다. 사용자 재실행 [39255797385](https://github.com/agree-git/pokemon-deckbuilder/actions/runs/39255797385)은 성공했다. 새 버전에서도 태그를 먼저 준비하고 추가 workflow 권한/개인 토큰을 요구하지 않는다.

자료 raw SHA push는 origin/development-materials를 갱신하지 않을 수 있다. 로컬 제작 전 반드시 fetch하고 실제5도구 파일의 Git blob SHA와 build-info materials_revision을 일치시킨다. [이전v0.28.2 상세 제작 근거](https://github.com/agree-git/pokemon-deckbuilder/blob/21c9f74b89e56f62de0ee3686c82739b91584192/docs/github-releases.md).
