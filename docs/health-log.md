# Skilleaze HQ · health log

Newest first. Written by the automatic health check (see `health-check.md`).

## 25 Nov 2026, 06:25 IST · automatic check (window 03:23–06:23 IST)
Healthy: no 5xx, no database/edge-function errors, logins fine, advisors unchanged, data checks clean except the known SAN-1794807224485; night traffic (~440 requests); only small refusal bursts (MUNEEBA 3 rounds at 03:28 and 06:12 IST, ishfa 12 × PUT-1795513709056 05:13–05:17 IST) — below threshold. Live version.txt not reachable from the sandbox (proxy).

## 25 Nov 2026, 03:25 IST · automatic check (window 00:23–03:23 IST)
Healthy: no 5xx, no database/edge-function errors, logins fine, advisors unchanged, data checks clean except the known SAN-1794807224485; traffic down to ~5,300 requests in 3 h after the 00:25 realtime fix; only small refusal bursts (almisha 16 rounds 00:36–00:48 IST, MUNEEBA 1 round 02:19 IST) — below threshold, no fix needed. Live version.txt not reachable from the sandbox (proxy).

## 25 Nov 2026, 00:25 IST · automatic check (window 21:20–00:25 IST)
**Checked**: API errors, database errors, edge functions (no errors), logins (1 slow refresh-token 500 and 2 timeouts during the
outage below — noise), security advisors (unchanged), runbook data checks.
**Found**
- **Database crashed and restarted at 22:34–22:36 IST** ("database system was not properly shut down; automatic recovery").
  About 2 minutes of 520/521/522 errors for everyone signed in. Before it: statement timeouts from 21:33 IST and 11-second
  `app_kv` writes/reads. Load at the time was ~38,000 requests per 15 min, driven by **ishfa's refused-save loop**: ~13 uploads a
  minute of the ~0.9 MB `app_kv.puttur`, and each upload made every open app (16–20 people) download it again. After the
  restart ishfa's loop stopped (last refusal 23:53 IST) and traffic fell to ~2,000–8,000 per 15 min.
- **MUNEEBA**'s loop ran until 00:01 IST (162 × patch_extra + order_experts, same 6 ALPHA orders); no refusals since — her app now
  looks updated. **zahir**: 2 refusals at 22:37 IST only.
- **New: realtime re-subscribe loop in every app** (root cause of the high background traffic). After any single realtime drop
  (network blip, the DB restart), `subscribeAll` in `supabase/live.js` removed the old channel; supabase-js then reported that old
  channel as "CLOSED", which started another re-subscribe ~2.5 s later, and so on forever — each round a full refresh (9 queries).
  Seen in the logs: zahir 426 refreshes 22:37–23:40 IST with nobody else saving; user ed3f49e5 489 refreshes in 25 min after
  00:00 IST. Reproduced in a node test against the vendored supabase-js behaviour: one blip → 234 re-subscribes in 10 min.
- Data checks clean except the known SAN-1794807224485 (CV = FATHIMA.HANA, inactive).
**Fixed** (app, build b1795546604647): `supabase/live.js` `subscribeAll` — only the current channel may trigger a re-subscribe
(old channels' CLOSED is ignored); the unsubscribe also closes the newest channel. Tests: node simulation (old: 234 re-subscribes /
10 min after one blip; new: 2), repeated blips still reconnect once each, bundle check, live bundle loads with no script errors,
preview as Management / Head of ops / Ops manager / Sales agent / CV expert / LinkedIn expert (no script errors).
**Needs the owner**
1. The database restart (22:34 IST) was an overload, most likely memory on the current compute size. With the loops gone and this
   fix live, load should stay far lower; if it happens again, consider a bigger Supabase compute add-on (billing decision).
2. Still open: SAN-1794807224485 expert; SQL 50 + ALPHA-1795272437380 re-set (03:25 entry); consultants reading all enquiries via
   `app_kv.puttur` (15:25 entry); the 0.9 MB `app_kv.puttur` being re-downloaded by every app on each Puttur save (design item).

## 24 Nov 2026, 21:25 IST · automatic check (window 18:23–21:23 IST)
**Checked**: API errors, database errors, edge functions (no errors), logins (3 wrong passwords, ~5 slow `/auth/v1/user`
timeouts incl. one 504 at 21:15 IST — noise), security advisors (unchanged), runbook data checks.
**Found**
- The same three refused-save loops are still running, ~9,000 refused requests in the window:
  - **ishfa** 1,250 × PATCH PUT-1795513709056 ("Operations … cannot change order status", 18:30–21:22 IST, still going).
  - **zahir** 1,331 × (patch_extra + order_experts) on KAPPA-1793962857180 / KAPPA-1794467721091 (18:58–19:33 IST, every ~2.5 s);
    each round re-sends `wx = {linkedin: X, cv: X}` (X = SHIHAB / FATHIMATH.SHIREENA) — refused correctly, nothing changed.
  - **MUNEEBA** 461 × (patch_extra + order_experts) on her 6 ALPHA orders (18:36–21:16 IST).
  - **Why the earlier fixes did not reach them**: their requests show code from **before 23 Nov 18:10** (they still send
    order_experts for an order whose save was just refused — the current build never does; checked with a node test of
    `push`). zahir "opened" at 18:56 IST by signing in again in an old tab, not by reloading. The app's update check
    (`version.txt`) skips the reload while a save is pending — and in a refused-save loop a save is always pending,
    so these tabs can never update on their own.
- Data checks clean except the known SAN-1794807224485 (CV = FATHIMA.HANA, inactive) and ALPHA-1795272437380 (CV = THOIBA).
**Fixed** (app, build b1795535857202): `src/app.html` update check — if a new build is out and the save is still
pending after 3 checks (~4 min), the app saves unsaved changes to the device outbox and reloads anyway (the outbox is
restored and re-saved after the reload). Tests: unit test of the check (clean → reloads at once; stuck → reloads on the
3rd check with the outbox saved), bundle check, preview as Ops manager / CV expert / Management (no script errors).
This only helps from this build on — tabs already stuck on old code still need a manual reload.
**Needs the owner**
1. Ask **ishfa**, **zahir** and **MUNEEBA** to fully close every CRM tab/window (or the installed app) and open it
   again. Signing out and in is not enough.
2. Still open: SAN-1794807224485 expert; SQL 50 + ALPHA-1795272437380 re-set (03:25 entry); consultants reading all
   enquiries via `app_kv.puttur` (15:25 entry).

## 24 Nov 2026, 18:25 IST · automatic check (window 15:23–18:23 IST)
**Checked**: API errors, database errors, edge functions (none), logins (no failures), security advisors (unchanged),
runbook data checks.
**Found**
- **ishfa (Ops manager): 672 refused saves** on PUT-1795513709056 (16:48–18:16 IST), each `{"status":"CV SUBMITTED"}` →
  "Operations can assign experts but cannot change order status or money" (the guard was right; nothing was changed).
  RILWANA closed that order at 16:48:37 IST; ishfa's app kept sending its older status back. Each round also re-uploaded
  the ~0.9 MB `app_kv.puttur` (≈700 times), which makes every open app download it again.
  **Root cause** (reproduced in a node test of `liveRefresh`/`livePush`): when a refresh finished while a save was in
  flight, the save's success then set `_lastPushed` back to the pre-refresh copy, so the server's newer values looked
  like local edits and were re-sent on every refresh; this refusal text was also not recognised as "refused for good",
  so the self-heal never ran.
- **MUNEEBA: 486 + 484 refusals** (patch_extra + order_experts, 6 ALPHA orders, bursts 17:08–18:20 IST) — the same loop
  as in the 00:35 entry, running since at least 23 Nov 18:30 IST (~3,200 more overnight; earlier entries under-counted it).
  Request sizes show she re-sends old server values (e.g. ALPHA-1795272437380 CV = THOIBA), which matches the same
  stale-copy race. Desktop Safari (Mac).
- almisha 2 refusals (ETA-1793816841104, one round). faiza 7 × 401 at 17:52 IST (expired session, noise).
- Data checks clean except the known SAN-1794807224485 (CV = FATHIMA.HANA) and ALPHA-1795272437380 (CV = THOIBA).
**Fixed** (app, build b1795525263757):
- `src/app.html` liveRefresh: a refresh that returns while a save is running is dropped and re-loaded after the save
  (sync point not advanced, nothing lost), so a save can no longer overwrite newer server values in `_lastPushed`.
  Test: race simulation — old build re-sent the server's own change, new build sends only the real edit.
- `supabase/live.js` push: "cannot change…", "cannot be moved back", "Only the Head…", "Only HR…", "not from one of your
  agents" now count as refused for good → the app shows the saved version once and stops retrying.
  Tested: regex unit check, bundle check, preview as Ops manager / CV expert / Management (no script errors).
**Needs the owner**
1. Ask **ishfa** and **MUNEEBA** to fully close the CRM and open it again (or accept the update prompt) so they get the new build.
2. Still open: SAN-1794807224485 expert; SQL 50 + ALPHA-1795272437380 re-set (see 03:25 entry); consultants reading all
   enquiries via `app_kv.puttur` (15:25 entry).

## 24 Nov 2026, 15:25 IST · automatic check (window 12:23–15:23 IST)
**Checked**: API errors, database errors, edge functions (none), logins (2 wrong passwords, noise), security advisors
(same long-standing warnings; new `login_hr_key` from SQL 51 joins the existing SECURITY DEFINER list), runbook data checks.
**Found**
- **New: Puttur consultants re-sending other consultants' enquiries.** 189 refusals on `enquiries` ("violates row-level
  security policy (USING expression)"): nilufar 172 (14:23–14:28 IST, looping on nuha's ENQ-1795506716674),
  arifa 12, nuha 3, faiza 2 (all on nilufar's new ENQ-1795512176409, seconds after she created it).
  Root cause: every consultant's app also holds all enquiries through `app_kv.puttur` (2,365 copies), so a foreign
  enquiry can show up as "new" in a save and is upserted; RLS refuses it (correctly). The self-heal from 49 did not
  stop the loop for enquiries because it looked for them in `data.enq` instead of `data.puttur.enquiries`.
  No data was lost or changed. Not a business-rule issue.
- Other refusals low: almisha 10 (ETA-1793816841104, one round 12:56 IST), ishfa 4 (orders, one click).
- Data checks clean except the known SAN-1794807224485 (CV = FATHIMA.HANA) and ALPHA-1795272437380 (CV = THOIBA).
**Fixed** (app, build b1795514124392):
- `supabase/live.js` push: a consultant's save only ever sends enquiries whose consultant is that login (`staff_id`).
- `src/app.html` livePush heal: refused enquiries are now put back in `puttur.enquiries`, so any refusal stops after one round.
  Tested: node test of push as cse (only own enquiry sent) and manager (unchanged), heal unit test, preview as Consultant and
  Puttur manager (no script errors).
**Needs the owner**
1. Consultants can read every enquiry (names/phones) through `app_kv.puttur`, although the `enquiries` table limits them
   to their own. Decide whether that is wanted; narrowing it is a who-sees-what change, so it was not made.
2. Still open: SAN-1794807224485 expert; SQL 50 + ALPHA-1795272437380 re-set (see 03:25 entry).

## 24 Nov 2026, 12:25 IST · automatic check (window 09:20–12:23 IST)
Quiet: 16 refusals in 2 single rounds (MUNEEBA 10:26 IST, haseena 10:58 IST; 403/42501 + one "Experts can only update work status"), no 5xx, no new database or edge-function errors, logins normal, advisors unchanged.
Data checks clean except the known SAN-1794807224485 (CV = FATHIMA.HANA) and ALPHA-1795272437380 (CV = THOIBA). SQL 50 test not retried (tool needs an approval). Nothing changed; owner items from 03:25 still open.

## 24 Nov 2026, 09:25 IST · automatic check (window 06:22–09:22 IST)
Quiet: 6 refusals (MUNEEBA, 07:24 IST, one round, 403/42501), no 5xx, no new database or edge-function errors, logins normal,
advisors unchanged. Data checks clean except the known SAN-1794807224485 (CV = FATHIMA.HANA) and ALPHA-1795272437380 (CV = THOIBA).
SQL 50 rollback test sent again; the SQL tool again waited for an approval, so it did not run. Nothing changed; owner items from 03:25 still open.

## 24 Nov 2026, 06:25 IST · automatic check (window 03:22–06:22 IST)
Quiet: 11 refusals (MUNEEBA, 04:45–05:01 IST, 403/42501, stopped), no 5xx, no database/edge-function errors, logins
normal, advisors unchanged; data checks clean except the two known items (SAN-1794807224485 CV = FATHIMA.HANA;
ALPHA-1795272437380 CV = THOIBA). SQL 50 rollback test tried again, SQL tool again waited for an approval → not run.
Nothing changed; owner items from the 03:25 entry still open.

## 24 Nov 2026, 03:25 IST · automatic check (window 00:23–03:23 IST)
**Checked**: API errors, database errors (none), edge functions (admin-users all 200), logins (token refreshes
only, no failures), security advisors (same long-standing warnings, nothing new), runbook data checks (read-only
SQL worked). Live version.txt not checked (admin.skilleaze.com unreachable from the sandbox; repo = b1795450174078).
**Found**
- Quiet window. Refusals only: almisha 16 rounds (00:57–01:00 IST, then stopped) and MUNEEBA 1 round (01:31 IST),
  all 403 / 42501. Loops now stop on their own; the zahir / MUNEEBA tight loops from the last entry did not return.
- Data checks clean: status = extra.status, single-service tst = status, no CLOSED without closeAt, no pending
  transfer older than 7 days, every open assignment in wx has an order_experts row, HR person_key matches.
- **New:** SAN-1794807224485 (16 Nov, PENDING) is assigned CV = `FATHIMA.HANA`, which matches no login. Agent SAN
  typed it on 16 Nov 23:17 IST (activity_log). No expert sees this order. It could mean FATHIMATH HANA or HANA, so
  it was not changed.
- ALPHA-1795272437380 still CV = THOIBA (unchanged since last entry).
**Fixed**: nothing. SQL 50 was assembled with its rollback test and sent, but the SQL tool again stopped to ask
for an approval nobody was there to give, so it was neither tested nor applied (no change made).
**Needs the owner**
1. SAN-1794807224485: ask SAN / operations which expert was meant and re-assign it.
2. Still open from last entry: run `docs/pending-sql/50_test.sql` then 50; then re-set ALPHA-1795272437380
   (CV = HAFSATH MUYEENA, LinkedIn = THOIBA); allow the Supabase SQL tool to run writes without asking.

## 24 Nov 2026, 00:35 IST · automatic check (window 21:23–00:23 IST)
**Checked**: API errors, database errors, edge functions (none), logins (5 wrong passwords + 2 expired
refresh tokens, noise), security advisors (same long-standing warnings, nothing new). Read-only SQL worked
this time (used to trace the loops below), but the runbook data checks and the SQL 50 test could **not** be
finished: the SQL tool again asked for an approval nobody was there to give, and then could not be used.
**Found**
- One-off: ~120 × 521 (origin unreachable) for every open app at 21:31:51 IST, 1 second. Nothing to fix.
- Refused-save loops (all 403 / 42501, "not open to your login" + order_experts RLS):
  - zahir: new tab opened 22:58 IST, then a tight loop every ~2.5 s until 23:27 (691 rounds = ~9,000 requests).
    Each round re-sent KAPPA-1793962857180 and KAPPA-1794467721091 (combined orders whose CV part is open,
    LinkedIn already assigned; he can read them but not change them; refused) and DELTA-1795367164004 (his own
    order; saved but with nothing changed, only `updated_at` moved 1,382 times). Stopped by itself at 23:27.
  - MUNEEBA: high rate until ~22:30, then about one round every few minutes until 00:19. She keeps re-sending 6 ALPHA
    orders she is not assigned to (incl. ALPHA-1795272437380).
  - FATHIMATH HANA: SAN-1794034324693, 199 times, stopped 21:58. reem 6, HAFSATH MUYEENA 4 (low).
  - So the "undo refused saves" logic in the app does not stop every loop. zahir's tab was opened after the
    21:40 fix, so this happens on the current build too. The exact path that re-sends the undone records
    is **not yet found** (code read: livePush heal / liveRefresh "dirty" / outbox). Not changed blind.
- ALPHA-1795272437380 still damaged (CV = THOIBA in wx, order_experts cv = THOIBA + linkedin = THOIBA). activity_log
  shows the right value: ALPHA set CV = HAFSATH MUYEENA, LinkedIn = THOIBA at 21:22:52 IST; hafsath.muyeena's app
  overwrote it at 21:25:28 IST.
**Fixed**: nothing changed this run (no fix had a proven root cause and passing tests).
- SQL 50 reviewed again against the live functions: claim_order only inserts into order_experts, set_task_status
  only changes tst, so Take new work / status saves are not blocked by it. A ready rollback-only test is in
  `docs/pending-sql/50_test.sql` (it changes nothing).
**Needs the owner**
1. Run `docs/pending-sql/50_test.sql` in the SQL Editor (paste the body of 50 where it says). If every line matches
   the expected list, run `50_expert_keep_assignments.sql` and move it to `supabase/`.
2. After 50 is applied: ALPHA/operations set ALPHA-1795272437380 CV = HAFSATH MUYEENA (LinkedIn = THOIBA) again.
3. Ask zahir, MUNEEBA and FATHIMATH HANA to fully close the CRM tab/app and open it again.
4. Allow the Supabase connector's SQL tool to run without asking (or approve it when the check runs) — otherwise
   the data checks and database fixes cannot run unattended.

## 23 Nov 2026, 21:40 IST · automatic check (window 18:25–21:25 IST)
**Checked**: API errors, database errors (none), edge functions (none), logins (1 wrong password, noise),
security advisors (same long-standing warnings, nothing new). Data checks and live version.txt could
**not** be run: the Supabase SQL tool asked for an approval nobody was there to give, and admin.skilleaze.com
is not reachable from the check's sandbox.
**Found**
- Refused-save loops still running: MUNEEBA ~2,350 × (patch_extra + order_experts) in 3 h, still going at 21:22;
  zahir 546, reem 261, HAFSATH MUYEENA ~100, FATHIMATH HANA 9 (all 403 / 42501). MUNEEBA's tab is older than the
  18:10 fix. An app with unsaved changes never takes the update prompt, so these tabs stay on the old build.
- **Assignment overwritten (data damage)**: ALPHA-1795272437380 (CV + Cover letter + LinkedIn). Agent ALPHA set
  CV = HAFSATH MUYEENA, LinkedIn = THOIBA at 20:55 and again 21:22 IST; both times HAFSATH MUYEENA's app re-sent an
  old copy a few minutes later (20:55:58, 21:25:28 IST) and the order is now CV = THOIBA, LinkedIn missing from wx
  (order_experts still has LinkedIn = THOIBA). Cause: once the agent assigned her, the old refused save was
  suddenly allowed and went through. The database lets an expert's app rewrite who is assigned
  (patch_extra → wx, and order_experts update has `with check (true)`).
- Experts often flip their own CV assignment on/off (reem 10 orders at 11:02 IST, MUNEEBA, haseena) — same
  stale-copy pattern; these only touch their own part.
**Fixed (app, this commit)**
- "Take new work": after claim_order succeeds the pick is shown locally and never re-sent (the server already
  saved it; an expert's save of it was refused and looped).
- Refused-for-good records are removed from the device's unsaved-changes box, so they are not re-sent after a
  reload and no longer block the automatic update.
- "Close · not mine" (give back) clears the order's CV-expert field only when it is the expert's own name
  (giving back a LinkedIn part used to wipe the CV expert).
- Tested in preview (expert give back, management, agent): no script errors.
**Not done — needs the owner**
1. Run `docs/pending-sql/50_expert_keep_assignments.sql` (experts can no longer overwrite who is assigned;
   give back and Take new work still work). It was written but **not tested or applied**, because the SQL tool
   needed an approval. Test it in begin … rollback first, then move it to `supabase/50_…sql`.
2. ALPHA-1795272437380: ask ALPHA/operations to set CV = HAFSATH MUYEENA (and LinkedIn = THOIBA) again — only
   **after** HAFSATH MUYEENA has closed and reopened the app, or her old tab will overwrite it a third time.
3. Ask MUNEEBA, HAFSATH MUYEENA, FATHIMATH HANA, zahir and reem to fully close the CRM tab/app and open it again.

## 23 Nov 2026, 16:45 IST · first sweep (manual)
**Found**
- MUNEEBA: ~4,300 refused saves in 2 h. Tapping "Take this work" on the open CV part of CV + LinkedIn
  orders got "Already taken by <LinkedIn expert>" (claim_order read the copied LinkedIn name as the CV
  expert) and the app saved that answer into orders she cannot change, retrying forever.
- haseena: 17,699 refused HR saves + ~2,200 order refusals; no punch saved since 5 Nov (key mismatch).
- Reem: ~500 refused expert-link / order saves (old retry queue).
- 13 × 500 "lock not available" at 09:01 UTC while migration 48 ran (one-off).
**Fixed**
- App: refused-for-good saves are undone locally and reported once (no endless retries);
  "Already taken" is never saved.
- SQL 49: own HR records always use the login's key; claim_order ignores copied names.
**Left for owner**: none.
