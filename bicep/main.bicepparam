using 'main.bicep'

param baseName = 'fdrycodex'
param location = 'eastus2'
param codexDeploymentName = 'gpt-5-codex'
param codexModelName = 'gpt-5-codex'
param codexModelVersion = '2025-09-15'
param chatDeploymentName = 'gpt-4.1'
param chatModelName = 'gpt-4.1'
param chatModelVersion = '2025-04-14'
param principals = [
  {
    id: '4b74544b-02c6-4e4f-b936-732c9c3fff65'
    principalType: 'User'
  }
]
