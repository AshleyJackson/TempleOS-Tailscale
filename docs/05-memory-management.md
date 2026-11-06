# 05 — Memory Management

TempleOS's memory model is the single most important architectural fact for anyone adding
new subsystems: **there is one identity-mapped address space, shared by every task on
every core, with no paging in any practical sense and no swap.** The authoritative
description is `Doc/MemOverview.DD` (written by the author); this page summarizes it and
maps it to source.

## Design rationale (from `Doc/MemOverview.DD`, 2003 origin)

- Long mode *requires* paging, so TempleOS uses the next best thing: an **identity map**
  (virtual == physical). No address-map changes on task switch → ~0.5 µs switches and no
  TLB shootdowns.
- All code is kept in the **lowest 2 GiB** because the compiler emits only signed 32-bit
  relative `JMP`/`CALL`; any two code locations must be within ±2 GiB of each other.
- Hardware access needs uncached memory, so the first 4 GiB are **double-mapped**: a
  cached identity map plus an **uncached alias at `0x01AA000000`** (`dev.uncached_alias`,
  built by `UncachedAliasAlloc()`).

## System-wide memory map

| Range | Contents |
|---|---|
| `0x00007C00 – 0x00036AEF` | Kernel module, placed here by the boot loader (`BOOT_RAM_BASE`) |
| `0x00096600 – 0x00096FFF` | Boot block relocated here before loading the kernel module |
| `0x00097000 – 0x00097030` | Multicore start-up vector code (`MPN_VECT`) |
| `~0x0009F000 – 0x0009FFFF` | Extended BIOS data area |
| `0x000A0000 – 0x000BFFFF` | VGA graphics memory (write-through; alias at `text.vga_alias`) |
| `0x00100000 – 0x00101FFF` | `CSysFixedArea` — fixed misc area (CPU structs, Adam task/heap init) |
| `0x0010F000 – 0x7FFFFFFF` | **Code heap** (all code + compiler-allocated globals) |
| `0x80000000 – ~0xDFFFFFFF`, `0x100000000 – ~0x1A9FFFFFF` | **Data heap** (physical RAM in this range) |
| `0x01AA000000 – 0x02A9FFFFFF` | Uncached alias of the first 4 GiB (`dev.uncached_alias`) — for hardware access; 64-bit device allocations count downward from here via `Mem64DevAlloc()` (no PCI devices are actually supported) |

Page-table layout: 1 GiB pages where supported, 2 MiB fallback; the lowest 2 MiB uses
4 KiB write-through pages because VGA must be write-through. Note that since the 2016
uncached-alias change, dereferencing NULL no longer faults (the author calls this an
unfortunate loss of simplicity).

## Allocation: block pools and heaps (`Kernel/Mem/`)

| File | Role |
|---|---|
| `BlkPool.HC` | Power-of-two **block pools** backing all allocation; a known break exists in the data-heap pool (only affects contiguous-request fragmentation — "I can MAlloc an 8Gig chunk on my 12Gig machine") |
| `MAllocFree.HC` | `MAlloc()`/`Free()` (+ `CAlloc`, `AStrNew`, …); large allocations round up to a power of two; `MSize()` reports the real size; `Free(NULL)` is safe |
| `HeapCtrl.HC` | `CHeapCtrl` — independent heaps via `HeapCtrlInit()`; per-task heaps are instances of this |
| `PageTables.HC` | Identity-map construction (1 GiB / 2 MiB), uncached alias setup |
| `MemPag.HC`, `MemPhysical.HC` | Page-level and physical-memory bookkeeping (`Scale2Mem` etc.) |

Rules that matter for new code:

- **Every task has a code heap and a data heap**; memory allocated by a task is freed when
  the task dies. The immortal Adam task's heap is where system-wide objects live
  (`ACAlloc`, `AMAlloc`, `AStrNew`). You may allocate from *any* task's heap or an
  independent `CHeapCtrl` at any time, on any core.
- **Stacks do not grow** (no virtual memory). Default stack size is the kernel compile-time
  constant `MEM_DFT_STK`; larger stacks can be requested per `Spawn()`. Allocate big local
  arrays from the heap instead (`Doc/HolyC.DD`).
- On systems with < 2 GiB RAM, code and data pools are unified; on 2–4 GiB machines the
  code heap is a quarter of total (`BlkPoolsInit()`).
- Fragmentation over long sessions is acknowledged in theory but "has never happened" to
  the author.

## Implications for new subsystems (e.g., networking)

1. **No per-task isolation** — any bug can clobber any other task's memory; defensive
   bounds-checking matters more than here than in a paged OS.
2. **Code must fit in the low 2 GiB.** A network stack + crypto written in HolyC will be
   JIT/AOT-compiled into the code heap like everything else — no special handling needed,
   but keep an eye on total code size against the 100k-line budget philosophy.
3. **NIC MMIO** (PCI BARs in the low 4 GiB) is reachable through `dev.uncached_alias` —
   this is the mechanism a PIO/MMIO NIC driver would use, since there are no PCI DMA or
   BAR-mapping helpers today (`Kernel/PCIBIOS.HC` only does config-space reads).
4. **Buffers for packets** should come from a dedicated `HeapCtrlInit()` heap (or Adam's
   heap if immortal) so that killing the network task doesn't strand in-flight buffers —
   or, conversely, deliberately uses task-death cleanup.
