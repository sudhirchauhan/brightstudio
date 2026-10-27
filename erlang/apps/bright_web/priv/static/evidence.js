'use strict';
(()=>{
  const $=s=>document.querySelector(s),encoder=new TextEncoder(),decoder=new TextDecoder('utf-8',{fatal:true});
  let csrf,projects=[],reader,items=[],generation=0,selection,editItem,saveKey,savePayload,boardKey,boardPayload;
  const isBoards=location.pathname==='/studio/hub/evidence/';
  async function api(route,options={}){
    let response;try{response=await fetch(route,options);}catch{throw Error('Could not confirm the save. Keep your note and retry the same request.');}
    if(!response.ok){const error=Error(({400:'The quote or note is invalid. Capture the exact text from this revision.',401:'Your session has expired. Sign in again.',403:'This project is unavailable.',404:'This evidence or board is unavailable.',409:'A newer note was saved. Your draft is kept below; reload the latest note before editing again.',413:'The evidence or board limit has been reached.',503:'The database is unavailable. Your save has not been confirmed.'})[response.status]||'Request failed. Please retry.');error.status=response.status;throw error;}
    return response.json();
  }
  function post(route,data,key){return api(route,{method:'POST',headers:{'Content-Type':'application/json','X-CSRF-Token':csrf,...(key?{'Idempotency-Key':key}:{})},body:JSON.stringify(data)});}
  function el(tag,text){const node=document.createElement(tag);if(text!==undefined)node.textContent=text;return node;}
  function button(text,action){const node=el('button',text);node.type='button';node.className='secondary';node.addEventListener('click',action);return node;}
  function msg(text){$('#evidence-status').textContent=text;}
  function selected(s,e){
    if(!reader?.text || s<0 || e<=s)return;
    const quote=reader.text.slice(s,e);if(!quote.trim()||[...quote].length>2048||encoder.encode(quote).length>8192){msg('Select up to 2,048 characters of readable text.');return;}
    selection={source_id:reader.sourceId,revision_id:reader.revisionId,start_byte:encoder.encode(reader.text.slice(0,s)).length,end_byte:encoder.encode(reader.text.slice(0,e)).length,quote};
    editItem=undefined;saveKey=crypto.randomUUID();savePayload=undefined;
    $('#selected-quote').textContent=quote;$('#evidence-note').value='';$('#evidence-dialog-title').textContent='Save evidence';$('#evidence-save').textContent='Save evidence';$('#evidence-form-status').replaceChildren();
    $('#evidence-dialog').showModal();$('#evidence-note').focus();
  }
  $('#capture-selection').addEventListener('click',()=>{
    const formatted=window.brightFormattedSelection?.();if(formatted){if(formatted.error){msg(formatted.error);return;}selected(formatted.start,formatted.end);return;}
    const current=window.getSelection(),pre=$('#reading-text pre');
    if(!pre||!current.rangeCount||current.isCollapsed){msg('Select text in the Reader first, or use Find quote.');return;}
    const range=current.getRangeAt(0);if(!pre.contains(range.startContainer)||!pre.contains(range.endContainer)){msg('Select text within this revision only.');return;}
    const before=document.createRange();before.selectNodeContents(pre);before.setEnd(range.startContainer,range.startOffset);
    const start=before.toString().length;selected(start,start+range.toString().length);
  });
  $('#find-selection').addEventListener('click',()=>{
    const quote=$('#find-quote').value,text=reader?.text||'';
    if(!quote.trim()){msg('Enter an exact quote to find.');return;}
    const start=text.indexOf(quote);if(start<0){msg('That quote is not present in this revision.');return;}
    if(text.indexOf(quote,start+1)>=0){msg('That quote appears more than once. Enter a longer unique quote or select the exact occurrence in the Reader.');return;}
    selected(start,start+quote.length);
  });
  function paint(){
    const pre=$('#reading-text pre');if(!pre||!reader?.text)return;
    const bytes=encoder.encode(reader.text),fragments=[],anchors=items.filter(i=>i.revision_id===reader.revisionId&&i.anchor_state==='resolved').sort((a,b)=>a.start_byte-b.start_byte);
    let offset=0;for(const item of anchors){if(item.start_byte<offset)continue;fragments.push(document.createTextNode(decoder.decode(bytes.slice(offset,item.start_byte))));const mark=el('mark',item.quote);mark.id=`highlight-${item.id}`;mark.dataset.evidence=item.id;mark.title=item.note;fragments.push(mark);offset=item.end_byte;}
    fragments.push(document.createTextNode(decoder.decode(bytes.slice(offset))));pre.replaceChildren(...fragments);
  }
  function cards(target,list){
    target.replaceChildren();if(!list.length){target.append(el('p','No evidence yet. Capture a quote in the Reader to start.'));return;}
    for(const item of list){
      const card=el('article');card.className='card evidence-card';card.dataset.evidence=item.id;
      card.append(el('h3',item.source_title),el('p',`Pinned to revision ${item.revision}${item.anchor_state==='unresolved'?' · Unresolved anchor':reader&&reader.revisionId!==item.revision_id?' · Earlier revision':''}`),el('blockquote',item.quote),el('p',item.note||'No note yet.'));
      const actions=el('div');actions.className='evidence-actions';
      const open=el('a','Open pinned revision');open.href=`/studio/hub/sources/${item.source_id}?revision=${item.revision_id}#highlight-${item.id}`;actions.append(open);
      if(reader?.revisionId===item.revision_id&&item.anchor_state==='resolved')actions.append(button('Show highlight',()=>{if(window.brightShowFormattedEvidence?.(item))return;const mark=document.getElementById(`highlight-${item.id}`);if(mark){mark.scrollIntoView({block:'center'});mark.tabIndex=-1;mark.focus();}else msg('This highlight overlaps another. Its quote and exact location are retained.');}));
      actions.append(button('Edit note',()=>{
        editItem=item;selection=undefined;saveKey=crypto.randomUUID();savePayload=undefined;
        $('#selected-quote').textContent=item.quote;$('#evidence-note').value=item.note;$('#evidence-dialog-title').textContent=`Edit note · Version ${item.version}`;$('#evidence-save').textContent='Save note';$('#evidence-form-status').replaceChildren();$('#evidence-dialog').showModal();$('#evidence-note').focus();
      }));
      const audit=el('div');audit.hidden=true;actions.append(button('Note history',async()=>{
        if(!audit.hidden){audit.hidden=true;return;}audit.hidden=false;audit.textContent='Loading history…';
        try{const history=await api(`/studio/api/hub/evidence/${item.id}/notes`);audit.replaceChildren(...history.map(n=>el('p',`Version ${n.version}: ${n.note||'(empty note)'}`)));}catch(error){audit.textContent=error.message;}
      }));
      actions.append(button('Link to board',()=>linkPicker(card,item)));card.append(actions,audit);target.append(card);
    }
  }
  async function loadEvidence(){
    const current=reader,version=++generation;msg('Loading evidence…');$('#evidence-list').replaceChildren();
    try{const list=await api(`/studio/api/hub/evidence?source_id=${current.sourceId}`);if(version!==generation)return;items=list;document.dispatchEvent(new CustomEvent('bright-evidence-items',{detail:items}));cards($('#evidence-list'),items);paint();msg(items.length?`${items.length} pinned evidence items. Quotes stay attached to their original revision.`:'No evidence saved yet.');
      const mark=location.hash.startsWith('#highlight-')?document.getElementById(location.hash.slice(1)):null;if(mark)mark.scrollIntoView({block:'center'});
    }catch(error){if(version===generation)msg(error.message);}
  }
  $('#evidence-cancel').addEventListener('click',()=>$('#evidence-dialog').close());
  $('#evidence-dialog').addEventListener('cancel',event=>{if($('#evidence-save').disabled)event.preventDefault();});
  $('#evidence-form').addEventListener('submit',async event=>{
    event.preventDefault();const note=$('#evidence-note').value,data=editItem?{note,expected_version:editItem.version}:{...selection,note};
    const payload=JSON.stringify(data);if(savePayload!==undefined&&savePayload!==payload)saveKey=crypto.randomUUID();savePayload=payload;
    $('#evidence-save').disabled=true;$('#evidence-cancel').disabled=true;$('#evidence-form-status').textContent='Saving…';
    try{await post(editItem?`/studio/api/hub/evidence/${editItem.id}/notes`:'/studio/api/hub/evidence',data,saveKey);$('#evidence-dialog').close();if(isBoards)await openBoard(new URLSearchParams(location.search).get('board'));else {await loadEvidence();document.dispatchEvent(new CustomEvent('bright-evidence-saved'));}}
    catch(error){$('#evidence-form-status').textContent=error.message;if(error.status===409&&editItem){$('#evidence-form-status').append(button('Reload latest note',async()=>{
      try{const latest=await api(`/studio/api/hub/evidence/${editItem.id}`);editItem=latest;saveKey=crypto.randomUUID();savePayload=undefined;
        $('#evidence-form-status').replaceChildren(el('p',`Latest version ${latest.version}: ${latest.note||'(empty note)'}`),el('p','Your draft is still in the field. Review it before saving against this version.'));$('#evidence-dialog-title').textContent=`Edit note · Version ${latest.version}`;
      }catch(failure){$('#evidence-form-status').textContent=failure.message;}
    }));}}
    finally{$('#evidence-save').disabled=false;$('#evidence-cancel').disabled=false;}
  });
  async function linkPicker(card,item){
    const existing=card.querySelector('.board-picker');if(existing){existing.remove();return;}
    const picker=el('div');picker.className='board-picker';const label=el('label','Project'),project=el('select');project.setAttribute('aria-label','Board project');
    for(const p of projects){const option=el('option',p.title);option.value=p.id;project.append(option);}project.value=$('#project').value;label.append(project);
    const boardLabel=el('label','Board'),board=el('select');board.setAttribute('aria-label','Destination board');boardLabel.append(board);const state=el('p');state.setAttribute('role','status');
    let version=0;async function refresh(){const current=++version;board.replaceChildren();save.disabled=true;state.textContent='Loading boards…';try{const list=await api(`/studio/api/hub/boards?project_id=${project.value}`);if(current!==version)return;for(const b of list){const option=el('option',b.title);option.value=b.id;board.append(option);}state.textContent=list.length?'':'No boards in this project. Create one on the Evidence page.';save.disabled=!list.length;}catch(error){state.textContent=error.message;}}
    const save=button('Save board link',async()=>{save.disabled=true;try{await post(`/studio/api/hub/boards/${board.value}/links`,{evidence_id:item.id});state.textContent='Linked. Original source and revision are preserved.';}catch(error){state.textContent=error.message;}finally{save.disabled=false;}});
    project.addEventListener('change',refresh);picker.append(label,boardLabel,save,state);card.append(picker);await refresh();
  }
  async function openBoard(id){
    if(!id)return;$('#board-detail').hidden=false;$('#board-items').textContent='Loading evidence…';
    try{const board=await api(`/studio/api/hub/boards/${id}`);if(board.project_id!==$('#project').value){$('#board-items').textContent='Select this board’s project to open it.';return;}$('#board-heading').textContent=board.title;cards($('#board-items'),board.items);}catch(error){$('#board-items').textContent=error.message;}
  }
  let boardsVersion=0;
  async function loadBoards(){
    const version=++boardsVersion;$('#board-status').textContent='Loading boards…';$('#board-list').replaceChildren();$('#board-detail').hidden=true;
    try{const boards=await api(`/studio/api/hub/boards?project_id=${$('#project').value}`);if(version!==boardsVersion)return;
      for(const board of boards){const card=el('article');card.className='card';const link=el('a',board.title);link.href=`?board=${board.id}`;card.append(link);$('#board-list').append(card);}
      $('#board-status').textContent=boards.length?`${boards.length} project boards.`:'No boards yet. Create one to collect evidence.';
      const id=new URLSearchParams(location.search).get('board');if(id)await openBoard(id);
    }catch(error){if(version===boardsVersion)$('#board-status').textContent=error.message;}
  }
  $('#board-form').addEventListener('submit',async event=>{event.preventDefault();const data={project_id:$('#project').value,title:$('#board-title').value},payload=JSON.stringify(data);if(boardPayload!==payload)boardKey=crypto.randomUUID();boardPayload=payload;const save=event.currentTarget.querySelector('button');save.disabled=true;
    try{const board=await post('/studio/api/hub/boards',data,boardKey);$('#board-form').reset();boardPayload=undefined;history.replaceState(null,'',`?board=${board.id}`);await loadBoards();}catch(error){$('#board-status').textContent=error.message;}finally{save.disabled=false;}});
  $('#project').addEventListener('change',()=>{if(isBoards){history.replaceState(null,'',location.pathname);loadBoards();}});
  document.addEventListener('bright-session',event=>{if(!event.detail.enabled)return;csrf=event.detail.csrf;projects=event.detail.projects;$('#evidence-nav').hidden=false;if(isBoards)setTimeout(loadBoards,0);});
  document.addEventListener('bright-reader',event=>{reader=event.detail;$('#evidence-panel').hidden=false;const ready=reader.state==='ready'&&reader.text!==null;$('#capture-selection').disabled=!ready;$('#find-selection').disabled=!ready;
    if(ready)loadEvidence();else{++generation;$('#evidence-list').replaceChildren();msg('Evidence capture is available when this revision is ready to read.');}
  });
})();
