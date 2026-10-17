# 여기서부터 이어가기

## 읽는 순서

1. **이 문서**: 저장소 구조와 환경 준비를 확인합니다.
2. **[HANDOFF.md](HANDOFF.md)**: 현재 상태·마지막 작업·다음 후보를 확인합니다.
3. **[AGENTS.md](AGENTS.md)**: 에이전트 작업 지침을 확인합니다.
4. **[docs/rules.md](docs/rules.md)**: 변경할 시스템의 확정 규칙을 읽습니다.
5. **[docs/development.md](docs/development.md)**: 관련 코드와 실행할 검사를 찾습니다.

이전 대화나 오래된 갤러리를 전부 읽을 필요는 없습니다. 최신 사용자 지시가 문서보다 우선합니다. 과거 설계는 현재 규칙과 구분합니다.

## 브랜치 역할

- `main`: 실행할 게임 코드·씬·데이터·에셋·필수 출처 고지. **여기서 게임을 구현합니다.**
- `development-materials`: 이 문서·인계·현재 규칙·테스트·작은 도구. `project.godot`과 게임 사본이 없습니다.

새 환경에 필요한 것은 **Git, Godot 4.7.2, Python 3.10 이상**입니다. 기본 게임 실행에는 Python이나 네트워크가 필요하지 않습니다. 에셋과 데이터는 이미 게임에 포함돼 있습니다. 이전 클라우드의 `/workspace/...` 활성화 파일이나 실행 중인 디스플레이를 가정하지 않습니다.

## 기존 checkout에서 시작

먼저 저장소 루트에서 확인합니다.

```bash
git status --short
git branch --show-current
git log -5 --oneline
git fetch origin main development-materials:refs/remotes/origin/development-materials
git show origin/development-materials:HANDOFF.md
```

다른 작업자의 미커밋 변경이 있으면 보존합니다. 변경 중인 게임 checkout을 자료 확인 때문에 다른 브랜치로 바꾸지 않습니다. `reset --hard`, 강제 push, 불필요한 worktree를 사용하지 않습니다.

자료를 별도 폴더에 꺼내면 현재 게임 checkout과 함께 읽고 검사할 수 있습니다. 아래 `.dev-materials/`는 main에서 ignore됩니다.

```bash
mkdir -p .dev-materials
git archive origin/development-materials | tar -x -C .dev-materials
```

이 폴더는 자료 스냅샷입니다. 수정해도 자료 브랜치에 자동 반영되지 않으므로 결과는 해당 브랜치에 따로 커밋합니다. 계속 쓰던 자료 폴더에 로컬 수정이 있다면 새 빈 폴더로 추출해 덮어쓰지 않습니다.

```bash
godot --version
# 게임은 main의 project.godot을 Godot 4.7.2에서 열고 F5.
python3 .dev-materials/tools/check.py --game-dir . --suite smoke
```

Windows에서도 자료 ZIP을 별도 폴더에 풀거나 Git Bash의 위 명령을 사용할 수 있습니다. Python 실행 이름이 `python`인 환경에서는 명령만 바꿉니다. 실행 파일명이 다르면 검사기에 `--godot /path/to/godot`을 지정합니다.

## 저장소가 없는 환경

```bash
git clone --depth 1 --branch main https://github.com/agree-git/pokemon-deckbuilder.git
cd pokemon-deckbuilder
git fetch --depth 1 origin development-materials:refs/remotes/origin/development-materials
mkdir -p .dev-materials
git archive origin/development-materials | tar -x -C .dev-materials
```

얕은 clone은 과거의 큰 검토 산출물을 함께 받지 않습니다. 옛 자료가 실제로 필요하면 [고정 링크](docs/history.md)로 열거나 그때 필요한 커밋만 가져옵니다.

## 시작·종료 때 남길 것

시작할 때 실제 Git 상태와 사용자 요청을 확인하고 진행 중인 일이 있으면 잇습니다. 작업 뒤에는 **변경 내용·실제 검증·미완료·다음 한 단계**만 HANDOFF에 갱신합니다. 전체 채팅·긴 검사 로그·개인 저장 파일·머신 전용 경로를 인계 문서에 쌓지 않습니다.
