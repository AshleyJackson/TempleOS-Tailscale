# 04 — Kernel Subsystems

The kernel module (built from [`Kernel/Kernel.PRJ`](../Kernel/Kernel.PRJ)) contains the
scheduler, memory manager, block-device/filesystem layer, serial devices, multicore
support, display/text engine and a small set of system utilities. Everything runs in ring 0;
there are no drivers in the "driver" sense beyond the polled device routines below.

## Scheduler (`Kernel/Sched.HC`)

- **Cooperative round-robin**, one circular doubly-linked task queue per core, headed by
  that core's immortal executive (Adam on Core0, a Seth task on AP cores). On Core0 the
  queue order *is* the window z-order.
- A task runs until it calls `Yield()` or blocks waiting for a message/time; I/O-waiting
  tasks typically poll-and-yield loops ("this does not really degrade performance, but
  pegs the CPU Load" — author's comment in `Sched.HC`).
- Context switch = save/restore general regs + flags + FXSAVE of FPU/SSE state into the
  task's saved register file (`TASK_CONTEXT_SAVE` / `_TASK_CONTEXT_RESTORE` asm), with a
  shortcut that pushes directly onto the target task's stack. No address-map change, no
  disk I/O: **~0.5 µs** switches.
- The scheduler also handles global hotkeys: `Ctrl-Alt-X` kill task, `Ctrl-Alt-Del`
  reboot, `Ctrl-Alt-N` next task, `Ctrl-Alt-C` break execution.
- Task identity lives in the **FS segment register → current `CTask`**; core identity in
  **GS → current `CCPU`**.

## Tasks (`Kernel/KTask.HC`, `KGlbls.HC`)

- A `CTask` holds: saved registers (rax…r15, rflags), stack pointer, FPU state buffer,
  breakpoint list, code/data heap control blocks, symbol hash table, window/display flags,
  parent/child links, task name/title.
- **Adam task** = immortal root on Core0; its memory is the de-facto kernel memory
  (`ACAlloc`/`AMAlloc`/`AStrNew` allocate off it). Killing a task kills its children and
  frees its heaps.
- `Spawn()` creates tasks (optionally on another core); `PopUp()` creates helper child
  tasks with their own windows; `TaskWait()`, `Suspend()`, `Kill()` manage lifecycle.

## Jobs and messages (`Kernel/Job.HC`, `SerialDev/Message.HC`)

Five job types (`Doc/Job.DD`):

| Constant | Meaning | Posted via |
|---|---|---|
| `JOBT_TEXT_INPUT` (0) | Feed stdin text to a task | `TaskText()` |
| `JOBT_MSG` (1) | Post a message (2 I64 args, ≤63 types → bitmaskable) | `TaskMsg()` / `PostMsgWait()` |
| `JOBT_EXE_STR` (2) | Compile & execute source text in the target task | `TaskExe()` |
| `JOBT_CALL` (3) | Call a function on another core (MP work distribution) | `JobQue()` |
| `JOBT_SPAWN_TASK` (4) | Spawn a task on another core | `Spawn()` with target CPU |

`JobsHndlr()` is the pump that many system routines call to service queued jobs; results
are retrieved with `JobResGet()`. This job mechanism — not interrupts or threads — is how
applications use AP cores (see `Demo/MultiCore/`).

## Exceptions (`Kernel/KExcept.HC`)

HolyC exceptions are **char-string based**: `throw('msg')` stores the string in
`Fs->except_ch`; `catch{}` blocks inspect it and set `Fs->catch_except=TRUE` to stop the
search. The kernel installs int-fault handlers (`dbg.int_fault_code = IntFaultHndlrsNew`)
and maps CPU faults into this scheme; `Panic()` is the last-resort reporter.

## Interrupts and timers (`Kernel/KInts.HC`, `KMain.HC:TimersInit`)

- **PIC-based** (8259), not APIC, for device interrupts: IRQ0 = PIT timer, IRQ1 =
  keyboard, IRQ12 = mouse (with a polling fallback if IRQ12 never fires —
  `Doc/WhyNotMore.DD`). The **APIC is used only to start AP cores** (`MPAPICInit`,
  `Core0StartMP` in `Kernel/MultiProc.HC`).
- Timers: PIT channel 0 for the jiffy; **HPET** when present (enabled through the Intel
  LPC bridge's PCI config space, RCBA at offset 0xF0) for high-resolution time.
  `TimeCal()` calibrates against both (`Doc/TimeJiffy.DD`, `Doc/TimeHPET.DD`).

## Multicore — master/slave (`Kernel/MultiProc.HC`)

- Core0 is the **master**; AP cores run a **Seth task** that loops waiting for
  `JOBT_CALL` / `JOBT_SPAWN_TASK` jobs. The scheduler never migrates tasks between cores;
  applications explicitly target cores via `Spawn(...,target_cpu)` and `JobQue()`.
- Secondary cores are started through the APIC with a startup vector at
  `MPN_VECT = 0x97000` (see memory map in [05](05-memory-management.md)).
- Shared-state safety: LOCK-prefixed atomics exposed as `LBts()`/`LBtr()`/`LBtc()`
  (and a limited `lock{}` compiler feature). File, heap and hardware access paths have
  multicore-safe locks. Only Core0 tasks may own windows; AP cores can still help render.

## Display and text (`Kernel/Display.HC`, `FontStd.HC`, `FontCyrillic.HC`)

- One video driver: **VGA 640×480, 16 colors** (or 80×25 text mode if graphics init
  fails). The whole screen is refreshed at ~30 fps; there are no invalidation rectangles —
  the design targets full-screen games (`Doc/Strategy.DD`).
- Text and graphics are separate software layers; text sits on an 8×8 font grid. Two fonts:
  standard + Cyrillic (toggled with `Ctrl-Alt-F`), both defined in source as data
  (`FontStd.HC`, `FontCyrillic.HC`) — no external font files.
- VGA memory is accessed through the **uncached alias** (`text.vga_alias =
  dev.uncached_alias + VGAM_GRAPHICS`) to avoid cache coherency surprises; the physical
  A0000–BFFFF region is mapped write-through.

## Sound (PC speaker)

- Single voice, 8-bit signed "ona" values mapped to PC-speaker frequency/tone
  (`Doc/Snd.DD`; `Snd()` in kernel). No sound-card support by design. Music files and the
  Psalmody jukebox build on this one channel.

## PCI / BIOS services (`Kernel/PCIBIOS.HC`)

- A minimal **PCI config-space reader** (used to find HPET, locate IDE I/O ports via
  `DskATAId.HC`, enumerate devices into `dev.pci_head`). There are **no PCI device
  drivers**: no DMA, no BAR mapping beyond raw MMIO through the uncached alias. The author
  documents this as a deliberate complexity limit (`Doc/WhyNotMore.DD`) — and it is the
  primary technical constraint for any NIC work (see [12](12-networking-gap-analysis.md)).

## Utility subsystems

| Area | Files | Notes |
|---|---|---|
| Strings | `StrA.HC`, `StrB.HC`, `StrPrint.HC`, `StrScan.HC` | 8-bit ASCII (not just 7-bit); `printf`-style with extended format codes (`Doc/Print.DD`) |
| Math | `KMathA.HC`, `KMathB.HC` | F64 math, pow10 tables; all intermediate computation is 64-bit |
| Hashing | `KHashA.HC`, `KHashB.HC` | Symbol tables and general hash tables (`Doc/Hash.DD`) |
| Compression | `Compress.HC` | Transparent `.Z` file compression (whole-file oriented) |
| Debugging | `KDbg.HC`, `FunSeg.HC`, `EdLite.HC` | Breakpoints, function-segment cache, minimal editor for the raw screen (`Doc/DbgOverview.DD`) |
| Dates/times | `KDate.HC` | `CDate` packed date-time type (`Doc/TimeDate.DD`) |
| Sorting | `QSort.HC` | Quicksort used across subsystems |
