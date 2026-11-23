# Skilleaze HQ · health log

Newest first. Written by the automatic health check (see `health-check.md`).

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
