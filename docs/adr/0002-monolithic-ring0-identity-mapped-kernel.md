# 0002. Monolithic ring-0 kernel with a single identity-mapped address space

- **Status:** accepted (retroactive — upstream decision, recorded here for this fork)
- **Date:** recorded 2026-11-06; original design since ~2003 (`Doc/MemOverview.DD` history)

## Context

The author's stated goal was "a no-paging ring-0-only 64-bit operating system for super
speed with simplicity and full access" (2003, `Doc/MemOverview.DD`). Long mode requires
paging, so the compromise is an identity map: virtual == physical, one page-table set for
all tasks on all cores. There are no user/kernel privilege boundaries, no per-process
address spaces, no swap, and no memory protection between tasks. The compiler emits only
signed 32-bit relative `CALL/JMP`, which forces all code into the lowest 2 GiB ("code
heap"); data lives above it in the "data heap".

## Decision

Everything — kernel services, the compiler, every application — runs in **ring 0** and
shares **one identity-mapped address space**. Task isolation is organizational (each task
has its own heaps, stack and symbol table; memory is freed when a task dies), not
architectural. Context switches are register save/restore only (~0.5 µs). Hardware access
goes through an uncached alias of the first 4 GiB at `0x01AA000000`.

## Consequences

- **Gains:** trivially fast task switching; any pointer is valid from anywhere; no TLB or
  address-map management; a uniform programming model for kernel and app code.
- **Costs accepted:** one bug can clobber any other component's memory — defensive coding
  and in-system testing carry the safety load. There is no security boundary of any kind
  (explicitly: "No security or cryptography", `Doc/Strategy.DD`).
- For this fork: a network stack runs with full privilege and direct hardware access by
  default. A misbehaving NIC driver can take down the whole system — acceptable for a
  single-user home OS, but it raises the bar on Phase 1–2 testing in
  [../12-networking-gap-analysis.md](../12-networking-gap-analysis.md).
