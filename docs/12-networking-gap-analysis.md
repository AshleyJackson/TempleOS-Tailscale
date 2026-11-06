# 12 — Networking Gap Analysis (the Tailscale goal)

This document is the technical basis for the fork's purpose: making a TempleOS node able
to join a **Tailscale tailnet**. It records what exists today, what is missing, and a
phased work breakdown. The strategy decision itself lives in
[ADR-0006](adr/0006-tailscale-integration-strategy.md).

## Current state (verified against this tree)

**There is no networking of any kind.** A repository-wide search for TCP/IP, Ethernet or
Tailscale symbols finds only:

- `Misc/PCIDevices.DD` — a PCI *device-ID database* (documentation data), and
- `Demo/InFile/InSetIP.HC` — an IP-address *entry form* demo (UI pattern only).

Upstream, "no networking" was an explicit design decision (`Doc/Strategy.DD`,
`Doc/Requirements.DD`: *"Unsupported hardware: … No networking"*; the author even notes in
`Doc/WhyNotMore.DD` that FTP/telnet might be possible "in the far distant future" if they
fit the line budget). This fork consciously re-opens that decision — see
[ADR-0005](adr/0005-no-networking-baseline.md) (superseded) and ADR-0006.

### What exists and is reusable

| Asset | Where | Relevance to networking |
|---|---|---|
| PCI config-space reader + device enumeration (`dev.pci_head`) | `Kernel/PCIBIOS.HC` | Can find a NIC, read its BARs; **no** BAR mapping or DMA helpers exist yet |
| Uncached MMIO alias of the first 4 GiB (`dev.uncached_alias`) | `Kernel/Mem/PageTables.HC`, `KMain.HC:UncachedAliasAlloc` | NIC register memory (low-4-GiB BARs) is directly addressable — the mechanism a PIO/MMIO driver would use |
| Port I/O primitives (`InU8/OutU8/…`) | kernel asm | PIO register access (NE2000-class NICs are pure PIO) |
| Task/job model: dedicated tasks, `JobQue()` to AP cores, messages | `Kernel/Sched.HC`, `Job.HC`, `MultiProc.HC` | A polling **Net task** on Core0 + crypto jobs dispatched to AP cores fits the existing patterns (see `Demo/MultiCore/`) |
| Poll-and-`Yield()` I/O idiom | used by ATA disk driver (`Kernel/BlkDev/DskATA.HC`) | The house style for polled devices under a cooperative scheduler — NIC polling will follow it |
| F64 math + fixed-point lectures | `KMathA/B.HC`, `Demo/Lectures/FixedPoint*.HC` | Crypto needs integer/fixed-point code, not floats; the lectures are the in-repo reference |
| Registry for persistent settings, `.Z` file API | `Adam/ARegistry.HC`, `Kernel/BlkDev/DskFile.HC` | Storing node keys/config |
| DolDoc UI + widgets | `Adam/DolDoc/`, `Adam/Ctrls/` | A Tailscale status/config app would be a normal TempleOS app |

### What is missing (the gap)

1. **NIC driver** — none exist; no PCI DMA, no interrupt routing for PCI devices (PIC
   handles only IRQ0 timer / IRQ1 keyboard / IRQ12 mouse). A NIC must be *polled*, MMIO or
   PIO, consistent with how ATA disks are handled.
2. **Link layer** — Ethernet framing, ARP. Nothing exists.
3. **Network/transport layers** — no IPv4/IPv6, no UDP (WireGuard is UDP-based). Nothing
   exists; there isn't even a socket abstraction to extend.
4. **Cryptography** — no Curve25519, ChaCha20-Poly1305 or BLAKE2s anywhere in the tree.
   WireGuard requires all three (plus 64-bit integer arithmetic, which HolyC has natively).
5. **Tailnet membership** — either a Tailscale control-plane client (needs TLS/HTTPS —
   very heavy) or joining as an *external WireGuard peer* added from another tailnet node
   (only standard WireGuard required). See ADR-0006 for the decision.
6. **Device-model slot** — the drive-letter table has no class for network devices
   ([06](06-filesystems-and-storage.md)); a net device registry will be needed.

## Constraints that shape the design

- **Cooperative scheduler:** the Net task must poll-and-yield like the disk driver; under
  load, latency jitter is possible. Crypto (handshake + per-packet AEAD) should run as
  jobs on AP cores where available (`JobQue(JOBT_CALL)`), keeping Core0 responsive for UI.
- **No DMA:** packet buffers are copied through MMIO/PIO by the CPU. Fine for mesh-scale
  traffic (WireGuard workloads: chat, file sync, SSH); not a bulk-transfer design.
- **100k-line budget philosophy** (`Doc/Strategy.DD`): WireGuard's reference implementation
  is ~5–6k lines of C; a HolyC port with tests should be approachable within that spirit,
  but every line must earn its place.
- **Code heap:** the stack + crypto compile into the low-2-GiB code heap like everything
  else — no special handling, just keep an eye on total size.
- **512 MB minimum RAM:** keep ring buffers modest (e.g., a few hundred packets).

## Proposed repository layout for new work

```
Kernel/Net/                  # L2–L4 stack + NIC drivers (new directory)
  Net.HH                     #   public API (device registry, send/receive, config)
  NetTask.HC                 #   dedicated net task: poll loop + message pump
  NicNE2000.HC               #   NE2000/clone driver (QEMU "pcnet") — Phase 1 target
  NicRTL8139.HC              #   MMIO+PIO NIC for native hardware — later phase
  Arp.HC · Ip4.HC · Udp.HC   #   link/network/transport layers
Kernel/Crypto/               # reusable crypto primitives (new directory)
  Blake2s.HC · ChaCha20.HC · Poly1305.HC · Curve25519.HC
Kernel/Wg/                   # WireGuard protocol (new directory)
  WgHandshake.HC · WgData.HC · WgKeepalive.HC
Apps/Tailscale/              # user app: status, config, key management (DolDoc UI)
Demo/Net/                    # test programs: loopback frames, ping, RFC-vector self-tests
```

**Open question (recommendation):** keep the net stack **out of the AOT kernel module**
initially — JIT-load it from source like an app, so iteration doesn't require the full
`BootHDIns()` rebuild + boot-sector re-patch cycle. Move pieces into `Kernel.PRJ` only if
boot-time availability is ever needed. (Recorded in ADR-0006.)

## Phased work breakdown

| Phase | Deliverable | Exit test |
|---|---|---|
| **0 — Decisions & scaffolding** | ADRs finalized; `Kernel/Net` + `Kernel/Crypto` skeletons; net device registry design; config file format (registry keys) | Design review; empty Net task boots and yields cleanly |
| **1 — Raw Ethernet** | NE2000 driver for QEMU (`pcnet`); frame TX/RX on a polled loop | Two TempleOS VMs on a QEMU hub exchange crafted frames; patterns verified in `Demo/Net/` |
| **2 — IP + UDP** | ARP cache, IPv4 addressing (static config), UDP send/receive API | TempleOS node pings and UDP-echoes a Linux host on the same L2 segment (and vice versa) |
| **3 — WireGuard** | Crypto primitives with in-OS unit tests against RFC 7748 / RFC 8439 test vectors; WG handshake + data path between two TempleOS nodes (manual key exchange via file) | Two TempleOS VMs form a WG tunnel; throughput/loss sanity check; all RFC vectors pass |
| **4 — Tailnet membership** | Node added to an existing tailnet as an **external WireGuard peer** from another node; `Apps/Tailscale` status/config UI; persistent keys in registry | TempleOS node reachable by tailnet IP from other members; survives reboot with stored config |

**Status (2026-11-06):** Phase 0 complete — `Kernel/Net` + `Kernel/Crypto`
skeletons landed (`CNetDev` device registry, net task with poll/yield loop and
message pump, NE2000 register map + driver stubs, ARP/IP4/UDP interface stubs,
crypto interface stubs), config/key storage format fixed in
[net-config.md](net-config.md), and the exit test lives at
`Demo/Net/NetSelfTest.HC`. ADR-0006 is accepted.

Deferred (out of scope for now): IPv6, Tailscale control-plane protocol (TLS), DERP
relays, Funnel, TCP. Each would be a separate ADR if pursued.
