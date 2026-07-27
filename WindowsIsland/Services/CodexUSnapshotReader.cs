namespace CodexUIsland.Services;

using System;
using System.IO;
using System.Text.Json;
using CodexUIsland.Core;

public static class CodexUSnapshotReader
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public static CodexUSnapshot Load()
    {
        var configuredPath = Environment.GetEnvironmentVariable("CODEXU_ISLAND_SNAPSHOT");
        var path = !string.IsNullOrWhiteSpace(configuredPath)
            ? configuredPath
            : Path.Combine(AppContext.BaseDirectory, "sample-status.json");

        try
        {
            if (!File.Exists(path)) return CodexUSnapshot.Sample();
            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<CodexUSnapshot>(json, Options) ?? CodexUSnapshot.Sample();
        }
        catch
        {
            return CodexUSnapshot.Sample();
        }
    }
}
