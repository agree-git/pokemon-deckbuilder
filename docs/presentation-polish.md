# 아이템 크기·일반 트레이너·포획 연출

사용자2026-10-20 추가 요청. 빌드/export/CI/새Release는 요청하지 않았고 실행하지 않는다. 빌드는 앞으로 GitHub Actions·Releases에서만 한다. 원정v28/효과19/저장 스키마·RNG·밸런스/승인 보스 파티·이미지는 유지한다.

## 최소 파일 지도

- 큰 아이템: main `scripts/ui/tactical_journey_ui.gd::_item_sprite`. 원본 PNG를 넣고 표시 크기를 지정한 뒤 expand_mode를 바꿔 160px 원본의 최소 크기에 고정되던 순서가 원인이다. EXPAND_IGNORE_SIZE를 먼저 지정해 요청한 rect 안에 맞춘다. 이미지 원본은 바꾸지 않았다.
- 일반 트레이너: main `assets/trainers/regular/*.png`12장과 `.import`, 출처 `assets/sources/regular_trainers.json`. HGSS 원작의 반바지꼬마/짧은치마/곤충채집소년/엘리트남녀/아가씨/태권왕/신사/연구원/폭주족/새조련사/학원끝난아이. [Smogon 고정 원본](https://github.com/smogon/sprites/tree/a9214714f00974a8c28586829e6315d9ca5a6348/src/_uncategorized/canonical/trainers/gen4/heartgold-soulsilver). 원본 PNG 바이트 유지/파일별URL·SHA256·불투명bounds 기록. 기존 원작 권리·컬렉션 고지는 유지한다.
- `scripts/content/trainer_sprites.gd`는 trainer/veteran에만 별도 풀을 사용한다. `tactical_journey_ui.gd`가 run_id+step의 표시용 해시를 넘겨 원정·전투마다 무작위 배치하되 같은 전투의 refresh/저장복원은 동일한 이미지를 유지한다. 게임 RNG를 호출하지 않는다. 기존 gym/elite/champion 매핑/좌표는 그대로다.
- 포획: main `scripts/ui/capture_motion.gd`. 4.0초 기본/기존 전투 배속 적용. 투척 포물선·회전→명중·볼 열림→붉은 빛/수축·수납→닫힘→낙하·착지 반동→바닥에서3회 흔들림→잠금/성공 반짝임. 원본 ball.png를 불투명 영역에 맞춰 그리며 포켓몬의 기존 foot_anchor/스프라이트 bounds를 사용한다.
- `combat_motion.gd`가 해당 표시 노드를 소유하고 reset/finish 때 위치·색·크기·tween을 정리한다. `tactical_ui.gd::_present`는 이미 성공으로 확정된 capture 이벤트 앞에 모션을 재생한 뒤 기존 이벤트/다음 적 출전을 적용한다. 성공 안내도 끝난 뒤 표시한다. busy 중 C 중복은 차단한다. 포획 조건/확률/볼·에너지 비용/HP·획득·도감·저장 타이밍·이벤트/원정 난수는 바꾸지 않았다. 현재 규칙에서 가능한 포획은 기존대로 성공하며 새 실패 확률을 추가하지 않는다.

## 실제 검증

`tests/native_presentation_polish.gd`, 공식Godot4.7.2/1920×1080/격리XDG/Dummy audio. **176검사/0실패**, 실제 C키2회. 모든112아이템의54px rect,12트레이너 실제 이미지/불투명bounds/260px영역/안정 선택/보스 매핑 보존, 실제 public capture의 참조 원정·RNG·비용·저장 일치, 투척/수납/낙하/정확한3흔들림/성공/스킵완료/숨김/리셋을 확인했다. 최초 검사는 테스트 restored 변수의 동적 타입 추론 때문에 로드 전 실패했으며 타입을 명시했다.

스크린샷 검토에서 기존 성공 notice가 투척 시점에 먼저 표시되는 것을 발견해 _capture_notice로 끝까지 미뤘다. 이 범위만 `POLISH_CAPTURE_ONLY=1` **27검사/0실패**, 실제 C2회로 확인했고112아이템/12초상 검사는 반복하지 않았다. 최종은 종료 누수 경고도 없다. 앞선176 검사의2CanvasItem 누수는 tree에 추가하지 않은 검사 factory의 page2개를 해제하지 않은 문제였고 검사 fixture만 수정했다.

12PNG는 다운로드 후 SHA256/이미지 디코드/원작권리·출처를 확인했다. 새12장만 작은 격리 프로젝트에서 리소스 import했다. 최초 제한된 로컬 소켓 진단은 허용된 네트워크 환경에서 import를 확인해 해결했다. 게임 전체 editor import/빌드/export가 아니다.

현재 근거 `/tmp/pokemon-presentation-polish/native.log`, `capture-final.log`, `01-trainers-and-items.png`, `02-capture-flight.png`, `03-capture-absorb.png`, `04-capture-shake.png`, `05-capture-success.png`. 5화면을 직접 확인했다. 전체919기술/69전투/모든UI/모든포획대진·폼/Windows OS 실행·EXE 검사는 반복하지 않았다. 첫 전투의 HP를 포획 가능 범위로 맞춘 검사 fixture이며 실제 원정 클리어를 주장하지 않는다.

## 다시 필요할 때만

공식4.7.2를 PATH에 놓고 격리XDG/1920×1080 DISPLAY에서 native_pointer.py와 위 스크립트1묶음만 실행한다. 포획 수정만이면 POLISH_CAPTURE_ONLY=1로 한정한다. 이미지의 원본 파일을 축소 편집하거나, 연출을 위해 battle/events/저장JSON을 바꾸지 않는다.
