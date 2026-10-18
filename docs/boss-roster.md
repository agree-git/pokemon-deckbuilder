# 관장·사천왕·챔피언 목록과 BGM 배정

확인: 2026-10-18. 게임 main 반영은 완료했으며 EXE 생성은 계속 보류 중입니다. 원작 기반 파티 변경은 [별도 검토안](boss-party-review.md)에 정리했고 컨펌 전 게임에는 적용하지 않았습니다. **관장86·사천왕36·챔피언15, 총137대진**. 원정은 관장8→사천왕4→챔피언1, 기존69전투를 유지합니다. 새 원정(v3)은 같은 인물도 역할이 다르면 별개 대진으로 추첨합니다. 이전 저장(v1/v2)은 기존 경로를 복원합니다.

사용자 제공39파일을36개 녹음으로 중복 제거해 역할별로 연결했습니다. BW/BW2처럼 같은 역할에 두 곡이 있으면 등장할 때 하나를 고르고 해당 전투 내에서는 유지합니다. 레드는 챔피언입니다. 알로라 섬의왕/여왕은 요청한 관장 역할 후보에 포함합니다. 블루베리는 하나지방의 아카데미이며 첨부 파일의 팔데아 표기는 SV DLC 분류로 처리했습니다.

비트·마리·타임은 첨부 파일명에 없어 해당 지방의 일반 관장곡을 사용합니다. 표의 `지역 공용`으로 구분합니다. 추가 인물의 파티는 현재 게임의 일반1~3세대 범위에 맞춘 구성으로, 원작 후대 파티를 그대로 재현한 목록이 아닙니다. 신규13대진 모두 개별 대사3단계·전술·도트·적합한 배경을 연결했습니다.

[기계 판독 JSON](boss-roster.json) · [음원/ZIP 출처와 지문](https://github.com/agree-git/pokemon-deckbuilder/blob/main/assets/audio/boss_music/manifest.json) · [스프라이트 출처](https://github.com/agree-git/pokemon-deckbuilder/blob/main/assets/sources/trainer_sprites.json)

## 관장 · 86대진

| 지방 | 이름 | 역할 키 | 배정 녹음 | 비고 |
|---|---|---|---|---|
| 관동 | 웅 | `gym:brock` | boss_02 |  |
| 관동 | 이슬 | `gym:misty` | boss_02 |  |
| 관동 | 마티스 | `gym:lt_surge` | boss_02 |  |
| 관동 | 민화 | `gym:erika` | boss_02 |  |
| 관동 | 독수 | `gym:koga` | boss_02 |  |
| 관동 | 초련 | `gym:sabrina` | boss_02 |  |
| 관동 | 강연 | `gym:blaine` | boss_02 |  |
| 관동 | 비주기 | `gym:giovanni` | boss_02 |  |
| 관동 | 도희 | `gym:janine` | boss_01 |  |
| 관동 | 그린 | `gym:blue` | boss_01 |  |
| 성도 | 비상 | `gym:falkner` | boss_04 |  |
| 성도 | 호일 | `gym:bugsy` | boss_04 |  |
| 성도 | 꼭두 | `gym:whitney` | boss_04 |  |
| 성도 | 유빈 | `gym:morty` | boss_04 |  |
| 성도 | 사도 | `gym:chuck` | boss_04 |  |
| 성도 | 규리 | `gym:jasmine` | boss_04 |  |
| 성도 | 류옹 | `gym:pryce` | boss_04 |  |
| 성도 | 이향 | `gym:clair` | boss_04 |  |
| 호연 | 원규 | `gym:roxanne` | boss_06 |  |
| 호연 | 철구 | `gym:brawly` | boss_06 |  |
| 호연 | 암페어 | `gym:wattson` | boss_06 |  |
| 호연 | 민지 | `gym:flannery` | boss_06 |  |
| 호연 | 종길 | `gym:norman` | boss_06 |  |
| 호연 | 은송 | `gym:winona` | boss_06 |  |
| 호연 | 풍·란 | `gym:tate_liza` | boss_06 |  |
| 호연 | 윤진 | `gym:wallace` | boss_06 |  |
| 호연 | 아단 | `gym:juan` | boss_06 |  |
| 신오 | 강석 | `gym:roark` | boss_08 |  |
| 신오 | 유채 | `gym:gardenia` | boss_08 |  |
| 신오 | 자두 | `gym:maylene` | boss_08 |  |
| 신오 | 맥실러 | `gym:crasher_wake` | boss_08 |  |
| 신오 | 멜리사 | `gym:fantina` | boss_08 |  |
| 신오 | 동관 | `gym:byron` | boss_08 |  |
| 신오 | 무청 | `gym:candice` | boss_08 |  |
| 신오 | 전진 | `gym:volkner` | boss_08 |  |
| 하나 | 덴트 | `gym:cilan` | boss_11 |  |
| 하나 | 팟 | `gym:chili` | boss_11 |  |
| 하나 | 콘 | `gym:cress` | boss_11 |  |
| 하나 | 알로에 | `gym:lenora` | boss_11 |  |
| 하나 | 아티 | `gym:burgh` | boss_11, boss_12 |  |
| 하나 | 카밀레 | `gym:elesa` | boss_11, boss_12 |  |
| 하나 | 야콘 | `gym:clay` | boss_11, boss_12 |  |
| 하나 | 풍란 | `gym:skyla` | boss_11, boss_12 |  |
| 하나 | 담죽 | `gym:brycen` | boss_11 |  |
| 하나 | 사간 | `gym:drayden` | boss_11, boss_12 |  |
| 하나 | 아이리스 | `gym:iris` | boss_11 |  |
| 하나 | 체렌 | `gym:cheren` | boss_12 |  |
| 하나 | 보미 | `gym:roxie` | boss_12 |  |
| 하나 | 시즈 | `gym:marlon` | boss_12 |  |
| 칼로스 | 비올라 | `gym:viola` | boss_15 |  |
| 칼로스 | 자크로 | `gym:grant` | boss_15 |  |
| 칼로스 | 코르니 | `gym:korrina` | boss_15 |  |
| 칼로스 | 후쿠지 | `gym:ramos` | boss_15 |  |
| 칼로스 | 시트론 | `gym:clemont` | boss_15 |  |
| 칼로스 | 마슈 | `gym:valerie` | boss_15 |  |
| 칼로스 | 고지카 | `gym:olympia` | boss_15 |  |
| 칼로스 | 우르프 | `gym:wulfric` | boss_15 |  |
| 가라르 | 아킬 | `gym:milo` | boss_25 |  |
| 가라르 | 야청 | `gym:nessa` | boss_25 |  |
| 가라르 | 순무 | `gym:kabu` | boss_25 |  |
| 가라르 | 채두 | `gym:bea` | boss_25 |  |
| 가라르 | 어니언 | `gym:allister` | boss_25 |  |
| 가라르 | 포플러 | `gym:opal` | boss_25 |  |
| 가라르 | 마쿠와 | `gym:gordie` | boss_25 |  |
| 가라르 | 멜론 | `gym:melony` | boss_25 |  |
| 가라르 | 두송 | `gym:piers` | boss_24 |  |
| 가라르 | 금랑 | `gym:raihan` | boss_25 |  |
| 가라르 | 비트 | `gym:bede` | boss_25 | 지역 공용 |
| 가라르 | 마리 | `gym:marnie` | boss_25 | 지역 공용 |
| 가라르 | 도정 | `gym:klara` | boss_27 |  |
| 가라르 | 세이버리 | `gym:avery` | boss_30 |  |
| 가라르 | 마스터드 | `gym:mustard` | boss_28 |  |
| 가라르 | 피오니 | `gym:peony` | boss_29 |  |
| 팔데아 | 타임 | `gym:tyme` | boss_31 | 지역 공용 |
| 팔데아 | 단풍 | `gym:katy` | boss_31 |  |
| 팔데아 | 콜사 | `gym:brassius` | boss_31 |  |
| 팔데아 | 모야모 | `gym:iono` | boss_31 |  |
| 팔데아 | 곤포 | `gym:kofu` | boss_31 |  |
| 팔데아 | 청목 | `gym:larry` | boss_31 |  |
| 팔데아 | 라임 | `gym:ryme` | boss_31 |  |
| 팔데아 | 리파 | `gym:tulip` | boss_31 |  |
| 팔데아 | 그루샤 | `gym:grusha` | boss_31 |  |
| 알로라 | 할라 | `gym:hala` | boss_19 | 추가 |
| 알로라 | 라이치 | `gym:olivia` | boss_19 | 추가 |
| 알로라 | 나누 | `gym:nanu` | boss_19 | 추가 |
| 알로라 | 하푸우 | `gym:hapu` | boss_19 | 추가 |

## 사천왕 · 36대진

| 지방 | 이름 | 역할 키 | 배정 녹음 | 비고 |
|---|---|---|---|---|
| 관동 | 칸나 | `elite:lorelei` | boss_02 |  |
| 관동 | 시바 | `elite:bruno` | boss_02, boss_04 |  |
| 관동 | 국화 | `elite:agatha` | boss_02 |  |
| 관동·성도 | 목호 | `elite:lance` | boss_02 |  |
| 성도 | 일목 | `elite:will` | boss_04 |  |
| 성도 | 독수 | `elite:koga` | boss_04 |  |
| 성도 | 카렌 | `elite:karen` | boss_04 |  |
| 호연 | 혁진 | `elite:sidney` | boss_07 |  |
| 호연 | 회연 | `elite:phoebe` | boss_07 |  |
| 호연 | 미혜 | `elite:glacia` | boss_07 |  |
| 호연 | 권수 | `elite:drake` | boss_07 |  |
| 신오 | 충호 | `elite:aaron` | boss_09 |  |
| 신오 | 들국화 | `elite:bertha` | boss_09 |  |
| 신오 | 대엽 | `elite:flint` | boss_09 |  |
| 신오 | 오엽 | `elite:lucian` | boss_09 |  |
| 하나 | 망초 | `elite:shauntal` | boss_13 |  |
| 하나 | 블래리 | `elite:grimsley` | boss_13 |  |
| 하나 | 카틀레야 | `elite:caitlin` | boss_13 |  |
| 하나 | 연무 | `elite:marshal` | boss_13 |  |
| 칼로스 | 파키라 | `elite:malva` | boss_16 |  |
| 칼로스 | 즈미 | `elite:siebold` | boss_16 |  |
| 칼로스 | 간피 | `elite:wikstrom` | boss_16 |  |
| 칼로스 | 드라세나 | `elite:drasna` | boss_16 |  |
| 알로라 | 할라 | `elite:hala` | boss_20 |  |
| 알로라 | 라이치 | `elite:olivia` | boss_20 |  |
| 알로라 | 아세로라 | `elite:acerola` | boss_20 |  |
| 알로라 | 카일리 | `elite:kahili` | boss_20 |  |
| 팔데아 | 칠리 | `elite:rika` | boss_32 |  |
| 팔데아 | 뽀삐 | `elite:poppy` | boss_32 |  |
| 팔데아 | 청목 | `elite:larry` | boss_32 |  |
| 팔데아 | 팔자크 | `elite:hassel` | boss_32 |  |
| 알로라 | 멀레인 | `elite:molayne` | boss_20 | 추가 |
| 블루베리 | 하솔 | `elite:crispin` | boss_34 | 추가 |
| 블루베리 | 네리네 | `elite:amarys` | boss_34 | 추가 |
| 블루베리 | 타로 | `elite:lacey` | boss_34 | 추가 |
| 블루베리 | 제빈 | `elite:drayton` | boss_34 | 추가 |

## 챔피언 · 15대진

| 지방 | 이름 | 역할 키 | 배정 녹음 | 비고 |
|---|---|---|---|---|
| 관동 | 그린 | `champion:blue` | boss_03 |  |
| 성도 | 목호 | `champion:lance` | boss_05 |  |
| 호연 | 성호 | `champion:steven` | boss_14 |  |
| 호연 | 윤진 | `champion:wallace` | boss_14 |  |
| 신오 | 난천 | `champion:cynthia` | boss_10 |  |
| 하나 | 노간주 | `champion:alder` | boss_17 |  |
| 하나 | 아이리스 | `champion:iris` | boss_18 |  |
| 칼로스 | 카르네 | `champion:diantha` | boss_23 |  |
| 가라르 | 단델 | `champion:leon` | boss_26 |  |
| 팔데아 | 테사 | `champion:geeta` | boss_33 |  |
| 팔데아 | 네모 | `champion:nemona` | boss_35 |  |
| 알로라 | 쿠쿠이 | `champion:kukui` | boss_21 | 추가 |
| 알로라 | 하우 | `champion:hau` | boss_22 | 추가 |
| 블루베리 | 카지 | `champion:kieran` | boss_36 | 추가 |
| 관동 | 레드 | `champion:red` | boss_05 | 추가 |
