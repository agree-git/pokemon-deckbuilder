# 플레이어 기술 카드 보완 · 원정 v10

현재 새 원정v12는 능력·타입 교환과 공격 복사를 더해 누적371기술이다. [최신 범위/각색/남은 항목](player-move-exchange.md)을 먼저 확인한다. 아래 내용과 목록은 게시 당시 범위다.

v11은 이 규칙을 유지하며32카드를 추가 보완한 누적342기술을 사용한다. [v11 적용/각색/남은 범위](player-move-tactics.md)를 먼저 확인한다. 이 문서의311개 목록은 동결v10 범위다.

사용자 기준은 **원작과 수치가 달라도 기술의 특징을 잘 살리는 것**이다. 새 원정 v10은 플레이어 기술919개 가운데311개의 특징을 보완한다. 나머지는 기본 위력·타입·상태/단계·회복 등의 기존 단순 변환을 사용한다. 보스는 v9의138대표/233기술을 유지한다. 전체919기술의 원작 고유 효과 완성을 의미하지 않는다.

## 주요 적용

| 분야 | 새 카드 규칙 |
|---|---|
| 연타30기술 | 개별 타격/보호막·대타 판정, 기절 시 중단. 가변2~5회는3회, 트리플킥/트리플악셀은1·2·3배 타격, 집단구타는 살아 있는 동료 수, 찍찍베기는10회. 부가효과는 카드당1회 |
| 흡수11·반동11기술 | 보호막/대타/과잉 피해를 뺀 실제 상대 HP 감소를 기준으로 회복하거나 자기 HP 소비. 1/3은 정확한1/3로 계산. 기존 회복 감소 유물도 반영 |
| 충전16·재충전10기술 | 충전 카드를 손패에 보존하고 다음 아군턴부터 비용0 발사. 교대/카드 제거 시 취소. 솔라빔/솔라블레이드는 쾌청, 일렉트로빔은 비에서 즉시 공격. 파괴광선 계열은 다음 아군턴 종료까지 그 동료의 기술을 잠금 |
| 조건부 위력40기술 | HP·무게·스피드·상태·친밀도·능력 단계·장비·직전 피해 등을 실제 현재 상태로 계산. 바디프레스는 방어, 속임수는 상대 공격 사용. 고정 피해는 타입 무효를 유지 |
| 보호·대타·장막 | 방어11기술은 한 동료당 턴1회. 버티기는 직접 공격에 HP1, 접촉 반격도 실제 처리. 대타는 HP¼ 소비, 같은 HP 풀로 타격/부가효과 방어, 파괴 타격 잔여 피해 없음. 음성/대타 관통은 예외 |
| 회복·수면·연계 | 잠자기와 잠꼬대, 다음 턴 소원, 출전 중 아쿠아링/뿌리박기, 비축하기–꿀꺽/토해내기. 흑안개/클리어스모그·상태 회복도 별도 처리 |
| 봉인·고유 효과 | 하품의 지연 수면, 길동무의 직접 공격자 동반 기절, 지옥찌르기 음성 봉인, 섬뜩한주문 직전 기술 봉인, 타르샷 불꽃 약화, 전광쌍격 전기 소모, 대검돌격 취약, 거대해머 연속 사용 제한 |
| 설명·저장 | 카드 본문 최대5행, 전체 규칙은 툴팁, 전투 상태 배지. 충전·재충전·소원·대타·봉인 등 선택 상태를 UID 기반으로 저장/검증 |

분야 수는 중복된다. 전체 보완 기술은 아래311개다.

## 명시적 각색과 제한

- 행동은 기존 아군 카드턴→상대 행동 순서다. 우선도 공격은 비용1 감소·소진, 풀죽음/명중 약화는 이번 상대 행동 공격 피해20% 감소로 치환하며 중첩하지 않는다. 실제 명중률/성별/PP/새 특성 시스템을 추가하지 않는다.
- 일반 부가상태와 단계 변화는 표시된 효과를 확정 적용한다. 냉동은 수면1회로 각색한다. 높은 급소율은 피해15% 증가, 확정 급소는1.5배와 불리한 단계 무시로 구분한다.
- 반격류/보복·눈사태/기습은 현재 상대가 직전 상대턴에 준 마지막 실제 HP 피해를 참조한다. 반격은 물리, 미러코트는 특수, 메탈버스트/앙갚음은 양쪽을 받는다. 보호막·대타 피해는 기록하지 않는다.
- 충전 카드의 보존은 자동으로 계속된다. 공중/잠복/수중/모습 감추기 회피는 첫 준비 상대 행동에만 적용한다. 준비가 끝난 카드를 손에 계속 들고 있어도 영구 회피는 생기지 않는다. 준비 중 같은 동료의 다른 기술은 사용할 수 없으며, 교대하면 취소된다.
- 유턴/볼트체인지/퀵턴은 그 턴 수동 교대를 무료로 만든다. 교대 선택을 강요하지 않고 상대 구속/자기 뿌리는 우회하지 않는다. 필수 교체·고스트 탈출 규칙은 유지한다.
- 빛의장막/리플렉터/신비의부적은 즉시 적용한 뒤 다음5아군턴까지 유지한다. 전투 단위 상태와 소모 타입은 도감/영구 폼을 바꾸지 않는다.
- 잠꼬대는 배운 기술 순서에서 첫 사용 가능한 공격을 호출한다. 별도 기술 카드/난수 추첨은 없다. 소원은 시전자 자신에게 회복하며 대기 중에도 도달한다.
- 일격기는 위력160 강공격으로 각색하고 더 높은 레벨이나 타입 무효에는 실패한다. 트럼프카드는 PP 대신 손패 수, 변덕레이저는 공개10회 주기의3/6/10번째 강공격이다.
- 헤롱헤롱은 성별/확률 대신 시전자에게 받는 공격 피해를2상대턴 동안 절반으로 만들고 시전자 교대/기절로 끝난다. 섬뜩한주문은 PP 감소 대신 마지막 기술3상대턴 봉인이다.
- 도둑질/탁쳐서떨구기는 상대 장비를 무효화하지만 현재 NPC의 별도 지닌 물건 배치는 추가하지 않았다. 방어·회복 관련 원정 유물은 기존 규칙을 적용한다.

## 남아 있는 단순 변환

특성 교환/억제, PP 조작, 변신·광범위 기술 복사/추첨, 트릭룸의 실제 턴 순서 변경, 일부 앵콜/분노가루/설치·교체 기술, 전투 전용 폼/테라스탈 등은 본가의 고유 효과까지 구현하지 않았다. 해당 카드에 표시한 기본 위력·상태·능력 단계·보호막 등의 효과만 사용한다. 기술별 기본 정의는 `data/player_move_cards_v10.json`의 `moves`, 이번 보완 목록은 `enhanced`가 기준이다. 향후 특징 확장은 새 버전으로 분리한다.

## 호환성과 출처

- 원정 v1~v9는 `TacticalMoves`/플레이어 효과1을 유지한다. v10만 `PlayerMoveCards`/`PlayerMoveRules`와 `player_moves_version:2`를 선택한다. 진행 중인 이전 저장에 새 규칙을 소급하지 않는다.
- 보스 v6/v7/v8/v9 입력과 엔진, 승인137대진 파티/대표, 도감/기술머신/에셋/배경 좌표를 바꾸지 않는다. 같은 시드의 경로 RNG와 보스69전투 정의는 v9와 동일하다. 상인 가격 산식도 기존 정의를 유지한다.
- `move_context`는 선택 저장 필드다. 소유 UID/카드 UID/단계/턴/상한과 원정 버전의 일치를 검사한다. 이전 실제 v9 지문 `f823671d51317f3d0352a807005558ef2c9e4accc868fdc17b91c25d619e2d43`을 명시 수용한다.
- PokéAPI `5ee47a9a9c1229632ec4b473a9c1c53026e005dd`의 기존 전국도감과 고정 CSV4종을 대조했다. `tools/import_player_move_cards.py`가 입력 SHA256을 검사하고 결정적으로 생성한다. 원본 CSV/캐시·저장·긴 로그는 Git에 넣지 않는다.

생성 JSON SHA256: `cb17b795f6e3ee8309a1f8151846bbc0a79a06cf1127d01739539e276aaf1255`.

## 보완311기술 목록

번호는 원작 기술 ID다. 분류는 JSON의 기계 판독용 태그이며 각 기술의 한국어 설명은 게임 카드/툴팁을 따른다.

| ID | 기술 | 보완 분류 |
|---|---|---|
| 2 | 태권당수 | high_crit |
| 3 | 연속뺨치기 | multi_hit |
| 4 | 연속펀치 | multi_hit |
| 12 | 가위자르기 | ohko |
| 13 | 칼바람 | charge, high_crit |
| 19 | 공중날기 | charge |
| 23 | 짓밟기 | flinch |
| 24 | 두번차기 | multi_hit |
| 26 | 점프킥 | crash |
| 27 | 돌려차기 | flinch |
| 28 | 모래뿌리기 | accuracy |
| 29 | 박치기 | flinch |
| 31 | 마구찌르기 | multi_hit |
| 32 | 뿔드릴 | ohko |
| 36 | 돌진 | recoil |
| 38 | 이판사판태클 | recoil |
| 41 | 더블니들 | multi_hit |
| 42 | 바늘미사일 | multi_hit |
| 44 | 물기 | flinch |
| 49 | 소닉붐 | twenty |
| 63 | 파괴광선 | recharge |
| 66 | 지옥의바퀴 | recoil |
| 67 | 안다리걸기 | variable |
| 68 | 카운터 | counter |
| 69 | 지구던지기 | level |
| 71 | 흡수 | drain |
| 72 | 메가드레인 | drain |
| 75 | 잎날가르기 | high_crit |
| 76 | 솔라빔 | charge |
| 82 | 용의분노 | forty |
| 90 | 땅가르기 | ohko |
| 91 | 구멍파기 | charge |
| 98 | 전광석화 | priority |
| 101 | 나이트헤드 | level |
| 105 | HP회복 | healing |
| 108 | 연막 | accuracy |
| 113 | 빛의장막 | screen |
| 114 | 흑안개 | haze |
| 115 | 리플렉터 | reflect |
| 116 | 기충전 | focus_energy |
| 117 | 참기 | priority |
| 120 | 자폭 | self_ko |
| 125 | 뼈다귀치기 | flinch |
| 127 | 폭포오르기 | flinch |
| 130 | 로켓박치기 | charge |
| 131 | 가시대포 | multi_hit |
| 134 | 숟가락휘기 | accuracy |
| 135 | 알낳기 | healing |
| 136 | 무릎차기 | crash |
| 138 | 꿈먹기 | drain, dream |
| 140 | 구슬던지기 | multi_hit |
| 141 | 흡혈 | drain |
| 143 | 불새 | charge, flinch, high_crit |
| 148 | 플래시 | accuracy |
| 149 | 사이코웨이브 | psywave |
| 152 | 집게해머 | high_crit |
| 153 | 대폭발 | self_ko |
| 154 | 마구할퀴기 | multi_hit |
| 155 | 뼈다귀부메랑 | multi_hit |
| 156 | 잠자기 | rest |
| 157 | 스톤샤워 | flinch |
| 158 | 필살앞니 | flinch |
| 162 | 분노의앞니 | half |
| 163 | 베어가르기 | high_crit |
| 164 | 대타출동 | substitute |
| 165 | 발버둥 | self_cost |
| 167 | 트리플킥 | multi_hit |
| 168 | 도둑질 | thief |
| 173 | 코골기 | flinch |
| 174 | 저주 | curse |
| 175 | 바둥바둥 | variable |
| 177 | 에어로블라스트 | high_crit |
| 179 | 기사회생 | variable |
| 182 | 방어 | guard |
| 183 | 마하펀치 | priority |
| 187 | 배북 | belly |
| 189 | 진흙뿌리기 | accuracy |
| 190 | 대포무노포 | accuracy |
| 194 | 길동무 | destiny |
| 197 | 판별 | guard |
| 198 | 본러시 | multi_hit |
| 202 | 기가드레인 | drain |
| 203 | 버티기 | guard |
| 205 | 구르기 | chain |
| 208 | 우유마시기 | healing |
| 210 | 연속자르기 | chain |
| 213 | 헤롱헤롱 | attract |
| 214 | 잠꼬대 | sleep_talk |
| 215 | 치료방울 | party_cure |
| 216 | 은혜갚기 | variable |
| 218 | 화풀이 | variable |
| 219 | 신비의부적 | safeguard |
| 222 | 매그니튜드 | variable |
| 234 | 아침햇살 | healing |
| 235 | 광합성 | healing |
| 236 | 달빛 | healing |
| 238 | 크로스촙 | high_crit |
| 239 | 회오리 | flinch |
| 243 | 미러코트 | mirror_coat |
| 245 | 신속 | priority |
| 251 | 집단구타 | multi_hit |
| 252 | 속이기 | fake_out, flinch, priority |
| 254 | 비축하기 | stockpile |
| 255 | 토해내기 | spit_up |
| 256 | 꿀꺽 | healing, swallow |
| 262 | 추억의선물 | self_ko |
| 263 | 객기 | variable |
| 264 | 힘껏펀치 | variable |
| 273 | 희망사항 | wish |
| 275 | 뿌리박기 | root |
| 276 | 엄청난힘 | self_cost |
| 281 | 하품 | yawn |
| 282 | 탁쳐서떨구기 | knock |
| 283 | 죽기살기 | variable |
| 284 | 분화 | variable |
| 287 | 리프레시 | refresh |
| 291 | 다이빙 | charge |
| 292 | 손바닥치기 | multi_hit |
| 299 | 블레이즈킥 | high_crit |
| 301 | 아이스볼 | chain |
| 302 | 바늘팔 | flinch |
| 303 | 게으름피우기 | healing |
| 307 | 블라스트번 | recharge |
| 308 | 하이드로캐논 | recharge |
| 310 | 놀래키기 | flinch |
| 311 | 웨더볼 | variable |
| 312 | 아로마테라피 | party_cure |
| 314 | 에어커터 | high_crit |
| 315 | 오버히트 | self_cost |
| 323 | 해수스파우팅 | variable |
| 326 | 신통력 | flinch |
| 329 | 절대영도 | ohko |
| 330 | 탁류 | accuracy |
| 331 | 씨기관총 | multi_hit |
| 333 | 고드름침 | multi_hit |
| 338 | 하드플랜트 | recharge |
| 340 | 뛰어오르기 | charge |
| 342 | 포이즌테일 | high_crit |
| 344 | 볼트태클 | recoil |
| 348 | 리프블레이드 | high_crit |
| 350 | 록블라스트 | multi_hit |
| 354 | 사이코부스트 | self_cost |
| 355 | 날개쉬기 | healing |
| 359 | 암해머 | self_cost |
| 360 | 자이로볼 | variable |
| 362 | 소금물 | variable |
| 364 | 페인트 | priority |
| 368 | 메탈버스트 | metal_burst |
| 369 | 유턴 | pivot |
| 370 | 인파이트 | self_cost |
| 371 | 보복 | variable |
| 372 | 승부굳히기 | variable |
| 376 | 마지막수단 | variable |
| 378 | 쥐어짜기 | variable |
| 386 | 혼내기 | variable |
| 389 | 기습 | priority, sucker |
| 392 | 아쿠아링 | ring |
| 394 | 플레어드라이브 | recoil |
| 399 | 악의파동 | flinch |
| 400 | 깜짝베기 | high_crit |
| 403 | 에어슬래시 | flinch |
| 407 | 드래곤다이브 | flinch |
| 409 | 드레인펀치 | drain |
| 410 | 진공파 | priority |
| 413 | 브레이브버드 | recoil |
| 416 | 기가임팩트 | recharge |
| 418 | 불릿펀치 | priority |
| 419 | 눈사태 | variable |
| 420 | 얼음뭉치 | priority |
| 421 | 섀도클로 | high_crit |
| 422 | 번개엄니 | flinch |
| 423 | 얼음엄니 | flinch |
| 424 | 불꽃엄니 | flinch |
| 425 | 야습 | priority |
| 426 | 진흙폭탄 | accuracy |
| 427 | 사이코커터 | high_crit |
| 428 | 사념의박치기 | flinch |
| 429 | 미러샷 | accuracy |
| 432 | 안개제거 | defog |
| 434 | 용성군 | self_cost |
| 437 | 리프스톰 | self_cost |
| 439 | 암석포 | recharge |
| 440 | 크로스포이즌 | high_crit |
| 442 | 아이언헤드 | flinch |
| 444 | 스톤에지 | high_crit |
| 447 | 풀묶기 | variable |
| 452 | 우드해머 | recoil |
| 453 | 아쿠아제트 | priority |
| 454 | 공격지령 | high_crit |
| 456 | 회복지령 | healing |
| 457 | 양날박치기 | recoil |
| 458 | 더블어택 | multi_hit |
| 459 | 시간의포효 | recharge |
| 460 | 공간절단 | high_crit |
| 462 | 묵사발 | variable |
| 467 | 섀도다이브 | charge |
| 469 | 와이드가드 | guard |
| 480 | 업어후리기 | critical |
| 484 | 헤비봄버 | variable |
| 486 | 일렉트릭볼 | variable |
| 492 | 속임수 | variable |
| 497 | 에코보이스 | chain |
| 498 | 야금야금 | ignore_defense |
| 499 | 클리어스모그 | clear_stages |
| 500 | 어시스트파워 | variable |
| 501 | 패스트가드 | guard |
| 505 | 치유파동 | healing |
| 506 | 병상첨병 | variable |
| 512 | 애크러뱃 | variable |
| 514 | 원수갚기 | variable |
| 515 | 목숨걸기 | final_gambit, self_ko |
| 521 | 볼트체인지 | pivot |
| 524 | 얼음숨결 | critical |
| 528 | 와일드볼트 | recoil |
| 529 | 드릴라이너 | high_crit |
| 530 | 더블촙 | multi_hit |
| 531 | 하트스탬프 | flinch |
| 532 | 우드혼 | drain |
| 533 | 성스러운칼 | ignore_defense |
| 535 | 히트스탬프 | variable |
| 536 | 그래스믹서 | accuracy |
| 537 | 하드롤러 | flinch |
| 539 | 나이트버스트 | accuracy |
| 541 | 스위프뺨치기 | multi_hit |
| 543 | 아프로브레이크 | recoil |
| 544 | 기어소서 | multi_hit |
| 553 | 프리즈볼트 | charge |
| 554 | 콜드플레어 | charge |
| 556 | 고드름떨구기 | flinch |
| 557 | V제너레이트 | self_cost |
| 566 | 고스트다이브 | charge |
| 570 | 파라볼라차지 | drain |
| 577 | 드레인키스 | drain |
| 578 | 트릭가드 | guard |
| 588 | 킹실드 | guard |
| 594 | 물수리검 | multi_hit, priority |
| 596 | 니들가드 | guard |
| 601 | 지오컨트롤 | charge |
| 613 | 데스윙 | drain |
| 617 | 파멸의빛 | recoil |
| 620 | 화룡점정 | self_cost |
| 621 | 이차원러시 | self_cost |
| 659 | 모래모으기 | healing |
| 660 | 만나자마자 | priority |
| 661 | 토치카 | guard |
| 663 | DD래리어트 | ignore_defense |
| 665 | 아이스해머 | self_cost |
| 666 | 플라워힐 | healing |
| 669 | 솔라블레이드 | charge |
| 675 | 지옥찌르기 | silence |
| 681 | 기어오르기 | variable |
| 685 | 정화 | healing, purify |
| 690 | 부리캐논 | beak |
| 705 | 플뢰르캐논 | self_cost |
| 709 | 액셀록 | priority |
| 711 | 프리즘레이저 | recharge |
| 716 | 찌리리따끔따끔 | flinch |
| 717 | 자연의분노 | half |
| 719 | 1000만볼트 | high_crit |
| 720 | 깜짝헤드 | self_cost |
| 722 | 포톤가이저 | variable |
| 729 | 파찌파찌액셀 | priority |
| 731 | 둥실둥실폴 | flinch |
| 733 | 생생버블 | drain |
| 742 | 더블펀처 | flinch, multi_hit |
| 745 | 노려맞히기 | high_crit |
| 749 | 타르샷 | tar |
| 751 | 드래곤애로 | multi_hit |
| 775 | 소울비트 | self_cost |
| 776 | 바디프레스 | variable |
| 791 | 생명의물방울 | healing |
| 792 | 블로킹 | guard |
| 794 | 스타어설트 | recharge |
| 795 | 무한다이빔 | recharge |
| 796 | 철제광선 | self_cost |
| 799 | 스케일샷 | multi_hit |
| 800 | 메테오빔 | charge |
| 801 | 셸암즈 | variable |
| 807 | 질투의불꽃 | variable |
| 812 | 퀵턴 | pivot |
| 813 | 트리플악셀 | multi_hit |
| 814 | 더블윙 | multi_hit |
| 816 | 정글힐 | healing |
| 817 | 암흑강타 | critical |
| 818 | 수류연타 | critical, multi_hit |
| 820 | 드래곤에너지 | variable |
| 822 | 타오르는분노 | flinch |
| 826 | 섬뜩한주문 | seal |
| 838 | 들이받기 | self_cost |
| 850 | 브레이브차지 | refresh |
| 851 | 테라버스트 | tera_blast |
| 857 | 제트펀치 | priority |
| 860 | 찍찍베기 | multi_hit |
| 862 | 대검돌격 | glaive |
| 870 | 트릭플라워 | critical |
| 874 | 골드러시 | self_cost |
| 876 | 하이드로스팀 | hydro_steam |
| 877 | 카타스트로피 | half |
| 889 | 분노의주먹 | variable |
| 890 | 아머캐논 | self_cost |
| 892 | 전광쌍격 | double_shock |
| 893 | 거대해머 | hammer |
| 894 | 앙갚음 | metal_burst |
| 905 | 일렉트로빔 | charge |
| 907 | 변덕레이저 | variable |
| 908 | 화염의수호 | guard |
| 909 | 질풍신뢰 | priority |
| 911 | 타키온커터 | multi_hit |
| 912 | 하드프레스 | variable |
| 915 | 열불내기 | variable |
| 918 | 기선제압 | priority |
