# Skilleaze HQ · automatic health check (runbook)

A scheduled task runs this every 3 hours. The owner has authorised it to **find and fix issues on its own**,
code and database, within the guardrails below. Read `CLAUDE.md` first; its rules always win.

- Supabase project: `rmtljlzvmdnfdazytyoj` (Supabase connector tools)
- Repo: `skilleaze/skilleazecrm` (push to `main` = live on admin.skilleaze.com in ~1 min)
- Window: the last 3 hours (use `iso_timestamp_start` = now − 3 h on every log query)

## 1. Look
1. **API errors** (`edge_logs`): group by method, path, status, `response.headers.proxy_status`, user
   (`request.sb.auth_user`). Status ≥ 400.
2. **Database errors** (`postgres_logs`, severity ERROR/FATAL/PANIC): group by message.
3. **Edge functions** (`function_logs`, `function_edge_logs`): errors from `push-send`, `admin-users`.
4. **Logins** (`auth_logs`): repeated failures for one user, token refresh failures.
5. **Advisors**: `get_advisors` security and performance; note only new items.
6. **Data checks** (read-only SQL; CRM period = date ≥ 2026-11-02, `summary` lines excluded):
   - `orders.status` ≠ `extra->>'status'`; single-service orders whose only `tst` value ≠ `status`.
   - Open orders whose expert (`extra.wx.*`, or `extra.expert` when it is not a copy of another
     service's expert) has no matching `order_experts` row.
   - `order_experts` rows whose `expert_code` matches no active expert profile.
   - Profiles whose `person_key` differs from the key on their own new `hr_records`.
   - Transfers `pending` older than 7 days; orders CLOSED with no `closeAt`.
   - `version.txt` on admin.skilleaze.com equals the repo's `version.txt`.

## 2. Decide
Fix it when it is a real defect with a clear root cause, for example:
- the same refusal repeating (> 50 in the window for one user/path) — an app retrying something impossible;
- any 5xx, any new database error message, a failing edge function;
- data that breaks the rules in CLAUDE.md (status mismatch, missing expert link, wrong key).

Do **not** "fix" these; report them instead:
- anything that needs a business decision (pay, balances, ad maths, prices, who sees what);
- one-off user mistakes (a wrong password, one refused click);
- noise (expired tokens that refresh fine, a single 401).

## 3. Fix
- Find the root cause first (logs → code → data). One fix per root cause, smallest change that works.
- **App code**: edit `src/app.html` / `supabase/live.js` with exact find → replace, then
  `python3 tools/bundle.py release`, syntax-check, `python3 tools/preview.py` and test the screen in
  headless Chrome, commit, `git -c push.negotiate=true push origin main`.
- **Database**: new file `supabase/NN_name.sql` (next number, safe to run twice, `$fn$` quoting, no `?`
  operator). First run it **inside `begin; … rollback;`** together with tests that act as the affected
  users (`set_config('request.jwt.claims', …)` + `set local role authenticated`). Only if every test
  passes, apply it with `apply_migration`, then re-check.
- **Data repair**: only when the activity log proves the correct value; update only the rows involved;
  record exactly what changed in the health log.

## Guardrails (never)
- Never change or delete data dated on or before **1 Nov 2026** (pre-CRM, locked).
- Never delete orders, transfers, payments, HR records or logins.
- Never widen who can read or change data beyond what the fix needs; never touch passwords, keys or
  secrets; never sign in as a staff member.
- Never change business rules in CLAUDE.md §5 (pay, balances, ad spend, payments) — report instead.
- Never "fix" by disabling a guard trigger permanently or by catching and hiding an error.
- If a fix fails its tests twice, stop and report it.

## 4. Report
- Append one entry to `docs/health-log.md` (date/time IST, what was checked, findings, fixes with
  commit / SQL file, anything left for the owner) and push it with the fix commit.
- Send a push notification **only when something was fixed or needs the owner**; a clean run stays quiet.
