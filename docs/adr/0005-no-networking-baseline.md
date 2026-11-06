# 0005. No networking in the baseline OS

- **Status:** **superseded by [0006](0006-tailscale-integration-strategy.md)** (for this fork)
- **Date:** recorded 2026-11-06; original decision by the upstream author, stated repeatedly in `Doc/Strategy.DD`, `Doc/Requirements.DD`, `Doc/Demands.DD`

## Context

Upstream TempleOS deliberately excluded networking as a core design constraint:
"TempleOS does not do networking or multimedia" (`Doc/Strategy.DD`); "Unsupported
hardware: … No networking" (`Doc/Requirements.DD`). The rationale was complexity budget —
a browser is impossible within the 100k-line limit, and even FTP/telnet were only
speculated about "in the far distant future" if they could fit it (`Doc/WhyNotMore.DD`).
The OS was designed to dual-boot alongside Windows/Linux precisely *because* it has no
networking (`Doc/Demands.DD`), with file exchange happening through shared RedSea/FAT32
partitions and ISO-file drives.

## Decision (upstream)

No NIC drivers, no IP stack, no sockets, no crypto — networking was out of scope for the
system as released (V5.03). This repository's baseline contains zero networking code; the
only network-adjacent artifacts are a PCI device-ID database (`Misc/PCIDevices.DD`) and an
IP-entry form demo (`Demo/InFile/InSetIP.HC`).

## Consequences for this fork

- The upstream decision is **not** treated as binding here: the repository's purpose
  (its name) is to add Tailscale networking. This ADR exists so that the contradiction is
  explicit and deliberate, not accidental drift.
- Everything in [../12-networking-gap-analysis.md](../12-networking-gap-analysis.md) is net-new
  work: NIC driver, L2/L3/L4 stack, crypto, tailnet membership. None of it can be "found"
  in the baseline — only reused (PCI config reader, uncached MMIO alias, task/job model).
- The upstream complexity arguments still apply and are carried into ADR-0006 as design
  constraints: keep the line count bounded, one driver per class, polled I/O, no TLS.
