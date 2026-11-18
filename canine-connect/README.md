# Canine Connect

A macOS menu bar app that puts your Mac on a Canine cluster's private network with one switch, using
[Telepresence](https://telepresence.io). Once it's connected, `http://<service>.<namespace>.svc.cluster.local`
resolves and works from your browser, `psql`, `curl`, and so on, even for services that aren't public.

## Build and run

Needs macOS 13+ and the Swift toolchain (the Xcode Command Line Tools are enough):

```bash
cd canine-connect
script/build.sh --install   # builds, copies to ~/Applications, launches
```

`script/build.sh` on its own just builds `dist/Canine Connect.app`.

To check UI changes without clicking through the menu bar, render every state (signed out, disconnected,
connecting, connected, error) in light and dark mode to PNGs:

```bash
swift build && .build/debug/CanineConnect --snapshot /tmp/canine-connect-snapshots
```

## Using it

1. Click the Canine dog in the menu bar.
2. Sign in with your Canine URL and an API token (**Create one** opens Canine's API token page).
3. Choose a cluster and flip the switch. The first time, macOS asks for your password so Telepresence's
   network daemon can create the tunnel.

Picking another cluster while connected moves the connection to it. Quitting the app disconnects and stops the
Telepresence daemons.

## How it works

- **Canine:** calls `GET /api/v1/me` and `GET /api/v1/clusters` with the `X-API-Key` header, and `X-Account-Id`
  for the selected account. On connect it downloads that cluster's kubeconfig from
  `GET /api/v1/clusters/:name/download_kubeconfig` to `~/Library/Application Support/Canine Connect/kubeconfigs/`
  (mode 0600). The token is kept in the login keychain.
- **Telepresence:** the app ships its own CLI in `Contents/Resources/bin/telepresence`, pinned to the same version
  as the Traffic Manager chart Canine installs (`resources/helm/system_packages.yml`). It runs
  `telepresence connect --kubeconfig <file> --manager-namespace canine-system`, and polls
  `telepresence status --output json` for the menu bar state.
- **Root daemon:** Telepresence's root daemon has to run as root, and the CLI normally starts it with `sudo` from a
  terminal. A GUI app has no terminal, so the app starts `telepresence daemon-foreground` itself through the
  standard macOS administrator prompt. After that, `telepresence connect` needs no privileges.
- Clusters whose `telepresence` package isn't installed get a warning that links to the cluster in Canine.

Logs are in `~/Library/Logs/telepresence` (gear menu → **Open Telepresence Logs**).

## Releasing

People download the app from the **Canine Connect** page in Canine (`/canine_connect`, also linked from every
service's "Connect from your computer" dialog). Those links point at GitHub release assets built by
`.github/workflows/canine-connect.yml`:

1. Bump `CFBundleShortVersionString` in `Resources/Info.plist` and `CanineConnectRelease::VERSION` in
   `app/models/canine_connect_release.rb` to the same version (a spec checks they match).
2. Push a tag: `git tag canine-connect-v0.1.0 && git push origin canine-connect-v0.1.0`.

The workflow builds `CanineConnect-macos-arm64.zip` and `CanineConnect-macos-x86_64.zip` (`ARCH=... script/build.sh --zip`)
and attaches them to the `canine-connect-v<version>` release.

The download page's screenshot is `public/images/canine_connect/connected.png`, the `connected-dark.png` output of
`--snapshot`.

## Bumping Telepresence

Change `TELEPRESENCE_VERSION` in `script/build.sh` together with the chart version in
`resources/helm/system_packages.yml` and the CLI version in the root `Dockerfile` and `resources/system_install.sh`.
`spec/models/cluster_package_spec.rb` fails if they drift apart.

## Limitations

- The app is ad-hoc signed, not notarized. A browser download is quarantined, so macOS asks people to approve it
  under System Settings → Privacy & Security → Open Anyway. The `curl` install command on the download page avoids
  that. A Developer ID signature and notarization would remove the step.
- Releases are per-architecture (Apple Silicon and Intel), not a universal binary.
- A kubeconfig that authenticates through an exec plugin (`aws`, `gcloud`, `doctl`) needs that tool in
  `/opt/homebrew/bin`, `/usr/local/bin` or the system paths.
