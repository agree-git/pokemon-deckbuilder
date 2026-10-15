# 에셋 출처와 재사용

## 1~3세대 포켓몬 스프라이트

- 출처: [PokéAPI/sprites](https://github.com/PokeAPI/sprites), 커밋 `0dc105d5b12416932f29b594078282ab4be045f5`.
- 경로: `sprites/pokemon/{1..386}.png`, `sprites/pokemon/back/{1..386}.png`. 96×96 투명 PNG, 원본 픽셀을 변형하지 않고 포함한다. 앞·뒤 총 772장이다.
- 로컬 경로: `assets/pokemon/front/001.png` ~ `386.png`, `assets/pokemon/back/001.png` ~ `386.png`.
- [업스트림 라이선스](assets/sources/POKEAPI_SPRITES_LICENSE.txt)는 **이미지 저작권이 The Pokémon Company에 있음**을 명시한다. 저장소의 CC0 표기는 원작 포켓몬 이미지의 권리를 이전하지 않는다. 출처를 유지하고 외부 배포 시 권리 범위를 별도로 확인한다.

## 이름·타입·기술 데이터

- 출처: [PokéAPI/pokeapi](https://github.com/PokeAPI/pokeapi), 커밋 `81d20919845b6a445969b9265aab5cec6b04cece`, `data/v2/csv`.
- 원본 CSV와 [라이선스](assets/sources/POKEAPI_DATA_LICENSE.txt)를 `assets/sources/`에 보관했다.
- `data/catalog.json`은 1~3세대 원종 386종과 1세대 기술 165종을 추린 로컬 카탈로그다. 타입은 현대 분류와 복합타입을 유지하며 세대·지역·진화 전 종·아기·전설·환상 플래그를 기록한다. 지역폼·메가진화·별도 폼은 포함하지 않는다.
- `data/evolutions.json`은 같은 고정 커밋의 `pokemon_evolution.csv`에서 기본형의 조건 없는 레벨 진화 135개를 추렸다. 원본 CSV도 보관하며 돌·친밀도·통신·성별·랜덤·폼 등의 조건은 일반 레벨 진화로 포함하지 않는다. 전투 경험치 배율과 HP·공격 성장 수치는 이 게임이 작성했다.
- `data/progression.json`은 같은 고정 커밋의 6개 성장 곡선, 386종 성장 그룹, 354개 기술 메타데이터와 에메랄드 레벨별 기술표를 사용한다. 테오키스 원종은 루비·사파이어 기술표를 보완한다. 필터링한 `pokemon_moves_emerald.csv`의 해시와 전체 원본 해시를 모두 기록하며 `tools/build_progression.py`로 재생성한다. 배틀 효과·에너지·경험치 배율은 이 게임의 수치다.
- 기술의 VFX 프로필은 이 프로젝트가 작성한 표현용 매핑이다. 상태 확률·피해량·사용 가능 기술을 구현한 데이터가 아니다. 프리뷰에서는 어떤 포켓몬으로도 연출을 확인할 수 있다.
- 바이옴의 출현 등급과 가중치 8:3:1은 종별 상대 가중치 초안이다. 등급 전체의 출현 확률이나 실제 원작 서식 분포를 뜻하지 않는다. 전설·환상 21종은 일반 가중치 풀과 관장 편성에서 제외했다. 18개 타입 관장의 6마리 파티는 이 프로젝트가 작성한 편성이며 특정 원작 버전의 파티를 복제하지 않는다.

## 배경과 기술 이펙트

- 배경: 2026-10-15에 `image_gen`으로 생성한 2열×3행 도트 배경 아틀라스 3장. 18개 타입마다 별도 영역을 사용한다. 원작 게임 배경을 내려받은 에셋이 아니다.
- 생성 방향: 16비트 RPG 픽셀 아트, 동일한 전투 시점, 전경에 포켓몬이 설 공간, 글자·캐릭터·UI·구분선 제외. 원본 생성 파일은 `/workspace/generated_images`에 보존하고 프로젝트에는 복사본을 포함한다.
- `assets/biomes/atlas_1.png`: 불꽃 / 물 / 풀 / 노말 / 전기 / 얼음 순서.
- `assets/biomes/atlas_2.png`: 격투 / 독 / 땅 / 비행 / 에스퍼 / 벌레 순서.
- `assets/biomes/atlas_3.png`: 바위 / 고스트 / 드래곤 / 악 / 강철 / 페어리 순서.
- 모두 왼쪽 위부터 행 우선 순서다. `data/biomes.json`의 `background`, `cell`로 연결한다. `VisualCatalog.biome_texture()`가 `AtlasTexture`를 반환한다.
- 기술 연출은 외부 애니메이션을 복제하지 않고 `scripts/vfx/move_effect.gd`에 도형으로 작성했다. 이펙트 데이터, 씬 표현과 향후 전투 규칙을 분리했다.
- 그래픽 에셋은 도트 스타일로 사용하되 화면과 UI는 **1920×1080**에서 그린다. 전체 화면을 축소하는 SubViewport는 사용하지 않는다. 스프라이트의 최근접 필터·정수 배율을 유지하고 도형의 안티앨리어싱과 텍스처 흐림은 끈다.

## UI 아이콘

- `assets/ui/icons/*.svg`는 이 프로젝트가 직접 작성한 16×16 격자의 도트 아이콘 30종이다. 시작 화면·포획·회복·배지 기호를 포함하며 외부 아이콘 폰트나 인터넷 이미지에 의존하지 않는다.
- 에너지·공격·방어·타입·상태·드로우·교체·메뉴 등의 기호를 최근접 필터로 확대한다. 아이콘과 작은 수치를 함께 표시하고, 효과 설명은 툴팁·도움말로 제공한다.
- 트레이너 카드의 일러스트 6종은 `scripts/ui/trainer_card_art.gd`에서 직접 작성한 84×48 도트 장면을 2배로 그린다. 기존 UI 아이콘과 지도·방어물·서류·깃발·구급 상자 등의 도형을 조합하며 외부 일러스트나 원작 카드 이미지를 사용하지 않는다.
- 포켓몬 초상은 기존 스프라이트의 투명 여백을 런타임 `AtlasTexture`로 제외해 정수 배율로 표시한다. 원본 파일은 유지한다.

## 한국어 폰트

- [Google Fonts / Noto Sans KR](https://github.com/google/fonts/tree/main/ofl/notosanskr), 커밋 `e9678a5385322c63730122ba464765baad83cfd8`.
- `assets/fonts/NotoSansKR.ttf`와 [SIL Open Font License](assets/fonts/OFL.txt)를 포함한다.

## 재현

`python3 tools/import_pokemon_assets.py`로 고정 커밋에서 원본을 가져오고 `python3 tools/build_biomes.py`로 출현·관장 데이터와 목록 문서를 재생성한다. 이전 `import_kanto_assets.py`는 호환용 진입점으로 유지한다. 모든 다운로드는 HTTPS 검증을 유지하며, 파일별 URL과 SHA-256은 `assets/sources/manifest.json`에 기록한다. 동일한 파일은 재사용하며 실패한 다운로드가 있어도 완료된 파일을 재사용할 수 있다. 배경은 생성 에셋이므로 네트워크 임포터가 덮어쓰지 않는다.
