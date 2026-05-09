# ITL Bicep Extensions — Azure DevOps

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/itlusions/ITL.Bicep.Extensions.AzureDevOps)](https://github.com/itlusions/ITL.Bicep.Extensions.AzureDevOps/releases)
[![Docker](https://img.shields.io/badge/docker-ready-brightgreen)](https://github.com/itlusions/ITL.Bicep.Extensions.AzureDevOps/pkgs/container/itl-bicep-ext-azuredevops)

> **Declarative Infrastructure-as-Code for Azure DevOps** — Manage Azure DevOps service connections as Bicep resources using the [Bicep Extensibility V2 protocol](https://github.com/Azure/bicep-extensibility).

```bicep
extension ado

resource conn 'ServiceConnection@2024-01-01' = {
  identifiers: {
    organization: 'itlusions'
    project:      'my-project'
    name:         'my-project-azure-wif'
  }
  properties: {
    type:   'AzureRM'
    url:    'https://management.azure.com/'
    authorization: {
      scheme: 'WorkloadIdentityFederation'
      parameters: { tenantid: tenantId; serviceprincipalid: spId }
    }
    data: { subscriptionId: subscriptionId; subscriptionName: subscriptionName }
  }
}
```

## 📖 Documentation

- **[Architecture Guide](docs/ARCHITECTURE.md)** — How the extensibility provider works
- **[API Reference](docs/API-REFERENCE.md)** — Complete resource schema and operations
- **[Deployment Guide](docs/DEPLOYMENT.md)** — Production deployment patterns (ACI, AKS, App Service)
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** — Common issues and solutions
- **[Contributing](docs/CONTRIBUTING.md)** — Development setup and contribution guidelines

---

## Overview

This project is a **Bicep extensibility provider** that exposes Azure DevOps service connections as first-class Bicep resources. Once deployed, the provider lets you declare, create, update, and delete service connections in Azure DevOps directly from Bicep templates — no scripts, no manual portal steps.

### ✨ Key Features

- **🔐 Secure by default** — Uses Azure Workload Identity / Managed Identity (no PAT required)
- **📝 Declarative IaC** — Service connections defined alongside Azure resources in Bicep
- **🔄 Idempotent operations** — Safe to re-run deployments (create-or-update semantics)
- **🎯 Type-safe** — Full IntelliSense support in VS Code with Bicep extension
- **🐳 Container-native** — Deploy on ACI, AKS, App Service, or locally with Docker
- **🌐 Multi-runtime** — Choose .NET, Python, or PowerShell based on your stack
- **🔍 Observable** — Structured logging, OpenTelemetry support, Scalar API explorer

### 🏗️ Implementation Options

Three functionally equivalent implementations are included — pick the runtime that fits your infrastructure:

| Implementation | Entry point | Docker file | Runtime |
|---|---|---|---|
| **.NET 8 / C#** | `src/ITL.Bicep.Extensions.AzureDevOps/` | `Dockerfile` | ASP.NET Core 8 |
| **Python / FastAPI** | `src/itl_bicep_ext_azuredevops/` | `Dockerfile.python` | Python 3.12 + FastAPI |
| **PowerShell / Pode** | `src/ITL.Bicep.Extensions.AzureDevOps.PS/` | `Dockerfile.powershell` | PowerShell 7 + Pode |

All three expose the same HTTP API surface and handle authentication via **Azure DefaultAzureCredential**.

---

## Supported Resource Type

| Type | Description |
|---|---|
| `ServiceConnection@2024-01-01` | Azure DevOps service endpoint |

### Supported connection types

| `type` value | Scheme | Notes |
|---|---|---|
| `AzureRM` | `WorkloadIdentityFederation` | Recommended — no secret required |
| `AzureRM` | `ServicePrincipal` | Classic SP + client secret |
| `GitHub` | `Token` | GitHub Personal Access Token |

---

## Prerequisites

### Tooling

| Requirement | Minimum version | Notes |
|---|---|---|
| Bicep CLI | **0.29** | Extensibility experimental feature must be enabled |
| Azure CLI | **2.50** | Used to run `az deployment` |
| Docker | any current | Required to build and run provider images |

### Azure identity (authentication)

The provider authenticates to Azure DevOps using **Azure Workload Identity / Managed Identity** — no Personal Access Token is required. The credential resolution order is:

| Priority | Credential | Typical environment |
|---|---|---|
| 1 | **Workload Identity Federation** | AKS pod with federated identity, Azure Pipelines with `AzureServicePrincipal` connection |
| 2 | **Managed Identity** | ACI, App Service, Azure VM, AKS node pool |
| 3 | **Azure CLI** (`az login`) | Local development |
| 4 | **Visual Studio / VS Code** | Local development |

For the PowerShell runtime an additional fallback is available: `Get-AzAccessToken` from the `Az.Accounts` module after `Connect-AzAccount`.

> **Override**: Set the `AZURE_AD_TOKEN` environment variable to a pre-fetched Bearer token to skip all credential resolution (useful for testing).

### Azure DevOps permissions

The identity used by the provider (managed identity, service principal, or signed-in user) must have **Service Connections: Read & manage** permission in the target Azure DevOps organisation.

1. In Azure DevOps go to **Organisation Settings → Users** and add the identity.
2. For project-scoped permissions: **Project Settings → Service connections → Security** → grant *Administrator* or *Creator* role.

> The identity must be a member of the ADO organisation — having an Azure RBAC role is not sufficient.

### Container registry

The provider runs as a container. You need an **Azure Container Registry** (or any OCI registry) that the machine running `az deployment` can pull from.

---

## Quick Start

### 1. Configure Bicep

Add `bicepconfig.json` alongside your `.bicep` files:

```json
{
  "experimentalFeaturesEnabled": { "extensibility": true },
  "extensions": {
    "ado": "br:<your-acr>.azurecr.io/extensions/itl-azuredevops:1.0.0"
  }
}
```

### 2. Build and run the provider

**Docker — with Managed Identity (production)**

When running on Azure infrastructure (ACI, AKS, App Service) the container picks up the Managed Identity automatically — no extra environment variables needed:

```bash
# .NET
docker build -f Dockerfile -t itlbicep.azurecr.io/extensions/itl-azuredevops:1.0.0 .
docker run -p 8080:8080 itlbicep.azurecr.io/extensions/itl-azuredevops:1.0.0

# Python
docker build -f Dockerfile.python -t itlbicep.azurecr.io/extensions/itl-azuredevops-py:1.0.0 .
docker run -p 8080:8080 itlbicep.azurecr.io/extensions/itl-azuredevops-py:1.0.0

# PowerShell
docker build -f Dockerfile.powershell -t itlbicep.azurecr.io/extensions/itl-azuredevops-ps:1.0.0 .
docker run -p 8080:8080 itlbicep.azurecr.io/extensions/itl-azuredevops-ps:1.0.0
```

For a **user-assigned Managed Identity**, pass the client ID:

```bash
docker run -e AZURE_CLIENT_ID=<mi-client-id> -p 8080:8080 \
  itlbicep.azurecr.io/extensions/itl-azuredevops:1.0.0
```

**Local (development) — Azure CLI credential**

Sign in once with the Azure CLI, then run the provider. `DefaultAzureCredential` will pick up your CLI session automatically:

```bash
az login
```

```powershell
# PowerShell — Az.Accounts fallback
Install-Module -Name Pode, Az.Accounts -Force
Connect-AzAccount
pwsh ./src/ITL.Bicep.Extensions.AzureDevOps.PS/Server.ps1
```

```bash
# Python
pip install -e ".[dev]"
python -m itl_bicep_ext_azuredevops
```

```bash
# .NET
dotnet run --project src/ITL.Bicep.Extensions.AzureDevOps/
```

> **Testing without Azure identity** — set `AZURE_AD_TOKEN` to a Bearer token obtained via `az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv`.

### 3. Push to ACR

```bash
az acr login --name itlbicep
docker push itlbicep.azurecr.io/extensions/itl-azuredevops:1.0.0
```

### 4. Run the provider before deployment

The Bicep engine calls the provider **client-side** during template processing — Azure ARM never sees the ADO resources. You must have the provider running and reachable on port 8080 **before** you run `az deployment`.

```bash
# Local: use Azure CLI credential
docker run --rm -p 8080:8080 \
  itlbicep.azurecr.io/extensions/itl-azuredevops:1.0.0
```

In CI/CD (Azure Pipelines, GitHub Actions), run the image as a **service container** so it starts automatically for the duration of the job. See [Pipeline Service Container](#pipeline-service-container) below.

### 5. Deploy

```bash
az deployment group create \
  --resource-group my-rg \
  --template-file examples/serviceconnections.bicep \
  --parameters organization=itlusions project=my-project \
               subscriptionId=<sub-id> subscriptionName="My Sub" \
               tenantId=<tenant-id> servicePrincipalId=<app-id> \
               githubToken=<ghp_...>
```

---

## HTTP API (Bicep Extensibility V2)

All routes are `POST`. The Bicep engine calls these automatically — you don't call them directly.

| Route | Description |
|---|---|
| `POST /{version}/resource/preview` | Dry-run, returns computed fields |
| `POST /{version}/resource/createOrUpdate` | Idempotent create or update |
| `POST /{version}/resource/get` | Read a service connection |
| `POST /{version}/resource/delete` | Delete (idempotent — 204 if absent) |
| `POST /{version}/longRunningOperation/get` | Not used; returns 404 |

Required request headers: `x-ms-client-request-id`, `x-ms-correlation-request-id`, `Referer`.

---

## Security

- **No PAT required** — authentication uses Azure Workload Identity Federation or Managed Identity. No long-lived credential is stored in the image or injected at runtime.
- **Least-privilege identity** — the managed identity or service principal only needs *Service Connections: Read & manage* in Azure DevOps; no Azure RBAC role is required.
- **Secrets are stripped** from all responses — `accessToken`, `password`, `servicePrincipalKey`, `privateKey`, `apiToken` are never returned to Bicep.
- The provider must run on a **private network** — it receives unencrypted secrets from the Bicep engine over the local provider transport.
- **Token hygiene** — access tokens are fetched per-request and never logged or persisted.

---

## Project Structure

```
ITL.Bicep.Extensions.AzureDevOps/
├── Dockerfile                               (.NET 8)
├── Dockerfile.python                        (Python / FastAPI)
├── Dockerfile.powershell                    (PowerShell / Pode)
├── pyproject.toml
├── examples/
│   ├── bicepconfig.json
│   └── serviceconnections.bicep
└── src/
    ├── itl_bicep_ext_azuredevops/           Python package
    │   ├── app.py                           FastAPI app + 5 routes
    │   ├── ado_client.py                    ADO REST client
    │   ├── contract.py                      Pydantic models
    │   └── __main__.py
    ├── ITL.Bicep.Extensions.AzureDevOps/    .NET project
    │   ├── Program.cs
    │   ├── Handlers/
    │   ├── Models/
    │   └── Services/
    └── ITL.Bicep.Extensions.AzureDevOps.PS/ PowerShell module
        ├── ITL.Bicep.Extensions.AzureDevOps.psd1
        ├── ITL.Bicep.Extensions.AzureDevOps.psm1
        ├── Server.ps1
        ├── Handlers/
        ├── Models/
        └── Services/
```

---

## Pipeline Service Container

The provider must be running before `az deployment` is called. Use service containers to automate this in CI/CD.

### Azure Pipelines

The pipeline's service connection already provides an Azure AD token. Pass it to the provider container via `AZURE_AD_TOKEN` so it doesn't need IMDS:

```yaml
resources:
  containers:
    - container: ado_provider
      image: itlbicep.azurecr.io/extensions/itl-azuredevops:1.0.0
      # No PAT needed — token is injected from the pipeline service connection
      ports:
        - 8080:8080

jobs:
  - job: Deploy
    services:
      ado_provider: ado_provider
    steps:
      - task: AzureCLI@2
        displayName: Fetch ADO token and deploy
        env:
          BICEP_EXTENSION_ADO_BASEURI: http://localhost:8080
        inputs:
          azureSubscription: my-service-connection
          scriptType: bash
          scriptLocation: inlineScript
          addSpnToEnvironment: true  # exposes $servicePrincipalId / $idToken
          inlineScript: |
            # Obtain AAD token scoped to Azure DevOps and pass it to the provider
            ADO_TOKEN=$(az account get-access-token \
              --resource 499b84ac-1321-427f-aa17-267ca6975798 \
              --query accessToken -o tsv)
            export AZURE_AD_TOKEN=$ADO_TOKEN

            az deployment group create \
              --resource-group my-rg \
              --template-file examples/serviceconnections.bicep \
              --parameters organization=itlusions project=my-project \
                           subscriptionId=$(SUB_ID) tenantId=$(TENANT_ID) \
                           servicePrincipalId=$(SP_ID) subscriptionName="My Sub" \
                           githubToken=$(GITHUB_TOKEN)
```

> Alternatively, run the provider container in an Azure-hosted environment (ACI, AKS) with a Managed Identity — it will authenticate automatically without `AZURE_AD_TOKEN`.

### GitHub Actions

Use OIDC (`id-token: write`) to exchange a GitHub Actions token for an Azure AD token:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write   # required for OIDC login
      contents: read
    services:
      ado-provider:
        image: itlbicep.azurecr.io/extensions/itl-azuredevops:1.0.0
        ports:
          - 8080:8080
    steps:
      - uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Fetch ADO token and deploy
        env:
          BICEP_EXTENSION_ADO_BASEURI: http://localhost:8080
        run: |
          # Exchange current Azure credential for an ADO-scoped token
          ADO_TOKEN=$(az account get-access-token \
            --resource 499b84ac-1321-427f-aa17-267ca6975798 \
            --query accessToken -o tsv)
          export AZURE_AD_TOKEN=$ADO_TOKEN

          az deployment group create \
            --resource-group my-rg \
            --template-file examples/serviceconnections.bicep \
            --parameters organization=itlusions project=my-project \
                         subscriptionId=${{ vars.SUB_ID }} \
                         tenantId=${{ vars.TENANT_ID }} \
                         servicePrincipalId=${{ vars.SP_ID }} \
                         subscriptionName="My Sub" \
                         githubToken=${{ secrets.GITHUB_TOKEN }}
```

---

## How It Works

```
CI agent / local machine
┌──────────────────────────────────────────────────────────┐
│  az deployment group create                               │
│     └─ Bicep engine processes template                    │
│           └─ HTTP POST → localhost:8080 (this provider)   │
│                 └─ provider calls Azure DevOps REST API   │
└──────────────────────────────────────────────────────────┘
              ↓ compiled ARM (no ADO resources)
           Azure ARM — deploys Azure resources only
```

The provider handles ADO service connections **client-side** before the ARM payload reaches Azure. ADO is not an Azure resource — it never passes through ARM.

---

## Environment Variables

### Authentication

The provider uses `DefaultAzureCredential` and honours all standard Azure Identity environment variables. No PAT is required.

| Variable | Required | Description |
|---|---|---|
| `AZURE_CLIENT_ID` | No | Client ID of a **user-assigned** Managed Identity. Omit for system-assigned MI. |
| `AZURE_TENANT_ID` | No | Azure AD tenant ID. Required when using a Service Principal with `AZURE_CLIENT_SECRET` or `AZURE_CLIENT_CERTIFICATE_PATH`. |
| `AZURE_CLIENT_SECRET` | No | Service Principal client secret. Alternative to Managed Identity for local/CI use. |
| `AZURE_CLIENT_CERTIFICATE_PATH` | No | Path to a PEM/PKCS12 certificate for Service Principal auth. |
| `AZURE_AD_TOKEN` | No | Pre-fetched Bearer token for Azure DevOps (`499b84ac-...` resource). Bypasses credential resolution — useful in pipelines. |

### Runtime

| Variable | Required | Description |
|---|---|---|
| `BICEP_EXTENSION_ADO_BASEURI` | Yes (Bicep side) | Base URL the Bicep engine uses to reach this provider. Set on the machine running `az deployment`, not inside the container. Typically `http://localhost:8080`. |

---

## License

MIT — © ITLusions
