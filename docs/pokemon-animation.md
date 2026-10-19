# 포켓몬 Gen5 스타일 애니메이션

기술을 쓸 때의 돌진·몸통 신축·기울기와 복귀 동작은 별도 [기술 사용 모션](combat-motion.md)이다. 원본 프레임 자료를 수정할 필요 없이 그쪽 코드만 읽는다.

사용자 범위는 **포켓몬만**이다. 기준 디렉터리는 [Showdown gen5ani](https://play.pokemonshowdown.com/sprites/gen5ani/). 사용자는 정지 이미지/3D/숨쉬기 모션 대체 대신 DeviantArt를 포함해 실제 Gen5 스타일 프레임 자료를 더 찾도록 지시했다. 완료 결과는 **1,412항목 × 앞·뒤 =2,824뷰,실제 서로 다른 프레임,누락/대체0**이다. 트레이너·배경·기존 정적 PNG·게시 JSON은 유지한다. **새 버전/EXE/export/Windows CI/Release 보류**도 계속 적용된다.

## 최소 코드 지도

- main `scripts/content/pokemon_animation.gd`:뷰 매핑/불변 아틀라스 로드. 원본/확장 도감과 저장 fingerprint에는 관여하지 않는다. 실제 화면 참조 외 강한 텍스처 캐시32MiB,살아 있는 텍스처는 weakref로 재사용한다.
- `scripts/ui/pokemon_animation_player.gd`:Sprite2D/TextureRect의 개별 프레임 시계. 기존 바인딩을 새로 고침해도 재생을 리셋하지 않고,숨긴 포켓몬은 갱신을 멈춘다. 게임 RNG·배속·전투 상태에는 손대지 않는다.
- `BattleCanvas.set_species`:아군 back/적 front를 연결. 프레임 전체의 고정 bounds로 줌/발 기준/HUD 배치를 계산한다. 변신/교대/앞뒤 전환도 같은 경로다.
- `CombatWidgets.sprite`:기존 최대 영역 안에 nearest 확대/축소하고 같은 애니메이션 드라이버를 연결. 전투/파티/카드/야영/연구·도감/시작·튜토리얼의 포켓몬 초상에 공통 적용한다.
- `assets/pokemon/animated/manifest.json`:2,824개뷰/2,734개고유 PNG. 프레임/시간/종·폼 매핑과 입력 URL·고정 커밋·입출력 SHA256·가공 방법·제작자 고지를 기록한다. 이 파일은 시각 자료이며 JourneySave.CONTENT에 넣지 않는다.

## 찾은 원본과 매핑 계약

| 실제 사용 원본 | 표시 뷰 | 고정 리비전 |
|---|---:|---|
| Smogon `src/sprites/gen5/*.gif` (`gen5ani`의 원본 계열) |1,451|`a9214714f00974a8c28586829e6315d9ca5a6348`|
| PokéRogue `images/pokemon`/`exp`/`back` 2D 시트 |988|`009cac30c39d3615c7b2c320c3984af368871031`|
| EBDX 커뮤니티 `Graphics/Pokemon/Front`/`Back` 2D 스트립 |385|`4bd3abfe4185af0561f01d6dcd448bc1d02e0f8d`|

[커뮤니티 배포 안내](https://www.eeveeexpo.com/resources/1831/)와 [Animated Pokémon System](https://eeveeexpo.com/resources/1544/),[DeviantArt Terapagos 원작 예시](https://www.deviantart.com/retronc/art/Terapagos-Sprite-977394866),[Ghasty001 원작/허용·기반작가 명단](https://github.com/Ghasty001/Animated_sprites_by_Ghasty001)을 찾아 원본 배포본을 대조했다. 이 환경에서 Showdown/DeviantArt HTML의 직접 다운로드는403이므로 접근 제한을 우회하지 않고 공개 고정 GitHub 원본·배포본에서 확보했다. 3D `models`와 단일 프레임 PNG를 애니메이션으로 세지 않았다. PMD 자료도 조사했지만 최종 적용에는 사용하지 않았다.

프레임 색/실루엣은 그대로 보존한다. GIF 합성/시트 trim·회전을 복원하고 전체 프레임의 알파 합집합으로 균일하게 잘라 중복 이미지 픽셀만 묶는다. GIF 시간 유지,명시 시간이 없는 시트/스트립은12fps다. 원본 아틀라스의 잘못된 순서는 파일명 순으로 정렬했다. 외부 형식/인덱스에서 폼을 추측해 다시 만들지 말고 검토된 manifest를 재현 입력으로 쓴다.

특히 피카츄14개 의상/모자,마휘핑63종의 크림·장식,비비용 문양,지역폼을 구분한다. EBDX 피카츄는 `2=옷갈아입기,3=마담,4=마스크드,5=닥터,6=아이돌,7=하드록,8~15=캡`이며17은거다이맥스다. 이름/서로 다른 자료의 숫자 인덱스를 그대로 대입하면 안 된다. 호바귀/펌킨인 `0=작은,1=보통,2=큰,3=특대`는 각기 별도 시트다. 알로라 주인 텅구리는 `MAROWAK_1`이며 관동 텅구리와 공유하지 않는다. 서로 실제 전투 외형이 같은 유대변화 특성 개굴닌자/나메일의 출신 계열/분이벌레·분떠도리/밖에서 보이지 않는 인증표/주인의 같은 몸체는 공유를 명시한다.

main `ASSET_SOURCES.md`와 `assets/sources/ANIMATED_POKEMON_EBDX_CREDITS.txt`,`POKEROGUE_ANIMATION_*`,`POKEROGUE_IMAGES_ANIMATION_REUSE.toml.txt`,기존 Smogon/CC 고지를 함께 유지한다. 가져온 것은 포켓몬 그림이며 다른 게임의 코드/음원/UI는 아니다.

## 필요한 한 묶음 검증

- `python .dev-materials/tools/pokemon_animations.py --game-dir .`:2,824뷰,고유2,734PNG의 입력 연결/해시/PNG구조/좌표/시간/고유프레임/잉여파일0 검증 통과.
- `tests/native_pokemon_animation.gd`:Godot4.7.2,실제X11 1920×1080,**최종84검사/0실패**. 실제 전투의 프레임 재생/아군뒤·적앞/고정 발·HUD/새로고침 때 재생 유지/숨김 정지,실제 저장 바이트/전체 snapshot/UID·RNG와복원 동일. 표본48종/폼은 실제 디코딩 픽셀이 달라지는 것도 확인했다.
-48개초상영역 fitting,피카츄/알로라텅구리/호바귀 매핑,큰포켓몬/시각적교대3쌍/HUD상단/캐시32MiB 확인. PNG4장 중 전투와 폼 갤러리를 직접 시각 확인했다. 이 갤러리는 검사 전용이며 제품 UI에 추가하지 않았다.
- 초기 검사 스크립트의 Godot 내장 클래스 이름 충돌과 노드 이름 치환 오류를 고친 뒤 같은 범위만 다시 실행했다. 최종로그 SCRIPT ERROR/ERROR/누수없음. 소프트웨어X11의VSync경고1개는 기존 드라이버 안내다.
- 증거 `/tmp/pokemon-animation-review/{01-battle,02-battle-later,03-forms-and-latest,04-forms-later}.png`,로그 `/tmp/pokemon-animation-native.log`. 개인 저장은 해당 폴더의 격리 XDG 아래다. 전체919/69전투/전체기존창/빌드/패키지 검사는 반복하지 않았다.

아틀라스를 다시 만들 필요가 있을 때만 `python .dev-materials/tools/pokemon_animations.py --game-dir . --cache-dir /tmp/<외부캐시> --rebuild`를 쓴다. Pillow12.3.0이 필요하며 입력·결과 SHA256이 같아야 한다. 원본 캐시/검색 HTML/다른 게임 checkout/긴 로그/스크린샷은 커밋하지 않는다. 다음 사용자가 배포를 요청하면 누적 수정과 새 PNG가 공식 import/패키지 입력에 포함되는지 확인하며,지금은 export나Windows CI를 실행하지 않는다.
