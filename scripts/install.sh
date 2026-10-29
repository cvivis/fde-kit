#!/usr/bin/env bash
# fde-kit 설치 — 작업 폴더에 스킬과 규칙 파일을 둔다.
#
# 사용:
#   bash /tmp/fde-kit/scripts/install.sh                   # Codex (기본)
#   bash /tmp/fde-kit/scripts/install.sh --target claude    # Claude Code
#   bash /tmp/fde-kit/scripts/install.sh --dest ~/workspace # 설치 위치 지정
#
# 규칙 파일은 타깃에 맞는 이름으로 **하나만** 둔다 (AGENTS.md 또는 CLAUDE.md).
# 둘을 같이 두면 어느 것이 읽히는지 불확실해진다.
# 스킬 탐색 경로 가정이 틀릴 수 있으므로 Codex에서는 후보 경로 2곳에 깐다(--no-alt로 끌 수 있음).
# .git 은 복사하지 않는다.
set -u

TARGET=codex
DEST=$PWD
ALT=1
DOCS=1

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --dest)   DEST="${2:-}";   shift 2 ;;
    --no-alt)  ALT=0;  shift ;;
    --no-docs) DOCS=0; shift ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "알 수 없는 옵션: $1  (--help 참고)" >&2; exit 2 ;;
  esac
done

SRC=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd) || { echo "키트 경로를 찾지 못했습니다" >&2; exit 1; }
[ -d "$SRC/.agents/skills" ] || { echo "스킬 폴더가 없습니다: $SRC/.agents/skills" >&2; exit 1; }
mkdir -p "$DEST" 2>/dev/null || true
DEST=$(cd "$DEST" 2>/dev/null && pwd) || { echo "설치 위치를 찾지 못했습니다: $DEST" >&2; exit 1; }
[ "$SRC" = "$DEST" ] && { echo "설치 위치가 키트 자신입니다. --dest 로 작업 폴더를 지정하세요." >&2; exit 1; }

case "$TARGET" in
  codex)  RULES=AGENTS.md; OTHER=CLAUDE.md; DIRS=".agents/skills" ;;
  claude) RULES=CLAUDE.md; OTHER=AGENTS.md; DIRS=".claude/skills" ;;
  *) echo "--target 은 codex 또는 claude 입니다 (받은 값: $TARGET)" >&2; exit 2 ;;
esac
[ "$TARGET" = codex ] && [ "$ALT" = 1 ] && DIRS="$DIRS .codex/skills"

echo "fde-kit → $DEST   (타깃: $TARGET)"

# 1) 스킬
COUNT=0
for d in $DIRS; do
  if mkdir -p "$DEST/$d" 2>/dev/null && cp -R "$SRC/.agents/skills/." "$DEST/$d/" 2>/dev/null; then
    echo "  [스킬] $d"
    COUNT=$((COUNT + 1))
  else
    echo "  [실패] $d (건너뜀)"
  fi
done
[ "$COUNT" = 0 ] && { echo "스킬을 어디에도 복사하지 못했습니다. BOOTSTRAP.md(B안)로 전환하세요." >&2; exit 1; }

# 2) 규칙 파일 (기존 파일이 있으면 덧붙인다)
if [ -f "$DEST/$RULES" ]; then
  printf '\n' >> "$DEST/$RULES"
  cat "$SRC/AGENTS.md" >> "$DEST/$RULES"
  echo "  [규칙] $RULES (기존 파일에 덧붙임)"
else
  cp "$SRC/AGENTS.md" "$DEST/$RULES"
  echo "  [규칙] $RULES (새로 생성)"
fi
[ -f "$DEST/$OTHER" ] && echo "  [주의] $OTHER 도 있습니다. 규칙 파일은 하나만 두세요."

# 3) 사람이 읽는 문서 (있는 것만)
if [ "$DOCS" = 1 ]; then
  for f in CARD.md INCIDENTS.md PROMPTS.md; do
    [ -f "$SRC/$f" ] && cp "$SRC/$f" "$DEST/$f" && echo "  [문서] $f"
  done
fi

# 4) 보고 — 인식되어야 하는 스킬 이름
echo
echo "스킬 $(ls "$SRC/.agents/skills" | wc -l | tr -d ' ')종 (에이전트에서 이 이름으로 보여야 한다):"
for s in "$SRC"/.agents/skills/*/SKILL.md; do
  n=$(sed -n 's/^name: *//p' "$s" | head -1)
  echo "  \$${n:-$(basename "$(dirname "$s")")}"
done

echo
echo "다음: 에이전트를 실행하고 \$ 를 눌러 위 목록이 뜨는지 확인한다."
echo "      뜨지 않으면 INSTALL.md 의 분기표(B안/C안)를 따른다."
