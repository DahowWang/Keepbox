import Foundation
import SwiftData

/// 本機刪除紀錄，推上同步伺服器後就移除，讓其他裝置知道要跟著刪。
@Model
final class SyncTombstone {
    var recordType: String
    var recordID: UUID
    var deletedAt: Date

    init(recordType: String, recordID: UUID) {
        self.recordType = recordType
        self.recordID = recordID
        self.deletedAt = Date()
    }
}
