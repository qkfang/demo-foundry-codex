$ErrorActionPreference = 'Stop'

az group create --name 'rg-fdrycodex' --location 'eastus2' | Out-Null

az deployment group create --name 'fdrycodex-deploy' --resource-group 'rg-fdrycodex' --template-file './main.bicep' --parameters './main.bicepparam'
