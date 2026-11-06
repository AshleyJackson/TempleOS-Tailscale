# 06 — Filesystems and Storage

## Layering

From `Doc/FileLowLevel.DD` (and the `Kernel/BlkDev/` sources):

```
File API        FOpen / FBlkRead / FBlkWrite / FileRead / FileWrite   (CFile objects)
    │
Filesystems     RedSea (native)  |  FAT32  |  ISO9660 / RedSea-on-ISO
    │
Drive layer     CDrv per drive letter; DskCache (RAM cache) in front of hardware
    │
Block devices   CBlkDev: ATA PIO hard drives · ATAPI CD/DVD · RAM disks
    │
Hardware        IDE I/O ports (1F0/3F6…), polled — no interrupts, no DMA
```

Key API surface (declared in [`Kernel/KExts.HC`](../Kernel/KExts.HC)): `FOpen`,
`FBlkRead/FBlkWrite`, `FClose`, `FileRead/FileWrite` (whole-file), `FileFind`, `Cd`,
`DirMk`, `Del`, `Drv/DrvTypeSet`, `RedSeaFmt`, `Let2BlkDev/Let2Drv`, `BlkRead/BlkWrite`.

## RedSea — the native filesystem (`Kernel/BlkDev/FileSysRedSea.HC`)

From `Doc/RedSea.DD`: a simple 64-bit filesystem, similar to FAT32 but with **absolute
block addresses instead of clusters**, **fixed 64-byte directory entries** and **no FAT
table — just an allocation bitmap**. One "cluster" is one 512-byte sector.

- **Files are stored in contiguous blocks and cannot grow.** This whole-file orientation
  is what makes transparent compression practical (`.Z` files, `Kernel/Compress.HC`).
- Directory entry: `U16 attr; U8 name[38]; I64 clus(blk); I64 size; CDate datetime;` —
  filenames are ≤ 37 chars of a restricted 8-bit ASCII set (`char_bmp_filename`).
- Boot block (`CRedSeaBoot`) uses MBR partition type **0x88** to distinguish RedSea from
  real FAT32, and carries `drv_offset`, `sects`, `root_clus`, `bitmap_sects`, `unique_id`.
- **No bad-block table, no redundant allocation table** — reliability is discussed in
  `Doc/Reliability.DD` (the trade: simplicity over journaling).

## FAT32 and ISO9660

- `FileSysFAT.HC` (~974 lines) provides read/write FAT32 so TempleOS can share partitions
  with other OSes. The author's stated end-game is to delete it entirely if Windows/Linux
  would mount RedSea instead (`Doc/Demands.DD`).
- CD/DVD images are **RedSea laid over ISO9660/EL TORITO** ("RedSea-on-ISO"): a measured
  hard-drive partition image is copied onto the disc starting at ~sector 20, with 512-byte
  sectors placed four-per-2048-byte CD sector (`Adam/Opt/Boot/DskISORedSea.HC`,
  `DskISO9660.HC`). Bootable ISOs are produced by `RedSeaISO()` (used by
  [`Misc/DoDistro.HC`](../Misc/DoDistro.HC)).

## Block devices and drive letters

- One driver per device class, all **polled PIO** — "Disk code does not use interrupts,
  avoiding compatibility risks" (`Doc/Strategy.DD`):
  - `DskATA.HC` — ATA/SATA hard drives on IDE ports (1F0/3F6 primary/secondary);
    `DskATAId.HC` (~286 lines) locates the I/O ports via PCI config-space scanning when
    they aren't at the defaults.
  - `DskCDDVD.HC` — ATAPI CD/DVD (RedSea images only).
  - RAM disks for letters A–B.
- **Drive-letter allocation is fixed by class** (`Doc/Glossary.DD`) — relevant when adding
  new device types:

| Letters | Class |
|---|---|
| `:` / `~` | boot drive / home drive (aliases) |
| A–B | RAM drives |
| C–L | ATA hard drives |
| M–P | ISO file *read* drives |
| Q–S | ISO file *write* drives |
| T–Z | ATAPI CD/DVD drives |

  There is currently **no class for network devices** — a design point for the networking
  work ([12](12-networking-gap-analysis.md)).
- `DskCache.HC` keeps a RAM cache in front of each drive; its size is a kernel compile-time
  option (`kernel_cfg->dsk_cache_size_exp`, emitted into the boot stream by `KMain()`'s
  `#exe{}` block).

## Conventions for file work

- Whole-file reads/writes are the norm (`FileRead`/`FileWrite`); streaming is possible via
  `CFile` but uncommon.
- `.Z` suffix = transparently compressed; `.C` suffix = contiguous (uncompressed) variant;
  `.DD` documents, `.HC` source, `.PRJ` AOT build lists, `.BIN(.C)` binaries — see the
  extension table in `Doc/Glossary.DD`.
- `~` is a special directory designator for the home drive (`HomeSet()`).
