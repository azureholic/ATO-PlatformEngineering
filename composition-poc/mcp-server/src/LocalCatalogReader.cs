namespace CatalogMcpServer;

public sealed class LocalCatalogReader(CatalogOptions options, ILogger<LocalCatalogReader> logger) : ICatalogReader
{
    public Task<IReadOnlyList<CatalogItem>> ListItemsAsync(CancellationToken cancellationToken = default)
    {
        var root = options.LocalPath ?? Path.Combine(AppContext.BaseDirectory, "catalog");
        if (!Directory.Exists(root))
        {
            logger.LogWarning("Catalog directory {Path} does not exist.", root);
            return Task.FromResult<IReadOnlyList<CatalogItem>>(Array.Empty<CatalogItem>());
        }

        var items = new List<CatalogItem>();
        foreach (var dir in Directory.EnumerateDirectories(root))
        {
            var manifestPath = ManifestParser.ManifestFileNames
                .Select(n => Path.Combine(dir, n))
                .FirstOrDefault(File.Exists);
            if (manifestPath is null) continue;

            try
            {
                var raw = File.ReadAllText(manifestPath);
                items.Add(new CatalogItem(
                    Id: Path.GetFileName(dir),
                    ManifestPath: Path.GetRelativePath(root, manifestPath).Replace('\\', '/'),
                    ManifestFormat: ManifestParser.Format(manifestPath),
                    RawManifest: raw,
                    Manifest: ManifestParser.Parse(manifestPath, raw)));
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to read manifest at {Path}", manifestPath);
            }
        }

        IReadOnlyList<CatalogItem> result = items
            .OrderBy(i => i.Id, StringComparer.OrdinalIgnoreCase)
            .ToList();
        return Task.FromResult(result);
    }
}
