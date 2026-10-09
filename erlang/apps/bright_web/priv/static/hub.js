'use strict';
const $ = selector => document.querySelector(selector);
let csrf, sources = [], states = new Map(), key, requestData, loadVersion = 0, libraryEnabled = false;
let sourceId, revisions = [], selectedRevision, revisionVersion = 0, uploadSource, uploadKey, uploadFingerprint, createdSource;
const pending = new Set(['queued', 'processing']);
const labels = {queued:'Waiting to extract',processing:'Extracting',ready:'Ready to read',failed:'Needs attention'};
const failures = {no_text:'No readable text was found. Scanned PDFs need OCR, which is not available yet.',invalid_document:'This file could not be read. Check that it is valid, UTF-8 for TXT, and not password protected.',resource_limit:'This file exceeds the extraction limits. Try a smaller document.',extraction_unavailable:'The file converter is unavailable. Your original is saved; retry when the service is restored.',worker_unavailable:'Extraction could not finish after repeated worker restarts. You can retry.'};
const messages = {400:'Check the source details and file format.',401:'Your session has expired. Sign in again.',403:'You do not have access to this project.',404:'This source or revision is unavailable.',409:'The request conflicts with an earlier save, or the revision is not ready.',413:'The upload exceeds the 4 MiB file limit or your private storage allowance.',415:'Choose a TXT, PDF or EPUB file.',503:'The database is unavailable. Your changes have not been confirmed. Retry the same request.'};
async function api(path, options = {}) {
  let response;
  try { response = await fetch(path, options); } catch { throw new Error('Could not confirm the request. Keep this dialog open and retry the same file.'); }
  if (!response.ok) { const error = new Error(messages[response.status] || 'Request failed. Please retry.'); error.status = response.status; throw error; }
  return response.json();
}
function status(message, error = false) { $('#status').textContent = message; $('#status').classList.toggle('error', error); }
function render() {
  const query = $('#search').value.toLocaleLowerCase(), visible = sources.filter(source => source.title.toLocaleLowerCase().includes(query));
  $('#sources').replaceChildren(); $('#empty').hidden = visible.length > 0;
  $('#empty').textContent = sources.length ? 'No sources match your search.' : 'No sources yet. Add your first source to start your library.';
  for (const source of visible) {
    const card = document.createElement('article'); card.className = 'card';
    const heading = document.createElement('h2'), link = document.createElement('a'), detail = document.createElement('p');
    link.href = `/studio/hub/sources/${source.id}`; link.textContent = source.title;
    const revision = states.get(source.id);
    heading.append(link); detail.textContent = revision ? `${labels[revision.state]} · Revision ${revision.revision}` : `${source.kind} · Metadata saved`;
    card.append(heading, detail); $('#sources').append(card);
  }
}
async function load(quiet = false) {
  const version = ++loadVersion, project = $('#project').value;
  if (!quiet) { sources = []; render(); $('#add').disabled = true; status('Loading sources…'); }
  try {
    const [items, revisionStates] = await Promise.all([
      api(`/studio/api/hub/sources?project_id=${encodeURIComponent(project)}`),
      libraryEnabled ? api(`/studio/api/hub/library-state?project_id=${encodeURIComponent(project)}`) : []
    ]);
    if (version !== loadVersion) return;
    sources = items; states = new Map(revisionStates.map(item => [item.source_id,item]));
    render(); status(`Showing ${sources.length} newest sources in this project.`); $('#add').disabled = false;
  } catch(error) { if (version === loadVersion) { $('#empty').hidden = true; status(error.message,true); $('#add').disabled = true; } }
}
$('#search').addEventListener('input', render);
$('#project').addEventListener('change', () => load());
function dialog(existingSource) {
  $('#source-form').reset(); $('#form-status').textContent = ''; key = crypto.randomUUID(); uploadKey = crypto.randomUUID();
  requestData = uploadFingerprint = createdSource = undefined; uploadSource = existingSource;
  $('#metadata-fields').hidden = Boolean(existingSource);
  $('#source-form [name=title]').required = !existingSource;
  $('#file').required = Boolean(existingSource); $('#file-label').hidden = !libraryEnabled;
  $('#dialog-title').textContent = existingSource ? 'Upload a revision' : 'Add Source';
  $('#dialog-description').textContent = existingSource ? 'Save a new original. Earlier revisions remain available.' : 'Add metadata, and optionally a file to read.';
  $('#save').textContent = existingSource ? 'Upload file' : 'Save source';
  $('#dialog').showModal(); (existingSource ? $('#file') : $('#source-form [name=title]')).focus();
}
$('#add').addEventListener('click', () => dialog());
$('#first-upload').addEventListener('click', () => dialog(sourceId));
$('#upload-revision').addEventListener('click', () => dialog(sourceId));
$('#dialog').addEventListener('cancel', event => { if ($('#save').disabled) event.preventDefault(); });
$('#cancel').addEventListener('click', () => $('#dialog').close());
function fileType(file) {
  const extension = file.name.split('.').pop().toLowerCase();
  return {txt:'text/plain',pdf:'application/pdf',epub:'application/epub+zip'}[extension];
}
$('#source-form').addEventListener('submit', async event => {
  event.preventDefault(); const form = event.currentTarget, save = $('#save'), file = $('#file').files[0];
  if (file && (!fileType(file) || file.size === 0 || file.size > 4194304)) { $('#form-status').textContent = 'Choose a nonempty TXT, PDF or EPUB file up to 4 MiB.'; return; }
  const data = JSON.stringify({title:form.elements.title.value,kind:form.elements.kind.value,url:form.elements.url.value,project_id:$('#project').value});
  if (requestData !== undefined && requestData !== data) { key = crypto.randomUUID(); createdSource = undefined; }
  requestData = data; save.disabled = true; $('#cancel').disabled = true;
  try {
    let target = uploadSource || createdSource;
    if (!target) {
      $('#form-status').textContent = 'Saving metadata…';
      const source = await api('/studio/api/hub/sources',{method:'POST',headers:{'Content-Type':'application/json','X-CSRF-Token':csrf,'Idempotency-Key':key},body:data});
      target = createdSource = source.id;
    }
    if (file) {
      $('#form-status').textContent = 'Uploading private original…';
      const buffer = await file.arrayBuffer(), hash = new Uint8Array(await crypto.subtle.digest('SHA-256',buffer));
      const fingerprint = `${file.name}:${Array.from(hash).map(b => b.toString(16).padStart(2,'0')).join('')}`;
      if (uploadFingerprint !== undefined && uploadFingerprint !== fingerprint) uploadKey = crypto.randomUUID();
      uploadFingerprint = fingerprint;
      const revision = await api(`/studio/api/hub/sources/${target}/revisions`,{method:'POST',headers:{'Content-Type':fileType(file),'X-CSRF-Token':csrf,'Idempotency-Key':uploadKey,'X-Upload-Filename':encodeURIComponent(file.name)},body:file});
      if (sourceId) { selectedRevision = revision.id; history.replaceState(null,'',`?revision=${revision.id}`); }
    }
    $('#dialog').close();
    if (sourceId) { await loadRevisions(); $('#upload-revision').focus(); }
    else { await load(); $('#add').focus(); }
  } catch(error) { $('#form-status').textContent = createdSource && !uploadSource ? `Source metadata is saved. ${error.message}` : error.message; }
  finally { save.disabled = false; $('#cancel').disabled = false; }
});
async function loadRevisions() {
  const version = ++revisionVersion;
  try {
    const items = await api(`/studio/api/hub/sources/${sourceId}/revisions`);
    if (version !== revisionVersion) return;
    revisions = items; $('#metadata-only').hidden = items.length > 0; $('#first-upload').hidden = items.length > 0;
    $('#reading').hidden = !items.length;
    if (!items.length) { status('Source metadata loaded. Add a file when you are ready to read.'); return; }
    if (!selectedRevision) selectedRevision = new URLSearchParams(location.search).get('revision') || items[0].id;
    $('#revision').replaceChildren(...items.map(item => { const option=document.createElement('option'); option.value=item.id;option.textContent=`Revision ${item.revision} · ${item.filename}`;return option; }));
    const revision = items.find(item => item.id === selectedRevision);
    if (!revision) { $('#reading-text').replaceChildren(); $('#download').hidden = true; $('#retry').hidden = true; $('#reading-status').textContent = 'This revision is unavailable.'; return; }
    $('#revision').value = selectedRevision;
    $('#download').hidden = false; $('#download').href = `/studio/api/hub/sources/${sourceId}/revisions/${selectedRevision}/original`;
    $('#retry').hidden = revision.state !== 'failed'; $('#reading-text').replaceChildren();
    if (revision.state === 'ready') {
      const content = await api(`/studio/api/hub/sources/${sourceId}/revisions/${selectedRevision}/content`);
      if (version !== revisionVersion) return;
      const text = document.createElement('pre'); text.textContent = content.text; $('#reading-text').append(text);
      $('#reading-status').textContent = `Ready to read · Revision ${revision.revision}`; status('Your original and reading text are saved.');
    } else if (revision.state === 'failed') { $('#reading-status').textContent = failures[revision.error] || 'Extraction failed. Your original is still available.'; }
    else { $('#reading-status').textContent = revision.state === 'processing' ? 'Extracting readable text…' : 'Original saved. Waiting for the extraction worker…'; }
  } catch(error) { $('#reading-status').textContent = error.message; }
}
$('#revision').addEventListener('change', () => { $('#reading-text').replaceChildren(); $('#reading-status').textContent = 'Loading revision…'; selectedRevision = $('#revision').value; history.replaceState(null,'',`?revision=${selectedRevision}`); loadRevisions(); });
$('#retry').addEventListener('click', async () => {
  $('#retry').disabled = true;
  try { await api(`/studio/api/hub/sources/${sourceId}/revisions/${selectedRevision}/retry`,{method:'POST',headers:{'X-CSRF-Token':csrf}}); await loadRevisions(); }
  catch(error) { $('#reading-status').textContent = error.message; }
  finally { $('#retry').disabled = false; }
});
$('#logout').addEventListener('click', async () => {
  try { await api('/studio/api/session/logout',{method:'POST',headers:{'X-CSRF-Token':csrf}}); location.assign('/studio/login/'); }
  catch(error) { status(error.message,true); }
});
(async () => {
  document.querySelectorAll('nav a').forEach(a => { if(a.pathname === location.pathname) a.setAttribute('aria-current','page'); });
  try {
    const session = await api('/studio/api/session'); csrf = session.csrf; libraryEnabled = session.library_enabled; $('#account').textContent = session.email;
    $('#library-notice').textContent = libraryEnabled ? 'Private TXT, PDF and EPUB files, with readable text and immutable revisions.' : 'Metadata only. File reading is currently disabled.';
    const projects = await api('/studio/api/hub/projects');
    for(const project of projects) { const option = document.createElement('option'); option.value = project.id; option.textContent = project.title; $('#project').append(option); }
    if (!projects.length) { status('No projects available. Ask your workspace administrator to provision a project.'); return; }
    if (location.pathname.startsWith('/studio/hub/sources/')) {
      sourceId = location.pathname.split('/').pop();
      const source = await api(`/studio/api/hub/sources/${encodeURIComponent(sourceId)}`);
      $('#heading').textContent = 'Reader'; $('#reader').hidden = false;
      $('#source-title').textContent = source.title; $('#source-kind').textContent = source.kind;
      $('#project').value = source.project_id; $('#project').disabled = true;
      if(source.url) { $('#source-url').href = source.url; $('#source-url').hidden = false; }
      status('Source metadata loaded.'); if (libraryEnabled) await loadRevisions();
    } else { $('#library').hidden = false; await load(); }
    setInterval(() => {
      if (document.hidden || $('#dialog').open) return;
      if (sourceId && libraryEnabled && revisions.some(r => r.id === selectedRevision && pending.has(r.state))) loadRevisions();
      else if (!sourceId && Array.from(states.values()).some(r => pending.has(r.state))) load(true);
    },1500);
  } catch(error) { status(error.message,true); }
})();
