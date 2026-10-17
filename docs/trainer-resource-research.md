# 업로드된 트레이너 스프라이트 목록 조사

**자료를 확인했다.** `Pokémon Ultimate Trainer Sprite Collection.xlsx`에는 `Trainer Sprites`의 리소스 항목 277개와 `Collections with Trainer Sprite`의 팩 11개가 있다. 이미지가 내장된 파일은 아니며, 원본 사이트로 가는 링크와 분류·크레딧을 모은 목록이다. 이번에는 엑셀 내용과 하이퍼링크를 로컬에서 읽었으며 링크 대상의 실제 PNG/압축파일은 열거나 적용하지 않았다.

원본: [사용자가 제공한 Google 시트](https://docs.google.com/spreadsheets/d/1hHkm8mbWbH-TAsDW9L0xZ3uVqPl2kz3unohhtQtqRI0/edit?gid=0). XLSX SHA-256: `9c880b95d5933d6b6fb8dfde8436eeedafc65198d225db6bb8ce86ab842d536e`. 필요한 선별 항목 22개와 행 번호는 [구조화된 출처 목록](../assets/sources/trainer_resource_index.json)에 기록했다. 원본 파일·작성자 개인 메타데이터는 저장소에 복사하지 않았다.

## 보스 도트 탐색 우선순위

아래는 **엑셀에 실제 등재된 후보**다. 각 링크가 현재 열리는지, 6~9세대 어느 인물이 포함되는지, 기존 49개 미적용 대진을 전부 채우는지는 아직 확인되지 않았다.

| 우선 후보 | 원본 행 | 찾는 자료 |
|---|---|---|
| [Pokemon - Sprites - Trainers](https://www.deviantart.com/mbcmechachu/favourites/82691875/pokemon-sprites-trainers) | `Trainer Sprites!G190` | 여러 세대 전투용 도트를 모은 즐겨찾기. 수집자를 개별 그림의 작가로 간주하지 않는다. |
| [Graphics: - The DS-Style 64x64 Trainer Sprite Resource](https://www.pokecommunity.com/threads/the-ds-style-64x64-trainer-sprite-resource.308798/) | `Trainer Sprites!G158` | DS 스타일 64×64 트레이너 컬렉션. 인물별 포함 범위는 원문 확인 필요. |
| [Trainer sprites - Showdown!](https://play.pokemonshowdown.com/sprites/trainers/?view=sprites) | `Trainer Sprites!G165` | 이미 찾은 Showdown 컬렉션이 이 목록에도 등재되어 있다. |
| [Trainer Battle Sprites by Kyle-Dove on DeviantArt](https://www.deviantart.com/kyle-dove/art/Trainer-Battle-Sprites-705936021) | `Trainer Sprites!G93` | Kyle-Dove의 전투용 도트 모음. 그림별 실제 인물과 조건 확인 필요. |
| [Graphics: - ROM Hacking Sprites Pack: Overworlds, Trainer Sprites, Tilesets and more!](https://www.pokecommunity.com/threads/rom-hacking-sprites-pack-overworlds-trainer-sprites-tilesets-and-more.527581/) | `Trainer Sprites!G96` | 전투용·맵용·타일 등이 섞인 컬렉션. |
| [Trainer Sprite Collection (Link in Description)](https://www.deviantart.com/skidmarc25/art/1206670990) | `Trainer Sprites!G285` | 설명란에 컬렉션 링크가 있다는 항목. 실제 다운로드/인물 미확인. |
| [EPaulM - Digital Artist | DeviantArt](https://www.deviantart.com/epaulm/gallery?deviationid=980229018) | `Trainer Sprites!G288` | 64×64·여러 세대 전투용 도트 갤러리. 포함 범위 미확인. |

MBCMechachu 항목은 다른 작가의 작품을 모은 즐겨찾기 컬렉션이다. 실제 적용 시 각 그림의 원작자를 표기해야 한다. 어나더레드·올라라 포켓몬 타워가 이 컬렉션을 사용했다는 증거는 엑셀에 없으므로 해당 게임의 확정 출처로 설명하지 않는다.

## Eevee Expo에서 바로 열 후보

| 항목 | 작가/제출자 | 원본 행 | 분류상 주의 |
|---|---|---|
| [Trainer battlers - XY Trainer Class Sprites | Eevee Expo](https://eeveeexpo.com/resources/851/) | kyledove | `G127` | XY 일반 트레이너 직업군 자료. 관장/사천왕/챔피언 전체 수록으로 보지 않는다. |
| [Trainer battlers - ORAS Trainer Class Sprites ! | Eevee Expo](https://eeveeexpo.com/resources/853/) | kyledove | `G128` | ORAS 일반 트레이너 직업군 자료. 보스 전체 수록 미확인. |
| [Trainer battlers - SWSH Trainer Class Sprites | Eevee Expo](https://eeveeexpo.com/resources/942/) | kyledove | `G129` | SWSH 일반 트레이너 직업군 자료. Gen 4 표기와 원작 등장 세대를 혼동하지 않는다. |
| [USUM Trainer Classes](https://eeveeexpo.com/resources/949/) | kyledove | `G130` | USUM 일반 트레이너 직업군 자료. Gen 4는 도트 스타일일 수 있다. |
| [Trainer battlers - Random Trainer Graphic Resources | Eevee Expo](https://eeveeexpo.com/resources/1414/) | deoxysacid | `G114` | 여러 세대 트레이너 그래픽 모음. 실제 보스 포함 범위 미확인. |
| [Kitagami Ogre Clan Trainers](https://eeveeexpo.com/resources/1504/) | jinxed | `G108` | 9세대 관련 키타카미 오우거 클랜 전투용/맵용 자료. 현재 보스 후보 명단과는 별개다. |
| [Ethically-Sourced Handmade Alternate Trainer Spritepack](https://eeveeexpo.com/resources/1437/) | Muffyang | `G112` | 대체 전투 도트팩. 실제 보스 포함 범위 미확인. |
| [VS sprites - Trainer Sprite Pack | Eevee Expo](https://eeveeexpo.com/resources/1131/) | Tw_raZ | `G147` | 등장 전 VS 얼굴 자료. 전장에 서는 전신 도트와 구분한다. |

## 목록을 해석할 때

- `Generation`에는 등장 세대와 그림 스타일 분류가 섞여 있다. 예를 들어 `G129`의 SWSH, `G130`의 USUM 트레이너 직업군이 `Gen 4`로 표기되어 있다. `Gen 6` 이상만 필터링하면 후대 인물 도트를 놓칠 수 있다.
- `Trainer Sprites`/`Trainer battlers`는 전투용, `Overworld`는 맵 위 작은 캐릭터, `Trainer Vs. Faces`/`Mugshots`는 얼굴·초상 자료다. 단델 항목 `G245`는 `Overworld`이므로 전장용 전신 도트를 확인한 것으로 취급하지 않는다.
- `Trainer Classes`는 일반 트레이너 직업군 자료다. XY/SWSH라는 제목만으로 해당 세대 관장·사천왕·챔피언 전원 수록이라고 설명하지 않는다.
- 시트에는 비상업용 안내와 `☆` 작가 표기 필요, `❉` 조건 미기재 포함/표기 권장이 적혀 있다. 이는 목록의 안내이며 개별 원작 페이지의 허가를 대신하지 않는다.

## 다음 작업

기존 [49개 미적용 대진 후보](trainer-sprite-links.md)와 위 전투용 컬렉션을 대조한다. 우선 시트론을 포함한 고유 인물을 실제 그림으로 확인하고, 인물→원본→작가→사용 조건→SHA→게임 파일을 기록한 뒤 정수 배율·발끝·UI 간섭을 검증한다. 현재 게임의 75대진 원작 도트/49대진 공용 도트 상태는 이 조사로 바뀌지 않았다.
