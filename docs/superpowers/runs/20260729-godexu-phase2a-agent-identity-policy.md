# GodexU Phase 2A Agent identity and policy run

## Identity and boundary

- Run ID: `godexu-phase2a-agent-identity-policy-20260729`
- Date: 2026-07-29 Asia/Shanghai
- Baseline: `701184c`
- Implementation commits: `4d818d3`, `6df1d88`, `e25b7e5`
- Goal: make existing Agent node cards the local identity and policy entry
  point for the future GodexU multi-Agent control plane.
- Allowed implementation: local role, responsibility, A/B/C policy, native
  detail UI, strict local persistence, and regression coverage.
- Excluded: task delivery, NAS writes, repair, shared-memory synchronization,
  credentials, version bump, release assets, installed-app replacement, and
  GitHub push.

## Result

The existing CodexU dashboard remains the primary node-management surface.
Each Codex, OpenClaw, Claude Code, or Hermes node card can now open a native
identity sheet containing:

- an editable role name;
- an editable responsibility summary;
- A / B / C policy selection;
- the node's declared capabilities;
- an explicit notice that this phase grants no task-delivery, repair, or
  remote-action authority.

Default roles are deterministic:

| Runtime | Default role | Default responsibility |
| --- | --- | --- |
| Codex | Build & execute | Research, implement, verify, and deliver |
| OpenClaw | Coordinate | Maintain context, orchestrate work, and coordinate nodes |
| Claude Code | Code collaboration | Collaborate on local coding sessions and implementation |
| Hermes | Analyze & review | Analyze independently, research, and review results |

The Chinese UI renders localized defaults while preserving user-authored role
and responsibility text.

## Policy semantics

| Level | Current behavior |
| --- | --- |
| A / Guarded | Observe, analyze, and advise without external actions. |
| B / Collaborative | May prepare task and handoff drafts. Actual delivery is not implemented or authorized. |
| C / Flexible | Reserved for future user-defined rules. It grants no additional permission in Phase 2A. |

## Persistence and privacy

- Local store:
  `~/Library/Application Support/codexU/agent-profiles.json`
- Schema: `godexu-agent-profiles-v1`
- Maximum stored profiles: 32.
- Node identifiers, role lengths, responsibility lengths, schema keys,
  duplicate entries, and runtime matches are validated fail-closed.
- Writes are sorted and atomic.
- The public `--dump-agent-nodes` path does not serialize identity profiles.
- The store contains no SSH host, address, command, output, credential, key
  path, or remote-action field.

## TDD evidence

RED:

1. Identity tests failed because the policy and profile model did not exist.
2. Store tests failed because persistence, strict decoding, reset, and privacy
   behavior did not exist.
3. Presentation tests failed because localized defaults and policy copy did
   not exist.

GREEN:

- Identity defaults, sanitization, A/B/C coding, strict local persistence,
  reset, localized presentation, and bounded accessibility text all passed.
- Existing node presentation tests continued to pass after identity data was
  added.

## Verification

Automated denominator: `15`.

- Passed: `15/15`.
- Failed: `0/15`.
- Unverified: `0/15`.

Passed checks:

1. Statistics time-zone self-test.
2. Status-item self-test.
3. Rate-limit self-test.
4. Particle-animation self-test.
5. Update self-test.
6. Task-navigation self-test.
7. Local-system self-test.
8. Agent-selection self-test.
9. Agent-node self-test.
10. Agent-identity self-test.
11. Codex-token-event self-test.
12. Dynamic-Island self-test.
13. Display-surface self-test.
14. Global-shortcut self-test.
15. Codex, OpenClaw, Claude Code, and Hermes parser fixtures.

Additional verification:

- Optimized `make build`: passed.
- Ad-hoc code signing and strict signature verification: passed.
- `Info.plist` validation: passed.
- `git diff --check`: passed.
- Real node dump: `3/3` nodes returned for Codex, OpenClaw, and Hermes.
- Public node dump privacy scan: `0` identity or credential-field hits.

## Real UI acceptance

Acceptance denominator: `5`.

- Passed: `5/5`.
- Failed: `0/5`.
- Unverified: `0/5`.

Passed flows:

1. Existing node cards remained visible and clickable without changing the
   dashboard, status bar, or Dynamic Island navigation.
2. Hermes role changed from `分析复核` to `质量复核` and policy changed from
   A to B.
3. Saving updated the Hermes card immediately.
4. Closing and reopening the detail sheet returned `质量复核` and B from the
   local store.
5. Reset restored `分析复核` and A; a subsequent temporary edit followed by
   Cancel was not persisted.

The empty acceptance-test profile store was removed after verification, so the
user's machine returned to the original default-profile state.

## Status

| Dimension | Status | Evidence |
| --- | --- | --- |
| Implementation | passed | Model, store, presentation, card entry point, and detail sheet implemented. |
| Local verification | passed | 15/15 automated checks plus build, signing, plist, diff, live dump, and privacy checks passed. |
| End-to-end UI | passed | 5/5 save, readback, reset, and cancel flows passed in the built app. |
| NAS / cross-device | not performed | Existing remote nodes were only observed through the established read-only path. |
| Installed app | not modified | Phase 2A was accepted from the isolated worktree build; `/Applications/codexU.app` was not replaced. |
| GitHub | not pushed | The current Phase 2A diff has no fresh remote-write authorization. |
| Release | not authorized | No version bump, tag, DMG, notarization, or release was performed. |

## Rollback

- Source: revert commits `e25b7e5`, `6df1d88`, and `4d818d3`.
- Local identity overrides: use `恢复默认` per node, or remove the local
  `agent-profiles.json` store while codexU is not running.
- No NAS rollback is required because Phase 2A performed no NAS writes.
