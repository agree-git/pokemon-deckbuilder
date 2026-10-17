# 칼로스·알로라 팬 트레이너 도트

이 문서는 최초 14대진 추가 시점의 기록이다. 현재는 [추가 34대진 적용](trainer-sprite-expansion.md)으로 123대진/120 PNG·공용 시트론 1대진이다. 아래 실행 예시는 최신 main을 대상으로 한다.

게임 반영 commit: `fbe4834af190f7a7ce697572a8011bc0f268c6ff`. **팬 도트 14장**을 추가했다. 현재 개별 도트는 **89대진 / PNG 87장**, 공용 도트는 **35대진**이다. 기존 원작 75대진의 에셋 73장과 게임 데이터/규칙/배경 좌표는 유지한다.

[실제 1920×1080 화면 17장·전체 CSV·ZIP](../review/trainer-fan-sprites/README.md). 전투·대사·준비·투척·출전은 기존 연출을 사용한다. 원본 PNG는 수정하지 않고 실제 알파 발끝과 정수 최근접 배율로 그린다.

## 원본과 작가

- PNG: Smogon/sprites 고정 커밋 `a9214714f00974a8c28586829e6315d9ca5a6348`, `src/_uncategorized/noncanonical/trainers/gen6/x-y/` 및 `gen7/sun-moon/`.
- 작가와 구체적 사용 안내: pokemon-showdown-client 고정 커밋 `74056bbbb55d6ce15f9dd254186b94a51fe94b14`, `play.pokemonshowdown.com/sprites/trainers/index.php`. 원문 사본은 `assets/sources/trainer_gallery_credits.php.txt`다. PHP로 실행하지 않는 조사용 텍스트다.
- 안내 원문: “Many of these sprites are not from the games. Credit must be given to the appropriate artist if used elsewhere. DO NOT EDIT without permission.” 제작자를 표기하고 허락 없이 이미지를 편집하지 않는다. 저장소 일반 License 절도 제거하지 않는다. 코드의 MIT를 그림 전체에 적용하지 않는다.
- 접근 가능한 GitHub 원본을 사용했다. 갤러리의 파일명/인물과 제작자를 대응했으며 접속이 차단된 Showdown 이미지 호스트와 PNG 바이트가 같은지까지 검증하지는 못했다. 원본 캐릭터 권리와 팬 작가의 표기를 구분한다.

| 대진 | 이름 | 제작자 |
|---|---|---|
| elite:acerola | 아세로라 | Beliot419 |
| elite:drasna | 드라세나 | Gnomowladny |
| elite:hala | 할라 | Gnomowladny |
| elite:kahili | 카일리 | Beliot419 |
| elite:malva | 파키라 | Gnomowladny |
| elite:olivia | 라이치 | Beliot419 |
| elite:siebold | 즈미 | Gnomowladny |
| elite:wikstrom | 간피 | Gnomowladny |
| gym:korrina | 코르니 | Gnomowladny |
| gym:olympia | 고지카 | Gnomowladny |
| gym:ramos | 후쿠지 | Gnomowladny |
| gym:valerie | 마슈 | Gnomowladny |
| gym:viola | 비올라 | Gnomowladny |
| gym:wulfric | 우르프 | Gnomowladny |

게임에 포함한 필수 고지는 main의 `assets/sources/TRAINER_FAN_CREDITS.txt`, 실제 대응/원본 URL/PNG SHA/크기/알파 경계/크레딧 근거 SHA는 main의 `assets/sources/trainer_sprites.json`에 기록한다. 조사 문서·추가 테스트·갤러리는 이 자료 브랜치에만 둔다.

## 검증과 실행 대상

Godot 4.7.2/Linux: 콘텐츠·실제 글꼴·89도트 알파 경계/모든 자세·모델/난수 불변 3,645개, 실제 렌더링 158개/새 인물 14명 통과. 세 연출 속도에서 실제 도트/대사/공 궤적/출전 복원과 입력 잠금을 검사했다. 최종 로그에 스크립트 오류/잔여 리소스 경고가 없었다. 전체 PNG 87장의 SHA·크기와 14작가 대응/원문 지문을 오프라인 검사했다. 기존 73개 PNG 명세·데이터 12개·사용자 전장 JSON SHA는 유지한다.

이번은 에셋 추가다. 저장 버전·원정·적 난도·레벨·카드·보상 규칙을 바꾸지 않았고 추가 밸런스 측정/Windows 검증은 하지 않았다.

**이 브랜치의 게임 사본은 정리 전 기준이다.** 새 테스트는 최신 main 체크아웃을 대상으로 실행해야 한다. 예를 들어 main에서:

```bash
git show development-materials:tools/fetch_trainer_sprites.py > /tmp/check_trainer_sprites.py
git show development-materials:assets/sources/trainer_gallery_credits.php.txt > /tmp/trainer_gallery_credits.txt
python3 /tmp/check_trainer_sprites.py --game-root . --credits-index /tmp/trainer_gallery_credits.txt --expected-included 123
git show development-materials:tests/test_trainer_dialogue.gd > /tmp/test_trainer_dialogue.gd
godot --headless --path . --script /tmp/test_trainer_dialogue.gd
# 실제 화면이 있는 환경에서만 실행:
git show development-materials:tests/native_fan_trainers_probe.gd > /tmp/native_fan_trainers_probe.gd
godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script /tmp/native_fan_trainers_probe.gd
```

## 남은 대진

시트론·자크로·카르네 3대진, 가라르 17대진, 팔데아 15대진이 공용 도트다. 시트론은 GitHub 파일 경로를 확인했지만 작가를 확인하지 못했다. 다른 인물 외형을 대신 연결하지 않는다. 특정 팬게임의 실제 에셋 출처는 아직 확정하지 않았다.
