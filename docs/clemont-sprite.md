# 시트론 도트 적용 — 보스 외형 완료

게임 commit: `f4b53a573d94c7ef37a6937bec304853c7808446`. 사용자가 시트론 참조 그림과 [Gnomowladny의 원작 링크](https://www.deviantart.com/gnomowladny/art/Clemont-Sprite-430844892)를 제공해 마지막 미적용 대진을 연결했다. **124대진 모두 개별 외형 / PNG 121장 / 공용 외형 대진 0개**다. [화면 9장·ZIP·전체 CSV](../review/clemont/README.md).

## 출처와 그림 차이

- 제작자는 **Gnomowladny**이며 근거는 사용자가 제공한 원작 링크다. 원작 페이지는 현재 클라우드에서 403으로 열리지 않아 페이지의 사용 조건을 독립적으로 읽었다고 주장하지 않는다. 기존 컬렉션 고지와 제작자 표기를 유지하며 별도 이미지 허가를 새로 주장하지 않는다.
- 적용 파일은 [Smogon 고정 보관본](https://raw.githubusercontent.com/smogon/sprites/a9214714f00974a8c28586829e6315d9ca5a6348/src/_uncategorized/noncanonical/trainers/gen6/x-y/Clemont.png)이다. 사용자가 올린 참조와 같은 포즈지만 **푸른 전기 효과가 포함된 버전**이다. 이 차이를 적용 전 진행 설명과 갤러리에 명시했다. 업로드/DeviantArt 다운로드와 바이트가 동일하다고 기록하지 않는다.
- PNG는 수정 없이 그대로 사용했다. 80×80, 투명 경계 `[0,0,75,80]`, SHA-256 `d1a4aa1e9787fd28bea9533bae486e97d27a99ca688f19b932ed0ce0d1f17f29`다. 정수 3배·최근접 배율과 기존 전장 발 위치를 사용한다. 이미지 생성 결과를 사용한 것이 아니다.
- `credit_basis: user_provided_artist_link`와 정확한 원작 URL을 런타임 명세에 기록한다. 기존 갤러리 크레딧 인덱스에는 시트론 작가가 없으므로 원문 목록에 임의 항목을 넣거나 인덱스에 있었다고 주장하지 않는다. 검증 도구도 이 정확한 파일/작가/URL/SHA 조합만 별도로 검사한다.

## 실제 검증

Godot **4.7.2/Linux** import, 콘텐츠 **3,855개**, 전체 **121 PNG / 124대진 / 공용 0** SHA·출처·작가 근거 검증 통과. 기존 120 PNG와 그 메타데이터/대진, 게임 코드·씬·게임 데이터 12개를 유지했다.

실제 1920×1080 전투 창에서 **41개/세 연출 속도**를 통과하고 등장·투척·출전 후 9장을 촬영했다. 발끝·정수 배율·대사/파티와 간격, 입력 잠금, 공 궤적, 자연스러운 완료 후 입력 복원, HP·카드·에너지·난수 불변을 검사했다. 대표 등장/투척 화면을 직접 열어 보았다. OS 포인터 검사·Windows·추가 저장 회귀·밸런스 계측은 실행한 것으로 설명하지 않는다. Lv.30은 외형 비교용 테스트 데이터다.

## 최신 main에서 재현

이 자료 브랜치의 게임 사본은 최신 main이 아니다. main에서 파일을 추출해 실행한다.

```bash
git show development-materials:tools/fetch_trainer_sprites.py > /tmp/check_trainer_sprites.py
git show development-materials:assets/sources/trainer_gallery_credits.php.txt > /tmp/trainer_gallery_credits.txt
python3 /tmp/check_trainer_sprites.py --game-root . --credits-index /tmp/trainer_gallery_credits.txt --expected-included 124
git show development-materials:tests/test_trainer_dialogue.gd > /tmp/test_trainer_dialogue.gd
godot --headless --path . --script /tmp/test_trainer_dialogue.gd
# 실제 화면이 있는 환경에서만 실행:
git show development-materials:tests/native_clemont_probe.gd > /tmp/native_clemont_probe.gd
godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script /tmp/native_clemont_probe.gd
```

시트론 출처 탐색은 완료한 작업이다. 다음은 인물/희귀 이벤트 등 콘텐츠 개성을 보강하며, 사용자 지시에 따라 밸런스 조정·추가 난도 계측은 계속 보류한다.
