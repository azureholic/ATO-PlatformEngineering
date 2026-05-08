using CatalogMcpServer;
using CatalogMcpServer.Tools;
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddOptions<CatalogOptions>()
    .Bind(builder.Configuration.GetSection(CatalogOptions.SectionName))
    .ValidateOnStart();

builder.Services.AddSingleton(sp => sp.GetRequiredService<IOptions<CatalogOptions>>().Value);

builder.Services.AddHttpClient(GitHubCatalogReader.HttpClientName, (sp, client) =>
{
    var options = sp.GetRequiredService<CatalogOptions>();
    GitHubCatalogReader.ConfigureHttpClient(client, options);
});

builder.Services.AddSingleton<LocalCatalogReader>();
builder.Services.AddSingleton<GitHubCatalogReader>();
builder.Services.AddSingleton<ICatalogReader>(sp =>
{
    var options = sp.GetRequiredService<CatalogOptions>();
    return options.Source switch
    {
        CatalogSource.Local => sp.GetRequiredService<LocalCatalogReader>(),
        _ => sp.GetRequiredService<GitHubCatalogReader>()
    };
});

builder.Services
    .AddMcpServer()
    .WithHttpTransport()
    .WithTools<CatalogTools>();

var app = builder.Build();

var catalogOptions = app.Services.GetRequiredService<CatalogOptions>();

app.MapGet("/", () => Results.Ok(new
{
    name = "catalog-mcp-server",
    description = "MCP server that exposes the composition-poc catalog.",
    source = catalogOptions.Source.ToString(),
    github = catalogOptions.Source == CatalogSource.GitHub ? new
    {
        catalogOptions.GitHub.Owner,
        catalogOptions.GitHub.Repo,
        catalogOptions.GitHub.Branch,
        catalogOptions.GitHub.Path
    } : null,
    localPath = catalogOptions.Source == CatalogSource.Local ? catalogOptions.LocalPath : null
}));

app.MapGet("/healthz", () => Results.Ok("ok"));

app.MapMcp("/mcp");

app.Run();
