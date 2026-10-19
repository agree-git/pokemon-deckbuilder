# GitHub Releases 수동 배포

사용자가 EXE를 GitHub Releases에 버전별로 정리하도록 요청했다. 로컬v28 ZIP은 이미 완성했고,현재 연결에는Release/asset게시도구가 없으며`gh api`의 저장소조회도Forbidden으로 거부된다. Git접근과GitHub API접근은 별개다. 접근제한을 우회하거나토큰을요청하지않는다.

main의 `.github/workflows/windows-release.yml`은 **workflow_dispatch만** 사용한다. [Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml)에서 **Run workflow**를 한 번 실행하면 Windows에서 공식4.7.2제작→실제EXE headless 검사→초안릴리스/ZIP·SHA·보고서첨부→첨부파일명/크기확인→공개한다. 검사 실패 시 공개하지 않는다. main push/태그 push는 실행조건이 아니며 기존 preview도 그대로 수동이다.

현재기본값은 **v0.28.1 튜토리얼**이며게임SHA `a000509fbfef57b8ceeb6ff1456909d39f4e5810`와자료SHA `13b7cf70cfd259f0908eea0c81d8a4d5208640d1`다. 입력은40자리SHA/버전태그만허용한다. 릴리스대상태그가이미있으면덮어쓰지않는다. 향후수정본은새태그/게임SHA/자료SHA/해당release note를사용한다. 이전v0.28.0의자료/소스는당시기록을유지한다.

변경사항은 `docs/releases/v0.28.1.md`이며 최종첨부는빌더ZIP·`SHA256SUMS.txt`·`windows-native-report.json`이다. GitHub Source code 자동ZIP과게임실행ZIP을혼동하지않도록안내한다. Release asset은일반artifact의14일보관과달리release가남는동안유지된다.

현재 API차단때문에 이세션에서workflow시작/릴리스게시를확인할수없다. 사용자 실행전까지**Releases게시완료로보고하지않는다**. Windows CI가만드는ZIP은로컬Linux에서만든ZIP과동일소스여도엔진export/압축시점의메타데이터로해시가다를수있으므로게시된각ZIP의체크섬을사용한다. 로컬 ZIP을재게시했다고하지않는다.

구현은 main `39c92af5ddb127ed7468f0161764c81646312e10`,현재v0.28.1기본값은`ca884c3`에반영했다. YAML파싱/수동트리거만허용/기본게임·자료SHA/변경사항경로/검사선행/초안첨부/입력을환경변수로전달/태그404예상오류의exit0을확인했다. Windows실행은미실행이다. 사용자에게위workflow기본값실행링크와완성된로컬ZIP을안내한다. 워크플로실행을회피하기위한자동태그트리거는추가하지않았다.
