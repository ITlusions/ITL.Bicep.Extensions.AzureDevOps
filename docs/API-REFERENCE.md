# API Reference

## Resource Type: `ServiceConnection@2024-01-01`

Complete schema reference for Azure DevOps service connection resources in Bicep.

## Resource Declaration

```bicep
extension ado

resource <symbolic-name> 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: string    // Azure DevOps organization name
    project: string         // Project name
    name: string            // Service connection name (unique within project)
  }
  properties: {
    name: string            // Display name (usually matches identifiers.name)
    type: string            // Connection type: 'AzureRM', 'GitHub', etc.
    url: string             // Service URL
    authorization: {        // Authorization configuration
      scheme: string        // Auth scheme (depends on type)
      parameters: object    // Scheme-specific parameters
    }
    data: object            // Type-specific metadata
    isShared: bool?         // Share across projects (default: false)
    owner: string?          // Owner scope (default: 'Library')
  }
}
```

## Identifiers

The `identifiers` object uniquely identifies a service connection resource.

| Property | Type | Required | Description |
|---|---|---|---|
| `organization` | string | Yes | Azure DevOps organization name (e.g., `itlusions`) |
| `project` | string | Yes | Project name within the organization |
| `name` | string | Yes | Service connection name (must be unique within the project) |

**Example**:

```bicep
identifiers: {
  organization: 'itlusions'
  project: 'my-platform'
  name: 'my-platform-azure-prod'
}
```

**Naming conventions**:
- Use lowercase with hyphens: `my-app-azure-prod`
- Include environment suffix: `-dev`, `-staging`, `-prod`
- Prefix with project/app name for clarity

## Properties

### Common Properties

All service connection types support these properties:

| Property | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Display name (shown in Azure DevOps UI) |
| `type` | string | Yes | Connection type (`AzureRM`, `GitHub`, `dockerregistry`, etc.) |
| `url` | string | Yes | Target service URL |
| `authorization` | object | Yes | Authentication configuration |
| `data` | object | Yes | Type-specific metadata |
| `isShared` | bool | No | Share connection across projects (default: `false`) |
| `owner` | string | No | Owner scope (default: `Library`) |

---

## Connection Types

### AzureRM — Azure Resource Manager

Connect to Azure subscriptions using service principals or workload identity federation.

#### Scheme: `WorkloadIdentityFederation` (Recommended)

**No secrets required** — uses OIDC federation between Azure DevOps and Microsoft Entra ID.

```bicep
resource azureWif 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: 'itlusions'
    project: 'my-project'
    name: 'azure-prod-wif'
  }
  properties: {
    name: 'azure-prod-wif'
    type: 'AzureRM'
    url: 'https://management.azure.com/'
    authorization: {
      scheme: 'WorkloadIdentityFederation'
      parameters: {
        tenantid: '<tenant-id>'                      // Azure tenant ID
        serviceprincipalid: '<app-client-id>'        // Service principal (app) client ID
      }
    }
    data: {
      subscriptionId: '<subscription-id>'            // Target Azure subscription ID
      subscriptionName: 'Production Subscription'    // Display name
      environment: 'AzureCloud'                      // Azure environment (default: AzureCloud)
      scopeLevel: 'Subscription'                     // Scope level (default: Subscription)
      creationMode: 'Manual'                         // Creation mode (default: Manual)
    }
  }
}
```

**Prerequisites**:
1. Create an app registration in Microsoft Entra ID
2. Create a federated credential with issuer: `https://app.vstoken.visualstudio.com/<org-id>`
3. Grant the app RBAC roles on the Azure subscription (e.g., Contributor)

**Authorization parameters**:

| Parameter | Type | Required | Description |
|---|---|---|---|
| `tenantid` | string | Yes | Azure AD tenant ID |
| `serviceprincipalid` | string | Yes | Service principal (app registration) client ID |

**Data properties**:

| Property | Type | Required | Description |
|---|---|---|---|
| `subscriptionId` | string | Yes | Azure subscription ID |
| `subscriptionName` | string | Yes | Subscription display name |
| `environment` | string | No | Azure environment (default: `AzureCloud`, options: `AzureCloud`, `AzureChinaCloud`, `AzureUSGovernment`, `AzureGermanCloud`) |
| `scopeLevel` | string | No | Scope level (default: `Subscription`, options: `Subscription`, `ManagementGroup`) |
| `creationMode` | string | No | Creation mode (default: `Manual`) |

---

#### Scheme: `ServicePrincipal` (Classic)

Uses service principal with client secret. **Requires secret rotation**.

```bicep
@secure()
param clientSecret string

resource azureSp 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: 'itlusions'
    project: 'my-project'
    name: 'azure-prod-sp'
  }
  properties: {
    name: 'azure-prod-sp'
    type: 'AzureRM'
    url: 'https://management.azure.com/'
    authorization: {
      scheme: 'ServicePrincipal'
      parameters: {
        tenantid: '<tenant-id>'
        serviceprincipalid: '<app-client-id>'
        authenticationType: 'spnKey'                 // Always 'spnKey' for client secret
        serviceprincipalkey: clientSecret            // 🔒 Client secret
      }
    }
    data: {
      subscriptionId: '<subscription-id>'
      subscriptionName: 'Production Subscription'
      environment: 'AzureCloud'
      scopeLevel: 'Subscription'
      creationMode: 'Manual'
    }
  }
}
```

**Warning**: Store `serviceprincipalkey` in Azure Key Vault and reference it as a Bicep parameter. Never commit secrets to source control.

**Authorization parameters**:

| Parameter | Type | Required | Description |
|---|---|---|---|
| `tenantid` | string | Yes | Azure AD tenant ID |
| `serviceprincipalid` | string | Yes | Service principal client ID |
| `authenticationType` | string | Yes | Authentication type (always `spnKey` for client secret) |
| `serviceprincipalkey` | string | Yes | Client secret (mark parameter as `@secure()`) |

**Data properties**: Same as WorkloadIdentityFederation scheme.

---

### GitHub — GitHub Repository Access

Connect to GitHub repositories using a Personal Access Token (classic).

```bicep
@secure()
param githubToken string

resource github 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: 'itlusions'
    project: 'my-project'
    name: 'github-itlusions'
  }
  properties: {
    name: 'github-itlusions'
    type: 'GitHub'
    url: 'https://github.com'
    authorization: {
      scheme: 'Token'
      parameters: {
        accessToken: githubToken    // 🔒 GitHub PAT (classic) with repo scope
      }
    }
    data: {}
  }
}
```

**Prerequisites**:
1. Create a GitHub Personal Access Token (classic) with `repo` scope
2. Store token in Azure Key Vault
3. Pass token as `@secure()` parameter

**Authorization parameters**:

| Parameter | Type | Required | Description |
|---|---|---|---|
| `accessToken` | string | Yes | GitHub Personal Access Token (mark parameter as `@secure()`) |

**Data properties**: Empty object `{}`.

---

### Docker Registry

Connect to Docker registries (Docker Hub, ACR, etc.).

```bicep
@secure()
param dockerPassword string

resource dockerHub 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: 'itlusions'
    project: 'my-project'
    name: 'dockerhub'
  }
  properties: {
    name: 'dockerhub'
    type: 'dockerregistry'
    url: 'https://index.docker.io/v1/'    // Docker Hub URL
    authorization: {
      scheme: 'UsernamePassword'
      parameters: {
        username: 'myusername'
        password: dockerPassword             // 🔒 Docker Hub password or ACR token
        email: 'user@example.com'            // Optional
        registry: 'https://index.docker.io/v1/'
      }
    }
    data: {
      registrytype: 'DockerHub'              // Options: DockerHub, ContainerRegistry (ACR), Others
    }
  }
}
```

**For Azure Container Registry (ACR)**:

```bicep
resource acr 'ServiceConnection@2024-01-01' = {
  properties: {
    type: 'dockerregistry'
    url: 'https://myacr.azurecr.io'
    authorization: {
      scheme: 'UsernamePassword'
      parameters: {
        username: '<acr-username>'           // ACR admin username or service principal
        password: dockerPassword             // ACR admin password or SP client secret
        registry: 'https://myacr.azurecr.io'
      }
    }
    data: {
      registrytype: 'ContainerRegistry'      // ACR
    }
  }
}
```

**Authorization parameters**:

| Parameter | Type | Required | Description |
|---|---|---|---|
| `username` | string | Yes | Registry username |
| `password` | string | Yes | Registry password (mark parameter as `@secure()`) |
| `email` | string | No | Email address (optional) |
| `registry` | string | Yes | Registry URL |

**Data properties**:

| Property | Type | Required | Description |
|---|---|---|---|
| `registrytype` | string | Yes | Registry type (`DockerHub`, `ContainerRegistry`, `Others`) |

---

## HTTP API Endpoints

The provider exposes these endpoints (called by Bicep CLI):

### POST /ServiceConnection/preview

**Purpose**: Validate resource configuration without making changes.

**Request**:

```json
{
  "type": "ServiceConnection@2024-01-01",
  "identifiers": {
    "organization": "itlusions",
    "project": "my-project",
    "name": "my-conn"
  },
  "properties": {
    "name": "my-conn",
    "type": "AzureRM",
    "url": "https://management.azure.com/",
    "authorization": { ... },
    "data": { ... }
  }
}
```

**Response (success)**:

```json
{
  "status": "valid"
}
```

**Response (validation error)**:

```json
{
  "status": "invalid",
  "error": "Missing required property: authorization.parameters.tenantid"
}
```

---

### POST /ServiceConnection/save

**Purpose**: Create or update a service connection.

**Request**: Same format as `/preview`.

**Response**:

```json
{
  "properties": {
    "id": "12345-67890-abcdef",
    "name": "my-conn",
    "type": "AzureRM",
    "url": "https://management.azure.com/",
    "authorization": { ... },
    "data": { ... },
    "isReady": true,
    "owner": "Library"
  }
}
```

**Idempotency**: If a connection with the same `name` already exists, it is updated. Otherwise, a new connection is created.

---

### POST /ServiceConnection/get

**Purpose**: Retrieve the current state of a service connection.

**Request**:

```json
{
  "type": "ServiceConnection@2024-01-01",
  "identifiers": {
    "organization": "itlusions",
    "project": "my-project",
    "name": "my-conn"
  }
}
```

**Response (found)**:

```json
{
  "properties": {
    "id": "12345-67890-abcdef",
    "name": "my-conn",
    ...
  }
}
```

**Response (not found)**:

```json
{
  "status": "NotFound"
}
```

---

### POST /ServiceConnection/delete

**Purpose**: Delete a service connection.

**Request**: Same format as `/get`.

**Response**:

```json
{
  "status": "Deleted"
}
```

---

## Error Codes

| HTTP Status | Error | Description | Solution |
|---|---|---|---|
| 400 | Bad Request | Invalid request schema | Check Bicep template syntax |
| 401 | Unauthorized | Authentication failed | Ensure identity is member of ADO org |
| 403 | Forbidden | Insufficient permissions | Grant "Service Connections: Read & manage" permission |
| 404 | Not Found | Project or connection not found | Verify organization/project name |
| 409 | Conflict | Name conflict | Choose a different connection name |
| 429 | Too Many Requests | ADO API rate limit | Retry with exponential backoff |
| 500 | Internal Server Error | Provider error | Check provider logs |
| 502 | Bad Gateway | ADO API unavailable | Retry deployment |

---

## Examples

### Complete Multi-Connection Template

```bicep
extension ado

@description('Azure DevOps organization')
param organization string = 'itlusions'

@description('Project name')
param project string = 'my-platform'

@description('Azure subscription ID')
param subscriptionId string

@description('Azure tenant ID')
param tenantId string

@description('Service principal client ID')
param servicePrincipalId string

@secure()
@description('GitHub PAT')
param githubToken string

// Azure connection with Workload Identity Federation (no secrets)
resource azureWif 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: organization
    project: project
    name: '${project}-azure-prod'
  }
  properties: {
    name: '${project}-azure-prod'
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
      subscriptionName: 'Production'
      environment: 'AzureCloud'
      scopeLevel: 'Subscription'
      creationMode: 'Manual'
    }
  }
}

// GitHub connection
resource github 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: organization
    project: project
    name: '${project}-github'
  }
  properties: {
    name: '${project}-github'
    type: 'GitHub'
    url: 'https://github.com'
    authorization: {
      scheme: 'Token'
      parameters: {
        accessToken: githubToken
      }
    }
    data: {}
  }
}

output azureConnectionId string = azureWif.properties.id
output githubConnectionId string = github.properties.id
```

### Parameterized Connection

```bicep
extension ado

@description('Environment name')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('Azure subscription ID for the environment')
param subscriptionId string

var connectionName = 'azure-${environment}'

resource azureConn 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: 'itlusions'
    project: 'my-app'
    name: connectionName
  }
  properties: {
    name: connectionName
    type: 'AzureRM'
    url: 'https://management.azure.com/'
    authorization: {
      scheme: 'WorkloadIdentityFederation'
      parameters: {
        tenantid: subscription().tenantId
        serviceprincipalid: '<sp-client-id>'
      }
    }
    data: {
      subscriptionId: subscriptionId
      subscriptionName: '${environment} Subscription'
    }
  }
}
```

---

## Best Practices

### 1. Use Workload Identity Federation

Prefer `WorkloadIdentityFederation` over `ServicePrincipal` scheme:

**DO**: Use WIF (no secrets, no rotation, more secure)

```bicep
authorization: {
  scheme: 'WorkloadIdentityFederation'
  parameters: { tenantid: tenantId, serviceprincipalid: spId }
}
```

**DON'T**: Use Service Principal with client secret unless WIF is not supported

### 2. Never Hardcode Secrets

Always use `@secure()` parameters:

```bicep
@secure()
param githubToken string

resource github 'ServiceConnection@2024-01-01' = {
  properties: {
    authorization: {
      parameters: { accessToken: githubToken }  // ✅ Parameter
    }
  }
}
```

**DON'T**:

```bicep
parameters: { accessToken: 'ghp_1234567890...' }  // Hardcoded secret
```

### 3. Use Consistent Naming

Establish naming conventions:

```
<project>-<service>-<environment>
my-platform-azure-prod
my-platform-github-main
my-app-dockerhub-shared
```

### 4. Share Connections Sparingly

Only share connections across projects when truly needed:

```bicep
properties: {
  isShared: true  // Use with caution
}
```

**Reason**: Shared connections complicate permission management and auditing.

### 5. Document Connections

Add descriptions in code comments:

```bicep
// Production Azure connection for deployment pipelines
// Federated identity with Contributor role on subscription abc-123
resource azureProd 'ServiceConnection@2024-01-01' = { ... }
```

### 6. Version Control Connection Templates

Store connection definitions in Git alongside pipeline YAML:

```
repo/
├── azure-pipelines.yml
├── connections/
│   ├── main.bicep            # Connection definitions
│   └── bicepconfig.json      # Extension config
```

### 7. Test in Dev First

Always test connection changes in a dev project before production:

```bash
# Deploy to dev project
az deployment group create \
  --template-file connections/main.bicep \
  --parameters project=my-app-dev ...

# Verify in ADO UI, then deploy to prod
az deployment group create \
  --template-file connections/main.bicep \
  --parameters project=my-app-prod ...
```
