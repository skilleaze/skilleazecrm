# CLAUDE.md · Skilleaze HQ CRM — handoff and standing rules

Read this whole file before any work. It replaces the old Claude Design project.

## 1. What this is
Skilleaze HQ is the internal CRM at **https://admin.skilleaze.com**. It handles orders, CV/LinkedIn/portfolio experts, Puttur office enquiries, cash flow, transfers, payroll, HR and attendance.

- **Front end:** one web page. `crm-source.dc.html` is the **source**. `index.html` is the **compiled copy** that goes live, with every script inlined.
- **Back end:** Supabase project `rmtljlzvmdnfdazytyoj`, region Mumbai.
  - Postgres with row-level security (RLS), Auth (username@skilleaze.com), Storage, Realtime and Edge Functions.
- **Hosting:** GitHub repo, then Vercel deploys automatically on push.
- **CV portal:** separate site `cvportal.skilleaze.com` in repo `skilleaze/cvportal.skilleaze.com`. Its source copy is in `cvportal-source/`.

## 2. Repo layout
| Path | What it is |
|---|---|
| `index.html` | LIVE app (compiled, about 1.7 MB). Do not hand-edit it unless you are replacing it with a full new build |
| `crm-source.dc.html` | Editable source of the app (about 1.3 MB): template markup plus one `class Component` logic block |
| `support.js` | Runtime that renders `.dc.html` files (`<x-dc>`, `{{ }}` holes, `<sc-if>`, `<sc-for>`). Do not modify |
| `supabase/config.js` | Public Supabase URL, publishable key and VAPID public key (safe to ship) |
| `supabase/live.js` | All server I/O: sign-in, load and delta sync, saves, storage (`docUpload`/`docUrl`/`docOpen`), push, realtime |
| `supabase/schema.sql` + `NN_*.sql` | Database setup and every migration so far, in order. All have already been run on production |
| `supabase/functions/push-send`, `admin-users` | Edge functions: web push, and creating/resetting logins with the service role |
| `version.txt` | Build id. Must equal `const BUILD = 'b…'` inside the app. Open apps compare it and prompt users to reload |
| `sw.js`, `site.webmanifest`, icons, `vercel.json` | PWA and hosting files |

Private keys (VAPID private key, service role key, DB password) are **not** in the repo. Keep them in Supabase secrets and your password manager.

## 3. How to make a change (workflow)
1. Edit **`crm-source.dc.html`**. Use small, exact find-and-replace edits; never rewrite the file.
2. Bump the build id in both places:
   - In the source: `const BUILD = 'b<Date.now()>'`
   - In `version.txt`: the same value
3. Produce the live file, using one of these:
   - **Simplest (no build tool):** copy `crm-source.dc.html` over `index.html`. It loads `support.js` and `supabase/*.js` from the repo, so all three must stay deployed.
   - **Single-file (old way):** inline the scripts into one HTML file. This step was done by Claude Design, so it is optional now.
4. **Test before you deploy.** Open the Vercel *preview* URL of the branch, or `https://admin.skilleaze.com/crm-source.dc.html`. Then:
   - Sign in as each role you touched.
   - Check the browser console for errors.
5. Commit and push to `main`. Vercel deploys in about 1 minute.
6. Tell staff to reload, or wait for the update prompt.

> **Use Claude Code (or another agent that can open the repo), not plain chat.** The source file is too big to paste into a normal chat. Claude Code can search it (`grep`) and edit exact lines.
>
> In plain claude.ai chat, paste only the function you need. Find it by searching the file for its name first (for example `putMonth(`, `trRowsX(`, `updOrder(`). Then ask for a find → replace pair.

## 4. Database changes (SQL)
- **File naming:** put each change in the next numbered file in `supabase/`. **48 is used; next is `49_…sql`.** Write the SQL so it is safe to run twice: `create or replace`, `drop … if exists`, `on conflict do nothing`.
- **Running it:** paste it into Supabase → SQL Editor and run it.
  - Give the SQL inline in chat as well as in the file.
  - Avoid the `?` jsonb operator and `$$` quoting, because the editor can break them. Use `$fn$` and `(x->>'k') is not null`.
- **Triggers that block editor fixes:** when SQL run from the editor inserts or updates rows, disable the guard around it, then turn it back on:
  - `alter table orders disable trigger trg_guard_orders;` … `enable trigger …`
  - Same for `transfers` / `trg_guard_transfers`.
  - Same for `app_kv` / `trg_kv_guard`.
  - Otherwise rows are re-dated to today, set to pending, or silently ignored.
- **Other important triggers on `orders`:**
  - `trg_keep_status_forward`: closed work stays closed. Only management, operations or the Puttur manager can move status backwards.
  - `trg_a_sync_tst`: the task-status map follows the status on single-service orders.
- **Puttur ads:** `trg_puttur_ads_keep` on `app_kv` merges `puttur.ads` by id, so a save never deletes other days.
- **Audit:** every change is written to `activity_log`. Use it to recover lost data.
- **Expert work status (47):** experts change status only through the `set_task_status(p_id, p_status, p_task, p_types)` function (app: `setSt(`, live.js: `setTaskStatus`). It checks assignment, locks the row, merges per-service status on combined orders and returns the saved row; the app shows success only after it returns. Experts can never move work back to Not started. `patch_extra` raises an error when an order update hits 0 rows (no more silent "saved").
- **Combined orders (CV + LinkedIn etc.):** overall `status` = least advanced service, so it stays PENDING until every service moves. Experts see their own task status (`_wsData` projection in `renderVals`); management/ops see "In progress · n/N closed".
- **Take new work (48):** the pool is per service (`poolT(` in the app). Experts can read their agents' open orders that still have an unassigned, not-started service (`order_open_task()` in the `o_read` policy). Picking up a non-CV service never changes `expert` (= CV expert). Policies use `((select my_assigned_orders()))::text[]` so the lists are computed once per request, not per row.

## 5. Business rules (do not change without the owner)
- **Pre-CRM period is locked.** Everything up to and including **1 Nov 2026** comes from the agents' account sheets via `35_sheet_reconcile.sql` (FIX35-* adjustment lines). Never change data dated before 2 Nov without re-running that check. The CRM started on **2 Nov 2026**.
- **Agent balance** = received to personal account − agent share − (verified + PENDING transfers). Rejected transfers never count.
  - Money received to the UAE account, Skilleaze Pay or a gateway is not in the agent's cash flow.
- **Payments:**
  - A payment in "Needs changes" does NOT hold the order; experts can start.
  - Only management, operations or the Puttur manager can confirm, reject or send back a payment.
  - Head of Operations can reset Verified back to Pending, correct details and delete duplicates.
- **Multiple CVs in one payment:** creates one order per CV, sharing one payment. Price = sum of each CV's price. Revenue is counted once.
- **Expert pay:** counts orders placed in the month that are CLOSED and not refunded.
  - ₹30 per CV order.
  - ₹5 per cover letter (from Nov 2026).
  - ₹50 per LinkedIn or job-portal order.
  - ₹100 per portfolio.
  - ₹500 per interview-training hour.
  - CV Modification pays ₹0.
  - Payroll and Leaderboard use the same rule.
  - Combined orders (owner decision, 23 Nov 2026): each expert is paid when THEIR part is closed (`taskView(o, T)`), even if another service on the order is still open. Dashboard "My points", payslip (`hrPay`) and the Experts & payroll table all use this.
- **Ad spend:**
  - Indian account: ₹ + 18% GST.
  - UAE account: AED × ₹29.40.
  - M-cost rate is the tier saved on each order or ad day (`o.t` / `a.t` = `'D<rate>'`).
  - Agents' explainer pages must **not** show ad-charge maths or M-cost as company income.
- **Time zone:** all business dates are IST (Asia/Kolkata). Use the existing `istDay()` helpers, never browser-local dates.
- **Service access:** experts can hold several services (cv / ATS / Europass / cover letter / linkedin / portfolio / jobportal / interview).
  - This is set in Accounts → Login accounts → Service access.
  - It is stored in `app_kv.expertSkills` plus the `expert_skills` table.
  - Expert ↔ agent links are in `app_kv.expertAgents` plus the `expert_agents` table.

## 6. Roles (who sees what)
- **Management:** everything.
- **Head of Operations (Dhiya):** all operations, cash flow, transfers (verify / reject / reset), payroll, HR and service access.
- **Operations manager:** assignment desk and orders only.
- **Sales agents (Cloud, Greek-letter codes such as ALPHA or DIGAMMA):** their own orders, cash and transfers.
- **Puttur manager (Munavvir):** the Puttur office, Daily ads, Payment checks and Assign experts.
- **Puttur career consultants:** Enquiries and My orders only (with name/phone search).
- **Experts:** their work queue (Take new work → Not started → Draft shared → Submitted → Revision → Closed).

## 7. Where things are in the source (search these names)
| Area | Look for |
|---|---|
| Build id | `const BUILD =` |
| Save an order | `updOrder(` |
| Combined-order task status | `taskSt`, `taskTypes`, `ST_RANK`, `tst`, `_wsData`, `mNote` |
| Expert status save | `setSt(`, `set_task_status`, `setTaskStatus` |
| Expert queue | `Take new work`, `isStart(`, `shareLbl` |
| Puttur month maths | `putMonth(` |
| Puttur orders (manager / consultant) | `isPutOrders`, `pOrdQ`, `cseOrdQ` |
| Transfers screen | `isTransfersOps`, `trRowsX(` |
| Phone search | `phoneHit`, `phD` |
| Documents | `docOpen`, `docUrl` (in `supabase/live.js`) |
| Service access | `Service access`, `expertSkills` |

## 8. Open items and checks
- Recent builds to confirm with staff after upload:
  - Expert Share draft / Submit stick after reload, and documents open.
  - The Transfers page lists every Not verified transfer.
  - Consultant My orders search works on desktop and phone.
- Puttur Daily ads for 8 Nov (only 1 consultant saved) and some 13–14 Nov entries were never saved and must be re-entered by hand.
- If an agent's transfer status looks old, they reload. Every refresh reloads all transfer statuses.

## 9. How to brief Claude (copy this)
> "Project: Skilleaze HQ CRM. Read CLAUDE.md first. Change: <what>. Scope: <which portal/role only>. Do not touch: <other portals>. Edit crm-source.dc.html with exact find→replace, bump BUILD + version.txt, any SQL in supabase/47_….sql (safe to run again, also inline in chat). Tell me exactly what to upload and what to test."
