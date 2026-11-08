# Smilelog TV: máy chiếu Màn TV sản xuất

Biến một máy tính nhỏ cắm vào cổng HDMI của TV thành màn hình kiosk chạy Smilelog. Bật điện là
tự vào Smilelog, mất điện hay trình duyệt treo thì tự hồi phục.

## Hai chế độ

| | `tv` (mặc định) | `full` |
|---|---|---|
| Dùng cho | TV treo xưởng, chỉ để xem | Máy trạm ở quầy, bàn điều phối: có bàn phím, chuột |
| Màn được mở | Màn TV (`/production-tv`) | **Danh sách ca** (`/orders`) và **Kho việc** (`/kho-viec`), kể cả trang con như chi tiết ca |
| Mở lúc bật máy | `TV_URL` | `APP_URL` (mặc định Kho việc) |
| Bấm sang màn khác | Sau 2 phút tự quay về Màn TV | Sau 2 phút tự quay về `APP_URL` |
| Trang đăng nhập | Báo động: TV bị văng phiên | Bình thường, người dùng tự đăng nhập |
| Ngoài giờ làm | Màn chờ đồng hồ | Không có màn chờ, không ngắt người đang làm |
| Tài khoản nên dùng | Tài khoản riêng, chỉ được xem | Tài khoản của từng người, đăng xuất khi rời máy |

Muốn thêm màn cho chế độ `full` thì thêm đường dẫn vào `APP_PATHS` trong `/etc/smilelog-tv.conf`,
ví dụ `APP_PATHS="/orders /kho-viec /today/mine"`.

Đổi chế độ ngay trên máy, không cần cài lại:

```bash
sudo smilelog-tv mode full   # Danh sách ca + Kho việc
sudo smilelog-tv mode tv     # quay về Màn TV
sudo smilelog-tv mode        # xem đang ở chế độ nào
```

## Vì sao không cài thẳng lên TV Samsung

TV Samsung chạy **Tizen**, không phải Android: không cài được APK, không dùng được ADB và
cleanyourtv. Trình duyệt có sẵn trên TV cũng không tự mở một trang khi bật nguồn. Cách ổn định
nhất là cắm thêm một máy chạy Linux vào HDMI. TV chỉ còn làm việc hiển thị.

| Máy | Ưu | Nhược |
|---|---|---|
| **Mini PC cũ chip Intel** (ví dụ Dell OptiPlex 3050 **Micro**, i3/i5 đời 7, RAM 8 GB, SSD) | Ổ SSD bền hơn thẻ nhớ, dư sức, card Intel chạy tốt trên Linux | Phải bật **AC Recovery = Power On** trong BIOS; không có HDMI-CEC |
| **Raspberry Pi 5 (4 GB)** + nguồn 27W, tản nhiệt có quạt, thẻ nhớ loại chịu ghi liên tục | Máy mới có bảo hành, có điện là tự lên, bật/tắt TV qua HDMI-CEC | Thẻ nhớ kém bền hơn SSD; cần cáp micro-HDMI |

TV để bật liên tục và ngoài giờ chuyển sang màn chờ thì không cần HDMI-CEC: hai loại máy đều dùng
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
| Bật điện, mất điện rồi có lại | Tự mở Chromium toàn màn hình vào `TV_URL` |
| Mất mạng ngắn | Smilelog tự hiện "Mất kết nối" và tự tải lại sau 10 phút |
| Trang lỗi mạng, trang trắng, ai đó bấm sang trang khác | Watchdog mở lại trình duyệt sau 2 phút |
| Trình duyệt treo, không phản hồi | Watchdog mở lại sau 3 phút |
| Hết phiên, đang ở trang đăng nhập | **Báo động một lần** qua webhook và log; không khởi động lại vì việc đó vô ích |
| Ngoài giờ làm (`WORK_START`–`WORK_END`, `WORK_DAYS`) | Chuyển sang **màn chờ**: đồng hồ và ngày trên nền đen, đổi chỗ mỗi phút để TV không lưu ảnh, không lộ số liệu khi xưởng vắng |
| Vào giờ làm | Tự quay về Màn TV (trong vòng 1 phút) |
| Tuỳ chọn: tắt hẳn TV theo giờ | `SCREEN_ON` / `SCREEN_OFF` qua HDMI-CEC (chỉ Raspberry Pi; mặc định không dùng) |
| Xuất hình | Ép **1080p** (`RESOLUTION`) để Pi chạy mát, mượt; để trống thì dùng độ phân giải của TV |
| Mỗi đêm | Khởi động lại máy lúc `REBOOT_AT` |

## Lệnh hay dùng

```bash
sudo smilelog-tv status     # trang đang mở, lịch hẹn giờ, 20 dòng log gần nhất
sudo smilelog-tv restart    # mở lại trình duyệt
sudo smilelog-tv mode full  # đổi chế độ (tv | full), mở lại trình duyệt ngay
sudo smilelog-tv screen off # tắt TV ngay (screen on để bật)
sudo ./install.sh           # chạy lại sau khi sửa /etc/smilelog-tv.conf
sudo ./uninstall.sh         # gỡ, giữ phiên đăng nhập (--purge để xoá hết)
```

## Lưu ý bảo mật

- Cổng điều khiển trình duyệt `9222` chỉ mở trong máy (`127.0.0.1`), không mở ra mạng lab.
  Muốn dùng từ xa thì phải qua SSH.
- Đổi mật khẩu mặc định của tài khoản `pi` hoặc chỉ cho đăng nhập SSH bằng khoá.
- Máy đang giữ phiên Smilelog: ai cầm được máy là xem được Màn TV. Đây là lý do nên dùng
  tài khoản chỉ được xem.
- Chế độ `full` trên máy dùng chung: phiên đăng nhập được giữ qua cả lần khởi động lại, nên
  người sau dùng tiếp tài khoản của người trước nếu không đăng xuất. Dặn mọi người đăng xuất khi
  rời máy. Không dùng tài khoản Admin trên máy dùng chung.
