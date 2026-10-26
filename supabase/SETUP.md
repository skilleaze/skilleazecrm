# Skilleaze CRM · Supabase setup (about 15 minutes)

## 1. Create the project
1. Go to **supabase.com** → Sign up (use the company Google account).
2. **New project** → Name: `skilleaze-crm` → Region: **Mumbai (ap-south-1)** → set a strong database password and save it somewhere safe.
3. Wait about 2 minutes while it starts.

## 2. Run the setup file
1. Left menu → **SQL Editor** → **New query**.
2. Open `supabase/schema.sql` from this project, copy everything, paste, press **Run**.
3. You should see "Success. No rows returned". If an error shows, send me a screenshot of it.

## 3. Turn on email login
Left menu → **Authentication** → **Providers** → Email: on. Turn **Confirm email** off for now (staff accounts are created by you).

## 4. Send me two values
Left menu → **Project Settings** → **API**:
- **Project URL** (looks like `https://abcd1234.supabase.co`)
- **anon public** key

Never send the **service_role** key or the database password to anyone.

## 5. What I do next
1. Connect the CRM to your project (logins, live data, screenshot storage).
2. Prepare the cleaned import (orders, ads, transfers, expenses, payroll, salary statements).
3. Create the user list: Muneez, Hashim (management), Dhiya (head of operations), Ishfa (operations), every agent, every expert, Munavvir (Puttur manager), Customer Support staff. Each gets their own password.
4. Run a test week next to the sheets, then switch over.

## What the database enforces (not just the screen)
- Agents see only their own orders, ads and cash; order date is set by the server and can't be edited.
- Experts see only orders of agents assigned to them (or orders assigned to them), can only change work status, and only their own points.
- Ishfa: orders and experts, can assign/reassign, cannot change status or money, no ads, no cash.
- Dhiya: everything operational incl. cash flow, payroll and expenses; only she can verify agent transfers.
- Every transfer needs a screenshot; agents' transfers stay "Not verified" until Dhiya verifies.
- Head of operations can't add orders.
- Puttur manager sees only Puttur.
- Customer lookup works for everyone but only shows owner, status and expert — not prices.
- Every change to orders, transfers, expenses, payroll, ads, enquiries, issues and accounts is written to an audit log only management can read.
