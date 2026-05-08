namespace CatalogMcpServer;

public sealed class CatalogOptions
{
    public const string SectionName = "Catalog";

    public CatalogSource Source { get; set; } = CatalogSource.GitHub;

    public string? LocalPath { get; set; }

    public GitHubCatalogOptions GitHub { get; set; } = new();
}

public enum CatalogSource
{
    GitHub,
    Local
}

public sealed class GitHubCatalogOptions
{
    public string Owner { get; set; } = "azureholic";
    public string Repo { get; set; } = "ATO-Catalog";
    public string Branch { get; set; } = "main";
    public string Path { get; set; } = "";

    /// <summary>Optional Personal Access Token. Only required to raise the unauthenticated rate limit or for private repos.</summary>
    public string? Token { get; set; }
}
