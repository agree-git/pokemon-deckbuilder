# 에셋 출처와 권리

사용 에셋의 출처와 필수 고지입니다. 원본 CSV·생성 도구·상세 제작 기록·미적용 후보는 [과거 자료의 고정 링크](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/history.md)에서 확인합니다.

## 포켓몬과 아이템

[PokéAPI/sprites](https://github.com/PokeAPI/sprites), 커밋 `0dc105d5b12416932f29b594078282ab4be045f5`의 386종 앞/뒤 PNG 772장과 아이템 그림을 사용합니다. 일부 아이템의 색/용도는 프로젝트에서 조정했습니다. [원본 URL·지문](assets/sources/manifest.json)과 [업스트림 고지](assets/sources/POKEAPI_SPRITES_LICENSE.txt)를 포함합니다. 이미지 권리는 The Pokémon Company에 있으며 저장소의 CC0 표기가 원작 이미지 권리를 이전하지 않습니다.

## 게임 데이터

[PokéAPI/pokeapi](https://github.com/PokeAPI/pokeapi), 커밋 `81d20919845b6a445969b9265aab5cec6b04cece`의 CSV를 바탕으로 이름·타입·능력치·기술·성장·진화 데이터를 생성했습니다. [데이터 라이선스](assets/sources/POKEAPI_DATA_LICENSE.txt)를 포함합니다. 파티 편성·카드·원정 규칙은 자체 작성입니다.

## 트레이너

[Smogon / Pokémon Showdown](https://github.com/smogon/sprites), 커밋 `a9214714f00974a8c28586829e6315d9ca5a6348`의 `src/_uncategorized/canonical/trainers/`에서 원작 도트 74장을 수정 없이 가져와 76대진에 대응합니다. 후대 인물 61대진에는 팬 도트 58장을 사용합니다. 총 **137대진/132 PNG**로 모든 보스 대진에 개별 외형이 연결돼 있습니다. [인물별 URL·SHA·경계](assets/sources/trainer_sprites.json), [출처 원문의 License 절](assets/sources/SMOGON_SPRITES_LICENSE.txt)을 포함합니다. 이미지 권리는 Nintendo / Game Freak / The Pokémon Company에 있으며 코드의 MIT 허가와 구분합니다.

팬 도트 제작자는 **Gnomowladny**, **Beliot419**, **Brumirage**, **kyledove**, **ZacWeavile**입니다. 칼로스·알로라 및 시트론 15장은 위 Smogon 고정 원본, 추가 33장은 공개 Showdown 스프라이트 컬렉션 [SDM0/sprites](https://github.com/SDM0/sprites/tree/b22cba4e3b7bcb95e0259747952d0ddf4f8cfd6f/sprites/trainers)의 고정 원본입니다. 파일명과 작가를 공식 Showdown 갤러리의 크레딧 목록에 대응했으며 이미지 호스트의 바이트까지 비교한 것은 아닙니다. [제작자별 고지](assets/sources/TRAINER_FAN_CREDITS.txt)와 각 파일의 명세에 출처를 기록합니다. 구체적인 트레이너 갤러리 안내는 외부 사용 시 제작자 표기·허락 없는 편집 금지를 요구합니다. 다운로드한 PNG를 수정 없이 사용하며 일반 저장소 고지와 함께 유지합니다.

시트론은 사용자가 제공한 [Gnomowladny의 원작 링크](https://www.deviantart.com/gnomowladny/art/Clemont-Sprite-430844892)를 제작자 근거로 기록합니다. 적용한 GitHub 보관본은 제공 이미지와 같은 포즈에 푸른 전기 효과가 있는 버전입니다. 원작 페이지는 이 환경에서 열리지 않아 별도 사용 허가를 확인했다고 주장하지 않으며, 원본 픽셀과 기존 고지를 보존합니다.

## 아이콘·배경·연출

시작 화면의 원정대 문양과 게임 아이콘(`assets/branding`)은 프로젝트에서 직접 그린 픽셀 도형입니다. 카드·나침반·포획 볼을 조합했으며 시작 화면의 글자는 아래 Noto Sans KR을 사용합니다. 재생성 소스는 [자료 브랜치의 도구](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/tools/generate_branding.py)에 있습니다. 포켓몬 상표와 포획 볼의 원작 권리는 원래 권리자에게 있습니다.

타입 배지는 [duiker101/pokemon-type-svg-icons](https://github.com/duiker101/pokemon-type-svg-icons), 커밋 `5781623f147f1bf850f426cfe1874ba56a9b75ee`를 바탕으로 합니다. [원 디자인](https://dribbble.com/shots/4862612-Pokedex-iOS-app), [업스트림 안내](assets/sources/type-icons/README.md.txt), [명세](assets/sources/type_icons.json)를 유지합니다. “Very simple set of SVG icons for Pokemon types for any use.”라는 안내가 있으며 별도 LICENSE는 없습니다.

바이옴/리그 배경은 프로젝트용으로 이미지 생성 도구에서 제작했습니다. [바이옴 지문](assets/biomes/manifest.json)·[리그 지문](assets/league/manifest.json)과 `data/battlefield_layouts.json` 좌표를 사용합니다. 그 밖의 UI 기호·카드 그림·공용 트레이너·기술/날씨 연출은 코드로 직접 작성했습니다. 보스 대사와 희귀 포켓몬의 조우·포획·합류·방출 문구는 자체 작성입니다.

## 오디오·글꼴

지역 BGM 35곡은 사용자가 `bgm_1.zip`~`bgm_4.zip`으로 제공한 MP3를 사용합니다. DP/HGSS/BW/XY/ORAS/SM과 불가사의던전 탐험대의 음악이며 원래 권리는 Pokémon/Nintendo/Creatures/GAME FREAK 및 해당 권리자에게 있습니다. 원본 음원을 자체 합성곡·MIT·CC0로 표시하지 않습니다. 사용자 지시에 따라 전체 길이를 보존한 스테레오 48kHz Ogg Vorbis(q5)로 변환하고 두 단계 loudnorm(-18LUFS, true peak -2dB)으로 음량을 정리했습니다. 타이틀은 ORAS 미로마을, 종료/예비 야영곡은 HGSS 태초마을이며 지역은 35곡 전체에서 선곡합니다. [파일별 출처·원본 MP3/ZIP SHA256·변환 Ogg SHA256·길이](assets/audio/region_music/manifest.json)를 포함합니다. 원본 ZIP/MP3는 중복으로 커밋하지 않습니다. [변환 도구](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/tools/import_region_music.py)는 사용자 첨부 파일만 읽으며 외부 음원을 다운로드하지 않습니다.

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

## Windows 실행 파일의 엔진 고지

Windows 시험 빌드는 공식 Godot **4.7.2** 엔진을 포함합니다. Godot은 MIT 라이선스이며, 배포 폴더의 `licenses/Godot-LICENSE.txt`와 `licenses/Godot-COPYRIGHT.txt`에 엔진 및 포함된 라이브러리 고지를 함께 보관합니다. 에셋·폰트의 고지는 이 문서와 `assets` 아래에 유지합니다.

## 추가 보스 음악·캐릭터

사용자 제공 `bgm1.zip`~`bgm8.zip`의39MP3에서 동일 녹음을 중복 제거한36곡을 사용합니다. 지역곡과 동일하게 전체 길이를 유지한48kHz 스테레오 Vorbis q5/두 단계 loudnorm으로 변환했습니다. [보스 음악 명세](assets/audio/boss_music/manifest.json)에8ZIP·39원본 파일·36Ogg의 SHA256과137역할별 매핑·별칭·지역 공용 대체3건을 기록합니다. 원곡의 권리는 원래 권리자에게 있으며 MIT/CC0로 표시하지 않습니다.

추가 트레이너 PNG11개는 원본 바이트를 보존합니다. 나누·하푸우·멀레인·쿠쿠이·하우는 SDM0 미러의 Beliot419 작품, 블루베리5인은 PokeRogue assets 미러의 kyledove 작품입니다. 레드는 Smogon 미러의 HGSS 원작 도트입니다. 기존 할라(Gnomowladny)·라이치(Beliot419)는 관장 역할에도 연결했습니다. [파일별 고정 출처/지문/작가/고지](assets/sources/trainer_sprites.json) 및 [크레딧](assets/sources/TRAINER_FAN_CREDITS.txt)을 포함합니다. PokeRogue 미러의 적용 가능한 CC BY-NC-SA4.0 고지와 [라이선스 원문](assets/sources/POKEROGUE_ASSETS_CC_BY_NC_SA_4.txt)을 유지하며 원작 Pokémon 권리는 별개입니다.

추가 배경12곳은 프로젝트용 이미지 생성 도구로 제작했고 [리그 지문](assets/league/manifest.json)에 기록했습니다. 보스13대진의 대사39문구와 전술은 자체 작성했으며 파티는 현재 일반1~3세대 도감에 맞춘 게임용 구성입니다.

## 전국도감·지역/상시폼 확장

전국도감1,025종과 지역/상시/무늬/코스튬 폼을 합친1,412항목을 지원합니다. 원본 데이터가 정의한 상시 폼을 대상으로 하며 메가진화·거다이맥스 등 전투 전용 변신, 이동 자세, 폐기된 불명 타입 아르세우스는 제외합니다. 기존468항목의 PNG/울음소리와 역사적 이름·타입·종족값 데이터는 보존했습니다.

추가 앞/뒤 PNG **1,888장**, 울음소리 **944개**, 진화 재료 PNG **37장**을 고정 출처에서 가져왔습니다. PNG는 원본 바이트를 유지하며, 울음소리의 일부가 잘못된 확장자의 MP3이면 실제 Vorbis로 변환하고 원본/변환 지문을 기록합니다. 도롱마담 계통에서 갈라진 나메일과 분이벌레/분떠도리의 문양 계통은 원래 같은 외형이므로 실제 기본 외형을 공유합니다. 폼별 울음소리가 같은 경우도 출처와 공유 ID를 기록하며 별도 합성음으로 바꾸지 않습니다.

- 이미지: [PokeAPI/sprites 고정 커밋](https://github.com/PokeAPI/sprites/tree/289e842364648ec0495ae4ba12f48d5cbfbf670b), `sprites/pokemon`, `sprites/pokemon/back`, `sprites/items`. 650번 이후는 Smogon 커뮤니티의 Gen5 스타일 도트를 포함합니다. [업스트림 README](assets/sources/POKEAPI_SPRITES_README.md.txt)·[출처/정비 안내](assets/sources/POKEAPI_SPRITES_CONTRIBUTING.md.txt)·기존 PokéAPI/Smogon 고지를 유지합니다.
- 울음소리: [PokeAPI/cries 고정 커밋](https://github.com/PokeAPI/cries/tree/b3a9044bb839b5e3152aaa536c7b463a0fcf0140), `cries/pokemon/latest`. [전체1,412항목의 파일/디코딩 지문](assets/audio/cries/manifest.json)을 기록합니다.
- 데이터: [PokeAPI/pokeapi 고정 커밋](https://github.com/PokeAPI/pokeapi/tree/5ee47a9a9c1229632ec4b473a9c1c53026e005dd/data/v2/csv)의26개 CSV. 한국어 이름·폼·타입·능력치·특성 정보·레벨업/가르침 습득 경로·919기술·644진화분기를 사용합니다. [확장 출처](assets/sources/pokedex_expansion.json)와 [실행 데이터](data/pokedex_expansion.json)에 입력 파일 SHA256과 종별 습득 버전을 기록합니다.

기술의 위력/보조 효과는 기존 카드 전투 규칙에 맞춘 표현이며 원작의 모든 전용 기믹을 그대로 재현한 시뮬레이터가 아닙니다. 특성은 도감 정보로 포함하며 별도 전투 특성 시스템을 추가하지 않습니다. 위치·통신·특수 조작 조건은 야영 준비로 명시적으로 대체하고 기본 레벨/시간/친밀도/기술 조건을 적용합니다. 원작의 캐릭터/음악 권리는 원래 권리자에게 있으며 데이터·코드 라이선스가 이를 대신하지 않습니다.

기술머신 호환표 [technical_machines.json](data/technical_machines.json)은 같은 고정 `pokemon_moves.csv`의 습득 방법4(기술머신)만 추출한 데이터입니다. 각 포켓몬은 확장 데이터에 기록된 습득 버전을 따르며 1,412항목/303개 기술을 포함합니다. 입력 SHA256·고정 URL을 파일에 기록했고, 교배/가르침 전용 기술은 기술머신으로 분류하지 않습니다. 버전별 번호가 다르므로 게임에서는 기술명으로 표시합니다.

새 원정 v5의 보스 파티는 사용자 제공 대표 포켓몬 엑셀과 승인된 원작 기반 검토안을 [boss_parties.json](data/boss_parties.json)에 반영했습니다. 각 역할의 기준 작품·전투·원작 파티·Pokémon Database/Serebii 출처 URL 및 원작 외 정원 보충을 구분하고, 승인 파티 SHA256과 입력 엑셀 SHA256을 기록합니다. 기존1~3세대 범위에 맞춰 작성했던 역사적 파티 파일은 v1~v4 원정 저장 호환에 보존합니다. 새 이미지·음원은 추가하지 않았으며 이미 포함된 전종/상시 폼 에셋을 사용합니다. 원작 레벨·기술·도구·특성 및 전용 기믹 전체를 그대로 이식한 것은 아닙니다.


## 보스 대표 기술 효과 v6

[boss_move_effects_v6.json](data/boss_move_effects_v6.json)은 [대표 기술·전술 명세](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/boss-ace-tactics.md)의 P0 적용본입니다. 기존 확장 데이터의 고정 PokeAPI `5ee47a9a9c1229632ec4b473a9c1c53026e005dd` 기술 위력/분류/능력 변화/상태/회복 정보를 카드 전투 규칙으로 변환했습니다. 19대표의 원작 참조는 [고정 출처 목록](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/boss-ace-references.json)에 작품/전투/기술 ID와 pret 고정 커밋·Serebii 출처를 기록했습니다. 효과 규칙·한국어 설명·고정 행동 순서는 자체 작성입니다. 새 그림/음원/특성 시스템은 추가하지 않았습니다.

## 보스 대표 기술 효과 v7

[boss_move_effects_v7.json](data/boss_move_effects_v7.json)은 같은 고정 PokeAPI 기술 메타와 검토 명세의41대표 적용본입니다. 원작 파티/기술 출처는 위 고정 목록을 유지합니다. 잠자기·잠꼬대/일렉트로빔/솔라빔의 충전 및 날씨 조건은 [Rest](https://pokemondb.net/move/rest), [Sleep Talk](https://pokemondb.net/move/sleep-talk), [Electro Shot](https://pokemondb.net/move/electro-shot), [Solar Beam](https://pokemondb.net/move/solar-beam)을 추가 확인했습니다(2026-10-18). 카드 전투용 고정 연타/연속기 횟수,공개된 잠꼬대 선택,그림자분신 보호막 대체,고정 턴 순서는 자체 각색이며 원작 전체 전투 규칙을 재현한 것은 아닙니다. v6 입력은 그대로 보존했고 새 이미지·음원은 추가하지 않았습니다.

## 보스 대표 기술 효과 v8

[boss_move_effects_v8.json](data/boss_move_effects_v8.json)은 같은 고정 PokeAPI/검토 명세의105대표/실전189기술 적용본입니다. 체중은 기존 고정 도감의 `weight_hg`,접촉/음성/중력 제한 플래그는 같은 PokeAPI 커밋의 [move_flag_map.csv](https://raw.githubusercontent.com/PokeAPI/pokeapi/5ee47a9a9c1229632ec4b473a9c1c53026e005dd/data/v2/csv/move_flag_map.csv)(SHA256 `399cf005933418f406b94729903bd1528e9088bddc3bc1966be6c442a625da1b`)를 별도 동결 입력으로 보관합니다. 카운터/대타출동/뿌리박기/킹실드/성스러운칼/바디프레스 등의 효과는 같은 고정 `move_effect_prose.csv`와 Pokémon Database의 [중력](https://pokemondb.net/move/gravity),[스텔스록](https://pokemondb.net/move/stealth-rock),[자이로볼](https://pokemondb.net/move/gyro-ball),[메탈버스트](https://pokemondb.net/move/metal-burst),[빛의장막](https://pokemondb.net/move/light-screen)에서 추가 대조했습니다(2026-10-18).

고정 턴 순서의 따라가때리기/보복·현재 출전자 반격·NPC 은혜갚기 친밀도255 기준·고정 구속4회 등은 카드 전투용 각색입니다. 설치/장막 해제,대타 HP,실제 접촉 페널티와 상태 배지는 자체 구현/설명입니다. 새 이미지·음원·특성/PP 시스템은 추가하지 않았고 기존 v6/v7 데이터와 엔진을 보존했습니다.


## 대표 기술 고유 효과와 원정 v9

`data/boss_move_effects_v9.json`은 검토한138대표/233기술의 카드 전투용 효과 입력입니다. v6/v7/v8 자료와 엔진은 보존합니다. 기술 효과의 기초 사실은 위 PokéAPI 고정 커밋의 `move_effect_prose.csv`(SHA256 `f6d9bf0d28433a010a8b8b6a0a14d1ef72fbfcb997717f71b0e34483b7ee9697`)와 `move_flag_map.csv`에서 대조했습니다. 빈 효과 번호의 보충 사실은 [들이받기](https://pokemondb.net/move/headlong-rush),[열불내기](https://pokemondb.net/move/temper-flare),[변덕레이저](https://pokemondb.net/move/fickle-beam),[대검돌격](https://bulbapedia.bulbagarden.net/wiki/Glaive_Rush_(move)),[거대해머](https://bulbapedia.bulbagarden.net/wiki/Gigaton_Hammer_(move)),[전광쌍격](https://bulbapedia.bulbagarden.net/wiki/Double_Shock_(move))에서 대조했습니다(2026-10-18). 설명 원문을 통째로 복제하지 않았습니다.

헤롱헤롱의 확정 피해 감소·섬뜩한주문의 카드 봉인·일격기의 공개 위력160·변덕레이저의 공개10회 주기·따라하기의 기본 공격 카드 효과 복사·전투 중 장비 무효/종료 복구는 자체 카드 전투 각색입니다. 타입 소모는 전투 문맥에만 기록하며 도감/폼을 바꾸지 않습니다. 기술별 예고와 자료 브랜치의 [적용 현황](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/boss-move-effects.md)에 원작과의 차이를 표시합니다. 플레이어919기술의 모든 고유 효과나 성별/명중/PP/특성/테라스탈 시스템을 추가한 것은 아닙니다.

## 플레이어 기술 카드 v10

`data/player_move_cards_v10.json`은 기존 전국도감의 한국어 기술·위력·대상·상태/단계 자료에 PokéAPI 고정 커밋 [`5ee47a9a9c1229632ec4b473a9c1c53026e005dd`](https://github.com/PokeAPI/pokeapi/tree/5ee47a9a9c1229632ec4b473a9c1c53026e005dd/data/v2/csv)의 `moves.csv`, `move_meta.csv`, `move_flag_map.csv`, `move_effect_prose.csv`를 대조해 만든 카드 전투용 정의입니다. 원본 CSV 지문은 JSON의 `source.csv_sha256`에 기록했습니다. 게임 실행에 원본 CSV나 네트워크가 필요하지 않습니다.

919기술 중311개의 연타·흡수·반동·충전·재충전·조건부 위력·보조 효과를 보완했습니다. 성별/확률/PP/특성 등은 카드 규칙으로 각색하거나 기존 단순 변환으로 남습니다. 새 이미지·음원은 추가하지 않았습니다. [규칙·적용 목록](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/player-move-cards.md), [결정적 생성 도구](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/tools/import_player_move_cards.py).

## 플레이어 기술 카드 v11

`data/player_move_tactics_v11.json`은 위 동결v10 JSON과 같은 PokéAPI 고정CSV4종을 대조한32카드 추가 정의입니다. 원본 지문과v10 기반 지문은 JSON에 기록했습니다. 설치·구속·행동 제한·교대 인계·HP 조정은 자체 카드 전투 각색이며 새 에셋은 추가하지 않았습니다. [적용/각색/남은 범위](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/player-move-tactics.md), [결정적 생성기](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/tools/import_player_move_tactics.py).

## 플레이어 기술 카드 v12

`data/player_move_exchange_v12.json`은 동결v10/v11 JSON과 같은 PokéAPI 고정CSV4종을 대조한30카드 추가 정의입니다. 기반/원본 SHA256은 JSON에 기록했습니다. 능력 단계/기본 능력치 교환·타입 변경·공격 복사는 자체 카드 전투 각색이며 새 이미지나 음원은 추가하지 않았습니다. [적용/각색/남은 범위](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/player-move-exchange.md), [결정적 생성기](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/tools/import_player_move_exchange.py).

## 플레이어 기술 카드 v13

`data/player_move_fields_v13.json`은 동결v10~v12 JSON과 같은 PokéAPI 고정CSV4종을 대조한20카드 추가 정의입니다. 기술 데이터의 양수 공격 우선도도 고정했습니다. 원본/기반 SHA256은 JSON에 기록했습니다. 공통 필드·룸·진영 교환/방어·흙놀이/물놀이는 카드 전투 각색이며 새 에셋은 없습니다. [적용/각색/남은 범위](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/player-move-fields.md), [결정적 생성기](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/tools/import_player_move_fields.py).

## 플레이어 기술 카드 v14

`data/player_move_seals_v14.json`은 동결v10~v13 정의와 같은 PokéAPI 고정CSV4종을 대조한3카드 추가 정의입니다. 기반/원본 SHA256은 JSON에 기록했습니다. 매직룸·주술·페어리록은 카드 전투 각색이며 새 에셋은 없습니다. [적용/각색/남은 범위](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/player-move-seals.md), [결정적 생성기](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/tools/import_player_move_seals.py).

## 플레이어 기술 카드 v15

`data/player_move_altitude_v15.json`은 동결v10~v14 정의와 같은 PokéAPI 고정CSV4종을 대조한3카드 추가 정의입니다. 기반/원본 SHA256은 JSON에 기록했습니다. 중력·전자부유·텔레키네시스는 카드 전투 각색이며 새 에셋은 없습니다. [적용/각색/남은 범위](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/player-move-altitude.md), [정의 생성기](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/tools/import_player_move_altitude.py), [접지 필드 파생기](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/tools/derive_player_air_fields.py).

## 플레이어 기술 카드 v16

`data/player_move_traps_v16.json`은 동결v10~v15 정의와 같은 PokéAPI 고정CSV4종을 대조한7카드 추가 정의입니다. 지속 구속·문어굳히기·배수의진은 카드 전투 각색이며 새 에셋은 없습니다. 기반/원본 SHA256은 JSON에 기록했습니다. [효과/각색](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/docs/player-move-traps.md), [결정적 생성기](https://github.com/agree-git/pokemon-deckbuilder/blob/development-materials/tools/import_player_move_traps.py).
