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
systemctl daemon-reload
systemctl enable getty@tty1.service 2>/dev/null || true
rm -f /usr/local/bin/smilelog-tv /usr/local/bin/smilelog-tv-control /usr/local/bin/smilelog-tv-desktop
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
  userdel --remove smilelog-tv 2>/dev/null || true
  rm -f /etc/smilelog-tv.conf /etc/smilelog-tv.token /etc/smilelog-tv.tailscale-key
  echo "Tailscale vẫn giữ để còn vào máy từ xa; gỡ hẳn: sudo apt-get purge tailscale"
  userdel --remove daotao 2>/dev/null || true
  echo "Đã gỡ hẳn, kể cả cấu hình và phiên đăng nhập."
else
  echo "Đã gỡ dịch vụ. Còn giữ /etc/smilelog-tv.conf và /var/lib/smilelog-tv (phiên đăng nhập)."
fi
