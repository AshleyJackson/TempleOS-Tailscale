# 07 — HolyC Language Guide

HolyC is "more than C and less than C++" (`Doc/Glossary.DD`): C syntax plus C++-style
default arguments, `class` instead of `struct`, no type-checking, and a set of deliberate
extensions. The authoritative reference is [`../Doc/HolyC.DD`](../Doc/HolyC.DD); this page
is the working summary for people editing this repository.

## Types

| HolyC | Meaning |
|---|---|
| `I0` … `I64` | signed 0/8/16/32/64-bit ints (`I8`=char, `I16`=short, `I32`=int, `I64`=long) |
| `U0` … `U64` | unsigned variants; **`U0` is void but zero-size** (usable as a member) |
| `F64` | 8-byte float — there is **no F32** |

- **All values are extended to 64 bits when fetched; all intermediate computation is
  64-bit.** Shifting a negative I32 constant sign-extends first (examples in `Doc/HolyC.DD`).
- No bit-fields: use the bit-access routines (`Bt/Bts/Btr/Btc`) or sub-int access — any int
  can be viewed as bytes/words: `i.u16[1]=0x9ABC;`. A typed union-like class
  (`I64i union I64 { … }`) gives named views.
- No `typedef` (use `class`), no type-checking, no `<>` in `#include` (use `""`).

## Statements and control flow

- **No `main()`.** Code outside functions executes at load/start-up, in order. This is how
  scripts, songs and automations work — the same language drives everything.
- A bare string literal is a print statement: `"Hello\n";` → `Print`; with args it formats;
  `"" fmt,args` uses a variable format; a lone char const `'x'` → `PutChars`. Multi-char
  quotes are packed ints: `'ABC' == 0x434241`.
- **Default arguments may appear anywhere** in the parameter list, and calls can skip them:
  `Test(,3);` is valid. Functions with only default args can be called without parens: `Dir;`
- Chained comparisons: `if (13<=age<20)`. No ternary operator. `` ` `` is the power operator.
- `switch`: always a jump table; supports **ranges** (`case 4...7:`), **numberless cases**
  (= previous case + 1, or 0 for the first), and **sub_switch** grouping with `start:`/`end:`
  labels around nested case groups. No `continue` — use `goto`.
- Exceptions: `try{} catch{}` where `throw('msg')` carries a short char string readable as
  `Fs->except_ch`; set `Fs->catch_except=TRUE` in the catch to stop propagation.
- Variadic functions access their extra args via built-ins `argc` / `argv[]`.

## Functions, scoping and linkage

- Function *addresses* need `&`: `CALL &FUNC`, callbacks as `&MyCB`.
- **No namespaces.** Scope is the task symbol-table hierarchy: each task has a hash table;
  lookup walks up to the parent, ending at Adam's system-wide table (which holds all API
  symbols). No header includes are ever needed. Linkage keywords (`extern`, `import`,
  `_extern`, `_import`) are detailed in [`../Doc/ScopingLinkage.DD`](../Doc/ScopingLinkage.DD);
  see also the import examples at the top of [`Kernel/KExts.HC`](../Kernel/KExts.HC).
- **Naming conventions** (`Doc/Glossary.DD`) — follow these when adding code:

| Style | Used for |
|---|---|
| `MixedCaps` | HolyC functions and class names (with a 2–3 char module prefix, e.g. `Doc`, `Lex`) |
| `lower_case` | local vars, globals, class members |
| `_lower_case` | output arguments (passed by pointer) / args shadowing locals |
| `ALL_CAPS` | asm labels and `#define`s |
| `_ALL_CAPS` | asm routines callable from HolyC (leading underscore mandatory) |
| `XXXf_????` / `XXG_???` | flag bit numbers / flag groups; `res` reserved for the return-value local |

## Asm blocks, `$`, and meta-compilation

- Inline `asm { … }` with x86/x86_64 mnemonics (minimal 16-bit support exists for boot
  loaders). Labels are positional (`@@05`) or named; `USE32`/`USE64` switch operand size.
- `$` is the escape character in strings and markup; **in code, `$LABEL` yields the label's
  address** and inside a class definition it yields member offsets — this powers the `$LK`
  link syntax used throughout source and docs (e.g.
  `$LK,"KMain",A="FF:::/Kernel/KMain.HC,KMain"$`).
- **`#exe { … }` blocks run at compile time** and can inject text into the compilation
  stream via `StreamPrint()` — this is how kernel build options (`KCfg.HC`) are woven in,
  how `.PRJ` files configure the compiler mid-build, and how date/version strings get
  stamped. See [`Kernel/KMain.HC`](../Kernel/KMain.HC) and
  [`Kernel/Kernel.PRJ`](../Kernel/Kernel.PRJ) for canonical examples.
- `Option(OPTf_…, ON/OFF)` toggles compiler behavior (warnings, keep-private, externs-to-imports…).
  Full list: [`../Doc/Options.DD`](../Doc/Options.DD).

## Templates and class metadata

- HolyC has **templates** (`Compiler/Templates.HC`; demos in `Demo/Templates/`) — a limited
  code-generation facility for parameterized types.
- Class members can carry **metadata** (`format`, `data`), and the compiler retains its own
  structures about classes/vars at runtime (used by `ClassRep()`, `DocForm()`). The keyword
  `lastclass` names "the class of the previous argument" for default parameters.

## Practical notes for contributors

- There is no external toolchain: HolyC compiles **only inside TempleOS** (JIT from source,
  or AOT via `.PRJ`). Expect to iterate in-VM; use `RAMReboot()` for fast kernel restarts.
- The compiler *is* the debugger's friend: `Trace()`, `PassTrace()`, `U`/`Uf` unassemble
  generated code; breakpoints are per-task (`CBpt` lists saved with context).
- Keep an eye on total line count — the project has a self-imposed ~100k-line budget
  (`Doc/Strategy.DD`). New subsystems (e.g., networking) should be written to that standard.
