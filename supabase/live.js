// Skilleaze CRM · live connection to Supabase (sign-in, load, save, user admin)
(function () {
  const C = () => window.SKZ_SUPABASE;
  let client = null;
  const on = () => !!(C() && window.supabase && window.supabase.createClient);
  const sb = () => { if (!client && on()) client = window.supabase.createClient(C().url, C().key, { auth: { persistSession: true, autoRefreshToken: true, storageKey: 'skz-auth' } }); return client; };
  const email = u => String(u).trim().toLowerCase() + '@' + C().emailDomain;
  const T = ['cv', 'linkedin', 'portfolio', 'jobportal', 'interview'];
  const KV_SKIP = new Set(['orders', 'ads', 'transfers', 'expenses', 'issues', 'activity', 'passwords', 'pwTemp', 'loginFails', 'lastBackup', 'disabled', 'lastLogin', 'v']);
  const TBL = { orders: 'orders', ads: 'ad_days', transfers: 'transfers', expenses: 'expenses', issues: 'customer_issues', hr: 'hr_records' };
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
    issues: i => ({ id: i.id, customer_key: i.ckey || i.phone || i.id, name: i.name || null, phone: i.phone || null, type: i.type || 'Other', status: i.status === 'resolved' ? 'resolved' : 'open',
      agents: i.agents || [], cses: i.cses || [], experts: i.experts || [], order_ids: i.orderIds || [], extra: i })
  };
  const kvValue = (k, v) => k === 'users' && Array.isArray(v) ? v.map(u => { const { password, ...r } = u; return r; }) : v;
  const chk = r => { if (r && r.error) throw r.error; return r ? r.data : null; };

  const pause = ms => new Promise(z => setTimeout(z, ms));
  async function run(q) { let err = null; for (let t = 0; t < 3; t++) { const r = await q(); if (!r.error) return r; err = r.error; await pause(700 * (t + 1)); } throw err; }
  // Page-by-page download using "id greater than last id" (fast at any depth).
  // If a page times out, retry it smaller.
  async function pageAll(tbl, cols, since) {
    const c = sb(), out = []; let last = null, P = 1000;
    for (let g = 0; g < 2000; g++) {
      let rows = null, err = null;
      for (let t = 0; t < 5 && rows === null; t++) {
        let q = c.from(tbl).select(cols).order('id').limit(P);
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
    transfers: r => ({ ...r.extra, status: r.status === 'verified' ? r.extra.status : r.status }),
    expenses: r => r.extra,
    issues: r => ({ ...r.extra, status: r.status }),
    hr: r => ({ ...r.extra, id: r.id })
  };
  // HR table may not exist yet (05_hr.sql not run): never block sign-in because of it
  const soft = (k, p) => k === 'hr' ? p.catch(() => []) : p;
  const COLS = { orders: 'id,date,price,paid,pay_status,status,extra', ads: 'id,extra', transfers: 'id,status,extra', expenses: 'id,extra', issues: 'id,status,extra', hr: 'id,extra' };

  // Full download (first time on a device)
  async function load() {
    const c = sb(), started = new Date(Date.now() - 120000).toISOString();
    const kv = (await run(() => c.from('app_kv').select('key,value'))).data;
    const small = await Promise.all(['ads', 'transfers', 'expenses', 'issues', 'hr'].map(k => soft(k, pageAll(TBL[k], COLS[k]))));
    const big = await pageAll(TBL.orders, COLS.orders);
    const rows = Object.keys(TBL).map(k => k === 'orders' ? big : small[['ads', 'transfers', 'expenses', 'issues', 'hr'].indexOf(k)]);
    const d = { v: 'real1' }; kv.forEach(r => { d[r.key] = r.value; });
    Object.keys(TBL).forEach((k, i) => { d[k] = rows[i].map(MAP[k]); });
    return { d, empty: !d.orders.length && !kv.length, syncedAt: started };
  }
  // Only what changed since the last visit (plus ids, to spot deletions)
  async function loadChanges(since) {
    const c = sb(), started = new Date(Date.now() - 120000).toISOString(), ks = Object.keys(TBL);
    const [kv, ...rest] = await Promise.all([
      run(() => c.from('app_kv').select('key,value').gt('updated_at', since)).then(r => r.data),
      ...ks.map(k => soft(k, pageAll(TBL[k], COLS[k], since))),
      ...ks.map(k => soft(k, pageAll(TBL[k], 'id')))
    ]);
    const ch = {}, ids = {};
    ks.forEach((k, i) => { ch[k] = rest[i].map(MAP[k]); ids[k] = new Set(rest[ks.length + i].map(r => r.id)); });
    const kvo = {}; kv.forEach(r => { kvo[r.key] = r.value; });
    return { ch, ids, kv: kvo, syncedAt: started };
  }
  function applyChanges(base, delta, onlyIds) {
    const d = { ...base };
    Object.assign(d, delta.kv);
    Object.keys(TBL).forEach(k => {
      const m = new Map((base[k] || []).map(x => [x.id, x]));
      delta.ch[k].forEach(x => m.set(x.id, x));
      d[k] = [...m.values()].filter(x => !onlyIds || !onlyIds[k] || delta.ids[k].has(x.id) || !(onlyIds[k].has(x.id)));
    });
    return d;
  }

  // Save every change since `prev`. Returns a list of error messages.
  async function push(prev, next, getExpert, isMgmt, progress) {
    const c = sb(), jobs = [], errs = [];
    prev = prev || {};
    for (const k of Object.keys(TBL)) {
      const a = prev[k] || [], b = next[k] || []; if (a === b) continue;
      const pm = new Map(a.map(x => [x.id, x])), left = new Map(pm), added = [], changed = [];
      b.forEach(x => { const o = pm.get(x.id); if (!o) added.push(x); else if (o !== x) changed.push(x); left.delete(x.id); });
      const del = [...left.keys()].filter(Boolean);
      if (isMgmt) { const all = added.concat(changed); for (let i = 0; i < all.length; i += 500) { const part = all.slice(i, i + 500); jobs.push(() => c.from(TBL[k]).upsert(part.map(ROW[k]), { onConflict: 'id' }).then(chk)); } }
      else {
        for (let i = 0; i < added.length; i += 200) { const part = added.slice(i, i + 200); jobs.push(() => c.from(TBL[k]).insert(part.map(ROW[k])).then(chk)); }
        changed.forEach(x => jobs.push(() => { const r = ROW[k](x); delete r.id; return c.from(TBL[k]).update(r).eq('id', x.id).then(chk); }));
      }
      if (del.length) for (let i = 0; i < del.length; i += 300) { const part = del.slice(i, i + 300); jobs.push(() => c.from(TBL[k]).delete().in('id', part).then(chk)); }
      if (k === 'orders') {
        const mv = added.concat(changed).filter(x => { const o = pm.get(x.id); return !o || T.some(t => getExpert(o, t) !== getExpert(x, t)); });
        for (let i = 0; i < mv.length; i += 300) {
          const part = mv.slice(i, i + 300);
          jobs.push(async () => {
            await c.from('order_experts').delete().in('order_id', part.map(x => x.id)).then(chk);
            const ins = part.flatMap(x => T.map(t => [t, getExpert(x, t)]).filter(p => p[1]).map(([t, e]) => ({ order_id: x.id, service_type: t, expert_code: e })));
            if (ins.length) await c.from('order_experts').insert(ins).then(chk);
          });
        }
      }
    }
    const keys = new Set([...Object.keys(next), ...Object.keys(prev)]);
    keys.forEach(k => {
      if (KV_SKIP.has(k) || TBL[k] || next[k] === undefined || prev[k] === next[k]) return;
      jobs.push(() => c.from('app_kv').upsert({ key: k, value: kvValue(k, next[k]), updated_at: new Date().toISOString() }, { onConflict: 'key' }).then(chk));
      if (k === 'expertAgents') jobs.push(async () => {
        const rows = Object.entries(next.expertAgents || {}).flatMap(([e, ags]) => (ags || []).map(a => ({ expert_code: e, agent_code: a })));
        await c.from('expert_agents').delete().neq('expert_code', '').then(chk);
        for (let i = 0; i < rows.length; i += 500) await c.from('expert_agents').insert(rows.slice(i, i + 500)).then(chk);
      });
    });
    for (let i = 0; i < jobs.length; i++) {
      try { await jobs[i](); } catch (e) { errs.push((e && (e.message || e.details)) || String(e)); }
      if (progress) progress(i + 1, jobs.length);
    }
    return errs;
  }

  async function profile() {
    const { data: { user } } = await sb().auth.getUser(); if (!user) return null;
    const p = await sb().from('profiles').select('*').eq('id', user.id).maybeSingle().then(chk);
    return p ? { ...p, email: user.email } : { id: user.id, username: user.email.split('@')[0], role: null, active: false };
  }
  async function signIn(u, p) { const r = await sb().auth.signInWithPassword({ email: email(u), password: p }); if (r.error) throw r.error; return profile(); }
  async function session() { const { data } = await sb().auth.getSession(); return data && data.session ? profile() : null; }
  async function signOut() { try { await sb().auth.signOut(); } catch (e) {} }
  async function changePassword(p) { const r = await sb().auth.updateUser({ password: p }); if (r.error) throw r.error; await sb().rpc('touch_login', { changed: true }); }
  async function setPersonKey(k) { try { await sb().rpc('set_my_person_key', { k }); } catch (e) {} }
  async function touch() { try { await sb().rpc('touch_login', { changed: false }); } catch (e) {} }
  async function admin(action, body) {
    const { data, error } = await sb().functions.invoke('admin-users', { body: { action, ...(body || {}) } });
    if (error) { let msg = error.message; try { const j = await error.context.json(); msg = j.error || msg; } catch (e) {} throw new Error(msg); }
    if (data && data.error) throw new Error(data.error);
    return data;
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
  async function lookupRemote(q) { const { data, error } = await sb().rpc('lookup_orders', { q }); if (error) throw error; return (data || []).map(r => ({ ...(r.extra || {}), id: r.id, date: r.date, status: r.status, pay: r.pay_status, _remote: true })); }

  // Customer complaints: light refresh so notified people see new complaints without reloading
  async function issuesFetch() {
    const { data, error } = await sb().from('customer_issues').select('id,status,extra').order('created_at', { ascending: false }).limit(500);
    if (error) throw error; return (data || []).map(MAP.issues);
  }

  window.SKZLive = { issuesFetch, lookupRemote, docUpload, docUrl, setPersonKey, on, sb, photosLoad, photoUpload, loadChanges, applyChanges, signIn, session, profile, profiles, signOut, changePassword, touch, load, push, admin, bulkCreate };
})();
