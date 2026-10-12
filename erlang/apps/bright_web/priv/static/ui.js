'use strict';
(() => {
  const $ = s => document.querySelector(s);
  let focused = false, beforeFullscreen = false, fullscreenPending = false, lessonOpen = false;
  const mobile = matchMedia('(max-width:720px)');
  const notice = document.createElement('p');
  notice.id = 'mode-status'; notice.setAttribute('role','status'); notice.setAttribute('aria-live','polite');
  $('#main').prepend(notice);
  function render() {
    document.body.classList.toggle('focused',focused);
    for (const [id,mode] of [['reading-mode','reading'],['study-mode','study']]) {
      $( '#'+id).textContent = focused ? `Exit ${mode} mode` : `${mode[0].toUpperCase()+mode.slice(1)} mode`;
      $( '#'+id).setAttribute('aria-pressed',String(focused));
    }
    for (const id of ['reader-fullscreen','study-fullscreen']) {
      $( '#'+id).textContent = document.fullscreenElement ? 'Exit fullscreen · Esc' : 'Full screen';
      $( '#'+id).setAttribute('aria-pressed',String(Boolean(document.fullscreenElement)));
    }
  }
  function menu(open,returnFocus=true) {
    document.body.classList.toggle('menu-open',open);
    $('#navigation-open').setAttribute('aria-expanded',String(open));
    $('.content').inert = open;
    if(open) $('#navigation-close').focus();
    else if(returnFocus && mobile.matches) $('#navigation-open').focus();
  }
  $('#navigation-open').addEventListener('click',()=>menu(true));
  $('#navigation-close').addEventListener('click',()=>menu(false));
  mobile.addEventListener('change',()=>menu(false,false));
  function notes(open,focus=true) {
    $('#evidence-panel').toggleAttribute('data-open',open);
    $('#notes-open').setAttribute('aria-expanded',String(open));
    if(focus) (open ? $('#notes-close') : $('#notes-open')).focus();
  }
  $('#notes-open').addEventListener('click',()=>notes(true));
  $('#notes-close').addEventListener('click',()=>notes(false));
  document.addEventListener('bright-evidence-saved',()=>notes(true,false));
  document.addEventListener('bright-reader',()=>notes(false,false));
  document.addEventListener('bright-session',e=>{
    $('#capture-selection').hidden=!e.detail.enabled;
    $('#notes-open').hidden=!e.detail.enabled;
  });
  async function toggleMode() {
    if(fullscreenPending) return;
    const next=!focused;
    if(document.fullscreenElement) await document.exitFullscreen();
    focused=next; notice.textContent=''; render();
  }
  for(const id of ['reading-mode','study-mode']) $( '#'+id).addEventListener('click',toggleMode);
  async function fullscreen() {
    if(fullscreenPending)return;
    if(document.fullscreenElement){await document.exitFullscreen();return;}
    beforeFullscreen=focused; focused=true; notice.textContent=''; render();
    fullscreenPending=true;
    try {
      if(!document.documentElement.requestFullscreen) throw Error('unsupported');
      await document.documentElement.requestFullscreen();
    } catch {
      notice.textContent='Browser fullscreen is unavailable here. Distraction-free mode is still available.';
    } finally { fullscreenPending=false; render(); }
  }
  for(const id of ['reader-fullscreen','study-fullscreen']) $( '#'+id).addEventListener('click',fullscreen);
  document.addEventListener('fullscreenchange',()=>{
    if(!document.fullscreenElement) focused=beforeFullscreen;
    render();
  });
  document.addEventListener('bright-lesson',async e=>{
    const wasOpen=lessonOpen; lessonOpen=e.detail.open;
    document.body.classList.toggle('lesson-open',lessonOpen);
    if(!lessonOpen){if(document.fullscreenElement)await document.exitFullscreen();focused=false;}
    else if(!wasOpen){focused=true;menu(false,false);}
    render();
  });
  document.addEventListener('keydown',e=>{
    if(e.key==='Escape') {
      if(document.querySelector('dialog[open]'))return;
      if(document.body.classList.contains('menu-open')){menu(false);return;}
      if($('#evidence-panel').hasAttribute('data-open')){notes(false);return;}
      if(document.fullscreenElement){document.exitFullscreen();return;}
      if(!document.fullscreenElement && focused){focused=false;notice.textContent='';render();}
    }
    if(e.key==='Tab' && document.body.classList.contains('menu-open')) {
      const controls=[...$('#navigation').querySelectorAll('a,button')].filter(el=>el.getClientRects().length);
      const first=controls[0],last=controls.at(-1);
      if(e.shiftKey && document.activeElement===first){e.preventDefault();last.focus();}
      else if(!e.shiftKey && document.activeElement===last){e.preventDefault();first.focus();}
    }
  });
  // Options remain discoverable while ordinary reading stays uncluttered.
  if(new URLSearchParams(location.search).has('revision')) $('#reader-tools').open=true;
  render();
})();
