import Foundation
import CoreLocation

/// Thin HTTP client for the Rare Finder FastAPI backend.
struct BackendClient {
    var baseURL: URL
    var session: URLSession
    /// Closure that returns the current bearer token, or nil. Looked up on
    /// every request so logout/login updates take effect immediately
    /// without rebuilding the client.
    var tokenProvider: () -> String? = {
        UserDefaults.standard.string(forKey: "rf.authToken")
    }

    init(
        baseURL: URL = URL(string: "http://localhost:8000")!,
        session: URLSession = .shared,
        tokenProvider: (() -> String?)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        if let tokenProvider { self.tokenProvider = tokenProvider }
    }

    private func attachAuth(to request: inout URLRequest) {
        if let token = tokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    // MARK: - DTOs

    struct BountyDTO: Decodable {
        let id: UUID
        let title: String
        let summary: String
        let detail: String
        let category: String
        let status: String
        let latitude: Double
        let longitude: Double
        let district: String
        let verified_count: Int
        let upvotes: Int
        let downvotes: Int
        let intel_score: Int
        let symbol: String
        let image_url: String?
        let created_at: Date
        let updated_at: Date
        // Defaults keep the DTO backward-compatible if a backend predates the
        // is_bounty / radius_km columns.
        let is_bounty: Bool?
        let radius_km: Double?
    }

    struct IntelReplyDTO: Decodable {
        let id: UUID
        let report_id: UUID
        let parent_reply_id: UUID?
        let hunter_name: String
        let hunter_seed: String
        let content: String
        let created_at: Date
    }

    struct IntelReportDTO: Decodable {
        let id: UUID
        let bounty_id: UUID?
        let hunter_name: String
        let hunter_seed: String
        let note: String
        let status: String
        let district: String
        let latitude: Double
        let longitude: Double
        let upvotes: Int
        let downvotes: Int
        let symbol: String
        let points_awarded: Int
        let image_url: String?
        let created_at: Date
        let replies: [IntelReplyDTO]?
    }

    struct HunterDTO: Decodable {
        let id: UUID
        let display_name: String
        let handle: String
        let avatar_seed: String
        let points: Int
        let rank: Int
        let verifications: Int
        let streak: Int
        let is_moderator: Bool
        let email: String?
    }

    struct OTPRequestBody: Encodable {
        let identifier: String
        let purpose: String
    }

    struct OTPResponseDTO: Decodable {
        let code: String
        let expires_in: Int
        let email: String
        let purpose: String
        let message: String
    }

    struct LoginBody: Encodable {
        let identifier: String
        let password: String
    }

    struct SignupBody: Encodable {
        let email: String
        let password: String
        let code: String
        let display_name: String
    }

    struct ResetPasswordBody: Encodable {
        let email: String
        let code: String
        let new_password: String
    }

    struct AuthResponseDTO: Decodable {
        let token: String
        let hunter: HunterDTO
    }

    struct RewardDTO: Decodable {
        let id: UUID
        let title: String
        let summary: String
        let detail: String
        let cost: Int
        let symbol: String
        let is_featured: Bool
    }

    struct NotificationDTO: Decodable {
        let id: UUID
        let title: String
        let body: String
        let kind: String
        let symbol: String
        let read: Bool
        let created_at: Date
    }

    struct ModerationFlagDTO: Decodable {
        let id: UUID
        let title: String
        let handle: String
        let reason: String
        let sighting_count: Int
        let status: String
        let created_at: Date
        let category: String?
        let bounty_id: UUID?
        let report_id: UUID?
    }

    struct ModerationStatsDTO: Decodable {
        let intel_total: Int
        let bounty_total: Int
        let hunter_total: Int
        let pending_flags: Int
        let quarantined_flags: Int
        let actioned_flags: Int
    }

    struct SubmitReportRequest: Encodable {
        let bounty_id: UUID?
        let bounty_title: String?
        let hunter_name: String
        let hunter_seed: String?
        let note: String
        let status: String
        let district: String
        let latitude: Double
        let longitude: Double
        let symbol: String
        let is_geofence_verified: Bool
        let image_url: String?
    }

    struct SubmitReplyRequest: Encodable {
        let hunter_name: String
        let hunter_seed: String?
        let content: String
        let parent_reply_id: UUID?
    }

    struct SubmitReportResponse: Decodable {
        let report: IntelReportDTO
        let bounty: BountyDTO
        let points_awarded: Int
        let new_balance: Int
    }

    struct CreateBountyRequest: Encodable {
        let title: String
        let summary: String
        let detail: String
        let category: String
        let status: String
        let latitude: Double
        let longitude: Double
        let district: String
        let symbol: String
        let image_url: String?
        let is_bounty: Bool
        let radius_km: Double
    }

    struct RedeemResponse: Decodable {
        let success: Bool
        let message: String
        let new_balance: Int
    }

    // MARK: - Endpoints

    func health() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/health"))
        request.timeoutInterval = 4
        let (_, response) = try await session.data(for: request)
        try Self.verify(response, data: nil)
    }

    func fetchBounties() async throws -> [BountyDTO] { try await get("/bounties") }
    func fetchReports() async throws -> [IntelReportDTO] { try await get("/reports") }
    func fetchHunter() async throws -> HunterDTO { try await get("/hunters/me") }
    func fetchRewards() async throws -> [RewardDTO] { try await get("/rewards") }
    func fetchNotifications() async throws -> [NotificationDTO] { try await get("/notifications") }
    func fetchFlags() async throws -> [ModerationFlagDTO] { try await get("/moderation/flags") }
    func fetchLeaderboard() async throws -> [HunterDTO] { try await get("/hunters/leaderboard") }
    func fetchModerationStats() async throws -> ModerationStatsDTO { try await get("/moderation/stats") }

    func submitReport(_ body: SubmitReportRequest) async throws -> SubmitReportResponse {
        try await post("/reports", body: body)
    }

    func submitReply(reportID: UUID, body: SubmitReplyRequest) async throws -> IntelReplyDTO {
        try await post("/reports/\(reportID.uuidString)/replies", body: body)
    }

    func createBounty(_ body: CreateBountyRequest) async throws -> BountyDTO {
        try await post("/bounties", body: body)
    }

    func redeemReward(_ id: UUID) async throws -> RedeemResponse {
        try await post("/rewards/\(id.uuidString)/redeem", body: EmptyBody())
    }

    func uploadImage(data: Data) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent("/storage/upload"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (responseData, response) = try await session.data(for: request)
        try Self.verify(response, data: nil)
        
        struct UploadResponse: Decodable { let url: String }
        let result = try Self.decoder.decode(UploadResponse.self, from: responseData)
        return result.url
    }

    // MARK: - Auth

    func requestOTP(identifier: String, purpose: String) async throws -> OTPResponseDTO {
        try await post("/auth/request-otp", body: OTPRequestBody(identifier: identifier, purpose: purpose))
    }

    func login(identifier: String, password: String) async throws -> AuthResponseDTO {
        try await post("/auth/login", body: LoginBody(identifier: identifier, password: password))
    }

    func signup(email: String, password: String, code: String, displayName: String) async throws -> AuthResponseDTO {
        try await post(
            "/auth/signup",
            body: SignupBody(email: email, password: password, code: code, display_name: displayName)
        )
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws {
        let _: [String: Bool] = try await post(
            "/auth/reset-password",
            body: ResetPasswordBody(email: email, code: code, new_password: newPassword)
        )
    }

    func logout(token: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/auth/logout"))
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data("{}".utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.data(for: request)
        try Self.verify(response, data: nil)
    }

    /// `action` ∈ { "quarantine", "action", "dismiss" }.
    func moderationAction(flagID: UUID, action: String) async throws -> ModerationFlagDTO {
        try await post("/moderation/flags/\(flagID.uuidString)/\(action)", body: EmptyBody())
    }

    // MARK: - Transport

    private struct EmptyBody: Encodable {}

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.timeoutInterval = 5
        attachAuth(to: &request)
        let (data, response) = try await session.data(for: request)
        try Self.verify(response, data: data)
        return try Self.decoder.decode(T.self, from: data)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        attachAuth(to: &request)
        if !(body is EmptyBody) {
            request.httpBody = try Self.encoder.encode(body)
        } else {
            request.httpBody = Data("{}".utf8)
        }
        let (data, response) = try await session.data(for: request)
        try Self.verify(response, data: data)
        return try Self.decoder.decode(T.self, from: data)
    }

    struct BackendError: LocalizedError {
        let status: Int
        let detail: String
        var errorDescription: String? { detail }
    }

    private static func verify(_ response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            var detail = "Request failed (\(http.statusCode))"
            if let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let d = json["detail"] as? String {
                detail = d
            }
            throw BackendError(status: http.statusCode, detail: detail)
        }
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601WithFractional
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder.DateDecodingStrategy {
    static var iso8601WithFractional: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            if let d = ISO8601DateFormatter.rfWithFractional.date(from: string)
                ?? ISO8601DateFormatter.rfPlain.date(from: string) {
                return d
            }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Unrecognized date: \(string)"
            )
        }
    }
}

private extension ISO8601DateFormatter {
    static let rfWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let rfPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
