using Azure.AI.OpenAI;
using Azure.Identity;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Configuration;
using ModelContextProtocol.Client;

var config = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: false)
    .AddUserSecrets<Program>(optional: true)
    .AddEnvironmentVariables()
    .Build();

var endpoint = config["AzureOpenAI:Endpoint"]
    ?? throw new InvalidOperationException("AzureOpenAI:Endpoint is not configured. Set it via user-secrets.");
var deployment = config["AzureOpenAI:Deployment"]
    ?? throw new InvalidOperationException("AzureOpenAI:Deployment is not configured.");
var mcpEndpoint = config["Mcp:Endpoint"]
    ?? throw new InvalidOperationException("Mcp:Endpoint is not configured.");

// AzureOpenAIClient expects the resource base URI (not the /openai/v1 path).
var baseUri = new Uri(new Uri(endpoint), "/");

Console.WriteLine($"Azure OpenAI : {baseUri} (deployment: {deployment})");
Console.WriteLine($"MCP server   : {mcpEndpoint}");

var azureClient = new AzureOpenAIClient(baseUri, new DefaultAzureCredential());

IChatClient chatClient = new ChatClientBuilder(azureClient.GetChatClient(deployment).AsIChatClient())
    .UseFunctionInvocation()
    .Build();

var transport = new HttpClientTransport(new HttpClientTransportOptions
{
    Endpoint = new Uri(mcpEndpoint),
    Name = "catalog-mcp",
    TransportMode = HttpTransportMode.StreamableHttp,
});

await using var mcpClient = await McpClient.CreateAsync(transport);
var mcpTools = await mcpClient.ListToolsAsync();
Console.WriteLine($"MCP tools    : {string.Join(", ", mcpTools.Select(t => t.Name))}");
Console.WriteLine();

var messages = new List<ChatMessage>
{
    new(ChatRole.System,
        "You are a helpful assistant for the ATO platform engineering catalog. " +
        "Use the provided tools to look up catalog items when asked.")
};

var options = new ChatOptions
{
    Tools = [.. mcpTools.Cast<AITool>()],
};

Console.WriteLine("Type a message (empty line to quit).");
while (true)
{
    Console.Write("> ");
    var input = Console.ReadLine();
    if (string.IsNullOrWhiteSpace(input)) break;

    messages.Add(new ChatMessage(ChatRole.User, input));

    var response = await chatClient.GetResponseAsync(messages, options);
    Console.WriteLine(response.Text);
    Console.WriteLine();

    messages.AddRange(response.Messages);
}
