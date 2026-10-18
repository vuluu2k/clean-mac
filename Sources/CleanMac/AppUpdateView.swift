import CleanMacCore
import SwiftUI

struct UpdateStatusButton: View {
    @ObservedObject var updates: AppUpdates
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if case .available = updates.state {
                Label("Có phiên bản mới", systemImage: "arrow.down.circle.fill").foregroundStyle(Palette.mint)
            } else {
                Label("Kiểm tra cập nhật…", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(.white.opacity(0.65))
            }
        }
        .font(.system(size: 11)).buttonStyle(.plain).padding(.vertical, 5)
    }
}

struct AppUpdateView: View {
    @ObservedObject var updates: AppUpdates
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "arrow.down.circle").font(.system(size: 34)).foregroundStyle(Palette.mint)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Cập nhật clean-mac").font(.title2.bold())
                    Text("Đang dùng phiên bản \(updates.currentVersion)").font(.callout).foregroundStyle(.secondary)
                }
            }
            Group {
                switch updates.state {
                case .idle: Text("Kiểm tra bản phát hành mới trên GitHub khi bạn muốn.")
                case .checking: HStack { ProgressView().controlSize(.small); Text("Đang kiểm tra GitHub…") }
                case .upToDate: Label("Không có phiên bản mới hơn.", systemImage: "checkmark.circle")
                case .available(let release):
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Đã có phiên bản \(release.version.description)").font(.headline)
                        Link(destination: release.url) { Label("Xem và tải bản mới", systemImage: "arrow.up.right") }
                        Text("Tải bản mới từ GitHub, đóng app khi tác vụ đã xong rồi cài thay bản cũ. App không tự tải hoặc cài đè.")
                    }
                case .failed:
                    Text("Chưa kiểm tra được phiên bản. Kiểm tra kết nối mạng rồi thử lại; GitHub có thể giới hạn lượt truy cập.").foregroundStyle(.orange)
                }
            }
            .font(.callout)
            Divider()
            Toggle("Tự kiểm tra phiên bản khi mở app", isOn: $updates.automaticallyChecks)
                .disabled(!updates.canCheck)
            Text("Mặc định tắt. Khi bật, kiểm tra tối đa một lần mỗi ngày lúc mở app. Không hiện hộp thoại làm gián đoạn tác vụ.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Chỉ kết nối GitHub để đọc phiên bản công khai. GitHub có thể thấy IP và thông tin yêu cầu; không gửi tên tệp, đường dẫn hoặc kết quả quét.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Đóng") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Kiểm tra ngay") { Task { await updates.check() } }
                    .disabled(updates.state == .checking || !updates.canCheck)
            }
        }
        .padding(28).frame(width: 500)
    }
}
