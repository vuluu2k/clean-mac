import AppKit
import CleanMacCore
import SwiftUI

enum Palette {
    static let mint = Color(red: 0.39, green: 0.91, blue: 0.72)
    static let dark = Color(red: 0.06, green: 0.12, blue: 0.13)
    static let card = Color(nsColor: .controlBackgroundColor)
}

struct Dashboard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if model.page == .cleaner {
                            header
                            scanControls
                            overview
                            scanCoverage
                            recommendationControls
                            categoryCards
                            statusMessages
                            folderAnalysis
                            results
                        } else {
                            ApplicationManagementView(model: model)
                        }
                    }
                    .padding(30)
                }
                if model.page == .cleaner { footer }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 1080, minHeight: 740)
        .task { await model.refreshDisk() }
        .task { await model.updates.checkAutomatically() }
        .sheet(item: $model.confirmation) { captured in
            ConfirmationView(confirmation: captured, onCancel: { model.confirmation = nil }, onConfirm: { model.clean(captured) })
                .environment(\.locale, model.language.locale)
        }
        .sheet(isPresented: $model.showIssues) { issuesSheet.environment(\.locale, model.language.locale) }
        .sheet(isPresented: $model.showUpdates) { AppUpdateView(updates: model.updates, busy: model.busy).environment(\.locale, model.language.locale) }
        .sheet(item: $model.inspectedItem) { item in FindingDetailView(item: item).environment(\.locale, model.language.locale) }
        .sheet(item: $model.applicationPlan) { plan in ApplicationReviewView(model: model, plan: plan).environment(\.locale, model.language.locale) }
        .alert(L10n.text("Không thể thực hiện"), isPresented: Binding(
            get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button(L10n.text("Đóng"), role: .cancel) { model.alertMessage = nil }
        } message: { Text(model.alertMessage ?? "") }
        .environment(\.locale, model.language.locale)
    }

    private var sidebar: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 11) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 24)).foregroundStyle(Palette.mint)
                    .frame(width: 44, height: 44).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("clean-mac").font(.system(size: 21, weight: .semibold))
                    Text("NHẸ HƠN MỖI NGÀY").font(.system(size: 8, weight: .medium)).tracking(1.8).foregroundStyle(.white.opacity(0.5))
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "globe")
                Picker("Ngôn ngữ", selection: Binding(get: { model.language }, set: { model.setLanguage($0) })) {
                    ForEach(AppLanguage.allCases) { language in Text(language.title).tag(language) }
                }.labelsHidden().pickerStyle(.menu)
            }
            .font(.system(size: 12)).disabled(model.busy || model.hasOpenReview)
            .help("Đổi ngôn ngữ khi không có tác vụ hoặc màn hình xác nhận. Lựa chọn được lưu trên máy.")
            VStack(alignment: .leading, spacing: 7) {
                Text("KHÔNG GIAN LƯU TRỮ").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(.white.opacity(0.45)).padding(.bottom, 7)
                navigationRow(title: L10n.text("Tổng quan"), symbol: "square.grid.2x2", category: nil)
                applicationNavigationRow
                ForEach(CleanupCategory.allCases) { category in
                    navigationRow(title: category.title, symbol: category.symbol, category: category)
                }
            }
            Divider().overlay(.white.opacity(0.08))
            VStack(alignment: .leading, spacing: 12) {
                Text("PHẠM VI QUÉT").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(.white.opacity(0.45))
                Label(model.scanMode == .deep ? "Ổ khởi động /" : "Cache · Logs · Xcode", systemImage: "folder").font(.system(size: 11))
                Label(model.scanMode == .deep ? "Library · Ứng dụng · Tệp lớn" : "Downloads", systemImage: "arrow.down.circle").font(.system(size: 11))
                ForEach(model.reviewFolders, id: \.path) { folder in
                    HStack {
                        Label(folder.lastPathComponent, systemImage: "folder.badge.plus").lineLimit(1)
                        Spacer(minLength: 0)
                        Button { model.removeFolder(folder) } label: { Image(systemName: "xmark.circle") }
                            .buttonStyle(.plain).disabled(model.busy).accessibilityLabel("Bỏ thư mục \(folder.path)")
                    }
                    .font(.system(size: 11)).help(folder.path)
                }
                Button(action: model.chooseFolders) {
                    Label("Thêm thư mục", systemImage: "plus").font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain).foregroundStyle(Palette.mint).disabled(model.busy)
            }
            .foregroundStyle(.white.opacity(0.7))
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 8) {
                Label("Riêng tư từ thiết kế", systemImage: "lock.shield").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.mint)
                Text("Quét cục bộ. Không tài khoản.\nKhông gửi dữ liệu quét.")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).lineSpacing(4)
                UpdateStatusButton(updates: model.updates) { model.showUpdates = true }.disabled(model.hasOpenReview)
                Text("v\(model.updates.currentVersion) · Mã nguồn mở").font(.system(size: 9)).foregroundStyle(.white.opacity(0.3)).padding(.top, 7)
            }
        }
        .padding(.vertical, 24).padding(.horizontal, 18)
        }
        .frame(width: 244).frame(maxHeight: .infinity)
        .foregroundStyle(.white)
        .background(LinearGradient(colors: [Palette.dark, Color(red: 0.04, green: 0.09, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func navigationRow(title: String, symbol: String, category: CleanupCategory?) -> some View {
        let selected = model.page == .cleaner && model.category == category
        return Button { model.page = .cleaner; model.category = category } label: {
            HStack(spacing: 11) {
                Image(systemName: symbol).frame(width: 18)
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
                Spacer()
                if model.hasVisibleResults {
                    Text("\(model.report.items.filter { category == nil || $0.category == category }.count)")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                }
            }
            .font(.system(size: 12, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? Palette.mint : .white.opacity(0.65))
            .padding(.horizontal, 10).padding(.vertical, 12)
            .background(selected ? .white.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var categoryCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
            ForEach(CleanupCategory.allCases) { category in
                let items = model.report.items.filter { $0.category == category }
                Button { model.category = model.category == category ? nil : category } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: category.symbol).font(.system(size: 17)).foregroundStyle(.secondary)
                        Text(model.hasVisibleResults ? bytesText(items.reduce(0) { $0 + $1.bytes }) : "—")
                            .font(.system(size: 17, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                        Text(category.title).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(15)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(model.category == category ? Palette.mint : Color.primary.opacity(0.05), lineWidth: model.category == category ? 2 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).help(category.reason)
            }
        }
    }

    @ViewBuilder private var statusMessages: some View {
        if model.scanMode == .deep {
            notice("Quét sâu phần macOS cho phép đọc", detail: "Full Disk Access giúp đọc nhiều thư mục hơn. Hãy tự bật cho clean-mac rồi mở lại app. Không vượt SIP; bỏ qua ổ ngoài, đường dẫn APFS lặp, Trash và thư mục thông tin đăng nhập.", symbol: "lock.shield", color: .blue)
        }
        if let count = model.report.applicationCount {
            Text("Đã nhận diện \(count) bundle ID · \(model.report.leftoverApplicationCount) nhóm nghi còn sót · \(bytesText(model.report.cleanupBytes)) có thể chọn dọn")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        if model.report.cancelled {
            notice("Kết quả chưa đầy đủ", detail: "Bạn đã dừng quét. Các mục bên dưới chỉ là kết quả một phần.", symbol: "exclamationmark.triangle", color: .orange)
        }
        if let cleanup = model.cleanupReport {
            notice("Đã chuyển \(cleanup.moved.count) tệp (\(bytesText(cleanup.bytes))) vào Trash", detail: "Chưa giải phóng dung lượng. Bạn tự Empty Trash trong Finder sau khi kiểm tra. Có thể dùng Put Back để khôi phục.", symbol: cleanup.failures.isEmpty ? "checkmark.circle" : "exclamationmark.triangle", color: cleanup.failures.isEmpty ? .green : .orange)
        }
        if model.issueCount > 0 {
            Button { model.showIssues = true } label: {
                HStack {
                    Label("\(model.issueCount) cảnh báo / thao tác không thành công", systemImage: "exclamationmark.triangle")
                    Spacer()
                    Text("Xem chi tiết").underline()
                }.font(.system(size: 11)).foregroundStyle(.orange)
            }.buttonStyle(.plain)
        }
    }

    private func notice(_ title: String.LocalizationValue, detail: String.LocalizationValue, symbol: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text(title)).font(.system(size: 12, weight: .semibold))
                Text(L10n.text(detail)).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(13)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.category?.title ?? L10n.text("Đề xuất dọn dẹp")).font(.system(size: 17, weight: .semibold))
                    Text("\(model.filteredItems.count) tệp đang hiển thị · Lớn nhất trước · Không chọn sẵn")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Tìm tên hoặc đường dẫn", text: $model.query).textFieldStyle(.plain)
                }
                .font(.system(size: 11)).padding(9).frame(width: 220)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 8))
            }
            if let category = model.category {
                Text(category.reason).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack {
                Button("Chọn tệp có thể dọn", action: model.selectVisible).disabled(model.busy || !model.filteredItems.contains(where: \.canTrash))
                Button("Bỏ chọn tất cả") { model.selectedIDs.removeAll() }.disabled(model.busy || model.selectedIDs.isEmpty)
                Spacer()
                Text("Tuổi tệp ≠ không còn sử dụng").foregroundStyle(.secondary)
            }
            .buttonStyle(.link).font(.system(size: 10))
            if model.filteredItems.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(model.filteredItems) { item in
                        fileRow(item)
                        Divider().padding(.leading, 46)
                    }
                }
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: model.phase == .scanning ? "sparkle.magnifyingglass" : "tray")
                .font(.system(size: 30, weight: .light)).foregroundStyle(.secondary)
            Text(model.phase == .scanning ? "Đang tìm gợi ý…" : model.hasScanned ? "Không có tệp khớp bộ lọc" : "Quét trước. Quyết định sau.")
                .font(.system(size: 14, weight: .medium))
            Text(model.phase == .scanning ? "Kết quả tạm cập nhật trong lúc quét. Không cần chờ toàn ổ mới xem được kết quả." : model.hasScanned ? "Số tệp khớp bộ lọc không phải số tệp đã quét. Xem thống kê độ phủ và cảnh báo ở trên." : "Chưa đọc nội dung thư mục. Chọn chế độ rồi bấm Quét để bắt đầu.")
                .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(30).frame(maxWidth: .infinity, minHeight: 170)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 13))
    }

    private func fileRow(_ item: ScanItem) -> some View {
        HStack(spacing: 13) {
            Toggle(isOn: Binding(
                get: { model.selectedIDs.contains(item.id) },
                set: { if $0 { model.selectedIDs.insert(item.id) } else { model.selectedIDs.remove(item.id) } }
            )) { Text("Chọn \(item.url.path)") }
                .labelsHidden().toggleStyle(.checkbox).disabled(model.busy || !item.canTrash)
                .accessibilityLabel("Chọn \(item.url.path)")
            Image(systemName: item.category.symbol).font(.system(size: 17)).foregroundStyle(.secondary)
                .frame(width: 33, height: 37).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(item.url.lastPathComponent).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                    RecommendationBadge(level: item.recommendation)
                }
                if let identifier = item.applicationID {
                    Text("Nghi còn sót · \(identifier)").font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(item.url.deletingLastPathComponent().path.replacingOccurrences(of: model.home.path, with: "~"))
                    .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading).help(item.url.path + "\n" + item.reason)
            VStack(alignment: .trailing, spacing: 4) {
                Text(bytesText(item.bytes)).font(.system(size: 12, weight: .semibold, design: .monospaced))
                Text(item.snapshot.modifiedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: model.language.locale))).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            .frame(width: 100, alignment: .trailing)
            Button { model.inspectedItem = item } label: { Image(systemName: "info.circle") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Xem bằng chứng và giới hạn dọn")
                .accessibilityLabel("Thông tin \(item.url.lastPathComponent)")
            Button { NSWorkspace.shared.activateFileViewerSelecting([item.url]) } label: { Image(systemName: "folder") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Hiện trong Finder")
                .accessibilityLabel("Hiện \(item.url.lastPathComponent) trong Finder")
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.shield").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.phase == .cleaning ? "Đang kiểm tra và chuyển vào Trash…" : "\(model.selectedItems.count) tệp đã chọn · \(bytesText(model.selectedBytes))")
                    .font(.system(size: 12, weight: .semibold))
                Text("Luôn xem lại. Chỉ chuyển vào Trash sau khi xác nhận.").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            if model.phase == .cleaning { ProgressView().controlSize(.small) }
            Button(action: model.prepareCleanup) {
                Label("Xem lại & dọn", systemImage: "trash").font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .foregroundStyle(model.selectedItems.isEmpty ? Color.secondary : Palette.dark)
                    .background(model.selectedItems.isEmpty ? Color.primary.opacity(0.06) : Palette.mint, in: Capsule())
            }
            .buttonStyle(.plain).disabled(model.busy || model.selectedItems.isEmpty)
        }
        .padding(.horizontal, 30).padding(.vertical, 18)
        .background(Palette.card).overlay(alignment: .top) { Divider() }
    }

    private var issuesSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Các mục chưa xử lý được").font(.title2.bold())
            Text("Không tự vượt quyền macOS. Với thư mục bị chặn, hãy cấp Files and Folders hoặc Full Disk Access nếu muốn, mở lại app rồi quét lại.")
                .font(.callout).foregroundStyle(.secondary)
            List {
                ForEach(model.report.warnings) { warning in
                    issueRow(path: warning.path, message: warning.message)
                }
                ForEach(model.cleanupReport?.failures ?? []) { failure in
                    issueRow(path: failure.path, message: failure.message)
                }
            }
            HStack { Spacer(); Button("Đóng") { model.showIssues = false }.keyboardShortcut(.cancelAction) }
        }
        .padding(24).frame(width: 650, height: 460)
    }

    private func issueRow(path: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(path).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
            Text(message).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 5)
    }
}
