'use strict';
window.brightClearOffline=async()=>{
 await new Promise((resolve,reject)=>{const r=indexedDB.deleteDatabase('bright-offline'),timeout=setTimeout(()=>reject(Error('Close other Bright Studio tabs to remove private copies.')),5000);r.onsuccess=()=>{clearTimeout(timeout);resolve();};r.onerror=()=>{clearTimeout(timeout);reject(Error('Could not remove private device copies.'));};r.onblocked=()=>{};});
 for(const name of await caches.keys())if(name.startsWith('bright-offline-shell-'))await caches.delete(name);
 for(const r of await navigator.serviceWorker.getRegistrations())if(r.scope===location.origin+'/studio/hub/')await r.unregister();
 localStorage.removeItem('bright-offline-owner');
};
