// Skilleaze CRM · user management (create, reset password, deactivate)
// Supabase → Edge Functions → Deploy a new function → Via Editor
// Name: admin-users   → paste this file → Deploy
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const DOMAIN = 'skilleaze.com';
const out = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });

  const jwt = (req.headers.get('Authorization') || '').replace('Bearer ', '');
  const { data: { user } } = await admin.auth.getUser(jwt);
  if (!user) return out({ error: 'Not signed in' }, 401);
  const { data: me } = await admin.from('profiles').select('*').eq('id', user.id).eq('active', true).single();
  if (!me) return out({ error: 'No active profile' }, 403);

  // who may manage whom
  const may = (role: string) =>
    me.role === 'management' ||
    (me.role === 'ops' && (role === 'expert' || (me.ops_scope === 'head' && role === 'sales'))) ||
    (me.role === 'manager' && role === 'cse');

  const body = await req.json().catch(() => ({}));
  const findProfile = async (username: string) => (await admin.from('profiles').select('*').eq('username', String(username).toLowerCase()).single()).data;

  const create = async (u: any) => {
    const username = String(u.username || '').trim().toLowerCase();
    if (!/^[a-z0-9._-]{2,40}$/.test(username)) return { username, error: 'Bad username' };
    if (!may(u.role)) return { username, error: 'Not allowed for this role' };
    if (String(u.password || '').length < 8) return { username, error: 'Password must be 8+ characters' };
    const { data, error } = await admin.auth.admin.createUser({ email: `${username}@${DOMAIN}`, password: u.password, email_confirm: true });
    if (error) return { username, error: error.message };
    const { error: e2 } = await admin.from('profiles').insert({
      id: data.user.id, username, full_name: u.full_name || username, role: u.role,
      ops_scope: u.ops_scope ?? null, agent_code: u.agent_code ?? null, expert_code: u.expert_code ?? null,
      staff_id: u.staff_id ?? null, title: u.title ?? null, must_change_pw: true,
    });
    if (e2) { await admin.auth.admin.deleteUser(data.user.id); return { username, error: e2.message }; }
    return { username, ok: true };
  };

  try {
    switch (body.action) {
      case 'create':
        return out(await create(body.user));
      case 'bulk_create': {
        const res = [];
        for (const u of body.users || []) res.push(await create(u));
        return out({ results: res });
      }
      case 'reset': {
        const p = await findProfile(body.username);
        if (!p) return out({ error: 'User not found' }, 404);
        if (!may(p.role)) return out({ error: 'Not allowed' }, 403);
        if (String(body.password || '').length < 8) return out({ error: 'Password must be 8+ characters' }, 400);
        const { error } = await admin.auth.admin.updateUserById(p.id, { password: body.password });
        if (error) return out({ error: error.message }, 400);
        await admin.from('profiles').update({ must_change_pw: true }).eq('id', p.id);
        return out({ ok: true });
      }
      case 'set_active': {
        const p = await findProfile(body.username);
        if (!p) return out({ error: 'User not found' }, 404);
        if (!may(p.role) || p.id === me.id) return out({ error: 'Not allowed' }, 403);
        await admin.auth.admin.updateUserById(p.id, { ban_duration: body.active ? 'none' : '876000h' });
        await admin.from('profiles').update({ active: !!body.active }).eq('id', p.id);
        return out({ ok: true });
      }
      case 'update': {
        const p = await findProfile(body.username);
        if (!p) return out({ error: 'User not found' }, 404);
        if (!may(p.role)) return out({ error: 'Not allowed' }, 403);
        const f = body.fields || {};
        const allowed: Record<string, unknown> = {};
        for (const k of ['full_name', 'title', 'agent_code', 'expert_code', 'staff_id', 'ops_scope', 'photo_path']) if (k in f) allowed[k] = f[k];
        if (me.role === 'management' && f.role) allowed.role = f.role;
        await admin.from('profiles').update(allowed).eq('id', p.id);
        return out({ ok: true });
      }
      default:
        return out({ error: 'Unknown action' }, 400);
    }
  } catch (e) {
    return out({ error: String(e) }, 500);
  }
});
