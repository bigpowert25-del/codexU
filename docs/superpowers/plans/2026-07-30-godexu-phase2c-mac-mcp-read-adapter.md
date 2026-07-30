# GodexU Phase 2C Mac MCP Read Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose GodexU's Mac-local, metadata-only project and handoff index through a removable, read-only stdio MCP helper.

**Architecture:** The existing app executable remains the sole local-data authority and gains a fast `--dump-project-index` command backed by dedicated metadata readers that never open transcripts. A separately built SwiftPM helper uses the official MCP Swift SDK 0.12.1, invokes only that fixed bundle-relative command, strictly validates and briefly caches its response, and exposes bounded read tools/resources.

**Tech Stack:** Swift 6, Foundation, AppKit, SQLite CLI read-only queries, SwiftPM, official `modelcontextprotocol/swift-sdk` 0.12.1, MCP protocol `2025-11-25`, Make, shell acceptance probes.

---

## Locked Scope And File Map

This plan modifies only the isolated worktree. It does not access NAS, add a
network listener, alter `~/.codex/config.toml`, replace `/Applications/codexU.app`,
use a model/API, bump the app version, or push GitHub.

- `Sources/CodexUsageWidget/Domain/GodexUProjectIndex.swift`: public dump schema,
  bounded value normalization, stable IDs, sorting, filtering, and freshness.
- `Sources/CodexUsageWidget/Domain/GodexUProjectIndexSelfTest.swift`: executable
  RED/GREEN contract, privacy, strict-decoding, sorting, and filter checks.
- `Sources/CodexUsageWidget/Services/GodexUProjectIndexReader.swift`: local-only
  Codex SQLite, OpenClaw task/session-index, Runtime availability, and handoff
  metadata projections; fixture paths are injected.
- `Sources/CodexUsageWidget/Services/GodexUProjectIndexReaderSelfTest.swift`:
  fixture-based proof that transcript bodies and handoff notes are not read or
  emitted.
- `Sources/CodexUsageWidget/main.swift`: self-test routing and
  `--dump-project-index`; no UI initialization on either path.
- `MCPHelper/Package.swift`, `MCPHelper/Package.resolved`: exact SDK dependency
  and helper products.
- `MCPHelper/Sources/GodexUMCPCore/*.swift`: strict index mirror, fixed child
  launcher, cache, filter validation, and result builders.
- `MCPHelper/Sources/GodexUMCPServer/main.swift`: SDK stdio server and MCP
  handlers only.
- `MCPHelper/Sources/GodexUMCPContractTests/main.swift`: executable unit and
  privacy tests that do not depend on the unavailable `Testing` module.
- `MCPHelper/Sources/GodexUMCPProbe/main.swift`: real stdio initialize/list/call/
  read/error/shutdown probe.
- `scripts/test-project-index.sh`: app-index fixture and public-output checks.
- `scripts/test-mcp-helper.sh`: helper contract and protocol acceptance.
- `Makefile`: build matching helper architecture, bundle before signing, and add
  focused test targets.
- `THIRD_PARTY_NOTICES.md`: SDK and transitive dependency attribution.
- `README.md`, `README.en.md`: bounded local MCP capability and non-persistent
  connection guidance.
- `docs/superpowers/runs/20260730-godexu-phase2c-mac-mcp-read-adapter.md`:
  evidence denominator, timings, gaps, and rollback.

### Task 1: Define The Strict Project-Index Contract

**Files:**
- Create: `Sources/CodexUsageWidget/Domain/GodexUProjectIndexSelfTest.swift`
- Create: `Sources/CodexUsageWidget/Domain/GodexUProjectIndex.swift`

- [ ] **Step 1: Write the failing contract self-test**

Create a self-test whose fixture contains safe metadata plus sentinel secrets:

```swift
enum GodexUProjectIndexSelfTest {
    static func run() -> Bool {
        var failures: [String] = []
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let index = GodexUProjectIndex.make(
            generatedAt: now,
            freshness: .fresh,
            runtimeAvailability: [
                .init(runtime: .codex, status: .available),
                .init(runtime: .hermes, status: .unavailable)
            ],
            tasks: [
                .init(
                    nativeID: "raw-thread-secret",
                    title: "  Safe task title  ",
                    projectName: "Workspace",
                    sourceRuntime: .codex,
                    state: .active,
                    updatedAt: now,
                    progressPercent: 45
                )
            ],
            envelopes: [
                .init(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    projectID: AgentProjectWorkspaceBuilder.projectID(
                        forDerivedName: "Workspace"
                    ),
                    projectName: "Workspace",
                    title: "Review result",
                    sourceRuntime: .codex,
                    targetRuntime: .openClaw,
                    state: .ready,
                    revision: 1,
                    createdAt: now,
                    updatedAt: now
                )
            ],
            warnings: []
        )
        let data = try! GodexUProjectIndexCodec.encode(index)
        let text = String(decoding: data, as: UTF8.self)
        check(index.schema == "godexu-project-index-v1", "schema", &failures)
        check(index.deviceScope == "local-mac", "scope", &failures)
        check(!text.contains("raw-thread-secret"), "raw ID leaked", &failures)
        check(!text.contains("handoffNote"), "note key leaked", &failures)
        check((try? GodexUProjectIndexCodec.decode(data)) == index,
              "round trip", &failures)
        check(GodexUProjectIndexQuery.limit(500) == 50,
              "limit bound", &failures)
        check(GodexUProjectIndexQuery.projectID("../../../tmp") == nil,
              "unsafe project ID", &failures)
        failures.forEach {
            fputs("project index self-test failed: \($0)\n", stderr)
        }
        if failures.isEmpty { print("project index self-test passed") }
        return failures.isEmpty
    }
}
```

- [ ] **Step 2: Run the build and verify RED**

Run: `make build`

Expected: FAIL with missing `GodexUProjectIndex`, `GodexUProjectIndexCodec`, and
`GodexUProjectIndexQuery` symbols.

- [ ] **Step 3: Implement the minimal strict schema**

Define `Codable`, `Equatable` value types with these exact public keys:

```swift
struct GodexUProjectIndex: Codable, Equatable {
    let schema: String
    let generatedAt: Date
    let deviceScope: String
    let freshness: GodexUIndexFreshness
    let runtimeAvailability: [GodexURuntimeAvailability]
    let projects: [GodexUProjectSummary]
    let handoffs: [GodexUHandoffSummary]
    let warnings: [GodexUIndexWarning]
}
```

The builder must normalize titles to one line and 160 characters, expose only
`task-<stable hash>` IDs, group Codex/Claude by bounded derived project name,
group OpenClaw/Hermes under runtime workspace IDs, count task states, sort by
latest activity then name, and cap each project at 100 tasks. The codec must
use ISO-8601 dates, sorted JSON keys, and reject top-level unknown keys before
decoding; its strict shape check must also reject unknown keys in every nested
object and array element. Query validators accept only known runtime/state enums, safe
`project-*`/`runtime-*` IDs, UUID handoff IDs, and limits clamped to 1...50.

- [ ] **Step 4: Run the focused contract self-test**

Temporarily compile the new files with the existing app sources and invoke the
self-test through a small `swiftc` harness:

```sh
make build
build/codexU.app/Contents/MacOS/codexU --self-test-project-index
```

Expected after the Task 3 routing step: `project index self-test passed`.
Before Task 3, compile success is the GREEN evidence for the domain contract.

- [ ] **Step 5: Commit the contract**

Stage only both new domain files and commit:

```sh
git add Sources/CodexUsageWidget/Domain/GodexUProjectIndex.swift
git add Sources/CodexUsageWidget/Domain/GodexUProjectIndexSelfTest.swift
git commit -m "feat: define bounded project index"
```

### Task 2: Add Metadata-Only Local Readers

**Files:**
- Create: `Sources/CodexUsageWidget/Services/GodexUProjectIndexReaderSelfTest.swift`
- Create: `Sources/CodexUsageWidget/Services/GodexUProjectIndexReader.swift`

- [ ] **Step 1: Write failing fixture tests**

Build an isolated temporary home with:

```text
.codex/state_5.sqlite
.codex/sessions/secret-transcript.jsonl
.openclaw/workspace/memory/tasks.json
.openclaw/agents/main/sessions/sessions.json
.openclaw/agents/main/sessions/secret-transcript.jsonl
Library/Application Support/codexU/task-envelopes.json
```

The SQLite fixture has one `threads` row with a safe title and a
`rollout_path` pointing at a transcript containing
`TRANSCRIPT_SENTINEL_DO_NOT_READ`. The OpenClaw index points at a transcript
containing the same sentinel. The envelope contains
`HANDOFF_NOTE_SENTINEL_DO_NOT_EMIT`.

The test calls:

```swift
let reader = GodexUProjectIndexReader(
    homeDirectory: root,
    envelopeFileURL: envelopeURL,
    now: now
)
let data = try GodexUProjectIndexCodec.encode(reader.load())
let text = String(decoding: data, as: UTF8.self)
check(text.contains("Safe Codex title"), "Codex metadata missing", &failures)
check(text.contains("Safe OpenClaw task"), "OpenClaw metadata missing", &failures)
check(!text.contains("TRANSCRIPT_SENTINEL_DO_NOT_READ"),
      "transcript leaked", &failures)
check(!text.contains("HANDOFF_NOTE_SENTINEL_DO_NOT_EMIT"),
      "handoff note leaked", &failures)
check(!text.contains(root.path), "path leaked", &failures)
```

- [ ] **Step 2: Run the test and verify RED**

Run: `make build`

Expected: FAIL because `GodexUProjectIndexReader` does not exist.

- [ ] **Step 3: Implement dedicated readers**

Implement the reader without calling `CodexUsageReader`,
`OpenClawTaskReader`, `MultiRuntimeUsageReader`, or any transcript parser.

Codex query:

```sql
SELECT id, title, cwd, updated_at AS updatedAt, archived
FROM threads
ORDER BY updated_at DESC
LIMIT 500;
```

Run `/usr/bin/sqlite3` directly with `-readonly -json`; never invoke a shell.
Use only the first existing local Codex state DB. OpenClaw parses only canonical
`tasks.json` fields (`id`, `title`, `status`, timestamps, progress) and
`sessions.json` metadata (`sessionId`, `updatedAt`, `status`, `channel`,
`modelProvider`, `model`), never `sessionFile`. A session gets the neutral title
`OpenClaw Session <normalized suffix>`. Read the envelope document with the
existing strict store validation, then map an allowlisted summary that omits
origin node, target node, source task ID, and note. Missing sources produce
bounded warning codes such as `codex_metadata_unavailable`.

- [ ] **Step 4: Run the reader self-test**

Run:

```sh
make build
build/codexU.app/Contents/MacOS/codexU --self-test-project-index-reader
```

Expected after Task 3 routing: `project index reader self-test passed` and zero
sentinel/path hits.

- [ ] **Step 5: Commit the readers**

```sh
git add Sources/CodexUsageWidget/Services/GodexUProjectIndexReader.swift
git add Sources/CodexUsageWidget/Services/GodexUProjectIndexReaderSelfTest.swift
git commit -m "feat: read local project metadata safely"
```

### Task 3: Expose A Fast No-Window App Command

**Files:**
- Create: `scripts/test-project-index.sh`
- Modify: `Sources/CodexUsageWidget/main.swift`
- Modify: `Makefile`

- [ ] **Step 1: Write the failing command test**

The script must build unless `CODEXU_SKIP_BUILD=1`, run both self-tests, capture
stdout/stderr separately, run `--dump-project-index`, and assert:

```sh
test "$(python3 -c 'import json,sys; print(json.load(sys.stdin)[\"schema\"])' \
  < "$dump")" = "godexu-project-index-v1"
test ! -s "$stderr_file"
test "$(wc -l < "$dump" | tr -d ' ')" -eq 1
! rg -n 'handoffNote|recentReply|summary|rolloutPath|sessionFile|prompt|toolArguments' "$dump"
```

- [ ] **Step 2: Run and verify RED**

Run: `CODEXU_SKIP_BUILD=1 ./scripts/test-project-index.sh`

Expected: FAIL because the self-test flags and `--dump-project-index` are not
routed.

- [ ] **Step 3: Add command routing and JSON emission**

Insert branches before `NSApplication.shared`:

```swift
if CommandLine.arguments.contains("--self-test-project-index") {
    exit(GodexUProjectIndexSelfTest.run() ? 0 : 1)
}
if CommandLine.arguments.contains("--self-test-project-index-reader") {
    exit(GodexUProjectIndexReaderSelfTest.run() ? 0 : 1)
}
if CommandLine.arguments.contains("--dump-project-index") {
    do {
        let data = try GodexUProjectIndexCodec.encode(
            GodexUProjectIndexReader.live().load()
        )
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0a]))
        return
    } catch {
        fputs("project_index_unavailable\n", stderr)
        exit(1)
    }
}
```

Add `test-project-index` to `.PHONY` and:

```make
test-project-index: build
	CODEXU_SKIP_BUILD=1 ./scripts/test-project-index.sh
```

- [ ] **Step 4: Run GREEN and latency checks**

Run:

```sh
make test-project-index
/usr/bin/time -lp build/codexU.app/Contents/MacOS/codexU --dump-project-index \
  > /tmp/godexu-project-index.json
```

Expected: both self-tests pass, one valid JSON line, empty success stderr, and
the dump completes under 500 ms on the development Mac.

- [ ] **Step 5: Commit the command**

```sh
git add Sources/CodexUsageWidget/main.swift
git add Makefile
git add scripts/test-project-index.sh
git commit -m "feat: expose lightweight project index"
```

### Task 4: Build And Test The MCP Core

**Files:**
- Create: `MCPHelper/Package.swift`
- Create: `MCPHelper/Sources/GodexUMCPCore/ProjectIndex.swift`
- Create: `MCPHelper/Sources/GodexUMCPCore/ProjectIndexCache.swift`
- Create: `MCPHelper/Sources/GodexUMCPCore/ProjectIndexQueries.swift`
- Create: `MCPHelper/Sources/GodexUMCPContractTests/main.swift`

- [ ] **Step 1: Write the failing executable contract tests**

Pin:

```swift
.package(
    url: "https://github.com/modelcontextprotocol/swift-sdk.git",
    exact: "0.12.1"
)
```

Create a `GodexUMCPCore` library and an executable
`GodexUMCPContractTests`. Tests must cover:

- strict schema and unknown-key rejection;
- fixed executable resolution from
  `Contents/Helpers/GodexUMCPServer` to `Contents/MacOS/codexU`;
- no caller-provided path or command input;
- three-second fresh cache hit;
- refresh timeout;
- stale fallback no older than 15 minutes with original `generatedAt`;
- no-cache bounded failure;
- valid/invalid project IDs, handoff UUIDs, enum filters, and limits;
- list/get result caps and deterministic ordering;
- prohibited-key and sentinel scans over every returned JSON value.

- [ ] **Step 2: Run and verify RED**

Run:

```sh
swift run --package-path MCPHelper GodexUMCPContractTests
```

Expected: FAIL with missing core types such as `ProjectIndexCache`,
`ProjectIndexQueryService`, and `BundledAppCommand`.

- [ ] **Step 3: Implement the minimal core**

Mirror and strictly decode `godexu-project-index-v1`; do not import app source.
Implement:

```swift
actor ProjectIndexCache {
    let freshTTL: TimeInterval = 3
    let staleTTL: TimeInterval = 15 * 60
    func snapshot(now: Date) async throws -> ProjectIndex
}
```

The launcher uses `Process.executableURL` and fixed arguments
`["--dump-project-index"]`, captures stdout/stderr separately, caps each stream
at 2 MiB, terminates after three seconds, and maps all failures to public codes
without paths or child text. Cache only a fully decoded strict snapshot.
Queries apply validated filters and limits after cache retrieval.

- [ ] **Step 4: Run GREEN repeatedly**

Run:

```sh
swift run --package-path MCPHelper GodexUMCPContractTests
swift run --package-path MCPHelper GodexUMCPContractTests
```

Expected: both runs print `MCP contract self-tests passed` with zero failures.

- [ ] **Step 5: Resolve and commit dependencies and core**

Run: `swift package --package-path MCPHelper resolve`

Stage only package, resolved lockfile, core, and tests; commit:

```sh
git add MCPHelper/Package.swift MCPHelper/Package.resolved
git add MCPHelper/Sources/GodexUMCPCore
git add MCPHelper/Sources/GodexUMCPContractTests
git commit -m "feat: add bounded MCP helper core"
```

### Task 5: Add The Official-SDK Stdio Server And Probe

**Files:**
- Create: `MCPHelper/Sources/GodexUMCPServer/main.swift`
- Create: `MCPHelper/Sources/GodexUMCPProbe/main.swift`
- Create: `scripts/test-mcp-helper.sh`

- [ ] **Step 1: Write the failing protocol probe**

The probe launches a supplied helper binary only for test orchestration, sends
newline-delimited JSON-RPC, and verifies:

1. `initialize` negotiates `2025-11-25`;
2. initialized notification succeeds;
3. `tools/list` returns exactly the three `godexu_*` tools with read-only,
   non-destructive, closed-world annotations and explicit schemas;
4. `resources/list` includes `godexu://projects`;
5. resource templates list includes project and handoff templates;
6. valid list/get/handoff calls and reads return bounded JSON;
7. invalid tool, unsafe ID, invalid filter, and excessive limit fail safely;
8. malformed child output and timeout produce bounded errors;
9. stdout parses as JSON-RPC line by line and stderr contains no fixture
   sentinel or local path;
10. helper exits after stdin closes.

- [ ] **Step 2: Run the probe and verify RED**

Run: `./scripts/test-mcp-helper.sh`

Expected: FAIL because `GodexUMCPServer` and `GodexUMCPProbe` do not exist.

- [ ] **Step 3: Implement the SDK server**

Use SDK `Server`, `StdioTransport`, tool/resource list handlers, call/read
handlers, and resource-template handlers. The exact public surface is:

```text
resource: godexu://projects
templates: godexu://projects/{projectID}, godexu://handoffs/{envelopeID}
tools: godexu_project_list, godexu_project_get, godexu_handoff_list
```

Every tool has explicit input/output JSON schema and:

```text
readOnlyHint=true
destructiveHint=false
openWorldHint=false
```

Do not advertise prompts, roots, sampling, elicitation, tasks extension,
subscriptions, logging, or any mutation tool. Stdout is reserved for the SDK
transport; bounded diagnostic codes go only to stderr.

- [ ] **Step 4: Run GREEN protocol acceptance**

Run:

```sh
./scripts/test-mcp-helper.sh
```

Expected: protocol denominator prints all cases passed, zero privacy hits, and
clean helper shutdown.

- [ ] **Step 5: Commit server and probe**

```sh
git add MCPHelper/Sources/GodexUMCPServer
git add MCPHelper/Sources/GodexUMCPProbe
git add scripts/test-mcp-helper.sh
git commit -m "feat: serve project index over MCP"
```

### Task 6: Bundle, Sign, Cross-Build, And Attribute

**Files:**
- Modify: `Makefile`
- Create: `THIRD_PARTY_NOTICES.md`
- Modify: `README.md`
- Modify: `README.en.md`

- [ ] **Step 1: Add failing packaging assertions**

Extend `scripts/test-mcp-helper.sh` to require:

```sh
test -x build/codexU.app/Contents/Helpers/GodexUMCPServer
file build/codexU.app/Contents/Helpers/GodexUMCPServer | rg "$expected_arch"
codesign --verify --strict build/codexU.app/Contents/Helpers/GodexUMCPServer
codesign --verify --deep --strict build/codexU.app
```

Run: `./scripts/test-mcp-helper.sh`

Expected: FAIL because the helper is not bundled by `make build`.

- [ ] **Step 2: Bundle before signing**

Add `HELPERS_DIR`, a `build-mcp-helper` target using the same
`TARGET_TRIPLE`, and copy the `--show-bin-path` result to:

```text
build/codexU.app/Contents/Helpers/GodexUMCPServer
```

Create `Contents/Helpers` during app assembly and make `build` depend on the
matching helper. Sign the nested helper first when using a non-ad-hoc identity;
then sign and strictly verify the containing app.

- [ ] **Step 3: Add attribution and connection documentation**

Document:

- official Swift MCP SDK 0.12.1 and all locked transitive licenses;
- local stdio, no listener/network service;
- metadata-only fields and explicit prohibited content;
- the helper executable location;
- a temporary/manual connection example only;
- no silent `~/.codex/config.toml` mutation;
- no promise of NAS/Windows delivery or real Codex model-call acceptance.

- [ ] **Step 4: Verify both architectures**

Run:

```sh
make clean
make build TARGET_TRIPLE=arm64-apple-macos14.0
file build/codexU.app/Contents/Helpers/GodexUMCPServer
codesign --verify --deep --strict build/codexU.app
make clean
make build TARGET_TRIPLE=x86_64-apple-macos14.0
file build/codexU.app/Contents/Helpers/GodexUMCPServer
codesign --verify --deep --strict build/codexU.app
make clean
make build
```

Expected: 2/2 matching architectures and signatures pass; the final local build
matches the host architecture.

- [ ] **Step 5: Commit packaging and docs**

```sh
git add Makefile THIRD_PARTY_NOTICES.md README.md README.en.md
git add scripts/test-mcp-helper.sh
git commit -m "build: bundle and document MCP helper"
```

### Task 7: Regression, Privacy, Real Local Probe, And Evidence

**Files:**
- Create: `docs/superpowers/runs/20260730-godexu-phase2c-mac-mcp-read-adapter.md`

- [ ] **Step 1: Run all focused checks**

Run:

```sh
make test-project-index
./scripts/test-mcp-helper.sh
make test-agent-identity
make test-task-envelopes
make test-task-envelope-store
make test-task-navigation
make test-display-surface
build/codexU.app/Contents/MacOS/codexU --self-test-status-item
make test-dynamic-island
make test-parsers
```

Expected: every applicable check passes with explicit denominators.

- [ ] **Step 2: Run source and output privacy scans**

Generate a fresh dump and real MCP results, then scan for prohibited fields and
known local-path prefixes:

```sh
rg -n 'handoffNote|recentReply|rolloutPath|sessionFile|toolArguments|prompt|transcript' \
  /tmp/godexu-project-index.json /tmp/godexu-mcp-results.json
```

Expected: zero hits. Also assert no home-directory absolute path, raw database
path, SSH alias, account identity, credential-shaped value, or fixture sentinel.

- [ ] **Step 3: Run real local protocol and performance acceptance**

Using the bundled helper and current local metadata, record:

- initialize/list/call/read/error/shutdown denominator;
- first uncached project list latency;
- cached project list latency;
- helper startup time and RSS;
- dump latency;
- project/task/handoff counts;
- warnings and unavailable runtimes.

Do not invoke a Codex model. Report real Codex consumer acceptance as
`pending_authorization`, not passed.

- [ ] **Step 4: Run final repository gates**

Run:

```sh
git diff --check
make build
codesign --verify --deep --strict build/codexU.app
git status --short
```

Expected: no whitespace errors, build/signature pass, and only the run record is
uncommitted.

- [ ] **Step 5: Write and commit the run record**

Record implementation, local verification, real protocol probe, architecture,
privacy, regression, installed-app, persistent-registration, NAS, Windows,
GitHub, and model acceptance as separate status dimensions. Include rollback:
remove the helper package, bundle step, and dump command; no data migration or
persistent host configuration exists.

```sh
git add docs/superpowers/runs/20260730-godexu-phase2c-mac-mcp-read-adapter.md
git commit -m "docs: record Mac MCP adapter acceptance"
```

## Plan Self-Review

- Spec coverage: the seven tasks cover the strict index, metadata-only sources,
  no-window dump, official SDK helper, resources/tools, cache and failure
  semantics, privacy, two architectures, signing, attribution, regression,
  protocol evidence, and explicit consumer/installation/publish gaps.
- Scope check: persistent connection UI, task mutation/delivery, NAS transport,
  repair, Windows, rename/version, installation, and publishing remain separate
  future plans.
- Placeholder scan: the plan contains no implementation placeholders; every
  step names exact files, APIs, commands, and expected RED/GREEN evidence.
- Type consistency: app contract uses `GodexUProjectIndex*`; helper mirror uses
  `ProjectIndex*`; all three MCP tool/resource names match the approved design.
- TDD order: every production slice starts with a failing self-test or probe and
  requires observed RED before minimal implementation.
