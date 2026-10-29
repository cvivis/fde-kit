#!/usr/bin/env bash
# 앱을 0.0.0.0으로 띄우고 응답을 확인한 뒤 docs/VERIFY.md에 한 줄 남긴다.
# 사용: START_CMD="npm start" PORT=3000 bash .agents/skills/fde-verify/scripts/verify.sh [경로]
# 이미 떠 있으면 새로 띄우지 않는다. 서버는 별도 터미널 탭에서 유지하는 것을 권장.
set -u
START_CMD="${START_CMD:?START_CMD 를 지정하세요. 예: START_CMD='uvicorn app:app --host 0.0.0.0 --port 8000'}"
PORT="${PORT:-3000}"
CHECK_PATH="${1:-/}"
LOG="${TMPDIR:-/tmp}/verify-app.log"

if curl -s -o /dev/null "http://127.0.0.1:${PORT}${CHECK_PATH}"; then
  echo "이미 ${PORT} 포트에서 실행 중 — 새로 띄우지 않음"
else
  echo "기동: ${START_CMD}"
  nohup bash -c "${START_CMD}" > "${LOG}" 2>&1 &
  for _ in $(seq 1 40); do
    curl -s -o /dev/null "http://127.0.0.1:${PORT}${CHECK_PATH}" && break
    sleep 1
  done
fi

CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}${CHECK_PATH}")
BIND=$( (ss -ltn 2>/dev/null || netstat -ltn 2>/dev/null) | grep ":${PORT} " | head -1)
echo "HTTP ${CODE} ← GET :${PORT}${CHECK_PATH}"
echo "LISTEN: ${BIND:-확인 불가}"
case "${BIND}" in *127.0.0.1:*|*"[::1]":*) echo "경고: localhost에만 바인딩됨 → Browser 미리보기에서 안 열릴 수 있음. 0.0.0.0으로 바꾸세요.";; esac

mkdir -p docs
[ -f docs/VERIFY.md ] || printf '# VERIFY\n\n| 시각 | 확인한 것 | 명령/방법 | 결과 |\n|---|---|---|---|\n' > docs/VERIFY.md
echo "| $(date +%H:%M) | 기동·응답 | GET :${PORT}${CHECK_PATH} | HTTP ${CODE} |" >> docs/VERIFY.md

if [ "${CODE}" != "200" ]; then
  echo "실패 — 서버 로그 마지막 20줄:"; tail -n 20 "${LOG}" 2>/dev/null
  exit 1
fi
