# 0006. Tailscale integration strategy: phased WireGuard-first, join the tailnet as an external WireGuard peer

- **Status:** proposed
- **Date:** 2026-11-06

## Context

The purpose of this fork is to make a TempleOS node joinable to a **Tailscale tailnet**.
Constraints inherited from the baseline (ADRs 0001–0005): HolyC only, no external
toolchain or libraries; ring-0 single address space; polled PIO/MMIO hardware access with
no PCI DMA and no PCI interrupts; cooperative scheduler; a self-imposed ~100k-line budget
philosophy. The baseline has **zero** networking code — no NIC driver, no IP stack, no
crypto primitives (see [../12-networking-gap-analysis.md](../12-networking-gap-analysis.md)).

Tailscale itself is a Go userspace daemon (`tailscaled`) plus WireGuard: it speaks TLS to
a control plane for key/endpoint management and uses WireGuard (UDP) for actual traffic.
The full product therefore implies, in increasing order of cost: a NIC driver → an
Ethernet/IP/UDP stack → WireGuard crypto+protocol → optionally a TLS-based control-plane
client.

## Options considered

| Option | Description | Verdict |
|---|---|---|
| **A. Port `tailscaled` (Go) to TempleOS** | Run the Go runtime + tailscaled on HolyC | **Rejected.** Requires a GC/goroutine runtime, TLS, HTTP/2 and TCP — an order of magnitude beyond the line budget and contrary to ADR-0001's single-language simplicity. No realistic path. |
| **B. WireGuard in HolyC + full Tailscale control-plane client** | Implement WG *and* a TLS client for `controlplane.tailscale.com` (or self-hosted Headscale) so the node registers like any other Tailscale machine | **Deferred.** Technically possible but TLS (certificates, ECDHE handshake, X.509) is far more crypto surface than WireGuard itself, and the control protocol is complex and evolving. Revisit only if DERP relays / full Tailscale features become required — as a separate ADR. |
| **C. Standard WireGuard in HolyC; join the tailnet as an *external WireGuard peer*** | Implement the standard WireGuard protocol (Curve25519, ChaCha20-Poly1305, BLAKE2s) and have an administrator add the TempleOS node to an existing tailnet from another member node — Tailscale supports adding raw WireGuard peers to a tailnet. No TLS, no control protocol; keys are static and managed locally | **Recommended.** Delivers real tailnet membership (routing, DNS-by-convention, reachability by tailnet IP) with the minimum viable crypto surface: exactly one well-specified protocol with public test vectors (RFC 7748 / RFC 8439 / WG spec). |
| **D. Sidecar: run tailscaled on a companion Linux box and bridge to TempleOS** | Keep all Tailscale logic off-OS; connect the two machines over some link | **Rejected.** The bridge still requires a NIC driver + L2/L3 stack *inside* TempleOS (there is no shared-memory or other channel between them), so it saves none of the hard work while adding a second machine to babysit. |

## Decision

Adopt **Option C**, executed in the phases defined in
[../12-networking-gap-analysis.md](../12-networking-gap-analysis.md):

1. **Phase 0** — scaffolding: `Kernel/Net`, `Kernel/Crypto` directories; net device registry design (the drive-letter table has no network class); config/key storage via the registry + whole-file rewrite-replace discipline (ADR-0003).
2. **Phase 1** — raw Ethernet on a **polled NE2000-class driver** targeting QEMU's `pcnet` emulation (pure PIO, ideal for VM development; consistent with ADR-0004's one-driver-per-class, polled-I/O rule). Native-hardware NICs (MMIO+PIO class, e.g. RTL8139) come later as a second driver of the same "class".
3. **Phase 2** — ARP + IPv4 + UDP with static configuration; interop verified against a Linux host on the same L2 segment.
4. **Phase 3** — WireGuard: crypto primitives first, each validated in-system against published RFC test vectors (BLAKE2s, ChaCha20-Poly1305, Curve25519), then handshake + data path between two TempleOS nodes with manually exchanged keys.
5. **Phase 4** — tailnet membership as an external WireGuard peer; a `Apps/Tailscale` status/config app (DolDoc UI); persistent node key in the registry.

Supporting decisions:

- **Stack placement:** the net stack and crypto are initially **JIT-loadable modules outside the AOT kernel module** — no `Kernel.PRJ` changes, so iteration avoids the full rebuild + boot-sector re-patch cycle (see [../08-compiler-toolchain.md](../08-compiler-toolchain.md)). Move pieces into the kernel module only if boot-time availability is ever required.
- **Concurrency model:** a dedicated **Net task** on Core0 polls the NIC using the existing poll-and-`Yield()` idiom (same pattern as `Kernel/BlkDev/DskATA.HC`). Per-packet crypto (handshake + AEAD) is dispatched to AP cores as `JOBT_CALL` jobs when available, keeping the UI core responsive (`Demo/MultiCore/` patterns).
- **No DMA:** packet buffers are CPU-copied through PIO/MMIO. Acceptable for mesh-scale traffic; bulk transfer is out of scope.

## Consequences

**Gains**
- Real tailnet membership with a single, stable, well-specified protocol and public test vectors — the smallest credible path to "TempleOS on Tailscale".
- The WireGuard implementation is reusable independent of Tailscale (plain WG mesh between TempleOS nodes works from Phase 3).
- Stays inside the baseline's complexity philosophy: one driver per class, polled I/O, bounded line count, no new runtime dependencies.

**Costs / accepted limitations**
- **No DERP relays or Funnel** in this scope: connectivity requires UDP reachability between peers (direct, or via a user-configured static endpoint/NAT traversal done manually). Acceptable for home-LAN + tailnet use; revisit via Option B if needed.
- IPv4 only initially; no TCP (so no HTTP/HTTPS from TempleOS yet — the browser question remains open upstream).
- External-peer registration is an admin action on another node, not self-service from the TempleOS box.
- A misbehaving NIC driver or stack runs ring-0 with full memory access (ADR-0002): Phase 1–2 testing must be thorough before native-hardware use.

**Follow-ups (future ADRs if pursued)**
- TLS + Tailscale control-plane client (Option B) for DERP/Funnel and self-service enrollment.
- IPv6, TCP, and any browser work — each a separate decision with its own line-budget analysis.
