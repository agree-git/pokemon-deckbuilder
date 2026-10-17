# 9세대 희귀 검증

최신 `main`을 Godot 4.7.2로 먼저 import한다. 이 자료 브랜치의 이전 게임 복사본을 검증 대상으로 쓰지 않는다.

```bash
godot --headless --path /path/to/main --editor --import --quit
godot --headless --path /path/to/main --script /path/to/materials/tests/rare-gen9/test_gen9.gd
godot --headless --path /path/to/main --script /path/to/materials/tests/rare-gen9/test_rare_stories.gd
godot --headless --path /path/to/main --script /path/to/materials/tests/rare-gen9/test_rare_encounter.gd
godot --headless --path /path/to/main --script /path/to/materials/tests/rare-gen9/test_journey_save.gd
godot --headless --path /path/to/main --script /path/to/materials/tests/rare-gen9/test_compatibility.gd
godot --headless --path /path/to/main --script /path/to/materials/tests/rare-gen9/test_collection_hidden.gd
godot --headless --path /path/to/main --script /path/to/materials/tests/rare-gen9/test_rare_growth.gd
godot --headless --path /path/to/main --script /path/to/materials/tests/rare-gen9/test_audio.gd
godot --headless --path /path/to/main --script /path/to/materials/tests/rare-gen9/test_family_gate.gd
godot --headless --path /path/to/main --script /path/to/materials/tests/rare-gen9/test_family_ui.gd
python3 /path/to/materials/tools/rare-gen9/check_content.py --project-dir /path/to/main
```

기존 사용자 저장과 분리된 `XDG_DATA_HOME`/`XDG_CONFIG_HOME`을 사용한다. 실제 X11/1920×1080에서는 `RARE_REVIEW_DIR=/tmp/rare-review python3 run_pointer.py --project-dir /path/to/main --script native_gen9_probe.gd`로 원래 GUI에 OS 입력을 보낸다. 실제 창 검사는 동시에 여러 개 실행하지 않는다.

`test_gen9`는 전체 103종을 대상으로 데이터·실제 도트/오디오·포획 경계·스타팅·저장을 검증한다. 복잡한 정산/합류 전 과정은 대표 20종으로 검사하고, 모든 종의 이야기/UI는 별도로 확인한다. 시드 fixture는 중간 진행 상태를 구성하며 캠페인을 실제 완주했다는 주장이 아니다. native probe의 25종 정지 화면은 실제 재생 tween을 일시 정지해 촬영한다. 3종은 실제 클릭/자연 재생도 검사한다. 엔진 종료 코드와 `SCRIPT ERROR`/`ERROR:` 로그를 함께 확인한다.
