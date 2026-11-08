// Nhận lệnh từ nút nổi (content.js) và chuyển cho smilelog-tv-control trên chính máy này.
// Token nằm trong token.json của tiện ích: trang web không đọc được, nên chỉ nút này gọi được.
const BASE = 'http://127.0.0.1:9333';
const ACTIONS = { mode: 'GET', toggle: 'POST', restart: 'POST' };
const token = fetch(chrome.runtime.getURL('token.json')).then((r) => r.json()).then((j) => j.token);

chrome.runtime.onMessage.addListener((msg, sender, reply) => {
  // Tab mở thêm (ví dụ "Xem 3D"): kiosk không có thanh tab, nên tabs.js hỏi có cần nút Đóng không.
  if (msg && msg.action === 'tabCount') {
    chrome.tabs.query({}, (tabs) => reply({ count: tabs.length }));
    return true;
  }
  if (msg && msg.action === 'closeTab' && sender.tab) {
    chrome.tabs.remove(sender.tab.id);
    return false;
  }
  const method = msg && /^mode\/(tv|full|training)$/.test(msg.action) ? 'POST' : ACTIONS[msg && msg.action];
  if (!method) return false;
  (async () => {
    try {
      const res = await fetch(`${BASE}/${msg.action}`, { method, headers: { 'X-Smilelog-Token': await token } });
      reply(await res.json());
    } catch (e) {
      reply({ error: String(e) });
    }
  })();
  return true;
});
