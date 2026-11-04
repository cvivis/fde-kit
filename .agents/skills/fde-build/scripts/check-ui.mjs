#!/usr/bin/env node
// 화면 점검(KR-100): 화면이 "뜨는지"를 구현 항목 완료 전에 확인한다. 의존성 없음(Node 18+).
//   node .agents/skills/fde-build/scripts/check-ui.mjs [화면 폴더 또는 파일 ...] [--url http://127.0.0.1:8000/]
//   폴더를 주지 않으면 작업 폴더에서 화면 파일(.html, 화면 폴더의 .js)을 찾는다(node_modules·.git·docs·fde-kit·.agents 제외).
// 하는 일:
//   1) .html 안 인라인 <script>(src 없는 것, type=module 제외)와 화면용 .js(import/export 없는 것)를 구문 검사한다.
//   2) --url이 있으면 그 주소를 GET 해서 200인지, 받은 HTML의 인라인 스크립트도 구문이 맞는지 본다.
// 출력: "검사 n개 파일·스크립트 k개 / 오류 m건". 검사 0개면 실패(검증 0건은 통과가 아니다).
// 종료 코드: 0 통과 / 1 오류 있음 또는 검사 0개 / 2 사용법 오류
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative, extname } from 'node:path';

const args = process.argv.slice(2);
const ui = i => args[i];
let url = null; const targets = [];
for (let i = 0; i < args.length; i++) { if (args[i] === '--url') { url = ui(++i); if (!url) { console.error('사용: --url <주소>'); process.exit(2); } } else targets.push(args[i]); }

const SKIP = /(^|[\\/])(node_modules|\.git|docs|fde-kit|\.agents|\.claude|dist|build|coverage|tests?|__tests__)([\\/]|$)/;
const UIDIR = /(^|[\\/])(public|web|static|client|frontend|ui|www|templates|views)([\\/]|$)/;
const files = [];
const walk = d => { for (const f of readdirSync(d)) { const p = join(d, f); if (SKIP.test(relative('.', p))) continue; const s = statSync(p); if (s.isDirectory()) walk(p); else files.push(p); } };
if (!targets.length) walk('.');
else for (const t of targets) { if (!existsSync(t)) { console.error(`없음: ${t}`); process.exit(2); } statSync(t).isDirectory() ? walk(t) : files.push(t); }

const inline = html => [...html.matchAll(/<script(?![^>]*\bsrc=)(?![^>]*type=["']module)[^>]*>([\s\S]*?)<\/script>/gi)].map(m => m[1]);
const check = (code, where, errors) => { try { new Function(code); } catch (e) { errors.push(`${where}: ${e.message}`); } };

const errors = []; let nFiles = 0, nScripts = 0;
for (const f of files) {
  const ext = extname(f).toLowerCase();
  if (ext === '.html' || ext === '.htm') {
    const blocks = inline(readFileSync(f, 'utf8'));
    nFiles++; blocks.forEach((b, i) => { nScripts++; check(b, `${relative('.', f)} script ${i + 1}`, errors); });
  } else if ((ext === '.js') && (targets.length || UIDIR.test(relative('.', f)))) {
    const code = readFileSync(f, 'utf8');
    if (/^\s*(import|export)\b/m.test(code)) continue;   // 모듈 문법은 이 검사 대상 밖(번들러·브라우저가 판단)
    nFiles++; nScripts++; check(code, relative('.', f), errors);
  }
}

if (url) {
  try {
    const res = await fetch(url);
    const body = await res.text();
    if (res.status !== 200) errors.push(`${url}: HTTP ${res.status}`);
    nFiles++; inline(body).forEach((b, i) => { nScripts++; check(b, `${url} script ${i + 1}`, errors); });
  } catch (e) { errors.push(`${url}: 접속 실패 — ${e.message}`); }
}

console.log(`검사 ${nFiles}개 파일·스크립트 ${nScripts}개 / 오류 ${errors.length}건`);
for (const e of errors) console.log(`  오류: ${e}`);
if (!nFiles) { console.log('검사 0개 — 화면 파일을 못 찾았다. 화면 폴더를 인자로 준다(검증 0건은 통과가 아니다)'); process.exit(1); }
process.exit(errors.length ? 1 : 0);
