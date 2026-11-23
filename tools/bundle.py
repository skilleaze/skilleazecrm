#!/usr/bin/env python3
"""
Skilleaze HQ · bundle tool

index.html (the file Vercel serves) is a single self-unpacking bundle. Editing it
directly is painful, so the editable source lives in src/ and this script moves
between the two:

    python3 tools/bundle.py unpack   # index.html  -> src/   (only needed once / to re-sync)
    python3 tools/bundle.py build    # src/        -> index.html
    python3 tools/bundle.py check    # build to memory and confirm it matches index.html
    python3 tools/bundle.py release  # new build id (app.html + version.txt) then build — use before each deploy

What lives where after unpacking:
    src/app.html            the whole app: markup, CSS and the app's JavaScript  <- edit this
    supabase/live.js        Supabase connection layer (sign-in, load, save)      <- edit this
    supabase/config.js      Supabase URL / publishable key / push key            <- edit this
    src/vendor/*.js         React, ReactDOM, supabase-js, the dc runtime (don't edit)
    src/fonts/*.woff2       Cormorant Garamond + Lato
    src/images/logo.png     logo used inside the app
    src/bundle-shell.html   the outer loader page (rarely touched)
    src/resources.json      maps each resource id in app.html to its file
    src/.bundle-cache.json  original encoded bytes, so untouched files rebuild byte-for-byte

References inside app.html stay as resource ids (e.g. src="1403e8b1-...") — the
loader swaps them for the real files at runtime. To add a new image/script, put the
file in src/, add an entry to resources.json with a new UUID, and reference the UUID.
"""
import base64, gzip, hashlib, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
INDEX = os.path.join(ROOT, 'index.html')
MAN_RE = re.compile(r'(<script type="__bundler/manifest">\n)(.*?)(\n  </script>)', re.S)
TPL_RE = re.compile(r'(<script type="__bundler/template">\n)(.*?)(\n  </script>)', re.S)

# Friendly file names for the resources that exist today (anything unknown gets uuid-based names).
NAMES = {
    '1403e8b1-ffc9-49cc-a7fd-350c9e12426f': 'supabase/live.js',
    '5fa03d0b-bbbc-4df4-bc29-38092081c5d5': 'supabase/config.js',
    '24b39e75-5dcf-444d-856d-5f71a05b8b43': 'src/vendor/supabase-js-2.45.4.min.js',
    '659e7e93-3f67-4f07-a003-b55e51dafb80': 'src/vendor/dc-runtime.js',
    'c63db167-229b-4524-a3d2-a6e49cec6506': 'src/vendor/react-18.3.1.min.js',
    '5b83e3f7-dc8f-4471-bf1e-8e6f163fe7a0': 'src/vendor/react-dom-18.3.1.min.js',
    '85093557-1e56-48ef-93a4-ef74b764bddd': 'src/images/logo.png',
    '367d7cb5-6477-4026-bf06-10bb29321cd9': 'src/fonts/cormorant-cyrillic-ext.woff2',
    '2839111d-2292-4fa3-bbdd-21ea8860d155': 'src/fonts/cormorant-cyrillic.woff2',
    '4a3d61df-53d7-4634-9d53-2ad8e544d608': 'src/fonts/cormorant-vietnamese.woff2',
    '5c05eb12-a568-43f5-afc0-4c1035a36e6c': 'src/fonts/cormorant-latin-ext.woff2',
    '3d55cdfb-9d7f-4500-99f8-897b78957558': 'src/fonts/cormorant-latin.woff2',
    '0723fa08-0ce3-4dcd-8063-71069acbbe6c': 'src/fonts/lato-400-latin-ext.woff2',
    '160106d7-6b5a-4ed6-9773-8712f1ad1d88': 'src/fonts/lato-400-latin.woff2',
    '18979229-d5e5-45ea-9d4e-7090081e16ae': 'src/fonts/lato-700-latin-ext.woff2',
    '1ad51435-0243-4216-8904-e90d7765beee': 'src/fonts/lato-700-latin.woff2',
    '45e89972-5820-410a-9d9a-dd0cf2a91155': 'src/fonts/lato-900-latin-ext.woff2',
    '55780638-5d93-404c-977d-aa51af75d836': 'src/fonts/lato-900-latin.woff2',
}
EXT = {'image/png': '.png', 'font/woff2': '.woff2', 'application/javascript': '.js', 'text/javascript': '.js'}


def sha(b): return hashlib.sha256(b).hexdigest()
def p(rel): return os.path.join(ROOT, rel)


def encode_template(t):
    return json.dumps(t, ensure_ascii=False).replace('</', '<\\u002F')


def unpack():
    s = open(INDEX, encoding='utf-8').read()
    mm, tm = MAN_RE.search(s), TPL_RE.search(s)
    man, tpl = json.loads(mm.group(2)), json.loads(tm.group(2))
    os.makedirs(SRC, exist_ok=True)
    resources, cache = {}, {}
    for rid, ent in man.items():
        raw = base64.b64decode(ent['data'])
        if ent['compressed']:
            raw = gzip.decompress(raw)
        rel = NAMES.get(rid) or 'src/other/' + rid + EXT.get(ent['mime'], '.bin')
        os.makedirs(os.path.dirname(p(rel)), exist_ok=True)
        if os.path.exists(p(rel)) and open(p(rel), 'rb').read() != raw:
            print('  ! %s differs from the bundle copy — keeping the bundle copy as %s.bundled' % (rel, rel))
            open(p(rel) + '.bundled', 'wb').write(raw)
        else:
            open(p(rel), 'wb').write(raw)
        resources[rid] = {'file': rel, 'mime': ent['mime'], 'compressed': ent['compressed']}
        cache[rid] = {'sha256': sha(raw), 'data': ent['data']}
    open(os.path.join(SRC, 'app.html'), 'w', encoding='utf-8').write(tpl)
    shell = s[:mm.start(2)] + '{{MANIFEST}}' + s[mm.end(2):tm.start(2)] + '{{TEMPLATE}}' + s[tm.end(2):]
    open(os.path.join(SRC, 'bundle-shell.html'), 'w', encoding='utf-8').write(shell)
    json.dump(resources, open(os.path.join(SRC, 'resources.json'), 'w'), indent=2)
    json.dump(cache, open(os.path.join(SRC, '.bundle-cache.json'), 'w'), separators=(',', ':'))
    print('Unpacked %d resources + app.html into src/' % len(resources))


def render():
    resources = json.load(open(os.path.join(SRC, 'resources.json')))
    cpath = os.path.join(SRC, '.bundle-cache.json')
    cache = json.load(open(cpath)) if os.path.exists(cpath) else {}
    man, changed = {}, []
    for rid, r in resources.items():
        raw = open(p(r['file']), 'rb').read()
        c = cache.get(rid)
        if c and c['sha256'] == sha(raw):
            data = c['data']                      # untouched: reuse exact original bytes
        else:
            body = gzip.compress(raw, 9, mtime=0) if r['compressed'] else raw
            data = base64.b64encode(body).decode()
            changed.append(r['file'])
        man[rid] = {'mime': r['mime'], 'compressed': r['compressed'], 'data': data}
    tpl = open(os.path.join(SRC, 'app.html'), encoding='utf-8').read()
    shell = open(os.path.join(SRC, 'bundle-shell.html'), encoding='utf-8').read()
    out = shell.replace('{{MANIFEST}}', json.dumps(man, separators=(',', ':')), 1) \
               .replace('{{TEMPLATE}}', encode_template(tpl), 1)
    # Sanity: every resource id referenced by app.html must exist.
    ids = set(re.findall(r'"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})"', tpl))
    missing = sorted(i for i in ids if i not in resources and i not in shell)
    return out, changed, missing


def build():
    out, changed, missing = render()
    if missing:
        print('  ! app.html references unknown resource ids: ' + ', '.join(missing))
    open(INDEX, 'w', encoding='utf-8').write(out)
    print('Built index.html (%s bytes). Re-encoded: %s' % (format(len(out.encode()), ','), ', '.join(changed) or 'none'))


def check():
    out, changed, missing = render()
    cur = open(INDEX, encoding='utf-8').read()
    print('index.html is up to date with src/' if out == cur else 'index.html differs from src/ — run: python3 tools/bundle.py build')
    sys.exit(0 if out == cur else 1)


BUILD_RE = re.compile(r"const BUILD = 'b(\d+)'")


def release():
    """New build id in app.html + version.txt, then build. Open sessions see 'new version' and reload."""
    import time
    app_path = os.path.join(SRC, 'app.html')
    tpl = open(app_path, encoding='utf-8').read()
    if not BUILD_RE.search(tpl):
        sys.exit("Couldn't find const BUILD = 'b...' in src/app.html")
    new = 'b%d' % int(time.time() * 1000)
    open(app_path, 'w', encoding='utf-8').write(BUILD_RE.sub("const BUILD = '%s'" % new, tpl, count=1))
    open(os.path.join(ROOT, 'version.txt'), 'w').write(new)
    print('Build id -> ' + new)
    build()


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    {'unpack': unpack, 'build': build, 'check': check, 'release': release}.get(cmd, lambda: print(__doc__))()
