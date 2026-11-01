#!/bin/bash
# Cài máy chiếu Màn TV Smilelog lên Raspberry Pi OS / Debian / Ubuntu.
# Chạy lại được nhiều lần: sửa /etc/smilelog-tv.conf rồi chạy lại để áp dụng.
#   sudo ./install.sh
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
CONF=/etc/smilelog-tv.conf
UNITS=/etc/systemd/system
KIOSK_USER=smilelog-tv

[ "$(id -u)" -eq 0 ] || { echo "Cần chạy bằng sudo" >&2; exit 1; }
command -v apt-get >/dev/null || { echo "Chỉ hỗ trợ hệ Debian (Raspberry Pi OS, Debian, Ubuntu)" >&2; exit 1; }

echo "==> Cài gói"
apt-get update -q
if apt-cache show chromium >/dev/null 2>&1; then BROWSER_PKG=chromium; else BROWSER_PKG=chromium-browser; fi
DEBIAN_FRONTEND=noninteractive apt-get install -y -q cage "$BROWSER_PKG" jq curl v4l-utils

echo "==> Cấu hình"
[ -f "$CONF" ] || install -m 644 "$HERE/smilelog-tv.conf.example" "$CONF"
# shellcheck source=smilelog-tv.conf.example
. "$CONF"
install -m 755 "$HERE/smilelog-tv" /usr/local/bin/smilelog-tv

echo "==> Tài khoản chạy kiosk"
id "$KIOSK_USER" >/dev/null 2>&1 ||
  useradd --system --create-home --home-dir /var/lib/smilelog-tv --shell /usr/sbin/nologin "$KIOSK_USER"
for g in video render input; do
  getent group "$g" >/dev/null && usermod -aG "$g" "$KIOSK_USER"
done

echo "==> Dịch vụ systemd"
cat >"$UNITS/smilelog-tv.service" <<EOF
[Unit]
Description=Smilelog Màn TV (kiosk)
After=systemd-user-sessions.service network-online.target
Wants=network-online.target
Conflicts=getty@tty1.service
After=getty@tty1.service

[Service]
User=$KIOSK_USER
PAMName=login
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty-fail
StandardOutput=journal
StandardError=journal
UtmpIdentifier=tty1
UtmpMode=user
Environment=XDG_SESSION_TYPE=wayland
ExecStart=/usr/bin/cage -s -- /usr/local/bin/smilelog-tv browser
Restart=always
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

cat >"$UNITS/smilelog-tv-watchdog.service" <<EOF
[Unit]
Description=Smilelog Màn TV: giám sát

[Service]
Type=oneshot
ExecStart=/usr/local/bin/smilelog-tv watchdog
EOF

cat >"$UNITS/smilelog-tv-watchdog.timer" <<EOF
[Unit]
Description=Smilelog Màn TV: giám sát mỗi phút

[Timer]
OnBootSec=2min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
EOF

# Timer theo giờ trong file cấu hình. Giá trị trống thì gỡ timer tương ứng.
schedule() { # tên, giờ HH:MM, lệnh, mô tả
  local name=$1 at=$2 cmd=$3 desc=$4 cal="*-*-* $2:00"
  # Khởi động lại chạy mọi đêm; bật/tắt TV chỉ chạy vào SCREEN_DAYS.
  if [ "$name" != reboot ] && [ -n "${SCREEN_DAYS:-}" ]; then cal="$SCREEN_DAYS $cal"; fi
  if [ -z "$at" ]; then
    systemctl disable --now "smilelog-tv-$name.timer" 2>/dev/null || true
    rm -f "$UNITS/smilelog-tv-$name.service" "$UNITS/smilelog-tv-$name.timer"
    return
  fi
  cat >"$UNITS/smilelog-tv-$name.service" <<EOF
[Unit]
Description=Smilelog Màn TV: $desc

[Service]
Type=oneshot
ExecStart=$cmd
EOF
  cat >"$UNITS/smilelog-tv-$name.timer" <<EOF
[Unit]
Description=Smilelog Màn TV: $desc lúc $at

[Timer]
OnCalendar=$cal

[Install]
WantedBy=timers.target
EOF
  systemctl daemon-reload
  systemctl enable --now "smilelog-tv-$name.timer"
}

systemctl daemon-reload
systemctl disable getty@tty1.service 2>/dev/null || true
systemctl set-default graphical.target
systemctl enable smilelog-tv.service smilelog-tv-watchdog.timer
systemctl start smilelog-tv-watchdog.timer

if [ -e /dev/cec0 ]; then
  schedule screen-on "${SCREEN_ON:-}" "/usr/local/bin/smilelog-tv screen on" "bật TV"
  schedule screen-off "${SCREEN_OFF:-}" "/usr/local/bin/smilelog-tv screen off" "tắt TV"
else
  echo "    Không thấy /dev/cec0: bỏ qua hẹn giờ bật/tắt TV (cần Raspberry Pi)."
  schedule screen-on "" "" ""
  schedule screen-off "" "" ""
fi
schedule reboot "${REBOOT_AT:-}" "/bin/systemctl reboot" "khởi động lại"

systemctl restart smilelog-tv.service

cat <<EOF

Xong. TV đang mở: $TV_URL

Việc còn lại:
  1. Đăng nhập Smilelog một lần trên TV (cắm bàn phím USB, hoặc làm từ xa: xem README).
  2. Kiểm tra: sudo smilelog-tv status
  3. Khởi động lại máy để chắc chắn nó tự vào Màn TV: sudo reboot
EOF
