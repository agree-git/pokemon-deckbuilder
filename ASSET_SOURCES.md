# 에셋 출처와 권리

사용 에셋의 출처와 필수 고지입니다. 원본 CSV·생성 도구·상세 제작 기록·미적용 후보는 [과거 자료의 고정 링크](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/history.md)에서 확인합니다.

## 포켓몬과 아이템

[PokéAPI/sprites](https://github.com/PokeAPI/sprites), 커밋 `0dc105d5b12416932f29b594078282ab4be045f5`의 386종 앞/뒤 PNG 772장과 아이템 그림을 사용합니다. 일부 아이템의 색/용도는 프로젝트에서 조정했습니다. [원본 URL·지문](assets/sources/manifest.json)과 [업스트림 고지](assets/sources/POKEAPI_SPRITES_LICENSE.txt)를 포함합니다. 이미지 권리는 The Pokémon Company에 있으며 저장소의 CC0 표기가 원작 이미지 권리를 이전하지 않습니다.

## 게임 데이터

[PokéAPI/pokeapi](https://github.com/PokeAPI/pokeapi), 커밋 `81d20919845b6a445969b9265aab5cec6b04cece`의 CSV를 바탕으로 이름·타입·능력치·기술·성장·진화 데이터를 생성했습니다. [데이터 라이선스](assets/sources/POKEAPI_DATA_LICENSE.txt)를 포함합니다. 파티 편성·카드·원정 규칙은 자체 작성입니다.

## 트레이너

[Smogon / Pokémon Showdown](https://github.com/smogon/sprites), 커밋 `a9214714f00974a8c28586829e6315d9ca5a6348`의 `src/_uncategorized/canonical/trainers/`에서 원작 도트 73장을 수정 없이 가져와 75대진에 대응합니다. 후대 인물 49대진에는 팬 도트 48장을 사용합니다. 총 **124대진/121 PNG**로 모든 보스 대진에 개별 외형이 연결돼 있습니다. [인물별 URL·SHA·경계](assets/sources/trainer_sprites.json), [출처 원문의 License 절](assets/sources/SMOGON_SPRITES_LICENSE.txt)을 포함합니다. 이미지 권리는 Nintendo / Game Freak / The Pokémon Company에 있으며 코드의 MIT 허가와 구분합니다.

팬 도트 제작자는 **Gnomowladny**, **Beliot419**, **Brumirage**, **kyledove**, **ZacWeavile**입니다. 칼로스·알로라 및 시트론 15장은 위 Smogon 고정 원본, 추가 33장은 공개 Showdown 스프라이트 컬렉션 [SDM0/sprites](https://github.com/SDM0/sprites/tree/b22cba4e3b7bcb95e0259747952d0ddf4f8cfd6f/sprites/trainers)의 고정 원본입니다. 파일명과 작가를 공식 Showdown 갤러리의 크레딧 목록에 대응했으며 이미지 호스트의 바이트까지 비교한 것은 아닙니다. [제작자별 고지](assets/sources/TRAINER_FAN_CREDITS.txt)와 각 파일의 명세에 출처를 기록합니다. 구체적인 트레이너 갤러리 안내는 외부 사용 시 제작자 표기·허락 없는 편집 금지를 요구합니다. 다운로드한 PNG를 수정 없이 사용하며 일반 저장소 고지와 함께 유지합니다.

시트론은 사용자가 제공한 [Gnomowladny의 원작 링크](https://www.deviantart.com/gnomowladny/art/Clemont-Sprite-430844892)를 제작자 근거로 기록합니다. 적용한 GitHub 보관본은 제공 이미지와 같은 포즈에 푸른 전기 효과가 있는 버전입니다. 원작 페이지는 이 환경에서 열리지 않아 별도 사용 허가를 확인했다고 주장하지 않으며, 원본 픽셀과 기존 고지를 보존합니다.

## 아이콘·배경·연출

타입 배지는 [duiker101/pokemon-type-svg-icons](https://github.com/duiker101/pokemon-type-svg-icons), 커밋 `5781623f147f1bf850f426cfe1874ba56a9b75ee`를 바탕으로 합니다. [원 디자인](https://dribbble.com/shots/4862612-Pokedex-iOS-app), [업스트림 안내](assets/sources/type-icons/README.md.txt), [명세](assets/sources/type_icons.json)를 유지합니다. “Very simple set of SVG icons for Pokemon types for any use.”라는 안내가 있으며 별도 LICENSE는 없습니다.

바이옴/리그 배경은 프로젝트용으로 이미지 생성 도구에서 제작했습니다. [바이옴 지문](assets/biomes/manifest.json)·[리그 지문](assets/league/manifest.json)과 `data/battlefield_layouts.json` 좌표를 사용합니다. 그 밖의 UI 기호·카드 그림·공용 트레이너·기술/날씨 연출은 코드로 직접 작성했습니다. 보스 대사와 희귀 포켓몬의 조우·포획·합류·방출 문구는 자체 작성입니다.

## 오디오·글꼴

장면별 음악 5곡과 효과음 15종은 프로젝트에서 합성했습니다. [음악 명세](assets/audio/music/manifest.json)를 포함합니다.

바이옴 18곳의 탐험/야영 음악 18곡과 환경음 18종도 프로젝트에서 직접 합성했습니다. 원작 선율이나 외부 녹음을 사용하지 않습니다. 곡은 16마디(약34~55초), 환경음은 32초의 스테레오 Ogg 루프입니다. [바이옴 오디오 명세](assets/audio/biomes/manifest.json)에 템포·음색·환경음 설명·PCM/Ogg 지문을 기록했습니다. 재생성 소스는 [자료 브랜치의 도구](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/tools/generate_biome_audio.py)에 있습니다.

울음소리는 [PokéAPI/cries](https://github.com/PokeAPI/cries)에서 가져왔습니다. [커밋·지문·변환 명세](assets/audio/cries/manifest.json), [원문](assets/audio/cries/UPSTREAM_README.md), [라이선스](assets/audio/cries/UPSTREAM_LICENSE)를 포함합니다. #025는 MP3 비트스트림을 Ogg로 변환했으며 나머지 385개는 원본을 유지합니다. 소리의 권리는 The Pokémon Company에 있습니다.

[Noto Sans KR](assets/fonts/NotoSansKR.ttf)의 [SIL Open Font License](assets/fonts/OFL.txt)를 포함합니다.


## 9세대까지 희귀 포켓몬 확장

일반 1~3세대 범위는 유지하고 희귀 기본 종 100종 + 가라르 전설의 새 3폼을 지원합니다. 기존 21종에 **82개 런타임 항목**을 추가해 전체 도감은 468개입니다. 울트라비스트와 일반 패러독스는 제외하며, 준전설 기반 패러독스 6종은 사용자 지정 준전설로 분류합니다.

- 추가 앞/뒤 도트 **164장**: [Smogon / Pokémon Showdown! sprites](https://github.com/smogon/sprites/tree/a9214714f00974a8c28586829e6315d9ca5a6348/src/sprites/gen5)의 고정 커밋 `a9214714f00974a8c28586829e6315d9ca5a6348`을 사용합니다. 무쇠감투(#1023) 앞/뒤 2장은 PokéAPI/sprites `0dc105d5b12416932f29b594078282ab4be045f5`를 사용합니다. PNG는 원본 바이트를 보존하며 GIF만 첫 프레임을 RGBA PNG로 추출합니다. 원본 URL·원본/결과 SHA·변환·크기는 [manifest](assets/sources/manifest.json)에 있습니다.
- 후대의 BW 스타일 도트는 커뮤니티 작가들의 작업입니다. 업스트림은 커뮤니티 도트의 라이선스가 확정되지 않았으며 사용 전 문의하도록 안내합니다. 이를 MIT/CC0 배포 허가로 해석하지 않습니다. [업스트림 고지 원문](assets/sources/SMOGON_SPRITES_LICENSE.txt)을 유지합니다. PMD 자료는 사용하지 않았습니다.
- 한국어 이름·타입·종족값·성장 곡선·새 희귀의 레벨업 기술은 [PokéAPI](https://github.com/PokeAPI/pokeapi/tree/81d20919845b6a445969b9265aab5cec6b04cece/data/v2/csv) `81d20919845b6a445969b9265aab5cec6b04cece`에서 가져왔습니다. 기존 386종 데이터는 유지하고 신규 항목은 지원되는 최신 버전 그룹의 레벨업 기술을 사용합니다. 상세 수집 기록/도구는 [고정 수집 자료](https://github.com/agree-git/pokemon-deckbuilder/tree/ce23503f74fe28d79a23813cb0b72b2331c6b421/tools/rare-gen9)에 보관합니다. 기술 카드는 게임의 전술 규칙에 맞춘 변환이며 원작의 모든 기술 특수 규칙을 재현하는 것은 아닙니다.
- 추가 울음소리 **82개**: [PokéAPI/cries](https://github.com/PokeAPI/cries) `b3a9044bb839b5e3152aaa536c7b463a0fcf0140`. [울음소리 manifest](assets/audio/cries/manifest.json)에 원본 URL·지문을 기록했습니다. 업스트림의 808/809 파일은 확장자가 `.ogg`지만 실제 MP3여서 Ogg Vorbis quality 6으로 변환했고 원본/결과 지문을 구분했습니다.
- 새 진화 재료의 표시는 PokéAPI의 `seal-case`/`rare-candy` 아이콘을 공용 상징으로 사용합니다. 악의족자 원작 도트라고 표시하지 않습니다. 멜탄의사탕은 혼자 진행하는 원정에 맞춘 진화 재료입니다.
- **최종 초전설 등장 연출 25종**은 프로젝트에서 직접 작성한 절차적 도트 도형입니다. DNA·무지개·거품·지진·파도·구름·시간·공간·그림자·불꽃·번개·얼음·수풀·세포·태양·달·웜홀·칼·방패·눈보라·지층·전송 격자·스텔라 결정을 표현하며 외부 이미지나 생성 이미지를 사용하지 않았습니다. 포켓몬은 원래 권리자의 캐릭터입니다.
