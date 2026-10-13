'use strict';
function returnPath() {
  try {
    const next = new URL(new URLSearchParams(location.search).get('next') || '/studio/hub/',location.origin);
    if(next.origin === location.origin && /^\/studio\/hub\/(?:$|library\/$|evidence\/$|study\/$|focus\/$|documents\/$|assistant\/$|audio\/$|offline\/$|projects\/$|tasks\/$|planner\/$|account\/$|access\/$|sources\/[0-9a-f-]{36}$)/i.test(next.pathname)) return next.pathname + next.search + (next.hash || location.hash);
  } catch {}
  return '/studio/hub/';
}
if(new URLSearchParams(location.search).has('password_changed'))document.querySelector('#status').textContent='Password changed. Sign in with your new password.';
if(new URLSearchParams(location.search).has('local_copies'))document.querySelector('#status').textContent='Signed out. Close other Bright Studio tabs and remove private copies from this device.';
document.querySelector('#login-form').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.currentTarget, button = form.querySelector('button'), status = document.querySelector('#status');
  button.disabled = true; status.textContent = 'Signing in…';
  try {
    const response = await fetch('/studio/api/session/login', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(Object.fromEntries(new FormData(form)))});
    if (!response.ok) throw new Error(response.status === 401 ? 'Email or password was not accepted.' : response.status === 429 ? 'Too many attempts. Try again in five minutes.' : 'Sign in is unavailable. Please retry.');
    location.assign(returnPath());
  } catch(error) { status.textContent = error.message; }
  finally { button.disabled = false; }
});
