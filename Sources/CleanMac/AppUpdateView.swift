import CleanMacCore
import SwiftUI

struct UpdateStatusButton: View {
    @ObservedObject var updates: AppUpdates
    let action: () -> Void

    var body: some View {
        // Only an available update earns sidebar space; manual checks live in the app menu.
        if updates.release != nil {
            Button(action: action) {
                Label("Có phiên bản mới", systemImage: "arrow.down.circle.fill").foregroundStyle(Palette.mint)
            }
            .font(.system(size: 11)).buttonStyle(.plain).padding(.vertical, 5)
        }
    }
}

struct AppUpdateView: View {
    @ObservedObject var updates: AppUpdates
    var busy = false
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
                case .installed(let release):
                    Label("Đã cài phiên bản \(release.version.description). Thoát rồi mở lại app để dùng bản mới.", systemImage: "checkmark.circle")
                        .fixedSize(horizontal: false, vertical: true)
                case .available(let release), .installing(let release), .installFailed(let release):
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Đã có phiên bản \(release.version.description)").font(.headline)
                        if updates.installTarget != nil {
                            HStack(spacing: 12) {
                                Button("Cập nhật ngay") { Task { await updates.install(release) } }
                                    .buttonStyle(.borderedProminent).disabled(updates.isWorking || busy)
                                if case .installing = updates.state {
                                    ProgressView().controlSize(.small)
                                    Text("Đang tải và kiểm tra bản mới…").foregroundStyle(.secondary)
                                }
                            }
                            Text("Tải DMG từ GitHub, kiểm tra SHA-256, bundle ID, phiên bản và chữ ký, thay bản hiện tại (bản cũ vào Trash) rồi mở lại app.")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Cập nhật một chạm cần app nằm trong thư mục Applications. Hãy tải bản mới từ GitHub.")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        if case .installFailed = updates.state {
                            Text("Chưa cài được bản mới. App hiện tại vẫn giữ nguyên; bạn có thể tải từ GitHub.").foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                        }
                        Link(destination: release.url) { Label("Xem và tải bản mới", systemImage: "arrow.up.right") }.font(.caption)
                    }
                case .failed:
                    Text("Chưa kiểm tra được phiên bản. Kiểm tra kết nối mạng rồi thử lại; GitHub có thể giới hạn lượt truy cập.").foregroundStyle(.orange)
                }
            }
            .font(.callout)
            Divider()
            Toggle("Tự kiểm tra phiên bản khi mở app", isOn: $updates.automaticallyChecks)
                .disabled(!updates.canCheck || updates.isWorking)
            Text("Mặc định tắt. Khi bật, kiểm tra tối đa một lần mỗi ngày lúc mở app. Không hiện hộp thoại làm gián đoạn tác vụ.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Chỉ kết nối GitHub để đọc phiên bản công khai và tải bản cập nhật khi bạn bấm. GitHub có thể thấy IP và thông tin yêu cầu; không gửi tên tệp, đường dẫn hoặc kết quả quét.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Đóng") { dismiss() }.keyboardShortcut(.cancelAction).disabled(updates.isWorking)
                Spacer()
                Button("Kiểm tra ngay") { Task { await updates.check() } }
                    .disabled(updates.isWorking || !updates.canCheck)
            }
        }
        .padding(28).frame(width: 500)
    }
}
