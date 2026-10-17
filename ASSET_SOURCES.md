# 에셋 출처와 권리

사용 에셋의 출처와 필수 고지입니다. 원본 CSV·생성 도구·상세 제작 기록·미적용 후보는 [development-materials](https://github.com/agree-git/pokemon-deckbuilder/tree/development-materials)에 보관합니다.

## 포켓몬과 아이템

[PokéAPI/sprites](https://github.com/PokeAPI/sprites), 커밋 `0dc105d5b12416932f29b594078282ab4be045f5`의 386종 앞/뒤 PNG 772장과 아이템 그림을 사용합니다. 일부 아이템의 색/용도는 프로젝트에서 조정했습니다. [원본 URL·지문](assets/sources/manifest.json)과 [업스트림 고지](assets/sources/POKEAPI_SPRITES_LICENSE.txt)를 포함합니다. 이미지 권리는 The Pokémon Company에 있으며 저장소의 CC0 표기가 원작 이미지 권리를 이전하지 않습니다.

## 게임 데이터

[PokéAPI/pokeapi](https://github.com/PokeAPI/pokeapi), 커밋 `81d20919845b6a445969b9265aab5cec6b04cece`의 CSV를 바탕으로 이름·타입·능력치·기술·성장·진화 데이터를 생성했습니다. [데이터 라이선스](assets/sources/POKEAPI_DATA_LICENSE.txt)를 포함합니다. 파티 편성·카드·원정 규칙은 자체 작성입니다.

## 트레이너

[Smogon / Pokémon Showdown](https://github.com/smogon/sprites), 커밋 `a9214714f00974a8c28586829e6315d9ca5a6348`의 `src/_uncategorized/canonical/trainers/`에서 원작 도트 73장을 수정 없이 가져와 75대진에 대응합니다. 후대 인물 48대진에는 제작자 목록과 대응한 팬 도트 47장을 사용합니다. 총 123대진/120 PNG이며 시트론 1대진은 제작자 확인까지 자체 공용 도트를 사용합니다. [인물별 URL·SHA·경계](assets/sources/trainer_sprites.json), [출처 원문의 License 절](assets/sources/SMOGON_SPRITES_LICENSE.txt)을 포함합니다. 이미지 권리는 Nintendo / Game Freak / The Pokémon Company에 있으며 코드의 MIT 허가와 구분합니다.

팬 도트 제작자는 **Gnomowladny**, **Beliot419**, **Brumirage**, **kyledove**, **ZacWeavile**입니다. 칼로스·알로라 14장은 위 Smogon 고정 원본, 추가 33장은 공개 Showdown 스프라이트 컬렉션 [SDM0/sprites](https://github.com/SDM0/sprites/tree/b22cba4e3b7bcb95e0259747952d0ddf4f8cfd6f/sprites/trainers)의 고정 원본입니다. 파일명과 작가를 공식 Showdown 갤러리의 크레딧 목록에 대응했으며 이미지 호스트의 바이트까지 비교한 것은 아닙니다. [제작자별 고지](assets/sources/TRAINER_FAN_CREDITS.txt)와 각 파일의 명세에 출처를 기록합니다. 구체적인 트레이너 갤러리 안내는 외부 사용 시 제작자 표기·허락 없는 편집 금지를 요구합니다. 다운로드한 PNG를 수정 없이 사용하며 일반 저장소 고지와 함께 유지합니다.

## 아이콘·배경·연출

타입 배지는 [duiker101/pokemon-type-svg-icons](https://github.com/duiker101/pokemon-type-svg-icons), 커밋 `5781623f147f1bf850f426cfe1874ba56a9b75ee`를 바탕으로 합니다. [원 디자인](https://dribbble.com/shots/4862612-Pokedex-iOS-app), [업스트림 안내](assets/sources/type-icons/README.md.txt), [명세](assets/sources/type_icons.json)를 유지합니다. “Very simple set of SVG icons for Pokemon types for any use.”라는 안내가 있으며 별도 LICENSE는 없습니다.

바이옴/리그 배경은 프로젝트용으로 이미지 생성 도구에서 제작했습니다. [바이옴 지문](assets/biomes/manifest.json)·[리그 지문](assets/league/manifest.json)과 `data/battlefield_layouts.json` 좌표를 사용합니다. 그 밖의 UI 기호·카드 그림·공용 트레이너·기술/날씨 연출은 코드로 직접 작성했습니다. 보스 대사는 자체 작성입니다.

## 오디오·글꼴

장면별 음악 5곡과 효과음 15종은 프로젝트에서 합성했습니다. [음악 명세](assets/audio/music/manifest.json)를 포함합니다.

울음소리는 [PokéAPI/cries](https://github.com/PokeAPI/cries)에서 가져왔습니다. [커밋·지문·변환 명세](assets/audio/cries/manifest.json), [원문](assets/audio/cries/UPSTREAM_README.md), [라이선스](assets/audio/cries/UPSTREAM_LICENSE)를 포함합니다. #025는 MP3 비트스트림을 Ogg로 변환했으며 나머지 385개는 원본을 유지합니다. 소리의 권리는 The Pokémon Company에 있습니다.

[Noto Sans KR](assets/fonts/NotoSansKR.ttf)의 [SIL Open Font License](assets/fonts/OFL.txt)를 포함합니다.
