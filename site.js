(function(){
  /* --- photos: embedded once, assigned here --- */
  document.querySelectorAll('img[data-photo]').forEach(function(im){im.src=PHOTOS[im.getAttribute('data-photo')]||'';});

  /* --- live content from Supabase (optional): events deck, photo slots, gallery, forms ---
     If config.js is empty or the request fails, the baked-in content above is what shows. */
  var CFG=window.KC_CONFIG||{},DB=!!(CFG.SUPABASE_URL&&CFG.SUPABASE_ANON_KEY);
  function dbHeaders(extra){var h={'apikey':CFG.SUPABASE_ANON_KEY};if(extra)for(var k in extra)h[k]=extra[k];return h;}
  function dbGet(path){return fetch(CFG.SUPABASE_URL+'/rest/v1/'+path,{headers:dbHeaders()}).then(function(r){if(!r.ok)throw new Error(r.status);return r.json();});}
  function dbInsert(table,rec){return fetch(CFG.SUPABASE_URL+'/rest/v1/'+table,{method:'POST',headers:dbHeaders({'Content-Type':'application/json','Prefer':'return=minimal'}),body:JSON.stringify(rec)}).then(function(r){if(!r.ok)throw new Error(r.status);});}
  function absUrl(u){return u&&u.charAt(0)==='/'?u.slice(1):u;}

  var burger=document.getElementById('burger'),mnav=document.getElementById('mnav');
  function closeMenu(){mnav.classList.remove('open');burger.classList.remove('x');document.body.classList.remove('lock');burger.setAttribute('aria-expanded','false');}
  burger.addEventListener('click',function(){
    var open=mnav.classList.toggle('open');
    burger.classList.toggle('x',open);
    document.body.classList.toggle('lock',open);
    burger.setAttribute('aria-expanded',open?'true':'false');
  });
  mnav.querySelectorAll('a').forEach(function(a){a.addEventListener('click',closeMenu);});
  window.addEventListener('resize',function(){if(window.innerWidth>900)closeMenu();});
  document.addEventListener('keydown',function(e){if(e.key==='Escape')closeMenu();});

  var reduce=window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* --- events we host: deck + modal --- */
  var EVENTS=[{"id": "kids", "tag": "School holidays", "title": "Kids' parties", "teaser": "Space to run, pitches to play on, a clubhouse for cake and a braai for the grown-ups.", "desc": "Space to run, pitches to play on, a clubhouse for cake and a braai for the grown-ups. Bring an entertainer or a bouncy castle, or ask us about a rugby or touch session for the kids. It's ideal for school-holiday birthdays.", "photo": "fundaycard"}, {"id": "birthday", "tag": "30th to 70th", "title": "Milestone birthdays", "teaser": "We've celebrated 30ths, 40ths, 50ths and 60ths.", "desc": "We've celebrated 30ths, 40ths, 50ths and 60ths. This summer we're hosting a 70th with a brass band. Use the clubhouse and bar, or go big with a marquee and a stage.", "photo": "oktoberfest"}, {"id": "bbq", "tag": "Outdoor kitchen", "title": "BBQs and cook-outs", "teaser": "Our outdoor kitchen and braai pits make it easy.", "desc": "Our outdoor kitchen and braai pits make it easy. Fire them up for a family day, a team social or an end-of-term party. Bring your own food or your own caterer.", "photo": "hero1"}, {"id": "dinner", "tag": "Marquee", "title": "Formal dinners", "teaser": "We've hosted black-tie dinners in a marquee on the grounds, with seating for up to 150 guests from May to August.", "desc": "We've hosted black-tie dinners in a marquee on the grounds, with seating for up to 150 guests from May to August.", "photo": "marqueedinner"}, {"id": "wedding", "tag": "Three a year", "title": "Wedding celebrations", "teaser": "Say “I do” wherever you like, then bring everyone back to ours.", "desc": "Say “I do” wherever you like, then bring everyone back to ours. Hold a marquee on the grounds, a braai feast, speeches on the balcony and dancing in the bar. We host just three weddings a year and the dates go fast, so get in touch at least six months ahead.", "photo": "hero3"}, {"id": "other", "tag": "Stage & balcony", "title": "Live music and DJs", "teaser": "Bands on an outdoor stage and DJs on the balcony.", "desc": "Bands on an outdoor stage and DJs on the balcony. We've done it and it works.", "photo": "marqueeparty"}, {"id": "tournament", "tag": "Pitches", "title": "Tournaments and festivals", "teaser": "In July 2025 the Junior Touch Cup brought more than 300 kids to the club, with a barbecue running all day.", "desc": "In July 2025 the Junior Touch Cup brought more than 300 kids to the club, with a barbecue running all day. We've hosted mini rugby festivals with over 100 teams, plus 7s competitions. Six changing rooms and plenty of grass make it straightforward.", "photo": "floodlit"}, {"id": "community", "tag": "Community", "title": "Community days and outdoor cinema", "teaser": "Our three outdoor cinema days brought the whole neighbourhood out.", "desc": "Our three outdoor cinema days brought the whole neighbourhood out. Planning a fundraiser, fete or summer screening? Talk to us.", "photo": "cinema"}, {"id": "community", "tag": "Big matches", "title": "Watch parties and international nights", "teaser": "Our South African series nights round the braai are a club favourite.", "desc": "Our South African series nights round the braai are a club favourite. They're great for big matches and cultural celebrations.", "photo": "watchparty"}, {"id": "corporate", "tag": "Team days", "title": "Corporate and team days", "teaser": "Team BBQs, sports days and summer socials, with a bar, open grass and parking for around 100 cars.", "desc": "Team BBQs, sports days and summer socials, with a bar, open grass and parking for around 100 cars.", "photo": "pitches"}];
  function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
  function evPhoto(e){return e.photoUrl||PHOTOS[e.photo]||'';}
  function evCard(e,dup){
    return '<div class="ev'+(dup?' dup':'')+'"'+(dup?' aria-hidden="true"':'')+' data-ev="'+esc(e.id)+'" data-i="'+EVENTS.indexOf(e)+'" tabindex="'+(dup?'-1':'0')+'" role="button" aria-label="'+esc(e.title)+' — more info">'
      +'<div class="ph"><img '+(dup?'aria-hidden="true" ':'')+'decoding="async" src="'+esc(evPhoto(e))+'" alt=""></div>'
      +'<div class="body"><div class="tag">'+esc(e.tag)+'</div><h3>'+esc(e.title)+'</h3><p>'+esc(e.teaser)+'</p>'
      +'<div class="evbtns"><span class="btn glassy">More info</span><span class="btn sage" data-plan>Plan something like this</span></div></div></div>';
  }
  var track=document.getElementById('deckTrack');
  function renderDeck(){track.innerHTML=EVENTS.map(function(e){return evCard(e,false);}).join('')+EVENTS.map(function(e){return evCard(e,true);}).join('');}
  renderDeck();
  var modal=document.getElementById('evmodal'),form=document.getElementById('enquiryForm'),wrap=document.getElementById('enqWrap');
  function preselect(ev,sp){
    if(ev){var sel=form.querySelector('select[name=event_type]');if(sel&&sel.querySelector('option[value="'+ev+'"]'))sel.value=ev;}
    if(sp){var box=form.querySelector('input[name=spaces][value="'+sp+'"]');if(box){box.checked=true;var more=document.getElementById('enqMore');if(more)more.open=true;}}
  }
  function openEv(i){
    var e=EVENTS[i]; if(!e)return;
    var evmIm=document.getElementById('evmImg');
    evmIm.classList.remove('ld');evmIm.src=evPhoto(e);
    if(evmIm.complete&&evmIm.naturalWidth>0)evmIm.classList.add('ld');
    else evmIm.addEventListener('load',function(){evmIm.classList.add('ld');},{once:true});
    document.getElementById('evmTag').textContent=e.tag;
    document.getElementById('evmTitle').textContent=e.title;
    document.getElementById('evmMeta').innerHTML='';
    document.getElementById('evmDesc').textContent=e.desc;
    var cta=document.getElementById('evmEnquire');
    cta.setAttribute('data-event',e.id);cta.removeAttribute('data-space');cta.removeAttribute('target');cta.removeAttribute('rel');cta.setAttribute('href','#enquire');cta.textContent='Plan something like this';
    modal.classList.add('open');document.body.classList.add('lock');
  }
  function closeEv(){
    if(!modal.classList.contains('open')||modal.classList.contains('closing'))return;
    modal.classList.add('closing');
    setTimeout(function(){modal.classList.remove('open');modal.classList.remove('closing');document.body.classList.remove('lock');},reduce?0:300);
  }
  track.addEventListener('click',function(ev){
    var card=ev.target.closest('.ev'); if(!card)return;
    var i=parseInt(card.getAttribute('data-i'),10);
    if(ev.target.closest('[data-plan]')){preselect(EVENTS[i].id);document.getElementById('enquire').scrollIntoView({behavior:reduce?'auto':'smooth'});return;}
    openEv(i);
  });
  track.addEventListener('keydown',function(ev){
    if(ev.key==='Enter'||ev.key===' '){var card=ev.target.closest('.ev');if(card){ev.preventDefault();openEv(parseInt(card.getAttribute('data-i'),10));}}
  });
  modal.addEventListener('click',function(ev){
    if(ev.target.closest('[data-close]'))closeEv();
    var a=ev.target.closest('#evmEnquire');if(a){preselect(a.getAttribute('data-event'),a.getAttribute('data-space'));closeEv();}
  });
  document.addEventListener('keydown',function(ev){if(ev.key==='Escape'&&modal.classList.contains('open'))closeEv();});

  /* --- "Enquire about this space" pre-ticks the form --- */
  document.querySelectorAll('[data-space]').forEach(function(a){a.addEventListener('click',function(){preselect(null,a.getAttribute('data-space'));});});

  /* --- enquiry form --- */
  var date=form.querySelector('input[name=preferred_date]'),flex=form.querySelector('input[name=dates_flexible]');
  var t=new Date();date.min=t.getFullYear()+'-'+String(t.getMonth()+1).padStart(2,'0')+'-'+String(t.getDate()).padStart(2,'0');
  flex.addEventListener('change',function(){date.required=!flex.checked;});
  form.addEventListener('submit',function(e){
    e.preventDefault();
    var err=form.querySelector('.err');err.style.display='none';
    if(!form.checkValidity()){form.reportValidity();return;}
    var endpoint=form.getAttribute('data-endpoint');
    function done(){wrap.classList.add('sent');wrap.scrollIntoView({behavior:reduce?'auto':'smooth',block:'start'});}
    function fail(){btn.disabled=false;err.textContent='Sorry, that didn’t send. Please try again, or email info@kingsclubhouse.co.uk.';err.style.display='block';}
    var btn=form.querySelector('button[type=submit]');
    if(DB){
      btn.disabled=true;
      var fd=new FormData(form),num=function(v){v=parseInt(v,10);return isNaN(v)?null:v;},str=function(v){v=(v||'').trim();return v||null;};
      var rec={name:str(fd.get('name')),email:str(fd.get('email')),phone:str(fd.get('phone')),event_type:str(fd.get('event_type')),
        preferred_date:str(fd.get('preferred_date')),dates_flexible:!!fd.get('dates_flexible'),start_time:str(fd.get('start_time')),finish_time:str(fd.get('finish_time')),
        adults:num(fd.get('adults')),children:num(fd.get('children')),spaces:fd.getAll('spaces'),caterer:str(fd.get('caterer')),member:str(fd.get('member')),message:str(fd.get('message'))};
      dbInsert('enquiries',rec).then(done).catch(fail);return;
    }
    if(!endpoint){done();return;}
    btn.disabled=true;
    fetch(endpoint,{method:'POST',body:new FormData(form),headers:{'Accept':'application/json'}})
      .then(function(r){if(!r.ok)throw new Error(r.status);done();})
      .catch(fail);
  });

  /* --- community sign-up (preview: needs a mailing-list endpoint) --- */
  var commForm=document.getElementById('commForm');
  commForm.addEventListener('submit',function(ev){
    ev.preventDefault();
    if(!commForm.checkValidity()){commForm.reportValidity();return;}
    var wa=commForm.querySelector('[name=wa]').checked,news=commForm.querySelector('[name=news]').checked;
    function ok(){document.getElementById('waExtra').textContent=wa?' and your WhatsApp invite':'';document.getElementById('commWrap').classList.add('sent');}
    if(DB){
      var b=commForm.querySelector('button[type=submit]');b.disabled=true;
      dbInsert('signups',{name:commForm.querySelector('[name=name]').value.trim(),email:commForm.querySelector('[name=email]').value.trim(),mobile:(commForm.querySelector('[name=mobile]').value||'').trim()||null,news:news,whatsapp:wa})
        .then(ok).catch(function(){b.disabled=false;alert('Sorry, that didn’t go through. Please try again.');});
      return;
    }
    ok();
  });

  /* --- photo slider --- */
  var slides=document.querySelectorAll('#slides .slide'),sdots=document.getElementById('sdots'),sIdx=0,sTimer=null;
  if(slides.length){
    slides.forEach(function(_,i){var b=document.createElement('button');b.setAttribute('aria-label','Go to photo '+(i+1));if(i===0)b.className='on';b.addEventListener('click',function(){goSlide(i);restartAuto();});sdots.appendChild(b);});
    function goSlide(i){sIdx=(i+slides.length)%slides.length;slides.forEach(function(s,j){s.classList.toggle('on',j===sIdx);});sdots.querySelectorAll('button').forEach(function(b,j){b.classList.toggle('on',j===sIdx);});}
    function nextSlide(){goSlide(sIdx+1);}
    function startAuto(){if(!reduce)sTimer=setInterval(nextSlide,4500);}
    function restartAuto(){clearInterval(sTimer);startAuto();}
    document.getElementById('snext').addEventListener('click',function(){nextSlide();restartAuto();});
    document.getElementById('sprev').addEventListener('click',function(){goSlide(sIdx-1);restartAuto();});
    var slEl=document.getElementById('slider'),tx=null;
    slEl.addEventListener('mouseenter',function(){clearInterval(sTimer);});
    slEl.addEventListener('mouseleave',restartAuto);
    slEl.addEventListener('touchstart',function(e){tx=e.touches[0].clientX;clearInterval(sTimer);},{passive:true});
    slEl.addEventListener('touchend',function(e){if(tx===null)return;var dx=e.changedTouches[0].clientX-tx;if(Math.abs(dx)>40)(dx<0?nextSlide():goSlide(sIdx-1));tx=null;startAuto();},{passive:true});
    startAuto();
  }

  /* --- google reviews strip: placeholder cards until live reviews are connected --- */
  var GREV=[1,2,3].map(function(){return {n:'Google reviewer',c:'#6E7F5C',t:'Google review',txt:'Your live Google reviews will appear here once connected.'};});
  var GSM='<svg class="gsm" viewBox="0 0 48 48"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/><path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/></svg>';
  function grCard(r,dup){
    return '<div class="gr'+(dup?' dup':'')+'"'+(dup?' aria-hidden="true"':'')+'><div class="top"><span class="gav" style="background:'+r.c+'">G</span><div class="who"><b>'+r.n+'</b><span>'+r.t+'</span></div>'+GSM+'</div><div class="stars">★★★★★</div><p>'+r.txt+'</p></div>';
  }
  var grTrack=document.getElementById('grTrack');
  if(grTrack)grTrack.innerHTML=GREV.map(function(r){return grCard(r,false);}).join('')+GREV.map(function(r){return grCard(r,true);}).join('');

  /* --- smooth header: hide on scroll down, reveal on scroll up --- */
  var hdr=document.querySelector('header'),lastY=0,ticking=false;
  function onScroll(){
    var y=window.scrollY;
    hdr.classList.toggle('solid',y>8);
    if(!document.body.classList.contains('lock')){
      if(y>lastY&&y>340)hdr.classList.add('hide');
      else hdr.classList.remove('hide');
    }
    var tt=document.getElementById('totop');
    if(tt)tt.classList.toggle('show',y>900);
    var bar=document.querySelector('.ctabar'),heroEl=document.getElementById('top');
    if(bar&&heroEl)bar.classList.toggle('show',y>heroEl.offsetHeight-140);
    lastY=y;ticking=false;
  }
  onScroll();
  window.addEventListener('scroll',function(){if(!ticking){requestAnimationFrame(onScroll);ticking=true;}},{passive:true});

  /* --- back to top --- */
  var tt=document.createElement('button');
  tt.id='totop';tt.className='totop';tt.setAttribute('aria-label','Back to top');tt.innerHTML='↑';
  tt.addEventListener('click',function(){window.scrollTo({top:0,behavior:reduce?'auto':'smooth'});});
  document.body.appendChild(tt);

  /* --- scrollspy --- */
  var spyMap=['top','events','spaces','calendar','faq'];
  if('IntersectionObserver' in window){
    var spy=new IntersectionObserver(function(es){
      es.forEach(function(e){
        if(e.isIntersecting){
          document.querySelectorAll('.menu a').forEach(function(a){a.classList.toggle('cur',a.getAttribute('href')==='#'+e.target.id);});
        }
      });
    },{rootMargin:'-40% 0px -55% 0px'});
    spyMap.forEach(function(id){var el=document.getElementById(id);el&&spy.observe(el);});
  }

  /* --- fade images in as they load --- */
  function imgReady(img){img.classList.add('ld');}
  function watch(img){
    if(img.complete)imgReady(img);
    else{img.addEventListener('load',function(){imgReady(img);},{once:true});img.addEventListener('error',function(){imgReady(img);},{once:true});}
    if(img.decode&&img.src)img.decode().then(function(){imgReady(img);}).catch(function(){imgReady(img);});
  }
  document.querySelectorAll('img').forEach(watch);
  /* safety net: nothing stays invisible */
  setTimeout(function(){document.querySelectorAll('img').forEach(imgReady);},1500);
  new MutationObserver(function(muts){
    muts.forEach(function(m){m.addedNodes.forEach(function(n){if(n.querySelectorAll)n.querySelectorAll('img').forEach(watch);});});
  }).observe(document.body,{childList:true,subtree:true});

  /* --- scroll-reveal --- */
  if('IntersectionObserver' in window && !reduce){
    var io=new IntersectionObserver(function(es){
      es.forEach(function(e){if(e.isIntersecting){e.target.classList.add('inview');io.unobserve(e.target);}});
    },{threshold:.15,rootMargin:'0px 0px -40px 0px'});
    document.querySelectorAll('[data-reveal]').forEach(function(el){io.observe(el);});
  }else{
    document.querySelectorAll('[data-reveal]').forEach(function(el){el.classList.add('inview');});
  }

  /* --- hero stat count-up --- */
  function finalText(el){return el.getAttribute('data-count')+(el.getAttribute('data-suffix')||'');}
  if(!reduce){
    document.querySelectorAll('.vhero [data-count]').forEach(function(el){
      var target=parseInt(el.getAttribute('data-count'),10),suf=el.getAttribute('data-suffix')||'',dur=1400,start=null;
      function step(ts){
        if(!start)start=ts;
        var p=Math.min((ts-start)/dur,1),ease=1-Math.pow(1-p,3);
        el.textContent=Math.round(target*ease)+(p>=1?suf:'');
        if(p<1)requestAnimationFrame(step);
      }
      setTimeout(function(){requestAnimationFrame(step);},900);
    });
  }else{
    document.querySelectorAll('.vhero [data-count]').forEach(function(el){el.textContent=finalText(el);});
  }

  /* ===== mobile-first pass (Oct 2026) ===== */
  var phone=window.matchMedia('(max-width:760px)');

  /* --- photo gallery (phones) + lightbox --- */
  var GALLERY=[
    {p:'hero1',c:'A summer evening outside the clubhouse'},
    {p:'marqueeparty',c:'A live band in the marquee'},
    {p:'interior',c:'Inside the clubhouse'},
    {p:'cinema',c:'Outdoor cinema at sunset'},
    {p:'marqueedinner',c:'Summer dinner in the marquee'},
    {p:'floodlit',c:'Under the floodlights'},
    {p:'pitches',c:'Sunrise over the pitches from the balcony'},
    {p:'clubroom',c:'The clubhouse, set for a function'},
    {p:'funday',c:'A bouncy castle on the grass'},
    {p:'watchparty',c:'Big match on the big screen'},
    {p:'oktoberfest',c:'Oktoberfest night'},
    {p:'bigpitch',c:'Evening match on the big pitch'},
    {p:'hero3',c:'The view from the balcony'},
    {p:'hero2',c:'Spectators on the touchline'},
    {p:'fundaycard',c:'Family day on the grounds'},
    {p:'bar',c:'The bar'},
    {p:'seating',c:'Sofas and the trophy cabinet'},
    {p:'nightmatch',c:'A floodlit evening match'}
  ];
  var gal=document.getElementById('gallery');
  function gUrl(g){return g.url||PHOTOS[g.p]||'';}
  var galMore=document.getElementById('galMore');
  function galLabel(){if(galMore)galMore.textContent=gal&&gal.classList.contains('all')?'Show fewer photos':'See all '+GALLERY.length+' photos';}
  function renderGallery(){if(gal)gal.innerHTML=GALLERY.map(function(g,i){return '<button type="button" data-g="'+i+'" aria-label="Enlarge photo: '+esc(g.c)+'"><img src="'+esc(gUrl(g))+'" alt="'+esc(g.alt||g.c)+'" loading="'+(i<3?'eager':'lazy')+'" decoding="async"></button>';}).join('');galLabel();}
  renderGallery();
  if(galMore&&gal)galMore.addEventListener('click',function(){var o=gal.classList.toggle('all');galMore.setAttribute('aria-expanded',o?'true':'false');galLabel();if(!o)gal.scrollIntoView({behavior:reduce?'auto':'smooth',block:'start'});});
  var lb=document.getElementById('lb'),lbImg=document.getElementById('lbImg'),lbCap=document.getElementById('lbCap'),lbN=document.getElementById('lbN'),lbI=0,lbLast=null;
  function lbShow(i){
    lbI=(i+GALLERY.length)%GALLERY.length;var g=GALLERY[lbI];
    lbImg.src=gUrl(g);lbImg.alt=g.alt||g.c;lbCap.textContent=g.c;lbN.textContent=(lbI+1)+' / '+GALLERY.length;
  }
  function lbOpen(i){lbLast=document.activeElement;lbShow(i);lb.classList.add('open');document.body.classList.add('lock');document.querySelector('.lb-x').focus();}
  function lbClose(){lb.classList.remove('open');document.body.classList.remove('lock');if(lbLast&&lbLast.focus)lbLast.focus();}
  if(gal&&lb){
    gal.addEventListener('click',function(e){var b=e.target.closest('[data-g]');if(b)lbOpen(parseInt(b.getAttribute('data-g'),10));});
    lb.addEventListener('click',function(e){
      if(e.target.closest('[data-lbclose]')||e.target===lb)lbClose();
      else if(e.target.closest('[data-lbprev]'))lbShow(lbI-1);
      else if(e.target.closest('[data-lbnext]'))lbShow(lbI+1);
    });
    document.addEventListener('keydown',function(e){
      if(!lb.classList.contains('open'))return;
      if(e.key==='Escape')lbClose();else if(e.key==='ArrowLeft')lbShow(lbI-1);else if(e.key==='ArrowRight')lbShow(lbI+1);
    });
    var lx=null;
    lb.addEventListener('touchstart',function(e){lx=e.touches[0].clientX;},{passive:true});
    lb.addEventListener('touchend',function(e){if(lx===null)return;var dx=e.changedTouches[0].clientX-lx;if(Math.abs(dx)>40)lbShow(lbI+(dx<0?1:-1));lx=null;},{passive:true});
  }

  /* --- spaces: on phones a tile opens the full details in the sheet --- */
  var spWrap=document.querySelector('.rooms.sp');
  function openSpace(card){
    var im=card.querySelector('.ph img'),badge=card.querySelector('.ph small'),h=card.querySelector('h3'),p=card.querySelector('p'),rows=card.querySelectorAll('li'),btn=card.querySelector('.btn');
    var evmIm=document.getElementById('evmImg');
    evmIm.classList.remove('ld');evmIm.src=im?im.src:'';evmIm.alt=im?im.alt:'';
    if(evmIm.complete&&evmIm.naturalWidth>0)evmIm.classList.add('ld');else evmIm.addEventListener('load',function(){evmIm.classList.add('ld');},{once:true});
    document.getElementById('evmTag').textContent=badge?badge.textContent:'Space';
    document.getElementById('evmTitle').textContent=h?h.textContent:'';
    document.getElementById('evmMeta').innerHTML=Array.prototype.map.call(rows,function(li){
      var b=li.querySelector('b');var lab=li.firstChild&&li.firstChild.nodeType===3?li.firstChild.textContent.trim():'';
      return '<span>'+lab+(lab?': ':'')+'<b>'+(b?b.textContent:'')+'</b></span>';
    }).join('');
    document.getElementById('evmDesc').textContent=p?p.textContent:'';
    var cta=document.getElementById('evmEnquire');
    cta.removeAttribute('data-event');cta.removeAttribute('target');cta.removeAttribute('rel');
    if(btn&&btn.hasAttribute('data-space')){cta.setAttribute('data-space',btn.getAttribute('data-space'));cta.setAttribute('href','#enquire');cta.textContent='Enquire about this space';}
    else{cta.removeAttribute('data-space');cta.setAttribute('href',btn?btn.getAttribute('href'):'#enquire');cta.textContent=btn?btn.textContent:'Enquire now';}
    modal.classList.add('open');document.body.classList.add('lock');
  }
  if(spWrap){
    spWrap.addEventListener('click',function(e){
      if(!phone.matches)return;
      var card=e.target.closest('.room');if(!card)return;
      if(e.target.closest('a'))return;
      e.preventDefault();openSpace(card);
    });
    spWrap.querySelectorAll('.room').forEach(function(c){c.setAttribute('tabindex','0');c.setAttribute('role','button');});
    spWrap.addEventListener('keydown',function(e){if(phone.matches&&(e.key==='Enter'||e.key===' ')){var c=e.target.closest('.room');if(c&&e.target===c){e.preventDefault();openSpace(c);}}});
  }

  /* --- read-more clamps (phones) --- */
  function setupClamps(){
    if(!phone.matches)return;
    document.querySelectorAll('[data-clamp]').forEach(function(el){
      if(el.getAttribute('data-clamp-done'))return;
      el.setAttribute('data-clamp-done','1');
      el.classList.add('clamp');el.style.webkitLineClamp=el.getAttribute('data-clamp')||'3';
      if(el.scrollHeight>el.clientHeight+2){
        var b=document.createElement('button');b.type='button';b.className='morebtn';b.textContent='Read more';b.setAttribute('aria-expanded','false');
        b.addEventListener('click',function(){var o=el.classList.toggle('open');b.textContent=o?'Show less':'Read more';b.setAttribute('aria-expanded',o?'true':'false');});
        el.insertAdjacentElement('afterend',b);
      }else{el.classList.remove('clamp');}
    });
  }
  if(document.fonts&&document.fonts.ready)document.fonts.ready.then(setupClamps);else window.addEventListener('load',setupClamps);
  setTimeout(setupClamps,1200);

  /* --- enquiry form: optional details collapsed on phones --- */
  var enqMore=document.getElementById('enqMore');
  if(enqMore)enqMore.open=false;

  /* --- pull live content (non-blocking; page is already usable with baked-in data) --- */
  if(DB){
    dbGet('site_placements?select=slot,url,alt').then(function(rows){
      rows.forEach(function(r){document.querySelectorAll('img[data-slot="'+r.slot+'"]').forEach(function(im){if(im.src!==absUrl(r.url)){im.src=absUrl(r.url);}if(r.alt)im.alt=r.alt;});});
    }).catch(function(){});
    dbGet('site_events?select=slug,tag,title,teaser,description,photo_url').then(function(rows){
      if(!rows||!rows.length)return;
      EVENTS=rows.map(function(r){return {id:r.slug,tag:r.tag,title:r.title,teaser:r.teaser,desc:r.description,photoUrl:absUrl(r.photo_url)};});
      renderDeck();
    }).catch(function(){});
    dbGet('site_gallery?select=url,caption,alt').then(function(rows){
      if(!rows||!rows.length)return;
      GALLERY=rows.map(function(r){return {url:absUrl(r.url),c:r.caption||'',alt:r.alt||''};});
      renderGallery();
    }).catch(function(){});
  }

  /* --- what's on: month calendar + event list (events come from the staff area → Calendar) --- */
  (function(){
    var grid=document.getElementById('calGrid'),title=document.getElementById('calTitle'),list=document.getElementById('calList'),prev=document.getElementById('calPrev'),next=document.getElementById('calNext');
    if(!grid)return;
    var MONTHS=['January','February','March','April','May','June','July','August','September','October','November','December'];
    var DAYS=['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    var CAL=[],loading=DB,sel=null;
    function pad(n){return (n<10?'0':'')+n;}
    function ymd(d){return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate());}
    function parse(s){var p=String(s).split('-');return new Date(+p[0],+p[1]-1,+p[2]);}
    var now=new Date(),today=ymd(now),y=now.getFullYear(),m=now.getMonth();
    function t12(t){var x=/^(\d{1,2}):(\d{2})/.exec(t||'');if(!x)return t||'';var h=+x[1],ap=h>=12?'pm':'am';h=h%12||12;return h+(x[2]==='00'?'':':'+x[2])+ap;}
    function when(e){var a=t12(e.start_time),b=t12(e.end_time);return a&&b?a+'–'+b:a;}
    function longDate(s){var d=parse(s);return DAYS[d.getDay()]+' '+d.getDate()+' '+MONTHS[d.getMonth()];}
    function photo(e){return e.photo_url?absUrl(e.photo_url):PHOTOS.hero1;}
    function byId(id){for(var i=0;i<CAL.length;i++)if(String(CAL[i].id)===String(id))return CAL[i];return null;}
    function render(){
      var first=new Date(y,m,1),off=(first.getDay()+6)%7,days=new Date(y,m+1,0).getDate(),cells=Math.ceil((off+days)/7)*7,map={};
      CAL.forEach(function(e){(map[e.event_date]=map[e.event_date]||[]).push(e);});
      title.textContent=MONTHS[m]+' '+y;
      prev.disabled=(y===now.getFullYear()&&m===now.getMonth());
      var h=[];
      for(var i=0;i<cells;i++){
        var d=new Date(y,m,1-off+i),s=ymd(d),out=d.getMonth()!==m,ev=out?[]:(map[s]||[]);
        var cls='cd'+(out?' out':'')+(s<today?' past':'')+(s===today?' today':'')+(ev.length?' has':'')+(sel===s?' sel':'');
        h.push('<div class="'+cls+'" data-d="'+s+'"'+(ev.length?' role="button" tabindex="0" aria-label="'+esc(longDate(s)+': '+ev.map(function(e){return e.title;}).join(', '))+'"':'')+'>'
          +'<span class="dn">'+d.getDate()+'</span>'
          +ev.slice(0,3).map(function(e){return '<button type="button" class="cchip" data-id="'+esc(e.id)+'" tabindex="-1">'+esc(e.title)+'</button>';}).join('')
          +(ev.length>3?'<span class="cmore">+'+(ev.length-3)+' more</span>':'')
          +(ev.length?'<span class="cdots">'+ev.slice(0,3).map(function(){return '<i></i>';}).join('')+'</span>':'')
          +'</div>');
      }
      grid.innerHTML=h.join('');
      renderList();
    }
    function card(e){
      var d=parse(e.event_date),w=when(e);
      return '<button type="button" class="cev'+(e.event_date<today?' past':'')+'" data-id="'+esc(e.id)+'">'
        +'<span class="cph"><img src="'+esc(photo(e))+'" alt="" loading="lazy" decoding="async"></span>'
        +'<span class="cbd"><span class="cdate"><b>'+MONTHS[d.getMonth()].slice(0,3)+'</b><i>'+d.getDate()+'</i></span>'
        +'<span class="ctx"><span class="ct">'+esc(e.title)+'</span><span class="cm">'+esc(DAYS[d.getDay()]+(w?' · '+w:'')+(e.location?' at '+e.location:''))+'</span></span></span>'
        +(e.price?'<span class="cprice">'+esc(e.price)+'</span>':'')+'</button>';
    }
    function renderList(){
      if(loading){list.innerHTML='';return;}
      var a=ymd(new Date(y,m,1)),b=ymd(new Date(y,m+1,0));
      var items=CAL.filter(function(e){return sel?e.event_date===sel:(e.event_date>=a&&e.event_date<=b&&e.event_date>=today);});
      if(!items.length){
        var nx=CAL.filter(function(e){return e.event_date>b;})[0];
        list.innerHTML='<div class="calempty glass">'+(sel?'Nothing on that day.':'Nothing on the calendar for '+MONTHS[m]+' yet.')
          +'<span>Sign up and we\'ll tell you as soon as new dates go live.</span><div class="ce-btns"><a class="btn sage" href="#community">Sign up for events</a>'
          +(nx?'<button type="button" class="btn ghost" data-jump="'+esc(nx.event_date)+'">Next up: '+esc(nx.title)+', '+esc(longDate(nx.event_date))+'</button>':'')+'</div></div>';
        return;
      }
      list.innerHTML='<div class="calhd">'+(sel?esc(longDate(sel))+' <button type="button" data-clear>Show all of '+MONTHS[m]+'</button>':'Coming up in '+MONTHS[m])+'</div>'+items.map(card).join('');
    }
    function open(e){
      if(!e)return;
      var im=document.getElementById('evmImg');
      im.classList.remove('ld');im.src=photo(e);im.alt='';
      if(im.complete&&im.naturalWidth>0)im.classList.add('ld');else im.addEventListener('load',function(){im.classList.add('ld');},{once:true});
      document.getElementById('evmTag').textContent=longDate(e.event_date);
      document.getElementById('evmTitle').textContent=e.title;
      var rows=[['When',longDate(e.event_date)+' '+parse(e.event_date).getFullYear()+(when(e)?' · '+when(e):'')],['Where',e.location||"King's Clubhouse"],['Entry',e.price||'']];
      document.getElementById('evmMeta').innerHTML=rows.filter(function(r){return r[1];}).map(function(r){return '<span>'+r[0]+': <b>'+esc(r[1])+'</b></span>';}).join('');
      document.getElementById('evmDesc').textContent=e.description||'';
      var cta=document.getElementById('evmEnquire');
      cta.removeAttribute('data-event');cta.removeAttribute('data-space');
      if(e.link_url){cta.setAttribute('href',e.link_url);cta.setAttribute('target','_blank');cta.setAttribute('rel','noopener');cta.textContent='Book your place';}
      else{cta.setAttribute('href','#community');cta.removeAttribute('target');cta.removeAttribute('rel');cta.textContent='Sign up for events';}
      modal.classList.add('open');document.body.classList.add('lock');
    }
    function pick(s){sel=(sel===s)?null:s;render();if(sel&&phone.matches)list.scrollIntoView({behavior:reduce?'auto':'smooth',block:'start'});}
    grid.addEventListener('click',function(ev){
      var c=ev.target.closest('.cchip');
      if(c&&!phone.matches){open(byId(c.getAttribute('data-id')));return;}
      var cell=ev.target.closest('.cd.has');if(cell&&!cell.classList.contains('out'))pick(cell.getAttribute('data-d'));
    });
    grid.addEventListener('keydown',function(ev){if(ev.key==='Enter'||ev.key===' '){var cell=ev.target.closest('.cd.has');if(cell){ev.preventDefault();pick(cell.getAttribute('data-d'));}}});
    list.addEventListener('click',function(ev){
      var c=ev.target.closest('.cev');if(c){open(byId(c.getAttribute('data-id')));return;}
      if(ev.target.closest('[data-clear]')){sel=null;render();return;}
      var j=ev.target.closest('[data-jump]');if(j){var d=parse(j.getAttribute('data-jump'));y=d.getFullYear();m=d.getMonth();sel=null;render();}
    });
    prev.addEventListener('click',function(){if(prev.disabled)return;m--;if(m<0){m=11;y--;}sel=null;render();});
    next.addEventListener('click',function(){m++;if(m>11){m=0;y++;}sel=null;render();});
    render();
    if(DB){
      dbGet('site_calendar?select=id,title,event_date,start_time,end_time,location,price,description,link_url,photo_url&event_date=gte.'+ymd(new Date(now.getFullYear(),now.getMonth(),1)))
        .then(function(rows){CAL=rows||[];}).catch(function(){CAL=[];}).then(function(){loading=false;render();});
    }
  })();

  /* --- FAQ: show all --- */
  var faqMore=document.getElementById('faqMore'),faqEl=document.querySelector('.faq');
  if(faqMore&&faqEl){
    faqMore.addEventListener('click',function(){
      var all=faqEl.classList.toggle('all');
      faqMore.textContent=all?'Show fewer questions':'Show all 19 questions';
      faqMore.setAttribute('aria-expanded',all?'true':'false');
      if(!all)faqEl.scrollIntoView({behavior:reduce?'auto':'smooth',block:'start'});
    });
  }
})();
