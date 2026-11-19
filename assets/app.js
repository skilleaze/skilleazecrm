/* Stratt HQ · shared app code. No build step. */
(function () {
  'use strict';
  var C = window.STRATT_CONFIG || {};
  var sb = window.supabase.createClient(C.supabaseUrl, C.supabaseAnonKey, {
    auth: { flowType: 'pkce', persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });
  var DOMAINS = ['stratt.ae', 'stratton.ae'];

  var MODULES = [
    { id: 'dashboard', label: 'Dashboard', href: 'dashboard.html', icon: 'layout-dashboard' },
    { id: 'leads', label: 'Leads', href: 'leads.html', icon: 'target' },
    { id: 'listings', label: 'Listings', href: 'listings.html', icon: 'building-2' },
    { id: 'clients', label: 'Clients', href: 'clients.html', icon: 'contact' },
    { id: 'deals', label: 'Deals', href: 'deals.html', icon: 'handshake' },
    { id: 'marketing', label: 'Marketing', href: 'marketing.html', icon: 'megaphone' },
    { id: 'finance', label: 'Finance', href: 'finance.html', icon: 'wallet' },
    { id: 'hr', label: 'HR', href: 'hr.html', icon: 'id-card' },
    { id: 'documents', label: 'Documents', href: 'documents.html', icon: 'file-check' },
    { id: 'tasks', label: 'Tasks', href: 'tasks.html', icon: 'calendar-check' },
    { id: 'reports', label: 'Reports', href: 'reports.html', icon: 'bar-chart-3' },
    { id: 'settings', label: 'Settings', href: 'settings.html', icon: 'settings' }
  ];
  var LEVELS = { super_admin: 'Super admin', admin: 'Admin', user: 'User' };
  var HOME = { ceo: 'dashboard', admin: 'dashboard', finance: 'finance', hr: 'hr', sales: 'leads', agent: 'leads', marketing: 'marketing' };
  var VIEW_KEY = 'stratt_hq_view_as';
  var installEvt = null;
  window.addEventListener('beforeinstallprompt', function (e) { e.preventDefault(); installEvt = e; });

  /* ---------- DOM ---------- */
  function append(el, kids) {
    kids.flat(Infinity).forEach(function (c) {
      if (c == null || c === false || c === true) return;
      el.appendChild(c instanceof Node ? c : document.createTextNode(String(c)));
    });
    return el;
  }
  function h(tag, attrs) {
    var kids = Array.prototype.slice.call(arguments, 2);
    var el = document.createElement(tag), later = {};
    Object.keys(attrs || {}).forEach(function (k) {
      var v = attrs[k];
      if (v == null || v === false) return;
      if (k === 'class') el.className = v;
      else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
      else if (k.slice(0, 2) === 'on' && typeof v === 'function') el.addEventListener(k.slice(2).toLowerCase(), v);
      else if (k === 'value' || k === 'checked') later[k] = v;
      else el.setAttribute(k, v === true ? '' : v);
    });
    append(el, kids);
    if ('value' in later) {
      el.value = later.value;
      if (tag === 'select') Array.prototype.forEach.call(el.options, function (o) { o.defaultSelected = o.value === String(later.value); });
    }
    if ('checked' in later) el.checked = !!later.checked;
    return el;
  }
  var NS = 'http://www.w3.org/2000/svg';
  function s(tag, attrs) {
    var el = document.createElementNS(NS, tag);
    Object.keys(attrs || {}).forEach(function (k) { if (attrs[k] != null) el.setAttribute(k, attrs[k]); });
    append(el, Array.prototype.slice.call(arguments, 2));
    return el;
  }
  function icon(name, size) { return h('i', { 'data-lucide': name, width: size || 18, height: size || 18, 'stroke-width': 1.5 }); }
  function icons() { if (window.lucide) window.lucide.createIcons(); }
  var pending = [];
  function show(el) { if (el.dataset.w != null) el.style.width = el.dataset.w; else el.classList.add('in'); }
  function checkLazy() {
    var limit = (window.innerHeight || document.documentElement.clientHeight) + 40;
    pending = pending.filter(function (el) {
      if (!el.isConnected) return false;
      var r = el.getBoundingClientRect();
      if (r.top < limit && r.bottom > -40) { show(el); return false; }
      return true;
    });
  }
  document.addEventListener('scroll', checkLazy, { passive: true, capture: true });
  window.addEventListener('resize', checkLazy);
  function lazy(el) { pending.push(el); requestAnimationFrame(function () { requestAnimationFrame(checkLazy); }); return el; }
  function settle(root) { (root || document).querySelectorAll('[data-lazy]').forEach(function (el) { el.removeAttribute('data-lazy'); lazy(el); }); }
  var toastTimer;
  function toast(msg, isErr) {
    var old = document.querySelector('.toast'); if (old) old.remove();
    var t = h('div', { class: 'toast' + (isErr ? ' err' : ''), role: 'status' }, msg);
    document.body.appendChild(t);
    clearTimeout(toastTimer); toastTimer = setTimeout(function () { t.remove(); }, 3200);
  }

  /* ---------- format ---------- */
  var MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  var SHORT = MONTHS.map(function (m) { return m.slice(0, 3); });
  var START = '2026-03';
  var sum = function (a) { return a.reduce(function (x, y) { return x + (Number(y) || 0); }, 0); };
  function aed(n) {
    var v = Math.round((Number(n) || 0) * 100) / 100, a = Math.abs(v), d = a % 1 ? 2 : 0;
    var t = 'AED ' + a.toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
    return v < 0 ? '(' + t + ')' : t;
  }
  function aedShort(n) {
    var v = Math.abs(Number(n) || 0);
    if (v >= 1e6) return 'AED ' + (v / 1e6).toFixed(1) + 'M';
    if (v >= 1e5) return 'AED ' + Math.round(v / 1e3) + 'k';
    if (v >= 1e3) return 'AED ' + (v / 1e3).toFixed(1) + 'k';
    return 'AED ' + Math.round(v);
  }
  var ym = function (d) { return String(d || '').slice(0, 7); };
  function monthLabel(d) { var p = ym(d).split('-'); return MONTHS[+p[1] - 1] + ' ' + p[0]; }
  function shortMonth(d) { return SHORT[+ym(d).split('-')[1] - 1]; }
  function fmtDate(d) { if (!d) return '–'; var p = String(d).slice(0, 10).split('-'); return +p[2] + ' ' + SHORT[+p[1] - 1] + ' ' + p[0]; }
  function monthList() {
    var out = [], now = new Date(), p = START.split('-').map(Number), y = p[0], m = p[1];
    while (y < now.getFullYear() || (y === now.getFullYear() && m <= now.getMonth() + 1)) {
      out.push(y + '-' + String(m).padStart(2, '0'));
      m++; if (m > 12) { m = 1; y++; }
    }
    return out.reverse();
  }
  function period(p) {
    if (!p || p === 'all' || !/^\d{4}-\d{2}$/.test(p)) return { id: 'all', all: true, label: 'All time' };
    var a = p.split('-').map(Number), ny = a[1] === 12 ? a[0] + 1 : a[0], nm = a[1] === 12 ? 1 : a[1] + 1;
    return { id: p, all: false, label: MONTHS[a[1] - 1] + ' ' + a[0], from: p + '-01', to: ny + '-' + String(nm).padStart(2, '0') + '-01' };
  }
  function inPeriod(q, col, per) { return per.all ? q : q.gte(col, per.from).lt(col, per.to); }
  function within(d, per) { return per.all || ym(d) === per.id; }
  function matches(row, q) { return !q || JSON.stringify(row).toLowerCase().indexOf(String(q).toLowerCase()) >= 0; }
  function label(x) { return x ? String(x).replace(/_/g, ' ').replace(/^./, function (c) { return c.toUpperCase(); }) : '–'; }
  var CATEGORY_LABELS = { commission: 'Commission', salaries: 'Salaries', utilities: 'Utilities and communication', marketing: 'Marketing', listing_portals: 'Listing portals', rent_visas_admin: 'Rent, visas and admin', petty_cash: 'Petty cash and Cafesti', other: 'Other' };
  var COLOURS = ['#12253D', '#3E5C80', '#8B6B47', '#C9A77C', '#A9AEB5', '#D5D9DE', '#6C5235'];
  function today() { return new Date().toISOString().slice(0, 10); }
  function link(href, ctx) { return href + (ctx && !ctx.per.all ? (href.indexOf('?') >= 0 ? '&' : '?') + 'period=' + ctx.per.id : ''); }

  /* ---------- UI ---------- */
  function badge(t, tone) { return h('span', { class: 'badge ' + (tone || '') }, t); }
  function cell(t, sub) { return h('div', null, h('div', { class: 'h', style: { fontWeight: 600 } }, t), sub ? h('div', { class: 's' }, sub) : null); }
  function bold(t) { return h('b', { class: 'h' }, t); }

  function pageHead(ctx, o) {
    var per = o.period === false ? null : ctx.per;
    var tools = h('div', { class: 'tools' });
    if (per) {
      var sel = h('select', { 'aria-label': 'Period', onchange: function (e) {
        var p = new URLSearchParams(location.search);
        if (e.target.value === 'all') p.delete('period'); else p.set('period', e.target.value);
        var qs = p.toString(); location.href = location.pathname + (qs ? '?' + qs : '');
      } }, h('option', { value: 'all' }, 'All time'), monthList().map(function (m) { return h('option', { value: m }, monthLabel(m + '-01')); }));
      sel.value = per.id;
      tools.appendChild(h('label', { class: 'field period-wrap' }, icon('calendar'), sel));
    }
    if (o.search !== false) {
      var keep = Object.assign({}, o.keep || {});
      if (per && !per.all) keep.period = per.id;
      tools.appendChild(h('form', { method: 'get', class: 'search-form' },
        Object.keys(keep).map(function (k) { return keep[k] ? h('input', { type: 'hidden', name: k, value: keep[k] }) : null; }),
        h('label', { class: 'field search' }, icon('search'), h('input', { name: 'q', value: ctx.q, placeholder: 'Search', 'aria-label': 'Search' }))));
    }
    if (o.action) tools.appendChild(o.action);
    return h('div', { class: 'page-head' },
      h('div', null, h('div', { class: 'eyebrow' }, o.eyebrow + (per ? ' · ' + per.label : '')), h('h1', null, o.title), o.sub ? h('div', { class: 'sub' }, o.sub) : null),
      tools);
  }

  function tabs(ctx, items, active, page) {
    return h('div', { class: 'tabs' }, items.map(function (t) {
      return h('a', { href: link(page + '?tab=' + t[0], ctx), class: t[0] === active ? 'on' : '' }, t[1]);
    }));
  }

  function shortVal(v) { return String(v).replace(/([\d,]+)\.(\d{2})/, function (m, a, b) { return Math.round(parseFloat(a.replace(/,/g, '') + '.' + b)).toLocaleString('en-US'); }); }
  function kpis(items) {
    return h('div', { class: 'kpis' }, items.map(function (k) {
      return h('div', { class: 'card kpi' },
        h('div', { class: 'l' }, k.label),
        h('div', { class: 'v', title: String(k.value) }, h('span', { class: 'full' }, k.value), h('span', { class: 'short' }, shortVal(k.value))),
        h('div', { class: 'n ' + (k.tone || '') }, k.note));
    }));
  }

  function table(o) {
    var sec = h('section', { class: 'card' });
    if (o.title) sec.appendChild(h('div', { class: 'panel-title' }, h('h2', null, o.title), o.note != null ? h('span', { class: 'muted' }, o.note) : null));
    if (!o.rows.length) { sec.appendChild(h('div', { class: 'empty' }, o.empty || 'Nothing to show.')); return sec; }
    sec.appendChild(h('table', { class: 't' },
      h('thead', null, h('tr', null, o.columns.map(function (c) { return h('th', { class: c.num ? 'num' : '' }, c.label); }))),
      h('tbody', null, o.rows.map(function (r) {
        return h('tr', { class: r.__total ? 'total' : '' }, o.columns.map(function (c) {
          var v = c.render ? c.render(r) : r[c.key];
          return h('td', { 'data-label': c.label, class: c.num ? 'num' : '' }, v == null || v === '' ? '–' : v);
        }));
      }))));
    return sec;
  }

  function side(o) {
    return h('section', { class: 'card' },
      h('div', { class: 'panel-title' }, h('h2', null, o.title), o.note ? h('span', { class: 'muted' }, o.note) : null),
      h('div', { class: 'side-list' }, o.items.length ? o.items.map(function (it) {
        return h('div', { class: 'side-item' },
          h('div', { class: 'top' }, h('span', null, it.label), h('b', { class: it.tone || '' }, it.value)),
          it.sub ? h('div', { class: 'muted' }, it.sub) : null,
          it.pct != null ? h('div', { class: 'bar' }, h('i', { 'data-lazy': '1', 'data-w': Math.max(0, Math.min(100, it.pct)) + '%', style: { width: '0%', background: it.wood ? '#8B6B47' : '' } })) : null);
      }) : h('div', { class: 'muted', style: { padding: '12px 0' } }, o.empty || 'Nothing to show.')));
  }

  function row(main, aside) { return h('div', { class: 'row' }, h('div', { class: 'grow' }, main), aside ? h('div', { class: 'side' }, aside) : null); }

  function donut(segments, center, subText) {
    var total = sum(segments.map(function (x) { return x.value; })) || 1, acc = 0;
    var bg = segments.length ? 'conic-gradient(' + segments.map(function (x) { var f = acc; acc += x.value / total * 100; return x.color + ' ' + f.toFixed(2) + '% ' + acc.toFixed(2) + '%'; }).join(',') + ')' : 'rgba(18,37,61,0.08)';
    return [
      h('div', { class: 'donut lazy', 'data-lazy': '1', style: { background: bg } }, h('span', null, center, subText ? h('br') : null, subText ? h('small', { class: 'muted', style: { fontWeight: 400 } }, subText) : null)),
      h('div', { class: 'key' }, segments.map(function (x) { return h('div', null, h('span', { class: 'dot', style: { background: x.color } }), h('span', null, x.label), bold(x.value > 0 && x.value / total < 0.005 ? '<1%' : Math.round(x.value / total * 100) + '%')); }))
    ];
  }

  function lineChart(series, labels) {
    var W = 600, H = 240, top = Math.max.apply(null, [1].concat(series.flatMap(function (x) { return x.values; })));
    var svg = s('svg', { class: 'chart-svg', viewBox: '0 0 ' + W + ' ' + H, preserveAspectRatio: 'none', role: 'img', 'aria-label': 'Chart' },
      series.map(function (x) {
        var pts = x.values.map(function (y, i) { return [(x.values.length > 1 ? i * W / (x.values.length - 1) : W / 2).toFixed(1), (H - 4 - (y / top) * (H - 8)).toFixed(1)].join(','); }).join(' ');
        return s('polyline', { points: pts, fill: 'none', stroke: x.color, 'stroke-width': 2, 'stroke-dasharray': x.dash, 'vector-effect': 'non-scaling-stroke' });
      }));
    return h('div', null, h('div', { class: 'reveal', 'data-lazy': '1' }, svg), h('div', { class: 'chart-x' }, labels.map(function (l) { return h('span', null, l); })));
  }

  /* ---------- dialogs and actions ---------- */
  function dialog(build, wide) {
    var scrim = h('div', { class: 'scrim' });
    var box = h('div', { class: 'dialog' + (wide ? ' wide' : '') });
    var close = function () { scrim.remove(); document.removeEventListener('keydown', esc); };
    var esc = function (e) { if (e.key === 'Escape') close(); };
    scrim.addEventListener('click', function (e) { if (e.target === scrim) close(); });
    document.addEventListener('keydown', esc);
    append(box, [build(close)]);
    scrim.appendChild(box);
    document.body.appendChild(scrim);
    settle(scrim);
    icons();
    var first = box.querySelector('input,select,textarea');
    if (first) first.focus();
    return close;
  }

  function field(f) {
    if (f.type === 'select') {
      return h('label', { class: 'form-field' }, f.label,
        h('select', { name: f.name, required: f.required, value: f.default != null ? f.default : '' },
          f.required ? null : h('option', { value: '' }, '–'),
          f.options.map(function (o) { var v = Array.isArray(o) ? o : [o, o]; return h('option', { value: v[0] }, v[1]); })));
    }
    if (f.type === 'modules') {
      return h('fieldset', { class: 'form-field' }, h('legend', { style: { marginBottom: '6px' } }, f.label),
        h('div', { class: 'checks' }, f.options.map(function (o) { return h('label', null, h('input', { type: 'checkbox', name: f.name, value: o[0] }), o[1]); })));
    }
    if (f.type === 'textarea') return h('label', { class: 'form-field' }, f.label, h('textarea', { name: f.name, rows: 3 }));
    var type = ['number', 'date', 'month', 'time', 'email', 'file'].indexOf(f.type) >= 0 ? f.type : 'text';
    return h('label', { class: 'form-field' }, f.label, h('input', { name: f.name, type: type, step: type === 'number' ? '0.01' : null, required: f.required, value: f.default, placeholder: f.placeholder, accept: f.accept }));
  }

  function formDialog(o) {
    dialog(function (close) {
      var err = h('div', { class: 'error', role: 'alert' });
      var save = h('button', { type: 'submit', class: 'btn' }, o.saveLabel || 'Save');
      var form = h('form', { onsubmit: async function (e) {
        e.preventDefault();
        save.disabled = true; save.textContent = 'Saving…'; err.textContent = '';
        try { await o.submit(new FormData(form)); close(); }
        catch (x) { err.textContent = x.message || String(x); save.disabled = false; save.textContent = o.saveLabel || 'Save'; }
      }, style: { display: 'flex', flexDirection: 'column', gap: '16px' } },
        h('h2', null, o.title), o.intro ? h('div', { class: 'sub' }, o.intro) : null,
        o.fields.map(field), err,
        h('div', { class: 'dialog-actions' }, h('button', { type: 'button', class: 'btn ghost', onclick: close }, 'Cancel'), save));
      return form;
    });
  }

  function readForm(fd, fields, defaults) {
    var row = Object.assign({}, defaults || {});
    fields.forEach(function (f) {
      if (f.type === 'modules') { row[f.name] = fd.getAll(f.name); return; }
      var v = fd.get(f.name);
      if (v === null || v === '') return;
      if (f.type === 'number') v = Number(v);
      if (f.type === 'month') v = v + '-01';
      row[f.name] = v;
    });
    return row;
  }

  function addButton(ctx, o) {
    return h('button', { type: 'button', class: 'btn' + (o.ghost ? ' ghost' : ''), onclick: function () {
      formDialog({ title: o.title || o.label, fields: o.fields, intro: o.intro, submit: async function (fd) {
        var res = await sb.from(o.table).insert(readForm(fd, o.fields, o.defaults));
        if (res.error) throw res.error;
        await ctx.refresh();
        toast(o.done || 'Saved');
      } });
    } }, icon('plus'), o.label);
  }

  function rowAction(ctx, o) {
    var b = h('button', { type: 'button', class: 'btn sm' + (o.solid ? '' : ' ghost'), onclick: async function () {
      if (o.confirm && !window.confirm(o.confirm)) return;
      b.disabled = true; b.textContent = 'Saving…';
      var q = sb.from(o.table);
      var res = o.remove ? await q.delete().eq(o.idKey || 'id', o.id) : await q.update(o.patch).eq(o.idKey || 'id', o.id);
      if (res.error) { toast(res.error.message, true); b.disabled = false; b.textContent = o.label; return; }
      await ctx.refresh();
      toast(o.remove ? 'Removed' : 'Updated');
    } }, o.label);
    return b;
  }

  /* ---------- shell ---------- */
  function shell(app, ctx, moduleId, main) {
    var nav = MODULES.filter(function (m) { return ctx.access[m.id].view; });
    var menuEl = null;
    function closeMenu() { if (menuEl) { menuEl.remove(); menuEl = null; } }
    document.addEventListener('click', function (e) { if (menuEl && !menuEl.contains(e.target) && !e.target.closest('[data-menu]')) closeMenu(); });
    function openMenu(anchor, content, sideKey) {
      var was = menuEl && menuEl.parentNode === anchor;
      closeMenu();
      if (was) return;
      menuEl = h('div', { class: 'menu', style: sideKey === 'left' ? { left: 0 } : { right: 0 } }, content);
      anchor.appendChild(menuEl);
      icons();
    }
    var top = nav.slice(0, 7), rest = nav.slice(7);
    var navEl = h('nav', { class: 'nav', 'aria-label': 'Modules' }, top.map(function (m) { return h('a', { href: link(m.href, ctx), class: m.id === moduleId ? 'on' : '' }, m.label); }));
    if (rest.length) {
      var moreWrap = h('div', { style: { position: 'relative' } });
      moreWrap.appendChild(h('button', { type: 'button', class: 'more-btn', 'data-menu': '1', onclick: function () {
        openMenu(moreWrap, rest.map(function (m) { return h('a', { href: link(m.href, ctx) }, m.label); }), 'left');
      } }, 'More', icon('chevron-down', 16)));
      navEl.appendChild(moreWrap);
    }
    var name = (ctx.realProfile && ctx.realProfile.full_name) || ctx.user.email;
    var initials = String(name).split(/[\s@.]+/).filter(Boolean).slice(0, 2).map(function (x) { return x[0].toUpperCase(); }).join('');
    var userWrap = h('div', { style: { position: 'relative' } });
    userWrap.appendChild(h('button', { type: 'button', class: 'icon-btn avatar', 'aria-label': 'Account', 'data-menu': '1', onclick: function () {
      openMenu(userWrap, [
        h('div', { class: 'who' }, h('div', { class: 'h', style: { fontWeight: 700 } }, name), h('div', { class: 'muted', style: { overflowWrap: 'anywhere' } }, ctx.user.email), h('div', { class: 'muted' }, LEVELS[(ctx.realProfile && ctx.realProfile.access_level) || 'user'])),
        installEvt ? h('button', { type: 'button', onclick: function () { closeMenu(); installEvt.prompt(); installEvt = null; } }, icon('download'), 'Install app') : null,
        ctx.isSuperAdmin ? h('button', { type: 'button', onclick: function () { closeMenu(); viewAsDialog(ctx); } }, icon('eye'), 'View as…') : null,
        ctx.viewAs ? h('button', { type: 'button', onclick: exitView }, icon('undo-2'), 'Back to my view') : null,
        h('button', { type: 'button', onclick: async function () { localStorage.removeItem(VIEW_KEY); await sb.auth.signOut(); location.replace('login.html'); } }, icon('log-out'), 'Sign out')
      ]);
    } }, initials));
    var mTop = nav.length > 5 ? nav.slice(0, 4) : nav, mRest = nav.length > 5 ? nav.slice(4) : [];
    var bottom = h('nav', { class: 'bottom-bar', 'aria-label': 'Modules' },
      mTop.map(function (m) { return h('a', { href: link(m.href, ctx), class: m.id === moduleId ? 'on' : '' }, icon(m.icon, 20), m.label); }),
      mRest.length ? h('button', { type: 'button', onclick: function () {
        dialog(function (close) {
          return [h('h2', null, 'More'), h('div', { class: 'mobile-sheet' }, mRest.map(function (m) { return h('a', { href: link(m.href, ctx) }, icon(m.icon, 20), m.label); })), h('button', { type: 'button', class: 'btn ghost', onclick: close }, 'Close')];
        });
      } }, icon('menu', 20), 'More') : null);
    var banner = ctx.viewAs ? h('div', { class: 'viewas' },
      h('span', null, 'Viewing as ', h('b', null, ctx.viewAs.full_name), ' · ' + label(ctx.viewAs.role) + ' · ' + (LEVELS[ctx.viewAs.access_level] || '') + '. Changes you make are saved with your own account.'),
      h('button', { type: 'button', class: 'btn sm', onclick: exitView }, 'Back to my view')) : null;
    app.addEventListener('mouseover', function (e) {
      var a = e.target.closest && e.target.closest('a[href*=".html"]');
      if (!a || a.dataset.pf) return;
      a.dataset.pf = '1';
      document.head.appendChild(h('link', { rel: 'prefetch', href: a.getAttribute('href').split('?')[0] }));
    });
    app.replaceChildren(h('div', { class: 'topbar' }, banner,
      h('header', { class: 'header' }, h('a', { href: link('index.html', ctx), class: 'logo' }, h('img', { src: 'assets/stratt-logo-navy.png', alt: 'Stratt Signature', decoding: 'async' })), navEl, userWrap)),
      main, bottom);
  }

  function skeleton() {
    var sk = function (cls, style) { return h('span', { class: 'sk ' + (cls || ''), style: style }); };
    return [
      h('div', { class: 'page-head' }, h('div', null, sk('sk-line', { width: '160px' }), sk('sk-title'), sk('sk-line', { width: '60%' }))),
      h('div', { class: 'kpis' }, [0, 1, 2, 3].map(function () { return h('div', { class: 'card kpi' }, sk('sk-line', { width: '50%' }), sk('', { height: '30px', width: '80%' }), sk('sk-line', { width: '40%' })); })),
      h('section', { class: 'card', style: { paddingBottom: '16px' } }, h('div', { class: 'panel-title' }, sk('sk-line', { width: '180px', height: '16px' })),
        [0, 1, 2, 3, 4].map(function () { return h('div', { class: 'sk-row' }, sk(''), sk(''), sk('')); }))
    ];
  }
  function exitView() { localStorage.removeItem(VIEW_KEY); location.href = 'index.html'; }
  async function viewAsDialog(ctx) {
    var res = await sb.from('profiles').select('id, full_name, email, role, access_level, active').order('full_name');
    var people = (res.data || []).filter(function (p) { return p.id !== ctx.realUser.id; });
    dialog(function (close) {
      return [
        h('h2', null, 'View as'),
        h('div', { class: 'sub' }, 'See Stratt HQ with another person’s modules and home page. Use it to check access while building. Your own super admin access is unchanged.'),
        h('div', { class: 'mobile-sheet' },
          h('a', { href: '#', onclick: function (e) { e.preventDefault(); exitView(); } }, icon('user', 20), 'My own view'),
          people.length ? people.map(function (p) {
            return h('a', { href: '#', onclick: function (e) { e.preventDefault(); localStorage.setItem(VIEW_KEY, p.id); location.href = 'index.html'; } },
              icon('user', 20), h('span', { style: { flex: 1, minWidth: 0 } }, p.full_name, h('span', { class: 'muted', style: { display: 'block', fontFamily: 'var(--font-body)', fontWeight: 400 } }, label(p.role) + ' · ' + (LEVELS[p.access_level] || p.access_level) + (p.active ? '' : ' · disabled'))));
          }) : h('div', { class: 'muted', style: { padding: '12px 0' } }, 'No one else has signed in yet. People appear here after their first Google sign-in.')),
        h('button', { type: 'button', class: 'btn ghost', onclick: close }, 'Close')
      ];
    });
  }

  /* ---------- boot ---------- */
  async function loadAccess(user) {
    var uid = user.id || user;
    var res = await Promise.all([
      sb.from('profiles').select('*').eq('id', uid).maybeSingle(),
      sb.from('module_permissions').select('module, can_view, can_edit').eq('profile_id', uid)
    ]);
    var profile = res[0].data, perms = res[1].data || [];
    var active = !!(profile && profile.active), sa = active && profile.access_level === 'super_admin';
    var access = {};
    MODULES.forEach(function (m) {
      var p = perms.find(function (x) { return x.module === m.id; });
      access[m.id] = { view: sa || (active && !!p && (p.can_view || p.can_edit)), edit: sa || (active && !!p && p.can_edit) };
    });
    return { profile: profile, access: access };
  }

  async function boot(moduleId, render) {
    var app = document.getElementById('app');
    var got = await sb.auth.getSession();
    var session = got.data.session;
    if (!session) { location.replace('login.html'); return; }
    var user = session.user, dom = ((user.email || '').split('@')[1] || '').toLowerCase();
    if (DOMAINS.indexOf(dom) < 0) { await sb.auth.signOut(); location.replace('login.html?error=domain'); return; }
    var a = await loadAccess(user), real = a, viewAs = null;
    var asId = localStorage.getItem(VIEW_KEY);
    if (asId && asId !== user.id && real.profile && real.profile.active && real.profile.access_level === 'super_admin') {
      var b = await loadAccess(asId);
      if (b.profile) { a = b; viewAs = b.profile; } else localStorage.removeItem(VIEW_KEY);
    } else if (asId) localStorage.removeItem(VIEW_KEY);
    if (moduleId === null) {
      var role = a.profile && a.profile.role, home = HOME[role] && a.access[HOME[role]].view ? MODULES.find(function (m) { return m.id === HOME[role]; }) : null;
      var first = home || MODULES.find(function (m) { return a.access[m.id].view; });
      location.replace(first ? first.href + location.search : 'no-access.html');
      return;
    }
    if (moduleId !== 'none' && !a.access[moduleId].view) { location.replace('no-access.html'); return; }
    var params = new URLSearchParams(location.search);
    var ctx = {
      sb: sb, user: user, realUser: user, profile: a.profile, realProfile: real.profile, viewAs: viewAs, access: a.access, params: params,
      level: (a.profile && a.profile.access_level) || 'user',
      isSuperAdmin: !!(real.profile && real.profile.active && real.profile.access_level === 'super_admin'),
      canEdit: moduleId !== 'none' && a.access[moduleId].edit,
      per: period(params.get('period')), q: params.get('q') || '', tab: params.get('tab') || ''
    };
    var main = h('main', { class: 'main' }, skeleton());
    shell(app, ctx, moduleId, main);
    ctx.refresh = async function () {
      try {
        var nodes = await render(ctx);
        main.replaceChildren.apply(main, [nodes].flat(Infinity).filter(Boolean));
        settle(main);
        if (!main.dataset.once) { main.dataset.once = '1'; setTimeout(function () { main.classList.add('settled'); }, 700); }
      } catch (e) {
        console.error(e);
        main.replaceChildren(h('div', { class: 'card notice error' }, 'Something went wrong: ' + (e.message || e)));
      }
      icons();
    };
    sb.auth.onAuthStateChange(function (ev) { if (ev === 'SIGNED_OUT') location.replace('login.html'); });
    await ctx.refresh();
  }

  window.HQ = {
    sb: sb, MODULES: MODULES, HOME: HOME, toast: toast, lazy: lazy, settle: settle, DOMAINS: DOMAINS, LEVELS: LEVELS, config: C,
    h: h, s: s, icon: icon, icons: icons,
    sum: sum, aed: aed, aedShort: aedShort, ym: ym, monthLabel: monthLabel, shortMonth: shortMonth, fmtDate: fmtDate, monthList: monthList,
    period: period, inPeriod: inPeriod, within: within, matches: matches, label: label, today: today, link: link,
    CATEGORY_LABELS: CATEGORY_LABELS, COLOURS: COLOURS,
    badge: badge, cell: cell, bold: bold, pageHead: pageHead, tabs: tabs, kpis: kpis, table: table, side: side, row: row, donut: donut, lineChart: lineChart,
    dialog: dialog, field: field, formDialog: formDialog, readForm: readForm, addButton: addButton, rowAction: rowAction,
    boot: boot
  };
})();
