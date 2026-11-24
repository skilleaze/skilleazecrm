(function(){ if (window.__skzDemo) return; window.__skzDemo=1;
 // Preview never talks to the live database.
 function cut(){ try { if (window.SKZLive) { window.SKZLive.on = function(){ return false; }; window.SKZLive.sb = function(){ throw new Error('Preview: not connected'); }; } } catch(e){} }
 cut(); setInterval(cut, 300);
 try{localStorage.setItem('skz-alerts-nudge',String(Date.now()+864e9));}catch(e){}
 var R=[['muneez','Management'],['dhiya','Head of ops'],['ishfa','Ops manager'],['alpha','Sales agent'],['shafeeda','CV expert'],['akshara','LinkedIn expert'],['muhammed.munavvir','Puttur manager'],['aisha.rahman','Consultant']];
 function btn(t){return [...document.querySelectorAll('button')].find(b=>b.innerText.trim()===t);}
 function setV(el,v){var p=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set;p.call(el,v);el.dispatchEvent(new Event('input',{bubbles:true}));}
 function fill(u){var ins=[...document.querySelectorAll('input')].filter(i=>i.type==='text'||i.type==='password'||!i.type);var pw=document.querySelector('input[type=password]');if(!pw)return false;var us=ins.find(i=>i!==pw);setV(us,u);setV(pw,'skilleaze');setTimeout(function(){var b=btn('Sign in');if(b)b.click();},80);return true;}
 function as(u){if(fill(u))return;var lo=btn('Log out');if(lo)lo.click();var n=0,t=setInterval(function(){if(fill(u)||++n>40)clearInterval(t);},150);}
 function mount(){ if(document.getElementById('skzDemoBar')||!document.body)return;
  var d=document.createElement('div');d.id='skzDemoBar';
  d.style.cssText='position:fixed;left:50%;bottom:12px;transform:translateX(-50%);z-index:2147483647;background:#111827;color:#fff;border-radius:14px;padding:8px 10px;display:flex;gap:6px;align-items:center;flex-wrap:wrap;justify-content:center;max-width:calc(100vw - 24px);box-shadow:0 6px 24px rgba(0,0,0,.25);font:600 12px -apple-system,BlinkMacSystemFont,Segoe UI,sans-serif';
  var l=document.createElement('span');l.textContent='Preview · sample data · view as:';l.style.cssText='opacity:.75;margin:0 4px';d.appendChild(l);
  R.forEach(function(r){var b=document.createElement('button');b.textContent=r[1];b.style.cssText='background:#fff;color:#042d7c;border:0;border-radius:999px;padding:5px 10px;font:600 12px inherit;cursor:pointer';b.onclick=function(){as(r[0]);};d.appendChild(b);});
  var x=document.createElement('button');x.textContent='×';x.title='Hide';x.style.cssText='background:transparent;color:#fff;border:0;font-size:16px;cursor:pointer;padding:0 4px';x.onclick=function(){d.remove();};d.appendChild(x);
  document.body.appendChild(d);}
 function hush(){ if(![...document.querySelectorAll('h1,h2,h3,div,span')].some(e=>e.childElementCount===0&&e.textContent.trim()==='Complete your HR details'))return; var b=btn('Later'); if(b)b.click(); }
 setInterval(function(){mount();hush();},700);
})();
