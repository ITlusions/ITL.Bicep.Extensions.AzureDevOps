# Troubleshooting Guide

Common issues and solutions when deploying and using the ITL Bicep Azure DevOps extensibility provider.

## Quick Diagnostics

### Check Provider Health

```bash
curl http://provider-endpoint:8080/health
# Expected: {"status": "healthy"}
```

### Test Authentication

```bash
# Get Azure AD token manually
az account get-access-token \
  --resource 499b84ac-1321-427f-aa17-267ca6975798 \
  --query accessToken -o tsv

# Set as environment variable and restart provider
export AZURE_AD_TOKEN="<token>"
docker run -e AZURE_AD_TOKEN -p 8080:8080 itl-ado-provider:latest
```

### Enable Verbose Logging

**.NET**:

```bash
docker run -e ASPNETCORE_ENVIRONMENT=Development \
  -e Logging__LogLevel__Default=Debug \
  -p 8080:8080 itl-ado-provider:latest
```

**Python**:

```bash
docker run -e LOG_LEVEL=DEBUG -p 8080:8080 itl-ado-provider-py:latest
```

**PowerShell**:

```powershell
$env:VERBOSE = "true"
pwsh ./Server.ps1
```

---

## Authentication Issues

### Error: `401 Unauthorized` from ADO API

**Symptom**:

```
ExtensionError: Failed to create service connection
HTTP 401: Unauthorized
```

**Cause**: The identity (service principal, managed identity, or user) is not a member of the Azure DevOps organization.

**Solution**:

1. Get the identity's Object ID:
   ```bash
   # Service Principal
   az ad sp show --id <client-id> --query id -o tsv
   
   # Managed Identity
   az identity show --name <mi-name> --resource-group <rg> --query principalId -o tsv
   
   # Current user
   az ad signed-in-user show --query id -o tsv
   ```

2. Add the identity to ADO:
   - Navigate to: `https://dev.azure.com/{org}/_settings/users`
   - Click **Add users**
   - Paste the Object ID
   - Assign **Basic** access level
   - Click **Add**

3. Wait 5-10 minutes for changes to propagate

4. Retry deployment

---

### Error: `403 Forbidden` from ADO API

**Symptom**:

```
ExtensionError: Insufficient permissions
HTTP 403: Forbidden - User does not have permissions to create service connections
```

**Cause**: The identity lacks "Service Connections: Read & manage" permission.

**Solution**:

**Organization-level** (recommended):

1. Go to: `https://dev.azure.com/{org}/_settings/security`
2. Find the identity in the users list
3. Click **Permissions**
4. Set **Service Connections: Read & manage** to **Allow**

**Project-level**:

1. Go to: `https://dev.azure.com/{org}/{project}/_settings/adminservices`
2. Click **Security** tab
3. Add the identity to the **Administrators** group

**Verify permissions**:

```bash
# List service connections (should return 200 OK)
curl -H "Authorization: Bearer $TOKEN" \
  "https://dev.azure.com/{org}/{project}/_apis/serviceendpoint/endpoints?api-version=7.1"
```

---

### Error: `DefaultAzureCredential failed to retrieve a token`

**Symptom**:

```
Azure.Identity.AuthenticationFailedException:
DefaultAzureCredential failed to retrieve a token from the included credentials.
```

**Cause**: No credential source is available (not logged in, no managed identity, no environment variables).

**Solution**:

**Local development**:

```bash
az login
# Verify
az account show
```

**ACI/AKS/App Service**:

Ensure managed identity is assigned:

```bash
# ACI
az container show --name <name> --resource-group <rg> --query identity

# AKS (check pod service account)
kubectl describe pod <pod-name> -n <namespace>

# App Service
az webapp identity show --name <name> --resource-group <rg>
```

**Manual token override** (testing):

```bash
TOKEN=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
docker run -e AZURE_AD_TOKEN=$TOKEN -p 8080:8080 itl-ado-provider:latest
```

---

## Bicep Compilation Errors

### Error: `Extension 'ado' is not configured`

**Symptom**:

```
Error BCP204: Extension 'ado' is not defined in the bicepconfig.json file
```

**Solution**:

Create or update `bicepconfig.json`:

```json
{
  "experimentalFeaturesEnabled": {
    "extensibility": true
  },
  "extensions": {
    "ado": "http://localhost:8080"
  }
}
```

Place in the same directory as your `.bicep` file.

---

### Error: `Cannot connect to extension endpoint`

**Symptom**:

```
Error BCP999: Failed to communicate with extension 'ado'
Connection refused: http://localhost:8080
```

**Cause**: Provider is not running or not accessible.

**Solution**:

1. Start the provider:
   ```bash
   docker run -p 8080:8080 itl-ado-provider:latest
   ```

2. Verify it's running:
   ```bash
   curl http://localhost:8080/health
   ```

3. Check firewall rules (Windows):
   ```powershell
   New-NetFirewallRule -DisplayName "Bicep Provider" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
   ```

4. If using a remote endpoint, update `bicepconfig.json`:
   ```json
   {
     "extensions": {
       "ado": "http://provider.example.com:8080"
     }
   }
   ```

---

### Error: `Property 'identifiers' is required`

**Symptom**:

```
Error BCP035: The property 'identifiers' is required but wasn't found
```

**Solution**:

Ensure `identifiers` block is present:

```bicep
resource conn 'ServiceConnection@2024-01-01' = {
  identifiers: {                    // ✅ Required
    organization: 'my-org'
    project: 'my-project'
    name: 'my-conn'
  }
  properties: { ... }
}
```

---

## Azure DevOps API Errors

### Error: `Project does not exist`

**Symptom**:

```
HTTP 404: Project 'my-project' does not exist
```

**Solution**:

1. Verify project name (case-sensitive):
   ```bash
   # List projects
   az devops project list --org https://dev.azure.com/my-org
   ```

2. Ensure the identity has access to the project:
   - Go to: `https://dev.azure.com/{org}/{project}/_settings/security`
   - Add the identity to **Project Valid Users**

---

### Error: `Service connection name already exists`

**Symptom**:

```
HTTP 409: A service connection with name 'my-conn' already exists
```

**Cause**: Another connection with the same name exists (possibly created manually).

**Solution**:

1. **Option A**: Use a different name in Bicep

2. **Option B**: Delete the existing connection:
   - Go to: `https://dev.azure.com/{org}/{project}/_settings/adminservices`
   - Find the connection
   - Delete it
   - Retry deployment

3. **Option C**: Update the existing connection (provider handles this automatically if identifiers match)

---

### Error: `Rate limit exceeded`

**Symptom**:

```
HTTP 429: Too Many Requests
Retry after: 60 seconds
```

**Cause**: ADO API rate limit hit (200 requests per minute per identity).

**Solution**:

1. **Reduce deployment frequency** (batch connection creates)

2. **Implement retry logic** (provider includes exponential backoff)

3. **Use separate identities** for different environments (dev/staging/prod)

4. **Contact Microsoft Support** to increase rate limits for your organization

---

## Deployment Errors

### Error: `Connection timeout` during deployment

**Symptom**:

```
az deployment group create: Connection timeout after 90 seconds
```

**Cause**: Provider is slow to respond (ADO API latency, network issues).

**Solution**:

1. **Increase timeout**:
   ```bash
   az deployment group create \
     --timeout 300 \  # 5 minutes
     --template-file main.bicep
   ```

2. **Check provider logs**:
   ```bash
   docker logs <container-id>
   ```

3. **Test ADO API latency**:
   ```bash
   time curl -H "Authorization: Bearer $TOKEN" \
     "https://dev.azure.com/{org}/_apis/projects?api-version=7.1"
   ```

---

### Error: `Failed to pull provider image`

**Symptom**:

```
Error: Failed to pull image 'myacr.azurecr.io/itl-ado-provider:1.0.0'
```

**Solution**:

1. **Login to ACR**:
   ```bash
   az acr login --name myacr
   ```

2. **Verify image exists**:
   ```bash
   az acr repository show-tags --name myacr --repository itl-ado-provider
   ```

3. **For ACI/AKS**: Assign ACR pull permission to managed identity:
   ```bash
   az role assignment create \
     --assignee <identity-principal-id> \
     --role AcrPull \
     --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/myacr
   ```

---

## Container Issues

### Provider container crashes on startup

**Symptom**:

```bash
docker ps -a
# STATUS: Exited (137) 10 seconds ago
```

**Solution**:

1. **Check logs**:
   ```bash
   docker logs <container-id>
   ```

2. **Common causes**:
   - **Out of memory**: Increase memory limit
     ```bash
     docker run -m 1g -p 8080:8080 itl-ado-provider:latest
     ```
   - **Port already in use**: Use a different port
     ```bash
     docker run -p 8081:8080 itl-ado-provider:latest
     ```
   - **Missing environment variable**: Check required vars
     ```bash
     docker run -e AZURE_CLIENT_ID=<id> -p 8080:8080 itl-ado-provider:latest
     ```

---

### Port 8080 already in use

**Symptom**:

```
Error: bind: address already in use
```

**Solution**:

1. **Find process using port**:
   ```bash
   # Linux/macOS
   lsof -i :8080
   
   # Windows
   netstat -ano | findstr :8080
   ```

2. **Kill process or use different port**:
   ```bash
   docker run -p 8081:8080 itl-ado-provider:latest
   ```
   
   Update `bicepconfig.json`:
   ```json
   {
     "extensions": {
       "ado": "http://localhost:8081"
     }
   }
   ```

---

## Performance Issues

### Slow deployments (>10 seconds per connection)

**Symptoms**:
- Bicep compilation takes >1 minute for 5 connections
- Provider logs show >5s per ADO API call

**Causes & Solutions**:

1. **Network latency**:
   - **Solution**: Deploy provider closer to ADO region
   - **Check latency**: `ping dev.azure.com`

2. **Token acquisition latency**:
   - **Solution**: Use managed identity instead of Azure CLI credential
   - **Verify**: Check provider logs for "Token acquired in Xms"

3. **ADO API throttling**:
   - **Solution**: Reduce connection create frequency
   - **Verify**: Check response headers for `X-RateLimit-Remaining`

---

## Data Issues

### Connection properties not updated

**Symptom**:

Bicep deployment succeeds, but connection properties in ADO UI don't match template.

**Cause**: ADO API returns stale data (cache).

**Solution**:

1. **Force refresh** in ADO UI (Ctrl+F5)

2. **Wait 1-2 minutes** for ADO cache to expire

3. **Verify via API**:
   ```bash
   curl -H "Authorization: Bearer $TOKEN" \
     "https://dev.azure.com/{org}/{project}/_apis/serviceendpoint/endpoints/{id}?api-version=7.1"
   ```

---

### Secure parameters not working

**Symptom**:

```
Error: Cannot read secure parameter 'clientSecret'
```

**Solution**:

Ensure parameter is marked `@secure()`:

```bicep
@secure()
param clientSecret string  // ✅ Correct

// ❌ Wrong:
param clientSecret string
```

Pass via command line or parameter file (not in template):

```bash
az deployment group create \
  --template-file main.bicep \
  --parameters clientSecret=$SECRET
```

---

## CI/CD Issues

### Service container not accessible in Azure Pipelines

**Symptom**:

```
Error: Connection refused: http://ado-provider:8080
```

**Solution**:

Use the service container name (not `localhost`):

```yaml
services:
  ado_provider: ado_provider  # Container name

steps:
- script: |
    # Use container name as hostname
    curl http://ado_provider:8080/health
```

Update `bicepconfig.json`:

```json
{
  "extensions": {
    "ado": "http://ado_provider:8080"
  }
}
```

---

### GitHub Actions service container not starting

**Symptom**:

```
Error: Failed to pull image: unauthorized
```

**Solution**:

Add credentials to service:

```yaml
services:
  ado-provider:
    image: ghcr.io/itlusions/itl-ado-provider:latest
    credentials:
      username: ${{ github.actor }}
      password: ${{ secrets.GITHUB_TOKEN }}
```

---

## Getting Help

### Enable Debug Logging

**.NET**:

```bash
docker run \
  -e ASPNETCORE_ENVIRONMENT=Development \
  -e Logging__LogLevel__Default=Debug \
  -e Logging__LogLevel__Microsoft=Information \
  -e Logging__LogLevel__ITL=Debug \
  -p 8080:8080 itl-ado-provider:latest
```

**Python**:

```bash
docker run -e LOG_LEVEL=DEBUG -p 8080:8080 itl-ado-provider-py:latest
```

**PowerShell**:

```powershell
$VerbosePreference = "Continue"
pwsh ./Server.ps1
```

### Collect Diagnostic Information

```bash
# Provider version
curl http://localhost:8080/health

# Azure CLI version
az --version

# Bicep CLI version
az bicep version

# Docker version
docker --version

# Container logs
docker logs <container-id> > provider-logs.txt

# Bicep verbose output
az deployment group create \
  --template-file main.bicep \
  --verbose > deployment-logs.txt 2>&1
```

### Report Issues

When reporting issues, include:

1. **Provider logs** (with DEBUG level enabled)
2. **Bicep template** (sanitize secrets)
3. **bicepconfig.json**
4. **Deployment command** and output
5. **Environment** (local/ACI/AKS/App Service)
6. **Versions** (Bicep CLI, Azure CLI, provider image tag)

Open an issue at: https://github.com/itlusions/ITL.Bicep.Extensions.AzureDevOps/issues

---

## Common Error Messages Reference

| Error | HTTP | Cause | Fix |
|---|---|---|---|
| `DefaultAzureCredential failed` | N/A | No auth source | `az login` or assign managed identity |
| `Unauthorized` | 401 | Not in ADO org | Add identity to org |
| `Forbidden` | 403 | No permissions | Grant "Service Connections" permission |
| `Not Found` | 404 | Project doesn't exist | Verify project name |
| `Conflict` | 409 | Name already exists | Choose different name or delete existing |
| `Rate limit exceeded` | 429 | Too many requests | Wait and retry, reduce frequency |
| `Internal Server Error` | 500 | Provider crash | Check logs, restart provider |
| `Bad Gateway` | 502 | ADO API unavailable | Retry later |
| `Connection refused` | N/A | Provider not running | Start provider |
| `Extension not configured` | N/A | Missing bicepconfig.json | Create config file |
