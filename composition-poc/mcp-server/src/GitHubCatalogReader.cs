using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json.Serialization;

namespace CatalogMcpServer;

public sealed class GitHubCatalogReader(
    CatalogOptions options,
    IHttpClientFactory httpClientFactory,
    ILogger<GitHubCatalogReader> logger) : ICatalogReader
{
    public const string HttpClientName = "github-catalog";

    public async Task<IReadOnlyList<CatalogItem>> ListItemsAsync(CancellationToken cancellationToken = default)
    {
        var gh = options.GitHub;
        var http = httpClientFactory.CreateClient(HttpClientName);

        var path = (gh.Path ?? string.Empty).Trim('/');
        var dirUrl = $"https://api.github.com/repos/{gh.Owner}/{gh.Repo}/contents/{path}?ref={Uri.EscapeDataString(gh.Branch)}";
        List<GitHubContentEntry>? entries;
        try
        {
            entries = await http.GetFromJsonAsync<List<GitHubContentEntry>>(dirUrl, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to list GitHub directory {Url}", dirUrl);
            return Array.Empty<CatalogItem>();
        }

        if (entries is null)
        {
            return Array.Empty<CatalogItem>();
        }

        var items = new List<CatalogItem>();
        foreach (var entry in entries.Where(e => e.Type == "dir"))
        {
            var item = await TryReadItemAsync(http, gh, entry, cancellationToken);
            if (item is not null)
            {
                items.Add(item);
            }
        }

        return items
            .OrderBy(i => i.Id, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private async Task<CatalogItem?> TryReadItemAsync(
        HttpClient http,
        GitHubCatalogOptions gh,
        GitHubContentEntry dirEntry,
        CancellationToken cancellationToken)
    {
        var subUrl = $"https://api.github.com/repos/{gh.Owner}/{gh.Repo}/contents/{dirEntry.Path}?ref={Uri.EscapeDataString(gh.Branch)}";
        List<GitHubContentEntry>? subEntries;
        try
        {
            subEntries = await http.GetFromJsonAsync<List<GitHubContentEntry>>(subUrl, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to list GitHub directory {Url}", subUrl);
            return null;
        }

        if (subEntries is null) return null;

        var manifest = ManifestParser.ManifestFileNames
            .Select(n => subEntries.FirstOrDefault(e =>
                e.Type == "file" && string.Equals(e.Name, n, StringComparison.OrdinalIgnoreCase)))
            .FirstOrDefault(e => e is not null);

        if (manifest is null || string.IsNullOrEmpty(manifest.DownloadUrl))
        {
            return null;
        }

        try
        {
            var raw = await http.GetStringAsync(manifest.DownloadUrl, cancellationToken);
            return new CatalogItem(
                Id: dirEntry.Name,
                ManifestPath: manifest.Path,
                ManifestFormat: ManifestParser.Format(manifest.Name),
                RawManifest: raw,
                Manifest: ManifestParser.Parse(manifest.Name, raw));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to download manifest {Url}", manifest.DownloadUrl);
            return null;
        }
    }

    public static void ConfigureHttpClient(HttpClient client, CatalogOptions options)
    {
        client.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("catalog-mcp-server", "1.0"));
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/vnd.github+json"));
        client.DefaultRequestHeaders.Add("X-GitHub-Api-Version", "2022-11-28");
        if (!string.IsNullOrWhiteSpace(options.GitHub.Token))
        {
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", options.GitHub.Token);
        }
    }

    private sealed record GitHubContentEntry
    {
        [JsonPropertyName("name")] public string Name { get; init; } = "";
        [JsonPropertyName("path")] public string Path { get; init; } = "";
        [JsonPropertyName("type")] public string Type { get; init; } = "";
        [JsonPropertyName("download_url")] public string? DownloadUrl { get; init; }
    }
}
