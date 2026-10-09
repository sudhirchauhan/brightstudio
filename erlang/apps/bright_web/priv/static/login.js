'use strict';
document.querySelector('#login-form').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.currentTarget, button = form.querySelector('button'), status = document.querySelector('#status');
  button.disabled = true; status.textContent = 'Signing in…';
  try {
    const response = await fetch('/studio/api/session/login', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(Object.fromEntries(new FormData(form)))});
    if (!response.ok) throw new Error(response.status === 401 ? 'Email or password was not accepted.' : response.status === 429 ? 'Too many attempts. Try again in five minutes.' : 'Sign in is unavailable. Please retry.');
    location.assign('/studio/hub/');
  } catch(error) { status.textContent = error.message; }
  finally { button.disabled = false; }
});
