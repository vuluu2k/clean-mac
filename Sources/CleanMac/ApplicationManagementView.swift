import AppKit
import CleanMacCore
import SwiftUI

struct ApplicationManagementView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Gỡ ứng dụng", systemImage: "app.badge.checkmark").font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("Chọn app → xem app và dữ liệu liên quan → xác nhận chuyển vào Trash. Không tự dừng ứng dụng, không gỡ dịch vụ/driver và không xóa vĩnh viễn.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Button(model.applicationCatalog == nil ? "Quét ứng dụng" : "Quét lại ứng dụng", action: model.scanApplications)
                    .buttonStyle(.borderedProminent).tint(Palette.mint).foregroundStyle(Palette.dark)
                    .disabled(model.busy || model.hasOpenReview)
                if model.busy {
                    ProgressView().controlSize(.small)
                    if model.phase == .scanningApplications || model.phase == .reviewingApplication {
                        Button("Dừng phân tích", action: model.cancelScan)
                    }
                }
                Spacer()
                TextField("Tìm tên, bundle ID hoặc đường dẫn", text: $model.applicationQuery)
                    .textFieldStyle(.roundedBorder).frame(width: 280)
            }
            Picker("Khả năng gỡ", selection: $model.applicationFilter) {
                Text("Tất cả").tag(AppModel.ApplicationFilter.all)
                Text("Có thể phân tích để gỡ").tag(AppModel.ApplicationFilter.removable)
                Text("Nên giữ / đang bị khóa").tag(AppModel.ApplicationFilter.keep)
            }.pickerStyle(.segmented)
            if !model.applicationStatus.isEmpty { Text(model.applicationStatus.localized()).font(.callout).foregroundStyle(.secondary) }
            if model.busy && model.phase == .scanning {
                Text("Lượt quét dữ liệu đang chạy. Quay lại Tổng quan để theo dõi; chỉ quét ứng dụng khi tác vụ đó kết thúc.")
                    .font(.callout).foregroundStyle(.orange)
            }
            if let result = model.applicationRemovalReport {
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.applicationMoved ? "Đã chuyển app và \(result.movedFiles.count) tệp dữ liệu vào Trash" : "Ứng dụng chưa được chuyển vào Trash")
                        .font(.headline)
                    Text("\(bytesText(result.bytes)) dung lượng logic đã chuyển, chưa phải dung lượng giải phóng. Kiểm tra Trash và dùng Finder → Put Back khi cần.")
                        .font(.callout).foregroundStyle(.secondary)
                    ForEach(result.failures) { failure in
                        Text("\(failure.path)\n\(failure.message)").font(.system(size: 11)).foregroundStyle(.orange).textSelection(.enabled)
                    }
                }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
            }
            if let catalog = model.applicationCatalog, !catalog.warnings.isEmpty {
                DisclosureGroup("\(catalog.warnings.count) cảnh báo danh mục — dữ liệu liên quan có thể bị khóa dọn") {
                    ForEach(catalog.warnings) { warning in
                        Text("\(warning.path)\n\(warning.message)").font(.system(size: 10)).textSelection(.enabled).padding(.vertical, 4)
                    }
                }.foregroundStyle(.orange)
            }
            Text("Chỉ gỡ app bên thứ ba trong /Applications hoặc ~/Applications. App Apple, hệ thống, clean-mac, app đang chạy và app portable ngoài phạm vi được giữ lại. Dung lượng được tính khi phân tích từng app.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if model.filteredApplications.isEmpty {
                ContentUnavailableView(model.applicationCatalog == nil ? "Quét để xem ứng dụng" : "Không có ứng dụng khớp tìm kiếm", systemImage: "app.dashed")
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(model.filteredApplications) { app in
                        applicationRow(app)
                        Divider().padding(.leading, 48)
                    }
                }.background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func applicationRow(_ app: InstalledApplication) -> some View {
        let reason = model.applicationProtections[app.id]?.localized()
        return HStack(spacing: 13) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path)).resizable().frame(width: 32, height: 32)
                .opacity(reason == nil ? 1 : 0.55)
            VStack(alignment: .leading, spacing: 5) {
                Text(app.name).font(.system(size: 13, weight: .semibold))
                Text(app.identifier).font(.system(size: 10)).foregroundStyle(.secondary)
                Text(app.id).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Text(reason ?? L10n.text("Cần xem lại · Bạn quyết định app nào không còn cần."))
                    .font(.system(size: 10)).foregroundStyle(reason == nil ? Color.secondary : .orange)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Button { NSWorkspace.shared.activateFileViewerSelecting([app.url]) } label: { Image(systemName: "folder") }
                .buttonStyle(.plain).help("Hiện ứng dụng trong Finder")
            Button(reason == nil ? "Phân tích để gỡ" : "Xem giới hạn") { model.reviewApplication(app) }
                .disabled(model.busy || model.hasOpenReview)
        }.padding(15)
    }
}

extension Dashboard {
    var applicationNavigationRow: some View {
        Button { model.page = .applications } label: {
            HStack(spacing: 11) {
                Image(systemName: "app.badge.checkmark").frame(width: 18)
                Text("Gỡ ứng dụng").lineLimit(1).minimumScaleFactor(0.8)
                Spacer()
                if let count = model.applicationCatalog?.applications.count { Text("\(count)").font(.system(size: 10, design: .monospaced)) }
            }
            .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 12)
            .foregroundStyle(model.page == .applications ? Palette.mint : .white.opacity(0.65))
            .background(model.page == .applications ? .white.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(model.page == .applications ? .isSelected : [])
    }
}
