# 0001. HolyC as the single implementation language (no external toolchain)

- **Status:** accepted (retroactive — upstream decision, recorded here for this fork)
- **Date:** recorded 2026-11-06; original decision by the upstream author ~2003–2017

## Context

TempleOS is a single-author project with a self-imposed ~100k-line budget and an explicit
goal of total simplicity (`Doc/Strategy.DD`: "One language … for command-line, scripts,
songs, automations and code"). The system must be buildable from its own source with no
external dependencies: the compiler is written in the same language it compiles, and the
only AOT artifacts are the kernel module and the compiler itself.

## Decision

The entire OS — kernel, compiler, applications, scripts, songs and automations — is
written in **HolyC** (a nonstandard C dialect) plus inline x86/x86_64 assembly, and it
compiles **only inside TempleOS itself**. There is no external toolchain, no linker, no
object files: user code is JIT-compiled into the code heap at runtime; `.PRJ` file lists
AOT-compile only the kernel module and the compiler.

## Consequences

- The system is self-hosting and fully auditable from one source tree (this repository).
- Development requires a running TempleOS instance (VM or native); there is no way to
  compile, lint or unit-test HolyC code on a host OS. All testing happens in-system
  (`Misc/OSTestSuite.HC`, `Demo/` corpus).
- The compiler's quirks *are* the language spec; `Doc/HolyC.DD` and the compiler source
  are authoritative (see [../07-holyc-language.md](../07-holyc-language.md)).
- For this fork: any new subsystem (e.g., networking) must be written in HolyC with no
  external dependencies, and its tests must run inside TempleOS. Porting third-party C
  code is a translation exercise, not an integration one.
