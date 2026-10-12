'use strict';
(() => {
  const $=s=>document.querySelector(s), page=location.pathname==='/studio/hub/study/';
  let csrf,pass,request,loadVersion=0,enabled=false,opening=false,saving=false;
  function busy(value){ $('#project').disabled=value; $('#study-reload').disabled=value; $('#study-back').disabled=value; }
  const messages={400:'Enter an answer, or a reflection of at least 20 characters.',401:'Your session has expired. Sign in again.',403:'You do not have access to this project.',404:'This lesson is unavailable.',409:'Progress changed in another tab. Refresh study to load the saved lesson. Your answer is kept below.',413:'Your study allowance is full.',503:'Could not confirm the save. Retry the same answer.'};
  async function api(path,options={}) {
    let response;try{response=await fetch('/studio/api/hub/'+path,options);}catch{throw new Error('Could not confirm the save. Retry the same answer.');}
    if(!response.ok){const e=new Error(messages[response.status]||'Please retry.');e.status=response.status;throw e;}return response.json();
  }
  function status(text){$('#study-status').textContent=text;}
  function button(label,action){const b=document.createElement('button');b.type='button';b.textContent=label;b.addEventListener('click',action);return b;}
  function show(next,clear=true){
    pass=next;document.dispatchEvent(new CustomEvent('bright-lesson',{detail:{open:true}}));$('#study-lesson').hidden=false;$('#study-picker').hidden=true;$('#study-passes').hidden=true;
    $('#study-title').textContent=pass.source_title;$('#study-context-title').textContent=pass.source_title;$('#study-context-revision').textContent=`Revision ${pass.revision}`;
    $('#study-origin').href=`/studio/hub/sources/${pass.source_id}?revision=${pass.revision_id}`;
    $('#study-progress').textContent=`Revision ${pass.revision} · ${pass.step} of ${pass.total} chunks complete · ${pass.state}`;
    $('#lesson-progress').max=pass.total+1;$('#lesson-progress').value=pass.step+(pass.state==='completed'?1:0);
    $('#study-step-title').textContent=pass.state==='completed'?'A small step forward.':pass.state==='summary'?'What will you take with you?':'Recall the idea';
    $('#study-form').hidden=pass.state==='completed';$('#study-reference').hidden=pass.state!=='active';
    $('#study-summary').hidden=pass.state!=='completed';$('#study-summary').textContent=pass.summary;
    if(pass.state==='active'){$('#study-text').textContent=pass.lesson.text;$('#study-prompt').textContent=`Enter the missing word: ${pass.lesson.prompt}`;$('#study-submit').textContent='Check answer';}
    else if(pass.state==='summary'){$('#study-prompt').textContent='What will you remember or apply? Write a reflection of at least 20 characters.';$('#study-submit').textContent='Complete lesson';}
    if(clear){$('#study-answer').value='';$('#study-reference').open=false;}
    history.replaceState(null,'',`?pass=${pass.id}`);
  }
  async function open(id){if(opening||saving)return;opening=true;busy(true);status('Loading saved lesson…');if(!pass)$('#study-lesson').hidden=true;try{const next=await api(`study/${id}`);const source=await api(`sources/${next.source_id}`);$('#project').value=source.project_id;show(next);request=undefined;$('#study-feedback').textContent='';status('Saved progress loaded.');if(pass.state!=='completed')$('#study-answer').focus();}catch(e){status(e.message);if(pass)$('#study-feedback').textContent=e.message;}finally{opening=false;busy(false);}}
  async function start(source,revision){
    if(opening||saving)return;opening=true;busy(true);status('Opening revision-pinned lesson…');
    // Start is unique per owned revision. Reload can safely resume an uncertain start.
    try{const next=await api('study',{method:'POST',headers:{'Content-Type':'application/json','X-CSRF-Token':csrf,'Idempotency-Key':crypto.randomUUID()},body:JSON.stringify({source_id:source,revision_id:revision})});const origin=await api(`sources/${next.source_id}`);$('#project').value=origin.project_id;show(next);request=undefined;$('#study-feedback').textContent='';status('Lesson saved.');if(pass.state!=='completed')$('#study-answer').focus();}catch(e){status(e.message);}finally{opening=false;busy(false);}
  }
  async function load(){
    document.dispatchEvent(new CustomEvent('bright-lesson',{detail:{open:false}}));
    const version=++loadVersion,project=$('#project').value;status('Loading lessons…');
    $('#study-picker').replaceChildren();$('#study-passes').replaceChildren();$('#study-lesson').hidden=true;$('#study-picker').hidden=false;$('#study-passes').hidden=false;
    try{
      const [sources,states,passes]=await Promise.all([api(`sources?project_id=${project}`),api(`library-state?project_id=${project}`),api(`study?project_id=${project}`)]);
      if(version!==loadVersion)return;const ready=new Map(states.filter(r=>r.state==='ready').map(r=>[r.source_id,r]));
      for(const s of sources){const r=ready.get(s.id);if(!r)continue;const card=document.createElement('article');card.className='card';const h=document.createElement('h2');h.textContent=s.title;card.append(h,button(`Study revision ${r.revision}`,()=>start(s.id,r.revision_id)));$('#study-picker').append(card);}
      for(const p of passes){const card=document.createElement('article');card.className='card';const h=document.createElement('h2');h.textContent=p.source_title;const detail=document.createElement('p');detail.textContent=`Revision ${p.revision} · ${p.step}/${p.total} · ${p.state}`;card.append(h,detail,button(p.state==='completed'?'Review lesson':'Resume lesson',()=>open(p.id)));$('#study-passes').append(card);}
      status(ready.size||passes.length?'Choose a ready source or resume a saved lesson.':'No ready sources yet. Upload a file in Library and wait for extraction.');
    }catch(e){if(version===loadVersion)status(e.message);}
  }
  $('#study-form').addEventListener('submit',async event=>{
    event.preventDefault();if(!pass||saving||opening)return;const data={expected_version:pass.version,step:pass.step,kind:pass.state==='summary'?'summary':'answer',answer:$('#study-answer').value};
    const body=JSON.stringify(data);if(!request||request.body!==body)request={key:crypto.randomUUID(),body};
    saving=true;busy(true);$('#study-submit').disabled=true;$('#study-feedback').textContent='Saving answer…';
    try{const result=await api(`study/${pass.id}/attempts`,{method:'POST',headers:{'Content-Type':'application/json','X-CSRF-Token':csrf,'Idempotency-Key':request.key},body:request.body});const latest=await api(`study/${pass.id}`);const changed=latest.step!==pass.step||latest.state!==pass.state;request=undefined;show(latest,result.correct||changed);$('#study-feedback').textContent=result.feedback;$('#study-feedback').dataset.correct=String(result.correct);if(latest.state!=='completed')$('#study-answer').focus();}
    catch(e){$('#study-feedback').textContent=e.message;}
    finally{saving=false;busy(false);$('#study-submit').disabled=false;}
  });
  $('#study-back').addEventListener('click',()=>{history.replaceState(null,'','/studio/hub/study/');pass=undefined;request=undefined;load();});
  $('#study-reload').addEventListener('click',async()=>{const draft=$('#study-answer').value;if(pass){await open(pass.id);$('#study-answer').value=draft;}else load();});
  $('#project').addEventListener('change',()=>{if(enabled&&page){pass=undefined;request=undefined;history.replaceState(null,'','/studio/hub/study/');load();}});
  document.addEventListener('bright-reader',event=>{const d=event.detail;$('#study-source').hidden=!enabled||d.state!=='ready';$('#study-source').href=`/studio/hub/study/?source=${d.sourceId}&revision=${d.revisionId}`;});
  document.addEventListener('bright-session',async event=>{
    enabled=event.detail.studyEnabled;csrf=event.detail.csrf;$('#study-nav').hidden=!enabled;if(!enabled||!page)return;
    // Hub populates the project selector synchronously after dispatching this event.
    await Promise.resolve();const params=new URLSearchParams(location.search);
    if(params.has('pass'))await open(params.get('pass'));
    else if(params.has('source')&&params.has('revision'))await start(params.get('source'),params.get('revision'));
    else await load();
  });
})();
