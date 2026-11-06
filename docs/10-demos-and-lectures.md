# 10 — Demos and Lectures (`Demo/`)

`Demo/` holds ~220 single-purpose programs: games, graphics experiments, language-feature
demos, project templates and interactive **lectures**. The author's own index is
[`../Doc/DemoIndex.DD`](../Doc/DemoIndex.DD). Demos double as the system's test corpus —
the OS test suite runs many of them (see [11](11-build-test-distribute.md)).

## Lectures (`Demo/Lectures/`) — interactive teaching material

These are the best starting point for understanding low-level TempleOS:

| Lecture | Topic |
|---|---|
| `MiniCompiler.HC` | How a tiny compiler works (mirrors the real pipeline) |
| `Ring3.HC` | Privilege levels and why TempleOS avoids them |
| `InterruptDemo.HC`, `PCIInterrupts.HC` | Interrupt handling; PCI interrupt routing (relevant to NIC work!) |
| `ScrnMemory.HC` | How screen memory works |
| `GraphicsCPULoad.HC` | Measuring graphics cost |
| `FixedPoint.HC`, `FixedPointAdvanced.HC` | Fixed-point arithmetic (useful for crypto/protocol code) |
| `AndNotMod.HC`, `NegDisp.HC`, `Optimization.HC`, `MiniGrLib.HC` | Language and optimization concepts |

## Multicore (`Demo/MultiCore/`)

`MPAdd`, `MPPrint`, `MPRadix`, `Palindrome`, `Primes`, `LoadTest`, `Lock`, `Interrupts` —
examples of `JobQue()` work distribution, LOCK-prefixed atomics and AP-core behavior.
**Any network-stack design that uses AP cores for crypto should start here.**

## Games (`Demo/Games/`)

~30 games: `TicTacToe`, `TreeCheckers`, `Maze`, `DunGen` (dungeon generator), `Rocket`,
`RocketScience`, `BomberGolf`, `BigGuns`, `BattleLines`, `CastleFrankenstein`, `TheDead`,
`Varoom`, `Zing`, `ZoneOut`, `Whap`, `Wenceslas`, `Talons`, `Stadium` (+ generator),
physics demos (`MassSpring`, `Collision`, `CircleTrace`, `RainDrops`, `PredatorPrey`)…

## Graphics (`Demo/Graphics/`)

~45 graphics experiments: sprites (`SpritePlot3D`, `SpritePutExt`, `EdSprite`), 3D
(`3DPoly`, `Pick3D`, `RotateTank`, `Shading`, `Shadow`, `WinZBuf`), animation
(`CharAnimation`, `Bounce`, `SunMoon`, `WallPaperFish`), UI (`ScrollBars`, `Slider`,
`PullDownMenu`-adjacent), math visualization (`BSpline`, `PoleZeros`, `LowPassFilter`,
`Lattice`), and utilities (`ScrnCapture`, `FontEd`, `Palette`).

## Language & system feature demos (top level)

| Demo | Shows |
|---|---|
| `Asm/` (`AsmHelloWorld`, `MulByHand`, `DivByHand`, `BuzzFizz`, …) | Inline asm, calling conventions |
| `Exceptions.HC`, `SubSwitch.HC`, `NullCase.HC`, `LastClass.HC`, `ClassMeta.HC`, `Directives.HC`, `Define.HC` | HolyC language features (see [07](07-holyc-language.md)) |
| `MemDemo.HC`, `StkGrow.HC`, `GlblVars.HC`, `MsgLoop.HC`, `OnceDemo.HC` | Memory, stacks, messages, run-once automation |
| `Dsk/` (`DskRaw`, `DataBase`, `SerializeTree`, `UnusedSpaceRep`) | Raw disk access and file formats |
| `Snd/` (`ASCIIOrgan`, `MorseCode`, …) | PC-speaker sound |
| `InFile/` (`InPopUp`, **`InSetIP`**) | `.IN` input-file scripting — note `InSetIP` is an IP-address entry demo, the closest existing artifact to networking UX |
| `WebLogDemo/` (+ real templeos.org access logs) | Parsing web server logs (text-processing pattern) |
| `RegistryDemo.HC`, `Profiler`-adjacent utils | Registry API |
| `Templates/` (`Game1`, `Lex1`, `MultiCore1`, `ODE1`, `Registry1`, `Util1/2`) | **Project templates** — copy one when starting a new app/subsystem |

## Using demos as tests

`Misc/OSTestSuite.HC` drives many of these files in sequence (see
[11-build-test-distribute.md](11-build-test-distribute.md)). When adding subsystems, the
house pattern for regression coverage is: write a small demo that exercises the feature,
then add it to the test suite.
