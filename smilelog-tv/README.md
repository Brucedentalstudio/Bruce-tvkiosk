# Smilelog TV: máy chiếu Màn TV sản xuất

Biến một máy tính nhỏ cắm vào cổng HDMI của TV thành màn hình kiosk chạy Smilelog. Bật điện là
tự vào Smilelog, mất điện hay trình duyệt treo thì tự hồi phục.

## Ba chế độ

| | `tv` | `full` (mặc định, màn chính Kho việc) | `training` (Đào tạo) |
|---|---|---|---|
| Dùng cho | TV treo xưởng, chỉ để xem | Máy trạm ở quầy, bàn điều phối | Đào tạo nội bộ, slide đơn giản |
| Màn hình | Màn TV (`/production-tv`) | **Danh sách ca** (`/orders`) và **Kho việc** (`/kho-viec`), kể cả trang con | Giao diện Ubuntu bình thường: LibreOffice, Chromium, mở file từ USB |
| Bấm sang màn khác | Sau 2 phút tự quay về Màn TV | Sau 2 phút tự quay về `APP_URL` | Tự do |
| Trang đăng nhập | Báo động: TV bị văng phiên | Báo động một lần, không mở lại trình duyệt | Không áp dụng |
| Ngoài giờ làm (chỉ khi đặt `WORK_START`/`WORK_END`; mặc định Màn TV 24/7) | Màn chờ đồng hồ | Không có màn chờ | Không khoá, không tự ngủ |
| Tài khoản | Tài khoản Smilelog chỉ được xem | Tài khoản Smilelog của từng người | Tài khoản máy `daotao`, không mật khẩu, không quyền quản trị |

**Chế độ Đào tạo** phải bật riêng, vì tải thêm khoảng 1-2 GB (giao diện GNOME, LibreOffice, phông chữ):
đặt `ENABLE_TRAINING="yes"` trong `/etc/smilelog-tv.conf` rồi chạy `sudo ./install.sh`. Thanh bên trái
có sẵn: **Microsoft 365** (PowerPoint, Excel trên web), **Google Drive**, LibreOffice Impress và
Calc, File, **Quay về Ca & Kho việc**, **Quay về Màn TV**.

- File `.pptx`, `.xlsx` đơn giản mở bằng LibreOffice là được. File nhiều hiệu ứng, SmartArt, macro
  thì mở bằng Microsoft 365 trên web, hoặc dùng laptop cắm cổng HDMI thứ 2 của TV.
- Bút trình chiếu không dây (clicker) dùng được ngay: nó gửi phím chuyển trang như bàn phím.
- Rời chế độ Đào tạo là đóng toàn bộ phiên đang mở: **lưu file trước khi chuyển**.

Muốn thêm màn cho chế độ `full` thì thêm đường dẫn vào `APP_PATHS` trong `/etc/smilelog-tv.conf`,
ví dụ `APP_PATHS="/orders /kho-viec /today/mine"`.

## Đổi chế độ ngay trên TV

| Cách | Thao tác |
|---|---|
| **Nút nổi** ⇄ góc dưới bên trái | Bấm ⇄ để mở bảng, bấm **"Chuyển sang …"** (một nút cho mỗi chế độ khác) để xác nhận. Bảng có thêm **"Mở lại trình duyệt"**, tự đóng sau 8 giây |
| **Phím tắt** (cắm bàn phím USB hoặc không dây) | **Ctrl+Alt+M** đổi vòng Màn TV → Ca & Kho việc → Đào tạo → Màn TV; **Ctrl+Alt+R** mở lại trình duyệt. Dùng được cả trong chế độ Đào tạo |
| **Biểu tượng** trong chế độ Đào tạo | **Quay về Ca & Kho việc**, **Quay về Màn TV** trên thanh bên trái |
| **SSH** | `sudo smilelog-tv mode tv`, `mode full`, `mode training`, `mode toggle`, hoặc `mode` để xem chế độ hiện tại |

- Màn hình tải lại trong vài giây sau khi đổi. Bấm lặp trong 5 giây đó bị bỏ qua, nên không đổi
  nhầm hai lần.
- Nút nổi chỉ hiện trên trang Smilelog, mờ đi khi không dùng. Không hiện trên màn chờ ngoài giờ;
  lúc đó dùng phím tắt.
- Ẩn nút nổi trên TV chỉ để xem: đặt `SHOW_SWITCH_BUTTON="no"` rồi chạy lại `sudo ./install.sh`.
  Phím tắt vẫn dùng được.
- Nút và phím tắt gọi dịch vụ `smilelog-tv-control` chỉ nghe trong máy (`127.0.0.1:9333`) và cần
  mã khoá trong `/etc/smilelog-tv.token`, nên trang web khác mở trên máy không đổi được chế độ.

## In phiếu, tải file, tải ảnh lên, tab mới

| Việc | Cách chạy trên máy kiosk |
|---|---|
| **In phiếu, QR** | Máy in mạng đời mới thường tự hiện (CUPS tự tìm). Không thấy thì thêm tay: `sudo smilelog-tv printer add phieu 192.168.1.50`, rồi `sudo smilelog-tv printer test`. Bấm In trong Smilelog sẽ hiện hộp chọn máy in. Muốn bấm In là in luôn: `KIOSK_PRINTING="yes"` |
| **Xuất Excel, tải file** | Cắm USB (FAT32 hoặc exFAT): Chromium hỏi chỗ lưu và mở sẵn USB (`/media/usb`). Rút USB ra mang đi |
| **Tải ảnh lên** (ảnh lỗi khi báo làm lại…) | Chép ảnh vào USB, cắm vào máy, chọn ảnh từ `/media/usb`. Chụp bằng điện thoại thì dùng app IPS InLab nhanh hơn |
| **Link mở tab mới** ("Xem 3D") | Tab mới có nút **"✕ Đóng tab này"** góc trên bên phải, bấm để quay về Smilelog. Ở chế độ `full`, máy không tự mở lại khi còn tab Smilelog phía sau |

## Điều khiển và cập nhật từ xa

| Việc | Cách |
|---|---|
| **Cập nhật** | Mỗi ngày lúc `AUTO_UPDATE_AT` (mặc định 18:30, trước giờ khởi động lại) máy tự lấy bản mới nhất từ GitHub (`UPDATE_REPO`, nhánh `UPDATE_BRANCH`) và cài lại. Cập nhật ngay: `sudo smilelog-tv update`. Xem bản đang chạy: `smilelog-tv version` |
| **Kiểm tra máy** | `sudo smilelog-tv doctor`: liệt kê từng mục OK / CHÚ Ý / LỖI (trình duyệt, kiosk, nút, phím tắt, máy in, USB, chế độ Đào tạo, mạng). Gửi kết quả cho người hỗ trợ |
| **Vào máy từ xa (Tailscale)** | `install.sh` tự cài Tailscale, bật SSH qua Tailscale và tự cập nhật. Đưa máy vào mạng của lab một lần, chọn một trong hai cách: (1) đặt khoá đăng nhập vào `/etc/smilelog-tv.tailscale-key` rồi chạy lại `install.sh`; (2) chạy `sudo smilelog-tv remote up` và mở đường link hiện ra trên điện thoại. Sau đó từ laptop có Tailscale ở bất kỳ đâu: `ssh tv-xuong-1` rồi gõ lệnh `smilelog-tv` như ngồi tại chỗ. Không cần mở cổng trên router. Xem tên, IP: `smilelog-tv remote` |
| **Xem và bấm màn hình kiosk từ xa** | Qua Tailscale: `ssh -L 9222:127.0.0.1:9222 tv-xuong-1`, mở Chrome trên laptop vào `chrome://inspect`, bấm **inspect** trang đang mở: thấy đúng màn hình TV và bấm, gõ được |
| **RustDesk** (xem, điều khiển màn hình) | `install.sh` tự cài bản mới nhất, đặt mật khẩu cố định và nâng cấp mỗi đêm. Xem ID và mật khẩu trên máy: `sudo smilelog-tv rustdesk`. Trên laptop hoặc điện thoại mở RustDesk, nhập ID và mật khẩu đó. Chế độ Đào tạo luôn điều khiển được (chạy X11). Màn TV, Ca & Kho việc điều khiển được khi kiosk chạy X11 (`DISPLAY_SERVER="x11"`); kiosk Wayland thì RustDesk không thấy màn hình, dùng dòng dưới |

**Khoá đăng nhập Tailscale** (cho nhiều máy, không phải mở link từng máy): Tailscale admin → Settings
→ Keys → **Generate auth key**, chọn *Reusable*, gắn tag (ví dụ `tag:kiosk`) để khoá không hết hạn theo
người tạo. Lưu trên từng máy:
`sudo install -m 600 /dev/stdin /etc/smilelog-tv.tailscale-key` (dán khoá, Enter, Ctrl+D). Không ghi
khoá vào `/etc/smilelog-tv.conf`, không gửi khoá qua chat. Trong Tailscale admin → Access controls,
cho phép tài khoản quản lý SSH vào máy có tag này.

Repo đang **public** nên máy tự cập nhật được không cần khoá. Nếu chuyển repo sang **private**, mỗi
máy cần một khoá chỉ đọc (GitHub → Settings → Deploy keys) và `UPDATE_REPO` dạng
`git@github.com:Brucedentalstudio/Bruce-tvkiosk.git`.

### Tự cập nhật khi repo có thay đổi

Ngoài lượt cập nhật hằng ngày, cứ mỗi `AUTO_UPDATE_CHECK_MIN` phút (mặc định 10) máy hỏi GitHub
commit mới nhất của nhánh `UPDATE_BRANCH`. Không có gì mới thì không làm gì, không ghi dòng log nào
của Smilelog TV. Có commit mới thì máy cài ngay như `sudo smilelog-tv update`.

- Gộp (merge) vào `main` là mọi máy nhận bản mới trong khoảng `AUTO_UPDATE_CHECK_MIN` phút cộng 1-3
  phút (mặc định khoảng 10-15 phút), kể cả giữa ca.
- Khi cài bản mới, kiosk mở lại nên **màn hình TV tối khoảng 10-30 giây**, một lần cho mỗi bản mới.
- Không có bản mới thì lượt kiểm tra nhanh không nâng Tailscale, RustDesk: việc đó để lượt
  `AUTO_UPDATE_AT`. Có bản mới thì `install.sh` chạy như mọi lần cài, nên RustDesk có thể được nâng
  ngay lúc đó, kể cả giữa ca.
- Mất mạng: chỉ ghi một dòng log, không báo động; có mạng lại thì kiểm tra tiếp.
- Mỗi lúc chỉ một lượt cập nhật chạy; lượt đến sau (hằng ngày, kiểm tra nhanh, chạy tay) bỏ qua.
- Tắt: để trống `AUTO_UPDATE_CHECK_MIN=""` trong `/etc/smilelog-tv.conf` rồi chạy lại `sudo ./install.sh`
  (hoặc `sudo smilelog-tv update --force`).
- Máy đã cài từ trước không cần làm gì: lượt cập nhật kế tiếp của máy chạy `install.sh` bản mới, tự
  thêm `AUTO_UPDATE_CHECK_MIN="10"` vào file cấu hình và tạo timer. Kiểm tra:
  `systemctl list-timers smilelog-tv-update-check.timer`.
- Bản mới mà `install.sh` lỗi giữa chừng (ví dụ apt đang bận, mất điện lúc cài) thì lượt kiểm tra sau
  thử lại, tối đa 3 lần cho mỗi commit. Lỗi đủ 3 lần thì máy chờ commit mới hơn, hoặc chạy
  `sudo smilelog-tv update --force`. Lỗi trước bước mở lại kiosk thì màn hình không tối.
- Bản mới có `smilelog-tv`, `install.sh` hoặc `uninstall.sh` lỗi cú pháp (`bash -n`) thì máy không cài,
  giữ bản đang chạy, ghi một dòng log và chờ commit sửa (nhớ cả qua khởi động lại).

## Wayland hay X11 cho kiosk

Khi chạy `sudo ./install.sh` từ bàn phím, máy in bảng so sánh dưới đây và hỏi KTV chọn (Enter = giữ
lựa chọn hiện tại). Chọn sẵn không hỏi: `sudo ./install.sh --display x11` hoặc `--display wayland`.
Lần cập nhật tự động ban đêm không hỏi, giữ lựa chọn đã lưu trong `DISPLAY_SERVER`.

| | `x11` (**mặc định**, khuyên dùng) | `wayland` (cage) |
|---|---|---|
| RustDesk xem, điều khiển kiosk | **Có**, kể cả khi trình duyệt treo, màn đen | Không: chỉ còn SSH qua Tailscale |
| Khoá chặt | Đủ cho kiosk: chỉ Chromium toàn màn hình, không thanh tác vụ | Chặt nhất: chỉ chạy đúng một ứng dụng |
| Hình ảnh | Có thể hơi xé hình khi cuộn nhanh | Mượt, không xé hình |
| Chọn khi | Muốn hỗ trợ từ xa mà không phải tới máy (đa số trường hợp) | Máy không cần điều khiển từ xa, hoặc X11 lỗi hiển thị trên máy đó |

Có lỗi hiển thị sau khi đổi: chạy lại `sudo ./install.sh --display wayland` là về như cũ.

## Vì sao không cài thẳng lên TV Samsung

TV Samsung chạy **Tizen**, không phải Android: không cài được APK, không dùng được ADB và
cleanyourtv. Trình duyệt có sẵn trên TV cũng không tự mở một trang khi bật nguồn. Cách ổn định
nhất là cắm thêm một máy chạy Linux vào HDMI. TV chỉ còn làm việc hiển thị.

| Máy | Ưu | Nhược |
|---|---|---|
| **Mini PC cũ chip Intel** (ví dụ Dell OptiPlex 3050 **Micro**, i3/i5 đời 7, RAM 8 GB, SSD) | Ổ SSD bền hơn thẻ nhớ, dư sức, card Intel chạy tốt trên Linux | Phải bật **AC Recovery = Power On** trong BIOS; không có HDMI-CEC |
| **Raspberry Pi 5 (4 GB)** + nguồn 27W, tản nhiệt có quạt, thẻ nhớ loại chịu ghi liên tục | Máy mới có bảo hành, có điện là tự lên, bật/tắt TV qua HDMI-CEC | Thẻ nhớ kém bền hơn SSD; cần cáp micro-HDMI |

TV để bật liên tục và (nếu đặt giờ làm) ngoài giờ chuyển sang màn chờ thì không cần HDMI-CEC: hai loại máy đều dùng
được, chọn loại rẻ hơn ở thời điểm mua. Tránh máy có card đồ hoạ rời (ví dụ HP Z2 Mini có Quadro):
tốn điện và dễ lỗi driver với giao diện kiosk.

## Cài đặt (khoảng 20 phút mỗi TV)

1. Cài hệ điều hành, đặt tên máy (ví dụ `tv-xuong-1`), bật SSH, nên cắm dây LAN:
   - Raspberry Pi: **Raspberry Pi OS Lite (64-bit)** bằng Raspberry Pi Imager.
   - Mini PC: **Debian 12** bản không giao diện (bỏ chọn desktop, chọn SSH server). Vào BIOS bật
     **AC Recovery = Power On** để mất điện có lại là máy tự lên.
2. Cài đặt TV Samsung (xem mục bên dưới).
3. Mở `smilelog-tv.conf.example`, kiểm tra `TV_URL`, giờ làm việc và webhook báo động.
4. Chép thư mục này lên máy và cài:

   ```bash
   scp -r smilelog-tv pi@tv-xuong-1.local:
   ssh pi@tv-xuong-1.local
   cd smilelog-tv && sudo ./install.sh
   ```

5. Đăng nhập Smilelog một lần (xem bên dưới), rồi `sudo reboot` để chắc chắn máy tự vào Màn TV.

## Cài đặt TV Samsung khi để bật liên tục

Tên mục có thể khác theo đời TV. Không tắt các mục này thì TV tự tắt hoặc tự hiện màn chờ của nó:

- **Tự động tắt nguồn** (Auto Power Off, thường trong *Chung → Giải pháp tiết kiệm năng lượng*):
  **Tắt**. Mặc định TV tự tắt sau 4 giờ không ai bấm remote.
- **Tắt khi không có tín hiệu** (No Signal Power Off): **Tắt**.
- **Thời gian bảo vệ tự động** (Auto Protection Time): **Tắt**. Màn chờ đã do máy chiếu lo.
- Nguồn vào: chọn đúng cổng HDMI cắm máy; nếu có **Anynet+ (HDMI-CEC)** thì bật để TV tự chuyển cổng.
- Độ sáng: giảm xuống khoảng 60–70% để TV bền hơn khi chạy cả ngày.
- TV **OLED** (dòng S90, S95) dễ lưu ảnh khi chiếu bảng cố định nhiều giờ. TV LED/QLED thông
  thường không bị vấn đề này.

## Đăng nhập lần đầu

Nên dùng **tài khoản riêng cho TV, chỉ được xem**, không dùng tài khoản của một người cụ thể.
Phiên đăng nhập lưu trong `/var/lib/smilelog-tv/profile`, nên khởi động lại máy không mất phiên.

- **Cách 1:** cắm bàn phím và chuột USB vào máy, đăng nhập trên TV, rút ra.
- **Cách 2, từ xa:** trên laptop chạy `ssh -L 9222:127.0.0.1:9222 pi@tv-xuong-1.local`,
  mở Chrome vào `chrome://inspect`, mục **Configure** thêm `localhost:9222`, rồi bấm
  **inspect** vào trang đang mở để gõ đăng nhập ngay trong cửa sổ đó.

## Máy tự làm gì

| Tình huống | Xử lý |
|---|---|
| Bật điện, mất điện rồi có lại | Tự mở Chromium toàn màn hình vào `APP_URL` (Kho việc, chế độ `full`) hoặc `TV_URL` (chế độ `tv`) |
| Mất mạng ngắn | Smilelog tự hiện "Mất kết nối" và tự tải lại sau 10 phút |
| Trang lỗi mạng, trang trắng, ai đó bấm sang trang khác | Watchdog mở lại trình duyệt sau 2 phút |
| Trình duyệt treo, không phản hồi | Watchdog mở lại sau 3 phút |
| Hết phiên, đang ở trang đăng nhập (chế độ `tv` và `full`) | **Báo động một lần** qua webhook và log; không khởi động lại vì việc đó vô ích; rời trang đăng nhập thì lần sau lại báo |
| Ngoài giờ làm (chỉ khi đặt `WORK_START`–`WORK_END`, `WORK_DAYS`; mặc định để trống thì Màn TV 24/7) | Chuyển sang **màn chờ**: đồng hồ và ngày trên nền đen, đổi chỗ mỗi phút để TV không lưu ảnh, không lộ số liệu khi Lab vắng |
| Vào giờ làm (chỉ khi đặt giờ làm; mặc định Màn TV 24/7) | Tự quay về Màn TV (trong vòng 1 phút) |
| Tuỳ chọn: tắt hẳn TV theo giờ | `SCREEN_ON` / `SCREEN_OFF` qua HDMI-CEC (chỉ Raspberry Pi; mặc định không dùng) |
| Xuất hình | Ép **1080p** (`RESOLUTION`) để Pi chạy mát, mượt; để trống thì dùng độ phân giải của TV |
| Mỗi ngày | Khởi động lại máy lúc `REBOOT_AT` (mặc định 19:00, giờ Bruce chọn; màn hình tối khoảng 1 phút) |

## Màn chính Kho việc và chống lưu ảnh

Máy cài mới mặc định `MODE="full"`: bật lên vào **Kho việc** (`APP_URL`). Màn TV sản xuất vẫn chọn được bằng nút ⇄.

Màn hình sáng 24/7 nên tiện ích trong trình duyệt tự làm 3 việc (chế độ `tv` và `full`), và xoay bước ở Kho việc:

| Việc | Tuỳ chọn (mặc định) | Tắt |
|---|---|---|
| Dời cả trang lên/sang trái vài điểm ảnh, thanh trên và menu dời theo | `BURNIN_SHIFT_MIN="5"` phút, `BURNIN_SHIFT_PX="4"` | `BURNIN_SHIFT_MIN=""` |
| Màn chờ đồng hồ phủ lên trang rồi về đúng trang cũ, không tải lại. Có người dùng trong 2 phút qua thì hoãn; chạm hoặc gõ phím là tắt ngay | `BURNIN_SAVER_EVERY_MIN="60"`, `BURNIN_SAVER_SEC="60"` | `BURNIN_SAVER_EVERY_MIN=""` |
| Làm tối ban đêm, trang vẫn bấm được | `DIM_START="22:00"`, `DIM_END="05:00"`, `DIM_LEVEL="0.3"` | `DIM_START=""` |
| Kho việc xoay qua các bước (chỉ `full`); có người dùng thì dừng, rảnh 2 phút thì xoay tiếp | `KHO_ROTATE_SEC="30"`, `KHO_ROTATE_STAGES="MAU,CAD,CAM,CAMNGUOI,SU,COMPOSITE,QC"` (MAU = Mẫu, CAM = CAM máy, CAMNGUOI = CAM nguội). Chỉ xoay qua bước Kho việc của máy chủ đang có cho tài khoản đó | `KHO_ROTATE_SEC=""` |

Sửa các dòng này trong `/etc/smilelog-tv.conf` là đủ: trang đang mở đọc lại trong vòng 1 phút, không cần người tại chỗ. Ví dụ chỉ xoay CAD và Sứ, mỗi bước 1 phút:

```bash
sudo sed -i -E 's/^KHO_ROTATE_STAGES=.*/KHO_ROTATE_STAGES="CAD,SU"/; s/^KHO_ROTATE_SEC=.*/KHO_ROTATE_SEC="60"/' /etc/smilelog-tv.conf
```

### Chuyển máy đang chạy sang Kho việc

`install.sh` không ghi đè `/etc/smilelog-tv.conf`, nên máy đã cài vẫn giữ `MODE` cũ (thường là `tv`). Vào máy từ xa (Tailscale SSH) rồi chạy:

```bash
sudo smilelog-tv mode full
```

Lệnh này ghi `MODE="full"` vào `/etc/smilelog-tv.conf` (giữ sau khi khởi động lại) và mở lại trình duyệt ngay vào Kho việc. Các tuỳ chọn chống lưu ảnh ở trên được thêm vào file cấu hình với giá trị mặc định ở lần cập nhật kế tiếp (`smilelog-tv update` chạy lại `install.sh`).

## Lệnh hay dùng

```bash
sudo smilelog-tv status     # trang đang mở, lịch hẹn giờ, 20 dòng log gần nhất
sudo smilelog-tv restart    # mở lại trình duyệt
sudo smilelog-tv mode full  # đổi chế độ (tv | full | training | toggle)
sudo smilelog-tv doctor     # kiểm tra máy, gửi kết quả cho người hỗ trợ
sudo smilelog-tv update     # cập nhật ngay từ GitHub
sudo smilelog-tv printer list  # máy in (add TÊN IP | default TÊN | test)
sudo journalctl -u smilelog-tv-control -n 20  # nhật ký phím tắt và nút nổi
sudo smilelog-tv screen off # tắt TV ngay (screen on để bật)
sudo ./install.sh           # chạy lại sau khi sửa /etc/smilelog-tv.conf
sudo ./uninstall.sh         # gỡ, giữ phiên đăng nhập (--purge để xoá hết)
```

### Chuyển máy đang chạy sang 24/7

`install.sh` không ghi đè `/etc/smilelog-tv.conf` có sẵn, nên máy đã cài vẫn giữ 07:00 đến 19:30. Để Màn TV chiếu 24/7:

```bash
sudo sed -i -E 's/^WORK_START=.*/WORK_START=""/; s/^WORK_END=.*/WORK_END=""/' /etc/smilelog-tv.conf
```

Không cần chạy lại `install.sh`: watchdog chạy mỗi phút và đọc lại file này mỗi lần, nên trong vòng 1 phút TV tự quay về Màn TV.

Để đổi giờ khởi động lại về 19:00 và giờ cập nhật về 18:30 (máy cũ đang để 03:30 và 02:30), sửa file rồi chạy lại `install.sh`, vì hẹn giờ là timer systemd do `install.sh` ghi ra, chỉ sửa file cấu hình thì chưa đổi:

```bash
sudo sed -i -E 's/^REBOOT_AT=.*/REBOOT_AT="19:00"/; s/^AUTO_UPDATE_AT=.*/AUTO_UPDATE_AT="18:30"/' /etc/smilelog-tv.conf
sudo smilelog-tv update --force
systemctl list-timers 'smilelog-tv-reboot.timer' 'smilelog-tv-update.timer'   # kiểm tra: 19:00 và 18:30
```

Lệnh `update --force` lấy bản mới nhất của nhánh `main` trên GitHub rồi chạy lại `install.sh` để ghi lại các timer. Nếu `install.sh` hỏi "Chọn 1 hoặc 2", bấm Enter để giữ cách vẽ màn hình hiện tại. Kiosk khởi động lại nên màn hình tối khoảng 10-30 giây.

Hoặc chạy `sudo ./install.sh` trong thư mục đã chép lên máy lúc cài.

## Lưu ý bảo mật

- Cổng điều khiển trình duyệt `9222` chỉ mở trong máy (`127.0.0.1`), không mở ra mạng lab.
  Muốn dùng từ xa thì phải qua SSH.
- Đổi mật khẩu mặc định của tài khoản `pi` hoặc chỉ cho đăng nhập SSH bằng khoá.
- Máy đang giữ phiên Smilelog: ai cầm được máy là xem được Màn TV. Đây là lý do nên dùng
  tài khoản chỉ được xem.
- Chế độ `full` trên máy dùng chung: phiên đăng nhập được giữ qua cả lần khởi động lại, nên
  người sau dùng tiếp tài khoản của người trước nếu không đăng xuất. Dặn mọi người đăng xuất khi
  rời máy. Không dùng tài khoản Admin trên máy dùng chung.
