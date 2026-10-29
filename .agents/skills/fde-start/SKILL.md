---
name: fde-start
description: FDE 과제 착수(S0). 과제 README를 읽고 docs/ 작업 문서 양식과 .gitignore를 준비하고, 런타임·OpenAI 환경변수 존재·필수 제출 파일명을 확인한다. 과제를 처음 받았을 때 사용. 코드는 쓰지 않는다.
---

# S0 착수 (0–12분)

코드는 쓰지 않는다. 환경과 과제를 정확히 파악하는 것이 목적이다.

## 절차
1. 작업 폴더 루트에서 `bash .agents/skills/fde-start/scripts/init-docs.sh` 실행.
2. 루트 README(과제 안내)를 읽고 `docs/STATE.md`의 "과제 요약"을 채운다.
   - 현업 요청 원문은 그대로 인용
   - **필수 제출물·필수 파일명·필수 문서**(계획 문서, 협업 기록 등)를 목록으로 — 과제마다 다르므로 README 원문 그대로
   - 필수 요구 / 열린 결정(정해지지 않은 것) 구분
   - 실행 환경 제약(포트, 언어, OpenAI 사용 방식)
3. 환경 확인 (값은 절대 출력하지 않는다):
   - `node --version; python3 --version; java -version 2>&1 | head -1`
   - `python3 .agents/skills/fde-start/scripts/check-openai.py` (openai 패키지가 없으면 `pip install openai` 후)
4. 첫 커밋: `[S0] chore: 작업 문서 준비 및 과제 요약` (키트 출처 URL을 커밋 본문에 적는다)

## 보고
- 필수 제출물 목록, 열린 결정 3개 이내, 사람이 놓치기 쉬운 README 제약 3개.
- 끝나면 "다음: 담당자 인터뷰(fde-interview)"라고 알린다.
