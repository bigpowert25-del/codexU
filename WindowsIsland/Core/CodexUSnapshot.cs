namespace CodexUIsland.Core;

using System;
using System.Collections.Generic;
using System.Linq;

public sealed class CodexUSnapshot
{
    public DateTimeOffset RefreshedAt { get; init; } = DateTimeOffset.Now;
    public CodexStatus Codex { get; init; } = new();
    public List<AgentStatus> Agents { get; init; } = [];
    public LocalSystemStatus System { get; init; } = new();
    public List<IslandEvent> Events { get; init; } = [];

    public string TitleText()
    {
        var quota = Codex.Quota?.FiveHourPercent is double percent
            ? $"{percent:0}%"
            : "--";
        return $"Codex {quota}";
    }

    public string BodyText()
    {
        var agents = Agents.Count == 0
            ? "agents --"
            : string.Join(" · ", Agents.Select(agent => $"{agent.DisplayNameOrId()} {agent.Status}"));
        return $"Token {Compact(Codex.TodayTokens)} · CPU {Percent(System.CpuPercent)} · Mem {Percent(System.MemoryPercent)} · {agents}";
    }

    public static CodexUSnapshot Sample() => new()
    {
        RefreshedAt = DateTimeOffset.Now,
        Codex = new CodexStatus
        {
            TodayTokens = 313_600_000,
            ActiveTasks = 5,
            AttentionTasks = 1,
            Quota = new CodexQuota { FiveHourPercent = 42, SevenDayPercent = 64 }
        },
        Agents =
        [
            new AgentStatus { Id = "openclaw", Name = "OpenClaw", Source = "nas", Status = "running", TodayTokens = 7_100_000 },
            new AgentStatus { Id = "hermes", Name = "Hermes", Source = "nas", Status = "running", TodayTokens = 420_000 }
        ],
        System = new LocalSystemStatus
        {
            CpuPercent = 38,
            MemoryPercent = 72,
            ThermalState = "nominal"
        },
        Events =
        [
            new IslandEvent { Kind = "attention", Source = "codex", Title = "Needs input", UpdatedAt = DateTimeOffset.Now }
        ]
    };

    private static string Percent(double? value) => value is double number ? $"{number:0}%" : "--";

    private static string Compact(long? value)
    {
        if (value is null) return "--";
        var number = (double)value.Value;
        if (Math.Abs(number) >= 1_000_000_000) return $"{number / 1_000_000_000:0.0}B";
        if (Math.Abs(number) >= 1_000_000) return $"{number / 1_000_000:0.0}M";
        if (Math.Abs(number) >= 1_000) return $"{number / 1_000:0.0}K";
        return value.Value.ToString();
    }
}

public sealed class CodexStatus
{
    public CodexQuota? Quota { get; init; }
    public long? TodayTokens { get; init; }
    public int ActiveTasks { get; init; }
    public int AttentionTasks { get; init; }
}

public sealed class CodexQuota
{
    public double? FiveHourPercent { get; init; }
    public double? SevenDayPercent { get; init; }
}

public sealed class AgentStatus
{
    public string Id { get; init; } = "";
    public string? Name { get; init; }
    public string Source { get; init; } = "local";
    public string Status { get; init; } = "unknown";
    public long? TodayTokens { get; init; }

    public string DisplayNameOrId() => string.IsNullOrWhiteSpace(Name) ? Id : Name!;
}

public sealed class LocalSystemStatus
{
    public double? CpuPercent { get; init; }
    public double? MemoryPercent { get; init; }
    public string? ThermalState { get; init; }
    public double? TemperatureC { get; init; }
}

public sealed class IslandEvent
{
    public string Kind { get; init; } = "";
    public string Source { get; init; } = "";
    public string Title { get; init; } = "";
    public DateTimeOffset? UpdatedAt { get; init; }
}
