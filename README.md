# Stratt HQ

The internal system for Stratt Signature, built as plain HTML, CSS and JavaScript with no build step. Data, Google sign-in and file storage run on Supabase. The site is hosted on Vercel.

## Files
- `login.html`: Google sign-in, limited to stratt.ae and stratton.ae accounts
- `index.html`: sends each person to their first permitted module
- `dashboard.html`, `leads.html`, `listings.html`, `clients.html`, `deals.html`, `marketing.html`, `finance.html`, `hr.html`, `documents.html`, `tasks.html`, `reports.html`, `settings.html`: one page per module
- `assets/config.js`: your Supabase URL and anon key. Edit this first.
- `assets/app.js`: shared code (sign-in, access, layout, tables and forms)
- `assets/app.css`: all styling
- `supabase/`: database scripts. Run them once each, in this order: schema, seed, access, automation.

## Run locally
Open the folder in VS Code and start it with the Live Server extension. Opening the files directly with file:// does not work with Google sign-in.

## Deploy
Push to GitHub, import the repository in Vercel and deploy. Choose "Other" as the framework, with no build command and no output directory.
