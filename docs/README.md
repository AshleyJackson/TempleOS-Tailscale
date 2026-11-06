# TempleOS-Tailscale — Documentation

This repository is a source snapshot of **TempleOS V5.03** (the final public release,
March 2017; this tree tracks the November 2017 nightly plus a February 2020 fix commit)
with the stated goal of adding **Tailscale networking** to it.

> **Provenance.** The code in `Kernel/`, `Compiler/`, `Apps/`, `Adam/`, `Demo/`, `Doc/`
> and `Misc/` is unmodified upstream TempleOS source, written by Terry Davis ("Adam")
> in HolyC, a nonstandard C dialect. It compiles **only** inside TempleOS itself — there
> is no external toolchain. See [01-project-overview.md](01-project-overview.md).

## Documentation index

| Doc | Contents |
|---|---|
| [01-project-overview.md](01-project-overview.md) | What this repo is, provenance, the Tailscale goal, top-level directory map |
| [02-architecture.md](02-architecture.md) | System architecture: boot chain, kernel subsystems, task model, memory, storage, toolchain (with diagrams) |
| [03-boot-process.md](03-boot-process.md) | BIOS → boot sector → 16/32/64-bit stages → `KMain` → `StartOS.HC`; installers; RAM reboot |
| [04-kernel-subsystems.md](04-kernel-subsystems.md) | Scheduler, tasks/jobs/messages, exceptions, interrupts & timers, multicore (master/slave), display, sound |
| [05-memory-management.md](05-memory-management.md) | Identity mapping, code vs data heap, block pools, page tables, uncached alias, per-task heaps |
| [06-filesystems-and-storage.md](06-filesystems-and-storage.md) | RedSea (native), FAT32, ISO9660; ATA PIO / ATAPI block devices; drive-letter table; `.Z` compression |
| [07-holyc-language.md](07-holyc-language.md) | HolyC language guide: types, syntax extensions, `$`-links, `#exe`, asm blocks, scoping rules |
| [08-compiler-toolchain.md](08-compiler-toolchain.md) | Compiler pipeline (lex → parse → optimize → codegen), JIT vs AOT, `.PRJ`/`.BIN` files, build flow |
| [09-applications-and-tools.md](09-applications-and-tools.md) | Catalog of `Apps/` and the `Adam/` developer tools (DolDoc editor, God, sprite editor, disk utilities…) |
| [10-demos-and-lectures.md](10-demos-and-lectures.md) | Index of `Demo/` programs and `Demo/Lectures/` teaching material |
| [11-build-test-distribute.md](11-build-test-distribute.md) | How the OS is built, tested (`OSTestSuite`) and distributed (custom ISOs, TOSZ Linux tool) |
| [12-networking-gap-analysis.md](12-networking-gap-analysis.md) | **The point of this fork:** what exists today, what is missing for Tailscale, and the work breakdown (with phase status) |
| [net-config.md](net-config.md) | Net stack config & key storage design (Phase 0 deliverable of ADR-0006) |

## Architecture Decision Records

See [`adr/README.md`](adr/README.md). ADRs 0001–0005 document decisions already
embodied in the upstream codebase (retroactive); **ADR-0006** is the decision record
for the Tailscale integration strategy — accepted, with Phase 0 scaffolding landed.

## Relationship to `Doc/`

The original author's documentation lives in [`../Doc/`](../Doc/) as `.DD` files — a
binary-ish "DolDoc" format with `$` markup, viewable only inside TempleOS's editor.
These Markdown docs are the external-facing companion: they summarize and cross-reference
the `.DD` material for people working on this repository from outside TempleOS. Where the
two disagree, the source code wins; where the author's intent matters (design rationale),
the `.DD` files are authoritative — especially `Strategy.DD`, `WhyNotMore.DD`,
`MemOverview.DD`, `Boot.DD`, `RedSea.DD`, `HolyC.DD` and `Glossary.DD`.
