#!/usr/bin/env bash
# 단계 진입 점검: 앞 단계 산출물의 빈 칸을 결정론으로 찾는다. 문서 규칙("비어 있으면 멈춘다")을 코드로 한 번 더 건다.
# 사용(작업 폴더 루트): bash .agents/skills/fde-start/scripts/check-stage.sh S3|S4|S6|S7
#   공통: docs/TASK-ORIGINALS.sha256(S0 init-docs.sh가 기록)의 과제 원본 파일이 바뀌거나 없어졌으면 막는다(KR-122)
#   S3: 한 줄 명세, STATE 목표 한 줄, 성공 기준 1개 이상
#       리서치형(STATE "- 과제 유형: 리서치형")은 한 줄 명세 "- 근거:"에 RESEARCH "## 결정" C-ID(원문 있는 행) — KR-136
#       RESEARCH "## 최소 정보 점검" 8칸 빈칸 없음·근거 있음·"- 판정: 충족" — KR-144
#       check-req.sh count 통과(지문 요구 1건 이상) + REQ-USER 얻은 요구 1건 이상 — KR-145
#       (경고만, 종료 코드에 영향 없음) INTERVIEW 요구 체크리스트 빈 칸 — S2가 [기본]을 가정으로 채웠어야 한다
#       (경고만) 성공 기준이 5개를 넘으면 — KR-046, 늘릴 땐 다음 사이클·교체 중 하나를 사람에게 물었어야 한다
#   S4: S3 + 성공 기준마다 확인 방법, 작업 목록 항목마다 완료 조건, 모든 성공 기준 번호가 작업 목록에 연결,
#       DECISIONS 의도 칸이 빈 줄로 남은 결정 없음(KR-048 — "empty — 이유"는 통과, 완전히 빈 줄만 막는다),
#       LOGIC 결정 한 문장(또는 "결정 없음 — 이유"), 조건 1개 이상, "반드시" 조건마다 담당 단계(KR-060·061·068),
#       (경고만) LOGIC 단계 행의 확인 케이스 빈 칸(KR-074)
#       check-req.sh links — 범위 안 요구마다 설계 연결(KR-146)·반드시 요구 숫자 대조(KR-154). 누락·반드시 숫자 불일치는 막고, 근거 없음·해석 차이(KR-149)는 경고만
#       check-work.sh design — 반드시 조건의 출처 없는 숫자는 막고(KR-157), 점수 숫자 한도·위반 테스트 계획·단계 표·DECISIONS·작업 목록은 경고(KR-119·120·158·159)
#   S6: S4 + git log에 [S4] 커밋이 있어야 함(KR-049 — 구현 전에 검증을 시작하지 않는다)
#       (경고만) check-req.sh verify — 구현 확인 미확인 개수·ID(KR-147). S6이 판정해 채우므로 막지 않는다
#   S7: S3 + [S4] 커밋 + 원본 대조. (경고만) 구현 확인 미확인 — 제출 문서 "알려진 한계"에 옮긴다
#       (경고만) check-work.sh verify — VERIFY 성공 기준별 충족 행 수·판정·근거, 목적 적합 5행(KR-163)
# 판정 스크립트 check-req.sh·check-work.sh는 node(.mjs)를 부른다(KR-164). node가 없으면 그 판정은 "실행 불가"이고 통과가 아니다(KR-107).
# 종료 코드: 0 통과 / 1 빈 칸 있음(출력된 칸을 사람에게 보여 주고 멈춘다) / 2 사용법 오류 / 3 실행 불가(node 없음 — 빈 칸은 없었지만 판정 일부를 못 돌림)
set -u

STAGE="${1:-}"
case "$STAGE" in S3|S4|S6|S7) ;; *) echo "사용: check-stage.sh S3|S4|S6|S7" >&2; exit 2 ;; esac

A=docs/AGREEMENT.md
S=docs/STATE.md
for f in "$A" "$S"; do
  [ -f "$f" ] || { echo "없음: $f — S0(init-docs.sh)부터" >&2; exit 2; }
done

FAIL=0
NOEXEC=0
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

# 1) 한 줄 명세: 양식 문구([누가] …)가 남아 있지 않은 내용 줄. "- 근거:" 줄은 명세가 아니다
spec="$(section "$A" "한 줄 명세" | trim | grep -v '^$' | grep -v '^- 근거:' | head -1)"
if [ -z "$spec" ] || printf '%s' "$spec" | grep -q '\[누가\]'; then
  miss "AGREEMENT 한 줄 명세 — 목적을 문장으로 못 쓰면 설계를 시작하지 않는다"
fi

# 1-B) 한 줄 명세 근거 — KR-136. 리서치형(STATE "- 과제 유형: 리서치형")은 INTERVIEW 인용 대신 RESEARCH "## 결정"의
#      C-ID(원문이 있는 행)를 근거로 받는다. 혼합형은 INTERVIEW 인용(#n) 또는 C-ID가 없으면 경고만 한다.
R=docs/RESEARCH.md
kind="$(grep -m1 '^- 과제 유형:' "$S" | sed 's/^- 과제 유형://' | trim)"
basis="$(section "$A" "한 줄 명세" | trim | grep -v '^$')"
cids_ok=""
if [ -f "$R" ]; then
  for c in $(printf '%s' "$basis" | grep -oE 'C-[0-9]+' | sort -u); do
    section "$R" "결정" | awk -F'|' -v id="$c" '
      /^\|/ { for (i = 2; i < NF; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); if ($2 == id && $5 != "") f = 1 }
      END { exit !f }' && cids_ok="$cids_ok $c"
  done
fi
case "$kind" in
  리서치형*)
    [ -n "$cids_ok" ] || miss "AGREEMENT 한 줄 명세 근거 — 리서치형은 RESEARCH '## 결정'의 C-ID(원문이 있는 행)를 '- 근거:' 줄에 적는다" ;;
  혼합형*)
    [ -n "$cids_ok" ] || printf '%s' "$basis" | grep -qE '#[0-9]+' || echo "경고(멈추지 않음): AGREEMENT 한 줄 명세 근거(INTERVIEW #n 또는 C-ID)가 없다" ;;
  *) echo "경고(멈추지 않음): STATE 기준판 '과제 유형'이 비어 있다 — S0이 혼합형/리서치형을 지문 근거로 적는다" ;;
esac

# 1-C) 최소 정보 점검 — KR-144. RESEARCH "## 최소 정보 점검" 8칸이 모두 있고 빈칸이 없으며 판정이 충족이어야 한다.
#      표 열: | 칸 | 상태 | 근거 |. 상태는 채움/가정(근거 필수)/빈칸.
if [ ! -f "$R" ]; then
  miss "docs/RESEARCH.md 없음 — S1 조사(\$fde-research)의 최소 정보 점검이 필요하다"
else
  minfo="$(section "$R" "최소 정보 점검")"
  table="$(printf '%s\n' "$minfo" | awk -F'|' '
    /^\|/ && $0 !~ /^\|[-[:space:]|]+$/ {
      for (i = 2; i < NF; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
      if ($2 == "칸") next
      print $2 "\t" $3 "\t" $4
    }')"
  blanks=""
  for label in "결정 한 문장" "출력 한 줄" "입력 데이터 열" "반드시 조건 숫자" "점수·목표 기준" "예외 처리" "출발선" "고른 방안"; do
    row="$(printf '%s\n' "$table" | awk -F'\t' -v l="$label" '$1 == l { print; exit }')"
    if [ -z "$row" ]; then miss "RESEARCH 최소 정보 점검 '$label' 칸 없음 — 칸 8개를 지우지 않는다"; continue; fi
    st="$(printf '%s' "$row" | cut -f2)"; ev="$(printf '%s' "$row" | cut -f3)"
    case "$st" in
      채움|가정) [ -n "$ev" ] || miss "RESEARCH 최소 정보 점검 '$label' 근거 — $st이면 인용 #n·C-ID·F-ID·사람 말을 적는다" ;;
      *) blanks="$blanks$label, " ;;
    esac
  done
  [ -n "$blanks" ] && miss "RESEARCH 최소 정보 점검 빈칸: ${blanks%, } — 빈칸만 묶어 묻고, 가정으로 넘기라는 답을 받으면 가정으로 적는다"
  verdict="$(printf '%s\n' "$minfo" | grep -m1 '^- 판정:' | sed 's/^- 판정://' | trim)"
  case "$verdict" in
    충족*) ;;
    "") miss "RESEARCH 최소 정보 점검 '- 판정:' 줄 없음" ;;
    *) miss "RESEARCH 최소 정보 점검 판정: $verdict" ;;
  esac
fi

# 1-D) 요구 문서 — KR-145. check-req.sh count가 통과(지문 요구 1건 이상)하고, 얻은 요구가 1건 이상이어야 한다.
reqout="$(bash "$(dirname "$0")/check-req.sh" count 2>&1)"; reqrc=$?
printf '%s\n' "$reqout"
if [ "$reqrc" -eq 3 ]; then
  NOEXEC=1
elif [ "$reqrc" -ne 0 ]; then
  miss "요구 문서 — check-req.sh count 실패(위 출력)"
else
  u_n="$(printf '%s\n' "$reqout" | sed -n 's/.*얻은 요구 \([0-9][0-9]*\)(.*/\1/p' | head -1)"
  [ "${u_n:-0}" -gt 0 ] || miss "REQ-USER 얻은 요구 0건 — 인터뷰 인용·조사 결정(C-ID)에서 얻은 요구를 U-ID로 올린다"
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

# 6-B) LOGIC 배정표 — KR-060·061·068. 결정이 있으면 조건이 1개 이상이고, "반드시" 조건마다 담당 단계가 있어야 한다.
#      표 열 순서: | ID | 종류 | 규칙(숫자) | 근거 | 담당 단계 | 방식 |. "- 결정: 결정 없음 — 이유"면 나머지를 보지 않는다.
L=docs/LOGIC.md
if [ "$STAGE" = S4 ] || [ "$STAGE" = S6 ]; then
  if [ ! -f "$L" ]; then
    miss "docs/LOGIC.md 없음 — 규칙이 걸린 결정이 없으면 '- 결정: 결정 없음 — 이유' 한 줄로 만든다"
  else
    decision="$(grep -m1 '^- 결정:' "$L" | sed 's/^- 결정://' | trim)"
    if [ -z "$decision" ]; then
      miss "LOGIC 결정 한 문장 — 없으면 '결정 없음 — 이유'"
    elif ! printf '%s' "$decision" | grep -q '^결정 없음'; then
      conds="$(section "$L" "조건" | awk -F'|' '
        /^\|/ && $0 !~ /^\|[-[:space:]|]+$/ {
          for (i = 2; i <= 7; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
          if ($2 == "ID" || $3 == "" || $4 == "") next
          print $2 "\t" $3 "\t" $4 "\t" $6
        }')"
      if [ -z "$conds" ]; then
        miss "LOGIC 조건 0개 — 검사할 조건이 없으면 검사기도 0건을 검사한다(검증 0건 = 실패)"
      else
        while IFS="$(printf '\t')" read -r cid kind rule owner; do
          [ "$kind" = 반드시 ] || continue
          [ -n "$owner" ] || miss "LOGIC 반드시 조건 $cid 담당 단계 — 어느 단계가 지키는지 정해야 로직이다"
          printf '%s' "$rule" | grep -q '숫자 없음' && echo "경고(멈추지 않음): LOGIC 반드시 조건 $cid 규칙에 숫자 없음 — 담당자 답을 받거나 AGREEMENT 가정에 값을 적는다"
        done <<EOF
$conds
EOF
      fi
      # (경고만) 단계 표 | 단계 | 하는 일 | 고르는 규칙 | 입력 → 출력 | 확인 케이스 | 에서 확인 케이스가 빈 행 — KR-074
      nocase="$(section "$L" "단계" | awk -F'|' '
        /^\|[[:space:]]*P[0-9]+/ {
          for (i = 2; i <= 6; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
          if ($3 != "" && $6 == "") printf "%s ", $2
        }')"
      [ -n "$nocase" ] && echo "경고(멈추지 않음): LOGIC 단계 ${nocase}확인 케이스 빈 칸 — 작은 입력 → 기대 출력을 적고 S4에서 테스트 이름을 채운다"
    fi
  fi
fi

# 6-C) 요구 추적 — KR-146·147·149. 지문 요구가 0건이면 1-D가 이미 막았으므로 보지 않는다.
#      S4·S6: check-req.sh links — 범위 안 요구의 설계 연결 누락·없는 ID는 막는다. 근거 없음·해석 차이는 경고(사람이 정한다).
#      S6·S7: check-req.sh verify — 구현 확인 미확인은 경고로 개수와 ID를 알린다(S6이 판정해 채우고, S7은 제출 문서 알려진 한계에 옮긴다).
if [ "$reqrc" -eq 0 ]; then
  if [ "$STAGE" = S4 ] || [ "$STAGE" = S6 ]; then
    lout="$(bash "$(dirname "$0")/check-req.sh" links 2>&1)"; lrc=$?
    printf '%s\n' "$lout"
    [ "$lrc" -ne 0 ] && miss "요구 설계 연결·숫자 — 위 누락 요구는 REQ 설계 연결 칸에 작업 항목 T<n>·LOGIC 조건 C<n>·단계 P<n>·결정 D<n>를, 반드시 숫자 불일치는 LOGIC 규칙에 요구 숫자를 그대로 적는다(S3 fde-design)"
  fi
  if [ "$STAGE" = S6 ] || [ "$STAGE" = S7 ]; then
    vout="$(bash "$(dirname "$0")/check-req.sh" verify 2>&1)"; vrc=$?
    printf '%s\n' "$vout" | grep -v '^근거 없음\|^  - [TC][0-9]* · '
    if [ "$vrc" -ne 0 ]; then
      n_un="$(printf '%s\n' "$vout" | sed -n 's/.*미확인: \(.*\)$/\1/p' | head -1 | tr ',' '\n' | grep -c .)"
      echo "경고(멈추지 않음): 요구 미확인 ${n_un}건 — 숨기지 않는다. S6은 REQ 구현 확인 칸에 충족/부분/미충족 — 근거로 판정하고, 판정 못 한 것은 문제 목록에, S7은 제출 문서 '알려진 한계'에 적는다"
    fi
  fi
fi

# 6-D) 설계 산출물의 셀 수 있는 점검 — KR-156·157. S4 진입(=S3 끝 자가 검증)에서만. 실패 줄(반드시 조건 숫자 출처 없음)만 막는다
if [ "$STAGE" = S4 ]; then
  wout="$(bash "$(dirname "$0")/check-work.sh" design 2>&1)"; wrc=$?
  printf '%s\n' "$wout" | grep -v '^통과: check-work\|^실패: check-work'
  [ "$wrc" -eq 3 ] && NOEXEC=1
  [ "$wrc" -ne 0 ] && [ "$wrc" -ne 3 ] && miss "설계 점검 — 위 check-work.sh design의 '실패:' 줄(S3 fde-design에서 고친다)"
fi
# 6-E) S6 검증 기록 — KR-163. S7 진입에서 경고만(148분 이후 제출 정리를 막지 않는다)
if [ "$STAGE" = S7 ]; then
  wout="$(bash "$(dirname "$0")/check-work.sh" verify 2>&1)"; wrc=$?
  [ "$wrc" -eq 3 ] && NOEXEC=1
  if [ "$wrc" -ne 0 ] && [ "$wrc" -ne 3 ]; then
    printf '%s\n' "$wout" | grep -v '^실패: check-work' | sed 's/^실패: /경고(멈추지 않음): S6 기록 — /'
  fi
fi

# 7) S6·S7: 구현 커밋([S4]) 없이 검증을 시작하려는가 — KR-049
if [ "$STAGE" = S6 ] || [ "$STAGE" = S7 ]; then
  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    git log --oneline 2>/dev/null | grep -qE '\[S4\]' || miss "git log에 [S4] 커밋이 없음 — 구현 전에 검증을 시작하지 않는다"
  else
    echo "경고(멈추지 않음): git 이력을 확인할 수 없어 [S4] 커밋 존재 여부를 못 봤다"
  fi
fi

# 8) 과제 원본 파일 — KR-122. 고쳤으면 되돌리고(git checkout -- <파일>) 내용은 submission/<같은 경로>에 쓴다
ORIG=docs/TASK-ORIGINALS.sha256
if [ -f "$ORIG" ]; then
  if command -v sha256sum >/dev/null 2>&1; then H="sha256sum"; else H="shasum -a 256"; fi
  changed="$($H -c "$ORIG" 2>/dev/null | grep -v ': OK$' | sed 's/: .*$//' | tr '\n' ' ')"
  [ -n "$changed" ] && miss "과제 원본 파일이 바뀜: ${changed}— git checkout -- <파일>로 되돌리고, 제출할 내용은 submission/<같은 경로> 복사본에 쓴다"
else
  echo "경고(멈추지 않음): $ORIG 없음 — 과제 원본 보존을 확인할 수 없다(S0 init-docs.sh가 만든다)"
fi

if [ "$FAIL" -eq 0 ] && [ "$NOEXEC" -eq 1 ]; then
  echo "실행 불가: $STAGE 진입 판정 중 node 스크립트(check-req·check-work)를 돌리지 못했다 — 통과 아님. node를 설치하거나 같은 점검을 손으로 보고 STATE에 남긴 뒤 사람에게 진행 여부를 묻는다(KR-107)"
  exit 3
fi
if [ "$FAIL" -eq 0 ]; then
  echo "통과: $STAGE 진입 조건"
  exit 0
fi
exit 1
