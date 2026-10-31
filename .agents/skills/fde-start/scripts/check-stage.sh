#!/usr/bin/env bash
# 단계 진입 점검: 앞 단계 산출물의 빈 칸을 결정론으로 찾는다. 문서 규칙("비어 있으면 멈춘다")을 코드로 한 번 더 건다.
# 사용(작업 폴더 루트): bash .agents/skills/fde-start/scripts/check-stage.sh S3|S4|S6
#   S3: 한 줄 명세, STATE 목표 한 줄, 성공 기준 1개 이상
#       (경고만, 종료 코드에 영향 없음) INTERVIEW 요구 체크리스트 빈 칸 — S2가 [기본]을 가정으로 채웠어야 한다
#       (경고만) 성공 기준이 5개를 넘으면 — KR-046, 늘릴 땐 다음 사이클·교체 중 하나를 사람에게 물었어야 한다
#   S4: S3 + 성공 기준마다 확인 방법, 작업 목록 항목마다 완료 조건, 모든 성공 기준 번호가 작업 목록에 연결,
#       DECISIONS 의도 칸이 빈 줄로 남은 결정 없음(KR-048 — "empty — 이유"는 통과, 완전히 빈 줄만 막는다)
#   S6: S4 + git log에 [S4] 커밋이 있어야 함(KR-049 — 구현 전에 검증을 시작하지 않는다)
# 종료 코드: 0 통과 / 1 빈 칸 있음(출력된 칸을 사람에게 보여 주고 멈춘다) / 2 사용법 오류
set -u

STAGE="${1:-}"
case "$STAGE" in S3|S4|S6) ;; *) echo "사용: check-stage.sh S3|S4|S6" >&2; exit 2 ;; esac

A=docs/AGREEMENT.md
S=docs/STATE.md
for f in "$A" "$S"; do
  [ -f "$f" ] || { echo "없음: $f — S0(init-docs.sh)부터" >&2; exit 2; }
done

FAIL=0
miss() { echo "빈 칸: $1"; FAIL=1; }

# "## 제목"으로 시작하는 절의 본문(다음 "## "까지). HTML 주석 줄은 뺀다.
section() {
  awk -v t="## $2" '
    index($0, t) == 1 { on = 1; next }
    on && /^## / { exit }
    on && !/^[[:space:]]*<!--/ { print }
  ' "$1"
}
trim() { sed -e 's/<!--.*-->//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

# 1) 한 줄 명세: 양식 문구([누가] …)가 남아 있지 않은 내용 줄
spec="$(section "$A" "한 줄 명세" | trim | grep -v '^$' | head -1)"
if [ -z "$spec" ] || printf '%s' "$spec" | grep -q '\[누가\]'; then
  miss "AGREEMENT 한 줄 명세 — 목적을 문장으로 못 쓰면 설계를 시작하지 않는다"
fi

# 2) STATE 목표 한 줄
goal="$(grep -m1 '^- 목표 한 줄:' "$S" | sed 's/^- 목표 한 줄://' | trim)"
[ -n "$goal" ] || miss "STATE 기준판 목표 한 줄"

# 3) 성공 기준 표: "| # | 기준 | 확인 방법 |" 행 중 기준이 찬 것
rows="$(section "$A" "성공 기준" | awk -F'|' '
  /^\|/ && $0 !~ /^\|[-[:space:]|]+$/ {
    n=$2; c=$3; m=$4
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", n); gsub(/^[[:space:]]+|[[:space:]]+$/, "", c); gsub(/^[[:space:]]+|[[:space:]]+$/, "", m)
    if (n == "#" || c == "") next
    print n "\t" m
  }')"
if [ -z "$rows" ]; then
  miss "AGREEMENT 성공 기준 — 1개 이상 필요"
fi

# (경고만) 성공 기준 개수가 상한(5)을 넘음 — KR-046. 합의 뒤 추가 요구로 불어났을 수 있다
if [ "$STAGE" = S3 ] && [ -n "$rows" ]; then
  n_rows="$(printf '%s\n' "$rows" | grep -c .)"
  [ "$n_rows" -gt 5 ] && echo "경고(멈추지 않음): 성공 기준 ${n_rows}개(상한 5) — 추가 요구를 다음 사이클로 미뤘는지, 기존 기준과 교체했는지 사람에게 확인"
fi

# (경고만) INTERVIEW 요구 체크리스트 빈 칸: "- P4 … [기본: …]: " 뒤가 비어 있는 줄. 시간 때문에 넘어올 수 있으므로 멈추지 않는다
I=docs/INTERVIEW.md
if [ "$STAGE" = S3 ] && [ -f "$I" ]; then
  blank="$(section "$I" "요구 체크리스트" | grep -E "^- [A-Z][0-9]+ .*\]:[[:space:]]*$" | sed -E "s/^- ([A-Z][0-9]+) .*/\1/" | tr "\n" " ")"
  [ -n "$blank" ] && echo "경고(멈추지 않음): 요구 체크리스트 빈 칸 — ${blank}→ [기본] 값을 가정으로 채워 AGREEMENT 가정에 적는다"
fi

if { [ "$STAGE" = S4 ] || [ "$STAGE" = S6 ]; } && [ -n "$rows" ]; then
  tasks="$(section "$S" "작업 목록" | grep -E '^- \[[ x]\] .*[^[:space:]]')"
  # 4) 성공 기준마다 확인 방법, 그리고 작업 목록에 번호가 연결됐는지(빠짐없이)
  while IFS="$(printf '\t')" read -r n m; do
    [ -n "$m" ] || miss "AGREEMENT 성공 기준 #$n 확인 방법 (S3에서 채운다)"
    printf '%s\n' "$tasks" | grep -qE "#$n([^0-9]|$)" || miss "작업 목록에 성공 기준 #$n 연결 항목 없음"
  done <<EOF
$rows
EOF
  # 5) 작업 목록 항목마다 완료 조건
  if [ -z "$tasks" ]; then
    miss "STATE 작업 목록"
  else
    printf '%s\n' "$tasks" | grep -v '완료 조건:' | while IFS= read -r t; do
      echo "빈 칸: 작업 항목 완료 조건 — $t"
    done | grep . && FAIL=1
  fi
fi

# 6) DECISIONS 의도 칸이 완전히 빈 줄인 결정이 있는가 — KR-048. "empty — 이유"는 내용이 있으므로 통과시킨다.
D=docs/DECISIONS.md
if { [ "$STAGE" = S4 ] || [ "$STAGE" = S6 ]; } && [ -f "$D" ]; then
  blank_intent="$(grep -nE '^[[:space:]]*-[[:space:]]*\*\*의도\*\*:[[:space:]]*$' "$D" | cut -d: -f1 | tr '\n' ' ')"
  [ -n "$blank_intent" ] && miss "DECISIONS 의도 칸이 빈 줄(줄 번호: ${blank_intent}) — 추측해 채우지 말고 사람에게 받는다"
fi

# 7) S6: 구현 커밋([S4]) 없이 검증을 시작하려는가 — KR-049
if [ "$STAGE" = S6 ]; then
  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    git log --oneline 2>/dev/null | grep -qE '\[S4\]' || miss "git log에 [S4] 커밋이 없음 — 구현 전에 검증을 시작하지 않는다"
  else
    echo "경고(멈추지 않음): git 이력을 확인할 수 없어 [S4] 커밋 존재 여부를 못 봤다"
  fi
fi

if [ "$FAIL" -eq 0 ]; then
  echo "통과: $STAGE 진입 조건"
  exit 0
fi
exit 1
