// Skilleaze HQ · push-send
// Sends phone/desktop push notifications for chat messages, customer issues, announcements and tests.
// Uses only built-in Web Crypto (no npm web-push), so it runs reliably on Supabase Edge.
// Deploy: Edge Functions → Deploy a new function → Via Editor → name "push-send" → paste → Deploy.
// Secrets (Edge Functions → Secrets): VAPID_PUBLIC, VAPID_PRIVATE, VAPID_SUBJECT (mailto:you@skilleaze.com)
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const out = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });

const AUTO: Record<string, string[]> = {
  'cloud-all': ['sales', 'expert', 'ops', 'management'],
  'cloud-sales': ['sales', 'ops', 'management'],
  'cloud-experts': ['expert', 'ops', 'management'],
  'puttur-all': ['manager', 'cse', 'ops', 'management'],
};
const plain = (t: string) => {
  if (!t || t[0] !== '§') return t;
  try { const o = JSON.parse(t.slice(1)); if (o.k === 'txt') return o.c || ''; return (o.k === 'voice' ? '🎤 Voice message' : '📷 Photo') + (o.c ? ' · ' + o.c : ''); } catch (_) { return t; }
};
const cut = (s: string, n: number) => (s || '').length > n ? s.slice(0, n - 1) + '…' : (s || '');

// ---------- Web Push (RFC 8291 aes128gcm + RFC 8292 VAPID) ----------
const enc = new TextEncoder();
const b64u = (b: Uint8Array) => btoa(String.fromCharCode(...b)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const unb64u = (s: string) => { s = s.replace(/-/g, '+').replace(/_/g, '/'); while (s.length % 4) s += '='; const r = atob(s); return Uint8Array.from(r, c => c.charCodeAt(0)); };
const cat = (...a: Uint8Array[]) => { const n = a.reduce((x, y) => x + y.length, 0), o = new Uint8Array(n); let i = 0; for (const x of a) { o.set(x, i); i += x.length; } return o; };
const hmac = async (key: Uint8Array, data: Uint8Array) => new Uint8Array(await crypto.subtle.sign('HMAC', await crypto.subtle.importKey('raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']), data));

let vapidKey: CryptoKey | null = null;
async function vapidSigner(pub: string, priv: string) {
  if (vapidKey) return vapidKey;
  const P = unb64u(pub);
  vapidKey = await crypto.subtle.importKey('jwk', { kty: 'EC', crv: 'P-256', d: priv, x: b64u(P.slice(1, 33)), y: b64u(P.slice(33, 65)), ext: true }, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  return vapidKey;
}
async function vapidAuth(endpoint: string, pub: string, priv: string, sub: string) {
  const aud = new URL(endpoint).origin;
  const h = b64u(enc.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const p = b64u(enc.encode(JSON.stringify({ aud, exp: Math.floor(Date.now() / 1000) + 12 * 3600, sub })));
  const sig = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, await vapidSigner(pub, priv), enc.encode(h + '.' + p)));
  return 'vapid t=' + h + '.' + p + '.' + b64u(sig) + ', k=' + pub;
}
async function encrypt(p256dh: string, authS: string, payload: string) {
  const ua = unb64u(p256dh), auth = unb64u(authS);
  const eph = await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']) as CryptoKeyPair;
  const asPub = new Uint8Array(await crypto.subtle.exportKey('raw', eph.publicKey));
  const uaKey = await crypto.subtle.importKey('raw', ua, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: uaKey }, eph.privateKey, 256));
  const prkKey = await hmac(auth, ecdh);
  const ikm = await hmac(prkKey, cat(enc.encode('WebPush: info\0'), ua, asPub, new Uint8Array([1])));
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const prk = await hmac(salt, ikm);
  const cek = (await hmac(prk, cat(enc.encode('Content-Encoding: aes128gcm\0'), new Uint8Array([1])))).slice(0, 16);
  const nonce = (await hmac(prk, cat(enc.encode('Content-Encoding: nonce\0'), new Uint8Array([1])))).slice(0, 12);
  const key = await crypto.subtle.importKey('raw', cek, { name: 'AES-GCM' }, false, ['encrypt']);
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, key, cat(enc.encode(payload), new Uint8Array([2]))));
  const rs = new Uint8Array([0, 0, 16, 0]);
  return cat(salt, rs, new Uint8Array([asPub.length]), asPub, ct);
}
async function sendPush(s: any, payload: string, urgency: string, V: { pub: string; priv: string; sub: string }) {
  const body = await encrypt(s.p256dh, s.auth, payload);
  const r = await fetch(s.endpoint, { method: 'POST', headers: { Authorization: await vapidAuth(s.endpoint, V.pub, V.priv, V.sub), 'Content-Encoding': 'aes128gcm', 'Content-Type': 'application/octet-stream', TTL: '86400', Urgency: urgency }, body });
  return r.status;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const V = { pub: Deno.env.get('VAPID_PUBLIC') || '', priv: Deno.env.get('VAPID_PRIVATE') || '', sub: Deno.env.get('VAPID_SUBJECT') || 'mailto:admin@skilleaze.com' };
    if (!V.pub || !V.priv) return out({ error: 'VAPID secrets are missing', missingSecrets: true }, 200);
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
    const jwt = (req.headers.get('Authorization') || '').replace('Bearer ', '');
    const { data: { user } } = await admin.auth.getUser(jwt);
    if (!user) return out({ error: 'Not signed in' }, 401);
    const { data: me } = await admin.from('profiles').select('*').eq('id', user.id).eq('active', true).single();
    if (!me) return out({ error: 'No active profile' }, 403);

    const body = await req.json().catch(() => ({}));
    const { data: people } = await admin.from('profiles').select('username, full_name, role, agent_code, expert_code, staff_id').eq('active', true);
    const P = people || [];
    let to: string[] = [], title = 'Skilleaze HQ', text = '', url = '/', tag = '', type = body.kind || '', self = false;
    const myName = me.full_name || me.username;

    if (body.kind === 'test') {
      to = [me.username]; self = true; title = 'Skilleaze HQ'; text = 'Test notification · this device is set up ✅'; tag = 'test'; type = 'chat';
    } else if (body.kind === 'chat') {
      const { data: m } = await admin.from('chat_messages').select('*').eq('id', body.id).single();
      if (!m) return out({ sent: 0, missing: true });
      if (m.created_by !== user.id) return out({ error: 'Not your message' }, 403);
      const { data: g } = await admin.from('chat_groups').select('*').eq('id', m.group_id).single();
      if (!g || g.archived) return out({ sent: 0 });
      const set = new Set<string>(g.members || []);
      if (g.kind !== 'dm' && g.auto && AUTO[g.auto]) P.filter(p => AUTO[g.auto].includes(p.role) && !(g.removed || []).includes(p.username)).forEach(p => set.add(p.username));
      to = [...set];
      const t = plain(m.body);
      const mentioned = new Set(P.filter(p => p.full_name && t.includes('@' + p.full_name)).map(p => p.username));
      title = g.kind === 'dm' ? myName : (g.name || 'Group chat');
      text = g.kind === 'dm' ? cut(t, 160) : myName + ': ' + cut(t, 150);
      url = '/?go=chat&g=' + encodeURIComponent(g.id); tag = 'chat-' + g.id;
      body._mentioned = [...mentioned];
    } else if (body.kind === 'issue') {
      const { data: i } = await admin.from('customer_issues').select('*').eq('id', body.id).single();
      if (!i) return out({ sent: 0, missing: true });
      const staff = ['management', 'ops', 'manager'].includes(me.role);
      const mine = i.created_by === user.id || (i.agents || []).includes(me.agent_code) || (i.experts || []).includes(me.expert_code) || (i.cses || []).includes(me.staff_id);
      if (!staff && !mine) return out({ error: 'Not allowed' }, 403);
      const creator = i.created_by ? (await admin.from('profiles').select('username').eq('id', i.created_by).single()).data : null;
      to = P.filter(p => ['management', 'ops'].includes(p.role) || (p.role === 'manager' && (i.cses || []).length)
        || (p.agent_code && (i.agents || []).includes(p.agent_code)) || (p.expert_code && (i.experts || []).includes(p.expert_code)) || (p.staff_id && (i.cses || []).includes(p.staff_id))
        || (creator && p.username === creator.username)).map(p => p.username);
      title = (body.isNew ? 'New customer issue · ' : 'Customer issue update · ') + (i.name || i.phone || 'Customer');
      text = myName + ': ' + cut(body.note || i.type || '', 150);
      url = '/?go=lookup'; tag = 'issue-' + i.id;
    } else if (body.kind === 'ann') {
      if (!['management', 'ops', 'manager'].includes(me.role)) return out({ error: 'Not allowed' }, 403);
      const br = body.branch || 'all';
      const cloud = ['sales', 'expert', 'ops', 'management'], puttur = ['manager', 'cse', 'ops', 'management'];
      to = P.filter(p => br === 'all' || (br === 'cloud' ? cloud : puttur).includes(p.role)).map(p => p.username);
      title = '📣 ' + cut(body.title || 'Announcement', 60); text = cut(body.text || '', 170);
      url = '/?go=hr_me'; tag = 'ann-' + (body.id || Date.now());
    } else return out({ error: 'Unknown kind' }, 400);

    to = [...new Set(to)].filter(u => u && (self || u !== me.username));
    if (!to.length) return out({ sent: 0, people: 0 });

    const { data: subs } = await admin.from('push_subs').select('*').in('username', to);
    const ment = new Set<string>(body._mentioned || []);
    let sent = 0, gone = 0, failed = 0; const codes: number[] = [];
    await Promise.all((subs || []).map(async (s: any) => {
      try {
        const extra = ment.has(s.username) ? ' · mentioned you' : '';
        const payload = JSON.stringify({ title: title + extra, body: text, url, tag, type });
        const st = await sendPush(s, payload, type === 'issue' || extra ? 'high' : 'normal', V);
        codes.push(st);
        if (st >= 200 && st < 300) { sent++; await admin.from('push_subs').update({ last_ok: new Date().toISOString() }).eq('endpoint', s.endpoint); }
        else if (st === 404 || st === 410) { gone++; await admin.from('push_subs').delete().eq('endpoint', s.endpoint); }
        else failed++;
      } catch (_) { failed++; }
    }));
    return out({ sent, gone, failed, devices: (subs || []).length, people: to.length, codes: codes.slice(0, 5) });
  } catch (e) {
    return out({ error: String(e) }, 500);
  }
});
