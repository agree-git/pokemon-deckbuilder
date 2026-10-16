# 관장 후보 확장 이전 저장 검체

`8e5a676e0280abb5c8565e38b03a385fa036feb6` 체크아웃에서 생성했다. 실제 사용자 저장을 수집한 파일이 아니다.

- `legacy-run.json`과 `.head`: 시드 42, field_kit, 스타팅 1/4/7인 새 원정을 `JourneySave.save()`로 기록한 v3 봉투다. 재현용 run_id는 1로 채운 32자리다. route_version 필드는 없다.
- `legacy-route-signatures.json`: 변경 전 경로 생성기로 시드 0/1/3/42/2026/2027의 서명을 기록했다.

`test_gym_candidates.gd`는 파일을 정상 로더로 읽고 전체 상태/경로/난수를 보존하는지 확인한다. 새 생성기의 결과를 정답으로 재생성해 이 파일을 갱신하지 않는다. 이전 개체값/노력치 저장의 별도 검체도 그대로 유지한다.
