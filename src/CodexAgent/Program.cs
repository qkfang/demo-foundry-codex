using Azure.AI.Projects;
using Azure.AI.Projects.Agents;
using Azure.Identity;
using Microsoft.Extensions.Configuration;
using OpenAI.Responses;

var config = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: true)
    .AddEnvironmentVariables()
    .Build();

var endpoint = config["FoundryProjectEndpoint"]
    ?? throw new InvalidOperationException("FoundryProjectEndpoint is not set.");
var deploymentName = config["CodexDeploymentName"]
    ?? throw new InvalidOperationException("CodexDeploymentName is not set.");
var tenantId = config["TenantId"];

var prompt = args.Length > 0
    ? string.Join(' ', args)
    : "Write a short Python function that returns the nth Fibonacci number, then run it for n=10 and show the result.";

var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
{
    TenantId = tenantId,
    ExcludeVisualStudioCodeCredential = true
});

var projectClient = new AIProjectClient(new Uri(endpoint), credential);

const string agentId = "demo-codex-agent";
const string instructions = """
    You are a coding agent. Use the code interpreter tool to solve the user's task.
    Write clear, runnable code, execute it when helpful, and explain the result briefly.
    """;

var agentDefinition = new DeclarativeAgentDefinition(model: deploymentName)
{
    Instructions = instructions
};
var codeInterpreterContainer = new CodeInterpreterToolContainer(
    CodeInterpreterToolContainerConfiguration.CreateAutomaticContainerConfiguration());
agentDefinition.Tools.Add(ResponseTool.CreateCodeInterpreterTool(codeInterpreterContainer));

var agentVersion = projectClient.AgentAdministrationClient
    .CreateAgentVersion(agentId, new ProjectsAgentVersionCreationOptions(agentDefinition))
    .Value;

var responseClient = projectClient.ProjectOpenAIClient
    .GetProjectResponsesClientForAgent(agentVersion.Name);

Console.WriteLine($"Agent: {agentId}");
Console.WriteLine($"Prompt: {prompt}");
Console.WriteLine();

var options = new CreateResponseOptions
{
    InputItems = { ResponseItem.CreateUserMessageItem(prompt) }
};

var result = await responseClient.CreateResponseAsync(options);

Console.WriteLine(result.Value.GetOutputText());
