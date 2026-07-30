# GodexU v2 Phase 2B Project Hub And Handoff Draft Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing Projects tab into a local multi-Agent project hub and let users prepare auditable task handoff drafts addressed to visible Agent nodes without sending them.

**Architecture:** A strict Codable envelope model and atomic Application Support store hold only local drafts, including MCP-ready UUID, origin-node, and monotonic-revision semantics. A pure workspace builder groups the existing normalized task board with those envelopes. The existing task detail sheet gains a target-Agent draft editor, while a new SwiftUI two-pane project hub presents tasks and handoffs without exposing summaries, replies, paths, or transport claims. No MCP server or SDK is added in this phase.

**Tech Stack:** Swift 6 command-line compilation, SwiftUI/AppKit, Foundation JSON, existing codexU node/identity/task models, existing self-test CLI.

---

## Allowed Paths

- `Sources/CodexUsageWidget/Domain/AgentTaskEnvelope.swift`
- `Sources/CodexUsageWidget/Domain/AgentTaskEnvelopeSelfTest.swift`
- `Sources/CodexUsageWidget/Domain/AgentProjectWorkspace.swift`
- `Sources/CodexUsageWidget/Services/AgentTaskEnvelopeStore.swift`
- `Sources/CodexUsageWidget/UI/AgentProjectHubView.swift`
- `Sources/CodexUsageWidget/main.swift`
- `Makefile`
- `CHANGELOG.md`
- `docs/superpowers/specs/2026-07-30-godexu-phase2b-project-handoff-design.md`
- `docs/superpowers/plans/2026-07-30-godexu-phase2b-project-handoff.md`
- `docs/superpowers/runs/20260730-godexu-phase2b-project-handoff.md`

All other paths are excluded. In particular, do not change runtime providers,
token attribution, node probes/configuration, Agent identity storage, Dynamic
Island, status-item, Windows, update routing, version files, release assets,
the installed app, NAS state, Memory Router, MCP host configuration, or GitHub.

## Task 1: Baseline And Design Receipt

**Files:**

- Existing build and tests only.
- Commit the Phase 2B spec and plan.

- [ ] **Step 1: Record the isolated baseline**

Run:

```sh
git rev-parse --git-dir
git rev-parse --git-common-dir
git branch --show-current
git status --porcelain=v1
git rev-parse --short HEAD
```

Expected: the linked worktree is on
`codex/dynamic-island-local-prototype`; the baseline before the Phase 2B spec
is `9a69320`; no unrelated path is dirty.

- [ ] **Step 2: Run the focused existing baseline**

Run:

```sh
bin=build/codexU.app/Contents/MacOS/codexU
"$bin" --self-test-task-navigation
"$bin" --self-test-agent-nodes
"$bin" --self-test-agent-identity
CODEXU_SKIP_BUILD=1 ./scripts/test-parsers.sh
git diff --check
```

Expected: three self-tests and all four runtime parser fixtures pass.

- [ ] **Step 3: Commit the reviewed design and plan**

Enumerate every status path, compare it to the two documentation paths, then
stage only those paths:

```sh
git add \
  docs/superpowers/specs/2026-07-30-godexu-phase2b-project-handoff-design.md \
  docs/superpowers/plans/2026-07-30-godexu-phase2b-project-handoff.md
git diff --cached --check
git commit -m "docs: plan GodexU project handoffs"
```

Expected: the allowlist set difference is empty.

## Task 2: Envelope And Project Domain RED/GREEN

**Files:**

- Create: `Sources/CodexUsageWidget/Domain/AgentTaskEnvelopeSelfTest.swift`
- Create after RED: `Sources/CodexUsageWidget/Domain/AgentTaskEnvelope.swift`
- Create after RED: `Sources/CodexUsageWidget/Domain/AgentProjectWorkspace.swift`
- Modify: `Sources/CodexUsageWidget/main.swift`
- Modify: `Makefile`

- [ ] **Step 1: Register the failing self-test**

Add `--self-test-task-envelopes` to `main.swift`:

```swift
if CommandLine.arguments.contains("--self-test-task-envelopes") {
    exit(AgentTaskEnvelopeSelfTest.run() ? 0 : 1)
}
```

Add `test-task-envelopes` to `Makefile`:

```make
test-task-envelopes: build
	"$(MACOS_DIR)/$(APP_NAME)" --self-test-task-envelopes
```

Create a self-test that requires:

```swift
let envelope = AgentTaskEnvelope.sanitized(
    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
    originNodeID: "local-godexu",
    revision: 1,
    sourceTaskID: "codex-thread-1",
    sourceRuntime: .codex,
    projectID: "spicy",
    projectName: "Spicy",
    title: "Review daily package",
    targetNodeID: "nas-hermes",
    targetRuntime: .hermes,
    handoffNote: "Check evidence coverage.",
    state: .draft,
    createdAt: testDate,
    updatedAt: testDate
)
expect(envelope?.state == .draft, "valid draft should be accepted")
expect(
    AgentTaskEnvelopeState.allCases.map(\.rawValue) == ["draft", "ready"],
    "only local pre-delivery states should exist"
)
```

Also require:

- canonical UUID and safe source/node/project identifiers;
- safe origin node and positive monotonic revision;
- title maximum 160 characters;
- note maximum 400 characters and eight lines;
- empty title, unsafe ID, invalid time order, and oversized stored records fail;
- `ready` remains named `ready`, never queued/sent/delivered;
- Codex/Claude task details derive a bounded project label;
- OpenClaw/Hermes without canonical project metadata use runtime-scoped fallback;
- active tasks sort before pending/scheduled/done inside a project;
- projects sort by newest activity, then handoff update time;
- unclassified tasks from different runtimes do not merge.

- [ ] **Step 2: Verify RED**

Run:

```sh
make build
```

Expected: compile failure because `AgentTaskEnvelope`,
`AgentTaskEnvelopeState`, and `AgentProjectWorkspaceBuilder` do not exist.

- [ ] **Step 3: Implement the minimal envelope model**

Create:

```swift
enum AgentTaskEnvelopeState: String, CaseIterable, Codable, Equatable, Identifiable {
    case draft
    case ready
    var id: String { rawValue }
}

struct AgentTaskEnvelope: Identifiable, Codable, Equatable {
    static let maximumTitleLength = 160
    static let maximumNoteLength = 400
    static let maximumNoteLines = 8

    let id: UUID
    let originNodeID: String
    let revision: Int
    let sourceTaskID: String
    let sourceRuntime: RuntimeScope
    let projectID: String
    let projectName: String
    let title: String
    let targetNodeID: String
    let targetRuntime: RuntimeScope
    let handoffNote: String
    let state: AgentTaskEnvelopeState
    let createdAt: Date
    let updatedAt: Date

    static func sanitized(
        id: UUID,
        originNodeID: String,
        revision: Int,
        sourceTaskID: String,
        sourceRuntime: RuntimeScope,
        projectID: String,
        projectName: String,
        title: String,
        targetNodeID: String,
        targetRuntime: RuntimeScope,
        handoffNote: String,
        state: AgentTaskEnvelopeState,
        createdAt: Date,
        updatedAt: Date
    ) -> Self?
}
```

Normalize IDs to `[A-Za-z0-9._:-]`, bound IDs to 96 characters, collapse title
whitespace, preserve at most eight non-empty note lines, and reject
`updatedAt < createdAt` or `revision < 1`. Treat the UUID as the future
idempotency key; do not create a separate transport-specific identifier.

- [ ] **Step 4: Implement the pure project workspace**

Create:

```swift
struct AgentProjectIdentity: Identifiable, Equatable {
    let id: String
    let name: String
    let isDerived: Bool
}

struct AgentProjectWorkspace: Identifiable, Equatable {
    let identity: AgentProjectIdentity
    let tasks: [TaskItem]
    let envelopes: [AgentTaskEnvelope]
    let runtimes: [RuntimeScope]
    let lastActiveAt: Date?
    var id: String { identity.id }
}

enum AgentProjectWorkspaceBuilder {
    static func identity(for item: TaskItem) -> AgentProjectIdentity
    static func make(
        taskBoard: TaskBoard?,
        envelopes: [AgentTaskEnvelope]
    ) -> [AgentProjectWorkspace]
}
```

For Codex and Claude Code, use the bounded text before ` · ` when present. For
OpenClaw and Hermes, use a runtime-scoped workspace fallback because the
normalized task model does not expose a trustworthy canonical project ID.
Merge envelopes by stored project ID. Do not parse or retain paths.

- [ ] **Step 5: Verify GREEN**

Run:

```sh
make build
build/codexU.app/Contents/MacOS/codexU --self-test-task-envelopes
build/codexU.app/Contents/MacOS/codexU --self-test-task-navigation
```

Expected: the new self-test and existing navigation test pass.

- [ ] **Step 6: Commit the domain**

Enumerate all status paths and require the set difference against this task's
five files to be empty. Then:

```sh
git add \
  Sources/CodexUsageWidget/Domain/AgentTaskEnvelope.swift \
  Sources/CodexUsageWidget/Domain/AgentTaskEnvelopeSelfTest.swift \
  Sources/CodexUsageWidget/Domain/AgentProjectWorkspace.swift \
  Sources/CodexUsageWidget/main.swift \
  Makefile
git commit -m "feat: define local Agent task envelopes"
```

## Task 3: Strict Local Store RED/GREEN

**Files:**

- Modify: `Sources/CodexUsageWidget/Domain/AgentTaskEnvelopeSelfTest.swift`
- Create: `Sources/CodexUsageWidget/Services/AgentTaskEnvelopeStore.swift`

- [ ] **Step 1: Add failing store tests**

Use a temporary directory:

```swift
let store = AgentTaskEnvelopeStore(fileURL: temporaryURL)
try store.upsert(envelope)
let restored = AgentTaskEnvelopeStore(fileURL: temporaryURL)
expect(restored.envelopes == [envelope], "saved envelope should reload")
```

Require:

- missing file yields `[]`;
- upsert preserves one ID and replaces the matching record;
- updating preserves `originNodeID` and `createdAt`, and increments revision by
  exactly one;
- repeating an identical upsert at the same revision is idempotent;
- a skipped, stale, or conflicting revision is rejected;
- delete removes only the named UUID;
- deterministic ordering is newest `updatedAt` first;
- maximum 256 envelopes;
- unsupported schema, unknown document/profile key, duplicate UUID, malformed
  JSON, unsafe node/task/project ID, and invalid dates fail closed;
- serialized JSON contains no `queued`, `sent`, `delivered`, `accepted`,
  `running`, `credential`, `networkHost`, `command`, `stdout`, `stderr`,
  `summary`, or `recentReply` key.

- [ ] **Step 2: Verify RED**

Run:

```sh
make build
```

Expected: compile failure because `AgentTaskEnvelopeStore` does not exist.

- [ ] **Step 3: Implement the store**

Create:

```swift
final class AgentTaskEnvelopeStore: ObservableObject {
    @Published private(set) var envelopes: [AgentTaskEnvelope]
    let fileURL: URL

    init(fileURL: URL = Self.defaultFileURL())
    func upsert(_ envelope: AgentTaskEnvelope) throws
    func delete(id: UUID) throws
    static func defaultFileURL() -> URL
}
```

Persist:

```json
{
  "schema": "godexu-task-envelopes-v1",
  "envelopes": []
}
```

Use strict exact-key validation, ISO-8601 dates, sorted keys, pretty printing,
an atomic write, whole-document fail-closed loading, and the domain validator.
When replacing an existing ID, reject a changed `createdAt`.
Also reject a changed `originNodeID`; require either an identical idempotent
write at the current revision or a changed record at `current.revision + 1`.

- [ ] **Step 4: Verify GREEN and privacy**

Run:

```sh
make build
build/codexU.app/Contents/MacOS/codexU --self-test-task-envelopes
rg -n -i 'queued|sent|delivered|accepted|running|credential|networkHost|stdout|stderr' \
  Sources/CodexUsageWidget/Domain/AgentTaskEnvelope.swift \
  Sources/CodexUsageWidget/Services/AgentTaskEnvelopeStore.swift
```

Expected: tests pass. The source scan may contain forbidden words only inside
the self-test's negative assertions, never as stored fields or production
state.

- [ ] **Step 5: Commit the store**

```sh
git add \
  Sources/CodexUsageWidget/Domain/AgentTaskEnvelopeSelfTest.swift \
  Sources/CodexUsageWidget/Services/AgentTaskEnvelopeStore.swift
git commit -m "feat: persist local Agent handoff drafts"
```

## Task 4: Project-Hub Presentation RED/GREEN

**Files:**

- Modify: `Sources/CodexUsageWidget/Domain/AgentTaskEnvelopeSelfTest.swift`
- Create: `Sources/CodexUsageWidget/UI/AgentProjectHubView.swift`

- [ ] **Step 1: Add failing presentation tests**

Require a pure presentation:

```swift
let presentation = AgentProjectPresentation.make(
    workspace,
    nodes: nodes,
    profileStore: profileStore,
    language: .chinese,
    now: testDate
)
expect(presentation.title == "Spicy", "project title should be preserved")
expect(presentation.handoffCountText == "1 个交接", "handoff count should localize")
expect(
    presentation.envelopes.first?.deliveryNotice == "仅保存在本机，尚未投递",
    "ready state must not claim delivery"
)
```

Also require:

- task/source runtime labels;
- target node role and A/B/C policy;
- missing target node displays unavailable rather than inventing a node;
- no summary, recent reply, path, note, or credential appears in project
  overview accessibility text;
- all overview strings are bounded.

- [ ] **Step 2: Verify RED**

Run:

```sh
make build
```

Expected: compile failure because `AgentProjectPresentation` does not exist.

- [ ] **Step 3: Implement presentation and two-pane view**

Create `AgentProjectPresentation` and `AgentProjectHubView`.

The view receives:

```swift
let taskBoard: TaskBoard?
let envelopes: [AgentTaskEnvelope]
let nodes: [AgentNodeSnapshot]
@ObservedObject var profileStore: AgentIdentityProfileStore
let language: WidgetLanguage
```

It builds workspaces with `AgentProjectWorkspaceBuilder`, keeps one selected
project ID, and uses:

- a 190-point project list;
- a flexible detail pane;
- existing runtime logos, task badges, list-row backgrounds, and semantic
  colors;
- four compact metrics: active, done, Agents, handoffs;
- task rows that open the existing `TaskDetailView`;
- envelope rows that show target role, policy, state, relative time, and the
  local-only notice;
- content-bounded empty states.

Do not show task summaries, replies, handoff notes, or filesystem paths in the
hub.

- [ ] **Step 4: Verify GREEN**

Run:

```sh
make build
build/codexU.app/Contents/MacOS/codexU --self-test-task-envelopes
```

Expected: project presentation tests pass.

## Task 5: Task Detail Draft Editor

**Files:**

- Modify: `Sources/CodexUsageWidget/main.swift`
- Modify: `Sources/CodexUsageWidget/UI/AgentProjectHubView.swift`

- [ ] **Step 1: Own and route the stores**

Add one store beside the Phase 2A store:

```swift
@StateObject private var identityStore = AgentIdentityProfileStore()
@StateObject private var envelopeStore = AgentTaskEnvelopeStore()
```

Pass `nodeStore.snapshots`, `identityStore`, and `envelopeStore` through
`TaskBoardColumnView` and `TaskIssueCard` to `TaskDetailView`. Route the
Projects tab to:

```swift
AgentProjectHubView(
    taskBoard: combinedTaskBoard,
    envelopes: envelopeStore.envelopes,
    nodes: nodeStore.snapshots,
    profileStore: identityStore,
    envelopeStore: envelopeStore,
    language: language
)
```

Change the Projects tab label from “项目排行” to “项目” while retaining the
existing tab icon and shell.

- [ ] **Step 2: Add the local handoff editor**

Extend `TaskDetailView` with:

```swift
let nodes: [AgentNodeSnapshot]
@ObservedObject var profileStore: AgentIdentityProfileStore
@ObservedObject var envelopeStore: AgentTaskEnvelopeStore
```

Derive compatible targets from nodes whose runtime or node ID differs from the
source task. Add target picker, target role/policy, note editor, and two actions:

```swift
saveEnvelope(state: .draft)
saveEnvelope(state: .ready)
```

Use `AgentProjectWorkspaceBuilder.identity(for:)` for project identity. Reuse
an existing envelope with the same source task and target node when editing;
otherwise create a UUID with `originNodeID` resolved from the local node (or the
stable fallback `local-godexu`) and revision `1`. Editing increments revision
once. Always show:

```text
仅保存在本机，尚未投递
```

On validation or write failure, show a local understandable message that
contains no path or task body.

- [ ] **Step 3: Preserve existing task actions**

Verify the task-card primary action still opens detail, Codex tasks still show
`在 Codex 中打开`, progress still displays, and summary/recent reply remain
inside the detail sheet only.

Run:

```sh
make build
build/codexU.app/Contents/MacOS/codexU --self-test-task-envelopes
build/codexU.app/Contents/MacOS/codexU --self-test-task-navigation
build/codexU.app/Contents/MacOS/codexU --self-test-agent-identity
git diff --check
```

Expected: all checks pass.

- [ ] **Step 4: Commit the UI**

Enumerate the full status set and compare it to the UI task allowlist, then:

```sh
git add \
  Sources/CodexUsageWidget/Domain/AgentTaskEnvelopeSelfTest.swift \
  Sources/CodexUsageWidget/UI/AgentProjectHubView.swift \
  Sources/CodexUsageWidget/main.swift
git commit -m "feat: prepare Agent handoffs from project tasks"
```

## Task 6: Full Verification And Real UI Acceptance

**Files:**

- Modify: `CHANGELOG.md`
- Create: `docs/superpowers/runs/20260730-godexu-phase2b-project-handoff.md`

- [ ] **Step 1: Run a fresh optimized build**

Quit only the isolated worktree build if it is running, then:

```sh
make build
codesign --verify --deep --strict build/codexU.app
/usr/bin/plutil -lint Resources/Info.plist
```

Expected: optimized build, ad-hoc signature, strict verification, and plist
validation pass.

- [ ] **Step 2: Run the complete self-test denominator**

Run the binary with:

```text
statistics-time-zone
status-item
rate-limits
particle-animation
updates
task-navigation
local-system
agent-selection
agent-nodes
agent-identity
task-envelopes
codex-token-events
dynamic-island
display-surface
global-shortcut
```

Then:

```sh
CODEXU_SKIP_BUILD=1 ./scripts/test-parsers.sh
```

Expected: `15/15` built-in self-tests and `4/4` parser fixtures pass.

- [ ] **Step 3: Run real UI acceptance**

Launch the exact isolated app bundle and verify:

1. Projects opens a two-pane project hub using real observed tasks.
2. Selecting projects changes the task/handoff detail pane without overflow.
3. Opening a task preserves summary, progress, recent reply, and Codex deep
   link behavior.
4. A visible non-source target Agent can be selected.
5. Saving `draft` updates the correct project and says it remains local.
6. Marking `ready` still says it has not been delivered.
7. Closing and reopening the app reloads the envelope.
8. Deleting the acceptance envelope or restoring the pre-test file returns
   the machine to its original state.
9. Status item and Dynamic Island remain visually unchanged.

Capture the exact app path, source/target runtime, saved state, file schema,
reload result, cleanup result, and screenshots.

- [ ] **Step 4: Verify privacy and public outputs**

Run `--dump-agent-nodes` and `--dump-json`, then assert no envelope title,
handoff note, project ID, target node ID, role text, or task-envelope schema
appears. Inspect the local envelope JSON only for its approved exact keys.

Run:

```sh
git diff --check
git status --porcelain=v1
```

Expected: no diff errors and no out-of-scope paths.

- [ ] **Step 5: Record and commit the checkpoint**

Update `CHANGELOG.md` Unreleased and write the run record with:

- baseline and candidate commits;
- allowed/excluded paths;
- RED/GREEN evidence;
- automated denominator and failures;
- real UI denominator;
- local-store privacy result;
- test-artifact restoration;
- `execution_approval` from the user's “继续，别停”;
- `remote_write_approval: not granted`;
- `release_approval: not granted`;
- rollback instructions;
- Phase 2C remaining work.

Enumerate the exact final status set, require an empty allowlist difference, and
commit:

```sh
git add CHANGELOG.md docs/superpowers/runs/20260730-godexu-phase2b-project-handoff.md
git commit -m "docs: record project handoff acceptance"
```

Do not install, push, create a PR, merge, tag, release, or write NAS state.
Do not install an MCP SDK, start an MCP server, open a port, or edit any Codex,
OpenClaw, Hermes, or Claude MCP configuration.
