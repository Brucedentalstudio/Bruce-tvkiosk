(function () {
  'use strict';
  var KIND_LABEL = { image: 'Ảnh', video: 'Video', audio: 'Âm thanh', pdf: 'PDF', pptx: 'PowerPoint', slides: 'Slides' };
  var NOPPT = '(máy chưa cài LibreOffice)';
  var $ = function (id) { return document.getElementById(id); };
  var home = $('home'), groupsEl = $('groups'), banner = $('banner');
  var player = $('player'), stage = $('pStage'), ctrl = $('pCtrl'), pTitle = $('pTitle'), pAuto = $('pAuto');

  var pHint = $('pHint');
  var data = null, lastJson = '', pollTimer = null, inFlight = false;
  var cur = null; // open player state
  var openToken = 0;

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtSize(n) {
    if (typeof n !== 'number' || !isFinite(n)) return '';
    if (n >= 1048576) return (n / 1048576).toFixed(1).replace('.', ',') + ' MB';
    return Math.max(1, Math.round(n / 1024)) + ' KB';
  }
  function two(n) { return (n < 10 ? '0' : '') + n; }
  function fmtTime(s) {
    if (!isFinite(s) || s < 0) s = 0;
    s = Math.floor(s);
    var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    return (h ? h + ':' + two(m) : two(m)) + ':' + two(s % 60);
  }
  function fmtSync(iso) {
    var d = new Date(iso);
    if (isNaN(d)) return '';
    return two(d.getHours()) + ':' + two(d.getMinutes()) + ' ' + two(d.getDate()) + '/' + two(d.getMonth() + 1);
  }
  function fileUrl(prefix, id) {
    return prefix + id.split('/').map(encodeURIComponent).join('/');
  }

  // ---------- home ----------
  function rowHtml(it, pptxOk) {
    var dis = it.kind === 'pptx' && !pptxOk;
    var meta = dis ? NOPPT : (it.kind === 'slides' ? 'Trực tuyến' : fmtSize(it.size));
    return '<div class="row' + (dis ? ' disabled' : '') + '" tabindex="0" role="button"' + (dis ? ' aria-disabled="true"' : '') +
      ' data-id="' + esc(it.id) + '"><span class="badge t-' + it.kind + '">' + KIND_LABEL[it.kind] + '</span><span class="name">' +
      esc(it.name) + '</span><span class="meta">' + esc(meta) + '</span></div>';
  }
  function groupHtml(title, sub, rowsHtml, emptyText) {
    return '<div class="group"><h2>' + esc(title) + (sub ? ' <span class="sub">' + esc(sub) + '</span>' : '') + '</h2>' +
      (rowsHtml || '<div class="empty">' + esc(emptyText) + '</div>') + '</div>';
  }
  function render() {
    var d = data, html = '', items = {}, si = 0;
    d.sources.forEach(function (s) {
      var rs = (s.items || []).map(function (it) { items[it.id] = it; return rowHtml(it, d.pptx); }).join('');
      var sub = '', empty = 'Chưa có file';
      if (s.id === 'usb') {
        if (!s.available) { sub = 'Chưa cắm'; empty = 'Chưa cắm USB'; rs = ''; }
      } else if (s.id === 'drive') {
        if (s.lastSync && s.lastSync.ok) sub = 'Đồng bộ lúc ' + fmtSync(s.lastSync.at);
        else if (s.lastSync) sub = 'Đồng bộ lỗi: ' + (s.lastSync.message || '');
        else sub = 'Chưa bật đồng bộ';
      }
      html += groupHtml(s.label, sub, rs, empty);
    });
    var srows = (d.slides || []).map(function (sl) {
      var it = { id: 'slides/' + (si++), name: sl.name, kind: 'slides', url: sl.url };
      items[it.id] = it;
      return rowHtml(it, true);
    }).join('');
    html += groupHtml('Google Slides', '', srows, 'Chưa có link Google Slides');
    d.itemsById = items;

    var active = document.activeElement;
    var keepId = active && active.classList && active.classList.contains('row') ? active.getAttribute('data-id') : null;
    groupsEl.innerHTML = html;
    if (keepId) {
      var r = rowById(keepId);
      if (r) r.focus({ preventScroll: true }); else focusFirst();
    }
  }
  function rows() { return Array.prototype.slice.call(groupsEl.querySelectorAll('.row')); }
  function rowById(id) {
    var all = rows();
    for (var i = 0; i < all.length; i++) if (all[i].getAttribute('data-id') === id) return all[i];
    return null;
  }

  function load() {
    if (inFlight) return Promise.resolve();
    inFlight = true;
    var ac = new AbortController();
    var t = setTimeout(function () { ac.abort(); }, 4000);
    return fetch('/api/list', { cache: 'no-store', signal: ac.signal })
      .then(function (r) { if (!r.ok) throw new Error('http ' + r.status); return r.text(); })
      .then(function (txt) {
        var first = data === null;
        banner.hidden = true;
        var o = JSON.parse(txt);
        delete o.generated;
        var cmp = JSON.stringify(o);
        if (cmp !== lastJson) {
          lastJson = cmp;
          data = o;
          render();
        }
        if (first) focusFirst();
      })
      .catch(function () { banner.hidden = false; })
      .then(function () { clearTimeout(t); inFlight = false; });
  }
  function focusFirst() {
    var r = rows();
    (r[0] || $('btnRefresh')).focus();
  }
  // polls only while the home is visible
  function schedule() {
    clearTimeout(pollTimer);
    pollTimer = setTimeout(function () {
      if (!cur) load().then(schedule); else schedule();
    }, 5000);
  }

  $('btnRefresh').addEventListener('click', function () { load(); });

  // switch panel handshake with the kiosk extension content script
  var switchReady = false;
  window.addEventListener('message', function (e) {
    if (e.origin === location.origin && e.data && e.data.type === 'smilelog-tv:switch-panel-ready') {
      switchReady = true;
      $('mainHint').hidden = true;
    }
  });
  setTimeout(function () { if (!switchReady) $('mainHint').hidden = false; }, 3000);
  $('btnMain').addEventListener('click', function () {
    if (switchReady) window.postMessage({ type: 'smilelog-tv:open-switch-panel' }, location.origin);
    else $('mainHint').hidden = false;
  });

  groupsEl.addEventListener('click', function (e) {
    var row = e.target.closest && e.target.closest('.row');
    if (row) openRow(row);
  });

  function openRow(row) {
    if (row.classList.contains('disabled')) return;
    var it = data && data.itemsById[row.getAttribute('data-id')];
    if (it) openPlayer(it);
  }

  // ---------- player ----------
  function clearAuto() { if (cur && cur.timer) { clearInterval(cur.timer); cur.timer = null; } }
  function closePlayer() {
    if (!cur) return;
    var id = cur.item.id;
    if (cur.openId) id = cur.openId;
    openToken++;
    clearAuto();
    if (cur.abort) cur.abort.abort();
    stage.querySelectorAll('video,audio').forEach(function (m) { m.pause(); m.removeAttribute('src'); m.load(); });
    stage.innerHTML = ''; ctrl.innerHTML = '';
    player.hidden = true; home.hidden = false;
    cur = null;
    var r = rowById(id);
    if (r) r.focus(); else focusFirst();
    load().then(schedule);
  }
  $('pBack').addEventListener('click', closePlayer);

  function openPlayer(it) {
    openToken++;
    var token = openToken;
    cur = { item: it, openId: it.id, timer: null, auto: false, list: null, idx: 0 };
    home.hidden = true; player.hidden = false;
    stage.innerHTML = ''; ctrl.innerHTML = ''; pAuto.hidden = true;
    pTitle.textContent = it.name;
    var k = it.kind;
    if (k === 'image') openImage(it);
    else if (k === 'video' || k === 'audio') openMedia(it, k);
    else if (k === 'pdf') openFrame(fileUrl('/file/', it.id) + '#toolbar=0&view=Fit');
    else if (k === 'pptx') openPptx(it, token);
    else if (k === 'slides') openFrame(it.url, true);
    var inFrame = k === 'pdf' || k === 'pptx' || k === 'slides';
    pHint.textContent = inFrame ? 'Bấm Quay lại để về danh sách · ⇄ để về màn hình chính' : 'Esc để quay lại · ⇄ để về màn hình chính';
    if (!inFrame) player.focus();
  }

  function setMsg(text) { stage.innerHTML = '<div class="msg">' + esc(text) + '</div>'; }

  // Esc cannot be caught while focus is inside the PDF or Slides iframe (key events go to the
  // iframe document, not the parent); the "Quay lại" button stays visible there.
  function openFrame(src, slides) {
    var f = document.createElement('iframe');
    f.src = src;
    if (slides) f.setAttribute('allow', 'autoplay; fullscreen');
    f.setAttribute('allowfullscreen', '');
    stage.innerHTML = '';
    stage.appendChild(f);
    f.addEventListener('load', function () { try { f.focus(); } catch (e) {} });
    f.focus();
    return f;
  }

  function openPptx(it, token) {
    var url = fileUrl('/pdf/', it.id);
    stage.innerHTML = '<div class="ov"><div class="msg">Đang chuyển PowerPoint sang PDF, chờ một chút</div></div>';
    var ac = new AbortController();
    cur.abort = ac;
    fetch(url, { signal: ac.signal }).then(function (r) {
      if (token !== openToken) { ac.abort(); return; }
      var ct = r.headers.get('content-type') || '';
      if (!r.ok || ct.indexOf('json') >= 0) {
        return r.json().catch(function () { return {}; }).then(function (j) {
          if (token === openToken) setMsg(j.error || 'Không chuyển được file PowerPoint này');
        });
      }
      ac.abort(); // the converted file is cached by the server; the iframe fetches it itself
      var f = openFrame(url + '#toolbar=0&view=Fit');
      var ov = document.createElement('div');
      ov.className = 'ov';
      ov.innerHTML = '<div class="msg">Đang chuyển PowerPoint sang PDF, chờ một chút</div>';
      stage.appendChild(ov);
      f.addEventListener('load', function () { ov.remove(); });
    }).catch(function () {
      if (token === openToken && !ac.signal.aborted) setMsg('Không chuyển được file PowerPoint này');
    });
  }

  function openImage(it) {
    var src = it.id.split('/')[0];
    var list = ((data.sources.filter(function (s) { return s.id === src; })[0] || {}).items || [])
      .filter(function (x) { return x.kind === 'image'; });
    var idx = Math.max(0, list.map(function (x) { return x.id; }).indexOf(it.id));
    cur.list = list; cur.idx = idx;
    ctrl.innerHTML = '<button class="btn" id="iPrev" type="button">Trước</button><span class="count" id="iCount"></span><button class="btn pri" id="iNext" type="button">Sau</button>';
    $('iPrev').onclick = function () { stepImage(-1); };
    $('iNext').onclick = function () { stepImage(1); };
    pAuto.hidden = false; setAuto(false);
    showImage();
  }
  function showImage() {
    var it = cur.list[cur.idx];
    pTitle.textContent = it.name;
    cur.item = it;
    stage.innerHTML = '';
    var img = document.createElement('img');
    img.alt = it.name;
    img.onerror = function () { setMsg('Máy không hiển thị được ảnh này'); };
    img.src = fileUrl('/file/', it.id);
    stage.appendChild(img);
    $('iCount').textContent = (cur.idx + 1) + '/' + cur.list.length;
  }
  function stepImage(d) {
    var n = cur.list.length;
    cur.idx = (cur.idx + d + n) % n;
    showImage();
    if (cur.auto) setAuto(true);
  }
  function setAuto(on) {
    clearAuto();
    cur.auto = on;
    pAuto.setAttribute('aria-pressed', on ? 'true' : 'false');
    pAuto.textContent = 'Tự chạy: ' + (on ? 'Bật' : 'Tắt');
    if (on) cur.timer = setInterval(function () { stepImage(1); }, 8000);
  }
  pAuto.addEventListener('click', function () { if (cur && cur.list) setAuto(!cur.auto); });

  function openMedia(it, kind) {
    var m = document.createElement(kind === 'video' ? 'video' : 'audio');
    m.preload = 'auto';
    stage.innerHTML = '';
    if (kind === 'audio') stage.insertAdjacentHTML('beforeend', '<div class="big">' + esc(it.name) + '</div>');
    stage.appendChild(m);
    if (kind === 'audio') m.style.display = 'none';
    ctrl.innerHTML = '<button class="btn pri" id="mPlay" type="button">Tạm dừng</button>' +
      '<span class="count" id="mCur" style="min-width:0">00:00</span>' +
      '<input class="seek" id="mSeek" type="range" min="0" max="1000" value="0" aria-label="Tua">' +
      '<span class="count" id="mDur" style="min-width:0">00:00</span>' +
      '<label>Âm lượng <input class="vol" id="mVol" type="range" min="0" max="100" value="100" aria-label="Âm lượng"></label>';
    var play = $('mPlay'), seek = $('mSeek'), vol = $('mVol'), dragging = false;
    function sync() {
      play.textContent = m.paused ? 'Phát' : 'Tạm dừng';
      $('mCur').textContent = fmtTime(m.currentTime);
      $('mDur').textContent = fmtTime(m.duration);
      if (!dragging && m.duration) seek.value = Math.round(m.currentTime / m.duration * 1000);
      vol.value = Math.round(m.volume * 100);
    }
    ['timeupdate', 'play', 'pause', 'loadedmetadata', 'durationchange', 'volumechange', 'ended'].forEach(function (ev) { m.addEventListener(ev, sync); });
    m.addEventListener('error', function () {
      stage.innerHTML = '<div class="msg">Máy không phát được file này (định dạng không hỗ trợ)</div>';
      ctrl.innerHTML = '';
      cur.media = null;
    });
    play.onclick = function () { togglePlay(); };
    seek.addEventListener('input', function () { dragging = true; if (m.duration) m.currentTime = seek.value / 1000 * m.duration; });
    seek.addEventListener('change', function () { dragging = false; });
    vol.addEventListener('input', function () { m.volume = vol.value / 100; });
    cur.media = m;
    m.src = fileUrl('/file/', it.id);
    var p = m.play();
    if (p && p.catch) p.catch(function () { sync(); });
  }
  function togglePlay() {
    var m = cur && cur.media;
    if (!m) return;
    if (m.paused) { var p = m.play(); if (p && p.catch) p.catch(function () {}); } else m.pause();
  }

  // ---------- keyboard ----------
  document.addEventListener('keydown', function (e) {
    if (e.altKey || e.ctrlKey || e.metaKey) return;
    var k = e.key;
    if (cur) return playerKey(e, k);
    if (home.hidden) return;
    var t = e.target;
    if (t && t.tagName === 'BUTTON' && (k === 'Enter' || k === ' ')) return; // native button activation
    var all = rows();
    if (!all.length) return;
    var i = all.indexOf(document.activeElement), n = -1;
    if (k === 'ArrowDown' || k === 'ArrowRight' || k === 'PageDown') n = i < 0 ? 0 : Math.min(all.length - 1, i + 1);
    else if (k === 'ArrowUp' || k === 'ArrowLeft' || k === 'PageUp') n = i < 0 ? 0 : Math.max(0, i - 1);
    else if (k === 'Home') n = 0;
    else if (k === 'End') n = all.length - 1;
    else if ((k === 'Enter' || k === ' ') && i >= 0) { e.preventDefault(); openRow(all[i]); return; }
    if (n >= 0) { e.preventDefault(); all[n].focus(); }
  });
  function playerKey(e, k) {
    if (k === 'Escape' || k === 'Backspace') { e.preventDefault(); closePlayer(); return; }
    var t = e.target;
    var onRange = t && t.tagName === 'INPUT' && t.type === 'range';
    var onBtn = t && t.tagName === 'BUTTON';
    var kind = cur.item.kind;
    if (kind === 'image') {
      if (k === 'ArrowRight' || k === 'PageDown') { e.preventDefault(); stepImage(1); }
      else if (k === 'ArrowLeft' || k === 'PageUp') { e.preventDefault(); stepImage(-1); }
    } else if ((kind === 'video' || kind === 'audio') && cur.media) {
      var m = cur.media;
      if (onRange) return;
      if ((k === 'Enter' || k === ' ') && !onBtn) { e.preventDefault(); togglePlay(); }
      else if (k === 'ArrowRight') { e.preventDefault(); m.currentTime = Math.min(m.duration || 0, m.currentTime + 10); }
      else if (k === 'ArrowLeft') { e.preventDefault(); m.currentTime = Math.max(0, m.currentTime - 10); }
      else if (k === 'ArrowUp') { e.preventDefault(); m.volume = Math.min(1, m.volume + 0.1); }
      else if (k === 'ArrowDown') { e.preventDefault(); m.volume = Math.max(0, m.volume - 0.1); }
    }
  }

  load().then(schedule);
})();
