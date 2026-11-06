# 01 — Project Overview

## What this repository is

- **Upstream content:** a complete source snapshot of **TempleOS V5.03**, an x86_64
  operating system written by Terry Davis (in-universe "Adam") in **HolyC** and assembly.
  TempleOS is public domain / 100% open source; the author's own words: *"TempleOS is
  100% open source with all source present"* (`ReadMe.TXT`).
- **This fork:** named `TempleOS-Tailscale` because its purpose is to add
  **Tailscale/WireGuard networking** to an OS that was deliberately designed *without*
  any networking (see [ADR-0005](adr/0005-no-networking-baseline.md) and
  [ADR-0006](adr/0006-tailscale-integration-strategy.md)). As of this writing, **no
  Tailscale code exists in the tree yet** — it is a pristine baseline. The networking
  gap analysis and work breakdown are in [12-networking-gap-analysis.md](12-networking-gap-analysis.md).

## Key facts about the upstream system

| Property | Value / note |
|---|---|
| Version | V5.03 (released 2017-03-14 per `Doc/ChgLog.DD`); tree = Nov 2017 nightly + Feb 2020 fix (`git log`) |
| Author | Terry Davis, single author; ~82k lines of code at the time (self-reported in `Doc/WhyNotMore.DD`), with a hard self-imposed **100,000-line cap** (`Doc/Strategy.DD`) |
| Language | HolyC (nonstandard C dialect) + x86/x86_64 asm; compiles only inside TempleOS itself |
| Architecture | x86_64 ("long mode") **only**; no 32-bit support at runtime |
| Boot | Legacy BIOS only — explicitly **no UEFI** (`Doc/Boot.DD`, `Doc/WhyNotMore.DD`) |
| Privilege | Ring-0 for everything; no user/kernel boundary, no memory protection between tasks |
| Memory model | Single identity-mapped address space shared by all tasks on all cores (see [05](05-memory-management.md)) |
| Scheduler | Cooperative, non-preemptive round-robin per core (~0.5 µs context switch) |
| Multicore | Master/slave: Core0 is master; AP cores run "Seth" executive tasks that execute queued jobs |
| Display | 640×480, 16-color VGA only (declared a permanent design covenant by the author) |
| Storage | ATA/SATA PIO hard drives + ATAPI CD/DVD, polled (no interrupts); RedSea native FS, FAT32, ISO9660 |
| Input | PS/2 keyboard & mouse (legacy mode), no USB |
| Sound | Internal PC speaker only; single-voice 8-bit samples |
| Networking | **None** — an explicit design decision of the original OS |
| Minimum RAM | 512 MB (`ReadMe.TXT`, `Doc/Requirements.DD`) |
| Typical use | Runs inside QEMU / VMware / VirtualBox; native installs are discouraged by the author |

## The Tailscale goal (this fork)

The intended end state is a TempleOS node that can join a **Tailscale tailnet**. Because
upstream TempleOS has no NIC driver, no IP stack and no crypto, this requires building:

1. A network interface card driver (PCI MMIO/PIO class),
2. An Ethernet/ARP/IP/UDP stack,
3. A WireGuard implementation in HolyC,
4. Tailnet membership (see the strategy decision in [ADR-0006](adr/0006-tailscale-integration-strategy.md)).

Everything else in this repository is context: understanding how TempleOS boots, schedules
tasks, allocates memory and stores files determines *how* those four pieces must be built.

## Top-level directory map

```
TempleOS-Tailscale/
├── 0000Boot/            # Boot artifacts (e.g. 0000Kernel.BIN.C — C-encoding of the kernel binary)
├── Adam/                # "Adam's" personal tools & libraries: DolDoc editor, God app, Gr/SpriteEd,
│   ├── ABlkDev/         #   disk utilities (partitioner, chkdsk, file manager)
│   ├── AutoComplete/    #   jump-to-source autocomplete tool + dictionary generator
│   ├── Ctrls/           #   UI widgets (buttons, sliders)
│   ├── DolDoc/          #   the document editor/browser engine (~30 files)
│   ├── God/             #   Bible search app ("God")
│   ├── Gr/              #   2D/3D graphics library + sprite & mesh editors
│   ├── Opt/Boot/        #   ALL boot loaders: BootDVD, BootMHD(2), BootHD, BootRAM, ISO tools
│   ├── Opt/Utils/       #   Diff, Profiler, MemRep, ToTXT, TOS installer helpers…
│   └── Snd/             #   music/sound file support
├── Apps/                # Shipped applications (12): Budget, GrModels, KeepAway, Logic, Psalmody,
│                        #   Span, Strut, TimeClock, Titanium, ToTheFront, Vocabulary, X-Caliber
├── Compiler/            # The HolyC compiler + x86_64 assembler (~37 files) — itself written in HolyC
├── Demo/                # ~220 demo programs: games, graphics, lectures, templates, multicore examples
├── Doc/                 # Author's documentation as .DD (DolDoc) files + Comm.HC
├── Downloads/           # ReadMe.TXT + Linux-side TOSZ tool copies
├── Kernel/              # The kernel (~78 files): boot stages, scheduler, memory, block devices,
│   ├── BlkDev/          #   ATA/ATAPI drivers, RedSea/FAT32/ISO filesystems, disk cache
│   ├── Mem/             #   MAlloc/Free, page tables, block pools, heap control
│   └── SerialDev/       #   keyboard, mouse, message queue
├── Linux/               # TOSZ.CPP — TempleOS-Zip utility for Linux; God word-list data files
├── Misc/                # DoDistro (custom ISO builder), OSInstall, OSTestSuite (171 tests),
│                        #   PCIDevices.DD database, Tour scripts
├── HomeKeyPlugIns.HC    # Root-level HolyC sources: the "Home" app (user account shell) and
├── HomeLocalize.HC      #   its startup scripts — compiled into the Adam task at boot
├── HomeSys.HC           #
├── HomeWrappers.HC      #
├── MakeHome.HC          # Build script for /Home (included by StartOS.HC)
├── Once.HC              # "Once" run-once automation support
├── PersonalMenu.DD      # Author's personal menu/docs
├── PersonalNotes.DD     # Author's notes
├── ReadMe.TXT           # Upstream readme (boot instructions, requirements)
└── StartOS.HC           # The boot script the Adam task executes after loading the compiler
```

## Conventions used in this documentation set

- File paths are relative to the repository root.
- "Upstream" = unmodified TempleOS V5.03 content; anything new for Tailscale will be
  documented as it lands (see [12](12-networking-gap-analysis.md) for the proposed layout).
- ADRs follow the format in [`adr/README.md`](adr/README.md); statuses are
  **Accepted** (embodied in code), **Proposed** (under consideration), or **Superseded**.
