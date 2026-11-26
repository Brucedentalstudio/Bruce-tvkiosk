// Nút nổi góc dưới bên trái: bấm để mở bảng, bấm lần nữa để xác nhận đổi chế độ.
// Hai bước để người đi ngang không đổi nhầm. Bảng tự đóng sau 8 giây.
(() => {
  if (window.top !== window || document.getElementById('smilelog-tv-switch')) return;

  const LABEL = { full: 'Kho việc (màn chính)', tv: 'Màn TV sản xuất', training: 'Đào tạo (Ubuntu, LibreOffice)', media: 'Trình chiếu' };
  const host = document.createElement('div');
  host.id = 'smilelog-tv-switch';
  host.style.cssText = 'position:fixed;left:12px;bottom:12px;z-index:2147483647';
  const root = host.attachShadow({ mode: 'closed' });
  root.innerHTML = `
    <style>
      :host { all: initial; }
      * { box-sizing: border-box; font: 500 14px/1.3 system-ui, "DejaVu Sans", sans-serif; }
      .pill { width: 36px; height: 36px; border-radius: 18px; border: 0; cursor: pointer;
        background: rgba(30,30,30,.55); color: #fff; font-size: 18px; opacity: .35; transition: opacity .2s; }
      .pill:hover, .pill:focus { opacity: 1; }
      .panel { display: none; width: 300px; padding: 12px; border-radius: 12px;
        background: rgba(20,20,20,.92); color: #eee; box-shadow: 0 6px 24px rgba(0,0,0,.4); }
      .open .panel { display: block; } .open .pill { display: none; }
      .now { color: #aaa; font-size: 12px; margin-bottom: 8px; }
      .now b { font-weight: 700; color: #fff; }
      button.act { display: block; width: 100%; margin-top: 6px; padding: 10px; border: 0; border-radius: 8px;
        cursor: pointer; background: #3b3b3b; color: #fff; text-align: left; }
      button.main { background: #2563eb; }
      .msg { margin-top: 8px; font-size: 12px; color: #fbbf24; }
    </style>
    <div class="wrap">
      <button class="pill" title="Đổi chế độ màn hình (Ctrl+Alt+M)" aria-label="Đổi chế độ màn hình">⇄</button>
      <div class="panel" role="dialog" aria-label="Đổi chế độ màn hình">
        <div class="now">Đang chạy: <b class="cur">…</b></div>
        <div class="targets"></div>
        <button class="act restart">Mở lại trình duyệt</button>
        <button class="act close">Đóng</button>
        <div class="msg" hidden></div>
      </div>
    </div>`;
  const $ = (s) => root.querySelector(s);
  const wrap = $('.wrap');
  const msg = $('.msg');
  let timer;

  const send = (action) => new Promise((ok) => chrome.runtime.sendMessage({ action }, (r) => ok(r || {})));
  const close = () => { wrap.classList.remove('open'); msg.hidden = true; clearTimeout(timer); };
  const say = (text) => { msg.textContent = text; msg.hidden = false; };

  const openPanel = async () => {
    wrap.classList.add('open');
    clearTimeout(timer);
    timer = setTimeout(close, 8000);
    const r = await send('mode');
    if (r.error || !r.mode) {
      $('.cur').textContent = 'không rõ';
      say('Không liên lạc được dịch vụ điều khiển trên máy.');
      return;
    }
    $('.cur').textContent = LABEL[r.mode] || r.mode;
    const targets = $('.targets');
    targets.textContent = '';
    // Kho việc là màn chính: nút "Chuyển sang Kho việc" luôn đứng đầu.
    const order = (m) => (m === 'full' ? 0 : 1);
    for (const m of (r.modes || ['full', 'tv']).filter((x) => x !== r.mode).sort((a, b) => order(a) - order(b))) {
      const b = document.createElement('button');
      b.className = 'act main';
      b.textContent = `Chuyển sang ${LABEL[m] || m}`;
      b.addEventListener('click', async () => {
        const res = await send(`mode/${m}`);
        say(res.ok ? 'Đang chuyển, màn hình sẽ đổi trong vài giây…' : res.error ? 'Không chuyển được.' : 'Vừa chuyển xong, chờ vài giây.');
      });
      targets.appendChild(b);
    }
  };
  $('.pill').addEventListener('click', openPanel);
  $('.restart').addEventListener('click', async () => {
    const r = await send('restart');
    say(r.ok ? 'Đang mở lại trình duyệt…' : 'Không mở lại được.');
  });
  $('.close').addEventListener('click', close);

  // Tiện ích luôn chạy (để chống lưu ảnh); SHOW_SWITCH_BUTTON="no" thì chỉ ẩn nút.
  send('settings').then((s) => {
    if (s.switch_button === false) return;
    document.documentElement.appendChild(host);
    // Trang Trình chiếu (http://127.0.0.1:<cổng>) nhờ mở bảng này qua postMessage; trang Smilelog không đổi gì.
    // Nút bị ẩn thì không báo sẵn sàng: trang Trình chiếu tự hiện gợi ý Ctrl+Alt+M.
    if (location.protocol === 'http:' && location.hostname === '127.0.0.1') {
      window.addEventListener('message', (e) => {
        if (e.origin === location.origin && e.source === window && e.data && e.data.type === 'smilelog-tv:open-switch-panel') openPanel();
      });
      window.postMessage({ type: 'smilelog-tv:switch-panel-ready' }, location.origin);
    }
  });
})();

// Chống lưu ảnh cho màn hình sáng 24/7 và xoay bước Kho việc. Giá trị lấy từ /etc/smilelog-tv.conf qua
// dịch vụ trên máy (đã kiểm tra ở đó), đọc lại mỗi phút; dịch vụ không trả lời thì mọi tính năng tắt.
(() => {
  if (window.top !== window || window.smilelogTvBurnin) return;
  window.smilelogTvBurnin = { touched: () => touched.size }; // thế giới riêng của tiện ích, trang không thấy
  const IDLE_MS = 120000; // có người chạm trong 2 phút qua thì không hiện màn chờ, không xoay bước
  const Z = 2147483646;
  let cfg = {};
  let lastInput = Date.now();
  let lastShift = Date.now();
  let lastSaver = Date.now();
  let lastRotate = Date.now();
  let step = 0;
  let saver = null;
  let saverUntil = 0;
  let dim = null;
  let lastXY = '';
  let fmt = null;
  const touched = new Map(); // phần tử đã dời -> style gốc, để trả lại khi tắt

  const send = (action) => new Promise((ok) => {
    try {
      chrome.runtime.sendMessage({ action }, (r) => ok((!chrome.runtime.lastError && r) || {}));
    } catch (e) {
      ok({});
    }
  });
  const on = () => !!cfg.mode && cfg.mode !== 'training';
  // Trang Trình chiếu: chỉ chống lưu ảnh ở danh sách file; đang phát (video, slide, ảnh) thì tắt hết, không phủ màn chờ.
  const mediaPage = location.protocol === 'http:' && location.hostname === '127.0.0.1';
  const playing = () => { const p = mediaPage && document.getElementById('player'); return !!p && !p.hidden; };
  const idle = () => Date.now() - lastInput >= IDLE_MS;

  // 1. Dời cả trang vài điểm ảnh. Không dùng transform trên html/body: phần tử fixed (thanh trên, menu)
  // sẽ trôi theo trang khi cuộn. Phần cuộn theo trang dời bằng position:relative, phần tử fixed dời bằng
  // thuộc tính translate (cộng thêm vào transform sẵn có). Chỉ dời lên và sang trái: không sinh thanh cuộn.
  const remember = (el, props) => {
    if (!touched.has(el)) touched.set(el, Object.fromEntries(props.map((p) => [p, el.style[p]])));
  };
  function shift(dx, dy) {
    if (!document.body) return;
    for (const el of touched.keys()) if (!el.isConnected) touched.delete(el); // hộp thoại, thông báo đã đóng
    for (const el of document.body.children) {
      const { position: pos, display } = getComputedStyle(el);
      if (display === 'none' || !(pos === 'static' || (pos === 'relative' && touched.has(el)))) continue;
      remember(el, ['position', 'left', 'top']);
      Object.assign(el.style, { position: 'relative', left: `${dx}px`, top: `${dy}px` });
    }
    for (const el of document.body.querySelectorAll('*')) {
      const cs = getComputedStyle(el);
      if (cs.position !== 'fixed' || (cs.translate !== 'none' && !touched.has(el))) continue;
      remember(el, ['translate']);
      el.style.translate = `${dx}px ${dy}px`;
    }
  }
  function unshift() {
    for (const [el, orig] of touched) Object.assign(el.style, orig);
    touched.clear();
  }

  // 2. Màn chờ đồng hồ (giống screensaver.html) phủ lên trang, không tải lại trang nên Kho việc giữ nguyên.
  function showSaver() {
    saver = document.createElement('div');
    saver.id = 'smilelog-tv-saver';
    saver.style.cssText = `position:fixed;inset:0;z-index:${Z};background:#000;cursor:none`;
    const root = saver.attachShadow({ mode: 'closed' });
    root.innerHTML = `<style>
        #b { position: absolute; text-align: center; color: #7a7a7a; transition: opacity 1.5s ease;
          font-family: system-ui, "DejaVu Sans", sans-serif; }
        #t { font-size: 14vw; font-weight: 200; line-height: 1; }
        #d { font-size: 2.6vw; margin-top: 1.2vw; font-weight: 300; }
      </style><div id="b"><div id="t"></div><div id="d"></div></div>`;
    const b = root.getElementById('b');
    // Múi giờ trình duyệt không biết thì dùng giờ của máy, không để lỗi làm màn chờ chớp tắt.
    const local = (fn, opts) => {
      try {
        return fn({ ...opts, timeZone: cfg.timezone || undefined });
      } catch (e) {
        return fn(opts);
      }
    };
    const draw = () => {
      const now = new Date();
      saver.drawn = Date.now();
      root.getElementById('t').textContent = local((o) => now.toLocaleTimeString('vi-VN', o), { hour: '2-digit', minute: '2-digit', hour12: false });
      const d = local((o) => now.toLocaleDateString('vi-VN', o), { weekday: 'long', day: 'numeric', month: 'numeric', year: 'numeric' });
      root.getElementById('d').textContent = d.charAt(0).toUpperCase() + d.slice(1);
      b.style.left = `${Math.round(Math.random() * Math.max(0, innerWidth - b.offsetWidth))}px`;
      b.style.top = `${Math.round(Math.random() * Math.max(0, innerHeight - b.offsetHeight))}px`;
    };
    saver.draw = () => { try { draw(); } catch (e) { /* vẫn giữ màn chờ đen tới hết giờ */ } };
    saverUntil = Date.now() + cfg.saver_sec * 1000;
    lastSaver = Date.now();
    // Chạm vào màn chờ chỉ để tắt nó, không bấm xuyên xuống nút bên dưới: giữ lớp phủ tới hết cú bấm.
    saver.addEventListener('click', () => removeSaver());
    document.documentElement.appendChild(saver);
    saver.draw();
  }
  function removeSaver() {
    if (saver) saver.remove();
    saver = null;
  }
  function hideSaver(byPointer) {
    if (!saver) return;
    if (!byPointer) return removeSaver();
    const s = saver;
    s.style.opacity = '0';
    setTimeout(() => { s.remove(); if (saver === s) saver = null; }, 1500);
  }

  // Có người dùng: chuột di chuyển thật, bấm, chạm, phím, cuộn. Chuột đứng yên mà trang đổi thì không tính.
  const onInput = (e) => {
    if (e.type === 'pointermove') {
      const xy = `${e.screenX},${e.screenY}`;
      const first = !lastXY;
      if (xy === lastXY) return;
      lastXY = xy;
      if (first) return;
    }
    // Phím luôn đi tiếp xuống trang (máy quét mã vạch gõ như bàn phím, không được mất ký tự đầu); có phím
    // thì cũng dừng xoay bước 2 phút, nên không đổi trang giữa lúc đang quét.
    lastInput = Date.now();
    if (saver && saver.style.opacity !== '0') hideSaver(e.type !== 'keydown');
  };
  addEventListener('keydown', onInput, true);
  for (const t of ['pointerdown', 'pointermove', 'touchstart', 'wheel']) addEventListener(t, onInput, { capture: true, passive: true });

  // 3. Làm tối ban đêm: lớp đen mờ không nhận bấm, trang vẫn đọc và bấm được.
  function hhmm() {
    try {
      if (!fmt || fmt.tz !== cfg.timezone) {
        fmt = new Intl.DateTimeFormat('en-GB', { timeZone: cfg.timezone || undefined, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
        fmt.tz = cfg.timezone;
      }
      return fmt.format(new Date());
    } catch (e) {
      fmt = null;
      return new Date().toTimeString().slice(0, 5);
    }
  }
  function nightNow() {
    const s = cfg.dim_start;
    const e = cfg.dim_end;
    if (!s || !e || !cfg.dim_level) return false;
    const n = hhmm();
    return s < e ? n >= s && n < e : n >= s || n < e; // qua đêm khi giờ bắt đầu lớn hơn giờ kết thúc
  }
  function setDim(want) {
    if (want && !dim) {
      dim = document.createElement('div');
      dim.id = 'smilelog-tv-dim';
      document.documentElement.appendChild(dim);
    }
    if (want) dim.style.cssText = `position:fixed;inset:0;z-index:${Z - 1};background:#000;opacity:${cfg.dim_level};pointer-events:none`;
    if (!want && dim) { dim.remove(); dim = null; }
  }

  // 4. Xoay bước Kho việc (#/kho-viec?stage=KEY). Vue Router: đổi URL tại chỗ rồi báo popstate để trang tự lọc lại,
  // không tải lại trang. Trang không có Vue Router thì mở lại URL (replace, không làm dài lịch sử).
  // Chỉ xoay qua bước máy chủ có cho tài khoản này (cùng danh sách chip của Kho việc), theo thứ tự trong
  // cấu hình; hỏi lại mỗi 10 phút. Không hỏi được thì dùng nguyên danh sách cấu hình.
  let offered = null;
  let offeredAt = -Infinity;
  function refreshOffered() {
    offeredAt = Date.now();
    const headers = { 'X-Requested-With': 'XMLHttpRequest' };
    try {
      const lab = localStorage.getItem('app-lab-id');
      if (lab) headers['X-Lab-Id'] = lab;
    } catch (e) { /* không đọc được localStorage: bỏ qua */ }
    fetch('/api/work-queue/by-stage?pageSize=1', { credentials: 'include', headers })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((j) => {
        const stages = (j && (j.stages || (j.data && j.data.stages))) || null;
        offered = Array.isArray(stages) ? stages.map((s) => String(s && s.key)) : null;
      })
      .catch(() => { offered = null; });
  }
  function rotationList() {
    const conf = cfg.rotate_stages || [];
    if (!offered) return conf;
    return conf.map((k) => offered.find((o) => o.toUpperCase() === k.toUpperCase())).filter(Boolean);
  }
  // Route của trang: Smilelog để route sau dấu # (https://smilelog.vn/#/kho-viec?stage=CAD), nên đường dẫn
  // và tham số nằm trong location.hash; trang dùng đường dẫn thường thì lấy pathname và search như cũ.
  function route() {
    const hashed = location.hash.startsWith('#/');
    const r = new URL(hashed ? location.hash.slice(1) : location.pathname + location.search, location.origin);
    return {
      path: r.pathname,
      params: r.searchParams,
      href() {
        const q = r.searchParams.toString();
        const tail = r.pathname + (q ? `?${q}` : '');
        return hashed ? `${location.pathname}${location.search}#${tail}` : tail + location.hash;
      },
    };
  }
  function rotate() {
    const list = rotationList();
    lastRotate = Date.now();
    if (!list.length) return;
    const r = route();
    const cur = (r.params.get('stage') || '').toUpperCase();
    r.params.set('stage', list[(list.findIndex((k) => k.toUpperCase() === cur) + 1) % list.length]);
    r.params.delete('holder'); // như khi bấm chip: đổi bước thì bỏ người giữ
    const url = r.href();
    if (history.state && typeof history.state === 'object' && 'position' in history.state) {
      history.replaceState(null, '', url);
      dispatchEvent(new PopStateEvent('popstate', { state: null }));
    } else {
      location.replace(url);
    }
  }

  // 5. Trang đăng nhập mà phiên vẫn còn. Smilelog có lúc về trang đăng nhập dù cookie phiên còn hạn, và
  // tài khoản chỉ xem (bot TV) khi đó không đăng nhập lại được: máy chủ chặn POST /api/auth/token của tài
  // khoản read-only đang có cookie (403). Đứng ở trang đăng nhập, không ai dùng 2 phút: hỏi /api/me, phiên
  // còn thì tải lại trang định tới (redirectUrl); phiên hết thật thì để yên chờ người đăng nhập.
  // Mỗi tab tải lại tối đa một lần mỗi 10 phút, để không tải lại mãi nếu trang vẫn quay về đăng nhập.
  let lastLoginCheck = -Infinity;
  function resumeSession() {
    lastLoginCheck = Date.now();
    fetch('/api/me', { credentials: 'include' })
      .then((r) => {
        if (!r.ok || route().path !== '/auth/login') return;
        const KEY = 'smilelog-tv-resumed-at';
        if (Date.now() - Number(sessionStorage.getItem(KEY) || 0) < 600000) return;
        sessionStorage.setItem(KEY, String(Date.now()));
        const back = route().params.get('redirectUrl') || '/';
        history.replaceState(null, '', `${location.pathname}${location.search}#${back.startsWith('/') ? back : '/'}`);
        location.reload();
      })
      .catch(() => {});
  }

  function tick() {
    const now = Date.now();
    if (!on() || playing()) {
      unshift();
      removeSaver();
      setDim(false);
      return;
    }
    if (!mediaPage && idle() && now - lastLoginCheck >= 30000 && route().path === '/auth/login') resumeSession();
    if (cfg.shift_min && cfg.shift_px) {
      if (now - lastShift >= cfg.shift_min * 60000) {
        const p = cfg.shift_px;
        const h = Math.round(p / 2);
        const at = [[0, 0], [-h, 0], [-p, 0], [-p, -h], [-p, -p], [-h, -p], [0, -p], [0, -h]][++step % 8];
        shift(at[0], at[1]);
        lastShift = now;
      }
    } else if (touched.size) {
      unshift();
    }
    if (saver) {
      if (now >= saverUntil || !cfg.saver_sec) hideSaver(false);
      else if (now - saver.drawn >= 15000) saver.draw();
    } else if (cfg.saver_every_min && cfg.saver_sec && now - lastSaver >= cfg.saver_every_min * 60000 && idle()) {
      showSaver(); // vừa có người dùng thì hoãn, hiện ngay khi rảnh 2 phút
    }
    setDim(nightNow());
    const kho = /^\/kho-viec\/?$/.test(route().path);
    if (cfg.mode === 'full' && kho && cfg.rotate_sec && cfg.rotate_stages && cfg.rotate_stages.length) {
      // Màn chờ đang hiện: dừng, sau đó bước hiện tại được chiếu đủ một lượt. Có người dùng: dừng tới khi
      // rảnh 2 phút rồi xoay tiếp từ bước đang đứng.
      if (now - offeredAt >= 600000) refreshOffered();
      if (saver) lastRotate = now;
      else if (idle() && now - lastRotate >= cfg.rotate_sec * 1000) rotate();
    }
  }

  const load = () => send('settings').then((s) => { cfg = s && !s.error ? s : {}; tick(); });
  load();
  setInterval(load, 60000);
  setInterval(tick, 1000);
})();
