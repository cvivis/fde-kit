#!/usr/bin/env node
// 설계·구현·검증 산출물에서 셀 수 있는 점검(KR-156). 의존성 없음(Node 18+). AI는 문서를 다시 읽고 세지 않고 이 출력을 옮겨 적는다.
// 해석(넓힘·좁힘이 옳은가, 결과가 담당자의 일에 맞는가)은 보지 않는다 — 사람과 AI가 판단한다.
// 사용(작업 폴더 루트): node .agents/skills/fde-start/scripts/check-work.mjs design|build|verify   (check-work.sh도 이것을 부른다)
//   design — S3 끝(check-stage.sh S4가 부른다). 읽기만 한다.
//     출처 없는 숫자(KR-157): LOGIC 조건 규칙 칸의 숫자(0~5 제외)가 INTERVIEW·AGREEMENT 가정·제약·RESEARCH 사실·출발선·
//       라운드 기록·결정·REQ-TASK·REQ-USER·README.md 어디에도 없다. 반드시 조건이면 막고, 점수·목표는 경고
//     점수 조건의 숫자 한도(KR-119): 종류 점수인데 근거 칸이 가리키는 원문(INTERVIEW #n 답·T-/U-ID 요구·C-ID 원문)에 숫자가 있고
//       AGREEMENT 가정에 그 조건 ID가 없다 — 경고
//     위반 테스트 계획(KR-120): 반드시 조건마다 LOGIC 검사기 절 "위반 테스트" 표에 그 조건 행(어긴 입력 칸이 찬 것) — 경고
//     단계 표·예시(KR-158): 고르는 규칙 빈칸·"적절히", 손으로 따라가는 예시 없음 — 경고
//     DECISIONS·작업 목록(KR-159): 결정마다 5줄과 이유 칸 근거, 작업 항목 ID·중복, 첫 항목 E2E, 결정이 있으면 둘째 항목 검사기 — 경고
//   build — S4·S5 항목 끝과 목록 끝, S6 검사기 확인. 검사기·테스트 명령을 실행한다.
//     완료 항목(KR-161): STATE 작업 목록 [x] T<n>마다 VERIFY 첫 표에 T<n> 행, git log [S4]·[S5] 커밋 제목에 T<n>. 복귀 지점 SHA가 커밋으로 있다
//     검사기(KR-160): LOGIC "- 함수·명령:"을 실행해 출력의 "검사 n"·"위반 m"을 읽는다. 명령 없음·검사 0·읽지 못함은 실패
//     위반 테스트(KR-120): 반드시 조건마다 테스트 파일에 조건 ID와 "위반"(또는 violat)이 같은 줄에 있고,
//       "- 테스트 명령:"이 exit 0이며 출력에 그 조건의 실패 줄이 없다
//     단계 테스트(KR-162): 단계 표 확인 케이스 칸 마지막 "·" 뒤 테스트 이름이 테스트 파일에 있다
//   verify — S6 끝(check-stage.sh S7이 경고로 부른다). VERIFY 성공 기준별 충족 행 수 = AGREEMENT 성공 기준 수,
//     행마다 판정·근거, 검사 0건 근거로 충족 없음, 목적 적합 5행 판정·근거, 요구별 충족 줄(KR-163)
// 테스트 파일: docs·fde-kit·.agents·.claude·.git·data·submission·node_modules 밖에서 test/·tests/·__tests__/ 아래이거나 test_*·*_test.*·*.test.*·*.spec.*
// 종료 코드: 0 통과(경고만) / 1 실패(출력의 "실패:" 줄) / 2 사용법 오류
import { readFileSync } from 'node:fs';
import { read, noComment, section, tableRows, field, hasTok, nums, workFiles, runCmd, git } from './doc-lib.mjs';

const MODE = process.argv[2] || '';
if (!['design', 'build', 'verify'].includes(MODE)) { console.error('사용: check-work.sh design|build|verify'); process.exit(2); }
const A = read('docs/AGREEMENT.md'), S = read('docs/STATE.md'), L = read('docs/LOGIC.md'), D = read('docs/DECISIONS.md'), I = read('docs/INTERVIEW.md');
const R = read('docs/RESEARCH.md'), V = read('docs/VERIFY.md'), RT = read('docs/REQ-TASK.md'), RU = read('docs/REQ-USER.md');
let FAIL = 0;
const log = s => console.log(s);
const fail = s => { log(`실패: ${s}`); FAIL = 1; };
const warn = s => log(`경고(멈추지 않음): ${s}`);

const decision = field(section(L, '결정'), '결정');
const HAS_DECISION = !!L && !!decision && !/^결정 없음/.test(decision);
// 조건 표: [ID, 종류, 규칙, 근거, 담당, 방식] (규칙 칸이 찬 행만)
const CONDS = tableRows(section(L, '조건')).filter(c => /^C\d+$/.test(c[0]) && c[2]);
const MUST = CONDS.filter(c => c[1] === '반드시').map(c => c[0]);
const CHECKER = section(L, '검사기');
const STEPS = tableRows(section(L, '단계')).filter(c => /^P\d+$/.test(c[0]) && c[1]);
const TASKS = section(S, '작업 목록').split('\n').filter(l => /^- \[[ xX]\] .*\S/.test(l));
const taskId = l => (l.replace(/^- \[[ xX]\] /, '').match(/^T\d+(?![0-9])/) || [''])[0];

function design() {
  if (!HAS_DECISION) log('LOGIC: 결정 없음(또는 결정 줄 빈칸 — check-stage.sh S4가 본다) — 조건·단계 점검 없음');
  else {
    // 1) 출처 없는 숫자 — KR-157
    const src = [noComment(I), section(A, '가정'), section(A, '제약'), ...['사실', '출발선', '라운드 기록', '결정'].map(t => section(R, t)),
      noComment(RT), noComment(RU), noComment(read('README.md'))].join('\n');
    const have = new Set(nums(src));
    let total = 0; const rows = [];
    for (const c of CONDS) {
      if (/^숫자 없음/.test(c[2])) continue;
      const ns = nums(c[2]).filter(n => !/^[0-5]$/.test(n));
      total += ns.length;
      const miss = [...new Set(ns.filter(n => !have.has(n)))];
      if (miss.length) rows.push({ id: c[0], kind: c[1], miss, rule: c[2] });
    }
    const k = rows.reduce((a, r) => a + r.miss.length, 0);
    log(`출처 없는 숫자: 조건 규칙 숫자 ${total}개 중 출처 없음 ${k}개${rows.length ? ` — ${rows.map(r => `${r.id}(${r.kind}) ${r.miss.join(' ')}`).join(', ')}` : ''}`);
    for (const r of rows) log(`  - ${r.id} ${r.kind} "${r.rule}" — ${r.miss.join(' ')}: INTERVIEW·AGREEMENT 가정·제약·RESEARCH·REQ·README 어디에도 없다`);
    const mustBad = rows.filter(r => r.kind === '반드시').map(r => r.id);
    if (mustBad.length) fail(`반드시 조건 ${mustBad.join(' ')} 규칙 숫자에 출처가 없다 — 담당자 답을 INTERVIEW 대화 기록 새 행으로 적거나 AGREEMENT 가정에 값과 이유를 적는다(지어낸 숫자로 구현하지 않는다)`);
    else if (k) warn('점수·목표 조건 숫자 출처 없음 — 근거를 INTERVIEW·AGREEMENT 가정에 남기거나 사람에게 확인');

    // 2) 점수 조건의 숫자 한도 — KR-119
    const txt = {};
    for (const c of tableRows(section(I, '대화 기록'))) if (/^\d+$/.test(c[0])) txt[`#${c[0]}`] = c[2] || '';
    for (const c of tableRows(noComment(RT))) if (/^T-\d+$/.test(c[0])) txt[c[0]] = c[1] || '';
    for (const c of tableRows(noComment(RU))) if (/^U-\d+$/.test(c[0])) txt[c[0]] = c[1] || '';
    for (const c of tableRows(section(R, '결정'))) if (/^C-\d+$/.test(c[0])) txt[c[0]] = c[3] || '';
    const assume = section(A, '가정');
    for (const c of CONDS) {
      if (c[1] !== '점수' || hasTok(assume, c[0])) continue;
      const cited = [...(c[3] || '').matchAll(/#\d+|[TUC]-\d+/g)].map(m => m[0]).filter(r => txt[r] && nums(txt[r]).length);
      if (cited.length) warn(`점수 조건 ${c[0]} 근거에 숫자 한도 — ${cited.map(r => `${r} ${txt[r]}`).join(' / ')} → 넘으면 안 되는 한도면 반드시로, 점수로 두려면 AGREEMENT 가정에 ${c[0]}과 이유를 적고 담당자 확인(KR-119)`);
    }

    // 3) 위반 테스트 계획 — KR-120
    const planned = new Set(tableRows(CHECKER).filter(c => /^C\d+$/.test(c[0]) && c[1]).map(c => c[0]));
    const nop = MUST.filter(c => !planned.has(c));
    log(`위반 테스트 계획: 반드시 조건 ${MUST.length}개 중 계획 있음 ${MUST.length - nop.length}개, 없음: ${nop.join(' ') || '없음'}`);
    if (nop.length) warn(`LOGIC 검사기 절 '위반 테스트' 표에 ${nop.join(' ')} 행이 없다 — 조건마다 일부러 어긴 작은 입력과 기대(위반 1건 이상)를 적는다`);

    // 4) 단계 표·손으로 따라가는 예시 — KR-158
    for (const c of STEPS) {
      if (!c[2]) warn(`LOGIC 단계 ${c[0]} 고르는 규칙 빈칸 — 정렬 기준·동점·한도를 적는다`);
      else if (/적절히|알아서/.test(c[2])) warn(`LOGIC 단계 ${c[0]} 고르는 규칙이 따라 할 수 없는 말("${c[2]}") — 정렬 기준·동점·한도로 쓴다`);
    }
    if (!/[^-\s]/.test(section(L, '손으로 따라가는 예시'))) warn('LOGIC 손으로 따라가는 예시 없음 — 실제 데이터 1~2건을 단계 순서대로 적는다');
  }

  // 5) DECISIONS 5줄·이유 근거 — KR-159
  const LAB = ['선택', '이유', '의도', '버린 대안', '알려진 약점'];
  let id = null, got = {};
  const flush = () => {
    if (!id) return;
    const miss = LAB.filter(l => !got[l]);
    if (miss.length) warn(`DECISIONS ${id} 칸 없음·빈칸: ${miss.join('·')} — 결정마다 5줄`);
    if (got['이유'] && !/#\d|INTERVIEW|AGREEMENT|RESEARCH|[TUC]-\d/.test(got['이유'])) warn(`DECISIONS ${id} 이유 칸에 근거(INTERVIEW #n·AGREEMENT 항목·T-/U-/C- ID)가 없다`);
    id = null; got = {};
  };
  for (const l of noComment(D).split('\n')) {
    if (/^## /.test(l)) { flush(); const m = l.match(/^## (D\d+)\./); if (m && !l.includes('(제목)')) id = m[1]; continue; }
    const m = id && l.match(/^\s*-\s*\*\*([^*]+)\*\*:\s*(.*)$/);
    if (m && m[2].trim()) got[m[1].trim()] = m[2].trim();
  }
  flush();

  // 6) 작업 목록 — KR-159
  if (TASKS.length) {
    const seen = new Set(), dup = [], noid = [];
    TASKS.forEach((l, i) => {
      const t = taskId(l), body = l.replace(/^- \[[ xX]\] /, '');
      if (t) { if (seen.has(t)) dup.push(t); seen.add(t); } else noid.push(`${i + 1}번째`);
      if (i === 0 && !/E2E/.test(body)) warn('작업 목록 첫 항목에 E2E가 없다 — 첫 항목은 실제 입력→실제 처리→결과 최소 E2E');
      if (i === 1 && HAS_DECISION && !/검사기/.test(body)) warn('LOGIC에 결정이 있는데 둘째 항목이 검사기가 아니다 — 개선 항목보다 검사기를 먼저');
    });
    if (dup.length) warn(`작업 항목 ID 중복: ${dup.join(' ')}`);
    if (noid.length) warn(`작업 항목 ID(T<n>) 없음: ${noid.join(' ')} — 커밋·VERIFY·REQ 설계 연결이 이 ID로 이어진다`);
  }
}

function build() {
  // 1) 완료 항목 — VERIFY 행·커밋·복귀 SHA (KR-161)
  const done = TASKS.filter(l => /^- \[[xX]\] T\d/.test(l)).map(taskId);
  const open = TASKS.filter(l => /^- \[ \] T\d/.test(l)).map(taskId);
  const vrows = tableRows(noComment(V)).filter(c => /^\d?\d:\d\d/.test(c[0])).map(c => c.join(' | '));
  const inRepo = git(['rev-parse', '--git-dir']);
  const haveGit = !!inRepo && inRepo.code === 0;
  const subjects = haveGit ? (git(['log', '--format=%s']).out || '').split('\n').filter(s => /\[S[45]\]/.test(s)) : [];
  let nv = 0, nc = 0; const gaps = [];
  for (const t of done) {
    if (vrows.some(r => hasTok(r, t))) nv++; else gaps.push(`${t}(VERIFY 행)`);
    if (haveGit) { if (subjects.some(s => hasTok(s, t))) nc++; else gaps.push(`${t}(커밋)`); }
  }
  log(`완료 항목: ${done.length}개 중 VERIFY 행 ${nv}개 · 커밋 ${nc}개, 빠짐: ${gaps.join(' ') || '없음'} / 남은 항목: ${open.join(' ') || '없음'}`);
  if (!haveGit) warn('git 이력을 볼 수 없어 항목별 커밋을 세지 못했다');
  if (gaps.length) fail('완료 표시한 항목의 증거가 빠졌다 — VERIFY 첫 표에 항목 ID가 들어간 행, 커밋 제목 "[S4] feat: T<n> …"');
  const sha = (field(section(S, '기준판'), '복귀 지점').match(/\b[0-9a-f]{7,40}\b/) || [''])[0];
  if (sha) {
    if (haveGit) { const r = git(['cat-file', '-e', `${sha}^{commit}`]); if (r && r.code === 0) log(`복귀 지점: ${sha} — 커밋 있음`); else fail(`STATE 복귀 지점 ${sha} 커밋이 git에 없다`); }
  } else if (done.length) fail('STATE 복귀 지점 SHA 없음 — 완료 항목이 있으면 마지막으로 실행 확인한 구현 커밋 SHA를 적는다');

  if (!HAS_DECISION) { log('LOGIC: 결정 없음 — 검사기·위반 테스트·단계 테스트 점검 없음'); return; }
  const tests = workFiles('test');
  const testTexts = tests.map(f => { try { return readFileSync(f, 'utf8'); } catch { return ''; } });

  // 2) 검사기 실행 — KR-160
  const cmd = field(CHECKER, '함수·명령');
  if (!cmd) fail("LOGIC 검사기 '- 함수·명령:' 빈칸 — 실행할 명령을 적는다(예: node src/check.js data/result.csv)");
  else {
    const r = runCmd(cmd);
    const num = re => { const m = r.out.match(re); return m ? m[2].replace(/,/g, '') : ''; };
    const nchk = num(/(검사|[Cc]hecked)[\s:=]*(\d[\d,]*)/), nvio = num(/(위반|[Vv]iolations?)[\s:=]*(\d[\d,]*)/);
    const line = (r.out.split('\n').find(l => /검사\s*\d|[Cc]hecked[\s:=]*\d/.test(l)) || '').trim();
    if (!nchk || !nvio) { fail(`검사기 출력에서 '검사 n'·'위반 m'을 읽지 못했다(exit ${r.code}) — 출력 형식: 검사 n건·조건 k개 / 위반 m건 — ${cmd}`); r.out.trim().split('\n').slice(-3).forEach(l => log(`  > ${l}`)); }
    else if (+nchk === 0) fail(`검사기 검사 0건 — 검증 0건은 실패(입력 0행·조건 0개) — ${cmd}`);
    else { log(`검사기: 검사 ${nchk} · 위반 ${nvio} (exit ${r.code}) — ${cmd}`); log(`  > ${line}`); }
  }

  // 3) 위반 테스트 — KR-120. 이름 규칙: 테스트 이름(또는 함수 이름)에 조건 ID와 "위반"(violat)
  if (!MUST.length) log('위반 테스트: 반드시 조건 0개 — 대상 없음');
  else {
    const found = MUST.filter(c => testTexts.some(tx => tx.split('\n').some(l => hasTok(l, c) && /위반|violat/i.test(l))));
    const none = MUST.filter(c => !found.includes(c));
    const tcmd = field(CHECKER, '테스트 명령'); let rcs = '실행 안 함'; const failed = [];
    if (!tcmd) fail("LOGIC 검사기 '- 테스트 명령:' 빈칸 — 위반 테스트를 실행할 명령을 적는다(예: node --test 또는 python -m pytest -v)");
    else {
      const r = runCmd(tcmd); rcs = `exit ${r.code}`;
      for (const c of found) if (r.out.split('\n').some(l => hasTok(l, c) && /not ok|FAIL|[Ff]ailed|✖|✕|✗/.test(l))) failed.push(c);
      if (r.code !== 0) { fail(`테스트 명령 실패(${rcs}) — ${tcmd}`); r.out.trim().split('\n').slice(-5).forEach(l => log(`  > ${l}`)); }
    }
    log(`위반 테스트: 반드시 조건 ${MUST.length}개 중 테스트 있음 ${found.length}개 · ${rcs}, 없음: ${none.join(' ') || '없음'}, 실패: ${failed.join(' ') || '없음'}`);
    if (none.length) fail(`반드시 조건 ${none.join(' ')} 위반 테스트 없음 — 일부러 어긴 작은 입력에 검사기가 위반 1건 이상을 내는 테스트, 이름에 조건 ID와 "위반"`);
    if (failed.length) fail(`위반 테스트 실패: ${failed.join(' ')} — 검사기가 위반을 못 잡는다. 이 검사기의 "위반 0"은 근거로 쓰지 않는다`);
  }

  // 4) 단계 테스트 이름 — KR-162
  const bad = []; let ok = 0;
  for (const c of STEPS) {
    const parts = (c[4] || '').split('·'), name = parts.length > 1 ? parts[parts.length - 1].replace(/`/g, '').trim() : '';
    if (!name || /→|->/.test(name)) { bad.push(`${c[0]}(이름 없음)`); continue; }
    if (testTexts.some(tx => tx.includes(name))) ok++; else bad.push(`${c[0]}("${name}" 테스트 파일에 없음)`);
  }
  log(`단계 테스트: 단계 ${STEPS.length}개 중 테스트 있음 ${ok}개, 빠짐: ${bad.join(' ') || '없음'}`);
  if (bad.length) fail('LOGIC 단계 확인 케이스의 테스트 — 칸 끝에 "· <테스트 이름>"을 적고 그 이름의 테스트를 만든다(아직 안 만든 단계면 남은 항목)');
  if (!tests.length) warn('테스트 파일을 찾지 못했다(test/·tests/·*.test.*·test_*·*_test.*)');
}

function verify() {
  const nCrit = tableRows(section(A, '성공 기준')).filter(c => /^\d+$/.test(c[0]) && c[1]).length;
  const crit = tableRows(section(V, '성공 기준별 충족')).filter(c => c[0] && c[0] !== '성공 기준');
  const nj = [], ne = [], z = [];
  crit.forEach((c, i) => {
    const j = c[1] || '', ev = c[2] || '', n = `${i + 1}행`;
    if (!/^(충족|부분|미충족)/.test(j)) nj.push(n);
    if (!ev) ne.push(n);
    if (/^충족/.test(j) && /검사\s*0(?!\d)|0개 수집|0 tests/.test(ev)) z.push(n);
  });
  log(`성공 기준별 충족: 성공 기준 ${nCrit}개 · 표 ${crit.length}행, 판정 없음: ${nj.join(' ') || '없음'}, 근거 없음: ${ne.join(' ') || '없음'}`);
  if (!nCrit) fail('AGREEMENT 성공 기준 0개 — 검증 0건은 실패');
  if (crit.length !== nCrit) fail(`VERIFY 성공 기준별 충족 ${crit.length}행 ≠ AGREEMENT 성공 기준 ${nCrit}개 — 기준마다 정확히 한 행`);
  if (nj.length) fail(`판정(충족/부분/미충족)이 없는 행: ${nj.join(' ')}`);
  if (ne.length) fail(`근거가 없는 행: ${ne.join(' ')} — 근거 없는 판정은 부분을 넘지 않는다`);
  if (z.length) fail(`검사 0건·테스트 0개를 근거로 한 충족: ${z.join(' ')} — 검증 0건은 충족 근거가 아니다`);
  const pur = tableRows(section(V, '목적 적합')).filter(c => c[0] && c[0] !== '볼 것');
  const pbad = pur.filter(c => !(/^(반영|부분|미반영|인용 없음)/.test(c[1] || '') && c[2])).map(c => c[0].replace(/\s+—.*$/, ''));
  log(`목적 적합: ${pur.length}행 중 판정·근거 있음 ${pur.length - pbad.length}행`);
  if (pur.length !== 5 || pbad.length) fail(`VERIFY 목적 적합은 5행 모두 판정(반영/부분/미반영/인용 없음)과 근거가 있어야 한다${pbad.length ? ` — 빈 행: ${pbad.join(', ')}` : ''}`);
  const vline = field(section(V, '요구별 충족'), 'verify 결과');
  if (vline) log(`요구별 충족: ${vline}`); else fail("VERIFY 요구별 충족 '- verify 결과:' 줄이 비었다 — check-req.sh verify 출력 한 줄을 옮긴다");
}

({ design, build, verify })[MODE]();
if (!FAIL) { log(`통과: check-work ${MODE}`); process.exit(0); }
log(`실패: check-work ${MODE} — 위 '실패:' 줄`);
process.exit(1);
