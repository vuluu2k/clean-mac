import AppKit
import CleanMacCore
import SwiftUI

struct ApplicationReviewView: View {
    @ObservedObject var model: AppModel
    let plan: ApplicationRemovalPlan
    @State private var filter: CleanupRecommendation?
    private var visible: [RelatedApplicationFile] { plan.files.filter { filter == nil || $0.recommendation == filter } }
    private var selected: [RelatedApplicationFile] { plan.files.filter { $0.canTrash && model.selectedRelatedIDs.contains($0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Xem lại trước khi gỡ \(plan.application.name)", systemImage: "app.badge.checkmark").font(.title2.bold())
            Text(plan.application.id).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
            Text("Bundle ID: \(plan.application.identifier)").font(.callout).foregroundStyle(.secondary)
            HStack {
                Label("App: \(bytesText(plan.applicationBytes))", systemImage: "app")
                Spacer()
                Text("\(selected.count) tệp dữ liệu chọn thêm · \(bytesText(selected.reduce(0) { $0 + $1.bytes }))")
            }.font(.callout)
            if let reason = plan.protectionReason {
                Label(reason, systemImage: "lock").font(.callout).foregroundStyle(.orange)
            }
            Text("App chỉ được gỡ khi bạn xác nhận bên dưới. Dữ liệu liên quan không được chọn sẵn. Chỉ khớp tên bundle ID; thư mục tên thân thiện, driver và dịch vụ có thể chưa được nhận diện.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Picker("Phân loại", selection: $filter) {
                Text("Tất cả (\(plan.files.count))").tag(CleanupRecommendation?.none)
                ForEach(CleanupRecommendation.allCases) { level in
                    Text("\(level.title) (\(plan.files.filter { $0.recommendation == level }.count))").tag(Optional(level))
                }
            }.pickerStyle(.segmented)
            HStack {
                Button("Chọn dữ liệu khuyên dọn", action: model.selectRecommendedApplicationFiles)
                    .disabled(model.busy || !plan.canRemoveApplication)
                Button("Bỏ chọn dữ liệu") { model.selectedRelatedIDs.removeAll() }.disabled(model.busy)
                Spacer()
                Text("\(visible.count) tệp đang hiển thị").foregroundStyle(.secondary)
            }.font(.system(size: 11))
            List(visible) { file in
                HStack(alignment: .top, spacing: 12) {
                    Toggle("Chọn \(file.id)", isOn: Binding(
                        get: { model.selectedRelatedIDs.contains(file.id) },
                        set: { if $0 { model.selectedRelatedIDs.insert(file.id) } else { model.selectedRelatedIDs.remove(file.id) } }
                    )).labelsHidden().toggleStyle(.checkbox)
                        .disabled(model.busy || !plan.canRemoveApplication || !file.canTrash)
                        .accessibilityLabel("Chọn \(file.id)")
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(file.url.lastPathComponent).fontWeight(.medium)
                            RecommendationBadge(level: file.recommendation)
                            Spacer()
                            Text(bytesText(file.bytes)).font(.system(size: 11, design: .monospaced))
                        }
                        Text(file.id).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                        Text(file.reason).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Button { NSWorkspace.shared.activateFileViewerSelecting([file.url]) } label: { Image(systemName: "folder") }
                        .buttonStyle(.plain).help("Hiện trong Finder")
                }.padding(.vertical, 6)
            }
            if plan.limited || !plan.warnings.isEmpty {
                DisclosureGroup("Phân tích có giới hạn / \(plan.warnings.count) cảnh báo") {
                    Text("Tối đa 50.000 mục duyệt và 20.000 tệp liên quan. Không có nghĩa đã tìm hết dữ liệu của app.").font(.caption)
                    ForEach(plan.warnings) { warning in
                        Text("\(warning.path): \(warning.message)").font(.system(size: 10)).textSelection(.enabled)
                    }
                }.font(.callout).foregroundStyle(.orange)
            }
            Text("Giữ nguyên database, container, dịch vụ và dữ liệu có thể dùng chung. App có thể cần trình gỡ riêng của nhà phát hành; không cam kết gỡ sạch mọi dấu vết.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button("Đóng") { model.applicationPlan = nil }.keyboardShortcut(.cancelAction).disabled(model.busy)
                if model.phase == .uninstalling { ProgressView().controlSize(.small) }
                Spacer()
                Button("Xem lại & gỡ ứng dụng", action: model.prepareApplicationRemoval)
                    .buttonStyle(.borderedProminent).disabled(model.busy || !plan.canRemoveApplication)
            }
        }
        .padding(24).frame(width: 900, height: 740)
        .interactiveDismissDisabled(model.busy)
        .sheet(item: $model.applicationConfirmation) { captured in
            ApplicationRemovalConfirmationView(confirmation: captured,
                onCancel: { model.applicationConfirmation = nil }, onConfirm: { model.uninstallApplication(captured) })
                .environment(\.locale, model.language.locale)
        }
    }
}

struct ApplicationRemovalConfirmationView: View {
    let confirmation: ApplicationRemovalConfirmation
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @State private var acknowledged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Label("Xác nhận gỡ \(confirmation.plan.application.name)", systemImage: "trash").font(.title2.bold())
            Text("App + \(confirmation.files.count) tệp đã chọn · \(bytesText(confirmation.bytes)) dung lượng logic")
                .font(.headline)
            List {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Ứng dụng: \(confirmation.plan.application.name)").fontWeight(.semibold)
                    Text(confirmation.plan.application.id).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                }.padding(.vertical, 5)
                ForEach(confirmation.files) { file in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(file.url.lastPathComponent); Spacer(); Text(bytesText(file.bytes)) }
                        Text(file.id).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                        Text(file.reason).font(.system(size: 10)).foregroundStyle(.secondary)
                    }.padding(.vertical, 5)
                }
            }
            Text("Hãy sao lưu dữ liệu cần giữ. App không force quit, không dùng quyền quản trị và không Empty Trash. Nếu gỡ app thất bại, dữ liệu của app được giữ nguyên. Các lỗi dọn dữ liệu sau đó được báo riêng.")
                .font(.callout).foregroundStyle(.secondary)
            Toggle("Tôi đã xem đường dẫn và đồng ý chuyển ứng dụng cùng các tệp đã chọn vào Trash.", isOn: $acknowledged)
                .font(.callout)
            HStack {
                Button("Hủy", action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Gỡ và chuyển vào Trash", action: onConfirm).buttonStyle(.borderedProminent).disabled(!acknowledged)
            }
        }.padding(25).frame(width: 760, height: 590).interactiveDismissDisabled()
    }
}
