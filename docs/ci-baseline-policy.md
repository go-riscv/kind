# CI baseline image policy

PR CI has two modes:

- `USE_PREBUILT_BASELINES=0` (default): rebuild release helper images from source. This remains the conservative fallback.
- `USE_PREBUILT_BASELINES=1`: no-apt PR consumer mode. PR CI pulls trusted, digest-pinned baseline/helper images from `ghcr.io/go-riscv`, retags them to the local names expected by the existing Makefiles, then rebuilds source-derived/current-output images from the PR.

Both modes use the `local` KinD build profile. The tagged release workflow uses the separate `release` profile, requires a `vX.Y.Z` release tag, and embeds that tag into the node, pause, kindnetd, local-path, and RISC-V HAProxy image references.

No-apt PR consumer mode is deterministic validation, not a security freshness guarantee. Freshness belongs to the baseline producer workflow and release workflow, where apt-based rebuilds happen explicitly.

The `no-apt` name applies to provisioning trusted baseline images on the PR runner. Source-derived images still execute their upstream package-install steps inside Docker builds when their inputs change. HAProxy is intentionally in that category: it is rebuilt from the patched KinD image definition and may run `apt-get` inside its isolated build container.

## Stable baseline images trusted by digest in PR consumer mode

These may be consumed only as immutable `@sha256` refs from `hack/release/baseline-images.env`:

- `debian-base-riscv64`
- `kube-cross-riscv64`
- `go-runner-riscv64`
- `setcap-riscv64`
- `distroless-iptables-riscv64`

Mutable tag-only refs are rejected by `hack/release/verify-baseline-images.sh`.

## Source-derived/current-output images

These are not trusted as generic PR baselines in the first pass:

- `pause`
- `etcd`
- `base`
- `kindnetd`
- `local-path-helper`
- `local-path-provisioner`
- `haproxy`
- final kind node image

They must be rebuilt when relevant source, patch, or version inputs change. In particular, a PR touching `pkg/kubernetes/**`, `pkg/kubernetes/patches/**`, `pkg/common.mk` Kubernetes/pause constants, or pause build wiring must not pass by silently consuming a stale prebuilt pause image.

## Timing evidence

`hack/release/build-images.sh` logs elapsed seconds, mode, and no-apt status:

```text
release image build elapsed_seconds=<n> mode=<0|1> no_apt_pr_ci=<0|1>
```

Use this line plus the GitHub Actions step duration to compare before/after PR CI behavior.
