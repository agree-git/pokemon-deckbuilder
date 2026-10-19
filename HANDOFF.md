# 현재 작업 인계

## 현재 상태

- 사용자는 엔딩 크레딧·새 릴리스를 요청했다. 제작자는 **DO**. 최신 지시는 **기존 명예의 전당·스크롤 화면 양식 유지, 첨부 YOUNG의 Another Red Credit.txt처럼 역할별 기여자 내용만 보완**이다. 문서형 상세 창/버튼/Name·Version·Website 화면은 제거했다.
- [크레딧 지도](docs/ending-credits.md),[릴리스 지도](docs/github-releases.md),[노트](docs/releases/v0.28.4.md). 원정v28/효과19/저장·RNG·승인파티·배경좌표/동결JSON 유지. 상태 원인 문구 추가 금지.
- 최종 게임 `83b32740e9988c3fbda39b20cc29b01f4fd1d614`, v0.28.4. 빌드 도구·검사 자료 `8e3a7a38b2df13a7a0c66591599a14aae1edf83c`. main 후속은 수동 workflow 기본값만 갱신한다.
- 전체 원정 클리어 시 화면별1회 자동 크레딧/결과 다시보기/시작 크레딧, 정지·스크롤·건너뛰기 지원. 실제 동료·성적과24역할/기여자 절. 전체3원문 고지는 외부 Credit.txt와 기존 출처 파일에 유지.
- 시험 태그v0.28.3은 미게시로 보존한다. v0.28.4 태그는 위 최종 게임 SHA에 고정한다. 중간 배치/사용자 보완 지시 전에 진행 중이던 import 빌드는 중단했으며 최종 산출물로 쓰지 않는다.

## 실제 검증·제작

- 공식4.7.2 실제 창 최종80검사/0실패·7클릭·4키. 기존 공개 행동으로69전 클리어한 v27 상태 복원. DO/기여자/문서뷰어 없음/기존 배치·폭/모달입력/정지·재생·끝·건너뛰기/결과·시작 재생/짧은원정·패배 제외/정확한 원정·RNG·저장 바이트 불변. 별도 배치 수정7/0. PNG 직접 확인. 전체69전투/919기술은 반복하지 않았다.
- 공식 에디터·템플릿 SHA512/격리 import/Windows EXE·PCK/검사용 export/아이콘6크기·PE 확인. **linux-pack31배포파일/15,188동일게임항목/시작화면/5,143실행검사/0실패**,격리프로필정리. [보고서](docs/reports/windows-v0.28.4-linux-pack.json).
- ZIP `builds/windows-v0.28.4-83b3274/PokemonExpedition-Windows-x86_64-83b3274.zip`,326,828,107바이트. SHA256 `9308beb17217312db14ab4b28e4d4a2783fdf199b149d224b3cd532e0c43d3d6`. 전체CRC/필수파일/DO·24절·원문3개/외부Credit.txt·JSON 바이트 일치/source_dirty=false/실제5도구파일Git blob 일치. [산출물](docs/reports/windows-v0.28.4-artifact.json).
- v0.28.4의 실제 Windows OS 실행·실물GPU/오디오/장시간 플레이는 미실행. 로컬 검사는 공식Linux template/동일PCK다. 새 Windows CI/게시 성공도 아직 미확인이다.

## 다음 한 단계

이번 반영에서 태그와 기본값을 준비한다. 사용자가 [Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml)에서 main/기본값으로 **새 Run workflow**를 실행한다. 기존 실행 Re-run은 쓰지 않는다. 환경의gh API는Forbidden/커넥터에dispatch·게시도구없음. 사용자가 실행하면 GET으로 실제결과와3첨부를확인한다.

이전403은 과거SHA/ref문제로 정확한소스태그+`--verify-tag`로수정했고 v0.28.2 [재실행39255797385](https://github.com/agree-git/pokemon-deckbuilder/actions/runs/39255797385)성공. 태그이동/덮어쓰기/자동trigger없음. 자료raw SHA push후에는fetch로추적참조를갱신한다.
