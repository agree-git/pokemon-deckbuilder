# 희귀 9세대 · 등장 연출 검토

촬영 코드 [81ca3ff](https://github.com/agree-git/pokemon-deckbuilder/commit/81ca3ff9be3cd5d754626250a00a536780efde9b) · 최종 게임 [main `2674ac9`](https://github.com/agree-git/pokemon-deckbuilder/commit/2674ac9a2912efd762fe7a3860c2f1e6c61d979a). **실제 1920×1080 화면 65장**입니다. 개발 검토용 전체 목록에는 희귀 포켓몬의 정체가 나옵니다. 촬영 후 변경은 무쇠감투 PNG의 원본 바이트 보존이며 RGBA 픽셀은 일치합니다.

- [전체 103종 CSV](rare_roster.csv) · [단서 463개 CSV](clues.csv) · [촬영 정보](manifest.json) · [독립 HTML 갤러리](index.html)
- [전체 화면 ZIP](rare-gen9-review-2026-10-17.zip) (다운로드 후 HTML을 열면 오프라인으로 볼 수 있습니다.)
- 일반 포켓몬은 1~3세대, 희귀는 1~9세대 기본 종 100 + 가라르 새 3폼. 일반 울트라비스트·패러독스 제외, 준전설 기반 패러독스 6종 포함.
- 준전설 53 · 환상 23 · 초전설 계열 27 (최종 25 + 코스모그·코스모움). 모두 포획 HP **10% 이하**. 단서/배지는 3/5/7개, 볼은 3/3/5개, 에너지는 2/2/3을 유지합니다.
- 코라이돈: 태고의 지층·거꾸로 흐르는 붉은 흙먼지. 미라이돈: 보라/청록 격자·입자 전송.

![25종 등장 효과](effects-contact.jpg)

## 발견 전 표시

![희귀 조사](screenshots/1025-hidden.png)
![도감 물음표](screenshots/collection-hidden.png)

조사·예약·지도·준비·이동은 정체를 숨깁니다. 도감에서 미발견 희귀의 실루엣·타입·번호와 검색 이름도 숨깁니다. 현재 원정에서 조우했거나 포획한 희귀는 표시합니다. 포획 도감은 포획 기록만 영구 보관하며 미포획 조우 이력을 새 영구 수집 시스템으로 추가하지는 않았습니다.

## 초전설 25종

예고는 progress 0.40, 등장은 0.67의 정지 프레임입니다. 효과는 1.0에서 정리되고 포켓몬과 조작이 완전히 드러납니다. 화면을 누르면 원본 크기로 볼 수 있습니다.

### 뮤츠

[예고](screenshots/150-anticipation.png) · [등장](screenshots/150-reveal.png)

![뮤츠](screenshots/150-reveal.png)

### 루기아

[예고](screenshots/249-anticipation.png) · [등장](screenshots/249-reveal.png)

![루기아](screenshots/249-reveal.png)

### 칠색조

[예고](screenshots/250-anticipation.png) · [등장](screenshots/250-reveal.png)

![칠색조](screenshots/250-reveal.png)

### 가이오가

[예고](screenshots/382-anticipation.png) · [등장](screenshots/382-reveal.png)

![가이오가](screenshots/382-reveal.png)

### 그란돈

[예고](screenshots/383-anticipation.png) · [등장](screenshots/383-reveal.png)

![그란돈](screenshots/383-reveal.png)

### 레쿠쟈

[예고](screenshots/384-anticipation.png) · [등장](screenshots/384-reveal.png)

![레쿠쟈](screenshots/384-reveal.png)

### 디아루가

[예고](screenshots/483-anticipation.png) · [등장](screenshots/483-reveal.png)

![디아루가](screenshots/483-reveal.png)

### 펄기아

[예고](screenshots/484-anticipation.png) · [등장](screenshots/484-reveal.png)

![펄기아](screenshots/484-reveal.png)

### 기라티나

[예고](screenshots/487-anticipation.png) · [등장](screenshots/487-reveal.png)

![기라티나](screenshots/487-reveal.png)

### 레시라무

[예고](screenshots/643-anticipation.png) · [등장](screenshots/643-reveal.png)

![레시라무](screenshots/643-reveal.png)

### 제크로무

[예고](screenshots/644-anticipation.png) · [등장](screenshots/644-reveal.png)

![제크로무](screenshots/644-reveal.png)

### 큐레무

[예고](screenshots/646-anticipation.png) · [등장](screenshots/646-reveal.png)

![큐레무](screenshots/646-reveal.png)

### 제르네아스

[예고](screenshots/716-anticipation.png) · [등장](screenshots/716-reveal.png)

![제르네아스](screenshots/716-reveal.png)

### 이벨타르

[예고](screenshots/717-anticipation.png) · [등장](screenshots/717-reveal.png)

![이벨타르](screenshots/717-reveal.png)

### 지가르데

[예고](screenshots/718-anticipation.png) · [등장](screenshots/718-reveal.png)

![지가르데](screenshots/718-reveal.png)

### 솔가레오

[예고](screenshots/791-anticipation.png) · [등장](screenshots/791-reveal.png)

![솔가레오](screenshots/791-reveal.png)

### 루나아라

[예고](screenshots/792-anticipation.png) · [등장](screenshots/792-reveal.png)

![루나아라](screenshots/792-reveal.png)

### 네크로즈마

[예고](screenshots/800-anticipation.png) · [등장](screenshots/800-reveal.png)

![네크로즈마](screenshots/800-reveal.png)

### 자시안

[예고](screenshots/888-anticipation.png) · [등장](screenshots/888-reveal.png)

![자시안](screenshots/888-reveal.png)

### 자마젠타

[예고](screenshots/889-anticipation.png) · [등장](screenshots/889-reveal.png)

![자마젠타](screenshots/889-reveal.png)

### 무한다이노

[예고](screenshots/890-anticipation.png) · [등장](screenshots/890-reveal.png)

![무한다이노](screenshots/890-reveal.png)

### 버드렉스

[예고](screenshots/898-anticipation.png) · [등장](screenshots/898-reveal.png)

![버드렉스](screenshots/898-reveal.png)

### 코라이돈

[예고](screenshots/1007-anticipation.png) · [등장](screenshots/1007-reveal.png)

![코라이돈](screenshots/1007-reveal.png)

### 미라이돈

[예고](screenshots/1008-anticipation.png) · [등장](screenshots/1008-reveal.png)

![미라이돈](screenshots/1008-reveal.png)

### 테라파고스

[예고](screenshots/1024-anticipation.png) · [등장](screenshots/1024-reveal.png)

![테라파고스](screenshots/1024-reveal.png)

## 확인한 범위

Linux/Godot **4.7.2** import 오류 0. 콘텐츠 보존/지문 3,293개, 신규 범위·103종 포획/스타팅/저장 5,660개, 희귀 전 과정 대표 20종/시드 추첨 5,886개, 종별 이야기/UI 3,593개 + 코스모그/코스모움 변경 85개, 기존 저장 1,759개, 역사 fingerprint/추첨 호환 93개, 초전설 계열 문턱 전 과정 5,112개, 도감 숨김 210개, 희귀 진화 56개, 울음소리 실제 디코딩 103개를 통과했습니다. 최종 실제 X11은 223개 검사·OS 클릭 26회, 65 PNG 촬영 실패 0개입니다. 배경 위치 JSON은 사용자 보정 hash를 유지합니다.

중간 원정 경계 검체에서 조사·포획을 검사한 결과입니다. 새 콘텐츠로 전체 69전투를 사람이나 자동 정책이 완주했다는 뜻은 아닙니다. 25종 모두 실제 렌더링과 상태/난수 무변경·정리를 검사했고, 3종은 실제 입력과 자연 재생을 검사했습니다. 전체 모음과 대표 원본을 육안 확인했습니다. Windows 실행과 사람 밸런스 평가는 별도 미완료입니다.

## 추가된 도트

코스모그·코스모움도 조사/배지 7개가 필요하므로 초전설 조건을 진화로 우회할 수 없습니다.

기존 21종 외 82개 항목의 앞/뒤 스프라이트와 울음소리를 연결했습니다. 아래는 새 앞모습 모음입니다.

![추가 82종/폼](new-sprites-contact.png)

원본/변환 고지는 [main/ASSET_SOURCES.md](https://github.com/agree-git/pokemon-deckbuilder/blob/main/ASSET_SOURCES.md)를 따릅니다.
