# fde-kit — 현업 인터뷰형(FDE) 과제용 작업 키트

현업 담당자와 대화해 문제를 정의하고 제한 시간 안에 웹서비스를 만드는 유형의 과제를 위한
**공개 작업 절차 키트**입니다.
과제 결과물(앱 코드)은 포함하지 않으며, 단계별 절차·문서 양식·검증 스크립트·코드 패턴 참고 자료만 담고 있습니다.

## 구성
```
AGENTS.md                      에이전트 작업 규칙 (단계·사람 몫·원칙·금지·확인요청·출력 형식)
.agents/skills/
  fde-start/                   S0 착수: docs 양식 생성, 환경·필수 제출물 확인
  fde-interview/               S1 발굴: 인터뷰 정리, 다음 질문 제안 (+질문 뱅크)
  fde-agreement/               S2 합의: 한 줄 명세, 범위, 성공 기준, 확인 메시지
  fde-design/                  S3 설계: 고정 코드/LLM 분리, 결정 기록, 작업 목록
  fde-build/                   S4·S5 구현: 항목 하나씩 (+OpenAI·녹음 패턴)
  fde-verify/                  S6 검증: 합의 대조, 점검, 바인딩 확인 스크립트
  fde-handoff/                 세션 교체
  fde-submit/                  S7 제출 정리, 예상 질문
INSTALL.md                     작업 폴더에 설치하는 방법
BOOTSTRAP.md                   스킬을 못 쓸 때의 대체 경로 (C안·B안 + 단계별 한 줄 지시)
```

## 사용

과제 지문과 자료가 있는 작업 폴더에서 실행하세요.

```bash
git clone https://github.com/cvivis/fde-kit
codex
```

Codex에 입력하세요. 이미 clone했다면 이 지시부터 시작하면 됩니다.

```text
fde-kit/INSTALL.md를 읽고 현재 과제 폴더에 키트를 적용해 줘.
기존 과제 파일과 규칙은 보존하고, 설치 확인까지만 해.
```

Codex가 스킬과 작업 규칙을 작업 폴더에 배치합니다. 별도 설치 프로그램은 필요 없습니다.
설치 후 `$fde-start` 인식을 확인하고 S0을 시작하세요. 상세 절차와 실패 시 분기는 [INSTALL.md](INSTALL.md).

## 대상 에이전트
기본은 **Codex**(`AGENTS.md` + `.agents/skills/`)입니다.
Claude Code에서 쓸 때는 `AGENTS.md`를 `CLAUDE.md`로 복사하고, `.agents/skills/`는 **그대로 둔 채**
스킬 인식용으로 `.claude/skills/`에도 복사하세요(스크립트 경로가 `.agents/skills/` 기준이라 옮기면 깨집니다).
호출은 `$fde-start` 대신 `/fde-start`. 규칙 파일은 작업 폴더에 **하나만** 두세요. 절차는 [INSTALL.md](INSTALL.md) "Claude Code".

## 설계 원칙
- 문제 정의·범위·현업 합의는 사람이 한다. 에이전트는 합의 범위 안에서 설계 제안 → 구현 → 검증.
- 판정·계산·저장은 고정 코드(+최소 테스트), LLM은 해석·문장만.
- 증거 없는 "완료"는 없다. 모든 확인은 명령과 결과로 기록한다.
- 합의에 없는 기능은 만들지 않는다.

## License
MIT — `LICENSE` 참고.
