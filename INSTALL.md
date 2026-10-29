# 당일 설치 (A안: 공개 저장소 clone) — 2분

이 저장소는 **과정용 스킬·문서 양식만** 담고 있고, 과제 결과물(앱 코드)은 없다.

## 순서 (작업 시작 직후, 터미널 1번 탭)
```bash
cd ~/workspace                      # 과제 작업 폴더 (첫 화면 터미널 경로 확인)
git clone --depth 1 --branch v1 https://github.com/cvivis/fde-kit /tmp/fde-kit
cp -r /tmp/fde-kit/.agents .
[ -f AGENTS.md ] && cat /tmp/fde-kit/AGENTS.md >> AGENTS.md || cp /tmp/fde-kit/AGENTS.md .
codex                               # 신뢰 확인 → 작업 폴더 맞는지 확인
```
Codex 안에서:
```
/status        # 모델·권한 확인
/model         # 모델 선택 
$fde-start     # S0 시작
```
Codex가 S0을 도는 동안 사람은 과제 지문을 정독한다(루트에 없을 수 있다 — `find . -iname 'README*'`).

## 확인 (clone 직후 10초)
clone 직후 **"You are in 'detached HEAD' state"** 안내가 10줄쯤 나오는 것은 **정상**이다
(태그를 지정해 받았기 때문). 실패가 아니므로 무시하고 아래만 확인한다.
```bash
ls /tmp/fde-kit                     # AGENTS.md, .agents, INSTALL.md 등이 보여야 한다
ls .agents/skills                   # fde-* 8개
git -C /tmp/fde-kit rev-parse --short HEAD   # 첫 커밋 본문에 적을 SHA
```
Codex에서 `$`를 눌러 `$fde-start`가 목록에 뜨는지 본다. **안 뜨면 아래 분기.**

| 상태 | 당일 행동 |
|---|---|
| `$fde-start` 인식됨 | 그대로 진행 |
| 스킬 미인식, 파일은 있음 | **C안**: "`.agents/skills/fde-start/SKILL.md`를 읽고 그 절차대로 진행해. 다른 단계 파일은 읽지 마." 이후 단계마다 같은 식으로 호출 |
| clone 자체 불가 | **B안**: `BOOTSTRAP.md`의 프롬프트를 직접 입력 |

사전 체험에서 어느 상태인지 **미리 확정해 둔다**. 당일에 판단하지 않는다.

## 주의
- `/tmp/fde-kit`의 `.git`은 작업 폴더로 복사하지 않는다(위 명령은 `.agents`와 `AGENTS.md`만).
- 첫 커밋 본문에 키트 출처를 남긴다(투명성):
  `키트 출처: https://github.com/cvivis/fde-kit @v1 (<SHA 7자리>) — 과정용 스킬·문서 양식만, 앱 코드 없음`
- 대회 전날 밤 이후로는 저장소를 수정하지 않는다. `--branch v1`로 clone하므로 이후 변경은 당일 결과에 영향이 없다.
- Claude Code용으로 쓸 때는 `AGENTS.md`를 `CLAUDE.md`로, `.agents/skills/`를 `.claude/skills/`로 복사한다.
  **둘을 같이 두지 않는다**(어느 쪽이 읽히는지 불확실해진다). 대회 환경은 Codex 전용이다.
