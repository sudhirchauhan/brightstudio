'use strict';
const $ = selector => document.querySelector(selector);
let csrf, sources = [], key, requestData, loadVersion = 0;
const messages = {400:'Check the title, type and URL.',401:'Your session has expired. Sign in again.',403:'You do not have access to this project.',404:'This source is unavailable.',409:'This request conflicts with a previous save. Close the dialog and try again.',503:'The database is unavailable. Your changes have not been confirmed. Retry to check the same request.'};
async function api(path, options = {}) {
  const response = await fetch(path, options);
  if (!response.ok) { const error = new Error(messages[response.status] || 'Request failed. Please retry.'); error.status = response.status; throw error; }
  return response.json();
}
function status(message, error = false) { $('#status').textContent = message; $('#status').classList.toggle('error', error); }
function render() {
  const query = $('#search').value.toLocaleLowerCase();
  const visible = sources.filter(source => source.title.toLocaleLowerCase().includes(query));
  $('#sources').replaceChildren();
  $('#empty').hidden = visible.length > 0;
  $('#empty').textContent = sources.length ? 'No sources match your search.' : 'No sources yet. Add your first source to start your library.';
  for (const source of visible) {
    const card = document.createElement('article'); card.className = 'card';
    const heading = document.createElement('h2'), link = document.createElement('a'), detail = document.createElement('p');
    link.href = `/studio/hub/sources/${source.id}`; link.textContent = source.title;
    heading.append(link); detail.textContent = `${source.kind} · Metadata saved`;
    card.append(heading, detail); $('#sources').append(card);
  }
}
async function load() {
  const version = ++loadVersion, project = $('#project').value;
  sources = []; render(); $('#add').disabled = true; status('Loading sources…');
  try {
    const items = await api(`/studio/api/hub/sources?project_id=${encodeURIComponent(project)}`);
    if (version !== loadVersion) return;
    sources = items; render(); status(`Showing ${sources.length} newest sources in this project.`); $('#add').disabled = false;
  } catch(error) { if (version === loadVersion) { $('#empty').hidden = true; status(error.message,true); } }
}
$('#search').addEventListener('input', render);
$('#project').addEventListener('change', load);
$('#add').addEventListener('click', () => {
  $('#source-form').reset(); $('#form-status').textContent = ''; key = crypto.randomUUID(); requestData = undefined;
  $('#dialog').showModal(); $('#source-form [name=title]').focus();
});
$('#dialog').addEventListener('cancel', event => { if ($('#save').disabled) event.preventDefault(); });
$('#cancel').addEventListener('click', () => $('#dialog').close());
$('#source-form').addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.currentTarget, save = $('#save');
  const data = JSON.stringify({...Object.fromEntries(new FormData(form)), project_id:$('#project').value});
  if (requestData !== undefined && requestData !== data) key = crypto.randomUUID();
  requestData = data; save.disabled = true; $('#cancel').disabled = true; $('#form-status').textContent = 'Saving metadata…';
  try {
    await api('/studio/api/hub/sources', {method:'POST',headers:{'Content-Type':'application/json','X-CSRF-Token':csrf,'Idempotency-Key':key},body:data});
    $('#dialog').close(); await load(); $('#add').focus();
  } catch(error) { $('#form-status').textContent = error.message; }
  finally { save.disabled = false; $('#cancel').disabled = false; }
});
$('#logout').addEventListener('click', async () => {
  try { await api('/studio/api/session/logout',{method:'POST',headers:{'X-CSRF-Token':csrf}}); location.assign('/studio/login/'); }
  catch(error) { status(error.message,true); }
});
(async () => {
  document.querySelectorAll('nav a').forEach(a => { if(a.pathname === location.pathname) a.setAttribute('aria-current','page'); });
  try {
    const session = await api('/studio/api/session'); csrf = session.csrf; $('#account').textContent = session.email;
    const projects = await api('/studio/api/hub/projects');
    for(const project of projects) { const option = document.createElement('option'); option.value = project.id; option.textContent = project.title; $('#project').append(option); }
    if (!projects.length) { status('No projects available. Ask your workspace administrator to provision a project.'); return; }
    if (location.pathname.startsWith('/studio/hub/sources/')) {
      const source = await api(`/studio/api/hub/sources/${encodeURIComponent(location.pathname.split('/').pop())}`);
      $('#heading').textContent = 'Reader'; $('#reader').hidden = false;
      $('#source-title').textContent = source.title; $('#source-kind').textContent = source.kind;
      $('#project').value = source.project_id; $('#project').disabled = true;
      if(source.url) { $('#source-url').href = source.url; $('#source-url').hidden = false; }
      status('Source metadata loaded.');
    } else { $('#library').hidden = false; await load(); }
  } catch(error) { status(error.message,true); }
})();
