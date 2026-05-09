# Models/ServiceConnectionModels.ps1
# Bicep Extensibility V2 contract helpers — mirrors contract.py and ServiceConnectionModels.cs
# Provides response-writing utilities and the resource body mapper.

$Script:SecretKeys = @('accesstoken', 'password', 'serviceprincipalkey', 'privatekey', 'apitoken')

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
        [string]$Target = $null,
        [int]   $Status = 400
    )
    $body = @{ error = @{ code = $Code; message = $Message } }
    if ($Target) { $body.error.target = $Target }

    foreach ($kv in (New-ResponseHeaders).GetEnumerator()) {
        Set-PodeHeader -Name $kv.Key -Value $kv.Value
    }
    Write-PodeJsonResponse -Value $body -StatusCode $Status
}

function Write-OkResponse {
    param([hashtable]$Body)
    foreach ($kv in (New-ResponseHeaders).GetEnumerator()) {
        Set-PodeHeader -Name $kv.Key -Value $kv.Value
    }
    Write-PodeJsonResponse -Value $Body -StatusCode 200
}

function Write-NoContentResponse {
    foreach ($kv in (New-ResponseHeaders).GetEnumerator()) {
        Set-PodeHeader -Name $kv.Key -Value $kv.Value
    }
    Set-PodeResponseStatus -Code 204
}

function Write-NotFoundResponse {
    param([string]$Message)
    foreach ($kv in (New-ResponseHeaders).GetEnumerator()) {
        Set-PodeHeader -Name $kv.Key -Value $kv.Value
    }
    Write-PodeJsonResponse -Value @{ error = @{ code = 'NotFound'; message = $Message } } -StatusCode 404
}

function Remove-SecretParams {
    param([hashtable]$Params)
    if (-not $Params) { return $null }
    $clean = @{}
    foreach ($kv in $Params.GetEnumerator()) {
        if ($kv.Key.ToLower() -notin $Script:SecretKeys) {
            $clean[$kv.Key] = $kv.Value
        }
    }
    return $clean
}

function ConvertPSObject-ToHashtable {
    param([Parameter(ValueFromPipeline)][object]$InputObject)
    process {
        if ($null -eq $InputObject)       { return $null }
        if ($InputObject -is [hashtable]) { return $InputObject }
        $ht = @{}
        $InputObject.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
        return $ht
    }
}

function ConvertTo-ResourceBody {
    param(
        [string]   $Type,
        [string]   $ApiVersion,
        [hashtable]$Identifiers,
        $AdoEndpoint
    )
    $auth   = $AdoEndpoint.authorization
    $params = if ($auth.parameters) {
        Remove-SecretParams -Params ($auth.parameters | ConvertPSObject-ToHashtable)
    } else { @{} }

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
