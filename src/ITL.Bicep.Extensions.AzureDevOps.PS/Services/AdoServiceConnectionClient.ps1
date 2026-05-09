# Services/AdoServiceConnectionClient.ps1
# Wraps the Azure DevOps Service Endpoints REST API v7.1.
# Mirrors AdoServiceConnectionClient.cs and ado_client.py.

$Script:AdoApiVersion = '7.1'

# Well-known Azure AD application ID for Azure DevOps
$Script:AdoResourceId = '499b84ac-1321-427f-aa17-267ca6975798'
$Script:AdoImdsUri    = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$Script:AdoResourceId"

$Script:DefaultUrls = @{
    azurerm = 'https://management.azure.com/'
    github  = 'https://github.com/'
}

function Get-AdoAuthHeader {
    <#
    .SYNOPSIS
        Returns HTTP headers with an Azure AD Bearer token for the ADO REST API.

    .DESCRIPTION
        Authentication priority:
          1. AZURE_AD_TOKEN env var     — explicit override (testing / local dev)
          2. IMDS endpoint              — Managed Identity or Workload Identity (AKS)
             Optionally scoped to AZURE_CLIENT_ID for user-assigned managed identity.
          3. Az.Accounts module         — 'Get-AzAccessToken' after 'Connect-AzAccount'
             Useful for local development without a managed identity.

        No PAT required. The identity used must be a member of the Azure DevOps
        organisation with "Service Connections: Read & manage" permission.
    #>

    # ---- 1. Explicit token override (testing / CI with pre-fetched token) ----
    if ($env:AZURE_AD_TOKEN) {
        return @{
            Authorization  = "Bearer $env:AZURE_AD_TOKEN"
            Accept         = 'application/json'
            'Content-Type' = 'application/json'
        }
    }

    # ---- 2. IMDS — Managed Identity / Workload Identity (AKS) ----
    try {
        $imdsUri = $Script:AdoImdsUri
        if ($env:AZURE_CLIENT_ID) {
            $imdsUri += "&client_id=$([uri]::EscapeDataString($env:AZURE_CLIENT_ID))"
        }
        $resp = Invoke-RestMethod -Uri $imdsUri -Headers @{ Metadata = 'true' } `
                                  -Method Get -TimeoutSec 3 -ErrorAction Stop
        return @{
            Authorization  = "Bearer $($resp.access_token)"
            Accept         = 'application/json'
            'Content-Type' = 'application/json'
        }
    }
    catch {
        # IMDS not reachable — fall through to Az.Accounts
    }

    # ---- 3. Az.Accounts module (local dev after Connect-AzAccount) ----
    if (Get-Module -Name Az.Accounts -ListAvailable -ErrorAction SilentlyContinue) {
        $tokenResp = Get-AzAccessToken -ResourceUrl "https://app.vssps.visualstudio.com" `
                                       -ErrorAction Stop
        return @{
            Authorization  = "Bearer $($tokenResp.Token)"
            Accept         = 'application/json'
            'Content-Type' = 'application/json'
        }
    }

    throw (
        "No Azure credential found. Options:`n" +
        "  - Run in a container/VM with a Managed Identity or Workload Identity (AKS).`n" +
        "  - Install Az module and run Connect-AzAccount for local development.`n" +
        "  - Set AZURE_AD_TOKEN to a pre-fetched Bearer token."
    )
}

function Get-AdoConnectionByName {
    param(
        [string]$Organization,
        [string]$Project,
        [string]$Name
    )
    $url = "https://dev.azure.com/$Organization/$Project/_apis/serviceendpoint/endpoints" +
           "?endpointNames=$Name&api-version=$Script:AdoApiVersion"
    try {
        $resp = Invoke-RestMethod -Uri $url -Headers (Get-AdoAuthHeader) -Method Get -ErrorAction Stop
        foreach ($ep in $resp.value) {
            if ($ep.name -ieq $Name) { return $ep }
        }
        return $null
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) { return $null }
        throw
    }
}

function New-AdoConnection {
    param(
        [string]   $Organization,
        [string]   $Project,
        [hashtable]$Props
    )
    $url     = "https://dev.azure.com/$Organization/$Project/_apis/serviceendpoint/endpoints?api-version=$Script:AdoApiVersion"
    $payload = Build-AdoPayload -Props $Props -Project $Project | ConvertTo-Json -Depth 10
    return Invoke-RestMethod -Uri $url -Headers (Get-AdoAuthHeader) -Method Post -Body $payload -ErrorAction Stop
}

function Update-AdoConnection {
    param(
        [string]   $Organization,
        [string]   $Project,
        [string]   $EndpointId,
        [hashtable]$Props
    )
    $url     = "https://dev.azure.com/$Organization/$Project/_apis/serviceendpoint/endpoints/$EndpointId`?api-version=$Script:AdoApiVersion"
    $payload = Build-AdoPayload -Props $Props -Project $Project
    $payload['id'] = $EndpointId
    return Invoke-RestMethod -Uri $url -Headers (Get-AdoAuthHeader) -Method Put -Body ($payload | ConvertTo-Json -Depth 10) -ErrorAction Stop
}

function Remove-AdoConnection {
    param(
        [string]$Organization,
        [string]$Project,
        [string]$EndpointId
    )
    $url = "https://dev.azure.com/$Organization/$Project/_apis/serviceendpoint/endpoints/$EndpointId`?api-version=$Script:AdoApiVersion"
    try {
        Invoke-RestMethod -Uri $url -Headers (Get-AdoAuthHeader) -Method Delete -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) { return $false }
        throw
    }
}

function Build-AdoPayload {
    param([hashtable]$Props, [string]$Project)
    $connType = $Props['type']
    return @{
        name          = $Props['name']
        type          = $connType
        url           = $Props['url'] ?? $Script:DefaultUrls[$connType.ToLower()] ?? 'https://dev.azure.com/'
        authorization = $Props['authorization']
        data          = $Props['data'] ?? @{}
        isShared      = $Props['isShared'] ?? $false
        serviceEndpointProjectReferences = @(
            @{
                projectReference = @{ name = $Project }
                name             = $Props['name']
            }
        )
    }
}
