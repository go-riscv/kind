# KinD for RISC-V

This repository ports [KinD](https://kind.sigs.k8s.io/) to `linux/riscv64`. The supported release pair is KinD v0.33.0 with Kubernetes v1.37.0. It builds the KinD and Kubernetes command line tools, the RISC-V node image, and the helper images required to create default and multi-control-plane clusters on RISC-V hosts.

## Release assets

The future release contract contains exactly six assets:

- `kind-linux-riscv64`
- `kubectl-linux-riscv64`
- `kubeadm-linux-riscv64`
- `kind-config-linux-riscv64.yaml`
- `verify-kind-release-riscv64.sh`
- `SHA256SUMS`

The already-published v0.33.0 release remains unchanged with seven assets; it also contains `k9s-linux-riscv64`. That historical artifact is not part of the current build or future release contract.

The release also publishes these images to `ghcr.io/go-riscv`: `kube-cross-riscv64`, `debian-base-riscv64`, `go-runner-riscv64`, `setcap-riscv64`, `distroless-iptables-riscv64`, `pause`, `etcd`, `local-path-helper`, `local-path-provisioner`, `base`, `kindnetd`, `haproxy`, and `node`. The released KinD binary defaults to `ghcr.io/go-riscv/node:vX.Y.Z`. HAProxy remains the RISC-V load balancer because the upstream Envoy image does not publish `linux/riscv64`.

## Development

Run the repository contract tests before building:

```sh
hack/ci/test-release-identity.sh
hack/ci/test-build-orchestration.sh
hack/ci/test-minimum-surface.sh
```

Build local images and binaries, then stage checksummed artifacts:

```sh
make dev-build
make dev-checksums
```

Local builds use `kindest/node:latest` as the output image name and local RISC-V helper image tags. The CI workflow uses GitHub Actions BuildKit cache import and export settings for the release helper images.

## Release workflow

Tags matching the canonical release version run the release workflow. The current source contract builds KinD v0.33.0 with Kubernetes v1.37.0 at its pinned release commit, verifies the binary and image contracts, publishes the versioned GHCR images and six future-contract assets, then creates default and HA clusters from downloaded release artifacts.

To verify a published release independently on a RISC-V host:

```sh
curl -fLO https://github.com/go-riscv/kind/releases/download/vX.Y.Z/verify-kind-release-riscv64.sh
chmod 0755 verify-kind-release-riscv64.sh
DOWNLOAD_RELEASE_ASSETS=1 ./verify-kind-release-riscv64.sh vX.Y.Z
```

The verifier checks `SHA256SUMS`, uses the released KinD configuration, and confirms that the running node and HAProxy images resolve to the expected GHCR repositories.
