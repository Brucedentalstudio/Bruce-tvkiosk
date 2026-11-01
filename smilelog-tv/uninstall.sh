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
rm -f /usr/local/bin/smilelog-tv
# Trả lại độ phân giải mặc định trên Raspberry Pi.
CMDLINE=/boot/firmware/cmdline.txt
if [ -f "$CMDLINE" ]; then sed -i -E 's/ ?video=HDMI-A-1:[^ ]*//g' "$CMDLINE"; fi

if [ "${1:-}" = --purge ]; then
  userdel --remove smilelog-tv 2>/dev/null || true
  rm -f /etc/smilelog-tv.conf
  echo "Đã gỡ hẳn, kể cả cấu hình và phiên đăng nhập."
else
  echo "Đã gỡ dịch vụ. Còn giữ /etc/smilelog-tv.conf và /var/lib/smilelog-tv (phiên đăng nhập)."
fi
