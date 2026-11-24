#!/usr/bin/env python3
"""
Build a clickable DESIGN PREVIEW of the CRM (like Claude Design's preview) into preview/index.html.

    python3 tools/preview.py

It copies src/ into a temp folder and, in that copy only:
  * turns LIVE_MODE off (no Supabase connection),
  * replaces loadReal() with made-up sample data (tools/preview/sample-data.js),
  * skips the forced-password and clock-in popups,
  * adds a "view as" role switcher bar (tools/preview/demo-bar.js).
The real src/ and index.html are never changed. Every demo login uses password: skilleaze
"""
import json, os, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = tempfile.mkdtemp(prefix='skz-preview-')
for part in ['src', 'supabase', 'tools']:
    shutil.copytree(os.path.join(ROOT, part), os.path.join(T, part), ignore=shutil.ignore_patterns('*.sql', 'functions'))
shutil.copy(os.path.join(ROOT, 'index.html'), os.path.join(T, 'index.html'))
app = os.path.join(T, 'src', 'app.html'); s = open(app, encoding='utf-8').read()

def rep(a, b):
    global s
    if s.count(a) != 1: sys.exit('Preview patch no longer matches (found %d): %s' % (s.count(a), a[:70]))
    s = s.replace(a, b)

rep('const LIVE_MODE = true;', 'const LIVE_MODE = false;')
rep('componentDidMount() { if (LIVE_MODE) this.waitLive(0);', 'componentDidMount() { window.__skzApp = this; window.__skzNAV = NAV; window.__skzIC = IC; window.__skzSHORT = SHORT; if (LIVE_MODE) this.waitLive(0);')
rep("function loadReal() { return Promise.reject(new Error('The live database is empty. Upload the data from the internal copy first.')); }",
    open(os.path.join(ROOT, 'tools', 'preview', 'sample-data.js'), encoding='utf-8').read().rstrip())
rep("forcePw: own ? null : { u, a: '', b: '', err: '' }", 'forcePw: null')
rep("!(!LIVE_MODE && /[?&]nopunch=1/.test(location.search))", 'LIVE_MODE')
UID = 'd3e0b0a1-7c2e-4f1a-9b55-5e1d0c0de0a1'
rep('<script src="659e7e93-3f67-4f07-a003-b55e51dafb80"></script>', '<script src="659e7e93-3f67-4f07-a003-b55e51dafb80"></script>\n<script src="%s"></script>' % UID)
open(app, 'w', encoding='utf-8').write(s)
shutil.copy(os.path.join(ROOT, 'tools', 'preview', 'demo-bar.js'), os.path.join(T, 'src', 'demo-bar.js'))
rp = os.path.join(T, 'src', 'resources.json'); r = json.load(open(rp))
r[UID] = {'file': 'src/demo-bar.js', 'mime': 'application/javascript', 'compressed': True}; json.dump(r, open(rp, 'w'), indent=2)
subprocess.run([sys.executable, os.path.join(T, 'tools', 'bundle.py'), 'build'], check=True, stdout=subprocess.DEVNULL)
os.makedirs(os.path.join(ROOT, 'preview'), exist_ok=True)
html = open(os.path.join(T, 'index.html'), encoding='utf-8').read().replace('<title>Skilleaze HQ · Sign in</title>', '<title>Skilleaze HQ · Design preview</title>', 1)
open(os.path.join(ROOT, 'preview', 'index.html'), 'w', encoding='utf-8').write(html)
shutil.rmtree(T)
print('Built preview/index.html — sample data only, not connected to Supabase.')
