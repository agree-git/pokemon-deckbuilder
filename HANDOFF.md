# 현재 작업 인계

## 최신 사용자 지시

- **빌드는 GitHub Actions·Releases에서만**, 로컬 빌드/export/ZIP 제작·전달 금지. 현재 수정은 새 릴리스 요청이 아니다. 이번에 빌드/CI/버전·태그 갱신을 하지 않았다.
- 2026-10-20 첨부 Credit.txt/README-Windows.txt/PLAY_GUIDE.md 적용, ASSET_SOURCES.md·CHANGELOG.md 제거. Credit.txt 바이트는 첨부 그대로, 엔딩 JSON은 같은9절. 기존 명예의 전당·스크롤 양식/DO 유지. 문서 뷰어 추가 금지.
- 실제 저장 위치도 **%APPDATA%\PokemonExpedition**으로 바꾸고 기존 저장 이전을 사용자가 선택했다. [저장 위치 지도](docs/save-location.md)부터 읽는다.
- 추가로 아이템 크기/원작 일반 트레이너 최소10명 재사용/몬스터볼 투척·수납·착지·3흔들림 요청. [연출 지도](docs/presentation-polish.md). 상태 원인 문구 추가 금지. 원정v28/효과19/저장·RNG·승인 보스·배경좌표/게시JSON은 유지.

## 구현 상태

- SaveLocation이 첫 autoload로 기존 원정 main/head/bak·도감 main/bak·설정을 비파괴 이전한다. 대상 기존 묶음은 보존/혼합 방지, staged plan·지문으로 중단 재개/완료 이후 재수입 방지. 실패 시 안내 후 종료. Windows/Linux 위치 차이 반영. 데이터 형식은 그대로다.
- 미래 GitHub 제작에서 main README-Windows.txt를 그대로 복사하며 내장 문구로 덮어쓰지 않는다. 제거한 두 문서의 활성 링크/도구 의존성/PE 고지를 정리했다. 테스트 전용 user dir와 verifier의 제품 경로도 수정.
- _item_sprite의 expand_mode 지정 순서를 고쳐160px 원본도 요청한 크기를 지킨다. 원본 PNG 불변.
- HGSS 원작 일반 트레이너12종을 원본바이트로 추가. URL/SHA/bounds는 regular_trainers.json. run_id+step 표시용해시로 일반 trainer/veteran만 재사용하고 동일전투/로드는 유지. 전용 보스 이미지/파티 불변.
- capture_motion.gd 기본4초/기존배속. 투척·명중·열림·수납·닫힘·낙하·반동·3흔들림·성공. busy중 중복차단/성공안내는 끝난 뒤/색·위치·크기 정리. 기존 포획 판정/비용·저장·난수는 유지.

## 실제 검사

- 저장 이전 **부모24+별도 첫 실행6=30/0**, 정확한 저장·RNG·도감·설정/원본 보존/기존대상·완료marker·중단·손상/실제autoload 순서. 공식4.7.2 격리headless. 로그 /tmp/pokemon-docs-savepath/test.log.
- 연출 **176/0**,112아이템 크기/12초상·bounds/보스보존/실제 C2회·참조포획/저장·RNG/각단계/스킵/리셋. 성공 notice 지연 수정 범위만 **27/0**, C2회·종료누수 없음. 테스트 factory page누수만 고쳤고 전체176은 반복하지 않았다. 5PNG 직접 확인. /tmp/pokemon-presentation-polish/{native,capture-final}.log.
- 첨부동일Credit/9절동기화/삭제문서참조/도구Python구문/PNG12지문·기존보스bounds 정적확인. 새12PNG 리소스만 격리import. 게임전체import/네이티브전체/919기술/69전투/Windows OS/EXE/빌드·CI·게시 미실행.

## 다음 단계

현재 변경을 main/자료에 반영한 뒤 사용자 수정사항을 기다린다. 빌드 요청이 오면 새 버전/새 게임·자료SHA/새 태그로 수동 GitHub Windows 검사·게시를 준비한다. v0.28.4 태그/기존workflow 입력은 동결한다. 새 dispatch/게시 도구가 없으면 사용자 Run workflow로 실행하고 GET으로 결과 확인. 자료 rawSHA push뒤 fetch로 tracking ref 갱신.

이전 배포 근거는 [고정 인계](https://github.com/agree-git/pokemon-deckbuilder/blob/12e0229419f0633afd3b4f8866cc05d5dd09f543/HANDOFF.md)에만 보관한다.
