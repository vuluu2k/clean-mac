# Install clean-mac / Cài đặt clean-mac

[Download v0.4.1](https://github.com/vuluu2k/clean-mac/releases/tag/v0.4.1) · [Build from source](README.md#build-and-run) · [Tự build](README.vi.md#chạy-ngay)

## English

Requires **macOS 14+**. The Universal app contains Apple silicon and Intel code. Intel hardware still needs manual verification.

**This release is ad-hoc signed, not Developer ID signed or notarized.** macOS can block the downloaded disk image or app.
Do not disable Gatekeeper or SIP. If you do not trust the release, build from source instead.

1. Download `clean-mac-0.4.1-universal.dmg` and `SHA256SUMS` from the release page.
2. In the download folder, verify the checksum:

   ```bash
   shasum -a 256 -c SHA256SUMS
   ```

3. Open the DMG. Drag `clean-mac.app` into the **Applications** shortcut.
4. Open the copied app from Applications, not from the disk image.
5. Eject the disk image after installation.

If macOS blocks an unidentified developer, use Apple's [Open Anyway guidance](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) only after verifying the source and checksum.
If macOS reports malware, stop. Do not bypass a malware warning.
If approval is unavailable, build locally from the published source. These instructions do not remove quarantine attributes or disable security protections.

The app does not scan automatically. Back up important data, choose a scan mode, then review the results.
Full Disk Access is optional and must be enabled manually. It does not bypass SIP or Unix permissions.
Moving items to Trash does not free space until you empty Trash yourself.

## Tiếng Việt

Cần **macOS 14+**. App Universal chứa mã cho cả Apple silicon và Intel. Phần cứng Intel vẫn cần kiểm tra thủ công.

**Bản này ký ad-hoc, chưa ký Developer ID và chưa notarize.** macOS có thể chặn DMG hoặc app đã tải.
Không tắt Gatekeeper hoặc SIP. Nếu chưa tin tưởng bản phát hành, hãy tự build từ mã nguồn.

1. Tải `clean-mac-0.4.1-universal.dmg` và `SHA256SUMS` từ trang release.
2. Trong thư mục chứa hai tệp, kiểm tra checksum:

   ```bash
   shasum -a 256 -c SHA256SUMS
   ```

3. Mở DMG. Kéo `clean-mac.app` vào shortcut **Applications**.
4. Mở bản app đã chép trong Applications, không chạy từ ổ DMG.
5. Eject ổ DMG sau khi cài.

Nếu macOS chặn vì nhà phát triển chưa được xác nhận, chỉ dùng [hướng dẫn Open Anyway của Apple](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) sau khi kiểm tra nguồn và checksum.
Nếu macOS báo mã độc, hãy dừng lại. Không vượt cảnh báo mã độc.
Nếu không thể cấp phép, hãy build cục bộ từ mã nguồn. Hướng dẫn này không xóa thuộc tính quarantine hay tắt bảo vệ hệ thống.

App không tự quét. Hãy sao lưu dữ liệu quan trọng, chọn chế độ quét rồi xem lại kết quả.
Full Disk Access là tùy chọn do bạn tự bật, không vượt SIP hoặc quyền Unix.
Chuyển vào Trash chưa giải phóng dung lượng cho tới khi bạn tự Empty Trash.
