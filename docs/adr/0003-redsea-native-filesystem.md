# 0003. RedSea as the native filesystem (contiguous files, bitmap allocation)

- **Status:** accepted (retroactive — upstream decision, recorded here for this fork)
- **Date:** recorded 2026-11-06; original decision by the upstream author (~2015–2017 era)

## Context

TempleOS processes files almost exclusively as whole units ("Whole files are processed
almost exclusively, allowing compression" — `Doc/Strategy.DD`). A fragmented, grow-in-place
filesystem (FAT-style chains) conflicts with that model and adds code. The author wanted a
64-bit filesystem simpler than FAT32: no FAT table, fixed directory entries, absolute block
addresses (`Doc/RedSea.DD`).

## Decision

The native filesystem is **RedSea** (MBR partition type 0x88): files are allocated in
**contiguous blocks only and cannot grow**; allocation is a plain bitmap; directory entries
are fixed 64-byte records with ≤37-char names. Whole-file orientation enables transparent
`.Z` compression of every file on disk. FAT32 support exists for interop but is slated for
removal if other OSes would mount RedSea instead (`Doc/Demands.DD`). CD/DVD media use
RedSea laid over ISO9660/EL TORITO ("RedSea-on-ISO").

## Consequences

- **Gains:** simple, fast whole-file I/O; compression everywhere for free; tiny driver code.
- **Costs accepted:** no in-place growth (rewrite to replace), no bad-block table, no
  journaling or redundant allocation metadata — reliability is a documented trade-off
  (`Doc/Reliability.DD`). Long-running writers must manage their own temp-file + rename
  pattern.
- For this fork: network configuration and key material should be written whole-file with
  the same rewrite-replace discipline; there is no append-friendly log format to lean on.
