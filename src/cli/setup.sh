#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Setup script: install Codex CLI and configure it for Azure AI Foundry
#
# Required environment variables (set before running or export them):
#   AZURE_OPENAI_API_KEY   - API key from your Azure OpenAI / AI Foundry resource
#   AZURE_OPENAI_ENDPOINT  - Endpoint URL, e.g. https://<resource>.openai.azure.com
#
# Optional:
#   CODEX_MODEL            - Deployment name (default: gpt-5-codex)
#   CODEX_PROMPT           - Prompt to run after setup
# ---------------------------------------------------------------------------

CODEX_MODEL="${CODEX_MODEL:-gpt-5-codex}"
CODEX_CONFIG_DIR="${HOME}/.codex"
CODEX_CONFIG_FILE="${CODEX_CONFIG_DIR}/config.toml"

if [[ -z "${AZURE_OPENAI_API_KEY:-}" ]]; then
  echo "Error: AZURE_OPENAI_API_KEY is not set."
  exit 1
fi

if [[ -z "${AZURE_OPENAI_ENDPOINT:-}" ]]; then
  echo "Error: AZURE_OPENAI_ENDPOINT is not set."
  exit 1
fi

# Strip trailing slash and append /openai
BASE_URL="${AZURE_OPENAI_ENDPOINT%/}/openai"

# Install Codex CLI if not already installed
if ! command -v codex &>/dev/null; then
  echo "Installing @openai/codex..."
  npm install -g @openai/codex
fi

# Create config directory
mkdir -p "${CODEX_CONFIG_DIR}"

# Write config.toml
cat > "${CODEX_CONFIG_FILE}" <<TOML
model = "${CODEX_MODEL}"
model_provider = "azure"
model_reasoning_effort = "medium"

[model_providers.azure]
name = "Azure OpenAI"
base_url = "${BASE_URL}"
env_key = "AZURE_OPENAI_API_KEY"
query_params = { api-version = "2025-04-01-preview" }
wire_api = "responses"
TOML

echo "Config written to ${CODEX_CONFIG_FILE}"
echo ""

# Run a sample prompt if provided, otherwise show usage
PROMPT="${CODEX_PROMPT:-}"
if [[ -n "${PROMPT}" ]]; then
  codex exec "${PROMPT}"
else
  echo "Usage:"
  echo "  codex exec \"<your prompt>\""
  echo ""
  echo "Example:"
  echo "  codex exec \"Write a Python function that returns the nth Fibonacci number\""
fi
