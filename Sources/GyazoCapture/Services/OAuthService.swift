import AppKit
import AuthenticationServices
import Foundation

@MainActor
final class OAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func authenticate(clientID: String, clientSecret: String) async throws -> String {
        let state = UUID().uuidString
        var components = URLComponents(string: "https://gyazo.com/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: AppConstants.callbackURL),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state)
        ]
        guard let authorizeURL = components.url else { throw OAuthError.invalidAuthorizationURL }

        let callbackURL = try await beginSession(authorizeURL: authorizeURL)
        guard let callback = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw OAuthError.invalidCallback
        }
        let values = Dictionary(uniqueKeysWithValues: (callback.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        guard values["state"] == state else { throw OAuthError.stateMismatch }
        guard let code = values["code"], !code.isEmpty else { throw OAuthError.authorizationCodeMissing }

        return try await exchangeCode(code, clientID: clientID, clientSecret: clientSecret)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? NSWindow()
    }

    private func beginSession(authorizeURL: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(
                url: authorizeURL,
                callbackURLScheme: AppConstants.callbackScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    self?.session = nil
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let callbackURL {
                        continuation.resume(returning: callbackURL)
                    } else {
                        continuation.resume(throwing: OAuthError.invalidCallback)
                    }
                }
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            session = authSession
            guard authSession.start() else {
                session = nil
                continuation.resume(throwing: OAuthError.couldNotStart)
                return
            }
        }
    }

    private func exchangeCode(_ code: String, clientID: String, clientSecret: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://gyazo.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormURLEncoder.encode([
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": AppConstants.callbackURL,
            "code": code,
            "grant_type": "authorization_code"
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try HTTPValidator.validate(response: response, data: data)
        return try JSONDecoder().decode(GyazoTokenResponse.self, from: data).accessToken
    }
}

enum OAuthError: LocalizedError {
    case invalidAuthorizationURL
    case invalidCallback
    case stateMismatch
    case authorizationCodeMissing
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .invalidAuthorizationURL: return "Gyazoの認証URLを作成できませんでした。"
        case .invalidCallback: return "Gyazoからの認証結果を読み取れませんでした。"
        case .stateMismatch: return "認証状態を検証できませんでした。もう一度お試しください。"
        case .authorizationCodeMissing: return "Gyazoから認証コードが返されませんでした。"
        case .couldNotStart: return "ブラウザ認証を開始できませんでした。"
        }
    }
}

enum FormURLEncoder {
    static func encode(_ values: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = values.sorted { $0.key < $1.key }.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        return components.percentEncodedQuery?.data(using: .utf8)
    }
}
