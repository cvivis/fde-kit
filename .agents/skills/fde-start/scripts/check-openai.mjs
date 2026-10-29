// OpenAI 연결 확인: 환경변수 존재, 모델 목록. 값은 출력하지 않는다.
// 사용: node kit/scripts/check-openai.mjs   (npm i openai 필요)
for (const key of ["OPENAI_API_KEY", "OPENAI_BASE_URL"]) {
  console.log(`${key}: ${process.env[key] ? "설정됨" : "없음"}`);
}

const { default: OpenAI } = await import("openai").catch(() => {
  console.error("openai 패키지 없음: npm i openai");
  process.exit(1);
});

const client = new OpenAI();
try {
  const ids = [];
  for await (const m of client.models.list()) ids.push(m.id);
  ids.sort();
  console.log(`사용 가능한 모델 ${ids.length}개:`);
  ids.forEach((id) => console.log("  -", id));
} catch (e) {
  console.log("모델 목록 조회 실패:", e.name, e.message);
}
