'use strict';
const $ = selector => document.querySelector(selector);
let csrf, sources = [], states = new Map(), key, requestData, loadVersion = 0, libraryEnabled = false, studyEnabled = false;
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
  const overview=location.pathname==='/studio/hub/';
  const latest=sources.find(source=>states.get(source.id)?.state==='ready');
  $('#continue-reading').hidden=!overview||!latest;$('#overview-study').hidden=!overview||!latest||!studyEnabled;
  if(latest){const revision=states.get(latest.id);$('#continue-title').textContent=latest.title;$('#continue-detail').textContent=`Revision ${revision.revision}`;$('#continue-link').href=`/studio/hub/sources/${latest.id}?revision=${revision.revision_id}`;$('#overview-study-title').textContent=latest.title;$('#overview-study-detail').textContent=`Revision ${revision.revision} · Recall and reflection`;$('#overview-study-link').href=`/studio/hub/study/?source=${latest.id}&revision=${revision.revision_id}`;}
  const query = $('#search').value.toLocaleLowerCase(), visible = sources.filter(source => source.title.toLocaleLowerCase().includes(query));
  $('#sources').replaceChildren(); $('#empty').hidden = visible.length > 0;
  $('#empty').textContent = sources.length ? 'No sources match your search.' : 'No sources yet. Add your first source to start your library.';
  for (const source of visible) {
    const card = document.createElement('article'); card.className = 'card';
    const heading = document.createElement('h2'), link = document.createElement('a'), detail = document.createElement('p');
    link.href = `/studio/hub/sources/${source.id}`; link.textContent = source.title;
    const revision = states.get(source.id);
    heading.append(link); detail.textContent = revision ? `${labels[revision.state]} · Revision ${revision.revision}` : `${source.kind} · Metadata saved`;
    const format=document.createElement('span');format.className='source-format';format.setAttribute('aria-hidden','true');format.textContent=source.kind.toUpperCase();
    card.append(format, heading, detail); $('#sources').append(card);
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
$('#project').addEventListener('change', () => {sessionStorage.setItem('bright-project',$('#project').value);if(!['/studio/hub/evidence/','/studio/hub/study/','/studio/hub/projects/','/studio/hub/tasks/','/studio/hub/planner/','/studio/hub/account/'].includes(location.pathname)) load();});
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
    $('#revision').value = selectedRevision;$('#reader-context-revision').textContent=`Revision ${revision.revision}`;
    if(revision.state==='failed')$('#reader-tools').open=true;
    $('#download').hidden = false; $('#download').href = `/studio/api/hub/sources/${sourceId}/revisions/${selectedRevision}/original`;
    $('#retry').hidden = revision.state !== 'failed'; $('#reading-text').replaceChildren();
    document.dispatchEvent(new CustomEvent('bright-reader',{detail:{sourceId,revisionId:selectedRevision,text:null,state:revision.state}}));
    if (revision.state === 'ready') {
      const content = await api(`/studio/api/hub/sources/${sourceId}/revisions/${selectedRevision}/content`);
      if (version !== revisionVersion) return;
      const text = document.createElement('pre'); text.textContent = content.text; $('#reading-text').append(text);
      document.dispatchEvent(new CustomEvent('bright-reader',{detail:{sourceId,revisionId:selectedRevision,text:content.text,state:'ready'}}));
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
    const session = await api('/studio/api/session'); csrf = session.csrf; libraryEnabled = session.library_enabled; studyEnabled=session.study_enabled; $('#account').textContent = session.display_name||session.email;
    $('#library-notice').textContent = libraryEnabled ? 'Private TXT, PDF and EPUB files, with readable text and immutable revisions.' : 'Metadata only. File reading is currently disabled.';
    const projects = await api('/studio/api/hub/projects');
    document.dispatchEvent(new CustomEvent('bright-session',{detail:{enabled:session.evidence_enabled,studyEnabled:session.study_enabled,workspaceEnabled:session.workspace_enabled,csrf,projects}}));
    for(const project of projects) { const option = document.createElement('option'); option.value = project.id; option.textContent = project.title; $('#project').append(option); }
    const preferred=new URLSearchParams(location.search).get('project')||sessionStorage.getItem('bright-project');if(projects.some(p=>p.id===preferred))$('#project').value=preferred;
    if (!projects.length) { status('No projects available. Ask your workspace administrator to provision a project.'); return; }
    if (location.pathname.startsWith('/studio/hub/sources/')) {
      sourceId = location.pathname.split('/').pop();
      const source = await api(`/studio/api/hub/sources/${encodeURIComponent(sourceId)}`);
      $('#page-intro').hidden=true; $('#reader').hidden = false;
      $('#source-title').textContent = source.title;$('#reader-context-title').textContent=source.title; $('#source-kind').textContent = source.kind;
      $('#project').value = source.project_id;sessionStorage.setItem('bright-project',source.project_id); $('#project').disabled = true;
      if(source.url) { $('#source-url').href = source.url; $('#source-url').hidden = false; }
      status('Source metadata loaded.'); if (libraryEnabled) await loadRevisions();
    } else if(['/studio/hub/projects/','/studio/hub/tasks/','/studio/hub/planner/','/studio/hub/account/'].includes(location.pathname)) { $('#workspace-page').hidden=false; status('Your projects, tasks and account settings.'); } else if(location.pathname === '/studio/hub/study/') { $('#heading').textContent='Study'; $('#description').textContent='Practice a passage, save a reflection, and return to your progress.'; $('#library-notice').hidden=true;$('#study-page').hidden=false; status('Practice and resume saved lessons.'); } else if(location.pathname === '/studio/hub/evidence/') { $('#heading').textContent='Evidence'; $('#library-notice').hidden=true;$('#boards-page').hidden=false; status('Collect pinned quotes and notes on your project boards.'); }
    else { const overview=location.pathname==='/studio/hub/';$('#heading').textContent=overview?'A little space to learn':'Library';$('#description').textContent=overview?'Return to a source, practice an idea, and make it your own.':'Keep the sources that matter, and return when you are ready.';$('#sources-heading').textContent=overview?'Recent sources':'Your sources';$('#library-notice').hidden=libraryEnabled;$('#library').hidden = false; await load(); }
    setInterval(() => {
      if (document.hidden || $('#dialog').open) return;
      if (sourceId && libraryEnabled && revisions.some(r => r.id === selectedRevision && pending.has(r.state))) loadRevisions();
      else if (!sourceId && !$('#library').hidden && Array.from(states.values()).some(r => pending.has(r.state))) load(true);
    },1500);
  } catch(error) { status(error.message,true); }
})();
