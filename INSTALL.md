# 당일 설치 (A안: 공개 저장소 clone) — 2분

이 저장소는 **과정용 스킬·문서 양식만** 담고 있고, 과제 결과물(앱 코드)은 없다.

## 순서 (작업 시작 직후, 터미널 1번 탭)
```bash
cd ~/workspace                      # 과제 작업 폴더 (첫 화면 터미널 경로 확인)
git clone --depth 1 --branch v1 https://github.com/cvivis/fde-kit /tmp/fde-kit
bash /tmp/fde-kit/scripts/install.sh
codex                               # 신뢰 확인 → 작업 폴더 맞는지 확인
```
Codex 안에서:
```
/status        # 모델·권한 확인
/model         # 모델 선택
$fde-start     # S0 시작
```
Codex가 S0을 도는 동안 사람은 과제 지문을 정독한다(루트에 없을 수 있다 — `find . -iname 'README*'`).

`install.sh`가 하는 일: 스킬을 `.agents/skills/`와 `.codex/skills/` **두 곳**에 깔고,
`AGENTS.md`를 두고(기존 파일이 있으면 덧붙임), **인식되어야 하는 스킬 이름 8개를 출력**한다.
`.git`은 복사하지 않는다. Claude Code용은 `--target claude`(`CLAUDE.md` + `.claude/skills/`).

## 확인 (clone 직후 10초)
clone 직후 **"You are in 'detached HEAD' state"** 안내가 10줄쯤 나오는 것은 **정상**이다
(태그를 지정해 받았기 때문). 실패가 아니므로 무시하고 아래만 확인한다.
```bash
ls /tmp/fde-kit                     # AGENTS.md, .agents, INSTALL.md 등이 보여야 한다
ls .agents/skills                   # fde-* 8개
git -C /tmp/fde-kit rev-parse --short HEAD   # 첫 커밋 본문에 적을 SHA
```
Codex에서 `$`를 눌러 `install.sh`가 출력한 **8개 이름이 목록에 뜨는지** 본다.

## 스킬이 인식되지 않을 때 — 4단 분기

**사전 체험에서 어느 상태인지 미리 확정해 둔다. 당일에는 판단하지 않고 분기만 실행한다.**

| 상태 | 확인 방법 | 당일 행동 |
|---|---|---|
| **A. 인식됨** | `$` 목록에 `$fde-start`가 보인다 | 그대로 진행 |
| **B. 한쪽 경로만 먹었다** | 한 경로만 인식된다 | 인식된 경로만 남기고 나머지는 `rm -rf`, 진행 |
| **C. 미인식, 파일은 있다** | `cat .agents/skills/fde-start/SKILL.md` 성공 | **아래 C안.** 키트의 90%가 살아난다 |
| **D. clone 자체 불가** | `git clone`이 실패 | **B안**: `BOOTSTRAP.md`를 외워서 입력 |

### C안 — 스킬 메커니즘 없이 파일을 직접 읽힌다

Codex에 그대로 입력한다. 외우지 않아도 되게 짧게 썼다.
```
.agents/skills/ 아래 SKILL.md 목록을 보여줘. 앞으로 내가 "S1 해"라고 하면
해당 단계 SKILL.md 하나만 읽고 그 절차를 그대로 수행해. 다른 단계 파일은 읽지 마.
```
마지막 문장이 중요하다 — 스킬 메커니즘이 주던 **"해당 단계 것만 읽기"** 토큰 절약을 복원한다.

단계 호출은 `$fde-start` 대신 **"S0 해" / "S1 해" / … / "S7 해"**로 한다.
`docs/DECISIONS.md`에 한 줄 남긴다: "스킬 디스커버리 미지원 → 파일 직접 참조로 전환."

## 주의
- 첫 커밋 본문에 키트 출처를 남긴다(투명성):
  `키트 출처: https://github.com/cvivis/fde-kit @v1 (<SHA 7자리>) — 과정용 스킬·문서 양식만, 앱 코드 없음`
- 대회 전날 밤 이후로는 저장소를 수정하지 않는다. `--branch v1`로 받으므로 이후 변경은 당일 결과에
  영향이 없다.
- 규칙 파일은 작업 폴더에 **하나만** 둔다(`AGENTS.md` 또는 `CLAUDE.md`). 둘 다 있으면
  `install.sh`가 경고한다. 대회 환경은 Codex 전용이다.
