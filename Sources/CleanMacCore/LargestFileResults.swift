import Foundation

struct LargestFileResults {
    let limit: Int
    private var items: [ScanItem] = []
    private(set) var limited = false
    var count: Int { min(items.count, limit) }

    init(limit: Int) { precondition(limit > 0); self.limit = limit }

    mutating func insert(_ item: ScanItem) {
        if items.count >= limit { limited = true }
        items.append(item)
        if items.count >= limit * 2 { items = largest }
    }

    var largest: [ScanItem] {
        Array(items.sorted { $0.bytes == $1.bytes ? $0.id < $1.id : $0.bytes > $1.bytes }.prefix(limit))
    }
}
