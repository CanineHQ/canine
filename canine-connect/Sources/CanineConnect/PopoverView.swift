import AppKit
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Header()
            if model.isSignedIn {
                ConnectView()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            } else if model.hasToken {
                ProgressView("Signing in…")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(48)
            } else {
                SignInView()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            if let error = model.errorMessage {
                ErrorBanner(message: error) { model.errorMessage = nil }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
            if model.isSignedIn {
                Footer()
            }
        }
        .frame(width: 360)
        .tint(Brand.accent)
    }
}

// MARK: - Header & footer

private struct Header: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            if model.isSignedIn {
                Image(nsImage: Brand.logo)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Canine Connect")
                        .font(.system(size: 13, weight: .semibold))
                    if let account = model.currentAccount {
                        Text(account.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            SettingsMenu()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}

private struct Footer: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                if let me = model.me {
                    Avatar(text: me.name ?? me.email)
                    Text(me.email)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if let api = model.api {
                    Button {
                        model.open(api.webURL("/"))
                    } label: {
                        Label("Open Canine", systemImage: "arrow.up.right")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .background(Color.primary.opacity(0.03))
    }
}

private struct Avatar: View {
    let text: String

    var body: some View {
        Text(String(text.prefix(1)).uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(Circle().fill(Brand.accent.gradient))
    }
}

private struct SettingsMenu: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Menu {
            if let me = model.me {
                if me.accounts.count > 1 {
                    Picker("Account", selection: Binding(
                        get: { model.currentAccount?.slug ?? "" },
                        set: { slug in
                            if let account = me.accounts.first(where: { $0.slug == slug }) {
                                Task { await model.switchAccount(account) }
                            }
                        }
                    )) {
                        ForEach(me.accounts) { Text($0.name).tag($0.slug) }
                    }
                    Divider()
                }
                Button("Refresh Clusters") { Task { await model.refreshClusters() } }
                Divider()
            }
            Toggle("Launch at Login", isOn: Binding(
                get: { model.launchesAtLogin },
                set: { model.setLaunchesAtLogin($0) }
            ))
            Button("Open Telepresence Logs") {
                model.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/telepresence"))
            }
            if let version = model.telepresenceVersion {
                Text("Telepresence \(version)")
            }
            Divider()
            if model.isSignedIn {
                Button("Sign Out") { Task { await model.signOut() } }
            }
            Button("Quit Canine Connect") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .tint(.secondary)
        .fixedSize()
    }
}

// MARK: - Connect

private struct ConnectView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Hero()
            ClusterList()
            if model.isConnected, let status = model.status?.userDaemon {
                ConnectionDetails(status: status, version: model.status?.trafficManager?.version)
            }
        }
    }
}

/// The big status card with the switch, WARP-style. It turns green when the tunnel is up.
private struct Hero: View {
    @EnvironmentObject private var model: AppModel

    private var isOn: Bool {
        switch model.connection {
        case .connected, .connecting: return true
        default: return false
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            StatusPill(connection: model.connection)
            BigSwitch(isOn: isOn, isBusy: model.connection.isBusy, onColoredBackground: model.isConnected) {
                Task { await model.toggle() }
            }
            .disabled(model.selectedCluster == nil && !model.isConnected)

            VStack(spacing: 3) {
                Text(headline)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Group {
                    if model.isConnected, let since = model.connectedSince {
                        TimelineView(.periodic(from: since, by: 1)) { context in
                            Text("Private network reachable · \(Self.elapsed(from: since, to: context.date))")
                        }
                    } else {
                        Text(caption)
                    }
                }
                .font(.system(size: 11.5))
                .opacity(model.isConnected ? 0.85 : 1)
                .foregroundStyle(model.isConnected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            }
            .foregroundStyle(model.isConnected ? .white : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(model.isConnected
                      ? AnyShapeStyle(LinearGradient(colors: [Brand.connected, Brand.connectedEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Color.primary.opacity(0.05)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(model.isConnected ? 0 : 0.06))
        }
        .animation(.easeInOut(duration: 0.25), value: model.isConnected)
    }

    private var headline: String {
        switch model.connection {
        case .connected: return model.connectedClusterName ?? "Connected"
        case .connecting(let step): return step
        case .disconnecting: return "Disconnecting…"
        case .disconnected: return "Not connected"
        }
    }

    private var caption: String {
        switch model.connection {
        case .connected: return "Private network reachable"
        case .connecting: return "This can take a few seconds"
        case .disconnecting: return "Closing the tunnel"
        case .disconnected:
            guard let name = model.selectedClusterName else { return "Choose a cluster below to get started" }
            return "Turn on to reach private services in \(name)"
        }
    }

    static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let (h, m, s) = (seconds / 3600, seconds / 60 % 60, seconds % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

private struct StatusPill: View {
    let connection: AppModel.Connection

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .shadow(color: dotColor.opacity(connection == .connected ? 0.9 : 0), radius: 3)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(connection == .connected ? Color.white : Color.secondary)
        .background(Capsule().fill(connection == .connected ? Color.white.opacity(0.2) : Color.primary.opacity(0.07)))
    }

    private var label: String {
        switch connection {
        case .connected: return "CONNECTED"
        case .connecting: return "CONNECTING"
        case .disconnecting: return "DISCONNECTING"
        case .disconnected: return "DISCONNECTED"
        }
    }

    private var dotColor: Color {
        switch connection {
        case .connected: return .white
        case .connecting, .disconnecting: return .orange
        case .disconnected: return .secondary.opacity(0.6)
        }
    }
}

/// One big switch is the whole point of the app.
private struct BigSwitch: View {
    let isOn: Bool
    let isBusy: Bool
    let onColoredBackground: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(width: 96, height: 52)
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1.5)
                    .frame(width: 44, height: 44)
                    .overlay {
                        if isBusy {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "power")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(isOn ? Brand.connected : Color.gray.opacity(0.7))
                        }
                    }
                    .padding(4)
            }
            .scaleEffect(isHovering && isEnabled && !isBusy ? 1.03 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isOn)
            .animation(.easeOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .disabled(isBusy)
        .accessibilityLabel(isOn ? "Disconnect" : "Connect")
    }

    private var trackColor: Color {
        if onColoredBackground { return .white.opacity(0.3) }
        return isOn ? Brand.connected : Color.primary.opacity(0.12)
    }
}

// MARK: - Clusters

private struct ClusterList: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel("Clusters")
                Spacer()
                Button {
                    Task { await model.refreshClusters() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(model.isLoadingClusters ? 360 : 0))
                        .animation(model.isLoadingClusters ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default,
                                   value: model.isLoadingClusters)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Refresh clusters")
            }
            .padding(.horizontal, 4)

            if model.clusters.isEmpty {
                Text(model.isLoadingClusters ? "Loading clusters…" : "No clusters in this account yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Card())
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(model.clusters) { cluster in
                            ClusterRow(cluster: cluster)
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: min(CGFloat(model.clusters.count) * 46 + 8, 200))
                .background(Card())
            }

            if let cluster = model.selectedCluster, cluster.telepresenceInstalled == false {
                MissingTelepresenceNote(cluster: cluster)
            }
        }
    }
}

private struct ClusterRow: View {
    @EnvironmentObject private var model: AppModel
    let cluster: CanineCluster
    @State private var isHovering = false

    private var isSelected: Bool { cluster.name == model.selectedClusterName }
    private var isConnected: Bool { model.isConnected && cluster.name == model.connectedClusterName }

    var body: some View {
        Button {
            Task { await model.select(cluster) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(Brand.accent.gradient) : AnyShapeStyle(Color.primary.opacity(0.07)))
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(cluster.name)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                trailing
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Brand.accent.opacity(0.12) : Color.primary.opacity(isHovering ? 0.05 : 0))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .disabled(model.connection.isBusy)
    }

    @ViewBuilder private var trailing: some View {
        if isConnected {
            Text("Live")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Capsule().fill(Brand.connected))
        } else if cluster.telepresenceInstalled == false {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .help("Telepresence isn't installed on this cluster")
        } else if isSelected {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Brand.accent)
        }
    }

    private var icon: String {
        cluster.clusterType == "local_k3s" ? "desktopcomputer" : "server.rack"
    }

    private var subtitle: String {
        let type: String
        switch cluster.clusterType {
        case "k8s": type = "Kubernetes"
        case "k3s": type = "K3s"
        case "local_k3s": type = "Local K3s"
        default: type = cluster.clusterType ?? "Cluster"
        }
        guard let status = cluster.status, status != "running" else { return type }
        return "\(type) · \(status.capitalized)"
    }
}

private struct MissingTelepresenceNote: View {
    @EnvironmentObject private var model: AppModel
    let cluster: CanineCluster

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Telepresence isn't installed on \(cluster.name).")
                    .font(.system(size: 11.5, weight: .medium))
                if let path = cluster.linkToViewUrl, let api = model.api {
                    Button("Install it from the cluster's packages →") { model.open(api.webURL(path)) }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.1)))
    }
}

// MARK: - Connection details

private struct ConnectionDetails: View {
    let status: TelepresenceStatus.UserDaemon
    let version: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Connection")
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 0) {
                if let context = status.kubernetesContext { row("Context", context) }
                if let server = status.kubernetesServer {
                    Divider().padding(.leading, 10)
                    row("API server", server.replacingOccurrences(of: "https://", with: ""))
                }
                if let ns = status.managerNamespace {
                    Divider().padding(.leading, 10)
                    row("Traffic manager", [ns, version].compactMap { $0 }.joined(separator: " · "))
                }
                Divider().padding(.leading, 10)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Reach any service by its cluster address")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    CopyableAddress("http://<service>.<namespace>.svc.cluster.local")
                }
                .padding(10)
            }
            .background(Card())
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

private struct CopyableAddress: View {
    let text: String
    @State private var copied = false

    init(_ text: String) { self.text = text }

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
        } label: {
            HStack(spacing: 6) {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10.5))
                    .foregroundStyle(copied ? Brand.connected : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .help("Copy")
    }
}

// MARK: - Sign in

private struct SignInView: View {
    @EnvironmentObject private var model: AppModel
    @State private var baseURL = ""
    @State private var token = ""
    @State private var usesAPIToken = false

    var body: some View {
        Group {
            if let attempt = model.browserSignIn {
                WaitingForBrowser(host: attempt.baseURL.host ?? attempt.baseURL.absoluteString)
            } else {
                form
            }
        }
        .onAppear { if baseURL.isEmpty { baseURL = model.baseURLString } }
    }

    private var form: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Image(nsImage: Brand.logo)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                Text("Sign in to Canine")
                    .font(.system(size: 17, weight: .semibold))
                Text("Reach private services on your clusters\nfrom this Mac, with one switch.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 12) {
                Field(label: "Canine URL") {
                    TextField("https://canine.sh", text: $baseURL)
                        .onSubmit { if !usesAPIToken { signInWithBrowser() } }
                }
                if usesAPIToken {
                    Field(label: "API token") {
                        SecureField("Paste your API token", text: $token)
                            .onSubmit(signInWithToken)
                    }
                }
            }

            VStack(spacing: 10) {
                if usesAPIToken {
                    Button(action: signInWithToken) {
                        ButtonLabel(title: "Sign In with Token", isBusy: model.isSigningIn)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.isSigningIn)

                    HStack(spacing: 12) {
                        Button("Create a token in Canine") {
                            if let url = URL(string: base)?.appendingPathComponent("api_tokens/new") { model.open(url) }
                        }
                        Text("·").foregroundStyle(.tertiary)
                        Button("Sign in with browser") { usesAPIToken = false }
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                } else {
                    Button(action: signInWithBrowser) {
                        ButtonLabel(title: "Sign In with Canine", systemImage: "safari", isBusy: model.isSigningIn)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.isSigningIn)

                    Text("Opens Canine in your browser to approve this Mac.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Button("Use an API token instead") { usesAPIToken = true }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }
            }
        }
    }

    private var base: String { baseURL.isEmpty ? AppModel.defaultBaseURL : baseURL }

    private func signInWithBrowser() {
        Task { await model.signInWithBrowser(baseURL: base) }
    }

    private func signInWithToken() {
        Task { await model.signIn(baseURL: base, token: token) }
    }
}

private struct ButtonLabel: View {
    let title: String
    var systemImage: String?
    let isBusy: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .opacity(isBusy ? 0 : 1)
            if isBusy { ProgressView().controlSize(.small).tint(.white) }
        }
    }
}

/// Shown while the person approves Canine Connect in their browser.
private struct WaitingForBrowser: View {
    @EnvironmentObject private var model: AppModel
    let host: String

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: Brand.logo)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
                Image(systemName: "safari.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, Brand.accent)
                    .background(Circle().fill(Color(nsColor: .windowBackgroundColor)).padding(-2))
                    .offset(x: 6, y: 4)
            }
            .padding(.top, 10)

            VStack(spacing: 6) {
                Text("Continue in your browser")
                    .font(.system(size: 17, weight: .semibold))
                Text("Approve Canine Connect on \(host).\nThis window updates when you're done.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(model.isSigningIn ? "Finishing sign-in…" : "Waiting for approval…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            VStack(spacing: 10) {
                Button { model.reopenBrowser() } label: {
                    ButtonLabel(title: "Open Browser Again", systemImage: "arrow.up.forward.app", isBusy: false)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Cancel") { model.cancelBrowserSignIn() }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            }
        }
    }
}

private struct Field<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            content
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Card(cornerRadius: 8))
        }
    }
}

// MARK: - Shared pieces

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.07))
            )
            .contentShape(Rectangle())
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Brand.accent.gradient)
                    .brightness(configuration.isPressed ? -0.08 : 0)
            )
            .opacity(isEnabled ? 1 : 0.6)
            .contentShape(Rectangle())
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

private struct Card: View {
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
    }
}

private struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 11.5))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.red.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.red.opacity(0.2)))
        )
    }
}
