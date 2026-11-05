// check-req.mjs·check-work.mjs가 같이 쓰는 문서 읽기 도구. 의존성 없음(Node 18+).
// 양식 문구(절 제목 "## …", 표 열 순서)에 기대어 읽는다 — 양식을 바꾸면 이 파일과 두 스크립트를 같이 고친다.
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

// 파일 본문(LF로 맞춤). 없으면 빈 문자열
export const read = f => (existsSync(f) ? readFileSync(f, 'utf8').replace(/\r\n/g, '\n') : '');
// HTML 주석(여러 줄 포함)을 지운다
export const noComment = t => t.replace(/<!--[\s\S]*?(-->|$)/g, '');
// "## 제목"으로 시작하는 줄 다음부터 다음 "## " 줄 전까지("### "는 안에 포함). 주석은 지운다
export function section(text, title) {
  const lines = noComment(text).split('\n');
  const i = lines.findIndex(l => l.startsWith(`## ${title}`));
  if (i < 0) return '';
  const out = [];
  for (const l of lines.slice(i + 1)) { if (/^## /.test(l)) break; out.push(l); }
  return out.join('\n');
}
// 표 행 → 칸 배열(앞뒤 공백 제거). awk -F'|'의 $2가 c[0]이다. 구분선 행은 뺀다
export const tableRows = text => text.split('\n')
  .filter(l => /^\|/.test(l) && !/^\|[-:\s|]+$/.test(l))
  .map(l => { const p = l.split('|'); return p.slice(1, p.length > 2 ? -1 : undefined).map(c => c.trim()); });
// "- 이름: 값" 줄의 값(주석·백틱 제거)
export function field(text, name) {
  const l = noComment(text).split('\n').find(x => x.startsWith(`- ${name}:`));
  return l === undefined ? '' : l.slice(name.length + 3).replace(/`/g, '').trim();
}
// 설계 ID·요구 ID 같은 토큰이 들어 있는가(대소문자 무시, 영숫자·하이픈 경계)
export const hasTok = (s, id) => ` ${String(s).toLowerCase().replace(/[^a-z0-9-]+/g, ' ')} `.includes(` ${id.toLowerCase()} `);
export const tokens = s => String(s).split(/[^A-Za-z0-9-]+/).filter(Boolean);

// 숫자 토큰(KR-154·157): 설계 ID(C1·T-01·P2·S4)·#n은 지우고, 1,000 → 1000, 09:00 → 9:00.
// 단위 = 바로 뒤 영문·% 묶음 또는 한글 한 글자. 결과 [{ n: '45', u: '명' }, …]
export function numUnits(s) {
  s = String(s).replace(/#\d+/g, ' ').replace(/[A-Za-z]+-?\d+/g, ' ').replace(/(\d),(?=\d{3})/g, '$1');
  const out = [];
  for (const m of s.matchAll(/\d+(?:[.:]\d+)?/g)) {
    const rest = s.slice(m.index + m[0].length);
    const u = (rest.match(/^[A-Za-z%]+/) || [''])[0] || (/^[가-힣]/.test(rest) ? rest[0] : '');
    out.push({ n: m[0].replace(/^0+(?=\d)/, ''), u });
  }
  return out;
}
export const nums = s => numUnits(s).map(x => x.n);

// 줄 머리(정규식)가 맞는 첫 줄을 바꿔 쓴다. 없으면 after(정규식) 줄 다음에 넣고, after가 null이면 1행 다음에 넣는다. 못 넣으면 false
export function rewriteLine(file, head, line, after = null) {
  const lines = readFileSync(file, 'utf8').split('\n');
  let i = lines.findIndex(l => head.test(l));
  if (i >= 0) lines[i] = line;
  else if (after) { i = lines.findIndex(l => after.test(l)); if (i < 0) return false; lines.splice(i + 1, 0, line); }
  else lines.splice(1, 0, line);
  writeFileSync(file, lines.join('\n'));
  return true;
}

// 작업 폴더 파일(키트·기록·데이터·의존성 폴더 밖). kind: 'test' | 'code'
const TOP_SKIP = new Set(['docs', 'fde-kit', '.agents', '.claude', '.git', 'data', 'submission']);
const ANY_SKIP = new Set(['node_modules', '.venv', '__pycache__', 'dist', 'build']);
const CODE_EXT = /\.(js|mjs|cjs|ts|tsx|jsx|py|json|ya?ml|toml|html|vue|svelte|go|java|kt|rb|php|rs|sh|sql|ini|cfg)$/;
export const isTestPath = p => /(^|\/)(tests?|__tests__)\//.test(p) || /(^|\/)test_[^/]*$/.test(p) || /_test\.[A-Za-z]+$/.test(p) || /\.(test|spec)\.[A-Za-z]+$/.test(p);
export function workFiles(kind, root = '.') {
  const out = [];
  const walk = (d, rel) => {
    let names; try { names = readdirSync(d); } catch { return; }
    for (const f of names) {
      if ((!rel && TOP_SKIP.has(f)) || ANY_SKIP.has(f)) continue;
      const p = join(d, f), r = rel ? `${rel}/${f}` : f;
      let st; try { st = statSync(p); } catch { continue; }
      if (st.isDirectory()) walk(p, r);
      else if (kind === 'test' ? isTestPath(r) : (!isTestPath(r) && f !== 'package-lock.json' && CODE_EXT.test(f))) out.push(r);
    }
  };
  walk(root, '');
  return out;
}

// 명령 실행(작업 폴더 루트, 300초 상한). { code, out }
// NODE_TEST_CONTEXT는 넘기지 않는다 — node --test 안에서 부르면 하위 node --test가 실패를 부모에게만 보고하고 exit 0으로 끝난다
export function runCmd(cmd) {
  const env = { ...process.env }; delete env.NODE_TEST_CONTEXT;
  const r = spawnSync(cmd, { shell: true, env, encoding: 'utf8', timeout: 300000, maxBuffer: 32 << 20, windowsHide: true });
  return { code: r.status === null ? (r.error ? 127 : 124) : r.status, out: `${r.stdout || ''}${r.stderr || ''}${r.error ? `\n${r.error.message}` : ''}` };
}
export function git(args) {
  const r = spawnSync('git', args, { encoding: 'utf8', windowsHide: true });
  return r.error ? null : { code: r.status, out: r.stdout || '' };
}
