import CleanMacCore
import SwiftUI

extension CleanupRecommendation {
    var color: Color {
        switch self {
        case .recommended: .green
        case .review: .orange
        case .keep: .secondary
        }
    }
    var symbol: String {
        switch self {
        case .recommended: "sparkles"
        case .review: "eye"
        case .keep: "lock"
        }
    }
}

struct RecommendationBadge: View {
    let level: CleanupRecommendation
    @Environment(\.locale) private var locale
    var body: some View {
        Label(level.title, systemImage: level.symbol)
            .font(.system(size: 9, weight: .medium)).foregroundStyle(level.color)
            .help(level.explanation)
            .id(locale.identifier) // Refresh deferred core text when the UI locale changes.
    }
}

extension Dashboard {
    @ViewBuilder var recommendationControls: some View {
        if model.hasVisibleResults {
            VStack(alignment: .leading, spacing: 10) {
                Text("Kiểm soát sau khi quét").font(.system(size: 16, weight: .semibold))
                HStack(spacing: 10) {
                    recommendationButton(nil, title: L10n.text("Tất cả"), items: model.report.items)
                    ForEach(CleanupRecommendation.allCases) { level in
                        recommendationButton(level, title: level.title, items: model.report.items.filter { $0.recommendation == level })
                    }
                }
                Text(model.recommendationFilter?.explanation ?? L10n.text("Khuyên dọn không có nghĩa là chắc chắn vô dụng. Cần xem lại vẫn có thể chọn; Không nên xóa bị khóa thao tác. Không chọn sẵn bất cứ tệp nào."))
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func recommendationButton(_ level: CleanupRecommendation?, title: String, items: [ScanItem]) -> some View {
        Button { model.recommendationFilter = level } label: {
            VStack(alignment: .leading, spacing: 7) {
                Label(title, systemImage: level?.symbol ?? "line.3.horizontal.decrease.circle")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(level?.color ?? .primary)
                Text("\(items.count) tệp · \(bytesText(items.reduce(0) { $0 + $1.bytes }))")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(model.recommendationFilter == level ? Palette.mint : .clear, lineWidth: 2))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(model.recommendationFilter == level ? .isSelected : [])
    }
}
