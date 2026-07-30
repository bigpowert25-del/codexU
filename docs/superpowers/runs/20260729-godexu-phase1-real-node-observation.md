# GodexU Phase 1 real-node observation run

- Date: 2026-07-29 Asia/Shanghai
- Baseline: `2f6d550`
- Accepted implementation: `62acc4f`
- Public review candidate: `b48c7c3`
- Installed version: `1.2.0`
- Scope: local Codex plus read-only NAS OpenClaw and Hermes observation

## Status

| Dimension | Status | Evidence |
| --- | --- | --- |
| Implementation | passed | Node model, strict local configuration, fixed SSH probes, cache fallback, dashboard cards, and native network preflight are committed. |
| Local verification | passed | 13/13 built-in self-tests, 4/4 runtime parser fixtures, optimized build, strict code-sign verification, plist validation, and diff checks passed. |
| Terminal-to-NAS read-only acceptance | passed | 3/3 nodes returned; OpenClaw and Hermes each had one running process and correctly reported `degraded` because their heartbeat sources were stale. |
| Installed app | passed | `/Applications/codexU.app` matches the optimized build executable hash and remains version `1.2.0`. |
| GUI live NAS observation | partial | Native preflight returned macOS local-network denial. The UI correctly showed cached state plus `允许局域网`; it did not promote cache to live health. |
| NAS writes | not performed | All NAS checks were read-only process and file-modification-time probes. |
| GitHub branch / Draft PR | passed | Public fork branch and [Draft PR #1](https://github.com/bigpowert25-del/codexU/pull/1) were read back at candidate `b48c7c3`; the PR includes the root cause, privacy boundary, verification, current screenshot, and open-source attribution. |
| Release / formal signing | blocked | No tag, GitHub Release, or DMG upload was performed. This Mac has no Apple-issued Developer ID Application identity, so a broadly distributed signed/notarized build cannot be produced here yet. |

## Real-node result

- Local Codex: available in the Terminal acceptance probe.
- NAS OpenClaw: process count `1`; heartbeat source old; health `degraded`.
- NAS Hermes: process count `1`; heartbeat source old; health `degraded`.
- Failure simulation: both remote nodes fell back to a cache younger than 24
  hours, marked `stale` and `isFromCache=true`.
- Public JSON excluded SSH aliases, network hosts, probe profiles, commands,
  stdout, stderr, environment data, credentials, and key paths.

## macOS permission finding

The same signed app binary can reach the NAS when invoked from Terminal, while
the GUI app receives local-network denial. The app now:

1. declares `NSLocalNetworkUsageDescription`;
2. uses an optional validated `networkHost` for native TCP preflight;
3. distinguishes local-network denial from timeout, authentication, host-key,
   name-resolution, connection-close, process-launch, protocol, and generic
   transport failures;
4. keeps showing last-known cache without calling it live.

No Apple-issued code-signing identity is installed on this Mac. Reliable GUI
live polling is therefore blocked on a Developer ID signing/notarization
decision, not on NAS availability or the SSH probe itself.

## UI acceptance

- Existing CodexU dashboard style is preserved.
- Agent node cards appear after the local CPU, memory, and thermal strip.
- Status-bar runtime selection remains Codex plus the selected companion.
- Dynamic Island compact and expanded modes remain unchanged.
- The installed GUI visibly distinguishes `缓存 · 允许局域网`.

## Rollback

- Installed-app backups were preserved under:
  `~/Library/Application Support/codexU/Backups/Applications-20260729/`
- Local node configuration:
  `~/Library/Application Support/codexU/nodes.json`
- Removing or renaming the local node configuration returns the app to a
  local-Codex-only node section.
