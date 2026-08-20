import Foundation

struct GyazoUserEnvelope: Decodable {
    let user: GyazoUser
}

struct GyazoUser: Decodable {
    let email: String
    let name: String
    let profileImage: URL?
    let uid: String

    enum CodingKeys: String, CodingKey {
        case email, name, uid
        case profileImage = "profile_image"
    }
}

struct GyazoTokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

struct GyazoUploadResponse: Decodable {
    let imageID: String
    let permalinkURL: URL
    let url: URL

    enum CodingKeys: String, CodingKey {
        case imageID = "image_id"
        case permalinkURL = "permalink_url"
        case url
    }
}

enum GyazoAccessPolicy: String, CaseIterable, Identifiable {
    case anyone
    case onlyMe = "only_me"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .anyone: return "リンクを知っている人"
        case .onlyMe: return "自分のみ"
        }
    }
}

struct GyazoUploadRequest {
    let pngData: Data
    let fileName: String
    let description: String
    let collectionID: String?
    let accessPolicy: GyazoAccessPolicy
}
