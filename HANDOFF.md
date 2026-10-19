# 현재 작업 인계

## 현재 상태

- main `5b553653c6986239ab438a27ac8d299a4f65f75b`: 새 원정v28 도전 난도와 사용자 요청 Windows EXE 제작 완료. 플레이어 효과19 유지. [난도/배포 지도](docs/campaign-challenge.md)만 먼저 읽는다.
- 트레이너/보스 각 상대 개시 보호막·지역/역할별 직접 공격 압박·야영40→35→30% 회복과 실제 예고/피해/제목/전술/야영 안내를 연결했다. 고정 피해는 배율 제외다.
- 기존v27이하 난도/50%휴식/저장/미래 상대·동일 입력/RNG,승인137대진/138대표·경험치·레벨·보상가격/기술/에셋은 유지한다. 새JSON은v28 게시 입력으로 동결한다.
- main·자료 push 승인 범위로 반영했다. EXE 제작은 최신 사용자 요청으로 재개됐지만 매 main push의 자동 빌드는 아니다. 수동workflow 유지.

## 실제 검증

- 공개 행동 시드2026: v27 69승/215턴/기절0→v28 69승/257턴/기절6·야영품14/2구매. 다른0/42는7승 뒤 첫관장 패배,강화 우선 야영준비0/42도 동일 관장 패배. 인간 평균 승률/수동 난도는 미측정이다.
- 최초자동4,723/0(실v27저장4개 정확 복원/미래 상대/동일 다음 입력/RNG/지문13포함). 무효한 전투가방 준비2026 중복은 추가 준비 근거에서 제외했다. 수정한 준비615/0.
- `test_challenge_contracts.gd`245/0:69전파티/경로/레벨/패턴 보존,일반/전용 공격 예고=실제,보호막,새실제저장/다음입력,난도필드변조/옛저장필드주입거부,구/신휴식.
- `native_challenge_review.gd`실제X11 9/0·1 OS클릭·제목/실제챔피언/야영3PNG 시각 확인. 야영HP는fixture. 초기검사타입/이미쓴야영fixture를 고친 뒤 통과. 전체919/기존전체창은 반복하지 않았다.

## Windows 배포 완료

- 공식4.7.2 TPZ SHA512/사용3템플릿 일치,격리import/export,Windows x86_64 PE/6크기아이콘/외부PCK,안내/출처/Showdown·엔진 라이선스 포함. source clean,빌드자료 `808678e9a19d0fca9d4d86d58aa7daf43bb3ce76`.
- ZIP `/workspace/pokemon-deckbuilder/builds/windows-v28-5b55365/PokemonExpedition-Windows-x86_64-5b55365.zip`,294,249,161바이트. SHA256 `30e160e079bc3fa392ef578faa97ba2a99593b40185ad450b69fe22b19f966d8`. 최종ZIP CRC/경로/해시통과.
- [실제 보고서](docs/reports/windows-v28-linux-pack.json):24배포파일/9,690동일PCK게임항목/시작화면/5,125실행검사/0실패/분리프로필삭제.1412스프라이트·울음소리/제공BGM/새v28난도/저장·설정 포함. Windows EXE 자체 실행은 아니다.
- 최초강제title종료의Ogg4객체/2리소스정리경고 때문에 구WAV만 인식하던 검사기를 현재곡의 정확한 타입/경로 조합에도 대응시켰다. 최종재확인은 경고없이종료했다. 제작후검사기만갱신했으며 실제해시는 보고서에 있다. 게임재빌드는 불필요하다.
- GitHub API Forbidden으로 Windows CI 미실행. 실제 Windows/GPU·오디오/인간평균난도는 미확인. 로컬결과/개인저장분리증거는 `/tmp/pokemon-challenge-review/`,캐시는 `/workspace/pokemon-build-cache`;커밋하지 않는다.

## 다음 한 단계

로컬 난도/EXE 작업은 완료다. 최신 사용자는 GitHub Releases 정리를 요청했다. API Forbidden으로 직접 게시할 수 없어 [수동 배포 지도](docs/github-releases.md)의workflow와버전별변경사항을준비한다. 실제게시/Windows CI는 아직미실행이다. ZIP 전체를 풀어 EXE와PCK를 함께 두면 Godot설치 없이 실행한다. 난도변경은 새원정부터 적용된다. Windows 실제플레이의 실행/난도 피드백을 받고 해당 문제만 수정한다. 전체검사/원정/EXE를 자동 반복하지 않는다.

이전v27마무리는 [고정 인계](https://github.com/agree-git/pokemon-deckbuilder/blob/6d03099c975253789ec987eb72b225aefb79ea3b/HANDOFF.md).
