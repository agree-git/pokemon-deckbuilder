# 현재 작업 인계

## 현재 상태

- 사용자 2026-10-19 새 릴리스 빌드를 명시적으로 요청했다. 이번 v0.28.2 빌드·수동Windows CI·배포 준비는 승인됐다. 이후 새 버전은 다시 요청받는다.
- 게임 소스 `84d06746db6387d8de1e4b4ee81b3f29f5e46e30`: 버전0.28.2/Windows 리소스 버전/누적 CHANGELOG/최신 Esc 안내. [릴리스 변경사항](docs/releases/v0.28.2.md).
- 앞선 [상태 효과](docs/status-vfx.md),[기술 모션](docs/combat-motion.md),[연구 UI](docs/workshop-layout.md),[음악 플레이어](docs/music-player.md),전종 애니메이션/야영겹침/진화단계 수정 포함. 상태 원인 문구는 추가하지 않는다.
- GitHub 공개 릴리스는 현재v0.28.0만 확인했다. v0.28.2 태그는 존재하지 않는다. Git HTTPS는 가능하지만 gh API는Forbidden, 현재 커넥터는Release 조회만 가능하고 게시/수동실행 도구는 없다. 수동 workflow 트리거는 유지한다.

## 진행 중인 검증

- 공식4.7.2 캐시 `/workspace/pokemon-build-cache`를 사용해 격리 import/Windows EXE/PCK/검사용별도export를 만든다. 출력 예정 `builds/windows-v0.28.2-84d0674`.
- `test_export.gd`에 새 버전/2,824애니메이션뷰·import존재/대표아틀라스8뷰디코딩/실제전투애니메이션·음악플레이어·상태VFX스크립트포함 검사를 추가했다. 아직 제작·패키지 검사는 완료하지 않았다.
- 앞선 기능별 실제창 검사는 [고정 이전 인계](https://github.com/agree-git/pokemon-deckbuilder/blob/94ea16325c99358b31d89d375f39ad905f0e5dac/HANDOFF.md)와 작업별 지도에 있다. 이번에 전체기능·기술·69전투·기존 전체창을 반복하지 않는다.

## 다음 한 단계

공식 Windows 제작 뒤 linux-pack의동일PCK/시작/저장·리소스검사를실행한다. 결과/보고서를자료에보관하고 main 수동Release기본값을v0.28.2/정확한게임·자료SHA로갱신한다. Windows 실제실행과GitHub게시가완료됐다고보고하지않는다.
