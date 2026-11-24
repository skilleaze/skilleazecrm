// Skilleaze CRM · live connection to Supabase (sign-in, load, save, user admin)
(function () {
  const C = () => window.SKZ_SUPABASE;
  let client = null;
  const on = () => !!(C() && window.supabase && window.supabase.createClient);
  const sb = () => { if (!client && on()) client = window.supabase.createClient(C().url, C().key, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: false, storageKey: 'skz-auth', storage: (() => { try { const t = '__skz'; window.localStorage.setItem(t, '1'); window.localStorage.removeItem(t); return window.localStorage; } catch (e) { const m = {}; return { getItem: k => (k in m ? m[k] : null), setItem: (k, v) => { m[k] = String(v); }, removeItem: k => { delete m[k]; } }; } })(), lock: async (name, timeout, fn) => fn() } }); return client; };
  const email = u => String(u).trim().toLowerCase() + '@' + C().emailDomain;
  const T = ['cv', 'linkedin', 'portfolio', 'jobportal', 'interview'];
  const KV_SKIP = new Set(['orders', 'ads', 'transfers', 'expenses', 'issues', 'activity', 'passwords', 'pwTemp', 'loginFails', 'lastBackup', 'disabled', 'lastLogin', 'v']);
  const TBL = { orders: 'orders', ads: 'ad_days', transfers: 'transfers', expenses: 'expenses', issues: 'customer_issues', hr: 'hr_records', enq: 'enquiries' };
  const ST = ['PENDING', 'DRAFT SHARED', 'CV SUBMITTED', 'REVISION', 'CLOSED'];
  const ROW = {
    orders: o => ({ id: o.id, branch: o.branch === 'puttur' ? 'puttur' : 'cloud', agent_code: o.branch === 'puttur' ? null : (o.agent || null), cse_id: o.branch === 'puttur' ? (o.bde || null) : null,
      date: o.date, name: o.name || null, phone: o.phone ? String(o.phone) : null, services: o.services || [], price: +o.price || 0, paid: +o.paid || 0,
      pay_status: ['PAID', 'PARTIAL', 'REFUNDED'].includes(o.pay) ? o.pay : 'PAID', via: o.via || null, status: ST.includes(o.status) ? o.status : 'PENDING',
      urgent: !!o.urgent, summary: !!o.summary, qty: o.qty == null ? null : Math.round(+o.qty), extra: o }),
    ads: a => ({ id: a.id || (a.agent + '-' + a.date), agent_code: a.agent || null, date: a.date, messages: Math.round(+a.messages || 0), aed: +a.aed || 0, summary: !!a.summary, extra: a }),
    transfers: t => ({ id: t.id, agent_code: t.agent || null, date: t.date, amount: +t.amount || 0, note: t.note || null, status: ['pending', 'verified', 'rejected'].includes(t.status) ? t.status : 'verified', imported: !t.proof, extra: t }),
    expenses: e => ({ id: e.id, branch: e.branch === 'puttur' ? 'puttur' : 'cloud', date: e.date, category: e.type || 'Other', name: e.name || '-', amount: +e.amount || 0, extra: e }),
    hr: h => ({ id: h.id, kind: h.kind, person_key: h.key || null, branch: ['cloud', 'puttur'].includes(h.branch) ? h.branch : 'all', extra: h }),
    enq: e => ({ id: e.id, cse_id: e.bde || e.cse || null, name: e.name || '', phone: e.phone || '', status: e.status || 'NEW', source: e.source || null, extra: e }),
    issues: i => ({ id: i.id, customer_key: i.ckey || i.phone || i.id, name: i.name || null, phone: i.phone || null, type: i.type || 'Other', status: i.status === 'resolved' ? 'resolved' : 'open',
      agents: i.agents || [], cses: i.cses || [], experts: i.experts || [], order_ids: i.orderIds || [], extra: i })
  };
  const kvValue = (k, v) => k === 'users' && Array.isArray(v) ? v.map(u => { const { password, ...r } = u; return r; }) : v;
  const chk = r => { if (r && r.error) throw r.error; return r ? r.data : null; };

  const pause = ms => new Promise(z => setTimeout(z, ms));
  const isAuthErr = e => !!e && (e.status === 401 || e.code === 'PGRST301' || e.code === 'PGRST303' || /jwt|token.*expired|not authenticated/i.test(String(e.message || '')));
  let _refreshing = null;
  async function fixAuth() { if (!_refreshing) _refreshing = (async () => { try { const r = await sb().auth.refreshSession(); return !!(r && r.data && r.data.session); } catch (e) { return false; } finally { setTimeout(() => { _refreshing = null; }, 5000); } })(); return _refreshing; }
  async function run(q) { let err = null; for (let t = 0; t < 3; t++) { const r = await q(); if (!r.error) return r; err = r.error;
      if (isAuthErr(r.error)) { const ok = await fixAuth(); if (!ok) { try { window.dispatchEvent(new CustomEvent('skz-auth-expired')); } catch (e) {} throw r.error; } continue; }
      await pause(700 * (t + 1)); } throw err; }
  // Page-by-page download using "id greater than last id" (fast at any depth).
  // If a page times out, retry it smaller.
  let ME = null;
  const scope = (tbl, q) => { const p = ME; if (!p || !p.role) return q;
    if (p.role === 'sales' && p.agent_code && (tbl === 'orders' || tbl === 'ad_days' || tbl === 'transfers')) return q.eq('agent_code', p.agent_code);
    if (p.role === 'cse' && p.staff_id && tbl === 'orders') return q.eq('cse_id', p.staff_id);
    if (p.role === 'manager' && tbl === 'orders') return q.eq('branch', 'puttur');
    return q; };
  async function pageAll(tbl, cols, since) {
    const c = sb(), out = []; let last = null, P = 1000;
    for (let g = 0; g < 2000; g++) {
      let rows = null, err = null;
      for (let t = 0; t < 5 && rows === null; t++) {
        let q = scope(tbl, c.from(tbl).select(cols)).order('id').limit(P);
        if (since) q = q.gt('updated_at', since);
        if (last !== null) q = q.gt('id', last);
        const r = await q;
        if (!r.error) rows = r.data;
        else { err = r.error; if (/timeout|canceling/i.test(r.error.message || '')) P = Math.max(100, Math.floor(P / 2)); await pause(600 * (t + 1)); }
      }
      if (rows === null) throw err;
      out.push(...rows);
      if (typeof window !== 'undefined' && window.SKZLiveProgress) window.SKZLiveProgress(tbl, out.length);
      if (rows.length < P) break;
      last = rows[rows.length - 1].id;
    }
    return out;
  }
  const MAP = {
    orders: r => ({ ...r.extra, id: r.id, date: r.date, price: +r.price, paid: +r.paid, pay: r.pay_status, status: r.status }),
    ads: r => r.extra,
    transfers: r => ({ ...(r.extra || {}), id: r.id, amount: +r.amount || (r.extra || {}).amount || 0, status: r.status || (r.extra || {}).status || 'verified', verifiedAt: r.verified_at || (r.extra || {}).verifiedAt }),
    expenses: r => r.extra,
    issues: r => ({ ...r.extra, status: r.status }),
    hr: r => ({ ...r.extra, id: r.id }),
    enq: r => ({ ...r.extra, id: r.id })
  };
  // HR table may not exist yet (05_hr.sql not run): never block sign-in because of it
  const soft = (k, p) => k === 'hr' ? p.catch(() => []) : p;
  const COLS = { orders: 'id,date,price,paid,pay_status,status,extra', ads: 'id,extra', transfers: 'id,status,amount,verified_at,extra', expenses: 'id,extra', issues: 'id,status,extra', hr: 'id,extra', enq: 'id,extra' };
  const enqStamp = x => Math.max(+(x && x.at) || 0, +(x && x.updated) || 0, ...(((x && x.log) || []).map(l => +(l.at || 0))), ((x && x.log) || []).length);
  const enqOf = x => (x && x.puttur && Array.isArray(x.puttur.enquiries)) ? x.puttur.enquiries : [];
  // Enquiries are one row each in the enquiries table; the app keeps them in puttur.enquiries.
  function foldEnq(d, extra, gone) { const m = new Map(); const add = e => { if (!e || !e.id || (gone && gone.has(e.id))) return; const o = m.get(e.id); if (!o || enqStamp(e) >= enqStamp(o)) m.set(e.id, e); };
    enqOf(d).forEach(add); (d.enq || []).forEach(add); (extra || []).forEach(add); delete d.enq;
    if (m.size || d.puttur) d.puttur = { ...(d.puttur || {}), enquiries: [...m.values()].sort((a, b) => (+b.at || 0) - (+a.at || 0)) }; return d; }

  // Full download (first time on a device)
  async function load() {
    const c = sb(), started = new Date(Date.now() - 120000).toISOString();
    const kv = (await run(() => c.from('app_kv').select('key,value'))).data;
    const small = await Promise.all(['ads', 'transfers', 'expenses', 'issues', 'hr', 'enq'].map(k => soft(k, pageAll(TBL[k], COLS[k]))));
    const big = await pageAll(TBL.orders, COLS.orders);
    const rows = Object.keys(TBL).map(k => k === 'orders' ? big : small[['ads', 'transfers', 'expenses', 'issues', 'hr', 'enq'].indexOf(k)] || []);
    const d = { v: 'real1' }; kv.forEach(r => { d[r.key] = r.value; });
    Object.keys(TBL).forEach((k, i) => { d[k] = rows[i].map(MAP[k]); });
    foldEnq(d);
    return { d, empty: !d.orders.length && !kv.length, syncedAt: started };
  }
  // Only what changed since the last visit (plus ids, to spot deletions)
  async function loadChanges(since, known) {
    const c = sb(), started = new Date(Date.now() - 120000).toISOString(), ks = Object.keys(TBL);
    const [kv, ...rest] = await Promise.all([
      run(() => c.from('app_kv').select('key,value').gt('updated_at', since)).then(r => r.data),
      ...ks.map(k => soft(k, pageAll(TBL[k], COLS[k], k === 'transfers' ? null : since))),
      ...ks.map(k => soft(k, pageAll(TBL[k], 'id')))
    ]);
    const ch = {}, ids = {};
    ks.forEach((k, i) => { ch[k] = rest[i].map(MAP[k]); ids[k] = new Set(rest[ks.length + i].map(r => r.id)); });
    // Rows this device is allowed to see but has never downloaded (e.g. newly assigned to me) — fetch them now
    if (known) for (const k of ks) { const kn = known[k]; if (!kn) continue; const have = new Set(ch[k].map(x => x.id));
      const miss = [...ids[k]].filter(id => !kn.has(id) && !have.has(id));
      for (let i = 0; i < miss.length; i += 150) { const part = miss.slice(i, i + 150);
        try { const r = await run(() => c.from(TBL[k]).select(COLS[k]).in('id', part)); (r.data || []).forEach(x => ch[k].push(MAP[k](x))); } catch (e) {} } }
    const kvo = {}; kv.forEach(r => { kvo[r.key] = r.value; });
    return { ch, ids, kv: kvo, syncedAt: started };
  }
  async function loadDelta(since) {
    const c = sb(), started = new Date(Date.now() - 90000).toISOString(), ks = Object.keys(TBL);
    const [kv, ...rest] = await Promise.all([
      run(() => c.from('app_kv').select('key,value').gt('updated_at', since)).then(r => r.data),
      ...ks.map(k => soft(k, pageAll(TBL[k], COLS[k], k === 'transfers' ? null : since)))
    ]);
    const ch = {}; ks.forEach((k, i) => { ch[k] = rest[i].map(MAP[k]); });
    const kvo = {}; (kv || []).forEach(r => { kvo[r.key] = r.value; });
    let gone = []; try { const rd = await c.from('deleted_rows').select('tbl,id').gt('at', since); if (!rd.error) gone = rd.data || []; } catch (e) {}
    const del = {}; ks.forEach(k => { const ids = gone.filter(g => g.tbl === TBL[k]).map(g => g.id); if (ids.length) del[k] = ids; });
    const n = ks.reduce((a, k) => a + ch[k].length, 0) + Object.keys(kvo).length + gone.length;
    return { ch, ids: {}, kv: kvo, del, syncedAt: started, n };
  }
  // Realtime: every synced table (and any added to TBL later) pushes a change signal to all open portals.
  let SYNC_CH = null, SYNC_CB = null, SYNC_TRY = 0, SYNC_T = null;
  function subscribeAll(cb) { SYNC_CB = cb; const c = sb(); if (SYNC_CH) { try { c.removeChannel(SYNC_CH); } catch (e) {} SYNC_CH = null; }
    const tables = [...new Set([...Object.values(TBL), 'order_experts', 'app_kv', 'expert_agents', 'profiles'])];
    let ch = c.channel('skz-sync-' + Math.random().toString(36).slice(2, 8));
    tables.forEach(t => { ch = ch.on('postgres_changes', { event: '*', schema: 'public', table: t }, p => { try { SYNC_CB && SYNC_CB(t, p); } catch (e) {} }); });
    ch.subscribe(st => { if (st === 'SUBSCRIBED') { SYNC_TRY = 0; try { SYNC_CB && SYNC_CB('*', null); } catch (e) {} }
      if (st === 'CHANNEL_ERROR' || st === 'TIMED_OUT' || st === 'CLOSED') { clearTimeout(SYNC_T); SYNC_TRY++; SYNC_T = setTimeout(() => { if (SYNC_CB) subscribeAll(SYNC_CB); }, Math.min(30000, 1500 * Math.pow(1.7, SYNC_TRY))); } });
    SYNC_CH = ch; return () => { SYNC_CB = null; clearTimeout(SYNC_T); try { c.removeChannel(ch); } catch (e) {} }; }
  function syncState() { return SYNC_CH ? SYNC_CH.state : 'none'; }
  function applyChanges(base, delta, onlyIds) {
    const d = { ...base }, localEnq = enqOf(base);
    Object.assign(d, delta.kv);
    Object.keys(TBL).forEach(k => { if (k === 'enq') return;
      const m = new Map((base[k] || []).map(x => [x.id, x]));
      delta.ch[k].forEach(x => m.set(x.id, x));
      d[k] = [...m.values()].filter(x => !onlyIds || !onlyIds[k] || delta.ids[k].has(x.id) || !(onlyIds[k].has(x.id)));
    });
    const gone = new Set(((delta.del && delta.del.enq) || []));
    if (onlyIds && onlyIds.enq && delta.ids && delta.ids.enq) localEnq.forEach(e => { if (onlyIds.enq.has(e.id) && !delta.ids.enq.has(e.id)) gone.add(e.id); });
    d.enq = localEnq; foldEnq(d, ((delta.ch && delta.ch.enq) || []), gone);
    return d;
  }

  // A login whose session is gone keeps "working" as an anonymous visitor: the screen shows cached orders
  // but every save is refused. Check first and send the person back to Sign in (unsaved changes stay on the device).
  async function haveSession() { try { const r = await sb().auth.getSession(); return !!(r && r.data && r.data.session); } catch (e) { return true; } }
  function signedOut() { try { window.dispatchEvent(new CustomEvent('skz-auth-expired')); } catch (e) {} return new Error('Your sign-in expired. Please sign in again.'); }

  // Save every change since `prev`. Returns a list of error messages.
  async function push(prev, next, getExpert, isMgmt, progress) {
    if (!(await haveSession())) return [signedOut().message];
    const c = sb(), jobs = [], errs = [], failed = new Set(), denied = [];
    // Refusals that can never succeed on a retry (permission / business rule), as opposed to network trouble.
    const isDenied = e => /row-level security|42501|not open to your login|Experts can only|cannot be changed|read-only|Only management|Only the assigned/i.test(String((e && (e.message || e.code || e.details)) || e || ''));
    const deny = (k, id, e) => { if (isDenied(e) && !denied.some(d => d.k === k && d.id === id)) denied.push({ k, id }); };
    const rls = e => /row-level security|42501/i.test(String((e && (e.message || e.code)) || ''));
    const one = async (k, x) => { const row = ROW[k](x); try { await c.from(TBL[k]).upsert([row], { onConflict: 'id' }).then(chk); } catch (e1) { if (!rls(e1)) { failed.add(x.id); deny(k, x.id, e1); throw e1; } const { id, ...rest } = row; const u = await c.from(TBL[k]).update(rest).eq('id', x.id).select('id'); if (u.error || !(u.data || []).length) { failed.add(x.id); deny(k, x.id, u.error || e1); throw u.error || e1; } } };
    prev = prev || {}; prev = { ...prev, enq: enqOf(prev) }; next = { ...next, enq: enqOf(next) };
    // Consultants only ever save their own enquiries; others' (copied in via app_kv.puttur) are read-only to them and were re-sent in a loop.
    if (ME && ME.role === 'cse') { const own = e => e && String(e.bde || e.cse || '') === String(ME.staff_id || ''); prev.enq = prev.enq.filter(own); next.enq = next.enq.filter(own); }
    for (const k of Object.keys(TBL)) {
      const a = prev[k] || [], b = next[k] || []; if (a === b) continue;
      const pm = new Map(a.map(x => [x.id, x])), left = new Map(pm), added = [], changed = [];
      b.forEach(x => { const o = pm.get(x.id); if (!o) added.push(x); else if (o !== x) changed.push(x); left.delete(x.id); });
      const DEL = window.__skzDel || (window.__skzDel = new Set()), del = [...left.keys()].filter(id => id && DEL.has(id)); del.forEach(id => DEL.delete(id));
const patchJob = (k, o, x) => async () => { const ra = ROW[k](o), rb = ROW[k](x), p = {}; let ex = null;
        Object.keys(rb).forEach(f => { if (f === 'id') return; if (JSON.stringify(ra[f]) === JSON.stringify(rb[f])) return; if (f === 'extra' && ra.extra && rb.extra && typeof rb.extra === 'object') { const set = {}, unset = []; Object.keys(rb.extra).forEach(q => { if (JSON.stringify(ra.extra[q]) !== JSON.stringify(rb.extra[q])) set[q] = rb.extra[q]; }); Object.keys(ra.extra).forEach(q => { if (!(q in rb.extra)) unset.push(q); }); ex = { set, unset }; } else p[f] = rb[f]; });
        if (Object.keys(p).length) { if (k === 'orders') { const ur = await c.from(TBL[k]).update(p).eq('id', x.id).select('id'); if (ur.error) throw ur.error; if (!(ur.data || []).length) throw new Error('Not saved: order ' + x.id + ' is not open to your login or was removed'); } else await c.from(TBL[k]).update(p).eq('id', x.id).then(chk); }
        if (ex && (Object.keys(ex.set).length || ex.unset.length)) { const rr = await c.rpc('patch_extra', { p_table: TBL[k], p_id: String(x.id), p_set: ex.set, p_unset: ex.unset }); if (rr.error) { if (/function|PGRST202|not exist/i.test(String(rr.error.message || rr.error.code || ''))) await c.from(TBL[k]).update({ extra: rb.extra }).eq('id', x.id).then(chk); else throw rr.error; } } };
      for (let i = 0; i < added.length; i += 200) { const part = added.slice(i, i + 200); jobs.push(async () => { try { await c.from(TBL[k]).upsert(part.map(ROW[k]), { onConflict: 'id' }).then(chk); } catch (e0) { let bad = null; for (const x of part) { try { await one(k, x); } catch (e1) { bad = bad || e1; } } if (bad) throw bad; } }); }
      changed.forEach(x => { const run = patchJob(k, pm.get(x.id), x); jobs.push(async () => { try { await run(); } catch (e) { failed.add(x.id); deny(k, x.id, e); throw e; } }); });
      if (del.length) for (let i = 0; i < del.length; i += 300) { const part = del.slice(i, i + 300); jobs.push(() => c.from(TBL[k]).delete().in('id', part).then(chk)); }
      if (k === 'orders') {
        const mv = added.concat(changed).filter(x => { const o = pm.get(x.id); return !o || T.some(t => getExpert(o, t) !== getExpert(x, t)); });
        const EC = e => String(e || '').toUpperCase().replace(/\s+/g, ' ').trim();
        for (let i = 0; i < mv.length; i += 300) {
          const part = mv.slice(i, i + 300);
          jobs.push(async () => {
            const ok = part.filter(x => !failed.has(x.id)); let bad = null;
            for (const x of ok) { const o = pm.get(x.id);
              for (const t of T) { const a = o ? EC(getExpert(o, t)) : '', b = EC(getExpert(x, t)); if (o && a === b) continue;
                try {
                  if (a && a !== b) await c.from('order_experts').delete().eq('order_id', x.id).eq('service_type', t).then(chk);
                  if (b) await c.from('order_experts').upsert([{ order_id: x.id, service_type: t, expert_code: b }], { onConflict: 'order_id,service_type' }).then(chk);
                } catch (e) { if (!/foreign key|23503/i.test(String(e && (e.message || e.code)))) { bad = bad || e; deny('orders', x.id, e); } } } }
            if (bad) throw bad;
          });
        }
      }
    }
    const keys = new Set([...Object.keys(next), ...Object.keys(prev)]);
    keys.forEach(k => {
      if (KV_SKIP.has(k) || TBL[k] || next[k] === undefined || prev[k] === next[k]) return;
      { const rl = ME && ME.role, admin = rl === 'management' || rl === 'ops' || rl === 'manager';
        if (!admin && !(k === 'issueSeen' || (k === 'puttur' && rl === 'cse') || (ME && k === 'inv_' + ME.id))) return; }
      if (k === 'users') { jobs.push(async () => {
        const r = await c.from('app_kv').select('value').eq('key', 'users').maybeSingle();
        const srv = (r && r.data && Array.isArray(r.data.value)) ? r.data.value : [], mine = next.users || [], was = new Set((prev.users || []).map(x => x.username)), now = new Set(mine.map(x => x.username));
        const gone = new Set([...was].filter(x => !now.has(x))), m = new Map();
        srv.forEach(x => { if (x && x.username && !gone.has(x.username)) m.set(x.username, x); });
        mine.forEach(x => { if (x && x.username) m.set(x.username, { ...(m.get(x.username) || {}), ...x }); });
        await c.from('app_kv').upsert({ key: 'users', value: kvValue('users', [...m.values()]), updated_at: new Date().toISOString() }, { onConflict: 'key' }).then(chk);
      }); return; }
      if (k === 'puttur') { jobs.push(async () => {
        const r = await c.from('app_kv').select('value').eq('key', 'puttur').maybeSingle(); const srv = (r && r.data && r.data.value) || {}, mine = next.puttur || {}, was = prev.puttur || {};
        const mergeList = (name, stamp) => { const S = Array.isArray(srv[name]) ? srv[name] : [], M = Array.isArray(mine[name]) ? mine[name] : [], W = new Set((Array.isArray(was[name]) ? was[name] : []).map(x => x && x.id)), N = new Set(M.map(x => x && x.id)), gone = new Set([...W].filter(id => !N.has(id)));
          const m = new Map(); S.forEach(x => { if (x && x.id && !gone.has(x.id)) m.set(x.id, x); });
          M.forEach(x => { if (!x || !x.id) return; const o = m.get(x.id); m.set(x.id, !o ? x : stamp(x) >= stamp(o) ? x : o); }); return [...m.values()]; };
        const st = x => Math.max(+(x.at || 0), +(x.updated || 0), ...((x.log || []).map(l => +(l.at || 0))), (x.log || []).length);
        // Merge key by key: id-lists merge per record (newest wins), other keys only override the server when this device changed them — a stale device can no longer wipe ads/expenses saved elsewhere.
        const merged = { ...srv }, idList = v => Array.isArray(v) && v.length > 0 && v.every(x => x && typeof x === 'object' && x.id);
        new Set([...Object.keys(srv), ...Object.keys(mine)]).forEach(k => { if (k === 'enquiries' || k === 'staff') return; const M = mine[k], S = srv[k], W = was[k];
          if ((idList(M) || idList(S) || idList(W)) && (Array.isArray(M) || M === undefined) && (Array.isArray(S) || S === undefined)) merged[k] = mergeList(k, st);
          else if (M !== W && M !== undefined) merged[k] = M; });
        merged.enquiries = mergeList('enquiries', st); merged.staff = mergeList('staff', x => +(x.updated || 0) || (x.left ? 1 : 0));
        await c.from('app_kv').upsert({ key: 'puttur', value: kvValue('puttur', merged), updated_at: new Date().toISOString() }, { onConflict: 'key' }).then(chk);
        next.puttur = merged;
      }); return; }
      if (k === 'expertAgents') { jobs.push(async () => {
        const pairs = m => new Set(Object.entries(m || {}).flatMap(([e, ags]) => (ags || []).map(a => e + '|' + a)));
        const A = pairs(prev.expertAgents), B = pairs(next.expertAgents), add = [...B].filter(x => !A.has(x)), rem = [...A].filter(x => !B.has(x));
        if (!add.length && !rem.length) return;
        const sv = await c.from('app_kv').select('value').eq('key', 'expertAgents').maybeSingle(); const S = pairs((sv.data && sv.data.value) || {});
        add.forEach(x => S.add(x)); rem.forEach(x => S.delete(x));
        const out = {}; S.forEach(x => { const [e, a] = x.split('|'); (out[e] = out[e] || []).push(a); });
        await c.from('app_kv').upsert({ key: 'expertAgents', value: out, updated_at: new Date().toISOString() }, { onConflict: 'key' }).then(chk);
        if (add.length) await c.from('expert_agents').upsert(add.map(x => { const [e, a] = x.split('|'); return { expert_code: e, agent_code: a }; }), { onConflict: 'expert_code,agent_code', ignoreDuplicates: true }).then(chk);
        for (const x of rem) { const [e, a] = x.split('|'); await c.from('expert_agents').delete().eq('expert_code', e).eq('agent_code', a).then(chk); }
        next.expertAgents = out; }); return; }
      jobs.push(() => c.from('app_kv').upsert({ key: k, value: kvValue(k, next[k]), updated_at: new Date().toISOString() }, { onConflict: 'key' }).then(chk));
    });
    for (let i = 0; i < jobs.length; i++) {
      try { await jobs[i](); } catch (e) { errs.push((e && (e.message || e.details)) || String(e)); }
      if (progress) progress(i + 1, jobs.length);
    }
    errs.denied = denied;
    return errs;
  }

  async function profile(known) {
    let user = null; for (let t = 0; t < 3 && !user; t++) { try { const r = await sb().auth.getUser(); user = r && r.data && r.data.user; } catch (e) {} if (!user && known) { user = known; break; } if (!user) await pause(500 * (t + 1)); }
    if (!user) return null;
    const p = await sb().from('profiles').select('*').eq('id', user.id).maybeSingle().then(chk);
    const out = p ? { ...p, email: user.email } : { id: user.id, username: user.email.split('@')[0], role: null, active: false }; ME = out; return out;
  }
  async function signIn(u, p) { const r = await sb().auth.signInWithPassword({ email: email(u), password: p }); if (r.error) throw r.error; return profile(); }
  async function session() {
    for (let t = 0; t < 3; t++) {
      let s = null; try { const r = await sb().auth.getSession(); s = r && r.data && r.data.session; } catch (e) {}
      if (!s && t === 0) { let had = false; try { had = !!window.localStorage.getItem('skz-auth'); } catch (e) {} if (!had) return null; try { const r2 = await sb().auth.refreshSession(); s = r2 && r2.data && r2.data.session; } catch (e) {} }
      if (s) { try { return await profile(s.user); } catch (e) { if (t === 2) throw e; } }
      await pause(700 * (t + 1));
    }
    return null; }
  async function signOut() { try { await sb().auth.signOut(); } catch (e) {} }
  async function changePassword(p) { const r = await sb().auth.updateUser({ password: p }); if (r.error) throw r.error;
    let ok = false; for (let t = 0; t < 3 && !ok; t++) { const x = await sb().rpc('touch_login', { changed: true }); if (!x.error) ok = true; else { const y = await sb().rpc('clear_my_pw_flag'); if (!y.error) ok = true; else await pause(800); } }
    if (!ok) throw new Error('Your new password is saved, but the "change password" reminder could not be cleared. Please tell management.'); }
  async function setPersonKey(k) { try { await sb().rpc('set_my_person_key', { k }); } catch (e) {} }
  async function touch() { try { await sb().rpc('touch_login', { changed: false }); } catch (e) {} }
  async function admin(action, body) {
    // Direct call with only standard headers (avoids browser CORS blocks), retried on network failure
    const url = C().url.replace(/\/$/, '') + '/functions/v1/admin-users', payload = JSON.stringify({ action, ...(body || {}) });
    let lastErr = null;
    for (let t = 0; t < 3; t++) {
      let tok = null; try { const s = await sb().auth.getSession(); tok = s && s.data && s.data.session && s.data.session.access_token; } catch (e) {}
      if (!tok) { try { const r0 = await sb().auth.refreshSession(); tok = r0 && r0.data && r0.data.session && r0.data.session.access_token; } catch (e) {} }
      if (!tok) throw new Error('Your sign-in expired. Please sign out and sign in again.');
      let r;
      try { const ctl = typeof AbortController !== 'undefined' ? new AbortController() : null, tm = ctl ? setTimeout(() => ctl.abort(), 25000) : null;
        r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + tok, apikey: C().key }, body: payload, signal: ctl ? ctl.signal : undefined }); if (tm) clearTimeout(tm); }
      catch (e) { lastErr = e; await pause(1200 * (t + 1)); continue; }
      let j = null; try { j = await r.json(); } catch (e) {}
      if (r.status === 401 && t < 2) { try { await sb().auth.refreshSession(); } catch (e) {} continue; }
      if (r.status >= 500 && t < 2) { lastErr = new Error((j && j.error) || 'Server error ' + r.status); await pause(1500 * (t + 1)); continue; }
      if (!r.ok || (j && j.error)) {
        const msg = (j && j.error) || ('Server error ' + r.status);
        if (t > 0 && action === 'create' && /already (been )?registered|already exists|duplicate/i.test(msg)) return { ok: true, username: body && body.user && body.user.username, retried: true };
        throw new Error(msg);
      }
      return j || {};
    }
    throw new Error('Could not reach the server. Check the internet connection and try again.' + (lastErr && lastErr.message ? ' (' + lastErr.message + ')' : ''));
  }
  async function bulkCreate(users, progress) {
    const res = [];
    for (let i = 0; i < users.length; i += 10) {
      const part = users.slice(i, i + 10);
      try { const d = await admin('bulk_create', { users: part }); res.push(...(d.results || [])); }
      catch (e) { res.push(...part.map(u => ({ username: u.username, error: e.message }))); }
      if (progress) progress(Math.min(i + 10, users.length), users.length);
    }
    return res;
  }
  async function profiles() { return sb().from('profiles').select('username,full_name,role,active,last_login,must_change_pw').then(chk); }


  // Display pictures · Supabase Storage bucket "photos" (public read)
  const b64 = s => btoa(unescape(encodeURIComponent(s))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const unb64 = s => { s = s.replace(/-/g, '+').replace(/_/g, '/'); while (s.length % 4) s += '='; return decodeURIComponent(escape(atob(s))); };
  async function photosLoad() {
    const c = sb(), out = {}, seen = {}; let off = 0;
    for (let g = 0; g < 20; g++) {
      const { data, error } = await c.storage.from('photos').list('', { limit: 1000, offset: off, sortBy: { column: 'name', order: 'asc' } });
      if (error || !data) break;
      data.forEach(f => { const m = /^(.+)__(\d+)\.jpg$/.exec(f.name); if (!m) return; let k; try { k = unb64(m[1]); } catch (e) { return; } const ts = +m[2]; if (seen[k] && seen[k] > ts) return; seen[k] = ts; out[k] = c.storage.from('photos').getPublicUrl(f.name).data.publicUrl; });
      if (data.length < 1000) break; off += 1000;
    }
    return out;
  }
  async function photoUpload(key, blob) {
    const c = sb(), name = b64(key) + '__' + Date.now() + '.jpg';
    const r = await c.storage.from('photos').upload(name, blob, { contentType: 'image/jpeg', upsert: false, cacheControl: '31536000' });
    if (r.error) throw r.error;
    return c.storage.from('photos').getPublicUrl(name).data.publicUrl;
  }

  async function docUpload(path, file) { const r = await sb().storage.from('proofs').upload(path, file, { upsert: false, contentType: file.type || 'application/octet-stream' }); if (r.error) throw r.error; return path; }
  async function docUrl(path) { const r = await sb().storage.from('proofs').createSignedUrl(path, 600); if (r.error) throw r.error; return r.data.signedUrl; }
  function docOpen(path) {
    let w = null; try { w = window.open('', '_blank'); if (w) w.document.write('<p style="font:14px sans-serif;padding:20px">Opening the file…</p>'); } catch (e) { w = null; }
    return docUrl(path).then(u => { if (w && !w.closed) w.location.replace(u); else window.location.assign(u); return u; })
      .catch(e => { try { if (w) w.close(); } catch (x) {} throw e; });
  }
  async function lookupRemote(q) { const { data, error } = await sb().rpc('lookup_orders', { q }); if (error) throw error; return (data || []).map(r => ({ ...(r.extra || {}), id: r.id, date: r.date, status: r.status, pay: r.pay_status, _remote: true })); }

  // Customer complaints: light refresh so notified people see new complaints without reloading
  async function issuesFetch() {
    const since = window.__issSince || new Date(Date.now() - 30 * 864e5).toISOString(), started = new Date(Date.now() - 60000).toISOString();
    const { data, error } = await sb().from('customer_issues').select('id,status,extra').gt('updated_at', since).order('updated_at', { ascending: false }).limit(200);
    if (!error) window.__issSince = started;
    if (error) throw error; return (data || []).map(MAP.issues);
  }


  // Chat
  const chatRowG = r => ({ id: r.id, name: r.name, branch: r.branch, kind: r.kind, auto: r.auto || null, members: r.members || [], removed: r.removed || [], photo: r.photo || '', at: Date.parse(r.updated_at || r.created_at) || 0 });
  const chatRowM = r => ({ id: r.id, g: r.group_id, by: r.sender, t: r.body, at: Date.parse(r.created_at) || 0, iso: r.created_at });
  async function chatLoad(since) { const c = sb(); const g = await c.from('chat_groups').select('*').eq('archived', false); if (g.error) throw g.error;
    let q = c.from('chat_messages').select('id,group_id,sender,body,created_at').order('created_at', { ascending: true }).limit(3000);
    q = since ? q.gt('created_at', since) : q.gte('created_at', new Date(Date.now() - 90 * 864e5).toISOString());
    const m = await q; if (m.error) throw m.error; return { groups: (g.data || []).map(chatRowG), msgs: (m.data || []).map(chatRowM) }; }
  async function chatSend(m) { const r = await sb().from('chat_messages').insert({ id: m.id, group_id: m.g, sender: m.by, body: m.t }).select('id,group_id,sender,body,created_at').single(); if (r.error) throw r.error; return chatRowM(r.data); }
  async function chatGroupSave(g) { const row = { id: g.id, name: g.name || '', branch: g.branch === 'puttur' ? 'puttur' : 'cloud', kind: g.kind === 'dm' ? 'dm' : 'group', auto: g.auto || null, members: g.members || [], removed: g.removed || [], ...(g.photo !== undefined ? { photo: g.photo || null } : {}), updated_at: new Date().toISOString() };
    const r = g.kind === 'dm' ? await sb().from('chat_groups').insert(row).select('*').single() : await sb().from('chat_groups').upsert(row).select('*').single();
    if (r.error) { if (g.kind === 'dm' && /duplicate/i.test(r.error.message || '')) { const x = await sb().from('chat_groups').select('*').eq('id', g.id).single(); if (!x.error) return chatRowG(x.data); } throw r.error; } return chatRowG(r.data); }
  async function chatGroupDel(id) { const r = await sb().from('chat_groups').update({ archived: true, updated_at: new Date().toISOString() }).eq('id', id); if (r.error) throw r.error; }


  // ---- Notifications: realtime + web push ----
  let rtCh = null;
  function rtStart(cb) { try { const c = sb(); if (rtCh) { c.removeChannel(rtCh); rtCh = null; }
      rtCh = c.channel('skz-alerts')
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'chat_messages' }, p => { try { cb('chat', chatRowM(p.new)); } catch (e) {} })
        .on('postgres_changes', { event: '*', schema: 'public', table: 'customer_issues' }, () => { try { cb('issue'); } catch (e) {} })
        .subscribe(); } catch (e) {} }
  function rtStop() { try { if (rtCh) sb().removeChannel(rtCh); } catch (e) {} rtCh = null; }
  async function pushSave(sub, username) { const j = sub.toJSON ? sub.toJSON() : sub; let r = await sb().rpc('push_claim', { p_endpoint: j.endpoint, p_p256dh: j.keys.p256dh, p_auth: j.keys.auth, p_ua: (navigator.userAgent || '').slice(0, 200) });
    if (r.error && /function|not exist|PGRST202/i.test(String(r.error.message || r.error.code || ''))) r = await sb().from('push_subs').upsert({ endpoint: j.endpoint, username, p256dh: j.keys.p256dh, auth: j.keys.auth, ua: (navigator.userAgent || '').slice(0, 200) }, { onConflict: 'endpoint' });
    if (r.error) throw r.error; return true; }
  async function pushRemove(endpoint) { try { await sb().from('push_subs').delete().eq('endpoint', endpoint); } catch (e) {} }
  async function pushSend(body) { try { const r = await sb().functions.invoke('push-send', { body }); return r.data || null; } catch (e) { return null; } }

  async function chatMediaUp(path, blob) { const r = await sb().storage.from('chat').upload(path, blob, { upsert: false, contentType: blob.type || 'application/octet-stream', cacheControl: '31536000' }); if (r.error) throw r.error; return path; }
  async function chatMediaUrl(path) { const r = await sb().storage.from('chat').createSignedUrl(path, 60 * 60 * 6); if (r.error) throw r.error; return r.data && r.data.signedUrl; }
  async function chatMediaPub(path, blob) { const c = sb(); const r = await c.storage.from('photos').upload(path, blob, { upsert: false, contentType: blob.type || 'application/octet-stream', cacheControl: '31536000' }); if (r.error) throw r.error; return c.storage.from('photos').getPublicUrl(path).data.publicUrl; }
  async function chatDelete(id) { const r = await sb().from('chat_messages').delete().eq('id', id); if (r.error) throw r.error; return true; }
  async function pushTest() { try { const r = await sb().functions.invoke('push-send', { body: { kind: 'test' } }); if (r.error) { let st = 0, msg = r.error.message || ''; try { st = r.error.context && r.error.context.status || 0; } catch (e) {} return { ok: false, status: st, msg }; } return { ok: true, data: r.data || {} }; } catch (e) { return { ok: false, status: 0, msg: (e && e.message) || 'network' }; } }
  async function chatStorageTest(gid) { const c = sb(), path = String(gid || '').replace(/\|/g, ',') + '/check-' + Date.now().toString(36) + '.txt'; const r = await c.storage.from('chat').upload(path, new Blob(['ok'], { type: 'text/plain' }), { upsert: false, contentType: 'text/plain' }); if (r.error) return { ok: false, msg: r.error.message || 'upload failed' }; const u = await c.storage.from('chat').createSignedUrl(path, 60); try { await c.storage.from('chat').remove([path]); } catch (e) {} return u.error ? { ok: false, msg: 'upload ok, reading failed: ' + u.error.message } : { ok: true }; }
  // Expert work status: one server-side, locked, all-or-nothing change. Resolves with the saved order, or throws.
  async function setTaskStatus(id, status, task, types) {
    const args = { p_id: String(id), p_status: status, p_task: task || null, p_types: types && types.length > 1 ? types : null };
    if (!(await haveSession())) throw signedOut();
    let r = await sb().rpc('set_task_status', args);
    if (r.error && isAuthErr(r.error) && await fixAuth()) r = await sb().rpc('set_task_status', args);
    if (r.error) throw r.error;
    if (!r.data || !r.data.id) throw new Error('Not saved: no reply from the server');
    return MAP.orders(r.data);
  }
  window.SKZLive = { setTaskStatus, subscribeAll, syncState, loadDelta, chatMediaPub, chatDelete, pushTest, chatStorageTest, chatMediaUp, chatMediaUrl, rtStart, rtStop, pushSave, pushRemove, pushSend, chatLoad, chatSend, chatGroupSave, chatGroupDel, issuesFetch, lookupRemote, docUpload, docUrl, docOpen, setPersonKey, on, sb, photosLoad, photoUpload, loadChanges, applyChanges, signIn, session, profile, profiles, signOut, changePassword, touch, load, push, admin, bulkCreate };
  window.SKZLive.chatLoad = async () => ({ groups: [], msgs: [], messages: [], since: new Date().toISOString(), off: true });
  window.SKZLive.chatSend = async () => { throw new Error('Chat has been removed'); };
  window.SKZLive.chatGroupSave = async () => { throw new Error('Chat has been removed'); };
  window.SKZLive.chatGroupDel = async () => true;
  window.SKZLive.chatMediaUp = async () => { throw new Error('Chat has been removed'); };
  window.SKZLive.chatMediaUrl = async () => '';
  window.SKZLive.chatMediaPub = async () => '';
  window.SKZLive.chatDelete = async () => true;
  window.SKZLive.chatStorageTest = async () => ({ ok: false, off: true });
})();
