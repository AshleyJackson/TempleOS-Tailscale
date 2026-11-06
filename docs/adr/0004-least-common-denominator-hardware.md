# 0004. Least-common-denominator hardware support (ATA PIO, PS/2, VGA; no PCI DMA, no USB)

- **Status:** accepted (retroactive — upstream decision, recorded here for this fork)
- **Date:** recorded 2026-11-06; original decision by the upstream author (`Doc/Strategy.DD`, `Doc/WhyNotMore.DD`)

## Context

PC hardware diversity is "the greatest challenge for PC operating systems"
(`Doc/Strategy.DD`). The author's rule: one driver per device class, using only the oldest
stable interfaces — ATA/SATA PIO (polled I/O ports), ATAPI CD/DVD, PS/2 keyboard/mouse,
VGA 640×480 16-color, PC speaker, PIT/HPET timers, PIC interrupts. Modern PCI devices were
tried and rejected: "modern PCI devices require ten times more code and I cannot even come
close to making them work on everyone's machine" (`Doc/WhyNotMore.DD`, after an HDAudio
attempt). USB was judged hopeless for the same reason. The result is a system that runs in
QEMU/VMware/VirtualBox with legacy BIOS settings, at the cost of slow PIO disk I/O and no
native-hardware friendliness.

## Decision

Support exactly one driver per device class on legacy interfaces; **no PCI DMA, no PCI
device interrupts, no USB, no UEFI, no GPU acceleration, no sound cards**. Disk I/O is
polled (no interrupts) to avoid compatibility risk. A minimal PCI *config-space* reader
exists (`Kernel/PCIBIOS.HC`) for locating legacy devices and reading HPET — not as a
general PCI driver framework.

## Consequences

- **Gains:** small, uniform, highly portable driver code; works across VMs and old/new
  hardware alike; the whole storage stack fits in a few thousand lines.
- **Costs accepted:** slow PIO disk throughput; no modern devices (AHCI, USB mass storage,
  HD audio); native installs are discouraged by the author himself.
- For this fork: this ADR is the direct constraint on networking work. A NIC cannot use
  DMA or PCI interrupts — it must be **polled MMIO/PIO** through `dev.uncached_alias`,
  exactly like the ATA driver polls its ports. That shapes the hardware targets and the
  performance expectations in [../12-networking-gap-analysis.md](../12-networking-gap-analysis.md)
  and ADR-0006. Note that adding a NIC is *new* territory even for this philosophy: it is
  still "one driver per class, polled", but the class (network) did not exist upstream.
