# Skilleaze HQ · health log

Newest first. Written by the automatic health check (see `health-check.md`).

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
