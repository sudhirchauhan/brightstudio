'use strict';
const cacheName='bright-offline-shell-v1',assets=['/studio/hub/offline-shell.html','/studio/hub/offline-local.js','/studio/hub.css'];
self.addEventListener('install',event=>event.waitUntil(caches.open(cacheName).then(c=>c.addAll(assets)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(names=>Promise.all(names.filter(n=>n.startsWith('bright-offline-shell-')&&n!==cacheName).map(n=>caches.delete(n)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{const u=new URL(event.request.url);if(u.origin!==location.origin)return;if(event.request.mode==='navigate'&&u.pathname==='/studio/hub/offline/')event.respondWith(caches.match('/studio/hub/offline-shell.html').then(r=>r||fetch(event.request)));else if(assets.includes(u.pathname))event.respondWith(fetch(event.request).catch(()=>caches.match(u.pathname)));});
// No session response, API, private source or package is stored in CacheStorage.
