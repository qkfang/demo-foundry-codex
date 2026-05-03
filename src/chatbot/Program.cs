using Azure.AI.Projects;
using Azure.AI.Projects.Agents;
using Azure.Identity;
using OpenAI.Responses;
using System.Text;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

app.UseStaticFiles();

var endpoint = app.Configuration["FoundryProjectEndpoint"]
    ?? throw new InvalidOperationException("FoundryProjectEndpoint is not set.");
var deploymentName = app.Configuration["CodexDeploymentName"]
    ?? throw new InvalidOperationException("CodexDeploymentName is not set.");
var tenantId = app.Configuration["TenantId"];

var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
{
    TenantId = tenantId,
    ExcludeVisualStudioCodeCredential = true
});

var projectClient = new AIProjectClient(new Uri(endpoint), credential);

const string agentId = "demo-chatbot-agent";
const string instructions = """
    You are a coding assistant. Use the code interpreter tool to write, run, and test code.
    Explain what you are doing at each step and show the output clearly.
    """;

var agentDefinition = new DeclarativeAgentDefinition(model: deploymentName)
{
    Instructions = instructions
};
var container = new CodeInterpreterToolContainer(
    CodeInterpreterToolContainerConfiguration.CreateAutomaticContainerConfiguration());
agentDefinition.Tools.Add(ResponseTool.CreateCodeInterpreterTool(container));

var agentVersion = projectClient.AgentAdministrationClient
    .CreateAgentVersion(agentId, new ProjectsAgentVersionCreationOptions(agentDefinition))
    .Value;

var responseClient = projectClient.ProjectOpenAIClient
    .GetProjectResponsesClientForAgent(agentVersion.Name);

app.MapPost("/api/chat", async (HttpContext ctx, ChatRequest req) =>
{
    ctx.Response.ContentType = "text/event-stream";
    ctx.Response.Headers.CacheControl = "no-cache";
    ctx.Response.Headers["X-Accel-Buffering"] = "no";

    async Task Send(object data)
    {
        var line = $"data: {JsonSerializer.Serialize(data)}\n\n";
        await ctx.Response.Body.WriteAsync(Encoding.UTF8.GetBytes(line));
        await ctx.Response.Body.FlushAsync();
    }

    var options = new CreateResponseOptions
    {
        InputItems = { ResponseItem.CreateUserMessageItem(req.Message) }
    };
    if (!string.IsNullOrEmpty(req.PreviousResponseId))
        options.PreviousResponseId = req.PreviousResponseId;

    string? responseId = null;
    try
    {
        var streaming = responseClient.CreateResponseStreamingAsync(options);
        await foreach (var update in streaming)
        {
            switch (update)
            {
                case StreamingResponseOutputTextDeltaUpdate textDelta:
                    await Send(new { type = "text", content = textDelta.Delta });
                    break;

                case StreamingResponseCodeInterpreterCallInProgressUpdate:
                    await Send(new { type = "code_start" });
                    break;

                case StreamingResponseCodeInterpreterCallCodeDeltaUpdate codeDelta:
                    await Send(new { type = "code_delta", content = codeDelta.Delta });
                    break;

                case StreamingResponseCodeInterpreterCallInterpretingUpdate:
                    await Send(new { type = "code_running" });
                    break;

                case StreamingResponseOutputItemDoneUpdate itemDone
                    when itemDone.Item is CodeInterpreterCallResponseItem ci:
                    foreach (var output in ci.Outputs.OfType<CodeInterpreterCallLogsOutput>())
                        await Send(new { type = "code_output", content = output.Logs });
                    break;

                case StreamingResponseCompletedUpdate completed:
                    responseId = completed.Response.Id;
                    break;
            }
        }
    }
    catch (Exception ex)
    {
        await Send(new { type = "error", content = ex.Message });
    }

    await Send(new { type = "done", responseId });
});

app.Run();

record ChatRequest(string Message, string? PreviousResponseId);
