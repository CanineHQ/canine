# Agent Sandbox Snapshots

## Problem

When an agent sandbox pod restarts, all filesystem changes are lost — installed system packages (`apt install`), globally installed tools (`pip install`, `go install`), config files, etc. Only the home directory (`/home/gem`) is persisted via PVC. Mounting individual directories (like `/usr/local`, `/var/lib/apt`) is fragile since tools can install to arbitrary paths.

## Solution: OCI Image Snapshots via In-Cluster Registry

Commit the entire container filesystem to an OCI image on stop, push it to an in-cluster registry, and use that image on next boot. This captures everything — system packages, global tools, config changes — with zero guesswork about which directories changed.

### Why This Approach

- **Complete**: captures the full filesystem diff, not just specific mount paths
- **No special hardware**: works on any Kubernetes cluster (DigitalOcean, GKE, EKS, bare metal)
- **No secrets leakage**: images never leave the cluster since the registry runs in-cluster
- **Simple restore**: the snapshot image IS the container image on next boot — no init containers, no extract step
- **Efficient**: OCI layering means only the diff from the base image is stored

### Performance Expectations

| Operation | Time |
|-----------|------|
| Snapshot (commit + push to in-cluster registry) | 15-30s |
| Restore (pull snapshot image) | 10-20s |
| Typical snapshot size (user delta) | 200MB - 2GB |

## Architecture

```
Stop flow:
  Canine → SnapshotJob → exec into pod, commit filesystem → push to in-cluster registry → save image ref → delete pod

Start flow:
  Canine → ProvisionJob → check for snapshot_image → create Sandbox CR with snapshot image (or base image if first boot)

First boot:
  image: ghcr.io/agent-infra/sandbox:1.0.0.152

Subsequent boots:
  image: registry.default.svc.cluster.local:5000/sandbox-snapshots:sandbox-{id}-{timestamp}
```

## Implementation Plan

### 1. In-Cluster Registry (part of agent-sandbox cluster package)

Deploy a plain Docker `registry:2` as a Deployment + Service + PVC inside the cluster when the agent-sandbox package is installed. No external ingress — only accessible via cluster DNS at `registry.default.svc.cluster.local:5000`.

- Deployment: `registry:2` image, single replica
- Service: ClusterIP on port 5000
- PVC: persistent storage for image layers (size TBD, start with 50-100Gi)
- No auth needed since it's cluster-internal only

Update `ClusterPackage::Installer::AgentSandbox` to deploy the registry manifests alongside the agent-sandbox CRDs.

### 2. Database Changes

Add `snapshot_image` column to `agent_sandboxes` table:

```ruby
add_column :agent_sandboxes, :snapshot_image, :string
```

### 3. SnapshotJob

New job: `AgentSandboxes::SnapshotJob`

- Exec into the running pod
- Use `crane` (or `buildah`/`skopeo`) to commit the container filesystem to a new OCI image
- Push to `registry.default.svc.cluster.local:5000/sandbox-snapshots:sandbox-{id}-{timestamp}`
- Update `agent_sandbox.snapshot_image` with the full image reference
- Note: `crane` is preferred — it's a single Go binary, no daemon needed, no privileges required

### 4. Update ProvisionJob

Modify `build_sandbox_yaml` to use the snapshot image if available:

```ruby
image = agent_sandbox.snapshot_image || "ghcr.io/agent-infra/sandbox:1.0.0.152"
```

When booting from a snapshot, the Sandbox CR uses the snapshot image instead of the base image. No other changes needed — the pod just starts with the user's full environment baked in.

### 5. Stop vs Destroy Actions

Introduce two distinct actions:

- **Stop**: snapshot the filesystem, then suspend/delete the pod. Sandbox record stays. Can be resumed later from the snapshot.
- **Destroy**: optionally snapshot, then delete the pod AND the sandbox record. Clean removal.

Add a `stop` action to the controller and a `StopJob` that runs `SnapshotJob` then suspends the sandbox.

### 6. UI Changes

- Add "Stop" button to sandbox show page (alongside existing "Destroy")
- Show snapshot status/timestamp on the sandbox detail page
- Indicate whether a sandbox will boot from a snapshot or fresh image

## Open Questions

- **Registry storage sizing**: How much PVC space for the registry? Depends on number of sandboxes and how much users install. Start with 100Gi and monitor.
- **Snapshot retention**: Keep only the latest snapshot per sandbox, or allow multiple? Probably just latest to save space.
- **Crane installation**: Needs to be available in the pod or run as a Job. Could use a sidecar or a separate snapshot pod with crane pre-installed.
- **Base image updates**: When the base aio-sandbox image is updated, snapshots are still based on the old image. May need a "rebuild" option that starts fresh from the new base image.
- **Concurrent access**: If multiple users are connected when a stop is triggered, need to handle gracefully (notify, then snapshot).

## References

- OpenSandbox rootfs snapshot approach: https://open-sandbox.ai/architecture
- Agent Sandbox snapshots (GKE-only): https://agent-sandbox.sigs.k8s.io/docs/sandbox/snapshots/
- crane (OCI tool): https://github.com/google/go-containerregistry/tree/main/cmd/crane
- Docker registry: https://hub.docker.com/_/registry
