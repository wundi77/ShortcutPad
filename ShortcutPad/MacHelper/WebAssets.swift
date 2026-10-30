import Foundation

/// Die Webseite, die der Mac dem iPad/iPhone anbietet (eine einzige Datei, kein Nachladen).
/// Als Raw-String (#"""…"""#) eingebettet, damit Backslashes im JavaScript unverändert bleiben.
enum WebAssets {
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
<title>ShortcutPad</title>
<style>
  :root {
    --bg: #101114; --card: #1b1d23; --line: #2c2f38; --text: #f2f3f5; --dim: #9aa0ad;
    --accent: #0a84ff; --ok: #30d158; --bad: #ff453a; --warn: #ffd60a;
  }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html, body { margin: 0; height: 100%; background: var(--bg); color: var(--text);
    font: 16px -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; }
  body { padding: env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);
    -webkit-user-select: none; user-select: none; touch-action: manipulation; }
  .wrap { min-height: 100%; display: flex; flex-direction: column; gap: 14px; padding: 16px; max-width: 760px; margin: 0 auto; }
  .hidden { display: none !important; }
  .card { background: var(--card); border: 1px solid var(--line); border-radius: 14px; padding: 14px 16px; }
  .row { display: flex; align-items: center; gap: 10px; }
  .dot { width: 12px; height: 12px; border-radius: 50%; background: var(--dim); flex: none; }
  .dot.ok { background: var(--ok); } .dot.bad { background: var(--bad); } .dot.warn { background: var(--warn); }
  .title { font-weight: 600; }
  .dim { color: var(--dim); font-size: 14px; }
  h1 { font-size: 22px; margin: 4px 0 0; }
  #padArea { flex: 1; display: flex; flex-direction: column; justify-content: center; min-height: 240px; }
  #bigButton { width: 100%; min-height: 240px; height: 42vh; border: 0; border-radius: 28px;
    background: linear-gradient(160deg, #1a8cff, #0a5fd8); color: #fff; font-size: 64px; font-weight: 700;
    letter-spacing: 1px; box-shadow: 0 10px 30px rgba(10, 132, 255, .35); }
  #bigButton:active, #bigButton.pressed { transform: scale(.98); filter: brightness(1.15); }
  #bigButton:disabled { background: #3a3d47; box-shadow: none; color: #8b909c; }
  #bigButton .sub { display: block; font-size: 15px; font-weight: 500; opacity: .85; margin-top: 8px; letter-spacing: 0; }
  #result { min-height: 22px; text-align: center; font-size: 15px; }
  #result.ok { color: var(--ok); } #result.bad { color: var(--bad); }
  button.plain { background: var(--card); color: var(--text); border: 1px solid var(--line); border-radius: 12px;
    padding: 12px 16px; font-size: 16px; }
  button.primary { background: var(--accent); border-color: var(--accent); color: #fff; font-weight: 600; }
  .chips { display: flex; gap: 8px; flex-wrap: wrap; margin: 10px 0; }
  .chip { flex: 1; min-width: 70px; text-align: center; padding: 12px 6px; border-radius: 12px; border: 1px solid var(--line);
    background: var(--bg); color: var(--text); font-size: 16px; }
  .chip.on { background: var(--accent); border-color: var(--accent); color: #fff; font-weight: 600; }
  input[type=text], input[type=tel], select { width: 100%; padding: 12px; border-radius: 12px; border: 1px solid var(--line);
    background: var(--bg); color: var(--text); font-size: 18px; -webkit-user-select: text; user-select: text; }
  input.pin { text-align: center; letter-spacing: 8px; font-size: 28px; }
  .seg { display: flex; border: 1px solid var(--line); border-radius: 12px; overflow: hidden; margin: 8px 0; }
  .seg button { flex: 1; padding: 11px; border: 0; background: var(--bg); color: var(--text); font-size: 15px; }
  .seg button.on { background: var(--accent); color: #fff; font-weight: 600; }
  .err { color: var(--bad); font-size: 14px; min-height: 18px; margin-top: 8px; }
  .spacer { height: 6px; }
</style>
</head>
<body>
<div class="wrap">
  <h1>ShortcutPad</h1>

  <!-- Kopplung -->
  <div id="pairView" class="hidden">
    <div class="card">
      <div class="title">Mit dem Mac koppeln</div>
      <p class="dim">Gib den 6-stelligen Code ein, den das Helper-Fenster auf dem Mac anzeigt. Das ist nur beim ersten Mal nötig.</p>
      <input id="pinInput" class="pin" type="tel" inputmode="numeric" maxlength="6" autocomplete="off" placeholder="••••••">
      <div class="spacer"></div>
      <button id="pairButton" class="plain primary" style="width:100%">Koppeln</button>
      <div id="pairError" class="err"></div>
    </div>
  </div>

  <!-- Pad -->
  <div id="padView" class="hidden" style="display:flex;flex-direction:column;gap:14px;flex:1">
    <div class="card">
      <div class="row"><span id="dot" class="dot"></span><span id="statusTitle" class="title">Verbinde …</span></div>
      <div id="statusDetail" class="dim" style="margin-top:6px"></div>
    </div>

    <div id="padArea">
      <button id="bigButton" type="button"><span id="bigLabel">⌘B</span><span class="sub">Tippen zum Auslösen</span></button>
    </div>
    <div id="result"></div>

    <div class="card">
      <div class="row" style="justify-content:space-between">
        <span class="title">Tastenkürzel</span>
        <button id="editToggle" class="plain" type="button">Ändern</button>
      </div>
      <div id="editor" class="hidden">
        <div class="chips" id="chips"></div>
        <div class="seg">
          <button id="modeChar" type="button" class="on">Zeichen</button>
          <button id="modeNamed" type="button">Sondertaste</button>
        </div>
        <input id="charInput" type="text" maxlength="2" autocapitalize="off" autocorrect="off" spellcheck="false" placeholder="Taste, z. B. b">
        <select id="namedSelect" class="hidden"></select>
        <p class="dim" id="editorHint"></p>
      </div>
    </div>

    <div class="row" style="justify-content:center">
      <button id="unpairButton" class="plain" type="button">Kopplung lösen</button>
    </div>
  </div>
</div>

<script>
(function () {
  'use strict';

  var MODS = [
    { id: 'control', symbol: '⌃', title: 'Control' },
    { id: 'option',  symbol: '⌥', title: 'Option' },
    { id: 'shift',   symbol: '⇧', title: 'Shift' },
    { id: 'command', symbol: '⌘', title: 'Command' }
  ];

  var NAMED = [
    ['return', '↩', 'Return'], ['tab', '⇥', 'Tab'], ['space', '␣', 'Leertaste'],
    ['backspace', '⌫', 'Löschen (⌫)'], ['forwardDelete', '⌦', 'Entf (⌦)'], ['escape', '⎋', 'Escape'],
    ['left', '←', 'Pfeil links'], ['right', '→', 'Pfeil rechts'], ['up', '↑', 'Pfeil hoch'], ['down', '↓', 'Pfeil runter'],
    ['home', '↖', 'Pos1'], ['end', '↘', 'Ende'], ['pageUp', '⇞', 'Bild ↑'], ['pageDown', '⇟', 'Bild ↓']
  ];
  for (var f = 1; f <= 12; f++) { NAMED.push(['f' + f, 'F' + f, 'F' + f]); }

  var TOKEN_KEY = 'pad.token.v1';
  var SHORTCUT_KEY = 'pad.shortcut.v1';

  var token = load(TOKEN_KEY, '');
  var shortcut = loadShortcut();
  var online = false;
  var pollTimer = null;
  var editing = false;
  var mode = 'char';

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

  function defaultShortcut() { return { key: 'b', modifiers: ['command'] }; }

  function loadShortcut() {
    try {
      var raw = load(SHORTCUT_KEY, '');
      if (!raw) { return defaultShortcut(); }
      var parsed = JSON.parse(raw);
      if (parsed && typeof parsed.key === 'string' && parsed.key.length > 0 && Array.isArray(parsed.modifiers)) {
        return parsed;
      }
    } catch (e) { /* defekte Daten → Standard */ }
    return defaultShortcut();
  }

  function namedInfo(key) {
    for (var i = 0; i < NAMED.length; i++) { if (NAMED[i][0] === key) { return NAMED[i]; } }
    return null;
  }

  function hasMod(id) { return shortcut.modifiers.indexOf(id) >= 0; }

  function display(s) {
    var text = '';
    for (var i = 0; i < MODS.length; i++) {
      if (s.modifiers.indexOf(MODS[i].id) >= 0) { text += MODS[i].symbol; }
    }
    var named = s.key.length > 1 ? namedInfo(s.key) : null;
    return text + (named ? named[1] : s.key.toUpperCase());
  }

  function isValid(s) {
    return s.key.length === 1 || (s.key.length > 1 && namedInfo(s.key) !== null);
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

  // ---------- Ansichten ----------

  function showPair() {
    stopPolling();
    $('padView').classList.add('hidden');
    $('padView').style.display = 'none';
    $('pairView').classList.remove('hidden');
  }

  function showPad() {
    $('pairView').classList.add('hidden');
    $('padView').classList.remove('hidden');
    $('padView').style.display = 'flex';
    renderShortcut();
    startPolling();
  }

  function setResult(text, kind) {
    var el = $('result');
    el.textContent = text || '';
    el.className = kind || '';
  }

  function renderShortcut() {
    $('bigLabel').textContent = display(shortcut);
    $('bigButton').disabled = !online || !isValid(shortcut);
  }

  function renderStatus(status) {
    var dot = $('dot');
    if (!status) {
      dot.className = 'dot bad';
      $('statusTitle').textContent = 'Mac nicht erreichbar';
      $('statusDetail').textContent = 'Läuft der Helper, und ist „Webseite anbieten“ eingeschaltet?';
      online = false;
    } else {
      online = true;
      if (status.accessibilityGranted) {
        dot.className = 'dot ok';
        $('statusTitle').textContent = 'Mac verbunden: ' + status.macName;
        $('statusDetail').textContent = 'Aktives Programm: ' + status.frontmostApp;
      } else {
        dot.className = 'dot warn';
        $('statusTitle').textContent = 'Verbunden, aber keine Freigabe';
        $('statusDetail').textContent = 'Am Mac unter Bedienungshilfen den ShortcutPadHelper erlauben.';
      }
    }
    renderShortcut();
  }

  // ---------- Status-Abfrage ----------

  function poll() {
    api('GET', '/api/status').then(function (res) {
      if (res.status === 401) { unpair(true); return; }
      renderStatus(res.status === 200 ? res.data : null);
    }, function () {
      renderStatus(null);
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

  // ---------- Auslösen ----------

  var busy = false;

  function trigger() {
    if (busy || !online || !isValid(shortcut)) { return; }
    busy = true;
    setResult('Sende …', '');
    api('POST', '/api/trigger', { shortcut: shortcut }).then(function (res) {
      busy = false;
      if (res.status === 401) { unpair(true); return; }
      if (res.status === 200) {
        setResult((res.data.ok ? '✓ ' : '✗ ') + res.data.message, res.data.ok ? 'ok' : 'bad');
      } else {
        setResult('✗ ' + (res.data.error || 'Fehler'), 'bad');
      }
    }, function () {
      busy = false;
      setResult('✗ Mac nicht erreichbar', 'bad');
    });
  }

  $('bigButton').addEventListener('click', trigger);

  // ---------- Kopplung ----------

  function pair(pin) {
    $('pairError').textContent = '';
    api('POST', '/api/pair', { pin: pin }).then(function (res) {
      if (res.status === 200 && res.data.token) {
        token = res.data.token;
        save(TOKEN_KEY, token);
        $('pinInput').value = '';
        showPad();
      } else {
        $('pairError').textContent = res.data.error || 'Koppeln fehlgeschlagen';
      }
    }, function () {
      $('pairError').textContent = 'Mac nicht erreichbar';
    });
  }

  function unpair(expired) {
    token = '';
    remove(TOKEN_KEY);
    online = false;
    showPair();
    $('pairError').textContent = expired ? 'Die Kopplung ist nicht mehr gültig. Bitte neu koppeln.' : '';
  }

  $('pairButton').addEventListener('click', function () {
    var pin = $('pinInput').value.replace(/\D/g, '');
    if (pin.length !== 6) { $('pairError').textContent = 'Bitte 6 Ziffern eingeben'; return; }
    pair(pin);
  });

  $('pinInput').addEventListener('input', function () {
    var cleaned = this.value.replace(/\D/g, '').slice(0, 6);
    if (cleaned !== this.value) { this.value = cleaned; }
    if (cleaned.length === 6) { pair(cleaned); }
  });

  $('unpairButton').addEventListener('click', function () { unpair(false); });

  // ---------- Editor ----------

  function persist() { save(SHORTCUT_KEY, JSON.stringify(shortcut)); renderShortcut(); updateHint(); }

  function updateHint() {
    $('editorHint').textContent = isValid(shortcut)
      ? 'Aktuell: ' + display(shortcut)
      : 'Bitte eine Taste wählen.';
  }

  function buildChips() {
    var box = $('chips');
    box.textContent = '';
    MODS.forEach(function (m) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'chip' + (hasMod(m.id) ? ' on' : '');
      b.textContent = m.symbol + ' ' + m.title;
      b.addEventListener('click', function () {
        var i = shortcut.modifiers.indexOf(m.id);
        if (i >= 0) { shortcut.modifiers.splice(i, 1); } else { shortcut.modifiers.push(m.id); }
        b.className = 'chip' + (hasMod(m.id) ? ' on' : '');
        persist();
      });
      box.appendChild(b);
    });
  }

  function buildNamedSelect() {
    var sel = $('namedSelect');
    sel.textContent = '';
    NAMED.forEach(function (n) {
      var o = document.createElement('option');
      o.value = n[0];
      o.textContent = n[1] + '  ' + n[2];
      sel.appendChild(o);
    });
  }

  function setMode(next) {
    mode = next;
    $('modeChar').className = next === 'char' ? 'on' : '';
    $('modeNamed').className = next === 'named' ? 'on' : '';
    $('charInput').classList.toggle('hidden', next !== 'char');
    $('namedSelect').classList.toggle('hidden', next !== 'named');
    if (next === 'named') {
      var named = shortcut.key.length > 1 ? namedInfo(shortcut.key) : null;
      if (!named) { shortcut.key = 'f5'; }
      $('namedSelect').value = shortcut.key;
    } else {
      $('charInput').value = shortcut.key.length === 1 ? shortcut.key : '';
      if (shortcut.key.length > 1) { shortcut.key = ''; }
    }
    persist();
  }

  $('modeChar').addEventListener('click', function () { setMode('char'); });
  $('modeNamed').addEventListener('click', function () { setMode('named'); });

  $('charInput').addEventListener('input', function () {
    var chars = Array.from(this.value);
    var last = chars.length ? chars[chars.length - 1] : '';
    if (last.length > 1) { last = ''; } // Emoji o. Ä. ablehnen
    this.value = last;
    shortcut.key = last;
    persist();
  });

  $('namedSelect').addEventListener('change', function () {
    shortcut.key = this.value;
    persist();
  });

  $('editToggle').addEventListener('click', function () {
    editing = !editing;
    $('editor').classList.toggle('hidden', !editing);
    this.textContent = editing ? 'Fertig' : 'Ändern';
    if (editing) {
      buildChips();
      buildNamedSelect();
      setMode(shortcut.key.length > 1 && namedInfo(shortcut.key) ? 'named' : 'char');
    }
  });

  // ---------- Start ----------

  function start() {
    var match = /pin=(\d{6})/.exec(window.location.hash || '');
    if (match) {
      try { history.replaceState(null, '', window.location.pathname); } catch (e) { /* egal */ }
      token = '';
      remove(TOKEN_KEY);
      showPair();
      pair(match[1]);
      return;
    }
    if (token) { showPad(); } else { showPair(); }
  }

  window.addEventListener('hashchange', function () {
    if (/pin=\d{6}/.test(window.location.hash || '')) { start(); }
  });

  start();
})();
</script>
</body>
</html>
"""#
}
