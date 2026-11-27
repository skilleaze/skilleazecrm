# Skilleaze HQ · health log

Newest first. Written by the automatic health check (see `health-check.md`).

## 27 Nov 2026, 12:25 IST · automatic check (window 09:23–12:23 IST)
Healthy: no 4xx/5xx in ~47.2k requests except 1 wrong password, no database/edge-function/login errors, advisors unchanged; data checks clean except the known SAN-1794807224485 (inactive expert FATHIMA.HANA) and ETA-1793816841104 (CV still Not started, `expert` ALMISHA vs `wx.cv` SHIREENA — still needs ops to reassign). Live version.txt not reachable from the sandbox (proxy). Older owner items still open.

## 27 Nov 2026, 09:25 IST · automatic check (window 06:23–09:23 IST)
Healthy: no 4xx/5xx in ~1.4k requests (quiet morning), no database/edge-function/login errors, advisors unchanged; data checks clean except the known SAN-1794807224485 (inactive expert FATHIMA.HANA) and ETA-1793816841104 (CV still Not started, `expert` ALMISHA vs `wx.cv` SHIREENA — still needs ops to reassign). Live version.txt not reachable from the sandbox (proxy). Older owner items still open.

## 27 Nov 2026, 06:25 IST · automatic check (window 03:23–06:23 IST)
Healthy: no 4xx/5xx in ~230 requests (quiet night), no database/edge-function/login errors (1 subquery error was the last check's own query), advisors unchanged; data checks clean except the known SAN-1794807224485 (inactive expert FATHIMA.HANA) and ETA-1793816841104 (CV still Not started, `expert` ALMISHA vs `wx.cv` SHIREENA — still needs ops to reassign). Live version.txt not reachable from the sandbox (proxy). Older owner items still open.

## 27 Nov 2026, 03:25 IST · automatic check (window 00:23–03:23 IST)
Healthy: no 4xx/5xx in ~2.7k requests (quiet night), no database/edge-function/login errors (1 column error was the last check's own query), advisors unchanged; data checks clean except the known SAN-1794807224485 (inactive expert FATHIMA.HANA) and ETA-1793816841104 (CV still Not started, `expert` ALMISHA vs `wx.cv` SHIREENA — still needs ops to reassign). Live version.txt not reachable from the sandbox (proxy). Older owner items still open.

## 27 Nov 2026, 00:25 IST · automatic check (window 21:23–00:23 IST)
Healthy: no 4xx/5xx in ~20.7k requests, no database/edge-function/login errors, advisors unchanged; data checks clean except the known SAN-1794807224485 (inactive expert FATHIMA.HANA) and ETA-1793816841104 (CV still Not started, `expert` ALMISHA vs `wx.cv` SHIREENA — still needs ops to reassign). Live version.txt not reachable from the sandbox (proxy). Older owner items still open.

## 26 Nov 2026, 21:25 IST · automatic check (window 18:22–21:22 IST)
Mostly healthy: ~29k requests, 2 one-off 5xx (1 × `lookup_orders` statement timeout for muneeba at 19:26 IST — the same search runs in ~0.2 s now, 18 other calls fine; 1 × `hr_records` 555 upstream timeout for muneez at 19:48 IST), no other database/edge-function errors (1 column error was the last check's own query), logins fine (1 wrong password + 1 stale refresh token from a `localhost:3000` page — noise), advisors unchanged; data checks clean except the known SAN-1794807224485 (inactive expert FATHIMA.HANA) and **one new finding**: **ETA-1793816841104** has `expert` = ALMISHA but its CV task (`wx.cv` + `order_experts`) is FATHIMATH.SHIREENA. activity_log + edge logs: almisha claimed the CV at 10:55 IST (`claim_order`), then at 11:37 IST an old build in her browser replayed a save it had queued before the claim (refused twice at 10:40/10:54 IST) and that put `wx.cv` back to SHIREENA; her tab then kept getting refused until 11:40 IST. The current build already treats these refusals as final, so there is no code fix to make. I did not change the data because which expert should do it is an assignment call. CV is still Not started (LinkedIn is closed, by SHIREENA). **Needs ops**: reassign the CV on ETA-1793816841104 in Assign experts (to ALMISHA if she is doing it, or confirm SHIREENA). Live version.txt not reachable from the sandbox (proxy). Older owner items still open.

## 26 Nov 2026, 18:25 IST · automatic check (window 15:22–18:22 IST)
Healthy: no 5xx in ~47.7k requests, no database/edge-function errors, logins fine (3 weak-password refusals when creating a login, 1 wrong password, 1 one-off refresh timeout — noise), advisors unchanged; only 3 × `set_task_status` 400s for wau at 15:28 IST (the same mixed-login tab, before the 15:25 fix reached it); data checks clean except the known SAN-1794807224485 (open order on inactive expert FATHIMA.HANA). WAU has since entered one transfer today (t1795687698936, ₹2,970, pending) — owner to confirm it covers the 3 lost ones. Older owner items still open.

## 26 Nov 2026, 15:25 IST · automatic check (window 12:22–15:22 IST)
**Checked**: API errors (~56.8k requests, no 5xx), database errors, edge functions (no errors), logins (4 wrong passwords from a
`localhost:3000` page + 1 stale refresh token — noise), security advisors (unchanged), runbook data checks (clean except the known
SAN-1794807224485 on inactive expert FATHIMA.HANA). Live version.txt not checked (proxy).
**Found**: one Mac Chrome is used for both **wau** (agent) and **fathimath.ishfana** (expert). With a WAU tab still open, the other tab
signed in as the expert (14:37 IST); the browser shares one sign-in across tabs, so the WAU tab then sent its saves under the
expert's login. The database refused them correctly (6 × transfers RLS, 2 × orders RLS), and the app's refused-save self-heal then
**dropped them**: 3 WAU transfers (t1795684868767 at 14:51, t1795686515614 and t1795686537226 at 15:18 IST) and order
WAU-1795686690625 (15:21) were never saved. WAU re-entered one order (WAU-1795686804188, musthafa, ₹490) after signing back in;
**no WAU transfer exists after 24 Nov**. Also 3 × `set_task_status` refusals for wau at 14:37 (WAU tab trying expert work — same cause).
**Fixed** (`supabase/live.js`, build b1795686958224): every save / work-status change first checks that the browser's current sign-in
is still this tab's login. If another tab signed in as someone else, nothing is sent (changes stay in this login's on-device outbox and
save when that login signs in again) and the tab tells the person and reloads as the new login. Same-tab sign-in is unaffected.
Tested with a mocked client (same user saves; switched user sends nothing, not marked refused, tab reloads; same-tab sign-in no reload)
and both builds boot cleanly in headless Chrome.
**Needs the owner**: ask **WAU** to re-enter the 3 transfers from this afternoon (and check the second order), and to use one login per
browser (or a separate browser/profile for the expert login). Older items (activity_log size, SQL 50/52, SAN expert, etc.) still open.

## 26 Nov 2026, 12:25 IST · automatic check (window 09:23–12:23 IST)
Healthy: no 5xx in ~19.3k requests, no database/edge-function/login errors, advisors unchanged; only 10 × `order_experts` + 10 × `patch_extra` 403s for almisha on ETA-1793816841104 (10:40–11:40 IST, below threshold); data checks clean except the known SAN-1794807224485 (open order on inactive expert FATHIMA.HANA). Owner items from 25 Nov 12:25 (activity_log size, SQL 50/52, SAN expert, etc.) still open.

## 26 Nov 2026, 09:25 IST · automatic check (window 06:23–09:23 IST)
Healthy: no 4xx/5xx in ~2.2k requests except 1 wrong password, no database/edge-function/login errors, advisors unchanged; data checks clean except the known SAN-1794807224485 (open order on inactive expert FATHIMA.HANA). Live version.txt not reachable from the sandbox (proxy). Owner items from 12:25 (activity_log size, SQL 50/52, SAN expert, etc.) still open.

## 26 Nov 2026, 06:25 IST · automatic check (window 03:23–06:23 IST)
Healthy: no 4xx/5xx in ~134 requests (quiet night), no database/edge-function/login errors, advisors unchanged; data checks clean except the known SAN-1794807224485 (open order on inactive expert FATHIMA.HANA) and Munavvir's manager-entered punch for Arifa (correct). Live version.txt not reachable from the sandbox (proxy). Owner items from 12:25 (activity_log size, SQL 50/52, SAN expert, etc.) still open.

## 26 Nov 2026, 03:25 IST · automatic check (window 00:22–03:22 IST)
Healthy: no 5xx in ~2.7k requests (quiet night), no database/edge-function/login errors, advisors unchanged; only 4 × `order_experts` + 4 × `patch_extra` 403s for the same expert as 00:25 (below threshold); data checks clean except the known SAN-1794807224485 (open order on inactive expert FATHIMA.HANA). Owner items from 12:25 (activity_log size, SQL 50/52, SAN expert, etc.) still open.

## 26 Nov 2026, 00:25 IST · automatic check (window 21:22–00:22 IST)
Healthy: no 5xx in ~30.4k requests, no database/edge-function/login errors, advisors unchanged; only 4 × `order_experts` + 4 × `patch_extra` 403s for one expert (below threshold); data checks clean except the known SAN-1794807224485 (open order on inactive expert FATHIMA.HANA) and Munavvir's manager-entered punch for Arifa (correct). Live version.txt not reachable from the sandbox (proxy). Owner items from 12:25 (activity_log size, SQL 50/52, SAN expert, etc.) still open.

## 25 Nov 2026, 21:25 IST · automatic check (window 18:22–21:22 IST)
Healthy: no 5xx in ~22.3k requests, no database/edge-function errors (1 enum error was this check's own query), logins fine (1 × 401 app_kv save — noise), advisors unchanged; almisha had 27 stale-tab refusal rounds (20:20–20:25 IST, below threshold, stopped); data checks clean except the known SAN-1794807224485 (open order on inactive expert FATHIMA.HANA). Owner items from 12:25 (activity_log size, SQL 50/52, SAN expert, etc.) still open.

## 25 Nov 2026, 18:25 IST · automatic check (window 15:22–18:22 IST)
Healthy: no 5xx, no database/edge-function errors (1 expected "Balance not received yet" refusal), logins fine (2 wrong passwords, 1 stale refresh token — noise), advisors unchanged; no stale-tab refusal loops (only 4 × 4xx in ~48.7k requests); data checks clean except the known SAN-1794807224485 (open order still on inactive expert FATHIMA.HANA). Live version.txt not reachable from the sandbox (proxy). Owner items from 12:25 (activity_log size, SQL 50/52, SAN expert, etc.) still open.

## 25 Nov 2026, 15:25 IST · automatic check (window 12:23–15:23 IST)
Healthy: no 5xx, no database/edge-function errors, logins fine, advisors unchanged; both stale-tab loops have **stopped** (MUNEEBA last refusal 12:27 IST, almisha 12:31 IST, ishfa 12:55 IST — tabs evidently reopened), traffic back to ~6–7k requests per 30 min, slowest response 0.8 s in the last half hour; data checks clean except the known SAN-1794807224485 (1 manager-entered punch fix for arifa under her own key — correct). SQL 52 not applied (no longer urgent). Live version.txt not reachable from the sandbox (proxy). Owner items from 12:25 (activity_log size, SQL 50/52, SAN expert, etc.) still open.

## 25 Nov 2026, 12:25 IST · automatic check (window 09:23–12:23 IST)
**Checked**: API errors, database errors, edge functions (no errors), logins (no failures), security advisors (unchanged: 4 mutable
search_path, SECURITY DEFINER callable lints). Runbook data checks **not run** again: the first write-test SQL triggered the
Supabase approval prompt, which timed out (read-only queries before it worked).
**Found** (no 5xx, no new database error messages)
- **Both stale-tab refusal loops are still running and MUNEEBA's got much heavier.**
  - MUNEEBA (expert): 1,330 × `order_experts` RLS refusals + 1,326 × `patch_extra` "not open to your login" on the same 6 ALPHA orders
    (+ ETA-1793816841104) from 09:55 IST, ~60 a minute since 12:00 IST, each round followed by a full refresh (9 queries).
    She sends `order_experts` even after `patch_extra` fails — only builds before 49 do that, so this is an old tab, not a bug in
    the current app.
  - ishfa (ops): 383 × PATCH orders "Operations … cannot change order status or money" (PUT-1795513709056), each with a re-upload
    of the ~0.9 MB `app_kv.puttur`; burst again from 12:00 IST. Two `app_kv` upserts took **10.2–10.6 s** in the last 25 min — the
    same strain that preceded last night's 22:34 IST crash.
- almisha: 10 refused rounds (12:12–12:22 IST), below threshold.
**Fixed**: nothing. `docs/pending-sql/52_kv_skip_same.sql` is still the right mitigation for the puttur re-uploads, but its required
`begin … rollback` test as ishfa could not run (approval timed out), so per the runbook it was not applied.
**Needs the owner (urgent)**
1. Ask **MUNEEBA** and **ishfa** to close every CRM tab/window (all browsers/devices) and open admin.skilleaze.com fresh.
2. Run `docs/pending-sql/52_kv_skip_same.sql` in the SQL Editor (or allow the Supabase connector's SQL without a prompt for this task).
3. Still open from 09:25: ~7 GB `activity_log`; SAN-1794807224485 expert; SQL 50 + ALPHA-1795272437380; consultants reading all
   enquiries via `app_kv.puttur`; database compute size.

## 25 Nov 2026, 09:25 IST · automatic check (window 06:23–09:23 IST)
**Checked**: API errors, database errors, edge functions (no errors), logins (1 wrong refresh token, a few slow `/auth/v1/user` — noise),
security advisors (unchanged: 4 mutable search_path, SECURITY DEFINER callable lints). The runbook data checks were **not run**:
the Supabase SQL tool started asking for an approval nobody was there to give, so this run stopped using it.
**Found**
- **ishfa's stale-tab loop is back and heavy** (Mac browser tab on a build from before 24 Nov 21:25 IST — it cannot update itself):
  295 × PATCH PUT-1795513709056 refused ("Operations … cannot change order status or money") from 07:09 IST, ~11 a minute since
  09:00 IST and still going. Every round also re-uploads the ~0.9 MB `app_kv.puttur` (316 uploads in 25 min) — the same pattern
  that crashed the database at 22:34 IST last night. Nothing is changed by it (the guard refuses correctly).
- **New: `activity_log` is ~7.1 GB of the 7.3 GB database.** `log_change` writes the full old + new `app_kv` row on every save;
  348 of the last 356 `puttur` saves were the identical value (151 MB of audit copies in 3 h). This is what fills the disk.
- MUNEEBA: 36 refused rounds on her 6 ALPHA orders (07:59–09:14 IST), below threshold; same stale-build loop as before.
- 1 database error "column h.owner does not exist" at 06:23 IST was this health check's own data-check query (noise).
**Prepared, not applied**: `docs/pending-sql/52_kv_skip_same.sql` — a last-running BEFORE UPDATE trigger on `app_kv` that skips
a save whose value is unchanged (no new row version, no audit copy, no realtime event; the save still returns OK; real changes
are saved and logged as before). The required `begin … rollback` test as ishfa could not run (approval prompt timed out), so per
the runbook it was not applied.
**Needs the owner (urgent)**
1. Ask **ishfa** to close every CRM tab/window on her Mac and open admin.skilleaze.com again (signing out is not enough).
   MUNEEBA the same.
2. Review and run `docs/pending-sql/52_kv_skip_same.sql` in the SQL Editor (or approve it on the next run).
3. Decide what to do with the ~7 GB `activity_log` (mostly identical `app_kv.puttur` copies) — e.g. archive/delete old
   `table_name='app_kv'` rows where `old_data->'value' = new_data->'value'`. Not done automatically: it is audit data.
4. Still open: SAN-1794807224485 expert; SQL 50 + ALPHA-1795272437380 re-set; consultants reading all enquiries via
   `app_kv.puttur`; database compute size.

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
