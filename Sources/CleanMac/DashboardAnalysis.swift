import AppKit
import CleanMacCore
import SwiftUI

extension Dashboard {
    @ViewBuilder var scanCoverage: some View {
        if model.hasVisibleResults {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 20) {
                    coverageMetric("Lượt kiểm tra tệp", value: model.report.visitedFiles.formatted())
                    coverageMetric("Thư mục đã ghi nhận", value: model.report.visitedDirectories.formatted())
                    coverageMetric("Dung lượng logic đã ghi nhận", value: bytesText(model.report.scannedBytes))
                    Button { model.showIssues = true } label: {
                        coverageMetric("Lỗi đọc đã ghi nhận", value: model.report.readErrors.formatted())
                    }.buttonStyle(.plain).disabled(model.report.readErrors == 0)
                }
                if model.phase == .scanning {
                    Text("Đang quét · Danh sách tạm giữ tối đa 500 tệp và cập nhật trong lúc duyệt. Chưa cho phép dọn.")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.blue)
                }
                Text("Số gợi ý không phải số tệp đã quét. Lượt kiểm tra có thể trùng giữa các giai đoạn. Dung lượng logic không phải dung lượng có thể giải phóng.")
                    .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if model.report.readErrors > 0 {
                    Text("Một số đường dẫn không đọc được. Bấm số lỗi để xem chi tiết; lưu tối đa 100 cảnh báo. Không coi kết quả là toàn bộ dữ liệu trên máy.")
                        .font(.system(size: 10)).foregroundStyle(.orange)
                }
            }
            .padding(15).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func coverageMetric(_ title: String.LocalizationValue, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.system(size: 18, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
            Text(L10n.text(title)).font(.system(size: 10)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder var folderAnalysis: some View {
        if model.scanMode == .deep && model.hasVisibleResults && (model.category == nil || model.category == .systemFiles) && (model.recommendationFilter == nil || model.recommendationFilter == .keep) {
            let folders = model.report.folderUsages.filter { model.query.isEmpty || $0.url.path.localizedCaseInsensitiveContains(model.query) }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Thư mục chiếm dung lượng").font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Label("Chỉ phân tích", systemImage: "lock").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Text("Cộng cả tệp nhỏ, không chỉ tệp từ 10 MB. Thư mục lớn không có nghĩa là rác; app không cho chọn dọn cả thư mục.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                if folders.isEmpty {
                    Text(model.phase == .scanning ? "Đang tổng hợp thư mục từ 100 MB…" : "Chưa có thư mục từ 100 MB khớp tìm kiếm trong phần đọc được.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).padding(.vertical, 10)
                }
                LazyVStack(spacing: 0) {
                    ForEach(folders.prefix(8)) { folder in folderRow(folder) }
                    if folders.count > 8 {
                        DisclosureGroup("Xem thêm \(folders.count - 8) thư mục") {
                            ForEach(folders.dropFirst(8)) { folder in folderRow(folder) }
                        }.font(.system(size: 11)).padding(12)
                    }
                }
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                if model.report.folderSummaryLimited {
                    Text("Đã chạm giới hạn chi tiết thư mục (8 cấp / 50.000 mục). Lượt duyệt tệp vẫn tiếp tục; các thư mục cha đã theo dõi vẫn được cộng dung lượng.")
                        .font(.system(size: 10)).foregroundStyle(.orange)
                }
                Text("Tổng hợp tối đa 8 cấp / 50.000 thư mục; hiển thị 100 mục lớn nhất. Thư mục cha đã gồm thư mục con: không cộng các hàng với nhau. Số liệu là snapshot, có thể một phần khi đang quét hoặc có lỗi đọc.")
                    .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func folderRow(_ folder: FolderUsage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "folder").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.url.lastPathComponent).font(.system(size: 12, weight: .medium))
                Text(folder.url.path).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }.frame(maxWidth: .infinity, alignment: .leading).help(folder.url.path)
            VStack(alignment: .trailing, spacing: 4) {
                Text(bytesText(folder.bytes)).font(.system(size: 12, weight: .semibold, design: .monospaced))
                Text("\(folder.fileCount) tệp đã ghi nhận").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Button { NSWorkspace.shared.activateFileViewerSelecting([folder.url]) } label: { Image(systemName: "folder.badge.magnifyingglass") }
                .buttonStyle(.plain).help("Hiện thư mục trong Finder; không dọn")
                .accessibilityLabel("Hiện \(folder.url.path) trong Finder")
        }.padding(13)
    }
}
