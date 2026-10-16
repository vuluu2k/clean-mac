import AppKit
import CleanMacCore
import SwiftUI

struct FindingDetailView: View {
    let item: ScanItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(item.category.title, systemImage: item.category.symbol).font(.title2.bold())
            Text(item.url.lastPathComponent).font(.headline)
            Text(item.url.path).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
            HStack {
                Text(bytesText(item.bytes))
                Spacer()
                Label(item.canTrash ? "Có thể chọn để xem lại" : "Chỉ phân tích, không được dọn", systemImage: item.canTrash ? "checkmark.shield" : "lock")
            }.font(.callout)
            RecommendationBadge(level: item.recommendation)
            Text(item.recommendation.explanation).font(.callout).foregroundStyle(.secondary)
            Divider()
            Text(item.reason).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            Text("Không thấy .app không chứng minh dữ liệu vô dụng. App portable, plugin, công cụ CLI và dữ liệu offline có thể vẫn cần các tệp này.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Hiện trong Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                Spacer()
                Button("Đóng") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(25).frame(width: 640)
    }
}
