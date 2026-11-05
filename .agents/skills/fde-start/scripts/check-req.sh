#!/usr/bin/env bash
# 요구 문서 개수 점검(KR-145): docs/REQ-TASK.md(지문 요구 T-ID)·docs/REQ-USER.md(얻은 요구 U-ID) 표를 다시 세어
# 각 문서 맨 위 "개수:" 줄을 고쳐 쓰고 한 줄 요약을 출력한다. 개수를 손으로 세지 않는다.
# 사용(작업 폴더 루트): bash .agents/skills/fde-start/scripts/check-req.sh count
#   REQ-TASK 표: | ID | 요구(지문 원문) | 우선 | 종류 | 범위 | 설계 연결 | 구현 확인 |
#   REQ-USER 표: | ID | 요구 | 출처 | 우선 | 종류 | 범위 | 설계 연결 | 구현 확인 |
#   범위 안(m) = 범위 칸이 "이번"으로 시작하는 행. 설계 연결 x/m·구현 확인 y/m은 범위 안 행 중 그 칸이 찬 수.
# 종료 코드: 0 통과 / 1 지문 요구 0건(검증 0건은 실패) 또는 문서 없음 / 2 사용법 오류
# (links·verify 모드는 아직 없다 — 설계 연결·구현 확인 누락 검사는 다음 단계에서 더한다)
set -u

MODE="${1:-}"
[ "$MODE" = count ] || { echo "사용: check-req.sh count" >&2; exit 2; }

T=docs/REQ-TASK.md
U=docs/REQ-USER.md
for f in "$T" "$U"; do
  [ -f "$f" ] || { echo "없음: $f — S0(init-docs.sh)부터" >&2; exit 1; }
done

# 표 행 → "우선<TAB>범위<TAB>설계연결<TAB>구현확인". ID가 접두(T-/U-)+숫자이고 요구 칸이 찬 행만 센다.
# $1: 파일, $2: ID 접두, $3: 우선 열 번호, $4: 범위 열 번호(설계 연결·구현 확인은 범위 다음 두 열)
rows() {
  awk -F'|' -v pre="$2" -v pc="$3" -v sc="$4" '
    /^\|/ {
      for (i = 2; i < NF; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
      if ($2 !~ ("^" pre "[0-9]+$") || $3 == "") next
      print $pc "\t" $sc "\t" $(sc + 1) "\t" $(sc + 2)
    }' "$1"
}

# "총 n · 필수 a · …" 에 쓸 값: 우선 값별 개수, 제외, 범위 안, 설계 연결, 구현 확인
tally() {
  awk -F'\t' -v keys="$1" '
    BEGIN { nk = split(keys, k, " ") }
    {
      total++
      for (i = 1; i <= nk; i++) if ($1 == k[i]) c[i]++
      ok = 0; for (i = 1; i <= nk; i++) if ($1 == k[i]) ok = 1
      if (!ok && !(($1) in seen)) { seen[$1] = 1; bad = bad " " ($1 == "" ? "(빈 칸)" : $1) }
      if ($2 ~ /^제외/) ex++
      else if ($2 ~ /^이번/) { m++; if ($3 != "") x++; if ($4 != "") y++ }
      else if ($2 == "" || $2 ~ /^미정/) und++
    }
    END {
      line = "총 " total + 0
      for (i = 1; i <= nk; i++) line = line " · " k[i] " " c[i] + 0
      printf "%s · 제외 %d · 설계 연결 %d/%d · 구현 확인 %d/%d\t%d\t%d\t%s\n", line, ex, x, m, y, m, und, ex, bad
    }'
}

# 맨 위 "개수:" 줄을 바꿔 쓴다. 없으면 제목 줄 다음에 넣는다.
rewrite() {
  if grep -q '^개수:' "$1"; then
    awk -v l="개수: $2" '!d && /^개수:/ { print l; d = 1; next } { print }' "$1" > "$1.tmp"
  else
    awk -v l="개수: $2" 'NR == 1 { print; print l; next } { print }' "$1" > "$1.tmp"
  fi
  mv "$1.tmp" "$1"
}

t_rows="$(rows "$T" T- 4 6)"
u_rows="$(rows "$U" U- 5 7)"
IFS="$(printf '\t')" read -r t_line t_und t_ex t_bad <<EOF
$(printf '%s' "$t_rows" | grep . | tally "필수 권장")
EOF
IFS="$(printf '\t')" read -r u_line u_und u_ex u_bad <<EOF
$(printf '%s' "$u_rows" | grep . | tally "P0 P1 P2")
EOF
rewrite "$T" "$t_line"
rewrite "$U" "$u_line"

num() { printf '%s' "$1" | sed -n "s/.*$2 \([0-9][0-9]*\).*/\1/p"; }
t_n="$(num "$t_line" 총)"; u_n="$(num "$u_line" 총)"
echo "요구: 지문 ${t_n}(필수 $(num "$t_line" 필수)·권장 $(num "$t_line" 권장)) · 얻은 요구 ${u_n}(P0 $(num "$u_line" P0)·P1 $(num "$u_line" P1)·P2 $(num "$u_line" P2)) · 제외 $((t_ex + u_ex))"

[ -n "$t_bad" ] && echo "경고(멈추지 않음): REQ-TASK 우선 칸이 필수/권장이 아님:$t_bad"
[ -n "$u_bad" ] && echo "경고(멈추지 않음): REQ-USER 우선 칸이 P0/P1/P2가 아님:$u_bad"
[ "$t_und" -gt 0 ] && echo "경고(멈추지 않음): REQ-TASK 범위가 비었거나 미정 ${t_und}건 — 이번 또는 '제외 — 이유'로 적는다"
[ "$u_und" -gt 0 ] && echo "경고(멈추지 않음): REQ-USER 범위 미정 ${u_und}건 — S2 합의에서 이번/제외로 확정한다"
[ "$u_n" -eq 0 ] && echo "경고(멈추지 않음): 얻은 요구 0건 — S1 인터뷰·조사 결정에서 REQ-USER에 올린다(S3 진입 검사는 0건을 막는다)"

if [ "$t_n" -eq 0 ]; then
  echo "실패: 지문 요구 0건 — 검증 0건은 실패. S0이 과제 지문의 요구를 REQ-TASK에 원문으로 옮긴다" >&2
  exit 1
fi
exit 0
