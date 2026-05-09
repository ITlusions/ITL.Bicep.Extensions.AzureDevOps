#!/usr/bin/env pwsh
# Forwarding stub — entry point moved to the structured project layout.
# Use:  pwsh ./src/ITL.Bicep.Extensions.AzureDevOps.PS/Server.ps1

& "$PSScriptRoot/ITL.Bicep.Extensions.AzureDevOps.PS/Server.ps1"

$ErrorActionPreference = 'Stop'

$Pat = $env:ADO_PAT
if (-not $Pat) {
    throw "Environment variable ADO_PAT is required."
}

Import-Module Pode

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Get-AuthHeader {
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes(":$Pat")
    $b64    = [Convert]::ToBase64String($bytes)
    return @{
        Authorization  = "Basic $b64"
        Accept         = 'application/json'
        'Content-Type' = 'application/json'
    }
}

function New-ResponseHeaders {
    return @{
        'x-ms-request-id' = [System.Guid]::NewGuid().ToString()
        'Date'            = [System.DateTime]::UtcNow.ToString('r')
    }
}

function Write-ErrorResponse {
    param(
        [string]$Code,
        [string]$Message,
        [string]$Target   = $null,
        [int]   $Status   = 400
    )
    $body = @{ error = @{ code = $Code; message = $Message } }
    if ($Target) { $body.error.target = $Target }
    $headers = New-ResponseHeaders
    foreach ($kv in $headers.GetEnumerator()) {
        Set-PodeHeader -Name $kv.Key -Value $kv.Value
    }
    Write-PodeJsonResponse -Value $body -StatusCode $Status
}

function Write-OkResponse {
    param([hashtable]$Body)
    $headers = New-ResponseHeaders
    foreach ($kv in $headers.GetEnumerator()) {
        Set-PodeHeader -Name $kv.Key -Value $kv.Value
    }
    Write-PodeJsonResponse -Value $Body -StatusCode 200
}

$SecretKeys = @('accesstoken','password','serviceprincipalkey','privatekey','apitoken')

function Remove-SecretParams {
    param([hashtable]$Params)
    if (-not $Params) { return $null }
    $clean = @{}
    foreach ($kv in $Params.GetEnumerator()) {
        if ($kv.Key.ToLower() -notin $SecretKeys) {
            $clean[$kv.Key] = $kv.Value
        }
    }
    return $clean
}

function Get-AdoUrl {
    param([string]$Organization, [string]$Project, [string]$Suffix = '')
    return "https://dev.azure.com/$Organization/$Project/_apis/serviceendpoint/endpoints?api-version=7.1$Suffix"
}

# ---------------------------------------------------------------------------
# ADO API calls
# ---------------------------------------------------------------------------

function Get-AdoConnectionByName {
    param([string]$Organization, [string]$Project, [string]$Name)
    $url = Get-AdoUrl -Organization $Organization -Project $Project -Suffix "&endpointNames=$Name"
    try {
        $resp = Invoke-RestMethod -Uri $url -Headers (Get-AuthHeader) -Method Get -ErrorAction Stop
        foreach ($ep in $resp.value) {
            if ($ep.name -ieq $Name) { return $ep }
        }
        return $null
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response.StatusCode -eq 404) { return $null }
        throw
    }
}

function New-AdoConnection {
    param([string]$Organization, [string]$Project, [hashtable]$Props)
    $payload = Build-AdoPayload -Props $Props -Project $Project | ConvertTo-Json -Depth 10
    $url = Get-AdoUrl -Organization $Organization -Project $Project
    return Invoke-RestMethod -Uri $url -Headers (Get-AuthHeader) -Method Post -Body $payload -ErrorAction Stop
}

function Update-AdoConnection {
    param([string]$Organization, [string]$Project, [string]$EndpointId, [hashtable]$Props)
    $payload = Build-AdoPayload -Props $Props -Project $Project
    $payload['id'] = $EndpointId
    $url = "https://dev.azure.com/$Organization/$Project/_apis/serviceendpoint/endpoints/$EndpointId`?api-version=7.1"
    return Invoke-RestMethod -Uri $url -Headers (Get-AuthHeader) -Method Put -Body ($payload | ConvertTo-Json -Depth 10) -ErrorAction Stop
}

function Remove-AdoConnection {
    param([string]$Organization, [string]$Project, [string]$EndpointId)
    $url = "https://dev.azure.com/$Organization/$Project/_apis/serviceendpoint/endpoints/$EndpointId`?api-version=7.1"
    try {
        Invoke-RestMethod -Uri $url -Headers (Get-AuthHeader) -Method Delete -ErrorAction Stop | Out-Null
        return $true
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response.StatusCode -eq 404) { return $false }
        throw
    }
}

function Build-AdoPayload {
    param([hashtable]$Props, [string]$Project)
    $connType = $Props['type']
    $defaultUrls = @{ azurerm = 'https://management.azure.com/'; github = 'https://github.com/' }
    return @{
        name          = $Props['name']
        type          = $connType
        url           = $Props['url'] ?? $defaultUrls[$connType.ToLower()] ?? 'https://dev.azure.com/'
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

function ConvertTo-ResourceBody {
    param([string]$Type, [string]$ApiVersion, [hashtable]$Identifiers, $AdoEndpoint)
    $auth = $AdoEndpoint.authorization
    $params = if ($auth.parameters) { Remove-SecretParams -Params ($auth.parameters | ConvertPSObject-ToHashtable) } else { @{} }
    return @{
        type        = $Type
        apiVersion  = $ApiVersion
        identifiers = $Identifiers
        properties  = @{
            name            = $AdoEndpoint.name
            type            = $AdoEndpoint.type
            url             = $AdoEndpoint.url
            authorization   = @{
                scheme     = $auth.scheme
                parameters = $params
            }
            data            = $AdoEndpoint.data ?? @{}
            isShared        = $AdoEndpoint.isShared
            id              = $AdoEndpoint.id
            operationStatus = $AdoEndpoint.operationStatus?.state
        }
    }
}

function ConvertPSObject-ToHashtable {
    param([Parameter(ValueFromPipeline)][object]$InputObject)
    process {
        if ($null -eq $InputObject)            { return $null }
        if ($InputObject -is [hashtable])      { return $InputObject }
        $ht = @{}
        $InputObject.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
        return $ht
    }
}

# ---------------------------------------------------------------------------
# Pode server
# ---------------------------------------------------------------------------

Start-PodeServer -Threads 4 {

    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # -----------------------------------------------------------------------
    # POST /{version}/resource/preview
    # -----------------------------------------------------------------------
    Add-PodeRoute -Method Post -Path '/:version/resource/preview' -ScriptBlock {
        $body  = $WebEvent.Data
        $props = $body.properties

        $connType = $props.type ?? ''
        $defaultUrls = @{ azurerm = 'https://management.azure.com/'; github = 'https://github.com/' }

        $preview = @{
            type        = $body.type
            apiVersion  = $body.apiVersion
            identifiers = @{ name = $props.name }
            properties  = $props + @{
                id              = '(assigned by Azure DevOps on create)'
                operationStatus = 'Ready'
                url             = $props.url ?? $defaultUrls[$connType.ToLower()] ?? 'https://dev.azure.com/'
            }
            metadata = @{
                readOnly   = @('/properties/id')
                calculated = @('/properties/id', '/properties/operationStatus')
            }
        }
        Write-OkResponse -Body $preview
    }

    # -----------------------------------------------------------------------
    # POST /{version}/resource/createOrUpdate
    # -----------------------------------------------------------------------
    Add-PodeRoute -Method Post -Path '/:version/resource/createOrUpdate' -ScriptBlock {
        $body  = $WebEvent.Data
        $props = $body.properties | ConvertPSObject-ToHashtable

        $org  = $props['organization']
        $proj = $props['project']
        $name = $props['name']

        if (-not ($org -and $proj -and $name)) {
            Write-ErrorResponse -Code 'MissingIdentifiers' -Message "properties must include 'organization', 'project', and 'name'."
            return
        }
        if (-not $props['type']) {
            Write-ErrorResponse -Code 'MissingProperty' -Message "Property 'type' is required." -Target '/properties/type'
            return
        }

        try {
            $existing = Get-AdoConnectionByName -Organization $org -Project $proj -Name $name
            if ($existing) {
                $result = Update-AdoConnection -Organization $org -Project $proj -EndpointId $existing.id -Props $props
            } else {
                $result = New-AdoConnection -Organization $org -Project $proj -Props $props
            }
        } catch {
            Write-ErrorResponse -Code 'AdoApiError' -Message $_.Exception.Message -Status 502
            return
        }

        $identifiers = @{ organization = $org; project = $proj; name = $name }
        $resource = ConvertTo-ResourceBody -Type $body.type -ApiVersion $body.apiVersion -Identifiers $identifiers -AdoEndpoint $result
        Write-OkResponse -Body $resource
    }

    # -----------------------------------------------------------------------
    # POST /{version}/resource/get
    # -----------------------------------------------------------------------
    Add-PodeRoute -Method Post -Path '/:version/resource/get' -ScriptBlock {
        $body        = $WebEvent.Data
        $identifiers = $body.identifiers | ConvertPSObject-ToHashtable

        $org  = $identifiers['organization']
        $proj = $identifiers['project']
        $name = $identifiers['name']

        if (-not ($org -and $proj -and $name)) {
            Write-ErrorResponse -Code 'MissingIdentifiers' -Message "identifiers must include 'organization', 'project', and 'name'."
            return
        }

        try {
            $ado = Get-AdoConnectionByName -Organization $org -Project $proj -Name $name
        } catch {
            Write-ErrorResponse -Code 'AdoApiError' -Message $_.Exception.Message -Status 502
            return
        }

        if (-not $ado) {
            $errBody = @{ error = @{ code = 'NotFound'; message = "Service connection '$name' not found in project '$proj'." } }
            $headers = New-ResponseHeaders
            foreach ($kv in $headers.GetEnumerator()) { Set-PodeHeader -Name $kv.Key -Value $kv.Value }
            Write-PodeJsonResponse -Value $errBody -StatusCode 404
            return
        }

        $resource = ConvertTo-ResourceBody -Type $body.type -ApiVersion $body.apiVersion -Identifiers $identifiers -AdoEndpoint $ado
        Write-OkResponse -Body $resource
    }

    # -----------------------------------------------------------------------
    # POST /{version}/resource/delete
    # -----------------------------------------------------------------------
    Add-PodeRoute -Method Post -Path '/:version/resource/delete' -ScriptBlock {
        $body        = $WebEvent.Data
        $identifiers = $body.identifiers | ConvertPSObject-ToHashtable

        $org  = $identifiers['organization']
        $proj = $identifiers['project']
        $name = $identifiers['name']

        if (-not ($org -and $proj -and $name)) {
            Write-ErrorResponse -Code 'MissingIdentifiers' -Message "identifiers must include 'organization', 'project', and 'name'."
            return
        }

        try {
            $existing = Get-AdoConnectionByName -Organization $org -Project $proj -Name $name
            if (-not $existing) {
                # Already gone — idempotent 204
                $headers = New-ResponseHeaders
                foreach ($kv in $headers.GetEnumerator()) { Set-PodeHeader -Name $kv.Key -Value $kv.Value }
                Set-PodeResponseStatus -Code 204
                return
            }
            Remove-AdoConnection -Organization $org -Project $proj -EndpointId $existing.id | Out-Null
        } catch {
            Write-ErrorResponse -Code 'AdoApiError' -Message $_.Exception.Message -Status 502
            return
        }

        $headers = New-ResponseHeaders
        foreach ($kv in $headers.GetEnumerator()) { Set-PodeHeader -Name $kv.Key -Value $kv.Value }
        Set-PodeResponseStatus -Code 204
    }

    # -----------------------------------------------------------------------
    # POST /{version}/longRunningOperation/get  (stub)
    # -----------------------------------------------------------------------
    Add-PodeRoute -Method Post -Path '/:version/longRunningOperation/get' -ScriptBlock {
        Write-ErrorResponse -Code 'UnknownOperation' -Message 'This extension does not use long-running operations.' -Status 404
    }
}
