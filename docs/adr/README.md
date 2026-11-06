# Architecture Decision Records (ADRs)

This directory records the architectural decisions governing this repository — both those
already embodied in the upstream TempleOS V5.03 codebase and those made for the Tailscale
effort.

## Format

Each ADR follows a lightweight variant of Michael Nygard's format:

```markdown
# NNNN. Title

- **Status:** accepted | proposed | superseded by NNNN | rejected
- **Date:** YYYY-MM-DD

## Context
What forces are at play (technical, organizational, historical).

## Decision
The change we are making and why, stated in one paragraph.

## Consequences
Trade-offs accepted, follow-up work, and what this decision rules out.
```

Numbering is sequential; ADRs are never deleted — they get superseded.

## Index

| ADR | Title | Status | Scope |
|---|---|---|---|
| [0001](0001-holyc-single-language.md) | HolyC as the single implementation language (no external toolchain) | Accepted (retroactive — upstream) | Toolchain |
| [0002](0002-monolithic-ring0-identity-mapped-kernel.md) | Monolithic ring-0 kernel with a single identity-mapped address space | Accepted (retroactive — upstream) | Kernel / memory |
| [0003](0003-redsea-native-filesystem.md) | RedSea as the native filesystem (contiguous files, bitmap allocation) | Accepted (retroactive — upstream) | Storage |
| [0004](0004-least-common-denominator-hardware.md) | Least-common-denominator hardware support (ATA PIO, PS/2, VGA; no PCI DMA, no USB) | Accepted (retroactive — upstream) | Hardware drivers |
| [0005](0005-no-networking-baseline.md) | No networking in the baseline OS | **Superseded by 0006** (upstream decision, re-opened by this fork) | Networking |
| [0006](0006-tailscale-integration-strategy.md) | Tailscale integration strategy: phased WireGuard-first, join tailnet as external WG peer | **Accepted** (Phase 0 landed 2026-11-06) | Networking (this fork) |

## Conventions for new ADRs

- One decision per ADR; link related docs in `../` (numbered docs 01–12).
- Decisions that change the upstream baseline must cite which upstream document they
  contradict (e.g., `Doc/Strategy.DD`) and say so explicitly.
- "Proposed" ADRs become "Accepted" when their first phase lands in code; record the date
  of acceptance in a commit message referencing the ADR number.
