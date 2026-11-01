# Smilelog TV: máy chiếu Màn TV sản xuất

Biến một máy tính nhỏ cắm vào cổng HDMI của TV thành màn hình kiosk chỉ chạy
`/production-tv` của Smilelog. Bật điện là tự vào màn sản xuất, mất điện hay trình duyệt treo
thì tự hồi phục, hết phiên đăng nhập thì báo động.

## Vì sao không cài thẳng lên TV Samsung

TV Samsung chạy **Tizen**, không phải Android: không cài được APK, không dùng được ADB và
cleanyourtv. Trình duyệt có sẵn trên TV cũng không tự mở một trang khi bật nguồn. Cách ổn định
nhất là cắm thêm một máy chạy Linux vào HDMI. TV chỉ còn làm việc hiển thị.

| Máy | Ưu | Nhược |
|---|---|---|
| **Raspberry Pi 5 (4 GB)** + nguồn, vỏ có quạt, thẻ nhớ 32 GB | Bật/tắt TV theo giờ qua HDMI-CEC (Anynet+), rẻ, tiêu thụ ít điện | Thẻ nhớ có thể hỏng sau vài năm: dùng thẻ loại tốt |
| **Mini PC Intel N100** | Mạnh hơn, ổ SSD bền hơn thẻ nhớ | Đắt hơn, đa số không có CEC nên không hẹn giờ bật/tắt TV được |

Chọn Pi 5 nếu cần bật/tắt màn theo ca. Giá tham khảo tự kiểm tra lại khi mua.

## Cài đặt (khoảng 20 phút mỗi TV)

1. Cài **Raspberry Pi OS Lite (64-bit)** bằng Raspberry Pi Imager. Trong Imager, đặt sẵn
   Wi-Fi (hoặc cắm dây LAN, ổn định hơn), tên máy (ví dụ `tv-xuong-1`) và **bật SSH**.
2. Trên TV Samsung: Cài đặt → Kết nối → Quản lý thiết bị ngoài → bật **Anynet+ (HDMI-CEC)**.
   Đặt TV tự chuyển sang đúng cổng HDMI khi có tín hiệu.
3. Mở `smilelog-tv.conf.example`, kiểm tra `TV_URL`, giờ bật/tắt và webhook báo động.
4. Chép thư mục này lên máy và cài:

   ```bash
   scp -r smilelog-tv pi@tv-xuong-1.local:
   ssh pi@tv-xuong-1.local
   cd smilelog-tv && sudo ./install.sh
   ```

5. Đăng nhập Smilelog một lần (xem bên dưới), rồi `sudo reboot` để chắc chắn máy tự vào Màn TV.

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
| Giờ tan ca / vào ca | Tắt / bật TV qua HDMI-CEC (chỉ Raspberry Pi) |
| Xuất hình | Ép **1080p** (`RESOLUTION`) để Pi chạy mát, mượt; để trống thì dùng độ phân giải của TV |
| Mỗi đêm | Khởi động lại máy lúc `REBOOT_AT` |

## Lệnh hay dùng

```bash
sudo smilelog-tv status     # trang đang mở, lịch hẹn giờ, 20 dòng log gần nhất
sudo smilelog-tv restart    # mở lại trình duyệt
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
