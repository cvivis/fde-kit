---
name: fde-handoff
description: 세션 교체 전 docs/HANDOFF.md를 작성하고 STATE를 갱신해 커밋한다. 정해진 시점(약 100분)이나 맥락이 무거워져 결정을 다시 묻거나 같은 설명이 반복될 때 사용. 새 세션은 이 문서부터 읽는다.
---

# 세션 교체

## 기존 세션에서
1. `docs/HANDOFF.md`를 양식대로 덮어쓴다.
   - 목표 한 줄, 실행 방법(명령·포트), **실제로 실행해서 확인한 것**과 **미확인** 구분
   - 내린 결정은 DECISIONS 번호만, 남은 일 순서, 알려진 위험
   - "다음 한 걸음": 새 세션이 첫 명령으로 바로 실행할 수 있게 구체적으로
2. `docs/STATE.md` 현재 단계·작업 목록 갱신.
3. 커밋: `[H] docs: handoff`
4. 사람에게 알린다: "새 세션을 열고(Codex `/new`, Claude Code `/clear`) 아래 첫 프롬프트를 입력하세요."

## 새 세션 첫 프롬프트
"AGENTS.md(Claude Code는 CLAUDE.md), docs/HANDOFF.md, docs/STATE.md 순서로 읽고 3줄로 요약해. 다음 한 걸음을 시작하기 전에 내 확인을 기다려."
