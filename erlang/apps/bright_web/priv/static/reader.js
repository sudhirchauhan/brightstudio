/* Formatted originals remain a view of an owned immutable revision. */
(() => {
  const $=s=>document.querySelector(s),root=$('#formatted-reader');if(!root)return;
  let current,epoch=0,renderEpoch=0,pdfTask,pdf,chapters,index=0,annotations=[],renderTask,textTask,controller,loading,highlightRanges=new Map();
  const allowed=new Set('p div span h1 h2 h3 h4 h5 h6 em strong b i blockquote ul ol li table thead tbody tr td th pre code br hr sup sub'.split(' '));
  const status=t=>{$('#format-status').textContent=t;};
  function normalize(text){let value='',positions=[];for(let i=0;i<text.length;i++){const c=text[i];if(/\s/u.test(c)){if(value&&!value.endsWith(' ')){value+=' ';positions.push(i);}}else {value+=c;positions.push(i);}}return {value,positions};}
  function canonicalQuote(quote){
    if(!current?.text)return null;const q=normalize(quote.trim()).value.trim(),n=normalize(current.text);
    if(!q)return null;const start=n.value.indexOf(q);if(start<0||n.value.indexOf(q,start+1)>=0)return null;
    return {start:n.positions[start],end:n.positions[start+q.length-1]+1};
  }
  function textMap(){
    const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT),nodes=[];let n,text='';
    while((n=walker.nextNode())){nodes.push({node:n,start:text.length});text+=n.textContent;}
    return {text,nodes};
  }
  function paint(){
    highlightRanges.clear();CSS.highlights?.delete('reader-evidence');if(!CSS.highlights||!window.Highlight||root.hidden)return;
    const map=textMap(),normalized=normalize(map.text),ranges=[];
    for(const item of annotations){
      if(item.revision_id!==current?.revisionId||item.anchor_state!=='resolved')continue;
      const q=normalize(item.quote).value.trim(),i=normalized.value.indexOf(q);
      if(!q||i<0||normalized.value.indexOf(q,i+1)>=0)continue;
      const a=normalized.positions[i],b=normalized.positions[i+q.length-1]+1;
      const first=map.nodes.find(n=>a>=n.start&&a<n.start+n.node.length),last=map.nodes.find(n=>b>n.start&&b<=n.start+n.node.length);
      if(!first||!last)continue;const range=document.createRange();range.setStart(first.node,a-first.start);range.setEnd(last.node,b-last.start);ranges.push(range);highlightRanges.set(item.id,range);
    }
    CSS.highlights.set('reader-evidence',new Highlight(...ranges));
  }
  function element(node){
    if(typeof node.text==='string')return document.createTextNode(node.text);
    if(node.tag==='img'&&['image/png','image/jpeg'].includes(node.mime)&&/^[A-Za-z0-9+/=]+$/.test(node.data||'')){
      const img=document.createElement('img');img.alt=node.alt||'Book illustration';img.src=`data:${node.mime};base64,${node.data}`;return img;
    }
    const el=document.createElement(allowed.has(node.tag)?node.tag:'span');for(const child of node.children||[])el.append(element(child));return el;
  }
  async function load(){if(!loading)loading=loadInner().catch(error=>{loading=undefined;throw error;});return loading;}
  async function loadInner(){
    const version=epoch,context=current;if(pdf||chapters)return;
    if(context.mime==='application/pdf'){
      const lib=await import('/studio/hub/pdfjs/pdf.mjs');if(version!==epoch)return;
      lib.GlobalWorkerOptions.workerSrc='/studio/hub/pdfjs/pdf.worker.mjs';
      // Fetch through the existing private endpoint; no public blob or credentials in URLs.
      const response=await fetch(`/studio/api/hub/sources/${context.sourceId}/revisions/${context.revisionId}/original`,{cache:'no-store',signal:controller.signal});
      if(!response.ok)throw Error('The private original is unavailable. Sign in again or return to Library.');
      const bytes=await response.arrayBuffer();if(version!==epoch)return;
      pdfTask=lib.getDocument({data:bytes,isEvalSupported:false,disableAutoFetch:true,stopAtErrors:true,maxImageSize:16777216,cMapUrl:'/studio/hub/pdfjs/cmaps/',cMapPacked:true,standardFontDataUrl:'/studio/hub/pdfjs/standard_fonts/',useSystemFonts:true});
      const document=await pdfTask.promise;if(version!==epoch){await document.destroy();return;}pdf=document;
      if(pdf.numPages>200){await pdf.destroy();pdf=undefined;throw Error('Formatted PDF viewing is limited to 200 pages. Download the original to read a larger document.');}
    }else{
      const response=await fetch(`/studio/api/hub/sources/${context.sourceId}/revisions/${context.revisionId}/book`,{cache:'no-store',signal:controller.signal});
      if(!response.ok)throw Error('This EPUB could not be opened safely. Use the text view or download the original.');
      const data=await response.json();if(version!==epoch)return;chapters=data;
    }
    if(version!==epoch)return;
    const count=pdf?pdf.numPages:chapters.length;
    $('#format-location').replaceChildren(...Array.from({length:count},(_,i)=>{const o=document.createElement('option');o.value=i;o.textContent=pdf?`Page ${i+1}`:`Chapter ${i+1}`;return o;}));
  }
  async function render(){
    if(!current||$('#reader-view').value!=='formatted')return;
    const version=epoch,draw=++renderEpoch;renderTask?.cancel();textTask?.cancel();status('Opening formatted original…');
    $('#format-prev').disabled=true;$('#format-next').disabled=true;
    try{
      await load();if(version!==epoch||draw!==renderEpoch)return;
      root.replaceChildren();$('#format-location').value=index;
      const count=pdf?pdf.numPages:chapters.length;
      if(pdf){
        const lib=await import('/studio/hub/pdfjs/pdf.mjs'),page=await pdf.getPage(index+1);if(version!==epoch||draw!==renderEpoch)return;
        const base=page.getViewport({scale:1}),fit=Math.min(1.6,Math.max(200,root.clientWidth-8)/base.width),scale=fit*Number($('#format-zoom').value),viewport=page.getViewport({scale});
        if(viewport.width>8192||viewport.height>8192||viewport.width*viewport.height>8388608)throw Error('This page exceeds the rendering size limit. Reduce zoom or use text view.');
        const box=document.createElement('div');box.className='pdf-page';box.style.width=`${viewport.width}px`;box.style.height=`${viewport.height}px`;box.style.setProperty('--scale-factor',scale);
        const canvas=document.createElement('canvas'),ratio=Math.min(window.devicePixelRatio||1,2);canvas.width=Math.ceil(viewport.width*ratio);canvas.height=Math.ceil(viewport.height*ratio);canvas.style.width=`${viewport.width}px`;canvas.style.height=`${viewport.height}px`;canvas.setAttribute('aria-label',`Original PDF page ${index+1}`);
        const layer=document.createElement('div');layer.className='textLayer';box.append(canvas,layer);root.append(box);
        renderTask=page.render({canvasContext:canvas.getContext('2d'),viewport,transform:ratio===1?null:[ratio,0,0,ratio,0,0]});await renderTask.promise;
        if(version!==epoch||draw!==renderEpoch)return;
        const content=await page.getTextContent();if(version!==epoch||draw!==renderEpoch)return;
        textTask=new lib.TextLayer({textContentSource:content,container:layer,viewport});await textTask.render();
        if(version!==epoch||draw!==renderEpoch)return;
        status(content.items.some(i=>i.str?.trim())?`Page ${index+1} of ${count}. Select text to annotate.`:`Page ${index+1} of ${count}. Scanned page: select OCR text in Text and annotations view.`);
      }else{
        const article=document.createElement('article');article.className='epub-chapter';article.setAttribute('aria-label',`EPUB chapter ${index+1}`);for(const node of chapters[index].nodes)article.append(element(node));root.append(article);status(`Chapter ${index+1} of ${count}. Publisher scripts, external resources and styles are excluded.`);
      }
      if(version!==epoch||draw!==renderEpoch)return;
      $('#format-prev').disabled=index===0;$('#format-next').disabled=index===count-1;paint();
    }catch(error){if(version!==epoch||draw!==renderEpoch||error.name==='RenderingCancelledException'||error.name==='AbortError')return;status(error.message+' Text view and private download remain available.');root.replaceChildren();}
  }
  function view(){const formatted=$('#reader-view').value==='formatted';root.hidden=!formatted;$('#reading-text').hidden=formatted;$('#format-status').hidden=!formatted;for(const id of ['format-prev','format-next','format-location-label'])$('#'+id).hidden=!formatted;$('#format-zoom-label').hidden=!formatted||current?.mime!=='application/pdf';if(formatted)render();else CSS.highlights?.delete('reader-evidence');}
  $('#reader-view').addEventListener('change',view);
  $('#format-location').addEventListener('change',()=>{index=Number($('#format-location').value);render();});
  $('#format-prev').addEventListener('click',()=>{index=Math.max(0,index-1);render();});
  $('#format-next').addEventListener('click',()=>{index=Math.min((pdf?.numPages||chapters?.length||1)-1,index+1);render();});
  $('#format-zoom').addEventListener('change',render);
  document.addEventListener('bright-reader',event=>{
    const next=event.detail,same=current?.revisionId===next.revisionId;
    current=next;if(same)return;
    epoch++;renderEpoch++;controller?.abort();controller=new AbortController();renderTask?.cancel();textTask?.cancel();pdfTask?.destroy().catch(()=>{});pdfTask=undefined;loading=undefined;pdf=undefined;chapters=undefined;annotations=[];index=0;root.replaceChildren();CSS.highlights?.delete('reader-evidence');
    const supported=['application/pdf','application/epub+zip'].includes(current.mime);$('#format-controls').hidden=!supported;$('#reader-view').value='text';$('#format-zoom').value='1';view();
  });
  document.addEventListener('bright-evidence-items',event=>{annotations=event.detail;paint();});
  window.brightShowFormattedEvidence=item=>{
    if(root.hidden)return false;
    const range=highlightRanges.get(item.id);
    if(range){range.startContainer.parentElement.scrollIntoView({block:'center'});return true;}
    $('#reader-view').value='text';view();return false;
  };
  window.brightFormattedSelection=()=>{
    if(root.hidden)return null;const selection=window.getSelection();if(!selection?.rangeCount||selection.isCollapsed)return {error:'Select text in the formatted page first.'};
    const range=selection.getRangeAt(0);if(!root.contains(range.startContainer)||!root.contains(range.endContainer))return {error:'Select within this page or chapter only.'};
    const match=canonicalQuote(selection.toString());return match||{error:'This selection cannot be matched uniquely to the saved revision text. Use Text and annotations to capture the exact passage.'};
  };
})();
