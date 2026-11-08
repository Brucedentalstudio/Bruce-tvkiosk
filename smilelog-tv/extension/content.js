// Nút nổi góc dưới bên trái: bấm để mở bảng, bấm lần nữa để xác nhận đổi chế độ.
// Hai bước để người đi ngang không đổi nhầm. Bảng tự đóng sau 8 giây.
(() => {
  if (window.top !== window || document.getElementById('smilelog-tv-switch')) return;

  const LABEL = { tv: 'Màn TV', full: 'Danh sách ca & Kho việc' };
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
        <button class="act main switch">Chuyển sang …</button>
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

  $('.pill').addEventListener('click', async () => {
    wrap.classList.add('open');
    timer = setTimeout(close, 8000);
    const r = await send('mode');
    if (r.error || !r.mode) {
      $('.cur').textContent = 'không rõ';
      say('Không liên lạc được dịch vụ điều khiển trên máy.');
      return;
    }
    const next = r.mode === 'tv' ? 'full' : 'tv';
    $('.cur').textContent = LABEL[r.mode];
    $('.switch').textContent = `Chuyển sang ${LABEL[next]}`;
  });
  $('.switch').addEventListener('click', async () => {
    const r = await send('toggle');
    say(r.ok ? 'Đang chuyển, màn hình sẽ tải lại trong vài giây…' : r.error ? 'Không chuyển được.' : 'Vừa chuyển xong, chờ vài giây.');
  });
  $('.restart').addEventListener('click', async () => {
    const r = await send('restart');
    say(r.ok ? 'Đang mở lại trình duyệt…' : 'Không mở lại được.');
  });
  $('.close').addEventListener('click', close);

  document.documentElement.appendChild(host);
})();
