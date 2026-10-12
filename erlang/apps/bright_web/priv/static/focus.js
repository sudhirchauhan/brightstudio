'use strict';
(() => {
  const $=s=>document.querySelector(s),page=location.pathname==='/studio/hub/focus/';
  let csrf,enabled=false,session,targets=[],saving=false,opening=false,request,version=0,receivedAt=0;
  const messages={400:'Check the duration, checkpoint (10 characters) or reflection (20 characters).',401:'Your session has expired. Sign in again.',403:'This project is unavailable.',404:'This session or linked work is unavailable.',409:'Saved state changed, or another session is open. Load saved sessions before trying again. Your draft is kept.',413:'Your Focus allowance is full.',503:'Could not confirm the save. Retry the same request.'};
  async function api(path,options={}) {
    let r;try{r=await fetch('/studio/api/hub/'+path,options);}catch{throw Error('Could not confirm the save. Retry the same request.');}
    if(!r.ok){let detail={};try{detail=await r.json();}catch{}const e=Error(detail.error==='not_ready'?'Completion needs the saved session time and at least one checkpoint.':messages[r.status]||'Please retry.');e.status=r.status;throw e;}return r.json();
  }
  function node(tag,text){const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n;}
  function button(text,action){const n=node('button',text);n.type='button';n.addEventListener('click',action);return n;}
  function status(text){$('#focus-status').textContent=text;}
  function closed(){return session&&['completed','cancelled'].includes(session.state);}
  function busy(value){saving=value;$('#project').disabled=value||Boolean(session);for(const id of ['focus-start-button','focus-reload','focus-back','focus-pause','focus-resume','focus-cancel','focus-sync','focus-checkpoint-save'])$('#'+id).disabled=value;tick();}
  function activity(open){document.dispatchEvent(new CustomEvent('bright-focus',{detail:{open}}));}
  function tick(){
    if(!session)return;
    const elapsed=Math.min(session.duration_ms,session.elapsed_ms+(session.state==='active'?Math.max(0,performance.now()-receivedAt):0));
    const remaining=Math.ceil((session.duration_ms-elapsed)/1000);$('#focus-timer').textContent=`${String(Math.floor(remaining/60)).padStart(2,'0')}:${String(remaining%60).padStart(2,'0')}`;
    const ready=elapsed>=session.duration_ms&&session.checkpoint_count>=1;if(ready&&!closed())$('#focus-complete-box').open=true;
    $('#focus-finish').disabled=saving||closed()||!ready;
    $('#focus-checkpoint-save').disabled=saving||closed()||session.checkpoint_count>=20;
    $('#focus-gate').textContent=closed()?'Saved session.':!session.checkpoint_count?'Save at least one checkpoint, then finish when the time is complete.':elapsed<session.duration_ms?'Finish when the session time is complete.':'Time is complete. Save your reflection to finish.';
  }
  function show(next,preserve=true){
    const first=!session;session=next;receivedAt=performance.now();$('#focus-session').hidden=false;$('#focus-home').hidden=true;
    $('#project').value=next.project_id;$('#project').disabled=true;sessionStorage.setItem('bright-project',next.project_id);
    $('#focus-title').textContent=next.target_title;$('#focus-context').textContent=next.source_id?`${next.target_title} · Revision ${next.revision}`:`${next.target_title} · Task`;
    $('#focus-hint').hidden=closed();$('#focus-hint').textContent=next.state==='paused'?'Your timer is paused. Resume when you are ready.':'The timer keeps running when you leave. Pause it to stop.';
    $('#focus-state').textContent=`${next.state==='active'?'In progress':next.state[0].toUpperCase()+next.state.slice(1)} · ${next.checkpoint_count} saved checkpoints`;
    $('#focus-origin').href=next.source_id?`/studio/hub/sources/${next.source_id}?revision=${next.revision_id}`:`/studio/hub/tasks/?project=${next.project_id}`;
    $('#focus-pause').hidden=next.state!=='active';$('#focus-resume').hidden=next.state!=='paused';$('#focus-cancel').hidden=closed();
    if(!preserve){$('#focus-note').value='';$('#focus-summary').value='';}
    $('#focus-checkpoint').hidden=closed()&&!$('#focus-note').value;$('#focus-complete').hidden=closed()&&!$('#focus-summary').value;
    $('#focus-checkpoint-box').hidden=$('#focus-checkpoint').hidden;$('#focus-complete-box').hidden=$('#focus-complete').hidden;
    if(first){$('#focus-checkpoint-box').open=false;$('#focus-complete-box').open=false;}
    $('#focus-note').readOnly=closed();$('#focus-summary').readOnly=closed();
    $('#focus-completed-summary').hidden=next.state!=='completed';$('#focus-completed-summary').textContent=next.summary;
    const selected=$('#focus-evidence').value;$('#focus-evidence').replaceChildren(new Option('No evidence link',''));
    for(const e of next.evidence_options||[]){const o=new Option(`${e.title} · Revision ${e.revision}: ${e.quote.slice(0,100)}`,e.id);$('#focus-evidence').append(o);}
    $('#focus-evidence-label').hidden=!(next.evidence_options||[]).length;$('#focus-evidence').value=[...$('#focus-evidence').options].some(o=>o.value===selected)?selected:'';
    $('#focus-checkpoints').replaceChildren();
    for(const c of next.checkpoints){const card=node('article');card.className='card';card.append(node('h3',`Checkpoint ${c.ordinal}`),node('p',c.note));if(c.quote){card.append(node('blockquote',c.quote));const link=node('a','Open pinned evidence');link.href=`/studio/hub/sources/${c.source_id}?revision=${c.revision_id}#highlight-${c.evidence_id}`;card.append(link);}$('#focus-checkpoints').append(card);}
    history.replaceState(null,'',`?session=${next.id}`);if(first){activity(true);$('#focus-mode').focus({preventScroll:true});window.scrollTo(0,0);}tick();
  }
  async function open(id){if(saving||opening)return;opening=true;$('#focus-sync').disabled=true;try{const next=await api(`focus/${id}`);show(next);request=undefined;$('#focus-save-status').textContent='Saved session loaded. Your draft is kept; review checkpoints before saving.';status('');}catch(e){(session?$('#focus-save-status'):$('#focus-status')).textContent=e.message;}finally{opening=false;$('#focus-sync').disabled=false;}}
  function card(s){const c=node('article');c.className='card';c.append(node('h2',s.target_title),node('p',`${s.state} · ${s.duration_ms/60000} minutes · ${s.checkpoint_count} checkpoints`),button(['active','paused'].includes(s.state)?'Resume saved session':'Review session',()=>open(s.id)));return c;}
  async function load(){
    if(saving)return;const current=++version,project=$('#project').value;status('Loading saved sessions…');$('#focus-start-button').disabled=true;
    try{const [work,data]=await Promise.all([api(`focus/targets?project_id=${encodeURIComponent(project)}`),api(`focus?project_id=${encodeURIComponent(project)}`)]);if(current!==version)return;
      targets=[...work.tasks,...work.sources];$('#focus-target').replaceChildren(...targets.map((t,i)=>new Option(`${t.source_id?'Source':'Task'}: ${t.title}${t.revision?` · Revision ${t.revision}`:''}`,String(i))));
      const params=new URLSearchParams(location.search),preferred=targets.findIndex(t=>params.has('task')?t.task_id===params.get('task'):t.source_id===params.get('source')&&t.revision_id===params.get('revision'));
      if(preferred>=0)$('#focus-target').value=String(preferred);
      $('#focus-current').replaceChildren();$('#focus-current').hidden=!data.current;if(data.current)$('#focus-current').append(node('p','You have an open session. Resume or cancel it before starting another.'),card(data.current));
      $('#focus-start-button').disabled=!targets.length||Boolean(data.current);$('#focus-list').replaceChildren(...data.sessions.map(card));
      status(!targets.length?'No tasks or ready sources yet. Add learning work to this project first.':data.current?'Resume your saved session.':'Choose one piece of learning work.');if(!data.sessions.length)$('#focus-list').append(node('p','No sessions yet. Start your first Focus session.'));
    }catch(e){if(current===version)status(e.message);}
  }
  async function saveAction(action,extra={}){
    if(saving||opening||!session)return;
    const body=JSON.stringify({action,expected_version:session.version,...extra});if(!request||request.body!==body)request={body,key:crypto.randomUUID()};
    busy(true);$('#focus-save-status').textContent='Saving…';
    try{await api(`focus/${session.id}/actions`,{method:'POST',headers:{'Content-Type':'application/json','X-CSRF-Token':csrf,'Idempotency-Key':request.key},body:request.body});
      const latest=await api(`focus/${session.id}`);show(latest);request=undefined;
      if(action==='checkpoint'){$('#focus-note').value='';if(closed()){$('#focus-checkpoint').hidden=true;$('#focus-checkpoint-box').hidden=true;}}if(action==='complete'){$('#focus-summary').value='';$('#focus-complete').hidden=true;$('#focus-complete-box').hidden=true;}
      $('#focus-save-status').textContent=action==='checkpoint'?'Checkpoint saved.':action==='complete'?'Session completed and saved.':'Saved session updated.';
    }catch(e){$('#focus-save-status').textContent=e.message;}finally{busy(false);}
  }
  $('#focus-start').addEventListener('submit',async e=>{
    e.preventDefault();if(saving||opening)return;const target=targets[Number($('#focus-target').value)];if(!target)return;
    const body=JSON.stringify({project_id:$('#project').value,minutes:Number($('#focus-minutes').value),...(target.task_id?{task_id:target.task_id}:{source_id:target.source_id,revision_id:target.revision_id})});
    if(!request||request.body!==body)request={body,key:crypto.randomUUID()};busy(true);status('Starting saved session…');
    try{const receipt=await api('focus',{method:'POST',headers:{'Content-Type':'application/json','X-CSRF-Token':csrf,'Idempotency-Key':request.key},body:request.body});show(await api(`focus/${receipt.id}`),false);request=undefined;status('');$('#focus-save-status').textContent='Session saved.';}catch(err){status(err.message);}finally{busy(false);}
  });
  for(const action of ['pause','resume','cancel'])$('#focus-'+action).addEventListener('click',()=>saveAction(action));
  $('#focus-checkpoint').addEventListener('submit',e=>{e.preventDefault();saveAction('checkpoint',{expected_checkpoint:session.checkpoint_count,note:$('#focus-note').value,evidence_id:$('#focus-evidence').value||null});});
  $('#focus-complete').addEventListener('submit',e=>{e.preventDefault();saveAction('complete',{summary:$('#focus-summary').value});});
  $('#focus-sync').addEventListener('click',()=>open(session.id));$('#focus-reload').addEventListener('click',load);
  $('#focus-back').addEventListener('click',()=>{if(saving||opening)return;session=undefined;request=undefined;$('#focus-session').hidden=true;$('#focus-home').hidden=false;$('#project').disabled=false;history.replaceState(null,'','/studio/hub/focus/');activity(false);load();});
  $('#project').addEventListener('change',()=>{if(enabled&&page&&!session)load();});
  document.addEventListener('bright-reader',e=>{const d=e.detail;$('#focus-source').hidden=!enabled||d.state!=='ready';$('#focus-source').href=`/studio/hub/focus/?source=${d.sourceId}&revision=${d.revisionId}&project=${$('#project').value}`;});
  document.addEventListener('bright-session',async e=>{enabled=e.detail.focusEnabled;csrf=e.detail.csrf;$('#focus-nav').hidden=!enabled;if(!enabled||!page)return;await Promise.resolve();const id=new URLSearchParams(location.search).get('session');if(id)await open(id);else await load();});
  setInterval(tick,1000);
  setInterval(async()=>{if(!session||saving||opening||request||document.hidden||closed())return;const id=session.id;try{const latest=await api(`focus/${id}`);if(!session||session.id!==id||saving||request)return;if(latest.version===session.version){session=latest;receivedAt=performance.now();tick();}else $('#focus-save-status').textContent='Saved state changed in another tab. Load saved session. Your draft is kept.';}catch(e){if(session?.id===id)$('#focus-save-status').textContent=e.message;}},15000);
})();
