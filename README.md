# Skilleaze HQ

Internal operations CRM for Skilleaze staff — orders, experts, enquiries, ads, transfers, cash flow, payroll, chat and push notifications. Served at **admin.skilleaze.com** (Vercel), backed by **Supabase** (Postgres + Auth + Storage + Edge Functions).

**Read `CLAUDE.md` first** — it is the owner's handoff with the standing rules (business rules, SQL conventions, roles). Name mapping: CLAUDE.md's `crm-source.dc.html` = `src/app.html` here; `support.js` = `src/vendor/dc-runtime.js`. `tools/bundle.py release` does CLAUDE.md steps 2–3 (bump BUILD + version.txt, produce single-file `index.html`).

## Layout

```
index.html               ← the deployed page (a self-unpacking bundle) — GENERATED, don't hand-edit
src/app.html             ← the app itself: markup, CSS and app JavaScript — EDIT THIS
src/vendor/              React 18, ReactDOM, supabase-js 2.45.4, dc runtime (third-party, leave alone)
src/fonts/, src/images/  Cormorant Garamond + Lato, in-app logo
src/bundle-shell.html    outer loader page; src/resources.json maps resource ids → files
tools/bundle.py          unpack / build / check / release
supabase/live.js         Supabase connection layer (sign-in, load, save, user admin) — bundled into index.html
supabase/config.js       Supabase URL, publishable key, VAPID public key — bundled into index.html
supabase/schema.sql      base schema (tables, RLS, roles, audit log)
supabase/NN_*.sql        incremental migrations applied after schema.sql, in number order
supabase/functions/      Edge Functions: admin-users (create/reset/deactivate staff), push-send (web push)
supabase/SETUP.md        original Supabase setup + what the database enforces per role
sw.js, site.webmanifest  PWA service worker (push notifications) + manifest
vercel.json              security headers and cache rules
version.txt              current build id — open sessions reload when it changes
*.png, assets/           icons, OG card, logos
```

## Everyday workflow

1. Edit `src/app.html` (UI/logic) or `supabase/live.js` / `supabase/config.js` (data layer).
2. `python3 tools/bundle.py release` — stamps a new build id and rebuilds `index.html`.
   (`build` rebuilds without a new id; `check` confirms `index.html` matches `src/`.)
3. Preview: `python3 -m http.server 8000` in this folder → http://localhost:8000
4. Design preview (optional): `python3 tools/preview.py` builds `preview/index.html` — the same app with sample data, no database, and a "view as" role switcher (published as the "Skilleaze HQ · Design preview" artifact). Exports/downloads don't work there.
5. Deploy the folder to Vercel (root = this folder, no build step). Staff with the app open get a "new version" prompt.

## Database changes

`schema.sql` plus every numbered migration has already been run on the live project (`rmtljlzvmdnfdazytyoj`). For a change, add the next file (e.g. `supabase/47_<what>.sql`), run it once in Supabase → SQL Editor, and commit it. Many numbers are shared by two or three files (04, 05, 07, 09, 10, 12, 13, 16, 17, 18, 28, 30, 31, 32, 33, 36) — files sharing a number are independent changes. Files with `check` in the name are read-only diagnostics.

Edge Functions are deployed from Supabase → Edge Functions → Via Editor (paste `index.ts`). Both use the built-in `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY`; `push-send` also needs secrets `VAPID_PUBLIC`, `VAPID_PRIVATE`, `VAPID_SUBJECT`.

## Keys

`config.js` holds only public values (URL, publishable key, VAPID public key). Never commit the `service_role` key, the database password or the VAPID private key — those live in Supabase secrets.

## Hosting

Pushing to `main` deploys to admin.skilleaze.com via Vercel. `.vercelignore` keeps `src/`, `tools/`, notes and SQL off the public site; only `index.html`, `sw.js`, icons, `supabase/*.js` and config files are served.
