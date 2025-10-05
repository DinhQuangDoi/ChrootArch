# 🏗️ ChrootArch – Arch Linux chroot + XFCE + Termux-X11

ChrootArch giúp bạn triển khai **môi trường Arch Linux hoàn chỉnh ngay trên Android** thông qua **chroot** và **Termux-X11**, với mục tiêu:
- Trải nghiệm desktop Linux (XFCE) nhanh và ổn định 🖥️
- Dễ dàng cài đặt chỉ với **một dòng lệnh**
- Hỗ trợ 3D acceleration (VirGL), âm thanh (PulseAudio) và đầy đủ môi trường GUI

---

## 🚀 Tính năng nổi bật

- 🐧 Tải & giải nén Arch Linux ARM tự động  
- 🔧 Thiết lập mạng (`resolv.conf`, `hosts`) tự động  
- 👤 Cấu hình người dùng, mật khẩu, múi giờ & locale ngay lần đầu khởi động  
- 💻 Giao diện XFCE qua Termux-X11  
- 🔥 Hỗ trợ VirGL renderer, PulseAudio, termux-wake-lock  
- 🧰 lệnh khởi động tiện lợi:
  - `start-arch`: vào Arch CLI
  - `start-arch-x11`: khởi động GUI XFCE + X11

---

## 🔧 Cài đặt

### Yêu cầu
- Thiết bị đã root
- Cài đặt module [Busybox](https://github.com/Magisk-Modules-Alt-Repo/BuiltIn-BusyBox/releases) hoặc bỏ qua nếu bạn sử dụng KSU hoặc các nhánh của KSU như RKSU, KSU Next, Sukisu Ultra 

### Cài Termux + Termux-X11

- [Termux (Github Release)](https://github.com/termux/termux-app/releases)
- [Termux-X11 (Github Release)](https://github.com/termux/termux-x11/releases)

---

### Chạy lệnh cài đặt (One-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main/install.sh | bash
```
### Gỡ cài đặt 
```bash
curl -fsSL https://raw.githubusercontent.com/DinhQuangDoi/ChrootArch/main/scripts/uninstall.sh | bash
