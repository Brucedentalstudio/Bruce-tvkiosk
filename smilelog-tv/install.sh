#!/bin/bash
# Cài máy chiếu Màn TV Smilelog lên Raspberry Pi OS / Debian / Ubuntu.
# Chạy lại được nhiều lần: sửa /etc/smilelog-tv.conf rồi chạy lại để áp dụng.
#   sudo ./install.sh                   hỏi chọn X11 / Wayland (Enter = giữ lựa chọn hiện tại)
#   sudo ./install.sh --display x11     chọn sẵn, không hỏi (x11 hoặc wayland)
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
CONF=/etc/smilelog-tv.conf
UNITS=/etc/systemd/system
KIOSK_USER=smilelog-tv

ARG_DISPLAY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --display) ARG_DISPLAY=${2:-}; shift 2 ;;
    --display=*) ARG_DISPLAY=${1#*=}; shift ;;
    *) echo "Không hiểu tham số: $1 (dùng: --display x11|wayland)" >&2; exit 2 ;;
  esac
done
case "$ARG_DISPLAY" in "" | x11 | wayland) ;; *) echo "--display chỉ nhận x11 hoặc wayland" >&2; exit 2 ;; esac

[ "$(id -u)" -eq 0 ] || { echo "Cần chạy bằng sudo" >&2; exit 1; }
command -v apt-get >/dev/null || { echo "Chỉ hỗ trợ hệ Debian (Raspberry Pi OS, Debian, Ubuntu)" >&2; exit 1; }

echo "==> Cài gói"
apt-get update -q
if apt-cache show chromium >/dev/null 2>&1; then BROWSER_PKG=chromium; else BROWSER_PKG=chromium-browser; fi
DEBIAN_FRONTEND=noninteractive apt-get install -y -q cage "$BROWSER_PKG" jq curl v4l-utils python3 git
# python3-evdev bắt phím tắt Ctrl+Alt+M / Ctrl+Alt+R; thiếu gói này thì chỉ còn nút nổi trên màn hình.
DEBIAN_FRONTEND=noninteractive apt-get install -y -q python3-evdev ||
  echo "    Không cài được python3-evdev: phím tắt sẽ không chạy, nút nổi vẫn dùng được"
# In phiếu, QR: CUPS + tự tìm máy in mạng (IPP Everywhere, không cần driver riêng).
DEBIAN_FRONTEND=noninteractive apt-get install -y -q cups cups-browsed avahi-daemon ||
  echo "    Không cài được CUPS: chưa in được"
# wlr-randr đổi độ phân giải ngay trong phiên kiosk; bản phân phối cũ có thể không có gói này.
DEBIAN_FRONTEND=noninteractive apt-get install -y -q wlr-randr ||
  echo "    Không cài được wlr-randr: độ phân giải chỉ đặt qua cmdline.txt"

echo "==> Cấu hình"
[ -f "$CONF" ] || install -m 644 "$HERE/smilelog-tv.conf.example" "$CONF"
# Máy cài từ bản cũ: thêm các tuỳ chọn mới (giá trị mặc định) mà không đụng giá trị đã sửa.
added=""
while IFS= read -r line; do
  key=${line%%=*}
  grep -q "^$key=" "$CONF" || added+="$line"$'\n'
done < <(grep -E '^[A-Z_]+=' "$HERE/smilelog-tv.conf.example")
if [ -n "$added" ]; then
  printf '\n# Tuỳ chọn mới thêm khi cập nhật (giải thích trong smilelog-tv.conf.example)\n%s' "$added" >>"$CONF"
  echo "    Đã thêm tuỳ chọn mới vào $CONF: $(echo "$added" | cut -d= -f1 | tr '\n' ' ')"
fi
# shellcheck source=smilelog-tv.conf.example
. "$CONF"
install -m 755 "$HERE/smilelog-tv" /usr/local/bin/smilelog-tv
install -D -m 644 "$HERE/screensaver.html" /usr/local/share/smilelog-tv/screensaver.html
install -m 755 "$HERE/smilelog-tv-control" /usr/local/bin/smilelog-tv-control
install -m 755 "$HERE/smilelog-tv-desktop" /usr/local/bin/smilelog-tv-desktop

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

echo "==> Cách vẽ màn hình kiosk: X11 hay Wayland"
CUR_DISPLAY=${DISPLAY_SERVER:-x11}
if [ -n "$ARG_DISPLAY" ]; then
  DISPLAY_SERVER=$ARG_DISPLAY
elif [ -t 0 ] && [ -t 1 ]; then
  cat <<EOF
    Chọn cách kiosk (Màn TV, Ca & Kho việc) vẽ màn hình. Chế độ Đào tạo không bị ảnh hưởng.

    [1] X11 (khuyên dùng, mặc định)
        + RustDesk xem và điều khiển được màn hình TV từ xa, kể cả khi trình duyệt treo, màn đen,
          nên đa số sự cố xử lý được mà không phải tới tận máy.
        - Có thể hơi xé hình khi cuộn nhanh (Màn TV chủ yếu đổi trang nên ít thấy).
    [2] Wayland
        + Khoá chặt nhất (chỉ chạy đúng một ứng dụng), hình mượt, không xé hình.
        - RustDesk KHÔNG thấy màn hình kiosk; hỗ trợ từ xa chỉ còn SSH qua Tailscale.
        Chọn khi: máy không cần điều khiển màn hình từ xa, hoặc X11 bị lỗi hiển thị trên máy này.

    Đang dùng: $CUR_DISPLAY. Đổi sau được: chạy lại install.sh và chọn lại.
EOF
  read -r -p "    Chọn 1 hoặc 2 (Enter = giữ $CUR_DISPLAY): " ans || ans=""
  case "$ans" in
    1) DISPLAY_SERVER=x11 ;;
    2) DISPLAY_SERVER=wayland ;;
    "") DISPLAY_SERVER=$CUR_DISPLAY ;;
    *) echo "    Không hiểu \"$ans\": giữ $CUR_DISPLAY"; DISPLAY_SERVER=$CUR_DISPLAY ;;
  esac
else
  # Chạy tự động (cập nhật ban đêm): không hỏi, giữ lựa chọn đã lưu.
  DISPLAY_SERVER=$CUR_DISPLAY
fi
if grep -q '^DISPLAY_SERVER=' "$CONF"; then
  sed -i "s/^DISPLAY_SERVER=.*/DISPLAY_SERVER=\"$DISPLAY_SERVER\"/" "$CONF"
else
  printf '\nDISPLAY_SERVER="%s"\n' "$DISPLAY_SERVER" >>"$CONF"
fi
echo "    Kiosk chạy: $DISPLAY_SERVER"

if [ "$DISPLAY_SERVER" = x11 ]; then
  echo "==> Kiosk chạy X11"
  # Xorg tối giản: không màn đăng nhập, không thanh tác vụ; chỉ Chromium toàn màn hình.
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q xserver-xorg xinit x11-xserver-utils unclutter matchbox-window-manager
fi

echo "==> Phím tắt và nút đổi chế độ"
# Token chỉ root và tiện ích trong trình duyệt đọc được; trang web lạ không gọi được lệnh đổi chế độ.
[ -s /etc/smilelog-tv.token ] || (umask 077 && head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' >/etc/smilelog-tv.token)
EXT=/usr/local/share/smilelog-tv/extension
install -d -m 750 -g "$KIOSK_USER" "$EXT"
install -m 640 -g "$KIOSK_USER" "$HERE/extension/background.js" "$HERE/extension/content.js" "$HERE/extension/tabs.js" "$EXT/"
jq -n --arg t "$(cat /etc/smilelog-tv.token)" '{token: $t}' | install -m 640 -g "$KIOSK_USER" /dev/stdin "$EXT/token.json"
# Nút chỉ hiện trên các trang Smilelog: tên miền của TV_URL, APP_URL và APP_HOSTS (cả tên miền con).
hosts=$(printf '%s\n' "${TV_URL:-}" "${APP_URL:-}" | sed -nE 's#^https?://([^/:]+).*#\1#p'; tr ' ' '\n' <<<"${APP_HOSTS:-}")
matches=$(printf '%s\n' "$hosts" | sort -u | jq -R 'select(length > 0) | ("https://" + .), ("https://*." + .) | . + "/*"' | jq -s .)
jq --argjson m "$matches" '.content_scripts[0].matches = $m' "$HERE/extension/manifest.template.json" |
  install -m 640 -g "$KIOSK_USER" /dev/stdin "$EXT/manifest.json"

if [ "${ENABLE_TAILSCALE:-yes}" = yes ]; then
  echo "==> Tailscale (vào máy từ xa)"
  # Cài từ kho chính thức của Tailscale; lần sau apt và tính năng tự cập nhật của Tailscale giữ bản mới.
  command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh ||
    echo "    Không cài được Tailscale: kiểm tra mạng rồi chạy lại install.sh"
  if command -v tailscale >/dev/null; then
    systemctl enable --now tailscaled
    /usr/local/bin/smilelog-tv remote up || true
  fi
fi

if [ "${ENABLE_RUSTDESK:-yes}" = yes ]; then
  echo "==> RustDesk (điều khiển màn hình từ xa)"
  /usr/local/bin/smilelog-tv rustdesk install || echo "    Chưa cài được RustDesk: chạy lại install.sh khi có mạng"
fi

echo "==> USB, tải file, tải ảnh lên"
# Cắm USB (FAT32/exFAT) là gắn vào /media/usb, mọi tài khoản đọc ghi được. Chromium hỏi chỗ lưu khi
# tải file (Xuất Excel) và mở sẵn USB; khi chọn ảnh tải lên cũng chọn từ /media/usb.
install -d /media/usb
cat >/etc/udev/rules.d/99-smilelog-tv-usb.rules <<EOF
ACTION=="add", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", ENV{ID_FS_TYPE}=="vfat|exfat", RUN{program}+="/usr/bin/systemd-mount --no-block --collect -o uid=$(id -u "$KIOSK_USER"),gid=$(id -g "$KIOSK_USER"),umask=000 \$devnode /media/usb"
ACTION=="remove", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", RUN{program}+="/usr/bin/systemd-mount --umount \$devnode"
EOF
udevadm control --reload || true
for d in /etc/chromium/policies/managed /etc/chromium-browser/policies/managed; do
  install -d "$d"
  jq -n '{PromptForDownloadLocation: true, DownloadDirectory: "/media/usb"}' >"$d/smilelog-tv.json"
done

if [ "${ENABLE_TRAINING:-no}" = yes ]; then
  echo "==> Chế độ Đào tạo (giao diện Ubuntu, LibreOffice)"
  TU=${TRAINING_USER:-daotao}
  # shellcheck source=/dev/null
  . /etc/os-release
  if [ "${ID:-}" = ubuntu ]; then DESKTOP_PKGS=(ubuntu-desktop-minimal); else DESKTOP_PKGS=(gnome-core gdm3); fi
  # RustDesk điều khiển không cần người ngồi máy chỉ chạy được trên X11: cài Xorg cho giao diện Đào tạo.
  [ "${ENABLE_RUSTDESK:-yes}" = yes ] && DESKTOP_PKGS+=(xserver-xorg)
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q "${DESKTOP_PKGS[@]}" dconf-cli \
    libreoffice-impress libreoffice-calc libreoffice-writer libreoffice-gtk3 libreoffice-l10n-vi \
    fonts-crosextra-carlito fonts-crosextra-caladea fonts-noto-core
  # Tài khoản riêng, không mật khẩu, không quyền quản trị; GDM tự đăng nhập vào đây.
  id "$TU" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash --comment "Dao tao" "$TU"
  passwd -d "$TU" >/dev/null
  GDMCONF=/etc/gdm3/custom.conf
  [ -f "$GDMCONF" ] && [ ! -f "$GDMCONF.smilelog-tv.bak" ] && cp "$GDMCONF" "$GDMCONF.smilelog-tv.bak"
  install -d /etc/gdm3
  # Có RustDesk thì giao diện Đào tạo chạy X11 (WaylandEnable=false) để RustDesk xem và điều khiển được.
  if [ "${ENABLE_RUSTDESK:-yes}" = yes ]; then WAYLAND=false; else WAYLAND=true; fi
  printf '[daemon]\nAutomaticLoginEnable=true\nAutomaticLogin=%s\nWaylandEnable=%s\n\n[security]\n\n[xdmcp]\n\n[chooser]\n\n[debug]\n' "$TU" "$WAYLAND" >"$GDMCONF"
  # Biểu tượng trên thanh bên trái: Microsoft 365, Google Drive, LibreOffice, File, hai nút quay về.
  APPS=/usr/local/share/applications
  install -d "$APPS"
  launcher() { # tên file, tiêu đề, lệnh, biểu tượng
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nIcon=%s\nTerminal=false\n' "$2" "$3" "$4" >"$APPS/$1.desktop"
  }
  launcher smilelog-tv-ms365 "Microsoft 365 (PowerPoint, Excel)" "smilelog-tv-desktop open https://www.office.com" web-browser
  launcher smilelog-tv-gdrive "Google Drive" "smilelog-tv-desktop open https://drive.google.com" web-browser
  launcher smilelog-tv-back-tv "Quay về Màn TV" "smilelog-tv-desktop switch tv" video-display
  launcher smilelog-tv-back-full "Quay về Ca & Kho việc" "smilelog-tv-desktop switch full" view-list
  # Thiết lập chung: thanh biểu tượng, không khoá màn hình, không tự ngủ khi đang trình chiếu.
  install -d /etc/dconf/profile /etc/dconf/db/local.d
  if [ ! -f /etc/dconf/profile/user ]; then
    printf 'user-db:user\nsystem-db:local\n' >/etc/dconf/profile/user
  elif ! grep -q '^system-db:local' /etc/dconf/profile/user; then
    echo 'system-db:local' >>/etc/dconf/profile/user
  fi
  cat >/etc/dconf/db/local.d/00-smilelog-tv <<'EOF'
[org/gnome/shell]
favorite-apps=['smilelog-tv-ms365.desktop', 'smilelog-tv-gdrive.desktop', 'libreoffice-impress.desktop', 'libreoffice-calc.desktop', 'org.gnome.Nautilus.desktop', 'smilelog-tv-back-full.desktop', 'smilelog-tv-back-tv.desktop']

[org/gnome/desktop/screensaver]
lock-enabled=false

[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
EOF
  dconf update
fi

echo "==> Dịch vụ systemd"
if [ "$DISPLAY_SERVER" = x11 ]; then
  KIOSK_SESSION_TYPE=x11
  # Xorg chạy bằng tài khoản kiosk trên tty1 (phiên logind), không cần quyền root.
  KIOSK_EXEC="/usr/bin/xinit /usr/local/bin/smilelog-tv x11-session -- /usr/bin/Xorg :0 vt1 -keeptty -nolisten tcp -s 0 -dpms"
else
  KIOSK_SESSION_TYPE=wayland
  KIOSK_EXEC="/usr/bin/cage -s -- /usr/local/bin/smilelog-tv browser"
fi
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
Environment=XDG_SESSION_TYPE=$KIOSK_SESSION_TYPE
ExecStart=$KIOSK_EXEC
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
  # Khởi động lại, cập nhật chạy mọi đêm; bật/tắt TV chỉ chạy vào SCREEN_DAYS.
  if [ "$name" != reboot ] && [ "$name" != update ] && [ -n "${SCREEN_DAYS:-}" ]; then cal="$SCREEN_DAYS $cal"; fi
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
schedule update "${AUTO_UPDATE_AT-02:30}" "/usr/local/bin/smilelog-tv update" "cập nhật từ GitHub"

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

# Bật kiosk hoặc giao diện Đào tạo theo MODE; tắt màn đăng nhập Ubuntu khi chạy kiosk để hai bên
# không giành màn hình.
/usr/local/bin/smilelog-tv apply

cat <<EOF

Xong. TV đang mở: $TV_URL

Việc còn lại:
  1. Đăng nhập Smilelog một lần trên TV (cắm bàn phím USB, hoặc làm từ xa: xem README).
  2. Kiểm tra: sudo smilelog-tv status
  3. Khởi động lại máy để chắc chắn nó tự vào Màn TV: sudo reboot
EOF
