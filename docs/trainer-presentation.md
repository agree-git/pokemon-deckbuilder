# 보스 대사와 트레이너 도트

관장 82팀·사천왕 31팀·챔피언 11팀, 총 124개 대진에 등장/마지막 포켓몬 출전/패배 대사 372개를 연결했다. 원작 대사를 인용하지 않은 짧은 자체 한국어 문장이다. 원작 도트 75대진/73 PNG에 팬 제작 49대진/48 PNG를 더했다. 현재 **124대진/121 PNG**가 모두 개별 외형을 사용한다. [시트론 적용과 출처](clemont-sprite.md)를 따른다. [최신 34대진 추가](trainer-sprite-expansion.md)와 [이전 14대진](trainer-fan-sprites.md)을 따른다.

## 등장과 표시

트레이너가 들어오면 대사를 보여주고 준비 → 공 투척 → 포켓몬 출전 → 퇴장 순서로 이어진다. 마지막 상대 포켓몬도 실제 공에서 나온 뒤에 대사를 보여준다. 기본 표시 시간은 2.2초이며 기존 1/1.5/2배 전투 연출 설정을 따른다. 표시 중 전투 입력은 잠긴다. 패배 대사는 승리 결과 창에서 계속 읽을 수 있다. 일반 트레이너/엘리트 트레이너는 기존 짧은 도입을 사용한다.

`kind:id`로 찾으므로 그린·목호·독수·윤진·아이리스·청목의 서로 다른 역할을 혼동하지 않는다. 타입 강조색은 해당 인물의 실제 전문 타입을 따른다. 혼합 파티/챔피언의 대사 창은 전문 타입을 임의로 지정하지 않고 배지 기호를 사용한다. 알 수 없는 ID는 다른 인물의 대사나 외형을 대신 사용하지 않는다.

대사 조회와 연출은 전투/원정/난수/저장을 바꾸지 않는다. 같은 전투의 UI 갱신과 이미 행동한 중간 저장 복원에서는 등장 대사를 반복하지 않는다. 마지막 출전 이후 저장을 복원해도 그 대사를 다시 재생하지 않으며, 승리 저장은 결과의 패배 대사를 바로 복원한다. 기존과 같이 첫 행동 전 전투를 파일에서 새로 불러오면 등장 연출이 다시 나올 수 있다.

## 도트 출처와 적용 범위

- 출처: [Smogon / Pokémon Showdown sprite repository](https://github.com/smogon/sprites), 고정 커밋 `a9214714f00974a8c28586829e6315d9ca5a6348`의 `src/_uncategorized/canonical/trainers/`.
- 1~5세대 게임에서 가져온 인물별 정면 도트다. 포켓몬 종의 1~3세대 제한과 별개로 관장·리그 인물은 전 지방을 허용한다.
- 원본 PNG는 수정하지 않는다. 원본 투명 영역의 실제 경계를 기록하고, 발끝을 기존 전장 바닥 좌표에 놓는다. 최근접 보간·정수 배율로 최대 높이 260/폭 260 안에 그린다. 풍·란은 두 사람이 있는 원작 도트 한 장을 사용한다.
- 그린 관장/챔피언, 아이리스 관장/챔피언, 윤진 관장/챔피언은 역할에 맞는 원작 버전을 대응한다. 원본은 정지 이미지다. 준비·투척 시 작은 몸 이동과 별도 포켓볼 궤적을 합성하며, 인물별 원작 투척 프레임을 새로 확보한 것은 아니다.
- **모든 124대진을 적용했다.** 시트론은 사용자가 제공한 Gnomowladny 원작 링크를 기록했다. [후대 적용 목록](trainer-sprite-links.md)과 [최신 추가 출처](trainer-sprite-expansion.md)를 따른다. Showdown 갤러리의 제작자 표기·허락 없는 편집 금지 안내와 일반 저장소 고지를 함께 유지한다.
- 포켓몬 이미지 권리는 Nintendo / Game Freak / The Pokémon Company에 있다. 출처 저장소 공개가 상업 배포 허가를 뜻하지 않는다. 고정 원문은 `assets/sources/SMOGON_SPRITES_README.md`, 대진별 적용/미적용·원본 URL·SHA-256·크기·투명 경계는 `assets/sources/trainer_sprites.json`에 있다.

검증과 원본 재다운로드:

```bash
python3 /tmp/check_trainer_sprites.py --game-root . --credits-index /tmp/trainer_gallery_credits.txt --expected-included 124
# 최신 main에서 외부 검증 파일을 추출하는 절차는 trainer-sprite-expansion.md를 따른다.
```

## 수정할 파일

- `data/trainer_dialogue.json`: 역할별 세 문장. 문장을 늘리면 두 대사 창의 실제 한국어 줄바꿈도 검사한다.
- `scripts/content/trainer_dialogue.gd`: 원정 메타데이터와 대사 조회. 이름만으로 잘못 대응하는 fallback은 두지 않는다.
- `assets/sources/trainer_sprites.json` / `scripts/content/trainer_sprites.gd`: 안정 ID별 에셋 대응과 읽기 전용 조회. 새 팬 도트는 제작자·조건을 먼저 기록한다.
- `scripts/ui/trainer_entrance.gd`: 원본 도트/공용 도트와 공 궤적. `TrainerSpeech`와 `TacticalUI`는 등장·마지막 출전·결과 시점을 담당한다.

## 검토

[전체 124대진 적용 상태·시트론 화면·ZIP·CSV](../review/clemont/README.md). [직전 추가 34대진 화면 39장](../review/trainer-sprite-expansion/README.md). 아래는 최초 적용 때의 역사 자료로, 당시 공용이던 모야모/청목도 현재는 개별 도트를 사용한다.

[실제 1920×1080 화면·전체 적용/미적용 목록·CSV·ZIP](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/review/trainer-presentation/README.md). 웅·목호·난천은 원본 도트, 모야모·청목은 공용 도트로 남은 인물을 보여준다. 마지막 출전/승리 화면은 해당 시점을 확인하기 위한 HP 1 검토 fixture이며 정상 난도 자료가 아니다.
