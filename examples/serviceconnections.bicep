// serviceconnections.bicep
// Creates three service connections in Azure DevOps:
//   1. Azure Resource Manager (Workload Identity Federation — recommended)
//   2. Azure Resource Manager (Service Principal)
//   3. GitHub (PAT)
//
// Prerequisites:
//   - bicepconfig.json with the 'ado' extension registered
//   - ADO_PAT env var set on the provider host with:
//       Service Connections: Read & manage

@description('Azure DevOps organization name, e.g. itlusions')
param organization string

@description('Azure DevOps project name')
param project string

@description('Azure subscription ID to connect to')
param subscriptionId string

@description('Azure subscription display name')
param subscriptionName string

@description('Azure tenant ID')
param tenantId string

@description('Service principal (app registration) client ID')
param servicePrincipalId string

@description('GitHub PAT for the GitHub service connection')
@secure()
param githubToken string

// ------------------------------------------------------------------
// Import the ITL Azure DevOps extension
// ------------------------------------------------------------------
extension ado

// ------------------------------------------------------------------
// 1. Azure Resource Manager — Workload Identity Federation (no secret)
// ------------------------------------------------------------------
resource azureWif 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: organization
    project: project
    name: '${project}-azure-wif'
  }
  properties: {
    name: '${project}-azure-wif'
    type: 'AzureRM'
    url: 'https://management.azure.com/'
    authorization: {
      scheme: 'WorkloadIdentityFederation'
      parameters: {
        tenantid: tenantId
        serviceprincipalid: servicePrincipalId
      }
    }
    data: {
      subscriptionId: subscriptionId
      subscriptionName: subscriptionName
      environment: 'AzureCloud'
      scopeLevel: 'Subscription'
      creationMode: 'Manual'
    }
    isShared: false
  }
}

// ------------------------------------------------------------------
// 2. Azure Resource Manager — Service Principal (classic)
// ------------------------------------------------------------------
resource azureSp 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: organization
    project: project
    name: '${project}-azure-sp'
  }
  properties: {
    name: '${project}-azure-sp'
    type: 'AzureRM'
    url: 'https://management.azure.com/'
    authorization: {
      scheme: 'ServicePrincipal'
      parameters: {
        tenantid: tenantId
        serviceprincipalid: servicePrincipalId
        // serviceprincipalkey: '<inject from Key Vault>'
      }
    }
    data: {
      subscriptionId: subscriptionId
      subscriptionName: subscriptionName
      environment: 'AzureCloud'
      scopeLevel: 'Subscription'
    }
    isShared: false
  }
}

// ------------------------------------------------------------------
// 3. GitHub — Personal Access Token
// ------------------------------------------------------------------
resource github 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: organization
    project: project
    name: '${project}-github'
  }
  properties: {
    name: '${project}-github'
    type: 'github'
    url: 'https://github.com/'
    authorization: {
      scheme: 'PersonalAccessToken'
      parameters: {
        accesstoken: githubToken
      }
    }
    data: {}
    isShared: false
  }
}

// ------------------------------------------------------------------
// Outputs
// ------------------------------------------------------------------
output azureWifConnectionId string = azureWif.properties.id
output azureSpConnectionId  string = azureSp.properties.id
output githubConnectionId   string = github.properties.id
