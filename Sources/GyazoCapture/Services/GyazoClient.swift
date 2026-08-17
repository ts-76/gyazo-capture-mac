import Foundation

struct GyazoClient {
    func currentUser(accessToken: String) async throws -> GyazoUser {
        var request = URLRequest(url: URL(string: "https://api.gyazo.com/api/users/me")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try HTTPValidator.validate(response: response, data: data)
        return try JSONDecoder().decode(GyazoUserEnvelope.self, from: data).user
    }

    func upload(_ upload: GyazoUploadRequest, accessToken: String) async throws -> GyazoUploadResponse {
        let boundary = "GyazoCapture-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://upload.gyazo.com/api/upload")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = MultipartFormData.build(
            boundary: boundary,
            fields: [
                "access_policy": upload.accessPolicy.rawValue,
                "metadata_is_public": "false",
                "app": AppConstants.appName,
                "desc": upload.description,
                "collection_id": upload.collectionID ?? ""
            ],
            fileField: "imagedata",
            filename: "capture.png",
            mimeType: "image/png",
            fileData: upload.pngData
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try HTTPValidator.validate(response: response, data: data)
        return try JSONDecoder().decode(GyazoUploadResponse.self, from: data)
    }
}

enum MultipartFormData {
    static func build(
        boundary: String,
        fields: [String: String],
        fileField: String,
        filename: String,
        mimeType: String,
        fileData: Data
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        for (name, value) in fields.sorted(by: { $0.key < $1.key }) where !value.isEmpty {
            body.appendUTF8("--\(boundary)\(lineBreak)")
            body.appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)")
            body.appendUTF8("\(value)\(lineBreak)")
        }

        body.appendUTF8("--\(boundary)\(lineBreak)")
        body.appendUTF8("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\(lineBreak)")
        body.appendUTF8("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
        body.append(fileData)
        body.appendUTF8(lineBreak)
        body.appendUTF8("--\(boundary)--\(lineBreak)")
        return body
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}

enum HTTPValidator {
    static func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw HTTPError.server(status: response.statusCode, message: message)
        }
    }
}

enum HTTPError: LocalizedError {
    case invalidResponse
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "サーバーから正しい応答を受け取れませんでした。"
        case .server(let status, let message):
            let detail = message.isEmpty ? "" : " \(message)"
            return "Gyazo APIがエラーを返しました（HTTP \(status)）。\(detail)"
        }
    }
}
