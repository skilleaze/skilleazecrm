# Skilleaze HQ · health log

Newest first. Written by the automatic health check (see `health-check.md`).

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
