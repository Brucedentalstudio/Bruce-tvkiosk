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
DEBIAN_FRONTEND=noninteractive apt-get install -y -q cage "$BROWSER_PKG" jq curl v4l-utils python3
# python3-evdev bắt phím tắt Ctrl+Alt+M / Ctrl+Alt+R; thiếu gói này thì chỉ còn nút nổi trên màn hình.
DEBIAN_FRONTEND=noninteractive apt-get install -y -q python3-evdev ||
  echo "    Không cài được python3-evdev: phím tắt sẽ không chạy, nút nổi vẫn dùng được"
# wlr-randr đổi độ phân giải ngay trong phiên kiosk; bản phân phối cũ có thể không có gói này.
DEBIAN_FRONTEND=noninteractive apt-get install -y -q wlr-randr ||
  echo "    Không cài được wlr-randr: độ phân giải chỉ đặt qua cmdline.txt"

echo "==> Cấu hình"
[ -f "$CONF" ] || install -m 644 "$HERE/smilelog-tv.conf.example" "$CONF"
# shellcheck source=smilelog-tv.conf.example
. "$CONF"
install -m 755 "$HERE/smilelog-tv" /usr/local/bin/smilelog-tv
install -D -m 644 "$HERE/screensaver.html" /usr/local/share/smilelog-tv/screensaver.html
install -m 755 "$HERE/smilelog-tv-control" /usr/local/bin/smilelog-tv-control

if [ -n "${TIMEZONE:-}" ]; then
  timedatectl set-timezone "$TIMEZONE"
  echo "    Múi giờ: $TIMEZONE"
fi

echo "==> Tài khoản chạy kiosk"
id "$KIOSK_USER" >/dev/null 2>&1 ||
  useradd --system --create-home --home-dir /var/lib/smilelog-tv --shell /usr/sbin/nologin "$KIOSK_USER"
for g in video render input; do
  getent group "$g" >/dev/null && usermod -aG "$g" "$KIOSK_USER"
done

echo "==> Phím tắt và nút đổi chế độ"
# Token chỉ root và tiện ích trong trình duyệt đọc được; trang web lạ không gọi được lệnh đổi chế độ.
[ -s /etc/smilelog-tv.token ] || (umask 077 && head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' >/etc/smilelog-tv.token)
EXT=/usr/local/share/smilelog-tv/extension
install -d -m 750 -g "$KIOSK_USER" "$EXT"
install -m 640 -g "$KIOSK_USER" "$HERE/extension/background.js" "$HERE/extension/content.js" "$EXT/"
jq -n --arg t "$(cat /etc/smilelog-tv.token)" '{token: $t}' | install -m 640 -g "$KIOSK_USER" /dev/stdin "$EXT/token.json"
# Nút chỉ hiện trên các trang Smilelog: tên miền của TV_URL, APP_URL và APP_HOSTS (cả tên miền con).
hosts=$(printf '%s\n' "${TV_URL:-}" "${APP_URL:-}" | sed -nE 's#^https?://([^/:]+).*#\1#p'; tr ' ' '\n' <<<"${APP_HOSTS:-}")
matches=$(printf '%s\n' "$hosts" | sort -u | jq -R 'select(length > 0) | ("https://" + .), ("https://*." + .) | . + "/*"' | jq -s .)
jq --argjson m "$matches" '.content_scripts[0].matches = $m' "$HERE/extension/manifest.template.json" |
  install -m 640 -g "$KIOSK_USER" /dev/stdin "$EXT/manifest.json"

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

cat >"$UNITS/smilelog-tv-control.service" <<EOF
[Unit]
Description=Smilelog Màn TV: phím tắt và nút đổi chế độ

[Service]
ExecStart=/usr/local/bin/smilelog-tv-control
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
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
systemctl enable smilelog-tv.service smilelog-tv-watchdog.timer smilelog-tv-control.service
systemctl restart smilelog-tv-control.service
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

echo "==> Độ phân giải"
# Trên Raspberry Pi, tham số video= trong cmdline.txt đặt chế độ hình cho cổng HDMI0 từ lúc khởi động.
CMDLINE=/boot/firmware/cmdline.txt
NEED_REBOOT=""
if [ -f "$CMDLINE" ]; then
  [ -f "$CMDLINE.smilelog-tv.bak" ] || cp "$CMDLINE" "$CMDLINE.smilelog-tv.bak"
  old=$(cat "$CMDLINE")
  new=$(sed -E 's/ ?video=HDMI-A-1:[^ ]*//g' "$CMDLINE")
  [ -n "${RESOLUTION:-}" ] && new="$new video=HDMI-A-1:${RESOLUTION}@60"
  if [ "$new" != "$old" ]; then
    echo "$new" >"$CMDLINE"
    NEED_REBOOT=1
  fi
  echo "    ${RESOLUTION:-mặc định của TV}${NEED_REBOOT:+ (có hiệu lực sau khi khởi động lại)}"
else
  echo "    Không phải Raspberry Pi: chỉ đặt độ phân giải trong phiên kiosk (wlr-randr)"
fi

systemctl restart smilelog-tv.service

cat <<EOF

Xong. TV đang mở: $TV_URL

Việc còn lại:
  1. Đăng nhập Smilelog một lần trên TV (cắm bàn phím USB, hoặc làm từ xa: xem README).
  2. Kiểm tra: sudo smilelog-tv status
  3. Khởi động lại máy để chắc chắn nó tự vào Màn TV: sudo reboot
EOF
