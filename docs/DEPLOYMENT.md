# Deployment Guide

Production deployment patterns for the ITL Bicep Azure DevOps extensibility provider.

## Overview

The provider must be running and network-accessible when you execute `az deployment` commands. This guide covers deployment options ranging from local development to enterprise production environments.

**Most users don't need a dedicated server!** The simplest approach is to run the provider as a **service container** in your CI/CD pipeline and communicate with it via `localhost` or the service container hostname. This requires zero infrastructure management and costs nothing extra. See [CI/CD Service Containers](#5-cicd-service-containers) below.

## Deployment Options Comparison

| Option | Use Case | Complexity | Cost | Scalability |
|---|---|---|---|---|
| **Service Containers (CI/CD)** | Pipeline-only usage (recommended) | Low | Included | N/A |
| **Local Docker** | Development, testing | Low | Free | N/A |
| **Azure Container Instances** | Simple production, CI/CD | Low | ~$15/month | Low |
| **Azure Kubernetes Service** | Enterprise, high availability | High | ~$70/month+ | High |
| **Azure App Service** | Managed PaaS, easy scaling | Medium | ~$50/month+ | Medium |

**Recommended starting point** — No infrastructure to manage, no extra cost, provider spins up only when pipeline runs.

---

## 1. Local Development

### Using Docker

**Best for**: Local testing, development

```bash
# Build image (.NET implementation)
docker build -f Dockerfile -t itl-ado-provider:local .

# Run with Azure CLI credential
az login
docker run --rm -p 8080:8080 \
  -v ~/.azure:/root/.azure:ro \
  itl-ado-provider:local
```

**Verify**:

```bash
curl http://localhost:8080/health
# Expected: {"status": "healthy"}
```

### Using Native Runtime

#### .NET

```bash
cd src/ITL.Bicep.Extensions.AzureDevOps
az login
dotnet run
```

#### Python

```bash
cd src/itl_bicep_ext_azuredevops
az login
pip install -e ".[dev]"
python -m itl_bicep_ext_azuredevops
```

#### PowerShell

```powershell
Connect-AzAccount
pwsh ./src/ITL.Bicep.Extensions.AzureDevOps.PS/Server.ps1
```

---

## 2. Azure Container Instances (ACI)

**Best for**: Simple production, CI/CD workloads, low traffic

### Prerequisites

- Azure Container Registry (ACR)
- User-assigned Managed Identity with ADO org membership

### Setup

```bash
# 1. Build and push to ACR
az acr login --name myacr
docker build -f Dockerfile -t myacr.azurecr.io/itl-ado-provider:1.0.0 .
docker push myacr.azurecr.io/itl-ado-provider:1.0.0

# 2. Create user-assigned managed identity
az identity create \
  --name ado-provider-identity \
  --resource-group my-rg

# Get identity client ID
IDENTITY_ID=$(az identity show \
  --name ado-provider-identity \
  --resource-group my-rg \
  --query clientId -o tsv)

# 3. Add managed identity to Azure DevOps org
# Go to: https://dev.azure.com/{org}/_settings/users
# Add the identity using its Object ID (from Azure portal)

# 4. Deploy ACI with managed identity
az container create \
  --name ado-provider \
  --resource-group my-rg \
  --image myacr.azurecr.io/itl-ado-provider:1.0.0 \
  --acr-identity $(az identity show --name ado-provider-identity --resource-group my-rg --query id -o tsv) \
  --assign-identity $(az identity show --name ado-provider-identity --resource-group my-rg --query id -o tsv) \
  --environment-variables AZURE_CLIENT_ID=$IDENTITY_ID \
  --ports 8080 \
  --cpu 1 \
  --memory 1.5 \
  --dns-name-label ado-provider-unique \
  --restart-policy Always
```

### Get Endpoint

```bash
FQDN=$(az container show \
  --name ado-provider \
  --resource-group my-rg \
  --query ipAddress.fqdn -o tsv)

echo "Provider endpoint: http://$FQDN:8080"
```

Update `bicepconfig.json`:

```json
{
  "extensions": {
    "ado": "http://ado-provider-unique.region.azurecontainer.io:8080"
  }
}
```

### VNet Integration (Private Network)

```bash
# Create VNet and subnet
az network vnet create \
  --name provider-vnet \
  --resource-group my-rg \
  --address-prefix 10.0.0.0/16

az network vnet subnet create \
  --name aci-subnet \
  --resource-group my-rg \
  --vnet-name provider-vnet \
  --address-prefix 10.0.1.0/24 \
  --delegations Microsoft.ContainerInstance/containerGroups

# Deploy ACI to VNet
az container create \
  --name ado-provider \
  --resource-group my-rg \
  --image myacr.azurecr.io/itl-ado-provider:1.0.0 \
  --vnet provider-vnet \
  --subnet aci-subnet \
  --assign-identity $(az identity show --name ado-provider-identity --resource-group my-rg --query id -o tsv) \
  --ports 8080 \
  --cpu 1 \
  --memory 1.5 \
  --restart-policy Always
```

**Access via VNet**: Deploy an Azure Bastion host or VPN gateway, then use the private IP address.

---

## 3. Azure Kubernetes Service (AKS)

**Best for**: Enterprise, high availability, auto-scaling

### Prerequisites

- AKS cluster with workload identity enabled
- Helm 3

### Setup

#### 1. Create Kubernetes Resources

`deployment.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ado-provider
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ado-provider
  namespace: ado-provider
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ado-provider
  template:
    metadata:
      labels:
        app: ado-provider
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: ado-provider-sa
      containers:
      - name: provider
        image: myacr.azurecr.io/itl-ado-provider:1.0.0
        ports:
        - containerPort: 8080
        env:
        - name: AZURE_CLIENT_ID
          value: "<federated-identity-client-id>"
        - name: AZURE_TENANT_ID
          value: "<tenant-id>"
        - name: AZURE_FEDERATED_TOKEN_FILE
          value: /var/run/secrets/azure/tokens/azure-identity-token
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: ado-provider
  namespace: ado-provider
spec:
  type: LoadBalancer  # or ClusterIP for internal access only
  selector:
    app: ado-provider
  ports:
  - port: 80
    targetPort: 8080
```

#### 2. Configure Workload Identity

```bash
# Create managed identity
az identity create \
  --name ado-provider-aks \
  --resource-group my-rg

IDENTITY_CLIENT_ID=$(az identity show --name ado-provider-aks --resource-group my-rg --query clientId -o tsv)
IDENTITY_OBJECT_ID=$(az identity show --name ado-provider-aks --resource-group my-rg --query principalId -o tsv)

# Get AKS OIDC issuer
AKS_OIDC_ISSUER=$(az aks show --name my-aks --resource-group my-rg --query oidcIssuerProfile.issuerUrl -o tsv)

# Create federated credential
az identity federated-credential create \
  --name ado-provider-fedcred \
  --identity-name ado-provider-aks \
  --resource-group my-rg \
  --issuer $AKS_OIDC_ISSUER \
  --subject system:serviceaccount:ado-provider:ado-provider-sa

# Add identity to ADO org (use IDENTITY_OBJECT_ID in ADO UI)
```

#### 3. Create Service Account

`serviceaccount.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ado-provider-sa
  namespace: ado-provider
  annotations:
    azure.workload.identity/client-id: "<federated-identity-client-id>"
```

#### 4. Deploy

```bash
kubectl apply -f serviceaccount.yaml
kubectl apply -f deployment.yaml

# Get LoadBalancer IP
kubectl get svc ado-provider -n ado-provider
```

Update `bicepconfig.json`:

```json
{
  "extensions": {
    "ado": "http://<loadbalancer-ip>"
  }
}
```

#### 5. Internal Access Only (Recommended)

For production, use ClusterIP service + Ingress:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ado-provider
  namespace: ado-provider
spec:
  type: ClusterIP  # Internal only
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ado-provider
  namespace: ado-provider
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: ado-provider.internal.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ado-provider
            port:
              number: 80
```

---

## 4. Azure App Service

**Best for**: Managed PaaS, easy scaling, no Kubernetes overhead

### Setup

```bash
# 1. Create App Service Plan (Linux)
az appservice plan create \
  --name ado-provider-plan \
  --resource-group my-rg \
  --is-linux \
  --sku B1

# 2. Create Web App
az webapp create \
  --name ado-provider-webapp \
  --resource-group my-rg \
  --plan ado-provider-plan \
  --deployment-container-image-name myacr.azurecr.io/itl-ado-provider:1.0.0

# 3. Configure managed identity
az webapp identity assign \
  --name ado-provider-webapp \
  --resource-group my-rg

IDENTITY_PRINCIPAL_ID=$(az webapp identity show \
  --name ado-provider-webapp \
  --resource-group my-rg \
  --query principalId -o tsv)

# Add identity to ADO org (use IDENTITY_PRINCIPAL_ID in ADO UI)

# 4. Configure environment variables
az webapp config appsettings set \
  --name ado-provider-webapp \
  --resource-group my-rg \
  --settings PORT=8080

# 5. Enable container logging
az webapp log config \
  --name ado-provider-webapp \
  --resource-group my-rg \
  --docker-container-logging filesystem
```

Get endpoint:

```bash
WEBAPP_URL=$(az webapp show \
  --name ado-provider-webapp \
  --resource-group my-rg \
  --query defaultHostName -o tsv)

echo "Provider endpoint: https://$WEBAPP_URL"
```

Update `bicepconfig.json`:

```json
{
  "extensions": {
    "ado": "https://ado-provider-webapp.azurewebsites.net"
  }
}
```

### VNet Integration

```bash
# Create VNet integration
az webapp vnet-integration add \
  --name ado-provider-webapp \
  --resource-group my-rg \
  --vnet provider-vnet \
  --subnet webapp-subnet

# Enable private endpoint
az network private-endpoint create \
  --name ado-provider-pe \
  --resource-group my-rg \
  --vnet-name provider-vnet \
  --subnet private-endpoint-subnet \
  --connection-name ado-provider-conn \
  --private-connection-resource-id $(az webapp show --name ado-provider-webapp --resource-group my-rg --query id -o tsv) \
  --group-id sites
```

---

## 5. CI/CD Service Containers (Recommended)

**Best for**: Pipeline deployments (no dedicated server needed!)

**Why this is the simplest approach:**
- Provider spins up automatically when your pipeline runs
- No infrastructure to manage or pay for
- Communicate via `localhost` (GitHub Actions) or service name (Azure Pipelines)
- Uses the pipeline's managed identity for authentication
- Provider shuts down when pipeline completes

### Azure Pipelines

`azure-pipelines.yml`:

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

resources:
  containers:
  - container: ado_provider
    image: myacr.azurecr.io/itl-ado-provider:1.0.0
    endpoint: myACRServiceConnection  # ACR service connection
    ports:
    - 8080:8080

services:
  ado_provider: ado_provider

steps:
- task: AzureCLI@2
  inputs:
    azureSubscription: 'my-azure-connection'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      # Provider runs at http://ado-provider:8080 (service container name)
      
      # Update bicepconfig.json to point to service container
      cat > bicepconfig.json <<EOF
      {
        "experimentalFeaturesEnabled": { "extensibility": true },
        "extensions": {
          "ado": "http://ado_provider:8080"
        }
      }
      EOF
      
      # Deploy Bicep template
      az deployment group create \
        --resource-group my-rg \
        --template-file connections/main.bicep \
        --parameters @connections/params.json
```

**Note**: The service container uses the pipeline's managed identity for authentication.

### GitHub Actions

`.github/workflows/deploy.yml`:

```yaml
name: Deploy Service Connections

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    services:
      ado-provider:
        image: ghcr.io/itlusions/itl-ado-provider:latest
        ports:
          - 8080:8080
        credentials:
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Deploy Connections
      run: |
        # Provider runs at http://localhost:8080
        cat > bicepconfig.json <<EOF
        {
          "experimentalFeaturesEnabled": { "extensibility": true },
          "extensions": {
            "ado": "http://localhost:8080"
          }
        }
        EOF
        
        az deployment group create \
          --resource-group my-rg \
          --template-file connections/main.bicep \
          --parameters @connections/params.json
```

---

## Security Considerations

### Network Security

**Production recommendations**:

1. **Private network only**: Deploy provider in VNet, no public IP
2. **Firewall rules**: Restrict access to deployment machine IPs
3. **VPN/Bastion**: Access via VPN or Azure Bastion for internal deployments
4. **TLS/HTTPS**: Use Application Gateway or Ingress Controller for HTTPS termination

### Identity Security

**Best practices**:

1. **Use managed identity** (no secrets)
2. **Least privilege**: Grant only "Service Connections: Read & manage" permission
3. **Separate identities per environment**: dev/staging/prod identities
4. **Audit access**: Monitor ADO org member additions via Azure Activity Log

### Secret Management

**For connection secrets** (e.g., GitHub PAT, SP client secret):

1. Store in **Azure Key Vault**
2. Reference in Bicep as `@secure()` parameters
3. Use Key Vault integration in Azure Pipelines/GitHub Actions
4. Rotate secrets regularly

Example:

```yaml
# Azure Pipelines
variables:
- group: my-keyvault-secrets  # Variable group linked to Key Vault

steps:
- task: AzureCLI@2
  inputs:
    inlineScript: |
      az deployment group create \
        --template-file main.bicep \
        --parameters githubToken=$(githubToken)  # From Key Vault
```

---

## Monitoring & Observability

### Logging

All implementations emit structured JSON logs to stdout. Configure log collection:

**Azure Container Insights (AKS)**:

```bash
az aks enable-addons \
  --name my-aks \
  --resource-group my-rg \
  --addons monitoring
```

Query logs in Log Analytics:

```kusto
ContainerLog
| where ContainerName == "provider"
| project TimeGenerated, LogEntry
| order by TimeGenerated desc
```

**App Service Logs**:

```bash
# Stream logs
az webapp log tail --name ado-provider-webapp --resource-group my-rg

# Download logs
az webapp log download --name ado-provider-webapp --resource-group my-rg
```

### Metrics

**.NET implementation** exposes Prometheus metrics on `/metrics`:

```bash
curl http://provider-endpoint:8080/metrics
```

Scrape with Prometheus or Azure Monitor:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'ado-provider'
    static_configs:
      - targets: ['ado-provider:8080']
```

Key metrics:
- `bicep_extension_requests_total` (counter)
- `bicep_extension_request_duration_seconds` (histogram)
- `bicep_extension_ado_api_calls_total` (counter)

### Health Checks

All implementations expose `/health` endpoint:

```bash
curl http://provider-endpoint:8080/health
# Response: {"status": "healthy"}
```

Configure Kubernetes liveness/readiness probes or App Service health check path.

---

## Cost Optimization

### ACI

- **Baseline**: ~$15/month (1 vCPU, 1.5 GB RAM, always on)
- **Optimization**: Use Azure Automation to start/stop ACI on schedule (e.g., business hours only)

### AKS

- **Baseline**: ~$70/month (2-node cluster, B2s VMs)
- **Optimization**:
  - Use **Azure Spot VMs** for non-critical environments (~80% cost reduction)
  - Enable **Cluster Autoscaler** (scale to 0 when idle)
  - Use **B-series Burstable VMs** for low-traffic workloads

### App Service

- **Baseline**: ~$50/month (B1 plan)
- **Optimization**:
  - Use **Free tier** for dev/test (1 GB RAM, 60 min CPU/day)
  - Use **Shared tier** ($10/month) for light production workloads
  - Enable **Autoscale** to scale down during off-peak hours

---

## High Availability

### AKS HA Setup

```yaml
# 3 replicas across availability zones
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - ado-provider
            topologyKey: topology.kubernetes.io/zone
```

### App Service HA

- Enable **Zone Redundancy** (Premium v2/v3 plans)
- Use **Traffic Manager** or **Front Door** for multi-region failover

### Load Testing

Before production, test with expected load:

```bash
# Apache Bench
ab -n 1000 -c 10 http://provider-endpoint:8080/health

# k6
k6 run --vus 10 --duration 30s loadtest.js
```

Expected performance:
- Latency: 100-500ms per connection create/update
- Throughput: 10-50 requests/sec (single instance)

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common deployment issues and solutions.
