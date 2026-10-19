# 현재 작업 인계

## 현재 상태

- main `5b55365`: 사용자 요청으로 새 원정v28 도전 난도와 EXE 제작을 재개했다. 플레이어 효과19는 유지한다. [난도/배포 지도](docs/campaign-challenge.md)만 먼저 읽는다.
- 트레이너/보스 각 상대 개시 보호막,지역·역할별 직접 공격 압박,야영40→35→30% 회복을 추가했다. 실제 예고/피해를 일치시키고 제목/전술/야영지에서 안내한다. 고정 피해는 배율 제외다.
- 기존v27이하 난도/50%휴식/저장/미래 상대·동일 입력/RNG,승인137대진/138대표·경험치·레벨·보상가격/기술/에셋은 유지한다. 새 JSON은v28의 게시 입력으로 동결한다.
- 사용자용 README/PLAY_GUIDE/CHANGELOG를 갱신하고 빌더에 루트 라이선스/안내를 포함했다. main push와 자료 push는 계속 승인 범위다.

## 실제 검증

- 같은 시드2026 공개 행동: 기존69승/215턴/기절0→v28도69승/257턴/기절6·야영품14개/2구매. 단순 정책 다른0/42는 각7승 뒤 첫 관장 패배. 야영 강화 준비0/42도 같은 관장 패배다. 인간 평균 승률은 미측정이며 실제 수동 난도 피드백이 다음 근거다.
- 최초자동4,723/0(실제v27 저장4개 정확 복원/미래 상대/동일 다음 입력/RNG/실제지문13포함). 중복 준비2026은 유효한 추가 준비 근거에서 제외. 수정한 준비두시드615/0.
- `test_challenge_contracts.gd`245/0:69전 파티/경로/레벨/패턴 보존,일반/전용 공격 예고=실제,개시보호막,새실제저장/다음입력,난도필드변조/옛저장필드주입거부,구/신휴식.
- `native_challenge_review.gd`실제X11 9/0·1 OS클릭,제목/실제챔피언/야영3PNG 시각 확인. 야영HP는fixture. 초기검사타입/사용済야영fixture를 고친 뒤 통과했다. 전체919/기존전체창은 반복하지 않았다.
- 공식4.7.2 TPZ SHA512와 사용3템플릿의 바이트 일치를 확인했다. 개인데이터 분리결과는 `/tmp/pokemon-challenge-review/`,캐시는 `/workspace/pokemon-build-cache`;커밋하지 않는다.

## 미완료/다음 한 단계

- 요청한 Windows EXE를 `tools/build_windows.py`로 격리 제작하고 `verify_export.py --mode linux-pack`로 배포동일PCK/리소스/저장을 확인한 뒤 ZIP/SHA를 전달한다. Godot설치불필요,EXE/PCK동반. source는 위main커밋을 사용한다.
- GitHub API가Forbidden여서 Windows CI는 실행하지 못했다. 로컬Windows구조/아이콘+Linux동일PCK검사는 Windows 실기 실행과 구분하고 한계를 보고한다. 수동workflow는 유지한다.
- 빌드가 끝나면 이 인계의 미완료를 실제결과/다운로드경로/해시로 교체한다. 이전v27마무리는 [고정 인계](https://github.com/agree-git/pokemon-deckbuilder/blob/6d03099c975253789ec987eb72b225aefb79ea3b/HANDOFF.md).
