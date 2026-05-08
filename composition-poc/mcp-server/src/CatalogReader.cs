using System.Text.Json;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace CatalogMcpServer;

public interface ICatalogReader
{
    Task<IReadOnlyList<CatalogItem>> ListItemsAsync(CancellationToken cancellationToken = default);
}

internal static class ManifestParser
{
    private static readonly IDeserializer YamlDeserializer = new DeserializerBuilder()
        .WithNamingConvention(CamelCaseNamingConvention.Instance)
        .IgnoreUnmatchedProperties()
        .Build();

    public static readonly string[] ManifestFileNames = { "manifest.yaml", "manifest.yml", "manifest.json" };

    public static object? Parse(string fileName, string raw)
    {
        var ext = Path.GetExtension(fileName).ToLowerInvariant();
        if (ext is ".yaml" or ".yml")
        {
            return YamlDeserializer.Deserialize<object?>(raw);
        }
        if (ext == ".json")
        {
            return JsonSerializer.Deserialize<JsonElement>(raw);
        }
        return raw;
    }

    public static string Format(string fileName)
        => Path.GetExtension(fileName).TrimStart('.').ToLowerInvariant();
}

public sealed record CatalogItem(
    string Id,
    string ManifestPath,
    string ManifestFormat,
    string RawManifest,
    object? Manifest);
