# 11 — Build, Test, and Distribution

## Building

**There is no external toolchain.** HolyC compiles only inside TempleOS itself; the
"build system" is a set of in-OS scripts. (See [08](08-compiler-toolchain.md) for the
pipeline.)

| What | How |
|---|---|
| Kernel module + compiler binary | `BootHDIns()` → `MakeAll()` AOT-compiles [`Kernel/Kernel.PRJ`](../Kernel/Kernel.PRJ) and [`Compiler/Compiler.PRJ`](../Compiler/Compiler.PRJ), then re-patches the boot sector with the new kernel's LBA. This is the only "release build" that exists |
| Everything else (apps, tools, your new code) | JIT: `#include` it from a task, or `ExeFile()` it from a program. No build step, no artifacts |
| Fast kernel iteration | `RAMReboot()` (`Adam/Opt/Boot/BootRAM.HC`) — soft reboot without hardware reset, for when you're changing the kernel module or startup scripts |
| Compile-time configuration | `#exe{}` blocks in `.PRJ` files + `KCfg.HC` options (mount letters, disk cache size, `CFG_NO_MP`, debug-distro flags) |

### Running TempleOS to develop against this tree

1. Boot the V5.03 ISO (or a distro you built with `DoDistro`) in QEMU/VMware/VirtualBox —
   legacy BIOS mode, ≥ 512 MB RAM, IDE disk + CD/DVD exposed as PIO ports (`ReadMe.TXT`,
   `Doc/Requirements.DD`). If the drive I/O ports aren't at defaults, locate them with
   `lspci -v` (Linux) or Windows System Info and enter them at boot.
2. To try changes from this repository: copy the modified `.HC` files into the running
   system's tree (e.g., via a mounted ISO-file drive, letters M–S) and `#include` them —
   JIT picks up your code immediately.
3. Kernel-module changes require the full `BootHDIns()` rebuild + boot-sector re-patch
   cycle; use `RAMReboot()` to apply without a power cycle.

## Testing

- **`Misc/OSTestSuite.HC`** is the system test suite: 171 numbered steps (`progress4_max=171`)
  that exercise the OS end-to-end — it runs demo files in user tasks (`TSFile()` includes a
  file, waits for task death), sends keystrokes (`TSFileChar()`), and reports progress via
  the system progress bars. It is the closest thing to CI this project has; run it after
  any kernel-level change.
- The `Demo/` corpus *is* the regression test set (see [10](10-demos-and-lectures.md)).
  House pattern for new features: write a small demo that exercises them, then add it to
  the suite.
- In-system debugging tools: breakpoints + raw debugger (`Doc/DbgOverview.DD`), `MemRep`,
  `TaskRep`, `CPURep`, `Profiler`, `HeapLog`, `Trace`/`PassTrace` for compiler output.

## Distribution artifacts

| Artifact | Producer | Notes |
|---|---|---|
| Bootable CD/DVD ISO (RedSea-on-ISO, EL TORITO) | [`Misc/DoDistro.HC`](../Misc/DoDistro.HC) `MakeMyISO()` — copies all top-level dirs into `/Distro`, runs `BootDVDIns()`, then `RedSeaISO()`; optional burn via `DVDImageWrite('T', …, MT_DVD)` | The supported way to make a custom distro from a running system |
| Hard-disk install | [`Misc/OSInstall.HC`](../Misc/OSInstall.HC) + `Adam/Opt/Boot` installers (`BootHDIns`, `BootMHDIns`) | Partitioner is `DskPrt` in `Adam/ABlkDev` |
| `/0000Boot/0000Kernel.BIN.C` | `BootDVDIns()` | C-encoded kernel binary consumed by the CD boot path (a checked-in copy lives in this repo) |
| **TOSZ** — TempleOS-Zip for Linux | [`Linux/TOSZ.CPP`](../Linux/) (+ copies under `Downloads/Linux/`) | A C++ tool that runs on *Linux* to unpack TempleOS `.Z` files; used e.g. to extract screencast data from GR/AU files exported by TempleOS. Also ships God word-list data (`GodWords`, `GodPassage`) for Linux-side use |

## Working in this fork (git)

- The branch is `god`; upstream history is a series of V5.03 nightly snapshots plus one
  Feb 2020 fix commit ("Fix corrupted Compiler.BIN…"). Treat the tree as an immutable
  baseline until Tailscale work lands.
- Suggested discipline for new work (see [12](12-networking-gap-analysis.md) for layout):
  keep upstream files untouched where possible, add new subsystems in their own directory
  (e.g., `Kernel/Net/`), and record each architectural choice as an ADR under
  [`adr/`](adr/README.md).
