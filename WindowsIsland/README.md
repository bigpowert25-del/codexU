# codexU Island for Windows

A small local Windows Dynamic Island prototype for showing Codex / OpenClaw / Hermes status.

This folder is a local prototype copied from the MIT-licensed WPF project `sadeeshasathsara/dynamic-island-on-windows`, then adapted for codexU. The original MIT license is kept in `LICENSE`.

## What it shows

- Codex quota and today's token total.
- OpenClaw / Hermes status from a local JSON snapshot.
- CPU, memory, and thermal fields when present in the snapshot.
- Optional Windows notifications when launched with `--notifications`.

## Local snapshot

By default the app reads `sample-status.json` from the app folder.

To point it at a real local snapshot:

```powershell
$env:CODEXU_ISLAND_SNAPSHOT="C:\path\to\codexu-status.json"
dotnet run --project .\CodexUIsland.csproj
```

The snapshot format is:

```json
{
  "refreshedAt": "2026-07-27T09:30:00+08:00",
  "codex": {
    "quota": {"fiveHourPercent": 42, "sevenDayPercent": 64},
    "todayTokens": 313600000,
    "activeTasks": 5,
    "attentionTasks": 1
  },
  "agents": [
    {"id": "openclaw", "name": "OpenClaw", "source": "nas", "status": "running", "todayTokens": 7100000},
    {"id": "hermes", "name": "Hermes", "source": "nas", "status": "running", "todayTokens": 420000}
  ],
  "system": {"cpuPercent": 38, "memoryPercent": 72, "thermalState": "nominal", "temperatureC": null},
  "events": [{"kind": "attention", "source": "codex", "title": "Needs input"}]
}
```

## Build on Windows

Requirements:

- Windows 11 build 22621 or later.
- .NET 8 SDK.

Commands:

```powershell
cd WindowsIsland
dotnet build .\CodexUIsland.csproj
dotnet run --project .\CodexUIsland.csproj
```

Notification listening is disabled by default so the local status pill opens without asking for notification permission. To test the inherited notification behavior:

```powershell
dotnet run --project .\CodexUIsland.csproj -- --notifications
```

## Attribution

- Original Windows base: `sadeeshasathsara/dynamic-island-on-windows`
- Original license: MIT, preserved in `LICENSE`
- codexU adaptation: local snapshot model, default status display, codexU naming, and notification opt-in behavior
