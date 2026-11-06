# 03 — Boot Process

TempleOS boots **only through legacy BIOS** (no UEFI support by design — `Doc/Boot.DD`,
`Doc/WhyNotMore.DD`). The whole chain is: BIOS → hand-written boot sector → a small
AOT-compiled "kernel module" that fits in 640 KB → mode switches to long mode → `KMain()`
→ load the compiler → run `StartOS.HC`.

## Stage overview

```mermaid
sequenceDiagram
    participant PWR as Power/Reset
    participant BIOS as BIOS
    participant BS as Boot sector (16-bit asm)
    participant KMOD as Kernel.BIN.C @ 0x7C00
    participant K64 as KStart64.HC (long mode entry)
    participant KM as KMain() [Kernel/KMain.HC]
    participant CMP as /Compiler/Compiler.BIN
    participant ADAM as Adam task

    PWR->>BIOS: POST, boot order
    BIOS->>BS: load sector 0 (CD EL TORITO / MBR / partition)
    BS->>KMOD: load kernel module to BOOT_RAM_BASE=0x7C00 (<640K budget)
    KMOD->>KMOD: 16-bit real mode → 32-bit protected, build identity page tables
    KMOD->>K64: SYS_ENTER_LONG_MODE (CR4.PAE|PSE, CR3=PML4, EFER.LME, CR0.PG, far jump cs64)
    K64->>KM: CPUStructInit, Adam HeapCtrl + TaskInit, FS/GS bases set, JMP &KMain
    KM->>KM: BlkPoolsInit, SysGlblsInit, TimersInit (PIT+HPET), IntsInit, BlkDevsInitAll
    KM->>KM: multicore start (Core0StartMP) unless CFG_NO_MP; kbd/mouse init
    KM->>CMP: Load("Compiler")  → RLf_COMPILER
    KM->>ADAM: ExeFile("StartOS") — JIT-compiles /StartOS.HC into Adam's memory
    ADAM->>ADAM: MakeAdam, WinMgrTask, RegInit, wallpaper, ~/MakeHome
    ADAM-->>KM: SrvTaskCont (never returns; Adam in server mode)
```

## The boot sectors (`Adam/Opt/Boot/`)

All boot code is hand-written assembly kept tiny enough for one sector/block. They do not
read directories — they are **patched with the LBA** of the files to load, so updating the
kernel means recompiling *and* re-patching in one step (the `*Ins` installers).

| File | Role |
|---|---|
| `BootDVD.HC` | CD/DVD boot sector ("TempleOS CD-ROM Boot Loader"); ISOs are made RedSea-on-ISO with EL TORITO (`DskISORedSea.HC`) |
| `BootDVDIns.HC` | Prepares a CD install: creates `/0000Boot/0000Kernel.BIN.C` (the kernel binary in C-encoded form) |
| `BootMHD.HC` / `BootMHD2.HC` | Master-HD stage 1 (block zero) + stage 2. Unusually, stage 2 is stored *as a file* (`/0000Boot/BootMHD2.BIN.C`) inside a partition; it shows a menu and boots a chosen partition |
| `BootMHDIns.HC` | Installs the master boot loader |
| `BootHD.HC` / `BootHDIns.HC` | Per-partition boot record (first block of the partition) + installer. `BootHDIns()` calls `MakeAll()`, which AOT-compiles `/Kernel/Kernel.PRJ` → `Kernel.BIN.C` and `/Compiler/Compiler.PRJ` → `Compiler.BIN`, then patches the boot sector with the new LBAs |
| `BootRAM.HC` | **Soft reboot** (`RAMReboot()`): copies a small trampoline high in RAM and reboots without a hardware reset — used when iterating on kernel/startup scripts |

The checked-in artifact [`0000Boot/0000Kernel.BIN.C`](../0000Boot/) is an example of the
C-encoded kernel binary produced by `BootDVDIns`.

## The kernel module and mode switches

- The boot sector loads **`Kernel.BIN.C`** to `BOOT_RAM_BASE = 0x7C00`. It must stay under
  640 KB because it runs in 16-bit real mode (`Doc/Boot.DD`).
- In 32-bit protected mode the kernel builds its page tables: an **identity map** of all
  RAM using 1 GiB (or 2 MiB fallback) pages, with the lowest 2 MiB as 4 KiB write-through
  pages for VGA and an uncached alias of the first 4 GiB at `0x01AA000000`
  (`Kernel/Mem/PageTables.HC`, `UncachedAliasAlloc`; history in `Doc/MemOverview.DD`).
- Long mode entry is `SYS_ENTER_LONG_MODE` in [`Kernel/KStart64.HC`](../Kernel/KStart64.HC):
  set `CR4.PAE|PSE`, load PML4 into CR3, set `EFER.LME`, enable paging via CR0, then a far
  jump to the 64-bit code segment. After that: CPU struct init for Core0 (GS base), Adam's
  heap control block and task are initialized in the fixed area at `SYS_FIXED_AREA`
  (`0x100000–0x101FFF`), FS is pointed at the Adam `CTask`, and control jumps to `KMain`.

## `KMain()` — kernel bring-up sequence

From [`Kernel/KMain.HC`](../Kernel/KMain.HC) (order matters; run-level flags are set as
each milestone completes):

1. Mute PC speaker; `BlkPoolsInit` (memory block pools), `SysGlblsInit` (CPUID cache-line
   width, macro queue, bit tables, extension table, key device init).
2. `Mem32DevInit`, `UncachedAliasAlloc`, `LoadKernel`.
3. `SysGrInit` — VGA setup: 80×25 text mode or 640×480 16-color graphics; sets up the
   uncached alias pointers (`text.vga_alias`).
4. Create the **Adam task** ("Adam Task CPU00"), load user defines, `Core0Init`, `IntInit1`.
5. Print banner "TempleOS V%5.3f"; `TimersInit` — PIT period + HPET enable (HPET located
   via PCI config space of the Intel LPC bridge); verify ≥ 512 MB RAM or warn.
6. `IntsInit` — install PIC handlers and **enable IRQs** (`RLf_INTERRUPTS`).
7. `TimeCal`, `BlkDevsInitAll`, mount boot drive `DskChg(':')` (`RLf_BLKDEV`).
8. Start multicore: `Core0StartMP` unless the compile-time option `CFG_NO_MP` is set
   (`RLf_MP`). Kernel build options come from `KCfg.HC`, injected at AOT time via `#exe{}`
   blocks in [`Kernel/Kernel.PRJ`](../Kernel/Kernel.PRJ).
9. Keyboard/mouse init; spawn the mouse hard-driver task.
10. **`Load("Compiler")`** — load `/Compiler/Compiler.BIN` (`RLf_COMPILER`). From this point
    HolyC source can be compiled and run.
11. `ExeFile("StartOS")` — JIT-compile and execute [`StartOS.HC`](../StartOS.HC) in the
    Adam task; on exception, drop to the raw debugger.
12. `SrvTaskCont` — Adam enters server mode (never returns).

### Run-level flags (`sys_run_level`)

Set progressively during boot (names from `Doc/Boot.DD`): `RLf_16BIT`, `RLf_VGA`,
`RLf_32BIT`, `RLf_PATCHED`, `RLf_16MEG_SYS_CODE_BP`, `RLf_64BIT`,
`RLf_16MEG_ADAM_HEAP_CTRL`, `RLf_FULL_HEAPS`, `RLf_RAW`, `RLf_INTERRUPTS`,
`RLf_BLKDEV`, `RLf_MP`, `RLf_COMPILER`, `RLf_DOC`, `RLf_WINMGR`, `RLf_REGISTRY`,
`RLf_HOME`, `RLf_AUTO_COMPLETE`, `RLf_ADAM_SERVER`, `RLf_ONCE_ADAM`, `RLf_ONCE_USER`.

## After the kernel: `StartOS.HC`

[`StartOS.HC`](../StartOS.HC) is executed by the Adam task and brings up the user system:

1. Includes the kernel/compiler headers, enables warning options, purges Adam's hash table.
2. `#include "/Adam/MakeAdam"` — compiles **all of `/Adam`** (DolDoc editor, Gr library,
   God app, boot tools, utilities…) into immortal memory; creates the document terminal
   (`DocTermNew`) and window layout.
3. Spawns the **Window Manager task**; initializes the registry (`RegInit`, `RLf_REGISTRY`);
   handles install registration; sets the wallpaper; ensures `/Tmp` exists.
4. `#include "~/MakeHome"` — compiles the user's **Home** account (the root-level
   `Home*.HC` files in this repo) and runs its startup (`RLf_HOME`).
5. Adam then sits in server mode, accepting jobs from other tasks.

## Booting from media vs disk

- **CD/DVD:** ISO is a RedSea filesystem image laid over 2048-byte CD sectors with EL
  TORITO boot records; `BootDVD` loads the kernel module. Custom distros are built with
  [`Misc/DoDistro.HC`](../Misc/DoDistro.HC) (`MakeMyISO`).
- **Hard disk:** either a partition's own boot record (`BootHD`) or the two-stage MBR
  (`BootMHD` + menu-driven `BootMHD2`). Install flow: [`Misc/OSInstall.HC`](../Misc/OSInstall.HC).
- **Virtual machines** (QEMU/VMware/VirtualBox) are the author's recommended environment;
  BIOS must expose legacy PS/2 and IDE PIO ports (`Doc/WhyNotMore.DD`, `ReadMe.TXT`).
