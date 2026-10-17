# 희귀 9세대 수집/재현 도구

실행 게임은 `main`을 사용한다. 이 브랜치의 게임 사본은 이전 자료다. Python 3 + Pillow + ffmpeg/ffprobe가 필요하다.

```bash
python3 fetch_csv.py --cache-dir /tmp/rare-cache
# Smogon/sprites 고정 커밋을 가진 로컬 Git 저장소를 사용한다.
python3 extend_data.py --project-dir /path/to/main-checkout --cache-dir /tmp/rare-cache --sprite-repo /path/to/smogon-sprites
python3 fetch_assets.py --project-dir /path/to/main-checkout --cache-dir /tmp/rare-cache --sprite-repo /path/to/smogon-sprites
python3 stories.py --project-dir /path/to/main-checkout
godot --headless --path /path/to/main-checkout --editor --import --quit
```

데이터/이미지/울음소리 pin은 각 도구와 manifest에 고정한다. `extend_data.py`는 일반 #001~386과 기존 기술 정의를 보존하고 추가 희귀 데이터를 재생성한다. CSV 수집 해시와 종별 기술 버전은 JSON에 기록했다. `sprite_paths.json`의 null 2개는 누락이 아니라 무쇠감투의 PokéAPI PNG 대체 경로다. GIF 첫 프레임 추출과 확장자만 OGG인 MP3 2개 변환을 명시한다. FFmpeg의 OGG 직렬 번호 때문에 재인코딩된 파일 바이트는 달라질 수 있다. 유효한 원본/결과 hash는 해당 실행에서 다시 기록한다.

데이터/에셋 도구는 런타임 파일을 쓴다. 일반 실행에는 필요하지 않으며, 의도적으로 자료를 재수집할 때만 사용한다. 원본 미술의 사용 고지는 `main/ASSET_SOURCES.md`를 따른다.
