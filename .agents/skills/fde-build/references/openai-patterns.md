# OpenAI 호출 패턴

원칙: 키와 URL은 환경변수(`OPENAI_API_KEY`, `OPENAI_BASE_URL`)에서 SDK가 자동으로 읽게 둔다. 코드에 쓰지 않는다.
모델 이름은 `python3 .agents/skills/fde-start/scripts/check-openai.py` 결과에서 고른다. API 사용법이 헷갈리면 Codex는 내장 `$openai-docs` 스킬로 확인하고, Claude Code는 이 파일의 패턴과 설치된 SDK 소스(`pip show -f openai`, `node_modules/openai`)만 본다(외부 브라우저·외부 AI 사용 금지).

서버 바인딩: FastAPI `uvicorn app:app --host 0.0.0.0 --port 8000` / Express `app.listen(3000, '0.0.0.0')` / Vite `vite --host 0.0.0.0` / Spring Boot `server.address=0.0.0.0`

---

## 1. 음성 → 텍스트 (STT)

### Python (FastAPI)
```python
from openai import OpenAI
from fastapi import UploadFile

client = OpenAI()  # 환경변수 자동 사용

async def transcribe(file: UploadFile) -> str:
    data = await file.read()
    result = client.audio.transcriptions.create(
        model=STT_MODEL,                      # 예: "whisper-1" 또는 환경에서 확인한 모델
        file=(file.filename or "answer.webm", data),
        language="ko",                        # 다국어면 생략
    )
    return result.text
```

### Node (Express + multer)
```js
import OpenAI, { toFile } from "openai";
const client = new OpenAI(); // 환경변수 자동 사용

export async function transcribe(buffer, filename = "answer.webm") {
  const result = await client.audio.transcriptions.create({
    model: STT_MODEL,
    file: await toFile(buffer, filename),
    language: "ko",
  });
  return result.text;
}
```

---

## 2. 텍스트 → 구조화된 피드백 (JSON 스키마)

판정·점수는 고정 코드로, LLM은 "해석과 문장"만. 결과는 스키마로 받는다.

### 현업의 기준·어조를 넣는 자리 (중요)

프롬프트는 **빈 틀**이고, 내용은 인터뷰에서 받은 3층(L1 기준 / L2 순서 / L3 문장)으로 채운다.
추출 절차: `.agents/skills/fde-interview/references/expertise-extraction.md`

```
system: 너는 <담당자 역할>이다.
        기준: {L1 원문}
        방식: {L2 순서·개수}  — 이 순서와 개수를 벗어나지 마라.
        어조 예시: {L3 문장 2~3개}
        기준에 없는 평가는 하지 마라.
        숫자 지표는 이미 계산되어 주어지므로 다시 계산하지 마라.
user:   입력: {사용자 입력}
        지표(고정 코드 계산): {이름: 값, …}
```

**마지막 두 줄이 핵심이다.** 지표를 주되 재계산을 금지하면 LLM은 숫자를 사실로 받아들여 문장만
만든다. 숫자 출처가 하나로 고정되고, 화면의 숫자와 설명 문장이 어긋나는 사고가 사라진다.

**스키마 필드 순서 = L2 순서.** "좋은 점 먼저, 고칠 것 하나"를 들었으면 `strengths`가 먼저,
`improvements`는 `maxItems: 1`이다. 순서·개수를 스키마로 강제하는 것이 프롬프트로 부탁하는 것보다
안정적이다.

프롬프트에 넣은 담당자 문장은 **출처를 `docs/DECISIONS.md`에 남긴다**(어느 질문의 답인지).

### Python
```python
import json

FEEDBACK_SCHEMA = {
    "type": "object",
    "properties": {
        "strengths": {"type": "array", "items": {"type": "string"}},
        "improvements": {"type": "array", "items": {"type": "string"}},
        "next_try_tip": {"type": "string"},
    },
    "required": ["strengths", "improvements", "next_try_tip"],
    "additionalProperties": False,
}

def feedback(question: str, answer: str, criteria: str) -> dict | None:
    resp = client.chat.completions.create(
        model=LLM_MODEL,
        messages=[
            {"role": "system", "content": f"너는 인터뷰 코치다. 기준:\n{criteria}\n기준에 없는 평가는 하지 마."},
            {"role": "user", "content": f"질문: {question}\n답변: {answer}"},
        ],
        response_format={
            "type": "json_schema",
            "json_schema": {"name": "feedback", "schema": FEEDBACK_SCHEMA, "strict": True},
        },
    )
    try:
        return json.loads(resp.choices[0].message.content)
    except (json.JSONDecodeError, TypeError):
        return None  # 화면에는 "피드백을 만들지 못했어요. 다시 시도" 표시
```

### Node
```js
const resp = await client.chat.completions.create({
  model: LLM_MODEL,
  messages: [
    { role: "system", content: `너는 인터뷰 코치다. 기준:\n${criteria}\n기준에 없는 평가는 하지 마.` },
    { role: "user", content: `질문: ${question}\n답변: ${answer}` },
  ],
  response_format: {
    type: "json_schema",
    json_schema: { name: "feedback", schema: FEEDBACK_SCHEMA, strict: true },
  },
});
let fb = null;
try { fb = JSON.parse(resp.choices[0].message.content); } catch { /* fallback UI */ }
```

> 환경의 프록시가 `json_schema`를 지원하지 않으면 `response_format: { type: "json_object" }` 로 바꾸고 프롬프트에 JSON 형식을 명시한 뒤, 파싱 후 필수 키를 코드로 검사한다.

---

## 3. 결정론 지표 예시 (LLM 없이 고정 코드로)

텍스트와 녹음 길이만으로 계산 가능한 것은 코드로 한다. 재현 가능하고 설명하기 쉽다.
```python
FILLERS = ["음", "어", "그", "약간", "뭔가", "이제"]

def metrics(text: str, duration_sec: float) -> dict:
    words = text.split()
    filler_count = sum(text.count(f + " ") for f in FILLERS)
    return {
        "duration_sec": round(duration_sec, 1),
        "chars_per_min": round(len(text.replace(" ", "")) / max(duration_sec / 60, 0.01)),
        "filler_count": filler_count,
        "word_count": len(words),
    }
```
(지표 종류와 기준값은 S1에서 들은 현업 기준에 맞춰 바꾼다.)

---

## 4. 브라우저 녹음 (MediaRecorder)

```html
<button id="rec">녹음 시작</button>
<script>
let recorder, chunks = [], startedAt = 0;
const btn = document.getElementById("rec");

btn.onclick = async () => {
  if (recorder && recorder.state === "recording") { recorder.stop(); return; }
  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  recorder = new MediaRecorder(stream);
  chunks = [];
  recorder.ondataavailable = e => chunks.push(e.data);
  recorder.onstop = async () => {
    stream.getTracks().forEach(t => t.stop());
    const blob = new Blob(chunks, { type: recorder.mimeType || "audio/webm" });
    const form = new FormData();
    form.append("audio", blob, "answer.webm");
    form.append("duration", ((Date.now() - startedAt) / 1000).toString());
    btn.disabled = true; btn.textContent = "분석 중…";
    const res = await fetch("/api/answer", { method: "POST", body: form });
    // 결과 표시 …
    btn.disabled = false; btn.textContent = "녹음 시작";
  };
  startedAt = Date.now();
  recorder.start();
  btn.textContent = "녹음 끝내기";
};
</script>
```
주의: 마이크 권한은 HTTPS 또는 localhost에서만 허용된다. 작업 환경의 브라우저 미리보기에서 권한 요청이 뜨는지 미리 확인하고, 안 되면 **텍스트 입력** 또는 오디오 파일 선택(`<input type="file" accept="audio/*">`)을 대체 경로로 둔다.
