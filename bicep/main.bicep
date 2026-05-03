@description('Base name prefix for all resources')
param baseName string = 'fdrycodex'

@description('Azure region for all resources')
param location string = 'eastus2'

@description('Principal object IDs to grant access to deployed resources')
param principals array = []

@description('Codex model deployment name')
param codexDeploymentName string = 'gpt-5-codex'

@description('Codex model name in the OpenAI catalog')
param codexModelName string = 'gpt-5-codex'

@description('Codex model version')
param codexModelVersion string = '2025-09-15'

@description('Chat model deployment name')
param chatDeploymentName string = 'gpt-4.1'

@description('Chat model name in the OpenAI catalog')
param chatModelName string = 'gpt-4.1'

@description('Chat model version')
param chatModelVersion string = '2025-04-14'

var commonTags = {
  workload: 'foundry-codex-demo'
  SecurityControl: 'Ignore'
}

var foundryName = '${baseName}-foundry'

module foundry 'foundry.bicep' = {
  name: 'foundryDeployment'
  params: {
    name: foundryName
    location: location
    tags: commonTags
    codexDeploymentName: codexDeploymentName
    codexModelName: codexModelName
    codexModelVersion: codexModelVersion
    chatDeploymentName: chatDeploymentName
    chatModelName: chatModelName
    chatModelVersion: chatModelVersion
  }
}

resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' existing = {
  name: foundryName
  dependsOn: [foundry]
}

var cognitiveServicesOpenAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
var azureAIUserRoleId = '53ca6127-db72-4b80-b1b0-d745d6d5456d'
var azureAIDeveloperRoleId = '64702f94-c441-49e6-a78b-ef80e0188fee'

resource principalOpenAIUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principal in principals: {
  name: guid(foundryAccount.id, principal.id, cognitiveServicesOpenAIUserRoleId)
  scope: foundryAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalId: principal.id
    principalType: principal.principalType
  }
}]

resource principalAIUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principal in principals: {
  name: guid(foundryAccount.id, principal.id, azureAIUserRoleId)
  scope: foundryAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', azureAIUserRoleId)
    principalId: principal.id
    principalType: principal.principalType
  }
}]

resource principalAIDeveloperRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principal in principals: {
  name: guid(foundryAccount.id, principal.id, azureAIDeveloperRoleId)
  scope: foundryAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', azureAIDeveloperRoleId)
    principalId: principal.id
    principalType: principal.principalType
  }
}]

output foundryAccountName string = foundry.outputs.accountName
output foundryAccountEndpoint string = foundry.outputs.accountEndpoint
output projectName string = foundry.outputs.projectName
output projectEndpoint string = foundry.outputs.projectEndpoint
output codexDeploymentName string = foundry.outputs.deploymentName
