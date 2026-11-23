#!/bin/bash
# Gỡ máy chiếu Màn TV Smilelog. Giữ cấu hình và phiên đăng nhập, trừ khi có --purge.
#   sudo ./uninstall.sh [--purge]
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Cần chạy bằng sudo" >&2; exit 1; }

for unit in /etc/systemd/system/smilelog-tv*.timer /etc/systemd/system/smilelog-tv*.service; do
  [ -e "$unit" ] || continue
  systemctl disable --now "$(basename "$unit")" 2>/dev/null || true
  rm -f "$unit"
done
# Cả hai unit smilelog-tv-drive-sync.* đã nằm trong vòng lặp trên; gỡ thêm drop-in thứ tự khởi động của Trình chiếu.
rm -f /etc/systemd/system/smilelog-tv.service.d/media.conf
rmdir /etc/systemd/system/smilelog-tv.service.d 2>/dev/null || true
systemctl daemon-reload
systemctl enable getty@tty1.service 2>/dev/null || true
rm -f /usr/local/bin/smilelog-tv /usr/local/bin/smilelog-tv-control /usr/local/bin/smilelog-tv-desktop
rm -f /usr/local/bin/smilelog-tv-media
rm -rf /var/cache/smilelog-tv/media
rm -f /etc/udev/rules.d/99-smilelog-tv-usb.rules /usr/local/share/applications/smilelog-tv-*.desktop
rm -f /etc/chromium/policies/managed/smilelog-tv.json /etc/chromium-browser/policies/managed/smilelog-tv.json
udevadm control --reload 2>/dev/null || true
if [ -f /etc/dconf/db/local.d/00-smilelog-tv ]; then
  rm -f /etc/dconf/db/local.d/00-smilelog-tv
  dconf update 2>/dev/null || true
fi
# Trả lại màn đăng nhập Ubuntu như trước khi cài.
if [ -f /etc/gdm3/custom.conf.smilelog-tv.bak ]; then
  mv /etc/gdm3/custom.conf.smilelog-tv.bak /etc/gdm3/custom.conf
fi
for dm in gdm3.service gdm.service; do
  if systemctl cat "$dm" >/dev/null 2>&1; then systemctl enable "$dm" 2>/dev/null || true; break; fi
done
rm -rf /usr/local/share/smilelog-tv
# Trả lại độ phân giải mặc định trên Raspberry Pi.
CMDLINE=/boot/firmware/cmdline.txt
if [ -f "$CMDLINE" ]; then sed -i -E 's/ ?video=HDMI-A-1:[^ ]*//g' "$CMDLINE"; fi

if [ "${1:-}" = --purge ]; then
  # File Trình chiếu của người dùng (MEDIA_DIR, có thể nằm ngoài thư mục của tài khoản kiosk).
  MEDIA_DIR=$(grep '^MEDIA_DIR=' /etc/smilelog-tv.conf 2>/dev/null | tail -n 1 | cut -d= -f2- | tr -d "\"'" || true)
  MEDIA_DIR=$(realpath -m -- "${MEDIA_DIR:-/var/lib/smilelog-tv/media}" 2>/dev/null || true)
  # Chỉ xoá khi sâu từ 3 cấp trở lên và nằm dưới /var/lib/smilelog-tv/ hoặc /srv/.
  case "$MEDIA_DIR" in
    /var/lib/smilelog-tv/?*|/srv/?*/?*) rm -rf -- "$MEDIA_DIR" ;;
    *) echo "Bỏ qua xoá MEDIA_DIR ('$MEDIA_DIR'): đường dẫn không an toàn" >&2 ;;
  esac
  userdel --remove smilelog-tv 2>/dev/null || true
  rm -f /etc/smilelog-tv.conf /etc/smilelog-tv.token /etc/smilelog-tv.tailscale-key /etc/smilelog-tv.rustdesk-password /etc/smilelog-tv.drive-sa.json
  echo "Tailscale, RustDesk vẫn giữ để còn vào máy từ xa; gỡ hẳn: sudo apt-get purge tailscale rustdesk"
  userdel --remove daotao 2>/dev/null || true
  echo "Đã gỡ hẳn, kể cả cấu hình và phiên đăng nhập."
else
  echo "Đã gỡ dịch vụ. Còn giữ /etc/smilelog-tv.conf và /var/lib/smilelog-tv (phiên đăng nhập)."
fi
