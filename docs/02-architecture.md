# 02 — System Architecture

TempleOS is a **monolithic, ring-0-only, single-address-space** operating system for
x86_64 PCs. There is no user/kernel boundary, no virtual memory per process, and no
linker: the OS, its compiler, and every application share one identity-mapped address
space and one privilege level. The design philosophy (from `Doc/Strategy.DD`) is a
deliberate *reduction* of complexity — "a kayak, not a Titanic" — with a hard 100k-line
budget for the whole system.

## High-level view

```mermaid
flowchart TB
    subgraph HW["Hardware (least-common-denominator set)"]
        VGA["VGA 640x480 16-color<br/>(A0000-BFFFF, write-through)"]
        KBD["PS/2 keyboard + mouse<br/>(IRQ1 / IRQ12 or poll)"]
        ATA["ATA/SATA PIO disk ports<br/>(polled, no interrupts)"]
        ATAPI["ATAPI CD/DVD (PIO)"]
        SPK["PC speaker (8-bit single voice)"]
        PIT["PIT + HPET timers"]
    end

    subgraph BOOT["Boot chain (see 03-boot-process.md)"]
        BIOS["BIOS"] --> BS["Boot sector<br/>BootDVD / BootMHD(2) / BootHD"]
        BS --> K16["Kernel.BIN.C @ 0x7C00<br/>(16-bit real mode, < 640K)"]
        K16 --> K32["32-bit protected mode<br/>page tables built (identity map)"]
        K32 --> K64["Long mode entry<br/>(KStart64.HC: CR4.PAE, EFER.LME, far jump)"]
    end

    subgraph KERNEL["Kernel module (AOT-compiled, Kernel.PRJ)"]
        KM["KMain()<br/>SysGlblsInit, TimersInit, IntsInit,<br/>BlkDevsInitAll, KbdMsInit"]
        SCHED["Sched.HC — cooperative round-robin<br/>per-core task queues (Seth/Adam head)"]
        MEM["Mem/ — MAlloc/Free, BlkPool,<br/>PageTables, HeapCtrl"]
        BLK["BlkDev/ — DskATA, DskCDDVD,<br/>RedSea / FAT32 / ISO9660, DskCache"]
        SER["SerialDev/ — Keyboard, Mouse, Message"]
        MP["MultiProc.HC — master/slave cores,<br/>APIC startup, LOCK-prefixed atomics"]
        INTS["KInts.HC — PIC handlers (IRQ0/1/12)"]
    end

    subgraph TOOLCHAIN["Toolchain (loaded at boot, JIT for everything else)"]
        CMP["Compiler.BIN<br/>HolyC compiler + x86_64 assembler"]
        ADAM["Adam task (immortal)<br/>runs StartOS.HC → MakeAdam → WinMgrTask,<br/>registry, wallpaper, ~/MakeHome → server mode"]
    end

    subgraph APPS["Applications (JIT-compiled into code heap)"]
        HOME["/Home — user account shell"]
        DOLDOC["DolDoc editor/browser<br/>(command line = source = docs = dialogs)"]
        GOD["God, Psalmody, games…<br/>(see 09-applications-and-tools.md)"]
    end

    K64 --> KM
    KM --> SCHED & MEM & BLK & SER & MP & INTS
    KM -->|Load("Compiler")| CMP
    KM -->|ExeFile("StartOS")| ADAM
    ADAM --> HOME & DOLDOC & GOD
    HW -.-> KERNEL
```

## The task model: "multi-thread / single-process"

- There is **no distinction between thread, process and task** (`Doc/Glossary.DD`).
  A *task* = saved register file + stack + code heap + data heap + symbol table.
- The CPU's **FS segment register always points at the current task's `CTask`**;
  **GS points at the current core's `CCPU`**. This makes per-task state a one-register
  lookup and is why context switches are ~half a microsecond (save/restore regs + FXSAVE,
  no address-map change — see `Kernel/Sched.HC`).
- The **Adam task** on Core0 is the immortal parent of all tasks; its heap holds
  system-wide ("kernel-like") memory. Each AP core has an immortal **Seth task** that
  idles waiting for jobs (`CoreAPSethTask` in `Kernel/MultiProc.HC`).
- Only Core0 tasks may have windows (640×480 is one screen; the window manager composites
  per-task text/graphics layers). Child tasks exist for pop-ups and helpers.
- **Scoping without namespaces:** every task has a hash symbol table; name lookup walks
  up the parent chain to Adam's table, which holds all API symbols. No `#include` of
  headers is ever required (`Doc/Strategy.DD`, `Doc/Glossary.DD`).

## Scheduling and multicore

- **Cooperative round-robin** per core: a task runs until it calls `Yield()` (or blocks
  on a message/time). The scheduler walks the circular queue, skipping tasks that are not
  ready. It is explicitly *not* preemptive (`Doc/Strategy.DD`: "The Scheduler is for home
  systems… wonderfully simple").
- **Master/slave multicore**, not SMP: Core0 (master) owns all windows and launches apps;
  AP cores only run what applications explicitly `Spawn()` or `JobQue()` to them. The
  scheduler never migrates tasks between cores (`Doc/MultiCore.DD`).
- Multicore safety comes from **LOCK-prefixed instructions** exposed as `LBts/LBtr/LBtc`
  (and a shaky `lock{}` compiler feature). File, heap and hardware access have multicore-safe locks.

## Communication primitives

- **Jobs** (`Kernel/Job.HC`): five kinds — text input, message, execute-source-string,
  call-function, spawn-task. `JobQue()` posts to any core's Seth task; `JobResGet()`
  retrieves results. This is the work-distribution API for AP cores.
- **Messages** (`Kernel/SerialDev/Message.HC`): up to 63 message types (a bitmask can be
  passed), each with two I64 args; tasks block on `TaskWait()`.
- **Exceptions:** HolyC `try/catch/throw` where `throw()` carries a small char string
  (`Fs->except_ch`) — used for control flow and error reporting alike.

## Storage stack (summary)

```
File API: FOpen / FBlkRead / FBlkWrite / FileRead / FileWrite   (Kernel/BlkDev/DskFile.HC, DskStrA/B.HC)
    │  whole-file oriented; .Z files transparently compressed (Kernel/Compress.HC)
FileSystem: RedSea (native, MBR type 0x88) | FAT32 | ISO9660 / RedSea-on-ISO   (FileSys*.HC)
    │  contiguous allocation only → enables compression; no bad-block table
Block device: CBlkDev per drive letter; ATA PIO polled driver + ATAPI CD/DVD   (DskATA.HC, DskCDDVD.HC)
    │  disk cache in RAM (DskCache.HC); drive letters A–Z partitioned by class (see 06)
Hardware: IDE I/O ports 1F0/3F6 etc. — located manually or via PCI config scan (DskATAId.HC, PCIBIOS.HC)
```

## Toolchain and code layout

- The **compiler is part of the OS**: `KMain()` loads `/Compiler/Compiler.BIN` before
  running anything else (`Kernel/KMain.HC`). From then on, *everything* — user programs,
  scripts, songs, automations — is HolyC source compiled **JIT** into the code heap.
- Only two artifacts are AOT-compiled to `.BIN`: the kernel module and the compiler itself
  (both from `.PRJ` file lists; there is no linker and no object files). See
  [08-compiler-toolchain.md](08-compiler-toolchain.md).
- **Code heap vs data heap:** all code lives in the lowest 2 GiB because the compiler
  emits only 32-bit relative `CALL/JMP`; data (heap allocations) lives above, up to RAM.
  See [05-memory-management.md](05-memory-management.md).

## What is deliberately absent

Per `Doc/Strategy.DD`, `Doc/Requirements.DD` and `Doc/WhyNotMore.DD`: no networking, no
USB (beyond legacy PS/2), no sound cards, no GPU acceleration, no AHCI/DMA disk access,
no UEFI, no security/cryptography, no file permissions. Each absence is a conscious
complexity trade — and each is a gap that the Tailscale effort must consciously re-open
(see [12-networking-gap-analysis.md](12-networking-gap-analysis.md) and ADR-0005/0006).
