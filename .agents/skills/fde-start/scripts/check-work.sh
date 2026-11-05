#!/usr/bin/env bash
# 설계·구현·검증 산출물 점검(design|build|verify) — 판정은 check-work.mjs(Node 18+, 의존성 없음)가 한다. 이 파일은 인자를 그대로 넘기는 얇은 래퍼다.
# 사용(작업 폴더 루트): bash .agents/skills/fde-start/scripts/check-work.sh <모드>  — 모드·출력·종료 코드는 check-work.mjs 머리말
# node가 없으면 "실행 불가"로 알리고 exit 3 — 통과로 치지 않는다(KR-107·KR-164). 같은 점검을 손으로 본 결과를 STATE에 남기고 사람에게 묻는다.
if ! command -v node >/dev/null 2>&1; then
  echo "실행 불가 — node 없음: check-work.mjs를 돌릴 수 없다(통과 아님). 과제 런타임으로 node를 설치하거나, 같은 점검을 손으로 보고 STATE에 남긴 뒤 사람에게 진행 여부를 묻는다(KR-107)" >&2
  exit 3
fi
exec node "$(dirname "$0")/check-work.mjs" "$@"
