# Introduction

Welcome to the `k8s-riscv64` repository! This repository contains the necessary files and configurations to deploy Kubernetes on RISC-V 64-bit architecture.

In this README, you will find detailed instructions on how to set up and use `k8s-riscv64` to run Kubernetes clusters on RISC-V 64-bit machines.

Let's get started!

# Usage

## Releases

Tagged releases in the form `vX.Y.Z` publish:

- `kind-linux-riscv64`
- `kubectl-linux-riscv64`
- `kubeadm-linux-riscv64`
- `k9s-linux-riscv64`
- `kind-config-linux-riscv64.yaml`
- `verify-kind-release-riscv64.sh`
- `SHA256SUMS`

to the corresponding GitHub Release, and push the supporting container images plus the final node image to `ghcr.io/go-riscv`.

The published node image reference is:

`ghcr.io/go-riscv/node:vX.Y.Z`

The published `kind-linux-riscv64` binary is built with that GHCR node image as its default node image; override it with `--image` or a KinD config only when using a local/custom node image.

Use `make dev-build` for local development. This profile uses `kindest/node:latest`, locally tagged RISC-V helper images, and `haproxy:riscv64` for multi-control-plane clusters. Tagged releases use the explicit release profile and require `RELEASE_TAG=vX.Y.Z`; every runtime image reference and the generated release config then use that same tag. KinD v0.32 uses Envoy upstream, but this RISC-V build deliberately retains HAProxy because the upstream Envoy image does not publish `linux/riscv64`.

The release config can be used directly:

```sh
./kind-linux-riscv64 create cluster --config kind-config-linux-riscv64.yaml
```

To verify a release on a RISC-V host without `gh`, download the verifier and let it fetch the checksummed assets. It removes only the exact release and development tags before creating the cluster, then verifies that the running node and HAProxy images resolve to GHCR repository digests:

```sh
curl -fLO https://github.com/go-riscv/kind/releases/download/vX.Y.Z/verify-kind-release-riscv64.sh
chmod 0755 verify-kind-release-riscv64.sh
DOWNLOAD_RELEASE_ASSETS=1 ./verify-kind-release-riscv64.sh vX.Y.Z
```
