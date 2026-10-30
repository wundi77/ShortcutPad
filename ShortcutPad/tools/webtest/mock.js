const http=require('http'),fs=require('fs');
const html=fs.readFileSync(__dirname+'/index.html','utf8');
const G={Datei:['11111111-0000-0000-0000-000000000001','blau'],Bearbeiten:['11111111-0000-0000-0000-000000000002','indigo'],Ebenen:['11111111-0000-0000-0000-000000000003','orange'],Auswahl:['11111111-0000-0000-0000-000000000004','rot'],Werkzeug:['11111111-0000-0000-0000-000000000005','gruen'],Ansicht:['11111111-0000-0000-0000-000000000006','tuerkis']};
let n=0;
function sc(keys){const mods=[];let key='';for(const ch of keys){if(ch==='⌃')mods.push('control');else if(ch==='⌥')mods.push('option');else if(ch==='⇧')mods.push('shift');else if(ch==='⌘')mods.push('command');else key+=ch;}return{key:key.toLowerCase(),modifiers:mods};}
function btn(label,keys,g,star){n++;return{type:'button',button:{id:'b'+n,label,shortcut:sc(keys),groupID:G[g][0],emphasized:!!star}};}
function folder(name,color,rows){n++;return{type:'folder',folder:{id:'f'+n,name,color,buttons:rows.map(r=>btn(r[0],r[1],name).button)}};}
function photoshop(style){return{id:'S1',name:'Photoshop',appBundleID:'com.adobe.Photoshop',appName:'Adobe Photoshop',autoSwitch:true,color:'blau',style,size:'medium',showShortcuts:true,
 groups:Object.keys(G).map(k=>({id:G[k][0],name:k,color:G[k][1]})),
 items:[btn('Speichern','⌘S','Datei',1),btn('Zurück','⌘Z','Bearbeiten',1),btn('Neue Ebene','⇧⌘N','Ebenen',1),btn('Pinsel','B','Werkzeug',1),
 folder('Datei','blau',[['Neu','⌘N'],['Öffnen','⌘O'],['Speichern als','⇧⌘S'],['Für Web','⌥⇧⌘S']]),
 folder('Bearbeiten','indigo',[['Verlauf','⌥⌘Z'],['Kopieren','⌘C'],['Einfügen','⌘V']]),
 folder('Ebenen','orange',[['Duplikat','⌘J'],['Gruppe','⌘G'],['Maske','⌥⌘G'],['Reduzieren','⇧⌘E']]),
 folder('Auswahl','rot',[['Alles','⌘A'],['Aufheben','⌘D'],['Umkehren','⇧⌘I'],['Verfeinern','⌥⌘R'],['Transform','⌘T']]),
 folder('Werkzeug','gruen',[['Lasso','L'],['Farben tauschen','X']]),
 folder('Ansicht','tuerkis',[['100 %','⌘1'],['Lineale','⌘R'],['Bildgröße','⌥⌘I']]),
 btn('Vor','⇧⌘Z','Bearbeiten'),btn('Radierer','E','Werkzeug'),btn('Bewegen','V','Werkzeug'),btn('Einpassen','⌘0','Ansicht',1)]};}
const state={style:'bar',active:'S1',pinned:false,ax:true,down:false,log:[]};
const general={id:'S2',name:'Allgemein',appBundleID:null,appName:null,autoSwitch:true,color:'grau',style:'bar',size:'medium',showShortcuts:true,groups:[],items:[btn('Kopieren','⌘C','Datei'),btn('Einfügen','⌘V','Datei')]};
http.createServer((req,res)=>{
  let body='';req.on('data',d=>body+=d);req.on('end',()=>{
    const send=(code,obj)=>{res.writeHead(code,{'Content-Type':'application/json'});res.end(JSON.stringify(obj));};
    if(req.method==='GET'&&!req.url.startsWith('/api/')&&!req.url.startsWith('/__')){res.writeHead(200,{'Content-Type':'text/html'});return res.end(html);}
    if(req.url==='/__state'){Object.assign(state,JSON.parse(body||'{}'));return send(200,state);}
    if(req.url==='/__log')return send(200,state.log);
    if(state.down){req.socket.destroy();return;}
    if(req.url==='/api/pair'&&req.method==='POST'){const b=JSON.parse(body);return b.pin==='123456'?send(200,{token:'0123456789abcdef0123456789abcdef'}):send(403,{error:'Falscher Code'});}
    if(req.headers['x-pad-token']!=='0123456789abcdef0123456789abcdef')return send(401,{error:'Nicht gekoppelt'});
    if(req.url==='/api/status')return send(200,{macName:'Mac Studio',accessibilityGranted:state.ax,frontmostApp:'Adobe Photoshop',revision:1+(state.style==='fill'?1:0),activeSetID:state.active,pinned:state.pinned});
    if(req.url==='/api/library')return send(200,{revision:1+(state.style==='fill'?1:0),sets:[photoshop(state.style),general],activeSetID:state.active,pinned:state.pinned});
    if(req.url==='/api/select'){const b=JSON.parse(body);if(b.setID){state.active=b.setID;state.pinned=true;}else{state.pinned=false;state.active='S1';}return send(200,{ok:true});}
    if(req.url==='/api/trigger'){const b=JSON.parse(body);state.log.push(b.shortcut);return send(200,{ok:true,message:'gesendet (Mock)'});}
    send(404,{error:'?'});
  });
}).listen(8799,()=>console.log('mock ready'));
