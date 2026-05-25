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
- `SHA256SUMS`

to the corresponding GitHub Release, and push the supporting container images plus the final node image to `ghcr.io/go-riscv`.

The published node image reference is:

`ghcr.io/go-riscv/node:vX.Y.Z`
