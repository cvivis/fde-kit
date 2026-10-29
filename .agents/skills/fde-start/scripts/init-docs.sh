#!/usr/bin/env bash
# 작업 폴더 루트에서 실행: docs/ 양식 복사, .gitignore 준비, git 초기화. 기존 파일은 덮어쓰지 않는다.
# 사용: bash .agents/skills/fde-start/scripts/init-docs.sh
set -e

# 키트 폴더에서 실수로 실행하는 것을 막는다(여기서 돌리면 작업 폴더가 아니라 키트가 오염된다).
if [ -f ./INSTALL.md ] && [ -f ./BOOTSTRAP.md ] && [ -f ./LICENSE ]; then
  echo "여기는 키트 폴더입니다. 과제 작업 폴더로 이동해서 실행하세요." >&2
  exit 1
fi
TPL="$(cd "$(dirname "$0")/../assets/templates" && pwd)"
mkdir -p docs
for f in STATE INTERVIEW AGREEMENT DECISIONS VERIFY HANDOFF DEFENSE; do
  [ -f "docs/$f.md" ] || cp "$TPL/$f.md" "docs/$f.md"
done
touch .gitignore
for p in ".env" ".env.*" "node_modules/" "__pycache__/" ".venv/" "*.webm" "build/" "target/" ".gradle/"; do
  grep -qxF "$p" .gitignore || echo "$p" >> .gitignore
done
[ -d .git ] || git init -q
echo "docs/ 준비 완료: $(ls docs | tr '\n' ' ')"
