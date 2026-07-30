# GodexU Phase 2C Mac MCP Read Adapter Run

Date: 2026-07-30 (Asia/Shanghai)

## Scope

- Task ID: `godexu-phase2c-mac-mcp-read-adapter`
- Worktree: isolated local feature worktree (machine path intentionally omitted)
- Branch: `codex/dynamic-island-local-prototype`
- Goal: expose a removable, Mac-local, metadata-only project and handoff index
  through a read-only stdio MCP helper.
- Excluded: installed-app replacement, persistent Codex registration, Codex
  model invocation, NAS access, Windows changes, GitHub push, rename/version
  bump, and task mutation/delivery.

## Implementation

Status: `passed`

- The app owns the `godexu-project-index-v1` contract and the fixed
  `--dump-project-index` command.
- Codex is read from the SQLite `threads` table only. OpenClaw is read from
  task/session index metadata only. Runtime availability and bounded handoff
  metadata are projected into the same index.
- Public IDs are normalized hashes. Raw thread/session IDs, transcript paths,
  handoff notes, recent replies, prompts, tool arguments, and database/SSH
  details are not part of the public schema. Credential-shaped content in
  visible metadata is replaced before export and rejected again by the helper.
- `GodexUMCPServer` uses the official Swift MCP SDK 0.12.1 and protocol
  `2025-11-25`. It exposes exactly three read-only tools and project/handoff
  resources over stdio, with no listener.
- The helper invokes only the sibling app's fixed `--dump-project-index`
  command. Internal bundle-directory symlinks are rejected. Child output is
  stopped at 2 MiB, the child has a hard timeout, concurrent refreshes share
  one in-flight task, and a successful snapshot may be reused in memory for
  three seconds.
- The helper is built for the same target triple, copied to
  `Contents/Helpers`, signed before the containing app, and included in deep
  signature verification.

## Verification Denominators

Status: `passed`

- App self-test routes: `18/18` passed.
- Focused app scripts: `2/2` passed:
  - project-index command/timeout/privacy suite;
  - Codex, OpenClaw, Claude Code, and Hermes parser fixture suite.
- MCP helper suites: `3/3` passed:
  - strict contract/cache/timeout tests;
  - real stdio initialize/list/call/read/error/EOF protocol probe;
  - bundled-helper architecture and nested/app signature checks.
- Architecture builds: `2/2` passed:
  - `arm64-apple-macos14.0`;
  - `x86_64-apple-macos14.0`.
- Output privacy scans: `2/2` passed with `0` prohibited field, local-path, or
  credential-shaped hits:
  - `/tmp/godexu-project-index.json`;
  - `/tmp/godexu-mcp-results.json`.
- Final arm64 signatures: `2/2` passed:
  - nested helper strict verification;
  - containing app deep strict verification.

The final local artifact is an optimized, ad-hoc signed arm64 development
build. Developer ID signing, notarization, installation, and public release
remain separate gates.

## Real Local Protocol Evidence

Status: `passed`

The live probe launched the helper from the built app bundle, which then
invoked the real sibling app executable against current Mac-local metadata.
It did not use the fixture app.

- Project-index dump: `168 ms`.
- Helper startup through completed MCP initialize: `15 ms`.
- First uncached project list: `221 ms`.
- Cached project list: `30 ms`.
- Helper resident memory: `13,712 KB`.
- Projects: `38`.
- Tasks: `433`.
- Handoffs: `0`.
- Warnings: `1` (`hermes_metadata_unavailable`).
- Runtime availability records: Codex, OpenClaw, and Claude Code reported
  `localOnly`; Hermes reported `unavailable` because its local `state.db` is
  absent.
- Protocol responses captured: `9`.
- Successful helper stdout consisted only of JSON-RPC lines; stderr was empty;
  EOF stopped the process within the probe bound.

These values are a point-in-time local measurement, not a performance promise.

## Artifact Evidence

- Final app executable architecture: `arm64`.
- Final helper architecture: `arm64`.
- App executable SHA-256:
  `a7deae3e5c54ec74228f6472a9094f905edcd1ffe43a5bae8031b1c6e184e648`
- Helper SHA-256:
  `e9363e70f3ca83b587d6293dae1d72f312379e56f8d4c011205240f7491278aa`
- Signing mode: ad-hoc development signature; no Team ID.

## Independent Review

Status: `passed`

The first read-only review reported `0` Critical and `5` Important findings:
credential-shaped title exposure, dropped availability/warnings, duplicate
concurrent refreshes, bundle-ancestor symlink escape, and MCP error/output
schema mismatch. All five were fixed. A bounded re-review reported
`5/5 resolved`, no remaining Important finding, and independently reran the
contract tests, protocol/helper tests, and whitespace gate successfully.

## Separate Status Dimensions

| Dimension | Status | Evidence or boundary |
| --- | --- | --- |
| Implementation | `passed` | Strict app contract, metadata readers, MCP helper, bundle step |
| Local regression | `passed` | 18/18 routes and 2/2 focused scripts |
| MCP fixture protocol | `passed` | Contract, valid/error/timeout protocol, EOF shutdown |
| Real local protocol | `passed` | 38 projects and 433 tasks via bundled helper |
| Privacy | `passed` | 2/2 output files, zero prohibited hits |
| arm64 build/sign | `passed` | app/helper architecture match and signatures verify |
| x86_64 build/sign | `passed` | app/helper architecture match and signatures verify |
| Visible UI change | `not_applicable` | This phase adds no user-visible surface |
| Installed app | `pending_authorization` | `/Applications/codexU.app` was not replaced |
| Persistent MCP registration | `pending_authorization` | No Codex config was modified |
| Real Codex model consumer | `pending_authorization` | No model was invoked |
| NAS/OpenClaw/Hermes remote access | `not_applicable` | No NAS or network access occurred |
| Windows | `not_applicable` | No Windows files or runtime changed |
| GitHub/public release | `pending_authorization` | No push, PR, release, or version bump |

## Known Limits

- This is the first read-only aggregation seam, not cross-device task delivery.
- Project names and titles are metadata and can still contain user-authored
  wording after path/UUID normalization; the adapter intentionally does not
  summarize or model-process that text.
- The three-second cache is per helper process and is not a persistent memory
  system.
- Runtime availability reports local structured-data presence, not a remote
  Agent health guarantee.

## Rollback

No data migration or persistent host configuration exists. Rollback is:

1. remove `MCPHelper/`;
2. remove the helper build/copy/sign steps and `test-mcp-helper` target from
   `Makefile`;
3. remove the app's project-index domain/reader/self-tests and
   `--dump-project-index` routing;
4. remove the Phase 2C documentation and third-party entries.

Removing the build worktree also removes the development app artifact. No
installed app, Codex configuration, NAS state, Windows state, or GitHub state
requires restoration.
