#!/usr/bin/env node
// 요구 문서 점검(KR-145·146·147·149·151·154·155): docs/REQ-TASK.md(지문 요구 T-ID)·docs/REQ-USER.md(얻은 요구 U-ID). 의존성 없음(Node 18+).
// 사용(작업 폴더 루트): node .agents/skills/fde-start/scripts/check-req.mjs count|links|verify   (check-req.sh도 이것을 부른다)
//   count  — 표를 다시 세어 두 문서 맨 위 "개수:" 줄과 STATE 기준판 "- 요구:" 줄을 고쳐 쓰고 한 줄 요약을 출력한다.
//            개수를 손으로 세거나 옮겨 적지 않는다.
//   links  — (S3 끝·S4 진입) 범위 "이번" 요구마다 "설계 연결" 칸에 설계 ID가 있고 그 ID가 실제로 있는지 본다.
//            설계 ID: STATE 작업 목록 T<n> · LOGIC 조건 C<n>·단계 P<n> · DECISIONS D<n> (요구 ID T-01·U-01·결정 C-01과 다르다)
//            거꾸로(KR-149): 작업 목록 항목·LOGIC 조건 행 중 범위 안 요구가 가리키지 않는 것을 "근거 없음(범위 밖)"으로,
//            요구 종류(반드시·점수·목표)와 연결된 LOGIC 조건 종류가 다르면 "해석 차이"로 알린다 — 둘 다 경고, 고칠지는 사람이 정한다.
//            숫자 대조(KR-154): 요구 원문의 숫자(단위 포함)가 연결된 LOGIC 조건 규칙 칸에 없으면 "숫자 불일치" — 반드시 요구면 막는다.
//            단위는 둘 다 있을 때만 비교한다(45명 ↔ 45건은 불일치, 45 ↔ 45명은 일치).
//   verify — (S4 끝·S6·S7) 범위 "이번" 요구마다 "구현 확인" 칸에 판정(충족/부분/미충족 — 근거)이 있는지 본다. 비면 미확인.
//            판정 근거(KR-155): 충족·부분은 "VERIFY <시각>"(그 시각 행이 VERIFY 첫 표에 있어야) 또는 "`명령` → 결과"가 없으면 미확인.
//            반드시 요구의 충족은 검사기 출력(검사 n(>0) · 위반 0)이 칸이나 가리킨 VERIFY 행에 있어야 한다.
//            코드 숫자(KR-154): 요구 숫자가 코드·설정 파일(테스트·docs·키트·data 밖)에 없으면 경고.
//   표 열 — REQ-TASK: | ID | 요구(지문 원문) | 우선 | 종류 | 범위 | 설계 연결 | 구현 확인 |
//           REQ-USER: | ID | 요구 | 출처 | 우선 | 종류 | 범위 | 설계 연결 | 구현 확인 |
//   개수 줄의 설계 연결 x/m = 범위 안 m개 중 설계 ID가 있고 모두 실제로 있는 요구, 구현 확인 y/m = 인정된 판정이 적힌 요구.
// 종료 코드: 0 통과 / 1 지문 요구 0건·범위 안 요구 0건(검증 0건은 실패)·문서 없음, links 누락·반드시 숫자 불일치, verify 미확인 / 2 사용법 오류
// 근거 없음·해석 차이·점수·목표 숫자 불일치·대조 불가·코드 숫자·제외 요구는 종료 코드에 영향 없음(경고).
import { existsSync, readFileSync } from 'node:fs';
import { read, section, tableRows, tokens, numUnits, rewriteLine, workFiles } from './doc-lib.mjs';

const MODE = process.argv[2] || '';
if (!['count', 'links', 'verify'].includes(MODE)) { console.error('사용: check-req.sh count|links|verify'); process.exit(2); }
const T = 'docs/REQ-TASK.md', U = 'docs/REQ-USER.md', S = 'docs/STATE.md', L = 'docs/LOGIC.md', D = 'docs/DECISIONS.md', V = 'docs/VERIFY.md';
for (const f of [T, U]) if (!existsSync(f)) { console.error(`없음: ${f} — S0(init-docs.sh)부터`); process.exit(1); }
const log = s => console.log(s);

// 실제로 있는 설계 항목: { id, kind(LOGIC 조건만), text }
//   작업 목록 "- [ ] T<n> …", LOGIC 조건 행(규칙 칸이 찬 것), 단계 행(하는 일 칸이 찬 것), DECISIONS "## D<n>. 제목"
const ITEMS = [];
for (const l of section(read(S), '작업 목록').split('\n')) {
  const m = l.match(/^- \[[ xX]\] (T\d+)(?:[^0-9]|$)/); if (m) ITEMS.push({ id: m[1], kind: '', text: l });
}
const logic = read(L);
const crules = {};  // C<n> → 규칙
for (const t of ['조건', '단계']) for (const c of tableRows(section(logic, t))) {
  if (/^C\d+$/.test(c[0]) && c[2]) { ITEMS.push({ id: c[0], kind: c[1] || '', text: `| ${c.join(' | ')} |` }); crules[c[0]] = c[2]; }
  else if (/^P\d+$/.test(c[0]) && c[1]) ITEMS.push({ id: c[0], kind: '', text: `| ${c.join(' | ')} |` });
}
for (const l of read(D).split('\n')) { const m = l.match(/^## (D\d+)\./); if (m && !l.includes('(제목)')) ITEMS.push({ id: m[1], kind: '', text: l }); }
const IDS = new Set(ITEMS.map(i => i.id));
const CKIND = {}; for (const i of ITEMS) if (/^C/.test(i.id) && i.kind && !(i.id in CKIND)) CKIND[i.id] = i.kind;

// VERIFY 첫 표 행: 시각(앞 0 뗌) → 행 글
const VT = {};
for (const c of tableRows(read(V))) if (/^\d?\d:\d\d$/.test(c[0])) { const t = c[0].replace(/^0/, ''); VT[t] = `${VT[t] || ''} ${c.join(' | ')}`; }

// 판정 근거(KR-155): 충족·부분은 VERIFY 시각 행 또는 `명령` → 결과. 반드시 충족은 검사기 출력
function judge(v, kind) {
  let vs = /미충족/.test(v) ? '미충족' : /부분/.test(v) ? '부분' : /충족/.test(v) ? '충족' : '미확인', why = '';
  if (vs === '충족' || vs === '부분') {
    let ev = v, ok = false;
    const m = v.match(/VERIFY\s*(\d?\d:\d\d)/);
    if (m) { const tm = m[1].replace(/^0/, ''); if (tm in VT) { ok = true; ev += VT[tm]; } else why = `VERIFY ${tm} 행 없음`; }
    else if (/`[^`]+`\s*[^\s`]/.test(v)) ok = true;
    else why = '근거 없음 — VERIFY <시각> 또는 `명령` → 결과';
    if (ok && vs === '충족' && kind === '반드시' && !(/검사\s*[1-9]/.test(ev) && /위반\s*0(?!\d)/.test(ev))) { ok = false; why = '반드시 충족 근거에 검사기 출력(검사 n · 위반 0) 없음'; }
    if (!ok) vs = '미확인';
  }
  return { vs, why };
}

// 표 행 → { id, pri, kind, scope, link, v, req, ls(연결 상태), vs(판정), why }
//   ID가 접두(T-/U-)+숫자이고 요구 칸이 찬 행만. 연결 상태: 연결 / 빈칸 / ID없음 / 없는ID:<ids>
// pc: 우선 칸, sc: 범위 칸(c 배열 번호 — 종류는 범위 앞, 설계 연결·구현 확인은 범위 다음 두 칸)
function rows(file, pre, pc, sc) {
  return tableRows(read(file)).filter(c => new RegExp(`^${pre}\\d+$`).test(c[0]) && c[1]).map(c => {
    const link = c[sc + 1] || '', v = c[sc + 2] || '', kind = c[sc - 1] || '';
    const ids = tokens(link).filter(t => /^[TCPD]\d+$/.test(t)), bad = ids.filter(t => !IDS.has(t));
    const ls = !link ? '빈칸' : !ids.length ? 'ID없음' : bad.length ? `없는ID:${bad.join(',')}` : '연결';
    return { id: c[0], pri: c[pc] || '', kind, scope: c[sc] || '', link, v, req: c[1], ls, ...judge(v, kind) };
  });
}
const tRows = rows(T, 'T-', 2, 4), uRows = rows(U, 'U-', 3, 5);
const inRows = [...tRows, ...uRows].filter(r => /^이번/.test(r.scope));

function tally(rs, keys) {
  const c = Object.fromEntries(keys.map(k => [k, 0])), bad = [];
  let ex = 0, m = 0, x = 0, y = 0, und = 0;
  for (const r of rs) {
    if (r.pri in c) c[r.pri]++; else { const n = r.pri || '(빈 칸)'; if (!bad.includes(n)) bad.push(n); }
    if (/^제외/.test(r.scope)) ex++;
    else if (/^이번/.test(r.scope)) { m++; if (r.ls === '연결') x++; if (r.vs !== '미확인') y++; }
    else if (!r.scope || /^미정/.test(r.scope)) und++;
  }
  const line = `총 ${rs.length}${keys.map(k => ` · ${k} ${c[k]}`).join('')} · 제외 ${ex} · 설계 연결 ${x}/${m} · 구현 확인 ${y}/${m}`;
  return { line, total: rs.length, c, ex, m, x, y, und, bad: bad.map(b => ` ${b}`).join('') };
}
const t = tally(tRows, ['필수', '권장']), u = tally(uRows, ['P0', 'P1', 'P2']);
rewriteLine(T, /^개수:/, `개수: ${t.line}`);
rewriteLine(U, /^개수:/, `개수: ${u.line}`);
const m = t.m + u.m, x = t.x + u.x, y = t.y + u.y;
const summary = `요구: 지문 ${t.total}(필수 ${t.c['필수']}·권장 ${t.c['권장']}) · 얻은 요구 ${u.total}(P0 ${u.c.P0}·P1 ${u.c.P1}·P2 ${u.c.P2}) · 제외 ${t.ex + u.ex} · 설계 연결 ${x}/${m} · 구현 확인 ${y}/${m}`;

// STATE 기준판 "- 요구:" 줄 — KR-151. 손으로 옮겨 적지 않는다(S0 뒤에 낡는다)
if (existsSync(S) && !rewriteLine(S, /^- 요구:/, `- ${summary} <!-- check-req.sh가 다시 쓴다 -->`, /^## 기준판/))
  log("경고(멈추지 않음): STATE에 '- 요구:' 줄과 '## 기준판' 절이 없어 요구 줄을 못 썼다");

if (MODE === 'count') {
  log(summary);
  if (t.bad) log(`경고(멈추지 않음): REQ-TASK 우선 칸이 필수/권장이 아님:${t.bad}`);
  if (u.bad) log(`경고(멈추지 않음): REQ-USER 우선 칸이 P0/P1/P2가 아님:${u.bad}`);
  if (t.und > 0) log(`경고(멈추지 않음): REQ-TASK 범위가 비었거나 미정 ${t.und}건 — 이번 또는 '제외 — 이유'로 적는다`);
  if (u.und > 0) log(`경고(멈추지 않음): REQ-USER 범위 미정 ${u.und}건 — S2 합의에서 이번/제외로 확정한다`);
  if (u.total === 0) log('경고(멈추지 않음): 얻은 요구 0건 — S1 인터뷰·지문 밖 입력·조사 결정에서 REQ-USER에 올린다(S3 진입 검사는 0건을 막는다 — 정말 없으면 "- 해당 없음 — 이유")');
}
if (t.total === 0) { console.error('실패: 지문 요구 0건 — 검증 0건은 실패. S0이 과제 지문의 요구를 REQ-TASK에 원문으로 옮긴다'); process.exit(1); }
if (MODE === 'count') process.exit(0);
if (m === 0) { console.error("실패: 범위 '이번' 요구 0건 — 검증할 요구가 없다(검증 0건은 실패). S2 합의에서 범위를 확정한다"); process.exit(1); }

// 거꾸로(KR-149): 작업 목록 항목(T<n>)·LOGIC 조건(C<n>) 중 범위 안 요구가 설계 연결로 가리키지 않고,
// 자기 줄에도 범위 안 요구 ID(T-01·U-01)가 없는 것 → 근거 없음(범위 밖). 경고만.
function reportOrphans() {
  const inIds = new Set(inRows.map(r => r.id));
  const linked = new Set(inRows.flatMap(r => tokens(r.link)).filter(k => /^[TC]\d+$/.test(k)));
  const seen = new Set(), o = [];
  for (const i of ITEMS) {
    if (!/^[TC]\d+$/.test(i.id) || linked.has(i.id)) continue;
    if (tokens(i.text).some(k => /^[TU]-\d+$/.test(k) && inIds.has(k))) continue;
    o.push({ id: i.id, body: i.text.replace(/^- \[[ xX]\] /, '').replace(/^[-|\s]+|[|\s]+$/g, '') });
    seen.add(i.id);
  }
  if (!o.length) return log('근거 없음(범위 밖): 없음');
  log(`근거 없음(범위 밖): ${o.map(i => i.id).join(', ')} — 범위 안 요구 ID가 가리키지 않는다. 요구에 잇기/빼기/그대로 두기는 사람이 정한다`);
  for (const i of o) log(`  - ${i.id} · ${i.body}`);
}

if (MODE === 'links') {
  const miss = inRows.filter(r => r.ls !== '연결');
  log(`설계 연결: 요구 ${m}개 중 설계 연결 ${x}개, 누락: ${miss.map(r => r.id).join(', ') || '없음'}`);
  for (const r of miss) {
    const why = r.ls === '빈칸' ? '설계 연결 칸 빈칸' : r.ls === 'ID없음' ? `설계 ID(T<n>·C<n>·P<n>·D<n>) 없음: ${r.link}` : `없는 ID ${r.ls.replace(/^없는ID:/, '')} — STATE 작업 목록·LOGIC·DECISIONS에 없다`;
    log(`  - ${r.id} [${r.pri}·${r.kind}] ${why} — "${r.req}"`);
  }
  // 해석 차이: 요구 종류(반드시·점수·목표)와 연결된 LOGIC 조건 종류가 다르다(예: 점수를 반드시로) — 경고
  for (const r of inRows) if (/^(반드시|점수|목표)$/.test(r.kind))
    for (const k of tokens(r.link)) if (/^C\d+$/.test(k) && k in CKIND && CKIND[k] !== r.kind) log(`해석 차이(사람이 판단): ${r.id} 종류 ${r.kind} → ${k} ${CKIND[k]} — "${r.req}"`);
  // 숫자 대조(KR-154)
  let withNum = 0, ok = 0; const bad = [], nolink = [];
  for (const r of inRows) {
    const want = numUnits(r.req); if (!want.length) continue;
    withNum++;
    const cs = tokens(r.link).filter(k => /^C\d+$/.test(k) && k in crules);
    if (!cs.length) { if (/^(반드시|점수|목표)$/.test(r.kind)) nolink.push(r); continue; }
    const have = cs.flatMap(k => numUnits(crules[k]));
    const miss = [...new Set(want.filter(w => !have.some(h => h.n === w.n && (!w.u || !h.u || w.u === h.u))).map(w => w.n + w.u))];
    if (!miss.length) { ok++; continue; }
    bad.push({ r, miss, rules: cs.map(k => `${k} "${crules[k]}"`).join(' / ') });
  }
  log(`숫자 대조: 숫자 있는 요구 ${withNum}개 중 일치 ${ok}개, 불일치: ${bad.map(b => b.r.id).join(', ') || '없음'}${nolink.length ? `, 대조 불가(연결된 LOGIC 조건 없음): ${nolink.map(r => r.id).join(', ')}` : ''}`);
  for (const b of bad) log(`  - 숫자 불일치: ${b.r.id} [${b.r.kind}] 요구 ${b.miss.join(', ')} → ${b.rules}에 없음 — "${b.r.req}"`);
  for (const r of nolink) log(`  - 대조 불가: ${r.id} [${r.kind}] 숫자가 있는데 설계 연결에 LOGIC 조건(C<n>)이 없다 — "${r.req}"`);
  const mustBad = bad.filter(b => b.r.kind === '반드시').map(b => b.r.id);
  if (mustBad.length) log(`실패: 반드시 요구 ${mustBad.join(' ')} 숫자가 연결된 LOGIC 조건 규칙과 다르다 — 요구 원문 숫자·단위 그대로 규칙에 적거나, 바꿨으면 담당자 확인 뒤 요구를 다시 합의한다`);
  reportOrphans();
  process.exit(miss.length || mustBad.length ? 1 : 0);
}

// verify
const miss = inRows.filter(r => r.vs === '미확인');
const cnt = v => inRows.filter(r => r.vs === v).length;
log(`구현 확인: 요구 ${m}개 중 구현 확인 ${y}개(충족 ${cnt('충족')} · 부분 ${cnt('부분')} · 미충족 ${cnt('미충족')}), 미확인: ${miss.map(r => r.id).join(', ') || '없음'}`);
for (const r of miss) log(`  - ${r.id} [${r.pri}·${r.kind}] 미확인${r.why ? `(${r.why})` : ''} — "${r.req}"${r.link ? ` (설계 연결 ${r.link})` : ''}`);
// 코드 숫자(KR-154): 범위 안 요구(제출 제외) 원문의 숫자가 코드·설정 파일에 있는가 — 경고만
const pairs = inRows.filter(r => r.kind !== '제출').map(r => ({ id: r.id, ns: [...new Set(numUnits(r.req).map(w => w.n))] })).filter(p => p.ns.length);
if (pairs.length) {
  const files = workFiles('code');
  if (!files.length) log('코드 숫자: 코드 파일 없음 — 대조 못 함');
  else {
    const texts = files.map(f => { try { return readFileSync(f, 'utf8'); } catch { return ''; } });
    const absent = pairs.map(p => ({ id: p.id, ns: p.ns.filter(n => { const re = new RegExp(`(^|[^0-9.])${n.replace(/\./g, '\\.')}(?![0-9])`); return !texts.some(tx => re.test(tx)); }) })).filter(p => p.ns.length);
    const list = absent.map(p => `${p.id}(${p.ns.join('·')})`).join(', ');
    log(`코드 숫자: 숫자 있는 요구 ${pairs.length}개 중 코드에 숫자가 모두 있음 ${pairs.length - absent.length}개, 없음: ${list || '없음'}`);
    if (list) log('경고(멈추지 않음): 요구 숫자가 코드·설정에 없다 — 상수·설정으로 그 값을 쓰는지 확인한다(환산했으면 VERIFY 해석 점검에 적는다)');
  }
}
reportOrphans();
process.exit(miss.length ? 1 : 0);
