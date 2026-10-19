# clean-mac

[English](README.md) · **Tiếng Việt** · [Website](https://vuluu2k.github.io/clean-mac/) · [GitHub](https://github.com/vuluu2k/clean-mac)

**Dọn gọn. Nhẹ máy. Không thuê bao.**

App macOS native miễn phí, mã nguồn mở, viết bằng SwiftUI. Quét dữ liệu có thể dọn, giải thích lý do và để bạn quyết định. Không server, tài khoản, AI cloud hay telemetry.
Kiểm tra cập nhật (mặc định tắt) chỉ đọc phiên bản công khai trên GitHub; không gửi dữ liệu quét.

## Tải bản dựng sẵn

[Tải DMG Universal — v0.4.0](https://github.com/vuluu2k/clean-mac/releases/download/v0.4.0/clean-mac-0.4.0-universal.dmg) · [SHA256SUMS](https://github.com/vuluu2k/clean-mac/releases/download/v0.4.0/SHA256SUMS)

App chứa mã Apple silicon và Intel cho macOS 14+. Phần cứng Intel vẫn cần kiểm tra thủ công.
**Bản này ký ad-hoc, chưa ký Developer ID hoặc notarize. macOS có thể chặn.** Hãy đọc [hướng dẫn cài và bảo mật](INSTALL.md) trước khi mở DMG. Bạn vẫn có thể tự build từ mã nguồn.

## Chạy ngay

Yêu cầu **macOS 14+**, Xcode hoặc Command Line Tools có **Swift 6+**.

```bash
xcode-select --install  # Chỉ cần nếu máy chưa có công cụ phát triển
swift test
./Scripts/run-app.sh
```

Script tạo và mở `dist/clean-mac.app`. Có thể kéo app này vào Applications để dùng mà không cần terminal.

Chỉ tạo app, không mở:

```bash
./Scripts/build-app.sh
```

Bản build ký ad-hoc trên máy hiện tại, chưa có Developer ID hoặc notarization. Khi phân phối sang máy khác, Gatekeeper có thể chặn. Không tắt Gatekeeper toàn hệ thống.

## Đổi ngôn ngữ ngay trong app

Chọn **Tiếng Việt** hoặc **English** ở đầu thanh bên, cạnh biểu tượng quả địa cầu. App đổi giao diện ngay và lưu lựa chọn cho lần mở sau. Không cần quét lại, không mất bộ lọc hoặc tệp đang chọn.

Bộ chọn bị khóa khi có tác vụ hoặc màn hình xem lại/xác nhận. Hộp thoại quyền, lỗi gốc của hệ thống và định dạng dung lượng có thể theo ngôn ngữ/vùng của macOS.

## Có gì trong v0.4.0

- Thông báo cập nhật tùy chọn: tự bấm kiểm tra hoặc bật kiểm tra mỗi ngày khi mở app qua GitHub Releases. Không tự tải hay tự cài.
- Dashboard dung lượng ổ đĩa thực, giao diện Việt/English chuyển đổi được, hỗ trợ giao diện sáng/tối của hệ thống.
- Hai chế độ: **Quét nhanh** và **Quét sâu toàn ổ** khởi động.
- Quét nền, kết quả tạm cập nhật trong lúc duyệt, tiến độ theo nhóm/đường dẫn và dừng quét.
- Tách lượt kiểm tra tệp/thư mục, dung lượng logic đã ghi nhận, lỗi đọc và số gợi ý hiển thị.
- Tổng hợp thư mục từ 100 MB, kể cả khi từng tệp đều nhỏ; chỉ phân tích và mở Finder, không xóa thư mục.
- Nhận diện dữ liệu **nghi còn sót** của app theo bundle ID, danh mục `.app` và LaunchServices.
- Bộ lọc **Khuyên dọn / Cần xem lại / Không nên xóa**, có lý do; mục bị khóa không thể chọn dọn.
- Trang **Gỡ ứng dụng**: danh mục app, xem dữ liệu khớp bundle ID và xác nhận riêng trước khi chuyển vào Trash.
- Nhóm gợi ý, tìm tên/đường dẫn, sắp tệp lớn nhất trước và mở vị trí trong Finder.
- Thêm thư mục bên trong Home để tìm tệp lớn. Danh sách thư mục chỉ tồn tại trong phiên chạy.
- Không chọn sẵn mục nào. Màn hình xác nhận hiển thị đường dẫn đầy đủ và rủi ro.
- Chuyển vào Trash qua API macOS. Báo riêng từng lỗi, không xóa vĩnh viễn khi thất bại.

## Quy tắc “thông minh”

Đây là quy tắc minh bạch, không phải AI đoán dữ liệu nào vô dụng.

| Nhóm | Phạm vi | Điều kiện |
|---|---|---|
| Cache cũ | `~/Library/Caches` | Không sửa đổi ít nhất 14 ngày |
| Log cũ | `~/Library/Logs` | Không sửa đổi ít nhất 14 ngày |
| Build Xcode | `~/Library/Developer/Xcode/DerivedData` | Từng tệp không sửa đổi ít nhất 30 ngày |
| Bộ cài cũ | `~/Downloads` | `.dmg`, `.pkg`, `.mpkg` không sửa đổi ít nhất 30 ngày |
| Tệp lớn | Downloads và thư mục được thêm | Từ 100 MB, luôn cần bạn tự xem xét |
| Dữ liệu app còn sót | Các vị trí Library có tên bundle ID rõ ràng | Không thấy app tương ứng; chỉ là nghi vấn |
| Phân tích toàn ổ | Phần ổ khởi động có quyền đọc | Tệp từ 10 MB; chỉ xem nếu ngoài phạm vi dọn |
| Thư mục chiếm dung lượng | Các tệp đọc được trong lượt quét sâu | Tổng từ 100 MB, gồm cả tệp nhỏ; luôn chỉ xem |

**Tệp cũ hoặc tệp lớn không đồng nghĩa với không còn dùng.** App dùng ngày sửa đổi, không coi ngày truy cập là bằng chứng. Bộ cài mới nhưng lớn vẫn có thể xuất hiện trong nhóm Tệp lớn.

Chỉ từng tệp thường trong phạm vi an toàn mới được đưa vào xác nhận dọn. Thống kê thư mục không cấp quyền xóa cả thư mục. Các thư mục build/cache rỗng còn lại được giữ nguyên.

## Quét sâu và cấp quyền

1. Chọn **Quét sâu toàn ổ** trên dashboard.
2. Nếu muốn mở rộng quyền đọc, bấm **Full Disk Access**.
3. Trong **System Settings → Privacy & Security → Full Disk Access**, tự thêm và bật `clean-mac.app`.
4. Thoát và mở lại app. Sau khi build lại, macOS có thể yêu cầu cấp lại quyền cho bản ký ad-hoc.
5. Bấm **Quét sâu toàn ổ**. Xem thống kê và kết quả tạm ngay trong lúc duyệt; danh sách tạm giữ tối đa 500 tệp. Bấm **Dừng quét** nếu cần.
6. Xem **Thư mục chiếm dung lượng**, **Dữ liệu app còn sót** hoặc **Phân tích toàn ổ**. Bấm nút `ⓘ` để xem bằng chứng. Chỉ có thể chọn dọn sau khi quét dừng/kết thúc.

**Ít gợi ý không có nghĩa là ít tệp được quét.** Các tệp dưới 10 MB vẫn được tính vào dung lượng thư mục. Số lượt kiểm tra có thể trùng giữa giai đoạn nhanh và sâu. Dung lượng logic đã ghi nhận không phải dung lượng rác hay số byte có thể thu hồi.

Thống kê thư mục giữ tối đa 50.000 đường dẫn, sâu 8 cấp và hiển thị 100 mục lớn nhất từ 100 MB. Chạm giới hạn tổng hợp không dừng lượt duyệt tệp; app báo giới hạn chi tiết. Thư mục cha đã gồm con: không cộng các hàng với nhau. Số liệu chỉ phản ánh phần đọc được và thời điểm quét.

Quét sâu duyệt metadata ở `/Applications`, `/Library`, `/System`, `/Users`, `/private`, `/usr`, `/opt` và các phần khác của ổ khởi động mà macOS cho đọc. Chế độ này bao gồm mục ẩn và nội dung package khi phân tích, nhưng không cho xóa chúng tùy tiện.

App bỏ qua `/dev`, các pseudo filesystem, `/Volumes`, `/System/Volumes`, Trash, Keychains và thư mục thông tin đăng nhập thông dụng. Đường dẫn APFS lặp và symlink không được đi theo. Ổ ngoài không nằm trong lượt quét này.

**Không cam kết đọc được 100% hệ thống.** Full Disk Access không thay thế quyền sở hữu Unix hoặc SIP. Vùng bị chặn được báo trong cảnh báo. App không dùng `sudo`, helper đặc quyền hoặc tắt bảo vệ macOS.

## Nhận diện app đã gỡ: có bằng chứng, không đoán chắc

App đọc bundle ID từ `Contents/Info.plist` trong các `.app` tìm thấy. App đối chiếu các thư mục ứng dụng chuẩn, kết quả quét sâu và LaunchServices. Ngoài các plist nhận diện này, scanner không đọc nội dung dữ liệu người dùng.

Các vị trí được xem xét:

- `~/Library/Caches/<bundle-id>` và `Logs/<bundle-id>`.
- `~/Library/Application Support/<bundle-id>`.
- `~/Library/Preferences/<bundle-id>.plist`.
- `~/Library/Saved Application State/<bundle-id>.savedState`.
- Containers và LaunchAgents trong Home: **chỉ xem**.
- Các vị trí tương ứng trong `/Library`, thêm LaunchDaemons: **chỉ xem**.

Ví dụ: `~/Library/Application Support/com.example.oldapp/` có thể được gợi ý khi không thấy app tương ứng. Mỗi tệp hiển thị bundle ID và lý do. Tìm bundle ID trong ô tìm kiếm để xem cùng nhóm.

**Không thấy `.app` không chứng minh ứng dụng đã gỡ.** Plugin, app portable, công cụ CLI hoặc app trên ổ chưa gắn có thể vẫn dùng dữ liệu. App bỏ qua Apple ID, tên nhóm chia sẻ và các ID cùng tiền tố nhà phát hành với app còn cài. Đây là lựa chọn bảo thủ, có thể bỏ sót dữ liệu thật sự không cần.

Thư mục chỉ có tên thân thiện như `Slack` hoặc `My App` không được tự gán chủ sở hữu. Chưa có lịch sử gỡ app nên không thể kết luận chính xác các trường hợp đó.

Chỉ tệp thường trong allowlist Library của người dùng mới có thể chọn dọn. Database, Containers, launch agents và dữ liệu dùng chung vẫn chỉ xem. Khi danh mục app lỗi hoặc chưa đầy đủ, các nghi vấn còn sót bị khóa dọn. Trước khi dọn, app lập lại danh mục ứng dụng chuẩn và kiểm tra LaunchServices để chặn app vừa được cài lại.

## Gỡ ứng dụng và dữ liệu liên quan

1. Mở **Gỡ ứng dụng** → **Quét ứng dụng**. Có thể tìm tên, bundle ID, đường dẫn hoặc lọc app có thể phân tích/đang bị khóa.
2. Đóng app muốn gỡ bằng cách thông thường. clean-mac không force quit.
3. Bấm **Phân tích để gỡ**. Xem đường dẫn app, dung lượng và từng tệp liên quan.
4. Không có dữ liệu nào được chọn sẵn. **Khuyên dọn** là cache/log cũ; **Cần xem lại** có thể chứa thiết lập/dữ liệu offline; **Không nên xóa** bị khóa.
5. Chọn riêng dữ liệu muốn bỏ. Có thể chỉ gỡ app, giữ toàn bộ dữ liệu.
6. Bấm **Xem lại & gỡ ứng dụng**, kiểm tra danh sách cố định rồi đánh dấu đồng ý.
7. Chuyển vào Trash, kiểm tra báo cáo từng lỗi và dùng Finder → **Put Back** khi cần.

Chỉ gỡ `.app` bên thứ ba trong `/Applications` hoặc `~/Applications`. Giữ app Apple, hệ thống, clean-mac, app đang chạy và app ngoài phạm vi. Trước khi chuyển, app kiểm tra lại toàn bộ metadata bundle (tối đa 200.000 mục), trạng thái đang chạy và các tệp đã chọn. Nếu bundle thay đổi hoặc không kiểm tra đầy đủ được, thao tác bị chặn.

Dữ liệu liên quan chỉ khớp bundle ID chính xác; tên thân thiện có thể bị bỏ sót. Database, Containers, dịch vụ, vị trí hệ thống và dữ liệu có thể dùng chung với bản app/nhà phát hành khác đều chỉ xem. Danh mục không đầy đủ khóa dọn dữ liệu, không tự suy đoán chủ sở hữu. Phân tích liên quan giới hạn 50.000 mục và 20.000 tệp lưu lại.

App được chuyển trước; nếu thất bại, dữ liệu giữ nguyên. Lỗi từng tệp về sau được báo riêng, không có xóa vĩnh viễn hoặc rollback tự động. Driver, extension và daemon có thể cần trình gỡ của nhà phát hành. **Không cam kết gỡ sạch mọi dấu vết.**

## Dọn an toàn

1. Sao lưu dữ liệu quan trọng.
2. Chọn chế độ rồi bấm nút quét.
3. Kiểm tra cảnh báo về quyền truy cập hoặc kết quả một phần.
4. Xem từng đường dẫn và lý do. Dùng nút thư mục để kiểm tra trong Finder.
5. Đóng ứng dụng liên quan trước khi dọn cache hoặc build.
6. Chọn các tệp bạn thực sự không cần.
7. Bấm **Xem lại & dọn**, đọc danh sách và đánh dấu xác nhận.
8. Sau khi chuyển, kiểm tra Trash trong Finder. Dùng **Put Back** nếu cần khôi phục.
9. Khi chắc chắn không cần dữ liệu, tự **Empty Trash** trong Finder.

**Chuyển vào Trash chưa giải phóng dung lượng ổ đĩa.** App không tự Empty Trash. Kích thước hiển thị là dung lượng logic, không phải cam kết số byte sẽ thu hồi trên APFS.

Cache có thể chứa dữ liệu offline. Dọn cache có thể yêu cầu tải lại dữ liệu hoặc đăng nhập lại. Dọn DerivedData có thể làm lần build sau chậm hơn. Không chọn hàng loạt chỉ vì tổng dung lượng lớn.

## Hàng rào bảo vệ và giới hạn

- Không dùng `sudo` và không cho dọn `/System`, `/Library` hoặc dữ liệu người dùng khác.
- Application Support trong Home chỉ được dọn từng tệp nếu khớp chính sách nghi còn sót hoặc dữ liệu liên quan của app đang gỡ, và được xác nhận.
- Containers và launch agents chỉ xem. Không đọc Keychains.
- Dọn tệp thông thường không dọn symlink, hard link, mục ẩn, alias hoặc package. Gỡ ứng dụng là ngoại lệ riêng cho bundle `.app` đã kiểm tra; không mở quyền xóa thư mục dữ liệu bất kỳ.
- Bỏ qua tệp cloud mà macOS nhận diện và placeholder dataless. Không chủ động tải chúng xuống.
- Không dọn database nhận diện qua đuôi `.db`, `.sqlite`, `.sqlite3`, kèm journal/WAL/SHM, hoặc tệp tải dở thông dụng.
- Trước mỗi thao tác Trash, kiểm tra lại phạm vi, đường dẫn, loại tệp, device/inode, kích thước, mtime và ctime.
- Khi tệp thay đổi hoặc mất quyền truy cập, giữ nguyên và yêu cầu quét lại.
- Quét nhanh giới hạn 500.000 mục duyệt. Quét sâu không dừng duyệt theo số lượng nhưng chỉ lưu kết quả giới hạn.
- Giữ tối đa 20.000 kết quả cuối và 100 cảnh báo. Khi chạm giới hạn, app báo rõ kết quả chưa đầy đủ.

API Trash nhận đường dẫn. Kiểm tra lại không loại bỏ hoàn toàn cuộc đua đổi tên đường dẫn do tiến trình khác gây ra. App không phải sandbox bảo mật. Không chạy bằng quyền quản trị.

macOS có thể yêu cầu quyền **Files and Folders**. Nếu từ chối, app báo các phần không đọc được. Full Disk Access là tùy chọn để mở rộng lượt quét, không phải giấy phép xóa hệ thống.

Chưa có tìm tệp trùng, xóa snapshot APFS, dọn Docker, lịch chạy nền hoặc tự phát hiện ứng dụng đang dùng từng cache. Trạng thái đang chạy chỉ được kiểm tra khi gỡ app.

## Phát triển và kiểm thử

```bash
swift test
swift Scripts/check-localization.swift
./Scripts/build-app.sh
```

Để đóng gói DMG Universal, chạy `./Scripts/build-dmg.sh`. Script build kiến trúc còn lại, ghép binary, ký ad-hoc, mount chỉ đọc để kiểm tra và tạo checksum trong `dist/releases/`. Không ghi đè bản release đã có.

Bản dịch nằm trong `Sources/CleanMacCore/Resources/`. Tiếng Việt là ngôn ngữ nguồn dự phòng; bảng English chứa các bản dịch. Trình kiểm tra trích khóa trực tiếp bằng Swift compiler và đối chiếu các placeholder. Tên app, đường dẫn và bundle ID không được dịch.

Nếu app cũ đang được sử dụng, tạo bundle kiểm tra riêng để không ghi đè nó:

```bash
CLEAN_MAC_APP_PATH="$PWD/dist/preview/clean-mac.app" ./Scripts/build-app.sh
```

Kiểm thử dùng các Home giả trong thư mục tạm. Thao tác Trash được thay bằng hàm thử nghiệm hoặc di chuyển trong fixture. **Tests không quét Home thật và không dùng Trash thật.**

```text
Sources/CleanMacCore/  Quy tắc, scanner, xác thực tệp và thao tác Trash
Sources/CleanMac/      SwiftUI dashboard và trạng thái bất đồng bộ
Tests/                Kiểm thử filesystem và trạng thái chọn/xác nhận
Scripts/              Tạo icon, build, ký ad-hoc và chạy app
Resources/            Info.plist và mô tả quyền truy cập
specs/                Phạm vi, kiến trúc và kịch bản kiểm tra thủ công
```

Xem [kịch bản dọn cơ bản](specs/epics/e01-safe-cleaner/plan.md) và [quét sâu](specs/epics/e02-deep-analysis/plan.md) trước khi dùng với dữ liệu có giá trị. Tests dùng cả Home giả, ổ khởi động giả và lookup ứng dụng được tiêm; không quét ổ thật.

## Website mã nguồn mở

Landing page Việt/English nằm trong `site/`, dùng HTML/CSS/JavaScript thuần, không thư viện ngoài hay analytics. Hình giao diện dùng dữ liệu minh họa, không lấy ảnh dữ liệu thật trên máy.

```bash
python3 -m http.server 8000 --directory site
node --test Scripts/test-site.mjs  # Node 22+ chỉ dùng để kiểm tra website
```

GitHub Actions kiểm tra app, bản dịch, bundle và website trước khi deploy `site/` từ nhánh `main` lên [GitHub Pages](https://vuluu2k.github.io/clean-mac/). Các tệp cũng dùng được trên host tĩnh khác, không cần dự án Vercel. Bản tải được xuất bản thành GitHub Release assets, không commit app vào Git. CI kiểm tra DMG Universal trước khi deploy website.

## Đóng góp

Dùng Conventional Commits, ví dụ `feat: add duplicate review`. Đọc [CONVENTIONS.md](CONVENTIONS.md), bổ sung kiểm thử an toàn và chạy toàn bộ preflight trước khi gửi thay đổi.

Mã nguồn: [vuluu2k/clean-mac](https://github.com/vuluu2k/clean-mac). Có thể báo lỗi tại [Issues](https://github.com/vuluu2k/clean-mac/issues).

## Giấy phép và nguồn API

[MIT](LICENSE). Miễn phí sử dụng và chỉnh sửa. Phần mềm cung cấp nguyên trạng, không bảo đảm chống mất dữ liệu.

- [FileManager.trashItem](https://developer.apple.com/documentation/foundation/filemanager/trashitem(at:resultingitemurl:))
- [Apple: Free up storage space on Mac](https://support.apple.com/en-us/102624)
- [NSWorkspace.urlForApplication](https://developer.apple.com/documentation/appkit/nsworkspace/urlforapplication(withbundleidentifier:))
- [Apple: Privacy & Security / Full Disk Access](https://support.apple.com/guide/mac-help/change-privacy-security-settings-on-mac-mchl211c911f/mac)
