import Foundation

/// Die Webseite, die der Mac dem iPad/iPhone anbietet (eine einzige Datei, kein Nachladen).
/// Als Raw-String (#"""…"""#) eingebettet, damit Backslashes im JavaScript unverändert bleiben.
///
/// Die Seite zeigt das Pad nur an: Sets, Buttons und Ordner kommen vom Mac (`GET /api/library`),
/// beim Antippen geht das Kürzel an `POST /api/trigger`. Bearbeiten ist nur in der Mac-App möglich.
/// Bewusst ohne Framework und nur mit älterer JavaScript-Syntax (var, function, keine Pfeilfunktionen).
enum WebAssets {
    /// Beschreibung der Web-App (Name, Vollbild, Symbole). Wird unter /manifest.webmanifest ausgeliefert.
    static let manifestJSON = "{\"name\":\"ShortcutPad\",\"short_name\":\"ShortcutPad\",\"description\":\"Tastaturkürzel für den Mac per Fingertipp\",\"scope\":\"/\",\"display\":\"standalone\",\"orientation\":\"any\",\"background_color\":\"rgb(14, 15, 18)\",\"theme_color\":\"rgb(14, 15, 18)\",\"icons\":[{\"src\":\"/icon-192.png\",\"sizes\":\"192x192\",\"type\":\"image/png\"},{\"src\":\"/icon-512.png\",\"sizes\":\"512x512\",\"type\":\"image/png\"}]}"

    static let indexHTML = #"""
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="ShortcutPad">
<meta name="color-scheme" content="dark">
<meta name="theme-color" content="rgb(14, 15, 18)">
<link rel="manifest" href="/manifest.webmanifest">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<title>ShortcutPad</title>
<style>
  :root {
    --bg: #0e0f12; --tile: #25262b; --text: #f2f3f5; --dim: #a3a6af; --line: #34363d;
    --ok: #4ade80; --bad: #ff6b7f; --warn: #fbbf24; --glow: 11, 99, 240;
    --pad: 14px; --gap: 8px; --t: 84px;
  }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html, body { margin: 0; height: 100%; background-color: var(--bg); color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif; font-size: 16px;
    -webkit-font-smoothing: antialiased; }
  body { padding: env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);
    -webkit-user-select: none; user-select: none; touch-action: manipulation; overflow: hidden;
    background-image: radial-gradient(120% 40% at 50% 0%, rgba(var(--glow), .18), rgba(var(--glow), 0) 70%);
    background-repeat: no-repeat; }
  html, body { overscroll-behavior: none; }
  button { font: inherit; color: inherit; }
  .hidden { display: none !important; }
  .mono { font-family: ui-monospace, "SF Mono", Menlo, monospace; }

  /* Kopplung */
  #pairView { height: 100%; padding: 14px 24px 0; max-width: 520px; margin: 0 auto; }
  .brand { font-size: 12px; letter-spacing: .14em; color: var(--dim); padding-top: 14px; }
  #pairView h1 { font-size: 32px; font-weight: 800; letter-spacing: -.02em; line-height: 1.1; margin: 64px 0 12px; }
  #pairView p { font-size: 16px; line-height: 1.5; color: #b9bcc5; margin: 0; }
  .digits { position: relative; display: flex; gap: 8px; margin-top: 32px; }
  .digit { flex: 1; min-width: 0; height: 64px; border-radius: 14px; background: #1c1d21; box-shadow: inset 0 0 0 1px var(--line);
    display: flex; align-items: center; justify-content: center; font-size: 30px; font-weight: 500;
    font-family: ui-monospace, "SF Mono", Menlo, monospace; }
  .digit.cur { box-shadow: inset 0 0 0 2px #5b9bff; background: #1c2230; }
  #pinInput { position: absolute; inset: 0; width: 100%; height: 100%; opacity: 0; font-size: 16px; border: 0; background: none; color: transparent; }
  .err { color: var(--bad); font-size: 14px; min-height: 20px; margin-top: 14px; }
  .note { font-size: 13px; color: var(--dim); line-height: 1.45; margin-top: 8px; }

  /* Pad */
  #padView { height: 100%; display: flex; flex-direction: column; }
  .head { flex: none; padding: 8px var(--pad) 0; }
  .headrow { display: flex; align-items: center; justify-content: space-between; gap: 10px; min-height: 44px; }
  .setbtn { display: inline-flex; align-items: center; gap: 9px; min-height: 44px; background: none; border: 0; padding: 0; cursor: pointer; text-align: left; }
  .setdot { width: 11px; height: 11px; border-radius: 50%; flex: none; background: #0b63f0; }
  .setname { font-size: 24px; font-weight: 800; letter-spacing: -.01em; }
  .chev { color: var(--dim); flex: none; }
  .tag { padding: 2px 6px; border: 1px solid #3b3e47; border-radius: 6px; font-size: 10px; letter-spacing: .08em; color: var(--dim); }
  .tag.pin { color: #7fb0ff; border-color: #2c4a7a; }
  .roundbtn { width: 44px; height: 44px; border: 0; border-radius: 50%; background: #1c1d21; color: #b9bcc5; flex: none;
    display: inline-flex; align-items: center; justify-content: center; cursor: pointer; }
  .roundbtn.on { background: #1c2a44; color: #7fb0ff; }
  .upper { font-size: 15px; font-weight: 600; color: var(--dim); }
  .ftitle { display: flex; align-items: center; gap: 10px; margin-top: 2px; }
  .ftitle .setname { font-size: 28px; }
  .sub { display: flex; align-items: center; gap: 8px; font-size: 12.5px; color: var(--dim); margin-top: 3px; }
  .sdot { width: 7px; height: 7px; border-radius: 50%; background: var(--dim); flex: none; }
  .sdot.ok { background: var(--ok); } .sdot.bad { background: var(--bad); } .sdot.warn { background: var(--warn); }

  .banner { flex: none; margin: 14px var(--pad) 0; padding: 18px; border-radius: 16px; display: flex; flex-direction: column; gap: 10px; }
  .banner.bad { background: #2b1a1d; } .banner.warn { background: #2a2414; }
  .banner .bt { font-size: 17px; font-weight: 700; } .banner.bad .bt { color: #ffc2cb; } .banner.warn .bt { color: #f8dc96; }
  .banner .bx { font-size: 14px; line-height: 1.5; } .banner.bad .bx { color: #e9cdd2; } .banner.warn .bx { color: #e8dcbc; }
  .banner .bh { font-size: 11.5px; color: #c9b77e; }
  .banner button { margin-top: 4px; height: 48px; border: 0; border-radius: 12px; background: #f2f3f5; color: #111214; font-size: 15px; font-weight: 700; cursor: pointer; }

  .hint { flex: none; margin: 10px var(--pad) 0; padding: 4px 4px 4px 14px; border-radius: 12px; background: #1c1d21; color: var(--dim);
    font-size: 13px; display: flex; align-items: center; justify-content: space-between; gap: 10px; }
  .hint button { background: none; border: 0; color: var(--dim); font-size: 24px; width: 44px; height: 40px; cursor: pointer; }
  .gridwrap { flex: 1; min-height: 0; overflow-y: auto; -webkit-overflow-scrolling: touch; padding: 16px var(--pad) 70px; }
  .grid { display: grid; gap: var(--gap); }
  .grid.off .tile { opacity: .4; pointer-events: none; }
  .grid.noax .tile { opacity: .55; pointer-events: none; }
  .tile { position: relative; aspect-ratio: 1 / 1; border: 0; border-radius: calc(var(--t) * .19); padding: 6px 5px 12px;
    display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 3px; cursor: pointer; overflow: hidden;
    background: var(--tile); color: var(--text); box-shadow: inset 0 1px 0 rgba(255, 255, 255, .07), 0 6px 14px rgba(0, 0, 0, .35);
    transition: transform .08s, box-shadow .08s; }
  .tile.fill { background: var(--c); color: #fff; }
  .tl { font-weight: 700; font-size: clamp(11px, calc(var(--t) * .145), 20px); line-height: 1.15; text-align: center; overflow-wrap: anywhere;
    display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; max-width: 100%; }
  .tk { font-size: clamp(9px, calc(var(--t) * .105), 13px); font-family: ui-monospace, "SF Mono", Menlo, monospace; color: var(--dim); max-width: 100%;
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .tile.fill .tk { color: rgba(255, 255, 255, .88); }
  .tb { position: absolute; left: 20%; right: 20%; bottom: calc(var(--t) * .08); height: calc(var(--t) * .036); min-height: 3px; border-radius: 2px; background: var(--c); }
  .tile.fill .tb { display: none; }
  .tab { position: absolute; top: 0; left: 14%; width: 34%; height: calc(var(--t) * .1); min-height: 7px; border-radius: 0 0 6px 6px; background: var(--c); }
  .tile.fill .tab { background: rgba(255, 255, 255, .4); }
  .tile.back { background: #d0d3da; color: #1e1f23; padding: 0 0 calc(var(--t) * .04); font-size: calc(var(--t) * .5); font-weight: 600;
    font-family: ui-rounded, "SF Pro Rounded", -apple-system, sans-serif; line-height: 1; }
  .tile:active, .tile.pressed { transform: scale(.94); box-shadow: 0 0 0 2px var(--c, #fff), 0 0 22px var(--c, #fff); }
  .empty { grid-column: 1 / -1; color: var(--dim); font-size: 14px; line-height: 1.5; padding: 8px 2px; }

  .dots { position: fixed; left: 0; right: 0; bottom: calc(16px + env(safe-area-inset-bottom)); display: flex; justify-content: center; gap: 7px; pointer-events: none; }
  .dots i { width: 6px; height: 6px; border-radius: 3px; background: #4a4d57; }
  .dots i.on { width: 18px; background: #fff; }

  .toast { position: fixed; left: 16px; right: 16px; bottom: calc(34px + env(safe-area-inset-bottom)); max-width: 520px; margin: 0 auto;
    display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-radius: 16px; background: #16281d;
    box-shadow: 0 0 0 1px #24452f, 0 14px 30px rgba(0, 0, 0, .5); }
  .toast.bad { background: #2b1a1d; box-shadow: 0 0 0 1px #5a2a33, 0 14px 30px rgba(0, 0, 0, .5); }
  .toast .tt { font-size: 14.5px; font-weight: 700; color: #ddf8e6; } .toast.bad .tt { color: #ffc2cb; }
  .toast .td { font-size: 11.5px; margin-top: 2px; color: #9fd9b4; } .toast.bad .td { color: #e9cdd2; }
  .toast svg { flex: none; }
  .ic-ok { color: #4ade80; } .ic-bad { color: #ff6b7f; } .ic-chk { color: #6fa8ff; }

  /* Set wählen */
  .overlay { position: fixed; inset: 0; background: rgba(0, 0, 0, .58); z-index: 20; }
  .sheet { position: absolute; left: 0; right: 0; bottom: 0; max-width: 560px; margin: 0 auto; max-height: 92%; overflow-y: auto;
    padding: 10px 16px calc(24px + env(safe-area-inset-bottom)); border-radius: 26px 26px 0 0; background: #1c1d21; box-shadow: 0 -1px 0 var(--line); }
  .grab { width: 38px; height: 5px; border-radius: 3px; background: #4a4d57; margin: 0 auto 12px; }
  .sheet h2 { margin: 0; font-size: 21px; font-weight: 800; }
  .sheethead { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; }
  .link { background: none; border: 0; color: #6fa8ff; font-size: 16px; font-weight: 600; min-height: 44px; padding: 0 4px; cursor: pointer; }
  .autorow { display: flex; align-items: center; gap: 14px; padding: 14px; border-radius: 14px; background: var(--tile); margin-bottom: 8px; }
  .autorow .at { font-size: 15.5px; font-weight: 600; } .autorow .ad { margin-top: 3px; font-size: 12.5px; line-height: 1.4; color: var(--dim); }
  .sw { position: relative; flex: none; width: 51px; height: 31px; border: 0; border-radius: 16px; background: #4a4d57; cursor: pointer; }
  .sw i { position: absolute; top: 2px; left: 2px; width: 27px; height: 27px; border-radius: 50%; background: #fff; transition: left .15s; }
  .sw.on { background: #30d158; } .sw.on i { left: 22px; }
  .setrow { display: flex; align-items: center; gap: 14px; width: 100%; min-height: 56px; padding: 8px 14px; border: 0; border-radius: 12px; background: transparent; text-align: left; cursor: pointer; }
  .setrow.cur { background: var(--tile); }
  .setrow .rd { width: 12px; height: 12px; border-radius: 50%; flex: none; }
  .setrow .rn { font-size: 17px; font-weight: 600; } .setrow .ra { margin-top: 2px; font-size: 11.5px; color: var(--dim); }
  .setrow .rx { flex: 1; min-width: 0; }
  .foot { padding: 10px 2px 0; font-size: 12.5px; line-height: 1.45; color: var(--dim); }
  .unpair { margin-top: 10px; background: none; border: 0; color: #ff7a8a; font-size: 14px; padding: 8px 2px; cursor: pointer; }

  body.tablet .setname { font-size: 34px; }
  body.tablet .ftitle .setname { font-size: 34px; }
  body.tablet .sub { font-size: 15px; }
  body.tablet .upper { font-size: 20px; }
  body.tablet .roundbtn { width: 52px; height: 52px; }
  body.tablet .tb { min-height: 4px; }
</style>
</head>
<body>

<!-- Kopplung -->
<section id="pairView" class="hidden">
  <div class="brand mono">SHORTCUTPAD</div>
  <h1>Mit dem Mac koppeln</h1>
  <p>Gib den Code ein, der im ShortcutPad-Fenster am Mac steht. Das ist pro Gerät nur einmal nötig.</p>
  <div class="digits" id="digits">
    <div class="digit"></div><div class="digit"></div><div class="digit"></div><div class="digit"></div><div class="digit"></div><div class="digit"></div>
    <input id="pinInput" type="tel" inputmode="numeric" maxlength="6" autocomplete="one-time-code" aria-label="Kopplungscode, sechs Ziffern">
  </div>
  <div id="pairError" class="err" role="alert"></div>
  <div class="note">Nach fünf falschen Codes pausiert die Kopplung 30 Sekunden.</div>
</section>

<!-- Pad -->
<section id="padView" class="hidden">
  <div class="head" id="head"></div>
  <div id="banner" class="banner hidden"></div>
  <div id="hint" class="hint hidden"></div>
  <div class="gridwrap" id="gridwrap"><div class="grid" id="grid"></div></div>
  <div class="dots" id="dots"></div>
  <div id="toast" class="toast hidden" role="status"></div>
</section>

<!-- Set wählen -->
<div id="overlay" class="overlay hidden">
  <div class="sheet" id="sheet" role="dialog" aria-label="Set wählen"></div>
</div>

<script>
(function () {
  'use strict';

  var COLORS = { rot: '#E11D48', orange: '#CC420C', pink: '#DB2777', blau: '#0B63F0', indigo: '#6D4DE6', gruen: '#15803D', tuerkis: '#0E7490', grau: '#64748B' };
  var MIN_TILE = { small: [64, 96], medium: [80, 128], large: [104, 160] };
  var MODS = [['control', '⌃'], ['option', '⌥'], ['shift', '⇧'], ['command', '⌘']];
  var NAMED = { 'return': '↩', tab: '⇥', space: '␣', backspace: '⌫', forwardDelete: '⌦', escape: '⎋', left: '←', right: '→', up: '↑', down: '↓',
    home: '↖', end: '↘', pageUp: '⇞', pageDown: '⇟' };

  var TOKEN_KEY = 'pad.token.v1';
  var HINT_KEY = 'pad.hint.v1';

  var token = load(TOKEN_KEY, '');
  var status = null;      // Antwort von /api/status
  var library = null;     // Antwort von /api/library
  var online = false;
  var openFolderID = null;
  var lastKey = '';
  var lastSetID = '';
  var pollTimer = null;
  var tablet = false;
  var busy = false;
  var toastTimer = null;
  var sheetOpen = false;

  function $(id) { return document.getElementById(id); }

  function load(key, fallback) {
    try { var v = window.localStorage.getItem(key); return v === null ? fallback : v; } catch (e) { return fallback; }
  }
  function save(key, value) {
    try { window.localStorage.setItem(key, value); } catch (e) { /* Privates Surfen o. Ä. */ }
  }
  function remove(key) {
    try { window.localStorage.removeItem(key); } catch (e) { /* ignorieren */ }
  }

  function el(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) { node.className = cls; }
    if (text !== undefined && text !== null) { node.textContent = text; }
    return node;
  }

  function svg(markup) {
    var holder = document.createElement('span');
    holder.innerHTML = markup;
    return holder.firstChild;
  }

  var ICON_CHEV = '<svg class="chev" width="14" height="14" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2.5 4.5 6 8l3.5-3.5"/></svg>';
  var ICON_PIN = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 3h6l-1 5 3 3v2H7v-2l3-3-1-5z"/><path d="M12 13v8"/></svg>';
  var ICON_OK = '<svg class="ic-ok" width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 10.5 8 14.5 16 5.5"/></svg>';
  var ICON_BAD = '<svg class="ic-bad" width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M5 5l10 10M15 5L5 15"/></svg>';
  var ICON_CHECK = '<svg class="ic-chk" width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-label="aktuell"><path d="M4 10.5 8 14.5 16 5.5"/></svg>';

  // ---------- Kürzel anzeigen ----------

  function display(sc) {
    var text = '';
    for (var i = 0; i < MODS.length; i++) {
      if (sc.modifiers.indexOf(MODS[i][0]) >= 0) { text += MODS[i][1]; }
    }
    var key = sc.key;
    if (key.length > 1) {
      key = NAMED[key] || key.toUpperCase();
    } else {
      key = key.toUpperCase();
    }
    return text + key;
  }

  function hex(color) { return COLORS[color] || COLORS.grau; }

  function rgb(color) {
    var h = hex(color).replace('#', '');
    return parseInt(h.substr(0, 2), 16) + ', ' + parseInt(h.substr(2, 2), 16) + ', ' + parseInt(h.substr(4, 2), 16);
  }

  // ---------- Netzwerk ----------

  function api(method, path, body) {
    var controller = (typeof AbortController !== 'undefined') ? new AbortController() : null;
    var timer = controller ? setTimeout(function () { controller.abort(); }, 4000) : null;
    var headers = { 'Content-Type': 'application/json' };
    if (token) { headers['X-Pad-Token'] = token; }
    var options = { method: method, headers: headers, cache: 'no-store' };
    if (body !== undefined) { options.body = JSON.stringify(body); }
    if (controller) { options.signal = controller.signal; }
    return fetch(path, options).then(function (response) {
      if (timer) { clearTimeout(timer); }
      return response.json().catch(function () { return {}; }).then(function (data) {
        return { status: response.status, data: data };
      });
    }, function (error) {
      if (timer) { clearTimeout(timer); }
      throw error;
    });
  }

  // ---------- Daten ----------

  function currentSet() {
    if (!library || !library.sets || library.sets.length === 0) { return null; }
    var id = status && status.activeSetID ? status.activeSetID : library.activeSetID;
    for (var i = 0; i < library.sets.length; i++) {
      if (library.sets[i].id === id) { return library.sets[i]; }
    }
    return library.sets[0];
  }

  function findFolder(set, id) {
    if (!set || !id) { return null; }
    for (var i = 0; i < set.items.length; i++) {
      var item = set.items[i];
      if (item.type === 'folder' && item.folder.id === id) { return item.folder; }
    }
    return null;
  }

  function groupColor(set, groupID) {
    if (!groupID) { return null; }
    for (var i = 0; i < set.groups.length; i++) {
      if (set.groups[i].id === groupID) { return set.groups[i].color; }
    }
    return null;
  }

  function buttonColor(set, button) {
    return button.colorOverride || groupColor(set, button.groupID) || set.color;
  }

  function isPinned() { return !!(status && status.pinned); }

  // ---------- Ansichten ----------

  function showPair() {
    stopPolling();
    $('padView').classList.add('hidden');
    $('pairView').classList.remove('hidden');
    renderDigits();
  }

  // Läuft die Seite als Web-App vom Home-Bildschirm (ohne Browserleisten)?
  function isStandalone() {
    return window.navigator.standalone === true ||
      (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches);
  }

  // Im Browser hängt die Seite die Kopplung an die Adresse. Wer dann „Zum Home-Bildschirm“ wählt, nimmt sie in die Web-App mit
  // (die Web-App hat einen eigenen Speicher und sieht die Kopplung aus Safari sonst nicht).
  function markUrl() {
    if (isStandalone() || !token) { return; }
    try { history.replaceState(null, '', '/#t=' + token); } catch (e) { /* egal */ }
  }

  function updateHint() {
    var box = $('hint');
    var ios = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    if (isStandalone() || !ios || load(HINT_KEY, '') === '1') { box.classList.add('hidden'); return; }
    box.textContent = '';
    box.classList.remove('hidden');
    box.appendChild(el('span', '', 'Für Vollbild: Teilen → „Zum Home-Bildschirm“'));
    var close = el('button', '', '×');
    close.type = 'button';
    close.setAttribute('aria-label', 'Hinweis schließen');
    close.addEventListener('click', function () {
      save(HINT_KEY, '1');
      box.classList.add('hidden');
    });
    box.appendChild(close);
  }

  function showPad() {
    $('pairView').classList.add('hidden');
    $('padView').classList.remove('hidden');
    markUrl();
    updateHint();
    lastKey = '';
    startPolling();
    render();
  }

  // ---------- Darstellung ----------

  function computeLayout(set) {
    tablet = Math.min(window.innerWidth, window.innerHeight) >= 600;
    document.body.className = tablet ? 'tablet' : '';
    var pad = tablet ? 28 : 14;
    var gap = tablet ? 12 : 8;
    var size = (set && MIN_TILE[set.size]) ? set.size : 'medium';
    var min = MIN_TILE[size][tablet ? 1 : 0];
    var wrap = $('gridwrap');
    var usable = Math.max(120, wrap.clientWidth - 2 * pad);
    var cols = Math.max(1, Math.floor((usable + gap) / (min + gap)));
    var tile = (usable - (cols - 1) * gap) / cols;
    var root = document.documentElement.style;
    root.setProperty('--pad', pad + 'px');
    root.setProperty('--gap', gap + 'px');
    root.setProperty('--t', tile.toFixed(1) + 'px');
    return cols;
  }

  function renderStatusLine() {
    var line = $('statusLine');
    if (!line) { return; }
    var dot = line.firstChild;
    var text = line.lastChild;
    var set = currentSet();
    var folder = findFolder(set, openFolderID);
    var prefix = folder ? folder.buttons.length + (folder.buttons.length === 1 ? ' Button · ' : ' Buttons · ') : '';
    if (!online || !status) {
      dot.className = 'sdot bad';
      text.textContent = 'Kein Mac verbunden';
    } else if (!status.accessibilityGranted) {
      dot.className = 'sdot warn';
      text.textContent = prefix + status.macName + ' · Tasten gesperrt';
    } else {
      dot.className = 'sdot ok';
      text.textContent = prefix + status.macName + ' · ' + status.frontmostApp + ' vorne';
    }
  }

  function render() {
    if (!token) { return; }
    var set = currentSet();
    var ax = !!(status && status.accessibilityGranted);
    var state = !online ? 'off' : (ax ? 'ok' : 'noax');

    if (set && String(set.id) !== lastSetID) {
      if (lastSetID !== '') { openFolderID = null; }
      lastSetID = String(set.id);
    }
    if (openFolderID && !findFolder(set, openFolderID)) { openFolderID = null; }

    var key = [state, set ? set.id : '', openFolderID || '', library ? library.revision : '', isPinned() ? 1 : 0, window.innerWidth, window.innerHeight].join('|');
    if (key === lastKey) { renderStatusLine(); return; }
    lastKey = key;

    document.documentElement.style.setProperty('--glow', set ? rgb(set.color) : '11, 99, 240');
    var cols = computeLayout(set);
    renderHeader(set);
    renderBanner(state);
    renderGrid(set, state, cols);
    renderDots(set);
    renderStatusLine();
  }

  function renderHeader(set) {
    var head = $('head');
    head.textContent = '';
    var folder = findFolder(set, openFolderID);
    var row = el('div', 'headrow');

    if (folder) {
      row.appendChild(el('span', 'upper', set.name + ' ›'));
    } else {
      var setBtn = el('button', 'setbtn');
      setBtn.type = 'button';
      var dot = el('span', 'setdot');
      dot.style.background = hex(set ? set.color : 'blau');
      setBtn.appendChild(dot);
      setBtn.appendChild(el('span', 'setname', set ? set.name : 'ShortcutPad'));
      setBtn.appendChild(svg(ICON_CHEV));
      setBtn.appendChild(el('span', 'tag mono' + (isPinned() ? ' pin' : ''), isPinned() ? 'FIXIERT' : 'AUTO'));
      setBtn.addEventListener('click', openSheet);
      row.appendChild(setBtn);
    }

    var pin = el('button', 'roundbtn' + (isPinned() ? ' on' : ''));
    pin.type = 'button';
    pin.setAttribute('aria-label', isPinned() ? 'Set nicht mehr fixieren' : 'Set fixieren');
    pin.setAttribute('aria-pressed', isPinned() ? 'true' : 'false');
    pin.appendChild(svg(ICON_PIN));
    pin.addEventListener('click', function () {
      var s = currentSet();
      if (!s) { return; }
      selectSet(isPinned() ? null : s.id);
    });
    row.appendChild(pin);
    head.appendChild(row);

    if (folder) {
      var title = el('div', 'ftitle');
      var fdot = el('span', 'setdot');
      fdot.style.background = hex(folder.color);
      title.appendChild(fdot);
      title.appendChild(el('span', 'setname', folder.name));
      head.appendChild(title);
    }

    var sub = el('div', 'sub');
    sub.id = 'statusLine';
    sub.appendChild(el('span', 'sdot'));
    sub.appendChild(el('span', '', ''));
    head.appendChild(sub);
  }

  function renderBanner(state) {
    var banner = $('banner');
    banner.textContent = '';
    if (state === 'ok') { banner.className = 'banner hidden'; return; }
    if (state === 'off') {
      banner.className = 'banner bad';
      banner.appendChild(el('div', 'bt', 'Mac nicht erreichbar'));
      banner.appendChild(el('div', 'bx', 'Läuft ShortcutPad am Mac und ist die Webseite eingeschaltet? Mac und Gerät müssen im selben WLAN sein.'));
      var retry = el('button', '', 'Erneut versuchen');
      retry.type = 'button';
      retry.addEventListener('click', poll);
      banner.appendChild(retry);
    } else {
      banner.className = 'banner warn';
      banner.appendChild(el('div', 'bt', 'Bedienungshilfen fehlen am Mac'));
      banner.appendChild(el('div', 'bx', 'Der Mac ist verbunden, darf aber noch keine Tasten senden. Am Mac: ShortcutPad öffnen, Verbindung, Bedienungshilfen freigeben.'));
      banner.appendChild(el('div', 'bh mono', 'Hier am Gerät lässt sich das nicht ändern.'));
    }
  }

  function makeTile(set, label, keys, colorName, filled, isFolder) {
    var tile = el('button', 'tile' + (filled ? ' fill' : ''));
    tile.type = 'button';
    tile.style.setProperty('--c', hex(colorName));
    if (isFolder) { tile.appendChild(el('span', 'tab')); }
    tile.appendChild(el('span', 'tl', label));
    if (keys) { tile.appendChild(el('span', 'tk', keys)); }
    tile.appendChild(el('span', 'tb'));
    return tile;
  }

  function renderGrid(set, state, cols) {
    var grid = $('grid');
    grid.textContent = '';
    grid.className = 'grid' + (state === 'off' ? ' off' : (state === 'noax' ? ' noax' : ''));
    grid.style.gridTemplateColumns = 'repeat(' + cols + ', minmax(0, 1fr))';
    if (!set) {
      grid.appendChild(el('div', 'empty', online ? 'Es gibt noch keine Sets. Lege am Mac in der App ein Set an.' : ''));
      return;
    }
    var folder = findFolder(set, openFolderID);
    var showKeys = set.showShortcuts !== false;

    if (folder) {
      var back = el('button', 'tile back', '<');
      back.type = 'button';
      back.setAttribute('aria-label', 'Zurück zur Hauptebene');
      back.addEventListener('click', function () { openFolderID = null; lastKey = ''; render(); });
      grid.appendChild(back);
      if (folder.buttons.length === 0) {
        grid.appendChild(el('div', 'empty', 'Dieser Ordner ist noch leer. Buttons legst du am Mac hinein.'));
      }
      folder.buttons.forEach(function (button) {
        grid.appendChild(buttonTile(set, button, showKeys));
      });
      return;
    }

    if (set.items.length === 0) {
      grid.appendChild(el('div', 'empty', 'Dieses Set hat noch keine Buttons. Am Mac anlegen.'));
      return;
    }
    set.items.forEach(function (item) {
      if (item.type === 'folder') {
        var f = item.folder;
        var filled = set.style !== 'bar';
        var count = f.buttons.length + (f.buttons.length === 1 ? ' Button' : ' Buttons');
        var tile = makeTile(set, f.name, count, f.color, filled, true);
        tile.addEventListener('click', function () { openFolderID = f.id; lastKey = ''; render(); });
        grid.appendChild(tile);
      } else {
        grid.appendChild(buttonTile(set, item.button, showKeys));
      }
    });
  }

  function buttonTile(set, button, showKeys) {
    var filled = set.style === 'fill' || (set.style === 'mix' && button.emphasized);
    var tile = makeTile(set, button.label, showKeys ? display(button.shortcut) : '', buttonColor(set, button), filled, false);
    tile.addEventListener('click', function () { trigger(button, tile); });
    return tile;
  }

  function renderDots(set) {
    var dots = $('dots');
    dots.textContent = '';
    if (!library || !set || library.sets.length < 2 || openFolderID) { return; }
    library.sets.forEach(function (s) {
      dots.appendChild(el('i', s.id === set.id ? 'on' : ''));
    });
  }

  // ---------- Meldungen ----------

  function showToast(ok, title, detail) {
    var toast = $('toast');
    toast.textContent = '';
    toast.className = 'toast' + (ok ? '' : ' bad');
    toast.appendChild(svg(ok ? ICON_OK : ICON_BAD));
    var box = el('div');
    box.appendChild(el('div', 'tt', title));
    box.appendChild(el('div', 'td mono', detail));
    toast.appendChild(box);
    if (toastTimer) { clearTimeout(toastTimer); }
    toastTimer = setTimeout(function () { toast.className = 'toast hidden'; }, ok ? 1800 : 3200);
  }

  // ---------- Auslösen ----------

  function trigger(button, tile) {
    if (busy || !online || !status || !status.accessibilityGranted) { return; }
    busy = true;
    tile.classList.add('pressed');
    setTimeout(function () { tile.classList.remove('pressed'); }, 220);
    api('POST', '/api/trigger', { shortcut: button.shortcut }).then(function (res) {
      busy = false;
      if (res.status === 401) { unpair(true); return; }
      if (res.status === 200 && res.data.ok) {
        showToast(true, button.label + ' gesendet', res.data.message);
      } else {
        showToast(false, button.label + ' nicht gesendet', res.data.message || res.data.error || 'Fehler');
      }
    }, function () {
      busy = false;
      showToast(false, button.label + ' nicht gesendet', 'Mac nicht erreichbar');
    });
  }

  // ---------- Set wählen ----------

  function selectSet(id) {
    if (status) {
      status.pinned = !!id;
      if (id) { status.activeSetID = id; }
    }
    if (id) { openFolderID = null; }
    lastKey = '';
    render();
    api('POST', '/api/select', { setID: id }).then(function (res) {
      if (res.status === 401) { unpair(true); return; }
      poll();
    }, function () { poll(); });
  }

  function openSheet() {
    if (!library || !library.sets.length) { return; }
    sheetOpen = true;
    buildSheet();
    $('overlay').classList.remove('hidden');
  }

  function closeSheet() {
    sheetOpen = false;
    $('overlay').classList.add('hidden');
  }

  function buildSheet() {
    var sheet = $('sheet');
    sheet.textContent = '';
    var set = currentSet();
    sheet.appendChild(el('div', 'grab'));
    var head = el('div', 'sheethead');
    head.appendChild(el('h2', '', 'Set wählen'));
    var done = el('button', 'link', 'Fertig');
    done.type = 'button';
    done.addEventListener('click', closeSheet);
    head.appendChild(done);
    sheet.appendChild(head);

    var auto = el('div', 'autorow');
    var text = el('div');
    text.style.flex = '1';
    text.appendChild(el('div', 'at', 'Automatisch wechseln'));
    text.appendChild(el('div', 'ad', 'Das Set folgt dem vordersten Programm am Mac.'));
    auto.appendChild(text);
    var sw = el('button', 'sw' + (isPinned() ? '' : ' on'));
    sw.type = 'button';
    sw.setAttribute('role', 'switch');
    sw.setAttribute('aria-checked', isPinned() ? 'false' : 'true');
    sw.setAttribute('aria-label', 'Automatisch wechseln');
    sw.appendChild(el('i'));
    sw.addEventListener('click', function () {
      var s = currentSet();
      selectSet(isPinned() ? null : (s ? s.id : null));
      setTimeout(buildSheet, 60);
    });
    auto.appendChild(sw);
    sheet.appendChild(auto);

    library.sets.forEach(function (s) {
      var row = el('button', 'setrow' + (set && s.id === set.id ? ' cur' : ''));
      row.type = 'button';
      var dot = el('span', 'rd');
      dot.style.background = hex(s.color);
      row.appendChild(dot);
      var box = el('span', 'rx');
      box.appendChild(el('div', 'rn', s.name));
      box.appendChild(el('div', 'ra mono', s.appName || 'Alle anderen Programme'));
      row.appendChild(box);
      if (set && s.id === set.id) { row.appendChild(svg(ICON_CHECK)); }
      row.addEventListener('click', function () {
        selectSet(s.id);
        closeSheet();
      });
      sheet.appendChild(row);
    });

    sheet.appendChild(el('div', 'foot', 'Sets und Buttons legst du am Mac an. Hier wählst du nur aus.'));
    var unpairBtn = el('button', 'unpair', 'Kopplung lösen');
    unpairBtn.type = 'button';
    unpairBtn.addEventListener('click', function () { closeSheet(); unpair(false); });
    sheet.appendChild(unpairBtn);
  }

  $('overlay').addEventListener('click', function (event) {
    if (event.target === $('overlay')) { closeSheet(); }
  });

  // ---------- Wischen zwischen Sets ----------

  var touchStart = null;
  $('gridwrap').addEventListener('touchstart', function (event) {
    if (event.touches.length !== 1) { touchStart = null; return; }
    touchStart = { x: event.touches[0].clientX, y: event.touches[0].clientY };
  }, { passive: true });
  $('gridwrap').addEventListener('touchend', function (event) {
    if (!touchStart || !library || library.sets.length < 2 || openFolderID || !event.changedTouches.length) { touchStart = null; return; }
    var dx = event.changedTouches[0].clientX - touchStart.x;
    var dy = event.changedTouches[0].clientY - touchStart.y;
    touchStart = null;
    if (Math.abs(dx) < 70 || Math.abs(dx) < Math.abs(dy) * 2) { return; }
    var set = currentSet();
    var index = 0;
    for (var i = 0; i < library.sets.length; i++) {
      if (set && library.sets[i].id === set.id) { index = i; }
    }
    var next = index + (dx < 0 ? 1 : -1);
    if (next < 0 || next >= library.sets.length) { return; }
    selectSet(library.sets[next].id);
  }, { passive: true });

  // ---------- Abfragen ----------

  function loadLibrary() {
    api('GET', '/api/library').then(function (res) {
      if (res.status === 401) { unpair(true); return; }
      if (res.status === 200) {
        library = res.data;
        lastKey = '';
        render();
        if (sheetOpen) { buildSheet(); }
      }
    }, function () { /* nächste Abfrage */ });
  }

  function poll() {
    api('GET', '/api/status').then(function (res) {
      if (res.status === 401) { unpair(true); return; }
      if (res.status === 200) {
        status = res.data;
        online = true;
        if (library === null || library.revision !== status.revision) { loadLibrary(); }
      } else {
        online = false;
      }
      render();
    }, function () {
      online = false;
      render();
    });
  }

  function startPolling() {
    stopPolling();
    poll();
    pollTimer = setInterval(poll, 1500);
  }

  function stopPolling() {
    if (pollTimer) { clearInterval(pollTimer); pollTimer = null; }
  }

  document.addEventListener('visibilitychange', function () {
    if (!token) { return; }
    if (document.hidden) { stopPolling(); } else { startPolling(); }
  });

  window.addEventListener('resize', function () { lastKey = ''; render(); });

  // ---------- Kopplung ----------

  function renderDigits() {
    var value = $('pinInput').value;
    var boxes = $('digits').getElementsByClassName('digit');
    for (var i = 0; i < boxes.length; i++) {
      boxes[i].textContent = value.charAt(i);
      boxes[i].className = 'digit' + (i === value.length ? ' cur' : '');
    }
  }

  function pair(pin) {
    $('pairError').textContent = '';
    api('POST', '/api/pair', { pin: pin }).then(function (res) {
      if (res.status === 200 && res.data.token) {
        token = res.data.token;
        save(TOKEN_KEY, token);
        $('pinInput').value = '';
        status = null; library = null; openFolderID = null; lastSetID = '';
        showPad();
      } else {
        $('pairError').textContent = res.data.error || 'Koppeln fehlgeschlagen';
        $('pinInput').value = '';
        renderDigits();
      }
    }, function () {
      $('pairError').textContent = 'Mac nicht erreichbar';
    });
  }

  function unpair(expired) {
    token = '';
    remove(TOKEN_KEY);
    online = false;
    status = null;
    library = null;
    try { history.replaceState(null, '', '/'); } catch (e) { /* egal */ }
    showPair();
    $('pairError').textContent = expired ? 'Die Kopplung ist nicht mehr gültig. Bitte neu koppeln.' : '';
  }

  $('pinInput').addEventListener('input', function () {
    var cleaned = this.value.replace(/\D/g, '').slice(0, 6);
    if (cleaned !== this.value) { this.value = cleaned; }
    renderDigits();
    if (cleaned.length === 6) { pair(cleaned); }
  });

  // ---------- Start ----------

  // Der Code steht normalerweise nach dem „#“ der Adresse; zur Sicherheit wird auch ?pin=… und ein verirrtes %23pin=… im Pfad erkannt.
  function findPin() {
    var where = [window.location.hash || '', window.location.search || '', window.location.pathname || ''];
    for (var i = 0; i < where.length; i++) {
      var m = /pin(?:=|%3D)(\d{6})/i.exec(where[i]);
      if (m) { return m; }
    }
    return null;
  }

  function start() {
    // Kopplung aus der Adresse übernehmen (Web-App vom Home-Bildschirm, siehe markUrl)
    var handed = /[#&]t=([0-9a-f]{16,64})/i.exec(window.location.hash || '');
    if (handed && !findPin()) {
      if (!token) { token = handed[1]; save(TOKEN_KEY, token); }
      if (isStandalone()) {
        try { history.replaceState(null, '', '/'); } catch (e) { /* egal */ }
      }
    }
    var match = findPin();
    if (match) {
      try { history.replaceState(null, '', '/'); } catch (e) { /* egal */ }
      token = '';
      remove(TOKEN_KEY);
      showPair();
      pair(match[1]);
      return;
    }
    if (token) { showPad(); } else { showPair(); }
  }

  window.addEventListener('hashchange', function () {
    if (findPin()) { start(); }
  });

  start();
})();
</script>
</body>
</html>
"""#
}
