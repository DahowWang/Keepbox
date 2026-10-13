import Foundation

/// 同步伺服器上的一筆資料（對應 server/ 的 records 表）。
struct SyncRecord {
    enum RecordType: String {
        case file, folder, tag
    }

    var type: RecordType
    var id: UUID
    var updatedAt: Int64
    var deleted: Bool
    var data: [String: Any]

    var json: [String: Any] {
        ["type": type.rawValue, "id": id.uuidString, "updatedAt": updatedAt, "deleted": deleted, "data": data]
    }

    init(type: RecordType, id: UUID, updatedAt: Int64, deleted: Bool, data: [String: Any]) {
        self.type = type
        self.id = id
        self.updatedAt = updatedAt
        self.deleted = deleted
        self.data = data
    }

    init?(json: [String: Any]) {
        guard let typeName = json["type"] as? String, let type = RecordType(rawValue: typeName),
              let idString = json["id"] as? String, let id = UUID(uuidString: idString),
              let updatedAt = json["updatedAt"] as? NSNumber else { return nil }
        self.init(type: type, id: id, updatedAt: updatedAt.int64Value,
                  deleted: json["deleted"] as? Bool ?? false,
                  data: json["data"] as? [String: Any] ?? [:])
    }
}

enum SyncError: LocalizedError {
    case unauthorized
    case server(Int)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "同步 token 不正確"
        case .server(let code): return "同步伺服器錯誤（\(code)）"
        case .badResponse: return "同步伺服器回應格式不正確"
        }
    }
}

struct SyncClient {
    static let maxPushBatch = 200

    let baseURL: URL
    let token: String
    var session: URLSession = .shared

    struct ChangesPage {
        var records: [SyncRecord]
        var cursor: Int
        var more: Bool
    }

    func changes(since cursor: Int) async throws -> ChangesPage {
        var components = URLComponents(url: baseURL.appending(path: "v1/changes"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "since", value: String(cursor))]
        let (data, _) = try await send(URLRequest(url: components.url!))
        guard let body = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawRecords = body["records"] as? [[String: Any]],
              let next = body["cursor"] as? Int else { throw SyncError.badResponse }
        return ChangesPage(records: rawRecords.compactMap(SyncRecord.init(json:)),
                           cursor: next, more: body["more"] as? Bool ?? false)
    }

    func push(_ records: [SyncRecord]) async throws {
        var request = URLRequest(url: baseURL.appending(path: "v1/push"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["records": records.map(\.json)])
        _ = try await send(request)
    }

    func putContent(id: UUID, html: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "v1/content/\(id.uuidString)"))
        request.httpMethod = "PUT"
        request.setValue("text/html; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(html.utf8)
        _ = try await send(request)
    }

    /// 伺服器還沒有這份內容時回傳 nil（例如另一台裝置還在上傳）。
    func getContent(id: UUID) async throws -> String? {
        let request = URLRequest(url: baseURL.appending(path: "v1/content/\(id.uuidString)"))
        let (data, status) = try await send(request, allowNotFound: true)
        guard status != 404 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private func send(_ request: URLRequest, allowNotFound: Bool = false) async throws -> (Data, Int) {
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.badResponse }
        switch http.statusCode {
        case 200..<300: return (data, http.statusCode)
        case 404 where allowNotFound: return (data, 404)
        case 401: throw SyncError.unauthorized
        default: throw SyncError.server(http.statusCode)
        }
    }
}
