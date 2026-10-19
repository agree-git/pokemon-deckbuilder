# 현재 작업 인계

## 현재 상태

- 사용자가2026-10-19 새릴리스빌드를명시요청했다. **이번v0.28.2 제작/수동Windows CI·배포준비는승인됐다.** 이후버전은재요청받는다. [릴리스지도](docs/github-releases.md)부터읽는다.
- 빌드게임소스 `84d06746db6387d8de1e4b4ee81b3f29f5e46e30`. 버전0.28.2/Windows버전/누적CHANGELOG/PLAY_GUIDE갱신. main의별도커밋은수동워크플로기본값만갱신한다. 변경사항은[릴리스노트](docs/releases/v0.28.2.md).
- 튜토리얼/전종애니메이션/야영겹침·UI·연구폭/음악플레이어/기술동작/상태효과/진화단계수정포함. 상태원인문구는추가하지않는다. 원정v28/효과19/기존저장·승인파티·RNG·배경좌표/게시JSON은유지한다.

## 실제 제작·검증

- 공식4.7.2 SHA512확인,격리import/Windows EXE/PCK/별도검사용export완료. 아이콘6크기/PE버전0.28.2/외부PCK확인.
- **linux-pack29배포파일/15,184동일게임항목/시작화면/5,140실행검사/0실패**,격리프로필제거/깨끗한종료.2,824애니메이션뷰import·대표8뷰디코딩/새UI스크립트/카탈로그·음원·저장·설정포함. [보고서](docs/reports/windows-v0.28.2-linux-pack.json).
- ZIP `PokemonExpedition-Windows-x86_64-84d0674.zip` / 326,788,599바이트. SHA256 `552a54d0e21ee9b34beecc527a0cf92d879b3ad54d968495e58e92abf3f8f225`. `builds/windows-v0.28.2-84d0674`에있다. CRC/필수파일/최종SHA통과. [산출물정보](docs/reports/windows-v0.28.2-artifact.json)참조.
- 로컬빌드자료 `2e33c07ba5fbc1570fec50bb689e5a6f612e60bc`. 로컬추적참조가낡아최초build-info의자료SHA만달랐다. 실제5도구파일의해시와Git blob을대조해기록만정정/ZIP재생성. 검증한EXE/PCK불변. 다음자료push후에는fetch뒤SHA를확인한다.
- Windows실제OS실행·실물GPU/오디오/새장시간플레이는미실행. 전체919기술/69전투/기존전체UI·기능검사를반복하지않았다. 앞선실제창근거는[고정이전인계](https://github.com/agree-git/pokemon-deckbuilder/blob/94ea16325c99358b31d89d375f39ad905f0e5dac/HANDOFF.md)와작업별지도에있다.

## 남은 한 단계

`gh api`Forbidden/현재커넥터에dispatch·release게시도구없음. GET으로공개v0.28.0만확인. **v0.28.2 workflow/태그/Release는아직실행·생성·게시하지못했다.** 자동태그트리거등우회는없다.

사용자가[Windows release](https://github.com/agree-git/pokemon-deckbuilder/actions/workflows/windows-release.yml)에서main/기본값그대로Run workflow를실행하면실제Windows검사뒤게시한다. 실행됐다는회신이오면GET워크플로/릴리스조회로실제결과·3첨부파일을확인한다. 입력게임SHA는위값,자료SHA는main워크플로기본값의고정40자리다.
