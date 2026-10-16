# 배경을 보며 포켓몬 위치 수정하기

**[HTML 파일 다운로드 · 약 28MB](https://github.com/agree-git/pokemon-deckbuilder/raw/refs/heads/background-review-2026-10-16/pokemon-background-editor.html?download=1)** · **[ZIP 다운로드 · 약 21MB](https://github.com/agree-git/pokemon-deckbuilder/raw/refs/heads/background-review-2026-10-16/pokemon-background-editor.zip)**

HTML 하나만 내려받아 브라우저로 열면 됩니다. GitHub 파일 보기 화면에서는 실행되지 않습니다. ZIP에도 같은 HTML이 들어 있습니다. 배경 48종과 386종 앞뒤 스프라이트를 포함해 인터넷 없이 동작합니다.

1. 배경을 선택합니다.
2. 포켓몬을 드래그하거나, 내 포켓몬/상대를 선택하고 발판 중심을 누릅니다.
3. ‘게임 구도 미리보기’로 확인합니다.
4. **‘수정 좌표 JSON 저장’**을 누릅니다. `battlefield_layouts.json`을 보내주시면 게임에 적용하겠습니다.

숫자·방향키 미세 조정, 터치, 되돌리기/다시 하기, JSON 불러오기, CSV/PNG 저장도 지원합니다. 직접 적용하려면 게임 종료 후 프로젝트의 `data/battlefield_layouts.json`을 교체하고 다시 실행합니다. [자세한 사용법/재현 소스](https://github.com/agree-git/pokemon-deckbuilder/blob/main/docs/battlefield-editor.md).

[![HTML 위치 수정 도구](editor-preview.png)](editor-preview.png)

[게임 구도 미리보기 예시](editor-game-preview.png). UI는 영역 가이드이며 실제 게임 UI 실행은 아닙니다.

**현재 게임 좌표를 초기값으로 담은 수정 도구입니다. 기존 좌표가 전체적으로 어긋난다는 피드백 이후 제공하며, 아래 예전 갤러리·ZIP·CSV를 새 좌표로 재촬영한 것은 아닙니다.**

---

# 이전 전투 배경 갤러리

이전 좌표로 촬영한 **1920×1080 실제 게임 화면 65장**입니다. 바이옴 18·사천왕 후보 31·챔피언 후보 11·예비 5를 포함합니다. 같은 방을 공유하는 사천왕도 모두 촬영했습니다.

아래 모음 이미지를 누르면 확대할 수 있습니다. 분류별 원본은 접힌 목록을 펼쳐 확인하세요.

[전체 ZIP 다운로드 · 약 81MB](https://github.com/agree-git/pokemon-deckbuilder/raw/refs/heads/background-review-2026-10-16/pokemon-background-aligned-final-2026-10-16.zip) · [좌표 CSV 보기](review/floor_coordinates.csv) · [CSV 다운로드](https://github.com/agree-git/pokemon-deckbuilder/raw/refs/heads/background-review-2026-10-16/review/floor_coordinates.csv) · [HTML 갤러리 파일](review/index.html)

ZIP을 풀고 `index.html`을 열면 이름·타입·지방 검색과 일반/접지 좌표 화면 전환을 사용할 수 있습니다. GitHub에서는 이 문서가 모바일용 갤러리입니다.

배경 48종의 바닥을 수동 계측했습니다. 좌표 CSV와 가이드의 수치는 셀 내부 좌표 및 화면 투영 좌표입니다. 고정 파티로 만든 검토용 장면이며 원정 완주 기록이나 사용자 저장이 아닙니다.

구현: [8e5a676](https://github.com/agree-git/pokemon-deckbuilder/commit/8e5a676e0280abb5c8565e38b03a385fa036feb6). 이 자료는 해당 접지 수정 결과이며 이후 콘텐츠 변경 전 촬영본입니다.

## 바이옴 18곳

[![바이옴 18곳 모음](review/sheets/biomes.png)](review/sheets/biomes.png)

<details><summary>바이옴 18곳 원본 전체 펼치기</summary>

### 노말 · 바람결 초원

[![노말 · 바람결 초원](review/screens/biomes/normal.png)](review/screens/biomes/normal.png)

[접지 기준점 확인](review/guides/biomes_normal.png)

### 불꽃 · 잿불 칼데라

[![불꽃 · 잿불 칼데라](review/screens/biomes/fire.png)](review/screens/biomes/fire.png)

[접지 기준점 확인](review/guides/biomes_fire.png)

### 물 · 해오름 물가

[![물 · 해오름 물가](review/screens/biomes/water.png)](review/screens/biomes/water.png)

[접지 기준점 확인](review/guides/biomes_water.png)

### 풀 · 햇살숲 정원

[![풀 · 햇살숲 정원](review/screens/biomes/grass.png)](review/screens/biomes/grass.png)

[접지 기준점 확인](review/guides/biomes_grass.png)

### 전기 · 번개 수정 고원

[![전기 · 번개 수정 고원](review/screens/biomes/electric.png)](review/screens/biomes/electric.png)

[접지 기준점 확인](review/guides/biomes_electric.png)

### 얼음 · 서리빛 빙하

[![얼음 · 서리빛 빙하](review/screens/biomes/ice.png)](review/screens/biomes/ice.png)

[접지 기준점 확인](review/guides/biomes_ice.png)

### 격투 · 수련 협곡

[![격투 · 수련 협곡](review/screens/biomes/fighting.png)](review/screens/biomes/fighting.png)

[접지 기준점 확인](review/guides/biomes_fighting.png)

### 독 · 독안개 늪

[![독 · 독안개 늪](review/screens/biomes/poison.png)](review/screens/biomes/poison.png)

[접지 기준점 확인](review/guides/biomes_poison.png)

### 땅 · 모래바람 사막

[![땅 · 모래바람 사막](review/screens/biomes/ground.png)](review/screens/biomes/ground.png)

[접지 기준점 확인](review/guides/biomes_ground.png)

### 비행 · 구름마루 절벽

[![비행 · 구름마루 절벽](review/screens/biomes/flying.png)](review/screens/biomes/flying.png)

[접지 기준점 확인](review/guides/biomes_flying.png)

### 에스퍼 · 별무리 유적

[![에스퍼 · 별무리 유적](review/screens/biomes/psychic.png)](review/screens/biomes/psychic.png)

[접지 기준점 확인](review/guides/biomes_psychic.png)

### 벌레 · 이슬잎 수풀

[![벌레 · 이슬잎 수풀](review/screens/biomes/bug.png)](review/screens/biomes/bug.png)

[접지 기준점 확인](review/guides/biomes_bug.png)

### 바위 · 화석바위 산지

[![바위 · 화석바위 산지](review/screens/biomes/rock.png)](review/screens/biomes/rock.png)

[접지 기준점 확인](review/guides/biomes_rock.png)

### 고스트 · 달그림 묘원

[![고스트 · 달그림 묘원](review/screens/biomes/ghost.png)](review/screens/biomes/ghost.png)

[접지 기준점 확인](review/guides/biomes_ghost.png)

### 드래곤 · 용마루 성역

[![드래곤 · 용마루 성역](review/screens/biomes/dragon.png)](review/screens/biomes/dragon.png)

[접지 기준점 확인](review/guides/biomes_dragon.png)

### 악 · 그믐밤 숲

[![악 · 그믐밤 숲](review/screens/biomes/dark.png)](review/screens/biomes/dark.png)

[접지 기준점 확인](review/guides/biomes_dark.png)

### 강철 · 녹슨 발전소

[![강철 · 녹슨 발전소](review/screens/biomes/steel.png)](review/screens/biomes/steel.png)

[접지 기준점 확인](review/guides/biomes_steel.png)

### 페어리 · 별꽃 요정숲

[![페어리 · 별꽃 요정숲](review/screens/biomes/fairy.png)](review/screens/biomes/fairy.png)

[접지 기준점 확인](review/guides/biomes_fairy.png)

</details>

## 사천왕 후보 31명

[![사천왕 후보 31명 모음](review/sheets/elite.png)](review/sheets/elite.png)

<details><summary>사천왕 후보 31명 원본 전체 펼치기</summary>

### 관동 · 칸나 / 얼음

[![관동 · 칸나 / 얼음](review/screens/elite/lorelei.png)](review/screens/elite/lorelei.png)

[접지 기준점 확인](review/guides/elite_lorelei.png)

### 관동 · 시바 / 격투

[![관동 · 시바 / 격투](review/screens/elite/bruno.png)](review/screens/elite/bruno.png)

[접지 기준점 확인](review/guides/elite_bruno.png)

### 관동 · 국화 / 고스트

[![관동 · 국화 / 고스트](review/screens/elite/agatha.png)](review/screens/elite/agatha.png)

[접지 기준점 확인](review/guides/elite_agatha.png)

### 관동·성도 · 목호 / 드래곤

[![관동·성도 · 목호 / 드래곤](review/screens/elite/lance.png)](review/screens/elite/lance.png)

[접지 기준점 확인](review/guides/elite_lance.png)

### 성도 · 일목 / 에스퍼

[![성도 · 일목 / 에스퍼](review/screens/elite/will.png)](review/screens/elite/will.png)

[접지 기준점 확인](review/guides/elite_will.png)

### 성도 · 독수 / 독

[![성도 · 독수 / 독](review/screens/elite/koga.png)](review/screens/elite/koga.png)

[접지 기준점 확인](review/guides/elite_koga.png)

### 성도 · 카렌 / 악

[![성도 · 카렌 / 악](review/screens/elite/karen.png)](review/screens/elite/karen.png)

[접지 기준점 확인](review/guides/elite_karen.png)

### 호연 · 혁진 / 악

[![호연 · 혁진 / 악](review/screens/elite/sidney.png)](review/screens/elite/sidney.png)

[접지 기준점 확인](review/guides/elite_karen.png)

### 호연 · 회연 / 고스트

[![호연 · 회연 / 고스트](review/screens/elite/phoebe.png)](review/screens/elite/phoebe.png)

[접지 기준점 확인](review/guides/elite_agatha.png)

### 호연 · 미혜 / 얼음

[![호연 · 미혜 / 얼음](review/screens/elite/glacia.png)](review/screens/elite/glacia.png)

[접지 기준점 확인](review/guides/elite_lorelei.png)

### 호연 · 권수 / 드래곤

[![호연 · 권수 / 드래곤](review/screens/elite/drake.png)](review/screens/elite/drake.png)

[접지 기준점 확인](review/guides/elite_lance.png)

### 신오 · 충호 / 벌레

[![신오 · 충호 / 벌레](review/screens/elite/aaron.png)](review/screens/elite/aaron.png)

[접지 기준점 확인](review/guides/elite_aaron.png)

### 신오 · 들국화 / 땅

[![신오 · 들국화 / 땅](review/screens/elite/bertha.png)](review/screens/elite/bertha.png)

[접지 기준점 확인](review/guides/elite_bertha.png)

### 신오 · 대엽 / 불꽃

[![신오 · 대엽 / 불꽃](review/screens/elite/flint.png)](review/screens/elite/flint.png)

[접지 기준점 확인](review/guides/elite_flint.png)

### 신오 · 오엽 / 에스퍼

[![신오 · 오엽 / 에스퍼](review/screens/elite/lucian.png)](review/screens/elite/lucian.png)

[접지 기준점 확인](review/guides/elite_will.png)

### 하나 · 망초 / 고스트

[![하나 · 망초 / 고스트](review/screens/elite/shauntal.png)](review/screens/elite/shauntal.png)

[접지 기준점 확인](review/guides/elite_agatha.png)

### 하나 · 블래리 / 악

[![하나 · 블래리 / 악](review/screens/elite/grimsley.png)](review/screens/elite/grimsley.png)

[접지 기준점 확인](review/guides/elite_karen.png)

### 하나 · 카틀레야 / 에스퍼

[![하나 · 카틀레야 / 에스퍼](review/screens/elite/caitlin.png)](review/screens/elite/caitlin.png)

[접지 기준점 확인](review/guides/elite_will.png)

### 하나 · 연무 / 격투

[![하나 · 연무 / 격투](review/screens/elite/marshal.png)](review/screens/elite/marshal.png)

[접지 기준점 확인](review/guides/elite_bruno.png)

### 칼로스 · 파키라 / 불꽃

[![칼로스 · 파키라 / 불꽃](review/screens/elite/malva.png)](review/screens/elite/malva.png)

[접지 기준점 확인](review/guides/elite_flint.png)

### 칼로스 · 즈미 / 물

[![칼로스 · 즈미 / 물](review/screens/elite/siebold.png)](review/screens/elite/siebold.png)

[접지 기준점 확인](review/guides/elite_siebold.png)

### 칼로스 · 간피 / 강철

[![칼로스 · 간피 / 강철](review/screens/elite/wikstrom.png)](review/screens/elite/wikstrom.png)

[접지 기준점 확인](review/guides/elite_wikstrom.png)

### 칼로스 · 드라세나 / 드래곤

[![칼로스 · 드라세나 / 드래곤](review/screens/elite/drasna.png)](review/screens/elite/drasna.png)

[접지 기준점 확인](review/guides/elite_lance.png)

### 알로라 · 할라 / 격투

[![알로라 · 할라 / 격투](review/screens/elite/hala.png)](review/screens/elite/hala.png)

[접지 기준점 확인](review/guides/elite_bruno.png)

### 알로라 · 라이치 / 바위

[![알로라 · 라이치 / 바위](review/screens/elite/olivia.png)](review/screens/elite/olivia.png)

[접지 기준점 확인](review/guides/elite_olivia.png)

### 알로라 · 아세로라 / 고스트

[![알로라 · 아세로라 / 고스트](review/screens/elite/acerola.png)](review/screens/elite/acerola.png)

[접지 기준점 확인](review/guides/elite_agatha.png)

### 알로라 · 카일리 / 비행

[![알로라 · 카일리 / 비행](review/screens/elite/kahili.png)](review/screens/elite/kahili.png)

[접지 기준점 확인](review/guides/elite_kahili.png)

### 팔데아 · 칠리 / 땅

[![팔데아 · 칠리 / 땅](review/screens/elite/rika.png)](review/screens/elite/rika.png)

[접지 기준점 확인](review/guides/elite_bertha.png)

### 팔데아 · 뽀삐 / 강철

[![팔데아 · 뽀삐 / 강철](review/screens/elite/poppy.png)](review/screens/elite/poppy.png)

[접지 기준점 확인](review/guides/elite_wikstrom.png)

### 팔데아 · 청목 / 비행

[![팔데아 · 청목 / 비행](review/screens/elite/larry.png)](review/screens/elite/larry.png)

[접지 기준점 확인](review/guides/elite_kahili.png)

### 팔데아 · 팔자크 / 드래곤

[![팔데아 · 팔자크 / 드래곤](review/screens/elite/hassel.png)](review/screens/elite/hassel.png)

[접지 기준점 확인](review/guides/elite_lance.png)

</details>

## 챔피언 후보 11명

[![챔피언 후보 11명 모음](review/sheets/champions.png)](review/sheets/champions.png)

<details><summary>챔피언 후보 11명 원본 전체 펼치기</summary>

### 관동 · 그린

[![관동 · 그린](review/screens/champions/blue.png)](review/screens/champions/blue.png)

[접지 기준점 확인](review/guides/champions_blue.png)

### 성도 · 목호

[![성도 · 목호](review/screens/champions/lance.png)](review/screens/champions/lance.png)

[접지 기준점 확인](review/guides/champions_lance.png)

### 호연 · 성호

[![호연 · 성호](review/screens/champions/steven.png)](review/screens/champions/steven.png)

[접지 기준점 확인](review/guides/champions_steven.png)

### 호연 · 윤진

[![호연 · 윤진](review/screens/champions/wallace.png)](review/screens/champions/wallace.png)

[접지 기준점 확인](review/guides/champions_wallace.png)

### 신오 · 난천

[![신오 · 난천](review/screens/champions/cynthia.png)](review/screens/champions/cynthia.png)

[접지 기준점 확인](review/guides/champions_cynthia.png)

### 하나 · 노간주

[![하나 · 노간주](review/screens/champions/alder.png)](review/screens/champions/alder.png)

[접지 기준점 확인](review/guides/champions_alder.png)

### 하나 · 아이리스

[![하나 · 아이리스](review/screens/champions/iris.png)](review/screens/champions/iris.png)

[접지 기준점 확인](review/guides/champions_iris.png)

### 칼로스 · 카르네

[![칼로스 · 카르네](review/screens/champions/diantha.png)](review/screens/champions/diantha.png)

[접지 기준점 확인](review/guides/champions_diantha.png)

### 가라르 · 단델

[![가라르 · 단델](review/screens/champions/leon.png)](review/screens/champions/leon.png)

[접지 기준점 확인](review/guides/champions_leon.png)

### 팔데아 · 테사

[![팔데아 · 테사](review/screens/champions/geeta.png)](review/screens/champions/geeta.png)

[접지 기준점 확인](review/guides/champions_geeta.png)

### 팔데아 · 네모

[![팔데아 · 네모](review/screens/champions/nemona.png)](review/screens/champions/nemona.png)

[접지 기준점 확인](review/guides/champions_nemona.png)

</details>

## 예비 배경 5개

[![예비 배경 5개 모음](review/sheets/reserve.png)](review/sheets/reserve.png)

<details><summary>예비 배경 5개 원본 전체 펼치기</summary>

### 예비 노말 룸

[![예비 노말 룸](review/screens/reserve/elite_normal.png)](review/screens/reserve/elite_normal.png)

[접지 기준점 확인](review/guides/reserve_elite_normal.png)

### 예비 전기 룸

[![예비 전기 룸](review/screens/reserve/elite_electric.png)](review/screens/reserve/elite_electric.png)

[접지 기준점 확인](review/guides/reserve_elite_electric.png)

### 예비 풀 룸

[![예비 풀 룸](review/screens/reserve/elite_grass.png)](review/screens/reserve/elite_grass.png)

[접지 기준점 확인](review/guides/reserve_elite_grass.png)

### 예비 페어리 룸

[![예비 페어리 룸](review/screens/reserve/elite_fairy.png)](review/screens/reserve/elite_fairy.png)

[접지 기준점 확인](review/guides/reserve_elite_fairy.png)

### 공용 리그 홀

[![공용 리그 홀](review/screens/reserve/champion_fallback.png)](review/screens/reserve/champion_fallback.png)

[접지 기준점 확인](review/guides/reserve_champion_fallback.png)

</details>
