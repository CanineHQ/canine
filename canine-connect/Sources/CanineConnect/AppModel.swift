import AppKit
import Foundation
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    enum Connection: Equatable {
        case disconnected
        case connecting(String)
        case connected
        case disconnecting

        var isBusy: Bool {
            switch self {
            case .connecting, .disconnecting: return true
            default: return false
            }
        }
    }

    static let defaultBaseURL = "https://canine.sh"
    static let defaultManagerNamespace = "canine-system"
    private static let tokenKey = "api-token"

    @Published private(set) var connection: Connection = .disconnected
    @Published private(set) var status: TelepresenceStatus?
    @Published private(set) var me: CanineMe?
    @Published private(set) var clusters: [CanineCluster] = []
    @Published private(set) var isSigningIn = false
    /// Set while waiting for the browser to hand back an OAuth code.
    @Published private(set) var browserSignIn: OAuthClient.Attempt?
    @Published private(set) var isLoadingClusters = false
    @Published private(set) var telepresenceVersion: String?
    @Published var errorMessage: String?

    @Published var baseURLString: String {
        didSet { defaults.set(baseURLString, forKey: "baseURL") }
    }
    @Published var managerNamespace: String {
        didSet { defaults.set(managerNamespace, forKey: "managerNamespace") }
    }
    @Published private(set) var selectedClusterName: String? {
        didSet { defaults.set(selectedClusterName, forKey: "selectedCluster") }
    }
    /// The Canine cluster the live telepresence session belongs to; survives app restarts.
    @Published private(set) var connectedClusterName: String? {
        didSet { defaults.set(connectedClusterName, forKey: "connectedCluster") }
    }
    /// When the app made the current connection; nil if it was made elsewhere (e.g. the CLI).
    @Published private(set) var connectedSince: Date? {
        didSet { defaults.set(connectedSince, forKey: "connectedSince") }
    }
    private var accountSlug: String? {
        didSet { defaults.set(accountSlug, forKey: "accountSlug") }
    }

    let telepresence: Telepresence?
    private let defaults = UserDefaults.standard
    private var credential: CanineCredential?
    private var pollTask: Task<Void, Never>?

    init() {
        baseURLString = defaults.string(forKey: "baseURL") ?? Self.defaultBaseURL
        managerNamespace = defaults.string(forKey: "managerNamespace") ?? Self.defaultManagerNamespace
        selectedClusterName = defaults.string(forKey: "selectedCluster")
        connectedClusterName = defaults.string(forKey: "connectedCluster")
        accountSlug = defaults.string(forKey: "accountSlug")
        connectedSince = defaults.object(forKey: "connectedSince") as? Date
        telepresence = Telepresence.locate()
        credential = Keychain.read(Self.tokenKey).map {
            CanineCredential(kind: UserDefaults.standard.string(forKey: "credentialKind"), secret: $0)
        }

        pollTask = Task { [weak self] in
            await self?.loadTelepresenceVersion()
            while !Task.isCancelled {
                await self?.refreshStatus()
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
        if credential != nil { Task { await loadAccount() } }
    }

    /// A model with canned state and no side effects, for `--snapshot` renders.
    init(preview connection: Connection, signedIn: Bool = true, awaitingBrowser: Bool = false, error: String? = nil) {
        let account = CanineAccount(id: 1, name: "Acme Inc", slug: "acme")
        let pkgs = [CanineCluster.Package(name: "telepresence", status: "installed")]
        baseURLString = Self.defaultBaseURL
        managerNamespace = Self.defaultManagerNamespace
        telepresence = nil
        self.connection = connection
        errorMessage = error
        telepresenceVersion = "v2.21.1"
        if awaitingBrowser, let url = URL(string: Self.defaultBaseURL) {
            browserSignIn = OAuthClient(baseURL: url).begin(clientID: "preview")
        }
        guard signedIn else { return }
        credential = .oauth("preview")
        accountSlug = "acme"
        me = CanineMe(email: "you@example.com", name: "You", currentAccount: account, accounts: [account])
        clusters = [
            CanineCluster(id: 1, name: "production", clusterType: "k8s", status: "running", linkToViewUrl: "/clusters/1", packages: pkgs),
            CanineCluster(id: 2, name: "staging", clusterType: "k3s", status: "running", linkToViewUrl: "/clusters/2", packages: pkgs),
            CanineCluster(id: 3, name: "homelab", clusterType: "local_k3s", status: "running", linkToViewUrl: "/clusters/3", packages: [])
        ]
        selectedClusterName = "production"
        if connection == .connected {
            connectedClusterName = "production"
            connectedSince = Date().addingTimeInterval(-754)
            status = TelepresenceStatus(
                userDaemon: .init(running: true, status: "Connected", kubernetesContext: "production",
                                  kubernetesServer: "https://a1b2c3d4.k8s.example.com", namespace: "default",
                                  managerNamespace: "canine-system"),
                rootDaemon: .init(running: true),
                trafficManager: .init(version: "v2.21.1")
            )
        }
    }

    // MARK: - Derived state

    var isSignedIn: Bool { me != nil }
    var hasToken: Bool { credential != nil }
    var isConnected: Bool { connection == .connected }

    var api: CanineAPI? {
        guard let credential, let url = URL(string: baseURLString) else { return nil }
        return CanineAPI(baseURL: url, credential: credential, accountSlug: accountSlug)
    }

    var currentAccount: CanineAccount? {
        guard let me else { return nil }
        return me.accounts.first { $0.slug == accountSlug } ?? me.currentAccount
    }

    var selectedCluster: CanineCluster? {
        clusters.first { $0.name == selectedClusterName }
    }

    // MARK: - Canine

    /// Signs in through the browser: the person approves Canine Connect on Canine's own sign-in page, and the
    /// browser hands a code back on canine-connect://. Finishes in `handleCallback(_:)`.
    func signInWithBrowser(baseURL: String) async {
        guard let url = normalizedBaseURL(baseURL) else { return }
        isSigningIn = true
        defer { isSigningIn = false }
        errorMessage = nil
        do {
            let client = OAuthClient(baseURL: url)
            let clientID = try await registeredClientID(for: url, client: client)
            let attempt = client.begin(clientID: clientID)
            browserSignIn = attempt
            open(attempt.authorizeURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reopenBrowser() {
        if let browserSignIn { open(browserSignIn.authorizeURL) }
    }

    func cancelBrowserSignIn() {
        // A stale registration (e.g. Canine's database was reset) would fail in the browser where the app can't
        // see it; registering again next time costs nothing.
        if let browserSignIn { forgetClientID(for: browserSignIn.baseURL) }
        browserSignIn = nil
    }

    /// The browser calling back with canine-connect://oauth/callback?code=…&state=…
    func handleCallback(_ url: URL) async {
        guard url.scheme == OAuthClient.callbackScheme else { return }
        guard let attempt = browserSignIn else {
            errorMessage = "That sign-in has expired. Sign in again."
            return
        }
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let code = try OAuthClient.code(from: url, attempt: attempt)
            let token = try await OAuthClient(baseURL: attempt.baseURL).exchange(code: code, attempt: attempt)
            browserSignIn = nil
            await finishSignIn(baseURL: attempt.baseURL, credential: .oauth(token)) {
                // Signed in with OAuth but the API still wants an API key: Canine is older than this app
                OAuthError.unsupported
            }
        } catch {
            if case OAuthError.stateMismatch = error { errorMessage = error.localizedDescription; return }
            browserSignIn = nil
            errorMessage = error.localizedDescription
        }
    }

    func signIn(baseURL: String, token newToken: String) async {
        guard let url = normalizedBaseURL(baseURL) else { return }
        let trimmedToken = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            errorMessage = "Paste an API token from Canine."
            return
        }
        isSigningIn = true
        defer { isSigningIn = false }
        await finishSignIn(baseURL: url, credential: .apiKey(trimmedToken))
    }

    private func finishSignIn(baseURL url: URL, credential newCredential: CanineCredential,
                              whenUnauthorized: (() -> Error)? = nil) async {
        errorMessage = nil
        do {
            let me = try await CanineAPI(baseURL: url, credential: newCredential).me()
            Keychain.write(newCredential.secret, for: Self.tokenKey)
            defaults.set(newCredential.kind, forKey: "credentialKind")
            credential = newCredential
            baseURLString = url.absoluteString
            accountSlug = me.currentAccount.slug
            self.me = me
            await refreshClusters()
        } catch CanineAPIError.unauthorized where whenUnauthorized != nil {
            errorMessage = whenUnauthorized?().localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        if isConnected { await disconnect() }
        if case .oauth(let token) = credential, let url = URL(string: baseURLString) {
            await OAuthClient(baseURL: url).revoke(token: token, clientID: clientIDs[baseURLString])
        }
        Keychain.delete(Self.tokenKey)
        credential = nil
        me = nil
        clusters = []
        accountSlug = nil
        selectedClusterName = nil
        errorMessage = nil
    }

    func switchAccount(_ account: CanineAccount) async {
        guard account.slug != accountSlug else { return }
        if isConnected { await disconnect() }
        accountSlug = account.slug
        selectedClusterName = nil
        clusters = []
        await refreshClusters()
    }

    func refreshClusters() async {
        guard let api else { return }
        isLoadingClusters = true
        defer { isLoadingClusters = false }
        do {
            clusters = try await api.clusters()
            if selectedCluster == nil {
                selectedClusterName = clusters.first { $0.name == connectedClusterName }?.name
                    ?? clusters.first { $0.telepresenceInstalled != false }?.name
                    ?? clusters.first?.name
            }
        } catch {
            handle(error)
        }
    }

    private func normalizedBaseURL(_ value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true, url.host != nil else {
            errorMessage = "Enter your Canine URL, like https://canine.sh"
            return nil
        }
        return url
    }

    /// Canine Connect registers itself once per Canine it signs in to (RFC 7591) and reuses that client_id.
    private var clientIDs: [String: String] {
        get { defaults.dictionary(forKey: "oauthClientIDs") as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: "oauthClientIDs") }
    }

    private func registeredClientID(for url: URL, client: OAuthClient) async throws -> String {
        if let existing = clientIDs[url.absoluteString] { return existing }
        let clientID = try await client.register()
        clientIDs[url.absoluteString] = clientID
        return clientID
    }

    private func forgetClientID(for url: URL) {
        clientIDs[url.absoluteString] = nil
    }

    private func loadAccount() async {
        guard let api else { return }
        do {
            me = try await api.me()
            if let me, !me.accounts.contains(where: { $0.slug == accountSlug }) { accountSlug = me.currentAccount.slug }
            await refreshClusters()
        } catch {
            handle(error)
        }
    }

    // MARK: - Telepresence

    func toggle() async {
        isConnected ? await disconnect() : await connect()
    }

    func select(_ cluster: CanineCluster) async {
        guard cluster.name != selectedClusterName else { return }
        selectedClusterName = cluster.name
        // Like a VPN's location picker: changing it while connected moves the connection.
        if isConnected { await connect() }
    }

    func connect() async {
        guard !connection.isBusy else { return }
        guard let telepresence else { errorMessage = TelepresenceError.binaryNotFound.localizedDescription; return }
        guard let api, let cluster = selectedCluster else { errorMessage = "Choose a cluster first."; return }

        errorMessage = nil
        do {
            connection = .connecting("Fetching kubeconfig…")
            let kubeconfig = try writeKubeconfig(try await api.kubeconfig(clusterName: cluster.name), for: cluster)

            if status?.isConnected == true {
                connection = .connecting("Leaving \(connectedClusterName ?? "current cluster")…")
                await telepresence.quit()
            }

            if !Telepresence.rootDaemonReachable() {
                connection = .connecting("Waiting for your password…")
                try await telepresence.startRootDaemon()
            }

            connection = .connecting("Connecting to \(cluster.name)…")
            try await telepresence.connect(kubeconfig: kubeconfig, managerNamespace: managerNamespace)
            connectedClusterName = cluster.name
            connectedSince = Date()
            connection = .connected
        } catch {
            connection = .disconnected
            handle(error)
        }
        await refreshStatus(force: true)
    }

    func disconnect() async {
        guard let telepresence, !connection.isBusy else { return }
        connection = .disconnecting
        await telepresence.quit()
        connectedClusterName = nil
        connectedSince = nil
        connection = .disconnected
        await refreshStatus(force: true)
    }

    /// Called when the app quits: tear down the tunnel and the root daemon so nothing privileged lingers.
    func shutdown() async {
        pollTask?.cancel()
        guard let telepresence else { return }
        if status?.isConnected == true || Telepresence.rootDaemonReachable() {
            await telepresence.quit(stopDaemons: true)
        }
    }

    private func refreshStatus(force: Bool = false) async {
        guard let telepresence else { return }
        let latest = await telepresence.status()
        status = latest
        guard force || !connection.isBusy else { return }
        let connected = latest?.isConnected == true
        if !connected {
            connectedSince = nil
            connectedClusterName = nil
        }
        connection = connected ? .connected : .disconnected
    }

    private func loadTelepresenceVersion() async {
        telepresenceVersion = await telepresence?.version()
    }

    private func writeKubeconfig(_ data: Data, for cluster: CanineCluster) throws -> URL {
        let dir = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Canine Connect/kubeconfigs", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let safeName = cluster.name.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        let file = dir.appendingPathComponent("\(safeName).json")
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return file
    }

    private func handle(_ error: Error) {
        if case CanineAPIError.unauthorized = error {
            Keychain.delete(Self.tokenKey)
            credential = nil
            me = nil
            clusters = []
        }
        errorMessage = error.localizedDescription
    }

    // MARK: - Launch at login

    var launchesAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            enabled ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister()
        } catch {
            errorMessage = "Couldn't change Launch at Login: \(error.localizedDescription)"
        }
        objectWillChange.send()
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
