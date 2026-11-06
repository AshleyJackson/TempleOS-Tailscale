# Net Configuration and Key Storage

Phase 0 design decision for ADR-0006: **where the net stack keeps its
configuration and key material, and in what format.** The actual read/write
code lands with Phase 3/4 (WireGuard + tailnet membership); this document
fixes the formats now so that code can rely on them.

## Storage mechanisms available in TempleOS

| Mechanism | API | Character |
|---|---|---|
| Registry | `RegDft("TempleOS/X","…")`, `RegExe("TempleOS/X")`, `RegWrite("TempleOS/X",fmt,…)` (see `Demo/AcctExample/TOS/TOSNIST.HC`, `Demo/Games/CircleTrace.HC`) | Persistent key/value store; values are **HolyC source text** that gets compiled and executed when read (`RegExe`). House pattern: namespace `"TempleOS/<AppName>"` |
| Files under `~/Tailscale/` | `FileRead`/`FileWrite`, whole-file oriented (ADR-0003) | Plain-text files on the home drive; survive reboot; visible/editable from a user terminal |

## Decision

**Small runtime settings → registry namespace `"TempleOS/Net"`.
Key material and peer lists → plain-text files under `~/Tailscale/`.**

Rationale:

- Registry values are executable source text. Storing *secrets* (a 32-byte
  Curve25519 private key) as code that gets compiled into a task's context on
  every read is needlessly risky in a ring-0, no-protection system
  (ADR-0002). Plain files keep secrets out of the symbol table.
- Files match ADR-0003's whole-file rewrite-replace discipline: RedSea files
  are contiguous and cannot grow, so updates are "write new file, replace old"
  — exactly how config should behave (atomic-ish, no partial writes).
- The registry is the right tool for small scalar settings that code wants to
  read cheaply at boot (`RegExe` once into the net task's context).

## Registry: `"TempleOS/Net"`

Defaults are established with `RegDft` (idempotent — only writes if absent),
then loaded with `RegExe`. Values mirror the `CNetGlbls.cfg_*` fields in
`Kernel/Net/Net.HH`:

```holyc
//Established once at first boot (Phase 4):
RegDft("TempleOS/Net","U32 cfg_ip=0;\nU32 cfg_netmask=0;\nU32 cfg_gateway=0;\nI64 dft_nd_index=-1;\n");
RegExe("TempleOS/Net");
//Written on change (Phase 4 UI):
RegWrite("TempleOS/Net","U32 cfg_ip=%X;U32 cfg_netmask=%X;U32 cfg_gateway=%X;I64 dft_nd_index=%d;\n",…);
```

- `cfg_*` are network-byte-order IPv4 addresses as U32 (0 = unset).
- `dft_nd_index`: index into `net.nd[]` of the default transmit device
  (`-1` = none; Phase 1 sets it when a NIC is added via `NET_MSG_DEV_ADD`).

## Files under `~/Tailscale/`

| File | Contents | Written by |
|---|---|---|
| `node_key` | The node's Curve25519 **private** key: 64 hex chars + newline (32 bytes). Generated once at first join; never transmitted | Phase 4 setup flow |
| `peers` | One line per WireGuard peer: `<64-hex public key> <endpoint ip or name> <port>` — whitespace-separated, one peer per line, blank lines and `//` comments allowed | Phase 4 UI / manual edit from a user terminal |

Format notes:

- Hex (lowercase) is used for keys because HolyC has no binary file API in the
  house style — everything on disk is text. 64 hex chars + newline = 65 bytes,
  trivially within RedSea's contiguous-file model.
- `peers` is a *list*, so it grows over time; each update rewrites the whole
  file (write to `peers.tmp`, then replace) per ADR-0003 — never append in
  place, since RedSea files cannot grow.
- The public key derived from `node_key` is shown to the admin for pasting into
  another tailnet node's external-peer config; it is not stored separately
  (it is derivable).

## Write discipline (ADR-0003)

All writes follow: **write complete new content to a temp file → verify →
replace the original.** There is no append-friendly log format in RedSea, and
a half-written key file must never be observable. The net task performs these
writes on Core0 between `Yield`s; files are small (≤ a few KB), so whole-file
I/O cost is negligible.

## What this deliberately does *not* cover

- No TLS/control-plane state (ADR-0006 Option B is deferred).
- No per-peer handshake keys or ephemeral state — those live in RAM only and
  are rebuilt from `peers` + `node_key` on reboot.
- No file permissions concept exists in TempleOS; the home drive is trusted by
  definition (single-user OS).
