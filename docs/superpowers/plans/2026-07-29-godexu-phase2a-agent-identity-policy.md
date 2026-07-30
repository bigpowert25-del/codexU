# GodexU v2 Phase 2A Agent Identity And Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add locally editable Agent roles and fail-closed A/B/C policy metadata to the existing GodexU node cards without performing remote actions.

**Architecture:** A small Codable domain model provides deterministic runtime defaults and validation. A versioned atomic Application Support store persists node-specific overrides. Existing node cards become buttons that open a draft-based SwiftUI detail sheet; profile data stays outside all public diagnostic JSON.

**Tech Stack:** Swift 6 command-line compilation, SwiftUI/AppKit, Foundation JSON, existing codexU self-test entry points.

---

## Allowed Paths

- `Sources/CodexUsageWidget/Domain/AgentIdentityProfile.swift`
- `Sources/CodexUsageWidget/Domain/AgentIdentityProfileSelfTest.swift`
- `Sources/CodexUsageWidget/Services/AgentIdentityProfileStore.swift`
- `Sources/CodexUsageWidget/UI/AgentNodeViews.swift`
- `Sources/CodexUsageWidget/main.swift`
- `Makefile`
- `CHANGELOG.md`
- `docs/superpowers/specs/2026-07-29-godexu-phase2a-agent-identity-policy-design.md`
- `docs/superpowers/plans/2026-07-29-godexu-phase2a-agent-identity-policy.md`
- `docs/superpowers/runs/20260729-godexu-phase2a-agent-identity-policy.md`

All other paths are excluded. No NAS, node configuration, provider, token, task, memory, update, Dynamic Island, status-item, Windows, version, release, or GitHub state may change.

### Task 1: Baseline And Design Receipt

- [ ] **Step 1: Record isolation and baseline**

Run:

```sh
git rev-parse --git-dir
git rev-parse --git-common-dir
git branch --show-current
git status --porcelain
```

Expected: linked worktree on `codex/dynamic-island-local-prototype`; only the Phase 2A design and plan are untracked.

- [ ] **Step 2: Re-run the existing node baseline**

Run:

```sh
build/codexU.app/Contents/MacOS/codexU --self-test-agent-nodes
CODEXU_SKIP_BUILD=1 ./scripts/test-parsers.sh
git diff --check
```

Expected: node test and four parser fixtures pass, zero diff errors.

- [ ] **Step 3: Commit the approved design and plan**

Stage only the two Phase 2A docs, verify the allowlist difference is empty, and commit:

```sh
git commit -m "docs: define GodexU Agent identity phase"
```

### Task 2: Agent Identity Domain RED/GREEN

**Files:**

- Create: `Sources/CodexUsageWidget/Domain/AgentIdentityProfileSelfTest.swift`
- Create after RED: `Sources/CodexUsageWidget/Domain/AgentIdentityProfile.swift`
- Modify: `Sources/CodexUsageWidget/main.swift`
- Modify: `Makefile`

- [ ] **Step 1: Write the failing self-test**

Create a test entry point that requires:

```swift
let profile = AgentIdentityProfile.defaultProfile(
    nodeID: "local-codex",
    runtime: .codex,
    now: Date(timeIntervalSince1970: 1_000)
)
precondition(profile.roleName == "Build & execute")
precondition(profile.policyLevel == .guarded)
precondition(AgentPolicyLevel.allCases.map(\.rawValue) == ["a", "b", "c"])
```

Also assert deterministic defaults for OpenClaw, Claude Code, and Hermes; role-name/summary trimming; maximum lengths; newline handling; invalid empty role rejection; and runtime/node identity preservation.

Register `--self-test-agent-identity` in `main.swift` and `test-agent-identity` in `Makefile`.

- [ ] **Step 2: Verify RED**

Run:

```sh
make build
```

Expected: compile failure because `AgentIdentityProfile` and `AgentPolicyLevel` do not exist.

- [ ] **Step 3: Implement the minimal domain model**

Create:

```swift
enum AgentPolicyLevel: String, CaseIterable, Codable, Equatable, Identifiable {
    case guarded = "a"
    case collaborative = "b"
    case flexible = "c"
    var id: String { rawValue }
}

struct AgentIdentityProfile: Identifiable, Codable, Equatable {
    let nodeID: String
    let runtime: RuntimeScope
    let roleName: String
    let responsibility: String
    let policyLevel: AgentPolicyLevel
    let updatedAt: Date
    var id: String { nodeID }

    static func defaultProfile(nodeID: String, runtime: RuntimeScope, now: Date) -> Self
    static func sanitized(
        nodeID: String,
        runtime: RuntimeScope,
        roleName: String,
        responsibility: String,
        policyLevel: AgentPolicyLevel,
        updatedAt: Date
    ) -> Self?
}
```

Use English canonical default data in the model and localize only presentation text. Clamp role names to 32 characters and responsibilities to 120 characters after trimming; convert role-name line breaks to spaces and allow at most three responsibility lines.

- [ ] **Step 4: Verify GREEN**

Run:

```sh
make build
build/codexU.app/Contents/MacOS/codexU --self-test-agent-identity
```

Expected: build succeeds and prints `agent identity self-test passed`.

- [ ] **Step 5: Commit**

Commit only the domain, test, Makefile, and CLI registration:

```sh
git commit -m "feat: define Agent identity policies"
```

### Task 3: Local Profile Store RED/GREEN

**Files:**

- Modify: `Sources/CodexUsageWidget/Domain/AgentIdentityProfileSelfTest.swift`
- Create: `Sources/CodexUsageWidget/Services/AgentIdentityProfileStore.swift`

- [ ] **Step 1: Add failing store tests**

Use a temporary directory and require:

```swift
let store = AgentIdentityProfileStore(fileURL: temporaryURL)
try store.save(customProfile)
let restored = store.profile(
    nodeID: "nas-hermes",
    runtime: .hermes,
    now: testDate
)
precondition(restored == customProfile)
```

Also require:

- a missing file returns the runtime default at A;
- save/reload is deterministic;
- reset removes the override and returns the default;
- a node/runtime mismatch is ignored;
- duplicate node records fail closed;
- unsupported schema and malformed JSON fail closed;
- maximum 32 overrides;
- the stored document contains no SSH alias, network host, command, output, credential, or path field.

- [ ] **Step 2: Verify RED**

Run:

```sh
make build
```

Expected: compile failure because `AgentIdentityProfileStore` does not exist.

- [ ] **Step 3: Implement the store**

Implement:

```swift
final class AgentIdentityProfileStore: ObservableObject {
    @Published private(set) var overrides: [String: AgentIdentityProfile]

    init(fileURL: URL = Self.defaultFileURL())
    func profile(nodeID: String, runtime: RuntimeScope, now: Date) -> AgentIdentityProfile
    func save(_ profile: AgentIdentityProfile) throws
    func reset(nodeID: String) throws
}
```

Persist `{"schema":"godexu-agent-profiles-v1","profiles":[...]}` with sorted keys and ISO-8601 dates using `.atomic`. Decode the whole document strictly; any invalid document yields an empty override set.

- [ ] **Step 4: Verify GREEN and privacy**

Run:

```sh
make build
build/codexU.app/Contents/MacOS/codexU --self-test-agent-identity
```

Expected: all domain/store checks pass.

- [ ] **Step 5: Commit**

```sh
git commit -m "feat: persist local Agent profiles"
```

### Task 4: Node-Card Presentation RED/GREEN

**Files:**

- Modify: `Sources/CodexUsageWidget/Domain/AgentIdentityProfileSelfTest.swift`
- Modify: `Sources/CodexUsageWidget/UI/AgentNodeViews.swift`

- [ ] **Step 1: Add failing presentation tests**

Require a pure `AgentIdentityPresentation.make(profile:language:)` result with:

- localized role and policy label;
- A/B/C policy symbol;
- localized warning that policy metadata grants no execution permission;
- bounded accessibility text;
- fallback to canonical custom role text without leaking paths.

- [ ] **Step 2: Verify RED**

Run:

```sh
make build
```

Expected: compile failure because presentation types do not exist.

- [ ] **Step 3: Implement presentation and card badge**

Add `profile` to each node presentation. Make each tile a plain button with a trailing `A`, `B`, or `C` badge plus chevron while retaining the health icon/text and equal-height card layout.

- [ ] **Step 4: Verify GREEN**

Run:

```sh
make build
build/codexU.app/Contents/MacOS/codexU --self-test-agent-identity
build/codexU.app/Contents/MacOS/codexU --self-test-agent-nodes
```

Expected: both tests pass.

### Task 5: Agent Detail Editor

**Files:**

- Modify: `Sources/CodexUsageWidget/UI/AgentNodeViews.swift`
- Modify: `Sources/CodexUsageWidget/main.swift`

- [ ] **Step 1: Connect the profile store**

Create one `@StateObject` profile store in `UsageWidgetView`, pass it to `AgentNodeStatusSection`, and do not couple it to the remote polling lifecycle.

- [ ] **Step 2: Add the detail sheet**

Implement `AgentIdentityDetailView` with:

- runtime logo, node/device label, and current health;
- editable role name and responsibility;
- segmented A/B/C picker with the selected-level description;
- read-only capability chips;
- local-only / no-execution notice;
- Cancel, Reset, and Save;
- inline validation/save error;
- fixed width around 520 points and content-driven height.

The sheet edits a draft. Save calls `AgentIdentityProfile.sanitized` then the store; Reset restores the runtime default; Cancel dismisses without mutation.

- [ ] **Step 3: Build and targeted smoke**

Run:

```sh
make build
build/codexU.app/Contents/MacOS/codexU --self-test-agent-identity
build/codexU.app/Contents/MacOS/codexU --self-test-agent-nodes
git diff --check
```

Expected: all checks pass.

- [ ] **Step 4: Commit**

```sh
git commit -m "feat: edit Agent roles from node cards"
```

### Task 6: Full Verification And Real UI Acceptance

- [ ] **Step 1: Run all built-in tests**

Build once, then run:

```sh
for name in statistics-time-zone status-item rate-limits particle-animation updates \
  task-navigation local-system agent-selection agent-nodes agent-identity \
  codex-token-events dynamic-island display-surface global-shortcut; do
  build/codexU.app/Contents/MacOS/codexU "--self-test-$name"
done
```

Expected: 14/14 pass.

- [ ] **Step 2: Run parser and privacy checks**

Run parser fixtures, plist lint, strict codesign, JSON validation, the existing public node JSON exclusion assertion, Phase 2A path/secret scans, and `git diff --check`.

- [ ] **Step 3: Real UI acceptance**

Launch the worktree app and verify with Computer Use:

- three node cards show A and are clickable;
- Codex defaults to Build & execute, OpenClaw to Coordinate, Hermes to Analyze & review;
- edit Hermes role and set B, save, close, reopen, and confirm persistence;
- Reset restores Hermes to A/default;
- Cancel does not save;
- long text validates/truncates without layout overflow;
- main dashboard, status item, and Dynamic Island still open.

Use a temporary profile file or restore the user's original profile file after the acceptance run.

- [ ] **Step 4: No-NAS acceptance**

With an injected or temporary empty remote-node configuration, verify the local Codex card still opens and edits normally. Restore the original node configuration before final reporting.

### Task 7: Run Record And Handoff

- [ ] **Step 1: Update Unreleased changelog**

Record the local Agent identity editor, A/B/C fail-closed semantics, and absence of execution authority.

- [ ] **Step 2: Write run record**

Create `docs/superpowers/runs/20260729-godexu-phase2a-agent-identity-policy.md` with:

- baseline and candidate commits;
- exact allowed paths and empty set-difference receipts;
- RED/GREEN evidence;
- 14/14 tests, parser/build/privacy/UI results;
- local profile backup/restore evidence;
- explicit `NAS writes: not performed`;
- `release_status: not_authorized`;
- next phase choices: project aggregation or task-envelope/outbox protocol.

- [ ] **Step 3: Final allowlist and clean-tree review**

Enumerate staged, unstaged, deleted, renamed, and untracked paths; stop if any path is outside the allowlist. Run `git diff --check` and inspect the complete commit series.

- [ ] **Step 4: Do not push**

The prior push authorization covered the Phase 1 candidate only. Keep Phase 2A local until the user reviews the actual result and explicitly authorizes this changed diff.
