#!/usr/bin/env bash
# 작업 폴더 루트에서 실행: 과제 원본 파일 목록·해시 기록, docs/ 양식 복사, .gitignore 준비, git 초기화. 기존 파일은 덮어쓰지 않는다.
# 사용: bash .agents/skills/fde-start/scripts/init-docs.sh
set -e

# 키트 폴더에서 실수로 실행하는 것을 막는다(여기서 돌리면 작업 폴더가 아니라 키트가 오염된다).
if [ -f ./INSTALL.md ] && [ -f ./BOOTSTRAP.md ] && [ -f ./LICENSE ]; then
  echo "여기는 키트 폴더입니다. 과제 작업 폴더로 이동해서 실행하세요." >&2
  exit 1
fi
TPL="$(cd "$(dirname "$0")/../assets/templates" && pwd)"
mkdir -p docs
# 과제 원본 보존(KR-122): 키트가 손대기 전 작업 폴더에 있던 파일을 기록한다. 이 파일들은 고치지 않는다(check-stage.sh가 확인).
# 키트 설치가 다루는 AGENTS.md·CLAUDE.md(마커 블록)·.gitignore(줄 추가)와 키트·git 폴더는 뺀다. 이미 기록이 있으면 다시 만들지 않는다.
ORIG=docs/TASK-ORIGINALS.sha256
if [ ! -f "$ORIG" ]; then
  if command -v sha256sum >/dev/null 2>&1; then H="sha256sum"; else H="shasum -a 256"; fi
  find . \( -path ./.git -o -path ./.agents -o -path ./.claude -o -path ./fde-kit -o -path ./node_modules -o -path ./submission \) -prune -o \
    -type f ! -path ./AGENTS.md ! -path ./CLAUDE.md ! -path ./.gitignore ! -path "./$ORIG" ! -path "./$ORIG.tmp" -print | LC_ALL=C sort | while IFS= read -r f; do $H "$f"; done > "$ORIG.tmp"
  mv "$ORIG.tmp" "$ORIG"
  echo "과제 원본 $(wc -l < "$ORIG" | tr -d ' ')개 기록: $ORIG — 이 파일들은 고치지 않는다. 제출할 내용은 submission/<같은 경로> 복사본에 쓴다."
fi
for f in STATE INTERVIEW AGREEMENT DECISIONS LOGIC VERIFY HANDOFF DEFENSE; do
  [ -f "docs/$f.md" ] || cp "$TPL/$f.md" "docs/$f.md"
done
touch .gitignore
for p in ".env" ".env.*" "node_modules/" "__pycache__/" ".venv/" "*.webm" "build/" "target/" ".gradle/"; do
  grep -qxF "$p" .gitignore || echo "$p" >> .gitignore
done
[ -d .git ] || git init -q
echo "docs/ 준비 완료: $(ls docs | tr '\n' ' ')"
