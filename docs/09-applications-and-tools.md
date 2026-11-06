# 09 — Applications and Developer Tools

## Shipped applications (`Apps/`)

Each app is a directory of HolyC sources with the usual `Load.HC` / `Run.HC` /
`Install.HC` trio (install registers it, load compiles it on demand). All are JIT-compiled
at runtime; none require external resources — graphics and data live in source.

| App | What it is |
|---|---|
| **Budget** (`Apps/Budget/`) | Personal budgeting: accounts, entries, templates, string-file driven categories (`BgtAccts`, `BgtEntry`, `BgtTemplate`…) |
| **GrModels** (`Apps/GrModels/`) | 3D mesh *generators* (sphere `BallGen`, humanoid `ManGen`) — the generated meshes are cut-and-pasted into other apps like KeepAway |
| **KeepAway** (`Apps/KeepAway/`) | Arcade ball-vs-players game using GrModels meshes; has AI opponents and scoring |
| **Logic** (`Apps/Logic/`) | Digital logic-gate circuit designer/simulator: gate tables, multi-input gates, iterative "passes" to resolve outputs |
| **Psalmody** (`Apps/Psalmody/`) | Hymn/psalm music player with jukebox, song "puppets" (per-song animation tasks), tempo controls and example songs with graphics |
| **Span** (`Apps/Span/`) | Bridge/span physics: builds spring-mass structures and simulates them with the real-time ODE solver (`CMathODE`, adaptive Runge-Kutta) |
| **Strut** (`Apps/Strut/`) | Interactive mass-spring structure toy (Edit/Play modes, starfield backdrop), also on the `CMass`/`CSpring` physics core |
| **TimeClock** (`Apps/TimeClock/`) | Time-clock applet: punch in/out events persisted to a data file |
| **Titanium** (`Apps/Titanium/`) | Space shooter (renamed from "TimeOut", Nov 2016); large scrolling map, best score kept in the registry |
| **ToTheFront** (`Apps/ToTheFront/`) | Hex-grid tactical tank battle: terrain movement costs, line-of-sight, human + simple AI players (`AIs/Human.HC`, `AIs/SimpleAI.HC`) |
| **Vocabulary** (`Apps/Vocabulary/`) | Vocabulary quiz with random word selection |
| **X-Caliber** (`Apps/X-Caliber/`) | Space shooter with laser heat management, anti-spin and solar-storm hazards; best score in registry |

## The "Adam" toolset (`Adam/`)

This is the developer environment — compiled into immortal memory at boot by
`StartOS.HC → /Adam/MakeAdam`. It is where most of the system's user-facing capability lives.

| Area | Files | Purpose |
|---|---|---|
| **DolDoc editor/browser** | `Adam/DolDoc/*` (~30 files) | The single editor that *is* the command line, source viewer, document browser and dialog form engine: text with graphics/links/icons/trees/colors (`DocEd`, `DocForm`, `DocTree`, `DocFind`, `DocMacro`, `DocRun` — code can be embedded in and executed from documents) |
| **God app** | `Adam/God/*` | Bible search ("Oracle" on F7 for words, Shift-F7 for passages), doodle pad, songs (`GodBible`, `HolySpirit`) |
| **Graphics library + editors** | `Adam/Gr/*` | 2D/3D graphics API (`Gr.HH`), sprite editor (`SpriteEd`), 3D mesh editor with polygon/fence/prism tools (`SpriteMeshEd`), screen capture/screencast (`ScrnCast`) |
| **Sound** | `Adam/Snd/*` | Music file support, effects, on the single PC-speaker voice |
| **Disk utilities** | `Adam/ABlkDev/*` | Partitioner (`DskPrt`), disk check (`ChkDsk`, `DskChk`), file manager (`FileMgr`), mount/unmount, drive reports |
| **AutoComplete** | `Adam/AutoComplete/*` | Jump-to-source autocomplete with a generated dictionary (`ACDictGen`) — the IDE's code navigation |
| **Widgets** | `Adam/Ctrls/*` | Buttons and sliders as first-class widgets (not child windows) |
| **Boot loaders** | `Adam/Opt/Boot/*` | All boot-sector code + ISO tools (see [03](03-boot-process.md)) |
| **Utilities** | `Adam/Opt/Utils/*` | `Diff`, `Find`, `Merge`, `Profiler`, `MemRep`, `HeapLog`, `LinkChk`, `ToTXT`/`ToDolDoc` converters, `TOS.HC` install helpers |
| **System services** | `WinMgr.HC`, `ARegistry.HC`, `WallPaper.HC`, `TaskRep.HC`, `CPURep.HC`, `AMouse.HC`, `InFile.HC`, `Host.HC`, `InsReg.HC` | Window manager task, registry (persistent key/values), wallpaper, task/CPU reports, mouse driver install, `.IN` input-file support, VM host-disk switching, install registration |

## The Home account (`/Home`, root-level files)

The user-facing "account" shell: `HomeKeyPlugIns.HC`, `HomeLocalize.HC`, `HomeSys.HC`,
`HomeWrappers.HC` + [`MakeHome.HC`](../MakeHome.HC), compiled by `StartOS.HC` after Adam.
[`Once.HC`](../Once.HC) provides run-once automation (e.g., first-boot setup). A complete
example account with blog, themes and policies is in
[`Demo/AcctExample/TOS/`](../Demo/AcctExample/) — the pattern for building custom Home setups.

## Where to look when adding a Tailscale UI

- New apps follow the `Apps/<Name>/` convention (`Load.HC`, `Run.HC`, `Install.HC`).
- Dialogs/forms are DolDoc documents, not separate windows; widgets come from `Adam/Ctrls`.
- Long-running background work should be a spawned task (or jobs on AP cores), never a
  blocking loop in the UI task — the scheduler is cooperative ([04](04-kernel-subsystems.md)).
