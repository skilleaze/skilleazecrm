// Skilleaze HQ · notifications service worker
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

self.addEventListener('push', e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (x) { d = { title: 'Skilleaze HQ', body: e.data ? e.data.text() : '' }; }
  const title = d.title || 'Skilleaze HQ';
  e.waitUntil((async () => {
    const wins = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const visible = wins.some(w => w.visibilityState === 'visible' && w.focused);
    if (visible) { wins.forEach(w => w.postMessage({ skzPush: d })); return; }
    await self.registration.showNotification(title, {
      body: d.body || '', tag: d.tag || undefined, renotify: !!d.tag,
      icon: '/icon-512.png', badge: '/favicon-hq.png',
      data: { url: d.url || '/', type: d.type || '' }, vibrate: d.type === 'issue' ? [120, 60, 120, 60, 200] : [80, 40, 80]
    });
  })());
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || '/';
  e.waitUntil((async () => {
    const wins = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const w of wins) { if ('focus' in w) { w.postMessage({ skzOpen: url }); return w.focus(); } }
    return self.clients.openWindow(url);
  })());
});
