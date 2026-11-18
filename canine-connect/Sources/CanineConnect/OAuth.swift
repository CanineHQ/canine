import CryptoKit
import Foundation
import Security

enum OAuthError: LocalizedError {
    case unsupported
    case denied(String?)
    case stateMismatch
    case server(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "This Canine doesn't support signing in from the app yet. Use an API token instead."
        case .denied(let description):
            return description ?? "Sign-in was cancelled in the browser."
        case .stateMismatch:
            return "That sign-in link didn't come from this app. Try signing in again."
        case .server(let message):
            return "Canine couldn't complete sign-in: \(message)"
        }
    }
}

/// Signs in to Canine through the browser: OAuth 2.0 authorization code with PKCE (RFC 7636), as a public
/// native client (RFC 8252) that registers itself with Canine's dynamic client registration (RFC 7591), so no
/// one has to set up an OAuth application first. The browser hands the code back on the `canine-connect://`
/// URL scheme declared in Info.plist.
struct OAuthClient {
    static let callbackScheme = "canine-connect"
    static let redirectURI = "\(callbackScheme)://oauth/callback"
    static let scope = "read"

    let baseURL: URL

    /// A pending browser sign-in: what the app needs to finish it when the browser calls back.
    struct Attempt {
        let baseURL: URL
        let clientID: String
        let verifier: String
        let state: String
        let authorizeURL: URL
    }

    func begin(clientID: String) -> Attempt {
        let verifier = Self.randomURLSafe(bytes: 32)
        let state = Self.randomURLSafe(bytes: 16)
        var components = URLComponents(url: baseURL.appendingPathComponent("oauth/authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: Self.challenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        return Attempt(baseURL: baseURL, clientID: clientID, verifier: verifier, state: state, authorizeURL: components.url!)
    }

    /// Registers Canine Connect as a public client and returns its client_id.
    func register() async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("oauth/register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_name": "Canine Connect",
            "redirect_uris": [Self.redirectURI],
            "token_endpoint_auth_method": "none"
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        // Canine versions without OAuth return 404 here
        if status == 404 { throw OAuthError.unsupported }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard status == 201, let clientID = json?["client_id"] as? String else {
            throw OAuthError.server(Self.errorDescription(json) ?? "registration failed (\(status))")
        }
        return clientID
    }

    /// Exchanges the code from the browser for an access token.
    func exchange(code: String, attempt: Attempt) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("oauth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncode([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.redirectURI,
            "client_id": attempt.clientID,
            "code_verifier": attempt.verifier
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (response as? HTTPURLResponse)?.statusCode == 200, let token = json?["access_token"] as? String else {
            throw OAuthError.server(Self.errorDescription(json) ?? "the token request failed")
        }
        return token
    }

    /// Best effort: revokes the token on sign-out so it stops working server-side too.
    func revoke(token: String, clientID: String?) async {
        var request = URLRequest(url: baseURL.appendingPathComponent("oauth/revoke"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = ["token": token]
        if let clientID { form["client_id"] = clientID }
        request.httpBody = Self.formEncode(form)
        request.timeoutInterval = 10
        _ = try? await URLSession.shared.data(for: request)
    }

    /// Reads the code out of `canine-connect://oauth/callback?code=…&state=…`.
    static func code(from callback: URL, attempt: Attempt) throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in items.first { $0.name == name }?.value }
        guard value("state") == attempt.state else { throw OAuthError.stateMismatch }
        if let error = value("error") {
            throw OAuthError.denied(error == "access_denied" ? nil : value("error_description") ?? error)
        }
        guard let code = value("code"), !code.isEmpty else { throw OAuthError.server("no authorization code came back") }
        return code
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func randomURLSafe(bytes count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formEncode(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = fields.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
        }.joined(separator: "&")
        return Data(body.utf8)
    }

    private static func errorDescription(_ json: [String: Any]?) -> String? {
        (json?["error_description"] as? String) ?? (json?["error"] as? String)
    }
}
