# Setup script: install Codex CLI and configure it for Azure AI Foundry
#
# Required environment variables (set before running):
#   AZURE_OPENAI_API_KEY   - API key from your Azure OpenAI / AI Foundry resource
#   AZURE_OPENAI_ENDPOINT  - Endpoint URL, e.g. https://<resource>.openai.azure.com
#
# Optional:
#   CODEX_MODEL            - Deployment name (default: gpt-5-codex)
#   CODEX_PROMPT           - Prompt to run after setup

param(
    [string]$Model    = $env:CODEX_MODEL ?? "gpt-5-codex",
    [string]$Prompt   = $env:CODEX_PROMPT ?? ""
)

$ErrorActionPreference = 'Stop'

$ApiKey   = $env:AZURE_OPENAI_API_KEY
$Endpoint = $env:AZURE_OPENAI_ENDPOINT

if (-not $ApiKey) {
    Write-Error "AZURE_OPENAI_API_KEY is not set."
    exit 1
}

if (-not $Endpoint) {
    Write-Error "AZURE_OPENAI_ENDPOINT is not set."
    exit 1
}

$BaseUrl = $Endpoint.TrimEnd('/') + '/openai'

# Install Codex CLI if not already installed
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Host "Installing @openai/codex..."
    npm install -g @openai/codex
}

# Create config directory
$ConfigDir  = Join-Path $HOME ".codex"
$ConfigFile = Join-Path $ConfigDir "config.toml"
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

# Write config.toml
@"
model = "$Model"
model_provider = "azure"
model_reasoning_effort = "medium"

[model_providers.azure]
name = "Azure OpenAI"
base_url = "$BaseUrl"
env_key = "AZURE_OPENAI_API_KEY"
query_params = { api-version = "2025-04-01-preview" }
wire_api = "responses"
"@ | Set-Content -Path $ConfigFile -Encoding UTF8

Write-Host "Config written to $ConfigFile"
Write-Host ""

if ($Prompt) {
    codex exec $Prompt
} else {
    Write-Host "Usage:"
    Write-Host '  codex exec "<your prompt>"'
    Write-Host ""
    Write-Host "Example:"
    Write-Host '  codex exec "Write a Python function that returns the nth Fibonacci number"'
}
