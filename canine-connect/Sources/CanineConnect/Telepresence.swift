import AppKit
import Foundation

struct TelepresenceStatus: Decodable {
    struct UserDaemon: Decodable {
        var running: Bool?
        var status: String?
        var kubernetesContext: String?
        var kubernetesServer: String?
        var namespace: String?
        var managerNamespace: String?
    }

    struct RootDaemon: Decodable {
        var running: Bool?
    }

    struct TrafficManager: Decodable {
        var version: String?
    }

    var userDaemon: UserDaemon?
    var rootDaemon: RootDaemon?
    var trafficManager: TrafficManager?

    var isConnected: Bool { userDaemon?.status == "Connected" }
}

enum TelepresenceError: LocalizedError {
    case binaryNotFound
    case rootDaemonDeclined
    case rootDaemonFailed(String)
    case command(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Couldn't find the telepresence CLI. Rebuild the app with script/build.sh, or install telepresence."
        case .rootDaemonDeclined:
            return "Telepresence needs administrator access to create the network tunnel."
        case .rootDaemonFailed(let message):
            return "Couldn't start the Telepresence daemon: \(message)"
        case .command(let message):
            return message
        }
    }
}

/// Drives the telepresence CLI. The app ships its own copy (Contents/Resources/bin/telepresence) pinned to the
/// version Canine installs on clusters, and falls back to one on the PATH.
struct Telepresence {
    let binary: URL

    static func locate() -> Telepresence? {
        var candidates: [URL] = []
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("bin/telepresence") {
            candidates.append(bundled)
        }
        candidates += ["/opt/homebrew/bin/telepresence", "/usr/local/bin/telepresence"].map(URL.init(fileURLWithPath:))
        return candidates
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
            .map(Telepresence.init(binary:))
    }

    func version() async -> String? {
        guard let result = try? await Shell.run(binary, ["version"]), result.succeeded else { return nil }
        return result.stdout
            .split(separator: "\n")
            .first { $0.hasPrefix("OSS Client") || $0.hasPrefix("Client") }?
            .split(separator: ":").last?
            .trimmingCharacters(in: .whitespaces)
    }

    func status() async -> TelepresenceStatus? {
        guard let result = try? await Shell.run(binary, ["status", "--output", "json"]) else { return nil }
        // `status --output json` prints the JSON object first; anything after it is noise.
        guard let start = result.stdout.firstIndex(of: "{") else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        var json = Substring(result.stdout[start...])
        // Trim to the matching closing brace in case extra output follows.
        if let end = Self.matchingBraceEnd(json) { json = json[..<end] }
        return try? decoder.decode(TelepresenceStatus.self, from: Data(json.utf8))
    }

    /// Telepresence's root daemon owns the TUN device and DNS, so it must run as root. The CLI would normally
    /// `sudo` it from a terminal; a GUI app has no terminal, so we start it ourselves behind the standard
    /// macOS admin prompt. Once it is up, `telepresence connect` finds its socket and needs no further privileges.
    @MainActor
    func startRootDaemon() async throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let logDir = home.appendingPathComponent("Library/Logs/telepresence").path
        let configDir = home.appendingPathComponent("Library/Application Support/telepresence").path
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)

        // Backgrounded with output redirected so `do shell script` returns immediately (Apple TN2065).
        let command = [binary.path, "daemon-foreground", logDir, configDir].map(Self.shellQuote).joined(separator: " ")
            + " >/dev/null 2>&1 &"
        let source = """
        do shell script \(Self.appleScriptQuote(command)) with prompt "Canine Connect needs your password to start the Telepresence network tunnel." with administrator privileges
        """

        var errorInfo: NSDictionary?
        NSApp.activate(ignoringOtherApps: true)
        NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
        if let errorInfo {
            if (errorInfo[NSAppleScript.errorNumber] as? Int) == -128 { throw TelepresenceError.rootDaemonDeclined }
            throw TelepresenceError.rootDaemonFailed(errorInfo[NSAppleScript.errorMessage] as? String ?? "unknown error")
        }

        for _ in 0..<40 {
            if Self.rootDaemonReachable() { return }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        throw TelepresenceError.rootDaemonFailed("it didn't come up. See \(logDir)/daemon.log")
    }

    static let rootDaemonSocket = "/var/run/telepresence-daemon.socket"

    /// Whether the root daemon is up. `telepresence status` can't tell us: it learns about the root daemon through
    /// the user daemon, so before the first connect it reports "not running" even when it is. Instead we connect
    /// to the daemon's socket, which also rules out a stale socket file left by a crashed daemon.
    static func rootDaemonReachable() -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = Array(rootDaemonSocket.utf8CString)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: path.prefix(buffer.count).map { UInt8(bitPattern: $0) })
        }
        let length = socklen_t(MemoryLayout<sockaddr_un>.size)
        return withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, length) == 0 }
        }
    }

    func connect(kubeconfig: URL, managerNamespace: String) async throws {
        let result = try await Shell.run(binary, [
            "connect",
            "--kubeconfig", kubeconfig.path,
            "--manager-namespace", managerNamespace
        ])
        guard result.succeeded else { throw TelepresenceError.command(result.errorMessage) }
    }

    /// `stopDaemons` also stops the root daemon, so the next connect asks for the password again.
    func quit(stopDaemons: Bool = false) async {
        _ = try? await Shell.run(binary, stopDaemons ? ["quit", "-s"] : ["quit"])
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func matchingBraceEnd(_ text: Substring) -> Substring.Index? {
        var depth = 0
        var inString = false
        var escaped = false
        for index in text.indices {
            let char = text[index]
            if inString {
                if escaped { escaped = false } else if char == "\\" { escaped = true } else if char == "\"" { inString = false }
                continue
            }
            switch char {
            case "\"": inString = true
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return text.index(after: index) }
            default: break
            }
        }
        return nil
    }
}
