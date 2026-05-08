using System.ComponentModel;
using ModelContextProtocol.Server;

namespace CatalogMcpServer.Tools;

[McpServerToolType]
public sealed class CatalogTools(ICatalogReader reader)
{
    [McpServerTool(Name = "list_catalog_items")]
    [Description("List every catalog item discovered in the catalog source, returning their parsed manifests.")]
    public async Task<IReadOnlyList<CatalogItem>> ListCatalogItemsAsync(CancellationToken cancellationToken)
        => await reader.ListItemsAsync(cancellationToken);

    [McpServerTool(Name = "get_catalog_item")]
    [Description("Get a single catalog item by its id (the catalog folder name).")]
    public async Task<CatalogItem?> GetCatalogItemAsync(
        [Description("The catalog item id (folder name under the catalog root).")] string id,
        CancellationToken cancellationToken)
    {
        var items = await reader.ListItemsAsync(cancellationToken);
        return items.FirstOrDefault(i => string.Equals(i.Id, id, StringComparison.OrdinalIgnoreCase));
    }
}
