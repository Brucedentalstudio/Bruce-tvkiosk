// Kiosk không có thanh tab: link mở tab mới (ví dụ "Xem 3D") sẽ che Smilelog mà không có đường về.
// Khi có hơn một tab, hiện nút "✕ Đóng tab này" góc trên bên phải; đóng xong quay về tab trước.
(() => {
  if (window.top !== window || document.getElementById('smilelog-tv-close-tab')) return;
  chrome.runtime.sendMessage({ action: 'tabCount' }, (r) => {
    if (!r || r.count < 2) return;
    const host = document.createElement('div');
    host.id = 'smilelog-tv-close-tab';
    host.style.cssText = 'position:fixed;right:12px;top:12px;z-index:2147483647';
    const root = host.attachShadow({ mode: 'closed' });
    root.innerHTML = `
      <style>
        button { all: initial; cursor: pointer; padding: 10px 16px; border-radius: 20px;
          background: rgba(20,20,20,.85); color: #fff; font: 600 15px system-ui, "DejaVu Sans", sans-serif;
          box-shadow: 0 4px 16px rgba(0,0,0,.35); }
        button:hover { background: #dc2626; }
      </style>
      <button title="Đóng tab này và quay về Smilelog">✕ Đóng tab này</button>`;
    root.querySelector('button').addEventListener('click', () => chrome.runtime.sendMessage({ action: 'closeTab' }));
    document.documentElement.appendChild(host);
  });
})();
