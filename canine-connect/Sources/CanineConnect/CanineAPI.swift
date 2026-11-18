import Foundation

struct CanineAccount: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let slug: String
}

struct CanineMe: Decodable {
    let email: String
    let name: String?
    let currentAccount: CanineAccount
    let accounts: [CanineAccount]
}

struct CanineCluster: Decodable, Identifiable, Hashable {
    struct Package: Decodable, Hashable {
        let name: String
        let status: String
    }

    let id: Int
    let name: String
    let clusterType: String?
    let status: String?
    let linkToViewUrl: String?
    let packages: [Package]?

    /// nil when the cluster's packages aren't known (older Canine versions don't report them).
    var telepresenceInstalled: Bool? {
        guard let packages else { return nil }
        return packages.first { $0.name == "telepresence" }?.status == "installed"
    }
}

/// How the app proves who it is to Canine's /api/v1.
enum CanineCredential: Equatable {
    /// From browser sign-in (OAuth), sent as `Authorization: Bearer`.
    case oauth(String)
    /// Pasted from Settings → API Tokens, sent as `X-API-Key`.
    case apiKey(String)

    var secret: String {
        switch self {
        case .oauth(let token), .apiKey(let token): return token
        }
    }

    var kind: String {
        switch self {
        case .oauth: return "oauth"
        case .apiKey: return "apiKey"
        }
    }

    init(kind: String?, secret: String) {
        self = kind == "oauth" ? .oauth(secret) : .apiKey(secret)
    }
}

enum CanineAPIError: LocalizedError {
    case unauthorized
    case http(Int, String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Canine didn't accept your sign-in. It may have expired or been revoked. Sign in again."
        case .http(let code, let message): return "Canine returned \(code): \(message)"
        case .badResponse: return "Canine sent a response the app couldn't read."
        }
    }
}

/// Talks to Canine's /api/v1 with an OAuth access token or an API token.
struct CanineAPI {
    let baseURL: URL
    let credential: CanineCredential
    var accountSlug: String?

    func me() async throws -> CanineMe {
        try decode(CanineMe.self, from: try await get("api/v1/me"))
    }

    func clusters() async throws -> [CanineCluster] {
        struct Response: Decodable { let clusters: [CanineCluster] }
        return try decode(Response.self, from: try await get("api/v1/clusters")).clusters
    }

    /// Returns the kubeconfig as JSON, which kubectl and telepresence parse as YAML. Slashes must stay unescaped:
    /// `\/` is valid JSON but an invalid escape in a YAML double-quoted string.
    func kubeconfig(clusterName: String) async throws -> Data {
        let name = clusterName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? clusterName
        let data = try await get("api/v1/clusters/\(name)/download_kubeconfig")
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let kubeconfig = object["kubeconfig"], !(kubeconfig is NSNull)
        else { throw CanineAPIError.badResponse }
        return try JSONSerialization.data(withJSONObject: kubeconfig, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    func webURL(_ path: String) -> URL {
        URL(string: path, relativeTo: baseURL)?.absoluteURL ?? baseURL
    }

    private func get(_ path: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        switch credential {
        case .oauth(let token): request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .apiKey(let token): request.setValue(token, forHTTPHeaderField: "X-API-Key")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountSlug { request.setValue(accountSlug, forHTTPHeaderField: "X-Account-Id") }
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CanineAPIError.badResponse }
        switch http.statusCode {
        case 200..<300: return data
        case 401: throw CanineAPIError.unauthorized
        default:
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw CanineAPIError.http(http.statusCode, message ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do { return try decoder.decode(type, from: data) } catch { throw CanineAPIError.badResponse }
    }
}
