# 가라르·팔데아와 칼로스 트레이너 도트 확장

이 문서는 34대진 추가 시점의 기록이다. 이후 [시트론 적용](clemont-sprite.md)으로 124대진/121 PNG·공용 0대진이 됐다. 아래 실행 예시는 최신 main을 대상으로 한다.

게임 반영 commit: `49c967aaf96ea25889dfabd7bf8135d1bfbf2b17`. **34대진 / 원본 PNG 33장**을 추가했다. 가라르 17·팔데아 15·칼로스 자크로/카르네 2대진이다. 청목은 관장/사천왕이 같은 파일을 공유한다. **전체 123/124대진 / PNG 120장**이며 시트론만 제작자 확인까지 공용 도트를 쓴다.

[실제 화면 39장·전체 대진 CSV·ZIP](../review/trainer-sprite-expansion/README.md). 기존 원작 도트 75대진과 앞서 추가한 칼로스/알로라 14대진을 그대로 보존했다.

## 출처와 제작자

- 다운로드: [SDM0/sprites](https://github.com/SDM0/sprites/tree/b22cba4e3b7bcb95e0259747952d0ddf4f8cfd6f/sprites/trainers), 고정 커밋 `b22cba4e3b7bcb95e0259747952d0ddf4f8cfd6f`의 공개 Showdown 컬렉션. 업로더를 그림의 제작자로 표기하지 않는다.
- 제작자 근거: [Showdown 트레이너 갤러리 고정 크레딧](https://github.com/smogon/pokemon-showdown-client/blob/74056bbbb55d6ce15f9dd254186b94a51fe94b14/play.pokemonshowdown.com/sprites/trainers/index.php). 보관 원문은 `assets/sources/trainer_gallery_credits.php.txt`이며 SHA-256은 `a8ded83ddb43f3ccd9896c700613b1528ba3819d5e39dae100fe5e87d286152c`다. 파일명별 작가를 대응했다.
- 안내: “Credit must be given to the appropriate artist if used elsewhere. DO NOT EDIT without permission.” 원본 PNG를 수정하지 않고 제작자를 명세와 필수 고지에 기록한다. 원래 캐릭터 권리는 Nintendo / Game Freak / The Pokémon Company에 있다.
- Brumirage 18명, kyledove 14명/15대진, ZacWeavile 1명이다. 네모는 바이올렛 복장 `nemona-v.png`를 사용한다.
- 공개 GitHub 컬렉션의 바이트와 SHA·실제 투명 경계를 검증했다. 접속이 차단된 Showdown 이미지 서버와 바이트가 같은지까지 비교하지는 않았다. 특정 팬게임이 같은 에셋을 사용했다는 근거도 확인하지 않았다.

| 대진 | 이름 | 제작자 |
|---|---|---|
| gym:grant | 자크로 | kyledove |
| gym:milo | 아킬 | Brumirage |
| gym:nessa | 야청 | Brumirage |
| gym:kabu | 순무 | Brumirage |
| gym:bea | 채두 | Brumirage |
| gym:allister | 어니언 | Brumirage |
| gym:opal | 포플러 | Brumirage |
| gym:gordie | 마쿠와 | Brumirage |
| gym:melony | 멜론 | Brumirage |
| gym:piers | 두송 | Brumirage |
| gym:raihan | 금랑 | Brumirage |
| gym:bede | 비트 | Brumirage |
| gym:marnie | 마리 | Brumirage |
| gym:klara | 도정 | Brumirage |
| gym:avery | 세이버리 | Brumirage |
| gym:mustard | 마스터드 | Brumirage |
| gym:peony | 피오니 | Brumirage |
| gym:tyme | 타임 | kyledove |
| gym:katy | 단풍 | kyledove |
| gym:brassius | 콜사 | kyledove |
| gym:iono | 모야모 | kyledove |
| gym:kofu | 곤포 | kyledove |
| gym:larry | 청목 | kyledove |
| gym:ryme | 라임 | kyledove |
| gym:tulip | 리파 | kyledove |
| gym:grusha | 그루샤 | ZacWeavile |
| elite:rika | 칠리 | kyledove |
| elite:poppy | 뽀삐 | kyledove |
| elite:larry | 청목 | kyledove |
| elite:hassel | 팔자크 | kyledove |
| champion:diantha | 카르네 | Brumirage |
| champion:leon | 단델 | Brumirage |
| champion:geeta | 테사 | kyledove |
| champion:nemona | 네모 | kyledove |

## 적용과 검증

게임 코드·씬·게임 데이터 12개·저장 버전·성장/난도를 바꾸지 않았다. 사용자 전장 좌표 SHA-256은 `b0f2e796afbb02eb04bef728ae28cfd113b1b8a8d6939911d5d0371ba89724f3`다. 기존 87 PNG 바이트/메타데이터를 모두 보존했다.

- Godot **4.7.2/Linux** import 통과. 콘텐츠·글꼴·123대진 도트의 투명 경계·세 자세의 정수 배율/안전 영역·대사·모델/난수 불변 **3,849개** 통과.
- 실제 1920×1080 전투 창 **380개/34대진/세 연출 속도** 통과. 등장 34장·투척 5장을 촬영했다. 입력 잠금, 본인 도트/대사, 발끝, 파티 목록/대사창과 간격, 공 비행, 카드/HP/에너지/난수 불변, 완료 후 입력 복원을 검사한다. OS 포인터 클릭 검사는 아니다.
- **124대진 / 123개별 도트 / 공용 1 / PNG 120장**의 SHA·크기·출처 고정 커밋·작가/고지 원문 지문을 오프라인 확인했다.
- 모야모·단델·뽀삐·테사의 실제 캡처를 직접 열어 확인했다. 39장은 외형 비교용 Lv.30 테스트 데이터이며 실제 챔피언은 기존대로 전원 Lv.100이다. Windows 실행·밸런스 측정·추가 저장 회귀를 실행한 것은 아니다.

## 최신 main에서 재현

이 자료 브랜치의 게임 사본은 최신 main이 아니다. main 체크아웃에서 검증 파일을 외부로 추출해 실행한다. 필수 에셋과 출처 고지만 main에 두고 개발 도구/갤러리는 여기에 보관한다.

```bash
git show development-materials:tools/fetch_trainer_sprites.py > /tmp/check_trainer_sprites.py
git show development-materials:assets/sources/trainer_gallery_credits.php.txt > /tmp/trainer_gallery_credits.txt
python3 /tmp/check_trainer_sprites.py --game-root . --credits-index /tmp/trainer_gallery_credits.txt --expected-included 124
git show development-materials:tests/test_trainer_dialogue.gd > /tmp/test_trainer_dialogue.gd
godot --headless --path . --script /tmp/test_trainer_dialogue.gd
# 실제 화면이 있는 환경에서만 실행:
git show development-materials:tests/native_later_trainers_probe.gd > /tmp/native_later_trainers_probe.gd
godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script /tmp/native_later_trainers_probe.gd
```

시트론은 현재 크레딧 목록에 작가가 없어 다른 작가를 임의로 붙이지 않는다. 나머지 도트 확보를 다시 미완료로 취급하지 않는다.
