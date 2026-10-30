const { chromium } = require('playwright');
const post=(page,path,body)=>page.evaluate(([p,b])=>fetch(p,{method:'POST',body:JSON.stringify(b)}).then(r=>r.json()),[path,body]);
(async()=>{
  const browser=await chromium.launch();
  const errors=[];
  async function ctx(w,h,name){
    const c=await browser.newContext({viewport:{width:w,height:h},deviceScaleFactor:2,hasTouch:true});
    const p=await c.newPage();
    p.on('pageerror',e=>errors.push(name+': '+e.message));
    p.on('console',m=>{if(m.type()==='error')errors.push(name+' console: '+m.text())});
    return p;
  }
  // iPhone: Kopplung
  let p=await ctx(390,844,'phone');
  await post(await (async()=>{await p.goto('http://localhost:8799/');return p})(),'/__state',{style:'bar',active:'S1',pinned:false,ax:true,down:false,log:[]});
  await p.reload();
  await p.screenshot({path:'out/01-pair.png'});
  await p.fill('#pinInput','111111'); await p.waitForTimeout(400);
  console.log('wrong pin error:',await p.textContent('#pairError'));
  await p.fill('#pinInput','123456'); await p.waitForTimeout(1200);
  await p.screenshot({path:'out/02-main.png'});
  console.log('tiles main:',await p.locator('.tile').count(),'cols:',await p.evaluate(()=>getComputedStyle(document.getElementById('grid')).gridTemplateColumns.split(' ').length));
  // Button tippen
  await p.locator('.tile',{hasText:'Neue Ebene'}).click(); await p.waitForTimeout(300);
  await p.screenshot({path:'out/03-pressed.png'});
  // Ordner öffnen
  await p.locator('.tile',{hasText:'Ebenen'}).first().click(); await p.waitForTimeout(300);
  await p.screenshot({path:'out/04-folder.png'});
  console.log('tiles folder:',await p.locator('.tile').count(),'first:',await p.locator('.tile').first().textContent());
  await p.locator('.tile.back').click(); await p.waitForTimeout(200);
  console.log('back to main tiles:',await p.locator('.tile').count());
  // Set-Wahl
  await p.locator('.setbtn').click(); await p.waitForTimeout(200);
  await p.screenshot({path:'out/05-sheet.png'});
  await p.locator('.setrow',{hasText:'Allgemein'}).click(); await p.waitForTimeout(1800);
  await p.screenshot({path:'out/06-general.png'});
  console.log('tag after select:',await p.textContent('.tag'),'| set:',await p.textContent('.setname'));
  // zurück auf auto
  await p.locator('.roundbtn').click(); await p.waitForTimeout(1800);
  console.log('tag after unpin:',await p.textContent('.tag'),'| set:',await p.textContent('.setname'));
  // Stil fill
  await post(p,'/__state',{style:'fill'}); await p.waitForTimeout(2200);
  await p.screenshot({path:'out/07-fill.png'});
  // Ohne Freigabe
  await post(p,'/__state',{style:'bar',ax:false}); await p.waitForTimeout(2200);
  await p.screenshot({path:'out/08-noax.png'});
  // Offline
  await post(p,'/__state',{ax:true,down:true}); await p.waitForTimeout(2200);
  await p.screenshot({path:'out/09-offline.png'});
  await fetch('http://localhost:8799/__state',{method:'POST',body:JSON.stringify({down:false})});
  console.log('trigger log:',await (await fetch('http://localhost:8799/__log')).text());
  // QR-Link
  let q=await ctx(390,844,'qr');
  await q.goto('http://localhost:8799/#pin=123456'); await q.waitForTimeout(1500);
  console.log('qr pairing -> tiles:',await q.locator('.tile').count());
  // iPad quer / hoch, iPhone quer
  for (const [w,h,n] of [[1180,820,'ipad-quer'],[820,1180,'ipad-hoch'],[844,390,'iphone-quer']]){
    const t=await ctx(w,h,n);
    await t.goto('http://localhost:8799/'); await t.evaluate(()=>localStorage.setItem('pad.token.v1','0123456789abcdef0123456789abcdef')); await t.reload(); await t.waitForTimeout(1500);
    console.log(n,'cols:',await t.evaluate(()=>getComputedStyle(document.getElementById('grid')).gridTemplateColumns.split(' ').length),'tile:',await t.evaluate(()=>getComputedStyle(document.documentElement).getPropertyValue('--t')));
    await t.screenshot({path:'out/10-'+n+'.png'});
  }
  console.log('ERRORS:',errors);
  await browser.close();
})();
