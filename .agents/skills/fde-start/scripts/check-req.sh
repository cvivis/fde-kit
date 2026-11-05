#!/usr/bin/env bash
# 요구 문서 점검(KR-145·146·147·149·151): docs/REQ-TASK.md(지문 요구 T-ID)·docs/REQ-USER.md(얻은 요구 U-ID).
# 사용(작업 폴더 루트): bash .agents/skills/fde-start/scripts/check-req.sh count|links|verify
#   count  — 표를 다시 세어 두 문서 맨 위 "개수:" 줄과 STATE 기준판 "- 요구:" 줄을 고쳐 쓰고 한 줄 요약을 출력한다.
#            개수를 손으로 세거나 옮겨 적지 않는다.
#   links  — (S3 끝·S4 진입) 범위 "이번" 요구마다 "설계 연결" 칸에 설계 ID가 있고 그 ID가 실제로 있는지 본다.
#            설계 ID: STATE 작업 목록 T<n> · LOGIC 조건 C<n>·단계 P<n> · DECISIONS D<n> (요구 ID T-01·U-01·결정 C-01과 다르다)
#            거꾸로(KR-149): 작업 목록 항목·LOGIC 조건 행 중 범위 안 요구가 가리키지 않는 것을 "근거 없음(범위 밖)"으로,
#            요구 종류(반드시·점수·목표)와 연결된 LOGIC 조건 종류가 다르면 "해석 차이"로 알린다 — 둘 다 경고, 고칠지는 사람이 정한다.
#   verify — (S4 끝·S6·S7) 범위 "이번" 요구마다 "구현 확인" 칸에 판정(충족/부분/미충족 — 근거)이 있는지 본다. 비면 미확인.
#   표 열 — REQ-TASK: | ID | 요구(지문 원문) | 우선 | 종류 | 범위 | 설계 연결 | 구현 확인 |
#           REQ-USER: | ID | 요구 | 출처 | 우선 | 종류 | 범위 | 설계 연결 | 구현 확인 |
#   개수 줄의 설계 연결 x/m = 범위 안 m개 중 설계 ID가 있고 모두 실제로 있는 요구, 구현 확인 y/m = 판정이 적힌 요구.
# 종료 코드: 0 통과 / 1 지문 요구 0건·범위 안 요구 0건(검증 0건은 실패)·문서 없음, links 누락, verify 미확인 / 2 사용법 오류
# 근거 없음·해석 차이·제외 요구는 종료 코드에 영향 없음(경고).
set -u

MODE="${1:-}"
case "$MODE" in count|links|verify) ;; *) echo "사용: check-req.sh count|links|verify" >&2; exit 2 ;; esac

T=docs/REQ-TASK.md
U=docs/REQ-USER.md
S=docs/STATE.md
L=docs/LOGIC.md
D=docs/DECISIONS.md
for f in "$T" "$U"; do
  [ -f "$f" ] || { echo "없음: $f — S0(init-docs.sh)부터" >&2; exit 1; }
done

# "## 제목"으로 시작하는 절의 본문(다음 "## "까지). HTML 주석 줄은 뺀다.
section() {
  [ -f "$1" ] || return 0
  awk -v t="## $2" '
    index($0, t) == 1 { on = 1; next }
    on && /^## / { exit }
    on && !/^[[:space:]]*<!--/ { print }
  ' "$1"
}

# 실제로 있는 설계 항목: "ID<TAB>종류<TAB>본문" (종류는 LOGIC 조건만)
#   작업 목록 "- [ ] T<n> …", LOGIC 조건 행(규칙 칸이 찬 것), 단계 행(하는 일 칸이 찬 것), DECISIONS "## D<n>. 제목"
design_items() {
  section "$S" "작업 목록" | awk '/^- \[[ xX]\] T[0-9]+([^0-9]|$)/ { id = $0; sub(/^- \[[ xX]\] /, "", id); sub(/[^A-Za-z0-9].*$/, "", id); print id "\t\t" $0 }'
  { section "$L" "조건"; section "$L" "단계"; } | awk -F'|' '
    /^\|/ {
      for (i = 2; i < NF; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
      if ($2 ~ /^C[0-9]+$/ && $4 != "") print $2 "\t" $3 "\t" $0
      else if ($2 ~ /^P[0-9]+$/ && $3 != "") print $2 "\t\t" $0
    }'
  [ -f "$D" ] && grep -E '^## D[0-9]+\.' "$D" | grep -v '(제목)' | awk '{ id = $2; sub(/\..*$/, "", id); print id "\t\t" $0 }'
  return 0
}
ITEMS="$(design_items)"
IDS=" $(printf '%s\n' "$ITEMS" | cut -f1 | grep . | awk '!s[$0]++' | tr '\n' ' ')"
CKINDS="$(printf '%s\n' "$ITEMS" | awk -F'\t' '$1 ~ /^C/ && $2 != "" { printf "%s=%s ", $1, $2 }')"

# 표 행 → "ID<TAB>우선<TAB>종류<TAB>범위<TAB>설계연결<TAB>구현확인<TAB>요구<TAB>연결상태<TAB>판정"
#   ID가 접두(T-/U-)+숫자이고 요구 칸이 찬 행만. 연결상태: 연결 / 빈칸 / ID없음 / 없는ID:<ids>
#   판정: 구현 확인 칸의 미충족 / 부분 / 충족, 없으면 미확인
# $1: 파일, $2: ID 접두, $3: 우선 열 번호, $4: 범위 열 번호(종류는 범위 앞, 설계 연결·구현 확인은 범위 다음 두 열)
rows() {
  awk -F'|' -v pre="$2" -v pc="$3" -v sc="$4" -v ids="$IDS " '
    /^\|/ {
      for (i = 2; i < NF; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
      if ($2 !~ ("^" pre "[0-9]+$") || $3 == "") next
      link = $(sc + 1); v = $(sc + 2)
      s = link; gsub(/[^A-Za-z0-9-]+/, " ", s); n = split(s, tk, " "); found = 0; bad = ""
      for (i = 1; i <= n; i++) if (tk[i] ~ /^[TCPD][0-9]+$/) {
        found++
        if (index(ids, " " tk[i] " ") == 0) bad = bad (bad == "" ? "" : ",") tk[i]
      }
      ls = (link == "") ? "빈칸" : (found == 0 ? "ID없음" : (bad != "" ? "없는ID:" bad : "연결"))
      vs = (v ~ /미충족/) ? "미충족" : (v ~ /부분/) ? "부분" : (v ~ /충족/) ? "충족" : "미확인"
      req = $3
      print $2 "\t" $pc "\t" $(sc - 1) "\t" $sc "\t" link "\t" v "\t" req "\t" ls "\t" vs
    }' "$1"
}
t_rows="$(rows "$T" T- 4 6)"
u_rows="$(rows "$U" U- 5 7)"
all_rows="$(printf '%s\n%s\n' "$t_rows" "$u_rows" | grep .)"
in_rows="$(printf '%s\n' "$all_rows" | awk -F'\t' '$4 ~ /^이번/')"

# "총 n · 필수 a · …" 에 쓸 값: 우선 값별 개수, 제외, 범위 안, 설계 연결, 구현 확인
tally() {
  awk -F'\t' -v keys="$1" '
    BEGIN { nk = split(keys, k, " ") }
    {
      total++
      ok = 0; for (i = 1; i <= nk; i++) if ($2 == k[i]) { c[i]++; ok = 1 }
      if (!ok && !(($2) in seen)) { seen[$2] = 1; bad = bad " " ($2 == "" ? "(빈 칸)" : $2) }
      if ($4 ~ /^제외/) ex++
      else if ($4 ~ /^이번/) { m++; if ($8 == "연결") x++; if ($9 != "미확인") y++ }
      else if ($4 == "" || $4 ~ /^미정/) und++
    }
    END {
      line = "총 " total + 0
      for (i = 1; i <= nk; i++) line = line " · " k[i] " " c[i] + 0
      printf "%s · 제외 %d · 설계 연결 %d/%d · 구현 확인 %d/%d\t%d\t%d\t%d\t%d\t%d\t%s\n", line, ex, x, m, y, m, und, ex, m, x, y, bad
    }'
}

# 줄 바꿔 쓰기: $1 파일, $2 줄 머리(정규식), $3 새 줄, $4 없을 때 넣을 자리(그 줄 머리 다음, 비면 1행 다음)
rewrite() {
  if grep -q "$2" "$1"; then
    awk -v h="$2" -v l="$3" '!d && $0 ~ h { print l; d = 1; next } { print }' "$1" > "$1.tmp"
  elif [ -n "${4:-}" ] && grep -q "$4" "$1"; then
    awk -v h="$4" -v l="$3" '{ print } !d && $0 ~ h { print l; d = 1 }' "$1" > "$1.tmp"
  elif [ -z "${4:-}" ]; then
    awk -v l="$3" 'NR == 1 { print; print l; next } { print }' "$1" > "$1.tmp"
  else
    return 1
  fi
  mv "$1.tmp" "$1"
}

TAB="$(printf '\t')"
IFS="$TAB" read -r t_line t_und t_ex t_m t_x t_y t_bad <<EOF
$(printf '%s\n' "$t_rows" | grep . | tally "필수 권장")
EOF
IFS="$TAB" read -r u_line u_und u_ex u_m u_x u_y u_bad <<EOF
$(printf '%s\n' "$u_rows" | grep . | tally "P0 P1 P2")
EOF
rewrite "$T" '^개수:' "개수: $t_line"
rewrite "$U" '^개수:' "개수: $u_line"

num() { printf '%s' "$1" | sed -n "s/.*$2 \([0-9][0-9]*\).*/\1/p"; }
t_n="$(num "$t_line" 총)"; u_n="$(num "$u_line" 총)"
m=$((t_m + u_m)); x=$((t_x + u_x)); y=$((t_y + u_y))
summary="요구: 지문 ${t_n}(필수 $(num "$t_line" 필수)·권장 $(num "$t_line" 권장)) · 얻은 요구 ${u_n}(P0 $(num "$u_line" P0)·P1 $(num "$u_line" P1)·P2 $(num "$u_line" P2)) · 제외 $((t_ex + u_ex)) · 설계 연결 ${x}/${m} · 구현 확인 ${y}/${m}"

# STATE 기준판 "- 요구:" 줄 — KR-151. 손으로 옮겨 적지 않는다(S0 뒤에 낡는다)
if [ -f "$S" ]; then
  rewrite "$S" '^- 요구:' "- $summary <!-- check-req.sh가 다시 쓴다 -->" '^## 기준판' \
    || echo "경고(멈추지 않음): STATE에 '- 요구:' 줄과 '## 기준판' 절이 없어 요구 줄을 못 썼다"
fi

if [ "$MODE" = count ]; then
  echo "$summary"
  [ -n "$t_bad" ] && echo "경고(멈추지 않음): REQ-TASK 우선 칸이 필수/권장이 아님:$t_bad"
  [ -n "$u_bad" ] && echo "경고(멈추지 않음): REQ-USER 우선 칸이 P0/P1/P2가 아님:$u_bad"
  [ "$t_und" -gt 0 ] && echo "경고(멈추지 않음): REQ-TASK 범위가 비었거나 미정 ${t_und}건 — 이번 또는 '제외 — 이유'로 적는다"
  [ "$u_und" -gt 0 ] && echo "경고(멈추지 않음): REQ-USER 범위 미정 ${u_und}건 — S2 합의에서 이번/제외로 확정한다"
  [ "$u_n" -eq 0 ] && echo "경고(멈추지 않음): 얻은 요구 0건 — S1 인터뷰·조사 결정에서 REQ-USER에 올린다(S3 진입 검사는 0건을 막는다)"
fi

if [ "$t_n" -eq 0 ]; then
  echo "실패: 지문 요구 0건 — 검증 0건은 실패. S0이 과제 지문의 요구를 REQ-TASK에 원문으로 옮긴다" >&2
  exit 1
fi
[ "$MODE" = count ] && exit 0

if [ "$m" -eq 0 ]; then
  echo "실패: 범위 '이번' 요구 0건 — 검증할 요구가 없다(검증 0건은 실패). S2 합의에서 범위를 확정한다" >&2
  exit 1
fi

# 거꾸로(KR-149): 작업 목록 항목(T<n>)·LOGIC 조건(C<n>) 중 범위 안 요구가 설계 연결로 가리키지 않고,
# 자기 줄에도 범위 안 요구 ID(T-01·U-01)가 없는 것 → 근거 없음(범위 밖). 경고만.
orphans() {
  in_ids=" $(printf '%s\n' "$in_rows" | cut -f1 | tr '\n' ' ')"
  linked=" $(printf '%s\n' "$in_rows" | cut -f5 | tr -c 'A-Za-z0-9\n-' ' ' | tr ' ' '\n' | grep -E '^[TC][0-9]+$' | awk '!s[$0]++' | tr '\n' ' ')"
  printf '%s\n' "$ITEMS" | awk -F'\t' -v in_ids="$in_ids " -v linked="$linked " '
    $1 ~ /^[TC][0-9]+$/ {
      if (index(linked, " " $1 " ")) next
      s = $3; gsub(/[^A-Za-z0-9-]+/, " ", s); n = split(s, tk, " "); ok = 0
      for (i = 1; i <= n; i++) if (tk[i] ~ /^[TU]-[0-9]+$/ && index(in_ids, " " tk[i] " ")) ok = 1
      if (ok) next
      body = $3; sub(/^- \[[ xX]\] /, "", body); gsub(/^[-|[:space:]]+|[|[:space:]]+$/, "", body)
      print $1 "\t" body
    }'
}
report_orphans() {
  o="$(orphans)"
  if [ -n "$o" ]; then
    echo "근거 없음(범위 밖): $(printf '%s\n' "$o" | cut -f1 | tr '\n' ' ' | sed 's/ $//; s/ /, /g') — 범위 안 요구 ID가 가리키지 않는다. 요구에 잇기/빼기/그대로 두기는 사람이 정한다"
    printf '%s\n' "$o" | awk -F'\t' '{ print "  - " $1 " · " $2 }'
  else
    echo "근거 없음(범위 밖): 없음"
  fi
}

if [ "$MODE" = links ]; then
  miss="$(printf '%s\n' "$in_rows" | awk -F'\t' '$8 != "연결"')"
  names="$(printf '%s\n' "$miss" | cut -f1 | grep . | tr '\n' ' ' | sed 's/ $//; s/ /, /g')"
  echo "설계 연결: 요구 ${m}개 중 설계 연결 ${x}개, 누락: ${names:-없음}"
  printf '%s\n' "$miss" | grep . | awk -F'\t' '{
    ids = $8; sub(/^없는ID:/, "", ids)
    why = ($8 == "빈칸") ? "설계 연결 칸 빈칸" : ($8 == "ID없음") ? "설계 ID(T<n>·C<n>·P<n>·D<n>) 없음: " $5 : "없는 ID " ids " — STATE 작업 목록·LOGIC·DECISIONS에 없다"
    print "  - " $1 " [" $2 "·" $3 "] " why " — \"" $7 "\""
  }'
  # 해석 차이: 요구 종류(반드시·점수·목표)와 연결된 LOGIC 조건 종류가 다르다(예: 점수를 반드시로) — 경고
  printf '%s\n' "$in_rows" | awk -F'\t' -v ck=" $CKINDS" '
    $3 ~ /^(반드시|점수|목표)$/ {
      s = $5; gsub(/[^A-Za-z0-9-]+/, " ", s); n = split(s, tk, " ")
      for (i = 1; i <= n; i++) if (tk[i] ~ /^C[0-9]+$/ && (p = index(ck, " " tk[i] "="))) {
        kk = substr(ck, p + length(tk[i]) + 2); sub(/ .*/, "", kk)
        if (kk != $3) print "해석 차이(사람이 판단): " $1 " 종류 " $3 " → " tk[i] " " kk " — \"" $7 "\""
      }
    }'
  report_orphans
  [ -n "$names" ] && exit 1
  exit 0
fi

# verify
miss="$(printf '%s\n' "$in_rows" | awk -F'\t' '$9 == "미확인"')"
names="$(printf '%s\n' "$miss" | cut -f1 | grep . | tr '\n' ' ' | sed 's/ $//; s/ /, /g')"
cnt() { printf '%s\n' "$in_rows" | awk -F'\t' -v v="$1" '$9 == v' | grep -c .; }
echo "구현 확인: 요구 ${m}개 중 구현 확인 ${y}개(충족 $(cnt 충족) · 부분 $(cnt 부분) · 미충족 $(cnt 미충족)), 미확인: ${names:-없음}"
printf '%s\n' "$miss" | grep . | awk -F'\t' '{
  link = ($5 == "") ? "" : " (설계 연결 " $5 ")"
  print "  - " $1 " [" $2 "·" $3 "] 미확인 — \"" $7 "\"" link
}'
report_orphans
[ -n "$names" ] && exit 1
exit 0
