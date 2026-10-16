import AppKit
import CleanMacCore
import SwiftUI

extension Dashboard {
    var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                Text("ÍT BỪA BỘN. THÊM KHÔNG GIAN.").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(.secondary)
                Text("Dọn gọn. Nhẹ máy.").font(.system(size: 30, weight: .semibold, design: .rounded))
            }
            Spacer()
            Label("100% CỤC BỘ", systemImage: "checkmark.shield.fill")
                .font(.system(size: 9, weight: .semibold)).tracking(0.8)
                .foregroundStyle(.secondary).padding(10)
                .background(Palette.card, in: Capsule())
        }
    }

    var scanControls: some View {
        HStack {
            Picker("Chế độ quét", selection: Binding(get: { model.scanMode }, set: { model.setScanMode($0) })) {
                Text("Quét nhanh").tag(ScanMode.quick)
                Text("Quét sâu toàn ổ").tag(ScanMode.deep)
            }
            .pickerStyle(.segmented).frame(width: 310).disabled(model.busy || model.confirmation != nil)
            Spacer()
            if model.scanMode == .deep {
                Button(action: model.openFullDiskAccessSettings) {
                    Label("Full Disk Access", systemImage: "lock.open")
                }
                .help("Mở cài đặt để tự bật quyền cho clean-mac. Không tự thay đổi quyền hệ thống.")
            }
        }
    }

    var overview: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Label(model.phase == .scanning ? "KẾT QUẢ TẠM · ĐANG QUÉT" : model.hasVisibleResults ? (model.scanMode == .deep ? "DUNG LƯỢNG TỆP ĐÃ GHI NHẬN" : "DUNG LƯỢNG KHỚP QUY TẮC") : "BẮT ĐẦU TỪ MỘT LẦN QUÉT", systemImage: "sparkles")
                    .font(.system(size: 10, weight: .semibold)).tracking(1.3).foregroundStyle(Palette.mint)
                Text(model.hasVisibleResults ? bytesText(model.scanMode == .deep ? model.report.scannedBytes : model.report.bytes) : model.phase == .scanning ? L10n.text("Đang phân tích…") : L10n.text("Một chiếc Mac gọn hơn."))
                    .font(.system(size: model.hasVisibleResults ? 43 : 28, weight: .medium, design: .rounded)).foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(model.hasVisibleResults ? "\(model.report.items.count) tệp đang hiển thị · \(bytesText(model.report.cleanupBytes)) khớp phạm vi dọn. Dung lượng đã ghi nhận không phải dung lượng rác." : model.scanMode == .deep ? "Duyệt ổ khởi động, cộng cả tệp nhỏ vào thư mục.\nBạn quyết định giữ gì, dọn gì." : "Tìm cache cũ, dữ liệu build và tệp lớn.\nBạn quyết định giữ gì, dọn gì.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65)).lineSpacing(4)
                HStack(spacing: 14) {
                    Button(action: model.scan) {
                        Label(model.hasScanned ? "Quét lại" : model.scanMode == .deep ? "Quét sâu toàn ổ" : "Quét thông minh", systemImage: "sparkle.magnifyingglass")
                            .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 16).padding(.vertical, 11)
                            .foregroundStyle(Palette.dark).background(Palette.mint, in: Capsule())
                    }
                    .buttonStyle(.plain).disabled(model.busy)
                    if model.phase == .scanning {
                        ProgressView().controlSize(.small).tint(Palette.mint)
                        Button("Dừng quét", action: model.cancelScan).buttonStyle(.plain).foregroundStyle(.white)
                    } else {
                        Text("Không xóa vĩnh viễn").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                    }
                }
                if let progress = model.progress {
                    Text("\(progress.category.title) · \(progress.visitedFiles) lượt kiểm tra tệp")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                    if let path = progress.currentPath {
                        Text(path).font(.system(size: 9)).foregroundStyle(.white.opacity(0.5)).lineLimit(1).truncationMode(.middle)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let disk = model.disk {
                DiskRing(disk: disk)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "externaldrive").font(.largeTitle)
                    Text("Chưa đọc được ổ đĩa").font(.caption)
                }
                .foregroundStyle(.white.opacity(0.6)).frame(width: 160).help(model.diskError ?? L10n.text("Đang đọc dung lượng"))
            }
        }
        .padding(27).frame(maxWidth: .infinity, minHeight: 230)
        .background(LinearGradient(colors: [Palette.dark, Color(red: 0.09, green: 0.23, blue: 0.22)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct DiskRing: View {
    let disk: DiskSpace
    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle().stroke(.white.opacity(0.1), lineWidth: 9)
                Circle().trim(from: 0, to: CGFloat(max(0, min(1, Double(disk.available) / Double(disk.total)))))
                    .stroke(Palette.mint, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 5) {
                    Text(bytesText(disk.available)).font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("CÒN TRỐNG").font(.system(size: 8, weight: .medium)).tracking(1.5).foregroundStyle(.white.opacity(0.55))
                }.foregroundStyle(.white)
            }.frame(width: 130, height: 130)
            Text("Ổ đĩa Home · \(bytesText(disk.total))").font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
        }
        .frame(width: 165)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ổ đĩa còn trống \(bytesText(disk.available)) trên tổng \(bytesText(disk.total))")
    }
}

struct ConfirmationView: View {
    let confirmation: CleanupConfirmation
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @State private var acknowledged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Xem lại trước khi dọn", systemImage: "trash").font(.title2.bold())
            Text("\(confirmation.items.count) tệp · \(bytesText(confirmation.bytes)) dung lượng logic")
                .font(.headline)
            Text("Đóng ứng dụng liên quan trước khi dọn cache hoặc build. Tệp cũ và tệp lớn vẫn có thể quan trọng.")
                .foregroundStyle(.secondary)
            List(confirmation.items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(item.url.lastPathComponent).fontWeight(.medium); Spacer(); Text(bytesText(item.bytes)) }
                    Text(item.url.path).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                    Text(item.reason).font(.system(size: 10)).foregroundStyle(.secondary)
                }.padding(.vertical, 5)
            }
            Text("Chuyển vào Trash chưa làm tăng dung lượng trống. App không Empty Trash. Dùng Finder → Put Back để khôi phục khi có thể.")
                .font(.callout).foregroundStyle(.secondary)
            Toggle("Tôi đã xem danh sách và chấp nhận chuyển các tệp này vào Trash.", isOn: $acknowledged)
                .font(.callout)
            HStack {
                Button("Hủy", action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Chuyển \(confirmation.items.count) tệp vào Trash", action: onConfirm)
                    .buttonStyle(.borderedProminent).tint(.accentColor).disabled(!acknowledged)
            }
        }
        .padding(26).frame(width: 700, height: 580)
        .interactiveDismissDisabled()
    }
}
